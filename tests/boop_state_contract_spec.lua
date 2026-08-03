local helper = dofile(os.getenv("TESTS_DIRECTORY") .. "/support/boop_test_helper.lua")

describe("boop owned state contracts", function()
  before_each(function()
    helper.reset()
  end)

  it("initializes owned runtime state domains", function()
    local state = boop.runtime.state()

    assert.are.equal(boop.state, state)
    for _, domain in ipairs({
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
    }) do
      assert.is_table(state[domain], domain .. " domain")
    end
  end)

  it("keeps current owned-domain defaults stable", function()
    local state = boop.runtime.state()

    assert.is_false(state.combat.pullState)
    assert.is_table(state.combat.temporaryAttackPreferences)
    assert.is_true(state.lifecycle.ready)
    assert.are.equal("", state.targeting.currentTargetId)
    assert.are.equal("", state.targeting.lastRoomDir)
    assert.is_false(state.gold.getPending)
    assert.is_false(state.gold.putPending)
    assert.is_false(state.queue.prequeuedStandard)
    assert.is_false(state.walk.active)
    assert.is_false(state.diag.hold)
    assert.are.equal(0, state.diag.venomConfusionCount)
    assert.is_false(state.inventory.wieldedLeft)
    assert.is_nil(state.gag.pendingAttack)
  end)

  it("maps runtime context from owned domains", function()
    local state = boop.runtime.state()
    local shield = { attempted = false, timer = 88 }
    local left = { id = "left-weapon", name = "a left-hand weapon" }
    local right = { id = "right-weapon", name = "a right-hand weapon" }
    local ready = { harry = true, pummel = false }

    state.targeting.currentTargetId = "42"
    state.targeting.targetName = "a contract denizen"
    state.targeting.targetShield = shield
    state.queue.prequeuedStandard = true
    state.queue.aliasAction = "command hound at 42"
    state.gold.getPending = true
    state.gold.putPending = true
    state.gold.packTarget = "pack123"
    state.diag.hold = true
    state.diag.label = "matic"
    state.diag.venomConfusionCount = 1
    state.inventory.wieldedLeft = left
    state.inventory.wieldedRight = right
    state.rage.ready = ready

    local context = boop.runtime.context()

    assert.are.equal("42", context.target.id)
    assert.are.equal("a contract denizen", context.target.name)
    assert.are.equal(shield, context.target.shield)
    assert.is_true(context.queue.prequeuedStandard)
    assert.are.equal("command hound at 42", context.queue.aliasAction)
    assert.is_true(context.gold.getPending)
    assert.is_true(context.gold.putPending)
    assert.are.equal("pack123", context.gold.packTarget)
    assert.is_true(context.diag.hold)
    assert.are.equal("matic", context.diag.label)
    assert.are.equal(1, context.diag.venomConfusionCount)
    assert.are.equal(left, context.inventory.wieldedLeft)
    assert.are.equal(right, context.inventory.wieldedRight)
    assert.are.equal(ready, context.rage.ready)
  end)
end)
