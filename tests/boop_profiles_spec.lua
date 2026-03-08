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
end)
