local helper = dofile(os.getenv("TESTS_DIRECTORY") .. "/support/boop_test_helper.lua")

describe("boop rage modes", function()
  before_each(function()
    helper.reset()
    helper.setTarget("42", "a test denizen", "80%")
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
end)
