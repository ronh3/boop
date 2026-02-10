boop.skills = boop.skills or {}

local function norm(value)
  return boop.util.safeLower(boop.util.trim(value or ""))
end

function boop.skills.init()
  boop.skills.known = boop.skills.known or {}
  boop.skills.skillToGroup = boop.skills.skillToGroup or {}
  boop.skills.pending = {}
  boop.skills.queue = {}
  boop.skills.processing = false
  boop.skills.processingTimer = nil
  boop.skills.requestedGroups = {}
  boop.skills.lastList = nil
  boop.skills.lastInfo = nil
end

local function learnedFromInfo(info)
  if info and info.learned ~= nil then
    return info.learned and true or false
  end
  local text = (info and info.info or ""):lower()
  if text:find("not yet learned", 1, true)
    or text:find("not learned", 1, true)
    or text:find("you have not learned", 1, true)
  then
    return false
  end
  return true
end

function boop.skills.requestAll()
  if not sendGMCP then return end

  if boop.skills.desiredGroups and #boop.skills.desiredGroups > 0 then
    for _, group in ipairs(boop.skills.desiredGroups) do
      boop.skills.requestGroup(group)
    end
    return
  end

  sendGMCP([[Char.Skills.Get]])
  sendGMCP([[Char.Skills.Get {"group":"attainment"}]])
end

function boop.skills.requestGroup(group)
  if not sendGMCP then return end
  local key = norm(group)
  if key == "" then return end
  if boop.skills.requestedGroups[key] then return end
  boop.skills.requestedGroups[key] = true
  sendGMCP(string.format([[Char.Skills.Get {"group":"%s"}]], key))
end

function boop.skills.requestSkillDirect(name, group)
  if not name or name == "" then return end
  local key = norm(name)
  if key == "" then return end
  if boop.skills.pending[key] then return end
  local groupKey = norm(group or boop.skills.skillToGroup[key] or "")
  if groupKey == "" then return end

  boop.skills.skillToGroup[key] = groupKey
  boop.skills.pending[key] = true
  boop.skills.queue[#boop.skills.queue + 1] = { group = groupKey, name = key }
  boop.skills.processQueue()
end

function boop.skills.processQueue()
  if boop.skills.processing then return end
  if #boop.skills.queue == 0 then return end

  local nextItem = table.remove(boop.skills.queue, 1)
  boop.skills.processing = true
  sendGMCP(string.format([[Char.Skills.Get {"group":"%s","name":"%s"}]], nextItem.group, nextItem.name))

  if boop.skills.processingTimer then
    killTimer(boop.skills.processingTimer)
  end
  boop.skills.processingTimer = tempTimer(1.5, function()
    if boop.skills.processing then
      boop.skills.processing = false
      boop.skills.processQueue()
    end
  end)
end

function boop.skills.knownSkill(name)
  if not name or name == "" then return true end
  local key = norm(name)
  local val = boop.skills.known[key]
  if val == nil then
    local group = boop.skills.skillToGroup[key]
    if group and group ~= "" then
      boop.skills.requestSkillDirect(name, group)
    end
    return false
  end
  return val
end

function boop.skills.ensureSkill(name, group)
  if not name or name == "" then return true end
  local key = norm(name)
  if boop.skills.known[key] ~= nil then
    return boop.skills.known[key]
  end
  if group and group ~= "" then
    boop.skills.skillToGroup[key] = norm(group)
    boop.skills.requestSkillDirect(name, group)
  end
  return false
end

function boop.skills.handleGroups()
  if not gmcp or not gmcp.Char or not gmcp.Char.Skills or not gmcp.Char.Skills.Groups then return end
  for _, group in ipairs(gmcp.Char.Skills.Groups) do
    local name = group.name or group
    if name and name ~= "" then
      boop.skills.requestGroup(name)
    end
  end
end

function boop.skills.handleList()
  if not gmcp or not gmcp.Char or not gmcp.Char.Skills or not gmcp.Char.Skills.List then return end
  local raw = gmcp.Char.Skills.List
  local list = raw.list or raw or {}
  local group = norm(raw.group or raw.name or raw.groupName)
  boop.skills.lastList = { group = group, list = list }

  local function handleEntry(entry, keyHint)
    local name = entry
    if type(entry) == "table" then
      name = entry.name or entry.skill or entry.id or keyHint
    elseif type(entry) == "number" then
      name = tostring(entry)
    end
    if name and name ~= "" then
      local key = norm(name)
      if group ~= "" then
        boop.skills.skillToGroup[key] = group
      end
    end
  end

  if #list > 0 then
    for _, entry in ipairs(list) do
      handleEntry(entry, nil)
    end
  else
    for key, entry in pairs(list) do
      handleEntry(entry, key)
    end
  end
end

function boop.skills.handleInfo()
  if not gmcp or not gmcp.Char or not gmcp.Char.Skills or not gmcp.Char.Skills.Info then return end
  local info = gmcp.Char.Skills.Info
  boop.skills.lastInfo = info
  local key = norm(info.skill or info.name or "")
  if key == "" then
    boop.skills.processing = false
    boop.skills.processQueue()
    return
  end
  boop.skills.known[key] = learnedFromInfo(info)
  boop.skills.pending[key] = nil
  boop.skills.processing = false
  if boop.skills.processingTimer then
    killTimer(boop.skills.processingTimer)
    boop.skills.processingTimer = nil
  end
  boop.skills.processQueue()
end

function boop.onSkillsGroups()
  boop.skills.handleGroups()
end

function boop.onSkillsList()
  boop.skills.handleList()
end

function boop.onSkillsInfo()
  boop.skills.handleInfo()
end
