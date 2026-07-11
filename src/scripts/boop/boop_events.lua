boop.events = boop.events or {}

local function nowSeconds()
  if getEpoch then return getEpoch() end
  return os.clock()
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

local function findRoomGoldItem(items)
  if type(items) ~= "table" then return nil end
  for _, item in ipairs(items) do
    if isGoldItem(item) then
      return item
    end
  end
  return nil
end

local AUTO_GOLD_FLUSH_SECONDS = 0.35
local GOLD_READY_QUEUE = "freestand"

local function queueGoldCommand(command)
  send("queue add " .. GOLD_READY_QUEUE .. " " .. command, false)
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
  return { code = "", systems = {}, waitsFor = {}, observed = {} }
end

local function setBlocker(code, label, systems, waitsFor, opts)
  if runtime() and boop.runtime.setBlocker then
    return boop.runtime.setBlocker(code, label, systems, waitsFor, opts or {})
  end
  return false
end

local function shouldHold(system)
  return runtime() and boop.runtime.shouldHold and boop.runtime.shouldHold(system)
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
  return not not (gmcp and gmcp.IRE and gmcp.IRE.Target and gmcp.IRE.Display)
end

local function warnBlocker(blocker)
  if not (boop.util and boop.util.warn) then return end
  if type(blocker) ~= "table" or tostring(blocker.code or "") == "" then return end
  local stateBlocker = boop.state and boop.state.combat and boop.state.combat.blocker or nil
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
  local blocker = boop.state and boop.state.combat and boop.state.combat.blocker or nil
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

local function enterGmcpIreBlocker(source, supportAlreadyRequested)
  local previous = blockerSnapshot()
  local firstEntry = previous.code ~= "gmcp_ire_missing"
  local blocker = setBlocker("gmcp_ire_missing", "GMCP IRE missing", BLOCKER_SYSTEMS_GMCP, {
    gmcp = true,
    prompt = true,
  }, {
    source = source,
    observed = {
      ire = false,
    },
  })
  if supportAlreadyRequested then
    local stateBlocker = boop.state and boop.state.combat and boop.state.combat.blocker or nil
    if type(stateBlocker) == "table" then
      stateBlocker.lastRetryAt = nowSeconds()
    end
  else
    requestCoreSupportsThrottled(firstEntry)
  end
  warnBlocker(blocker)
  return blocker
end

local function reconcileIreSupport(source)
  if ireReady() then
    if runtime() and boop.runtime.noteGmcpObserved then
      boop.runtime.noteGmcpObserved("ire")
    end
    return true
  end
  enterGmcpIreBlocker(source)
  return false
end

local function enterRoomBlocker(code, label, observed)
  if blockerSnapshot().code == "gmcp_ire_missing" then
    return blockerSnapshot()
  end
  return setBlocker(code, label, BLOCKER_SYSTEMS_ROOM, {
    gmcp = true,
  }, {
    source = "room",
    observed = observed or {},
  })
end

local function roomInfoIsPartial(info)
  return not info or not info.num or type(info.exits) ~= "table"
end

local function noteRoomGmcpObserved()
  if blockerSnapshot().code == "gmcp_ire_missing" then
    return
  end
  if runtime() and boop.runtime.noteGmcpObserved then
    boop.runtime.noteGmcpObserved("room")
  end
end

local function noteTargetGmcpObserved()
  if blockerSnapshot().code == "gmcp_ire_missing" then
    return
  end
  if runtime() and boop.runtime.noteGmcpObserved then
    boop.runtime.noteGmcpObserved("target")
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

function boop.clearGoldQueueIntent()
  boop.state = boop.state or {}
  if boop.state.gold.autoGrabTimer then
    killTimer(boop.state.gold.autoGrabTimer)
    boop.state.gold.autoGrabTimer = nil
  end
  boop.state.gold.autoGrabPending = false
  boop.state.gold.autoGrabPendingAt = nil
  boop.state.gold.dropped = false
  if boop.state.gold.pendingTimer then
    killTimer(boop.state.gold.pendingTimer)
    boop.state.gold.pendingTimer = nil
  end
  boop.state.gold.getPending = false
  boop.state.gold.putPending = false
  boop.state.gold.getRetries = 0
  boop.state.gold.putRetries = 0
  boop.state.gold.packTarget = ""
