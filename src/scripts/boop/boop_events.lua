boop.events = boop.events or {}

local function nowSeconds()
  if getEpoch then return getEpoch() end
  return os.clock()
end

local function classKeyForOpener()
  if gmcp and gmcp.Char and gmcp.Char.Status and gmcp.Char.Status.class then
    return gmcp.Char.Status.class
  end
  return boop.state and boop.state.class or ""
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

function boop.clearGoldQueueIntent()
  boop.state = boop.state or {}
  if boop.state.autoGrabGoldTimer then
    killTimer(boop.state.autoGrabGoldTimer)
    boop.state.autoGrabGoldTimer = nil
  end
  boop.state.autoGrabGoldPending = false
  boop.state.autoGrabGoldPendingAt = nil
  boop.state.goldDropped = false
  if boop.state.goldPendingTimer then
    killTimer(boop.state.goldPendingTimer)
    boop.state.goldPendingTimer = nil
  end
  boop.state.goldGetPending = false
  boop.state.goldPutPending = false
  boop.state.goldGetRetries = 0
  boop.state.goldPutRetries = 0
  boop.state.goldPackTarget = ""
end

local function stopGoldPendingTimeout()
  boop.state = boop.state or {}
  if boop.state.goldPendingTimer then
    killTimer(boop.state.goldPendingTimer)
    boop.state.goldPendingTimer = nil
  end
end

