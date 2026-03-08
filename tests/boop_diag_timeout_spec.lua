local helper = dofile(os.getenv("TESTS_DIRECTORY") .. "/support/boop_test_helper.lua")

describe("boop diagnose timeout", function()
  local send_stub
  local timer_stub
  local kill_timer_stub
  local warn_stub
  local timeout_callback

  before_each(function()
    helper.reset()
    timeout_callback = nil

    boop.config.diagTimeoutSeconds = 8

    send_stub = stub(_G, "send", function(_, _) end)
    timer_stub = stub(_G, "tempTimer", function(_, callback)
      timeout_callback = callback
      return 321
    end)
    kill_timer_stub = stub(_G, "killTimer", function(_) end)
    warn_stub = stub(boop.util, "warn", function(_) end)
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
    if warn_stub then
      warn_stub:revert()
      warn_stub = nil
    end
  end)

  it("resumes attacks if diagnose confirmation never arrives before the timeout", function()
    boop.ui.diag()

    assert.is_true(boop.state.diagHold)
    assert.is_false(boop.state.diagAwaitPrompt)
    assert.are.equal(321, boop.state.diagTimeoutTimer)
    assert.is_function(timeout_callback)

    timeout_callback()

    assert.is_false(boop.state.diagHold)
    assert.is_false(boop.state.diagAwaitPrompt)
    assert.is_nil(boop.state.diagTimeoutTimer)
    assert.stub(warn_stub).was_called_with("diag timeout; attacks resumed")
  end)
end)
