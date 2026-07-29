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
local GOLD_PICKUP_QUEUE = "full"
local GOLD_PACK_QUEUE = "freestand"
local GOLD_PHASE = {
  DEFERRED_ROOM = "deferred_room",
  PICKUP_PENDING = "pickup_pending",
  PACK_PENDING = "pack_pending",
}

local function queueGoldCommand(queueName, command)
  send("queue add " .. queueName .. " " .. command, false)
  return true
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
  if goldItem then
    boop.trace.log(string.format(
      "gmcp room items list: count=%d | gold=yes | gold=%s (%s)",
      count,
      tostring(goldItem.name or "?"),
      tostring(goldItem.id or "?")
    ))
    return
  end
  boop.trace.log(string.format("gmcp room items list: count=%d | gold=no", count))
end

local function traceRoomItemEvent(kind, item)
  if not boop.trace or not boop.trace.log then return end
  local name = item and item.name or "?"
  local id = item and item.id or "?"
  local gold = isGoldItem(item) and "yes" or "no"
  boop.trace.log(string.format("gmcp room item %s: %s (%s) | gold=%s", tostring(kind or "?"), tostring(name), tostring(id), gold))
end

local BLOCKER_SYSTEMS_GMCP = {
  target = true,
  combat = true,
  queue = true,
  gold = true,
  walk = true,
}

local BLOCKER_SYSTEMS_ROOM = {
  target = true,
  combat = true,
  gold = true,
  walk = true,
}

local GMCP_RETRY_SECONDS = 2

local function runtime()
  return boop.runtime
end

local function blockerSnapshot()
  if runtime() and boop.runtime.blockerSnapshot then
    return boop.runtime.blockerSnapshot()
  end
  return { owner = "", code = "", systems = {}, waitsFor = {}, observed = {}, additionalCount = 0 }
end

local function setBlocker(owner, code, label, systems, waitsFor, opts)
  if runtime() and boop.runtime.setBlocker then
    return boop.runtime.setBlocker(owner, code, label, systems, waitsFor, opts or {})
  end
  return false
end

local function shouldHold(system, exceptOwner)
  return runtime()
    and boop.runtime.shouldHold
    and boop.runtime.shouldHold(system, exceptOwner)
end

local function traceHeld(system, reason)
  if boop.trace and boop.trace.log then
    local blocker = blockerSnapshot()
    boop.trace.log(string.format(
      "%s held: %s -- %s%s",
      tostring(system or "automation"),
      tostring(blocker.code or ""),
      tostring(blocker.label or ""),
      reason and (" | " .. tostring(reason)) or ""
    ))
  end
end

local function ireReady()
  local ire = gmcp and gmcp.IRE or nil
  return type(ire) == "table"
    and (type(ire.Target) == "table" or type(ire.Display) == "table")
end

local function warnBlocker(blocker)
  if not (boop.util and boop.util.warn) then return end
  if type(blocker) ~= "table" or tostring(blocker.code or "") == "" then return end
  local stateBlocker = boop.state
    and boop.state.combat
    and boop.state.combat.blockersByOwner
    and boop.state.combat.blockersByOwner["gmcp:ire"]
    or nil
  if type(stateBlocker) ~= "table" then return end
  local now = nowSeconds()
  local lastAt = tonumber(stateBlocker.lastWarningAt) or 0
  local lastCode = tostring(stateBlocker.lastWarningCode or "")
  local throttle = tonumber(stateBlocker.warningThrottleSeconds) or GMCP_RETRY_SECONDS
  if lastCode == blocker.code and lastAt > 0 and (now - lastAt) < throttle then
    return
  end
  stateBlocker.lastWarningAt = now
  stateBlocker.lastWarningCode = blocker.code
  boop.util.warn(string.format("%s -- %s", tostring(blocker.code or ""), tostring(blocker.label or "")))
end

