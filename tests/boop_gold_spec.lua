local helper = dofile(os.getenv("TESTS_DIRECTORY") .. "/support/boop_test_helper.lua")

describe("boop gold handling", function()
  local send_stub
  local timer_stub
  local kill_timer_stub

  before_each(function()
    helper.reset()
    boop.config.enabled = true
    boop.config.autoGrabGold = true

    send_stub = stub(_G, "send", function(_, _) end)
    timer_stub = stub(_G, "tempTimer", function(_, _)
      return 1
    end)
    kill_timer_stub = stub(_G, "killTimer", function(_) end)
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

  it("queues immediate get and put commands when queueing is disabled", function()
    boop.config.useQueueing = false
    boop.config.goldPack = "pack"

    boop.onGoldDropLine("A handful of sovereigns spills onto the ground.")

    assert.stub(send_stub).was_called_with("queue add freestand get sovereigns", false)
    assert.stub(send_stub).was_called_with("queue add freestand put sovereigns in pack", false)
    assert.is_true(boop.state.goldGetPending)
    assert.is_true(boop.state.goldPutPending)
    assert.are.equal("pack", boop.state.goldPackTarget)
  end)

  it("flushes pending gold when tick finds no target under queueing", function()
    boop.config.useQueueing = true
    boop.config.goldPack = "pack"
    boop.state.autoGrabGoldPending = true
    boop.state.goldDropped = true

    boop.tick()

    assert.stub(send_stub).was_called_with("queue add freestand get sovereigns", false)
    assert.stub(send_stub).was_called_with("queue add freestand put sovereigns in pack", false)
    assert.is_false(boop.state.autoGrabGoldPending)
    assert.is_false(boop.state.goldDropped)
    assert.is_true(boop.state.goldGetPending)
    assert.is_true(boop.state.goldPutPending)
  end)
end)
