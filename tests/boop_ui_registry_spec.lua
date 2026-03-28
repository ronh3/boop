local helper = dofile(os.getenv("TESTS_DIRECTORY") .. "/support/boop_test_helper.lua")

describe("boop ui registries", function()
  before_each(function()
    helper.reset()
  end)

  it("exposes shared config, screen, mode, preset, and help registries", function()
    assert.are.equal("targetingMode", boop.config.schema.aliases.targeting)
    assert.is_function(boop.config.setters.partySize)
    assert.are.equal("combat", boop.ui.screens.configSections[1].key)
    assert.is_function(boop.ui.screens.configActions.combat[1])
    assert.is_not_nil(boop.ui.modes["leader-call"])
    assert.is_not_nil(boop.ui.presets.party)
    assert.is_true(#boop.ui.helpTopics > 0)
  end)

  it("drives mode changes from the shared mode registry", function()
    boop.config.assistLeader = "Leader"

    boop.ui.modeCommand("leader-call")

    assert.is_true(boop.config.assistEnabled)
    assert.is_false(boop.config.autoTargetCall)
    assert.is_true(boop.config.targetCall)
  end)

  it("drives preset application from the shared preset registry", function()
    boop.ui.presetCommand("party")

    assert.are.equal("whitelist", boop.config.targetingMode)
    assert.are.equal(2, boop.config.partySize)
    assert.is_false(boop.config.assistEnabled)
    assert.is_false(boop.config.autoTargetCall)
  end)

  it("drives raw config updates from the shared setter registry", function()
    boop.ui.setConfigValue("partysize", "3")

    assert.are.equal(3, boop.config.partySize)
  end)
end)
