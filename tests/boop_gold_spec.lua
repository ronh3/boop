local helper = dofile(os.getenv("TESTS_DIRECTORY") .. "/support/boop_test_helper.lua")

describe("boop gold handling", function()
  local send_stub
  local timer_stub
  local kill_timer_stub
  local scheduled

  before_each(function()
    helper.reset()
    scheduled = {}
    boop.config.enabled = true
    boop.config.autoGrabGold = true

    send_stub = stub(_G, "send", function(_, _) end)
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
    if timer_stub then
      timer_stub:revert()
      timer_stub = nil
    end
    if kill_timer_stub then
      kill_timer_stub:revert()
      kill_timer_stub = nil
    end
  end)

  it("sends an immediate get command when queueing is disabled", function()
    boop.config.useQueueing = false
    boop.config.goldPack = "pack"

    boop.onGoldDropLine("A handful of sovereigns spills onto the ground.")

    assert.stub(send_stub).was_called_with("get sovereigns", false)
    assert.is_true(boop.state.goldGetPending)
    assert.is_true(boop.state.goldPutPending)
    assert.are.equal("pack", boop.state.goldPackTarget)
  end)

  it("flushes pending gold when tick finds no target under queueing", function()
    boop.config.useQueueing = true
    boop.config.goldPack = "pack"
    boop.state.autoGrabGoldPending = true
    boop.state.autoGrabGoldPendingAt = -1
    boop.state.goldDropped = true

    boop.tick()

    assert.stub(send_stub).was_called_with("get sovereigns", false)
    assert.is_false(boop.state.autoGrabGoldPending)
    assert.is_false(boop.state.goldDropped)
    assert.is_true(boop.state.goldGetPending)
    assert.is_true(boop.state.goldPutPending)
  end)

  it("flushes aged pending gold during tick even if combat is ongoing", function()
    boop.config.useQueueing = true
    boop.config.goldPack = "pack"
    boop.state.autoGrabGoldPending = true
    boop.state.autoGrabGoldPendingAt = -1
    boop.state.goldDropped = true
    helper.setClass("Occultist")
    helper.learnSkills({
      { name = "Warp", group = "Occultism" },
      { name = "harry", group = "Attainment" },
    })
    helper.setDenizens({
      { id = "42", name = "a test denizen" },
    })
    helper.setTarget("42", "a test denizen", "100%")

    boop.tick()

    assert.stub(send_stub).was_called_with("get sovereigns", false)
    assert.is_false(boop.state.autoGrabGoldPending)
    assert.is_true(boop.state.goldGetPending)
    assert.is_true(boop.state.goldPutPending)
  end)

  it("sends the put command only after a successful get", function()
    boop.state.goldGetPending = true
    boop.state.goldPutPending = true
    boop.state.goldPackTarget = "pack"

    boop.onGoldGetSuccess()

    assert.stub(send_stub).was_called_with("put sovereigns in pack", false)
    assert.is_false(boop.state.goldGetPending)
    assert.is_true(boop.state.goldPutPending)
  end)

  it("blocks queued combat and flushes gold directly when queueing sees pending gold", function()
    boop.config.useQueueing = true
    boop.config.goldPack = "pack"
    boop.state.autoGrabGoldPending = true
    boop.state.autoGrabGoldPendingAt = -1
    boop.state.goldDropped = true

    boop.executeAction("warp 42")

    assert.stub(send_stub).was_called_with("get sovereigns", false)
    assert.stub(send_stub).was_not_called_with("queue addclearfull freestand BOOP_ATTACK", false)
    assert.is_false(boop.state.autoGrabGoldPending)
    assert.is_true(boop.state.goldGetPending)
    assert.is_true(boop.state.goldPutPending)
  end)
end)
