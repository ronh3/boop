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
    stateSchemaVersion = 1,
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
    pullGeneration = 0,
    pullState = false,
    operationModelVersion = 1,
    blockersByOwner = {},
    blocker = {
      owner = "",
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
      lastRetryAt = nil,
      warningThrottleSeconds = 2,
      additionalCount = 0,
    },
    lastComboTraceKey = nil,
    lastOpenerTraceKey = nil,
    lastRageDecision = nil,
    temporaryAttackPreferences = {},
  },
  lifecycle = {
    connectionGeneration = 0,
    promptSeen = false,
    ireSeen = false,
    ready = false,
    source = "",
    lastRetryAt = nil,
    lastWarningAt = nil,
    lastWarningCode = "",
    warningThrottleSeconds = 2,
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
    gameTargetSync = {
      generation = 0,
      desiredId = "",
      confirmedId = "",
      pending = false,
      attempts = 0,
      retryTimer = false,
      suppressed = 0,
      exhausted = false,
    },
    roomObservation = {
      generation = 0,
      roomId = "",
      infoSeen = false,
      itemsSeen = false,
      acceptedItems = {},
      fenceQueue = {},
      activeFenceId = false,
      nextFenceId = 1,
      lastCompletedFence = false,
      nextApplicationId = 1,
      activeApplication = false,
      acceptedSourceAuthority = false,
      refreshAttempted = false,
      refreshReason = "",
      refreshTimeoutTimer = false,
      warned = false,
    },
    movementIntent = {
      generation = 0,
      active = false,
      direction = "",
      originRoomId = "",
      originObservationGeneration = 0,
      sentAt = nil,
      candidateItems = false,
      candidateAt = nil,
      candidateFenceId = false,
      candidateStatus = "",
      lastReason = "",
    },
  },
  gold = {
    generation = 0,
    operation = false,
    packQuarantineGeneration = 0,
    packQuarantine = false,
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
    prequeueSourceAuthority = false,
    aliasAction = "",
    aliasDirty = true,
    outboundSequence = 0,
    outboundExpectations = {},
    outboundObserved = {},
    outboundDispatchGeneration = 0,
    outboundDispatches = {},
    standardGeneration = 0,
    standardDispatchId = 0,
    standardOperation = false,
    lastStandardTerminal = false,
    standardRecovery = false,
    promptSequence = 0,
  },
  walk = {
    active = false,
    owned = false,
    roomSettled = false,
    moveQueued = false,
    arrivalRoom = "",
    generation = 0,
    roomGeneration = 0,
    moveIssuedForRoomGeneration = false,
    reservationId = 0,
    refreshTimer = nil,
    emitterTimer = nil,
    refreshWarned = false,
  },
  diag = {
    hold = false,
    awaitPrompt = false,
    timeoutTimer = nil,
    label = "",
    generation = 0,
    operation = false,
    evidenceQueue = {},
    venomConfusionCount = 0,
  },
  trace = {
    buffer = {},
    live = false,
  },
  ui = {
    configScreen = "home",
    configReturnScreen = nil,
    configReturnPrefix = nil,
  },
  rage = {
    amount = 0,
    ready = {},
    timers = {},
    samples = {},
    freeNext = false,
  },
  inventory = {
    generation = 0,
    completeItems = {},
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

local STATE_SCHEMA_VERSION = 1
local OPERATION_MODEL_VERSION = 1
local DOMAIN_NAMES = {
  "combat",
  "lifecycle",
  "targeting",
  "gold",
  "queue",
  "walk",
  "diag",
  "trace",
  "ui",
  "rage",
  "inventory",
  "ih",
  "gag",
}

function boop.runtime.ensureState()
  if type(boop.state) ~= "table" then
    boop.state = {}
  end
  local state = boop.state
  local previousCombat = rawget(state, "combat")
  local schemaCurrent = type(previousCombat) == "table"
    and tonumber(rawget(previousCombat, "stateSchemaVersion"))
      == STATE_SCHEMA_VERSION
  local migrateOperationModel = type(previousCombat) == "table"
    and tonumber(rawget(previousCombat, "operationModelVersion"))
      ~= OPERATION_MODEL_VERSION

  if schemaCurrent and not migrateOperationModel then
    local domainsIntact = true
    for _, domain in ipairs(DOMAIN_NAMES) do
      if type(rawget(state, domain)) ~= "table" then
        domainsIntact = false
        break
      end
    end
    if domainsIntact then
      return state
    end
  end

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

  state.combat.blockersByOwner =
    type(state.combat.blockersByOwner) == "table"
      and state.combat.blockersByOwner
      or {}
  if migrateOperationModel then
    for owner in pairs(state.combat.blockersByOwner) do
      if not (boop.locks
          and boop.locks.isOperationOwner
          and boop.locks.isOperationOwner(owner)) then
        state.combat.blockersByOwner[owner] = nil
      end
    end
  end
  state.combat.stateSchemaVersion = STATE_SCHEMA_VERSION
  state.combat.operationModelVersion = OPERATION_MODEL_VERSION
  state.combat.operationLocksByOwner = state.combat.blockersByOwner
  state.combat.operationLock =
    type(state.combat.operationLock) == "table"
      and state.combat.operationLock
      or deepCopy(DOMAIN_DEFAULTS.combat.blocker)
  return state
end

function boop.runtime.state()
  return boop.runtime.ensureState()
end

local function lifecycleState()
  local lifecycle = boop.runtime.ensureState().lifecycle
  lifecycle.connectionGeneration =
    tonumber(lifecycle.connectionGeneration) or 0
  lifecycle.promptSeen = not not lifecycle.promptSeen
  lifecycle.ireSeen = not not lifecycle.ireSeen
  lifecycle.ready = lifecycle.promptSeen and lifecycle.ireSeen
  lifecycle.source = tostring(lifecycle.source or "")
  lifecycle.warningThrottleSeconds =
    tonumber(lifecycle.warningThrottleSeconds) or 2
  lifecycle.lastWarningCode =
    tostring(lifecycle.lastWarningCode or "")
  return lifecycle
end

function boop.runtime.beginConnectionLifecycle(source)
  local lifecycle = lifecycleState()
  lifecycle.connectionGeneration = lifecycle.connectionGeneration + 1
  lifecycle.promptSeen = false
  lifecycle.ireSeen = false
  lifecycle.ready = false
  lifecycle.source = tostring(source or "connection")
  lifecycle.lastRetryAt = nil
  lifecycle.lastWarningAt = nil
  lifecycle.lastWarningCode = ""
  return boop.runtime.lifecycleSnapshot()
end

function boop.runtime.observeLifecycleIre(available, source)
  local lifecycle = lifecycleState()
  lifecycle.ireSeen = available == true
  lifecycle.ready = lifecycle.promptSeen and lifecycle.ireSeen
  lifecycle.source = tostring(source or "ire")
  return boop.runtime.lifecycleSnapshot()
end

function boop.runtime.observeLifecyclePrompt(source)
  local lifecycle = lifecycleState()
  lifecycle.promptSeen = true
  lifecycle.ready = lifecycle.promptSeen and lifecycle.ireSeen
  lifecycle.source = tostring(source or "prompt")
  return boop.runtime.lifecycleSnapshot()
end

function boop.runtime.lifecycleSnapshot()
  local lifecycle = lifecycleState()
  return {
    connectionGeneration = lifecycle.connectionGeneration,
    promptSeen = lifecycle.promptSeen,
    ireSeen = lifecycle.ireSeen,
    ready = lifecycle.ready,
    source = lifecycle.source,
    lastRetryAt = lifecycle.lastRetryAt,
    lastWarningAt = lifecycle.lastWarningAt,
    lastWarningCode = lifecycle.lastWarningCode,
    warningThrottleSeconds = lifecycle.warningThrottleSeconds,
  }
end

function boop.runtime.readinessSnapshot()
  return {
    lifecycle = boop.runtime.lifecycleSnapshot(),
    room = boop.room.roomReadinessSnapshot(),
  }
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

local function sourceAuthorityMatches(left, right)
  local leftCopy = copySourceAuthority(left)
  local rightCopy = copySourceAuthority(right)
  return leftCopy
    and rightCopy
    and leftCopy.applicationId ~= nil
    and leftCopy.roomId ~= ""
    and leftCopy.observationGeneration ~= nil
    and leftCopy.applicationId == rightCopy.applicationId
    and leftCopy.roomId == rightCopy.roomId
    and leftCopy.observationGeneration == rightCopy.observationGeneration
end

local function trace(message)
  if boop.trace and boop.trace.log then
    boop.trace.log(message)
  end
end

local STANDARD_GRACE_SECONDS = 0.35
local PACK_QUARANTINE_GRACE_SECONDS = 0.35
local OUTBOUND_HISTORY_LIMIT = 64
local OUTBOUND_EXPECTATION_LIMIT = 16
local LEAP_DENIAL_LINE =
  "Both of your legs must be free and unhindered to do that."

local function packQuarantineState()
  local state = boop.runtime.ensureState()
  local quarantine = state.gold.packQuarantine
  if type(quarantine) ~= "table" then
    return false
  end
  quarantine.quarantineId = tonumber(quarantine.quarantineId) or 0
  quarantine.oldGeneration = tonumber(quarantine.oldGeneration) or 0
  quarantine.oldDispatchId = tonumber(quarantine.oldDispatchId) or 0
  quarantine.outboundSequence = tonumber(quarantine.outboundSequence) or 0
  quarantine.releaseInventoryGeneration =
    tonumber(quarantine.releaseInventoryGeneration) or 0
  quarantine.releasePromptSequence =
    tonumber(quarantine.releasePromptSequence) or 0
  quarantine.windowOpenPromptSequence =
    tonumber(quarantine.windowOpenPromptSequence) or false
  quarantine.windowClosePromptSequence =
    tonumber(quarantine.windowClosePromptSequence) or false
  quarantine.graceToken = tonumber(quarantine.graceToken) or 0
  quarantine.graceInventoryGeneration =
    tonumber(quarantine.graceInventoryGeneration) or false
  quarantine.requiredInventoryGeneration = math.max(
    1,
    tonumber(quarantine.requiredInventoryGeneration) or 1
  )
  quarantine.qualifyingInventoryGeneration =
    tonumber(quarantine.qualifyingInventoryGeneration) or false
  quarantine.windowClosed = not not quarantine.windowClosed
  quarantine.graceExpired = not not quarantine.graceExpired
  quarantine.inventoryHasSovereigns =
    not not quarantine.inventoryHasSovereigns
  quarantine.eligible = not not quarantine.eligible
  quarantine.consumed = not not quarantine.consumed
  quarantine.resolved = not not quarantine.resolved
  quarantine.resolutionReason = tostring(
    quarantine.resolutionReason or ""
  )
  quarantine.lateActivityCount =
    tonumber(quarantine.lateActivityCount) or 0
  return quarantine
end

local function activePackQuarantine()
  local quarantine = packQuarantineState()
  if not quarantine or quarantine.resolved or quarantine.consumed then
    return false
  end
  return quarantine
end

local function inventoryState()
  local inventory = boop.runtime.ensureState().inventory
  inventory.generation = tonumber(inventory.generation) or 0
  inventory.completeItems = type(inventory.completeItems) == "table"
      and inventory.completeItems
    or {}
  return inventory
end

function boop.runtime.packQuarantineSnapshot()
  local quarantine = packQuarantineState()
  return quarantine and deepCopy(quarantine) or false
end

function boop.runtime.createPackQuarantine(operation)
  if type(operation) ~= "table"
      or tostring(operation.phase or "") ~= "pack_pending"
      or operation.terminal then
    return false
  end
  local state = boop.runtime.ensureState()
  local previous = activePackQuarantine()
  if previous then
    if previous.graceTimer and killTimer then
      killTimer(previous.graceTimer)
    end
    previous.graceTimer = false
    previous.eligible = false
    previous.resolved = true
    previous.resolutionReason = "superseded"
  end
  state.gold.packQuarantineGeneration =
    (tonumber(state.gold.packQuarantineGeneration) or 0) + 1
  state.queue.promptSequence = tonumber(state.queue.promptSequence) or 0
  local inventory = inventoryState()
  local quarantine = {
    quarantineId = state.gold.packQuarantineGeneration,
    oldOwner = tostring(operation.blockerOwner or ""),
    oldGeneration = tonumber(operation.generation) or 0,
    oldDispatchId = tonumber(operation.dispatchId) or 0,
    oldDispatchProvenance = tostring(
      operation.dispatchProvenance or ""
    ),
    nativePut = tostring(operation.nativeCommand or ""),
    wireCommand = tostring(operation.wireCommand or ""),
    packTarget = tostring(operation.packTarget or ""),
    outboundSequence = tonumber(operation.outboundSequence) or 0,
    releaseInventoryGeneration = inventory.generation,
    releasePromptSequence = state.queue.promptSequence,
    windowOpenPromptSequence = false,
    windowClosePromptSequence = false,
    windowClosed = false,
    graceToken = 0,
    graceTimer = false,
    graceExpired = false,
    graceInventoryGeneration = false,
    requiredInventoryGeneration = inventory.generation + 1,
    qualifyingInventoryGeneration = false,
    inventoryHasSovereigns = false,
    eligible = false,
    consumed = false,
    resolved = false,
    resolutionReason = "",
    lateActivityCount = 0,
    lastLateActivity = "",
    lastLateOutboundSequence = false,
  }
  state.gold.packQuarantine = quarantine
  trace(string.format(
    "gold pack quarantine created: owner=%s | generation=%s | dispatch=%s | inventory=%s | outbound=%s",
    quarantine.oldOwner,
    tostring(quarantine.oldGeneration),
    tostring(quarantine.oldDispatchId),
    tostring(quarantine.releaseInventoryGeneration),
    tostring(quarantine.outboundSequence)
  ))
  return deepCopy(quarantine)
end

function boop.runtime.resolvePackQuarantine(reason)
  local quarantine = activePackQuarantine()
  if not quarantine then
    return false
  end
  if quarantine.graceTimer and killTimer then
    killTimer(quarantine.graceTimer)
  end
  quarantine.graceTimer = false
  quarantine.eligible = false
  quarantine.inventoryHasSovereigns = false
  quarantine.resolved = true
  quarantine.resolutionReason = tostring(reason or "resolved")
  trace(string.format(
    "gold pack quarantine resolved: owner=%s | generation=%s | reason=%s",
    quarantine.oldOwner,
    tostring(quarantine.oldGeneration),
    quarantine.resolutionReason
  ))
  return true
end

function boop.runtime.observePackQuarantinePrompt(ready)
  local state = boop.runtime.ensureState()
  state.queue.promptSequence =
    (tonumber(state.queue.promptSequence) or 0) + 1
  local sequence = state.queue.promptSequence
  local quarantine = activePackQuarantine()
  if not quarantine then
    return false
  end
  if not quarantine.windowOpenPromptSequence then
    if ready ~= true then
      return false
    end
    quarantine.windowOpenPromptSequence = sequence
    trace(string.format(
      "gold pack quarantine window opened: generation=%s | prompt=%s",
      tostring(quarantine.oldGeneration),
      tostring(sequence)
    ))
    return true
  end
  if quarantine.windowClosed then
    return false
  end

  quarantine.windowClosed = true
  quarantine.windowClosePromptSequence = sequence
  quarantine.graceToken = quarantine.graceToken + 1
  local expectedId = quarantine.quarantineId
  local expectedToken = quarantine.graceToken
  local timerId = false
  if tempTimer then
    timerId = tempTimer(PACK_QUARANTINE_GRACE_SECONDS, function()
      local active = activePackQuarantine()
      if not active
          or active.quarantineId ~= expectedId
          or active.graceToken ~= expectedToken
          or active.graceTimer ~= timerId then
        return
      end
      active.graceTimer = false
      active.graceExpired = true
      active.graceInventoryGeneration = inventoryState().generation
      active.requiredInventoryGeneration = math.max(
        active.requiredInventoryGeneration,
        active.graceInventoryGeneration + 1
      )
      trace(string.format(
        "gold pack quarantine grace expired: generation=%s | inventory=%s",
        tostring(active.oldGeneration),
        tostring(active.graceInventoryGeneration)
      ))
    end)
  end
  quarantine.graceTimer = timerId or false
  trace(string.format(
    "gold pack quarantine window closed: generation=%s | prompt=%s | grace=%s",
    tostring(quarantine.oldGeneration),
    tostring(sequence),
    tostring(quarantine.graceToken)
  ))
  return true
end

function boop.runtime.observeInventorySnapshot(items)
  local inventory = inventoryState()
  inventory.generation = inventory.generation + 1
  inventory.completeItems = deepCopy(
    type(items) == "table" and items or {}
  )
  return {
    generation = inventory.generation,
    items = deepCopy(inventory.completeItems),
  }
end

function boop.runtime.observePackQuarantineInventory(
  inventoryGeneration,
  hasSovereigns
)
  local quarantine = activePackQuarantine()
  local generation = tonumber(inventoryGeneration) or 0
  if not quarantine
      or not quarantine.windowClosed
      or not quarantine.graceExpired
      or generation <= quarantine.releaseInventoryGeneration
      or generation < quarantine.requiredInventoryGeneration then
    return false
  end
  quarantine.qualifyingInventoryGeneration = generation
  quarantine.inventoryHasSovereigns = hasSovereigns == true
  if not quarantine.inventoryHasSovereigns then
    quarantine.eligible = false
    quarantine.resolved = true
    quarantine.resolutionReason = "inventory_without_sovereigns"
    trace(string.format(
      "gold pack quarantine cleared by inventory: generation=%s | inventory=%s | sovereigns=no",
      tostring(quarantine.oldGeneration),
      tostring(generation)
    ))
    return true
  end
  quarantine.eligible = true
  trace(string.format(
    "gold pack quarantine eligible: generation=%s | inventory=%s | sovereigns=yes",
    tostring(quarantine.oldGeneration),
    tostring(generation)
  ))
  return true
end

function boop.runtime.notePackQuarantineActivity(kind, outboundSequence)
  local quarantine = activePackQuarantine()
  if not quarantine then
    return false
  end
  local activity = tostring(kind or "old pack activity")
  local sequence = tonumber(outboundSequence) or false
  trace(string.format(
    "gold pack quarantine old activity: owner=%s | generation=%s | dispatch=%s | activity=%s | outbound=%s | eligible=%s",
    quarantine.oldOwner,
    tostring(quarantine.oldGeneration),
    tostring(quarantine.oldDispatchId),
    activity,
    tostring(sequence or "none"),
    tostring(quarantine.eligible)
  ))
  if not quarantine.eligible then
    return false
  end
  quarantine.lateActivityCount = quarantine.lateActivityCount + 1
  quarantine.lastLateActivity = activity
  quarantine.lastLateOutboundSequence = sequence
  local inventory = inventoryState()
  quarantine.eligible = false
  quarantine.inventoryHasSovereigns = false
  quarantine.requiredInventoryGeneration = math.max(
    quarantine.requiredInventoryGeneration,
    inventory.generation + 1
  )
  return true
end

function boop.runtime.consumePackQuarantine(
  oldGeneration,
  inventoryGeneration,
  reason
)
  local quarantine = activePackQuarantine()
  if not quarantine
      or not quarantine.eligible
      or tonumber(oldGeneration) ~= quarantine.oldGeneration
      or tonumber(inventoryGeneration)
        ~= quarantine.qualifyingInventoryGeneration
      or inventoryState().generation
        ~= quarantine.qualifyingInventoryGeneration then
    return false
  end
  quarantine.eligible = false
  quarantine.consumed = true
  quarantine.resolved = true
  quarantine.resolutionReason = tostring(reason or "consumed")
  trace(string.format(
    "gold pack quarantine consumed: generation=%s | inventory=%s | reason=%s",
    tostring(quarantine.oldGeneration),
    tostring(quarantine.qualifyingInventoryGeneration),
    quarantine.resolutionReason
  ))
  return deepCopy(quarantine)
end

local function standardQueueState()
  local queue = boop.runtime.ensureState().queue
  queue.outboundSequence = tonumber(queue.outboundSequence) or 0
  queue.outboundExpectations =
    type(queue.outboundExpectations) == "table"
      and queue.outboundExpectations
      or {}
  queue.outboundObserved = type(queue.outboundObserved) == "table"
      and queue.outboundObserved
    or {}
  queue.outboundDispatchGeneration =
    tonumber(queue.outboundDispatchGeneration) or 0
  queue.outboundDispatches = type(queue.outboundDispatches) == "table"
      and queue.outboundDispatches
    or {}
  queue.standardGeneration = tonumber(queue.standardGeneration) or 0
  queue.standardDispatchId = tonumber(queue.standardDispatchId) or 0
  queue.standardOperation = type(queue.standardOperation) == "table"
      and queue.standardOperation
    or false
  queue.lastStandardTerminal =
    type(queue.lastStandardTerminal) == "table"
      and queue.lastStandardTerminal
      or false
  queue.standardRecovery = type(queue.standardRecovery) == "table"
      and queue.standardRecovery
    or false
  return queue
end

local function activeStandard()
  local operation = standardQueueState().standardOperation
  if type(operation) ~= "table" or operation.terminal then
    return false
  end
  return operation
end

local function standardClock()
  if getEpoch then
    return tonumber(getEpoch()) or os.clock()
  end
  return os.clock()
end

local function sameStandardIdentity(operation, identity)
  return type(operation) == "table"
    and type(identity) == "table"
    and tostring(operation.owner or "") == tostring(identity.owner or "")
    and tonumber(operation.generation) == tonumber(identity.generation)
    and tostring(operation.dispatchId or "")
      == tostring(identity.dispatchId or "")
end

local function trimOutboundHistory(entries, limit)
  while #entries > limit do
    table.remove(entries, 1)
  end
end

function boop.runtime.standardPending()
  return activeStandard() and true or false
end

function boop.runtime.standardMutationBarrier()
  local operation = activeStandard()
  return type(operation) == "table"
    and operation.mode == "queued"
    and type(operation.baseline) == "table"
end

function boop.runtime.standardRecoveryPending()
  local recovery = standardQueueState().standardRecovery
  return type(recovery) == "table" and not recovery.retried
end

function boop.runtime.standardSnapshot()
  local operation = standardQueueState().standardOperation
  return type(operation) == "table" and deepCopy(operation) or false
end

function boop.runtime.lastStandardTerminalSnapshot()
  local terminal = standardQueueState().lastStandardTerminal
  return type(terminal) == "table" and deepCopy(terminal) or false
end

function boop.runtime.outboundSnapshot()
  local queue = standardQueueState()
  return {
    sequence = queue.outboundSequence,
    expectations = deepCopy(queue.outboundExpectations),
    observed = deepCopy(queue.outboundObserved),
    dispatches = deepCopy(queue.outboundDispatches),
  }
end

function boop.runtime.newOutboundRegistration(kind)
  local queue = standardQueueState()
  queue.outboundDispatchGeneration =
    queue.outboundDispatchGeneration + 1
  local generation = queue.outboundDispatchGeneration
  local semanticKind = tostring(kind or "dispatch")
  return {
    owner = semanticKind .. ":" .. tostring(generation),
    generation = generation,
    dispatchId = semanticKind .. ":" .. tostring(generation),
    kind = semanticKind,
  }
end

function boop.runtime.prepareLeapCausality(generation)
  local state = boop.runtime.ensureState()
  local operation = state.diag.operation
  local expectedGeneration = tonumber(generation)
  if type(operation) ~= "table"
      or operation.terminal
      or operation.name ~= "leap"
      or operation.completionMode ~= "room_change"
      or operation.generation ~= expectedGeneration then
    return false
  end

  local queue = standardQueueState()
  local observation = boop.room.observationIdentitySnapshot()
  local owner = tostring(operation.blockerOwner or "")
  local command = tostring(operation.command or "")
  local registration = {
    owner = owner,
    generation = expectedGeneration,
    dispatchId = owner,
    kind = "leap",
  }
  operation.causal = {
    owner = registration.owner,
    generation = registration.generation,
    dispatchId = registration.dispatchId,
    kind = registration.kind,
    command = command,
    clearCommand = "clearqueue all",
    nativeCommand = "queue addclearfull freestand " .. command,
    roomId = tostring(operation.originRoomId or ""),
    roomGeneration = tonumber(observation.generation) or 0,
    registeredAfterSequence = queue.outboundSequence,
    timeoutToken = operation.timeoutTimer,
    observedWireCommands = {},
    baseline = false,
    windowOpen = false,
    contaminatedAt = false,
    contaminatedCommand = "",
    ambiguityTraced = false,
    terminal = false,
    terminalReason = nil,
  }
  trace(string.format(
    "leap causal registered: owner=%s | generation=%s | room=%s | roomGeneration=%s | outbound=%s | timeout=%s",
    owner,
    tostring(expectedGeneration or ""),
    tostring(operation.causal.roomId),
    tostring(operation.causal.roomGeneration),
    tostring(operation.causal.registeredAfterSequence),
    tostring(operation.causal.timeoutToken or "")
  ))
  return deepCopy(registration)
end

function boop.runtime.standardAliasBinding()
  local queue = standardQueueState()
  return {
    action = tostring(queue.aliasAction or ""),
    dirty = queue.aliasDirty ~= false,
  }
end

function boop.runtime.markStandardAliasDirty()
  local queue = standardQueueState()
  queue.aliasDirty = true
  return true
end

function boop.runtime.recordStandardAliasBinding(action, dirty)
  local queue = standardQueueState()
  queue.aliasAction = tostring(action or "")
  queue.aliasDirty = dirty ~= false
  return boop.runtime.standardAliasBinding()
end

function boop.runtime.beginStandardDispatch(options)
  options = type(options) == "table" and options or {}
  if activeStandard() then
    return false
  end

  local queue = standardQueueState()
  local registration = type(options.outcomeRegistration) == "table"
      and options.outcomeRegistration
    or {}
  queue.standardGeneration = queue.standardGeneration + 1
  queue.standardDispatchId = queue.standardDispatchId + 1
  local generation = tonumber(registration.generation)
    or queue.standardGeneration
  if generation > queue.standardGeneration then
    queue.standardGeneration = generation
  end
  local dispatchId = tostring(
    registration.dispatchId
      or ("standard:" .. tostring(queue.standardDispatchId))
  )
  local owner = tostring(
    registration.owner or ("standard:" .. tostring(generation))
  )
  local mode = tostring(options.mode or "queued")
  local targetId = tostring(options.targetId or "")
  local operation = {
    owner = owner,
    generation = generation,
    dispatchId = dispatchId,
    kind = "standard",
    mode = mode,
    status = "dispatching",
    terminal = false,
    terminalReason = "",
    action = tostring(options.action or ""),
    targetId = targetId,
    sourceAuthority = copySourceAuthority(options.sourceAuthority),
    aliasBinding = tostring(options.aliasBinding or options.action or ""),
    baseline = false,
    expectedWireCommands = {},
    observedWireCommands = {},
    finalOwnedWireSequence = false,
    candidate = nil,
    promptCount = 0,
    firstReadyPrompt = false,
    graceStarted = false,
    graceToken = 0,
    graceTimer = false,
    obstacle = false,
    retryBudget = math.max(0, tonumber(options.retryBudget) or 1),
    quarantined = false,
    targetInvalid = false,
    targetInvalidReason = "",
    contaminatedAt = false,
    contaminatedCommand = "",
    clearSent = false,
    startedAt = standardClock(),
  }
  queue.standardOperation = operation
  queue.standardRecovery = false
  queue.prequeuedStandard = true
  queue.prequeueSourceAuthority =
    copySourceAuthority(operation.sourceAuthority)
  return {
    owner = owner,
    generation = generation,
    dispatchId = dispatchId,
    kind = "standard",
  }
end

function boop.runtime.completeStandardDispatch(identity, options)
  local operation = activeStandard()
  if not sameStandardIdentity(operation, identity) then
    return false
  end
  options = type(options) == "table" and options or {}
  operation.mode = tostring(options.mode or operation.mode or "queued")
  operation.aliasBinding = tostring(
    options.aliasBinding or operation.aliasBinding or operation.action or ""
  )
  if operation.status == "dispatching" then
    operation.status = "queued"
  end
  local queue = standardQueueState()
  queue.prequeuedStandard = true
  queue.prequeueSourceAuthority =
    copySourceAuthority(operation.sourceAuthority)
  return deepCopy(operation)
end

function boop.runtime.abortStandardDispatch(identity, reason)
  local operation = activeStandard()
  if not sameStandardIdentity(operation, identity) then
    return false
  end
  operation.status = "aborted"
  operation.terminal = true
  operation.terminalReason = tostring(reason or "dispatch aborted")
  operation.terminalAt = standardClock()
  local queue = standardQueueState()
  queue.prequeuedStandard = false
  queue.prequeueSourceAuthority = false
  queue.lastStandardTerminal = deepCopy(operation)
  return true
end

function boop.runtime.registerOutboundExpectation(registration, command, role)
  if type(registration) ~= "table" then
    return false
  end
  local wire = tostring(command or "")
  if wire == "" then
    return false
  end
  local queue = standardQueueState()
  local expectation = {
    command = wire,
    owner = tostring(registration.owner or ""),
    generation = tonumber(registration.generation),
    dispatchId = tostring(registration.dispatchId or ""),
    kind = tostring(registration.kind or "standard"),
    role = tostring(role or "wire"),
    registeredAfterSequence = queue.outboundSequence,
  }
  local dispatch = false
  for _, candidate in ipairs(queue.outboundDispatches) do
    if sameStandardIdentity(candidate, expectation) then
      dispatch = candidate
      break
    end
  end
  if not dispatch then
    dispatch = {
      owner = expectation.owner,
      generation = expectation.generation,
      dispatchId = expectation.dispatchId,
      kind = expectation.kind,
      expectedWireCommands = {},
      observedWireCommands = {},
      finalOwnedWireSequence = false,
    }
    queue.outboundDispatches[#queue.outboundDispatches + 1] = dispatch
    trimOutboundHistory(queue.outboundDispatches, 32)
  end
  dispatch.expectedWireCommands[#dispatch.expectedWireCommands + 1] = {
    command = wire,
  }
  queue.outboundExpectations[#queue.outboundExpectations + 1] = expectation
  trimOutboundHistory(
    queue.outboundExpectations,
    OUTBOUND_EXPECTATION_LIMIT
  )
  local operation = activeStandard()
  if operation and sameStandardIdentity(operation, expectation) then
    operation.expectedWireCommands[
      #operation.expectedWireCommands + 1
    ] = { command = wire }
  end
  return deepCopy(expectation)
end

function boop.runtime.observeOutbound(command)
  local wire = tostring(command or "")
  if wire == "" then
    return false
  end
  local queue = standardQueueState()
  queue.outboundSequence = queue.outboundSequence + 1
  local expectation = queue.outboundExpectations[1]
  local owned = type(expectation) == "table"
    and expectation.command == wire
  if owned then
    table.remove(queue.outboundExpectations, 1)
  elseif type(expectation) == "table" then
    queue.outboundExpectations = {}
  end
  local observed = {
    command = wire,
    sequence = queue.outboundSequence,
    owned = owned,
    owner = owned and expectation.owner or "manual",
    generation = owned and expectation.generation or false,
    dispatchId = owned and expectation.dispatchId or "",
    kind = owned and expectation.kind or "manual",
    role = owned and expectation.role or "manual",
  }
  queue.outboundObserved[#queue.outboundObserved + 1] = observed
  trimOutboundHistory(queue.outboundObserved, OUTBOUND_HISTORY_LIMIT)

  if owned then
    for _, dispatch in ipairs(queue.outboundDispatches) do
      if sameStandardIdentity(dispatch, expectation) then
        dispatch.observedWireCommands[
          #dispatch.observedWireCommands + 1
        ] = {
          command = wire,
          sequence = observed.sequence,
        }
        dispatch.finalOwnedWireSequence = observed.sequence
        break
      end
    end
  end

  local operation = activeStandard()
  if operation then
    if owned and sameStandardIdentity(operation, expectation) then
      operation.observedWireCommands[
        #operation.observedWireCommands + 1
      ] = {
        command = wire,
        sequence = observed.sequence,
      }
      operation.finalOwnedWireSequence = observed.sequence
      if expectation.role == "baseline"
          or expectation.role == "final" then
        operation.baseline = {
          command = wire,
          sequence = observed.sequence,
          owner = observed.owner,
          generation = observed.generation,
          dispatchId = observed.dispatchId,
        }
      end
    elseif type(operation.baseline) == "table"
        and observed.sequence > tonumber(operation.baseline.sequence or 0)
        and not operation.contaminatedAt then
      operation.contaminatedAt = observed.sequence
      operation.contaminatedCommand = wire
    end
  end

  local interrupt = boop.runtime.ensureState().diag.operation
  local causal = type(interrupt) == "table" and interrupt.causal or false
  if type(interrupt) == "table"
      and not interrupt.terminal
      and interrupt.name == "leap"
      and type(causal) == "table"
      and not causal.terminal then
    if owned and sameStandardIdentity(causal, expectation) then
      causal.observedWireCommands[#causal.observedWireCommands + 1] = {
        command = wire,
        sequence = observed.sequence,
        role = observed.role,
      }
      if expectation.role == "leap_baseline"
          and wire == causal.nativeCommand then
        causal.baseline = {
          command = wire,
          sequence = observed.sequence,
          owner = observed.owner,
          generation = observed.generation,
          dispatchId = observed.dispatchId,
        }
        causal.windowOpen = true
        trace(string.format(
          "leap causal window open: owner=%s | generation=%s | outbound=%s | room=%s | roomGeneration=%s",
          tostring(causal.owner or ""),
          tostring(causal.generation or ""),
          tostring(observed.sequence),
          tostring(causal.roomId or ""),
          tostring(causal.roomGeneration or "")
        ))
      end
    elseif causal.windowOpen
        and not observed.owned
        and observed.sequence > tonumber(
          type(causal.baseline) == "table"
            and causal.baseline.sequence
            or 0
        )
        and not causal.contaminatedAt then
      causal.contaminatedAt = observed.sequence
      causal.contaminatedCommand = wire
    end
  end
  return deepCopy(observed)
end

local function clearStandardExpectations(identity)
  local queue = standardQueueState()
  local retained = {}
  for _, expectation in ipairs(queue.outboundExpectations) do
    if not sameStandardIdentity(identity, expectation) then
      retained[#retained + 1] = expectation
    end
  end
  queue.outboundExpectations = retained
end

local function terminalizeStandard(operation, status, reason)
  local current = activeStandard()
  if not sameStandardIdentity(current, operation) then
    return false
  end
  if current.graceTimer and killTimer then
    killTimer(current.graceTimer)
  end
  current.graceTimer = false
  current.status = tostring(status or "expired")
  current.terminal = true
  current.terminalReason = tostring(reason or status or "terminal")
  current.terminalAt = standardClock()
  local queue = standardQueueState()
  queue.prequeuedStandard = false
  queue.prequeueSourceAuthority = false
  clearStandardExpectations(current)

  if current.status == "denied"
      and tostring(current.obstacle or "") ~= ""
      and current.obstacle ~= "target_absent" then
    queue.standardRecovery = {
      generation = current.generation,
      obstacle = current.obstacle,
      recovered = false,
      retried = false,
      retryBudget = current.retryBudget,
      operation = deepCopy(current),
    }
  else
    queue.standardRecovery = false
  end
  queue.lastStandardTerminal = deepCopy(current)
  trace(string.format(
    "standard terminal: %s | generation=%s | reason=%s",
    current.status,
    tostring(current.generation),
    current.terminalReason
  ))
  if current.quarantined
      and boop.onStandardLifecycleTerminal then
    boop.onStandardLifecycleTerminal(deepCopy(current))
  end
  return deepCopy(current)
end

function boop.runtime.bufferStandardCandidate(candidate)
  local operation = activeStandard()
  if not operation then
    return false
  end
  candidate = type(candidate) == "table" and candidate or {}
  local kind = tostring(candidate.kind or "")
  if kind ~= "success" and kind ~= "denial" then
    return false
  end
  local queue = standardQueueState()
  operation.candidate = {
    kind = kind,
    obstacle = tostring(candidate.obstacle or ""),
    line = tostring(candidate.line or ""),
    owner = operation.owner,
    generation = operation.generation,
    dispatchId = operation.dispatchId,
    targetId = operation.targetId,
    sourceAuthority = copySourceAuthority(operation.sourceAuthority),
    baselineSequence = type(operation.baseline) == "table"
        and tonumber(operation.baseline.sequence)
      or false,
    outboundSequence = queue.outboundSequence,
    observedAt = standardClock(),
  }
  return true
end

local function standardCandidateDisposition(operation, candidate)
  if type(operation) ~= "table" or type(candidate) ~= "table" then
    return false, "identity missing"
  end
  if tostring(candidate.owner or "") ~= tostring(operation.owner or "") then
    return false, "owner mismatch"
  end
  if tonumber(candidate.generation) ~= tonumber(operation.generation) then
    return false, "generation mismatch"
  end
  if tostring(candidate.dispatchId or "")
      ~= tostring(operation.dispatchId or "") then
    return false, "dispatch mismatch"
  end
  if tostring(candidate.targetId or "")
      ~= tostring(operation.targetId or "") then
    return false, "candidate target mismatch"
  end

  local state = boop.runtime.ensureState()
  if tostring(state.targeting.currentTargetId or "")
      ~= tostring(operation.targetId or "") then
    return false, "current target changed"
  end

  local baseline = operation.baseline
  local baselineSequence = type(baseline) == "table"
      and tonumber(baseline.sequence)
    or nil
  if baselineSequence == nil then
    return false, "baseline missing"
  end
  if tostring(baseline.owner or "") ~= tostring(operation.owner or "")
      or tonumber(baseline.generation) ~= tonumber(operation.generation)
      or tostring(baseline.dispatchId or "")
        ~= tostring(operation.dispatchId or "") then
    return false, "baseline ownership mismatch"
  end
  if tonumber(candidate.baselineSequence) ~= baselineSequence then
    return false, "baseline mismatch"
  end
  local candidateOutboundSequence = tonumber(candidate.outboundSequence)
  if candidateOutboundSequence == nil
      or candidateOutboundSequence < baselineSequence then
    return false, "outbound sequence before baseline"
  end
  if operation.contaminatedAt
      and tonumber(operation.contaminatedAt)
        <= candidateOutboundSequence then
    return false, "outbound contamination"
  end

  if not operation.sourceAuthority then
    return true, "accepted"
  end
  local captured = copySourceAuthority(operation.sourceAuthority)
  if not captured
      or captured.applicationId == nil
      or captured.roomId == ""
      or captured.observationGeneration == nil then
    return false, "captured room authority missing"
  end
  if not sourceAuthorityMatches(candidate.sourceAuthority, captured) then
    return false, "candidate room authority mismatch"
  end

  return boop.room.sourceAuthorityDisposition(captured)
end

local function retryStandard(operation, reason)
  if type(operation) ~= "table"
      or tonumber(operation.retryBudget or 0) <= 0
      or not boop.retryStandardDispatch then
    return false
  end
  local retry = deepCopy(operation)
  retry.retryBudget = 0
  return boop.retryStandardDispatch(retry, reason) == true
end

local function startStandardGrace(operation)
  if operation.graceStarted then
    return false
  end
  operation.firstReadyPrompt = true
  operation.firstReadySequence = operation.promptCount
  operation.graceStarted = true
  operation.graceToken = (tonumber(operation.graceToken) or 0) + 1
  local generation = operation.generation
  local token = operation.graceToken
  if not tempTimer then
    local terminal = terminalizeStandard(
      operation,
      "expired",
      "ready prompt grace unavailable"
    )
    if terminal and not terminal.quarantined then
      retryStandard(terminal, "standard grace unavailable")
    end
    return true
  end
  local timerId = false
  timerId = tempTimer(STANDARD_GRACE_SECONDS, function()
    local current = activeStandard()
    if not current
        or tonumber(current.generation) ~= tonumber(generation)
        or tonumber(current.graceToken) ~= tonumber(token)
        or current.graceTimer ~= timerId then
      return false
    end
    current.graceTimer = false
    local terminal = terminalizeStandard(
      current,
      "expired",
      "ready prompt grace expired"
    )
    if terminal and not terminal.quarantined then
      retryStandard(terminal, "standard grace expired")
    end
    return true
  end)
  operation.graceTimer = timerId
  return true
end

function boop.runtime.reconcileStandardPrompt(ready)
  local operation = activeStandard()
  if operation then
    operation.promptCount = (tonumber(operation.promptCount) or 0) + 1
    local candidate = operation.candidate
    operation.candidate = nil
    local candidateAccepted, candidateDisposition =
      standardCandidateDisposition(operation, candidate)
    if type(candidate) == "table" and candidateAccepted then
      candidate.promptSequence = operation.promptCount
      candidate.promptReady = ready == true
      operation.resultCandidate = deepCopy(candidate)
      operation.resultPrompt = {
        sequence = operation.promptCount,
        ready = ready == true,
      }
      if candidate.kind == "success" then
        return terminalizeStandard(
          operation,
          "executed",
          candidate.line ~= "" and candidate.line or "prompt-confirmed success"
        )
      end
      operation.obstacle = tostring(candidate.obstacle or "denied")
      return terminalizeStandard(
        operation,
        "denied",
        candidate.line ~= "" and candidate.line or operation.obstacle
      )
    end
    if type(candidate) == "table" then
      operation.lastAmbiguousCandidate = deepCopy(candidate)
      operation.lastAmbiguousPrompt = {
        sequence = operation.promptCount,
        ready = ready == true,
      }
      trace(string.format(
        "standard candidate ambiguous: reason=%s | owner=%s | generation=%s | dispatch=%s | kind=%s | line=%s | baseline=%s | outbound=%s | contamination=%s",
        tostring(candidateDisposition or "unknown"),
        tostring(operation.owner or ""),
        tostring(operation.generation),
        tostring(operation.dispatchId or ""),
        tostring(candidate.kind or ""),
        tostring(candidate.line or ""),
        tostring(candidate.baselineSequence or ""),
        tostring(candidate.outboundSequence or ""),
        tostring(operation.contaminatedAt or "")
      ))
    end
    if ready == true then
      startStandardGrace(operation)
    end
    return deepCopy(operation)
  end

  local recovery = standardQueueState().standardRecovery
  if ready == true
      and type(recovery) == "table"
      and recovery.recovered
      and not recovery.retried
      and tonumber(recovery.retryBudget or 0) > 0 then
    recovery.retried = true
    retryStandard(recovery.operation, "matching obstacle recovery")
    return true
  end
  return false
end

function boop.runtime.noteStandardRecovery(obstacle)
  local recovery = standardQueueState().standardRecovery
  local key = tostring(obstacle or "")
  if type(recovery) ~= "table"
      or recovery.retried
      or key == ""
      or tostring(recovery.obstacle or "") ~= key then
    return false
  end
  recovery.recovered = true
  recovery.recoveredAt = standardClock()
  return true
end

function boop.runtime.markStandardTargetInvalid(reason)
  local operation = activeStandard()
  if not operation then
    return false
  end
  operation.status = "target-invalid"
  operation.targetInvalid = true
  operation.quarantined = true
  operation.targetInvalidReason = tostring(reason or "target invalid")
  trace(string.format(
    "standard target quarantined: generation=%s | target=%s | reason=%s",
    tostring(operation.generation),
    tostring(operation.targetId),
    operation.targetInvalidReason
  ))
  return deepCopy(operation)
end

function boop.runtime.revokeStandard(reason)
  local operation = activeStandard()
  if not operation then
    return false
  end
  if not operation.clearSent and send then
    operation.clearSent = true
    boop.runtime.registerOutboundExpectation(
      operation,
      "clearqueue all",
      "revocation"
    )
    send("clearqueue all", false)
    trace(string.format(
      "standard queue collateral cleared: generation=%s | target=%s | reason=%s",
      tostring(operation.generation),
      tostring(operation.targetId),
      tostring(reason or "target revoked")
    ))
  end
  return terminalizeStandard(
    operation,
    "revoked",
    tostring(reason or "target revoked")
  )
end

function boop.runtime.enqueueDiagEvidence(generation)
  local state = boop.runtime.ensureState()
  local staleQueue = state.diag.evidenceQueue or {}
  if #staleQueue > 0 then
    local staleGenerations = {}
    for _, record in ipairs(staleQueue) do
      if type(record) == "table" then
        staleGenerations[#staleGenerations + 1] = tostring(
          record.generation or ""
        )
      end
    end
    trace(string.format(
      "diag evidence superseded: generations=%s | next=%s",
      table.concat(staleGenerations, ","),
      tostring(generation or "")
    ))
  end
  state.diag.evidenceQueue = {}
  local record = {
    generation = tonumber(generation) or 0,
    resultSeen = false,
    terminal = false,
    tombstone = false,
  }
  state.diag.evidenceQueue[#state.diag.evidenceQueue + 1] = record
  return record
end

function boop.runtime.resetVenomConfusionCount(reason)
  local state = boop.runtime.ensureState()
  local previous = tonumber(state.diag.venomConfusionCount) or 0
  state.diag.venomConfusionCount = 0
  if previous > 0 then
    trace(string.format(
      "venom confusion reset: %d -> 0 | reason=%s",
      previous,
      tostring(reason or "reset")
    ))
  end
  return previous
end

local function tombstoneInterruptEvidence(state, generation)
  for _, record in ipairs(state.diag.evidenceQueue or {}) do
    if type(record) == "table"
        and tonumber(record.generation) == tonumber(generation) then
      record.terminal = true
      record.tombstone = true
      return true
    end
  end
  return false
end

local function terminalizeInterrupt(operation, terminalReason, opts)
  opts = type(opts) == "table" and opts or {}
  local state = boop.runtime.ensureState()
  if type(operation) ~= "table" or operation.terminal then
    return false
  end

  local reason = tostring(terminalReason or "")
  local expectedGeneration = tonumber(operation.generation)
  operation.terminal = true
  operation.terminalReason = reason
  local causal = operation.causal
  if type(causal) == "table" then
    causal.windowOpen = false
    causal.terminal = true
    causal.terminalReason = reason
    causal.terminalOutboundSequence = standardQueueState().outboundSequence
    clearStandardExpectations(causal)
  end
  if opts.tombstoneEvidence == true
      or (reason == "timeout"
        and operation.completionMode == "result_then_prompt") then
    tombstoneInterruptEvidence(state, expectedGeneration)
  end

  local timerId = operation.timeoutTimer
  operation.timeoutTimer = nil
  if timerId and killTimer then
    killTimer(timerId)
  end

  boop.locks.clearOperationLock(operation.blockerOwner, reason)

  local name = tostring(operation.name or "interrupt")
  local owner = tostring(operation.blockerOwner or "")
  if state.diag.operation == operation then
    state.diag.operation = false
    state.diag.hold = false
    state.diag.awaitPrompt = false
    state.diag.timeoutTimer = nil
    state.diag.label = ""
  end

  if opts.silent ~= true then
    if reason == "timeout" then
      if boop.util and boop.util.warn then
        boop.util.warn(name .. " timeout; attacks resumed")
      end
    elseif reason == "command_failed" then
      if boop.util and boop.util.warn then
        boop.util.warn(name .. " command failed; attacks resumed")
      end
    elseif boop.util and boop.util.ok then
      boop.util.ok(name .. " complete; attacks resumed")
    end
  end
  trace(string.format(
    "interrupt terminal: %s | generation=%s | name=%s | reason=%s",
    owner,
    tostring(expectedGeneration or ""),
    name,
    reason
  ))
  if opts.suppressFollowup ~= true then
    if name == "diag" and reason == "diagnose_result_prompt" then
      boop.runtime.resetVenomConfusionCount("diagnose complete")
    elseif name ~= "diag"
        and boop.tryVenomConfusionDiag
        and (tonumber(state.diag.venomConfusionCount) or 0) >= 2 then
      boop.tryVenomConfusionDiag("interrupt complete")
    end
  end
  return true
end

function boop.runtime.supersedeInterrupt(operation, incoming)
  local incomingName = type(incoming) == "table"
      and tostring(incoming.name or "interrupt")
    or tostring(incoming or "interrupt")
  return terminalizeInterrupt(
    operation,
    "superseded_by:" .. incomingName,
    {
      silent = true,
      suppressFollowup = true,
      tombstoneEvidence = true,
    }
  )
end

function boop.runtime.cancelActiveInterrupt(reason)
  local state = boop.runtime.ensureState()
  local operation = state.diag.operation
  if type(operation) ~= "table" or operation.terminal then
    return false
  end
  return terminalizeInterrupt(
    operation,
    "superseded_by:" .. tostring(reason or "safety"),
    {
      silent = true,
      suppressFollowup = true,
      tombstoneEvidence = true,
    }
  )
end

function boop.runtime.completeInterrupt(generation, terminalReason)
  local state = boop.runtime.ensureState()
  local operation = state.diag.operation
  local expectedGeneration = tonumber(generation)
  if type(operation) ~= "table"
      or operation.generation ~= expectedGeneration
      or operation.terminal then
    return false
  end
  return terminalizeInterrupt(operation, terminalReason)
end

local FLY_SUCCESS_LINE = "The gauntlets carry you up into the skies."

function boop.runtime.onFlyCommandSucceeded(line, capturedGeneration)
  if tostring(line or "") ~= FLY_SUCCESS_LINE then
    return false
  end

  local state = boop.runtime.ensureState()
  local operation = state.diag.operation
  if type(operation) ~= "table"
      or operation.terminal
      or operation.name ~= "fly" then
    return false
  end
  if capturedGeneration ~= nil
      and tonumber(capturedGeneration) ~= tonumber(operation.generation) then
    return false
  end

  local completed = boop.runtime.completeInterrupt(
    operation.generation,
    "command_succeeded"
  )
  if not completed then
    return false
  end
  if tempTimer then
    tempTimer(0, function()
      if boop and boop.tick then
        boop.tick(nil, nil, "other")
      end
    end)
  elseif boop and boop.tick then
    boop.tick(nil, nil, "other")
  end
  return true
end

local function traceLeapDenialDiagnostic(operation, causal, reason)
  if type(causal) == "table" and causal.ambiguityTraced then
    return false
  end
  if type(causal) == "table" then
    causal.ambiguityTraced = true
  end
  trace(string.format(
    "leap denial ambiguous: reason=%s | active=%s | owner=%s | generation=%s | baseline=%s | outbound=%s | contamination=%s",
    tostring(reason or "unknown"),
    tostring(type(operation) == "table" and operation.name or "none"),
    tostring(type(causal) == "table" and causal.owner or ""),
    tostring(type(causal) == "table" and causal.generation or ""),
    tostring(
      type(causal) == "table"
        and type(causal.baseline) == "table"
        and causal.baseline.sequence
        or ""
    ),
    tostring(standardQueueState().outboundSequence),
    tostring(type(causal) == "table" and causal.contaminatedAt or "")
  ))
  return true
end

function boop.runtime.onLeapCommandDenied(line, capturedGeneration)
  if tostring(line or "") ~= LEAP_DENIAL_LINE then
    return false
  end

  local state = boop.runtime.ensureState()
  local operation = state.diag.operation
  local causal = type(operation) == "table" and operation.causal or false
  if type(operation) ~= "table"
      or operation.terminal
      or operation.name ~= "leap"
      or operation.completionMode ~= "room_change" then
    traceLeapDenialDiagnostic(operation, causal, "no active leap")
    return false
  end

  local expectedGeneration = operation.generation
  if capturedGeneration ~= nil
      and tonumber(capturedGeneration) ~= tonumber(expectedGeneration) then
    traceLeapDenialDiagnostic(operation, causal, "stale generation")
    return false
  end
  if type(causal) ~= "table"
      or causal.terminal
      or tostring(causal.owner or "")
        ~= tostring(operation.blockerOwner or "")
      or tonumber(causal.generation) ~= tonumber(expectedGeneration)
      or tostring(causal.dispatchId or "")
        ~= tostring(operation.blockerOwner or "")
      or tostring(causal.command or "") ~= tostring(operation.command or "")
      or causal.timeoutToken ~= operation.timeoutTimer then
    traceLeapDenialDiagnostic(operation, causal, "identity mismatch")
    return false
  end

  local observation = boop.room.observationIdentitySnapshot()
  local currentRoom = tostring(state.targeting.room or "")
  if currentRoom == "" then
    currentRoom = tostring(
      gmcp
        and gmcp.Room
        and gmcp.Room.Info
        and gmcp.Room.Info.num
        or ""
    )
  end
  if tostring(causal.roomId or "") == ""
      or currentRoom ~= tostring(causal.roomId or "")
      or tostring(observation.roomId or "")
        ~= tostring(causal.roomId or "")
      or tonumber(observation.generation)
        ~= tonumber(causal.roomGeneration) then
    traceLeapDenialDiagnostic(operation, causal, "room authority changed")
    return false
  end

  if not causal.windowOpen
      or type(causal.baseline) ~= "table"
      or tostring(causal.baseline.owner or "") ~= tostring(causal.owner or "")
      or tonumber(causal.baseline.generation)
        ~= tonumber(causal.generation)
      or tostring(causal.baseline.command or "")
        ~= tostring(causal.nativeCommand or "") then
    traceLeapDenialDiagnostic(operation, causal, "window not open")
    return false
  end
  if causal.contaminatedAt
      and tonumber(causal.contaminatedAt)
        > tonumber(causal.baseline.sequence or 0) then
    traceLeapDenialDiagnostic(operation, causal, "unowned outbound")
    return false
  end

  local completed = boop.runtime.completeInterrupt(
    expectedGeneration,
    "command_failed"
  )
  if not completed then
    return false
  end
  if tempTimer then
    tempTimer(0, function()
      if boop and boop.tick then
        boop.tick(nil, nil, "other")
      end
    end)
  elseif boop and boop.tick then
    boop.tick(nil, nil, "other")
  end
  return true
end

function boop.runtime.markOldestDiagEvidenceResult(source)
  local state = boop.runtime.ensureState()
  local head = state.diag.evidenceQueue and state.diag.evidenceQueue[1] or nil
  if type(head) ~= "table" or head.resultSeen then
    return false
  end

  head.resultSeen = true
  local operation = state.diag.operation
  if type(operation) == "table"
      and not operation.terminal
      and operation.name == "diag"
      and operation.completionMode == "result_then_prompt"
      and operation.generation == head.generation then
    operation.resultSeen = true
    state.diag.awaitPrompt = true
  end
  trace(string.format(
    "diag result observed: source=%s | evidenceGeneration=%s | activeGeneration=%s | tombstone=%s",
    tostring(source or "text"),
    tostring(head.generation or ""),
    tostring(type(operation) == "table" and operation.generation or ""),
    tostring(head.tombstone == true)
  ))
  return true
end

function boop.runtime.consumeOldestDiagEvidencePrompt()
  local state = boop.runtime.ensureState()
  local queue = state.diag.evidenceQueue or {}
  local head = queue[1]
  if type(head) ~= "table" or not head.resultSeen then
    return false, false
  end

  table.remove(queue, 1)
  trace(string.format(
    "diag prompt consumed: evidenceGeneration=%s | activeGeneration=%s | tombstone=%s",
    tostring(head.generation or ""),
    tostring(
      type(state.diag.operation) == "table"
        and state.diag.operation.generation
        or ""
    ),
    tostring(head.tombstone == true)
  ))
  if head.terminal or head.tombstone then
    return true, false
  end

  local operation = state.diag.operation
  if type(operation) == "table"
      and not operation.terminal
      and operation.name == "diag"
      and operation.completionMode == "result_then_prompt"
      and operation.generation == head.generation then
    return true, boop.runtime.completeInterrupt(
      head.generation,
      "diagnose_result_prompt"
    )
  end
  return true, false
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
  if type(gold.operation) == "table" and not gold.operation.terminal then
    return string.format(
      "%s:%s",
      tostring(gold.operation.phase or "pending"),
      tostring(gold.operation.generation or "?")
    )
  end
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

function boop.runtime.automationIntentTraceMessage(reason, opts)
  return automationTraceMessage(reason, opts)
end

function boop.runtime.clearAttackIntent(reason, opts)
  opts = opts or {}
  local state = boop.runtime.ensureState()
  local reasonText = tostring(reason or "")
  local pendingStandard = activeStandard()
  local departureInvalidation = pendingStandard
    and (
      reasonText == "target_lost"
      or reasonText == "room_changed"
      or reasonText == "room_partial"
      or reasonText == "missing_room"
      or opts.standardDisposition == "target-invalid"
    )
  state.combat.attacking = false
  state.combat.lastRageDecision = nil
  state.combat.pendingStandard = nil
  state.combat.pendingRage = nil
  state.combat.attackPlan = nil

  killOwnedTimer(state.queue.prequeueTimer)
  state.queue.prequeueTimer = nil

  if departureInvalidation then
    boop.runtime.markStandardTargetInvalid(reasonText)
    if not opts.suppressTrace then
      trace("attack intent quarantined: " .. reasonText)
    end
    return true, "quarantined"
  end

  if pendingStandard then
    boop.runtime.revokeStandard(reasonText ~= "" and reasonText or "attack intent cleared")
  end

  state.queue.prequeuedStandard = false
  state.queue.prequeueSourceAuthority = false
  state.queue.aliasAction = ""
  state.queue.aliasDirty = true

  if not opts.suppressTrace then
    trace("attack intent cleared: " .. tostring(reason or "unspecified"))
  end
  return true, "cleared"
end

function boop.runtime.clearAutomationResidualIntent(reason, opts)
  opts = opts or {}
  local state = boop.runtime.ensureState()
  local includeWalk = opts.includeWalk ~= false
  local includeGold = opts.includeGold ~= false
  local message = opts.traceMessage or automationTraceMessage(reason, opts)

  if includeWalk then
    killOwnedTimer(state.walk.refreshTimer)
    killOwnedTimer(state.walk.emitterTimer)
    state.walk.generation = (tonumber(state.walk.generation) or 0) + 1
    state.walk.active = false
    state.walk.owned = false
    state.walk.roomSettled = false
    state.walk.moveQueued = false
    state.walk.arrivalRoom = ""
    state.walk.roomGeneration = 0
    state.walk.moveIssuedForRoomGeneration = false
    state.walk.reservationId = tonumber(state.walk.reservationId) or 0
    state.walk.refreshTimer = nil
    state.walk.emitterTimer = nil
    state.walk.refreshWarned = false
  end

  if includeGold then
    local operation = state.gold.operation
    if type(operation) == "table" then
      operation.terminal = true
      killOwnedTimer(operation.flushTimer)
      killOwnedTimer(operation.timeoutTimer)
      boop.locks.clearOperationLock(
        operation.blockerOwner,
        tostring(reason or "automation clear")
      )
    end
    killOwnedTimer(state.gold.autoGrabTimer)
    killOwnedTimer(state.gold.pendingTimer)
    state.gold.operation = false
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

function boop.runtime.context(sourceAuthority, options)
  if boop.perf.on then
    boop.perf.count("contexts_built")
  end
  local state = boop.runtime.ensureState()
  local room = currentRoom()
  local authority = copySourceAuthority(sourceAuthority)
  options = type(options) == "table" and options or {}
  local roomOwned = options.roomOwned == true or authority and true or false
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
  local rageAmount = tonumber(state.rage.amount) or 0
  local assistLeader = boop.util and boop.util.trim and boop.util.trim((boop.config and boop.config.assistLeader) or "") or tostring((boop.config and boop.config.assistLeader) or "")

  local operation = boop.locks.operationLockSnapshot()
  return {
    state = state,
    config = boop.config or {},
    gmcp = gmcp,
    roomOwned = roomOwned,
    provisionalCombat = options.provisionalCombat == true,
    sourceAuthority = authority,
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
      standardPending = boop.runtime.standardPending(),
      standard = boop.runtime.standardSnapshot(),
      balanceReadyAt = state.queue.balanceReadyAt,
      equilibriumReadyAt = state.queue.equilibriumReadyAt,
      aliasAction = tostring(state.queue.aliasAction or ""),
      aliasDirty = state.queue.aliasDirty ~= false,
    },
    walk = {
      active = not not state.walk.active,
      owned = not not state.walk.owned,
      roomSettled = not not state.walk.roomSettled,
      moveQueued = not not state.walk.moveQueued,
      arrivalRoom = tostring(state.walk.arrivalRoom or ""),
      generation = tonumber(state.walk.generation) or 0,
      roomGeneration = tonumber(state.walk.roomGeneration) or 0,
      moveIssuedForRoomGeneration =
        not not state.walk.moveIssuedForRoomGeneration,
      reservationId = tonumber(state.walk.reservationId) or 0,
      refreshTimer = state.walk.refreshTimer,
      emitterTimer = state.walk.emitterTimer,
      refreshWarned = not not state.walk.refreshWarned,
    },
    gold = {
      generation = tonumber(state.gold.generation) or 0,
      operation = type(state.gold.operation) == "table"
          and deepCopy(state.gold.operation)
        or false,
      autoGrabPending = not not state.gold.autoGrabPending,
      getPending = not not state.gold.getPending,
      putPending = not not state.gold.putPending,
      packTarget = tostring(state.gold.packTarget or ""),
    },
    diag = {
      hold = not not state.diag.hold,
      awaitPrompt = not not state.diag.awaitPrompt,
      label = tostring(state.diag.label or ""),
      venomConfusionCount =
        tonumber(state.diag.venomConfusionCount) or 0,
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
    readiness = boop.runtime.readinessSnapshot(),
    operation = operation,
    blocker = operation,
  }
end

boop.perf.register("context", boop.runtime, "context")
