boop.walk = boop.walk or {}

local WALKER_PACKAGE_URL = "https://github.com/demonnic/demonnicAutoWalker/releases/latest/download/demonnicAutoWalker.mpackage"
boop.walk.packageUrl = boop.walk.packageUrl or WALKER_PACKAGE_URL

local function ensureDomain(state, domain)
  if type(state[domain]) ~= "table" then
    state[domain] = {}
  end
  return state[domain]
end

local function stateDomains()
  local state
  if boop.runtime and boop.runtime.ensureState then
    state = boop.runtime.ensureState()
  else
    boop.state = boop.state or {}
    state = boop.state
  end

  return state,
    ensureDomain(state, "walk"),
    ensureDomain(state, "diag"),
    ensureDomain(state, "combat"),
    ensureDomain(state, "gold"),
    ensureDomain(state, "targeting")
end

local function walkState()
  local _, walk = stateDomains()
  return walk
end

local function runtimeWalkBlocker()
  if not (boop.runtime and boop.runtime.shouldHold and boop.runtime.shouldHold("walk")) then
    return nil
  end
  local snapshot = boop.runtime.blockerSnapshot and boop.runtime.blockerSnapshot() or {}
  local label = tostring(snapshot.label or "")
  if label ~= "" then
    return label
  end
  local code = tostring(snapshot.code or "")
  if code ~= "" then
    return code
  end
  return "runtime blocker is active"
end

local function goldPending(gold)
  return gold.autoGrabPending or gold.getPending or gold.putPending
end

local function currentTargetId(targeting)
  return tostring(targeting.currentTargetId or "")
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

local function pullBlocker(combat)
  local pull = combat and combat.pullState or nil
  if type(pull) ~= "table" or not pull.active then
    return nil
  end
  local originRoom = tostring(pull.originRoom or "")
  local currentRoom = tostring(pull.currentRoom or currentRoomId() or "")
  if originRoom ~= "" and currentRoom ~= "" and currentRoom ~= originRoom then
    return "pull in progress"
  end
  return nil
end

local function cancelArrivalTimer()
  local walk = walkState()
  if walk.arrivalTimer then
    killTimer(walk.arrivalTimer)
    walk.arrivalTimer = nil
  end
end

local function armArrivalFallback(reason)
  local walk = walkState()
  cancelArrivalTimer()
  walk.moveQueued = false
  walk.roomSettled = false
  walk.arrivalRoom = currentRoomId()

  local arrivalRoom = walk.arrivalRoom
  walk.arrivalTimer = tempTimer(0.2, function()
    local liveWalk = walkState()
    liveWalk.arrivalTimer = nil
    if not liveWalk.active then
      return
    end
    if arrivalRoom ~= "" and currentRoomId() ~= "" and currentRoomId() ~= arrivalRoom then
      return
    end
    liveWalk.roomSettled = true
    boop.walk.maybeAdvance(reason or "arrival fallback")
  end)
end

local function resetRuntimeFlags()
  local walk = walkState()
  cancelArrivalTimer()
  walk.active = false
  walk.owned = false
  walk.roomSettled = false
  walk.moveQueued = false
  walk.arrivalRoom = ""
end

local function available()
  return type(demonwalker) == "table"
    and type(demonwalker.init) == "function"
end

local function attached()
  return type(demonwalker) == "table" and demonwalker.enabled and true or false
end

local function blockedReason()
  local _, walk, diag, combat, gold, targeting = stateDomains()
  if not available() then
    return "demonnicAutoWalker is not installed"
  end
  if not walk.active then
    return "walk is not active"
  end
  if not boop.config.enabled then
    return "boop is disabled"
  end
  if boop.config.targetingMode == "manual" then
    return "manual targeting is active"
  end
  if not walk.roomSettled then
    return "room has not settled yet"
  end
  if walk.moveQueued then
    return "move already queued"
  end
  if boop.targets and boop.targets.waitingForTargetCall and boop.targets.waitingForTargetCall() then
    return "waiting for leader target call"
  end
  local runtimeBlocker = runtimeWalkBlocker()
  if runtimeBlocker then
    return runtimeBlocker
  end
  local pullReason = pullBlocker(combat)
  if pullReason then
    return pullReason
  end
  if diag.hold then
    return "diag pause is active"
  end
  if combat.fleeing then
    return "flee is active"
  end
  if goldPending(gold) then
    return "loot handling is still pending"
  end
  if currentTargetId(targeting) ~= "" then
    return "current target still set"
  end
  local targetId = boop.targets and boop.targets.choose and boop.targets.choose() or ""
  if targetId ~= "" then
    return "room still has a valid target"
  end
  return nil
