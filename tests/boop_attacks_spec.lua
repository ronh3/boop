local helper = dofile(os.getenv("TESTS_DIRECTORY") .. "/support/boop_test_helper.lua")

describe("boop attack selection", function()
  before_each(function()
    helper.reset()
    helper.setClass("Occultist")
    helper.setTarget("42", "a test denizen", "100%")
    helper.learnSkills({
      { name = "Attend", group = "Occultism" },
      { name = "Lycantha", group = "Domination" },
      { name = "Warp", group = "Occultism" },
      { name = "ruin", group = "Attainment" },
    })
  end)

  it("prefers the full-hp opener when available", function()
    helper.setRage(0)

    local actions = boop.attacks.choose()

    assert.are.equal("attend 42", actions.standard)
    assert.are.equal("", actions.rage)
    assert.is_true(actions.standardIsOpener)
  end)

  it("chooses a rage shieldbreak when the target is shielded", function()
    helper.setTargetHp("80%")
    helper.setRage(17)
    boop.state.targetShield = { gained = os.clock(), attempted = false }

    local actions = boop.attacks.choose()

    assert.are.equal("command hound at 42", actions.standard)
    assert.are.equal("ruin 42", actions.rage)
  end)

  it("honors a preferred standard damage attack when it is available", function()
    helper.setTargetHp("80%")
    local key = boop.attacks.preferenceConfigKey("occultist", "dam", "")
    boop.config[key] = "warp"

    local actions = boop.attacks.choose()

    assert.are.equal("warp 42", actions.standard)
  end)

  it("falls back to the normal standard damage order when the preferred attack is unavailable", function()
    helper.setTargetHp("80%")
    helper.setSkillKnown("Warp", false, "Occultism")
    local key = boop.attacks.preferenceConfigKey("occultist", "dam", "")
    boop.config[key] = "warp"

    local actions = boop.attacks.choose()

    assert.are.equal("command hound at 42", actions.standard)
  end)
end)
