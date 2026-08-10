local helper = dofile(os.getenv("TESTS_DIRECTORY") .. "/support/boop_test_helper.lua")

describe("boop rage modes", function()
  local function loadProfile(name)
    dofile(
      os.getenv("TESTS_DIRECTORY")
        .. "/../src/scripts/boop/attacks/"
        .. name
        .. ".lua"
    )
  end

  before_each(function()
    helper.reset()
    loadProfile("psion")
    loadProfile("sentinel")
    loadProfile("unnamable")
    loadProfile("infernal")
    helper.setTarget("42", "a test denizen", "80%")
  end)

  it("falls back to simple rage for a stale unsupported aff mode", function()
    helper.setClass("Infernal")
    helper.setSpec("Dual Cutting")
    helper.setRage(14)
    helper.learnSkills({
      { name = "Duality", group = "Weaponmastery" },
      { name = "ravage", group = "Attainment" },
    })
    boop.config.attackMode = "aff"

    local actions = boop.attacks.choose()

    assert.are.equal("dsl 42", actions.standard)
    assert.are.equal("ravage 42", actions.rage)
    assert.are.equal("simple", actions.rageDecision.mode)
  end)

  it("falls back to simple damage in combo mode when no provider support exists", function()
    helper.setClass("Occultist")
    helper.setRage(25)
    helper.learnSkills({
      { name = "Lycantha", group = "Domination" },
      { name = "fluctuate", group = "Attainment" },
      { name = "harry", group = "Attainment" },
    })
    boop.config.attackMode = "combo"

    local actions = boop.attacks.choose()

    assert.are.equal("command hound at 42", actions.standard)
    assert.are.equal("harry 42", actions.rage)
  end)

  it("prioritizes an affliction in tempo mode when damage cannot preserve reserve", function()
    helper.setClass("Occultist")
    helper.setRage(29)
    helper.learnSkills({
      { name = "Lycantha", group = "Domination" },
      { name = "stagnate", group = "Attainment" },
      { name = "harry", group = "Attainment" },
    })
    boop.config.attackMode = "tempo"

    local actions = boop.attacks.choose()

    assert.are.equal("command hound at 42", actions.standard)
    assert.are.equal("stagnate 42", actions.rage)
  end)

  it("spends damage in tempo mode when it can keep aff reserve available", function()
    helper.setClass("Occultist")
    helper.setRage(43)
    helper.learnSkills({
      { name = "Lycantha", group = "Domination" },
      { name = "stagnate", group = "Attainment" },
      { name = "harry", group = "Attainment" },
    })
    boop.config.attackMode = "tempo"

    local actions = boop.attacks.choose()

    assert.are.equal("command hound at 42", actions.standard)
    assert.are.equal("harry 42", actions.rage)
  end)

  it("fires the conditional in combo mode when target afflictions already satisfy it", function()
    helper.setClass("Occultist")
    helper.setRage(25)
    helper.learnSkills({
      { name = "Lycantha", group = "Domination" },
      { name = "fluctuate", group = "Attainment" },
    })
    helper.addTargetAfflictions({ "fear", "amnesia" })
    boop.config.attackMode = "combo"

    local actions = boop.attacks.choose()

    assert.are.equal("command hound at 42", actions.standard)
    assert.are.equal("fluctuate 42", actions.rage)
  end)

  it("holds rage in combo mode when a rostered party class can enable the conditional", function()
    helper.setClass("Occultist")
    helper.setRage(25)
    helper.learnSkills({
      { name = "Lycantha", group = "Domination" },
      { name = "fluctuate", group = "Attainment" },
      { name = "harry", group = "Attainment" },
    })
    boop.config.partyRoster = "unnamable"
    boop.config.attackMode = "combo"

    local actions = boop.attacks.choose()

    assert.are.equal("command hound at 42", actions.standard)
    assert.are.equal("", actions.rage)
  end)

  it("uses a party-enabling affliction in combo mode when roster synergy exists", function()
    helper.setClass("Occultist")
    helper.setRage(32)
    helper.learnSkills({
      { name = "Lycantha", group = "Domination" },
      { name = "fluctuate", group = "Attainment" },
      { name = "temper", group = "Attainment" },
      { name = "harry", group = "Attainment" },
    })
    boop.config.partyRoster = "unnamable"
    boop.config.attackMode = "combo"

    local actions = boop.attacks.choose()

    assert.are.equal("command hound at 42", actions.standard)
    assert.are.equal("temper 42", actions.rage)
  end)

  it("lets Unnamable pool for dread and then enables Occultist fluctuate on the next decision", function()
    helper.setClass("Unnamable")
    helper.setRage(23)
    helper.learnSkills({
      { name = "dread", group = "Attainment" },
      { name = "shriek", group = "Attainment" },
    })
    boop.config.partyRoster = "occultist"
    boop.config.attackMode = "combo"

    local primerActions = boop.attacks.choose()

    assert.are.equal("kill 42", primerActions.standard)
    assert.are.equal("", primerActions.rage)

    helper.setRage(24)
    primerActions = boop.attacks.choose()

    assert.are.equal("kill 42", primerActions.standard)
    assert.are.equal("croon dread 42", primerActions.rage)

    helper.addTargetAfflictions({ "fear" })
    helper.setClass("Occultist")
    helper.setRage(25)
    helper.learnSkills({
      { name = "Lycantha", group = "Domination" },
      { name = "fluctuate", group = "Attainment" },
    })
    boop.config.partyRoster = "unnamable"

    local spenderActions = boop.attacks.choose()

    assert.are.equal("command hound at 42", spenderActions.standard)
    assert.are.equal("fluctuate 42", spenderActions.rage)
  end)

  it("lets Occultist pool for temper and then enables Unnamable onslaught on the next decision", function()
    helper.setClass("Occultist")
    helper.setRage(31)
    helper.learnSkills({
      { name = "Lycantha", group = "Domination" },
      { name = "temper", group = "Attainment" },
      { name = "harry", group = "Attainment" },
    })
    boop.config.partyRoster = "unnamable"
    boop.config.attackMode = "combo"

    local primerActions = boop.attacks.choose()

    assert.are.equal("command hound at 42", primerActions.standard)
    assert.are.equal("", primerActions.rage)

    helper.setRage(32)
    primerActions = boop.attacks.choose()

    assert.are.equal("command hound at 42", primerActions.standard)
    assert.are.equal("temper 42", primerActions.rage)

    helper.addTargetAfflictions({ "charm" })
    helper.setClass("Unnamable")
    helper.setRage(25)
    helper.learnSkills({
      { name = "onslaught", group = "Attainment" },
    })
    boop.config.partyRoster = "occultist"

    local spenderActions = boop.attacks.choose()

    assert.are.equal("kill 42", spenderActions.standard)
    assert.are.equal("unnamable onslaught 42", spenderActions.rage)
  end)

  it("suppresses rage actions in none mode", function()
    helper.setClass("Sentinel")
    helper.setRage(36)
    helper.learnSkills({
      { name = "Claw", group = "Metamorphosis" },
      { name = "pester", group = "Attainment" },
      { name = "skewer", group = "Attainment" },
    })
    boop.config.attackMode = "none"

    local actions = boop.attacks.choose()

    assert.are.equal("claw 42", actions.standard)
    assert.are.equal("", actions.rage)
  end)

  it("preserves the configured rage pool after ordinary spending", function()
    helper.setClass("Sentinel")
    helper.setRage(19)
    helper.learnSkills({
      { name = "Claw", group = "Metamorphosis" },
      { name = "pester", group = "Attainment" },
    })
    boop.config.attackMode = "small"
    boop.config.ragePoolThreshold = 20

    local actions = boop.attacks.choose()

    assert.are.equal("claw 42", actions.standard)
    assert.are.equal("", actions.rage)
    assert.are.equal("pool_hold", actions.rageDecision.outcome)

    helper.setRage(20)
    actions = boop.attacks.choose()

    assert.are.equal("", actions.rage)
    assert.are.equal("pool_hold", actions.rageDecision.outcome)

    helper.setRage(33)
    actions = boop.attacks.choose()

    assert.are.equal("", actions.rage)
    assert.are.equal("pool_hold", actions.rageDecision.outcome)

    helper.setRage(34)
    actions = boop.attacks.choose()

    assert.are.equal("pester 42", actions.rage)
    assert.are.equal("small_damage", actions.rageDecision.outcome)
  end)

  it("uses the affliction attack in aff mode", function()
    helper.setClass("Sentinel")
    helper.setRage(32)
    helper.learnSkills({
      { name = "Claw", group = "Metamorphosis" },
      { name = "tame", group = "Attainment" },
    })
    boop.config.attackMode = "aff"

    local actions = boop.attacks.choose()

    assert.are.equal("claw 42", actions.standard)
    assert.are.equal("goad 42", actions.rage)
  end)

  it("uses Devastate as Psion simple high damage", function()
    helper.setClass("Psion")
    helper.setRage(36)
    helper.learnSkills({
      { name = "Charge", group = "Weaving" },
      { name = "barbedblade", group = "Attainment" },
      { name = "devastate", group = "Attainment" },
      { name = "whirlwind", group = "Attainment" },
    })
    boop.config.attackMode = "simple"

    local actions = boop.attacks.choose()

    assert.are.equal("psi transcend shatter/weave charge 42", actions.standard)
    assert.are.equal("psi transcend shatter/psi devastate 42", actions.rage)
  end)

  it("uses Psion Whirlwind in hybrid only when its conditional affliction is present", function()
    helper.setClass("Psion")
    helper.setRage(25)
    helper.learnSkills({
      { name = "Charge", group = "Weaving" },
      { name = "whirlwind", group = "Attainment" },
    })
    helper.addTargetAfflictions({ "inhibit" })
    boop.config.attackMode = "hybrid"

    local actions = boop.attacks.choose()

    assert.are.equal("psi transcend shatter/weave charge 42", actions.standard)
    assert.are.equal("psi transcend shatter/weave whirlwind 42", actions.rage)
  end)

  it("reserves Psion Whirlwind as a pull-capable damage action", function()
    helper.setClass("Psion")
    helper.setRage(25)
    helper.learnSkills({
      { name = "Charge", group = "Weaving" },
      { name = "whirlwind", group = "Attainment" },
    })
    helper.addTargetAfflictions({ "inhibit" })
    boop.config.attackMode = "hybrid"
    boop.config.pullRageReserve = true

    local actions = boop.attacks.choose()

    assert.are.equal("psi transcend shatter/weave charge 42", actions.standard)
    assert.are.equal("", actions.rage)
  end)

  it("uses Psion Regrowth in hybrid to prime Whirlwind when affordable", function()
    helper.setClass("Psion")
    helper.setRage(24)
    helper.learnSkills({
      { name = "Charge", group = "Weaving" },
      { name = "barbedblade", group = "Attainment" },
      { name = "regrowth", group = "Attainment" },
      { name = "whirlwind", group = "Attainment" },
    })
    boop.config.attackMode = "hybrid"

    local actions = boop.attacks.choose()

    assert.are.equal("psi transcend shatter/weave charge 42", actions.standard)
    assert.are.equal("psi transcend shatter/enact regrowth 42", actions.rage)
  end)

  it("does not use Psion Terror as a hybrid party primer", function()
    helper.setClass("Psion")
    helper.setRage(32)
    helper.learnSkills({
      { name = "Charge", group = "Weaving" },
      { name = "regrowth", group = "Attainment" },
      { name = "terror", group = "Attainment" },
      { name = "whirlwind", group = "Attainment" },
    })
    boop.config.partyRoster = "occultist"
    boop.config.attackMode = "hybrid"

    local actions = boop.attacks.choose()

    assert.are.equal("psi transcend shatter/weave charge 42", actions.standard)
    assert.are.equal("psi transcend shatter/enact regrowth 42", actions.rage)
  end)

  it("does not use fear afflictions as hybrid party primers", function()
    helper.setClass("Unnamable")
    helper.setRage(24)
    helper.learnSkills({
      { name = "dread", group = "Attainment" },
      { name = "shriek", group = "Attainment" },
    })
    boop.config.partyRoster = "occultist"
    boop.config.attackMode = "hybrid"

    local actions = boop.attacks.choose()

    assert.are.equal("kill 42", actions.standard)
    assert.are.equal("unnamable shriek 42", actions.rage)
  end)

  it("holds Psion hybrid rage for Regrowth when setting up Whirlwind", function()
    helper.setClass("Psion")
    helper.setRage(14)
    helper.learnSkills({
      { name = "Charge", group = "Weaving" },
      { name = "barbedblade", group = "Attainment" },
      { name = "regrowth", group = "Attainment" },
      { name = "whirlwind", group = "Attainment" },
    })
    boop.config.attackMode = "hybrid"

    local actions = boop.attacks.choose()

    assert.are.equal("psi transcend shatter/weave charge 42", actions.standard)
    assert.are.equal("", actions.rage)
  end)

  it("falls back to Psion simple damage in hybrid when Whirlwind is unavailable", function()
    helper.setClass("Psion")
    helper.setRage(36)
    helper.learnSkills({
      { name = "Charge", group = "Weaving" },
      { name = "barbedblade", group = "Attainment" },
      { name = "devastate", group = "Attainment" },
      { name = "regrowth", group = "Attainment" },
    })
    boop.config.attackMode = "hybrid"

    local actions = boop.attacks.choose()

    assert.are.equal("psi transcend shatter/weave charge 42", actions.standard)
    assert.are.equal("psi transcend shatter/psi devastate 42", actions.rage)
  end)

  it("uses Triumph free rage in hybrid on the highest ready damage attack", function()
    helper.setClass("Psion")
    helper.setRage(0)
    helper.learnSkills({
      { name = "Charge", group = "Weaving" },
      { name = "barbedblade", group = "Attainment" },
      { name = "devastate", group = "Attainment" },
      { name = "regrowth", group = "Attainment" },
      { name = "whirlwind", group = "Attainment" },
    })
    boop.config.attackMode = "hybrid"
    boop.config.ragePoolThreshold = 100
    boop.rage.onTriumphFreeRage()

    local actions = boop.attacks.choose()

    assert.are.equal("psi transcend shatter/weave charge 42", actions.standard)
    assert.are.equal("psi transcend shatter/psi devastate 42", actions.rage)
  end)

  it("uses a Triumph free conditional rage attack only when its condition is present", function()
    helper.setClass("Psion")
    helper.setRage(0)
    helper.learnSkills({
      { name = "Charge", group = "Weaving" },
      { name = "barbedblade", group = "Attainment" },
      { name = "whirlwind", group = "Attainment" },
    })
    helper.addTargetAfflictions({ "inhibit" })
    boop.config.attackMode = "hybrid"
    boop.rage.onTriumphFreeRage()

    local actions = boop.attacks.choose()

    assert.are.equal("psi transcend shatter/weave charge 42", actions.standard)
    assert.are.equal("psi transcend shatter/weave whirlwind 42", actions.rage)
  end)

  it("holds rage for a big hit in big mode instead of spending a small attack", function()
    helper.setClass("Sentinel")
    helper.setRage(14)
    helper.learnSkills({
      { name = "Claw", group = "Metamorphosis" },
      { name = "pester", group = "Attainment" },
      { name = "skewer", group = "Attainment" },
    })
    boop.config.attackMode = "big"

    local actions = boop.attacks.choose()

    assert.are.equal("claw 42", actions.standard)
    assert.are.equal("", actions.rage)
  end)

  it("uses the small damage action in small mode", function()
    helper.setClass("Sentinel")
    helper.setRage(14)
    helper.learnSkills({
      { name = "Claw", group = "Metamorphosis" },
      { name = "pester", group = "Attainment" },
      { name = "skewer", group = "Attainment" },
    })
    boop.config.attackMode = "small"

    local actions = boop.attacks.choose()

    assert.are.equal("claw 42", actions.standard)
    assert.are.equal("pester 42", actions.rage)
  end)

  it("holds rage in small mode when pull reserve is enabled and only the reserve amount is available", function()
    helper.setClass("Sentinel")
    helper.setRage(14)
    helper.learnSkills({
      { name = "Claw", group = "Metamorphosis" },
      { name = "pester", group = "Attainment" },
      { name = "skewer", group = "Attainment" },
    })
    boop.config.attackMode = "small"
    boop.config.pullRageReserve = true

    local actions = boop.attacks.choose()

    assert.are.equal("claw 42", actions.standard)
    assert.are.equal("", actions.rage)
  end)

  it("packages the ragepool alias", function()
    local root = os.getenv("TESTS_DIRECTORY") .. "/.."
    local manifestHandle = assert(io.open(
      root .. "/src/aliases/boop/Combat/aliases.json",
      "r"
    ))
    local manifest = manifestHandle:read("*a")
    manifestHandle:close()
    local scriptHandle = assert(io.open(
      root .. "/src/aliases/boop/Combat/Boop_Ragepool.lua",
      "r"
    ))
    local script = scriptHandle:read("*a")
    scriptHandle:close()

    assert.is_true(manifest:find("Boop Ragepool", 1, true) ~= nil)
    assert.is_true(manifest:find("boop\\\\s+ragepool", 1, true) ~= nil)
    assert.is_true(script:find("boop.ui.ragePoolCommand", 1, true) ~= nil)
  end)
end)
