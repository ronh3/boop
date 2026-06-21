local helper = dofile(os.getenv("TESTS_DIRECTORY") .. "/support/boop_test_helper.lua")

describe("boop gag summaries", function()
  local cecho_stub
  local echo_stub
  local select_stub
  local delete_stub
  local timer_stub
  local kill_timer_stub
  local outputs

  before_each(function()
    helper.reset()
    outputs = {}

    boop.config.gagOwnAttacks = true
    boop.config.gagOthersAttacks = false
    helper.setTarget("42", "a test denizen", "80%")
    helper.setDenizens({
      { id = "42", name = "a test denizen" },
    })

    cecho_stub = stub(_G, "cecho", function(msg)
      outputs[#outputs + 1] = msg
    end)
    echo_stub = stub(_G, "echo", function(msg)
      outputs[#outputs + 1] = msg
    end)
    select_stub = stub(_G, "selectCurrentLine", function() end)
    delete_stub = stub(_G, "deleteLine", function() end)
    timer_stub = stub(_G, "tempTimer", function(_, _)
      return 41
    end)
    kill_timer_stub = stub(_G, "killTimer", function(_) end)
  end)

  after_each(function()
    if cecho_stub then
      cecho_stub:revert()
      cecho_stub = nil
    end
    if echo_stub then
      echo_stub:revert()
      echo_stub = nil
    end
    if select_stub then
      select_stub:revert()
      select_stub = nil
    end
    if delete_stub then
      delete_stub:revert()
      delete_stub = nil
    end
    if timer_stub then
      timer_stub:revert()
      timer_stub = nil
    end
    if kill_timer_stub then
      kill_timer_stub:revert()
      kill_timer_stub = nil
    end
  end)

  it("condenses an own attack into one summary line with damage, crit, and balance", function()
    boop.gag.onAttackLine({
      ability = "Lycantha",
      actor = { kind = "literal", value = "You" },
      target = { kind = "match", index = 2 },
    }, {
      "You command your hound to rend the flesh of a test denizen again.",
      "a test denizen",
    }, "You command your hound to rend the flesh of a test denizen again.")
    boop.gag.onDamageLine("1,234", "cutting", "Damage line")
    boop.gag.onCriticalLine("world shattering critical", "Crit line")
    boop.gag.onBalanceUsed("2.5", "Balance line")

    assert.are.equal(1, #outputs)
    assert.is_true(outputs[1]:find("You", 1, true) ~= nil)
    assert.is_true(outputs[1]:find("Lycantha", 1, true) ~= nil)
    assert.is_true(outputs[1]:find("a test denizen", 1, true) ~= nil)
    assert.is_true(outputs[1]:find("1234 cutting - 32xCRIT", 1, true) ~= nil)
    assert.is_true(outputs[1]:find("Bal: 2.5s", 1, true) ~= nil)
  end)

  it("labels same-target proc damage inside the compact attack summary", function()
    boop.gag.onAttackLine({
      ability = "Charge",
      actor = { kind = "match", index = 2 },
      target = { kind = "match", index = 3 },
    }, {
      "Charging forward, you drive a translucent spear into a shade of might.",
      "you",
      "a shade of might",
    }, "Charging forward, you drive a translucent spear into a shade of might.")
    boop.gag.onCriticalLine("CRUSHING CRITICAL", "You have scored a CRUSHING CRITICAL hit!")
    boop.gag.onDamageLine("2,478", "physical cutting", "Damage dealt: 2,478 (physical cutting).")
    boop.gag.onProcLine("Gear", "", "Your gear enhances your strike with additional psychic damage.")
    boop.gag.onDamageLine("30", "psychic", "Damage dealt: 30 (psychic).")
    boop.gag.onProcLine("Spectral Claws", "a shade of might", "Spectral claws coalesce around a shade of might, slashing his form with savage fury.")
    boop.gag.onDamageLine("122", "physical cutting", "Damage dealt: 122 (physical cutting).")
    boop.gag.onBalanceUsed("2.1", "Balance used: 2.1s.")

    assert.are.equal(1, #outputs)
    assert.is_true(outputs[1]:find("Charge + Gear + Spectral Claws", 1, true) ~= nil)
    assert.is_true(outputs[1]:find("Charge: 2478 physical cutting - 4xCRIT", 1, true) ~= nil)
    assert.is_true(outputs[1]:find("Gear: 30 psychic", 1, true) ~= nil)
    assert.is_true(outputs[1]:find("Spectral Claws: 122 physical cutting", 1, true) ~= nil)
    assert.is_true(outputs[1]:find("Bal: 2.1s", 1, true) ~= nil)
  end)

  it("keeps psion shatter prefix damage with the following same-target attack", function()
    boop.gag.onAttackLine({
      ability = "Shatter",
      actor = nil,
      target = { kind = "match", index = 3 },
    }, {
      "You reach out with grim intent, seeking to shatter the psyche of an agitated ghost.",
      "You",
      "an agitated ghost",
    }, "You reach out with grim intent, seeking to shatter the psyche of an agitated ghost.")
    boop.gag.onDamageLine("200", "psychic", "Damage dealt: 200 (psychic).")
    boop.gag.onAttackLine({
      ability = "Charge",
      actor = { kind = "match", index = 2 },
      target = { kind = "match", index = 3 },
    }, {
      "Charging forward, you drive a translucent spear into an agitated ghost.",
      "you",
      "an agitated ghost",
    }, "Charging forward, you drive a translucent spear into an agitated ghost.")
    boop.gag.onDamageLine("2,478", "physical cutting", "Damage dealt: 2,478 (physical cutting).")
    boop.gag.onPrompt()

    assert.are.equal(1, #outputs)
    assert.is_true(outputs[1]:find("Shatter + Charge", 1, true) ~= nil)
    assert.is_true(outputs[1]:find("an agitated ghost", 1, true) ~= nil)
    assert.is_true(outputs[1]:find("Shatter: 200 psychic", 1, true) ~= nil)
    assert.is_true(outputs[1]:find("Charge: 2478 physical cutting", 1, true) ~= nil)
  end)

  it("splits target-changing proc damage before the next prompt", function()
    boop.gag.onProcLine("Tumble", "(room)", "You tumble violently into your surroundings, obliterating them with all the force of a rolling boulder.")
    boop.gag.onCriticalLine("CRUSHING CRITICAL", "You have scored a CRUSHING CRITICAL hit!")
    boop.gag.onDamageLine("19,242", "physical blunt", "Damage dealt: 19,242 (physical blunt).")
    boop.gag.onProcLine("Gear", "", "Your gear enhances your strike with additional psychic damage.")
    boop.gag.onDamageLine("180", "psychic", "Damage dealt: 180 (psychic).")
    boop.gag.onProcLine("Spectral Claws", "a lesser earth elemental", "Spectral claws coalesce around a lesser earth elemental, slashing its form with savage fury.")
    boop.gag.onCriticalLine("OBLITERATING CRITICAL", "You have scored an OBLITERATING CRITICAL hit!")
    boop.gag.onDamageLine("7,696", "physical cutting", "Damage dealt: 7,696 (physical cutting).")
    boop.gag.onDamageLine("4,810", "physical blunt", "Damage dealt: 4,810 (physical blunt).")
    boop.gag.onProcLine("Gear", "", "Your gear enhances your strike with additional psychic damage.")
    boop.gag.onCriticalLine("PLANE-RAZING CRITICAL", "You have scored a PLANE-RAZING CRITICAL hit!")
    boop.gag.onDamageLine("11,520", "psychic", "Damage dealt: 11,520 (psychic).")
    boop.gag.onPrompt()

    assert.are.equal(2, #outputs)
    assert.is_true(outputs[1]:find("Tumble + Gear", 1, true) ~= nil)
    assert.is_true(outputs[1]:find("(room)", 1, true) ~= nil)
    assert.is_true(outputs[1]:find("Tumble: 19242 physical blunt - 4xCRIT", 1, true) ~= nil)
    assert.is_true(outputs[1]:find("Gear: 180 psychic", 1, true) ~= nil)
    assert.is_true(outputs[2]:find("Spectral Claws + Gear", 1, true) ~= nil)
    assert.is_true(outputs[2]:find("a lesser earth elemental", 1, true) ~= nil)
    assert.is_true(outputs[2]:find("Spectral Claws: 7696 physical cutting - 8xCRIT", 1, true) ~= nil)
    assert.is_true(outputs[2]:find("Spectral Claws: 4810 physical blunt", 1, true) ~= nil)
    assert.is_true(outputs[2]:find("Gear: 11520 psychic - 64xCRIT", 1, true) ~= nil)
  end)

  it("condenses two pre-balance self jab-shaped hits as one DSL summary", function()
    boop.gag.onAttackLine({
      ability = "Jab",
      actor = { kind = "literal", value = "You" },
      target = { kind = "match", index = 2 },
    }, {
      "You swing a broad-bladed sword of hardship at a Vertani guard with all your might.",
      "a Vertani guard",
    }, "You swing a broad-bladed sword of hardship at a Vertani guard with all your might.")
    boop.gag.onDamageLine("356", "physical cutting", "Damage dealt: 356 (physical cutting).")
    boop.gag.onAttackLine({
      ability = "Jab",
      actor = { kind = "literal", value = "You" },
      target = { kind = "match", index = 2 },
    }, {
      "You slash into a Vertani guard with a curved blade of broken chains.",
      "a Vertani guard",
    }, "You slash into a Vertani guard with a curved blade of broken chains.")
    boop.gag.onCriticalLine("OBLITERATING CRITICAL", "You have scored an OBLITERATING CRITICAL hit!")
    boop.gag.onDamageLine("2854", "physical cutting", "Damage dealt: 2854 (physical cutting).")
    boop.gag.onBalanceUsed("1.9", "Balance used: 1.9s.")

    assert.are.equal(1, #outputs)
    assert.is_true(outputs[1]:find("You", 1, true) ~= nil)
    assert.is_true(outputs[1]:find("DSL", 1, true) ~= nil)
    assert.is_true(outputs[1]:find("a Vertani guard", 1, true) ~= nil)
    assert.is_true(outputs[1]:find("356 physical cutting", 1, true) ~= nil)
    assert.is_true(outputs[1]:find("2854 physical cutting - 8xCRIT", 1, true) ~= nil)
    assert.is_true(outputs[1]:find("Bal: 1.9s", 1, true) ~= nil)
  end)

  it("keeps a first-hit crit when two jab-shaped hits become a DSL summary", function()
    boop.gag.onAttackLine({
      ability = "Jab",
      actor = { kind = "literal", value = "You" },
      target = { kind = "match", index = 2 },
    }, {
      "You swing a broad-bladed sword of hardship at a Vertani guard with all your might.",
      "a Vertani guard",
    }, "You swing a broad-bladed sword of hardship at a Vertani guard with all your might.")
    boop.gag.onCriticalLine("OBLITERATING CRITICAL", "You have scored an OBLITERATING CRITICAL hit!")
    boop.gag.onDamageLine("2854", "physical cutting", "Damage dealt: 2854 (physical cutting).")
    boop.gag.onAttackLine({
      ability = "Jab",
      actor = { kind = "literal", value = "You" },
      target = { kind = "match", index = 2 },
    }, {
      "You slash into a Vertani guard with a curved blade of broken chains.",
      "a Vertani guard",
    }, "You slash into a Vertani guard with a curved blade of broken chains.")
    boop.gag.onDamageLine("356", "physical cutting", "Damage dealt: 356 (physical cutting).")
    boop.gag.onBalanceUsed("1.9", "Balance used: 1.9s.")

    assert.are.equal(1, #outputs)
    assert.is_true(outputs[1]:find("DSL", 1, true) ~= nil)
    assert.is_true(outputs[1]:find("a Vertani guard", 1, true) ~= nil)
    assert.is_true(outputs[1]:find("2854 physical cutting - 8xCRIT", 1, true) ~= nil)
    assert.is_true(outputs[1]:find("356 physical cutting", 1, true) ~= nil)
    assert.is_true(outputs[1]:find("Bal: 1.9s", 1, true) ~= nil)
  end)

  it("does not merge unrelated repeated own attack summaries before balance", function()
    boop.gag.onAttackLine({
      ability = "Lycantha",
      actor = { kind = "literal", value = "You" },
      target = { kind = "match", index = 2 },
    }, {
      "You command your hound to rend the flesh of a test denizen.",
      "a test denizen",
    }, "You command your hound to rend the flesh of a test denizen.")
    boop.gag.onDamageLine("111", "cutting", "Damage line")
    boop.gag.onAttackLine({
      ability = "Lycantha",
      actor = { kind = "literal", value = "You" },
      target = { kind = "match", index = 2 },
    }, {
      "You command your hound to rend the flesh of a test denizen.",
      "a test denizen",
    }, "You command your hound to rend the flesh of a test denizen.")
    boop.gag.onDamageLine("222", "cutting", "Damage line")
    boop.gag.onBalanceUsed("2.5", "Balance line")

    assert.are.equal(2, #outputs)
    assert.is_true(outputs[1]:find("Lycantha", 1, true) ~= nil)
    assert.is_true(outputs[1]:find("111 cutting", 1, true) ~= nil)
    assert.is_true(outputs[2]:find("Lycantha", 1, true) ~= nil)
    assert.is_true(outputs[2]:find("222 cutting", 1, true) ~= nil)
    assert.is_true(outputs[2]:find("Bal: 2.5s", 1, true) ~= nil)
  end)

  it("combines a sent razeslash shield line and jab-shaped hit as one summary", function()
    boop.gag.noteStandardIntent("rsl 42")
    boop.gag.onAttackLine({
      ability = "Raze",
      actor = { kind = "match", index = 2 },
      target = { kind = "match", index = 3 },
    }, {
      "You raze a Vertani guard's magical shield with a broad-bladed sword of hardship.",
      "You",
      "a Vertani guard",
    }, "You raze a Vertani guard's magical shield with a broad-bladed sword of hardship.")
    boop.gag.onBalanceUsed("2.1", "Balance used: 2.1s.")

    assert.are.equal(0, #outputs)

    boop.gag.onAttackLine({
      ability = "Jab",
      actor = { kind = "match", index = 2 },
      target = { kind = "match", index = 3 },
    }, {
      "Lightning-quick, you jab a Vertani guard with a curved blade of broken chains.",
      "you",
      "a Vertani guard",
    }, "Lightning-quick, you jab a Vertani guard with a curved blade of broken chains.")
    boop.gag.onDamageLine("356", "physical cutting", "Damage dealt: 356 (physical cutting).")
    boop.gag.onPrompt()

    assert.are.equal(1, #outputs)
    assert.is_true(outputs[1]:find("Razeslash", 1, true) ~= nil)
    assert.is_true(outputs[1]:find("a Vertani guard", 1, true) ~= nil)
    assert.is_true(outputs[1]:find("356 physical cutting", 1, true) ~= nil)
    assert.is_true(outputs[1]:find("Bal: 2.1s", 1, true) ~= nil)
    assert.is_true(outputs[1]:find("DSL", 1, true) == nil)
  end)

  it("suppresses hyena maul flavor and preserves the following DSL summary", function()
    boop.gag.onAttackLine({
      ability = "Hyena Maul",
      actor = { kind = "literal", value = "You" },
      target = { kind = "match", index = 2 },
    }, {
      "You command your hyena to maul a Vertani guard.",
      "a Vertani guard",
    }, "You command your hyena to maul a Vertani guard.")
    boop.gag.onCompanionMaulFlavor(
      "a Vertani guard",
      "A daemonic hyena lets loose a wooping cackle as she lunges at a Vertani guard, sinking her fangs into his flesh."
    )
    boop.gag.onCriticalLine("CRUSHING CRITICAL", "You have scored a CRUSHING CRITICAL hit!")
    boop.gag.onDamageLine("3388", "physical cutting", "Damage dealt: 3388 (physical cutting).")
    boop.gag.onAttackLine({
      ability = "Jab",
      actor = { kind = "literal", value = "You" },
      target = { kind = "match", index = 2 },
    }, {
      "You swing a broad-bladed sword of hardship at a Vertani guard with all your might.",
      "a Vertani guard",
    }, "You swing a broad-bladed sword of hardship at a Vertani guard with all your might.")
    boop.gag.onDamageLine("356", "physical cutting", "Damage dealt: 356 (physical cutting).")
    boop.gag.onAttackLine({
      ability = "Jab",
      actor = { kind = "match", index = 2 },
      target = { kind = "match", index = 3 },
    }, {
      "Lightning-quick, you jab a Vertani guard with a curved blade of broken chains.",
      "you",
      "a Vertani guard",
    }, "Lightning-quick, you jab a Vertani guard with a curved blade of broken chains.")
    boop.gag.onCriticalLine("OBLITERATING CRITICAL", "You have scored an OBLITERATING CRITICAL hit!")
    boop.gag.onDamageLine("2854", "physical cutting", "Damage dealt: 2854 (physical cutting).")
    boop.gag.onBalanceUsed("1.9", "Balance used: 1.9s.")

    assert.are.equal(2, #outputs)
    assert.is_true(outputs[1]:find("Hyena Maul", 1, true) ~= nil)
    assert.is_true(outputs[1]:find("a Vertani guard", 1, true) ~= nil)
    assert.is_true(outputs[1]:find("3388 physical cutting - 4xCRIT", 1, true) ~= nil)
    assert.is_true(outputs[2]:find("DSL", 1, true) ~= nil)
    assert.is_true(outputs[2]:find("356 physical cutting", 1, true) ~= nil)
    assert.is_true(outputs[2]:find("2854 physical cutting - 8xCRIT", 1, true) ~= nil)
    assert.is_true(outputs[2]:find("Bal: 1.9s", 1, true) ~= nil)
  end)

  it("suppresses the alternate hyena maul claw flavor", function()
    boop.gag.onAttackLine({
      ability = "Hyena Maul",
      actor = { kind = "literal", value = "You" },
      target = { kind = "match", index = 2 },
    }, {
      "You command your hyena to maul a Vertani guard.",
      "a Vertani guard",
    }, "You command your hyena to maul a Vertani guard.")
    boop.gag.onCompanionMaulFlavor(
      "a Vertani guard",
      "A daemonic hyena snarls as she hurls herself at a Vertani guard, raking her claws across his face."
    )
    boop.gag.onDamageLine("900", "physical cutting", "Damage dealt: 900 (physical cutting).")
    boop.gag.onPrompt()

    assert.are.equal(1, #outputs)
    assert.is_true(outputs[1]:find("Hyena Maul", 1, true) ~= nil)
    assert.is_true(outputs[1]:find("900 physical cutting", 1, true) ~= nil)
  end)

  it("starts a hyena maul summary from flavor if the command line was missed", function()
    boop.gag.onCompanionMaulFlavor(
      "a Vertani guard",
      "A daemonic hyena snarls as she hurls herself at a Vertani guard, raking her claws across his face."
    )
    boop.gag.onCriticalLine("CRUSHING CRITICAL", "You have scored a CRUSHING CRITICAL hit!")
    boop.gag.onDamageLine("3388", "physical cutting", "Damage dealt: 3388 (physical cutting).")
    boop.gag.onPrompt()

    assert.are.equal(1, #outputs)
    assert.is_true(outputs[1]:find("Hyena Maul", 1, true) ~= nil)
    assert.is_true(outputs[1]:find("a Vertani guard", 1, true) ~= nil)
    assert.is_true(outputs[1]:find("3388 physical cutting - 4xCRIT", 1, true) ~= nil)
  end)

  it("starts a hound maul summary from flavor if the command line was missed", function()
    boop.gag.onCompanionMaulFlavor(
      "a ghost bat",
      "A chaos hound lunges at a ghost bat with a baying howl, ripping into it with its distended jaws."
    )
    boop.gag.onDamageLine("777", "physical cutting", "Damage dealt: 777 (physical cutting).")
    boop.gag.onPrompt()

    assert.are.equal(1, #outputs)
    assert.is_true(outputs[1]:find("Hound Maul", 1, true) ~= nil)
    assert.is_true(outputs[1]:find("a ghost bat", 1, true) ~= nil)
    assert.is_true(outputs[1]:find("777 physical cutting", 1, true) ~= nil)
  end)

  it("starts a hyena maul summary from flavor if a non-maul attack was pending", function()
    boop.gag.onAttackLine({
      ability = "Jab",
      actor = { kind = "literal", value = "You" },
      target = { kind = "match", index = 2 },
    }, {
      "You swing a broad-bladed sword of hardship at a Vertani guard with all your might.",
      "a Vertani guard",
    }, "You swing a broad-bladed sword of hardship at a Vertani guard with all your might.")
    boop.gag.onCompanionMaulFlavor(
      "a Vertani guard",
      "A daemonic hyena lets loose a wooping cackle as she lunges at a Vertani guard, sinking her fangs into his flesh."
    )
    boop.gag.onDamageLine("3388", "physical cutting", "Damage dealt: 3388 (physical cutting).")
    boop.gag.onPrompt()

    assert.are.equal(2, #outputs)
    assert.is_true(outputs[1]:find("Jab", 1, true) ~= nil)
    assert.is_true(outputs[2]:find("Hyena Maul", 1, true) ~= nil)
    assert.is_true(outputs[2]:find("3388 physical cutting", 1, true) ~= nil)
  end)

  it("captures the alternate Unnamable destroy attack wording", function()
    boop.gag.onAttackLine({
      ability = "Destroy",
      actor = { kind = "literal", value = "You" },
      target = { kind = "match", index = 2 },
    }, {
      "You lash out with power and will, your only task to crush the light from your wretched target, a ghost bat.",
      "a ghost bat",
    }, "You lash out with power and will, your only task to crush the light from your wretched target, a ghost bat.")
    boop.gag.onDamageLine("2,222", "psychic", "Damage line")
    boop.gag.onBalanceUsed("1.9", "Balance line")

    assert.are.equal(1, #outputs)
    assert.is_true(outputs[1]:find("Destroy", 1, true) ~= nil)
    assert.is_true(outputs[1]:find("a ghost bat", 1, true) ~= nil)
    assert.is_true(outputs[1]:find("2222 psychic", 1, true) ~= nil)
  end)

  it("condenses a kill and experience line into one kill summary", function()
    boop.gag.onSlainLine("a test denizen", "Slain line")
    boop.gag.onExperienceLine("456", "Experience line")

    assert.are.equal(1, #outputs)
    assert.is_true(outputs[1]:find("Killed", 1, true) ~= nil)
    assert.is_true(outputs[1]:find("a test denizen", 1, true) ~= nil)
    assert.is_true(outputs[1]:find("456xp", 1, true) ~= nil)
  end)

  it("ignores generic slain-by lines for other players", function()
    boop.gag.onSlainLine("a test denizen", "A test denizen has been slain by SomeoneElse.", "SomeoneElse")

    assert.are.equal(0, #outputs)
  end)

  it("flushes a pending own attack summary on prompt even without balance lines", function()
    boop.gag.onAttackLine({
      ability = "Jab",
      actor = { kind = "literal", value = "You" },
      target = { kind = "match", index = 2 },
    }, { "line", "a test denizen" }, "You jab a test denizen.")

    boop.gag.onPrompt()

    assert.are.equal(1, #outputs)
    assert.is_true(outputs[1]:find("You", 1, true) ~= nil)
    assert.is_true(outputs[1]:find("Jab", 1, true) ~= nil)
    assert.is_true(outputs[1]:find("a test denizen", 1, true) ~= nil)
  end)

  it("emits an own attack summary immediately if the fallback timer cannot be armed", function()
    timer_stub:revert()
    timer_stub = stub(_G, "tempTimer", function(_, _)
      error("timer unavailable")
    end)

    boop.gag.onAttackLine({
      ability = "Jab",
      actor = { kind = "literal", value = "You" },
      target = { kind = "match", index = 2 },
    }, { "line", "a test denizen" }, "You jab a test denizen.")

    assert.are.equal(1, #outputs)
    assert.is_true(outputs[1]:find("You", 1, true) ~= nil)
    assert.is_true(outputs[1]:find("Jab", 1, true) ~= nil)
    assert.is_true(outputs[1]:find("a test denizen", 1, true) ~= nil)
  end)

  it("applies custom separator and background gag colors", function()
    boop.gag.setColor("own", "who", "yellow")
    boop.gag.setColor("own", "separator", "dark_grey")
    boop.gag.setColor("own", "background", "midnight_blue")

    outputs = {}
    boop.gag.onAttackLine({
      ability = "Jab",
      actor = { kind = "literal", value = "You" },
      target = { kind = "match", index = 2 },
    }, { "line", "a test denizen" }, "You jab a test denizen.")

    boop.gag.onPrompt()

    assert.are.equal(1, #outputs)
    assert.is_true(outputs[1]:find("<yellow:midnight_blue>You<reset>", 1, true) ~= nil)
    assert.is_true(outputs[1]:find("<dark_grey:midnight_blue>: <reset>", 1, true) ~= nil)
    assert.is_true(outputs[1]:find("<dark_grey:midnight_blue> -> <reset>", 1, true) ~= nil)
  end)

  it("uses a separate palette for other players' gag lines", function()
    boop.config.gagOthersAttacks = true
    boop.gag.setColor("others", "who", "khaki")
    boop.gag.setColor("others", "separator", "tomato")

    outputs = {}
    boop.gag.onAttackLine({
      ability = "Jab",
      actor = { kind = "literal", value = "Someone" },
      target = { kind = "match", index = 2 },
    }, { "line", "a test denizen" }, "Someone jabs a test denizen.")

    assert.are.equal(1, #outputs)
    assert.is_true(outputs[1]:find("<khaki>Someone<reset>", 1, true) ~= nil)
    assert.is_true(outputs[1]:find("<tomato>: <reset>", 1, true) ~= nil)
  end)

  it("condenses a known mob attack and health lost line", function()
    boop.config.gagMobAttacks = true

    boop.gag.onMobAttackLine({
      actor = { kind = "match", index = 2 },
    }, {
      "An agitated ghost floats up behind you and throttles you with a shred of her tattered robe.",
      "An agitated ghost",
    }, "An agitated ghost floats up behind you and throttles you with a shred of her tattered robe.")
    boop.gag.onHealthLostLine("649", "asphyxiation", "Health lost: 649 (asphyxiation).")

    assert.are.equal(1, #outputs)
    assert.is_true(outputs[1]:find("An agitated ghost", 1, true) ~= nil)
    assert.is_true(outputs[1]:find("Damage", 1, true) ~= nil)
    assert.is_true(outputs[1]:find("You", 1, true) ~= nil)
    assert.is_true(outputs[1]:find("649 asphyxiation", 1, true) ~= nil)
  end)

  it("uses a separate palette for mob gag lines", function()
    boop.config.gagMobAttacks = true
    boop.gag.setColor("mobs", "who", "orange")
    boop.gag.setColor("mobs", "ability", "tomato")

    outputs = {}
    boop.gag.onMobAttackLine({
      actor = { kind = "literal", value = "Mob" },
    }, { "line" }, "Mob hits you.")
    boop.gag.onHealthLostLine("1,234", "fire", "Health lost: 1,234 (fire).")

    assert.are.equal(1, #outputs)
    assert.is_true(outputs[1]:find("<orange>Mob<reset>", 1, true) ~= nil)
    assert.is_true(outputs[1]:find("<tomato>Damage<reset>", 1, true) ~= nil)
    assert.is_true(outputs[1]:find("1234 fire", 1, true) ~= nil)
  end)

  it("captures the third-person Occultist hound line as an others gag", function()
    boop.config.gagOwnAttacks = false
    boop.config.gagOthersAttacks = true

    outputs = {}
    boop.gag.onAttackLine({
      ability = "Lycantha",
      actor = { kind = "literal", value = "Chaos Hound" },
      target = { kind = "match", index = 2 },
    }, {
      "With an unearthly howl, a chaos hound leaps upon a test denizen and savages him viciously.",
      "a test denizen",
    }, "With an unearthly howl, a chaos hound leaps upon a test denizen and savages him viciously.")

    assert.are.equal(1, #outputs)
    assert.is_true(outputs[1]:find("Chaos Hound", 1, true) ~= nil)
    assert.is_true(outputs[1]:find("Lycantha", 1, true) ~= nil)
    assert.is_true(outputs[1]:find("a test denizen", 1, true) ~= nil)
  end)
end)
