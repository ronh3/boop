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
  state.combat.attacking = false
  state.combat.lastRageDecision = nil
  state.combat.pendingStandard = nil
  state.combat.pendingRage = nil
  state.combat.attackPlan = nil

  killOwnedTimer(state.queue.prequeueTimer)
  state.queue.prequeueTimer = nil
  state.queue.prequeuedStandard = false
  state.queue.prequeueSourceAuthority = false
  state.queue.aliasAction = ""
  state.queue.aliasDirty = true

  state.targeting.calledTargetId = ""
  state.targeting.calledTargetRoom = ""
  state.targeting.calledTargetBy = ""
  state.targeting.calledTargetAt = nil

  if opts.clearTarget == true
      or tostring(reason or "") == "target_lost" then
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