end

local function stopGoldPendingTimeout()
  boop.state = boop.state or {}
  if boop.state.gold.pendingTimer then
    killTimer(boop.state.gold.pendingTimer)
    boop.state.gold.pendingTimer = nil
  end
end

local function armGoldPendingTimeout()
  boop.state = boop.state or {}
  stopGoldPendingTimeout()
  boop.state.gold.pendingTimer = tempTimer(4, function()
    boop.state.gold.pendingTimer = nil
    if not (boop.state.gold.getPending or boop.state.gold.putPending) then
      return
    end
    boop.trace.log("gold pending timeout: clearing stale state")
    boop.util.warn("auto gold: clearing stale pending state")
    boop.clearGoldQueueIntent()
    if boop.walk and boop.walk.maybeAdvance then
      boop.walk.maybeAdvance("gold timeout clear")
    elseif boop.tick then
      boop.tick()
    end
  end)
end

function boop.markGoldQueueIntent(pack)
  boop.state = boop.state or {}
  local target = boop.util.trim(pack or "")
  boop.state.gold.getPending = true
  boop.state.gold.putPending = target ~= ""
  boop.state.gold.getRetries = 0
  boop.state.gold.putRetries = 0
  boop.state.gold.packTarget = target
  armGoldPendingTimeout()
end

local function queueGoldCommands()
  local pack = boop.util.trim(boop.config.goldPack or "")
  boop.markGoldQueueIntent(pack)
  queueGoldCommand("get sovereigns")
  boop.trace.log("gold queue: get sovereigns")

  if pack ~= "" then
    queueGoldCommand("put sovereigns in " .. pack)
    boop.trace.log("gold queue: put sovereigns in " .. pack)
  end
end

local cancelAutoGrabGoldTimer
local flushPendingGold

local function clearPendingGoldDrop(reason)
  boop.state = boop.state or {}
  if not boop.state.gold.autoGrabPending then
    return false
  end
  cancelAutoGrabGoldTimer()
  boop.state.gold.autoGrabPending = false
  boop.state.gold.autoGrabPendingAt = nil
  boop.state.gold.dropped = false
  if reason then
    boop.trace.log("gold pending clear: " .. tostring(reason))
  end
  return true
end

local function maybeFlushPendingGold(reason)
  boop.state = boop.state or {}
  if not boop.state.gold.autoGrabPending then return false end
  if shouldHold("gold") then
    traceHeld("gold", reason or "pending age exceeded")
    return false
  end
  if boop.state.gold.getPending or boop.state.gold.putPending then return false end
  local startedAt = tonumber(boop.state.gold.autoGrabPendingAt) or 0
  if startedAt <= 0 then return false end
  if (nowSeconds() - startedAt) < AUTO_GOLD_FLUSH_SECONDS then return false end
  return flushPendingGold(reason or "pending age exceeded")
end

local function onGoldDetected(source)
  if not boop.config.enabled then return end
  if not boop.config.autoGrabGold then return end
  if shouldHold("gold") then
    traceHeld("gold", source or "gold detected")
    return
  end

  boop.state = boop.state or {}
  boop.trace.log("gold drop detected" .. (source and (": " .. source) or ""))

  if boop.config.useQueueing then
    boop.state.gold.autoGrabPending = true
    boop.state.gold.autoGrabPendingAt = nowSeconds()
    boop.state.gold.dropped = true

    local denizenCount = boop.state.targeting.denizens and #boop.state.targeting.denizens or 0
    if denizenCount <= 0 then
      flushPendingGold("room clear on drop")
      return
    end

    cancelAutoGrabGoldTimer()
    boop.state.gold.autoGrabTimer = tempTimer(AUTO_GOLD_FLUSH_SECONDS, function()
      if not boop.config or not boop.config.enabled or not boop.config.autoGrabGold then
        cancelAutoGrabGoldTimer()
        return
      end
      flushPendingGold("fallback timer")
    end)
  else
    if boop.state.gold.getPending or boop.state.gold.putPending then
      return
    end
    queueGoldCommands()
  end
