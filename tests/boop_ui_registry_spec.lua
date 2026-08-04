local helper = dofile(os.getenv("TESTS_DIRECTORY") .. "/support/boop_test_helper.lua")

describe("boop ui registries", function()
  before_each(function()
    helper.reset()
  end)

  it("exposes shared config, screen, mode, preset, and help registries", function()
    assert.are.equal("targetingMode", boop.config.schema.aliases.targeting)
    assert.are.equal(
      "ragePoolThreshold",
      boop.config.schema.aliases.ragepool
    )
    assert.is_function(boop.config.setters.partySize)
    assert.is_function(boop.config.setters.ragePoolThreshold)
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
    boop.ui.setConfigValue("ragepool", "35")

    assert.are.equal(3, boop.config.partySize)
    assert.are.equal(35, boop.config.ragePoolThreshold)
  end)

  it("refreshes stale config registries on package reload", function()
    boop.config.schema = { aliases = {} }
    boop.config.setters = {}
    boop.ui.screens.configActions = { combat = {} }

    boop.registry.attachUiConfigRegistries()

    assert.are.equal("breakShields", boop.config.schema.aliases.breakshields)
    assert.are.equal(
      "ragePoolThreshold",
      boop.config.schema.aliases.ragepool
    )
    assert.is_function(boop.config.setters.breakShields)
    assert.is_function(boop.config.setters.ragePoolThreshold)
    assert.is_function(boop.ui.screens.configActions.combat[13])
    assert.is_function(boop.ui.screens.configActions.combat[18])
  end)

  it("replaces retained shield-mode handlers on package reload", function()
    local stale = function() end
    boop.registry.config.setters.breakShields = stale
    boop.registry.ui.screens.configActions.combat[13] = stale
    boop.registry.ui.helpTopics = { { key = "stale" } }

    dofile(
      os.getenv("TESTS_DIRECTORY")
        .. "/../src/scripts/boop/boop_ui_registry.lua"
    )

    assert.are_not.equal(stale, boop.config.setters.breakShields)
    assert.are_not.equal(
      stale,
      boop.ui.screens.configActions.combat[13]
    )
    local foundCombat = false
    for _, topic in ipairs(boop.ui.helpTopics) do
      if topic.key == "combat" then
        foundCombat = true
        break
      end
    end
    assert.is_true(foundCombat)
  end)

  it("documents bounded replay timeout recovery in gold help", function()
    local loot
    for _, topic in ipairs(boop.ui.helpTopics) do
      if topic.key == "loot" then
        loot = topic
        break
      end
    end
    assert.is_table(loot)
    local notes = table.concat(loot.notes or {}, " ")
    assert.is_truthy(notes:find("replayed pack", 1, true))
    assert.is_truthy(notes:find("releases", 1, true))
    assert.is_truthy(notes:find("later safe gold opportunity", 1, true))
  end)
end)
