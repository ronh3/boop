local helper = dofile(os.getenv("TESTS_DIRECTORY") .. "/support/boop_test_helper.lua")

describe("boop target selection", function()
  before_each(function()
    helper.reset()
    helper.setArea("Test Area")
    helper.setDenizens({
      { id = "10", name = "goblin" },
      { id = "11", name = "orc" },
      { id = "12", name = "rat" },
    })
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
end)