end

cancelAutoGrabGoldTimer = function()
  if boop.state and boop.state.gold.autoGrabTimer then
    killTimer(boop.state.gold.autoGrabTimer)
    boop.state.gold.autoGrabTimer = nil
  end
end

flushPendingGold = function(reason)
  boop.state = boop.state or {}
  if not boop.state.gold.autoGrabPending then return false end
  if shouldHold("gold") then
    traceHeld("gold", reason or "pending flush")
    return false
  end
  cancelAutoGrabGoldTimer()
  boop.state.gold.autoGrabPending = false
  boop.state.gold.autoGrabPendingAt = nil
  boop.state.gold.dropped = false
  boop.trace.log("gold pending flush: " .. tostring(reason or "unspecified"))
  queueGoldCommands()
  return true
end

boop.flushPendingGold = flushPendingGold
boop.maybeFlushPendingGold = maybeFlushPendingGold

local function autoGrabRoomItem(item)
  if not isGoldItem(item) then return end
  onGoldDetected("gmcp room item")
end

function boop.onGoldDropLine(rawLine)
  local line = boop.util.safeLower(boop.util.trim(rawLine or ""))
  if line == "" then return end
  if not line:find("sovereign", 1, true) then return end
  onGoldDetected("text line")
end

local function retryGoldGet(reason)
  boop.state = boop.state or {}
  if not boop.state.gold.getPending then return end
  local retries = boop.state.gold.getRetries or 0
  if retries >= 2 then
    boop.trace.log("gold get failed; giving up: " .. tostring(reason))
    boop.util.err("auto gold: unable to get sovereigns; check room loot/line timing")
    boop.state.gold.getPending = false
    boop.state.gold.putPending = false
    boop.state.gold.packTarget = ""
    stopGoldPendingTimeout()
    return
  end
  boop.state.gold.getRetries = retries + 1
  armGoldPendingTimeout()
  queueGoldCommand("get sovereigns")
  boop.trace.log("gold get retry " .. tostring(boop.state.gold.getRetries) .. ": " .. tostring(reason))
end

local function retryGoldPut(reason)
  boop.state = boop.state or {}
  if not boop.state.gold.putPending then return end
  local pack = boop.state.gold.packTarget or ""
  if pack == "" then
    boop.state.gold.putPending = false
    return
  end

  local retries = boop.state.gold.putRetries or 0
  if retries >= 1 then
    boop.trace.log("gold put failed for pack " .. pack .. "; giving up: " .. tostring(reason))
    boop.util.err("auto gold: unable to put sovereigns in " .. pack .. "; use `boop pack test`")
    boop.state.gold.putPending = false
    stopGoldPendingTimeout()
    return
  end
  boop.state.gold.putRetries = retries + 1
  armGoldPendingTimeout()
  queueGoldCommand("put sovereigns in " .. pack)
  boop.trace.log("gold put retry " .. tostring(boop.state.gold.putRetries) .. " for " .. pack .. ": " .. tostring(reason))
end

function boop.onGoldGetSuccess()
  boop.state = boop.state or {}
  if not boop.state.gold.getPending then return end
  boop.state.gold.getPending = false
  boop.state.gold.getRetries = 0
  if not boop.state.gold.putPending then
    boop.state.gold.putPending = false
    stopGoldPendingTimeout()
  end
  boop.trace.log("gold get success")
  if not boop.state.gold.putPending and boop.walk and boop.walk.maybeAdvance then
    boop.walk.maybeAdvance("gold get success")
  end
end

function boop.onGoldPutSuccess()
  boop.state = boop.state or {}
  if not boop.state.gold.putPending then return end
  boop.state.gold.putPending = false
  boop.state.gold.putRetries = 0
  stopGoldPendingTimeout()
  boop.trace.log("gold put success")
  if boop.walk and boop.walk.maybeAdvance then
    boop.walk.maybeAdvance("gold put success")
  end
end

