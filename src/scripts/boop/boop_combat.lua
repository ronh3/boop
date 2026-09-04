boop.combat = boop.combat or {}

local function copySourceAuthority(authority)
  if type(authority) ~= "table" then
    return false
  end
  return {
    applicationId = tonumber(authority.applicationId),
    roomId = tostring(authority.roomId or ""),
    observationGeneration = tonumber(
      authority.observationGeneration
    ),
  }
end

local function trace(message)
  if boop.trace and boop.trace.log then
    boop.trace.log(message)
  end
end

local function verdict(allowed, code, label, details)
  local result = details or {}
  result.allowed = allowed == true
  result.code = tostring(code or "")
  result.label = tostring(label or "")
  return result
end

local function operationSnapshot(context)
  if context and type(context.operation) == "table" then
    return context.operation
  end
  if context and type(context.blocker) == "table" then
    return context.blocker
  end
  if boop.runtime and boop.runtime.operationLockSnapshot then
    return boop.runtime.operationLockSnapshot()
  end
  return {}
end

local function operationHeld(context)
  local operation = operationSnapshot(context)
  return verdict(
    false,
    operation.code ~= "" and operation.code or "operation_hold",
    operation.label ~= "" and operation.label or "operation hold",
    { held = true, operation = operation }
  )
end

local function readinessFor(context)
  if context and type(context.readiness) == "table" then
    return context.readiness
  end
  if boop.runtime and boop.runtime.readinessSnapshot then
    return boop.runtime.readinessSnapshot()
  end
  return {}
end

local function targetAdjustedContext(context, targetId)
  if type(context) ~= "table" then
    return context
  end
  local wanted = tostring(targetId or "")
  local current = context.target or {}
  if tostring(current.id or "") == wanted then
    return context
  end

  local adjusted = {}
  for key, value in pairs(context) do
    adjusted[key] = value
  end
  local targetName = ""
  for _, denizen in ipairs(context.denizens or {}) do
    if tostring(denizen.id or "") == wanted then
      targetName = tostring(denizen.name or "")
      break
    end
  end
  adjusted.sourceAuthority =
    copySourceAuthority(context.sourceAuthority)
  adjusted.target = {
    id = wanted,
    name = targetName,
    shield = false,
    hpperc = "",
  }
  return adjusted
end

local function evaluatePlan(intent, context, targetId)
  local kind = tostring(intent.kind or "tick")
  local planContext = targetAdjustedContext(context, targetId)
  local plan = intent.plan
  if type(plan) ~= "table" then
    plan = boop.attacks
      and boop.attacks.choose
      and boop.attacks.choose(planContext)
      or { standard = "", rage = "" }
  end

  if kind == "tick" then
    if (not plan.standard or plan.standard == "")
        and (not plan.rage or plan.rage == "") then
      return verdict(false, "no_attack_plan", "no attack available", {
        targetId = targetId,
        plan = plan,
        planContext = planContext,
      })
    end
  else
    if not plan.standard or plan.standard == "" then
      return verdict(false, "no_standard_plan", "no standard attack available", {
        targetId = targetId,
        plan = plan,
        planContext = planContext,
      })
    end
    if kind == "refresh"
        and intent.requireShieldbreak ~= false
        and not plan.standardShieldbreak then
      return verdict(false, "shieldbreak_required", "shieldbreak standard required", {
        targetId = targetId,
        plan = plan,
        planContext = planContext,
      })
    end
  end

  return verdict(true, "allowed", "combat allowed", {
    targetId = targetId,
    plan = plan,
    planContext = planContext,
  })
end

