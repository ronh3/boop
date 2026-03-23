local helper = dofile(os.getenv("TESTS_DIRECTORY") .. "/support/boop_test_helper.lua")

describe("boop queued interrupts", function()
  local send_stub
  local timer_stub
  local kill_timer_stub
  local warn_stub
  local timeout_callback

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

    timeout_callback = nil
    timer_stub = stub(_G, "tempTimer", function(_, callback)
      timeout_callback = callback
      return 222
    end)
    kill_timer_stub = stub(_G, "killTimer", function(_) end)
    send_stub = stub(_G, "send", function(_, _) end)
    warn_stub = stub(boop.util, "warn", function(_) end)
  end)

  after_each(function()
    if send_stub then send_stub:revert() send_stub = nil end
    if timer_stub then timer_stub:revert() timer_stub = nil end
    if kill_timer_stub then kill_timer_stub:revert() kill_timer_stub = nil end
    if warn_stub then warn_stub:revert() warn_stub = nil end
  end)

  it("queues matic on the attack queue and resumes after the next prompt", function()
    boop.ui.matic()

    assert.is_true(boop.state.diagHold)
    assert.is_true(boop.state.diagAwaitPrompt)
    assert.are.equal("matic", boop.state.diagLabel)
    assert.stub(send_stub).was_called_with("queue addclearfull freestand ldeck draw matic", false)

    boop.onPrompt()

    assert.is_false(boop.state.diagHold)
    assert.is_false(boop.state.diagAwaitPrompt)
    assert.are.equal("", boop.state.diagLabel)
    assert.stub(send_stub).was_called_with("command hound at 42", false)
  end)

  it("resumes attacks if matic never completes before the timeout", function()
    boop.ui.matic()

    assert.are.equal(222, boop.state.diagTimeoutTimer)
    assert.is_function(timeout_callback)

    timeout_callback()

    assert.is_false(boop.state.diagHold)
    assert.is_false(boop.state.diagAwaitPrompt)
    assert.are.equal("", boop.state.diagLabel)
    assert.is_nil(boop.state.diagTimeoutTimer)
    assert.stub(warn_stub).was_called_with("matic timeout; attacks resumed")
  end)

  it("queues catarin on the attack queue and resumes after the next prompt", function()
    boop.ui.catarin()

    assert.is_true(boop.state.diagHold)
    assert.is_true(boop.state.diagAwaitPrompt)
    assert.are.equal("catarin", boop.state.diagLabel)
    assert.stub(send_stub).was_called_with("queue addclearfull freestand ldeck draw catarin", false)

    boop.onPrompt()

    assert.is_false(boop.state.diagHold)
    assert.is_false(boop.state.diagAwaitPrompt)
    assert.are.equal("", boop.state.diagLabel)
    assert.stub(send_stub).was_called_with("command hound at 42", false)
  end)

  it("queues fly on the attack queue and resumes after the next prompt", function()
    boop.ui.fly()

    assert.is_true(boop.state.diagHold)
    assert.is_true(boop.state.diagAwaitPrompt)
    assert.are.equal("fly", boop.state.diagLabel)
    assert.stub(send_stub).was_called_with("queue addclearfull freestand fly", false)

    boop.onPrompt()

    assert.is_false(boop.state.diagHold)
    assert.is_false(boop.state.diagAwaitPrompt)
    assert.are.equal("", boop.state.diagLabel)
    assert.stub(send_stub).was_called_with("command hound at 42", false)
  end)

  it("queues leap on the attack queue and resumes after the next prompt", function()
    boop.ui.leap("north")

    assert.is_true(boop.state.diagHold)
    assert.is_true(boop.state.diagAwaitPrompt)
    assert.are.equal("leap", boop.state.diagLabel)
    assert.stub(send_stub).was_called_with("queue addclearfull freestand leap north", false)

    boop.onPrompt()

    assert.is_false(boop.state.diagHold)
    assert.is_false(boop.state.diagAwaitPrompt)
    assert.are.equal("", boop.state.diagLabel)
    assert.stub(send_stub).was_called_with("command hound at 42", false)
  end)
end)
