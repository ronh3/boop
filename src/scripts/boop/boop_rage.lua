boop.rage = boop.rage or {}

local COOLDOWN_DENIAL =
  "You must wait a short time before you can use a battlerage ability again."
local AVAILABLE_PREFIX =
  "You can use another Battlerage ability again. Available abilities: "
local NO_ABILITIES_RECOVERY =
  "You can use another Battlerage ability again, but none of your abilities are currently available."
local RAGE_EXPIRED = "Your rage fades away."

boop.rage.NO_ABILITIES_RECOVERY = NO_ABILITIES_RECOVERY

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

local function keyForAbility(ability)
  local name = ability and (ability.name or ability.skill) or ""
  return boop.util.safeLower(boop.util.trim(name))
end

local function nowSeconds()
  if getEpoch then return getEpoch() end
  return os.clock()
end

local function rageState()
  boop.state = boop.state or {}
  boop.state.rage = boop.state.rage or {}
  local state = boop.state.rage
  state.amount = tonumber(state.amount) or 0
  state.ready = type(state.ready) == "table" and state.ready or {}
  state.timers = type(state.timers) == "table" and state.timers or {}
  state.timerGenerations = type(state.timerGenerations) == "table"
      and state.timerGenerations
    or {}
  state.samples = type(state.samples) == "table" and state.samples or {}
  state.dispatchGeneration = tonumber(state.dispatchGeneration) or 0
  state.pending = type(state.pending) == "table" and state.pending or false
  state.lastTerminal = type(state.lastTerminal) == "table"
      and state.lastTerminal
    or false
  if state.globalCooldownOpen == nil then
    state.globalCooldownOpen = true
  end
  state.triumphGeneration = tonumber(state.triumphGeneration) or 0
  state.triumph = type(state.triumph) == "table" and state.triumph or false
  if state.freeNext == nil then
    state.freeNext = false
  end
  return state
end

local function connectionGeneration()
  return tonumber(
    boop.state
      and boop.state.lifecycle
      and boop.state.lifecycle.connectionGeneration
      or 0
  ) or 0
end

local function currentRoomId()
  local room = boop.state
    and boop.state.targeting
    and boop.state.targeting.room
    or ""
  if tostring(room or "") == "" then
    room = gmcp
      and gmcp.Room
      and gmcp.Room.Info
      and gmcp.Room.Info.num
      or ""
  end
  return tostring(room or "")
end

local function currentTargetId()
  return tostring(
    boop.state
      and boop.state.targeting
      and boop.state.targeting.currentTargetId
      or ""
  )
end

local function sameIdentity(left, right)
  return type(left) == "table"
    and type(right) == "table"
    and tostring(left.owner or "") == tostring(right.owner or "")
    and tonumber(left.generation) == tonumber(right.generation)
    and tostring(left.dispatchId or "") == tostring(right.dispatchId or "")
end

local function dispatchFor(identity)
  local snapshot = boop.runtime
    and boop.runtime.outboundSnapshot
    and boop.runtime.outboundSnapshot()
    or false
  if type(snapshot) ~= "table" then
    return false, false
  end
  for _, dispatch in ipairs(snapshot.dispatches or {}) do
    if sameIdentity(dispatch, identity) then
      return dispatch, snapshot
    end
  end
  return false, snapshot
end

local function syncPending(operation)
  if type(operation) ~= "table" then
    return false
  end
  local dispatch, snapshot = dispatchFor(operation)
  if type(dispatch) == "table" then
    operation.expectedWireCommands = deepCopy(
      dispatch.expectedWireCommands or {}
    )
    operation.observedWireCommands = deepCopy(
      dispatch.observedWireCommands or {}
    )
    operation.finalOwnedWireSequence =
      dispatch.finalOwnedWireSequence or false
  end
  return dispatch, snapshot
end

local function clearResponseTimer(operation)
  if type(operation) ~= "table" or not operation.responseTimer then
    return
  end
  if killTimer then
    killTimer(operation.responseTimer)
  end
  operation.responseTimer = false
end

