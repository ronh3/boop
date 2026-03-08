local helper = dofile(os.getenv("TESTS_DIRECTORY") .. "/support/boop_test_helper.lua")

describe("boop diagnose pause and resume", function()
  local send_stub
  local timer_stub
  local kill_timer_stub

  before_each(function()
    helper.reset()
    helper.setArea("Test Area")
    helper.setClass("Occultist")
    helper.setTarget("42", "a test denizen", "80%")
    helper.setDenizens({
      { id = "42", name = "a test denizen" },
    })
    helper.learnSkill("Lycantha", "Domination")
    boop.config.enabled = true
    boop.config.attackMode = "simple"
    boop.config.targetingMode = "auto"
    boop.config.diagTimeoutSeconds = 8

    timer_stub = stub(_G, "tempTimer", function(_, _)
      return 1
    end)
    kill_timer_stub = stub(_G, "killTimer", function(_) end)
    send_stub = stub(_G, "send", function(_, _) end)
  end)

  after_each(function()
    if send_stub then
      send_stub:revert()
      send_stub = nil
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

  it("queues diagnose and pauses attacks while on hold", function()
    boop.ui.diag()

    assert.is_true(boop.state.diagHold)
    assert.is_false(boop.state.diagAwaitPrompt)
    assert.stub(send_stub).was_called_with("queue clear", false)
    assert.stub(send_stub).was_called_with("queue addclearfull freestand diagnose", false)

    boop.tick()

    assert.is_true(boop.state.diagHold)
    assert.is_false(boop.state.attacking)
  end)

  it("resumes attacks after the diagnose line and prompt", function()
    boop.ui.diag()
    boop.onDiagReadyLine()

    assert.is_true(boop.state.diagAwaitPrompt)

    boop.onPrompt()

    assert.is_false(boop.state.diagHold)
    assert.is_false(boop.state.diagAwaitPrompt)
    assert.stub(send_stub).was_called_with("command hound at 42", false)
  end)
end)