local function requestCoreSupportsThrottled(forceNow)
  if not boop.requestCoreSupports then return false end
  local blocker = boop.state
    and boop.state.combat
    and boop.state.combat.blockersByOwner
    and boop.state.combat.blockersByOwner["gmcp:ire"]
    or nil
  local now = nowSeconds()
  local lastAt = type(blocker) == "table" and tonumber(blocker.lastRetryAt) or nil
  if not forceNow and lastAt and lastAt > 0 and (now - lastAt) < GMCP_RETRY_SECONDS then
    return false
  end
  boop.requestCoreSupports({
    requestSkills = true,
    minInterval = 0,
    force = true,
  })
  if type(blocker) == "table" then
    blocker.lastRetryAt = now
  end
  return true
end

local function enterGmcpIreBlocker(
  source,
  supportAlreadyRequested,
  requestIfMissing
)
  local state = runtime() and boop.runtime.state and boop.runtime.state() or boop.state
  local previous = state
    and state.combat
    and state.combat.blockersByOwner
    and state.combat.blockersByOwner["gmcp:ire"]
    or nil
  local firstEntry = type(previous) ~= "table"
  local blocker = previous
  if firstEntry then
    blocker = setBlocker("gmcp:ire", "gmcp_ire_missing", "GMCP IRE missing", BLOCKER_SYSTEMS_GMCP, {
      gmcp = true,
      prompt = true,
    }, {
      source = source,
      observed = {
        ire = false,
      },
    })
  end
  if supportAlreadyRequested then
    local stateBlocker = boop.state
      and boop.state.combat
      and boop.state.combat.blockersByOwner
      and boop.state.combat.blockersByOwner["gmcp:ire"]
      or nil
    if type(stateBlocker) == "table" then
      stateBlocker.lastRetryAt = nowSeconds()
    end
  elseif requestIfMissing then
    requestCoreSupportsThrottled(firstEntry)
  end
  warnBlocker(blocker)
  return blocker
end

function boop.reconcileIreSupport(source, options)
  options = type(options) == "table" and options or {}
  local requestIfMissing = options.requestIfMissing
  if requestIfMissing == nil then
    requestIfMissing = true
  end
  if ireReady() then
    if runtime() and boop.runtime.noteGmcpObserved then
      boop.runtime.noteGmcpObserved("gmcp:ire", "ire")
    end
    return true
  end
  enterGmcpIreBlocker(
    source,
    options.supportAlreadyRequested == true,
    requestIfMissing
  )
  return false
end

function boop.onIreSupportObserved(source)
  return boop.reconcileIreSupport(
    source or "ire event",
    {
      requestIfMissing = false,
    }
  )
end

local function enterRoomBlocker(code, label, observed)
  return setBlocker("room:observation", code, label, BLOCKER_SYSTEMS_ROOM, {
    gmcp = true,
  }, {
    source = "room",
    observed = observed or {},
  })
end

local function roomInfoIsPartial(info)
  return not info or not info.num or type(info.exits) ~= "table"
end

local function noteTargetRoomGmcpObserved()
  if runtime() and boop.runtime.noteGmcpObserved then
    boop.runtime.noteGmcpObserved("target:loss", "room")
  end
end

local function noteRoomGmcpObserved()
  if runtime() and boop.runtime.noteGmcpObserved then
    boop.runtime.noteGmcpObserved("room:observation", "room")
  end
  noteTargetRoomGmcpObserved()
  return true
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

  if sendGMCP then
    if not fence.roomOnly then
      sendGMCP([[Char.Items.Inv]])
    end
    sendGMCP([[Char.Items.Room]])
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

