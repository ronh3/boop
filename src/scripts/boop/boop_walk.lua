boop.walk = boop.walk or {}

local function walkState()
  boop.state = boop.state or {}
  return boop.state
end

local function currentRoomId()
  if gmcp and gmcp.Room and gmcp.Room.Info and gmcp.Room.Info.num then
    return tostring(gmcp.Room.Info.num or "")
  end
  if mmp and mmp.currentroom then
    return tostring(mmp.currentroom or "")
  end
  return ""
end

local function cancelArrivalTimer()
  local state = walkState()
  if state.walkArrivalTimer then
    killTimer(state.walkArrivalTimer)
    state.walkArrivalTimer = nil
  end
end

local function armArrivalFallback(reason)
  local state = walkState()
  cancelArrivalTimer()
  state.walkMoveQueued = false
  state.walkRoomSettled = false
  state.walkArrivalRoom = currentRoomId()

  local arrivalRoom = state.walkArrivalRoom
  state.walkArrivalTimer = tempTimer(0.2, function()
    local liveState = walkState()
    liveState.walkArrivalTimer = nil
    if not liveState.walkActive then
      return
    end
    if arrivalRoom ~= "" and currentRoomId() ~= "" and currentRoomId() ~= arrivalRoom then
      return
    end
    liveState.walkRoomSettled = true
    boop.walk.maybeAdvance(reason or "arrival fallback")
  end)
end

local function resetRuntimeFlags()
  local state = walkState()
  cancelArrivalTimer()
  state.walkActive = false
  state.walkOwned = false
  state.walkRoomSettled = false
  state.walkMoveQueued = false
  state.walkArrivalRoom = ""
end

local function available()
  return type(demonwalker) == "table"
    and type(demonwalker.init) == "function"
    and type(raiseEvent) == "function"
end

local function attached()
  return type(demonwalker) == "table" and demonwalker.enabled and true or false
end

local function blockedReason()
  local state = walkState()
  if not available() then
    return "demonnicAutoWalker is not installed"
  end
  if not state.walkActive then
    return "walk is not active"
  end
  if not boop.config.enabled then
    return "boop is disabled"
  end
  if boop.config.targetingMode == "manual" then
    return "manual targeting is active"
  end
  if not state.walkRoomSettled then
    return "room has not settled yet"
  end
  if state.walkMoveQueued then
    return "move already queued"
  end
  if boop.targets and boop.targets.waitingForTargetCall and boop.targets.waitingForTargetCall() then
    return "waiting for leader target call"
  end
  if state.diagHold then
    return "diag pause is active"
  end
  if state.fleeing then
    return "flee is active"
  end
  if state.autoGrabGoldPending or state.goldGetPending or state.goldPutPending then
    return "loot handling is still pending"
  end
  if tostring(state.currentTargetId or "") ~= "" then
    return "current target still set"
  end
  local targetId = boop.targets and boop.targets.choose and boop.targets.choose() or ""
  if targetId ~= "" then
    return "room still has a valid target"
  end
  return nil
end

function boop.walk.isAvailable()
  return available()
end

function boop.walk.isActive()
  local state = walkState()
  return state.walkActive and true or false
end

function boop.walk.status()
  local state = walkState()
  local packageStatus = available() and "available" or "missing"
  local walkStatus = state.walkActive and "active" or "idle"
  local attachedStatus = attached() and "yes" or "no"
  local ownedStatus = state.walkOwned and "owned" or "attached"
  local settledStatus = state.walkRoomSettled and "yes" or "no"
  local blocked = blockedReason()

  boop.util.info(string.format(
    "walk: %s | package: %s | demonwalker active: %s | mode: %s | room settled: %s",
    walkStatus,
    packageStatus,
    attachedStatus,
    ownedStatus,
    settledStatus
  ))
  if blocked then
    boop.util.info("walk blocked: " .. blocked)
  else
    boop.util.ok("walk ready to advance when room is clear")
  end
end

function boop.walk.start(options)
  if not available() then
    boop.util.warn("demonnicAutoWalker is not available")
    boop.util.info("Install the separate package, then use: boop walk start")
    return false
  end

  local state = walkState()
  if state.walkActive and attached() then
    boop.walk.status()
    return true
  end

  state.walkActive = true
  state.walkOwned = not attached()
  state.walkMoveQueued = false
  state.walkRoomSettled = false
  state.walkArrivalRoom = currentRoomId()
  cancelArrivalTimer()

  if state.walkOwned then
    local ok, err = pcall(function()
      demonwalker:init(options or {})
    end)
    if not ok then
      resetRuntimeFlags()
      boop.util.err("walk start failed: " .. tostring(err))
      return false
    end
    boop.util.ok("walk started")
  else
    boop.util.ok("walk attached to current demonwalker run")
  end

  boop.walk.onArrived()
  return true
end

function boop.walk.stop(silent, external)
  local state = walkState()
  local wasActive = state.walkActive
  local shouldStopWalker = not external and attached()
  resetRuntimeFlags()

  if shouldStopWalker then
    pcall(function()
      raiseEvent("demonwalker.stop")
    end)
  end

  if not silent and wasActive then
    boop.util.ok("walk stopped")
  end
end

function boop.walk.onFinished()
  local wasActive = boop.walk.isActive()
  resetRuntimeFlags()
  if wasActive then
    boop.util.info("walk finished")
  end
end

function boop.walk.onArrived()
  local state = walkState()
  if not state.walkActive then
    return
  end
  armArrivalFallback("arrival fallback")
end

function boop.walk.onRoomSettled(reason)
  local state = walkState()
  if not state.walkActive then
    return false
  end
  cancelArrivalTimer()
  state.walkRoomSettled = true
  return boop.walk.maybeAdvance(reason or "room settled")
end

function boop.walk.onRoomChange()
  local state = walkState()
  if not state.walkActive then
    return
  end
  armArrivalFallback("room change fallback")
end

function boop.walk.maybeAdvance(reason)
  local state = walkState()
  local blocked = blockedReason()
  if blocked then
    return false, blocked
  end

  state.walkMoveQueued = true
  state.walkRoomSettled = false
  boop.trace.log("walk advance: " .. tostring(reason or "unspecified"))
  tempTimer(0, function()
    local liveState = walkState()
    if not liveState.walkActive then
      return
    end
    if raiseEvent then
      raiseEvent("demonwalker.move")
    end
  end)
  return true, nil
end

function boop.walk.move()
  if not boop.walk.isActive() then
    boop.util.warn("walk is not active")
    return false
  end
  local state = walkState()
  if state.walkMoveQueued then
    boop.util.info("walk move already queued")
    return false
  end
  state.walkRoomSettled = true
  local ok, err = boop.walk.maybeAdvance("manual move")
  if not ok and err then
    boop.util.warn("walk move blocked: " .. tostring(err))
  end
  return ok
end