function boop.onGoldCommandFailure(line)
  boop.state = boop.state or {}
  local reason = boop.util.trim(line or "")
  if boop.state.gold.getPending then
    retryGoldGet(reason)
    if not boop.state.gold.getPending and not boop.state.gold.putPending and boop.walk and boop.walk.maybeAdvance then
      boop.walk.maybeAdvance("gold get failed closed")
    end
    return
  end
  if boop.state.gold.putPending then
    retryGoldPut(reason)
    if not boop.state.gold.putPending and boop.walk and boop.walk.maybeAdvance then
      boop.walk.maybeAdvance("gold put failed closed")
    end
    return
  end
  if boop.walk and boop.walk.maybeAdvance then
    boop.walk.maybeAdvance("gold failure clear")
  end
end

function boop.onDiagReadyLine()
  if not boop.state or not boop.state.diag.hold then return end
  boop.state.diag.awaitPrompt = true
  boop.trace.log("diag ready line seen")
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
  if not ireReady() then
    enterGmcpIreBlocker("connection", true)
  elseif runtime() and boop.runtime.noteGmcpObserved then
    boop.runtime.noteGmcpObserved("ire")
  end
end

function boop.onRoomItemsList()
  if not gmcp or not gmcp.Char or not gmcp.Char.Items or not gmcp.Char.Items.List then return end
  if gmcp.Char.Items.List.location == "inv" then
    rebuildWieldedFromInventory(gmcp.Char.Items.List.items, "inventory list")
    return
  end
  if gmcp.Char.Items.List.location ~= "room" then return end
  local items = gmcp.Char.Items.List.items
  if type(items) ~= "table" then
    enterRoomBlocker("room_partial", "partial room state", {
      room = tostring(gmcp.Room and gmcp.Room.Info and gmcp.Room.Info.num or ""),
      items = false,
    })
    return
  end
  noteRoomGmcpObserved()
  boop.targets.updateRoomItems(items)

  -- Fallback for cases where item-add events are delayed/coalesced: if gold
  -- exists in the room list and we're not already processing a pickup, queue it.
  local goldItem = findRoomGoldItem(items)
  traceRoomItemsList(items, goldItem)
  if goldItem then
    boop.state = boop.state or {}
    if shouldHold("gold") then
      traceHeld("gold", "room items list")
    elseif not (boop.state.gold.autoGrabPending or boop.state.gold.getPending or boop.state.gold.putPending) then
      autoGrabRoomItem(goldItem)
    end
  end
  if shouldHold("walk") then
    traceHeld("walk", "room items list")
  elseif boop.walk and boop.walk.onRoomSettled then
    boop.walk.onRoomSettled("room items list")
  end
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
  noteRoomGmcpObserved()
  if shouldHold("gold") then
    traceHeld("gold", "room item add")
  else
    autoGrabRoomItem(item)
  end
end

