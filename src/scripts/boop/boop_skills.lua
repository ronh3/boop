boop.skills = boop.skills or {}

local function norm(value)
  return boop.util.safeLower(boop.util.trim(value or ""))
end

function boop.skills.init()
  boop.skills.known = boop.skills.known or {}
  boop.skills.skillToGroup = boop.skills.skillToGroup or {}
  boop.skills.groupHasList = {}
  boop.skills.groupOriginal = boop.skills.groupOriginal or {}
  boop.skills.requestedGroups = {}
  boop.skills.lastList = nil
  boop.skills.lastInfo = nil
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
  local original = boop.skills.groupOriginal[key] or group
  sendGMCP(string.format([[Char.Skills.Get {"group":"%s"}]], original))
end

function boop.skills.handleGroups()
  if not gmcp or not gmcp.Char or not gmcp.Char.Skills or not gmcp.Char.Skills.Groups then return end
  for _, group in ipairs(gmcp.Char.Skills.Groups) do
    local name = group.name or group
    if name and name ~= "" then
      boop.skills.groupOriginal[norm(name)] = name
    end
  end
  if boop.skills.desiredGroups and #boop.skills.desiredGroups > 0 then
    for _, group in ipairs(boop.skills.desiredGroups) do
      boop.skills.requestGroup(group)
    end
  end
end

function boop.skills.handleList()
  if not gmcp or not gmcp.Char or not gmcp.Char.Skills or not gmcp.Char.Skills.List then return end
  local raw = gmcp.Char.Skills.List
  local list = raw.list or raw or {}
  local group = raw.group or raw.name or raw.groupName
  local groupKey = norm(group)
  if groupKey == "" then return end

  boop.skills.groupOriginal[groupKey] = group or boop.skills.groupOriginal[groupKey]
  boop.skills.groupHasList[groupKey] = true
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
      boop.skills.known[key] = true
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

  if info.learned ~= nil then
    boop.skills.known[key] = info.learned and true or false
  else
    local text = (info.info or ""):lower()
    if text:find("not yet learned", 1, true)
      or text:find("not learned", 1, true)
      or text:find("you have not learned", 1, true)
    then
      boop.skills.known[key] = false
    end
  end
end

function boop.skills.ensureSkill(name, group)
  if not name or name == "" then return true end
  local key = norm(name)
  local groupKey = norm(group or boop.skills.skillToGroup[key] or "")

  if boop.skills.known[key] ~= nil then
    return boop.skills.known[key]
  end

  if groupKey ~= "" then
    boop.skills.skillToGroup[key] = groupKey
    if boop.skills.groupHasList[groupKey] then
      boop.skills.known[key] = false
      return false
    end
    boop.skills.requestGroup(groupKey)
    return false
  end

  return false
end

function boop.skills.knownSkill(name)
  return boop.skills.ensureSkill(name, nil)
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