function boop.combat.evaluateGates(intent)
  intent = type(intent) == "table" and intent or {}
  local kind = tostring(intent.kind or "tick")
  local context = intent.context
  local state = context and context.state
    or boop.runtime and boop.runtime.ensureState
      and boop.runtime.ensureState()
    or boop.state
    or {}
  local config = context and context.config or boop.config or {}

  if intent.resumeAtPlan == true then
    return evaluatePlan(
      intent,
      context,
      tostring(intent.targetId or "")
    )
  end

  local readiness = readinessFor(context)
  local lifecycle = readiness.lifecycle or {}
  local standardPending = boop.runtime
    and boop.runtime.standardPending
    and boop.runtime.standardPending()
    or false

  if kind == "tick" then
    if not config.enabled then
      return verdict(false, "disabled", "Boop disabled")
    end
    if lifecycle.ready ~= true then
      return verdict(
        false,
        "gmcp_ire_missing",
        "GMCP IRE awaiting current prompt evidence",
        { readiness = lifecycle }
      )
    end
    if state.diag and state.diag.hold then
      return verdict(false, "diag_hold", "diagnostic interrupt pending")
    end
    if standardPending then
      return verdict(false, "standard_pending", "exact standard lifecycle pending")
    end
    if boop.runtime
        and boop.runtime.standardRecoveryPending
        and boop.runtime.standardRecoveryPending() then
      return verdict(false, "standard_recovery_pending", "exact standard lifecycle pending")
    end
  else
    if lifecycle.ready ~= true then
      return verdict(
        false,
        "gmcp_ire_missing",
        "GMCP IRE awaiting current prompt evidence",
        { readiness = lifecycle }
      )
    end
    local room = readiness.room or {}
    if room.ready ~= true then
      return verdict(
        false,
        tostring(room.code or "room_not_ready"),
        tostring(room.label or "room awaiting current evidence"),
        { readiness = room }
      )
    end
    if not config.enabled then
      return verdict(false, "disabled", "Boop disabled")
    end
    if not config.prequeueEnabled then
      return verdict(false, "prequeue_disabled", "prequeue disabled")
    end
    if standardPending then
      return verdict(false, "standard_pending", "exact standard lifecycle pending")
    end
    for _, system in ipairs({ "queue", "target", "combat", "gold" }) do
      if boop.runtime
          and boop.runtime.operationHolds
          and boop.runtime.operationHolds(system) then
        return operationHeld(context)
      end
    end
    if kind == "refresh"
        and not (state.queue and state.queue.prequeuedStandard) then
      return verdict(false, "not_prequeued", "no prequeued standard")
    end
    if state.diag and state.diag.hold then
      return verdict(false, "diag_hold", "diagnostic interrupt pending")
    end
  end

  if kind == "tick" then
    local goldOperation = state.gold and state.gold.operation
    if type(goldOperation) == "table" and not goldOperation.terminal then
      if context and context.provisionalCombat == true then
        return verdict(false, "gold_operation", "Gold operation active", {
          goldOperation = goldOperation,
        })
      end
      if boop.safety
          and boop.safety.shouldFlee
          and boop.safety.shouldFlee() then
        return verdict(false, "flee", "flee threshold reached", {
          flee = true,
          goldOperation = goldOperation,
        })
      end
      local owner = tostring(goldOperation.blockerOwner or "")
      if boop.runtime.operationHolds("combat", owner)
          or boop.runtime.operationHolds("queue", owner)
          or boop.runtime.operationHolds("gold", owner)
          or boop.runtime.operationHolds("walk", owner) then
        local held = operationHeld(context)
        held.goldOperation = goldOperation
        held.goldHold = true
        return held
      end
      return verdict(false, "gold_operation", "Gold operation active", {
        flushGold = not goldOperation.timeoutTimer,
        goldOperation = goldOperation,
      })
    end
  end

  if kind == "tick" then
    for _, system in ipairs({
      "target", "combat", "queue", "gold", "walk",
    }) do
      if boop.runtime
          and boop.runtime.operationHolds
          and boop.runtime.operationHolds(system) then
        return operationHeld(context)
      end
    end
  end

  if kind == "tick"
      and not (context and context.provisionalCombat == true)
      and boop.maybeFlushPendingGold
      and boop.maybeFlushPendingGold("tick pending age") then
    return verdict(false, "gold_flushed", "pending Gold flushed")
  end
  if state.gold
      and (state.gold.getPending or state.gold.putPending) then
    return verdict(false, "gold_pending", "Gold command pending")
  end

  if kind == "tick" then
    local room = readiness.room or {}
    if room.ready ~= true
        and not (context and context.provisionalCombat == true) then
      return verdict(
        false,
        tostring(room.code or "room_not_ready"),
        tostring(room.label or "room awaiting current evidence"),
        { readiness = room }
      )
    end
  elseif kind == "prequeue" then
    if state.queue and state.queue.prequeuedStandard then
      return verdict(false, "already_prequeued", "standard already prequeued")
    end
    if gmcp and gmcp.Char and gmcp.Char.Vitals
        and gmcp.Char.Vitals.bal == "1"
        and gmcp.Char.Vitals.eq == "1" then
      return verdict(false, "prequeue_not_ready", "balance and equilibrium already ready")
    end
  elseif kind == "refresh" then
    if gmcp and gmcp.Char and gmcp.Char.Vitals
        and gmcp.Char.Vitals.bal == "1"
        and gmcp.Char.Vitals.eq == "1" then
      return verdict(false, "prequeue_not_ready", "balance and equilibrium already ready")
    end
  end

  if kind ~= "refresh"
      and boop.safety
      and boop.safety.shouldFlee
      and boop.safety.shouldFlee() then
    return verdict(false, "flee", "flee threshold reached", {
      flee = kind == "tick",
    })
  end

  local targetId = tostring(intent.targetId or "")
  if targetId == "" then
    targetId = tostring(
      boop.targets
        and boop.targets.choose
        and boop.targets.choose()
        or ""
    )
  end
  if targetId == "" then
    if kind == "tick"
        and context
        and context.provisionalCombat == true then
      return verdict(false, "no_target", "no eligible target")
    end
    local waiting = boop.targets
      and boop.targets.waitingForTargetCall
      and boop.targets.waitingForTargetCall()
      or false
    return verdict(
      false,
      waiting and "waiting_for_target" or "no_target",
      waiting and "waiting for leader target call" or "no eligible target",
      { waitingForTarget = waiting }
    )
  end

  if kind == "refresh"
      and tostring(state.targeting and state.targeting.currentTargetId or "")
        ~= targetId then
    return verdict(false, "target_changed", "prequeue target changed", {
      targetId = targetId,
    })
  end

  if intent.deferPlanning == true then
    return verdict(true, "allowed", "combat allowed", {
      targetId = targetId,
    })
  end
  return evaluatePlan(intent, context, targetId)
