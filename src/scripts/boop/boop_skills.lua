boop.skills = boop.skills or {}

local function norm(value)
  return boop.util.safeLower(boop.util.trim(value or ""))
end

function boop.skills.init()
  boop.skills.known = boop.skills.known or {}
  boop.skills.skillToGroup = boop.skills.skillToGroup or {}
  boop.skills.skillOriginal = boop.skills.skillOriginal or {}
  boop.skills.pending = {}
  boop.skills.pendingTimers = {}
  boop.skills.lastInfo = nil
  boop.skills.lastList = nil
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
  sendGMCP([[Char.Skills.Get]])
end

function boop.skills.requestSkillDirect(name, group)
  if not name or name == "" then return end
  local key = norm(name)
  local groupKey = norm(group or boop.skills.skillToGroup[key] or "")
  if key == "" or groupKey == "" then return end
  if boop.skills.pending[key] then return end

  boop.skills.skillToGroup[key] = groupKey
  boop.skills.pending[key] = true
  local skillName = boop.skills.skillOriginal[key] or name
  sendGMCP(string.format([[Char.Skills.Get {"group":"%s","name":"%s"}]], groupKey, skillName))

  if boop.skills.pendingTimers[key] then
    killTimer(boop.skills.pendingTimers[key])
  end
  boop.skills.pendingTimers[key] = tempTimer(1.5, function()
    boop.skills.pending[key] = nil
    boop.skills.pendingTimers[key] = nil
  end)
end

function boop.skills.knownSkill(name)
  if not name or name == "" then return true end
  local key = norm(name)
  local val = boop.skills.known[key]
  if val == nil then
    boop.skills.requestSkillDirect(name, boop.skills.skillToGroup[key])
    return false
  end
  return val
end

function boop.skills.ensureSkill(name, group)
  if not name or name == "" then return true end
  local key = norm(name)
  local val = boop.skills.known[key]
  if val ~= nil then return val end
  if group and group ~= "" then
    boop.skills.requestSkillDirect(name, group)
  end
  return false
end

function boop.skills.handleGroups()
  -- No-op for now; we request skills directly by group+name.
end

function boop.skills.handleList()
  if not gmcp or not gmcp.Char or not gmcp.Char.Skills or not gmcp.Char.Skills.List then return end
  local raw = gmcp.Char.Skills.List
  local list = raw.list or raw or {}
  local group = raw.group or raw.name or raw.groupName
  local groupKey = norm(group)
  if groupKey == "" then return end

  boop.skills.lastList = { group = groupKey, list = list }

  local function handleEntry(entry, keyHint)
    local name = entry
    if type(entry) == "table" then
      name = entry.name or entry.skill or entry.id or keyHint
    elseif type(entry) == "number" then
      name = tostring(entry)
    end
    local key = norm(name)
    if key ~= "" then
      boop.skills.skillToGroup[key] = groupKey
      boop.skills.skillOriginal[key] = name
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
  if key == "" then return end

  boop.skills.known[key] = learnedFromInfo(info)
  boop.skills.pending[key] = nil
  if boop.skills.pendingTimers[key] then
    killTimer(boop.skills.pendingTimers[key])
    boop.skills.pendingTimers[key] = nil
  end
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
