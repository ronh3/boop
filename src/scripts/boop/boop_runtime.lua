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
    pullState = false,
    blocker = {
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
      warningThrottleSeconds = 2,
    },
    lastComboTraceKey = nil,
    lastOpenerTraceKey = nil,
    lastRageDecision = nil,
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
  },
  gold = {
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
    aliasAction = "",
    aliasDirty = true,
  },
  walk = {
    active = false,
    owned = false,
    roomSettled = false,
    moveQueued = false,
    arrivalRoom = "",
    arrivalTimer = nil,
  },
  diag = {
    hold = false,
    awaitPrompt = false,
    timeoutTimer = nil,
    label = "",
  },
  trace = {
    buffer = {},
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

function boop.runtime.ensureState()
  boop.state = boop.state or {}
  local state = boop.state

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
  return state
end

function boop.runtime.state()
  return boop.runtime.ensureState()
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
  return table.concat(keys, ",")
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

local function currentBlocker()
  local state = boop.runtime.ensureState()
  state.combat.blocker = state.combat.blocker or deepCopy(DOMAIN_DEFAULTS.combat.blocker)
  return state.combat.blocker
end

local function blockerChanged(current, nextBlocker)
  return tostring(current.code or "") ~= tostring(nextBlocker.code or "")
    or tostring(current.label or "") ~= tostring(nextBlocker.label or "")
    or not mapsEqual(current.systems, nextBlocker.systems)
    or not mapsEqual(current.waitsFor, nextBlocker.waitsFor)
    or not mapsEqual(current.observed, nextBlocker.observed)
end

local function setBlockerFields(blocker, nextBlocker, preserveSince)
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
  blocker.warningThrottleSeconds = nextBlocker.warningThrottleSeconds
end

function boop.runtime.blockerSnapshot()
  local blocker = currentBlocker()
  return {
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
    warningThrottleSeconds = tonumber(blocker.warningThrottleSeconds) or 2,
  }
end

function boop.runtime.setBlocker(code, label, systems, waitsFor, opts)
  local input = code
  if type(input) == "table" then
    opts = input
    code = input.code
    label = input.label
    systems = input.systems
    waitsFor = input.waitsFor
  end
  opts = opts or {}

  local nextBlocker = {
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

  local blocker = currentBlocker()
  local changed = blockerChanged(blocker, nextBlocker)
  setBlockerFields(blocker, nextBlocker, not changed)
  if changed and nextBlocker.code ~= "" then
    trace(string.format(
      "blocker enter: %s -- %s | systems=%s | waitsFor=%s | observed=%s",
      nextBlocker.code,
      nextBlocker.label,
      formatMapKeys(nextBlocker.systems),
      formatMapKeys(nextBlocker.waitsFor),
      formatObserved(nextBlocker.observed)
    ))
  end
  return boop.runtime.blockerSnapshot()
end

function boop.runtime.clearBlocker(codeOrSource, observed)
  local blocker = currentBlocker()
  local code = tostring(blocker.code or "")
  if code == "" then
    return false
  end
  if type(observed) == "table" then
    for key, value in pairs(observed) do
      blocker.observed[tostring(key)] = value
    end
  end
  local reason = tostring(codeOrSource or "cleared")
  local label = tostring(blocker.label or "")
  trace(string.format("blocker exit: %s -- %s | reason=%s", code, label, reason))
  setBlockerFields(blocker, deepCopy(DOMAIN_DEFAULTS.combat.blocker), false)
  return true
end

function boop.runtime.shouldHold(system)
  local blocker = boop.runtime.blockerSnapshot()
  if blocker.code == "" then
    return false
  end
  local key = normalizeKey(system)
  return blocker.systems[key] == true
end

local function blockerCanAutoClear(blocker)
  if tostring(blocker.code or "") == "" then
    return false
  end
  return blocker.promptSeen and blocker.gmcpSeen
end

local function maybeClearObservedBlocker(reason)
  local blocker = currentBlocker()
  if blockerCanAutoClear(blocker) then
    boop.runtime.clearBlocker(reason or "observed prompt and gmcp")
  end
end

function boop.runtime.notePromptObserved()
  local blocker = currentBlocker()
  if tostring(blocker.code or "") == "" then
    return false
  end
  blocker.promptSeen = true
  blocker.observed = blocker.observed or {}
  blocker.observed.prompt = true
  maybeClearObservedBlocker("observed prompt and gmcp")
  return true
end

function boop.runtime.noteGmcpObserved(kind)
  local blocker = currentBlocker()
  if tostring(blocker.code or "") == "" then
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
  maybeClearObservedBlocker("observed prompt and gmcp")
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
  state.queue.aliasAction = ""
  state.queue.aliasDirty = true

  state.targeting.calledTargetId = ""
  state.targeting.calledTargetRoom = ""
  state.targeting.calledTargetBy = ""
  state.targeting.calledTargetAt = nil

  if tostring(reason or "") == "target_lost" then
    state.targeting.currentTargetId = ""
    state.targeting.targetName = ""
    if boop.targets and boop.targets.clearTargetShield then
      boop.targets.clearTargetShield("target_lost")
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
    boop.runtime.clearAttackIntent(reason, { suppressTrace = true })
  end

  if includeWalk then
    killOwnedTimer(state.walk.arrivalTimer)
    state.walk.active = false
    state.walk.owned = false
    state.walk.roomSettled = false
    state.walk.moveQueued = false
    state.walk.arrivalRoom = ""
    state.walk.arrivalTimer = nil
  end

  if includeGold then
    killOwnedTimer(state.gold.autoGrabTimer)
    killOwnedTimer(state.gold.pendingTimer)
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

function boop.runtime.context()
  local state = boop.runtime.ensureState()
  local room = currentRoom()
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

  return {
    state = state,
    config = boop.config or {},
    gmcp = gmcp,
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
    gold = {
      autoGrabPending = not not state.gold.autoGrabPending,
      getPending = not not state.gold.getPending,
      putPending = not not state.gold.putPending,
      packTarget = tostring(state.gold.packTarget or ""),
    },
    diag = {
      hold = not not state.diag.hold,
      awaitPrompt = not not state.diag.awaitPrompt,
      label = tostring(state.diag.label or ""),
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
    blocker = boop.runtime.blockerSnapshot(),
  }
end

local function heldEffect(context, system, detail)
  local blocker = context.blocker or boop.runtime.blockerSnapshot()
  return {
    kind = "trace",
    message = string.format(
      "%s held: %s -- %s",
      tostring(detail or system or "automation"),
      tostring(blocker.code or ""),
      tostring(blocker.label or "")
    ),
  }
end

local function tickStep(context)
  local state = context.state
  local effects = {}

  if not (context.config and context.config.enabled) then
    return { effects = effects, didAction = false }
  end
  if state.diag.hold then
    return { effects = effects, didAction = false }
  end
  if boop.runtime.shouldHold("target")
    or boop.runtime.shouldHold("combat")
    or boop.runtime.shouldHold("queue")
    or boop.runtime.shouldHold("gold")
    or boop.runtime.shouldHold("walk")
  then
    effects[#effects + 1] = heldEffect(context, "automation", "tick")
    return { effects = effects, didAction = false }
  end
  if boop.maybeFlushPendingGold and boop.maybeFlushPendingGold("tick pending age") then
    return { effects = effects, didAction = false }
  end
  if state.gold.getPending or state.gold.putPending then
    return { effects = effects, didAction = false }
  end

  if boop.safety and boop.safety.shouldFlee and boop.safety.shouldFlee() then
    effects[#effects + 1] = { kind = "flee" }
    return { effects = effects, didAction = false }
  end

  local targetId = boop.targets and boop.targets.choose and boop.targets.choose() or ""
  if not targetId or targetId == "" then
    if context.config.useQueueing and state.gold.autoGrabPending then
      effects[#effects + 1] = { kind = "flush_gold", reason = "tick no target" }
    end
    if boop.targets and boop.targets.waitingForTargetCall and boop.targets.waitingForTargetCall() then
      effects[#effects + 1] = { kind = "trace", message = "tick: waiting for leader target call" }
      return { effects = effects, didAction = false }
    end
    effects[#effects + 1] = { kind = "trace", message = "tick: no target" }
    effects[#effects + 1] = { kind = "walk_advance", reason = "tick no target" }
    return { effects = effects, didAction = false }
  end

  if tostring(state.targeting.currentTargetId or "") ~= tostring(targetId) then
    effects[#effects + 1] = { kind = "target", id = tostring(targetId) }
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
    effects[#effects + 1] = { kind = "combat_plan", plan = plan, context = planContext }
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

  if state.diag.hold then
    if state.diag.awaitPrompt then
      effects[#effects + 1] = {
        kind = "diag_complete",
        label = state.diag.label ~= "" and state.diag.label or "diag",
      }
    else
      runTick = false
    end
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
    if effect.kind == "trace" then
      if boop.trace and boop.trace.log then
        boop.trace.log(effect.message or "")
      end
    elseif effect.kind == "flush_gold" then
      if boop.flushPendingGold then
        boop.flushPendingGold(effect.reason or "runtime")
      end
    elseif effect.kind == "walk_advance" then
      if boop.walk and boop.walk.maybeAdvance then
        boop.walk.maybeAdvance(effect.reason or "runtime")
      end
    elseif effect.kind == "flee" then
      if boop.safety and boop.safety.flee then
        boop.safety.flee()
      end
    elseif effect.kind == "target" then
      if boop.targets and boop.targets.setTarget then
        boop.targets.setTarget(effect.id)
      end
    elseif effect.kind == "combat_plan" then
      if boop.attacks and boop.attacks.execute then
        if boop.attacks.execute(effect.plan, effect.context or context) then
          didAction = true
        end
      end
    elseif effect.kind == "diag_complete" then
      state.diag.hold = false
      state.diag.awaitPrompt = false
      state.diag.label = ""
      if state.diag.timeoutTimer then
        killTimer(state.diag.timeoutTimer)
        state.diag.timeoutTimer = nil
      end
      if boop.util and boop.util.ok then
        boop.util.ok((effect.label or "diag") .. " complete; attacks resumed")
      end
      if boop.trace and boop.trace.log then
        boop.trace.log((effect.label or "diag") .. " complete")
      end
    elseif effect.kind == "gag_prompt" then
      if boop.gag and boop.gag.onPrompt then
        boop.gag.onPrompt()
      end
    end
  end

  return didAction
end
