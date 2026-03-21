local helper = dofile(os.getenv("TESTS_DIRECTORY") .. "/support/boop_test_helper.lua")

describe("boop class profile selection", function()
  before_each(function()
    helper.reset()
    helper.setTarget("42", "a test denizen", "80%")
  end)

  it("uses the infernal two-handed profile and prepends focus speed when known", function()
    helper.setClass("Infernal")
    helper.setSpec("Two Handed")
    helper.learnSkills({
      { name = "Slaughter", group = "Weaponmastery" },
      { name = "Focus", group = "Weaponmastery" },
    })

    local actions = boop.attacks.choose()

    assert.are.equal("battlefury focus speed/slaughter 42", actions.standard)
  end)

  it("uses the infernal sword-and-shield shieldbreak standard for shielded targets", function()
    helper.setClass("Infernal")
    helper.setSpec("Sword and Shield")
    helper.learnSkill("Combination", "Weaponmastery")
    boop.state.targetShield = { attempted = false }

    local actions = boop.attacks.choose()

    assert.are.equal("combination 42 raze smash", actions.standard)
    assert.is_true(actions.standardShieldbreak)
  end)

  it("uses the runewarden dual blunt standard for the matching spec", function()
    helper.setClass("Runewarden")
    helper.setSpec("Dual Blunt")
    helper.learnSkill("Doublewhirl", "Weaponmastery")

    local actions = boop.attacks.choose()

    assert.are.equal("doublewhirl 42", actions.standard)
  end)

  it("prepends wield scythe for depthswalker damage when no scythe is tracked", function()
    helper.setClass("Depthswalker")
    helper.learnSkill("Reap", "Shadowmancy")

    local actions = boop.attacks.choose()

    assert.are.equal("wield scythe/shadow reap 42", actions.standard)
  end)

  it("does not prepend wield scythe for depthswalker damage when a scythe is already wielded", function()
    helper.setClass("Depthswalker")
    helper.learnSkill("Reap", "Shadowmancy")
    boop.state.wieldedRight = { id = "11", name = "a practice scythe", attrib = "L", icon = "weapon" }

    local actions = boop.attacks.choose()

    assert.are.equal("shadow reap 42", actions.standard)
  end)

  it("prepends wield dagger for depthswalker shieldbreak when no dagger is tracked", function()
    helper.setClass("Depthswalker")
    helper.learnSkill("Strike", "Shadowmancy")
    boop.state.targetShield = { attempted = false }
    boop.state.wieldedLeft = { id = "12", name = "a tower shield", attrib = "l", icon = "armour" }
    boop.state.wieldedRight = { id = "13", name = "a practice scythe", attrib = "L", icon = "weapon" }

    local actions = boop.attacks.choose()

    assert.are.equal("wield dagger/shadow strike 42", actions.standard)
    assert.is_true(actions.standardShieldbreak)
  end)

  it("prefers deteriorate for depthswalker when the target matches its affliction bucket", function()
    helper.setClass("Depthswalker")
    helper.learnSkill("Deteriorate", "Aeonics")
    helper.learnSkill("Reap", "Shadowmancy")
    helper.addTargetAfflictions({ "charm" })

    local actions = boop.attacks.choose()

    assert.are.equal("chrono deteriorate 42", actions.standard)
  end)

  it("prefers degenerate for depthswalker when the target matches its affliction bucket", function()
    helper.setClass("Depthswalker")
    helper.learnSkill("Degenerate", "Aeonics")
    helper.learnSkill("Reap", "Shadowmancy")
    helper.addTargetAfflictions({ "weakness" })

    local actions = boop.attacks.choose()

    assert.are.equal("chrono degenerate 42", actions.standard)
  end)
end)
