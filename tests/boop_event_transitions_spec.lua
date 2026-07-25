local helper = dofile(os.getenv("TESTS_DIRECTORY") .. "/support/boop_test_helper.lua")

describe("boop event-driven state transitions", function()
  local send_stub
  local send_gmcp_stub
  local timer_stub
  local kill_timer_stub
  local request_supports_stub
  local set_target_stub
  local saved_get_epoch
  local scheduled_callback
  local fake_epoch

  before_each(function()
    helper.reset()
    scheduled_callback = nil
    fake_epoch = 1000000

    send_stub = stub(_G, "send", function(_, _) end)
    send_gmcp_stub = stub(_G, "sendGMCP", function(_) end)
    timer_stub = stub(_G, "tempTimer", function(_, callback)
      scheduled_callback = callback
      return 99
    end)
    kill_timer_stub = stub(_G, "killTimer", function(_) end)
    saved_get_epoch = _G.getEpoch
    _G.getEpoch = function()
      return fake_epoch
    end
  end)

  after_each(function()
    _G.getEpoch = saved_get_epoch
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
    if request_supports_stub then
      request_supports_stub:revert()
      request_supports_stub = nil
    end
    if set_target_stub then
      set_target_stub:revert()
      set_target_stub = nil
    end
  end)

  local function stubCoreSupports()
    local calls = {}
    request_supports_stub = stub(boop, "requestCoreSupports", function(opts)
      calls[#calls + 1] = opts or {}
      return true
    end)
    return calls
  end

  local function blockerSnapshot()
    assert.is_function(boop.runtime.blockerSnapshot)
    return boop.runtime.blockerSnapshot()
  end

  local missingIreCases = {
    {
      name = "gmcp.IRE is missing",
      seed = function()
        gmcp.IRE = nil
      end,
    },
    {
      name = "both requested IRE modules are missing",
      seed = function()
        gmcp.IRE.Target = nil
        gmcp.IRE.Display = nil
      end,
    },
  }

  for _, entry in ipairs(missingIreCases) do
    local case = entry
    it("creates one owned GMCP recovery blocker when " .. case.name, function()
      local support_calls = stubCoreSupports()
      boop.config.enabled = true
      case.seed()

      boop.onCharStatus()

      assert.are.equal(1, #support_calls)
      assert.is_true(support_calls[1].requestSkills)

      local blocker = blockerSnapshot()
      assert.are.equal("gmcp_ire_missing", blocker.code)
      assert.are.equal("GMCP IRE missing", blocker.label)
      assert.is_true(blocker.systems.target)
      assert.is_true(blocker.systems.combat)
      assert.is_true(blocker.systems.queue)
      assert.is_true(blocker.systems.gold)
      assert.is_true(blocker.systems.walk)
      assert.is_true(blocker.waitsFor.gmcp)
      assert.is_true(blocker.waitsFor.prompt)
      assert.is_false(blocker.observed.ire)
      assert.is_true(boop.runtime.shouldHold("target"))
      assert.is_true(boop.runtime.shouldHold("combat"))
      assert.is_true(boop.runtime.shouldHold("queue"))
      assert.is_true(boop.runtime.shouldHold("gold"))
      assert.is_true(boop.runtime.shouldHold("walk"))
    end)
  end

  it("accepts IRE.Display as readiness evidence before IRE.Target emits data", function()
    local support_calls = stubCoreSupports()
    boop.config.enabled = true
    gmcp.IRE = {
      Display = {
        ButtonActions = {},
      },
      Rift = {
        Change = {
          amount = "1142",
          name = "quartz",
        },
      },
    }

    boop.onCharStatus()

    assert.are.equal(0, #support_calls)
    assert.are.equal("", blockerSnapshot().code)
  end)

  it("accepts IRE.Target as readiness evidence when IRE.Display has not emitted data", function()
    local support_calls = stubCoreSupports()
    boop.config.enabled = true
    gmcp.IRE.Display = nil

    boop.onCharStatus()

    assert.are.equal(0, #support_calls)
    assert.are.equal("", blockerSnapshot().code)
  end)

  it("retries missing IRE support immediately once, then throttles repeats until backoff expires", function()
    local support_calls = stubCoreSupports()
    boop.config.enabled = true
    gmcp.IRE.Target = nil
    gmcp.IRE.Display = nil

    boop.onCharStatus()
    boop.onCharStatus()

    assert.are.equal(1, #support_calls)

    fake_epoch = fake_epoch + 2500
    boop.onCharStatus()

    assert.are.equal(2, #support_calls)
  end)

  it("clears the GMCP recovery blocker after one requested IRE module and a prompt have arrived", function()
    stubCoreSupports()
    boop.config.enabled = true
    gmcp.IRE = nil

    boop.onCharStatus()
    assert.are.equal("gmcp_ire_missing", blockerSnapshot().code)

    gmcp.IRE = {
      Display = {
        ButtonActions = {},
      },
    }
    boop.onCharStatus()

    assert.are.equal("gmcp_ire_missing", blockerSnapshot().code)

    boop.onPrompt()

    assert.are.equal("", blockerSnapshot().code)
    assert.is_false(boop.runtime.shouldHold("target"))
    assert.is_false(boop.runtime.shouldHold("combat"))
  end)

  it("preserves an observed prompt across repeated missing IRE checks", function()
    stubCoreSupports()
    boop.config.enabled = true
    gmcp.IRE = nil

    boop.onCharStatus()
    boop.onPrompt()
    assert.is_true(blockerSnapshot().promptSeen)

    boop.onCharStatus()
    assert.is_true(blockerSnapshot().promptSeen)

    gmcp.IRE = {
      Display = {
        ButtonActions = {},
      },
    }
    boop.onCharStatus()

    assert.are.equal("", blockerSnapshot().code)
  end)

  it("creates owned room blockers for missing or partial room state", function()
    boop.config.enabled = true
    gmcp.Room.Info = nil

    boop.onRoomInfo()

    local missing = blockerSnapshot()
    assert.are.equal("missing_room", missing.code)
    assert.are.equal("missing room state", missing.label)
    assert.is_true(missing.systems.target)
    assert.is_true(missing.systems.combat)
    assert.is_true(missing.systems.walk)
    assert.is_true(missing.waitsFor.gmcp)

    gmcp.Room.Info = {
      num = 101,
      area = "Test Area",
    }
    boop.onRoomInfo()

    local partial = blockerSnapshot()
    assert.are.equal("room_partial", partial.code)
    assert.are.equal("partial room state", partial.label)
    assert.is_true(partial.systems.walk)
    assert.is_true(partial.waitsFor.gmcp)
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

  it("clears stale attack intent before same-tick retargeting from valid current-room denizens", function()
    helper.setArea("Test Area")
    helper.setClass("Occultist")
    helper.learnSkill("Lycantha", "Domination")
    gmcp.Char.Items.List = {
      location = "room",
      items = {
        { id = "42", name = "a first denizen", attrib = "m" },
        { id = "43", name = "an excluded denizen", attrib = "mx" },
        { id = "44", name = "a valid replacement", attrib = "m" },
      },
    }
    boop.onRoomItemsList()
    helper.setTarget("42", "a first denizen", "80%")
    helper.addTargetAfflictions({ "stupidity" })

    local state = helper.seedAutomationIntent()
    boop.config.enabled = true
    boop.config.useQueueing = true
    boop.config.targetingMode = "auto"
    state.targeting.calledTargetId = "42"
    state.targeting.targetName = "a first denizen"
    state.queue.aliasDirty = false

    local retarget_id = nil
    set_target_stub = stub(boop.targets, "setTarget", function(id)
      retarget_id = tostring(id or "")
      assert.are.equal("", boop.state.targeting.currentTargetId)
      assert.are.equal("", boop.state.targeting.targetName)
      assert.are.equal("", boop.state.targeting.calledTargetId)
      assert.are.equal("", boop.state.targeting.calledTargetRoom)
      assert.are.equal("", boop.state.targeting.calledTargetBy)
      assert.is_false(boop.state.queue.prequeuedStandard)
      assert.are.equal("", boop.state.queue.aliasAction)
      assert.is_true(boop.state.queue.aliasDirty)
      assert.is_nil(boop.state.combat.pendingStandard)
      assert.is_nil(boop.state.combat.pendingRage)
      assert.is_nil(boop.state.combat.attackPlan)
      assert.is_false(boop.afflictions.hasTarget("stupidity"))
    end)

    gmcp.Char.Items.Remove = {
      location = "room",
      item = { id = "42", name = "a first denizen", attrib = "m" },
    }

    boop.onRoomItemsRemove()

    assert.are.equal("44", retarget_id)
    assert.stub(send_stub).was_not_called_with("settarget 43", false)
  end)

  it("preserves active pull target state as the narrow target-loss exception", function()
    helper.setTarget("42", "a pulled denizen", "80%")
    helper.setDenizens({
      { id = "42", name = "a pulled denizen" },
    })
    boop.config.enabled = false
    boop.state.combat.pullState = {
      active = true,
      phase = "away",
      originRoom = "1",
      restoreEnabled = true,
    }
    boop.state.queue.prequeuedStandard = true
    boop.state.queue.aliasAction = "command hound at 42"
    boop.state.queue.aliasDirty = false

    gmcp.Char.Items.Remove = {
      location = "room",
      item = { id = "42", name = "a pulled denizen", attrib = "m" },
    }

    boop.onRoomItemsRemove()

    assert.are.equal("42", boop.state.targeting.currentTargetId)
    assert.are.equal("a pulled denizen", boop.state.targeting.targetName)
    assert.is_truthy(boop.state.combat.pullState)
    assert.are.equal("away", boop.state.combat.pullState.phase)
    assert.is_true(boop.state.queue.prequeuedStandard)
    assert.are.equal("command hound at 42", boop.state.queue.aliasAction)
    assert.is_false(boop.state.queue.aliasDirty)
  end)

  it("clears tracked shield state when gmcp target set changes", function()
    helper.setDenizens({
      { id = "77", name = "a game-selected denizen" },
    })
    helper.setTarget("42", "a test denizen", "80%")
    boop.state.targeting.targetShield = { attempted = false, timer = 55 }
    gmcp.IRE.Target.Set = "77"

    boop.onTargetSet()

    assert.are.equal("77", boop.state.targeting.currentTargetId)
    assert.are.equal("a game-selected denizen", boop.state.targeting.targetName)
    assert.is_false(boop.state.targeting.targetShield)
    assert.stub(kill_timer_stub).was_called_with(55)
    assert.stub(send_stub).was_not_called_with("settarget 77", false)
  end)

  it("clears tracked shield state when gmcp target info changes", function()
    helper.setTarget("42", "a test denizen", "80%")
    boop.state.targeting.targetShield = { attempted = false, timer = 56 }
    gmcp.IRE.Target.Info.id = "78"
    gmcp.IRE.Target.Info.short_desc = "a target-info denizen"

    boop.onTargetInfo()

    assert.are.equal("78", boop.state.targeting.currentTargetId)
    assert.are.equal("a target-info denizen", boop.state.targeting.targetName)
    assert.is_false(boop.state.targeting.targetShield)
    assert.stub(kill_timer_stub).was_called_with(56)
    assert.stub(send_stub).was_not_called_with("settarget 78", false)
  end)

  it("clears stale target name when gmcp target set clears", function()
    helper.setTarget("42", "a test denizen", "80%")
    boop.state.targeting.targetShield = { attempted = false, timer = 58 }
    gmcp.IRE.Target.Set = ""

    boop.onTargetSet()

    assert.are.equal("", boop.state.targeting.currentTargetId)
    assert.are.equal("", boop.state.targeting.targetName)
    assert.is_false(boop.state.targeting.targetShield)
    assert.stub(kill_timer_stub).was_called_with(58)
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