local function terminalizePending(operation, status, reason)
  local state = rageState()
  if not sameIdentity(state.pending, operation)
      or state.pending.terminal then
    return false
  end
  syncPending(state.pending)
  clearResponseTimer(state.pending)
  state.pending.status = tostring(status or "terminal")
  state.pending.reason = tostring(reason or status or "terminal")
  state.pending.terminalReason = state.pending.reason
  state.pending.terminal = true
  state.pending.firstTerminal = true
  state.pending.windowOpen = false
  state.pending.terminalAt = nowSeconds()
  state.lastTerminal = deepCopy(state.pending)
  state.pending = false
  return deepCopy(state.lastTerminal)
end

local function traceAmbiguous(operation, line)
  if type(operation) == "table" and not operation.ambiguityTraced then
    operation.ambiguityTraced = true
    if boop.trace and boop.trace.log then
      boop.trace.log(string.format(
        "rage outcome ambiguous: owner=%s | generation=%s | line=%s",
        tostring(operation.owner or ""),
        tostring(operation.generation or ""),
        tostring(line or "")
      ))
    end
  end
end

local function clearTriumph(reason, expectedGeneration)
  local state = rageState()
  local triumph = state.triumph
  if type(triumph) ~= "table"
      or not triumph.active
      or expectedGeneration
        and tonumber(expectedGeneration) ~= tonumber(triumph.generation) then
    state.freeNext = false
    return false
  end
  if triumph.timer and killTimer then
    killTimer(triumph.timer)
  end
  triumph.active = false
  triumph.reason = tostring(reason or "cleared")
  triumph.timer = false
  triumph.terminalAt = nowSeconds()
  state.freeNext = false
  if boop.trace and boop.trace.log then
    boop.trace.log(string.format(
      "rage triumph cleared: generation=%s | reason=%s",
      tostring(triumph.generation or ""),
      triumph.reason
    ))
  end
  return true
end

local function sourceAuthorityCurrent(operation)
  local authority = type(operation) == "table"
      and operation.sourceAuthority
    or false
  if type(authority) ~= "table" then
    return true
  end
  return boop.runtime
    and boop.runtime.validateRoomSourceAuthority
    and boop.runtime.validateRoomSourceAuthority(authority)
    or false
end

local function queuedStandardPending()
  if not (boop.runtime and boop.runtime.standardPending)
      or not boop.runtime.standardPending() then
    return false
  end
  local operation = boop.runtime.standardSnapshot
    and boop.runtime.standardSnapshot()
    or false
  return type(operation) == "table"
    and operation.mode == "queued"
    and not operation.terminal
end

