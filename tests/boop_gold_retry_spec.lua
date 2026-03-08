local helper = dofile(os.getenv("TESTS_DIRECTORY") .. "/support/boop_test_helper.lua")

describe("boop gold retry handling", function()
  local send_stub
  local err_stub

  before_each(function()
    helper.reset()
    send_stub = stub(_G, "send", function(_, _) end)
    err_stub = stub(boop.util, "err", function(_) end)
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
  end)

  it("retries a failed gold get command up to the retry limit", function()
    boop.state.goldGetPending = true

    boop.onGoldCommandFailure("missing sovereigns")

    assert.stub(send_stub).was_called_with("queue add freestand get sovereigns", false)
    assert.are.equal(1, boop.state.goldGetRetries)
    assert.is_true(boop.state.goldGetPending)
  end)

  it("gives up on gold get after the retry limit is reached", function()
    boop.state.goldGetPending = true
    boop.state.goldGetRetries = 2

    boop.onGoldCommandFailure("still missing sovereigns")

    assert.is_false(boop.state.goldGetPending)
    assert.stub(err_stub).was_called_with("auto gold: unable to get sovereigns; check room loot/line timing")
  end)

  it("retries a failed gold put command once for the configured pack", function()
    boop.state.goldPutPending = true
    boop.state.goldPackTarget = "pack"

    boop.onGoldCommandFailure("pack closed")

    assert.stub(send_stub).was_called_with("queue add freestand put sovereigns in pack", false)
    assert.are.equal(1, boop.state.goldPutRetries)
    assert.is_true(boop.state.goldPutPending)
  end)
end)