function boop.onRoomItemsRemove()
  if not gmcp or not gmcp.Char or not gmcp.Char.Items or not gmcp.Char.Items.Remove then return end
  if gmcp.Char.Items.Remove.location == "inv" then
    removeInvItem(gmcp.Char.Items.Remove.item, "inventory remove")
    return
  end
  if gmcp.Char.Items.Remove.location ~= "room" then return end
  local removed = gmcp.Char.Items.Remove.item
  local removedId = tostring((removed and removed.id) or "")
  local removedName = removed and removed.name or ""
  local removedWasGold = isGoldItem(removed)
  traceRoomItemEvent("remove", removed)
  boop.targets.removeRoomItem(removed)
  noteRoomGmcpObserved()

  if removedWasGold then
    boop.state = boop.state or {}
    if boop.state.gold.autoGrabPending then
      clearPendingGoldDrop("gold removed before flush")
    end
    if boop.state.gold.getPending or boop.state.gold.putPending then
      boop.trace.log("gold room item removed while pending: clearing stale gold state")
      boop.clearGoldQueueIntent()
    end
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
    setBlocker("pull_away", "pull in progress", {
      target = true,
      combat = true,
      walk = true,
    }, {
      room = true,
    }, {
      source = "pull",
      observed = {
        originRoom = tostring(pull.originRoom or ""),
        currentRoom = tostring(boop.state.targeting.room or ""),
      },
    })
    return
  end

  if boop.trace and boop.trace.log then
    boop.trace.log(string.format("target lost: %s -- %s", removedId, tostring(removedName or "")))
  end
  if boop.runtime and boop.runtime.clearAutomationIntent then
    boop.runtime.clearAutomationIntent("target_lost")
  else
    boop.state.targeting.currentTargetId = ""
    boop.state.targeting.targetName = ""
    boop.state.queue.prequeuedStandard = false
    boop.state.queue.aliasDirty = true
    if boop.targets and boop.targets.clearTargetShield then
      boop.targets.clearTargetShield("target removed")
    end
  end
  if boop.afflictions and boop.afflictions.clearTarget then
    boop.afflictions.clearTarget()
  end

  if not boop.config or not boop.config.enabled or boop.state.diag.hold then
    return
  end

  local nextTarget = boop.targets and boop.targets.choose and boop.targets.choose() or ""
  if nextTarget ~= "" then
    if boop.trace and boop.trace.log then
      boop.trace.log(string.format(
        "retarget selected: %s -- %s | reason=target_lost",
        tostring(nextTarget),
        denizenNameById(nextTarget)
      ))
    end
    boop.targets.setTarget(nextTarget)
  else
    setBlocker("target_lost", "target left room", {
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

  tempTimer(0, function()
    if boop and boop.tick then
      boop.tick()
    end
  end)
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

  local info = gmcp.Room.Info
  if roomInfoIsPartial(info) then
    enterRoomBlocker("room_partial", "partial room state", {
      room = tostring(info and info.num or ""),
      exits = type(info and info.exits) == "table",
    })
  else
    noteRoomGmcpObserved()
  end
  local targeting = boop.state.targeting
  local combat = boop.state.combat
  local previousRoom = targeting.room
  local previousRoomText = boop.util.trim(tostring(previousRoom or ""))
  local currentRoomText = boop.util.trim(tostring(info.num or ""))

  if previousRoomText ~= currentRoomText then
    targeting.movedRooms = true
    targeting.lastRoom = previousRoom
    boop.clearGoldQueueIntent()
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
    if boop.walk and boop.walk.onRoomChange then
      boop.walk.onRoomChange()
    end
  else
    targeting.movedRooms = false
  end

  targeting.room = info.num
  traceRoomInfo(info, targeting.movedRooms, previousRoom)
  if targeting.movedRooms and tostring(targeting.lastRoom or "") ~= "" and boop.stats and boop.stats.onRoomChange then
    boop.stats.onRoomChange()
  end

  local pull = combat.pullState
  if type(pull) == "table" and pull.active then
    local currentRoom = boop.util.trim(tostring(targeting.room or ""))
    local originRoom = boop.util.trim(tostring(pull.originRoom or ""))
    if currentRoom ~= "" and originRoom ~= "" then
      if pull.phase == "outbound" and currentRoom ~= originRoom then
        pull.phase = "away"
        boop.trace.log("pull: away room " .. currentRoom)
      elseif pull.phase == "away" and currentRoom == originRoom then
        if boop.ui and boop.ui.clearPullState then
          boop.ui.clearPullState("returned to origin")
        else
          combat.pullState = false
        end
        if pull.restoreEnabled then
          boop.ui.setEnabled(true, true)
          boop.util.ok("pull complete; boop resumed")
        else
          boop.util.ok("pull complete")
        end
        boop.trace.log("pull: returned to origin")
        if boop.runtime and boop.runtime.clearBlocker and blockerSnapshot().code == "pull_away" then
          boop.runtime.clearBlocker("pull returned")
        end
        if not currentTargetStillInRoom() and boop.runtime and boop.runtime.clearAutomationIntent then
          boop.runtime.clearAutomationIntent("target_lost")
        end
      end
    end
  end
end

function boop.onWalkArrived()
  if boop.walk and boop.walk.onArrived then
    boop.walk.onArrived()
  end
end

function boop.onWalkFinished()
  if boop.walk and boop.walk.onFinished then
    boop.walk.onFinished()
  end
end

function boop.onTargetSet()
  if not gmcp or not gmcp.IRE or not gmcp.IRE.Target or not gmcp.IRE.Target.Set then return end
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
  noteTargetGmcpObserved()
  local info = gmcp.IRE.Target.Info
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
  reconcileIreSupport("char status")
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

function boop.onBalanceUsed(kind, seconds)
  local duration = tonumber(seconds)
  if not duration then return end
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
  boop.schedulePrequeue()
end

function boop.schedulePrequeue()
  if shouldHold("queue") or shouldHold("target") or shouldHold("combat") then
    if boop.state.queue.prequeueTimer then
      killTimer(boop.state.queue.prequeueTimer)
      boop.state.queue.prequeueTimer = nil
    end
    traceHeld("queue", "schedule prequeue")
    return
  end
  if not boop.config.prequeueEnabled then
    if boop.state.queue.prequeueTimer then
      killTimer(boop.state.queue.prequeueTimer)
      boop.state.queue.prequeueTimer = nil
    end
    return
  end

  local lead = tonumber(boop.config.attackLeadSeconds) or 0
  if lead <= 0 or not boop.config.enabled then
    if boop.state.queue.prequeueTimer then
      killTimer(boop.state.queue.prequeueTimer)
      boop.state.queue.prequeueTimer = nil
    end
    return
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
  boop.state.queue.prequeueTimer = tempTimer(delay, function()
    boop.state.queue.prequeueTimer = nil
    boop.prequeueStandard()
  end)
end

function boop.prequeueStandard()
  if not boop.config.enabled then return end
  if not boop.config.prequeueEnabled then return end
  if shouldHold("queue") or shouldHold("target") or shouldHold("combat") or shouldHold("gold") then
    traceHeld("queue", "prequeue standard")
    return
  end
  if boop.state.diag.hold then return end
  if boop.state.gold.getPending or boop.state.gold.putPending then return end
  if boop.state.queue.prequeuedStandard then return end
  if gmcp and gmcp.Char and gmcp.Char.Vitals then
    if gmcp.Char.Vitals.bal == "1" and gmcp.Char.Vitals.eq == "1" then
      return
    end
  end

  if boop.safety and boop.safety.shouldFlee and boop.safety.shouldFlee() then
    return
  end

  local targetId = boop.targets.choose()
  if not targetId or targetId == "" then
    if boop.config.useQueueing and boop.state.gold.autoGrabPending then
      flushPendingGold("prequeue no target")
    end
    if boop.targets and boop.targets.waitingForTargetCall and boop.targets.waitingForTargetCall() then
      return
    end
    return
  end

  if boop.state.targeting.currentTargetId ~= targetId then
    boop.targets.setTarget(targetId)
  end

  local actions = boop.attacks.choose()
  if actions.standard and actions.standard ~= "" then
    boop.executeAction(actions.standard, true)
    if actions.standardIsOpener and boop.attacks and boop.attacks.markOpenerUsed then
      boop.attacks.markOpenerUsed(classKeyForOpener(), targetId)
    end
    if actions.standardShieldbreak and boop.targets and boop.targets.onShieldbreakAttempt then
      boop.targets.onShieldbreakAttempt()
    end
    boop.state.queue.prequeuedStandard = true
    boop.trace.log("prequeue sent standard")
  end
end

function boop.refreshPrequeuedStandard(reason)
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

  local actions = boop.attacks.choose()
  if not actions.standard or actions.standard == "" then return false end
  if not actions.standardShieldbreak then return false end

  boop.executeAction(actions.standard, true)
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

function boop.tick()
  if boop.runtime and boop.runtime.step and boop.runtime.applyEffects then
    local context = boop.runtime.context()
    local result = boop.runtime.step({ type = "tick", context = context })
    boop.state.combat.attacking = boop.runtime.applyEffects(result, context)
    return
  end
end

function boop.onPrompt()
  if runtime() and boop.runtime.notePromptObserved then
    boop.runtime.notePromptObserved()
  end
  if boop.runtime and boop.runtime.step and boop.runtime.applyEffects then
    local context = boop.runtime.context()
    local result = boop.runtime.step({ type = "prompt", context = context })
    boop.runtime.applyEffects(result, context)
    if result.runTick then
      boop.tick()
    end
    return
  end
end
