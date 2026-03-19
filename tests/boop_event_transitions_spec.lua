local helper = dofile(os.getenv("TESTS_DIRECTORY") .. "/support/boop_test_helper.lua")

describe("boop event-driven state transitions", function()
  local send_stub
  local send_gmcp_stub
  local timer_stub
  local kill_timer_stub
  local scheduled_callback

  before_each(function()
    helper.reset()
    scheduled_callback = nil

    send_stub = stub(_G, "send", function(_, _) end)
    send_gmcp_stub = stub(_G, "sendGMCP", function(_) end)
    timer_stub = stub(_G, "tempTimer", function(_, callback)
      scheduled_callback = callback
      return 99
    end)
    kill_timer_stub = stub(_G, "killTimer", function(_) end)
  end)

  after_each(function()
    if send_stub then
      send_stub:revert()
      send_stub = nil
    end
    if send_gmcp_stub then
      send_gmcp_stub:revert()
      send_gmcp_stub = nil
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

  it("retargets and clears queued state when the current denizen is removed from the room", function()
    helper.setArea("Test Area")
    helper.setClass("Occultist")
    helper.learnSkill("Lycantha", "Domination")
    helper.setDenizens({
      { id = "42", name = "a first denizen" },
      { id = "43", name = "a second denizen" },
    })
    helper.setTarget("42", "a first denizen", "80%")
    helper.addTargetAfflictions({ "stupidity" })

    boop.config.enabled = true
    boop.config.useQueueing = true
    boop.config.targetingMode = "auto"
    boop.state.targetShield = { attempted = false, timer = 77 }

    gmcp.Char.Items.Remove = {
      location = "room",
      item = { id = "42", name = "a first denizen", attrib = "m" },
    }

    boop.onRoomItemsRemove()

    assert.are.equal("43", boop.state.currentTargetId)
    assert.are.equal("a second denizen", boop.state.targetName)
    assert.is_false(boop.state.targetShield)
    assert.is_false(boop.afflictions.hasTarget("stupidity"))
    assert.is_function(scheduled_callback)
    assert.stub(kill_timer_stub).was_called_with(77)
    assert.stub(send_stub).was_called_with("queue clear", false)
    assert.stub(send_stub).was_called_with("settarget 43", false)

    scheduled_callback()

    assert.stub(send_stub).was_called_with("setalias BOOP_ATTACK command hound at 43", false)
    assert.stub(send_stub).was_called_with("queue addclearfull freestand BOOP_ATTACK", false)
  end)

  it("clears tracked shield state when gmcp target set changes", function()
    helper.setTarget("42", "a test denizen", "80%")
    boop.state.targetShield = { attempted = false, timer = 55 }
    gmcp.IRE.Target.Set = "77"

    boop.onTargetSet()

    assert.are.equal("77", boop.state.currentTargetId)
    assert.is_false(boop.state.targetShield)
    assert.stub(kill_timer_stub).was_called_with(55)
  end)

  it("clears tracked shield state when gmcp target info changes", function()
    helper.setTarget("42", "a test denizen", "80%")
    boop.state.targetShield = { attempted = false, timer = 56 }
    gmcp.IRE.Target.Info.id = "78"

    boop.onTargetInfo()

    assert.are.equal("78", boop.state.currentTargetId)
    assert.is_false(boop.state.targetShield)
    assert.stub(kill_timer_stub).was_called_with(56)
  end)

  it("clears gold intent and remembers the return exit when the room changes", function()
    boop.state.room = 100
    boop.state.fleeing = false
    boop.state.targetShield = { attempted = false, timer = 57 }
    boop.state.goldGetPending = true
    boop.state.goldPutPending = true
    boop.state.goldGetRetries = 1
    boop.state.goldPutRetries = 1
    boop.state.goldPackTarget = "pack"

    gmcp.Room.Info.num = 200
    gmcp.Room.Info.exits = {
      north = 100,
      south = 300,
    }

    boop.onRoomInfo()

    assert.is_true(boop.state.movedRooms)
    assert.are.equal(100, boop.state.lastRoom)
    assert.are.equal("north", boop.state.lastRoomDir)
    assert.are.equal(200, boop.state.room)
    assert.is_false(boop.state.targetShield)
    assert.is_false(boop.state.goldGetPending)
    assert.is_false(boop.state.goldPutPending)
    assert.are.equal(0, boop.state.goldGetRetries)
    assert.are.equal(0, boop.state.goldPutRetries)
    assert.are.equal("", boop.state.goldPackTarget)
    assert.stub(kill_timer_stub).was_called_with(57)
  end)

  it("clears stale gold state if room sovereigns disappear mid-handling", function()
    boop.config.enabled = true
    boop.state.autoGrabGoldPending = true
    boop.state.autoGrabGoldPendingAt = 1
    boop.state.goldDropped = true
    boop.state.goldGetPending = true
    boop.state.goldPutPending = true
    boop.state.goldPackTarget = "pack"

    gmcp.Char.Items.Remove = {
      location = "room",
      item = { id = "99", name = "some gold sovereigns" },
    }

    boop.onRoomItemsRemove()

    assert.is_false(boop.state.autoGrabGoldPending)
    assert.is_nil(boop.state.autoGrabGoldPendingAt)
    assert.is_false(boop.state.goldGetPending)
    assert.is_false(boop.state.goldPutPending)
    assert.are.equal("", boop.state.goldPackTarget)
  end)
end)
