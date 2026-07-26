boop.walk = boop.walk or {}

local WALKER_PACKAGE_URL = "https://github.com/demonnic/demonnicAutoWalker/releases/latest/download/demonnicAutoWalker.mpackage"
local WALK_REASON_LABELS = {
  walker_unavailable = "demonnicAutoWalker unavailable",
  walk_inactive = "walk mode is inactive",
  hunting_disabled = "hunting is disabled",
  manual_targeting = "manual targeting is active",
  room_unsettled = "current room evidence is incomplete",
  move_pending = "move already queued",
  target_active = "current target still set",
  room_denizen_active = "valid room target remains",
  leader_call_pending = "waiting for leader target call",
  gold_pending = "loot handling is pending",
  interrupt_pending = "interrupt is pending",
  pull_pending = "pull is pending",
  flee_active = "flee is active",
  walker_lost_before_emit = "demonnicAutoWalker became unavailable",
  room_refresh_exhausted = "room item refresh completed without settlement",
}
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

local function runtimeWalkBlocker(exceptOwner)
  if not (boop.runtime and boop.runtime.shouldHold) then
    return nil
  end
  if not boop.runtime.shouldHold("walk", exceptOwner) then
    return nil
  end
  local blockers = boop.runtime.blockersSnapshot
      and boop.runtime.blockersSnapshot()
    or {}
  local excluded = tostring(exceptOwner or "")
  for _, blocker in ipairs(blockers) do
    if tostring(blocker.owner or "") ~= excluded
        and type(blocker.systems) == "table"
        and blocker.systems.walk == true then
      return blocker
    end
  end
  return {
    code = "",
    label = "runtime blocker is active",
  }
end

local function goldPending(gold)
  local operation = gold and gold.operation or nil
  if type(operation) == "table" and not operation.terminal then
    return true
  end
  return gold
    and (gold.autoGrabPending or gold.getPending or gold.putPending)
    or false
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
  return type(pull) == "table"
    and pull.active == true
    and pull.terminal ~= true
end

local function cancelArrivalTimer()
  local walk = walkState()
  if walk.refreshTimer then
    if killTimer then
      killTimer(walk.refreshTimer)
    end
    walk.refreshTimer = nil
  end
end

local function armArrivalFallback(reason)
  local walk = walkState()
  cancelArrivalTimer()
  if walk.emitterTimer then
    if killTimer then
      killTimer(walk.emitterTimer)
    end
    walk.emitterTimer = nil
  end

  local roomId = currentRoomId()
  local observation = boop.runtime
      and boop.runtime.roomObservationSnapshot
      and boop.runtime.roomObservationSnapshot()
    or {}
  if boop.runtime
      and boop.runtime.startRoomObservation
      and roomId ~= ""
      and (
        tostring(observation.roomId or "") ~= roomId
        or not observation.infoSeen
      ) then
    observation = boop.runtime.startRoomObservation(roomId)
  end

  walk.moveQueued = false
  walk.moveIssuedForRoomGeneration = false
  walk.roomSettled = false
  walk.arrivalRoom = roomId
  walk.roomGeneration = tonumber(observation.generation) or 0
  walk.refreshWarned = false

  local owner = "walk:" .. tostring(tonumber(walk.generation) or 0)
  if boop.runtime and boop.runtime.setBlocker then
    boop.runtime.setBlocker(
      owner,
      "walk_room_unsettled",
      WALK_REASON_LABELS.room_unsettled,
      { walk = true },
      { room = true, items = true },
      {
        source = "walk",
        observed = {
          room = roomId,
          roomGeneration = walk.roomGeneration,
          items = observation.itemsSeen == true,
        },
      }
    )
  end

  if boop.requestRoomItemsOnce then
    boop.requestRoomItemsOnce(reason or "walk room evidence missing")
  end

  local runGeneration = tonumber(walk.generation) or 0
  local roomGeneration = tonumber(walk.roomGeneration) or 0
  local refreshTimer
  refreshTimer = tempTimer(0.2, function()
    local liveWalk = walkState()
    if liveWalk.refreshTimer ~= refreshTimer
        or not liveWalk.active
        or tonumber(liveWalk.generation) ~= runGeneration
        or tonumber(liveWalk.roomGeneration) ~= roomGeneration then
      return
    end
    liveWalk.refreshTimer = nil

    local liveObservation = boop.runtime
        and boop.runtime.roomObservationSnapshot
        and boop.runtime.roomObservationSnapshot()
      or {}
    local settled = liveObservation.infoSeen == true
      and liveObservation.itemsSeen == true
      and tostring(liveObservation.roomId or "") ~= ""
      and tostring(liveObservation.roomId or "") == currentRoomId()
      and tonumber(liveObservation.generation) == roomGeneration
    if settled then
      boop.walk.onRoomSettled(reason or "room refresh settled")
      return
    end

    if not liveWalk.refreshWarned then
      liveWalk.refreshWarned = true
      if boop.util and boop.util.warn then
        boop.util.warn(WALK_REASON_LABELS.room_refresh_exhausted)
      end
      if boop.trace and boop.trace.log then
        boop.trace.log(
          "room_refresh_exhausted: run="
            .. tostring(runGeneration)
            .. " roomGeneration="
            .. tostring(roomGeneration)
        )
      end
    end
  end)
  walk.refreshTimer = refreshTimer
