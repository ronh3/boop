local helper = dofile(os.getenv("TESTS_DIRECTORY") .. "/support/boop_test_helper.lua")

describe("boop Runtime and Targets lifecycle orchestration", function()
  local saved

  local function seedTargetState()
    local state = boop.runtime.state()
    state.targeting.currentTargetId = "42"
    state.targeting.targetName = "a lifecycle target"
    state.targeting.targetShield = { attempted = true, timer = false }
    state.targeting.calledTargetId = "42"
    state.targeting.calledTargetRoom = "101"
    state.targeting.calledTargetBy = "Ada"
    state.targeting.calledTargetAt = 123
    state.targeting.gameTargetSync.generation = 7
    state.targeting.gameTargetSync.desiredId = "42"
    state.targeting.gameTargetSync.confirmedId = ""
    state.targeting.gameTargetSync.pending = true
    state.targeting.gameTargetSync.attempts = 2
    state.targeting.gameTargetSync.suppressed = 1
    state.combat.attacking = true
    state.combat.lastRageDecision = { ability = "Harry" }
    state.combat.pendingStandard = { legacy = true }
    state.combat.pendingRage = { ability = "Harry" }
    state.combat.attackPlan = { standard = "jab 42" }
    state.queue.prequeuedStandard = true
    state.queue.prequeueSourceAuthority = {
      applicationId = 1,
      roomId = "1",
      observationGeneration = 1,
    }
    state.queue.aliasAction = "jab 42"
    state.queue.aliasDirty = false
    return state
  end

  before_each(function()
    helper.reset()
    saved = {
      resolvePackQuarantine = boop.runtime.resolvePackQuarantine,
      beginConnectionLifecycle = boop.runtime.beginConnectionLifecycle,
      resetGameTargetSync = boop.targets.resetGameTargetSync,
      resetConnectionMovementIntent = boop.room.resetConnectionMovementIntent,
      traceLog = boop.trace.log,
    }
  end)

  after_each(function()
    boop.runtime.resolvePackQuarantine = saved.resolvePackQuarantine
    boop.runtime.beginConnectionLifecycle = saved.beginConnectionLifecycle
    boop.targets.resetGameTargetSync = saved.resetGameTargetSync
    boop.room.resetConnectionMovementIntent = saved.resetConnectionMovementIntent
    boop.trace.log = saved.traceLog
  end)

  it("runs reconnect ownership in the preserved observable order", function()
    local state = boop.runtime.state()
    local lifecycleGeneration = state.lifecycle.connectionGeneration
    local syncGeneration = state.targeting.gameTargetSync.generation
    local observationGeneration = boop.room.roomObservationSnapshot().generation
    state.lifecycle.promptSeen = true
    state.lifecycle.ireSeen = true
    state.lifecycle.ready = true
    state.lifecycle.lastRetryAt = 12
    state.lifecycle.lastWarningAt = 13
    state.lifecycle.lastWarningCode = "old"
    state.targeting.gameTargetSync.desiredId = "42"
    state.targeting.gameTargetSync.confirmedId = "42"
    state.targeting.gameTargetSync.pending = true
    state.targeting.gameTargetSync.attempts = 2
    state.targeting.gameTargetSync.suppressed = 1
    state.targeting.movementIntent.generation = 9
    state.targeting.movementIntent.active = true
    state.targeting.movementIntent.direction = "north"
    state.targeting.movementIntent.originRoomId = "1"
    state.targeting.movementIntent.originObservationGeneration =
      observationGeneration

    local order = {}
    boop.runtime.resolvePackQuarantine = function(...)
      order[#order + 1] = "pack"
      return saved.resolvePackQuarantine(...)
    end
    boop.targets.resetGameTargetSync = function(...)
      order[#order + 1] = "target-sync"
      return saved.resetGameTargetSync(...)
    end
    boop.room.resetConnectionMovementIntent = function(...)
      order[#order + 1] = "movement"
      return saved.resetConnectionMovementIntent(...)
    end
    boop.runtime.beginConnectionLifecycle = function(...)
      order[#order + 1] = "lifecycle"
      return saved.beginConnectionLifecycle(...)
    end

    local lifecycle = boop.events.beginConnectionLifecycle("focused reconnect")

    assert.are.same({ "pack", "target-sync", "movement", "lifecycle" }, order)
    assert.are.equal(lifecycleGeneration + 1, lifecycle.connectionGeneration)
    assert.is_false(lifecycle.promptSeen)
    assert.is_false(lifecycle.ireSeen)
    assert.is_false(lifecycle.ready)
    assert.is_nil(lifecycle.lastRetryAt)
    assert.is_nil(lifecycle.lastWarningAt)
    assert.are.equal("", lifecycle.lastWarningCode)

    local sync = state.targeting.gameTargetSync
    assert.are.equal(syncGeneration + 1, sync.generation)
    assert.are.equal("", sync.desiredId)
    assert.are.equal("", sync.confirmedId)
    assert.is_false(sync.pending)
    assert.are.equal(0, sync.attempts)
    assert.are.equal(0, sync.suppressed)

    local movement = boop.room.movementIntentSnapshot()
    assert.are.equal(0, movement.generation)
    assert.is_false(movement.active)
    assert.are.equal("", movement.direction)
    assert.are.equal("", movement.originRoomId)
    assert.are.equal(
      observationGeneration,
      boop.room.roomObservationSnapshot().generation
    )
  end)

  it("retains target, shield, and target sync when clearTarget is false", function()
    local state = seedTargetState()
    local shield = state.targeting.targetShield
    local syncGeneration = state.targeting.gameTargetSync.generation
    local traces = {}
    boop.trace.log = function(message)
      traces[#traces + 1] = message
    end

    local cleared, disposition = boop.targets.clearAttackIntent(
      "manual clear",
      { clearTarget = false }
    )

    assert.is_true(cleared)
    assert.are.equal("cleared", disposition)
    assert.are.equal("42", state.targeting.currentTargetId)
    assert.are.equal("a lifecycle target", state.targeting.targetName)
    assert.are.equal(shield, state.targeting.targetShield)
    assert.are.equal(syncGeneration, state.targeting.gameTargetSync.generation)
    assert.are.equal("42", state.targeting.gameTargetSync.desiredId)
    assert.are.equal("", state.targeting.calledTargetId)
    assert.are.equal("", state.targeting.calledTargetRoom)
    assert.are.equal("", state.targeting.calledTargetBy)
    assert.is_nil(state.targeting.calledTargetAt)
    assert.is_false(state.combat.attacking)
    assert.is_nil(state.combat.lastRageDecision)
    assert.is_nil(state.combat.pendingStandard)
    assert.is_nil(state.combat.pendingRage)
    assert.is_nil(state.combat.attackPlan)
    assert.is_false(state.queue.prequeuedStandard)
    assert.are.equal("", state.queue.aliasAction)
    assert.are.same({ "attack intent cleared: manual clear" }, traces)
  end)

  it("clears target, shield, and sync together when clearTarget is true", function()
    local state = seedTargetState()
    local syncGeneration = state.targeting.gameTargetSync.generation
    local traces = {}
    boop.trace.log = function(message)
      traces[#traces + 1] = message
    end

    local cleared, disposition = boop.targets.clearAttackIntent(
      "explicit target clear",
      { clearTarget = true }
    )

    assert.is_true(cleared)
    assert.are.equal("cleared", disposition)
    assert.are.equal("", state.targeting.currentTargetId)
    assert.are.equal("", state.targeting.targetName)
    assert.is_false(state.targeting.targetShield)
    assert.are.equal(syncGeneration + 1, state.targeting.gameTargetSync.generation)
    assert.are.equal("", state.targeting.gameTargetSync.desiredId)
    assert.are.equal(
      "attack intent cleared: explicit target clear",
      traces[#traces]
    )
    assert.is_truthy(table.concat(traces, "\n"):find(
      "shield cleared: explicit target clear",
      1,
      true
    ))
  end)

  it("preserves target-lost Standard quarantine before target-domain clearing", function()
    local state = seedTargetState()
    local identity = boop.runtime.beginStandardDispatch({
      action = "jab 42",
      targetId = "42",
      sourceAuthority = boop.room.currentRoomSourceAuthority(),
    })
    assert.is_table(identity)
    assert.is_table(boop.runtime.completeStandardDispatch(identity, {
      mode = "queued",
    }))
    local shield = state.targeting.targetShield
    local syncGeneration = state.targeting.gameTargetSync.generation
    local traces = {}
    boop.trace.log = function(message)
      traces[#traces + 1] = message
    end

    local cleared, disposition = boop.targets.clearAttackIntent(
      "target_lost",
      { clearTarget = true }
    )

    assert.is_true(cleared)
    assert.are.equal("quarantined", disposition)
    local standard = boop.runtime.standardSnapshot()
    assert.are.equal("target-invalid", standard.status)
    assert.is_true(standard.targetInvalid)
    assert.is_true(standard.quarantined)
    assert.are.equal("target_lost", standard.targetInvalidReason)
    assert.are.equal("42", state.targeting.currentTargetId)
    assert.are.equal(shield, state.targeting.targetShield)
    assert.are.equal(syncGeneration, state.targeting.gameTargetSync.generation)
    assert.are.equal("attack intent quarantined: target_lost", traces[#traces])
  end)

  it("revokes a non-departure Standard through the Targets orchestration API", function()
    local state = seedTargetState()
    local identity = boop.runtime.beginStandardDispatch({
      action = "jab 42",
      targetId = "42",
      sourceAuthority = boop.room.currentRoomSourceAuthority(),
    })
    assert.is_table(identity)
    assert.is_table(boop.runtime.completeStandardDispatch(identity, {
      mode = "queued",
    }))

    local cleared, disposition = boop.targets.clearAttackIntent(
      "manual replacement",
      { clearTarget = false }
    )

    assert.is_true(cleared)
    assert.are.equal("cleared", disposition)
    assert.is_false(boop.runtime.standardPending())
    local terminal = boop.runtime.lastStandardTerminalSnapshot()
    assert.are.equal("revoked", terminal.status)
    assert.are.equal("manual replacement", terminal.terminalReason)
    assert.are.equal("42", state.targeting.currentTargetId)
    assert.is_table(state.targeting.targetShield)
  end)

  it("uses target-lost as an implicit target clear when no Standard is active", function()
    local state = seedTargetState()
    local syncGeneration = state.targeting.gameTargetSync.generation

    local cleared, disposition = boop.targets.clearAttackIntent("target_lost")

    assert.is_true(cleared)
    assert.are.equal("cleared", disposition)
    assert.are.equal("", state.targeting.currentTargetId)
    assert.are.equal("", state.targeting.targetName)
    assert.is_false(state.targeting.targetShield)
    assert.are.equal(syncGeneration + 1, state.targeting.gameTargetSync.generation)
  end)
end)
