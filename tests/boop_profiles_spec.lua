local helper = dofile(os.getenv("TESTS_DIRECTORY") .. "/support/boop_test_helper.lua")
local attacksRoot = helper.repoRoot() .. "/src/scripts/boop/attacks/"
dofile(attacksRoot .. "infernal.lua")
dofile(attacksRoot .. "runewarden.lua")
dofile(attacksRoot .. "depthswalker.lua")
dofile(attacksRoot .. "psion.lua")
dofile(attacksRoot .. "blue_dragon.lua")
dofile(attacksRoot .. "blademaster.lua")

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

  it("can prepend focus precision for two-handed standards when configured", function()
    helper.setClass("Infernal")
    helper.setSpec("Two Handed")
    helper.learnSkills({
      { name = "Slaughter", group = "Weaponmastery" },
      { name = "Focus", group = "Weaponmastery" },
    })
    boop.config.focusVerb = "precision"

    local actions = boop.attacks.choose()

    assert.are.equal("battlefury focus precision/slaughter 42", actions.standard)
  end)

  it("prepends the Infernal hyena maul when Malignity Maul is ready", function()
    helper.setClass("Infernal")
    helper.setSpec("Dual Cutting")
    helper.learnSkills({
      { name = "Duality", group = "Weaponmastery" },
      { name = "Maul", group = "Malignity" },
    })
    boop.rage.setReady("maul", true)

    local actions = boop.attacks.choose()

    assert.are.equal("hyena maul 42/dsl 42", actions.standard)
  end)

  it("uses the infernal sword-and-shield shieldbreak standard for shielded targets", function()
    helper.setClass("Infernal")
    helper.setSpec("Sword and Shield")
    helper.learnSkill("Combination", "Weaponmastery")
    boop.state.targeting.targetShield = { attempted = false }

    local actions = boop.attacks.choose()

    assert.are.equal("combination 42 raze smash", actions.standard)
    assert.is_true(actions.standardShieldbreak)
  end)

  it("uses the class/spec's normal standard selection in bypass mode", function()
    helper.setClass("Infernal")
    helper.setSpec("Sword and Shield")
    helper.learnSkill("Combination", "Weaponmastery")
    assert.is_true(boop.ui.setShieldMode("bypass", true))
    boop.state.targeting.targetShield = { attempted = false }

    local actions = boop.attacks.choose()

    assert.are.equal("combination 42 rend smash", actions.standard)
    assert.is_false(actions.standardShieldbreak)
  end)

  it("uses the standard shieldbreak instead of rage shieldbreak when pull reserve is enabled", function()
    helper.setClass("Infernal")
    helper.setSpec("Sword and Shield")
    helper.setRage(17)
    helper.learnSkill("Combination", "Weaponmastery")
    helper.learnSkill("shiver", "Attainment")
    boop.config.pullRageReserve = true
    boop.state.targeting.targetShield = { attempted = false }

    local actions = boop.attacks.choose()

    assert.are.equal("combination 42 raze smash", actions.standard)
    assert.is_true(actions.standardShieldbreak)
    assert.are.equal("", actions.rage)
  end)

  it("uses the Blademaster TwoArts raze against a shielded target", function()
    helper.setClass("Blademaster")
    helper.learnSkills({
      { name = "Drawslash", group = "TwoArts" },
      { name = "Raze", group = "TwoArts" },
    })
    boop.state.targeting.targetShield = { attempted = false }

    local actions = boop.attacks.choose()

    assert.are.equal("raze 42 sternum", actions.standard)
    assert.is_true(actions.standardShieldbreak)
  end)

  it("uses Blademaster multislash by default when it is known", function()
    helper.setClass("Blademaster")
    helper.learnSkills({
      { name = "Multislash", group = "TwoArts" },
      { name = "Drawslash", group = "TwoArts" },
    })

    local actions = boop.attacks.choose()

    assert.are.equal("multislash 42", actions.standard)
  end)

  it("keeps Blademaster drawslash selectable as a damage preference", function()
    helper.setClass("Blademaster")
    helper.learnSkills({
      { name = "Multislash", group = "TwoArts" },
      { name = "Drawslash", group = "TwoArts" },
    })
    boop.config[boop.attacks.preferenceConfigKey(
      "blademaster",
      "dam",
      ""
    )] = "drawslash"

    local actions = boop.attacks.choose()

    assert.are.equal("infuse fire/drawslash 42 sternum", actions.standard)
  end)

  it("lists both Blademaster standard damage preferences", function()
    local options = boop.attacks.standardOptions("blademaster", "dam")

    assert.are.equal(2, #options)
    assert.are.equal("Multislash -> multislash &tar", options[1].label)
    assert.are.equal(
      "Drawslash -> infuse fire/drawslash &tar sternum",
      options[2].label
    )
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
    boop.state.inventory.wieldedRight = { id = "11", name = "a practice scythe", attrib = "L", icon = "weapon" }

    local actions = boop.attacks.choose()

    assert.are.equal("shadow reap 42", actions.standard)
  end)

  it("uses designated weapon ids for depthswalker weapon swaps", function()
    helper.setClass("Depthswalker")
    helper.learnSkill("Strike", "Shadowmancy")
    boop.state.targeting.targetShield = { attempted = false }
    local key = boop.attacks.weaponConfigKey("depthswalker", "dagger")
    boop.config[key] = "47177"

    local actions = boop.attacks.choose()

    assert.are.equal("wield 47177/shadow strike 42", actions.standard)
  end)

  it("recognizes combined depthswalker weapon tokens like scythe12345 as already wielded", function()
    helper.setClass("Depthswalker")
    helper.learnSkill("Reap", "Shadowmancy")
    local key = boop.attacks.weaponConfigKey("depthswalker", "scythe")
    boop.config[key] = "scythe12345"
    boop.state.inventory.wieldedRight = { id = "12345", name = "a practice scythe", attrib = "L", icon = "weapon" }

    local actions = boop.attacks.choose()

    assert.are.equal("shadow reap 42", actions.standard)
  end)

  it("prepends wield dagger for depthswalker shieldbreak when no dagger is tracked", function()
    helper.setClass("Depthswalker")
    helper.learnSkill("Strike", "Shadowmancy")
    boop.state.targeting.targetShield = { attempted = false }
    boop.state.inventory.wieldedLeft = { id = "12", name = "a tower shield", attrib = "l", icon = "armour" }
    boop.state.inventory.wieldedRight = { id = "13", name = "a practice scythe", attrib = "L", icon = "weapon" }

    local actions = boop.attacks.choose()

    assert.are.equal("wield dagger/shadow strike 42", actions.standard)
    assert.is_true(actions.standardShieldbreak)
  end)

  it("prepends psi transcend shatter to psion standard and rage commands", function()
    helper.setClass("Psion")
    helper.setRage(14)
    helper.learnSkills({
      { name = "Charge", group = "Weaving" },
      { name = "barbedblade", group = "Attainment" },
    })

    local actions = boop.attacks.choose()

    assert.are.equal("psi transcend shatter/weave charge 42", actions.standard)
    assert.are.equal("psi transcend shatter/weave barbedblade 42", actions.rage)
  end)

  it("can prefer flurry as a psion standard damage attack", function()
    helper.setClass("Psion")
    helper.learnSkills({
      { name = "Charge", group = "Weaving" },
      { name = "Flurry", group = "Weaving" },
    })
    boop.config[boop.attacks.preferenceConfigKey("psion", "dam", "")] = "flurry"

    local actions = boop.attacks.choose()

    assert.are.equal("psi transcend shatter/weave flurry 42", actions.standard)
  end)

  it("can prefer blast as a dragon standard without prefixing every attack", function()
    helper.setClass("Blue Dragon")
    helper.setRage(14)
    helper.learnSkills({
      { name = "Incantation", group = "Dragoncraft" },
      { name = "Blast", group = "Dragoncraft" },
      { name = "dragonchill", group = "Attainment" },
    })

    local actions = boop.attacks.choose()

    assert.are.equal("incantation 42", actions.standard)
    assert.are.equal("dragonchill 42", actions.rage)

    boop.config[boop.attacks.preferenceConfigKey("blue dragon", "dam", "")] = "blast"

    local preferredActions = boop.attacks.choose()

    assert.are.equal("blast 42", preferredActions.standard)
    assert.are.equal("dragonchill 42", preferredActions.rage)
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