end

local function resetRuntimeFlags()
  local walk = walkState()
  cancelArrivalTimer()
  if walk.emitterTimer then
    if killTimer then
      killTimer(walk.emitterTimer)
    end
  end
  walk.active = false
  walk.owned = false
  walk.roomSettled = false
  walk.moveQueued = false
  walk.arrivalRoom = ""
  walk.generation = tonumber(walk.generation) or 0
  walk.roomGeneration = 0
  walk.moveIssuedForRoomGeneration = false
  walk.reservationId = tonumber(walk.reservationId) or 0
  walk.refreshTimer = nil
  walk.emitterTimer = nil
  walk.refreshWarned = false
end

local function available()
  return type(demonwalker) == "table"
    and type(demonwalker.init) == "function"
end

local function attached()
  return type(demonwalker) == "table" and demonwalker.enabled and true or false
end

local function walkSnapshot()
  local _, walk, diag, combat, gold, targeting = stateDomains()
  local observation = boop.runtime
      and boop.runtime.roomObservationSnapshot
      and boop.runtime.roomObservationSnapshot()
    or {}
  local roomId = currentRoomId()
  local roomSettled = observation.infoSeen == true
    and observation.itemsSeen == true
    and tostring(observation.roomId or "") ~= ""
    and tostring(observation.roomId or "") == roomId
    and tonumber(observation.generation)
      == (tonumber(walk.roomGeneration) or 0)
  local denizenId = boop.targets
      and boop.targets.choose
      and boop.targets.choose()
    or ""
  local waitingForLeader = boop.targets
      and boop.targets.waitingForTargetCall
      and boop.targets.waitingForTargetCall()
    or false
  local runtimeBlocker = runtimeWalkBlocker()

  return {
    packageAvailable = available(),
    active = walk.active == true,
    owned = walk.owned == true,
    huntingEnabled = boop.config and boop.config.enabled == true,
    targetingMode = tostring(
      boop.config and boop.config.targetingMode or ""
    ),
    roomSettled = roomSettled,
    roomId = roomId,
    roomObservation = observation,
    moveQueued = walk.moveQueued == true,
    generation = tonumber(walk.generation) or 0,
    roomGeneration = tonumber(walk.roomGeneration) or 0,
    moveIssuedForRoomGeneration =
      walk.moveIssuedForRoomGeneration == true,
    reservationId = tonumber(walk.reservationId) or 0,
    emitterTimer = walk.emitterTimer,
    targetId = currentTargetId(targeting),
    denizenId = tostring(denizenId or ""),
    waitingForLeader = waitingForLeader == true,
    goldPending = goldPending(gold),
    interruptPending = diag.hold == true,
    pullPending = pullBlocker(combat),
    fleeActive = combat.fleeing == true,
    runtimeBlocker = runtimeBlocker,
  }
end

