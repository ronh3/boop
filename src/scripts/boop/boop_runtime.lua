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
  },
}

local LEGACY_STATE_MAP = {
  hunting = { "combat", "hunting" },
  attacking = { "combat", "attacking" },
  fleeing = { "combat", "fleeing" },
  class = { "combat", "class" },
  spec = { "combat", "spec" },
  limiters = { "combat", "limiters" },
  openerUsedByClass = { "combat", "openerUsedByClass" },
  pullState = { "combat", "pullState" },
  lastComboTraceKey = { "combat", "lastComboTraceKey" },
  lastOpenerTraceKey = { "combat", "lastOpenerTraceKey" },
  lastRageDecision = { "combat", "lastRageDecision" },
  currentTargetId = { "targeting", "currentTargetId" },
  targetName = { "targeting", "targetName" },
  targetShield = { "targeting", "targetShield" },
  denizens = { "targeting", "denizens" },
  room = { "targeting", "room" },
  lastRoom = { "targeting", "lastRoom" },
  lastRoomDir = { "targeting", "lastRoomDir" },
  movedRooms = { "targeting", "movedRooms" },
  calledTargetId = { "targeting", "calledTargetId" },
  calledTargetRoom = { "targeting", "calledTargetRoom" },
  calledTargetBy = { "targeting", "calledTargetBy" },
  calledTargetAt = { "targeting", "calledTargetAt" },
  goldDropped = { "gold", "dropped" },
  shardsDropped = { "gold", "shardsDropped" },
  autoGrabGoldPending = { "gold", "autoGrabPending" },
  autoGrabGoldPendingAt = { "gold", "autoGrabPendingAt" },
  autoGrabGoldTimer = { "gold", "autoGrabTimer" },
  goldGetPending = { "gold", "getPending" },
  goldPutPending = { "gold", "putPending" },
  goldGetRetries = { "gold", "getRetries" },
  goldPutRetries = { "gold", "putRetries" },
  goldPackTarget = { "gold", "packTarget" },
  goldPendingTimer = { "gold", "pendingTimer" },
  balanceReadyAt = { "queue", "balanceReadyAt" },
  equilibriumReadyAt = { "queue", "equilibriumReadyAt" },
  prequeueTimer = { "queue", "prequeueTimer" },
  prequeuedStandard = { "queue", "prequeuedStandard" },
  queueAliasAction = { "queue", "aliasAction" },
  queueAliasDirty = { "queue", "aliasDirty" },
  walkActive = { "walk", "active" },
  walkOwned = { "walk", "owned" },
  walkRoomSettled = { "walk", "roomSettled" },
  walkMoveQueued = { "walk", "moveQueued" },
  walkArrivalRoom = { "walk", "arrivalRoom" },
  walkArrivalTimer = { "walk", "arrivalTimer" },
  diagHold = { "diag", "hold" },
  diagAwaitPrompt = { "diag", "awaitPrompt" },
  diagTimeoutTimer = { "diag", "timeoutTimer" },
  diagLabel = { "diag", "label" },
  traceBuffer = { "trace", "buffer" },
  configScreen = { "ui", "configScreen" },
  configReturnScreen = { "ui", "configReturnScreen" },
  configReturnPrefix = { "ui", "configReturnPrefix" },
  rageReady = { "rage", "ready" },
  rageTimers = { "rage", "timers" },
  rageSamples = { "rage", "samples" },
  inventoryItemsById = { "inventory", "itemsById" },
  wieldedLeft = { "inventory", "wieldedLeft" },
  wieldedRight = { "inventory", "wieldedRight" },
  ihActive = { "ih", "active" },
  ihRequested = { "ih", "requested" },
  ihTimer = { "ih", "timer" },
  lastGagRawLine = { "gag", "lastRawLine" },
  lastGagAt = { "gag", "lastAt" },
  gagPendingAttack = { "gag", "pendingAttack" },
  gagPendingAttackTimer = { "gag", "pendingAttackTimer" },
  gagPendingKill = { "gag", "pendingKill" },
  gagPendingKillTimer = { "gag", "pendingKillTimer" },
}

local function installStateMetatable(state)
  local meta = getmetatable(state) or {}
  if meta.__boop_runtime_installed then
    return
  end

  meta.__boop_runtime_installed = true
  meta.__index = function(tbl, key)
    local mapping = LEGACY_STATE_MAP[key]
    if mapping then
      local domain = rawget(tbl, mapping[1])
      if type(domain) == "table" then
        return domain[mapping[2]]
      end
    end
    return nil
  end
  meta.__newindex = function(tbl, key, value)
    local mapping = LEGACY_STATE_MAP[key]
    if mapping then
      local domain = rawget(tbl, mapping[1])
      if type(domain) ~= "table" then
        domain = {}
        rawset(tbl, mapping[1], domain)
      end
      domain[mapping[2]] = value
      return
    end
    rawset(tbl, key, value)
  end

  setmetatable(state, meta)
end

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

  for legacyKey, mapping in pairs(LEGACY_STATE_MAP) do
    local rawValue = rawget(state, legacyKey)
    local domain = rawget(state, mapping[1])
    if rawValue ~= nil then
      domain[mapping[2]] = rawValue
      rawset(state, legacyKey, nil)
    end
  end

  installStateMetatable(state)
  return state
end

function boop.runtime.state()
  return boop.runtime.ensureState()
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
  local hpperc = gmcp and gmcp.IRE and gmcp.IRE.Target and gmcp.IRE.Target.Info and gmcp.IRE.Target.Info.hpperc or ""
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
      id = tostring(state.targeting.currentTargetId or ""),
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
