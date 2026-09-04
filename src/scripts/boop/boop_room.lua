boop.room = boop.room or {}

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

local ROOM_OBSERVATION_DEFAULTS = {
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
}

local MOVEMENT_INTENT_DEFAULTS = {
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
}

local function normalizeRoomId(roomId)
  return tostring(roomId or ""):match("^%s*(.-)%s*$")
end

local function roomObservationState()
  local observation = boop.state.targeting.roomObservation
  if type(observation) ~= "table" then
    observation = deepCopy(ROOM_OBSERVATION_DEFAULTS)
    boop.state.targeting.roomObservation = observation
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

function boop.room.startRoomObservation(roomId, opts)
  opts = type(opts) == "table" and opts or {}
  local boundary = tostring(opts.boundary or "fresh_start")
  if boundary ~= "room_change" and boundary ~= "fresh_start" then
    return false
  end
  if boundary == "fresh_start" then
    local previousIntent = boop.state.targeting.movementIntent
    local intentGeneration = type(previousIntent) == "table"
        and tonumber(previousIntent.generation)
      or 0
    boop.state.targeting.movementIntent =
      deepCopy(MOVEMENT_INTENT_DEFAULTS)
    boop.state.targeting.movementIntent.generation = intentGeneration or 0
    boop.state.targeting.movementIntent.lastReason =
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
  boop.state.targeting.roomObservation = {
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
  return boop.room.roomObservationSnapshot()
end

function boop.room.observeRoomInfo(roomId, opts)
  opts = type(opts) == "table" and opts or {}
  local normalizedRoomId = normalizeRoomId(roomId)
  local observation = roomObservationState()
  if opts.movedRooms or opts.freshStart or opts.boundary == "room_change"
      or opts.boundary == "fresh_start" then
    return boop.room.startRoomObservation(normalizedRoomId, opts)
  end
  if normalizedRoomId == "" or normalizedRoomId ~= observation.roomId then
    return false
  end
  observation.infoSeen = true
  return boop.room.roomObservationSnapshot()
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
  local intent = boop.state.targeting.movementIntent
  if type(intent) ~= "table" then
    intent = deepCopy(MOVEMENT_INTENT_DEFAULTS)
    boop.state.targeting.movementIntent = intent
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

function boop.room.movementIntentSnapshot()
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

function boop.room.noteMovementIntent(direction)
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
    and boop.room.validateRoomSourceAuthority
    and boop.room.validateRoomSourceAuthority(authority)
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
  return boop.room.movementIntentSnapshot()
end

function boop.room.beginRoomResponseFence(reason, opts)
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

function boop.room.setRoomResponseFenceTimer(fenceId, timerId)
  local observation = roomObservationState()
  if tonumber(observation.activeFenceId) ~= tonumber(fenceId) then
    return false
  end
  observation.refreshTimeoutTimer = timerId or false
  return true
end

function boop.room.timeoutRoomResponseFence(fenceId, timerId)
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

function boop.room.clearMovementIntent(reason)
  local intent = movementIntentState()
  resetMovementIntent(intent, reason)
  return boop.room.movementIntentSnapshot()
end

function boop.room.captureMovementRoomItems(items, response)
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
  return boop.room.movementIntentSnapshot()
end

function boop.room.consumeMovementRoomItems(destinationRoomId)
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

function boop.room.observeRoomItemDelta(kind, item)
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

function boop.room.roomApplicationSnapshot(applicationId)
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

function boop.room.setRoomApplicationTimer(applicationId, timerId)
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

function boop.room.invalidateRoomApplication(applicationId, reason)
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

function boop.room.claimRoomApplication(
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
  return boop.room.roomApplicationSnapshot(application.applicationId)
end

local function roomSourceAuthorityCurrent(
  observation,
  sourceAuthority
)
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

function boop.room.validateRoomSourceAuthority(sourceAuthority)
  return roomSourceAuthorityCurrent(
    roomObservationState(),
    sourceAuthority
  ) and true or false
end

function boop.room.currentRoomSourceAuthority()
  local observation = roomObservationState()
  local authority = copySourceAuthority(
    observation.acceptedSourceAuthority
  )
  if authority
      and roomSourceAuthorityCurrent(observation, authority) then
    return authority
  end
  return false
end

function boop.room.observeRoomItemsList(location, items)
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

local function itemListSize(value)
  return type(value) == "table" and #value or 0
end

local function fenceItemSize(fence)
  if type(fence) ~= "table" then return 0 end
  return itemListSize(fence.invItems)
    + itemListSize(fence.roomItems)
    + itemListSize(fence.roomDeltas)
end

function boop.room.roomObservationSnapshot()
  local observation = roomObservationState()
  if boop.perf.on then
    local copiedItems = itemListSize(observation.acceptedItems)
    for _, fence in ipairs(observation.fenceQueue or {}) do
      copiedItems = copiedItems + fenceItemSize(fence)
    end
    copiedItems = copiedItems + fenceItemSize(observation.lastCompletedFence)
    if type(observation.activeApplication) == "table" then
      copiedItems = copiedItems
        + itemListSize(observation.activeApplication.items)
    end
    boop.perf.count("deepcopy_items", copiedItems)
  end
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

function boop.room.roomReadinessSnapshot()
  local observation = roomObservationState()
  local authority = copySourceAuthority(
    observation.acceptedSourceAuthority
  )
  if not roomSourceAuthorityCurrent(observation, authority) then
    authority = false
  end
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
    ready = roomReady,
    code = roomCode,
    label = roomLabel,
    roomId = tostring(observation.roomId or ""),
    generation = tonumber(observation.generation) or 0,
    infoSeen = not not observation.infoSeen,
    itemsSeen = not not observation.itemsSeen,
    sourceAuthority = authority,
  }
end


function boop.room.resetConnectionMovementIntent()
  boop.state.targeting.movementIntent = deepCopy(MOVEMENT_INTENT_DEFAULTS)
  return boop.room.movementIntentSnapshot()
end

function boop.room.observationIdentitySnapshot()
  local observation = roomObservationState()
  return {
    roomId = tostring(observation.roomId or ""),
    generation = tonumber(observation.generation) or 0,
  }
end

function boop.room.sourceAuthorityDisposition(sourceAuthority)
  local captured = copySourceAuthority(sourceAuthority)
  if not captured
      or captured.applicationId == nil
      or captured.roomId == ""
      or captured.observationGeneration == nil then
    return false, "captured room authority missing"
  end

  local observation = roomObservationState()
  local accepted = copySourceAuthority(
    observation.acceptedSourceAuthority
  )
  if not observation.infoSeen
      or not observation.itemsSeen
      or not accepted
      or accepted.applicationId == nil
      or accepted.roomId == ""
      or accepted.observationGeneration == nil then
    return false, "accepted room evidence missing"
  end
  if observation.roomId ~= captured.roomId
      or currentRoomId() ~= captured.roomId
      or accepted.roomId ~= captured.roomId then
    return false, "room changed"
  end
  if tonumber(observation.generation)
        ~= tonumber(captured.observationGeneration)
      or accepted.observationGeneration
        ~= captured.observationGeneration then
    return false, "observation generation changed"
  end
  if accepted.applicationId < captured.applicationId then
    return false, "application authority regressed"
  end
  if not boop.room.validateRoomSourceAuthority(accepted) then
    return false, "accepted room evidence missing"
  end
  if accepted.applicationId > captured.applicationId then
    return true, "same-room application superseded"
  end
  return true, "accepted"
end

local ROOM_RESPONSE_FENCE_WARNING_SECONDS = 8.0

local function warnRoomResponseFence(fence, timerId)
  if not boop.room.timeoutRoomResponseFence(fence.fenceId, timerId) then
    return false
  end
  if boop.trace and boop.trace.log then
    boop.trace.log(string.format(
      "room response fence timeout: generation=%s room=%s fence=%s",
      tostring(fence.generation),
      tostring(fence.roomId),
      tostring(fence.fenceId)
    ))
  end
  if boop.util and boop.util.warn then
    boop.util.warn("room_partial -- room response fence incomplete")
  end
  return true
end

local function sendGmcpRequestWithFlush(command)
  if not sendGMCP or not send then
    return false
  end
  sendGMCP(command)
  send(" ")
  return true
end

function boop.room.requestRoomItemsForFence(reason, opts)
  local fence = boop.room.beginRoomResponseFence(reason, opts)
  if not fence then return false end

  local timerId = false
  if tempTimer then
    timerId = tempTimer(ROOM_RESPONSE_FENCE_WARNING_SECONDS, function()
      warnRoomResponseFence(fence, timerId)
    end)
    boop.room.setRoomResponseFenceTimer(fence.fenceId, timerId)
  end

  if sendGMCP and send then
    if not fence.roomOnly then
      sendGmcpRequestWithFlush([[Char.Items.Inv ""]])
    end
    sendGmcpRequestWithFlush([[Char.Items.Room ""]])
  else
    if timerId and killTimer then killTimer(timerId) end
    boop.room.setRoomResponseFenceTimer(fence.fenceId, false)
    warnRoomResponseFence(fence, false)
  end
  return fence
end

function boop.room.requestRoomItemsOnce(reason)
  return boop.room.requestRoomItemsForFence(reason) and true or false
end