local function noteTargetGmcpObserved()
  if runtime() and boop.runtime.noteGmcpObserved then
    boop.runtime.noteGmcpObserved("target:loss", "target")
  end
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
  boop.runtime.clearAutomationIntent("target_lost", {
    includeGold = false,
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
    if shouldHold("queue", owner) or shouldHold("gold", owner) then
      return false
    end
    return boop.util.trim(operation.packTarget or "") ~= ""
  end

  if shouldHold("combat", owner)
      or shouldHold("queue", owner)
      or shouldHold("gold", owner)
      or shouldHold("walk", owner) then
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
    return setBlocker(
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

  return setBlocker(
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
    return setBlocker(
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

  return setBlocker(
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
      active.awaitingExplicitEvidence = true
      setGoldEvidenceWaitBlocker(active)
      if tonumber(active.replayWarningDispatchId) ~= tonumber(expectedDispatchId) then
        active.replayWarningDispatchId = expectedDispatchId
        if active.phase == GOLD_PHASE.PICKUP_PENDING then
          boop.trace.log(string.format(
            "gold replay timeout: pickup awaiting explicit evidence | generation=%s | dispatch=%s",
            tostring(generation),
            tostring(expectedDispatchId)
          ))
          boop.util.warn(
            "auto gold: replayed pickup timed out; move or disable/flee to cancel"
          )
        else
          boop.trace.log(string.format(
            "gold replay timeout: pack awaiting explicit evidence | generation=%s | dispatch=%s",
            tostring(generation),
            tostring(expectedDispatchId)
          ))
          boop.util.warn(
            "auto gold: replayed pack timed out; provide result/failure evidence or disable/flee to cancel"
          )
        end
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
  if operation.phase == GOLD_PHASE.PICKUP_PENDING then
    queueGoldCommand(GOLD_PICKUP_QUEUE, "get sovereigns")
    boop.trace.log(string.format(
      "gold queue: get sovereigns | generation=%s | room=%s",
      tostring(operation.generation),
      tostring(operation.roomId)
    ))
  elseif operation.phase == GOLD_PHASE.PACK_PENDING then
    local pack = boop.util.trim(operation.packTarget or "")
    if pack == "" then return false end
    queueGoldCommand(GOLD_PACK_QUEUE, "put sovereigns in " .. pack)
    boop.trace.log(string.format(
      "gold queue: put sovereigns in %s | generation=%s",
      pack,
      tostring(operation.generation)
    ))
  else
    return false
  end
  if displacementReplay then
    operation.replayPending = false
    operation.displacedByOwner = nil
    operation.displacedPhase = nil
    operation.displacedDispatchId = nil
  end
  armGoldPendingTimeout(
    operation.generation,
    operation.phase,
    operation.dispatchId,
    provenance
  )
  return true
end

function boop.displaceGoldQueueIntent(interruptOwner, reason)
  local operation = currentGoldOperation()
  local owner = tostring(interruptOwner or "")
  if not operation
      or owner == ""
      or operation.awaitingExplicitEvidence
      or operation.replayPending
      or not operation.timeoutTimer
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
  if runtime() and boop.runtime.clearBlocker then
    boop.runtime.clearBlocker(owner, reason)
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
        boop.tick()
      end
    end)
  end
  return true
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
      setBlocker(operation.blockerOwner, "gold_pickup_pending", "gold pickup pending", {
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

  state.gold.generation = (tonumber(state.gold.generation) or 0) + 1
  local generation = state.gold.generation
  local phase = evidenceComplete and currentGoldItem
    and GOLD_PHASE.PICKUP_PENDING
    or GOLD_PHASE.DEFERRED_ROOM
  operation = {
    generation = generation,
    phase = phase,
    terminal = false,
    blockerOwner = "gold:" .. tostring(generation),
    source = tostring(source or "gold detected"),
    roomId = roomId,
    roomGeneration = roomGeneration,
    goldItemId = tostring(
      currentGoldItem and currentGoldItem.id or requestedItemId
    ),
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
    replayWarningDispatchId = false,
    revalidationAttempted = false,
    revalidationFenceId = false,
    sourceAuthority = copySourceAuthority(observation.sourceAuthority),
  }
  state.gold.operation = operation

  if phase == GOLD_PHASE.DEFERRED_ROOM then
    setBlocker(operation.blockerOwner, "gold_deferred_room", "gold awaiting room evidence", {
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
    setBlocker(operation.blockerOwner, "gold_pickup_pending", "gold pickup pending", {
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
  operation.replayWarningDispatchId = false
  if boop.util.trim(operation.packTarget or "") == "" then
    return completeGoldOperation(generation, "get_success_no_pack")
  end

  setBlocker(operation.blockerOwner, "gold_pack_pending", "gold packing pending", {
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
  if operation.timeoutTimer or operation.awaitingExplicitEvidence then
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
  boop.markGoldQueueIntent(operation.packTarget)
  armGoldPendingTimeout(
    operation.generation,
    operation.phase,
    operation.dispatchId,
    operation.dispatchProvenance
  )
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
  return transferGoldToPacking(operation.generation)
end

function boop.onGoldPutSuccess()
  local operation = currentGoldOperation(nil, GOLD_PHASE.PACK_PENDING)
  if not operation then return false end
  boop.trace.log("gold put success")
  return completeGoldOperation(operation.generation, "put_success")
end

function boop.onGoldCommandFailure(line)
  local operation = currentGoldOperation()
  if not operation then return false end
  local reason = boop.util.trim(line or "")
  if operation.phase == GOLD_PHASE.PICKUP_PENDING then
    return retryGoldGet(reason)
  end
  if operation.phase == GOLD_PHASE.PACK_PENDING then
    return retryGoldPut(reason)
  end
  return false
end

function boop.onDiagReadyLine()
  return boop.runtime.markOldestDiagEvidenceResult()
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
  add("sysConnectionEvent", "boop.onConnectionEvent")
  add("demonwalker.arrived", "boop.onWalkArrived")
  add("demonwalker.finished", "boop.onWalkFinished")
end

function boop.onConnectionEvent()
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

local function applyRoomApplication(applicationId, sourceAuthority, timerId)
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
  noteRoomGmcpObserved()
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
    if not advanced and shouldHold("walk") then
      traceHeld("walk", "room items list")
    end
  end
  if boop.tick then
    boop.tick(authority)
  end
  return true
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
    applyRoomApplication(applicationId, authority, timerId)
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

function boop.onRoomItemsList()
  if not gmcp or not gmcp.Char or not gmcp.Char.Items or not gmcp.Char.Items.List then return end
  local list = deepCopy(gmcp.Char.Items.List)
  local transition = runtime()
    and boop.runtime.observeRoomItemsList
    and boop.runtime.observeRoomItemsList(list.location, list.items)
    or { status = "ignored" }
  if transition.inventoryItems then
    rebuildWieldedFromInventory(
      transition.inventoryItems,
      "inventory list"
    )
  elseif transition.status == "inventory" then
    rebuildWieldedFromInventory(transition.items, "inventory list")
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
  boop.targets.addRoomItem(item)
  if denizenNameById(item and item.id) ~= "" then
    noteTargetRoomGmcpObserved()
  end
  autoGrabRoomItem(item, {
    source = "gmcp room item Add",
    revalidateSettledAdd = true,
  })
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
    if shouldHold("target") then
      traceHeld("target", "target lost retarget")
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
    else
      setBlocker("target:loss", "target_lost", "target left room", {
        target = true,
        combat = true,
        queue = true,
      }, {
        gmcp = true,
        prompt = true,
      }, {
        source = "targeting",
        observed = {
          target = removedId,
          room = tostring(boop.state.targeting.room or ""),
        },
      })
    end

    if boop and boop.tick then
      boop.tick(sourceAuthority or nil, {
        roomOwned = sourceAuthority and true or false,
      })
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
    enterRoomBlocker("missing_room", "missing room state", {
      room = false,
    })
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
    enterRoomBlocker("room_partial", "partial room state", {
      room = tostring(info and info.num or ""),
      exits = type(info and info.exits) == "table",
    })
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
  if sameTrackedRoom and priorObservation.infoSeen and priorObservation.itemsSeen then
    return
  end
  if sameTrackedRoom then
    enterRoomBlocker("room_partial", "partial room state", {
      room = tostring(info.num or ""),
      items = false,
      generation = tonumber(priorObservation.generation) or 0,
    })
    boop.requestRoomItemsOnce("same-room info awaiting complete item list")
    return
  end

  local movedRooms = previousRoomText ~= currentRoomText
  if movedRooms then
    if boop.runtime and boop.runtime.invalidateRoomApplication then
      boop.runtime.invalidateRoomApplication(nil, "room changed")
    end
    if boop.runtime and boop.runtime.clearAttackIntent then
      boop.runtime.clearAttackIntent("room_changed", {
        source = "Room.Info",
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
  enterRoomBlocker("room_partial", "partial room state", {
    room = tostring(info.num or ""),
    items = false,
    generation = observation and observation.generation or 0,
  })

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
  noteTargetGmcpObserved()
  local newId = tostring(gmcp.IRE.Target.Set or "")
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
  noteTargetGmcpObserved()
  if info.id then
    local newId = tostring(info.id or "")
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
  boop.reconcileIreSupport("char status")
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
  boop.tick()
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
  boop.state.queue.prequeuedStandard = false
  boop.state.queue.prequeueSourceAuthority = false
  boop.schedulePrequeue(authority, {
    roomOwned = authority and true or false,
  })
end

function boop.schedulePrequeue(sourceAuthority, options)
  local authority = copySourceAuthority(sourceAuthority)
    or currentRoomSourceAuthority()
  options = type(options) == "table" and options or {}
  local roomOwned = options.roomOwned == true
    or authority and true or false
  if roomOwned and not authority then
    boop.state.queue.prequeueSourceAuthority = false
    return false
  end
  if shouldHold("queue") or shouldHold("target") or shouldHold("combat") then
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
  options = type(options) == "table" and options or {}
  local roomOwned = options.roomOwned == true
    or authority and true or false
  if roomOwned and not authority then
    return false
  end
  if not roomAuthorityCurrent(authority, "prequeue standard") then
    return false
  end
  if not boop.config.enabled then return false end
  if not boop.config.prequeueEnabled then return false end
  if shouldHold("queue") or shouldHold("target") or shouldHold("combat") or shouldHold("gold") then
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

  if boop.state.targeting.currentTargetId ~= targetId then
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
    if actions.standardShieldbreak and boop.targets and boop.targets.onShieldbreakAttempt then
      boop.targets.onShieldbreakAttempt()
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
  local roomOwned = options.roomOwned == true
    or authority and true or false
  if roomOwned and not authority then
    return false
  end
  if not roomAuthorityCurrent(authority, "refresh prequeue") then
    return false
  end
  if not boop.config.enabled then return false end
  if not boop.config.prequeueEnabled then return false end
  if shouldHold("queue") or shouldHold("target") or shouldHold("combat") or shouldHold("gold") then
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
  if not actions.standardShieldbreak then return false end

  if not boop.executeAction(
      actions.standard,
      true,
      automaticDispatchOptions(authority, roomOwned)
    ) then
    return false
  end
  if boop.targets and boop.targets.onShieldbreakAttempt then
    boop.targets.onShieldbreakAttempt()
  end
  boop.trace.log("prequeue rebuilt: " .. tostring(reason or "state change"))
  return true
end

function boop.canAct()
  if boop.state.combat.limiters.hunting then return false end
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
  if boop.state.combat.limiters.rage then return false end
  boop.state.combat.limiters.rage = true
  tempTimer(0.6, function() boop.state.combat.limiters.rage = false end)
  return true
end

function boop.tick(sourceAuthority, options)
  if boop.runtime and boop.runtime.step and boop.runtime.applyEffects then
    local suppliedAuthority = copySourceAuthority(sourceAuthority)
    options = type(options) == "table" and options or {}
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
  if runtime() and boop.runtime.notePromptObserved then
    boop.runtime.notePromptObserved()
  end
  if not boop.config or not boop.config.enabled then
    return false
  end
  if boop.runtime and boop.runtime.step and boop.runtime.applyEffects then
    local sourceAuthority = currentRoomSourceAuthority()
    local context = boop.runtime.context(sourceAuthority, {
      roomOwned = sourceAuthority and true or false,
    })
    local result = boop.runtime.step({ type = "prompt", context = context })
    boop.runtime.applyEffects(result, context)
    if result.runTick then
      boop.tick(sourceAuthority or nil)
    end
    return
  end
end
