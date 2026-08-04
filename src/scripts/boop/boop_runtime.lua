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
    operationModelVersion = 1,
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
    temporaryAttackPreferences = {},
  },
  lifecycle = {
    connectionGeneration = 0,
    promptSeen = false,
    ireSeen = false,
    ready = false,
    source = "",
    lastRetryAt = nil,
    lastWarningAt = nil,
    lastWarningCode = "",
    warningThrottleSeconds = 2,
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
      lastCompletedFence = false,
      nextApplicationId = 1,
      activeApplication = false,
      acceptedSourceAuthority = false,
      refreshAttempted = false,
      refreshReason = "",
      refreshTimeoutTimer = false,
      warned = false,
    },
    movementIntent = {
      generation = 0,
      active = false,
      direction = "",
      originRoomId = "",
      originObservationGeneration = 0,
      sentAt = nil,
      candidateItems = false,
      candidateAt = nil,
      candidateFenceId = false,
      candidateStatus = "",
      lastReason = "",
    },
  },
  gold = {
    generation = 0,
    operation = false,
    packQuarantineGeneration = 0,
    packQuarantine = false,
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
    prequeueSourceAuthority = false,
    aliasAction = "",
    aliasDirty = true,
    outboundSequence = 0,
    outboundExpectations = {},
    outboundObserved = {},
    outboundDispatchGeneration = 0,
    outboundDispatches = {},
    standardGeneration = 0,
    standardDispatchId = 0,
    standardOperation = false,
    lastStandardTerminal = false,
    standardRecovery = false,
    promptSequence = 0,
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
    venomConfusionCount = 0,
  },
  trace = {
    buffer = {},
    live = false,
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
    generation = 0,
    completeItems = {},
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

local OPERATION_MODEL_VERSION = 1

local function isOperationOwner(owner)
  local value = tostring(owner or "")
  return value:match("^interrupt:.+") ~= nil
    or value:match("^pull:.+") ~= nil
    or value:match("^gold:.+") ~= nil
end

function boop.runtime.ensureState()
  boop.state = boop.state or {}
  local state = boop.state
  local previousCombat = rawget(state, "combat")
  local migrateOperationModel = type(previousCombat) == "table"
    and tonumber(rawget(previousCombat, "operationModelVersion"))
      ~= OPERATION_MODEL_VERSION

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

  state.combat.blockersByOwner =
    type(state.combat.blockersByOwner) == "table"
      and state.combat.blockersByOwner
      or {}
  if migrateOperationModel then
    for owner in pairs(state.combat.blockersByOwner) do
      if not isOperationOwner(owner) then
        state.combat.blockersByOwner[owner] = nil
      end
    end
  end
  state.combat.operationModelVersion = OPERATION_MODEL_VERSION
  state.combat.operationLocksByOwner = state.combat.blockersByOwner
  state.combat.operationLock =
    type(state.combat.operationLock) == "table"
      and state.combat.operationLock
      or deepCopy(DOMAIN_DEFAULTS.combat.blocker)
  return state
end

function boop.runtime.state()
  return boop.runtime.ensureState()
end

local function lifecycleState()
  local lifecycle = boop.runtime.ensureState().lifecycle
  lifecycle.connectionGeneration =
    tonumber(lifecycle.connectionGeneration) or 0
  lifecycle.promptSeen = not not lifecycle.promptSeen
  lifecycle.ireSeen = not not lifecycle.ireSeen
  lifecycle.ready = lifecycle.promptSeen and lifecycle.ireSeen
  lifecycle.source = tostring(lifecycle.source or "")
  lifecycle.warningThrottleSeconds =
    tonumber(lifecycle.warningThrottleSeconds) or 2
  lifecycle.lastWarningCode =
    tostring(lifecycle.lastWarningCode or "")
  return lifecycle
end

function boop.runtime.beginConnectionLifecycle(source)
  if boop.runtime.resolvePackQuarantine then
    boop.runtime.resolvePackQuarantine("connection")
  end
  local state = boop.runtime.ensureState()
  state.targeting.movementIntent =
    deepCopy(DOMAIN_DEFAULTS.targeting.movementIntent)
  local lifecycle = lifecycleState()
  lifecycle.connectionGeneration = lifecycle.connectionGeneration + 1
  lifecycle.promptSeen = false
  lifecycle.ireSeen = false
  lifecycle.ready = false
  lifecycle.source = tostring(source or "connection")
  lifecycle.lastRetryAt = nil
  lifecycle.lastWarningAt = nil
  lifecycle.lastWarningCode = ""
  return boop.runtime.lifecycleSnapshot()
end

function boop.runtime.observeLifecycleIre(available, source)
  local lifecycle = lifecycleState()
  lifecycle.ireSeen = available == true
  lifecycle.ready = lifecycle.promptSeen and lifecycle.ireSeen
  lifecycle.source = tostring(source or "ire")
  return boop.runtime.lifecycleSnapshot()
end

function boop.runtime.observeLifecyclePrompt(source)
  local lifecycle = lifecycleState()
  lifecycle.promptSeen = true
  lifecycle.ready = lifecycle.promptSeen and lifecycle.ireSeen
  lifecycle.source = tostring(source or "prompt")
  return boop.runtime.lifecycleSnapshot()
end

function boop.runtime.lifecycleSnapshot()
  local lifecycle = lifecycleState()
  return {
    connectionGeneration = lifecycle.connectionGeneration,
    promptSeen = lifecycle.promptSeen,
    ireSeen = lifecycle.ireSeen,
    ready = lifecycle.ready,
    source = lifecycle.source,
    lastRetryAt = lifecycle.lastRetryAt,
    lastWarningAt = lifecycle.lastWarningAt,
    lastWarningCode = lifecycle.lastWarningCode,
    warningThrottleSeconds = lifecycle.warningThrottleSeconds,
  }
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
  observation.lastCompletedFence =
    type(observation.lastCompletedFence) == "table"
      and observation.lastCompletedFence
      or false
  observation.nextApplicationId =
    math.max(1, tonumber(observation.nextApplicationId) or 1)
  observation.activeApplication =
    type(observation.activeApplication) == "table"
      and observation.activeApplication
      or false
  observation.acceptedSourceAuthority =
    type(observation.acceptedSourceAuthority) == "table"
      and observation.acceptedSourceAuthority
      or false
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
  if boundary == "fresh_start" then
    local previousIntent = state.targeting.movementIntent
    local intentGeneration = type(previousIntent) == "table"
        and tonumber(previousIntent.generation)
      or 0
    state.targeting.movementIntent =
      deepCopy(DOMAIN_DEFAULTS.targeting.movementIntent)
    state.targeting.movementIntent.generation = intentGeneration or 0
    state.targeting.movementIntent.lastReason =
      tostring(opts.reason or "fresh room observation")
  end
  local previous = roomObservationState()
  local generation = tonumber(previous.generation) or 0
  local normalizedRoomId = normalizeRoomId(roomId)
  local fences = previous.fenceQueue
  for _, fence in ipairs(fences) do
    fence.valid = false
  end
  local application = previous.activeApplication
  if type(application) == "table" then
    application.valid = false
    application.invalidReason = tostring(
      opts.reason or "room observation invalidated"
    )
    if application.pendingTimer and killTimer then
      killTimer(application.pendingTimer)
    end
    application.pendingTimer = false
  end
  if previous.refreshTimeoutTimer and killTimer then
    killTimer(previous.refreshTimeoutTimer)
  end
  state.targeting.roomObservation = {
    generation = generation + 1,
    roomId = normalizedRoomId,
    infoSeen = normalizedRoomId ~= "" and opts.infoSeen ~= false,
    itemsSeen = false,
    acceptedItems = {},
    fenceQueue = fences,
    activeFenceId = false,
    nextFenceId = previous.nextFenceId,
    lastCompletedFence = false,
    nextApplicationId = previous.nextApplicationId,
    activeApplication = false,
    acceptedSourceAuthority = false,
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

local function currentRoomId()
  return normalizeRoomId(
    gmcp
      and gmcp.Room
      and gmcp.Room.Info
      and gmcp.Room.Info.num
      or ""
  )
end

local MOVEMENT_INTENT_TTL_SECONDS = 2
local MOVEMENT_CANDIDATE_TTL_SECONDS = 1

local function movementClock()
  if getEpoch then
    return tonumber(getEpoch()) or os.clock()
  end
  return os.clock()
end

local function movementIntentState()
  local state = boop.runtime.ensureState()
  local intent = state.targeting.movementIntent
  if type(intent) ~= "table" then
    intent = deepCopy(DOMAIN_DEFAULTS.targeting.movementIntent)
    state.targeting.movementIntent = intent
  end
  intent.generation = tonumber(intent.generation) or 0
  intent.active = not not intent.active
  intent.direction = tostring(intent.direction or "")
  intent.originRoomId = normalizeRoomId(intent.originRoomId)
  intent.originObservationGeneration =
    tonumber(intent.originObservationGeneration) or 0
  intent.sentAt = tonumber(intent.sentAt)
  intent.candidateItems = type(intent.candidateItems) == "table"
    and intent.candidateItems
    or false
  intent.candidateAt = tonumber(intent.candidateAt)
  intent.candidateFenceId = intent.candidateFenceId or false
  intent.candidateStatus = tostring(intent.candidateStatus or "")
  intent.lastReason = tostring(intent.lastReason or "")
  return intent
end

local function resetMovementIntent(intent, reason)
  intent.active = false
  intent.direction = ""
  intent.originRoomId = ""
  intent.originObservationGeneration = 0
  intent.sentAt = nil
  intent.candidateItems = false
  intent.candidateAt = nil
  intent.candidateFenceId = false
  intent.candidateStatus = ""
  intent.lastReason = tostring(reason or "cleared")
end

local function movementIntentExpired(intent, now)
  local sentAt = tonumber(intent.sentAt)
  local elapsed = sentAt and (now - sentAt) or nil
  return not elapsed
    or elapsed < 0
    or elapsed > MOVEMENT_INTENT_TTL_SECONDS
end

function boop.runtime.movementIntentSnapshot()
  local intent = movementIntentState()
  return {
    generation = intent.generation,
    active = intent.active,
    direction = intent.direction,
    originRoomId = intent.originRoomId,
    originObservationGeneration =
      intent.originObservationGeneration,
    sentAt = intent.sentAt,
    candidateItems = deepCopy(intent.candidateItems),
    candidateAt = intent.candidateAt,
    candidateFenceId = intent.candidateFenceId,
    candidateStatus = intent.candidateStatus,
    lastReason = intent.lastReason,
  }
end

local function currentObservationFence(observation, roomId)
  local fence = observation.fenceQueue[1]
  return type(fence) == "table"
    and fence.valid ~= false
    and tonumber(fence.fenceId)
      == tonumber(observation.activeFenceId)
    and normalizeRoomId(fence.roomId) == roomId
    and tonumber(fence.generation)
      == tonumber(observation.generation)
    and fence.roomOnly ~= true
end

function boop.runtime.noteMovementIntent(direction)
  local normalizedDirection = tostring(direction or "")
    :lower()
    :match("^%s*(.-)%s*$")
  local observation = roomObservationState()
  local originRoomId = currentRoomId()
  local authority = observation.acceptedSourceAuthority
  local settledOrigin = observation.itemsSeen
    and type(authority) == "table"
    and normalizeRoomId(authority.roomId) == originRoomId
    and tonumber(authority.observationGeneration)
      == tonumber(observation.generation)
    and boop.runtime.validateRoomSourceAuthority
    and boop.runtime.validateRoomSourceAuthority(authority)
  local fencedOrigin = not observation.itemsSeen
    and currentObservationFence(observation, originRoomId)
  if normalizedDirection == ""
      or originRoomId == ""
      or observation.roomId ~= originRoomId
      or not observation.infoSeen
      or not (settledOrigin or fencedOrigin) then
    return false
  end

  local intent = movementIntentState()
  local now = movementClock()
  if intent.active and not movementIntentExpired(intent, now) then
    resetMovementIntent(intent, "overlapping movement commands")
    return false
  end
  if intent.active then
    resetMovementIntent(intent, "expired movement replaced")
  end
  intent.generation = intent.generation + 1
  intent.active = true
  intent.direction = normalizedDirection
  intent.originRoomId = originRoomId
  intent.originObservationGeneration = observation.generation
  intent.sentAt = now
  intent.candidateItems = false
  intent.candidateAt = nil
  intent.candidateFenceId = false
  intent.candidateStatus = ""
  intent.lastReason = "movement command observed"
  return boop.runtime.movementIntentSnapshot()
end

function boop.runtime.beginRoomResponseFence(reason, opts)
  opts = type(opts) == "table" and opts or {}
  local observation = roomObservationState()
  local roomOnly = opts.roomOnly == true
  if roomOnly then
    local expectedRoomId = normalizeRoomId(opts.roomId)
    local expectedGeneration = tonumber(opts.generation)
    if not observation.infoSeen
        or not observation.itemsSeen
        or observation.roomId == ""
        or observation.activeFenceId
        or expectedRoomId == ""
        or expectedRoomId ~= observation.roomId
        or expectedGeneration == nil
        or expectedGeneration ~= tonumber(observation.generation)
        or currentRoomId() ~= observation.roomId then
      return false
    end
  elseif not observation.infoSeen
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
    phase = roomOnly and "await_room" or "await_inv",
    valid = true,
    roomOnly = roomOnly,
    fenceType = roomOnly and "room_revalidation" or "observation",
    invSeen = false,
    roomSeen = false,
    invItems = false,
    roomItems = false,
    roomDeltas = {},
    completed = false,
    consumed = false,
    operationGeneration = roomOnly
      and tonumber(opts.operationGeneration)
      or false,
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
  local activeFence = false
  for _, fence in ipairs(observation.fenceQueue) do
    if tonumber(fence and fence.fenceId) == tonumber(fenceId) then
      activeFence = fence
      break
    end
  end
  if tonumber(observation.activeFenceId) ~= tonumber(fenceId)
      or type(activeFence) ~= "table"
      or (observation.itemsSeen and activeFence.roomOnly ~= true)
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

local function copySourceAuthority(authority)
  if type(authority) ~= "table" then
    return false
  end
  return {
    applicationId = tonumber(authority.applicationId),
    roomId = normalizeRoomId(authority.roomId),
    observationGeneration = tonumber(authority.observationGeneration),
  }
end

local function sourceAuthorityMatches(left, right)
  local leftCopy = copySourceAuthority(left)
  local rightCopy = copySourceAuthority(right)
  return leftCopy
    and rightCopy
    and leftCopy.applicationId ~= nil
    and leftCopy.roomId ~= ""
    and leftCopy.observationGeneration ~= nil
    and leftCopy.applicationId == rightCopy.applicationId
    and leftCopy.roomId == rightCopy.roomId
    and leftCopy.observationGeneration == rightCopy.observationGeneration
end

local function deepEqual(left, right, seen)
  if type(left) ~= type(right) then
    return false
  end
  if type(left) ~= "table" then
    return left == right
  end
  seen = seen or {}
  if seen[left] == right then
    return true
  end
  seen[left] = right
  for key, value in pairs(left) do
    if not deepEqual(value, right[key], seen) then
      return false
    end
  end
  for key in pairs(right) do
    if left[key] == nil then
      return false
    end
  end
  return true
end

local function movementBaselineCurrent(observation, intent, fenceId)
  local authority = observation.acceptedSourceAuthority
  local accepted = observation.itemsSeen
    and type(authority) == "table"
    and normalizeRoomId(authority.roomId) == intent.originRoomId
    and tonumber(authority.observationGeneration)
      == tonumber(intent.originObservationGeneration)

  local application = observation.activeApplication
  local applicationAuthority = type(application) == "table"
      and application.sourceAuthority
    or false
  local completedFence = observation.lastCompletedFence
  local pending = observation.itemsSeen
    and type(application) == "table"
    and application.valid ~= false
    and not application.claimed
    and not application.consumed
    and type(applicationAuthority) == "table"
    and normalizeRoomId(applicationAuthority.roomId)
      == intent.originRoomId
    and tonumber(applicationAuthority.observationGeneration)
      == tonumber(intent.originObservationGeneration)
    and type(completedFence) == "table"
    and tonumber(completedFence.fenceId) == tonumber(fenceId)
    and normalizeRoomId(completedFence.roomId) == intent.originRoomId
    and tonumber(completedFence.generation)
      == tonumber(intent.originObservationGeneration)
    and deepEqual(application.items, observation.acceptedItems)

  return accepted or pending
end

function boop.runtime.clearMovementIntent(reason)
  local intent = movementIntentState()
  resetMovementIntent(intent, reason)
  return boop.runtime.movementIntentSnapshot()
end

function boop.runtime.captureMovementRoomItems(items, response)
  if type(items) ~= "table" or type(response) ~= "table" then
    return false
  end
  local status = tostring(response.status or "")
  if status ~= "duplicate" and status ~= "orphan" then
    return false
  end

  local intent = movementIntentState()
  if not intent.active then
    return false
  end
  if status == "orphan"
      and type(intent.candidateItems) ~= "table" then
    return false
  end
  local now = movementClock()
  if movementIntentExpired(intent, now) then
    resetMovementIntent(intent, "movement intent expired")
    return false
  end

  local observation = roomObservationState()
  if currentRoomId() ~= intent.originRoomId
      or observation.roomId ~= intent.originRoomId
      or tonumber(observation.generation)
        ~= tonumber(intent.originObservationGeneration)
      or not observation.infoSeen
      or not observation.itemsSeen
      or observation.activeFenceId
      or #observation.fenceQueue > 0
      or not movementBaselineCurrent(
        observation,
        intent,
        response.fenceId or intent.candidateFenceId
      ) then
    return false
  end

  if deepEqual(items, observation.acceptedItems) then
    intent.candidateItems = false
    intent.candidateAt = nil
    intent.candidateFenceId = false
    intent.candidateStatus = ""
    intent.lastReason = "post-move list still matches origin"
    return false
  end

  intent.candidateItems = deepCopy(items)
  intent.candidateAt = now
  intent.candidateFenceId = response.fenceId
    or intent.candidateFenceId
    or false
  intent.candidateStatus = status
  intent.lastReason = "changed list retained pending Room.Info"
  return boop.runtime.movementIntentSnapshot()
end

function boop.runtime.consumeMovementRoomItems(destinationRoomId)
  local intent = movementIntentState()
  if not intent.active then
    return false
  end

  local destination = normalizeRoomId(destinationRoomId)
  local now = movementClock()
  local observation = roomObservationState()
  local candidateAt = tonumber(intent.candidateAt)
  local candidateElapsed = candidateAt and (now - candidateAt) or nil
  local valid = destination ~= ""
    and destination ~= intent.originRoomId
    and not movementIntentExpired(intent, now)
    and type(intent.candidateItems) == "table"
    and candidateElapsed ~= nil
    and candidateElapsed >= 0
    and candidateElapsed <= MOVEMENT_CANDIDATE_TTL_SECONDS
    and candidateAt >= (tonumber(intent.sentAt) or math.huge)
    and observation.roomId == intent.originRoomId
    and tonumber(observation.generation)
      == tonumber(intent.originObservationGeneration)
    and observation.infoSeen
    and observation.itemsSeen
    and not observation.activeFenceId
    and #observation.fenceQueue == 0
    and movementBaselineCurrent(
      observation,
      intent,
      intent.candidateFenceId
    )

  local result = valid and {
    intentGeneration = intent.generation,
    direction = intent.direction,
    originRoomId = intent.originRoomId,
    destinationRoomId = destination,
    originObservationGeneration =
      intent.originObservationGeneration,
    candidateItems = deepCopy(intent.candidateItems),
    candidateFenceId = intent.candidateFenceId,
    candidateStatus = intent.candidateStatus,
  } or false
  resetMovementIntent(
    intent,
    valid and "movement confirmed" or "movement confirmation rejected"
  )
  return result
end

local function roomItemId(item)
  if type(item) ~= "table" then
    return ""
  end
  return normalizeRoomId(item.id)
end

local function applyRoomItemDelta(items, kind, item)
  local out = type(items) == "table" and deepCopy(items) or {}
  local id = roomItemId(item)
  if id == "" then
    return out
  end

  if kind == "remove" then
    for index = #out, 1, -1 do
      if roomItemId(out[index]) == id then
        table.remove(out, index)
      end
    end
    return out
  end

  for index, existing in ipairs(out) do
    if roomItemId(existing) == id then
      local merged = deepCopy(existing)
      for key, value in pairs(item) do
        if merged[key] == nil then
          merged[key] = deepCopy(value)
        end
      end
      out[index] = merged
      return out
    end
  end
  out[#out + 1] = deepCopy(item)
  return out
end

local function applyRoomItemDeltas(items, deltas)
  local out = type(items) == "table" and deepCopy(items) or {}
  for _, delta in ipairs(deltas or {}) do
    local kind = tostring(delta and delta.kind or ""):lower()
    if kind == "add" or kind == "remove" then
      out = applyRoomItemDelta(out, kind, delta.item)
    end
  end
  return out
end

function boop.runtime.observeRoomItemDelta(kind, item)
  local normalizedKind = tostring(kind or ""):lower()
  local id = roomItemId(item)
  if (normalizedKind ~= "add" and normalizedKind ~= "remove")
      or id == "" then
    return { status = "ignored" }
  end

  local observation = roomObservationState()
  if not observation.infoSeen
      or observation.roomId == ""
      or currentRoomId() ~= observation.roomId then
    return { status = "stale" }
  end

  local delta = {
    kind = normalizedKind,
    item = deepCopy(item),
  }
  local fenceId = false
  for _, fence in ipairs(observation.fenceQueue) do
    if type(fence) == "table"
        and fence.valid
        and not fence.consumed
        and tonumber(fence.generation) == tonumber(observation.generation)
        and normalizeRoomId(fence.roomId) == observation.roomId then
      fence.roomDeltas = type(fence.roomDeltas) == "table"
        and fence.roomDeltas
        or {}
      fence.roomDeltas[#fence.roomDeltas + 1] = deepCopy(delta)
      fenceId = tonumber(fence.fenceId) or false
    end
  end

  local applicationId = false
  local application = observation.activeApplication
  local authority = type(application) == "table"
      and application.sourceAuthority
    or false
  if type(application) == "table"
      and application.valid
      and not application.claimed
      and not application.consumed
      and type(authority) == "table"
      and tonumber(authority.observationGeneration)
        == tonumber(observation.generation)
      and normalizeRoomId(authority.roomId) == observation.roomId then
    application.items = applyRoomItemDelta(
      application.items,
      normalizedKind,
      item
    )
    observation.acceptedItems = deepCopy(application.items)
    applicationId = tonumber(application.applicationId) or false
  end

  if not fenceId and not applicationId then
    return { status = "ignored" }
  end
  return {
    status = "recorded",
    kind = normalizedKind,
    itemId = id,
    roomId = observation.roomId,
    observationGeneration = observation.generation,
    fenceId = fenceId,
    applicationId = applicationId,
  }
end

local function createRoomApplication(observation, fence, items)
  local previous = observation.activeApplication
  if type(previous) == "table" then
    previous.valid = false
    previous.invalidReason = "superseded room application"
    if previous.pendingTimer and killTimer then
      killTimer(previous.pendingTimer)
    end
    previous.pendingTimer = false
  end
  observation.acceptedSourceAuthority = false

  local applicationId = observation.nextApplicationId
  observation.nextApplicationId = applicationId + 1
  local authority = {
    applicationId = applicationId,
    roomId = observation.roomId,
    observationGeneration = observation.generation,
  }
  observation.activeApplication = {
    applicationId = applicationId,
    fenceId = tonumber(fence and fence.fenceId),
    sourceAuthority = copySourceAuthority(authority),
    items = deepCopy(items),
    pendingTimer = false,
    claimed = false,
    consumed = false,
    valid = true,
    invalidReason = "",
  }
  return observation.activeApplication
end

function boop.runtime.roomApplicationSnapshot(applicationId)
  local observation = roomObservationState()
  local application = observation.activeApplication
  if type(application) ~= "table"
      or (applicationId ~= nil
        and tonumber(application.applicationId) ~= tonumber(applicationId)) then
    return false
  end
  return {
    applicationId = tonumber(application.applicationId),
    fenceId = tonumber(application.fenceId),
    sourceAuthority = copySourceAuthority(application.sourceAuthority),
    items = deepCopy(application.items),
    pendingTimer = application.pendingTimer or false,
    claimed = not not application.claimed,
    consumed = not not application.consumed,
    valid = not not application.valid,
    invalidReason = tostring(application.invalidReason or ""),
  }
end

function boop.runtime.setRoomApplicationTimer(applicationId, timerId)
  local observation = roomObservationState()
  local application = observation.activeApplication
  if type(application) ~= "table"
      or tonumber(application.applicationId) ~= tonumber(applicationId)
      or not application.valid
      or application.consumed then
    return false
  end
  application.pendingTimer = timerId or false
  return true
end

function boop.runtime.invalidateRoomApplication(applicationId, reason)
  local observation = roomObservationState()
  local application = observation.activeApplication
  if type(application) ~= "table"
      or (applicationId ~= nil
        and tonumber(application.applicationId) ~= tonumber(applicationId)) then
    observation.acceptedSourceAuthority = false
    return false
  end
  application.valid = false
  application.invalidReason = tostring(reason or "invalidated")
  if application.pendingTimer and killTimer then
    killTimer(application.pendingTimer)
  end
  application.pendingTimer = false
  if sourceAuthorityMatches(
      observation.acceptedSourceAuthority,
      application.sourceAuthority
    ) then
    observation.acceptedSourceAuthority = false
  end
  return true
end

function boop.runtime.claimRoomApplication(
  applicationId,
  sourceAuthority,
  timerId
)
  local observation = roomObservationState()
  local application = observation.activeApplication
  if type(application) ~= "table"
      or tonumber(application.applicationId) ~= tonumber(applicationId)
      or not application.valid
      or application.claimed
      or application.consumed
      or not sourceAuthorityMatches(
        sourceAuthority,
        application.sourceAuthority
      )
      or (timerId ~= nil and application.pendingTimer ~= timerId)
      or not observation.infoSeen
      or not observation.itemsSeen
      or observation.roomId == ""
      or tonumber(observation.generation)
        ~= tonumber(sourceAuthority.observationGeneration)
      or observation.roomId ~= normalizeRoomId(sourceAuthority.roomId)
      or currentRoomId() ~= observation.roomId then
    return false
  end
  application.claimed = true
  application.consumed = true
  application.pendingTimer = false
  observation.acceptedSourceAuthority =
    copySourceAuthority(application.sourceAuthority)
  return boop.runtime.roomApplicationSnapshot(application.applicationId)
end

function boop.runtime.validateRoomSourceAuthority(sourceAuthority)
  local observation = roomObservationState()
  local captured = copySourceAuthority(sourceAuthority)
  return captured
    and sourceAuthorityMatches(
      captured,
      observation.acceptedSourceAuthority
    )
    and observation.infoSeen
    and observation.itemsSeen
    and observation.roomId == captured.roomId
    and tonumber(observation.generation)
      == tonumber(captured.observationGeneration)
    and currentRoomId() == captured.roomId
    or false
end

function boop.runtime.currentRoomSourceAuthority()
  local observation = roomObservationState()
  local authority = copySourceAuthority(
    observation.acceptedSourceAuthority
  )
  if authority
      and boop.runtime.validateRoomSourceAuthority(authority) then
    return authority
  end
  return false
end

function boop.runtime.observeRoomItemsList(location, items)
  local observation = roomObservationState()
  local queue = observation.fenceQueue
  local fence = queue[1]
  local normalizedLocation = tostring(location or ""):lower()
  local copiedItems = type(items) == "table" and deepCopy(items) or false

  if normalizedLocation ~= "inv" and normalizedLocation ~= "room" then
    return {
      status = "ignored",
      fenceId = type(fence) == "table" and fence.fenceId or false,
      location = normalizedLocation,
    }
  end

  if type(fence) ~= "table" then
    local completed = observation.lastCompletedFence
    local completedItems = type(completed) == "table"
      and completed[normalizedLocation .. "Items"]
      or false
    if type(completed) == "table"
        and tonumber(completed.generation) == tonumber(observation.generation)
        and completedItems
        and copiedItems then
      completed.postCompletionDuplicates =
        type(completed.postCompletionDuplicates) == "table"
          and completed.postCompletionDuplicates
          or {}
      local duplicateKey = normalizedLocation .. "Seen"
      if not completed.postCompletionDuplicates[duplicateKey]
          or deepEqual(completedItems, copiedItems) then
        completed.postCompletionDuplicates[duplicateKey] = true
        return {
          status = "duplicate",
          fenceId = completed.fenceId,
          location = normalizedLocation,
          items = deepCopy(copiedItems),
        }
      end
    end
    if type(completed) == "table"
        and tonumber(completed.generation) == tonumber(observation.generation)
        and completedItems
        and copiedItems
        and deepEqual(completedItems, copiedItems) then
      return {
        status = "duplicate",
        fenceId = completed.fenceId,
        location = normalizedLocation,
        items = deepCopy(copiedItems),
      }
    end
    if normalizedLocation == "inv" and copiedItems then
      return {
        status = "inventory",
        location = normalizedLocation,
        items = copiedItems,
        inventoryItems = deepCopy(copiedItems),
      }
    end
    return {
      status = copiedItems and "orphan" or "rejected",
      location = normalizedLocation,
      items = copiedItems and deepCopy(copiedItems) or nil,
    }
  end

  if normalizedLocation == "inv" and fence.roomOnly then
    if not copiedItems then
      return {
        status = "rejected",
        fenceId = fence.fenceId,
        location = normalizedLocation,
      }
    end
    return {
      status = "inventory",
      fenceId = fence.fenceId,
      location = normalizedLocation,
      items = copiedItems,
      inventoryItems = deepCopy(copiedItems),
    }
  end

  if not copiedItems then
    return {
      status = "rejected",
      fenceId = fence.fenceId,
      location = normalizedLocation,
    }
  end

  local seenKey = normalizedLocation .. "Seen"
  local itemsKey = normalizedLocation .. "Items"
  if fence[seenKey] then
    return {
      status = "duplicate",
      fenceId = fence.fenceId,
      location = normalizedLocation,
      items = deepCopy(copiedItems),
    }
  end
  fence[seenKey] = true
  fence[itemsKey] = copiedItems
  if not fence.invSeen and not fence.roomOnly then
    fence.phase = "await_inv"
  elseif not fence.roomSeen then
    fence.phase = "await_room"
  else
    fence.phase = "complete"
  end

  local inventoryItems = normalizedLocation == "inv" and fence.valid
    and deepCopy(copiedItems)
    or false
  local complete = fence.roomSeen and (fence.roomOnly or fence.invSeen)
  if not complete then
    return {
      status = inventoryItems and "inventory"
        or (fence.valid and "latched" or "drained"),
      fenceId = fence.fenceId,
      location = normalizedLocation,
      items = inventoryItems or nil,
      inventoryItems = inventoryItems,
    }
  end

  fence.completed = true
  fence.consumed = true
  table.remove(queue, 1)
  if tonumber(observation.activeFenceId) == tonumber(fence.fenceId) then
    observation.activeFenceId = false
  end
  if observation.refreshTimeoutTimer and killTimer then
    killTimer(observation.refreshTimeoutTimer)
  end
  observation.refreshTimeoutTimer = false

  if not fence.valid
      or tonumber(fence.generation) ~= tonumber(observation.generation)
      or normalizeRoomId(fence.roomId) ~= observation.roomId
      or currentRoomId() ~= observation.roomId then
    return {
      status = "drained",
      fenceId = fence.fenceId,
      location = normalizedLocation,
    }
  end

  local acceptedItems = applyRoomItemDeltas(
    fence.roomItems,
    fence.roomDeltas
  )
  fence.roomItems = deepCopy(acceptedItems)
  observation.itemsSeen = true
  observation.acceptedItems = deepCopy(acceptedItems)
  observation.lastCompletedFence = deepCopy(fence)
  observation.lastCompletedFence.postCompletionDuplicates = {}
  local application = createRoomApplication(
    observation,
    fence,
    acceptedItems
  )
  return {
    status = "accepted",
    fenceId = fence.fenceId,
    generation = observation.generation,
    roomId = observation.roomId,
    items = deepCopy(acceptedItems),
    inventoryItems = inventoryItems,
    applicationId = application.applicationId,
    sourceAuthority = copySourceAuthority(application.sourceAuthority),
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
    lastCompletedFence = deepCopy(observation.lastCompletedFence),
    nextApplicationId = tonumber(observation.nextApplicationId) or 1,
    activeApplication = deepCopy(observation.activeApplication),
    acceptedSourceAuthority =
      copySourceAuthority(observation.acceptedSourceAuthority),
    refreshAttempted = not not observation.refreshAttempted,
    refreshReason = tostring(observation.refreshReason or ""),
    refreshTimeoutTimer = observation.refreshTimeoutTimer or false,
    warned = not not observation.warned,
  }
end

function boop.runtime.readinessSnapshot()
  local lifecycle = boop.runtime.lifecycleSnapshot()
  local observation = boop.runtime.roomObservationSnapshot()
  local authority = boop.runtime.currentRoomSourceAuthority()
  local roomReady = authority and true or false
  local roomCode = "ready"
  local roomLabel = "room ready"

  if observation.roomId == "" or observation.infoSeen ~= true then
    roomCode = "missing_room"
    roomLabel = "missing room state"
  elseif observation.itemsSeen ~= true or not roomReady then
    roomCode = "room_partial"
    roomLabel = "current room evidence is incomplete"
  end

  return {
    lifecycle = lifecycle,
    room = {
      ready = roomReady,
      code = roomCode,
      label = roomLabel,
      roomId = observation.roomId,
      generation = observation.generation,
      infoSeen = observation.infoSeen,
      itemsSeen = observation.itemsSeen,
      sourceAuthority = authority,
    },
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

local STANDARD_GRACE_SECONDS = 0.35
local PACK_QUARANTINE_GRACE_SECONDS = 0.35
local OUTBOUND_HISTORY_LIMIT = 64
local OUTBOUND_EXPECTATION_LIMIT = 16
local LEAP_DENIAL_LINE =
  "Both of your legs must be free and unhindered to do that."

local function packQuarantineState()
  local state = boop.runtime.ensureState()
  local quarantine = state.gold.packQuarantine
  if type(quarantine) ~= "table" then
    return false
  end
  quarantine.quarantineId = tonumber(quarantine.quarantineId) or 0
  quarantine.oldGeneration = tonumber(quarantine.oldGeneration) or 0
  quarantine.oldDispatchId = tonumber(quarantine.oldDispatchId) or 0
  quarantine.outboundSequence = tonumber(quarantine.outboundSequence) or 0
  quarantine.releaseInventoryGeneration =
    tonumber(quarantine.releaseInventoryGeneration) or 0
  quarantine.releasePromptSequence =
    tonumber(quarantine.releasePromptSequence) or 0
  quarantine.windowOpenPromptSequence =
    tonumber(quarantine.windowOpenPromptSequence) or false
  quarantine.windowClosePromptSequence =
    tonumber(quarantine.windowClosePromptSequence) or false
  quarantine.graceToken = tonumber(quarantine.graceToken) or 0
  quarantine.graceInventoryGeneration =
    tonumber(quarantine.graceInventoryGeneration) or false
  quarantine.requiredInventoryGeneration = math.max(
    1,
    tonumber(quarantine.requiredInventoryGeneration) or 1
  )
  quarantine.qualifyingInventoryGeneration =
    tonumber(quarantine.qualifyingInventoryGeneration) or false
  quarantine.windowClosed = not not quarantine.windowClosed
  quarantine.graceExpired = not not quarantine.graceExpired
  quarantine.inventoryHasSovereigns =
    not not quarantine.inventoryHasSovereigns
  quarantine.eligible = not not quarantine.eligible
  quarantine.consumed = not not quarantine.consumed
  quarantine.resolved = not not quarantine.resolved
  quarantine.resolutionReason = tostring(
    quarantine.resolutionReason or ""
  )
  quarantine.lateActivityCount =
    tonumber(quarantine.lateActivityCount) or 0
  return quarantine
end

local function activePackQuarantine()
  local quarantine = packQuarantineState()
  if not quarantine or quarantine.resolved or quarantine.consumed then
    return false
  end
  return quarantine
end

local function inventoryState()
  local inventory = boop.runtime.ensureState().inventory
  inventory.generation = tonumber(inventory.generation) or 0
  inventory.completeItems = type(inventory.completeItems) == "table"
      and inventory.completeItems
    or {}
  return inventory
end

function boop.runtime.packQuarantineSnapshot()
  local quarantine = packQuarantineState()
  return quarantine and deepCopy(quarantine) or false
end

function boop.runtime.createPackQuarantine(operation)
  if type(operation) ~= "table"
      or tostring(operation.phase or "") ~= "pack_pending"
      or operation.terminal then
    return false
  end
  local state = boop.runtime.ensureState()
  local previous = activePackQuarantine()
  if previous then
    if previous.graceTimer and killTimer then
      killTimer(previous.graceTimer)
    end
    previous.graceTimer = false
    previous.eligible = false
    previous.resolved = true
    previous.resolutionReason = "superseded"
  end
  state.gold.packQuarantineGeneration =
    (tonumber(state.gold.packQuarantineGeneration) or 0) + 1
  state.queue.promptSequence = tonumber(state.queue.promptSequence) or 0
  local inventory = inventoryState()
  local quarantine = {
    quarantineId = state.gold.packQuarantineGeneration,
    oldOwner = tostring(operation.blockerOwner or ""),
    oldGeneration = tonumber(operation.generation) or 0,
    oldDispatchId = tonumber(operation.dispatchId) or 0,
    oldDispatchProvenance = tostring(
      operation.dispatchProvenance or ""
    ),
    nativePut = tostring(operation.nativeCommand or ""),
    wireCommand = tostring(operation.wireCommand or ""),
    packTarget = tostring(operation.packTarget or ""),
    outboundSequence = tonumber(operation.outboundSequence) or 0,
    releaseInventoryGeneration = inventory.generation,
    releasePromptSequence = state.queue.promptSequence,
    windowOpenPromptSequence = false,
    windowClosePromptSequence = false,
    windowClosed = false,
    graceToken = 0,
    graceTimer = false,
    graceExpired = false,
    graceInventoryGeneration = false,
    requiredInventoryGeneration = inventory.generation + 1,
    qualifyingInventoryGeneration = false,
    inventoryHasSovereigns = false,
    eligible = false,
    consumed = false,
    resolved = false,
    resolutionReason = "",
    lateActivityCount = 0,
    lastLateActivity = "",
    lastLateOutboundSequence = false,
  }
  state.gold.packQuarantine = quarantine
  trace(string.format(
    "gold pack quarantine created: owner=%s | generation=%s | dispatch=%s | inventory=%s | outbound=%s",
    quarantine.oldOwner,
    tostring(quarantine.oldGeneration),
    tostring(quarantine.oldDispatchId),
    tostring(quarantine.releaseInventoryGeneration),
    tostring(quarantine.outboundSequence)
  ))
  return deepCopy(quarantine)
end

function boop.runtime.resolvePackQuarantine(reason)
  local quarantine = activePackQuarantine()
  if not quarantine then
    return false
  end
  if quarantine.graceTimer and killTimer then
    killTimer(quarantine.graceTimer)
  end
  quarantine.graceTimer = false
  quarantine.eligible = false
  quarantine.inventoryHasSovereigns = false
  quarantine.resolved = true
  quarantine.resolutionReason = tostring(reason or "resolved")
  trace(string.format(
    "gold pack quarantine resolved: owner=%s | generation=%s | reason=%s",
    quarantine.oldOwner,
    tostring(quarantine.oldGeneration),
    quarantine.resolutionReason
  ))
  return true
end

function boop.runtime.observePackQuarantinePrompt(ready)
  local state = boop.runtime.ensureState()
  state.queue.promptSequence =
    (tonumber(state.queue.promptSequence) or 0) + 1
  local sequence = state.queue.promptSequence
  local quarantine = activePackQuarantine()
  if not quarantine then
    return false
  end
  if not quarantine.windowOpenPromptSequence then
    if ready ~= true then
      return false
    end
    quarantine.windowOpenPromptSequence = sequence
    trace(string.format(
      "gold pack quarantine window opened: generation=%s | prompt=%s",
      tostring(quarantine.oldGeneration),
      tostring(sequence)
    ))
    return true
  end
  if quarantine.windowClosed then
    return false
  end

  quarantine.windowClosed = true
  quarantine.windowClosePromptSequence = sequence
  quarantine.graceToken = quarantine.graceToken + 1
  local expectedId = quarantine.quarantineId
  local expectedToken = quarantine.graceToken
  local timerId = false
  if tempTimer then
    timerId = tempTimer(PACK_QUARANTINE_GRACE_SECONDS, function()
      local active = activePackQuarantine()
      if not active
          or active.quarantineId ~= expectedId
          or active.graceToken ~= expectedToken
          or active.graceTimer ~= timerId then
        return
      end
      active.graceTimer = false
      active.graceExpired = true
      active.graceInventoryGeneration = inventoryState().generation
      active.requiredInventoryGeneration = math.max(
        active.requiredInventoryGeneration,
        active.graceInventoryGeneration + 1
      )
      trace(string.format(
        "gold pack quarantine grace expired: generation=%s | inventory=%s",
        tostring(active.oldGeneration),
        tostring(active.graceInventoryGeneration)
      ))
    end)
  end
  quarantine.graceTimer = timerId or false
  trace(string.format(
    "gold pack quarantine window closed: generation=%s | prompt=%s | grace=%s",
    tostring(quarantine.oldGeneration),
    tostring(sequence),
    tostring(quarantine.graceToken)
  ))
  return true
end

function boop.runtime.observeInventorySnapshot(items)
  local inventory = inventoryState()
  inventory.generation = inventory.generation + 1
  inventory.completeItems = deepCopy(
    type(items) == "table" and items or {}
  )
  return {
    generation = inventory.generation,
    items = deepCopy(inventory.completeItems),
  }
end

function boop.runtime.observePackQuarantineInventory(
  inventoryGeneration,
  hasSovereigns
)
  local quarantine = activePackQuarantine()
  local generation = tonumber(inventoryGeneration) or 0
  if not quarantine
      or not quarantine.windowClosed
      or not quarantine.graceExpired
      or generation <= quarantine.releaseInventoryGeneration
      or generation < quarantine.requiredInventoryGeneration then
    return false
  end
  quarantine.qualifyingInventoryGeneration = generation
  quarantine.inventoryHasSovereigns = hasSovereigns == true
  if not quarantine.inventoryHasSovereigns then
    quarantine.eligible = false
    quarantine.resolved = true
    quarantine.resolutionReason = "inventory_without_sovereigns"
    trace(string.format(
      "gold pack quarantine cleared by inventory: generation=%s | inventory=%s | sovereigns=no",
      tostring(quarantine.oldGeneration),
      tostring(generation)
    ))
    return true
  end
  quarantine.eligible = true
  trace(string.format(
    "gold pack quarantine eligible: generation=%s | inventory=%s | sovereigns=yes",
    tostring(quarantine.oldGeneration),
    tostring(generation)
  ))
  return true
end

function boop.runtime.notePackQuarantineActivity(kind, outboundSequence)
  local quarantine = activePackQuarantine()
  if not quarantine then
    return false
  end
  local activity = tostring(kind or "old pack activity")
  local sequence = tonumber(outboundSequence) or false
  trace(string.format(
    "gold pack quarantine old activity: owner=%s | generation=%s | dispatch=%s | activity=%s | outbound=%s | eligible=%s",
    quarantine.oldOwner,
    tostring(quarantine.oldGeneration),
    tostring(quarantine.oldDispatchId),
    activity,
    tostring(sequence or "none"),
    tostring(quarantine.eligible)
  ))
  if not quarantine.eligible then
    return false
  end
  quarantine.lateActivityCount = quarantine.lateActivityCount + 1
  quarantine.lastLateActivity = activity
  quarantine.lastLateOutboundSequence = sequence
  local inventory = inventoryState()
  quarantine.eligible = false
  quarantine.inventoryHasSovereigns = false
  quarantine.requiredInventoryGeneration = math.max(
    quarantine.requiredInventoryGeneration,
    inventory.generation + 1
  )
  return true
end

function boop.runtime.consumePackQuarantine(
  oldGeneration,
  inventoryGeneration,
  reason
)
  local quarantine = activePackQuarantine()
  if not quarantine
      or not quarantine.eligible
      or tonumber(oldGeneration) ~= quarantine.oldGeneration
      or tonumber(inventoryGeneration)
        ~= quarantine.qualifyingInventoryGeneration
      or inventoryState().generation
        ~= quarantine.qualifyingInventoryGeneration then
    return false
  end
  quarantine.eligible = false
  quarantine.consumed = true
  quarantine.resolved = true
  quarantine.resolutionReason = tostring(reason or "consumed")
  trace(string.format(
    "gold pack quarantine consumed: generation=%s | inventory=%s | reason=%s",
    tostring(quarantine.oldGeneration),
    tostring(quarantine.qualifyingInventoryGeneration),
    quarantine.resolutionReason
  ))
  return deepCopy(quarantine)
end

local function standardQueueState()
  local queue = boop.runtime.ensureState().queue
  queue.outboundSequence = tonumber(queue.outboundSequence) or 0
  queue.outboundExpectations =
    type(queue.outboundExpectations) == "table"
      and queue.outboundExpectations
      or {}
  queue.outboundObserved = type(queue.outboundObserved) == "table"
      and queue.outboundObserved
    or {}
  queue.outboundDispatchGeneration =
    tonumber(queue.outboundDispatchGeneration) or 0
  queue.outboundDispatches = type(queue.outboundDispatches) == "table"
      and queue.outboundDispatches
    or {}
  queue.standardGeneration = tonumber(queue.standardGeneration) or 0
  queue.standardDispatchId = tonumber(queue.standardDispatchId) or 0
  queue.standardOperation = type(queue.standardOperation) == "table"
      and queue.standardOperation
    or false
  queue.lastStandardTerminal =
    type(queue.lastStandardTerminal) == "table"
      and queue.lastStandardTerminal
      or false
  queue.standardRecovery = type(queue.standardRecovery) == "table"
      and queue.standardRecovery
    or false
  return queue
end

local function activeStandard()
  local operation = standardQueueState().standardOperation
  if type(operation) ~= "table" or operation.terminal then
    return false
  end
  return operation
end

local function standardClock()
  if getEpoch then
    return tonumber(getEpoch()) or os.clock()
  end
  return os.clock()
end

local function sameStandardIdentity(operation, identity)
  return type(operation) == "table"
    and type(identity) == "table"
    and tostring(operation.owner or "") == tostring(identity.owner or "")
    and tonumber(operation.generation) == tonumber(identity.generation)
    and tostring(operation.dispatchId or "")
      == tostring(identity.dispatchId or "")
end

local function trimOutboundHistory(entries, limit)
  while #entries > limit do
    table.remove(entries, 1)
  end
end

function boop.runtime.standardPending()
  return activeStandard() and true or false
end

function boop.runtime.standardMutationBarrier()
  local operation = activeStandard()
  return type(operation) == "table"
    and operation.mode == "queued"
    and type(operation.baseline) == "table"
end

function boop.runtime.standardRecoveryPending()
  local recovery = standardQueueState().standardRecovery
  return type(recovery) == "table" and not recovery.retried
end

function boop.runtime.standardSnapshot()
  local operation = standardQueueState().standardOperation
  return type(operation) == "table" and deepCopy(operation) or false
end

function boop.runtime.lastStandardTerminalSnapshot()
  local terminal = standardQueueState().lastStandardTerminal
  return type(terminal) == "table" and deepCopy(terminal) or false
end

function boop.runtime.outboundSnapshot()
  local queue = standardQueueState()
  return {
    sequence = queue.outboundSequence,
    expectations = deepCopy(queue.outboundExpectations),
    observed = deepCopy(queue.outboundObserved),
    dispatches = deepCopy(queue.outboundDispatches),
  }
end

function boop.runtime.newOutboundRegistration(kind)
  local queue = standardQueueState()
  queue.outboundDispatchGeneration =
    queue.outboundDispatchGeneration + 1
  local generation = queue.outboundDispatchGeneration
  local semanticKind = tostring(kind or "dispatch")
  return {
    owner = semanticKind .. ":" .. tostring(generation),
    generation = generation,
    dispatchId = semanticKind .. ":" .. tostring(generation),
    kind = semanticKind,
  }
end

function boop.runtime.prepareLeapCausality(generation)
  local state = boop.runtime.ensureState()
  local operation = state.diag.operation
  local expectedGeneration = tonumber(generation)
  if type(operation) ~= "table"
      or operation.terminal
      or operation.name ~= "leap"
      or operation.completionMode ~= "room_change"
      or operation.generation ~= expectedGeneration then
    return false
  end

  local queue = standardQueueState()
  local observation = state.targeting.roomObservation or {}
  local owner = tostring(operation.blockerOwner or "")
  local command = tostring(operation.command or "")
  local registration = {
    owner = owner,
    generation = expectedGeneration,
    dispatchId = owner,
    kind = "leap",
  }
  operation.causal = {
    owner = registration.owner,
    generation = registration.generation,
    dispatchId = registration.dispatchId,
    kind = registration.kind,
    command = command,
    clearCommand = "clearqueue all",
    nativeCommand = "queue addclearfull freestand " .. command,
    roomId = tostring(operation.originRoomId or ""),
    roomGeneration = tonumber(observation.generation) or 0,
    registeredAfterSequence = queue.outboundSequence,
    timeoutToken = operation.timeoutTimer,
    observedWireCommands = {},
    baseline = false,
    windowOpen = false,
    contaminatedAt = false,
    contaminatedCommand = "",
    ambiguityTraced = false,
    terminal = false,
    terminalReason = nil,
  }
  trace(string.format(
    "leap causal registered: owner=%s | generation=%s | room=%s | roomGeneration=%s | outbound=%s | timeout=%s",
    owner,
    tostring(expectedGeneration or ""),
    tostring(operation.causal.roomId),
    tostring(operation.causal.roomGeneration),
    tostring(operation.causal.registeredAfterSequence),
    tostring(operation.causal.timeoutToken or "")
  ))
  return deepCopy(registration)
end

function boop.runtime.beginStandardDispatch(options)
  options = type(options) == "table" and options or {}
  if activeStandard() then
    return false
  end

  local queue = standardQueueState()
  local registration = type(options.outcomeRegistration) == "table"
      and options.outcomeRegistration
    or {}
  queue.standardGeneration = queue.standardGeneration + 1
  queue.standardDispatchId = queue.standardDispatchId + 1
  local generation = tonumber(registration.generation)
    or queue.standardGeneration
  if generation > queue.standardGeneration then
    queue.standardGeneration = generation
  end
  local dispatchId = tostring(
    registration.dispatchId
      or ("standard:" .. tostring(queue.standardDispatchId))
  )
  local owner = tostring(
    registration.owner or ("standard:" .. tostring(generation))
  )
  local mode = tostring(options.mode or "queued")
  local targetId = tostring(options.targetId or "")
  local operation = {
    owner = owner,
    generation = generation,
    dispatchId = dispatchId,
    kind = "standard",
    mode = mode,
    status = "dispatching",
    terminal = false,
    terminalReason = "",
    action = tostring(options.action or ""),
    targetId = targetId,
    sourceAuthority = copySourceAuthority(options.sourceAuthority),
    aliasBinding = tostring(options.aliasBinding or options.action or ""),
    baseline = false,
    expectedWireCommands = {},
    observedWireCommands = {},
    finalOwnedWireSequence = false,
    candidate = nil,
    promptCount = 0,
    firstReadyPrompt = false,
    graceStarted = false,
    graceToken = 0,
    graceTimer = false,
    obstacle = false,
    retryBudget = math.max(0, tonumber(options.retryBudget) or 1),
    quarantined = false,
    targetInvalid = false,
    targetInvalidReason = "",
    contaminatedAt = false,
    contaminatedCommand = "",
    clearSent = false,
    startedAt = standardClock(),
  }
  queue.standardOperation = operation
  queue.standardRecovery = false
  queue.prequeuedStandard = true
  queue.prequeueSourceAuthority =
    copySourceAuthority(operation.sourceAuthority)
  return {
    owner = owner,
    generation = generation,
    dispatchId = dispatchId,
    kind = "standard",
  }
end

function boop.runtime.completeStandardDispatch(identity, options)
  local operation = activeStandard()
  if not sameStandardIdentity(operation, identity) then
    return false
  end
  options = type(options) == "table" and options or {}
  operation.mode = tostring(options.mode or operation.mode or "queued")
  operation.aliasBinding = tostring(
    options.aliasBinding or operation.aliasBinding or operation.action or ""
  )
  if operation.status == "dispatching" then
    operation.status = "queued"
  end
  local queue = standardQueueState()
  queue.prequeuedStandard = true
  queue.prequeueSourceAuthority =
    copySourceAuthority(operation.sourceAuthority)
  return deepCopy(operation)
end

function boop.runtime.abortStandardDispatch(identity, reason)
  local operation = activeStandard()
  if not sameStandardIdentity(operation, identity) then
    return false
  end
  operation.status = "aborted"
  operation.terminal = true
  operation.terminalReason = tostring(reason or "dispatch aborted")
  operation.terminalAt = standardClock()
  local queue = standardQueueState()
  queue.prequeuedStandard = false
  queue.prequeueSourceAuthority = false
  queue.lastStandardTerminal = deepCopy(operation)
  return true
end

function boop.runtime.registerOutboundExpectation(registration, command, role)
  if type(registration) ~= "table" then
    return false
  end
  local wire = tostring(command or "")
  if wire == "" then
    return false
  end
  local queue = standardQueueState()
  local expectation = {
    command = wire,
    owner = tostring(registration.owner or ""),
    generation = tonumber(registration.generation),
    dispatchId = tostring(registration.dispatchId or ""),
    kind = tostring(registration.kind or "standard"),
    role = tostring(role or "wire"),
    registeredAfterSequence = queue.outboundSequence,
  }
  local dispatch = false
  for _, candidate in ipairs(queue.outboundDispatches) do
    if sameStandardIdentity(candidate, expectation) then
      dispatch = candidate
      break
    end
  end
  if not dispatch then
    dispatch = {
      owner = expectation.owner,
      generation = expectation.generation,
      dispatchId = expectation.dispatchId,
      kind = expectation.kind,
      expectedWireCommands = {},
      observedWireCommands = {},
      finalOwnedWireSequence = false,
    }
    queue.outboundDispatches[#queue.outboundDispatches + 1] = dispatch
    trimOutboundHistory(queue.outboundDispatches, 32)
  end
  dispatch.expectedWireCommands[#dispatch.expectedWireCommands + 1] = {
    command = wire,
  }
  queue.outboundExpectations[#queue.outboundExpectations + 1] = expectation
  trimOutboundHistory(
    queue.outboundExpectations,
    OUTBOUND_EXPECTATION_LIMIT
  )
  local operation = activeStandard()
  if operation and sameStandardIdentity(operation, expectation) then
    operation.expectedWireCommands[
      #operation.expectedWireCommands + 1
    ] = { command = wire }
  end
  return deepCopy(expectation)
end

function boop.runtime.observeOutbound(command)
  local wire = tostring(command or "")
  if wire == "" then
    return false
  end
  local queue = standardQueueState()
  queue.outboundSequence = queue.outboundSequence + 1
  local expectation = queue.outboundExpectations[1]
  local owned = type(expectation) == "table"
    and expectation.command == wire
  if owned then
    table.remove(queue.outboundExpectations, 1)
  elseif type(expectation) == "table" then
    queue.outboundExpectations = {}
  end
  local observed = {
    command = wire,
    sequence = queue.outboundSequence,
    owned = owned,
    owner = owned and expectation.owner or "manual",
    generation = owned and expectation.generation or false,
    dispatchId = owned and expectation.dispatchId or "",
    kind = owned and expectation.kind or "manual",
    role = owned and expectation.role or "manual",
  }
  queue.outboundObserved[#queue.outboundObserved + 1] = observed
  trimOutboundHistory(queue.outboundObserved, OUTBOUND_HISTORY_LIMIT)

  if owned then
    for _, dispatch in ipairs(queue.outboundDispatches) do
      if sameStandardIdentity(dispatch, expectation) then
        dispatch.observedWireCommands[
          #dispatch.observedWireCommands + 1
        ] = {
          command = wire,
          sequence = observed.sequence,
        }
        dispatch.finalOwnedWireSequence = observed.sequence
        break
      end
    end
  end

  local operation = activeStandard()
  if operation then
    if owned and sameStandardIdentity(operation, expectation) then
      operation.observedWireCommands[
        #operation.observedWireCommands + 1
      ] = {
        command = wire,
        sequence = observed.sequence,
      }
      operation.finalOwnedWireSequence = observed.sequence
      if expectation.role == "baseline"
          or expectation.role == "final" then
        operation.baseline = {
          command = wire,
          sequence = observed.sequence,
          owner = observed.owner,
          generation = observed.generation,
          dispatchId = observed.dispatchId,
        }
      end
    elseif type(operation.baseline) == "table"
        and observed.sequence > tonumber(operation.baseline.sequence or 0)
        and not operation.contaminatedAt then
      operation.contaminatedAt = observed.sequence
      operation.contaminatedCommand = wire
    end
  end

  local interrupt = boop.runtime.ensureState().diag.operation
  local causal = type(interrupt) == "table" and interrupt.causal or false
  if type(interrupt) == "table"
      and not interrupt.terminal
      and interrupt.name == "leap"
      and type(causal) == "table"
      and not causal.terminal then
    if owned and sameStandardIdentity(causal, expectation) then
      causal.observedWireCommands[#causal.observedWireCommands + 1] = {
        command = wire,
        sequence = observed.sequence,
        role = observed.role,
      }
      if expectation.role == "leap_baseline"
          and wire == causal.nativeCommand then
        causal.baseline = {
          command = wire,
          sequence = observed.sequence,
          owner = observed.owner,
          generation = observed.generation,
          dispatchId = observed.dispatchId,
        }
        causal.windowOpen = true
        trace(string.format(
          "leap causal window open: owner=%s | generation=%s | outbound=%s | room=%s | roomGeneration=%s",
          tostring(causal.owner or ""),
          tostring(causal.generation or ""),
          tostring(observed.sequence),
          tostring(causal.roomId or ""),
          tostring(causal.roomGeneration or "")
        ))
      end
    elseif causal.windowOpen
        and not observed.owned
        and observed.sequence > tonumber(
          type(causal.baseline) == "table"
            and causal.baseline.sequence
            or 0
        )
        and not causal.contaminatedAt then
      causal.contaminatedAt = observed.sequence
      causal.contaminatedCommand = wire
    end
  end
  return deepCopy(observed)
end

local function clearStandardExpectations(identity)
  local queue = standardQueueState()
  local retained = {}
  for _, expectation in ipairs(queue.outboundExpectations) do
    if not sameStandardIdentity(identity, expectation) then
      retained[#retained + 1] = expectation
    end
  end
  queue.outboundExpectations = retained
end

local function terminalizeStandard(operation, status, reason)
  local current = activeStandard()
  if not sameStandardIdentity(current, operation) then
    return false
  end
  if current.graceTimer and killTimer then
    killTimer(current.graceTimer)
  end
  current.graceTimer = false
  current.status = tostring(status or "expired")
  current.terminal = true
  current.terminalReason = tostring(reason or status or "terminal")
  current.terminalAt = standardClock()
  local queue = standardQueueState()
  queue.prequeuedStandard = false
  queue.prequeueSourceAuthority = false
  clearStandardExpectations(current)

  if current.status == "denied"
      and tostring(current.obstacle or "") ~= ""
      and current.obstacle ~= "target_absent" then
    queue.standardRecovery = {
      generation = current.generation,
      obstacle = current.obstacle,
      recovered = false,
      retried = false,
      retryBudget = current.retryBudget,
      operation = deepCopy(current),
    }
  else
    queue.standardRecovery = false
  end
  queue.lastStandardTerminal = deepCopy(current)
  trace(string.format(
    "standard terminal: %s | generation=%s | reason=%s",
    current.status,
    tostring(current.generation),
    current.terminalReason
  ))
  if current.quarantined
      and boop.onStandardLifecycleTerminal then
    boop.onStandardLifecycleTerminal(deepCopy(current))
  end
  return deepCopy(current)
end

function boop.runtime.bufferStandardCandidate(candidate)
  local operation = activeStandard()
  if not operation then
    return false
  end
  candidate = type(candidate) == "table" and candidate or {}
  local kind = tostring(candidate.kind or "")
  if kind ~= "success" and kind ~= "denial" then
    return false
  end
  local queue = standardQueueState()
  operation.candidate = {
    kind = kind,
    obstacle = tostring(candidate.obstacle or ""),
    line = tostring(candidate.line or ""),
    owner = operation.owner,
    generation = operation.generation,
    dispatchId = operation.dispatchId,
    targetId = operation.targetId,
    sourceAuthority = copySourceAuthority(operation.sourceAuthority),
    baselineSequence = type(operation.baseline) == "table"
        and tonumber(operation.baseline.sequence)
      or false,
    outboundSequence = queue.outboundSequence,
    observedAt = standardClock(),
  }
  return true
end

local function candidateIsCurrent(operation, candidate)
  if not sameStandardIdentity(operation, candidate)
      or tostring(candidate.targetId or "")
        ~= tostring(operation.targetId or "")
      or type(operation.baseline) ~= "table"
      or tonumber(candidate.baselineSequence)
        ~= tonumber(operation.baseline.sequence)
      or tonumber(candidate.outboundSequence or 0)
        < tonumber(operation.baseline.sequence or 0) then
    return false
  end
  if operation.contaminatedAt
      and tonumber(operation.contaminatedAt)
        <= tonumber(candidate.outboundSequence or 0) then
    return false
  end
  if operation.quarantined then
    return true
  end
  if operation.sourceAuthority then
    return boop.runtime.validateRoomSourceAuthority(
      operation.sourceAuthority
    )
  end
  return true
end

local function retryStandard(operation, reason)
  if type(operation) ~= "table"
      or tonumber(operation.retryBudget or 0) <= 0
      or not boop.retryStandardDispatch then
    return false
  end
  local retry = deepCopy(operation)
  retry.retryBudget = 0
  return boop.retryStandardDispatch(retry, reason) == true
end

local function startStandardGrace(operation)
  if operation.graceStarted then
    return false
  end
  operation.firstReadyPrompt = true
  operation.firstReadySequence = operation.promptCount
  operation.graceStarted = true
  operation.graceToken = (tonumber(operation.graceToken) or 0) + 1
  local generation = operation.generation
  local token = operation.graceToken
  if not tempTimer then
    local terminal = terminalizeStandard(
      operation,
      "expired",
      "ready prompt grace unavailable"
    )
    if terminal and not terminal.quarantined then
      retryStandard(terminal, "standard grace unavailable")
    end
    return true
  end
  local timerId = false
  timerId = tempTimer(STANDARD_GRACE_SECONDS, function()
    local current = activeStandard()
    if not current
        or tonumber(current.generation) ~= tonumber(generation)
        or tonumber(current.graceToken) ~= tonumber(token)
        or current.graceTimer ~= timerId then
      return false
    end
    current.graceTimer = false
    local terminal = terminalizeStandard(
      current,
      "expired",
      "ready prompt grace expired"
    )
    if terminal and not terminal.quarantined then
      retryStandard(terminal, "standard grace expired")
    end
    return true
  end)
  operation.graceTimer = timerId
  return true
end

function boop.runtime.reconcileStandardPrompt(ready)
  local operation = activeStandard()
  if operation then
    operation.promptCount = (tonumber(operation.promptCount) or 0) + 1
    local candidate = operation.candidate
    operation.candidate = nil
    if type(candidate) == "table"
        and candidateIsCurrent(operation, candidate) then
      candidate.promptSequence = operation.promptCount
      candidate.promptReady = ready == true
      operation.resultCandidate = deepCopy(candidate)
      operation.resultPrompt = {
        sequence = operation.promptCount,
        ready = ready == true,
      }
      if candidate.kind == "success" then
        return terminalizeStandard(
          operation,
          "executed",
          candidate.line ~= "" and candidate.line or "prompt-confirmed success"
        )
      end
      operation.obstacle = tostring(candidate.obstacle or "denied")
      return terminalizeStandard(
        operation,
        "denied",
        candidate.line ~= "" and candidate.line or operation.obstacle
      )
    end
    if type(candidate) == "table" then
      operation.lastAmbiguousCandidate = deepCopy(candidate)
      operation.lastAmbiguousPrompt = {
        sequence = operation.promptCount,
        ready = ready == true,
      }
      trace(string.format(
        "standard candidate ambiguous: generation=%s | kind=%s | line=%s",
        tostring(operation.generation),
        tostring(candidate.kind or ""),
        tostring(candidate.line or "")
      ))
    end
    if ready == true then
      startStandardGrace(operation)
    end
    return deepCopy(operation)
  end

  local recovery = standardQueueState().standardRecovery
  if ready == true
      and type(recovery) == "table"
      and recovery.recovered
      and not recovery.retried
      and tonumber(recovery.retryBudget or 0) > 0 then
    recovery.retried = true
    retryStandard(recovery.operation, "matching obstacle recovery")
    return true
  end
  return false
end

function boop.runtime.noteStandardRecovery(obstacle)
  local recovery = standardQueueState().standardRecovery
  local key = tostring(obstacle or "")
  if type(recovery) ~= "table"
      or recovery.retried
      or key == ""
      or tostring(recovery.obstacle or "") ~= key then
    return false
  end
  recovery.recovered = true
  recovery.recoveredAt = standardClock()
  return true
end

function boop.runtime.markStandardTargetInvalid(reason)
  local operation = activeStandard()
  if not operation then
    return false
  end
  operation.status = "target-invalid"
  operation.targetInvalid = true
  operation.quarantined = true
  operation.targetInvalidReason = tostring(reason or "target invalid")
  trace(string.format(
    "standard target quarantined: generation=%s | target=%s | reason=%s",
    tostring(operation.generation),
    tostring(operation.targetId),
    operation.targetInvalidReason
  ))
  return deepCopy(operation)
end

function boop.runtime.revokeStandard(reason)
  local operation = activeStandard()
  if not operation then
    return false
  end
  if not operation.clearSent and send then
    operation.clearSent = true
    boop.runtime.registerOutboundExpectation(
      operation,
      "clearqueue all",
      "revocation"
    )
    send("clearqueue all", false)
    trace(string.format(
      "standard queue collateral cleared: generation=%s | target=%s | reason=%s",
      tostring(operation.generation),
      tostring(operation.targetId),
      tostring(reason or "target revoked")
    ))
  end
  return terminalizeStandard(
    operation,
    "revoked",
    tostring(reason or "target revoked")
  )
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
  local state = boop.runtime.ensureState()
  local records = sortedOperationRecords()
  local operation = records[1]
    and deepCopy(records[1])
    or deepCopy(DOMAIN_DEFAULTS.combat.blocker)
  operation.additionalCount = math.max(0, #records - 1)
  state.combat.operationLock = operation
  return operation
end

local function currentBlocker()
  local state = boop.runtime.ensureState()
  local records = sortedBlockerRecords()
  if #records == 0 then
    state.combat.blocker = deepCopy(DOMAIN_DEFAULTS.combat.blocker)
    currentOperationLock()
    return state.combat.blocker
  end
  state.combat.blocker = deepCopy(records[1])
  state.combat.blocker.additionalCount = #records - 1
  currentOperationLock()
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

function boop.runtime.blockerSnapshot()
  return publicBlockerSnapshot(currentBlocker())
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

function boop.runtime.operationLocksSnapshot()
  return deepCopy(sortedOperationRecords())
end

function boop.runtime.operationLockSnapshot()
  return publicBlockerSnapshot(currentOperationLock())
end

function boop.runtime.setOperationLock(
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
  return boop.runtime.setBlocker(
    owner,
    code,
    label,
    systems,
    waitsFor,
    opts
  )
end

function boop.runtime.clearOperationLock(owner, observed)
  if not isOperationOwner(owner) then
    return false
  end
  return boop.runtime.clearBlocker(owner, observed)
end

function boop.runtime.operationHolds(system, exceptOwner)
  local key = normalizeKey(system)
  local excluded = tostring(exceptOwner or "")
  for _, operation in ipairs(sortedOperationRecords()) do
    if operation.owner ~= excluded and operation.systems[key] == true then
      return true
    end
  end
  return false
end

function boop.runtime.enqueueDiagEvidence(generation)
  local state = boop.runtime.ensureState()
  local staleQueue = state.diag.evidenceQueue or {}
  if #staleQueue > 0 then
    local staleGenerations = {}
    for _, record in ipairs(staleQueue) do
      if type(record) == "table" then
        staleGenerations[#staleGenerations + 1] = tostring(
          record.generation or ""
        )
      end
    end
    trace(string.format(
      "diag evidence superseded: generations=%s | next=%s",
      table.concat(staleGenerations, ","),
      tostring(generation or "")
    ))
  end
  state.diag.evidenceQueue = {}
  local record = {
    generation = tonumber(generation) or 0,
    resultSeen = false,
    terminal = false,
    tombstone = false,
  }
  state.diag.evidenceQueue[#state.diag.evidenceQueue + 1] = record
  return record
end

function boop.runtime.resetVenomConfusionCount(reason)
  local state = boop.runtime.ensureState()
  local previous = tonumber(state.diag.venomConfusionCount) or 0
  state.diag.venomConfusionCount = 0
  if previous > 0 then
    trace(string.format(
      "venom confusion reset: %d -> 0 | reason=%s",
      previous,
      tostring(reason or "reset")
    ))
  end
  return previous
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

  local reason = tostring(terminalReason or "")
  operation.terminal = true
  local causal = operation.causal
  if type(causal) == "table" then
    causal.windowOpen = false
    causal.terminal = true
    causal.terminalReason = reason
    causal.terminalOutboundSequence = standardQueueState().outboundSequence
    clearStandardExpectations(causal)
  end
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

  boop.runtime.clearOperationLock(operation.blockerOwner, reason)

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
  elseif reason == "command_failed" then
    if boop.util and boop.util.warn then
      boop.util.warn(name .. " command failed; attacks resumed")
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
  if name == "diag" and reason == "diagnose_result_prompt" then
    boop.runtime.resetVenomConfusionCount("diagnose complete")
  elseif name ~= "diag"
      and boop.tryVenomConfusionDiag
      and (tonumber(state.diag.venomConfusionCount) or 0) >= 2 then
    boop.tryVenomConfusionDiag("interrupt complete")
  end
  return true
end

local function traceLeapDenialDiagnostic(operation, causal, reason)
  if type(causal) == "table" and causal.ambiguityTraced then
    return false
  end
  if type(causal) == "table" then
    causal.ambiguityTraced = true
  end
  trace(string.format(
    "leap denial ambiguous: reason=%s | active=%s | owner=%s | generation=%s | baseline=%s | outbound=%s | contamination=%s",
    tostring(reason or "unknown"),
    tostring(type(operation) == "table" and operation.name or "none"),
    tostring(type(causal) == "table" and causal.owner or ""),
    tostring(type(causal) == "table" and causal.generation or ""),
    tostring(
      type(causal) == "table"
        and type(causal.baseline) == "table"
        and causal.baseline.sequence
        or ""
    ),
    tostring(standardQueueState().outboundSequence),
    tostring(type(causal) == "table" and causal.contaminatedAt or "")
  ))
  return true
end

function boop.runtime.onLeapCommandDenied(line, capturedGeneration)
  if tostring(line or "") ~= LEAP_DENIAL_LINE then
    return false
  end

  local state = boop.runtime.ensureState()
  local operation = state.diag.operation
  local causal = type(operation) == "table" and operation.causal or false
  if type(operation) ~= "table"
      or operation.terminal
      or operation.name ~= "leap"
      or operation.completionMode ~= "room_change" then
    traceLeapDenialDiagnostic(operation, causal, "no active leap")
    return false
  end

  local expectedGeneration = operation.generation
  if capturedGeneration ~= nil
      and tonumber(capturedGeneration) ~= tonumber(expectedGeneration) then
    traceLeapDenialDiagnostic(operation, causal, "stale generation")
    return false
  end
  if type(causal) ~= "table"
      or causal.terminal
      or tostring(causal.owner or "")
        ~= tostring(operation.blockerOwner or "")
      or tonumber(causal.generation) ~= tonumber(expectedGeneration)
      or tostring(causal.dispatchId or "")
        ~= tostring(operation.blockerOwner or "")
      or tostring(causal.command or "") ~= tostring(operation.command or "")
      or causal.timeoutToken ~= operation.timeoutTimer then
    traceLeapDenialDiagnostic(operation, causal, "identity mismatch")
    return false
  end

  local observation = state.targeting.roomObservation or {}
  local currentRoom = tostring(state.targeting.room or "")
  if currentRoom == "" then
    currentRoom = tostring(
      gmcp
        and gmcp.Room
        and gmcp.Room.Info
        and gmcp.Room.Info.num
        or ""
    )
  end
  if tostring(causal.roomId or "") == ""
      or currentRoom ~= tostring(causal.roomId or "")
      or tostring(observation.roomId or "")
        ~= tostring(causal.roomId or "")
      or tonumber(observation.generation)
        ~= tonumber(causal.roomGeneration) then
    traceLeapDenialDiagnostic(operation, causal, "room authority changed")
    return false
  end

  if not causal.windowOpen
      or type(causal.baseline) ~= "table"
      or tostring(causal.baseline.owner or "") ~= tostring(causal.owner or "")
      or tonumber(causal.baseline.generation)
        ~= tonumber(causal.generation)
      or tostring(causal.baseline.command or "")
        ~= tostring(causal.nativeCommand or "") then
    traceLeapDenialDiagnostic(operation, causal, "window not open")
    return false
  end
  if causal.contaminatedAt
      and tonumber(causal.contaminatedAt)
        > tonumber(causal.baseline.sequence or 0) then
    traceLeapDenialDiagnostic(operation, causal, "unowned outbound")
    return false
  end

  local completed = boop.runtime.completeInterrupt(
    expectedGeneration,
    "command_failed"
  )
  if not completed then
    return false
  end
  if tempTimer then
    tempTimer(0, function()
      if boop and boop.tick then
        boop.tick()
      end
    end)
  elseif boop and boop.tick then
    boop.tick()
  end
  return true
end

function boop.runtime.markOldestDiagEvidenceResult(source)
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
  trace(string.format(
    "diag result observed: source=%s | evidenceGeneration=%s | activeGeneration=%s | tombstone=%s",
    tostring(source or "text"),
    tostring(head.generation or ""),
    tostring(type(operation) == "table" and operation.generation or ""),
    tostring(head.tombstone == true)
  ))
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
  trace(string.format(
    "diag prompt consumed: evidenceGeneration=%s | activeGeneration=%s | tombstone=%s",
    tostring(head.generation or ""),
    tostring(
      type(state.diag.operation) == "table"
        and state.diag.operation.generation
        or ""
    ),
    tostring(head.tombstone == true)
  ))
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
  local reasonText = tostring(reason or "")
  local pendingStandard = activeStandard()
  local departureInvalidation = pendingStandard
    and (
      reasonText == "target_lost"
      or reasonText == "room_changed"
      or reasonText == "room_partial"
      or reasonText == "missing_room"
      or opts.standardDisposition == "target-invalid"
    )
  state.combat.attacking = false
  state.combat.lastRageDecision = nil
  state.combat.pendingStandard = nil
  state.combat.pendingRage = nil
  state.combat.attackPlan = nil

  killOwnedTimer(state.queue.prequeueTimer)
  state.queue.prequeueTimer = nil

  state.targeting.calledTargetId = ""
  state.targeting.calledTargetRoom = ""
  state.targeting.calledTargetBy = ""
  state.targeting.calledTargetAt = nil

  if departureInvalidation then
    boop.runtime.markStandardTargetInvalid(reasonText)
    if not opts.suppressTrace then
      trace("attack intent quarantined: " .. reasonText)
    end
    return true
  end

  if pendingStandard then
    boop.runtime.revokeStandard(reasonText ~= "" and reasonText or "attack intent cleared")
  end

  state.queue.prequeuedStandard = false
  state.queue.prequeueSourceAuthority = false
  state.queue.aliasAction = ""
  state.queue.aliasDirty = true

  if opts.clearTarget == true
      or reasonText == "target_lost" then
    state.targeting.currentTargetId = ""
    state.targeting.targetName = ""
    if boop.targets and boop.targets.clearTargetShield then
      boop.targets.clearTargetShield(reason or "target cleared")
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
    boop.runtime.clearAttackIntent(reason, {
      suppressTrace = true,
      clearTarget = opts.clearTarget == true,
    })
  end

  if includeWalk then
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
  end

  if includeGold then
    local operation = state.gold.operation
    if type(operation) == "table" then
      operation.terminal = true
      killOwnedTimer(operation.flushTimer)
      killOwnedTimer(operation.timeoutTimer)
      boop.runtime.clearOperationLock(
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

function boop.runtime.context(sourceAuthority, options)
  local state = boop.runtime.ensureState()
  local room = currentRoom()
  local authority = copySourceAuthority(sourceAuthority)
  options = type(options) == "table" and options or {}
  local roomOwned = options.roomOwned == true or authority and true or false
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

  local operation = boop.runtime.operationLockSnapshot()
  return {
    state = state,
    config = boop.config or {},
    gmcp = gmcp,
    roomOwned = roomOwned,
    provisionalCombat = options.provisionalCombat == true,
    sourceAuthority = authority,
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
      standardPending = boop.runtime.standardPending(),
      standard = boop.runtime.standardSnapshot(),
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
      venomConfusionCount =
        tonumber(state.diag.venomConfusionCount) or 0,
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
    readiness = boop.runtime.readinessSnapshot(),
    operation = operation,
    blocker = operation,
  }
end

local function heldEffect(context, system, detail)
  local operation = context.operation
    or context.blocker
    or boop.runtime.operationLockSnapshot()
  return {
    kind = "trace",
    message = string.format(
      "%s held: %s -- %s",
      tostring(detail or system or "automation"),
      tostring(operation.code or ""),
      tostring(operation.label or "")
    ),
  }
end

local function readinessHeldEffect(detail, readiness)
  local status = readiness or {}
  return {
    kind = "trace",
    message = string.format(
      "%s held: %s -- %s",
      tostring(detail or "automation"),
      tostring(status.code or ""),
      tostring(status.label or "")
    ),
  }
end

local function tickStep(context)
  local state = context.state
  local effects = {}
  local authority = copySourceAuthority(context.sourceAuthority)
  local roomOwned = context.roomOwned == true
  local provisionalCombat = context.provisionalCombat == true

  if not (context.config and context.config.enabled) then
    return { effects = effects, didAction = false }
  end
  local readiness = context.readiness or {}
  local lifecycle = readiness.lifecycle or {}
  if lifecycle.ready ~= true then
    effects[#effects + 1] = readinessHeldEffect("tick", {
      code = "gmcp_ire_missing",
      label = "GMCP IRE awaiting current prompt evidence",
    })
    return { effects = effects, didAction = false }
  end
  if state.diag.hold then
    return { effects = effects, didAction = false }
  end

  if activeStandard() or boop.runtime.standardRecoveryPending() then
    effects[#effects + 1] = {
      kind = "trace",
      message = "tick held: exact standard lifecycle pending",
    }
    return { effects = effects, didAction = false }
  end

  local goldOperation = state.gold.operation
  if type(goldOperation) == "table" and not goldOperation.terminal then
    if provisionalCombat then
      return { effects = effects, didAction = false }
    end
    if boop.safety and boop.safety.shouldFlee and boop.safety.shouldFlee() then
      effects[#effects + 1] = { kind = "flee" }
      return { effects = effects, didAction = false }
    end
    local owner = tostring(goldOperation.blockerOwner or "")
    if boop.runtime.operationHolds("combat", owner)
      or boop.runtime.operationHolds("queue", owner)
      or boop.runtime.operationHolds("gold", owner)
      or boop.runtime.operationHolds("walk", owner)
    then
      effects[#effects + 1] = heldEffect(context, "gold", "gold")
      return { effects = effects, didAction = false }
    end
    if not goldOperation.timeoutTimer then
      effects[#effects + 1] = {
        kind = "flush_gold",
        reason = "tick gold stage",
        roomOwned = roomOwned,
        sourceAuthority = authority,
      }
    end
    return { effects = effects, didAction = false }
  end

  if boop.runtime.operationHolds("target")
    or boop.runtime.operationHolds("combat")
    or boop.runtime.operationHolds("queue")
    or boop.runtime.operationHolds("gold")
    or boop.runtime.operationHolds("walk")
  then
    effects[#effects + 1] = heldEffect(context, "automation", "tick")
    return { effects = effects, didAction = false }
  end
  if not provisionalCombat
      and boop.maybeFlushPendingGold
      and boop.maybeFlushPendingGold("tick pending age") then
    return { effects = effects, didAction = false }
  end
  if state.gold.getPending or state.gold.putPending then
    return { effects = effects, didAction = false }
  end
  local roomReadiness = readiness.room or {}
  if roomReadiness.ready ~= true and not provisionalCombat then
    effects[#effects + 1] =
      readinessHeldEffect("tick", roomReadiness)
    return { effects = effects, didAction = false }
  end

  if boop.safety and boop.safety.shouldFlee and boop.safety.shouldFlee() then
    effects[#effects + 1] = { kind = "flee" }
    return { effects = effects, didAction = false }
  end

  local targetId = boop.targets and boop.targets.choose and boop.targets.choose() or ""
  if not targetId or targetId == "" then
    if provisionalCombat then
      effects[#effects + 1] = {
        kind = "trace",
        message = "provisional combat: no eligible target",
      }
      return { effects = effects, didAction = false }
    end
    if context.config.useQueueing and state.gold.autoGrabPending then
      effects[#effects + 1] = {
        kind = "flush_gold",
        reason = "tick no target",
        roomOwned = roomOwned,
        sourceAuthority = authority,
      }
    end
    if boop.targets and boop.targets.waitingForTargetCall and boop.targets.waitingForTargetCall() then
      effects[#effects + 1] = { kind = "trace", message = "tick: waiting for leader target call" }
      return { effects = effects, didAction = false }
    end
    effects[#effects + 1] = { kind = "trace", message = "tick: no target" }
    effects[#effects + 1] = {
      kind = "walk_advance",
      reason = "tick no target",
      roomOwned = roomOwned,
      sourceAuthority = authority,
    }
    return { effects = effects, didAction = false }
  end

  if tostring(state.targeting.currentTargetId or "") ~= tostring(targetId) then
    effects[#effects + 1] = {
      kind = "target",
      id = tostring(targetId),
      roomOwned = roomOwned,
      sourceAuthority = authority,
    }
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
      roomOwned = context.roomOwned == true,
      provisionalCombat = context.provisionalCombat == true,
      sourceAuthority = copySourceAuthority(context.sourceAuthority),
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
    effects[#effects + 1] = {
      kind = "combat_plan",
      plan = plan,
      context = planContext,
      roomOwned = roomOwned,
      sourceAuthority = authority,
    }
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
    local sourceAuthority = copySourceAuthority(effect.sourceAuthority)
    local roomOwned = effect.roomOwned == true
    local authorized = not roomOwned
      or (sourceAuthority
        and boop.runtime.validateRoomSourceAuthority
        and boop.runtime.validateRoomSourceAuthority(sourceAuthority))
    if roomOwned and not authorized then
      trace(string.format(
        "room effect rejected: %s | application=%s | room=%s | generation=%s",
        tostring(effect.kind or ""),
        tostring(sourceAuthority and sourceAuthority.applicationId or ""),
        tostring(sourceAuthority and sourceAuthority.roomId or ""),
        tostring(
          sourceAuthority
            and sourceAuthority.observationGeneration
            or ""
        )
      ))
    elseif effect.kind == "trace" then
      if boop.trace and boop.trace.log then
        boop.trace.log(effect.message or "")
      end
    elseif effect.kind == "flush_gold" then
      if boop.flushPendingGold then
        boop.flushPendingGold(
          effect.reason or "runtime",
          sourceAuthority
        )
      end
    elseif effect.kind == "walk_advance" then
      if boop.walk and boop.walk.maybeAdvance then
        boop.walk.maybeAdvance(
          effect.reason or "runtime",
          sourceAuthority
        )
      end
    elseif effect.kind == "flee" then
      if boop.safety and boop.safety.flee then
        boop.safety.flee()
      end
    elseif effect.kind == "target" then
      if boop.targets and boop.targets.setTarget then
        boop.targets.setTarget(effect.id, {
          roomOwned = roomOwned,
          sourceAuthority = sourceAuthority,
        })
      end
    elseif effect.kind == "combat_plan" then
      if boop.attacks and boop.attacks.execute then
        if boop.attacks.execute(
          effect.plan,
          effect.context or context,
          sourceAuthority
        ) then
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
