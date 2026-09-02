boop.events = boop.events or {}

local function nowSeconds()
  if getEpoch then return getEpoch() end
  return os.clock()
end

local function deepCopy(value, seen)
  if type(value) ~= "table" then return value end
  seen = seen or {}
  if seen[value] then return seen[value] end
  local out = {}
  seen[value] = out
  for key, entry in pairs(value) do
    out[deepCopy(key, seen)] = deepCopy(entry, seen)
  end
  return out
end

local function copySourceAuthority(authority)
  if type(authority) ~= "table" then
    return false
  end
  return {
    applicationId = tonumber(authority.applicationId),
    roomId = tostring(authority.roomId or ""),
    observationGeneration = tonumber(authority.observationGeneration),
  }
end

local function currentRoomSourceAuthority()
  if boop.runtime
      and boop.runtime.currentRoomSourceAuthority then
    return copySourceAuthority(
      boop.runtime.currentRoomSourceAuthority()
    )
  end
  return false
end

local function roomAuthorityCurrent(authority, boundary)
  local captured = copySourceAuthority(authority)
  if not captured then
    return true
  end
  local valid = boop.runtime
    and boop.runtime.validateRoomSourceAuthority
    and boop.runtime.validateRoomSourceAuthority(captured)
    or false
  if not valid and boop.trace and boop.trace.log then
    boop.trace.log(string.format(
      "room callback rejected: %s | application=%s | room=%s | generation=%s",
      tostring(boundary or "callback"),
      tostring(captured.applicationId or ""),
      tostring(captured.roomId or ""),
      tostring(captured.observationGeneration or "")
    ))
  end
  return not not valid
end

local function automaticDispatchOptions(authority, roomOwned)
  local captured = copySourceAuthority(authority)
  return {
    roomOwned = roomOwned == true or captured and true or false,
    sourceAuthority = captured,
  }
end

local function classKeyForOpener()
  if gmcp and gmcp.Char and gmcp.Char.Status and gmcp.Char.Status.class then
    return gmcp.Char.Status.class
  end
  return boop.state and boop.state.combat.class or ""
end

local function isGoldItem(item)
  if not item or not item.name then return false end
  local name = boop.util.safeLower(item.name)
  if name:find("gold sovereign", 1, true) then return true end
  if name:find("sovereigns", 1, true) then return true end
  return false
end

local function findRoomGoldItem(items, expectedId)
  if type(items) ~= "table" then return nil end
  local wanted = tostring(expectedId or "")
  for _, item in ipairs(items) do
    if isGoldItem(item)
        and (wanted == "" or tostring(item.id or "") == wanted) then
      return item
    end
  end
  return nil
end

local AUTO_GOLD_FLUSH_SECONDS = 0.35
local ROOM_RESPONSE_FENCE_WARNING_SECONDS = 8.0
local MOVEMENT_DIRECTIONS = {
  n = true,
  north = true,
  s = true,
  south = true,
  e = true,
  east = true,
  w = true,
  west = true,
  ["in"] = true,
  out = true,
  u = true,
  up = true,
  d = true,
  down = true,
  nw = true,
  northwest = true,
  ne = true,
  northeast = true,
  se = true,
  southeast = true,
  sw = true,
  southwest = true,
}
local GOLD_PICKUP_QUEUE = "full"
local GOLD_PACK_QUEUE = "freestand"
local GOLD_DIRECT_PICKUP_SUFFIX =
  "flying into your hands before they can reach the ground."
local GOLD_PHASE = {
  DEFERRED_ROOM = "deferred_room",
  PICKUP_PENDING = "pickup_pending",
  PACK_PENDING = "pack_pending",
}

local function queueGoldCommand(queueName, command)
  local wireCommand = "queue add " .. queueName .. " " .. command
  send(wireCommand, false)
  return true, wireCommand
end

local function traceRoomInfo(info, moved, previousRoom)
  if not boop.trace or not boop.trace.log then return end
  if type(info) ~= "table" then return end

  local room = tostring(info.num or "")
  local area = tostring(info.area or "UNKNOWN")
  local exits = 0
  if type(info.exits) == "table" then
    for _ in pairs(info.exits) do
      exits = exits + 1
    end
  end

  local prefix = "gmcp room info"
  if moved then
    prefix = string.format("%s: %s -> %s", prefix, tostring(previousRoom or ""), room)
  else
    prefix = string.format("%s: %s", prefix, room)
  end

  boop.trace.log(string.format("%s | area=%s | exits=%d | moved=%s", prefix, area, exits, moved and "yes" or "no"))
end

local function traceRoomItemsList(items, goldItem)
  if not boop.trace or not boop.trace.log then return end
  local count = type(items) == "table" and #items or 0
  local denizens = 0
  for _, item in ipairs(items or {}) do
    if boop.targets
        and boop.targets.isValidDenizen
        and boop.targets.isValidDenizen(item) then
      denizens = denizens + 1
    end
  end
  if goldItem then
    boop.trace.log(string.format(
      "gmcp room items list: count=%d | gold=yes | gold=%s (%s) | denizens=%d",
      count,
      tostring(goldItem.name or "?"),
      tostring(goldItem.id or "?"),
      denizens
    ))
    return
  end
  boop.trace.log(string.format(
    "gmcp room items list: count=%d | gold=no | denizens=%d",
    count,
    denizens
  ))
end

local function countCombatDenizens(items)
  local count = 0
  for _, item in ipairs(items or {}) do
    if boop.targets
        and boop.targets.isValidDenizen
        and boop.targets.isValidDenizen(item) then
      count = count + 1
    end
  end
  return count
end

local function movementDirection(command)
  local normalized = boop.util
      and boop.util.trim
      and boop.util.safeLower
      and boop.util.safeLower(boop.util.trim(command or ""))
    or tostring(command or ""):lower():match("^%s*(.-)%s*$")
  return MOVEMENT_DIRECTIONS[normalized] and normalized or false
end

