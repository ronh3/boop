boop.locks = boop.locks or {}

local function deepCopy(value, seen)
  if type(value) ~= "table" then
    return value
  end
  seen = seen or {}
  if seen[value] then
    return seen[value]
  end
  local out = {}
  seen[value] = out
  for key, entry in pairs(value) do
    out[key] = deepCopy(entry, seen)
  end
  return out
end
local function emptyBlocker()
  return {
    owner = "",
    code = "",
    label = "",
    systems = {},
    waitsFor = {},
    observed = {},
    source = "",
    since = nil,
    promptSeen = false,
    gmcpSeen = false,
    lastWarningAt = nil,
    lastWarningCode = "",
    lastRetryAt = nil,
    warningThrottleSeconds = 2,
    additionalCount = 0,
  }
end

local function isOperationOwner(owner)
  local value = tostring(owner or "")
  return value:match("^interrupt:.+") ~= nil
    or value:match("^pull:.+") ~= nil
    or value:match("^gold:.+") ~= nil
end

function boop.locks.isOperationOwner(owner)
  return isOperationOwner(owner)
end

local function trace(message)
  if boop.trace and boop.trace.log then
    boop.trace.log(message)
  end
end

local SYSTEM_ALIASES = {
  attack = "combat",
  attacks = "combat",
  targeting = "target",
}