function boop.walk.evaluateAllClear(runGeneration, roomGeneration)
  local snapshot = walkSnapshot()
  if not snapshot.packageAvailable then
    return false, "walker_unavailable", WALK_REASON_LABELS.walker_unavailable
  end
  if not snapshot.active
      or (
        runGeneration ~= nil
        and tonumber(runGeneration) ~= snapshot.generation
      ) then
    return false, "walk_inactive", WALK_REASON_LABELS.walk_inactive
  end
  if not snapshot.huntingEnabled then
    return false, "hunting_disabled", WALK_REASON_LABELS.hunting_disabled
  end
  if snapshot.targetingMode == "manual" then
    return false, "manual_targeting", WALK_REASON_LABELS.manual_targeting
  end
  if not snapshot.roomSettled
      or (
        roomGeneration ~= nil
        and tonumber(roomGeneration) ~= snapshot.roomGeneration
      ) then
    return false, "room_unsettled", WALK_REASON_LABELS.room_unsettled
  end
  if snapshot.moveQueued then
    return false, "move_pending", WALK_REASON_LABELS.move_pending
  end
  if snapshot.targetId ~= "" then
    return false, "target_active", WALK_REASON_LABELS.target_active
  end
  if snapshot.denizenId ~= "" then
    return false,
      "room_denizen_active",
      WALK_REASON_LABELS.room_denizen_active
  end
  if snapshot.waitingForLeader then
    return false,
      "leader_call_pending",
      WALK_REASON_LABELS.leader_call_pending
  end
  if snapshot.goldPending then
    return false, "gold_pending", WALK_REASON_LABELS.gold_pending
  end
  if snapshot.interruptPending then
    return false,
      "interrupt_pending",
      WALK_REASON_LABELS.interrupt_pending
  end
  if snapshot.pullPending then
    return false, "pull_pending", WALK_REASON_LABELS.pull_pending
  end
  if snapshot.fleeActive then
    return false, "flee_active", WALK_REASON_LABELS.flee_active
  end
  if snapshot.runtimeBlocker then
    local code = tostring(snapshot.runtimeBlocker.code or "")
    local label = tostring(snapshot.runtimeBlocker.label or "")
    return false, code, label ~= "" and label or code
  end
  return true, nil, nil
end

local function evaluateReservedEmission(
  runGeneration,
  roomGeneration,
  reservationId
)
  local snapshot = walkSnapshot()
  if not snapshot.active
      or snapshot.generation ~= tonumber(runGeneration)
      or snapshot.roomGeneration ~= tonumber(roomGeneration)
      or snapshot.reservationId ~= tonumber(reservationId)
      or snapshot.emitterTimer == nil
      or not snapshot.moveQueued
      or not snapshot.moveIssuedForRoomGeneration then
    return false
  end
  if not snapshot.packageAvailable then
    return false, "walker_unavailable", WALK_REASON_LABELS.walker_unavailable
  end
  if not snapshot.huntingEnabled then
    return false, "hunting_disabled", WALK_REASON_LABELS.hunting_disabled
  end
  if snapshot.targetingMode == "manual" then
    return false, "manual_targeting", WALK_REASON_LABELS.manual_targeting
  end
  if not snapshot.roomSettled then
    return false, "room_unsettled", WALK_REASON_LABELS.room_unsettled
  end
  if snapshot.targetId ~= "" then
    return false, "target_active", WALK_REASON_LABELS.target_active
  end
  if snapshot.denizenId ~= "" then
    return false,
      "room_denizen_active",
      WALK_REASON_LABELS.room_denizen_active
  end
  if snapshot.waitingForLeader then
    return false,
      "leader_call_pending",
      WALK_REASON_LABELS.leader_call_pending
  end
  if snapshot.goldPending then
    return false, "gold_pending", WALK_REASON_LABELS.gold_pending
  end
  if snapshot.interruptPending then
    return false,
      "interrupt_pending",
      WALK_REASON_LABELS.interrupt_pending
  end
  if snapshot.pullPending then
    return false, "pull_pending", WALK_REASON_LABELS.pull_pending
  end
  if snapshot.fleeActive then
    return false, "flee_active", WALK_REASON_LABELS.flee_active
  end

  local owner = "walk:" .. tostring(runGeneration)
  local runtimeBlocker = runtimeWalkBlocker(owner)
  if runtimeBlocker then
    local code = tostring(runtimeBlocker.code or "")
    local label = tostring(runtimeBlocker.label or "")
    return false, code, label ~= "" and label or code
  end
  return true, nil, nil
end

