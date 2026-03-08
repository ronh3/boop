local helper = dofile(os.getenv("TESTS_DIRECTORY") .. "/support/boop_test_helper.lua")

describe("boop rage ingestion", function()
  local send_stub
  local timer_stub
  local kill_timer_stub
  local epoch_stub
  local info_stub
  local restore_callback

  before_each(function()
    helper.reset()
    restore_callback = nil

    send_stub = stub(_G, "send", function(_, _) end)
    timer_stub = stub(_G, "tempTimer", function(_, callback)
      restore_callback = callback
      return 45
    end)
    kill_timer_stub = stub(_G, "killTimer", function(_) end)
    info_stub = stub(boop.util, "info", function(_) end)
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
    if epoch_stub then
      epoch_stub:revert()
      epoch_stub = nil
    end
    if info_stub then
      info_stub:revert()
      info_stub = nil
    end
  end)

  it("marks rage abilities unavailable on use and restores them after the fallback timer", function()
    boop.config.rageFallbackSeconds = 12
    boop.rage.setReady("harry", true)

    boop.rage.onRageUsed({ name = "Harry" })

    assert.is_false(boop.state.rageReady.harry)
    assert.are.equal(45, boop.state.rageTimers.harry)
    assert.is_function(restore_callback)

    restore_callback()

    assert.is_true(boop.state.rageReady.harry)
    assert.is_nil(boop.state.rageTimers.harry)
  end)

  it("records rage samples and computes gain rate and eta from them", function()
    local ticks = { 100, 105, 110 }
    local idx = 0
    epoch_stub = stub(_G, "getEpoch", function()
      idx = idx + 1
      return ticks[idx] or ticks[#ticks]
    end)

    boop.rage.onRageObserved(10)
    boop.rage.onRageObserved(16)
    boop.rage.onRageObserved(22)

    assert.are.equal(1.2, boop.rage.getGainRate(20))
    assert.are.equal(10, boop.rage.etaToRage(34, 22, 20))
  end)

  it("tracks matching rage affliction add and remove triggers and sends party callouts", function()
    helper.setTarget("42", "a test denizen", "80%")

    boop.rage.onAfflictionTrigger({
      mode = "add",
      affs = { "Stunned" },
      target = { kind = "match", index = 2 },
      source = "test add",
    }, { "line", "a test denizen" }, "add line")

    assert.is_true(boop.afflictions.hasTarget("stun"))
    assert.stub(send_stub).was_called_with("pt 42: stun", false)

    boop.rage.onAfflictionTrigger({
      mode = "remove",
      affs = { "Stunned" },
      target = { kind = "match", index = 2 },
      source = "test remove",
    }, { "line", "a test denizen" }, "remove line")

    assert.is_false(boop.afflictions.hasTarget("stun"))
    assert.stub(send_stub).was_called_with("pt 42: stun down", false)
  end)

  it("ignores rage affliction triggers for other targets", function()
    helper.setTarget("42", "a test denizen", "80%")

    boop.rage.onAfflictionTrigger({
      mode = "add",
      affs = { "Stunned" },
      target = { kind = "match", index = 2 },
    }, { "line", "a different denizen" }, "other target line")

    assert.is_false(boop.afflictions.hasTarget("stun"))
    assert.stub(send_stub).was_not_called()
  end)

  it("does not process rage affliction triggers while boop is disabled", function()
    helper.setTarget("42", "a test denizen", "80%")
    boop.config.enabled = false

    boop.rage.onAfflictionTrigger({
      mode = "add",
      affs = { "Stunned" },
      target = { kind = "match", index = 2 },
    }, { "line", "a test denizen" }, "disabled line")

    assert.is_false(boop.afflictions.hasTarget("stun"))
    assert.stub(send_stub).was_not_called()
  end)
end)