end

local function heldEffect(context, detail)
  local operation = operationSnapshot(context)
  return {
    kind = "trace",
    message = string.format(
      "%s held: %s -- %s",
      tostring(detail or "automation"),
      tostring(operation.code or ""),
      tostring(operation.label or "")
    ),
  }
end

local function readinessHeldEffect(detail, readiness)
  local status = readiness or {}
  return {
    kind = "trace",
    message = string.format(
      "%s held: %s -- %s",
      tostring(detail or "automation"),
      tostring(status.code or ""),
      tostring(status.label or "")
    ),
  }
end

function boop.combat.tickStep(context)
  local state = context.state
  local effects = {}
  local authority = copySourceAuthority(context.sourceAuthority)
  local roomOwned = context.roomOwned == true
  local provisionalCombat = context.provisionalCombat == true
  local gate = boop.combat.evaluateGates({
    kind = "tick",
    context = context,
  })

  if not gate.allowed then
    if gate.code == "gmcp_ire_missing" then
      effects[#effects + 1] = readinessHeldEffect("tick", {
        code = gate.code,
        label = gate.label,
      })
    elseif gate.code == "standard_pending"
        or gate.code == "standard_recovery_pending" then
      effects[#effects + 1] = {
        kind = "trace",
        message = "tick held: exact standard lifecycle pending",
      }
    elseif gate.held then
      effects[#effects + 1] = heldEffect(
        context,
        gate.goldHold and "gold" or "tick"
      )
    elseif gate.flushGold then
      effects[#effects + 1] = {
        kind = "flush_gold",
        reason = "tick gold stage",
        roomOwned = roomOwned,
        sourceAuthority = authority,
      }
    elseif gate.readiness then
      effects[#effects + 1] =
        readinessHeldEffect("tick", gate.readiness)
    elseif gate.flee then
      effects[#effects + 1] = { kind = "flee" }
    elseif gate.code == "waiting_for_target" then
      effects[#effects + 1] = {
        kind = "trace",
        message = "tick: waiting for leader target call",
      }
    elseif gate.code == "no_target" then
      if provisionalCombat then
        effects[#effects + 1] = {
          kind = "trace",
          message = "provisional combat: no eligible target",
        }
        return { effects = effects, didAction = false }
      end
      if context.config.useQueueing and state.gold.autoGrabPending then
        effects[#effects + 1] = {
          kind = "flush_gold",
          reason = "tick no target",
          roomOwned = roomOwned,
          sourceAuthority = authority,
        }
      end
      effects[#effects + 1] = {
        kind = "trace",
        message = "tick: no target",
      }
      effects[#effects + 1] = {
        kind = "walk_advance",
        reason = "tick no target",
        roomOwned = roomOwned,
        sourceAuthority = authority,
      }
    elseif gate.code == "no_attack_plan" then
      local targetId = gate.targetId
      local targetNeedsSync = boop.targets
        and boop.targets.needsGameTargetSync
        and boop.targets.needsGameTargetSync(targetId)
      if tostring(state.targeting.currentTargetId or "")
          ~= tostring(targetId)
          or targetNeedsSync then
        effects[#effects + 1] = {
          kind = "target",
          id = tostring(targetId),
          roomOwned = roomOwned,
          sourceAuthority = authority,
        }
      end
    end
    return { effects = effects, didAction = false }
  end

  local targetId = gate.targetId
  local targetNeedsSync = boop.targets
    and boop.targets.needsGameTargetSync
    and boop.targets.needsGameTargetSync(targetId)
  if tostring(state.targeting.currentTargetId or "") ~= tostring(targetId)
      or targetNeedsSync then
    effects[#effects + 1] = {
      kind = "target",
      id = tostring(targetId),
      roomOwned = roomOwned,
      sourceAuthority = authority,
    }
  end

  effects[#effects + 1] = {
    kind = "combat_plan",
    plan = gate.plan,
    context = gate.planContext,
    roomOwned = roomOwned,
    sourceAuthority = authority,
  }
  return { effects = effects, didAction = true }
end

function boop.combat.promptStep(context)
  local state = context.state
  local effects = {}
  local runTick = true

  local evidenceHead = state.diag.evidenceQueue
    and state.diag.evidenceQueue[1]
    or nil
  local operation = state.diag.operation
  if type(evidenceHead) == "table" then
    if evidenceHead.resultSeen then
      local _, completed = boop.runtime.consumeOldestDiagEvidencePrompt()
      runTick = completed
    elseif type(operation) == "table" and not operation.terminal then
      runTick = false
    end
  elseif type(operation) == "table" and not operation.terminal then
    if operation.completionMode == "prompt" then
      runTick = boop.runtime.completeInterrupt(
        operation.generation,
        "prompt_complete"
      )
    else
      runTick = false
    end
  elseif state.diag.hold then
    runTick = false
  end

  effects[#effects + 1] = { kind = "gag_prompt" }
  return {
    effects = effects,
    didAction = false,
    runTick = runTick,
  }
end

function boop.combat.step(event)
  local data = event or {}
  local context = data.context or boop.runtime.context()
  if tostring(data.type or "tick") == "prompt" then
    return boop.combat.promptStep(context)
  end
  return boop.combat.tickStep(context)
end

function boop.combat.canAct()
  if boop.state.combat.limiters.hunting then
    if boop.perf.on then
      boop.perf.count("ticks_suppressed_by_limiter")
    end
    return false
  end
  if gmcp and gmcp.Char and gmcp.Char.Vitals then
    if gmcp.Char.Vitals.bal ~= "1"
        or gmcp.Char.Vitals.eq ~= "1" then
      return false
    end
  end
  boop.state.combat.limiters.hunting = true
  tempTimer(0.4, function()
    boop.state.combat.limiters.hunting = false
  end)
  return true
end

function boop.combat.canUseRage()
  if boop.rage
      and boop.rage.isGlobalCooldownOpen
      and not boop.rage.isGlobalCooldownOpen() then
    return false
  end
  if boop.state.combat.limiters.rage then
    return false
  end
  boop.state.combat.limiters.rage = true
  tempTimer(0.6, function()
    boop.state.combat.limiters.rage = false
  end)
  return true
end

local function attackAuthorityCurrent(authority, boundary)
  if not authority then
    return true
  end
  local valid = boop.runtime
    and boop.runtime.validateRoomSourceAuthority
    and boop.runtime.validateRoomSourceAuthority(authority)
    or false
  if not valid then
    trace(string.format(
      "room combat rejected: %s | application=%s | room=%s | generation=%s",
      tostring(boundary or "combat"),
      tostring(authority.applicationId or ""),
      tostring(authority.roomId or ""),
      tostring(authority.observationGeneration or "")
    ))
  end
  return not not valid
end

function boop.combat.execute(plan, context, sourceAuthority)
  if type(plan) ~= "table" then
    return false
  end

  local activeContext = context
    or boop.runtime and boop.runtime.context
      and boop.runtime.context()
    or nil
  local authority = copySourceAuthority(
    sourceAuthority
      or activeContext and activeContext.sourceAuthority
  )
  local dispatchOptions = {
    roomOwned = authority and true or false,
    sourceAuthority = authority,
  }
  local didAction = false

  if plan.standard and plan.standard ~= "" then
    local prequeued = activeContext
      and activeContext.queue
      and activeContext.queue.prequeuedStandard
      or false
    if not prequeued
        and attackAuthorityCurrent(authority, "standard")
        and boop.combat.canAct() then
      local targetId = activeContext
        and activeContext.target
        and activeContext.target.id
        or ""
      local emitted = boop.wire.executeAction(
        plan.standard,
        targetId,
        nil,
        dispatchOptions
      )
      if emitted then
        if boop.gag and boop.gag.noteStandardIntent then
          boop.gag.noteStandardIntent(plan.standard)
        end
        if plan.standardIsOpener
            and boop.attacks
            and boop.attacks.markOpenerUsed then
          boop.attacks.markOpenerUsed(
            plan.class or "",
            activeContext
              and activeContext.target
              and activeContext.target.id
              or ""
          )
        end
        local standardWasQueued = boop.config
          and boop.config.useQueueing
          or false
        if activeContext
            and activeContext.config
            and activeContext.config.useQueueing ~= nil then
          standardWasQueued = activeContext.config.useQueueing
        end
        if plan.standardShieldbreak
            and not standardWasQueued
            and boop.targets
            and boop.targets.onShieldbreakAttempt then
          boop.targets.onShieldbreakAttempt()
        end
        didAction = true
      else
        boop.state.combat.limiters.hunting = false
      end
    end
  end

  if plan.rage and plan.rage ~= "" then
    local standardOperation = boop.runtime
      and boop.runtime.standardSnapshot
      and boop.runtime.standardSnapshot()
      or false
    local standardPending = boop.runtime
      and boop.runtime.standardPending
      and boop.runtime.standardPending()
      and type(standardOperation) == "table"
      and standardOperation.mode == "queued"
      or false
    if not standardPending
        and attackAuthorityCurrent(authority, "rage")
        and boop.combat.canUseRage() then
      local targetId = activeContext
        and activeContext.target
        and activeContext.target.id
        or boop.state
          and boop.state.targeting
          and boop.state.targeting.currentTargetId
          or ""
      local registration = boop.rage
        and boop.rage.beginDispatch
        and boop.rage.beginDispatch({
          ability = plan.rageAbility,
          logicalAction = plan.rage,
          targetId = targetId,
          sourceAuthority = authority,
        })
        or false
      local emitted = false
      local completed = false
      if registration then
        local rageDispatchOptions = {
          roomOwned = dispatchOptions.roomOwned,
          sourceAuthority = dispatchOptions.sourceAuthority,
          dispatchMode = "direct",
          outcomeRegistration = {
            owner = registration.owner,
            generation = registration.generation,
            dispatchId = registration.dispatchId,
            kind = "rage",
          },
        }
        local ok, result = pcall(function()
          return boop.wire.executeAction(
            plan.rage,
            targetId,
            false,
            rageDispatchOptions
          )
        end)
        emitted = ok and result == true
        if not ok then
          trace("rage dispatch failed: " .. tostring(result))
        end
        if emitted
            and boop.rage
            and boop.rage.completeDispatch then
          completed = boop.rage.completeDispatch(registration)
            and true or false
        end
        if not emitted or not completed then
          if boop.rage and boop.rage.cancelDispatch then
            boop.rage.cancelDispatch(
              registration,
              emitted and "dispatch_incomplete"
                or "dispatch_failed"
            )
          end
          emitted = false
        end
      end
      if emitted and completed then
        if boop.stats and boop.stats.onRageExecuted then
          boop.stats.onRageExecuted(
            plan.rageAbility,
            plan.rageDecision
          )
        end
        if plan.rageAbility
            and plan.rageAbility.desc == "Shieldbreak"
            and boop.targets
            and boop.targets.onShieldbreakAttempt then
          boop.targets.onShieldbreakAttempt()
        end
        if boop.rage and boop.rage.onRageUsed then
          boop.rage.onRageUsed(plan.rageAbility, registration)
        end
        didAction = true
      else
        boop.state.combat.limiters.rage = false
      end
    elseif standardPending then
      trace("rage held: exact standard lifecycle pending")
    end
  end

  return didAction
end

function boop.combat.applyEffects(result, context)
  local state = context and context.state
    or boop.runtime.ensureState()
  local didAction = false

  for _, effect in ipairs(result and result.effects or {}) do
    local sourceAuthority =
      copySourceAuthority(effect.sourceAuthority)
    local roomOwned = effect.roomOwned == true
    local authorized = not roomOwned
      or sourceAuthority
        and boop.runtime.validateRoomSourceAuthority
        and boop.runtime.validateRoomSourceAuthority(sourceAuthority)
    if roomOwned and not authorized then
      trace(string.format(
        "room effect rejected: %s | application=%s | room=%s | generation=%s",
        tostring(effect.kind or ""),
        tostring(sourceAuthority and sourceAuthority.applicationId or ""),
        tostring(sourceAuthority and sourceAuthority.roomId or ""),
        tostring(
          sourceAuthority
            and sourceAuthority.observationGeneration
            or ""
        )
      ))
    elseif effect.kind == "trace" then
      trace(effect.message or "")
    elseif effect.kind == "flush_gold" then
      if boop.flushPendingGold then
        boop.flushPendingGold(
          effect.reason or "runtime",
          sourceAuthority
        )
      end
    elseif effect.kind == "walk_advance" then
      if boop.walk and boop.walk.maybeAdvance then
        boop.walk.maybeAdvance(
          effect.reason or "runtime",
          sourceAuthority
        )
      end
    elseif effect.kind == "flee" then
      if boop.safety and boop.safety.flee then
        boop.safety.flee()
      end
    elseif effect.kind == "target" then
      if boop.targets and boop.targets.setTarget then
        boop.targets.setTarget(effect.id, {
          roomOwned = roomOwned,
          sourceAuthority = sourceAuthority,
        })
      end
    elseif effect.kind == "combat_plan" then
      if boop.combat.execute(
          effect.plan,
          effect.context or context,
          sourceAuthority
        ) then
        didAction = true
      end
    elseif effect.kind == "gag_prompt" then
      if boop.gag and boop.gag.onPrompt then
        boop.gag.onPrompt()
      end
    end
  end

  return didAction
end

function boop.combat.tick(
  sourceAuthority,
  options,
  perfSource
)
  options = type(options) == "table" and options or {}
  local authority = copySourceAuthority(sourceAuthority)
  local context = boop.runtime.context(authority, {
    roomOwned = options.roomOwned == true
      or authority and true or false,
    provisionalCombat = options.provisionalCombat == true,
  })
  local result = boop.combat.step({
    type = "tick",
    context = context,
  })
  boop.state.combat.attacking =
    boop.combat.applyEffects(result, context)
  return boop.state.combat.attacking
end

function boop.combat.prompt(sourceAuthority)
  local authority = copySourceAuthority(sourceAuthority)
  local context = boop.runtime.context(authority, {
    roomOwned = authority and true or false,
  })
  local result = boop.combat.step({
    type = "prompt",
    context = context,
  })
  boop.combat.applyEffects(result, context)
  return result
end

boop.perf.register("applyEffects", boop.combat, "applyEffects")
boop.perf.register("tick", boop.combat, "tick", {
  sourceIndex = 3,
})
