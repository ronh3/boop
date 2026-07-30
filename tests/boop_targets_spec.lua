local helper = dofile(os.getenv("TESTS_DIRECTORY") .. "/support/boop_test_helper.lua")

describe("boop target selection", function()
  local tick_stub
  local save_list_stub

  before_each(function()
    helper.reset()
    helper.setArea("Test Area")
    helper.setDenizens({
      { id = "10", name = "goblin" },
      { id = "11", name = "orc" },
      { id = "12", name = "rat" },
    })
  end)

  after_each(function()
    if tick_stub then
      tick_stub:revert()
      tick_stub = nil
    end
    if save_list_stub then
      save_list_stub:revert()
      save_list_stub = nil
    end
  end)

  it("uses whitelist priority order when enabled", function()
    boop.config.targetingMode = "whitelist"
    boop.config.whitelistPriorityOrder = true
    helper.setWhitelist("Test Area", { "orc", "goblin" })

    assert.are.equal("11", boop.targets.choose())
  end)

  it("keeps the current valid target when retargetOnPriority is off", function()
    boop.config.targetingMode = "whitelist"
    boop.config.whitelistPriorityOrder = true
    boop.config.retargetOnPriority = false
    helper.setWhitelist("Test Area", { "orc", "goblin" })
    helper.setTarget("10", "goblin")

    assert.are.equal("10", boop.targets.choose())
  end)

  it("lets the global blacklist override whitelist eligibility", function()
    boop.config.targetingMode = "whitelist"
    boop.config.whitelistPriorityOrder = true
    helper.setWhitelist("Test Area", { "orc" })
    helper.setGlobalBlacklist({ "orc" })
    helper.setTarget("11", "orc")

    assert.are.equal("", boop.targets.choose())
    assert.is_false(boop.targets.isCurrentTargetEligible())
  end)

  it("lets the global blacklist override manual targeting", function()
    boop.config.targetingMode = "manual"
    helper.setGlobalBlacklist({ "orc" })
    helper.setTarget("11", "orc")

    assert.are.equal("", boop.targets.choose())
    assert.is_false(boop.targets.isCurrentTargetEligible())
  end)

  it("clears a newly globally blacklisted target without stopping walk", function()
    boop.config.enabled = true
    boop.config.targetingMode = "whitelist"
    helper.setWhitelist("Test Area", { "orc", "goblin" })
    helper.setTarget("11", "orc")
    boop.state.walk.active = true
    boop.state.walk.owned = true
    boop.state.walk.generation = 7
    boop.state.combat.attacking = true
    boop.state.combat.pendingStandard = "attack 11"
    boop.state.queue.prequeuedStandard = true
    boop.state.queue.aliasAction = "attack 11"
    boop.state.queue.aliasDirty = false

    local tickCalls = 0
    tick_stub = stub(boop, "tick", function()
      tickCalls = tickCalls + 1
      return false
    end)
    save_list_stub = stub(boop.db, "saveList", function() end)

    assert.is_true(boop.targets.addBlacklist("global", "orc"))

    assert.are.equal("", boop.state.targeting.currentTargetId)
    assert.are.equal("", boop.state.targeting.targetName)
    assert.is_false(boop.state.combat.attacking)
    assert.is_nil(boop.state.combat.pendingStandard)
    assert.is_false(boop.state.queue.prequeuedStandard)
    assert.are.equal("", boop.state.queue.aliasAction)
    assert.is_true(boop.state.queue.aliasDirty)
    assert.is_true(boop.state.walk.active)
    assert.is_true(boop.state.walk.owned)
    assert.are.equal(7, boop.state.walk.generation)
    assert.are.equal(1, tickCalls)
    assert.is_nil(
      boop.runtime.state().combat.blockersByOwner["target:loss"]
    )
  end)

  it("preserves an active pull target across accepted room contents", function()
    boop.config.targetingMode = "auto"
    helper.setTarget("11", "orc")
    boop.state.queue.prequeuedStandard = true
    boop.state.queue.aliasAction = "attack 11"
    boop.state.combat.pullState = {
      active = true,
      terminal = false,
      phase = "away",
    }

    boop.targets.updateRoomItems({}, {
      applicationId = 2,
      roomId = "2",
      observationGeneration = 2,
    })

    assert.are.equal("11", boop.state.targeting.currentTargetId)
    assert.are.equal("orc", boop.state.targeting.targetName)
    assert.is_true(boop.state.queue.prequeuedStandard)
    assert.are.equal("attack 11", boop.state.queue.aliasAction)
  end)
end)