local function completeOrderedDispatch(operation)
  local dispatch, snapshot = syncPending(operation)
  local expected = type(dispatch) == "table"
      and dispatch.expectedWireCommands
    or {}
  local observed = type(dispatch) == "table"
      and dispatch.observedWireCommands
    or {}
  if #expected == 0 or #expected ~= #observed then
    return false, snapshot
  end
  for index, expectedWire in ipairs(expected) do
    local observedWire = observed[index]
    if type(observedWire) ~= "table"
        or tostring(expectedWire.command or "")
          ~= tostring(observedWire.command or "") then
      return false, snapshot
    end
  end
  local last = observed[#observed]
  return type(last) == "table"
      and tonumber(dispatch.finalOwnedWireSequence)
        == tonumber(last.sequence),
    snapshot
end

local function causalPending(line, abilityKey)
  local state = rageState()
  local operation = state.pending
  if type(operation) ~= "table"
      or operation.terminal
      or operation.status ~= "pending"
      or operation.windowOpen ~= true then
    traceAmbiguous(operation, line)
    return false
  end
  local complete, snapshot = completeOrderedDispatch(operation)
  local finalSequence = tonumber(operation.finalOwnedWireSequence)
  local cleanSequence = type(snapshot) == "table"
    and finalSequence
    and tonumber(snapshot.sequence) == finalSequence
  local currentConnection = connectionGeneration()
    == tonumber(operation.connectionGeneration)
  local currentRoom = tostring(operation.roomId or "") == ""
    or currentRoomId() == tostring(operation.roomId or "")
  local currentTarget = tostring(operation.targetId or "") == ""
    or currentTargetId() == tostring(operation.targetId or "")
  local matchingAbility = not abilityKey
    or abilityKey == ""
    or abilityKey == tostring(operation.abilityKey or "")
  if not complete
      or not cleanSequence
      or operation.contaminatedAt
      or not currentConnection
      or not currentRoom
      or not currentTarget
      or not matchingAbility
      or not sourceAuthorityCurrent(operation) then
    traceAmbiguous(operation, line)
    return false
  end
  return operation
end

function boop.rage.init()
  local state = rageState()
  if type(state.triumph) ~= "table" then
    state.freeNext = false
  end
end

function boop.rage.setReady(name, ready)
  if not name or name == "" then return end
  local key = boop.util.safeLower(boop.util.trim(name))
  rageState().ready[key] = ready and true or false
end

function boop.rage.isGlobalCooldownOpen()
  return rageState().globalCooldownOpen == true
end

function boop.rage.pendingSnapshot()
  local pending = rageState().pending
  if type(pending) ~= "table" then
    return false
  end
  syncPending(pending)
  return deepCopy(pending)
end

function boop.rage.lastTerminalSnapshot()
  local terminal = rageState().lastTerminal
  return type(terminal) == "table" and deepCopy(terminal) or false
end

function boop.rage.beginDispatch(options)
  options = type(options) == "table" and options or {}
  local state = rageState()
  if type(state.pending) == "table"
      or not state.globalCooldownOpen
      or queuedStandardPending() then
    return false
  end
  local registration = boop.runtime
    and boop.runtime.newOutboundRegistration
    and boop.runtime.newOutboundRegistration("rage")
    or false
  if type(registration) ~= "table"
      or not registration.owner
      or not registration.generation
      or not registration.dispatchId then
    return false
  end
  state.dispatchGeneration = math.max(
    state.dispatchGeneration,
    tonumber(registration.generation) or 0
  )
  local authority = type(options.sourceAuthority) == "table"
      and deepCopy(options.sourceAuthority)
    or false
  local roomId = authority and tostring(authority.roomId or "")
    or currentRoomId()
  local snapshot = boop.runtime.outboundSnapshot()
  state.pending = {
    owner = tostring(registration.owner),
    generation = tonumber(registration.generation),
    dispatchId = tostring(registration.dispatchId),
    kind = "rage",
    mode = "direct",
    status = "dispatching",
    terminal = false,
    firstTerminal = false,
    reason = "",
    terminalReason = "",
    abilityKey = keyForAbility(options.ability),
    ability = deepCopy(options.ability),
    logicalAction = tostring(options.logicalAction or ""),
    targetId = tostring(options.targetId or currentTargetId()),
    roomId = roomId,
    sourceAuthority = authority,
    connectionGeneration = connectionGeneration(),
    registeredAfterSequence = tonumber(snapshot.sequence) or 0,
    expectedWireCommands = {},
    observedWireCommands = {},
    finalOwnedWireSequence = false,
    contaminatedAt = false,
    contaminatedCommand = "",
    ambiguityTraced = false,
    windowOpen = false,
    responseTimer = false,
    startedAt = nowSeconds(),
  }
  return {
    owner = state.pending.owner,
    generation = state.pending.generation,
    dispatchId = state.pending.dispatchId,
    kind = "rage",
  }
end

function boop.rage.onOutboundObserved(observed)
  local operation = rageState().pending
  if type(operation) ~= "table"
      or operation.terminal
      or type(observed) ~= "table" then
    return false
  end
  syncPending(operation)
  local owned = sameIdentity(operation, observed)
  if not owned then
    local sequence = tonumber(observed.sequence) or 0
    local baseline = tonumber(operation.finalOwnedWireSequence) or 0
    if operation.status == "pending" and sequence > baseline
        and not operation.contaminatedAt then
      operation.contaminatedAt = sequence
      operation.contaminatedCommand = tostring(observed.command or "")
    elseif operation.status == "dispatching"
        and sequence > tonumber(operation.registeredAfterSequence or 0)
        and not operation.contaminatedAt then
      operation.contaminatedAt = sequence
      operation.contaminatedCommand = tostring(observed.command or "")
    end
  end
  return owned
end

function boop.rage.completeDispatch(identity)
  local operation = rageState().pending
  if not sameIdentity(operation, identity)
      or operation.terminal
      or operation.status ~= "dispatching" then
    return false
  end
  local complete, snapshot = completeOrderedDispatch(operation)
  if not complete
      or operation.contaminatedAt
      or not sourceAuthorityCurrent(operation)
      or tonumber(snapshot and snapshot.sequence)
        ~= tonumber(operation.finalOwnedWireSequence) then
    terminalizePending(operation, "cancelled", "dispatch_incomplete")
    return false
  end
  operation.status = "pending"
  operation.windowOpen = true
  local owner = operation.owner
  local generation = operation.generation
  local dispatchId = operation.dispatchId
  local expectedConnection = operation.connectionGeneration
  local seconds = tonumber(boop.config.rageFallbackSeconds) or 26
  if seconds <= 0 then seconds = 26 end
  operation.responseTimer = tempTimer(seconds, function()
    local current = rageState().pending
    if sameIdentity(current, {
      owner = owner,
      generation = generation,
      dispatchId = dispatchId,
    }) and tonumber(current.connectionGeneration) == expectedConnection
        and connectionGeneration() == expectedConnection then
      terminalizePending(current, "expired", "timeout")
    end
  end)
  return deepCopy(operation)
end

function boop.rage.cancelDispatch(identity, reason)
  local operation = rageState().pending
  if not sameIdentity(operation, identity) or operation.terminal then
    return false
  end
  return terminalizePending(
    operation,
    "cancelled",
    tostring(reason or "dispatch_failed")
  ) and true or false
end

function boop.rage.onPrompt()
  local operation = rageState().pending
  if type(operation) ~= "table"
      or operation.status ~= "pending"
      or operation.terminal then
    return false
  end
  return terminalizePending(operation, "executed", "prompt") and true or false
end

function boop.rage.onRageUsed(ability, identity)
  local state = rageState()
  if identity == nil or sameIdentity(state.pending, identity) then
    clearTriumph("matching_use")
  end

  local key = ""
  if type(ability) == "table" then
    key = keyForAbility(ability)
  elseif type(ability) == "string" then
    key = boop.util.safeLower(ability)
  end
  if key == "" then return end

  boop.rage.setReady(key, false)

  local seconds = tonumber(boop.config.rageFallbackSeconds) or 26
  if seconds <= 0 then return end

  local timers = state.timers
  if timers[key] then
    killTimer(timers[key])
  end
  state.timerGenerations[key] =
    (tonumber(state.timerGenerations[key]) or 0) + 1
  local timerGeneration = state.timerGenerations[key]
  local expectedConnection = connectionGeneration()
  local timerId
  timerId = tempTimer(seconds, function()
    local current = rageState()
    if tonumber(current.timerGenerations[key]) == timerGeneration
        and current.timers[key] == timerId
        and connectionGeneration() == expectedConnection then
      boop.rage.setReady(key, true)
      current.timers[key] = nil
    end
  end)
  timers[key] = timerId
  boop.state.rage.timers = timers
end

function boop.rage.onTriumphFreeRage()
  local state = rageState()
  if type(state.triumph) == "table"
      and state.triumph.active
      and state.triumph.timer
      and killTimer then
    killTimer(state.triumph.timer)
  end
  state.triumphGeneration = state.triumphGeneration + 1
  local generation = state.triumphGeneration
  local expectedConnection = connectionGeneration()
  local seconds = tonumber(boop.config.rageFallbackSeconds) or 26
  if seconds <= 0 then seconds = 26 end
  state.triumph = {
    generation = generation,
    active = true,
    timer = false,
    connectionGeneration = expectedConnection,
    grantedAt = nowSeconds(),
  }
  state.freeNext = true
  state.triumph.timer = tempTimer(seconds, function()
    local current = rageState().triumph
    if type(current) == "table"
        and current.active
        and tonumber(current.generation) == generation
        and tonumber(current.connectionGeneration) == expectedConnection
        and connectionGeneration() == expectedConnection then
      clearTriumph("timeout", generation)
    end
  end)
  if boop.trace and boop.trace.log then
    boop.trace.log(string.format(
      "rage triumph: next rage free | generation=%s",
      tostring(generation)
    ))
  end
end

function boop.rage.hasFreeNext()
  local state = rageState()
  return type(state.triumph) == "table"
    and state.triumph.active == true
    and state.freeNext == true
end

function boop.rage.onReadyList(list)
  for _, name in ipairs(list or {}) do
    boop.rage.setReady(name, true)
  end
end

function boop.rage.onCommandOutcome(rawLine)
  local line = tostring(rawLine or "")
  if line == NO_ABILITIES_RECOVERY then
    rageState().globalCooldownOpen = true
    return true
  end

  if boop.util.starts(line, AVAILABLE_PREFIX) then
    local rawList = line:sub(#AVAILABLE_PREFIX + 1)
    if rawList == "" then
      return false
    end
    local names = boop.util.split(rawList, ",")
    if #names == 0 then
      return false
    end
    for index, name in ipairs(names) do
      local normalized = boop.util.trim(name)
      if normalized == "" then
        return false
      end
      names[index] = normalized
    end
    local state = rageState()
    state.globalCooldownOpen = true
    boop.rage.onReadyList(names)
    return true
  end

  if line == RAGE_EXPIRED then
    return clearTriumph("expiry")
  end

  if line == COOLDOWN_DENIAL then
    local operation = causalPending(line)
    if not operation then
      return false
    end
    rageState().globalCooldownOpen = false
    return terminalizePending(
      operation,
      "denied",
      "global_cooldown"
    ) and true or false
  end

  local ability = line:match(
    "^Your (%w+) ability could be used again but you lack the necessary Rage%.$"
  )
  if ability then
    local abilityKey = boop.util.safeLower(boop.util.trim(ability))
    local operation = causalPending(line, abilityKey)
    if not operation then
      return false
    end
    clearTriumph("insufficient_rage")
    return terminalizePending(
      operation,
      "denied",
      "insufficient_rage"
    ) and true or false
  end

  return false
end

function boop.rage.onConnectionReset(reason)
  local state = rageState()
  local pending = state.pending
  if type(pending) == "table" and not pending.terminal then
    terminalizePending(
      pending,
      "cancelled",
      tostring(reason or "connection")
    )
  end
  clearTriumph("connection")
  for key, timerId in pairs(state.timers) do
    if timerId and killTimer then
      killTimer(timerId)
    end
    state.timerGenerations[key] =
      (tonumber(state.timerGenerations[key]) or 0) + 1
  end
  state.timers = {}
  state.globalCooldownOpen = true
  state.freeNext = false
  if boop.state.combat and boop.state.combat.limiters then
    boop.state.combat.limiters.rage = false
  end
  return true
end

function boop.rage.onRageObserved(value)
  local rage = tonumber(value)
  if not rage then return end

  local state = rageState()
  state.amount = rage
  local samples = state.samples
  local now = nowSeconds()

  if #samples > 0 and math.abs((samples[#samples].t or 0) - now) < 0.05 then
    samples[#samples].r = rage
  else
    samples[#samples + 1] = { t = now, r = rage }
  end

  local cutoff = now - 65
  while #samples > 0 and (samples[1].t or 0) < cutoff do
    table.remove(samples, 1)
  end
end

function boop.rage.getGainRate(windowSeconds)
  local window = tonumber(windowSeconds) or 10
  if window <= 0 then return 0 end

  local samples = boop.state and boop.state.rage.samples or {}
  if not samples or #samples < 2 then return 0 end

  local cutoff = nowSeconds() - window
  local prev = nil
  local firstT = nil
  local lastT = nil
  local gained = 0

  for _, sample in ipairs(samples) do
    local t = tonumber(sample.t) or 0
    local r = tonumber(sample.r) or 0
    if t >= cutoff then
      if not firstT then
        firstT = t
      end
      if prev then
        local delta = r - (tonumber(prev.r) or 0)
        if delta > 0 then
          gained = gained + delta
        end
      end
      lastT = t
    end
    prev = sample
  end

  if not firstT or not lastT then return 0 end
  local elapsed = lastT - firstT
  if elapsed <= 0 then return 0 end
  return gained / elapsed
end

function boop.rage.etaToRage(targetRage, currentRage, windowSeconds)
  local target = tonumber(targetRage)
  local current = tonumber(currentRage)
  if not target or not current then return nil end
  if current >= target then return 0 end

  local rate = boop.rage.getGainRate(windowSeconds or 10)
  if rate <= 0 then return nil end

  return (target - current) / rate
end

function boop.rage.onHoundMaulUsed()
  boop.rage.setReady("maul", false)
  if boop.trace and boop.trace.log then
    boop.trace.log("hound maul used")
  end
end

function boop.rage.onHoundMaulReady()
  boop.rage.setReady("maul", true)
  if boop.trace and boop.trace.log then
    boop.trace.log("hound maul ready")
  end
end

function boop.rage.onHoundMaulNotReady()
  boop.rage.setReady("maul", false)
  if boop.trace and boop.trace.log then
    boop.trace.log("hound maul not ready")
  end
end

function boop.rage.onHyenaMaulUsed()
  boop.rage.setReady("maul", false)
  if boop.trace and boop.trace.log then
    boop.trace.log("hyena maul used")
  end
end

function boop.rage.onHyenaMaulReady()
  boop.rage.setReady("maul", true)
  if boop.trace and boop.trace.log then
    boop.trace.log("hyena maul ready")
  end
end

function boop.rage.onHyenaMaulNotReady()
  boop.rage.setReady("maul", false)
  if boop.trace and boop.trace.log then
    boop.trace.log("hyena maul not ready")
  end
end

local function normalizeEntityName(name)
  if not name then return "" end
  local value = boop.util.trim(tostring(name))
  value = value:gsub("\226\128\152", "'") -- left single quotation mark
  value = value:gsub("\226\128\153", "'") -- right single quotation mark
  return boop.util.safeLower(value)
end

local function sameEntityName(a, b)
  local left = normalizeEntityName(a)
  local right = normalizeEntityName(b)
  if left == "" or right == "" then return false end
  return left == right
end

local function resolveCapture(expr, matchTable)
  if type(expr) ~= "table" then return "" end
  local kind = expr.kind
  if kind == "match" then
    local idx = tonumber(expr.index)
    if not idx or type(matchTable) ~= "table" then return "" end
    return tostring(matchTable[idx] or "")
  end
  if kind == "literal" then
    return tostring(expr.value or "")
  end
  return ""
end

local function shouldTrackTarget(targetName)
  local captured = boop.util.trim(targetName or "")
  if captured == "" then return true end

  boop.state = boop.state or {}
  local current = boop.util.trim(boop.state.targeting.targetName or "")
  if current == "" and (boop.state.targeting.currentTargetId or "") ~= "" then
    -- Populate when we have an id but no name yet; this avoids dropping early lines.
    boop.state.targeting.targetName = captured
    current = captured
  end
  if current == "" then return false end
  return sameEntityName(captured, current)
end

local function sendAffCallout(mode, aff)
  if boop.config and boop.config.rageAffCalloutsEnabled == false then
    return
  end
  local key = boop.util.safeLower(boop.util.trim(aff or ""))
  if key == "stunned" then
    key = "stun"
  end
  if key == "" then return end
  local targetId = boop.util.trim(tostring((boop.state and boop.state.targeting.currentTargetId) or ""))
  if targetId == "" then return end

  local text
  if mode == "remove" then
    text = string.format("pt %s: %s down", targetId, key)
  else
    text = string.format("pt %s: %s", targetId, key)
  end
  send(text, false)
  if boop.util and boop.util.info then
    boop.util.info("callout: " .. text)
  end
end

function boop.rage.onAfflictionTrigger(spec, matchTable, _rawLine)
  if type(spec) ~= "table" then return end
  if not boop.afflictions then return end
  if boop.config and boop.config.enabled == false then return end

  local mode = boop.util.safeLower(spec.mode or "")
  local affs = spec.affs or {}
  if type(affs) ~= "table" or #affs == 0 then return end

  local target = resolveCapture(spec.target, matchTable)
  if not shouldTrackTarget(target) then return end

  local actor = resolveCapture(spec.user, matchTable)
  local source = boop.util.trim(spec.source or "battlerage")

  for _, aff in ipairs(affs) do
    local key = boop.util.safeLower(boop.util.trim(aff or ""))
    if key ~= "" then
      if mode == "add" then
        local changed = boop.afflictions.addTarget(key)
        if changed then
          sendAffCallout(mode, key)
        end
      elseif mode == "remove" then
        local changed = boop.afflictions.removeTarget(key)
        if changed then
          sendAffCallout(mode, key)
        end
      end
      if boop.trace and boop.trace.log then
        boop.trace.log(string.format("rage aff %s: %s (%s) actor=%s target=%s", mode, key, source, actor ~= "" and actor or "?", target ~= "" and target or "?"))
      end
    end
  end
end