local function armGoldPendingTimeout()
  boop.state = boop.state or {}
  stopGoldPendingTimeout()
  boop.state.goldPendingTimer = tempTimer(4, function()
    boop.state.goldPendingTimer = nil
    if not (boop.state.goldGetPending or boop.state.goldPutPending) then
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
  boop.state.goldGetPending = true
  boop.state.goldPutPending = target ~= ""
  boop.state.goldGetRetries = 0
  boop.state.goldPutRetries = 0
  boop.state.goldPackTarget = target
  armGoldPendingTimeout()
end

local function queueGoldCommands()
  local pack = boop.util.trim(boop.config.goldPack or "")
  boop.markGoldQueueIntent(pack)
  send("queue add balance get sovereigns", false)
  boop.trace.log("gold queue: get sovereigns")

  if pack ~= "" then
    send("queue add balance put sovereigns in " .. pack, false)
    boop.trace.log("gold queue: put sovereigns in " .. pack)
  end
end

local cancelAutoGrabGoldTimer
local flushPendingGold

local function clearPendingGoldDrop(reason)
  boop.state = boop.state or {}
  if not boop.state.autoGrabGoldPending then
    return false
  end
  cancelAutoGrabGoldTimer()
  boop.state.autoGrabGoldPending = false
  boop.state.autoGrabGoldPendingAt = nil
  boop.state.goldDropped = false
  if reason then
    boop.trace.log("gold pending clear: " .. tostring(reason))
  end
  return true
end

local function maybeFlushPendingGold(reason)
  boop.state = boop.state or {}
  if not boop.state.autoGrabGoldPending then return false end
  if boop.state.goldGetPending or boop.state.goldPutPending then return false end
  local startedAt = tonumber(boop.state.autoGrabGoldPendingAt) or 0
  if startedAt <= 0 then return false end
  if (nowSeconds() - startedAt) < AUTO_GOLD_FLUSH_SECONDS then return false end
  return flushPendingGold(reason or "pending age exceeded")
end

local function onGoldDetected(source)
  if not boop.config.enabled then return end
  if not boop.config.autoGrabGold then return end

  boop.state = boop.state or {}
  boop.trace.log("gold drop detected" .. (source and (": " .. source) or ""))

  if boop.config.useQueueing then
    boop.state.autoGrabGoldPending = true
    boop.state.autoGrabGoldPendingAt = nowSeconds()
    boop.state.goldDropped = true

    local denizenCount = boop.state.denizens and #boop.state.denizens or 0
    if denizenCount <= 0 then
      flushPendingGold("room clear on drop")
      return
    end

    cancelAutoGrabGoldTimer()
    boop.state.autoGrabGoldTimer = tempTimer(AUTO_GOLD_FLUSH_SECONDS, function()
      if not boop.config or not boop.config.enabled or not boop.config.autoGrabGold then
        cancelAutoGrabGoldTimer()
        return
      end
      flushPendingGold("fallback timer")
    end)
  else
    if boop.state.goldGetPending or boop.state.goldPutPending then
      return
    end
    queueGoldCommands()
  end
end

cancelAutoGrabGoldTimer = function()
  if boop.state and boop.state.autoGrabGoldTimer then
    killTimer(boop.state.autoGrabGoldTimer)
    boop.state.autoGrabGoldTimer = nil
  end
end

flushPendingGold = function(reason)
  boop.state = boop.state or {}
  if not boop.state.autoGrabGoldPending then return false end
  cancelAutoGrabGoldTimer()
  boop.state.autoGrabGoldPending = false
  boop.state.autoGrabGoldPendingAt = nil
  boop.state.goldDropped = false
  boop.trace.log("gold pending flush: " .. tostring(reason or "unspecified"))
  queueGoldCommands()
  return true
end

boop.flushPendingGold = flushPendingGold

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
  if not boop.state.goldGetPending then return end
  local retries = boop.state.goldGetRetries or 0
  if retries >= 2 then
    boop.trace.log("gold get failed; giving up: " .. tostring(reason))
    boop.util.err("auto gold: unable to get sovereigns; check room loot/line timing")
    boop.state.goldGetPending = false
    boop.state.goldPutPending = false
    boop.state.goldPackTarget = ""
    stopGoldPendingTimeout()
    return
  end
  boop.state.goldGetRetries = retries + 1
  armGoldPendingTimeout()
  send("queue add balance get sovereigns", false)
  boop.trace.log("gold get retry " .. tostring(boop.state.goldGetRetries) .. ": " .. tostring(reason))
end

local function retryGoldPut(reason)
  boop.state = boop.state or {}
  if not boop.state.goldPutPending then return end
  local pack = boop.state.goldPackTarget or ""
  if pack == "" then
    boop.state.goldPutPending = false
    return
  end

  local retries = boop.state.goldPutRetries or 0
  if retries >= 1 then
    boop.trace.log("gold put failed for pack " .. pack .. "; giving up: " .. tostring(reason))
    boop.util.err("auto gold: unable to put sovereigns in " .. pack .. "; use `boop pack test`")
    boop.state.goldPutPending = false
    stopGoldPendingTimeout()
    return
  end
  boop.state.goldPutRetries = retries + 1
  armGoldPendingTimeout()
  send("queue add balance put sovereigns in " .. pack, false)
  boop.trace.log("gold put retry " .. tostring(boop.state.goldPutRetries) .. " for " .. pack .. ": " .. tostring(reason))
end

function boop.onGoldGetSuccess()
  boop.state = boop.state or {}
  if not boop.state.goldGetPending then return end
  boop.state.goldGetPending = false
  boop.state.goldGetRetries = 0
  if not boop.state.goldPutPending then
    boop.state.goldPutPending = false
    stopGoldPendingTimeout()
  end
  boop.trace.log("gold get success")
  if not boop.state.goldPutPending and boop.walk and boop.walk.maybeAdvance then
    boop.walk.maybeAdvance("gold get success")
  end
end

function boop.onGoldPutSuccess()
  boop.state = boop.state or {}
  if not boop.state.goldPutPending then return end
  boop.state.goldPutPending = false
  boop.state.goldPutRetries = 0
  stopGoldPendingTimeout()
  boop.trace.log("gold put success")
  if boop.walk and boop.walk.maybeAdvance then
    boop.walk.maybeAdvance("gold put success")
  end
end

function boop.onGoldCommandFailure(line)
  boop.state = boop.state or {}
  local reason = boop.util.trim(line or "")
  if boop.state.goldGetPending then
    retryGoldGet(reason)
    if not boop.state.goldGetPending and not boop.state.goldPutPending and boop.walk and boop.walk.maybeAdvance then
      boop.walk.maybeAdvance("gold get failed closed")
    end
    return
  end
  if boop.state.goldPutPending then
    retryGoldPut(reason)
    if not boop.state.goldPutPending and boop.walk and boop.walk.maybeAdvance then
      boop.walk.maybeAdvance("gold put failed closed")
    end
    return
  end
  if boop.walk and boop.walk.maybeAdvance then
    boop.walk.maybeAdvance("gold failure clear")
  end
end

function boop.onDiagReadyLine()
  if not boop.state or not boop.state.diagHold then return end
  boop.state.diagAwaitPrompt = true
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
  add("gmcp.Room.Info", "boop.onRoomInfo")
  add("gmcp.IRE.Target.Set", "boop.onTargetSet")
  add("gmcp.IRE.Target.Info", "boop.onTargetInfo")
  add("gmcp.Char.Status", "boop.onCharStatus")
  add("gmcp.Char.Vitals", "boop.onVitals")
  add("gmcp.Char.Skills.Groups", "boop.onSkillsGroups")
  add("gmcp.Char.Skills.List", "boop.onSkillsList")
  add("gmcp.Char.Skills.Info", "boop.onSkillsInfo")
  add("demonwalker.arrived", "boop.onWalkArrived")
  add("demonwalker.finished", "boop.onWalkFinished")
end

function boop.onRoomItemsList()
  if not gmcp or not gmcp.Char or not gmcp.Char.Items or not gmcp.Char.Items.List then return end
  if gmcp.Char.Items.List.location ~= "room" then return end
  local items = gmcp.Char.Items.List.items
  boop.targets.updateRoomItems(items)

  -- Fallback for cases where item-add events are delayed/coalesced: if gold
  -- exists in the room list and we're not already processing a pickup, queue it.
  local goldItem = findRoomGoldItem(items)
  traceRoomItemsList(items, goldItem)
  if goldItem then
    boop.state = boop.state or {}
    if not (boop.state.autoGrabGoldPending or boop.state.goldGetPending or boop.state.goldPutPending) then
      autoGrabRoomItem(goldItem)
    end
  end
  if boop.walk and boop.walk.onRoomSettled then
    boop.walk.onRoomSettled("room items list")
  end
end

function boop.onRoomItemsAdd()
  if not gmcp or not gmcp.Char or not gmcp.Char.Items or not gmcp.Char.Items.Add then return end
  if gmcp.Char.Items.Add.location ~= "room" then return end
  local item = gmcp.Char.Items.Add.item
  traceRoomItemEvent("add", item)
  boop.targets.addRoomItem(item)
  autoGrabRoomItem(item)
end

function boop.onRoomItemsRemove()
  if not gmcp or not gmcp.Char or not gmcp.Char.Items or not gmcp.Char.Items.Remove then return end
  if gmcp.Char.Items.Remove.location ~= "room" then return end
  local removed = gmcp.Char.Items.Remove.item
  local removedId = tostring((removed and removed.id) or "")
  local removedName = removed and removed.name or ""
  local removedWasGold = isGoldItem(removed)
  traceRoomItemEvent("remove", removed)
  boop.targets.removeRoomItem(removed)

  if removedWasGold then
    boop.state = boop.state or {}
    if boop.state.autoGrabGoldPending then
      clearPendingGoldDrop("gold removed before flush")
    end
    if boop.state.goldGetPending or boop.state.goldPutPending then
      boop.trace.log("gold room item removed while pending: clearing stale gold state")
      boop.clearGoldQueueIntent()
    end
  end

  if removedId ~= "" and boop.targets and boop.targets.clearTargetCall and tostring(boop.state.calledTargetId or "") == removedId then
    boop.targets.clearTargetCall("called target removed")
  end

  if removedId == "" then
    return
  end

  boop.state = boop.state or {}
  local current = tostring(boop.state.currentTargetId or "")
  if current == "" or current ~= removedId then
    return
  end

  if boop.stats and boop.stats.onTargetRemoved then
    boop.stats.onTargetRemoved(removedId, removedName)
  end
  boop.state.currentTargetId = ""
  boop.state.targetName = ""
  boop.state.prequeuedStandard = false
  boop.state.queueAliasDirty = true

  if boop.targets and boop.targets.clearTargetShield then
    boop.targets.clearTargetShield("target removed")
  end
  if boop.afflictions and boop.afflictions.clearTarget then
    boop.afflictions.clearTarget()
  end

  if not boop.config or not boop.config.enabled or boop.state.diagHold then
    return
  end

  local nextTarget = boop.targets and boop.targets.choose and boop.targets.choose() or ""
  if nextTarget ~= "" then
    boop.targets.setTarget(nextTarget)
  end

  tempTimer(0, function()
    if boop and boop.tick then
      boop.tick()
    end
  end)
end

function boop.onRoomInfo()
  if not gmcp or not gmcp.Room or not gmcp.Room.Info then return end
  local vars = boop.state
  local previousRoom = vars.room

  if vars.room ~= gmcp.Room.Info.num then
    vars.movedRooms = true
    vars.lastRoom = vars.room
    boop.clearGoldQueueIntent()
    if boop.targets and boop.targets.clearTargetCall then
      boop.targets.clearTargetCall("room changed")
    end
    if boop.targets and boop.targets.clearTargetShield then
      boop.targets.clearTargetShield("room changed")
    end

    if not vars.fleeing then
      if gmcp.Room.Info.exits then
        for dir, id in pairs(gmcp.Room.Info.exits) do
          if tonumber(id) == tonumber(vars.room) then
            vars.lastRoomDir = dir
          end
        end
      end
    else
      vars.lastRoomDir = ""
      vars.fleeing = false
    end
    if boop.walk and boop.walk.onRoomChange then
      boop.walk.onRoomChange()
    end
  else
    vars.movedRooms = false
  end

  vars.room = gmcp.Room.Info.num
  traceRoomInfo(gmcp.Room.Info, vars.movedRooms, previousRoom)
  if vars.movedRooms and vars.lastRoom ~= "" and boop.stats and boop.stats.onRoomChange then
    boop.stats.onRoomChange()
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
  local newId = tostring(gmcp.IRE.Target.Set or "")
  local oldId = tostring(boop.state.currentTargetId or "")
  if oldId ~= "" and newId ~= "" and oldId ~= newId and boop.targets and boop.targets.clearTargetShield then
    boop.targets.clearTargetShield("target gmcp set changed")
  end
  boop.state.currentTargetId = newId
end

function boop.onTargetInfo()
  if not gmcp or not gmcp.IRE or not gmcp.IRE.Target or not gmcp.IRE.Target.Info then return end
  if gmcp.IRE.Target.Info.id then
    local newId = tostring(gmcp.IRE.Target.Info.id or "")
    local oldId = tostring(boop.state.currentTargetId or "")
    if oldId ~= "" and newId ~= "" and oldId ~= newId and boop.targets and boop.targets.clearTargetShield then
      boop.targets.clearTargetShield("target gmcp info changed")
    end
    boop.state.currentTargetId = newId
  end
end

function boop.onCharStatus()
  if not gmcp or not gmcp.Char or not gmcp.Char.Status then return end
  if gmcp.Char.Status.class then
    local newClass = gmcp.Char.Status.class
    if boop.state.class ~= newClass then
      boop.state.class = newClass
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
    boop.state.spec = spec
  end
  boop.tick()
end

function boop.onBalanceUsed(kind, seconds)
  local duration = tonumber(seconds)
  if not duration then return end
  local key = boop.util.safeLower(kind or "")
  local readyAt = nowSeconds() + duration
  if key == "balance" then
    boop.state.balanceReadyAt = readyAt
  elseif key == "equilibrium" then
    boop.state.equilibriumReadyAt = readyAt
  else
    return
  end
  boop.state.prequeuedStandard = false
  boop.schedulePrequeue()
end

function boop.schedulePrequeue()
  if not boop.config.prequeueEnabled then
    if boop.state.prequeueTimer then
      killTimer(boop.state.prequeueTimer)
      boop.state.prequeueTimer = nil
    end
    return
  end

  local lead = tonumber(boop.config.attackLeadSeconds) or 0
  if lead <= 0 or not boop.config.enabled then
    if boop.state.prequeueTimer then
      killTimer(boop.state.prequeueTimer)
      boop.state.prequeueTimer = nil
    end
    return
  end

  local bal = boop.state.balanceReadyAt or 0
  local eq = boop.state.equilibriumReadyAt or 0
  local readyAt = math.max(bal, eq)
  if readyAt <= 0 then return end

  local delay = readyAt - lead - nowSeconds()
  if delay < 0 then delay = 0 end
  boop.trace.log(string.format("prequeue scheduled in %.2fs (lead %.2fs)", delay, lead))

  if boop.state.prequeueTimer then
    killTimer(boop.state.prequeueTimer)
  end
  boop.state.prequeueTimer = tempTimer(delay, function()
    boop.state.prequeueTimer = nil
    boop.prequeueStandard()
  end)
end

function boop.prequeueStandard()
  if not boop.config.enabled then return end
  if not boop.config.prequeueEnabled then return end
  if boop.state.diagHold then return end
  if boop.state.goldGetPending or boop.state.goldPutPending then return end
  if boop.state.prequeuedStandard then return end
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
    if boop.config.useQueueing and boop.state.autoGrabGoldPending then
      flushPendingGold("prequeue no target")
    end
    if boop.targets and boop.targets.waitingForTargetCall and boop.targets.waitingForTargetCall() then
      return
    end
    return
  end

  if boop.state.currentTargetId ~= targetId then
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
    boop.state.prequeuedStandard = true
    boop.trace.log("prequeue sent standard")
  end
end

function boop.refreshPrequeuedStandard(reason)
  if not boop.config.enabled then return false end
  if not boop.config.prequeueEnabled then return false end
  if not boop.state.prequeuedStandard then return false end
  if boop.state.diagHold then return false end
  if boop.state.goldGetPending or boop.state.goldPutPending then return false end
  if gmcp and gmcp.Char and gmcp.Char.Vitals then
    if gmcp.Char.Vitals.bal == "1" and gmcp.Char.Vitals.eq == "1" then
      return false
    end
  end

  local targetId = boop.targets.choose()
  if not targetId or targetId == "" then return false end
  if tostring(boop.state.currentTargetId or "") ~= tostring(targetId) then
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
  if boop.state.limiters.hunting then return false end
  if gmcp and gmcp.Char and gmcp.Char.Vitals then
    if gmcp.Char.Vitals.bal ~= "1" or gmcp.Char.Vitals.eq ~= "1" then
      return false
    end
  end
  boop.state.limiters.hunting = true
  tempTimer(0.4, function() boop.state.limiters.hunting = false end)
  return true
end

function boop.canUseRage()
  if boop.state.limiters.rage then return false end
  boop.state.limiters.rage = true
  tempTimer(0.6, function() boop.state.limiters.rage = false end)
  return true
end

function boop.tick()
  if not boop.config.enabled then return end
  if boop.state.diagHold then return end
  if maybeFlushPendingGold("tick pending age") then return end
  if boop.state.goldGetPending or boop.state.goldPutPending then return end

  if boop.safety and boop.safety.shouldFlee and boop.safety.shouldFlee() then
    boop.safety.flee()
    return
  end

  local targetId = boop.targets.choose()
  if not targetId or targetId == "" then
    boop.state.attacking = false
    if boop.config.useQueueing and boop.state.autoGrabGoldPending then
      flushPendingGold("tick no target")
    end
    if boop.targets and boop.targets.waitingForTargetCall and boop.targets.waitingForTargetCall() then
      boop.trace.log("tick: waiting for leader target call")
      return
    end
    boop.trace.log("tick: no target")
    if boop.walk and boop.walk.maybeAdvance then
      boop.walk.maybeAdvance("tick no target")
    end
    return
  end

  if boop.state.currentTargetId ~= targetId then
    boop.targets.setTarget(targetId)
  end

  local actions = boop.attacks.choose()
  local didAction = false

  if actions.standard and actions.standard ~= "" then
    if not boop.state.prequeuedStandard and boop.canAct() then
      boop.executeAction(actions.standard)
      if actions.standardIsOpener and boop.attacks and boop.attacks.markOpenerUsed then
        boop.attacks.markOpenerUsed(classKeyForOpener(), targetId)
      end
      if actions.standardShieldbreak and boop.targets and boop.targets.onShieldbreakAttempt then
        boop.targets.onShieldbreakAttempt()
      end
      didAction = true
    end
  end

  if actions.rage and actions.rage ~= "" then
    if boop.canUseRage() then
      boop.executeRageAction(actions.rage)
      if boop.stats and boop.stats.onRageExecuted then
        boop.stats.onRageExecuted(actions.rageAbility, actions.rageDecision)
      end
      if actions.rageAbility and actions.rageAbility.desc == "Shieldbreak" and boop.targets and boop.targets.onShieldbreakAttempt then
        boop.targets.onShieldbreakAttempt()
      end
      if boop.rage and boop.rage.onRageUsed then
        boop.rage.onRageUsed(actions.rageAbility)
      end
      didAction = true
    end
  end

  boop.state.attacking = didAction
end

function boop.onPrompt()
  if boop.state and boop.state.diagHold then
    if boop.state.diagAwaitPrompt then
      local label = boop.state.diagLabel ~= "" and boop.state.diagLabel or "diag"
      boop.state.diagHold = false
      boop.state.diagAwaitPrompt = false
      boop.state.diagLabel = ""
      if boop.state.diagTimeoutTimer then
        killTimer(boop.state.diagTimeoutTimer)
        boop.state.diagTimeoutTimer = nil
      end
      boop.util.ok(label .. " complete; attacks resumed")
      boop.trace.log(label .. " complete")
    else
      return
    end
  end
  if boop.gag and boop.gag.onPrompt then
    boop.gag.onPrompt()
  end
  boop.tick()
end
