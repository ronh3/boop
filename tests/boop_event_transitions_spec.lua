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

  it("retargets without clearing the server queue when the current denizen is removed from the room", function()
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
    boop.state.targeting.targetShield = { attempted = false, timer = 77 }

    gmcp.Char.Items.Remove = {
      location = "room",
      item = { id = "42", name = "a first denizen", attrib = "m" },
    }

    boop.onRoomItemsRemove()

    assert.are.equal("43", boop.state.targeting.currentTargetId)
    assert.are.equal("a second denizen", boop.state.targeting.targetName)
    assert.is_false(boop.state.targeting.targetShield)
    assert.is_false(boop.afflictions.hasTarget("stupidity"))
    assert.is_function(scheduled_callback)
    assert.stub(kill_timer_stub).was_called_with(77)
    assert.stub(send_stub).was_called_with("settarget 43", false)
    assert.stub(send_stub).was_not_called_with("queue clear", false)

    scheduled_callback()

    assert.stub(send_stub).was_called_with("setalias BOOP_ATTACK command hound at 43", false)
    assert.stub(send_stub).was_called_with("queue addclearfull freestand BOOP_ATTACK", false)
  end)

  it("clears tracked shield state when gmcp target set changes", function()
    helper.setTarget("42", "a test denizen", "80%")
    boop.state.targeting.targetShield = { attempted = false, timer = 55 }
    gmcp.IRE.Target.Set = "77"

    boop.onTargetSet()

    assert.are.equal("77", boop.state.targeting.currentTargetId)
    assert.is_false(boop.state.targeting.targetShield)
    assert.stub(kill_timer_stub).was_called_with(55)
  end)

  it("clears tracked shield state when gmcp target info changes", function()
    helper.setTarget("42", "a test denizen", "80%")
    boop.state.targeting.targetShield = { attempted = false, timer = 56 }
    gmcp.IRE.Target.Info.id = "78"

    boop.onTargetInfo()

    assert.are.equal("78", boop.state.targeting.currentTargetId)
    assert.is_false(boop.state.targeting.targetShield)
    assert.stub(kill_timer_stub).was_called_with(56)
  end)

  it("clears gold intent and remembers the return exit when the room changes", function()
    boop.state.targeting.room = 100
    boop.state.combat.fleeing = false
    boop.state.targeting.targetShield = { attempted = false, timer = 57 }
    boop.state.gold.getPending = true
    boop.state.gold.putPending = true
    boop.state.gold.getRetries = 1
    boop.state.gold.putRetries = 1
    boop.state.gold.packTarget = "pack"

    gmcp.Room.Info.num = 200
    gmcp.Room.Info.exits = {
      north = 100,
      south = 300,
    }

    boop.onRoomInfo()

    assert.is_true(boop.state.targeting.movedRooms)
    assert.are.equal(100, boop.state.targeting.lastRoom)
    assert.are.equal("north", boop.state.targeting.lastRoomDir)
    assert.are.equal(200, boop.state.targeting.room)
    assert.is_false(boop.state.targeting.targetShield)
    assert.is_false(boop.state.gold.getPending)
    assert.is_false(boop.state.gold.putPending)
    assert.are.equal(0, boop.state.gold.getRetries)
    assert.are.equal(0, boop.state.gold.putRetries)
    assert.are.equal("", boop.state.gold.packTarget)
    assert.stub(kill_timer_stub).was_called_with(57)
  end)

  it("clears stale gold state if room sovereigns disappear mid-handling", function()
    boop.config.enabled = true
    boop.state.gold.autoGrabPending = true
    boop.state.gold.autoGrabPendingAt = 1
    boop.state.gold.dropped = true
    boop.state.gold.getPending = true
    boop.state.gold.putPending = true
    boop.state.gold.packTarget = "pack"

    gmcp.Char.Items.Remove = {
      location = "room",
      item = { id = "99", name = "some gold sovereigns" },
    }

    boop.onRoomItemsRemove()

    assert.is_false(boop.state.gold.autoGrabPending)
    assert.is_nil(boop.state.gold.autoGrabPendingAt)
    assert.is_false(boop.state.gold.getPending)
    assert.is_false(boop.state.gold.putPending)
    assert.are.equal("", boop.state.gold.packTarget)
  end)

  it("re-announces core gmcp supports on connection-ready events", function()
    boop.onConnectionEvent()

    assert.stub(send_gmcp_stub).was_called_with('Core.Supports.Add ["IRE.Target 1"]')
    assert.stub(send_gmcp_stub).was_called_with('Core.Supports.Add ["IRE.Display 3"]')
    assert.stub(send_gmcp_stub).was_called_with('Core.Supports.Add ["Char.Skills 1"]')
    assert.stub(send_gmcp_stub).was_called_with([[Char.Skills.Get]])
  end)

  it("retries core gmcp support negotiation when char status arrives before IRE gmcp is active", function()
    gmcp.IRE = nil
    gmcp.Char.Status.class = "Occultist"

    boop.onCharStatus()

    assert.stub(send_gmcp_stub).was_called_with('Core.Supports.Add ["IRE.Target 1"]')
    assert.stub(send_gmcp_stub).was_called_with('Core.Supports.Add ["IRE.Display 3"]')
    assert.stub(send_gmcp_stub).was_called_with('Core.Supports.Add ["Char.Skills 1"]')
  end)
end)
