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
    }, { "line", "a test denizen" }, "You lunge at a test denizen.")
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
end)
