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
      { name = "harry", group = "Attainment" },
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

  it("skips the full-hp opener when target hp info belongs to a different target", function()
    helper.setRage(0)
    gmcp.IRE.Target.Info.id = "41"
    gmcp.IRE.Target.Info.hpperc = "100%"

    local actions = boop.attacks.choose()

    assert.are.equal("command hound at 42", actions.standard)
    assert.is_false(actions.standardIsOpener)
  end)

  it("chooses a rage shieldbreak when the target is shielded", function()
    helper.setTargetHp("80%")
    helper.setRage(17)
    boop.state.targeting.targetShield = { gained = os.clock(), attempted = false }

    local actions = boop.attacks.choose()

    assert.are.equal("command hound at 42", actions.standard)
    assert.are.equal("ruin 42", actions.rage)
  end)

  it("does not choose a rage shieldbreak when shield breaking is disabled", function()
    helper.setTargetHp("80%")
    helper.setRage(17)
    boop.config.breakShields = false
    boop.state.targeting.targetShield = { gained = os.clock(), attempted = false }

    local actions = boop.attacks.choose()

    assert.are.equal("command hound at 42", actions.standard)
    assert.are.equal("harry 42", actions.rage)
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

  it("lists Infernal spec-specific Weaponmastery options for boop prefer", function()
    helper.setClass("Infernal")
    helper.setSpec("Dual Cutting")

    local options = boop.attacks.standardOptions("infernal", "dam")
    local labels = {}
    for _, option in ipairs(options) do
      labels[#labels + 1] = option.label
    end
    local joined = table.concat(labels, "\n")

    assert.is_true(joined:find("Duality", 1, true) ~= nil)
    assert.is_true(joined:find("dsl &tar", 1, true) ~= nil)
    assert.is_true(joined:find("Swordplay", 1, true) ~= nil)
    assert.is_true(joined:find("jab &tar", 1, true) ~= nil)
  end)

  it("matches Warrior spec names case-insensitively for preference options", function()
    helper.setClass("Infernal")
    helper.setSpec("dual cutting")

    local options = boop.attacks.standardOptions("infernal", "dam")

    assert.are.equal("Duality -> dsl &tar", options[1].label)
  end)

  it("lists Infernal quarc as a standard damage preference option", function()
    helper.setClass("Infernal")
    helper.setSpec("Dual Cutting")

    local options = boop.attacks.standardOptions("infernal", "dam")
    local labels = {}
    for _, option in ipairs(options) do
      labels[#labels + 1] = option.label
    end
    local joined = table.concat(labels, "\n")

    assert.is_true(joined:find("quarc -> quash &tar/arc", 1, true) ~= nil)
  end)

  it("uses Infernal quarc when preferred", function()
    helper.setClass("Infernal")
    helper.setSpec("Dual Cutting")
    helper.setTargetHp("80%")
    local key = boop.attacks.preferenceConfigKey("infernal", "dam", "Dual Cutting")
    boop.config[key] = "quarc"

    local actions = boop.attacks.choose()

    assert.are.equal("quash 42/arc", actions.standard)
  end)

  it("lists Dragon blast as a standard damage preference option", function()
    local options = boop.attacks.standardOptions("blue dragon", "dam")
    local labels = {}
    for _, option in ipairs(options) do
      labels[#labels + 1] = option.label
    end
    local joined = table.concat(labels, "\n")

    assert.is_true(joined:find("Blast -> blast &tar", 1, true) ~= nil)
  end)

  it("lists Psion flurry as a standard damage preference option", function()
    local options = boop.attacks.standardOptions("psion", "dam")
    local labels = {}
    for _, option in ipairs(options) do
      labels[#labels + 1] = option.label
    end
    local joined = table.concat(labels, "\n")

    assert.is_true(joined:find("Charge -> weave charge &tar", 1, true) ~= nil)
    assert.is_true(joined:find("Flurry -> weave flurry &tar", 1, true) ~= nil)
  end)
end)
