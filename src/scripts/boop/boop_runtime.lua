boop.runtime = boop.runtime or {}

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

local DOMAIN_DEFAULTS = {
  combat = {
    hunting = false,
    attacking = false,
    fleeing = false,
    class = "",
    spec = "",
    limiters = {
      hunting = false,
      targeting = false,
      setting = false,
      rage = false,
    },
    openerUsedByClass = {},
    pullGeneration = 0,
    pullState = false,
    blockersByOwner = {},
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
      additionalCount = 0,
    },
    lastComboTraceKey = nil,
    lastOpenerTraceKey = nil,
    lastRageDecision = nil,
  },
  targeting = {
    currentTargetId = "",
    targetName = "",
    targetShield = false,
    denizens = {},
    room = "",
    lastRoom = "",
    lastRoomDir = "",
    movedRooms = false,
    calledTargetId = "",
    calledTargetRoom = "",
    calledTargetBy = "",
    calledTargetAt = nil,
    incomingWhitelistShares = {},
    pendingWhitelistShare = nil,
    roomObservation = {
      generation = 0,
      roomId = "",
      infoSeen = false,
      itemsSeen = false,
      acceptedItems = {},
      fenceQueue = {},
      activeFenceId = false,
      nextFenceId = 1,
      refreshAttempted = false,
      refreshReason = "",
      refreshTimeoutTimer = false,
      warned = false,
    },
  },
  gold = {
    generation = 0,
    operation = false,
    dropped = false,
    shardsDropped = false,
    autoGrabPending = false,
    autoGrabPendingAt = nil,
    autoGrabTimer = nil,
    getPending = false,
    putPending = false,
    getRetries = 0,
    putRetries = 0,
    packTarget = "",
    pendingTimer = nil,
  },
  queue = {
    balanceReadyAt = nil,
    equilibriumReadyAt = nil,
    prequeueTimer = nil,
    prequeuedStandard = false,
    aliasAction = "",
    aliasDirty = true,
  },
  walk = {
    active = false,
    owned = false,
    roomSettled = false,
    moveQueued = false,
    arrivalRoom = "",
    generation = 0,
    roomGeneration = 0,
    moveIssuedForRoomGeneration = false,
    reservationId = 0,
    refreshTimer = nil,
    emitterTimer = nil,
    refreshWarned = false,
  },
  diag = {
    hold = false,
    awaitPrompt = false,
    timeoutTimer = nil,
    label = "",
    generation = 0,
    operation = false,
    evidenceQueue = {},
  },
  trace = {
    buffer = {},
  },
  ui = {
    configScreen = "home",
    configReturnScreen = nil,
    configReturnPrefix = nil,
  },
  rage = {
    ready = {},
    timers = {},
    samples = {},
    freeNext = false,
  },
  inventory = {
    itemsById = {},
    wieldedLeft = false,
    wieldedRight = false,
  },
  ih = {
    active = false,
    requested = false,
    timer = nil,
  },
  gag = {
    lastRawLine = "",
    lastAt = 0,
    pendingAttack = nil,
    pendingAttackTimer = nil,
    pendingKill = nil,
    pendingKillTimer = nil,
    razeslashIntent = nil,
  },
}

function boop.runtime.ensureState()
  boop.state = boop.state or {}
  local state = boop.state

  for domain, defaults in pairs(DOMAIN_DEFAULTS) do
    local current = rawget(state, domain)
    if type(current) ~= "table" then
      current = {}
      rawset(state, domain, current)
    end
    for key, default in pairs(defaults) do
      if current[key] == nil then
        current[key] = deepCopy(default)
      end
    end
  end
  return state
end

function boop.runtime.state()
  return boop.runtime.ensureState()
end

local function normalizeRoomId(roomId)
  return tostring(roomId or ""):match("^%s*(.-)%s*$")
end

local function roomObservationState()
  local state = boop.runtime.ensureState()
  local observation = state.targeting.roomObservation
  if type(observation) ~= "table" then
    observation = deepCopy(DOMAIN_DEFAULTS.targeting.roomObservation)
    state.targeting.roomObservation = observation
  end
  observation.generation = tonumber(observation.generation) or 0
  observation.roomId = normalizeRoomId(observation.roomId)
  observation.infoSeen = not not observation.infoSeen
  observation.itemsSeen = not not observation.itemsSeen
  observation.acceptedItems = type(observation.acceptedItems) == "table"
    and observation.acceptedItems
    or {}
  observation.fenceQueue = type(observation.fenceQueue) == "table"
    and observation.fenceQueue
    or {}
  observation.activeFenceId = observation.activeFenceId or false
  observation.nextFenceId = math.max(1, tonumber(observation.nextFenceId) or 1)
  observation.refreshAttempted = not not observation.refreshAttempted
  observation.refreshReason = tostring(observation.refreshReason or "")
  observation.refreshTimeoutTimer = observation.refreshTimeoutTimer or false
  observation.warned = not not observation.warned
  return observation
