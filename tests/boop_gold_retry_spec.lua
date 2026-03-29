local helper = dofile(os.getenv("TESTS_DIRECTORY") .. "/support/boop_test_helper.lua")

describe("boop gold retry handling", function()
  local send_stub
  local err_stub
  local warn_stub
  local timer_stub
  local kill_timer_stub
  local scheduled

  before_each(function()
    helper.reset()
    scheduled = {}
    send_stub = stub(_G, "send", function(_, _) end)
    err_stub = stub(boop.util, "err", function(_) end)
    warn_stub = stub(boop.util, "warn", function(_) end)
    timer_stub = stub(_G, "tempTimer", function(_, callback)
      scheduled[#scheduled + 1] = callback
      return #scheduled
    end)
    kill_timer_stub = stub(_G, "killTimer", function(_) end)
  end)

  after_each(function()
    if send_stub then
      send_stub:revert()
      send_stub = nil
    end
    if err_stub then
      err_stub:revert()
      err_stub = nil
    end
    if warn_stub then
      warn_stub:revert()
      warn_stub = nil
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

  it("retries a failed gold get command up to the retry limit", function()
    boop.state.gold.getPending = true

    boop.onGoldCommandFailure("missing sovereigns")

    assert.stub(send_stub).was_called_with("queue add balance get sovereigns", false)
    assert.are.equal(1, boop.state.gold.getRetries)
    assert.is_true(boop.state.gold.getPending)
  end)

  it("gives up on gold get after the retry limit is reached", function()
    boop.state.gold.getPending = true
    boop.state.gold.getRetries = 2
    boop.state.gold.putPending = true
    boop.state.gold.packTarget = "pack"

    boop.onGoldCommandFailure("still missing sovereigns")

    assert.is_false(boop.state.gold.getPending)
    assert.is_false(boop.state.gold.putPending)
    assert.are.equal("", boop.state.gold.packTarget)
    assert.stub(err_stub).was_called_with("auto gold: unable to get sovereigns; check room loot/line timing")
  end)

  it("retries a failed gold put command once for the configured pack", function()
    boop.state.gold.putPending = true
    boop.state.gold.packTarget = "pack"

    boop.onGoldCommandFailure("pack closed")

    assert.stub(send_stub).was_called_with("queue add balance put sovereigns in pack", false)
    assert.are.equal(1, boop.state.gold.putRetries)
    assert.is_true(boop.state.gold.putPending)
  end)

  it("clears stale pending gold state if no completion trigger arrives", function()
    boop.markGoldQueueIntent("pack")

    assert.is_function(scheduled[1])
    scheduled[1]()

    assert.is_false(boop.state.gold.getPending)
    assert.is_false(boop.state.gold.putPending)
    assert.are.equal("", boop.state.gold.packTarget)
    assert.stub(warn_stub).was_called_with("auto gold: clearing stale pending state")
  end)
end)
