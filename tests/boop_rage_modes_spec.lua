local helper = dofile(os.getenv("TESTS_DIRECTORY") .. "/support/boop_test_helper.lua")

describe("boop rage modes", function()
  before_each(function()
    helper.reset()
    helper.setClass("Occultist")
    helper.setTarget("42", "a test denizen", "80%")
  end)

  it("falls back to simple damage in combo mode when no provider support exists", function()
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
end)