local function traceRoomItemsResponse(list, transition)
  if not boop.trace or not boop.trace.log then return end
  if not boop.config or not boop.config.traceEnabled then return end
  if type(list) ~= "table" or type(transition) ~= "table" then return end

  local observation = boop.runtime
    and boop.runtime.roomObservationSnapshot
    and boop.runtime.roomObservationSnapshot()
    or {}
  local fenceId = tonumber(transition.fenceId)
  local fence = false
  for _, candidate in ipairs(observation.fenceQueue or {}) do
    if tonumber(candidate.fenceId) == fenceId then
      fence = candidate
      break
    end
  end
  if not fence
      and type(observation.lastCompletedFence) == "table"
      and tonumber(observation.lastCompletedFence.fenceId) == fenceId then
    fence = observation.lastCompletedFence
  end

  local seen = {}
  local waits = {}
  if fence and fence.invSeen then seen[#seen + 1] = "inv" end
  if fence and fence.roomSeen then seen[#seen + 1] = "room" end
  if fence and not fence.roomOnly and not fence.invSeen then
    waits[#waits + 1] = "inv"
  end
  if fence and not fence.roomSeen then waits[#waits + 1] = "room" end

  boop.trace.log(string.format(
    "gmcp item list response: location=%s | count=%d | status=%s | fence=%s | seen=%s | waits=%s | room=%s | generation=%s",
    tostring(list.location or ""),
    type(list.items) == "table" and #list.items or 0,
    tostring(transition.status or "ignored"),
    tostring(transition.fenceId or "none"),
    #seen > 0 and table.concat(seen, ",") or "none",
    #waits > 0 and table.concat(waits, ",") or "none",
    tostring(fence and fence.roomId or observation.roomId or ""),
    tostring(fence and fence.generation or observation.generation or "")
  ))
end

local function traceRoomItemEvent(kind, item)
  if not boop.trace or not boop.trace.log then return end
  local name = item and item.name or "?"
  local id = item and item.id or "?"
  local gold = isGoldItem(item) and "yes" or "no"
  local attrib = item and item.attrib or ""
  boop.trace.log(string.format(
    "gmcp room item %s: %s (%s) | gold=%s | attrib=%s",
    tostring(kind or "?"),
    tostring(name),
    tostring(id),
    gold,
    tostring(attrib)
  ))
end

local function recordPendingRoomDelta(kind, item)
  local result = boop.runtime
      and boop.runtime.observeRoomItemDelta
      and boop.runtime.observeRoomItemDelta(kind, item)
    or { status = "ignored" }
  if result.status == "recorded"
      and boop.trace
      and boop.trace.log then
    boop.trace.log(string.format(
      "room item delta recorded: %s %s | room=%s | generation=%s | fence=%s | application=%s",
      tostring(result.kind or kind or "?"),
      tostring(result.itemId or (item and item.id) or "?"),
      tostring(result.roomId or ""),
      tostring(result.observationGeneration or ""),
      tostring(result.fenceId or ""),
      tostring(result.applicationId or "")
    ))
  end
  return result
end

local GMCP_RETRY_SECONDS = 2

local function runtime()
  return boop.runtime
end

local function operationSnapshot()
  if runtime() and boop.runtime.operationLockSnapshot then
    return boop.runtime.operationLockSnapshot()
  end
  return { owner = "", code = "", systems = {}, waitsFor = {}, observed = {}, additionalCount = 0 }
end

local function setOperationLock(owner, code, label, systems, waitsFor, opts)
  if runtime() and boop.runtime.setOperationLock then
    return boop.runtime.setOperationLock(
      owner,
      code,
      label,
      systems,
      waitsFor,
      opts or {}
    )
  end
  return false
end

local function operationHolds(system, exceptOwner)
  return runtime()
    and boop.runtime.operationHolds
    and boop.runtime.operationHolds(system, exceptOwner)
end

local function readinessAllows(requireRoom)
  local readiness = runtime()
      and boop.runtime.readinessSnapshot
      and boop.runtime.readinessSnapshot()
    or {}
  if not (readiness.lifecycle and readiness.lifecycle.ready) then
    return false
  end
  if requireRoom
      and not (readiness.room and readiness.room.ready) then
    return false
  end
  return true
end

local function traceHeld(system, reason)
  if boop.trace and boop.trace.log then
    local operation = operationSnapshot()
    boop.trace.log(string.format(
      "%s held: %s -- %s%s",
      tostring(system or "automation"),
      tostring(operation.code or ""),
      tostring(operation.label or ""),
      reason and (" | " .. tostring(reason)) or ""
    ))
  end
end

local function ireReady()
  local ire = gmcp and gmcp.IRE or nil
  return type(ire) == "table"
    and (type(ire.Target) == "table" or type(ire.Display) == "table")
end

local function warnIreReadiness(lifecycle)
  if not (boop.util and boop.util.warn) then return end
  if type(lifecycle) ~= "table" or lifecycle.ireSeen then return end
  local stateLifecycle = boop.state and boop.state.lifecycle or nil
  if type(stateLifecycle) ~= "table" then return end
  local now = nowSeconds()
  local lastAt = tonumber(stateLifecycle.lastWarningAt) or 0
  local lastCode = tostring(stateLifecycle.lastWarningCode or "")
  local throttle = tonumber(stateLifecycle.warningThrottleSeconds)
    or GMCP_RETRY_SECONDS
  if lastCode == "gmcp_ire_missing"
      and lastAt > 0
      and (now - lastAt) < throttle then
    return
  end
  stateLifecycle.lastWarningAt = now
  stateLifecycle.lastWarningCode = "gmcp_ire_missing"
  boop.util.warn("gmcp_ire_missing -- GMCP IRE missing")
end

local function requestCoreSupportsThrottled(forceNow)
  if not boop.requestCoreSupports then return false end
  local lifecycle = boop.state and boop.state.lifecycle or nil
  local now = nowSeconds()
  local lastAt = type(lifecycle) == "table"
      and tonumber(lifecycle.lastRetryAt)
    or nil
  if not forceNow and lastAt and lastAt > 0 and (now - lastAt) < GMCP_RETRY_SECONDS then
    return false
  end
  boop.requestCoreSupports({
    requestSkills = true,
    minInterval = 0,
    force = true,
  })
  if type(lifecycle) == "table" then
    lifecycle.lastRetryAt = now
  end
  return true
end

function boop.reconcileIreSupport(source, options)
  options = type(options) == "table" and options or {}
  source = tostring(source or "ire")
  local requestIfMissing = options.requestIfMissing
  if requestIfMissing == nil then
    requestIfMissing = true
  end
  if source == "connection" or options.reset == true then
    boop.runtime.beginConnectionLifecycle(source)
  end
  local before = boop.runtime.lifecycleSnapshot()
  if source == "prompt" then
    boop.runtime.observeLifecyclePrompt(source)
  end
  local lifecycle = boop.runtime.observeLifecycleIre(
    ireReady(),
    source
  )
  if options.supportAlreadyRequested == true then
    boop.state.lifecycle.lastRetryAt = nowSeconds()
  elseif not lifecycle.ireSeen and requestIfMissing then
    requestCoreSupportsThrottled(before.ireSeen ~= false)
  end
  if not lifecycle.ireSeen then
    warnIreReadiness(lifecycle)
  end
  if lifecycle.ready and not before.ready
      and boop.trace and boop.trace.log then
    boop.trace.log(
      "readiness ready: gmcp IRE and prompt observed"
    )
  end
  return lifecycle.ready, lifecycle.ready and not before.ready
end

function boop.onIreSupportObserved(source)
  local ready, becameReady = boop.reconcileIreSupport(
    source or "ire event",
    {
      requestIfMissing = false,
    }
  )
  if becameReady
      and boop.config
      and boop.config.enabled
      and tempTimer then
    local authority = currentRoomSourceAuthority()
    tempTimer(0, function()
      if boop and boop.tick then
        boop.tick(authority or nil, {
          roomOwned = authority and true or false,
        }, "other")
      end
    end)
  end
  return ready
end

local function roomInfoIsPartial(info)
  return not info or not info.num or type(info.exits) ~= "table"
end

local function warnRoomResponseFence(fence, timerId)
  if not (boop.runtime and boop.runtime.timeoutRoomResponseFence)
      or not boop.runtime.timeoutRoomResponseFence(fence.fenceId, timerId) then
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

local function requestRoomItemsForFence(reason, opts)
  if not (runtime() and boop.runtime.beginRoomResponseFence) then
    return false
  end
  local fence = boop.runtime.beginRoomResponseFence(reason, opts)
  if not fence then return false end

  local timerId = false
  if tempTimer then
    timerId = tempTimer(ROOM_RESPONSE_FENCE_WARNING_SECONDS, function()
      warnRoomResponseFence(fence, timerId)
    end)
    boop.runtime.setRoomResponseFenceTimer(fence.fenceId, timerId)
  end

  if sendGMCP and send then
    if not fence.roomOnly then
      sendGmcpRequestWithFlush([[Char.Items.Inv ""]])
    end
    sendGmcpRequestWithFlush([[Char.Items.Room ""]])
  else
    if timerId and killTimer then killTimer(timerId) end
    boop.runtime.setRoomResponseFenceTimer(fence.fenceId, false)
    warnRoomResponseFence(fence, false)
  end
  return fence
end

function boop.requestRoomItemsOnce(reason)
  return requestRoomItemsForFence(reason) and true or false
end

local function denizenNameById(id)
  local wanted = tostring(id or "")
  if wanted == "" or not boop.state or not boop.state.targeting then
    return ""
  end
  for _, denizen in ipairs(boop.state.targeting.denizens or {}) do
    if tostring(denizen.id or "") == wanted then
      return tostring(denizen.name or "")
    end
  end
  return ""
end

local function currentTargetStillInRoom()
  local current = tostring(boop.state and boop.state.targeting and boop.state.targeting.currentTargetId or "")
  return current ~= "" and denizenNameById(current) ~= ""
end

local function warnTargetLost()
  if boop.util and boop.util.warn then
    boop.util.warn("target_lost -- target left room")
  end
end

local function clearLostTargetIntent()
  boop.runtime.clearAttackIntent("target_lost", {
    clearTarget = true,
  })
  if boop.afflictions and boop.afflictions.clearTarget then
    boop.afflictions.clearTarget()
  end
end

local function copyInvItem(item)
  if type(item) ~= "table" then return false end
  return {
    id = tostring(item.id or ""),
    name = tostring(item.name or ""),
    attrib = tostring(item.attrib or ""),
    icon = tostring(item.icon or ""),
  }
end

local function parseWieldAttrib(attrib)
  local text = tostring(attrib or "")
  return text:find("l", 1, true) ~= nil, text:find("L", 1, true) ~= nil
end

local function sameTrackedItem(left, right)
  if not left and not right then return true end
  if not left or not right then return false end
  return tostring(left.id or "") == tostring(right.id or "")
    and tostring(left.name or "") == tostring(right.name or "")
    and tostring(left.attrib or "") == tostring(right.attrib or "")
    and tostring(left.icon or "") == tostring(right.icon or "")
end

local function traceWieldChange(hand, item, reason)
  if not boop.trace or not boop.trace.log then return end
  local label = tostring(hand or "?")
  if item then
    boop.trace.log(string.format(
      "wield %s: %s (%s) | icon=%s%s",
      label,
      tostring(item.name or "?"),
      tostring(item.id or "?"),
      tostring(item.icon or "?"),
      reason and (" | " .. tostring(reason)) or ""
    ))
  else
    boop.trace.log(string.format("wield %s: clear%s", label, reason and (" | " .. tostring(reason)) or ""))
  end
end

local function setWieldedHand(hand, item, reason)
  boop.state = boop.state or {}
  boop.state.inventory = boop.state.inventory or {}
  local key = hand == "left" and "wieldedLeft" or "wieldedRight"
  local nextItem = item and copyInvItem(item) or false
  local current = boop.state.inventory[key]
  if sameTrackedItem(current, nextItem) then
    return
  end
  boop.state.inventory[key] = nextItem
  traceWieldChange(hand, nextItem, reason)
end

local function updateWieldedFromInvItem(item, reason)
  boop.state = boop.state or {}
  boop.state.inventory = boop.state.inventory or {}
  if type(item) ~= "table" then return end
  local tracked = copyInvItem(item)
  local id = tostring(tracked.id or "")
  if id ~= "" then
    boop.state.inventory.itemsById = boop.state.inventory.itemsById or {}
    boop.state.inventory.itemsById[id] = tracked
  end

  local isLeft, isRight = parseWieldAttrib(tracked.attrib)
  local currentLeft = boop.state.inventory.wieldedLeft
  local currentRight = boop.state.inventory.wieldedRight
  if currentLeft and tostring(currentLeft.id or "") == id and not isLeft then
    setWieldedHand("left", false, reason or "attrib cleared")
  end
  if currentRight and tostring(currentRight.id or "") == id and not isRight then
    setWieldedHand("right", false, reason or "attrib cleared")
  end
  if isLeft then
    setWieldedHand("left", tracked, reason)
  end
  if isRight then
    setWieldedHand("right", tracked, reason)
  end
end

local function removeInvItem(item, reason)
  boop.state = boop.state or {}
  boop.state.inventory = boop.state.inventory or {}
  if type(item) ~= "table" then return end
  local id = tostring(item.id or "")
  if id ~= "" and boop.state.inventory.itemsById then
    boop.state.inventory.itemsById[id] = nil
  end
  if boop.state.inventory.wieldedLeft and tostring(boop.state.inventory.wieldedLeft.id or "") == id then
    setWieldedHand("left", false, reason or "removed")
  end
  if boop.state.inventory.wieldedRight and tostring(boop.state.inventory.wieldedRight.id or "") == id then
    setWieldedHand("right", false, reason or "removed")
  end
end

local function rebuildWieldedFromInventory(items, reason)
  boop.state = boop.state or {}
  boop.state.inventory = boop.state.inventory or {}
  boop.state.inventory.itemsById = {}
  local leftItem = false
  local rightItem = false
  if type(items) == "table" then
    for _, item in ipairs(items) do
      local tracked = copyInvItem(item)
      if tracked then
        local id = tostring(tracked.id or "")
        if id ~= "" then
          boop.state.inventory.itemsById[id] = tracked
        end
        local isLeft, isRight = parseWieldAttrib(tracked.attrib)
        if isLeft then leftItem = tracked end
        if isRight then rightItem = tracked end
      end
    end
  end
  setWieldedHand("left", leftItem, reason or "inventory list")
  setWieldedHand("right", rightItem, reason or "inventory list")
end

function boop.getWieldedItem(hand)
  boop.state = boop.state or {}
  boop.state.inventory = boop.state.inventory or {}
  local key = boop.util.safeLower(hand or "") == "right" and "wieldedRight" or "wieldedLeft"
  local item = boop.state.inventory[key]
  if not item then return nil end
  return copyInvItem(item)
end

local startGoldOperation
local transferGoldToPacking
local completeGoldOperation

local function currentGoldOperation(generation, expectedPhase)
  local state = runtime() and boop.runtime.state and boop.runtime.state() or boop.state
  local operation = state and state.gold and state.gold.operation or nil
  if type(operation) ~= "table" or operation.terminal then
    return false
  end
  if generation ~= nil and operation.generation ~= tonumber(generation) then
    return false
  end
  if expectedPhase ~= nil and operation.phase ~= expectedPhase then
    return false
  end
  return operation
end

local function canonicalGoldEvidence(
  observation,
  roomId,
  roomGeneration,
  expectedItemId
)
  if type(observation) ~= "table" then
    return false, nil
  end
  local state = runtime() and boop.runtime.state and boop.runtime.state() or boop.state
  local canonicalRoom = boop.util.trim(tostring(
    state and state.targeting and state.targeting.room or ""
  ))
  local expectedRoom = boop.util.trim(roomId or "")
  local expectedItem = tostring(expectedItemId or "")
  if expectedRoom == ""
      or (canonicalRoom ~= "" and canonicalRoom ~= expectedRoom)
      or tostring(observation.roomId or "") ~= expectedRoom
      or tonumber(observation.generation) ~= tonumber(roomGeneration)
      or observation.infoSeen ~= true
      or observation.itemsSeen ~= true
      or observation.activeFenceId then
    return false, nil
  end
  local goldItem = findRoomGoldItem(
    observation.acceptedItems,
    expectedItem
  )
  return goldItem ~= nil, goldItem
end

local function requestGoldRoomRevalidation(operation, observation)
  local active = currentGoldOperation(
    operation and operation.generation,
    GOLD_PHASE.DEFERRED_ROOM
  )
  if active ~= operation or operation.revalidationAttempted then
    return false
  end
  observation = type(observation) == "table" and observation or {}
  if observation.infoSeen ~= true
      or observation.itemsSeen ~= true
      or observation.activeFenceId
      or tostring(observation.roomId or "") ~= tostring(operation.roomId or "")
      or tonumber(observation.generation) ~= tonumber(operation.roomGeneration)
      or tostring(operation.goldItemId or "") == "" then
    return false
  end

  operation.revalidationAttempted = true
  operation.revalidationFenceId = false
  local fence = requestRoomItemsForFence(
    "gold Add awaiting current room revalidation",
    {
      roomOnly = true,
      roomId = operation.roomId,
      generation = operation.roomGeneration,
      operationGeneration = operation.generation,
    }
  )
  if not fence then
    return false
  end
  operation.revalidationFenceId = fence.fenceId
  return true
end

local function goldDispatchAuthorized(operation)
  local current = currentGoldOperation(
    operation and operation.generation,
    operation and operation.phase
  )
  if current ~= operation then
    return false
  end
  if not boop.config or not boop.config.enabled or not boop.config.autoGrabGold then
    return false
  end
  if not readinessAllows(
      operation.phase ~= GOLD_PHASE.PACK_PENDING
    ) then
    return false
  end
  if operation.awaitingExplicitEvidence then
    return false
  end

  local displacedByOwner = tostring(operation.displacedByOwner or "")
  if operation.replayPending and displacedByOwner ~= "" then
    local state = runtime() and boop.runtime.state and boop.runtime.state() or boop.state
    local blocker = state
      and state.combat
      and state.combat.blockersByOwner
      and state.combat.blockersByOwner[displacedByOwner]
      or nil
    if type(blocker) == "table" and tostring(blocker.code or "") ~= "" then
      return false
    end
  end

  local owner = tostring(operation.blockerOwner or "")
  if operation.phase == GOLD_PHASE.PACK_PENDING then
    if operationHolds("queue", owner)
        or operationHolds("gold", owner) then
      return false
    end
    return boop.util.trim(operation.packTarget or "") ~= ""
  end

  if operationHolds("combat", owner)
      or operationHolds("queue", owner)
      or operationHolds("gold", owner)
      or operationHolds("walk", owner) then
    return false
  end

  local observation = runtime()
    and boop.runtime.roomObservationSnapshot
    and boop.runtime.roomObservationSnapshot()
    or {}
  if operation.phase ~= GOLD_PHASE.DEFERRED_ROOM
      and operation.phase ~= GOLD_PHASE.PICKUP_PENDING then
    return false
  end
  local expectedItem = tostring(operation.goldItemId or "")
  if expectedItem == "" then
    return false
  end
  return canonicalGoldEvidence(
    observation,
    operation.roomId,
    operation.roomGeneration,
    expectedItem
  )
end

function boop.clearGoldQueueIntent()
  local state = runtime() and boop.runtime.state and boop.runtime.state() or boop.state
  if runtime() and boop.runtime.resolvePackQuarantine then
    boop.runtime.resolvePackQuarantine("disabled")
  end
  local operation = state and state.gold and state.gold.operation or nil
  if type(operation) == "table" and not operation.terminal then
    return completeGoldOperation(operation.generation, "disabled")
  end
  if state and state.gold then
    if state.gold.autoGrabTimer and killTimer then
      killTimer(state.gold.autoGrabTimer)
    end
    if state.gold.pendingTimer and killTimer then
      killTimer(state.gold.pendingTimer)
    end
    state.gold.autoGrabPending = false
    state.gold.autoGrabPendingAt = nil
    state.gold.autoGrabTimer = nil
    state.gold.getPending = false
    state.gold.putPending = false
    state.gold.getRetries = 0
    state.gold.putRetries = 0
    state.gold.packTarget = ""
    state.gold.pendingTimer = nil
    state.gold.dropped = false
  end
  return false
end

local function stopGoldPendingTimeout()
  local operation = currentGoldOperation()
  if not operation then return false end
  local timerId = operation.timeoutTimer
  operation.timeoutTimer = false
  if timerId and killTimer then
    killTimer(timerId)
  end
  boop.markGoldQueueIntent(operation.packTarget)
  return timerId and true or false
end

local function setGoldEvidenceWaitBlocker(operation)
  if operation.phase == GOLD_PHASE.PICKUP_PENDING then
    return setOperationLock(
      operation.blockerOwner,
      "gold_pickup_pending",
      "gold pickup awaiting explicit evidence; move or disable/flee to cancel",
      {
        combat = true,
        queue = true,
        gold = true,
        walk = true,
      },
      {
        gold_get = true,
        movement = true,
        disabled = true,
        flee = true,
      },
      {
        source = operation.source,
        observed = {
          generation = operation.generation,
          room = operation.roomId,
          roomGeneration = operation.roomGeneration,
          goldItem = operation.goldItemId,
          dispatch = operation.dispatchId,
        },
      }
    )
  end

  return setOperationLock(
    operation.blockerOwner,
    "gold_pack_pending",
    "gold packing awaiting explicit evidence; provide result/failure or disable/flee to cancel",
    {
      combat = true,
      queue = true,
      gold = true,
      walk = true,
    },
    {
      gold_put = true,
      gold_failure = true,
      disabled = true,
      flee = true,
    },
    {
      source = operation.source,
      observed = {
        generation = operation.generation,
        inventory = true,
        pack = operation.packTarget,
        dispatch = operation.dispatchId,
      },
    }
  )
end

local function setGoldDispatchBlocker(operation)
  if operation.phase == GOLD_PHASE.PICKUP_PENDING then
    return setOperationLock(
      operation.blockerOwner,
      "gold_pickup_pending",
      "gold pickup pending",
      {
        combat = true,
        queue = true,
        gold = true,
        walk = true,
      },
      {
        gold_get = true,
      },
      {
        source = operation.source,
        observed = {
          generation = operation.generation,
          room = operation.roomId,
          roomGeneration = operation.roomGeneration,
          goldItem = operation.goldItemId,
        },
      }
    )
  end

  return setOperationLock(
    operation.blockerOwner,
    "gold_pack_pending",
    "gold packing pending",
    {
      combat = true,
      queue = true,
      gold = true,
      walk = true,
    },
    {
      gold_put = true,
    },
    {
      source = operation.source,
      observed = {
        generation = operation.generation,
        inventory = true,
        pack = operation.packTarget,
      },
    }
  )
end

local function armGoldPendingTimeout(
  generation,
  expectedPhase,
  expectedDispatchId,
  dispatchProvenance
)
  local operation = currentGoldOperation(generation, expectedPhase)
  if not operation or not tempTimer then
    return false
  end
  if expectedPhase == GOLD_PHASE.PICKUP_PENDING
      and operation.awaitingQueueExecution then
    return false
  end
  expectedDispatchId = tonumber(expectedDispatchId)
    or tonumber(operation.dispatchId)
    or 0
  dispatchProvenance = tostring(
    dispatchProvenance or operation.dispatchProvenance or "initial"
  )
  stopGoldPendingTimeout()
  operation = currentGoldOperation(generation, expectedPhase)
  if not operation then return false end

  local timerId = false
  timerId = tempTimer(4, function()
    local active = currentGoldOperation(generation, expectedPhase)
    if not active
        or active.timeoutTimer ~= timerId
        or tonumber(active.dispatchId) ~= tonumber(expectedDispatchId) then
      return
    end
    active.timeoutTimer = false
    boop.markGoldQueueIntent(active.packTarget)
    if dispatchProvenance == "displacement_replay" then
      if active.phase == GOLD_PHASE.PACK_PENDING then
        local quarantine = false
        if runtime() and boop.runtime.createPackQuarantine then
          quarantine = boop.runtime.createPackQuarantine(active)
        end
        if not quarantine then
          active.awaitingExplicitEvidence = true
          setGoldEvidenceWaitBlocker(active)
          return
        end
        if tonumber(active.replayWarningDispatchId) ~= tonumber(expectedDispatchId) then
          active.replayWarningDispatchId = expectedDispatchId
          boop.trace.log(string.format(
            "gold replay timeout: pack released to quarantine | generation=%s | dispatch=%s",
            tostring(generation),
            tostring(expectedDispatchId)
          ))
          boop.util.warn(
            "auto gold: replayed pack timed out; releases now and will retry only after later safe gold evidence"
          )
        end
        completeGoldOperation(generation, "pack_replay_quarantined")
        return
      end

      active.awaitingExplicitEvidence = true
      setGoldEvidenceWaitBlocker(active)
      if tonumber(active.replayWarningDispatchId) ~= tonumber(expectedDispatchId) then
        active.replayWarningDispatchId = expectedDispatchId
        boop.trace.log(string.format(
          "gold replay timeout: pickup awaiting explicit evidence | generation=%s | dispatch=%s",
          tostring(generation),
          tostring(expectedDispatchId)
        ))
        boop.util.warn(
          "auto gold: replayed pickup timed out; move or disable/flee to cancel"
        )
      end
      boop.markGoldQueueIntent(active.packTarget)
      return
    end
    if not goldDispatchAuthorized(active) then
      return
    end
    boop.trace.log("gold pending timeout: clearing stale state")
    boop.util.warn("auto gold: clearing stale pending state")
    completeGoldOperation(generation, "pending_timeout")
  end)
  operation.timeoutTimer = timerId or false
  boop.markGoldQueueIntent(operation.packTarget)
  return operation.timeoutTimer
end

function boop.markGoldQueueIntent(_)
  local state = runtime() and boop.runtime.state and boop.runtime.state() or boop.state
  if not state or not state.gold then return false end
  local operation = currentGoldOperation()
  if not operation then
    state.gold.autoGrabPending = false
    state.gold.autoGrabPendingAt = nil
    state.gold.autoGrabTimer = nil
    state.gold.getPending = false
    state.gold.putPending = false
    state.gold.getRetries = 0
    state.gold.putRetries = 0
    state.gold.packTarget = ""
    state.gold.pendingTimer = nil
    state.gold.dropped = false
    return false
  end

  state.gold.autoGrabPending = operation.phase == GOLD_PHASE.DEFERRED_ROOM
  state.gold.autoGrabPendingAt = state.gold.autoGrabPending
    and (state.gold.autoGrabPendingAt or nowSeconds())
    or nil
  state.gold.autoGrabTimer = operation.flushTimer or nil
  state.gold.getPending = operation.phase == GOLD_PHASE.PICKUP_PENDING
  state.gold.putPending = operation.phase == GOLD_PHASE.PACK_PENDING
  state.gold.getRetries = tonumber(operation.getRetries) or 0
  state.gold.putRetries = tonumber(operation.putRetries) or 0
  state.gold.packTarget = tostring(operation.packTarget or "")
  state.gold.pendingTimer = operation.timeoutTimer or nil
  state.gold.dropped = operation.phase ~= GOLD_PHASE.PACK_PENDING
  return operation
end

local function queueGoldCommands()
  local operation = currentGoldOperation()
  if not operation
      or operation.timeoutTimer
      or operation.awaitingQueueExecution
      or operation.awaitingExplicitEvidence
      or not goldDispatchAuthorized(operation) then
    return false
  end
  local displacementReplay = operation.replayPending == true
  local provenance = displacementReplay
    and "displacement_replay"
    or "initial"
  operation.dispatchId = (tonumber(operation.dispatchId) or 0) + 1
  operation.dispatchProvenance = provenance
  operation.awaitingExplicitEvidence = false
  local nativeCommand = ""
  local wireCommand = ""
  local queued = false
  if operation.phase == GOLD_PHASE.PICKUP_PENDING then
    nativeCommand = "get sovereigns"
    queued, wireCommand = queueGoldCommand(
      GOLD_PICKUP_QUEUE,
      nativeCommand
    )
    boop.trace.log(string.format(
      "gold queue: get sovereigns | generation=%s | room=%s",
      tostring(operation.generation),
      tostring(operation.roomId)
    ))
    operation.awaitingQueueExecution = true
    operation.executionReadyPrompt = false
  elseif operation.phase == GOLD_PHASE.PACK_PENDING then
    local pack = boop.util.trim(operation.packTarget or "")
    if pack == "" then return false end
    nativeCommand = "put sovereigns in " .. pack
    queued, wireCommand = queueGoldCommand(
      GOLD_PACK_QUEUE,
      nativeCommand
    )
    boop.trace.log(string.format(
      "gold queue: put sovereigns in %s | generation=%s",
      pack,
      tostring(operation.generation)
    ))
    operation.awaitingQueueExecution = false
    operation.executionReadyPrompt = false
  else
    return false
  end
  if not queued then
    return false
  end
  operation.nativeCommand = nativeCommand
  operation.wireCommand = wireCommand
  local outbound = runtime()
    and boop.runtime.outboundSnapshot
    and boop.runtime.outboundSnapshot()
    or {}
  operation.outboundSequence = tonumber(outbound.sequence) or 0
  if displacementReplay then
    operation.replayPending = false
    operation.displacedByOwner = nil
    operation.displacedPhase = nil
    operation.displacedDispatchId = nil
  end
  if operation.phase == GOLD_PHASE.PICKUP_PENDING then
    boop.markGoldQueueIntent(operation.packTarget)
  else
    armGoldPendingTimeout(
      operation.generation,
      operation.phase,
      operation.dispatchId,
      provenance
    )
  end
  return true
end

function boop.displaceGoldQueueIntent(interruptOwner, reason)
  local operation = currentGoldOperation()
  local owner = tostring(interruptOwner or "")
  local pickupAwaitingExecution = operation
    and operation.phase == GOLD_PHASE.PICKUP_PENDING
    and operation.awaitingQueueExecution == true
  if not operation
      or owner == ""
      or operation.awaitingExplicitEvidence
      or operation.replayPending
      or (not operation.timeoutTimer and not pickupAwaitingExecution)
      or (operation.phase ~= GOLD_PHASE.PICKUP_PENDING
        and operation.phase ~= GOLD_PHASE.PACK_PENDING) then
    return false
  end

  local state = runtime() and boop.runtime.state and boop.runtime.state() or boop.state
  local blocker = state
    and state.combat
    and state.combat.blockersByOwner
    and state.combat.blockersByOwner[owner]
    or nil
  if type(blocker) ~= "table" or tostring(blocker.code or "") == "" then
    return false
  end

  local displacedTimer = operation.timeoutTimer
  operation.timeoutTimer = false
  if displacedTimer and killTimer then
    killTimer(displacedTimer)
  end
  operation.displacedByOwner = owner
  operation.displacedPhase = operation.phase
  operation.displacedDispatchId = operation.dispatchId
  operation.replayPending = true
  operation.awaitingExplicitEvidence = false
  operation.awaitingQueueExecution = false
  operation.executionReadyPrompt = false
  boop.markGoldQueueIntent(operation.packTarget)
  boop.trace.log(string.format(
    "gold dispatch displaced: %s | generation=%s | phase=%s | dispatch=%s | interrupt=%s | reason=%s",
    tostring(operation.blockerOwner),
    tostring(operation.generation),
    tostring(operation.phase),
    tostring(operation.dispatchId),
    owner,
    tostring(reason or "native queue replacement")
  ))
  return true
end

local cancelAutoGrabGoldTimer
local flushPendingGold

cancelAutoGrabGoldTimer = function()
  local operation = currentGoldOperation()
  if not operation then return false end
  local timerId = operation.flushTimer
  operation.flushTimer = false
  if timerId and killTimer then
    killTimer(timerId)
  end
  boop.markGoldQueueIntent(operation.packTarget)
  return timerId and true or false
end

completeGoldOperation = function(generation, terminalReason)
  local operation = currentGoldOperation(generation)
  if not operation then return false end

  operation.terminal = true
  local reason = tostring(terminalReason or "")
  local owner = tostring(operation.blockerOwner or "")
  local flushTimer = operation.flushTimer
  local timeoutTimer = operation.timeoutTimer
  operation.flushTimer = false
  operation.timeoutTimer = false
  if flushTimer and killTimer then killTimer(flushTimer) end
  if timeoutTimer and killTimer then killTimer(timeoutTimer) end
  if runtime() and boop.runtime.clearOperationLock then
    boop.runtime.clearOperationLock(owner, reason)
  end

  local state = runtime() and boop.runtime.state and boop.runtime.state() or boop.state
  state.gold.operation = false
  boop.markGoldQueueIntent()
  boop.trace.log(string.format(
    "gold terminal: %s | generation=%s | reason=%s",
    owner,
    tostring(generation),
    reason
  ))
  if tempTimer then
    tempTimer(0, function()
      local active = currentGoldOperation()
      if active and tonumber(active.generation) > tonumber(generation) then
        return
      end
      if boop and boop.tick then
        boop.tick(nil, nil, "other")
      end
    end)
  end
  return true
end

local function createGoldOperation(source, observation, packTarget, phase, goldItemId)
  local state = runtime() and boop.runtime.state and boop.runtime.state() or boop.state
  observation = type(observation) == "table" and observation or {}
  state.gold.generation = (tonumber(state.gold.generation) or 0) + 1
  local generation = state.gold.generation
  local operation = {
    generation = generation,
    phase = phase,
    terminal = false,
    blockerOwner = "gold:" .. tostring(generation),
    source = tostring(source or "gold detected"),
    roomId = tostring(observation.roomId or ""),
    roomGeneration = tonumber(observation.generation) or 0,
    goldItemId = tostring(goldItemId or ""),
    packTarget = boop.util.trim(packTarget or ""),
    getRetries = 0,
    putRetries = 0,
    flushTimer = false,
    timeoutTimer = false,
    dispatchId = 0,
    dispatchProvenance = false,
    displacedByOwner = nil,
    displacedPhase = nil,
    displacedDispatchId = nil,
    replayPending = false,
    awaitingExplicitEvidence = false,
    awaitingQueueExecution = false,
    executionReadyPrompt = false,
    replayWarningDispatchId = false,
    nativeCommand = "",
    wireCommand = "",
    outboundSequence = 0,
    revalidationAttempted = false,
    revalidationFenceId = false,
    sourceAuthority = copySourceAuthority(observation.sourceAuthority),
  }
  state.gold.operation = operation
  return operation
end

startGoldOperation = function(source, observation, packTarget)
  if not boop.config or not boop.config.enabled or not boop.config.autoGrabGold then
    return false
  end
  local state = runtime() and boop.runtime.state and boop.runtime.state() or boop.state
  observation = observation or (
    runtime()
      and boop.runtime.roomObservationSnapshot
      and boop.runtime.roomObservationSnapshot()
      or {}
  )
  local roomId = tostring(observation.roomId or "")
  local roomGeneration = tonumber(observation.generation) or 0
  local operation = currentGoldOperation()
  local canonicalRoom = boop.util.trim(tostring(
    state and state.targeting and state.targeting.room or ""
  ))
  if roomId ~= "" and canonicalRoom ~= "" and roomId ~= canonicalRoom then
    return false
  end
  local requestedItemId = tostring(observation.goldItemId or "")
  local operationItemId = operation
    and tostring(operation.goldItemId or "")
    or ""
  local expectedItemId = operationItemId ~= ""
    and operationItemId
    or requestedItemId
  local evidenceComplete, currentGoldItem = canonicalGoldEvidence(
    observation,
    roomId,
    roomGeneration,
    expectedItemId
  )

  if operation then
    if operation.phase == GOLD_PHASE.PACK_PENDING then
      return operation
    end
    if tostring(operation.roomId or "") ~= roomId
        or tonumber(operation.roomGeneration) ~= roomGeneration then
      completeGoldOperation(operation.generation, "room_changed")
      operation = false
    elseif operation.phase == GOLD_PHASE.DEFERRED_ROOM
        and evidenceComplete
        and currentGoldItem
        and (tostring(operation.goldItemId or "") == ""
          or tostring(operation.goldItemId or "") == tostring(currentGoldItem.id or "")) then
      cancelAutoGrabGoldTimer()
      stopGoldPendingTimeout()
      operation.phase = GOLD_PHASE.PICKUP_PENDING
      operation.goldItemId = tostring(currentGoldItem.id or observation.goldItemId or "")
      operation.flushTimer = false
      operation.timeoutTimer = false
      setOperationLock(operation.blockerOwner, "gold_pickup_pending", "gold pickup pending", {
        combat = true,
        queue = true,
        gold = true,
        walk = true,
      }, {
        gold_get = true,
      }, {
        source = operation.source,
        observed = {
          generation = operation.generation,
          room = operation.roomId,
          roomGeneration = operation.roomGeneration,
          goldItem = operation.goldItemId,
        },
      })
      boop.markGoldQueueIntent(operation.packTarget)
      return operation
    else
      if operation.phase == GOLD_PHASE.DEFERRED_ROOM
          and tostring(operation.goldItemId or "") == ""
          and requestedItemId ~= "" then
        operation.goldItemId = requestedItemId
      end
      return operation
    end
  end

  local phase = evidenceComplete and currentGoldItem
    and GOLD_PHASE.PICKUP_PENDING
    or GOLD_PHASE.DEFERRED_ROOM
  operation = createGoldOperation(
    source,
    observation,
    packTarget,
    phase,
    currentGoldItem and currentGoldItem.id or requestedItemId
  )
  local generation = operation.generation

  if phase == GOLD_PHASE.DEFERRED_ROOM then
    setOperationLock(operation.blockerOwner, "gold_deferred_room", "gold awaiting room evidence", {
      combat = true,
      queue = true,
      gold = true,
      walk = true,
    }, {
      gmcp = true,
    }, {
      source = operation.source,
      observed = {
        generation = generation,
        room = roomId,
        roomGeneration = roomGeneration,
        items = not not observation.itemsSeen,
      },
    })
    boop.markGoldQueueIntent(operation.packTarget)
    if boop.requestRoomItemsOnce then
      boop.requestRoomItemsOnce("gold awaiting complete room evidence")
    end
    if tempTimer then
      local timerId = false
      timerId = tempTimer(AUTO_GOLD_FLUSH_SECONDS, function()
        local active = currentGoldOperation(generation, GOLD_PHASE.DEFERRED_ROOM)
        if not active or active.flushTimer ~= timerId then
          return
        end
        active.flushTimer = false
        boop.markGoldQueueIntent(active.packTarget)
        if boop.maybeFlushPendingGold then
          boop.maybeFlushPendingGold("gold evidence fallback")
        end
      end)
      operation.flushTimer = timerId or false
    end
    armGoldPendingTimeout(generation, GOLD_PHASE.DEFERRED_ROOM)
  else
    setOperationLock(operation.blockerOwner, "gold_pickup_pending", "gold pickup pending", {
      combat = true,
      queue = true,
      gold = true,
      walk = true,
    }, {
      gold_get = true,
    }, {
      source = operation.source,
      observed = {
        generation = generation,
        room = roomId,
        roomGeneration = roomGeneration,
        goldItem = operation.goldItemId,
      },
    })
    boop.markGoldQueueIntent(operation.packTarget)
    queueGoldCommands()
  end
  return operation
end

transferGoldToPacking = function(generation)
  local operation = currentGoldOperation(generation, GOLD_PHASE.PICKUP_PENDING)
  if not operation then return false end
  stopGoldPendingTimeout()
  operation = currentGoldOperation(generation, GOLD_PHASE.PICKUP_PENDING)
  if not operation then return false end

  operation.phase = GOLD_PHASE.PACK_PENDING
  operation.roomId = ""
  operation.roomGeneration = 0
  operation.goldItemId = ""
  operation.getRetries = 0
  operation.putRetries = 0
  operation.flushTimer = false
  operation.timeoutTimer = false
  operation.dispatchProvenance = false
  operation.displacedByOwner = nil
  operation.displacedPhase = nil
  operation.displacedDispatchId = nil
  operation.replayPending = false
  operation.awaitingExplicitEvidence = false
  operation.awaitingQueueExecution = false
  operation.executionReadyPrompt = false
  operation.replayWarningDispatchId = false
  operation.nativeCommand = ""
  operation.wireCommand = ""
  operation.outboundSequence = 0
  if boop.util.trim(operation.packTarget or "") == "" then
    return completeGoldOperation(generation, "get_success_no_pack")
  end

  setOperationLock(operation.blockerOwner, "gold_pack_pending", "gold packing pending", {
    combat = true,
    queue = true,
    gold = true,
    walk = true,
  }, {
    gold_put = true,
  }, {
    source = operation.source,
    observed = {
      generation = generation,
      inventory = true,
      pack = operation.packTarget,
    },
  })
  boop.markGoldQueueIntent(operation.packTarget)
  queueGoldCommands()
  return true
end

local function inventoryContainsSovereigns(items)
  if type(items) ~= "table" then
    return false
  end
  for _, item in ipairs(items) do
    if isGoldItem(item) then
      return true
    end
  end
  return false
end

function boop.tryPackQuarantinedGold(source)
  if not (runtime()
      and boop.runtime.packQuarantineSnapshot
      and boop.runtime.consumePackQuarantine) then
    return false
  end
  local quarantine = boop.runtime.packQuarantineSnapshot()
  if type(quarantine) ~= "table"
      or quarantine.resolved
      or quarantine.consumed
      or not quarantine.eligible then
    return false
  end
  if not boop.config
      or not boop.config.enabled
      or not boop.config.autoGrabGold then
    return false
  end
  local pack = boop.util.trim(boop.config.goldPack or "")
  if pack == "" or currentGoldOperation() then
    return false
  end

  local state = boop.runtime.state()
  local inventory = state.inventory or {}
  local inventoryGeneration = tonumber(inventory.generation) or 0
  if inventoryGeneration
        ~= tonumber(quarantine.qualifyingInventoryGeneration)
      or not inventoryContainsSovereigns(inventory.completeItems) then
    return false
  end
  if not readinessAllows(false)
      or state.diag.hold
      or state.gold.getPending
      or state.gold.putPending
      or (boop.runtime.standardPending
        and boop.runtime.standardPending())
      or (boop.runtime.standardRecoveryPending
        and boop.runtime.standardRecoveryPending())
      or (boop.runtime.shouldHold
        and boop.runtime.shouldHold("combat"))
      or (boop.runtime.shouldHold
        and boop.runtime.shouldHold("queue"))
      or (boop.runtime.shouldHold
        and boop.runtime.shouldHold("gold"))
      or (boop.runtime.shouldHold
        and boop.runtime.shouldHold("walk")) then
    return false
  end

  local consumed = boop.runtime.consumePackQuarantine(
    quarantine.oldGeneration,
    inventoryGeneration,
    tostring(source or "safe gold opportunity")
  )
  if not consumed then
    return false
  end

  local operation = createGoldOperation(
    tostring(source or "quarantined gold repack"),
    {},
    pack,
    GOLD_PHASE.PACK_PENDING,
    ""
  )
  setGoldDispatchBlocker(operation)
  boop.markGoldQueueIntent(operation.packTarget)
  return queueGoldCommands()
end

local function clearPendingGoldDrop(reason)
  local operation = currentGoldOperation()
  if not operation then return false end
  if reason then
    boop.trace.log(string.format(
      "gold room item removed while %s: %s",
      tostring(operation.phase),
      tostring(reason)
    ))
  end
  return true
end

local function maybeFlushPendingGold(reason)
  local operation = currentGoldOperation()
  if not operation then
    return false
  end
  if operation.phase == GOLD_PHASE.DEFERRED_ROOM then
    if boop.requestRoomItemsOnce then
      boop.requestRoomItemsOnce(reason or "gold awaiting room evidence")
    end
    return false
  end
  if operation.timeoutTimer or operation.awaitingExplicitEvidence then
    return false
  end
  if operation.awaitingQueueExecution then
    return false
  end
  return flushPendingGold(reason or "gold stage ready")
end

local function onGoldDetected(source, item, opts)
  if not boop.config.enabled or not boop.config.autoGrabGold then return end
  opts = type(opts) == "table" and opts or {}
  local observation = runtime()
    and boop.runtime.roomObservationSnapshot
    and boop.runtime.roomObservationSnapshot()
    or {}
  observation.goldItemId = tostring(item and item.id or "")
  observation.sourceAuthority = copySourceAuthority(opts.sourceAuthority)
  boop.trace.log("gold drop detected" .. (source and (": " .. source) or ""))
  local operation = startGoldOperation(
    source,
    observation,
    boop.util.trim(boop.config.goldPack or "")
  )
  if opts.revalidateSettledAdd then
    requestGoldRoomRevalidation(operation, observation)
  end
  return operation
end

flushPendingGold = function(reason)
  local operation = currentGoldOperation()
  if not operation then return false end
  if operation.phase == GOLD_PHASE.DEFERRED_ROOM then
    return maybeFlushPendingGold(reason)
  end
  if operation.timeoutTimer
      or operation.awaitingQueueExecution
      or operation.awaitingExplicitEvidence then
    return false
  end
  if not goldDispatchAuthorized(operation) then
    traceHeld("gold", reason or "pending flush")
    return false
  end
  cancelAutoGrabGoldTimer()
  boop.trace.log("gold pending flush: " .. tostring(reason or "unspecified"))
  return queueGoldCommands()
end

boop.flushPendingGold = flushPendingGold
boop.maybeFlushPendingGold = maybeFlushPendingGold

local function autoGrabRoomItem(item, opts)
  if not isGoldItem(item) then return end
  opts = type(opts) == "table" and opts or {}
  onGoldDetected(
    opts.source or "gmcp room item",
    item,
    opts
  )
end

function boop.onGoldDropLine(rawLine)
  local line = boop.util.safeLower(boop.util.trim(rawLine or ""))
  if line == "" or not line:find("sovereign", 1, true) then return end
  onGoldDetected("text line")
end

function boop.onGoldDirectPickup(rawLine)
  if not boop.config
      or not boop.config.enabled
      or not boop.config.autoGrabGold then
    return false
  end

  local line = boop.util.safeLower(boop.util.trim(rawLine or ""))
  if not line:find("sovereign", 1, true)
      or line:sub(-#GOLD_DIRECT_PICKUP_SUFFIX) ~= GOLD_DIRECT_PICKUP_SUFFIX then
    return false
  end

  local quarantine = runtime()
    and boop.runtime.packQuarantineSnapshot
    and boop.runtime.packQuarantineSnapshot()
    or false
  if type(quarantine) == "table"
      and not quarantine.resolved
      and not quarantine.consumed then
    local active = currentGoldOperation()
    if active and active.phase ~= GOLD_PHASE.PACK_PENDING then
      completeGoldOperation(
        active.generation,
        "direct_pickup_quarantine_opportunity"
      )
      active = false
    end
    if not active and quarantine.eligible then
      return boop.tryPackQuarantinedGold("direct sovereign pickup")
    end
    boop.trace.log(
      "gold direct pickup observed while old pack quarantine awaits newer inventory"
    )
    return true
  end

  local operation = currentGoldOperation()
  if operation and operation.phase == GOLD_PHASE.PACK_PENDING then
    boop.trace.log("gold direct pickup coalesced: packing already pending")
    return true
  end

  if operation and operation.phase == GOLD_PHASE.DEFERRED_ROOM then
    cancelAutoGrabGoldTimer()
    stopGoldPendingTimeout()
    operation = currentGoldOperation(operation.generation, GOLD_PHASE.DEFERRED_ROOM)
    if not operation then return false end
    operation.phase = GOLD_PHASE.PICKUP_PENDING
  elseif operation and operation.phase ~= GOLD_PHASE.PICKUP_PENDING then
    return false
  end

  if not operation then
    operation = createGoldOperation(
      "direct sovereign pickup",
      {},
      boop.config.goldPack,
      GOLD_PHASE.PICKUP_PENDING,
      ""
    )
  end

  boop.trace.log(string.format(
    "gold direct pickup: inventory confirmed | generation=%s",
    tostring(operation.generation)
  ))
  return transferGoldToPacking(operation.generation)
end

local function retryGoldGet(reason)
  local operation = currentGoldOperation(nil, GOLD_PHASE.PICKUP_PENDING)
  if not operation then return false end
  local wasAwaitingEvidence = operation.awaitingExplicitEvidence == true
  operation.awaitingExplicitEvidence = false
  if not goldDispatchAuthorized(operation) then
    operation.awaitingExplicitEvidence = wasAwaitingEvidence
    return false
  end
  local retries = tonumber(operation.getRetries) or 0
  if retries >= 2 then
    boop.trace.log("gold get failed; giving up: " .. tostring(reason))
    boop.util.err("auto gold: unable to get sovereigns; check room loot/line timing")
    return completeGoldOperation(operation.generation, "get_retry_exhausted")
  end
  stopGoldPendingTimeout()
  operation = currentGoldOperation(operation.generation, GOLD_PHASE.PICKUP_PENDING)
  if not operation or not goldDispatchAuthorized(operation) then return false end
  operation.awaitingExplicitEvidence = false
  operation.replayWarningDispatchId = false
  operation.dispatchId = (tonumber(operation.dispatchId) or 0) + 1
  operation.dispatchProvenance = "retry"
  setGoldDispatchBlocker(operation)
  queueGoldCommand(GOLD_PICKUP_QUEUE, "get sovereigns")
  operation.getRetries = retries + 1
  operation.awaitingQueueExecution = true
  operation.executionReadyPrompt = false
  boop.markGoldQueueIntent(operation.packTarget)
  boop.trace.log("gold get retry " .. tostring(operation.getRetries) .. ": " .. tostring(reason))
  return true
end

local function retryGoldPut(reason)
  local operation = currentGoldOperation(nil, GOLD_PHASE.PACK_PENDING)
  if not operation then return false end
  local wasAwaitingEvidence = operation.awaitingExplicitEvidence == true
  operation.awaitingExplicitEvidence = false
  if not goldDispatchAuthorized(operation) then
    operation.awaitingExplicitEvidence = wasAwaitingEvidence
    return false
  end
  local pack = boop.util.trim(operation.packTarget or "")
  if pack == "" then
    return completeGoldOperation(operation.generation, "put_retry_exhausted")
  end
  local retries = tonumber(operation.putRetries) or 0
  if retries >= 1 then
    boop.trace.log("gold put failed for pack " .. pack .. "; giving up: " .. tostring(reason))
    boop.util.err("auto gold: unable to put sovereigns in " .. pack .. "; use `boop pack test`")
    return completeGoldOperation(operation.generation, "put_retry_exhausted")
  end
  stopGoldPendingTimeout()
  operation = currentGoldOperation(operation.generation, GOLD_PHASE.PACK_PENDING)
  if not operation or not goldDispatchAuthorized(operation) then return false end
  operation.awaitingExplicitEvidence = false
  operation.replayWarningDispatchId = false
  operation.dispatchId = (tonumber(operation.dispatchId) or 0) + 1
  operation.dispatchProvenance = "retry"
  setGoldDispatchBlocker(operation)
  queueGoldCommand(GOLD_PACK_QUEUE, "put sovereigns in " .. pack)
  operation.putRetries = retries + 1
  boop.markGoldQueueIntent(operation.packTarget)
  armGoldPendingTimeout(
    operation.generation,
    operation.phase,
    operation.dispatchId,
    operation.dispatchProvenance
  )
  boop.trace.log("gold put retry " .. tostring(operation.putRetries) .. " for " .. pack .. ": " .. tostring(reason))
  return true
end

function boop.onGoldGetSuccess()
  local operation = currentGoldOperation(nil, GOLD_PHASE.PICKUP_PENDING)
  if not operation then return false end
  boop.trace.log("gold get success")
  local quarantine = runtime()
    and boop.runtime.packQuarantineSnapshot
    and boop.runtime.packQuarantineSnapshot()
    or false
  if type(quarantine) == "table"
      and not quarantine.resolved
      and not quarantine.consumed then
    local completed = completeGoldOperation(
      operation.generation,
      "get_success_quarantine_opportunity"
    )
    if quarantine.eligible then
      boop.tryPackQuarantinedGold("confirmed sovereign pickup")
    end
    return completed
  end
  return transferGoldToPacking(operation.generation)
end

function boop.onGoldPutSuccess()
  local operation = currentGoldOperation(nil, GOLD_PHASE.PACK_PENDING)
  if not operation then
    if runtime() and boop.runtime.notePackQuarantineActivity then
      boop.runtime.notePackQuarantineActivity("old put success")
    end
    return false
  end
  boop.trace.log("gold put success")
  return completeGoldOperation(operation.generation, "put_success")
end

function boop.onGoldCommandFailure(line)
  local operation = currentGoldOperation()
  if not operation then
    if runtime() and boop.runtime.notePackQuarantineActivity then
      boop.runtime.notePackQuarantineActivity("old put failure")
    end
    return false
  end
  local reason = boop.util.trim(line or "")
  if operation.phase == GOLD_PHASE.PICKUP_PENDING then
    return retryGoldGet(reason)
  end
  if operation.phase == GOLD_PHASE.PACK_PENDING then
    return retryGoldPut(reason)
  end
  return false
end

local function reconcileGoldPickupPrompt(fullReady)
  local operation = currentGoldOperation(nil, GOLD_PHASE.PICKUP_PENDING)
  if not operation
      or not operation.awaitingQueueExecution
      or operation.replayPending
      or operation.awaitingExplicitEvidence
      or fullReady ~= true
      or not goldDispatchAuthorized(operation) then
    return false
  end

  operation.awaitingQueueExecution = false
  operation.executionReadyPrompt = true
  local timerId = armGoldPendingTimeout(
    operation.generation,
    operation.phase,
    operation.dispatchId,
    operation.dispatchProvenance
  )
  if boop.trace and boop.trace.log then
    boop.trace.log(string.format(
      "gold pickup execution ready: generation=%s | dispatch=%s | provenance=%s",
      tostring(operation.generation),
      tostring(operation.dispatchId),
      tostring(operation.dispatchProvenance or "initial")
    ))
  end
  return timerId and true or false
end

function boop.onDiagReadyLine()
  return boop.runtime.markOldestDiagEvidenceResult("text")
end

function boop.onDiagAfflictionsList()
  if not gmcp
      or not gmcp.Char
      or not gmcp.Char.Afflictions
      or type(gmcp.Char.Afflictions.List) ~= "table" then
    return false
  end
  return boop.runtime.markOldestDiagEvidenceResult("gmcp")
end

function boop.tryVenomConfusionDiag(source)
  local state = boop.runtime.state()
  local count = tonumber(state.diag.venomConfusionCount) or 0
  if count < 2 then
    return false
  end

  local operation = state.diag.operation
  if type(operation) == "table" and not operation.terminal then
    boop.trace.log(string.format(
      "venom confusion diagnose deferred: active=%s | count=%d | source=%s",
      tostring(operation.name or "interrupt"),
      count,
      tostring(source or "line")
    ))
    return false
  end

  if not (boop.ui and boop.ui.diag) then
    boop.trace.log("venom confusion diagnose unavailable")
    return false
  end

  local queued = boop.ui.diag() == true
  boop.trace.log(string.format(
    "venom confusion diagnose: %s | count=%d | source=%s",
    queued and "queued" or "not queued",
    count,
    tostring(source or "line")
  ))
  return queued
end

function boop.onVenomConfusionLine()
  local state = boop.runtime.state()
  local count = math.min(
    2,
    (tonumber(state.diag.venomConfusionCount) or 0) + 1
  )
  state.diag.venomConfusionCount = count
  boop.trace.log(string.format(
    "venom confusion observed: count=%d/2",
    count
  ))
  if count < 2 then
    return false
  end
  return boop.tryVenomConfusionDiag("line")
end

function boop.events.register()
  if boop.handlers then
    for _, id in ipairs(boop.handlers) do
      if killAnonymousEventHandler then
        killAnonymousEventHandler(id)
      end
    end
  end
  boop.handlers = {}

  if not registerAnonymousEventHandler then return end

  local function add(event, fn)
    local id = registerAnonymousEventHandler(event, fn)
    boop.handlers[#boop.handlers + 1] = id
  end

  add("gmcp.Char.Afflictions.List", "boop.onDiagAfflictionsList")
  add("gmcp.Char.Items.List", "boop.onRoomItemsList")
  add("gmcp.Char.Items.Add", "boop.onRoomItemsAdd")
  add("gmcp.Char.Items.Remove", "boop.onRoomItemsRemove")
  add("gmcp.Char.Items.Update", "boop.onItemsUpdate")
  add("gmcp.Room.Info", "boop.onRoomInfo")
  add("gmcp.IRE.Display.ButtonActions", "boop.onIreSupportObserved")
  add("gmcp.IRE.Display.FixedFont", "boop.onIreSupportObserved")
  add("gmcp.IRE.Display.Ohmap", "boop.onIreSupportObserved")
  add("gmcp.IRE.Target.Set", "boop.onTargetSet")
  add("gmcp.IRE.Target.Info", "boop.onTargetInfo")
  add("gmcp.Char.Status", "boop.onCharStatus")
  add("gmcp.Char.Vitals", "boop.onVitals")
  add("gmcp.Char.Skills.Groups", "boop.onSkillsGroups")
  add("gmcp.Char.Skills.List", "boop.onSkillsList")
  add("gmcp.Char.Skills.Info", "boop.onSkillsInfo")
  add("sysDataSendRequest", "boop.onDataSendRequest")
  add("sysConnectionEvent", "boop.onConnectionEvent")
  add("demonwalker.arrived", "boop.onWalkArrived")
  add("demonwalker.finished", "boop.onWalkFinished")
end

function boop.onDataSendRequest(_, command)
  local wireCommand = tostring(command or "")
  local trimmedCommand = boop.util
    and boop.util.trim
    and boop.util.trim(wireCommand)
    or wireCommand:match("^%s*(.-)%s*$")
  if trimmedCommand == "" then
    return false
  end
  if not (boop.config and boop.config.enabled) then
    return false
  end
  local outboundObserved = runtime()
    and boop.runtime.observeOutbound
    and boop.runtime.observeOutbound(command)
    or false
  if boop.rage and boop.rage.onOutboundObserved then
    boop.rage.onOutboundObserved(outboundObserved)
  end
  local quarantine = runtime()
    and boop.runtime.packQuarantineSnapshot
    and boop.runtime.packQuarantineSnapshot()
    or false
  if type(quarantine) == "table"
      and not quarantine.resolved
      and not quarantine.consumed
      and tostring(command or "") == tostring(quarantine.nativePut or "")
      and runtime()
      and boop.runtime.notePackQuarantineActivity then
    boop.runtime.notePackQuarantineActivity(
      "old put invocation",
      type(outboundObserved) == "table"
        and outboundObserved.sequence
        or false
    )
  end
  local direction = movementDirection(command)
  if not direction
      or not (runtime() and boop.runtime.noteMovementIntent) then
    return false
  end
  local intent = boop.runtime.noteMovementIntent(direction)
  if not intent then
    return false
  end
  if boop.trace and boop.trace.log then
    boop.trace.log(string.format(
      "movement intent armed: direction=%s | origin=%s | generation=%s",
      tostring(intent.direction or direction),
      tostring(intent.originRoomId or ""),
      tostring(intent.originObservationGeneration or "")
    ))
  end
  return true
end

function boop.onConnectionEvent()
  if boop.runtime and boop.runtime.resolvePackQuarantine then
    boop.runtime.resolvePackQuarantine("connection")
  end
  if boop.rage and boop.rage.onConnectionReset then
    boop.rage.onConnectionReset("connection")
  end
  boop.resetShieldMode("connection")
  if boop.runtime and boop.runtime.resetVenomConfusionCount then
    boop.runtime.resetVenomConfusionCount("connection")
  end
  if boop.attacks and boop.attacks.clearTemporaryPreferences then
    boop.attacks.clearTemporaryPreferences("connection")
  end
  if boop.requestCoreSupports then
    boop.requestCoreSupports({
      force = true,
      requestSkills = true,
    })
  end
  boop.reconcileIreSupport("connection", {
    supportAlreadyRequested = true,
    requestIfMissing = false,
  })
end

local function applyMovementProvisionalCombat(movement)
  if type(movement) ~= "table"
      or type(movement.candidateItems) ~= "table" then
    return false
  end
  local currentRoom = tostring(
    gmcp
      and gmcp.Room
      and gmcp.Room.Info
      and gmcp.Room.Info.num
      or ""
  )
  if currentRoom == ""
      or currentRoom ~= tostring(movement.destinationRoomId or "") then
    return false
  end

  local items = deepCopy(movement.candidateItems)
  local denizenCount = countCombatDenizens(items)
  if boop.trace and boop.trace.log then
    boop.trace.log(string.format(
      "movement confirmed: direction=%s | %s -> %s | provisional combat=%s | count=%d | denizens=%d",
      tostring(movement.direction or ""),
      tostring(movement.originRoomId or ""),
      currentRoom,
      denizenCount > 0 and "yes" or "no",
      #items,
      denizenCount
    ))
  end
  if denizenCount == 0
      or not (boop.targets and boop.targets.updateRoomItems) then
    return false
  end

  boop.targets.updateRoomItems(items)
  return boop.tick
    and boop.tick(nil, { provisionalCombat = true }, "room")
    or false
end

local function applyRoomApplication(
  applicationId,
  sourceAuthority,
  timerId,
  claimSource
)
  if not (runtime() and boop.runtime.claimRoomApplication) then
    return false
  end
  local application = boop.runtime.claimRoomApplication(
    applicationId,
    sourceAuthority,
    timerId
  )
  if not application then
    return false
  end

  local authority = copySourceAuthority(application.sourceAuthority)
  local items = deepCopy(application.items)
  if boop.trace and boop.trace.log then
    boop.trace.log(string.format(
      "room application claimed: source=%s | application=%s | room=%s | generation=%s",
      tostring(claimSource or "timer"),
      tostring(application.applicationId or ""),
      tostring(authority.roomId or ""),
      tostring(authority.observationGeneration or "")
    ))
  end
  boop.targets.updateRoomItems(items, authority)

  local goldItem = findRoomGoldItem(items)
  traceRoomItemsList(items, goldItem)
  if goldItem then
    autoGrabRoomItem(goldItem, {
      source = "accepted room application",
      sourceAuthority = authority,
    })
  end

  local walk = boop.state and boop.state.walk or {}
  local walkGeneration = tonumber(walk.generation) or 0
  local walkRoomGeneration = tonumber(walk.roomGeneration) or 0
  if boop.walk and boop.walk.onRoomSettled then
    local advanced = boop.walk.onRoomSettled(
      "room items list",
      walkGeneration,
      walkRoomGeneration,
      authority
    )
    if not advanced and operationHolds("walk") then
      traceHeld("walk", "room items list")
    end
  end
  local attacking = false
  if boop.tick then attacking = boop.tick(authority, nil, "room") end
  return true, attacking
end

local function scheduleRoomApplication(transition)
  local applicationId = tonumber(transition and transition.applicationId)
  local authority = copySourceAuthority(
    transition and transition.sourceAuthority
  )
  if not applicationId or not authority then
    return false
  end
  if not tempTimer then
    if boop.trace and boop.trace.log then
      boop.trace.log(string.format(
        "room application held: scheduler unavailable | application=%s | room=%s | generation=%s",
        tostring(applicationId),
        tostring(authority.roomId),
        tostring(authority.observationGeneration)
      ))
    end
    if boop.util and boop.util.warn then
      boop.util.warn(
        "room_partial -- accepted room evidence awaiting scheduler"
      )
    end
    return false
  end

  local timerId = false
  timerId = tempTimer(0, function()
    applyRoomApplication(applicationId, authority, timerId, "timer")
  end)
  if not boop.runtime.setRoomApplicationTimer(
      applicationId,
      timerId
    ) then
    if timerId and killTimer then
      killTimer(timerId)
    end
    return false
  end
  return true
end

local function applyPendingRoomApplicationFromTick()
  if not (runtime() and boop.runtime.roomApplicationSnapshot) then
    return false
  end
  local application = boop.runtime.roomApplicationSnapshot()
  if type(application) ~= "table"
      or not application.valid
      or application.claimed
      or application.consumed
      or not application.pendingTimer then
    return false
  end

  local timerId = application.pendingTimer
  local applied, attacking = applyRoomApplication(
    application.applicationId,
    application.sourceAuthority,
    timerId,
    "tick"
  )
  if not applied then return false end
  if killTimer then killTimer(timerId) end
  return true, attacking
end

function boop.onRoomItemsList()
  if not gmcp or not gmcp.Char or not gmcp.Char.Items or not gmcp.Char.Items.List then return end
  local list = deepCopy(gmcp.Char.Items.List)
  local transition = runtime()
    and boop.runtime.observeRoomItemsList
    and boop.runtime.observeRoomItemsList(list.location, list.items)
    or { status = "ignored" }
  traceRoomItemsResponse(list, transition)
  if tostring(list.location or ""):lower() == "room"
      and (transition.status == "duplicate"
        or transition.status == "orphan")
      and runtime()
      and boop.runtime.captureMovementRoomItems then
    local movement = boop.runtime.captureMovementRoomItems(
      transition.items or list.items,
      transition
    )
    if movement and boop.trace and boop.trace.log then
      boop.trace.log(string.format(
        "movement provisional list retained: direction=%s | origin=%s | count=%d | fence=%s | status=%s",
        tostring(movement.direction or ""),
        tostring(movement.originRoomId or ""),
        type(movement.candidateItems) == "table"
          and #movement.candidateItems
          or 0,
        tostring(movement.candidateFenceId or "none"),
        tostring(movement.candidateStatus or transition.status)
      ))
    end
  end
  local inventoryItems = transition.inventoryItems
  if type(inventoryItems) ~= "table"
      and transition.status == "inventory" then
    inventoryItems = transition.items
  end
  if type(inventoryItems) == "table" then
    rebuildWieldedFromInventory(inventoryItems, "inventory list")
  end
  local quarantineInventoryItems = inventoryItems
  if type(quarantineInventoryItems) ~= "table"
      and transition.status == "duplicate"
      and tostring(list.location or ""):lower() == "inv"
      and type(list.items) == "table" then
    quarantineInventoryItems = list.items
  end
  if type(quarantineInventoryItems) == "table" then
    if runtime() and boop.runtime.observeInventorySnapshot then
      local snapshot = boop.runtime.observeInventorySnapshot(
        quarantineInventoryItems
      )
      if boop.runtime.observePackQuarantineInventory then
        boop.runtime.observePackQuarantineInventory(
          snapshot.generation,
          inventoryContainsSovereigns(snapshot.items)
        )
      end
    end
  end
  if transition.status == "inventory" then
    return
  end
  if transition.status ~= "accepted" then return end
  scheduleRoomApplication(transition)
end

function boop.onRoomItemsAdd()
  if not gmcp or not gmcp.Char or not gmcp.Char.Items or not gmcp.Char.Items.Add then return end
  if gmcp.Char.Items.Add.location == "inv" then
    updateWieldedFromInvItem(gmcp.Char.Items.Add.item, "inventory add")
    return
  end
  if gmcp.Char.Items.Add.location ~= "room" then return end
  local item = gmcp.Char.Items.Add.item
  traceRoomItemEvent("add", item)
  recordPendingRoomDelta("add", item)
  local denizenAdded = boop.targets.addRoomItem(item)
  autoGrabRoomItem(item, {
    source = "gmcp room item Add",
    revalidateSettledAdd = true,
  })
  if denizenAdded
      and boop.config
      and boop.config.enabled
      and not (boop.state and boop.state.diag.hold)
      and tempTimer then
    local authority = currentRoomSourceAuthority()
    if authority then
      tempTimer(0, function()
        if roomAuthorityCurrent(authority, "room denizen add") then
          boop.tick(authority, { roomOwned = true }, "room")
        end
      end)
    end
  end
end

function boop.onRoomItemsRemove()
  if not gmcp or not gmcp.Char or not gmcp.Char.Items or not gmcp.Char.Items.Remove then return end
  if gmcp.Char.Items.Remove.location == "inv" then
    removeInvItem(gmcp.Char.Items.Remove.item, "inventory remove")
    return
  end
  if gmcp.Char.Items.Remove.location ~= "room" then return end
  local sourceAuthority = currentRoomSourceAuthority()
  local removed = gmcp.Char.Items.Remove.item
  local removedId = tostring((removed and removed.id) or "")
  local removedName = removed and removed.name or ""
  local removedWasGold = isGoldItem(removed)
  traceRoomItemEvent("remove", removed)
  recordPendingRoomDelta("remove", removed)
  boop.targets.removeRoomItem(removed)

  if removedWasGold then
    clearPendingGoldDrop("gold removed while operation pending")
  end

  if removedId ~= "" and boop.targets and boop.targets.clearTargetCall and tostring(boop.state.targeting.calledTargetId or "") == removedId then
    boop.targets.clearTargetCall("called target removed")
  end

  if removedId == "" then
    return
  end

  boop.state = boop.state or {}
  local current = tostring(boop.state.targeting.currentTargetId or "")
  if current == "" or current ~= removedId then
    return
  end

  if boop.stats and boop.stats.onTargetRemoved then
    boop.stats.onTargetRemoved(removedId, removedName)
  end

  local pull = boop.state.combat and boop.state.combat.pullState or nil
  if type(pull) == "table" and pull.active then
    return
  end

  if boop.trace and boop.trace.log then
    boop.trace.log(string.format("target lost: %s -- %s", removedId, tostring(removedName or "")))
  end
  warnTargetLost()
  clearLostTargetIntent()

  if not boop.config or not boop.config.enabled or boop.state.diag.hold then
    return
  end

  if not tempTimer then
    return false
  end

  tempTimer(0, function()
    if not roomAuthorityCurrent(
        sourceAuthority,
        "target loss retarget"
      ) then
      return false
    end
    if operationHolds("target") then
      traceHeld("target", "target lost retarget")
      return false
    end
    if boop.runtime
        and boop.runtime.standardPending
        and boop.runtime.standardPending() then
      if boop.trace and boop.trace.log then
        boop.trace.log(
          "target held: exact standard lifecycle pending | target lost retarget"
        )
      end
      return false
    end

    local nextTarget = boop.targets
      and boop.targets.choose
      and boop.targets.choose()
      or ""
    if nextTarget ~= "" then
      if boop.trace and boop.trace.log then
        boop.trace.log(string.format(
          "retarget selected: %s -- %s | reason=target_lost",
          tostring(nextTarget),
          denizenNameById(nextTarget)
        ))
      end
      local changed = boop.targets.setTarget(
        nextTarget,
        automaticDispatchOptions(sourceAuthority)
      )
      if not changed then
        return false
      end
    end

    if boop and boop.tick then
      boop.tick(sourceAuthority or nil, {
        roomOwned = sourceAuthority and true or false,
      }, "target")
    end
    return true
  end)
  return true
end

function boop.onItemsUpdate()
  if not gmcp or not gmcp.Char or not gmcp.Char.Items or not gmcp.Char.Items.Update then return end
  if gmcp.Char.Items.Update.location ~= "inv" then return end
  updateWieldedFromInvItem(gmcp.Char.Items.Update.item, "inventory update")
end

function boop.onRoomInfo()
  if not gmcp or not gmcp.Room or not gmcp.Room.Info then
    if boop.runtime and boop.runtime.clearAttackIntent then
      boop.runtime.clearAttackIntent("missing_room", {
        source = "Room.Info",
        clearTarget = true,
      })
    end
    if boop.runtime and boop.runtime.startRoomObservation then
      boop.runtime.startRoomObservation("", {
        boundary = "fresh_start",
        infoSeen = false,
        reason = "missing room state",
      })
    end
    return
  end
  if boop.runtime and boop.runtime.ensureState then
    boop.runtime.ensureState()
  end
  boop.state = boop.state or {}
  boop.state.targeting = boop.state.targeting or {}
  boop.state.combat = boop.state.combat or {}

  local info = deepCopy(gmcp.Room.Info)
  if roomInfoIsPartial(info) then
    if boop.runtime and boop.runtime.clearAttackIntent then
      boop.runtime.clearAttackIntent("room_partial", {
        source = "Room.Info",
        clearTarget = true,
      })
    end
    if boop.runtime and boop.runtime.startRoomObservation then
      boop.runtime.startRoomObservation(
        tostring(info and info.num or ""),
        {
          boundary = "fresh_start",
          infoSeen = tostring(info and info.num or "") ~= "",
          reason = "partial room state",
        }
      )
    end
    return
  end

  local targeting = boop.state.targeting
  local combat = boop.state.combat
  local previousRoom = targeting.room
  local previousRoomText = boop.util.trim(tostring(previousRoom or ""))
  local currentRoomText = boop.util.trim(tostring(info.num or ""))
  local priorObservation = boop.runtime
    and boop.runtime.roomObservationSnapshot
    and boop.runtime.roomObservationSnapshot()
    or {}
  local sameTrackedRoom = previousRoomText ~= ""
    and previousRoomText == currentRoomText
    and tostring(priorObservation.roomId or "") == currentRoomText
  if sameTrackedRoom
      and runtime()
      and boop.runtime.clearMovementIntent then
    local intent = boop.runtime.movementIntentSnapshot
      and boop.runtime.movementIntentSnapshot()
      or false
    if intent and intent.active then
      boop.runtime.clearMovementIntent("same-room Room.Info")
    end
  end
  if sameTrackedRoom and priorObservation.infoSeen and priorObservation.itemsSeen then
    return
  end
  if sameTrackedRoom then
    boop.requestRoomItemsOnce("same-room info awaiting complete item list")
    return
  end

  local movedRooms = previousRoomText ~= currentRoomText
  local provisionalMovement = false
  if movedRooms
      and runtime()
      and boop.runtime.consumeMovementRoomItems then
    provisionalMovement =
      boop.runtime.consumeMovementRoomItems(currentRoomText)
  end
  if movedRooms then
    if boop.runtime and boop.runtime.invalidateRoomApplication then
      boop.runtime.invalidateRoomApplication(nil, "room changed")
    end
    local pull = combat.pullState
    local preservePullIntent = type(pull) == "table"
      and pull.active
      and not pull.terminal
    if not preservePullIntent
        and boop.runtime
        and boop.runtime.clearAttackIntent then
      boop.runtime.clearAttackIntent("room_changed", {
        source = "Room.Info",
        clearTarget = true,
      })
    end
  end
  local observation = boop.runtime
    and boop.runtime.observeRoomInfo
    and boop.runtime.observeRoomInfo(info.num, {
      movedRooms = movedRooms,
      freshStart = not movedRooms,
      boundary = movedRooms and "room_change" or "fresh_start",
      previousRoom = previousRoomText,
      reason = "room info boundary",
    })
    or nil
  local goldOperation = currentGoldOperation()
  if goldOperation
      and (goldOperation.phase == GOLD_PHASE.DEFERRED_ROOM
        or goldOperation.phase == GOLD_PHASE.PICKUP_PENDING) then
    completeGoldOperation(goldOperation.generation, "room_changed")
  end
  local walk = boop.state.walk or {}
  local walkGeneration = tonumber(walk.generation) or 0
  local roomGeneration = observation and tonumber(observation.generation) or 0

  if movedRooms then
    targeting.movedRooms = true
    targeting.lastRoom = previousRoom
    if boop.targets and boop.targets.clearTargetCall then
      boop.targets.clearTargetCall("room changed")
    end
    if boop.targets and boop.targets.clearTargetShield then
      boop.targets.clearTargetShield("room changed")
    end

    targeting.lastRoomDir = ""
    if not combat.fleeing then
      if info.exits then
        for dir, id in pairs(info.exits) do
          if tonumber(id) == tonumber(previousRoom) then
            targeting.lastRoomDir = dir
            break
          end
        end
      end
    else
      combat.fleeing = false
    end
  else
    targeting.movedRooms = false
  end

  if boop.walk and boop.walk.onRoomChange then
    boop.walk.onRoomChange(walkGeneration, roomGeneration)
  end

  targeting.room = info.num
  traceRoomInfo(info, movedRooms, previousRoom)
  local interrupt = boop.state.diag and boop.state.diag.operation or nil
  if movedRooms
      and type(interrupt) == "table"
      and not interrupt.terminal
      and interrupt.completionMode == "room_change"
      and (interrupt.originRoomId == ""
        or tostring(interrupt.originRoomId) ~= currentRoomText) then
    boop.runtime.completeInterrupt(interrupt.generation, "room_changed")
  end
  if movedRooms and tostring(targeting.lastRoom or "") ~= ""
      and boop.stats and boop.stats.onRoomChange then
    boop.stats.onRoomChange()
  end

  local pull = combat.pullState
  if type(pull) == "table" and pull.active and not pull.terminal then
    local generation = tonumber(pull.generation)
    local currentRoom = boop.util.trim(tostring(targeting.room or ""))
    local originRoom = boop.util.trim(tostring(pull.originRoom or ""))
    local currentPull = combat.pullState
    if generation
        and type(currentPull) == "table"
        and currentPull.generation == generation
        and not currentPull.terminal
        and currentRoom ~= ""
        and originRoom ~= "" then
      if pull.phase == "outbound" and currentRoom ~= originRoom then
        pull.phase = "away"
        boop.trace.log("pull: away room " .. currentRoom)
      elseif currentRoom == originRoom
          and (pull.phase == "away" or pull.phase == "timed_out_away") then
        local terminalReason = pull.phase == "timed_out_away"
          and "returned_after_timeout"
          or "returned_origin"
        local completed = boop.ui
          and boop.ui.completePull
          and boop.ui.completePull(generation, terminalReason, {
            currentRoom = currentRoom,
          })
        if completed and not currentTargetStillInRoom() then
          clearLostTargetIntent()
        end
      end
    end
  end

  boop.requestRoomItemsOnce("room info awaiting complete item list")
  if provisionalMovement then
    applyMovementProvisionalCombat(provisionalMovement)
  end
end

function boop.onWalkArrived(...)
  if boop.walk and boop.walk.onArrived then
    return boop.walk.onArrived()
  end
  return false
end

function boop.onWalkFinished(runGeneration)
  if boop.walk and boop.walk.onFinished then
    return boop.walk.onFinished(tonumber(runGeneration))
  end
  return false
end

function boop.onTargetSet()
  if not gmcp or not gmcp.IRE or not gmcp.IRE.Target or not gmcp.IRE.Target.Set then return end
  boop.onIreSupportObserved("gmcp.IRE.Target.Set")
  if not boop.config or not boop.config.enabled then
    return true
  end
  local newId = tostring(gmcp.IRE.Target.Set or "")
  if boop.targets and boop.targets.observeGameTarget then
    local accepted, reason = boop.targets.observeGameTarget(newId, "set")
    if not accepted then
      if boop.trace and boop.trace.log then
        boop.trace.log(string.format(
          "target gmcp set ignored: id=%s | reason=%s",
          newId,
          tostring(reason or "stale")
        ))
      end
      return true
    end
  end
  local pending = boop.runtime
    and boop.runtime.standardSnapshot
    and boop.runtime.standardSnapshot()
    or false
  if type(pending) == "table"
      and not pending.terminal
      and newId ~= tostring(pending.targetId or "") then
    if newId == "" then
      boop.runtime.markStandardTargetInvalid("target gmcp cleared")
      return true
    end
    boop.runtime.clearAttackIntent("explicit retarget", {
      clearTarget = false,
    })
  end
  if boop.targets and boop.targets.applyTarget then
    boop.targets.applyTarget(newId, { reason = "target gmcp set changed" })
  else
    boop.state.targeting.currentTargetId = newId
  end
end

local function targetInfoName(info)
  if type(info) ~= "table" then return "" end
  local keys = { "name", "short_desc", "shortdesc", "short_description" }
  for _, key in ipairs(keys) do
    local value = boop.util.trim(info[key] or "")
    if value ~= "" then return value end
  end
  return ""
end

function boop.onTargetInfo()
  if not gmcp or not gmcp.IRE or not gmcp.IRE.Target or not gmcp.IRE.Target.Info then return end
  local info = gmcp.IRE.Target.Info
  boop.onIreSupportObserved("gmcp.IRE.Target.Info")
  if not boop.config or not boop.config.enabled then
    return true
  end
  if info.id then
    local newId = tostring(info.id or "")
    if boop.targets and boop.targets.observeGameTarget then
      local accepted, reason = boop.targets.observeGameTarget(newId, "info")
      if not accepted then
        if boop.trace and boop.trace.log then
          boop.trace.log(string.format(
            "target gmcp info ignored: id=%s | reason=%s",
            newId,
            tostring(reason or "stale")
          ))
        end
        return true
      end
    end
    local pending = boop.runtime
      and boop.runtime.standardSnapshot
      and boop.runtime.standardSnapshot()
      or false
    if type(pending) == "table"
        and not pending.terminal
        and newId ~= tostring(pending.targetId or "") then
      if newId == "" then
        boop.runtime.markStandardTargetInvalid(
          "target gmcp info cleared"
        )
        return true
      end
      boop.runtime.clearAttackIntent("explicit retarget", {
        clearTarget = false,
      })
    end
    if boop.targets and boop.targets.applyTarget then
      boop.targets.applyTarget(newId, {
        name = targetInfoName(info),
        reason = "target gmcp info changed",
      })
    else
      boop.state.targeting.currentTargetId = newId
    end
  end
end

function boop.onCharStatus()
  if not gmcp or not gmcp.Char or not gmcp.Char.Status then return end
  local _, becameReady = boop.reconcileIreSupport("char status")
  if gmcp.Char.Status.class then
    local newClass = gmcp.Char.Status.class
    if boop.state.combat.class ~= newClass then
      boop.state.combat.class = newClass
      if boop.skills and boop.skills.requestAll then
        boop.skills.requestAll()
      end
    end
  end
  if boop.stats and boop.stats.onCharStatus then
    boop.stats.onCharStatus()
  end
  if becameReady
      and boop.config
      and boop.config.enabled
      and tempTimer then
    local authority = currentRoomSourceAuthority()
    tempTimer(0, function()
      boop.tick(authority or nil, {
        roomOwned = authority and true or false,
      }, "charstatus")
    end)
  end
end

function boop.onVitals()
  if boop.rage and boop.rage.onRageObserved and boop.attacks and boop.attacks.getRage then
    boop.rage.onRageObserved(boop.attacks.getRage())
  end

  if gmcp and gmcp.Char and gmcp.Char.Vitals and gmcp.Char.Vitals.charstats then
    local spec = ""
    for _, stat in ipairs(gmcp.Char.Vitals.charstats) do
      local name, val = stat:match("^([^:]+):%s*(.+)$")
      if name == "Spec" then
        spec = val
        break
      end
    end
    boop.state.combat.spec = spec
  end
  boop.tick(nil, nil, "vitals")
end

function boop.onBalanceUsed(kind, seconds, sourceAuthority)
  local duration = tonumber(seconds)
  if not duration then return end
  local authority = copySourceAuthority(sourceAuthority)
    or currentRoomSourceAuthority()
  local key = boop.util.safeLower(kind or "")
  local readyAt = nowSeconds() + duration
  if key == "balance" then
    boop.state.queue.balanceReadyAt = readyAt
  elseif key == "equilibrium" then
    boop.state.queue.equilibriumReadyAt = readyAt
  else
    return
  end
  if boop.runtime
      and boop.runtime.standardPending
      and boop.runtime.standardPending() then
    boop.runtime.bufferStandardCandidate({
      kind = "success",
      line = string.format(
        "%s used: %ss",
        key == "balance" and "Balance" or "Equilibrium",
        tostring(seconds)
      ),
    })
    return true
  end
  boop.state.queue.prequeuedStandard = false
  boop.state.queue.prequeueSourceAuthority = false
  boop.schedulePrequeue(authority, {
    roomOwned = authority and true or false,
  })
end

local function standardLineEvidence(line)
  local raw = boop.util.trim(tostring(line or ""))
  local normalized = boop.util.safeLower(raw)
  if normalized == "" then
    return false
  end
  if normalized:match("^balance used:%s*[0-9%.]+s%.?$")
      or normalized:match("^equilibrium used:%s*[0-9%.]+s%.?$") then
    return { kind = "success", line = raw }
  end
  if normalized:find("no longer paralysed", 1, true) then
    return { recovery = "paralysis", line = raw }
  end
  if normalized:find("no longer stunned", 1, true) then
    return { recovery = "stun", line = raw }
  end
  if normalized == "you stand up." then
    return { recovery = "prone", line = raw }
  end
  if normalized:find("writhed free", 1, true)
      and (
        normalized:find("web", 1, true)
        or normalized:find("entanglement", 1, true)
      ) then
    return { recovery = "web", line = raw }
  end
  if normalized:find("writhed free", 1, true)
      and normalized:find("impal", 1, true) then
    return { recovery = "impale", line = raw }
  end
  if normalized:find("arms are free", 1, true) then
    return { recovery = "arms", line = raw }
  end
  if normalized:find("paralys", 1, true) then
    return { kind = "denial", obstacle = "paralysis", line = raw }
  end
  if normalized:find("stunned", 1, true) then
    return { kind = "denial", obstacle = "stun", line = raw }
  end
  if normalized:find("must be standing", 1, true)
      or normalized:find("you are prone", 1, true) then
    return { kind = "denial", obstacle = "prone", line = raw }
  end
  if normalized:find("webbed", 1, true)
      or normalized:find("tangled in webs", 1, true) then
    return { kind = "denial", obstacle = "web", line = raw }
  end
  if normalized:find("impaled", 1, true) then
    return { kind = "denial", obstacle = "impale", line = raw }
  end
  if normalized:find("arm", 1, true)
      and (
        normalized:find("cannot", 1, true)
        or normalized:find("required", 1, true)
        or normalized:find("unable", 1, true)
      ) then
    return { kind = "denial", obstacle = "arms", line = raw }
  end
  if normalized:find("nothing here by that name", 1, true)
      or normalized:find("nothing here to target", 1, true) then
    return {
      kind = "denial",
      obstacle = "target_absent",
      line = raw,
    }
  end
  return false
end

function boop.onStandardCommandOutcome(line)
  local evidence = standardLineEvidence(line)
  if not evidence then
    return false
  end
  if evidence.recovery then
    return boop.runtime
      and boop.runtime.noteStandardRecovery
      and boop.runtime.noteStandardRecovery(evidence.recovery)
      or false
  end
  return boop.runtime
    and boop.runtime.bufferStandardCandidate
    and boop.runtime.bufferStandardCandidate(evidence)
    or false
end

function boop.onStandardCommandRecovery(line)
  local evidence = standardLineEvidence(line)
  if not evidence or not evidence.recovery then
    return false
  end
  return boop.runtime
    and boop.runtime.noteStandardRecovery
    and boop.runtime.noteStandardRecovery(evidence.recovery)
    or false
end

function boop.retryStandardDispatch(operation, reason)
  if type(operation) ~= "table"
      or not boop.config
      or not boop.config.enabled
      or operation.quarantined
      or operationHolds("queue")
      or operationHolds("target")
      or operationHolds("combat")
      or operationHolds("gold")
      or boop.state.diag.hold
      or boop.state.gold.getPending
      or boop.state.gold.putPending then
    return false
  end
  if gmcp and gmcp.Char and gmcp.Char.Vitals
      and (
        gmcp.Char.Vitals.bal ~= "1"
        or gmcp.Char.Vitals.eq ~= "1"
      ) then
    return false
  end
  local targetId = tostring(operation.targetId or "")
  if targetId == ""
      or tostring(boop.state.targeting.currentTargetId or "")
        ~= targetId
      or not boop.targets
      or not boop.targets.isCurrentTargetEligible
      or not boop.targets.isCurrentTargetEligible() then
    return false
  end
  local authority = copySourceAuthority(operation.sourceAuthority)
  if authority
      and not roomAuthorityCurrent(
        authority,
        "standard retry"
      ) then
    return false
  end
  if boop.safety
      and boop.safety.shouldFlee
      and boop.safety.shouldFlee() then
    return false
  end
  local emitted = boop.executeAction(
    operation.action,
    operation.mode == "queued",
    {
      roomOwned = authority and true or false,
      sourceAuthority = authority,
      dispatchMode = operation.mode,
      standardRetryBudget = tonumber(operation.retryBudget) or 0,
    }
  )
  if emitted and boop.trace and boop.trace.log then
    boop.trace.log("standard retry dispatched: " .. tostring(reason or "retry"))
  end
  return emitted
end

function boop.onStandardLifecycleTerminal(operation)
  if type(operation) ~= "table" or not operation.quarantined then
    return false
  end
  local targetId = tostring(operation.targetId or "")
  if tostring(boop.state.targeting.currentTargetId or "") == targetId then
    boop.state.targeting.currentTargetId = ""
    boop.state.targeting.targetName = ""
    if boop.targets and boop.targets.clearTargetShield then
      boop.targets.clearTargetShield("standard target terminal")
    else
      boop.state.targeting.targetShield = false
    end
  end
  boop.state.queue.aliasAction = ""
  boop.state.queue.aliasDirty = true
  if boop.afflictions and boop.afflictions.clearTarget then
    boop.afflictions.clearTarget()
  end
  if not tempTimer then
    return false
  end
  tempTimer(0, function()
    if boop.runtime
        and boop.runtime.standardPending
        and boop.runtime.standardPending() then
      return false
    end
    local authority = currentRoomSourceAuthority()
    return boop.tick(authority or nil, {
      roomOwned = authority and true or false,
    }, "other")
  end)
  return true
end

function boop.schedulePrequeue(sourceAuthority, options)
  local authority = copySourceAuthority(sourceAuthority)
    or currentRoomSourceAuthority()
  options = type(options) == "table" and options or {}
  local roomOwned = options.roomOwned == true
    or authority and true or false
  if not authority or not readinessAllows(true) then
    boop.state.queue.prequeueSourceAuthority = false
    return false
  end
  roomOwned = true
  if operationHolds("queue")
      or operationHolds("target")
      or operationHolds("combat") then
    if boop.state.queue.prequeueTimer then
      killTimer(boop.state.queue.prequeueTimer)
      boop.state.queue.prequeueTimer = nil
    end
    boop.state.queue.prequeueSourceAuthority = false
    traceHeld("queue", "schedule prequeue")
    return false
  end
  if not boop.config.prequeueEnabled then
    if boop.state.queue.prequeueTimer then
      killTimer(boop.state.queue.prequeueTimer)
      boop.state.queue.prequeueTimer = nil
    end
    boop.state.queue.prequeueSourceAuthority = false
    return false
  end

  local lead = tonumber(boop.config.attackLeadSeconds) or 0
  if lead <= 0 or not boop.config.enabled then
    if boop.state.queue.prequeueTimer then
      killTimer(boop.state.queue.prequeueTimer)
      boop.state.queue.prequeueTimer = nil
    end
    boop.state.queue.prequeueSourceAuthority = false
    return false
  end

  local bal = boop.state.queue.balanceReadyAt or 0
  local eq = boop.state.queue.equilibriumReadyAt or 0
  local readyAt = math.max(bal, eq)
  if readyAt <= 0 then return end

  local delay = readyAt - lead - nowSeconds()
  if delay < 0 then delay = 0 end
  boop.trace.log(string.format("prequeue scheduled in %.2fs (lead %.2fs)", delay, lead))

  if boop.state.queue.prequeueTimer then
    killTimer(boop.state.queue.prequeueTimer)
  end
  boop.state.queue.prequeueSourceAuthority =
    copySourceAuthority(authority)
  local timerId = false
  timerId = tempTimer(delay, function()
    if not roomAuthorityCurrent(
        authority,
        "delayed prequeue"
      ) then
      return false
    end
    if boop.state.queue.prequeueTimer ~= timerId then
      return false
    end
    boop.state.queue.prequeueTimer = nil
    return boop.prequeueStandard(authority, {
      roomOwned = roomOwned,
    })
  end)
  boop.state.queue.prequeueTimer = timerId
  return true
end

function boop.prequeueStandard(sourceAuthority, options)
  local authority = copySourceAuthority(sourceAuthority)
    or currentRoomSourceAuthority()
  options = type(options) == "table" and options or {}
  local roomOwned = options.roomOwned == true
    or authority and true or false
  if not authority or not readinessAllows(true) then
    return false
  end
  roomOwned = true
  if not roomAuthorityCurrent(authority, "prequeue standard") then
    return false
  end
  if not boop.config.enabled then return false end
  if not boop.config.prequeueEnabled then return false end
  if boop.runtime.standardPending
      and boop.runtime.standardPending() then
    return false
  end
  if operationHolds("queue")
      or operationHolds("target")
      or operationHolds("combat")
      or operationHolds("gold") then
    traceHeld("queue", "prequeue standard")
    return false
  end
  if boop.state.diag.hold then return false end
  if boop.state.gold.getPending or boop.state.gold.putPending then return false end
  if boop.state.queue.prequeuedStandard then return false end
  if gmcp and gmcp.Char and gmcp.Char.Vitals then
    if gmcp.Char.Vitals.bal == "1" and gmcp.Char.Vitals.eq == "1" then
      return false
    end
  end

  if boop.safety and boop.safety.shouldFlee and boop.safety.shouldFlee() then
    return false
  end

  local targetId = boop.targets.choose()
  if not targetId or targetId == "" then
    if boop.config.useQueueing and boop.state.gold.autoGrabPending then
      flushPendingGold("prequeue no target")
    end
    if boop.targets and boop.targets.waitingForTargetCall and boop.targets.waitingForTargetCall() then
      return false
    end
    return false
  end

  local targetNeedsSync = boop.targets
    and boop.targets.needsGameTargetSync
    and boop.targets.needsGameTargetSync(targetId)
  if boop.state.targeting.currentTargetId ~= targetId
      or targetNeedsSync then
    if not boop.targets.setTarget(
        targetId,
        automaticDispatchOptions(authority, roomOwned)
      ) then
      return false
    end
  end

  local context = boop.runtime
    and boop.runtime.context
    and boop.runtime.context(authority)
    or nil
  local actions = boop.attacks.choose(context)
  if actions.standard and actions.standard ~= "" then
    local emitted = boop.executeAction(
      actions.standard,
      true,
      automaticDispatchOptions(authority, roomOwned)
    )
    if not emitted then
      return false
    end
    if actions.standardIsOpener and boop.attacks and boop.attacks.markOpenerUsed then
      boop.attacks.markOpenerUsed(classKeyForOpener(), targetId)
    end
    boop.state.queue.prequeuedStandard = true
    boop.state.queue.prequeueSourceAuthority =
      copySourceAuthority(authority)
    boop.trace.log("prequeue sent standard")
    return true
  end
  return false
end

function boop.refreshPrequeuedStandard(reason, sourceAuthority, options)
  local authority = copySourceAuthority(sourceAuthority)
    or copySourceAuthority(
      boop.state.queue.prequeueSourceAuthority
    )
  options = type(options) == "table" and options or {}
  local requireShieldbreak = options.requireShieldbreak ~= false
  local roomOwned = options.roomOwned == true
    or authority and true or false
  if not authority or not readinessAllows(true) then
    return false
  end
  roomOwned = true
  if not roomAuthorityCurrent(authority, "refresh prequeue") then
    return false
  end
  if not boop.config.enabled then return false end
  if not boop.config.prequeueEnabled then return false end
  if boop.runtime.standardPending
      and boop.runtime.standardPending() then
    return false
  end
  if operationHolds("queue")
      or operationHolds("target")
      or operationHolds("combat")
      or operationHolds("gold") then
    traceHeld("queue", "refresh prequeue")
    return false
  end
  if not boop.state.queue.prequeuedStandard then return false end
  if boop.state.diag.hold then return false end
  if boop.state.gold.getPending or boop.state.gold.putPending then return false end
  if gmcp and gmcp.Char and gmcp.Char.Vitals then
    if gmcp.Char.Vitals.bal == "1" and gmcp.Char.Vitals.eq == "1" then
      return false
    end
  end

  local targetId = boop.targets.choose()
  if not targetId or targetId == "" then return false end
  if tostring(boop.state.targeting.currentTargetId or "") ~= tostring(targetId) then
    return false
  end

  local context = boop.runtime
    and boop.runtime.context
    and boop.runtime.context(authority)
    or nil
  local actions = boop.attacks.choose(context)
  if not actions.standard or actions.standard == "" then return false end
  if requireShieldbreak and not actions.standardShieldbreak then return false end

  if not boop.executeAction(
      actions.standard,
      true,
      automaticDispatchOptions(authority, roomOwned)
    ) then
    return false
  end
  boop.trace.log("prequeue rebuilt: " .. tostring(reason or "state change"))
  return true
end

function boop.canAct()
  if boop.state.combat.limiters.hunting then
    if boop.perf.on then
      boop.perf.count("ticks_suppressed_by_limiter")
    end
    return false
  end
  if gmcp and gmcp.Char and gmcp.Char.Vitals then
    if gmcp.Char.Vitals.bal ~= "1" or gmcp.Char.Vitals.eq ~= "1" then
      return false
    end
  end
  boop.state.combat.limiters.hunting = true
  tempTimer(0.4, function() boop.state.combat.limiters.hunting = false end)
  return true
end

function boop.canUseRage()
  if boop.rage
      and boop.rage.isGlobalCooldownOpen
      and not boop.rage.isGlobalCooldownOpen() then
    return false
  end
  if boop.state.combat.limiters.rage then return false end
  boop.state.combat.limiters.rage = true
  tempTimer(0.6, function() boop.state.combat.limiters.rage = false end)
  return true
end

function boop.tick(sourceAuthority, options, perfSource)
  if boop.runtime and boop.runtime.step and boop.runtime.applyEffects then
    options = type(options) == "table" and options or {}
    local suppliedAuthority = copySourceAuthority(sourceAuthority)
    if not suppliedAuthority and options.provisionalCombat ~= true then
      local applied, attacking = applyPendingRoomApplicationFromTick()
      if applied then return attacking end
    end
    local roomOwned = options.roomOwned == true
      or suppliedAuthority and true or false
    if suppliedAuthority
        and not roomAuthorityCurrent(
          suppliedAuthority,
          "tick"
        ) then
      return false
    end
    local authority = suppliedAuthority or currentRoomSourceAuthority()
    roomOwned = roomOwned or authority and true or false
    if roomOwned and not authority then
      return false
    end
    local context = boop.runtime.context(authority, {
      roomOwned = roomOwned,
      provisionalCombat = options.provisionalCombat == true,
    })
    local result = boop.runtime.step({ type = "tick", context = context })
    boop.state.combat.attacking = boop.runtime.applyEffects(result, context)
    return boop.state.combat.attacking
  end
  return false
end

function boop.onPrompt()
  boop.reconcileIreSupport("prompt", {
    requestIfMissing = false,
  })
  if not boop.config or not boop.config.enabled then
    return false
  end
  if boop.rage and boop.rage.onPrompt then
    boop.rage.onPrompt()
  end
  local freestandReady = gmcp
    and gmcp.Char
    and gmcp.Char.Vitals
    and gmcp.Char.Vitals.bal == "1"
    and gmcp.Char.Vitals.eq == "1"
    or false
  reconcileGoldPickupPrompt(freestandReady)
  if boop.runtime and boop.runtime.observePackQuarantinePrompt then
    boop.runtime.observePackQuarantinePrompt(freestandReady)
  end
  local standardResult = boop.runtime
    and boop.runtime.reconcileStandardPrompt
    and boop.runtime.reconcileStandardPrompt(
      freestandReady
    )
    or false
  if boop.runtime and boop.runtime.step and boop.runtime.applyEffects then
    local sourceAuthority = currentRoomSourceAuthority()
    local context = boop.runtime.context(sourceAuthority, {
      roomOwned = sourceAuthority and true or false,
    })
    local result = boop.runtime.step({ type = "prompt", context = context })
    boop.runtime.applyEffects(result, context)
    if result.runTick
        and not (
          type(standardResult) == "table"
          and standardResult.terminal
          and standardResult.quarantined
        ) then
      boop.tick(sourceAuthority or nil, nil, "prompt")
    end
    return
  end
end

local function ireDisplayProbe(source)
  if source == "gmcp.IRE.Display.ButtonActions"
      or source == "gmcp.IRE.Display.FixedFont"
      or source == "gmcp.IRE.Display.Ohmap" then
    return source
  end
  return false
end

boop.perf.register(false, boop, "onIreSupportObserved", {
  nameResolver = ireDisplayProbe,
})
boop.perf.register(
  "gmcp.Char.Afflictions.List",
  boop,
  "onDiagAfflictionsList"
)
boop.perf.register("sysDataSendRequest", boop, "onDataSendRequest")
boop.perf.register("sysConnectionEvent", boop, "onConnectionEvent")
boop.perf.register("gmcp.Char.Items.List", boop, "onRoomItemsList")
boop.perf.register("gmcp.Char.Items.Add", boop, "onRoomItemsAdd")
boop.perf.register("gmcp.Char.Items.Remove", boop, "onRoomItemsRemove")
boop.perf.register("gmcp.Char.Items.Update", boop, "onItemsUpdate")
boop.perf.register("gmcp.Room.Info", boop, "onRoomInfo")
boop.perf.register("demonwalker.arrived", boop, "onWalkArrived")
boop.perf.register("demonwalker.finished", boop, "onWalkFinished")
boop.perf.register("gmcp.IRE.Target.Set", boop, "onTargetSet")
boop.perf.register("gmcp.IRE.Target.Info", boop, "onTargetInfo")
boop.perf.register("gmcp.Char.Status", boop, "onCharStatus")
boop.perf.register("gmcp.Char.Vitals", boop, "onVitals", {
  callback = "vitals",
})
boop.perf.register("prequeue.schedule", boop, "schedulePrequeue")
boop.perf.register("prequeue.standard", boop, "prequeueStandard")
boop.perf.register("prequeue.refresh", boop, "refreshPrequeuedStandard")
boop.perf.register("tick", boop, "tick", { sourceIndex = 3 })
boop.perf.register("prompt.callback", boop, "onPrompt", {
  callback = "prompt",
})