local function emitReservedMove(runGeneration, roomGeneration, reservationId)
  local walk = walkState()
  if walk.emitterTimer == nil
      or tonumber(walk.generation) ~= tonumber(runGeneration)
      or tonumber(walk.roomGeneration) ~= tonumber(roomGeneration)
      or tonumber(walk.reservationId) ~= tonumber(reservationId) then
    return false
  end

  local ok, code = evaluateReservedEmission(
    runGeneration,
    roomGeneration,
    reservationId
  )
  if not ok then
    if code == "walker_unavailable" then
      walk.emitterTimer = nil
      walk.moveQueued = false
      walk.moveIssuedForRoomGeneration = false
      local owner = "walk:" .. tostring(runGeneration)
      if boop.runtime and boop.runtime.setBlocker then
        boop.runtime.setBlocker(
          owner,
          "walker_unavailable",
          WALK_REASON_LABELS.walker_unavailable,
          { walk = true },
          { package = true },
          {
            source = "walk",
            observed = {
              room = currentRoomId(),
              roomGeneration = roomGeneration,
            },
          }
        )
      end
      if boop.util and boop.util.warn then
        boop.util.warn(WALK_REASON_LABELS.walker_lost_before_emit)
      end
    end
    return false
  end

  walk.emitterTimer = nil
  if raiseEvent then
    raiseEvent("demonwalker.move")
  end
  return true
end

local function blockedReason()
  local walk = walkState()
  local ok, _, label = boop.walk.evaluateAllClear(
    walk.generation,
    walk.roomGeneration
  )
  if ok then
    return nil
  end
  return label
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
    boop.util.info(
      "Use a Mudlet build with package installs enabled, then run: boop walk install"
    )
    return false
  end

  local url = tostring(boop.walk.packageUrl or WALKER_PACKAGE_URL or "")
  if url == "" then
    boop.util.err("walk install failed: package url is unavailable")
    return false
  end

  local ok, installed, err = pcall(installPackage, url)
  if not ok then
    boop.util.err("walk install failed: " .. tostring(installed))
    boop.util.info("Retry with: boop walk install")
    return false
  end
  if installed == false or (installed == nil and err ~= nil) then
    boop.util.err("walk install failed: " .. tostring(err or "request rejected"))
    boop.util.info("Retry with: boop walk install")
    return false
  end

  boop.util.ok("install requested: demonnicAutoWalker")
  boop.util.info(
    "If Mudlet prompts you, accept the package install, then use: boop walk start"
  )
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

function boop.walk.invalidateCurrentGeneration(reason)
  local walk = walkState()
  cancelArrivalTimer()
  if walk.emitterTimer then
    if killTimer then
      killTimer(walk.emitterTimer)
    end
  end
  walk.generation = (tonumber(walk.generation) or 0) + 1
  walk.roomGeneration = 0
  walk.roomSettled = false
  walk.moveQueued = false
  walk.moveIssuedForRoomGeneration = false
  walk.arrivalRoom = ""
  walk.refreshTimer = nil
  walk.emitterTimer = nil
  walk.refreshWarned = false
  if boop.trace and boop.trace.log and reason then
    boop.trace.log(
      "walk generation invalidated: "
        .. tostring(reason)
        .. " | generation="
        .. tostring(walk.generation)
    )
  end
  return walk.generation
end

function boop.walk.start(options)
  if not available() then
    boop.util.warn(WALK_REASON_LABELS.walker_unavailable)
    boop.util.info("Install it with: boop walk install")
    return false
  end

  local walk = walkState()
  if walk.active and attached() then
    boop.walk.status()
    return true
  end

  local oldOwner = "walk:" .. tostring(tonumber(walk.generation) or 0)
  boop.walk.invalidateCurrentGeneration("start")
  if boop.runtime and boop.runtime.clearBlocker then
    boop.runtime.clearBlocker(oldOwner, "walk restart")
  end
  walk.active = true
  walk.owned = not attached()

  if walk.owned then
    local ok, err = pcall(function()
      demonwalker:init(options or {})
    end)
    if not ok then
      local owner = "walk:" .. tostring(walk.generation)
      boop.walk.invalidateCurrentGeneration("start failed")
      resetRuntimeFlags()
      if boop.runtime and boop.runtime.clearBlocker then
        boop.runtime.clearBlocker(owner, "walk start failed")
      end
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
  local wasActive = walk.active == true
  local wasOwned = walk.owned == true
  local owner = "walk:" .. tostring(tonumber(walk.generation) or 0)

  boop.walk.invalidateCurrentGeneration("stop")
  if boop.runtime and boop.runtime.clearBlocker then
    boop.runtime.clearBlocker(owner, "walk stopped")
  end
  resetRuntimeFlags()

  if wasActive and wasOwned and not external and raiseEvent then
    raiseEvent("demonwalker.stop")
  end
  if not silent and wasActive then
    if wasOwned then
      boop.util.ok("walk stopped in current room")
    else
      boop.util.ok("walk detached in current room")
    end
  end
