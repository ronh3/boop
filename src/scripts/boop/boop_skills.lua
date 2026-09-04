boop.skills = boop.skills or {}

local function norm(value)
  return boop.util.safeLower(boop.util.trim(value or ""))
end

local function ensureCaches()
  boop.skills.known = boop.skills.known or {}
  boop.skills.knownGroups = boop.skills.knownGroups or {}
  boop.skills.skillToGroup = boop.skills.skillToGroup or {}
  boop.skills.skillOriginal = boop.skills.skillOriginal or {}
  boop.skills.pending = boop.skills.pending or {}
  boop.skills.pendingGroups = boop.skills.pendingGroups or {}
  boop.skills.pendingTimers = boop.skills.pendingTimers or {}
end

function boop.skills.init()
  ensureCaches()
  boop.skills.pending = {}
  boop.skills.pendingGroups = {}
  boop.skills.pendingTimers = {}
  boop.skills.lastInfo = nil
  boop.skills.lastList = nil
end

function boop.skills.setDesiredGroups(groups)
  if type(groups) ~= "table" then
    boop.skills.desiredGroups = {}
    return boop.skills.desiredGroups
  end

  local desired = {}
  for _, group in ipairs(groups) do
    desired[#desired + 1] = tostring(group)
  end
  boop.skills.desiredGroups = desired
  return desired
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

  -- Request the groups we actively gate on so skill->group mapping is filled early.
  local desired = boop.skills.desiredGroups or {}
  local seen = {}
  for _, group in ipairs(desired) do
    local groupKey = norm(group)
    if groupKey ~= "" and not seen[groupKey] then
      seen[groupKey] = true
      sendGMCP(string.format([[Char.Skills.Get {"group":"%s"}]], groupKey))
    end
  end
end

function boop.skills.requestSkillDirect(name, group)
  ensureCaches()
  if not name or name == "" then return end
  local key = norm(name)
  local groupKey = norm(group or boop.skills.skillToGroup[key] or "")
  if key == "" or groupKey == "" then return end
  if boop.skills.pending[key] then return end

  boop.skills.skillToGroup[key] = groupKey
  boop.skills.pending[key] = true
  boop.skills.pendingGroups[key] = groupKey
  local skillName = boop.skills.skillOriginal[key] or name
  sendGMCP(string.format([[Char.Skills.Get {"group":"%s","name":"%s"}]], groupKey, skillName))

  if boop.skills.pendingTimers[key] then
    killTimer(boop.skills.pendingTimers[key])
  end
  boop.skills.pendingTimers[key] = tempTimer(1.5, function()
    boop.skills.pending[key] = nil
    boop.skills.pendingGroups[key] = nil
    boop.skills.pendingTimers[key] = nil
  end)
end

function boop.skills.knownSkill(name)
  ensureCaches()
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
  ensureCaches()
  if not name or name == "" then return true end
  local key = norm(name)
  local val = boop.skills.known[key]
  local requestedGroup = norm(group)
  local cachedGroup = norm(boop.skills.knownGroups[key] or boop.skills.skillToGroup[key])
  if val ~= nil and (requestedGroup == "" or cachedGroup == "" or cachedGroup == requestedGroup) then
    return val
  end
  if requestedGroup ~= "" then
    boop.skills.requestSkillDirect(name, requestedGroup)
  end
  return false
end

function boop.skills.handleGroups()
  -- No-op for now; we request skills directly by group+name.
end

function boop.skills.handleList()
  ensureCaches()
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
  ensureCaches()
  if not gmcp or not gmcp.Char or not gmcp.Char.Skills or not gmcp.Char.Skills.Info then return end
  local info = gmcp.Char.Skills.Info
  boop.skills.lastInfo = info
  local key = norm(info.skill or info.name or "")
  if key == "" then return end

  local groupKey = norm(info.group or boop.skills.pendingGroups[key] or boop.skills.skillToGroup[key])
  boop.skills.known[key] = learnedFromInfo(info)
  if groupKey ~= "" then
    boop.skills.knownGroups[key] = groupKey
    boop.skills.skillToGroup[key] = groupKey
  end
  boop.skills.pending[key] = nil
  boop.skills.pendingGroups[key] = nil
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

boop.perf.register("gmcp.Char.Skills.Groups", boop, "onSkillsGroups")
boop.perf.register("gmcp.Char.Skills.List", boop, "onSkillsList")
boop.perf.register("gmcp.Char.Skills.Info", boop, "onSkillsInfo")
