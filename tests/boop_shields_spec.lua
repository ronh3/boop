local helper = dofile(os.getenv("TESTS_DIRECTORY") .. "/support/boop_test_helper.lua")

describe("boop shield tracking", function()
  local timer_stub
  local kill_timer_stub

  before_each(function()
    helper.reset()
    helper.setTarget("42", "a test denizen", "80%")
    helper.setDenizens({
      { id = "42", name = "a test denizen" },
    })

    timer_stub = stub(_G, "tempTimer", function(_, _)
      return 101
    end)
    kill_timer_stub = stub(_G, "killTimer", function(_) end)
  end)

  after_each(function()
    if timer_stub then
      timer_stub:revert()
      timer_stub = nil
    end
    if kill_timer_stub then
      kill_timer_stub:revert()
      kill_timer_stub = nil
    end
  end)

  it("tracks a shield when it is seen on the current target", function()
    boop.targets.onShielded("a test denizen")

    assert.is_table(boop.state.targetShield)
    assert.is_false(boop.state.targetShield.attempted)
    assert.are.equal(101, boop.state.targetShield.timer)
  end)

  it("clears tracked shield state when a matching shield-down trigger fires", function()
    boop.state.targetShield = { attempted = false, timer = 77 }

    local cleared = boop.targets.onShieldDownTrigger({
      source = "test shield trigger",
      target = { kind = "match", index = 2 },
    }, { "line", "a test denizen" }, "the shield falls away")

    assert.is_true(cleared)
    assert.is_false(boop.state.targetShield)
    assert.stub(kill_timer_stub).was_called_with(77)
  end)

  it("marks the tracked shield as attempted after a shieldbreak try", function()
    boop.state.targetShield = { attempted = false }

    boop.targets.onShieldbreakAttempt()

    assert.is_true(boop.state.targetShield.attempted)
    assert.is_number(boop.state.targetShield.lastAttempt)
  end)
end)