end

function boop.walk.onFinished()
  local walk = walkState()
  local wasActive = walk.active == true
  local owner = "walk:" .. tostring(tonumber(walk.generation) or 0)
  boop.walk.invalidateCurrentGeneration("finished")
  if boop.runtime and boop.runtime.clearBlocker then
    boop.runtime.clearBlocker(owner, "walk finished")
  end
  resetRuntimeFlags()
  if wasActive then
    boop.util.info("walk finished")
  end
end

function boop.walk.onArrived()
  local walk = walkState()
  if not walk.active then
    return false
  end
  armArrivalFallback("arrival fallback")
  return true
end

function boop.walk.onRoomSettled(reason)
  local walk = walkState()
  if not walk.active then
    return false, "walk_inactive", WALK_REASON_LABELS.walk_inactive
  end

  local observation = boop.runtime
      and boop.runtime.roomObservationSnapshot
      and boop.runtime.roomObservationSnapshot()
    or {}
  local settled = observation.infoSeen == true
    and observation.itemsSeen == true
    and tostring(observation.roomId or "") ~= ""
    and tostring(observation.roomId or "") == currentRoomId()
    and tonumber(observation.generation)
      == (tonumber(walk.roomGeneration) or 0)
  if not settled then
    walk.roomSettled = false
    local owner = "walk:" .. tostring(walk.generation)
    if boop.runtime and boop.runtime.setBlocker then
      boop.runtime.setBlocker(
        owner,
        "walk_room_unsettled",
        WALK_REASON_LABELS.room_unsettled,
        { walk = true },
        { room = true, items = true },
        {
          source = "walk",
          observed = {
            room = currentRoomId(),
            roomGeneration = walk.roomGeneration,
            items = observation.itemsSeen == true,
          },
        }
      )
    end
    return false, "room_unsettled", WALK_REASON_LABELS.room_unsettled
  end

  cancelArrivalTimer()
  walk.roomSettled = true
  walk.refreshWarned = false
  if not walk.moveQueued
      and boop.runtime
      and boop.runtime.clearBlocker then
    boop.runtime.clearBlocker(
      "walk:" .. tostring(walk.generation),
      tostring(reason or "room settled")
    )
  end
  return boop.walk.maybeAdvance(reason or "room settled")
end

function boop.walk.onRoomChange()
  local walk = walkState()
  if not walk.active then
    return false
  end
  armArrivalFallback("room change fallback")
  return true
end

function boop.walk.maybeAdvance(reason)
  local walk = walkState()
  local ok, code, label = boop.walk.evaluateAllClear(
    walk.generation,
    walk.roomGeneration
  )
  if not ok then
    return false, code, label
  end

  walk.roomSettled = true
  walk.moveQueued = true
  walk.moveIssuedForRoomGeneration = true
  walk.reservationId = (tonumber(walk.reservationId) or 0) + 1
  local runGeneration = tonumber(walk.generation) or 0
  local roomGeneration = tonumber(walk.roomGeneration) or 0
  local reservationId = tonumber(walk.reservationId) or 0
  local owner = "walk:" .. tostring(runGeneration)

  if boop.runtime and boop.runtime.setBlocker then
    boop.runtime.setBlocker(
      owner,
      "walk_move_pending",
      WALK_REASON_LABELS.move_pending,
      { walk = true },
      { room = true },
      {
        source = "walk",
        observed = {
          room = currentRoomId(),
          roomGeneration = roomGeneration,
          reservationId = reservationId,
        },
      }
    )
  end
  if boop.trace and boop.trace.log then
    boop.trace.log(
      "walk advance: "
        .. tostring(reason or "unspecified")
        .. " | run="
        .. tostring(runGeneration)
        .. " roomGeneration="
        .. tostring(roomGeneration)
        .. " reservation="
        .. tostring(reservationId)
    )
  end

  walk.emitterTimer = tempTimer(0, function()
    emitReservedMove(runGeneration, roomGeneration, reservationId)
  end)
  return true, nil, nil
end

function boop.walk.move()
  local walk = walkState()
  local ok, code, label = boop.walk.maybeAdvance("manual move")
  if not ok and label then
    boop.util.warn("walk move blocked: " .. tostring(label))
  end
  return ok, code, label
end