end

function boop.runtime.startRoomObservation(roomId, opts)
  opts = type(opts) == "table" and opts or {}
  local boundary = tostring(opts.boundary or "fresh_start")
  if boundary ~= "room_change" and boundary ~= "fresh_start" then
    return false
  end
  local state = boop.runtime.ensureState()
  local previous = roomObservationState()
  local generation = tonumber(previous.generation) or 0
  local normalizedRoomId = normalizeRoomId(roomId)
  local fences = previous.fenceQueue
  for _, fence in ipairs(fences) do
    fence.valid = false
  end
  if previous.refreshTimeoutTimer and killTimer then
    killTimer(previous.refreshTimeoutTimer)
  end
  state.targeting.roomObservation = {
    generation = generation + 1,
    roomId = normalizedRoomId,
    infoSeen = normalizedRoomId ~= "",
    itemsSeen = false,
    acceptedItems = {},
    fenceQueue = fences,
    activeFenceId = false,
    nextFenceId = previous.nextFenceId,
    refreshAttempted = false,
    refreshReason = tostring(opts.reason or ""),
    refreshTimeoutTimer = false,
    warned = false,
  }
  return boop.runtime.roomObservationSnapshot()
end

function boop.runtime.observeRoomInfo(roomId, opts)
  opts = type(opts) == "table" and opts or {}
  local normalizedRoomId = normalizeRoomId(roomId)
  local observation = roomObservationState()
  if opts.movedRooms or opts.freshStart or opts.boundary == "room_change"
      or opts.boundary == "fresh_start" then
    return boop.runtime.startRoomObservation(normalizedRoomId, opts)
  end
  if normalizedRoomId == "" or normalizedRoomId ~= observation.roomId then
    return false
  end
  observation.infoSeen = true
  return boop.runtime.roomObservationSnapshot()
end