end

function boop.walk.blockedReason()
  return blockedReason()
end

function boop.walk.isAvailable()
  return available()
end

function boop.walk.install()
  if available() then
    boop.util.info("demonnicAutoWalker is already available")
    boop.walk.status()
    return true
  end
  if type(installPackage) ~= "function" then
    boop.util.err("walk install failed: installPackage() is unavailable")
    boop.util.info("Use a Mudlet build with package installs enabled, then run: boop walk install")
    return false
  end

  local url = tostring(boop.walk.packageUrl or WALKER_PACKAGE_URL or "")
  if url == "" then
    boop.util.err("walk install failed: package url is unavailable")
    return false
  end

  local ok, err = pcall(function()
    installPackage(url)
  end)
  if not ok then
    boop.util.err("walk install failed: " .. tostring(err))
    boop.util.info("Retry with: boop walk install")
    return false
  end

  boop.util.ok("install requested: demonnicAutoWalker")
  boop.util.info("If Mudlet prompts you, accept the package install, then use: boop walk start")
  return true
end

function boop.walk.isActive()
  local walk = walkState()
  return walk.active and true or false
end

function boop.walk.status()
  local walk = walkState()
  local packageStatus = available() and "available" or "missing"
  local walkStatus = walk.active and "active" or "idle"
  local attachedStatus = attached() and "yes" or "no"
  local ownedStatus = walk.owned and "owned" or "attached"
  local settledStatus = walk.roomSettled and "yes" or "no"
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
    if not available() then
      boop.util.info("walk install: boop walk install")
    end
  else
    boop.util.ok("walk ready to advance when room is clear")
  end
end

function boop.walk.start(options)
  if not available() then
    boop.util.warn("demonnicAutoWalker is not available")
    boop.util.info("Install it with: boop walk install")
    return false
  end

  local walk = walkState()
  if walk.active and attached() then
    boop.walk.status()
    return true
  end

  walk.active = true
  walk.owned = not attached()
  walk.moveQueued = false
  walk.roomSettled = false
  walk.arrivalRoom = currentRoomId()
  cancelArrivalTimer()

  if walk.owned then
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
  local walk = walkState()
  local wasActive = walk.active
  resetRuntimeFlags()

  if not silent and wasActive then
    boop.util.ok("walk stopped in current room")
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
  local walk = walkState()
  if not walk.active then
    return
  end
  armArrivalFallback("arrival fallback")
end

function boop.walk.onRoomSettled(reason)
  local walk = walkState()
  if not walk.active then
    return false
  end
  cancelArrivalTimer()
  walk.roomSettled = true
  return boop.walk.maybeAdvance(reason or "room settled")
end

function boop.walk.onRoomChange()
  local walk = walkState()
  if not walk.active then
    return
  end
  armArrivalFallback("room change fallback")
end

function boop.walk.maybeAdvance(reason)
  local walk = walkState()
  local blocked = blockedReason()
  if blocked then
    return false, blocked
  end

  walk.moveQueued = true
  walk.roomSettled = false
  boop.trace.log("walk advance: " .. tostring(reason or "unspecified"))
  tempTimer(0, function()
    local liveWalk = walkState()
    if not liveWalk.active then
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
  local walk = walkState()
  if walk.moveQueued then
    boop.util.info("walk move already queued")
    return false
  end
  walk.roomSettled = true
  local ok, err = boop.walk.maybeAdvance("manual move")
  if not ok and err then
    boop.util.warn("walk move blocked: " .. tostring(err))
  end
  return ok
end
