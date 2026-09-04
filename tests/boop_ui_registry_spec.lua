local helper = dofile(os.getenv("TESTS_DIRECTORY") .. "/support/boop_test_helper.lua")
local sourceRoot = os.getenv("TESTS_DIRECTORY") .. "/../src/scripts/boop/"

describe("boop ui registries", function()
  local reloadStubs

  local function addReloadStub(value)
    reloadStubs[#reloadStubs + 1] = value
    return value
  end

  before_each(function()
    helper.reset()
    reloadStubs = {}
  end)

  after_each(function()
    for index = #reloadStubs, 1, -1 do
      reloadStubs[index]:revert()
    end
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

  it("attaches current registry data and handlers to stale public tables", function()
    boop.config.schema = { aliases = {} }
    boop.config.setters = {}
    boop.ui.screens.configActions = { combat = {} }

    boop.ui.registerRegistryHandlers()
    boop.registry.attachUiConfigRegistries(boop.config, boop.ui)

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

  it("refreshes generation-sensitive composition through the production reload path", function()
    local stale = function() end
    local staleHelp = { { key = "stale" } }
    boop.registry.config.setters.breakShields = stale
    boop.registry.ui.screens.configActions.combat[13] = stale
    boop.registry.ui.helpTopics = staleHelp
    boop.ui.helpTopics = staleHelp
    boop.bootstrapped = true

    dofile(sourceRoot .. "boop_init.lua")
    dofile(sourceRoot .. "boop_ui_registry.lua")
    dofile(sourceRoot .. "boop_ui.lua")

    local reconcile = addReloadStub(stub(
      boop,
      "reconcileIreSupport",
      function() return true, true end
    ))
    local flush = addReloadStub(stub(
      boop.stats,
      "flushPersistence",
      function() return true end
    ))
    local supports = addReloadStub(stub(boop, "requestCoreSupports"))
    local dbInit = addReloadStub(stub(boop.db, "init"))
    local statsInit = addReloadStub(stub(boop.stats, "init"))
    local eventRegister = addReloadStub(stub(boop.events, "register"))
    local ready = addReloadStub(stub(boop.ui, "status"))

    assert.are.equal(staleHelp, boop.ui.helpTopics)
    dofile(sourceRoot .. "boop_bootstrap.lua")

    assert.stub(flush).was_called_with("package reload")
    assert.stub(supports).was_not_called()
    assert.stub(dbInit).was_not_called()
    assert.stub(statsInit).was_not_called()
    assert.stub(eventRegister).was_not_called()
    assert.stub(ready).was_not_called()
    assert.are_not.equal(stale, boop.config.setters.breakShields)
    assert.are_not.equal(
      stale,
      boop.ui.screens.configActions.combat[13]
    )
    assert.are.equal(boop.registry.config.setters, boop.config.setters)
    assert.are.equal(boop.registry.ui.helpTopics, boop.ui.helpTopics)
    assert.are.equal(
      boop.registry.ui.screens.configActions,
      boop.ui.screens.configActions
    )
    local foundCombat = false
    for _, topic in ipairs(boop.ui.helpTopics) do
      if topic.key == "combat" then
        foundCombat = true
        break
      end
    end
    assert.is_true(foundCombat)

    boop.triggers.setEnabled(true)
    assert.stub(reconcile).was_called_with("enable")
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