function boop.runtime.beginRoomResponseFence(reason)
  local observation = roomObservationState()
  if not observation.infoSeen
      or observation.itemsSeen
      or observation.roomId == ""
      or observation.refreshAttempted then
    return false
  end
  local fenceId = observation.nextFenceId
  observation.nextFenceId = fenceId + 1
  local fence = {
    fenceId = fenceId,
    generation = observation.generation,
    roomId = observation.roomId,
    phase = "await_inv",
    valid = true,
  }
  observation.fenceQueue[#observation.fenceQueue + 1] = fence
  observation.activeFenceId = fenceId
  observation.refreshAttempted = true
  observation.refreshReason = tostring(reason or "room item evidence missing")
  return deepCopy(fence)
end

function boop.runtime.setRoomResponseFenceTimer(fenceId, timerId)
  local observation = roomObservationState()
  if tonumber(observation.activeFenceId) ~= tonumber(fenceId) then
    return false
  end
  observation.refreshTimeoutTimer = timerId or false
  return true
end

function boop.runtime.timeoutRoomResponseFence(fenceId, timerId)
  local observation = roomObservationState()
  if tonumber(observation.activeFenceId) ~= tonumber(fenceId)
      or observation.itemsSeen
      or observation.refreshTimeoutTimer ~= timerId then
    return false
  end
  observation.refreshTimeoutTimer = false
  if observation.warned then
    return false
  end
  observation.warned = true
  return true
end

local function currentRoomId()
  return normalizeRoomId(
    gmcp
      and gmcp.Room
      and gmcp.Room.Info
      and gmcp.Room.Info.num
      or ""
  )
end

function boop.runtime.observeRoomItemsList(location, items)
  local observation = roomObservationState()
  local queue = observation.fenceQueue
  local fence = queue[1]
  local normalizedLocation = tostring(location or ""):lower()
  local copiedItems = type(items) == "table" and deepCopy(items) or false

  if normalizedLocation == "inv" then
    if type(fence) ~= "table" then
      if not copiedItems then
        return {
          status = "rejected",
          location = normalizedLocation,
        }
      end
      return {
        status = "inventory",
        location = normalizedLocation,
        items = copiedItems,
      }
    end
    if fence.phase ~= "await_inv" then
      return {
        status = "duplicate",
        fenceId = fence.fenceId,
      }
    end
    fence.phase = "await_room"
    if not fence.valid then
      return {
        status = "drained",
        fenceId = fence.fenceId,
        location = normalizedLocation,
      }
    end
    if not copiedItems then
      fence.phase = "await_inv"
      return {
        status = "rejected",
        fenceId = fence.fenceId,
        location = normalizedLocation,
      }
    end
    return {
      status = "inventory",
      fenceId = fence.fenceId,
      items = copiedItems,
    }
  end

  if type(fence) ~= "table" then
    return {
      status = "orphan",
      location = normalizedLocation,
    }
  end

  if normalizedLocation ~= "room" then
    return {
      status = "ignored",
      fenceId = fence.fenceId,
      location = normalizedLocation,
    }
  end
  if fence.phase ~= "await_room" then
    return {
      status = "awaiting_inv",
      fenceId = fence.fenceId,
    }
  end

  table.remove(queue, 1)
  if not fence.valid then
    return {
      status = "drained",
      fenceId = fence.fenceId,
      location = normalizedLocation,
    }
  end
  if not copiedItems
      or tonumber(fence.generation) ~= tonumber(observation.generation)
      or normalizeRoomId(fence.roomId) ~= observation.roomId
      or currentRoomId() ~= observation.roomId then
    return {
      status = "rejected",
      fenceId = fence.fenceId,
      location = normalizedLocation,
    }
  end

  observation.itemsSeen = true
  observation.acceptedItems = copiedItems
  if tonumber(observation.activeFenceId) == tonumber(fence.fenceId) then
    observation.activeFenceId = false
  end
  if observation.refreshTimeoutTimer and killTimer then
    killTimer(observation.refreshTimeoutTimer)
  end
  observation.refreshTimeoutTimer = false
  return {
    status = "accepted",
    fenceId = fence.fenceId,
    generation = observation.generation,
    roomId = observation.roomId,
    items = deepCopy(copiedItems),
  }
end

function boop.runtime.roomObservationSnapshot()
  local observation = roomObservationState()
  return {
    generation = tonumber(observation.generation) or 0,
    roomId = tostring(observation.roomId or ""),
    infoSeen = not not observation.infoSeen,
    itemsSeen = not not observation.itemsSeen,
    acceptedItems = deepCopy(observation.acceptedItems),
    fenceQueue = deepCopy(observation.fenceQueue),
    activeFenceId = observation.activeFenceId or false,
    nextFenceId = tonumber(observation.nextFenceId) or 1,
    refreshAttempted = not not observation.refreshAttempted,
    refreshReason = tostring(observation.refreshReason or ""),
    refreshTimeoutTimer = observation.refreshTimeoutTimer or false,
    warned = not not observation.warned,
  }
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

local function trace(message)
  if boop.trace and boop.trace.log then
    boop.trace.log(message)
  end
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

local function sortedBlockerRecords()
  local state = boop.runtime.ensureState()
  state.combat.blockersByOwner = state.combat.blockersByOwner or {}
  local records = {}
  for owner, blocker in pairs(state.combat.blockersByOwner) do
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

local function currentBlocker()
  local state = boop.runtime.ensureState()
  local records = sortedBlockerRecords()
  if #records == 0 then
    state.combat.blocker = deepCopy(DOMAIN_DEFAULTS.combat.blocker)
    return state.combat.blocker
  end
  state.combat.blocker = deepCopy(records[1])
  state.combat.blocker.additionalCount = #records - 1
  return state.combat.blocker
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

function boop.runtime.blockersSnapshot()
  return deepCopy(sortedBlockerRecords())
end

function boop.runtime.blockerSnapshot()
  local blocker = currentBlocker()
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

function boop.runtime.setBlocker(owner, code, label, systems, waitsFor, opts)
  opts = opts or {}
  owner = tostring(owner or "")
  if owner == "" then
    return boop.runtime.blockerSnapshot()
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

  local state = boop.runtime.ensureState()
  state.combat.blockersByOwner = state.combat.blockersByOwner or {}
  local blocker = state.combat.blockersByOwner[owner]
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
  state.combat.blockersByOwner[owner] = blocker
  if changed and nextBlocker.code ~= "" then
    trace(string.format(
      "blocker enter: %s | %s -- %s | systems: %s | waits: %s | observed: %s",
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

function boop.runtime.clearBlocker(owner, observed)
  local state = boop.runtime.ensureState()
  state.combat.blockersByOwner = state.combat.blockersByOwner or {}
  owner = tostring(owner or "")
  local blocker = state.combat.blockersByOwner[owner]
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
  trace(string.format("blocker exit: %s | %s -- %s | reason=%s", owner, code, label, reason))
  state.combat.blockersByOwner[owner] = nil
  currentBlocker()
  return true
end

function boop.runtime.shouldHold(system, exceptOwner)
  local key = normalizeKey(system)
  local excluded = tostring(exceptOwner or "")
  for _, blocker in ipairs(sortedBlockerRecords()) do
    if blocker.owner ~= excluded and blocker.systems[key] == true then
      return true
    end
  end
  return false
end

function boop.runtime.enqueueDiagEvidence(generation)
  local state = boop.runtime.ensureState()
  state.diag.evidenceQueue = state.diag.evidenceQueue or {}
  local record = {
    generation = tonumber(generation) or 0,
    resultSeen = false,
    terminal = false,
    tombstone = false,
  }
  state.diag.evidenceQueue[#state.diag.evidenceQueue + 1] = record
  return record
end

function boop.runtime.completeInterrupt(generation, terminalReason)
  local state = boop.runtime.ensureState()
  local operation = state.diag.operation
  local expectedGeneration = tonumber(generation)
  if type(operation) ~= "table"
      or operation.generation ~= expectedGeneration
      or operation.terminal then
    return false
  end

  operation.terminal = true
  local reason = tostring(terminalReason or "")
  if reason == "timeout" and operation.completionMode == "result_then_prompt" then
    for _, record in ipairs(state.diag.evidenceQueue or {}) do
      if type(record) == "table" and record.generation == expectedGeneration then
        record.terminal = true
        record.tombstone = true
        break
      end
    end
  end

  local timerId = operation.timeoutTimer
  operation.timeoutTimer = nil
  if timerId and killTimer then
    killTimer(timerId)
  end

  boop.runtime.clearBlocker(operation.blockerOwner, reason)

  local name = tostring(operation.name or "interrupt")
  local owner = tostring(operation.blockerOwner or "")
  state.diag.operation = false
  state.diag.hold = false
  state.diag.awaitPrompt = false
  state.diag.timeoutTimer = nil
  state.diag.label = ""

  if reason == "timeout" then
    if boop.util and boop.util.warn then
      boop.util.warn(name .. " timeout; attacks resumed")
    end
  elseif boop.util and boop.util.ok then
    boop.util.ok(name .. " complete; attacks resumed")
  end
  trace(string.format(
    "interrupt terminal: %s | generation=%s | name=%s | reason=%s",
    owner,
    tostring(expectedGeneration or ""),
    name,
    reason
  ))
  return true
end

function boop.runtime.markOldestDiagEvidenceResult()
  local state = boop.runtime.ensureState()
  local head = state.diag.evidenceQueue and state.diag.evidenceQueue[1] or nil
  if type(head) ~= "table" or head.resultSeen then
    return false
  end

  head.resultSeen = true
  local operation = state.diag.operation
  if type(operation) == "table"
      and not operation.terminal
      and operation.name == "diag"
      and operation.completionMode == "result_then_prompt"
      and operation.generation == head.generation then
    operation.resultSeen = true
    state.diag.awaitPrompt = true
  end
  return true
end

function boop.runtime.consumeOldestDiagEvidencePrompt()
  local state = boop.runtime.ensureState()
  local queue = state.diag.evidenceQueue or {}
  local head = queue[1]
  if type(head) ~= "table" or not head.resultSeen then
    return false, false
  end

  table.remove(queue, 1)
  if head.terminal or head.tombstone then
    return true, false
  end

  local operation = state.diag.operation
  if type(operation) == "table"
      and not operation.terminal
      and operation.name == "diag"
      and operation.completionMode == "result_then_prompt"
      and operation.generation == head.generation then
    return true, boop.runtime.completeInterrupt(
      head.generation,
      "diagnose_result_prompt"
    )
  end
  return true, false
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
  local state = boop.runtime.ensureState()
  local blocker = state.combat.blockersByOwner and state.combat.blockersByOwner[owner] or nil
  if blockerCanAutoClear(blocker) then
    boop.runtime.clearBlocker(owner, reason or "declared evidence observed")
  end
end

function boop.runtime.notePromptObserved()
  local state = boop.runtime.ensureState()
  local changed = false
  for _, snapshot in ipairs(sortedBlockerRecords()) do
    local blocker = state.combat.blockersByOwner[snapshot.owner]
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

function boop.runtime.noteGmcpObserved(owner, kind)
  local state = boop.runtime.ensureState()
  owner = tostring(owner or "")
  local blocker = state.combat.blockersByOwner and state.combat.blockersByOwner[owner] or nil
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

local function killOwnedTimer(timerId)
  if timerId and killTimer then
    killTimer(timerId)
  end
end

local function describeQueue(queue)
  if queue.prequeuedStandard then
    return "prequeued aliasDirty=" .. tostring(queue.aliasDirty ~= false)
  end
  if tostring(queue.aliasAction or "") ~= "" then
    return "aliasDirty=" .. tostring(queue.aliasDirty ~= false)
  end
  return "clear"
end

local function describeGold(gold)
  if type(gold.operation) == "table" and not gold.operation.terminal then
    return string.format(
      "%s:%s",
      tostring(gold.operation.phase or "pending"),
      tostring(gold.operation.generation or "?")
    )
  end
  if gold.getPending or gold.putPending then
    local parts = {}
    if gold.getPending then parts[#parts + 1] = "get" end
    if gold.putPending then parts[#parts + 1] = "put" end
    return table.concat(parts, ",")
  end
  if gold.autoGrabPending then
    return "auto"
  end
  return "clear"
end

local function describeDiag(diag)
  if diag.hold then
    local label = tostring(diag.label or "")
    return "hold" .. (label ~= "" and (":" .. label) or "")
  end
  return "clear"
end

local function describeGag(gag)
  if type(gag.pendingAttack) == "table" then
    return string.format(
      "pending:%s/%s/%s",
      tostring(gag.pendingAttack.source or "?"),
      tostring(gag.pendingAttack.ability or "?"),
      tostring(gag.pendingAttack.target or "?")
    )
  end
  if gag.pendingKill then
    return "pending:kill"
  end
  return "clear"
end

local function automationTraceMessage(reason, opts)
  local state = boop.runtime.ensureState()
  local targetId = tostring(state.targeting.currentTargetId or "")
  if targetId == "" then
    targetId = tostring(state.targeting.calledTargetId or "")
  end
  local parts = {
    "automation intent cleared: " .. tostring(reason or "unspecified"),
  }
  if opts and opts.source and tostring(opts.source) ~= "" then
    parts[#parts + 1] = "source=" .. tostring(opts.source)
  end
  parts[#parts + 1] = "target=" .. targetId
  parts[#parts + 1] = "queue=" .. describeQueue(state.queue)
  parts[#parts + 1] = "walk=active " .. "moveQueued=" .. tostring(state.walk.moveQueued == true)
  parts[#parts + 1] = "gold=" .. describeGold(state.gold)
  parts[#parts + 1] = "diag=" .. describeDiag(state.diag)
  parts[#parts + 1] = "gag=" .. describeGag(state.gag)
  return table.concat(parts, " | ")
end

function boop.runtime.clearAttackIntent(reason, opts)
  opts = opts or {}
  local state = boop.runtime.ensureState()
  state.combat.attacking = false
  state.combat.lastRageDecision = nil
  state.combat.pendingStandard = nil
  state.combat.pendingRage = nil
  state.combat.attackPlan = nil

  killOwnedTimer(state.queue.prequeueTimer)
  state.queue.prequeueTimer = nil
  state.queue.prequeuedStandard = false
  state.queue.aliasAction = ""
  state.queue.aliasDirty = true

  state.targeting.calledTargetId = ""
  state.targeting.calledTargetRoom = ""
  state.targeting.calledTargetBy = ""
  state.targeting.calledTargetAt = nil

  if tostring(reason or "") == "target_lost" then
    state.targeting.currentTargetId = ""
    state.targeting.targetName = ""
    if boop.targets and boop.targets.clearTargetShield then
      boop.targets.clearTargetShield("target_lost")
    else
      state.targeting.targetShield = false
    end
  end

  if not opts.suppressTrace then
    trace("attack intent cleared: " .. tostring(reason or "unspecified"))
  end
  return true
end

function boop.runtime.clearAutomationIntent(reason, opts)
  opts = opts or {}
  local state = boop.runtime.ensureState()
  local includeAttack = opts.includeAttack ~= false
  local includeWalk = opts.includeWalk ~= false
  local includeGold = opts.includeGold ~= false
  local message = automationTraceMessage(reason, opts)

  if includeAttack then
    boop.runtime.clearAttackIntent(reason, { suppressTrace = true })
  end

  if includeWalk then
    local walkOwner = "walk:" .. tostring(tonumber(state.walk.generation) or 0)
    killOwnedTimer(state.walk.refreshTimer)
    killOwnedTimer(state.walk.emitterTimer)
    state.walk.generation = (tonumber(state.walk.generation) or 0) + 1
    state.walk.active = false
    state.walk.owned = false
    state.walk.roomSettled = false
    state.walk.moveQueued = false
    state.walk.arrivalRoom = ""
    state.walk.roomGeneration = 0
    state.walk.moveIssuedForRoomGeneration = false
    state.walk.reservationId = tonumber(state.walk.reservationId) or 0
    state.walk.refreshTimer = nil
    state.walk.emitterTimer = nil
    state.walk.refreshWarned = false
    boop.runtime.clearBlocker(walkOwner, tostring(reason or "automation clear"))
  end

  if includeGold then
    local operation = state.gold.operation
    if type(operation) == "table" then
      operation.terminal = true
      killOwnedTimer(operation.flushTimer)
      killOwnedTimer(operation.timeoutTimer)
      boop.runtime.clearBlocker(
        operation.blockerOwner,
        tostring(reason or "automation clear")
      )
    end
    killOwnedTimer(state.gold.autoGrabTimer)
    killOwnedTimer(state.gold.pendingTimer)
    state.gold.operation = false
    state.gold.dropped = false
    state.gold.shardsDropped = false
    state.gold.autoGrabPending = false
    state.gold.autoGrabPendingAt = nil
    state.gold.autoGrabTimer = nil
    state.gold.getPending = false
    state.gold.putPending = false
    state.gold.getRetries = 0
    state.gold.putRetries = 0
    state.gold.packTarget = ""
    state.gold.pendingTimer = nil
  end

  trace(message)
  return true
end

local function currentClass(state)
  local gmcpClass = gmcp and gmcp.Char and gmcp.Char.Status and gmcp.Char.Status.class or ""
  local class = boop.util and boop.util.safeLower and boop.util.safeLower(gmcpClass or "") or tostring(gmcpClass or ""):lower()
  if class ~= "" then
    return class
  end
  local fallback = state.combat.class or ""
  if boop.util and boop.util.safeLower then
    return boop.util.safeLower(fallback)
  end
  return tostring(fallback):lower()
end

local function currentSpec(state)
  local raw = state.combat.spec or ""
  if boop.util and boop.util.trim then
    return boop.util.trim(raw)
  end
  return tostring(raw or "")
end

local function currentRoom()
  local info = gmcp and gmcp.Room and gmcp.Room.Info or {}
  return {
    area = tostring(info.area or "UNKNOWN"),
    id = tostring(info.num or ""),
    exits = info.exits or {},
  }
end

function boop.runtime.context()
  local state = boop.runtime.ensureState()
  local room = currentRoom()
  local targetInfo = gmcp and gmcp.IRE and gmcp.IRE.Target and gmcp.IRE.Target.Info or {}
  local currentTargetId = tostring(state.targeting.currentTargetId or "")
  local targetInfoId = tostring(targetInfo.id or "")
  local hpperc = ""
  if targetInfo.hpperc ~= nil then
    if currentTargetId == "" then
      hpperc = targetInfoId == "" and tostring(targetInfo.hpperc or "") or ""
    elseif targetInfoId == currentTargetId then
      hpperc = tostring(targetInfo.hpperc or "")
    end
  end
  local rageAmount = 0
  if gmcp and gmcp.Char and gmcp.Char.Vitals and gmcp.Char.Vitals.charstats then
    for _, stat in ipairs(gmcp.Char.Vitals.charstats) do
      local name, val = tostring(stat or ""):match("^(%w+):%s*(%d+)")
      if name == "Rage" then
        rageAmount = tonumber(val) or 0
        break
      end
    end
  end
  local assistLeader = boop.util and boop.util.trim and boop.util.trim((boop.config and boop.config.assistLeader) or "") or tostring((boop.config and boop.config.assistLeader) or "")

  return {
    state = state,
    config = boop.config or {},
    gmcp = gmcp,
    class = currentClass(state),
    spec = currentSpec(state),
    room = room,
    target = {
      id = currentTargetId,
      infoId = targetInfoId,
      name = tostring(state.targeting.targetName or ""),
      shield = state.targeting.targetShield,
      hpperc = tostring(hpperc or ""),
    },
    denizens = state.targeting.denizens or {},
    queue = {
      prequeuedStandard = not not state.queue.prequeuedStandard,
      balanceReadyAt = state.queue.balanceReadyAt,
      equilibriumReadyAt = state.queue.equilibriumReadyAt,
      aliasAction = tostring(state.queue.aliasAction or ""),
      aliasDirty = state.queue.aliasDirty ~= false,
    },
    walk = {
      active = not not state.walk.active,
      owned = not not state.walk.owned,
      roomSettled = not not state.walk.roomSettled,
      moveQueued = not not state.walk.moveQueued,
      arrivalRoom = tostring(state.walk.arrivalRoom or ""),
      generation = tonumber(state.walk.generation) or 0,
      roomGeneration = tonumber(state.walk.roomGeneration) or 0,
      moveIssuedForRoomGeneration =
        not not state.walk.moveIssuedForRoomGeneration,
      reservationId = tonumber(state.walk.reservationId) or 0,
      refreshTimer = state.walk.refreshTimer,
      emitterTimer = state.walk.emitterTimer,
      refreshWarned = not not state.walk.refreshWarned,
    },
    gold = {
      generation = tonumber(state.gold.generation) or 0,
      operation = deepCopy(state.gold.operation),
      autoGrabPending = not not state.gold.autoGrabPending,
      getPending = not not state.gold.getPending,
      putPending = not not state.gold.putPending,
      packTarget = tostring(state.gold.packTarget or ""),
    },
    diag = {
      hold = not not state.diag.hold,
      awaitPrompt = not not state.diag.awaitPrompt,
      label = tostring(state.diag.label or ""),
    },
    assist = {
      enabled = not not ((boop.config and boop.config.assistEnabled) and assistLeader ~= ""),
      leader = assistLeader,
    },
    inventory = {
      wieldedLeft = state.inventory.wieldedLeft,
      wieldedRight = state.inventory.wieldedRight,
    },
    rage = {
      amount = rageAmount,
      ready = state.rage.ready or {},
      timers = state.rage.timers or {},
      samples = state.rage.samples or {},
    },
    blocker = boop.runtime.blockerSnapshot(),
  }
end

local function heldEffect(context, system, detail)
  local blocker = context.blocker or boop.runtime.blockerSnapshot()
  return {
    kind = "trace",
    message = string.format(
      "%s held: %s -- %s",
      tostring(detail or system or "automation"),
      tostring(blocker.code or ""),
      tostring(blocker.label or "")
    ),
  }
end

local function tickStep(context)
  local state = context.state
  local effects = {}

  if not (context.config and context.config.enabled) then
    return { effects = effects, didAction = false }
  end
  if state.diag.hold then
    return { effects = effects, didAction = false }
  end

  local goldOperation = state.gold.operation
  if type(goldOperation) == "table" and not goldOperation.terminal then
    if boop.safety and boop.safety.shouldFlee and boop.safety.shouldFlee() then
      effects[#effects + 1] = { kind = "flee" }
      return { effects = effects, didAction = false }
    end
    local owner = tostring(goldOperation.blockerOwner or "")
    if boop.runtime.shouldHold("combat", owner)
      or boop.runtime.shouldHold("queue", owner)
      or boop.runtime.shouldHold("gold", owner)
      or boop.runtime.shouldHold("walk", owner)
    then
      effects[#effects + 1] = heldEffect(context, "gold", "gold")
      return { effects = effects, didAction = false }
    end
    if not goldOperation.timeoutTimer then
      effects[#effects + 1] = { kind = "flush_gold", reason = "tick gold stage" }
    end
    return { effects = effects, didAction = false }
  end

  if boop.runtime.shouldHold("target")
    or boop.runtime.shouldHold("combat")
    or boop.runtime.shouldHold("queue")
    or boop.runtime.shouldHold("gold")
    or boop.runtime.shouldHold("walk")
  then
    effects[#effects + 1] = heldEffect(context, "automation", "tick")
    return { effects = effects, didAction = false }
  end
  if boop.maybeFlushPendingGold and boop.maybeFlushPendingGold("tick pending age") then
    return { effects = effects, didAction = false }
  end
  if state.gold.getPending or state.gold.putPending then
    return { effects = effects, didAction = false }
  end

  if boop.safety and boop.safety.shouldFlee and boop.safety.shouldFlee() then
    effects[#effects + 1] = { kind = "flee" }
    return { effects = effects, didAction = false }
  end

  local targetId = boop.targets and boop.targets.choose and boop.targets.choose() or ""
  if not targetId or targetId == "" then
    if context.config.useQueueing and state.gold.autoGrabPending then
      effects[#effects + 1] = { kind = "flush_gold", reason = "tick no target" }
    end
    if boop.targets and boop.targets.waitingForTargetCall and boop.targets.waitingForTargetCall() then
      effects[#effects + 1] = { kind = "trace", message = "tick: waiting for leader target call" }
      return { effects = effects, didAction = false }
    end
    effects[#effects + 1] = { kind = "trace", message = "tick: no target" }
    effects[#effects + 1] = { kind = "walk_advance", reason = "tick no target" }
    return { effects = effects, didAction = false }
  end

  if tostring(state.targeting.currentTargetId or "") ~= tostring(targetId) then
    effects[#effects + 1] = { kind = "target", id = tostring(targetId) }
  end

  local planContext = context
  if tostring(context.target.id or "") ~= tostring(targetId) then
    local nextTargetName = ""
    for _, denizen in ipairs(context.denizens or {}) do
      if tostring(denizen.id or "") == tostring(targetId) then
        nextTargetName = tostring(denizen.name or "")
        break
      end
    end
    planContext = {
      state = context.state,
      config = context.config,
      gmcp = context.gmcp,
      class = context.class,
      spec = context.spec,
      room = context.room,
      denizens = context.denizens,
      queue = context.queue,
      gold = context.gold,
      diag = context.diag,
      assist = context.assist,
      inventory = context.inventory,
      rage = context.rage,
      blocker = context.blocker,
      target = {
        id = tostring(targetId),
        name = nextTargetName,
        shield = false,
        hpperc = "",
      },
    }
  end

  local plan = boop.attacks and boop.attacks.choose and boop.attacks.choose(planContext) or { standard = "", rage = "" }
  if (plan.standard and plan.standard ~= "") or (plan.rage and plan.rage ~= "") then
    effects[#effects + 1] = { kind = "combat_plan", plan = plan, context = planContext }
  end

  return {
    effects = effects,
    didAction = not not ((plan.standard and plan.standard ~= "") or (plan.rage and plan.rage ~= "")),
  }
end

local function promptStep(context)
  local state = context.state
  local effects = {}
  local runTick = true

  local evidenceHead = state.diag.evidenceQueue and state.diag.evidenceQueue[1] or nil
  local operation = state.diag.operation
  if type(evidenceHead) == "table" then
    if evidenceHead.resultSeen then
      local _, completed = boop.runtime.consumeOldestDiagEvidencePrompt()
      runTick = completed
    elseif type(operation) == "table" and not operation.terminal then
      runTick = false
    end
  elseif type(operation) == "table" and not operation.terminal then
    if operation.completionMode == "prompt" then
      runTick = boop.runtime.completeInterrupt(
        operation.generation,
        "prompt_complete"
      )
    else
      runTick = false
    end
  elseif state.diag.hold then
    runTick = false
  end

  effects[#effects + 1] = { kind = "gag_prompt" }
  return { effects = effects, didAction = false, runTick = runTick }
end

function boop.runtime.step(event)
  local data = event or {}
  local context = data.context or boop.runtime.context()
  local kind = tostring(data.type or "tick")
  if kind == "prompt" then
    return promptStep(context)
  end
  return tickStep(context)
end

function boop.runtime.applyEffects(result, context)
  local state = (context and context.state) or boop.runtime.ensureState()
  local didAction = false

  for _, effect in ipairs((result and result.effects) or {}) do
    if effect.kind == "trace" then
      if boop.trace and boop.trace.log then
        boop.trace.log(effect.message or "")
      end
    elseif effect.kind == "flush_gold" then
      if boop.flushPendingGold then
        boop.flushPendingGold(effect.reason or "runtime")
      end
    elseif effect.kind == "walk_advance" then
      if boop.walk and boop.walk.maybeAdvance then
        boop.walk.maybeAdvance(effect.reason or "runtime")
      end
    elseif effect.kind == "flee" then
      if boop.safety and boop.safety.flee then
        boop.safety.flee()
      end
    elseif effect.kind == "target" then
      if boop.targets and boop.targets.setTarget then
        boop.targets.setTarget(effect.id)
      end
    elseif effect.kind == "combat_plan" then
      if boop.attacks and boop.attacks.execute then
        if boop.attacks.execute(effect.plan, effect.context or context) then
          didAction = true
        end
      end
    elseif effect.kind == "gag_prompt" then
      if boop.gag and boop.gag.onPrompt then
        boop.gag.onPrompt()
      end
    end
  end

  return didAction
end
