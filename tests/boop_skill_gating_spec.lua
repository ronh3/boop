local helper = dofile(os.getenv("TESTS_DIRECTORY") .. "/support/boop_test_helper.lua")

describe("boop skill-gated attack selection", function()
  before_each(function()
    helper.reset()
    helper.setClass("Occultist")
    helper.setTarget("42", "a test denizen", "100%")
  end)

  it("falls back to standard damage when the opener skill is unavailable", function()
    helper.setRage(0)
    helper.setSkillKnown("Attend", false, "Occultism")
    helper.learnSkills({
      { name = "Lycantha", group = "Domination" },
      { name = "Warp", group = "Occultism" },
    })

    local actions = boop.attacks.choose()

    assert.are.equal("command hound at 42", actions.standard)
    assert.is_false(actions.standardIsOpener)
  end)

  it("falls back to the secondary standard attack when the primary skill is unavailable", function()
    helper.setTargetHp("80%")
    helper.setSkillKnown("Lycantha", false, "Domination")
    helper.learnSkill("Warp", "Occultism")

    local actions = boop.attacks.choose()

    assert.are.equal("warp 42", actions.standard)
  end)

  it("suppresses rage output when the available rage skill is unknown", function()
    helper.setTargetHp("80%")
    helper.setRage(14)
    helper.learnSkill("Lycantha", "Domination")
    helper.setSkillKnown("harry", false, "Attainment")

    local actions = boop.attacks.choose()

    assert.are.equal("command hound at 42", actions.standard)
    assert.are.equal("", actions.rage)
  end)
end)