local function sortedKeys(map)
  local keys = {}
  if type(map) ~= "table" then
    return keys
  end
  for key, value in pairs(map) do
    if value then
      keys[#keys + 1] = tostring(key)
    end
  end
  table.sort(keys)
  return keys
end

local function normalizeKey(key)
  local value = tostring(key or "")
  return SYSTEM_ALIASES[value] or value
end

local function normalizeMap(values)
  local out = {}
  if type(values) ~= "table" then
    return out
  end
  local isArray = #values > 0
  if isArray then
    for _, value in ipairs(values) do
      local key = normalizeKey(value)
      if key ~= "" then
        out[key] = true
      end
    end
    return out
  end
  for key, value in pairs(values) do
    local normalized = normalizeKey(key)
    if normalized ~= "" then
      out[normalized] = not not value
    end
  end
  return out
end

local function normalizeObserved(values)
  local out = {}
  if type(values) ~= "table" then
    return out
  end
  for key, value in pairs(values) do
    out[tostring(key)] = value
  end
  return out
end

local function mapsEqual(left, right)
  left = type(left) == "table" and left or {}
  right = type(right) == "table" and right or {}
  for key, value in pairs(left) do
    if right[key] ~= value then
      return false
    end
  end
  for key, value in pairs(right) do
    if left[key] ~= value then
      return false
    end
  end
  return true
end

local function formatMapKeys(map)
  local keys = sortedKeys(map)
  if #keys == 0 then
    return "none"
  end
  return table.concat(keys, ", ")
end

local function formatObservedValue(value)
  if type(value) == "boolean" then
    return value and "true" or "false"
  end
  if value == nil then
    return "nil"
  end
  return tostring(value)
end

local function formatObserved(map)
  if type(map) ~= "table" then
    return "none"
  end
  local keys = {}
  for key in pairs(map) do
    keys[#keys + 1] = tostring(key)
  end
  table.sort(keys)
  if #keys == 0 then
    return "none"
  end
  local parts = {}
  for _, key in ipairs(keys) do
    parts[#parts + 1] = key .. ":" .. formatObservedValue(map[key])
  end
  return table.concat(parts, ",")
end


local BLOCKER_PRIORITY = {
  gmcp_ire_missing = 10,
  missing_room = 20,
  room_partial = 21,
  target_lost = 22,
  flee_active = 30,
  pull_timeout_away = 31,
  pull_away = 32,
  pull_active = 40,
  interrupt_pending = 50,
  gold_deferred_room = 60,
  gold_pickup_pending = 61,
  gold_pack_pending = 62,
  walk_room_unsettled = 70,
  walk_move_pending = 71,
  walker_unavailable = 72,
}

local function blockerPriority(blocker)
  return BLOCKER_PRIORITY[tostring(blocker and blocker.code or "")] or 100
end

local EMPTY_BLOCKER_RECORDS = {}

local function sortedBlockerRecords(blockersByOwner)
  if type(blockersByOwner) ~= "table" then
    boop.state.combat.blockersByOwner =
      boop.state.combat.blockersByOwner or {}
    blockersByOwner = boop.state.combat.blockersByOwner
  end
  if next(blockersByOwner) == nil then
    return EMPTY_BLOCKER_RECORDS
  end
  local records = {}
  for owner, blocker in pairs(blockersByOwner) do
    if type(blocker) == "table" and tostring(blocker.code or "") ~= "" then
      records[#records + 1] = {
        owner = tostring(owner),
        code = tostring(blocker.code or ""),
        label = tostring(blocker.label or ""),
        systems = normalizeMap(blocker.systems),
        waitsFor = normalizeMap(blocker.waitsFor),
        observed = normalizeObserved(blocker.observed),
        source = tostring(blocker.source or ""),
        since = blocker.since,
        promptSeen = not not blocker.promptSeen,
        gmcpSeen = not not blocker.gmcpSeen,
        lastWarningAt = blocker.lastWarningAt,
        lastWarningCode = tostring(blocker.lastWarningCode or ""),
        lastRetryAt = blocker.lastRetryAt,
        warningThrottleSeconds = tonumber(blocker.warningThrottleSeconds) or 2,
      }
    end
  end
  table.sort(records, function(left, right)
    local leftPriority = blockerPriority(left)
    local rightPriority = blockerPriority(right)
    if leftPriority ~= rightPriority then
      return leftPriority < rightPriority
    end
    if left.code ~= right.code then
      return left.code < right.code
    end
    return left.owner < right.owner
  end)
  return records
end

local function sortedOperationRecords()
  local records = {}
  for _, blocker in ipairs(sortedBlockerRecords()) do
    if isOperationOwner(blocker.owner) then
      records[#records + 1] = blocker
    end
  end
  return records
end

local function currentOperationLock()
  local records = sortedOperationRecords()
  local operation = records[1]
    and deepCopy(records[1])
    or emptyBlocker()
  operation.additionalCount = math.max(0, #records - 1)
  boop.state.combat.operationLock = operation
  return operation
end

local function currentBlocker()
  local records = sortedBlockerRecords()
  if #records == 0 then
    boop.state.combat.blocker = emptyBlocker()
    currentOperationLock()
    return boop.state.combat.blocker
  end
  boop.state.combat.blocker = deepCopy(records[1])
  boop.state.combat.blocker.additionalCount = #records - 1
  currentOperationLock()
  return boop.state.combat.blocker
end

local function blockerChanged(current, nextBlocker)
  return tostring(current.owner or "") ~= tostring(nextBlocker.owner or "")
    or tostring(current.code or "") ~= tostring(nextBlocker.code or "")
    or tostring(current.label or "") ~= tostring(nextBlocker.label or "")
    or not mapsEqual(current.systems, nextBlocker.systems)
    or not mapsEqual(current.waitsFor, nextBlocker.waitsFor)
    or not mapsEqual(current.observed, nextBlocker.observed)
    or tostring(current.source or "") ~= tostring(nextBlocker.source or "")
end

local function setBlockerFields(blocker, nextBlocker, preserveSince)
  blocker.owner = nextBlocker.owner
  blocker.code = nextBlocker.code
  blocker.label = nextBlocker.label
  blocker.systems = nextBlocker.systems
  blocker.waitsFor = nextBlocker.waitsFor
  blocker.observed = nextBlocker.observed
  blocker.source = nextBlocker.source
  blocker.since = preserveSince and blocker.since or nextBlocker.since
  blocker.promptSeen = nextBlocker.promptSeen
  blocker.gmcpSeen = nextBlocker.gmcpSeen
  blocker.lastWarningAt = preserveSince and blocker.lastWarningAt or nil
  blocker.lastWarningCode = preserveSince and blocker.lastWarningCode or ""
  blocker.lastRetryAt = preserveSince and blocker.lastRetryAt or nil
  blocker.warningThrottleSeconds = nextBlocker.warningThrottleSeconds
end

function boop.locks.blockersSnapshot()
  return deepCopy(sortedBlockerRecords())
end

local function publicBlockerSnapshot(blocker)
  return {
    owner = tostring(blocker.owner or ""),
    code = tostring(blocker.code or ""),
    label = tostring(blocker.label or ""),
    systems = normalizeMap(blocker.systems),
    waitsFor = normalizeMap(blocker.waitsFor),
    observed = normalizeObserved(blocker.observed),
    source = tostring(blocker.source or ""),
    since = blocker.since,
    promptSeen = not not blocker.promptSeen,
    gmcpSeen = not not blocker.gmcpSeen,
    lastWarningAt = blocker.lastWarningAt,
    lastWarningCode = tostring(blocker.lastWarningCode or ""),
    lastRetryAt = blocker.lastRetryAt,
    warningThrottleSeconds = tonumber(blocker.warningThrottleSeconds) or 2,
    additionalCount = tonumber(blocker.additionalCount) or 0,
  }
end

function boop.locks.blockerSnapshot()
  return publicBlockerSnapshot(currentBlocker())
end

function boop.locks.setBlocker(owner, code, label, systems, waitsFor, opts)
  opts = opts or {}
  owner = tostring(owner or "")
  if owner == "" then
    return boop.locks.blockerSnapshot()
  end

  local nextBlocker = {
    owner = owner,
    code = tostring(code or ""),
    label = tostring(label or ""),
    systems = normalizeMap(systems),
    waitsFor = normalizeMap(waitsFor),
    observed = normalizeObserved(opts.observed),
    source = tostring(opts.source or ""),
    since = opts.since or os.time(),
    promptSeen = not not opts.promptSeen,
    gmcpSeen = not not opts.gmcpSeen,
    warningThrottleSeconds = tonumber(opts.warningThrottleSeconds) or 2,
  }

  boop.state.combat.blockersByOwner =
    boop.state.combat.blockersByOwner or {}
  local blocker = boop.state.combat.blockersByOwner[owner]
  if type(blocker) ~= "table" then
    blocker = {
      owner = "",
      code = "",
      label = "",
      systems = {},
      waitsFor = {},
      observed = {},
      source = "",
      since = nil,
      promptSeen = false,
      gmcpSeen = false,
      lastWarningAt = nil,
      lastWarningCode = "",
      lastRetryAt = nil,
      warningThrottleSeconds = 2,
    }
  end
  local changed = blockerChanged(blocker, nextBlocker)
  setBlockerFields(blocker, nextBlocker, not changed)
  boop.state.combat.blockersByOwner[owner] = blocker
  if changed and nextBlocker.code ~= "" then
    local transition = isOperationOwner(owner)
        and "operation"
      or "compat blocker"
    trace(string.format(
      "%s enter: %s | %s -- %s | systems: %s | waits: %s | observed: %s",
      transition,
      nextBlocker.owner,
      nextBlocker.code,
      nextBlocker.label,
      formatMapKeys(nextBlocker.systems),
      formatMapKeys(nextBlocker.waitsFor),
      formatObserved(nextBlocker.observed)
    ))
  end
  currentBlocker()
  return deepCopy(blocker)
end

function boop.locks.clearBlocker(owner, observed)
  boop.state.combat.blockersByOwner =
    boop.state.combat.blockersByOwner or {}
  owner = tostring(owner or "")
  local blocker = boop.state.combat.blockersByOwner[owner]
  if type(blocker) ~= "table" then
    return false
  end
  local code = tostring(blocker.code or "")
  if code == "" then
    return false
  end
  if type(observed) == "table" then
    for key, value in pairs(observed) do
      blocker.observed[tostring(key)] = value
    end
  end
  local reason = type(observed) == "string" and observed or "cleared"
  local label = tostring(blocker.label or "")
  local transition = isOperationOwner(owner)
      and "operation"
    or "compat blocker"
  trace(string.format(
    "%s exit: %s | %s -- %s | reason=%s",
    transition,
    owner,
    code,
    label,
    reason
  ))
  boop.state.combat.blockersByOwner[owner] = nil
  currentBlocker()
  return true
end

function boop.locks.shouldHold(system, exceptOwner)
  local blockersByOwner =
    boop.state.combat.blockersByOwner
  if type(blockersByOwner) ~= "table"
      or next(blockersByOwner) == nil then
    return false
  end
  local key = normalizeKey(system)
  local excluded = tostring(exceptOwner or "")
  for _, blocker in ipairs(sortedBlockerRecords(blockersByOwner)) do
    if blocker.owner ~= excluded and blocker.systems[key] == true then
      return true
    end
  end
  return false
end

function boop.locks.operationLocksSnapshot()
  return deepCopy(sortedOperationRecords())
end

function boop.locks.operationLockSnapshot()
  return publicBlockerSnapshot(currentOperationLock())
end

function boop.locks.setOperationLock(
  owner,
  code,
  label,
  systems,
  waitsFor,
  opts
)
  if not isOperationOwner(owner) then
    return false
  end
  return boop.locks.setBlocker(
    owner,
    code,
    label,
    systems,
    waitsFor,
    opts
  )
end

function boop.locks.clearOperationLock(owner, observed)
  if not isOperationOwner(owner) then
    return false
  end
  return boop.locks.clearBlocker(owner, observed)
end

function boop.locks.operationHolds(system, exceptOwner)
  local blockersByOwner =
    boop.state.combat.blockersByOwner
  if type(blockersByOwner) ~= "table"
      or next(blockersByOwner) == nil then
    return false
  end
  local key = normalizeKey(system)
  local excluded = tostring(exceptOwner or "")
  for _, blocker in ipairs(sortedBlockerRecords(blockersByOwner)) do
    if isOperationOwner(blocker.owner)
        and blocker.owner ~= excluded
        and blocker.systems[key] == true then
      return true
    end
  end
  return false
end

local INTERRUPT_TIER_VALUES = {
  utility = 10,
  diagnostic = 20,
  emergency = 30,
  absolute = 40,
}

local INTERRUPT_NAME_TIERS = {
  matic = "utility",
  catarin = "utility",
  ts = "utility",
  diag = "diagnostic",
  leap = "emergency",
  fly = "emergency",
  flee = "absolute",
}

local function normalizeInterruptTier(tier, name)
  local key = tostring(tier or ""):lower()
  if INTERRUPT_TIER_VALUES[key] then
    return key
  end
  return INTERRUPT_NAME_TIERS[tostring(name or ""):lower()] or "utility"
end

function boop.locks.interruptAdmission(active, request)
  request = type(request) == "table" and request or {}
  local incomingName = tostring(request.name or "interrupt"):lower()
  local incomingTier = normalizeInterruptTier(request.tier, incomingName)
  local result = {
    decision = "start",
    reason = "no_active_interrupt",
    incomingName = incomingName,
    incomingTier = incomingTier,
    activeName = "",
    activeTier = "",
  }
  if type(active) ~= "table" or active.terminal then
    return result
  end

  local activeName = tostring(active.name or "interrupt"):lower()
  local activeTier = normalizeInterruptTier(active.tier, activeName)
  result.activeName = activeName
  result.activeTier = activeTier

  if incomingName == activeName and request.replaceSame == true then
    result.decision = "supersede"
    result.reason = "same_interrupt_retry"
    return result
  end

  local incomingValue = INTERRUPT_TIER_VALUES[incomingTier] or 0
  local activeValue = INTERRUPT_TIER_VALUES[activeTier] or 0
  if incomingValue > activeValue then
    result.decision = "supersede"
    result.reason = "higher_priority"
  elseif incomingValue == activeValue then
    result.decision = "reject"
    result.reason = incomingName == activeName
      and "duplicate_pending"
      or "same_tier_conflict"
  else
    result.decision = "reject"
    result.reason = "lower_priority"
  end
  return result
end


local function blockerCanAutoClear(blocker)
  if type(blocker) ~= "table" or tostring(blocker.code or "") == "" then
    return false
  end
  local required = false
  for evidence, needed in pairs(blocker.waitsFor or {}) do
    if needed then
      required = true
      if evidence == "prompt" and not blocker.promptSeen then
        return false
      elseif evidence == "gmcp" and not blocker.gmcpSeen then
        return false
      elseif evidence ~= "prompt"
          and evidence ~= "gmcp"
          and not (blocker.observed and blocker.observed[evidence]) then
        return false
      end
    end
  end
  return required
end

local function maybeClearObservedBlocker(owner, reason)
  local blockersByOwner = boop.state.combat.blockersByOwner
  local blocker = blockersByOwner and blockersByOwner[owner] or nil
  if blockerCanAutoClear(blocker) then
    boop.locks.clearBlocker(owner, reason or "declared evidence observed")
  end
end

function boop.locks.notePromptObserved()
  local changed = false
  for _, snapshot in ipairs(sortedBlockerRecords()) do
    local blocker = boop.state.combat.blockersByOwner[snapshot.owner]
    if blocker and blocker.waitsFor and blocker.waitsFor.prompt then
      blocker.promptSeen = true
      blocker.observed = blocker.observed or {}
      blocker.observed.prompt = true
      changed = true
      maybeClearObservedBlocker(snapshot.owner, "declared evidence observed")
    end
  end
  currentBlocker()
  return changed
end

function boop.locks.noteGmcpObserved(owner, kind)
  owner = tostring(owner or "")
  local blockersByOwner = boop.state.combat.blockersByOwner
  local blocker = blockersByOwner and blockersByOwner[owner] or nil
  if type(blocker) ~= "table" or tostring(blocker.code or "") == "" then
    return false
  end
  blocker.gmcpSeen = true
  blocker.observed = blocker.observed or {}
  blocker.observed.gmcp = true
  local observedKey = tostring(kind or "")
  if observedKey ~= "" then
    if observedKey == "room" and gmcp and gmcp.Room and gmcp.Room.Info then
      blocker.observed.room = tostring(gmcp.Room.Info.num or "")
    elseif observedKey == "ire" then
      blocker.observed.ire = true
    else
      blocker.observed[observedKey] = true
    end
  end
  maybeClearObservedBlocker(owner, "declared evidence observed")
  currentBlocker()
  return true
end
