local helper = dofile(os.getenv("TESTS_DIRECTORY") .. "/support/boop_test_helper.lua")

describe("boop event-driven state transitions", function()
  local send_stub
  local send_gmcp_stub
  local raise_event_stub
  local timer_stub
  local kill_timer_stub
  local request_supports_stub
  local set_target_stub
  local runtime_set_blocker_stub
  local runtime_clear_blocker_stub
  local runtime_note_gmcp_stub
  local tick_stub
  local flush_gold_stub
  local walk_advance_stub
  local walk_arrived_adapter_stub
  local walk_finished_adapter_stub
  local saved_get_epoch
  local scheduled_callback
  local scheduled_callbacks
  local fake_epoch
  local set_blocker_calls
  local clear_blocker_calls
  local note_gmcp_calls
  local sent_commands
  local gmcp_requests
  local raised_events
  local saved_demonwalker

  before_each(function()
    helper.reset()
    saved_demonwalker = _G.demonwalker
    scheduled_callback = nil
    scheduled_callbacks = {}
    fake_epoch = 1000000
    set_blocker_calls = {}
    clear_blocker_calls = {}
    note_gmcp_calls = {}
    sent_commands = {}
    gmcp_requests = {}
    raised_events = {}

    send_stub = stub(_G, "send", function(command, echo)
      sent_commands[#sent_commands + 1] = { command = command, echo = echo }
    end)
    send_gmcp_stub = stub(_G, "sendGMCP", function(command)
      gmcp_requests[#gmcp_requests + 1] = command
    end)
    raise_event_stub = stub(_G, "raiseEvent", function(name, ...)
      raised_events[#raised_events + 1] = { name = name, args = { ... } }
    end)
    timer_stub = stub(_G, "tempTimer", function(delay, callback)
      scheduled_callback = callback
      local id = 99 + #scheduled_callbacks
      scheduled_callbacks[#scheduled_callbacks + 1] = {
        id = id,
        delay = delay,
        callback = callback,
      }
      return id
    end)
    kill_timer_stub = stub(_G, "killTimer", function(_) end)
    saved_get_epoch = _G.getEpoch
    _G.getEpoch = function()
      return fake_epoch
    end
  end)

  after_each(function()
    _G.getEpoch = saved_get_epoch
    _G.demonwalker = saved_demonwalker
    if send_stub then
      send_stub:revert()
      send_stub = nil
    end
    if send_gmcp_stub then
      send_gmcp_stub:revert()
      send_gmcp_stub = nil
    end
    if raise_event_stub then
      raise_event_stub:revert()
      raise_event_stub = nil
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
    if runtime_note_gmcp_stub then
      runtime_note_gmcp_stub:revert()
      runtime_note_gmcp_stub = nil
    end
    if runtime_clear_blocker_stub then
      runtime_clear_blocker_stub:revert()
      runtime_clear_blocker_stub = nil
    end
    if runtime_set_blocker_stub then
      runtime_set_blocker_stub:revert()
      runtime_set_blocker_stub = nil
    end
    if walk_advance_stub then
      walk_advance_stub:revert()
      walk_advance_stub = nil
    end
    if walk_arrived_adapter_stub then
      walk_arrived_adapter_stub:revert()
      walk_arrived_adapter_stub = nil
    end
    if walk_finished_adapter_stub then
      walk_finished_adapter_stub:revert()
      walk_finished_adapter_stub = nil
    end
    if flush_gold_stub then
      flush_gold_stub:revert()
      flush_gold_stub = nil
    end
    if tick_stub then
      tick_stub:revert()
      tick_stub = nil
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

  local function countSent(command)
    local count = 0
    for _, entry in ipairs(sent_commands) do
      if entry.command == command then
        count = count + 1
      end
    end
    return count
  end

  local function countRaised(name)
    local count = 0
    for _, entry in ipairs(raised_events) do
      if entry.name == name then
        count = count + 1
      end
    end
    return count
  end

  local function countGoldSends()
    local count = 0
    for _, entry in ipairs(sent_commands) do
      if tostring(entry.command or ""):find("sovereigns", 1, true) then
        count = count + 1
      end
    end
    return count
  end

  local function callbackForTimer(timerId)
    for _, entry in ipairs(scheduled_callbacks) do
      if entry.id == timerId then
        return entry.callback
      end
    end
    return nil
  end

  local function blockerFor(owner)
    return boop.state
      and boop.state.combat
      and boop.state.combat.blockersByOwner
      and boop.state.combat.blockersByOwner[tostring(owner or "")]
      or nil
  end

  local function goldItem(id)
    return {
      id = tostring(id or "9001"),
      name = "some gold sovereigns",
      attrib = "t",
    }
  end

  local function copyGoldOperation(operation)
    if type(operation) ~= "table" then
      return operation
    end
    return {
      generation = operation.generation,
      phase = operation.phase,
      terminal = operation.terminal,
      blockerOwner = operation.blockerOwner,
      roomId = operation.roomId,
      roomGeneration = operation.roomGeneration,
      goldItemId = operation.goldItemId,
      packTarget = operation.packTarget,
      getRetries = operation.getRetries,
      putRetries = operation.putRetries,
      flushTimer = operation.flushTimer,
      timeoutTimer = operation.timeoutTimer,
    }
  end

  local function seedSettledGoldRoom(roomId, generation)
    local room = tostring(roomId or "1")
    gmcp.Room.Info = {
      num = room,
      area = "Test Area",
      exits = {},
    }
    boop.state.targeting.room = room
    helper.seedRoomObservation(room, {
      generation = generation or 1,
      infoSeen = true,
      itemsSeen = true,
    })
    gmcp.Char.Items.List = {
      location = "room",
      items = { goldItem("9001") },
    }
    boop.config.enabled = true
    boop.config.autoGrabGold = true
    boop.config.useQueueing = false
  end

  local function captureRuntimeBlockerCalls()
    local originalSetBlocker = boop.runtime.setBlocker
    local originalClearBlocker = boop.runtime.clearBlocker
    local originalNoteGmcp = boop.runtime.noteGmcpObserved
    runtime_set_blocker_stub = stub(boop.runtime, "setBlocker", function(...)
      set_blocker_calls[#set_blocker_calls + 1] = { ... }
      return originalSetBlocker(...)
    end)
    runtime_clear_blocker_stub = stub(boop.runtime, "clearBlocker", function(...)
      clear_blocker_calls[#clear_blocker_calls + 1] = { ... }
      return originalClearBlocker(...)
    end)
    runtime_note_gmcp_stub = stub(boop.runtime, "noteGmcpObserved", function(...)
      note_gmcp_calls[#note_gmcp_calls + 1] = { ... }
      return originalNoteGmcp(...)
    end)
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
      captureRuntimeBlockerCalls()

      boop.onCharStatus()

      assert.are.equal(1, #support_calls)
      assert.is_true(support_calls[1].requestSkills)

      local blocker = blockerSnapshot()
      assert.are.equal("gmcp:ire", blocker.owner)
      assert.are.equal("gmcp:ire", set_blocker_calls[1][1])
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
    captureRuntimeBlockerCalls()

    boop.onCharStatus()
    assert.are.equal("gmcp_ire_missing", blockerSnapshot().code)

    gmcp.IRE = {
      Display = {
        ButtonActions = {},
      },
    }
    boop.onCharStatus()

    assert.are.equal("gmcp_ire_missing", blockerSnapshot().code)
    assert.are.equal("gmcp:ire", note_gmcp_calls[#note_gmcp_calls][1])
    assert.are.equal("ire", note_gmcp_calls[#note_gmcp_calls][2])

    boop.onPrompt()

    assert.are.equal("", blockerSnapshot().code)
    assert.are.equal("gmcp:ire", clear_blocker_calls[#clear_blocker_calls][1])
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
    captureRuntimeBlockerCalls()

    boop.onRoomInfo()

    local missing = blockerSnapshot()
    assert.are.equal("room:observation", missing.owner)
    assert.are.equal("room:observation", set_blocker_calls[1][1])
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
    assert.are.equal("room:observation", partial.owner)
    assert.are.equal("room:observation", set_blocker_calls[2][1])
    assert.are.equal("room_partial", partial.code)
    assert.are.equal("partial room state", partial.label)
    assert.is_true(partial.systems.walk)
    assert.is_true(partial.waitsFor.gmcp)
  end)

  it("starts a fresh room observation and caps refresh requests per generation", function()
    helper.seedRoomObservation(100, {
      generation = 7,
      itemsSeen = true,
      refreshAttempted = true,
      refreshReason = "old generation",
      warned = true,
    })
    boop.state.targeting.room = 100
    gmcp.Room.Info = {
      num = 200,
      area = "Test Area",
      exits = {
        north = 100,
      },
    }

    boop.onRoomInfo()

    local observation = boop.runtime.roomObservationSnapshot()
    assert.are.equal(8, observation.generation)
    assert.are.equal("200", observation.roomId)
    assert.is_true(observation.infoSeen)
    assert.is_false(observation.itemsSeen)
    assert.is_true(observation.refreshAttempted)
    assert.are.equal("room info awaiting complete item list", observation.refreshReason)
    assert.is_false(observation.warned)
    assert.are.equal("room:observation", blockerSnapshot().owner)
    assert.is_true(boop.runtime.shouldHold("gold"))
    assert.are.same({ [[Char.Items.Room]] }, gmcp_requests)
    assert.is_false(boop.requestRoomItemsOnce("duplicate refresh"))
    assert.are.same({ [[Char.Items.Room]] }, gmcp_requests)
    assert.is_true(boop.runtime.roomObservationSnapshot().warned)
    assert.are.equal(0, #sent_commands)
    assert.are.equal(0, countRaised("demonwalker.move"))

    local immutable = boop.runtime.roomObservationSnapshot()
    immutable.roomId = "mutated"
    immutable.itemsSeen = true
    assert.are.equal("200", boop.runtime.roomObservationSnapshot().roomId)
    assert.is_false(boop.runtime.roomObservationSnapshot().itemsSeen)
  end)

  it("accepts only a complete room list after the current room info generation", function()
    gmcp.Char.Items.List = {
      location = "room",
      items = {},
    }
    boop.onRoomItemsList()
    local settled = boop.runtime.roomObservationSnapshot()
    assert.are.equal(1, settled.generation)
    assert.is_true(settled.itemsSeen)

    boop.state.targeting.room = 1
    boop.state.walk.active = true
    gmcp.Room.Info = {
      num = 2,
      area = "Test Area",
      exits = {
        south = 1,
      },
    }
    boop.onRoomInfo()
    local arrival_callback = scheduled_callback
    local current = boop.runtime.roomObservationSnapshot()
    assert.are.equal(2, current.generation)
    assert.are.equal("2", current.roomId)
    assert.is_false(current.itemsSeen)
    assert.are.same({ [[Char.Items.Room]] }, gmcp_requests)

    boop.onPrompt()
    assert.is_false(boop.runtime.roomObservationSnapshot().itemsSeen)
    assert.is_function(arrival_callback)
    arrival_callback()
    assert.is_false(boop.runtime.roomObservationSnapshot().itemsSeen)
    assert.are.equal(0, countRaised("demonwalker.move"))

    gmcp.Char.Items.List = {
      location = "inv",
      items = {},
    }
    boop.onRoomItemsList()
    assert.is_false(boop.runtime.roomObservationSnapshot().itemsSeen)

    gmcp.Char.Items.List = {
      location = "room",
      items = nil,
    }
    boop.onRoomItemsList()
    assert.is_false(boop.runtime.roomObservationSnapshot().itemsSeen)
    assert.are.same({ [[Char.Items.Room]] }, gmcp_requests)

    boop.state.walk.active = false
    gmcp.Char.Items.List = {
      location = "room",
      items = {},
    }
    boop.onRoomItemsList()
    local complete = boop.runtime.roomObservationSnapshot()
    assert.are.equal(2, complete.generation)
    assert.is_true(complete.itemsSeen)
    assert.are.equal("", blockerSnapshot().code)

    boop.onRoomItemsList()
    assert.are.equal(2, boop.runtime.roomObservationSnapshot().generation)
    assert.is_true(boop.runtime.roomObservationSnapshot().itemsSeen)
    assert.are.same({ [[Char.Items.Room]] }, gmcp_requests)
    assert.are.equal(0, #sent_commands)
    assert.are.equal(0, countRaised("demonwalker.move"))
  end)

  it("holds loot until a complete list stamps the current room observation", function()
    boop.config.enabled = true
    boop.config.autoGrabGold = true
    boop.config.useQueueing = false
    boop.config.goldPack = ""
    boop.state.targeting.room = 1
    gmcp.Room.Info = {
      num = 2,
      area = "Test Area",
      exits = {
        south = 1,
      },
    }

    boop.onRoomInfo()

    assert.are.equal(0, countSent("queue add freestand get sovereigns"))
    gmcp.Char.Items.List = {
      location = "room",
      items = {
        { id = "99", name = "some gold sovereigns" },
      },
    }
    boop.onRoomItemsList()

    assert.is_true(boop.runtime.roomObservationSnapshot().itemsSeen)
    assert.are.equal(1, countSent("queue add freestand get sovereigns"))
    assert.are.equal(0, countRaised("demonwalker.move"))
  end)

  it("releases current room evidence through one tick and one flush only after every owner clears", function()
    boop.config.enabled = true
    boop.config.autoGrabGold = true
    boop.config.useQueueing = false
    boop.config.goldPack = ""
    boop.state.targeting.room = 1
    gmcp.Room.Info = {
      num = 2,
      area = "Test Area",
      exits = {
        south = 1,
      },
    }
    boop.onRoomInfo()
    boop.onGoldDropLine("A handful of sovereigns spills onto the ground.")
    local operation = boop.state.gold.operation
    assert.is_table(operation)
    assert.are.equal("deferred_room", operation.phase)

    helper.setRuntimeBlocker({
      owner = "interrupt:remaining",
      code = "interrupt_pending",
      systems = { combat = true, queue = true, gold = true, walk = true },
    })

    local tickCalls = 0
    local flushCalls = 0
    local originalTick = boop.tick
    local originalFlush = boop.flushPendingGold
    tick_stub = stub(boop, "tick", function()
      tickCalls = tickCalls + 1
      return originalTick()
    end)
    flush_gold_stub = stub(boop, "flushPendingGold", function(reason)
      flushCalls = flushCalls + 1
      return originalFlush(reason)
    end)

    gmcp.Char.Items.List = {
      location = "room",
      items = { goldItem("9001") },
    }
    boop.onRoomItemsList()

    assert.are.equal("pickup_pending", boop.state.gold.operation.phase)
    assert.is_nil(boop.state.combat.blockersByOwner["room:observation"])
    assert.are.equal(1, tickCalls)
    assert.are.equal(0, flushCalls)
    assert.are.equal(0, countSent("queue add freestand get sovereigns"))

    boop.runtime.clearBlocker("interrupt:remaining", "final owner released")
    boop.tick()

    assert.are.equal(2, tickCalls)
    assert.are.equal(1, flushCalls)
    assert.are.equal(1, countSent("queue add freestand get sovereigns"))
    assert.are.equal(operation.generation, boop.state.gold.operation.generation)
    assert.are.equal(0, boop.state.gold.operation.getRetries)
  end)

  it("resumes one unchanged gold stage through the real GMCP recovery release path", function()
    seedSettledGoldRoom("1", 1)
    boop.config.goldPack = ""
    gmcp.IRE = nil
    boop.onCharStatus()
    assert.is_table(boop.state.combat.blockersByOwner["gmcp:ire"])
    boop.onGoldDropLine("A handful of sovereigns spills onto the ground.")
    local operation = copyGoldOperation(boop.state.gold.operation)
    assert.are.equal(0, countGoldSends())

    local tickCalls = 0
    local flushCalls = 0
    local originalTick = boop.tick
    local originalFlush = boop.flushPendingGold
    tick_stub = stub(boop, "tick", function()
      tickCalls = tickCalls + 1
      return originalTick()
    end)
    flush_gold_stub = stub(boop, "flushPendingGold", function(reason)
      flushCalls = flushCalls + 1
      return originalFlush(reason)
    end)

    gmcp.IRE = {
      Target = { Set = "", Info = { id = "", hpperc = "100%" } },
      Display = { ButtonActions = {} },
    }
    boop.onCharStatus()

    assert.is_table(boop.state.combat.blockersByOwner["gmcp:ire"])
    assert.are.equal(0, tickCalls)
    assert.are.equal(0, flushCalls)
    assert.are.equal(0, countGoldSends())

    boop.onPrompt()

    assert.is_nil(boop.state.combat.blockersByOwner["gmcp:ire"])
    assert.are.equal(1, tickCalls)
    assert.are.equal(1, flushCalls)
    assert.are.equal(1, countGoldSends())
    assert.are.equal(operation.generation, boop.state.gold.operation.generation)
    assert.are.equal(operation.phase, boop.state.gold.operation.phase)
    assert.are.equal(operation.getRetries, boop.state.gold.operation.getRetries)
  end)

  it("resumes one unchanged gold stage through the real interrupt release path", function()
    seedSettledGoldRoom("1", 1)
    boop.config.goldPack = ""
    boop.ui.matic()
    local interrupt = boop.state.diag.operation
    assert.is_table(interrupt)
    boop.onGoldDropLine("A handful of sovereigns spills onto the ground.")
    local operation = copyGoldOperation(boop.state.gold.operation)
    assert.are.equal(0, countGoldSends())

    local tickCalls = 0
    local flushCalls = 0
    local originalTick = boop.tick
    local originalFlush = boop.flushPendingGold
    tick_stub = stub(boop, "tick", function()
      tickCalls = tickCalls + 1
      return originalTick()
    end)
    flush_gold_stub = stub(boop, "flushPendingGold", function(reason)
      flushCalls = flushCalls + 1
      return originalFlush(reason)
    end)

    boop.onPrompt()

    assert.is_false(boop.state.diag.operation)
    assert.is_nil(boop.state.combat.blockersByOwner[interrupt.blockerOwner])
    assert.are.equal(1, tickCalls)
    assert.are.equal(1, flushCalls)
    assert.are.equal(1, countGoldSends())
    assert.are.equal(operation.generation, boop.state.gold.operation.generation)
    assert.are.equal(operation.phase, boop.state.gold.operation.phase)
    assert.are.equal(operation.getRetries, boop.state.gold.operation.getRetries)
  end)

  it("resumes one unchanged gold stage after the real pull completion path and one normal tick", function()
    seedSettledGoldRoom("1", 1)
    boop.config.goldPack = ""
    boop.state.combat.pullGeneration = 8
    boop.state.combat.pullState = {
      active = true,
      generation = 8,
      blockerOwner = "pull:8",
      phase = "outbound",
      terminal = false,
      originRoom = "1",
      timeoutTimer = 808,
    }
    helper.setRuntimeBlocker({
      owner = "pull:8",
      code = "pull_active",
      systems = { combat = true, queue = true, target = true, gold = true, walk = true },
    })
    boop.onGoldDropLine("A handful of sovereigns spills onto the ground.")
    local operation = copyGoldOperation(boop.state.gold.operation)
    assert.are.equal(0, countGoldSends())

    local tickCalls = 0
    local flushCalls = 0
    local originalTick = boop.tick
    local originalFlush = boop.flushPendingGold
    tick_stub = stub(boop, "tick", function()
      tickCalls = tickCalls + 1
      return originalTick()
    end)
    flush_gold_stub = stub(boop, "flushPendingGold", function(reason)
      flushCalls = flushCalls + 1
      return originalFlush(reason)
    end)

    assert.is_true(boop.ui.completePull(8, "timeout_at_origin"))
    boop.tick()

    assert.is_false(boop.state.combat.pullState)
    assert.is_nil(boop.state.combat.blockersByOwner["pull:8"])
    assert.are.equal(1, tickCalls)
    assert.are.equal(1, flushCalls)
    assert.are.equal(1, countGoldSends())
    assert.are.equal(operation.generation, boop.state.gold.operation.generation)
    assert.are.equal(operation.phase, boop.state.gold.operation.phase)
    assert.are.equal(operation.getRetries, boop.state.gold.operation.getRetries)
  end)

  it("keeps current gold unchanged when late old-room List, Add, Remove, and text evidence arrives", function()
    seedSettledGoldRoom("1", 1)
    boop.config.goldPack = ""
    boop.onGoldDropLine("A handful of sovereigns spills onto the ground.")

    gmcp.Room.Info = {
      num = 2,
      area = "Test Area",
      exits = {
        south = 1,
      },
    }
    boop.onRoomInfo()
    gmcp.Char.Items.List = {
      location = "room",
      items = { goldItem("9002") },
    }
    boop.onRoomItemsList()
    local current = copyGoldOperation(boop.state.gold.operation)
    local sendCount = countGoldSends()

    gmcp.Char.Items.List = {
      location = "room",
      items = { goldItem("9001") },
    }
    boop.onRoomItemsList()
    gmcp.Char.Items.Add = {
      location = "room",
      item = goldItem("9001"),
    }
    boop.onRoomItemsAdd()
    gmcp.Char.Items.Remove = {
      location = "room",
      item = goldItem("9001"),
    }
    boop.onRoomItemsRemove()
    boop.onGoldDropLine("Old-room sovereign text arrives late.")

    assert.are.same(current, copyGoldOperation(boop.state.gold.operation))
    assert.are.equal(sendCount, countGoldSends())
  end)

  it("invalidates a current room-owned stage on Room.Info and makes its captured timers stale", function()
    seedSettledGoldRoom("1", 1)
    boop.config.goldPack = ""
    boop.onGoldDropLine("A handful of sovereigns spills onto the ground.")
    local operation = copyGoldOperation(boop.state.gold.operation)
    local callbacks = {}
    for _, entry in ipairs(scheduled_callbacks) do
      callbacks[#callbacks + 1] = entry.callback
    end

    gmcp.Room.Info = {
      num = 1,
      area = "Test Area",
      exits = {},
    }
    boop.onRoomInfo()

    assert.is_false(boop.state.gold.operation)
    assert.is_nil(boop.state.combat.blockersByOwner[operation.blockerOwner])
    local sendsAfterInvalidation = countGoldSends()

    for _, callback in ipairs(callbacks) do
      callback()
    end

    assert.is_false(boop.state.gold.operation)
    assert.are.equal(sendsAfterInvalidation, countGoldSends())
  end)

  it("schedules one terminal reevaluation and makes a stale pack terminal a zero-effect no-op", function()
    seedSettledGoldRoom("1", 1)
    boop.config.goldPack = "pack"
    boop.onGoldDropLine("A handful of sovereigns spills onto the ground.")
    boop.onGoldGetSuccess()
    local callbacksBeforeTerminal = #scheduled_callbacks
    local sendsBeforeTerminal = countGoldSends()
    local tickCalls = 0
    local walkCalls = 0
    local originalTick = boop.tick
    tick_stub = stub(boop, "tick", function()
      tickCalls = tickCalls + 1
      return originalTick()
    end)
    walk_advance_stub = stub(boop.walk, "maybeAdvance", function(_)
      walkCalls = walkCalls + 1
      return false
    end)
    helper.setRuntimeBlocker({
      owner = "interrupt:remaining",
      code = "interrupt_pending",
      systems = { combat = true, queue = true, walk = true },
    })

    assert.is_true(boop.onGoldPutSuccess())
    assert.are.equal(callbacksBeforeTerminal + 1, #scheduled_callbacks)
    local terminalCallback = scheduled_callbacks[#scheduled_callbacks].callback
    assert.is_function(terminalCallback)
    terminalCallback()

    assert.are.equal(1, tickCalls)
    assert.are.equal(0, walkCalls)
    assert.are.equal(sendsBeforeTerminal, countGoldSends())
    assert.is_false(boop.state.gold.operation)

    local callbacksAfterTerminal = #scheduled_callbacks
    assert.is_false(boop.onGoldPutSuccess())
    assert.are.equal(callbacksAfterTerminal, #scheduled_callbacks)
    assert.are.equal(1, tickCalls)
    assert.are.equal(0, walkCalls)
    assert.are.equal(sendsBeforeTerminal, countGoldSends())
  end)

  it("keeps singleton GMCP, room, and target owners isolated at event boundaries", function()
    helper.setRuntimeBlocker({
      owner = "gmcp:ire",
      code = "gmcp_ire_missing",
      systems = { combat = true, walk = true },
      waitsFor = { gmcp = true, prompt = true },
    })
    helper.setRuntimeBlocker({
      owner = "room:observation",
      code = "room_partial",
      systems = { combat = true, walk = true },
      waitsFor = { gmcp = true },
    })
    helper.setRuntimeBlocker({
      owner = "target:loss",
      code = "target_lost",
      systems = { combat = true, queue = true },
      waitsFor = { gmcp = true, prompt = true },
    })
    captureRuntimeBlockerCalls()

    gmcp.Char.Items.List = {
      location = "room",
      items = {},
    }
    boop.onRoomItemsList()

    local blockers = boop.runtime.blockersSnapshot()
    assert.are.equal(2, #blockers)
    assert.are.equal("gmcp:ire", blockers[1].owner)
    assert.are.equal("target:loss", blockers[2].owner)
    assert.are.equal("room:observation", clear_blocker_calls[1][1])

    gmcp.IRE.Target.Set = "77"
    boop.onTargetSet()
    blockers = boop.runtime.blockersSnapshot()
    assert.are.equal(2, #blockers)
    assert.are.equal("gmcp:ire", blockers[1].owner)
    assert.are.equal("target:loss", blockers[2].owner)
    assert.are.equal("target:loss", note_gmcp_calls[#note_gmcp_calls][1])

    boop.onPrompt()
    blockers = boop.runtime.blockersSnapshot()
    assert.are.equal(1, #blockers)
    assert.are.equal("gmcp:ire", blockers[1].owner)
    assert.are.equal("target:loss", clear_blocker_calls[#clear_blocker_calls][1])
  end)

  local targetEvidenceCases = {
    {
      name = "Target.Set",
      invoke = function()
        gmcp.IRE.Target.Set = "77"
        boop.onTargetSet()
      end,
    },
    {
      name = "Target.Info",
      invoke = function()
        gmcp.IRE.Target.Info = {
          id = "78",
          short_desc = "a replacement denizen",
        }
        boop.onTargetInfo()
      end,
    },
  }

  for _, entry in ipairs(targetEvidenceCases) do
    local case = entry
    it("satisfies only target:loss from " .. case.name .. " evidence", function()
      helper.setTarget("42", "a removed denizen", "80%")
      helper.setDenizens({
        { id = "42", name = "a removed denizen" },
      })
      helper.setRuntimeBlocker({
        owner = "interrupt:88",
        code = "interrupt_pending",
        systems = { combat = true },
        waitsFor = { timeout = true },
      })
      boop.config.enabled = true
      boop.config.targetingMode = "auto"
      captureRuntimeBlockerCalls()

      gmcp.Char.Items.Remove = {
        location = "room",
        item = { id = "42", name = "a removed denizen", attrib = "m" },
      }
      boop.onRoomItemsRemove()

      assert.are.equal("target:loss", set_blocker_calls[1][1])
      local blockers = boop.runtime.blockersSnapshot()
      assert.are.equal(2, #blockers)
      assert.are.equal("target:loss", blockers[1].owner)
      assert.are.equal("interrupt:88", blockers[2].owner)

      case.invoke()

      assert.are.equal("target:loss", note_gmcp_calls[#note_gmcp_calls][1])
      assert.are.equal("target", note_gmcp_calls[#note_gmcp_calls][2])
      blockers = boop.runtime.blockersSnapshot()
      assert.are.equal(2, #blockers)

      boop.onPrompt()

      blockers = boop.runtime.blockersSnapshot()
      assert.are.equal(1, #blockers)
      assert.are.equal("interrupt:88", blockers[1].owner)
      assert.are.equal("target:loss", clear_blocker_calls[#clear_blocker_calls][1])
    end)
  end

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

  it("cleans target intent without attacking or executing prequeue while gold owns the queue", function()
    helper.setArea("Test Area")
    helper.setClass("Occultist")
    helper.learnSkills({
      { name = "Lycantha", group = "Domination" },
      { name = "harry", group = "Attainment" },
    })
    helper.setDenizens({
      { id = "42", name = "a first denizen" },
      { id = "43", name = "a second denizen" },
    })
    helper.setTarget("42", "a first denizen", "80%")
    helper.addTargetAfflictions({ "stupidity" })
    seedSettledGoldRoom("1", 1)
    boop.config.targetingMode = "auto"
    boop.config.prequeueEnabled = true
    boop.config.goldPack = ""
    boop.onGoldDropLine("A handful of sovereigns spills onto the ground.")
    assert.are.equal("pickup_pending", boop.state.gold.operation.phase)
    sent_commands = {}

    gmcp.Char.Items.Remove = {
      location = "room",
      item = { id = "42", name = "a first denizen", attrib = "m" },
    }
    boop.onRoomItemsRemove()

    assert.are.equal("43", boop.state.targeting.currentTargetId)
    assert.is_false(boop.afflictions.hasTarget("stupidity"))
    assert.is_function(scheduled_callback)
    assert.are.equal(0, countSent("queue clear"))
    assert.are.equal(0, countSent("command hound at 43"))
    assert.are.equal(0, countSent("harry 43"))
    assert.are.equal(0, countSent("setalias BOOP_ATTACK command hound at 43"))

    scheduled_callback()

    assert.are.equal(0, countSent("queue clear"))
    assert.are.equal(0, countSent("command hound at 43"))
    assert.are.equal(0, countSent("harry 43"))
    assert.are.equal(0, countSent("setalias BOOP_ATTACK command hound at 43"))
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
      generation = 7,
      blockerOwner = "pull:7",
      phase = "away",
      terminal = false,
      originRoom = "1",
      direction = "north",
      returnDirection = "south",
      command = "north|harry a pulled denizen|leap south",
      timeoutTimer = 707,
    }
    boop.state.combat.pullGeneration = 7
    helper.setRuntimeBlocker({
      owner = "pull:7",
      code = "pull_active",
      label = "pull active",
      systems = { combat = true, queue = true, target = true, gold = true, walk = true },
      waitsFor = { room = true },
    })
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
    assert.are.equal(7, boop.state.combat.pullState.generation)
    assert.are.equal("pull:7", boop.state.combat.pullState.blockerOwner)
    assert.is_false(boop.state.combat.pullState.terminal)
    assert.are.equal(707, boop.state.combat.pullState.timeoutTimer)
    local blocker = boop.state.combat.blockersByOwner["pull:7"]
    assert.is_table(blocker)
    assert.are.equal("pull_active", blocker.code)
    assert.are.same({
      combat = true,
      queue = true,
      target = true,
      gold = true,
      walk = true,
    }, blocker.systems)
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
    captureRuntimeBlockerCalls()

    boop.onTargetSet()

    assert.are.equal("77", boop.state.targeting.currentTargetId)
    assert.are.equal("a game-selected denizen", boop.state.targeting.targetName)
    assert.is_false(boop.state.targeting.targetShield)
    assert.stub(kill_timer_stub).was_called_with(55)
    assert.stub(send_stub).was_not_called_with("settarget 77", false)
    assert.are.equal("target:loss", note_gmcp_calls[1][1])
    assert.are.equal("target", note_gmcp_calls[1][2])
  end)

  it("clears tracked shield state when gmcp target info changes", function()
    helper.setTarget("42", "a test denizen", "80%")
    boop.state.targeting.targetShield = { attempted = false, timer = 56 }
    gmcp.IRE.Target.Info.id = "78"
    gmcp.IRE.Target.Info.short_desc = "a target-info denizen"
    captureRuntimeBlockerCalls()

    boop.onTargetInfo()

    assert.are.equal("78", boop.state.targeting.currentTargetId)
    assert.are.equal("a target-info denizen", boop.state.targeting.targetName)
    assert.is_false(boop.state.targeting.targetShield)
    assert.stub(kill_timer_stub).was_called_with(56)
    assert.stub(send_stub).was_not_called_with("settarget 78", false)
    assert.are.equal("target:loss", note_gmcp_calls[1][1])
    assert.are.equal("target", note_gmcp_calls[1][2])
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
    seedSettledGoldRoom("100", 1)
    boop.config.goldPack = ""
    boop.onGoldDropLine("A handful of sovereigns spills onto the ground.")
    local operation = copyGoldOperation(boop.state.gold.operation)
    boop.state.targeting.room = 100
    boop.state.combat.fleeing = false
    boop.state.targeting.targetShield = { attempted = false, timer = 57 }

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
    assert.is_false(boop.state.gold.operation)
    assert.is_nil(boop.state.combat.blockersByOwner[operation.blockerOwner])
    assert.is_false(boop.state.gold.getPending)
    assert.is_false(boop.state.gold.putPending)
    assert.are.equal(0, boop.state.gold.getRetries)
    assert.are.equal(0, boop.state.gold.putRetries)
    assert.are.equal("", boop.state.gold.packTarget)
    assert.stub(kill_timer_stub).was_called_with(57)
  end)

  it("does not let a room removal callback mutate current gold state", function()
    seedSettledGoldRoom("1", 1)
    boop.config.goldPack = ""
    boop.onGoldDropLine("A handful of sovereigns spills onto the ground.")
    local operation = copyGoldOperation(boop.state.gold.operation)
    local sendsBeforeRemove = countGoldSends()

    gmcp.Char.Items.Remove = {
      location = "room",
      item = { id = "99", name = "some gold sovereigns" },
    }

    boop.onRoomItemsRemove()

    assert.are.same(operation, copyGoldOperation(boop.state.gold.operation))
    assert.are.equal(sendsBeforeRemove, countGoldSends())
  end)

  it("routes current Room.Info and complete List through one walker owner", function()
    _G.demonwalker = {
      enabled = true,
      init = function() return true end,
    }
    boop.config.enabled = true
    boop.config.targetingMode = "auto"
    boop.config.targetCall = false
    helper.setTarget("", "", "100%")
    helper.setDenizens({})
    helper.seedRoomObservation("1", {
      generation = 7,
      infoSeen = true,
      itemsSeen = true,
    })

    local state = boop.runtime.state()
    state.walk.active = true
    state.walk.owned = false
    state.walk.roomSettled = true
    state.walk.moveQueued = false
    state.walk.arrivalRoom = "1"
    state.walk.generation = 12
    state.walk.roomGeneration = 7
    state.walk.moveIssuedForRoomGeneration = false
    state.walk.reservationId = 3
    state.walk.refreshTimer = nil
    state.walk.emitterTimer = nil
    state.walk.refreshWarned = false

    assert.is_true(boop.walk.maybeAdvance("event ordering seed"))
    local owner = "walk:12"
    local oldEmitter = state.walk.emitterTimer
    local oldEmitterCallback
    for _, entry in ipairs(scheduled_callbacks) do
      if entry.id == oldEmitter then
        oldEmitterCallback = entry.callback
      end
    end
    assert.is_function(oldEmitterCallback)
    assert.are.equal(
      "walk_move_pending",
      state.combat.blockersByOwner[owner].code
    )

    gmcp.Room.Info = {
      num = 1,
      area = "Test Area",
      exits = {},
    }
    boop.onRoomInfo()

    local currentObservation = boop.runtime.roomObservationSnapshot()
    assert.are.equal(12, state.walk.generation)
    assert.are.equal(currentObservation.generation, state.walk.roomGeneration)
    assert.is_false(currentObservation.itemsSeen)
    assert.is_false(state.walk.roomSettled)
    assert.is_false(state.walk.moveQueued)
    assert.is_false(state.walk.moveIssuedForRoomGeneration)
    assert.is_nil(state.walk.emitterTimer)
    assert.stub(kill_timer_stub).was_called_with(oldEmitter)
    assert.are.equal(
      "walk_room_unsettled",
      state.combat.blockersByOwner[owner].code
    )

    local roomGeneration = state.walk.roomGeneration
    local reservationAfterRoomInfo = state.walk.reservationId
    oldEmitterCallback()
    assert.are.equal(0, countRaised("demonwalker.move"))
    assert.are.equal(12, state.walk.generation)
    assert.are.equal(roomGeneration, state.walk.roomGeneration)
    assert.are.equal(reservationAfterRoomInfo, state.walk.reservationId)

    gmcp.Char.Items.List = {
      location = "room",
      items = {},
    }
    boop.onRoomItemsList()

    assert.is_true(boop.runtime.roomObservationSnapshot().itemsSeen)
    assert.is_true(state.walk.roomSettled)
    assert.is_true(state.walk.moveQueued)
    assert.is_true(state.walk.moveIssuedForRoomGeneration)
    assert.are.equal(reservationAfterRoomInfo + 1, state.walk.reservationId)
    assert.are.equal(
      "walk_move_pending",
      state.combat.blockersByOwner[owner].code
    )
    local currentEmitter = state.walk.emitterTimer
    local currentEmitterCallback
    for _, entry in ipairs(scheduled_callbacks) do
      if entry.id == currentEmitter then
        currentEmitterCallback = entry.callback
      end
    end
    assert.is_function(currentEmitterCallback)
    currentEmitterCallback()
    assert.are.equal(1, countRaised("demonwalker.move"))
  end)

  it("ignores stale arrived and finished adapter callbacks after restart", function()
    _G.demonwalker = {
      enabled = true,
      init = function() return true end,
    }
    boop.config.enabled = true
    boop.config.targetingMode = "auto"
    helper.seedRoomObservation("1", {
      generation = 9,
      infoSeen = true,
      itemsSeen = false,
    })
    local state = boop.runtime.state()
    state.walk.active = true
    state.walk.owned = false
    state.walk.generation = 22
    state.walk.roomGeneration = 9
    state.walk.arrivalRoom = "1"
    helper.setRuntimeBlocker({
      owner = "walk:22",
      code = "walk_room_unsettled",
      label = "current room evidence is incomplete",
      systems = { walk = true },
      waitsFor = { room = true, items = true },
    })
    local before = {
      active = state.walk.active,
      owned = state.walk.owned,
      generation = state.walk.generation,
      roomGeneration = state.walk.roomGeneration,
      reservationId = state.walk.reservationId,
      refreshTimer = state.walk.refreshTimer,
      emitterTimer = state.walk.emitterTimer,
      blocker = boop.runtime.blockersSnapshot(),
      scheduled = #scheduled_callbacks,
    }

    assert.is_false(boop.onWalkArrived(21, 8))
    assert.is_false(boop.onWalkFinished(21))

    assert.are.same(before, {
      active = state.walk.active,
      owned = state.walk.owned,
      generation = state.walk.generation,
      roomGeneration = state.walk.roomGeneration,
      reservationId = state.walk.reservationId,
      refreshTimer = state.walk.refreshTimer,
      emitterTimer = state.walk.emitterTimer,
      blocker = boop.runtime.blockersSnapshot(),
      scheduled = #scheduled_callbacks,
    })
    assert.are.equal(0, countRaised("demonwalker.move"))
    assert.are.equal(0, countRaised("demonwalker.stop"))
  end)

  local roomLifecycleOrders = {
    {
      name = "interrupt then pull",
      start = function()
        boop.ui.matic()
        boop.ui.pullCommand("mage", "north")
      end,
    },
    {
      name = "pull then interrupt",
      start = function()
        boop.ui.pullCommand("mage", "north")
        boop.ui.matic()
      end,
    },
  }

  for _, entry in ipairs(roomLifecycleOrders) do
    local case = entry
    it("retains interrupt, pull, and unrelated ownership across Room.Info for " .. case.name, function()
      helper.setClass("Occultist")
      helper.setRage(18)
      helper.learnSkill("Harry", "Attainment")
      helper.setSkillKnown("chaosgate", false, "Attainment")
      helper.setSkillKnown("fluctuate", false, "Attainment")
      boop.config.enabled = true
      boop.config.targetingMode = "auto"
      boop.config.diagTimeoutSeconds = 8
      boop.config.gameSeparator = "|"
      boop.state.targeting.room = "1"
      gmcp.Room.Info = {
        num = "1",
        area = "Test Area",
        exits = {},
      }
      helper.setRuntimeBlocker({
        owner = "test:retained",
        code = "interrupt_pending",
        label = "retained unrelated owner",
        systems = { audit = true },
        waitsFor = { timeout = true },
      })

      case.start()

      local interrupt = boop.state.diag.operation
      local pull = boop.state.combat.pullState
      assert.is_table(interrupt)
      assert.is_table(pull)
      local interruptTimeout = callbackForTimer(interrupt.timeoutTimer)
      local pullTimeout = callbackForTimer(pull.timeoutTimer)
      assert.is_function(interruptTimeout)
      assert.is_function(pullTimeout)
      assert.are.equal(2, #sent_commands)
      assert.are.equal(2, #scheduled_callbacks)

      gmcp.Room.Info = {
        num = "2",
        area = "Test Area",
        exits = { south = "1" },
      }
      boop.onRoomInfo()

      assert.are.equal("away", boop.state.combat.pullState.phase)
      assert.is_table(blockerFor(interrupt.blockerOwner))
      assert.is_table(blockerFor(pull.blockerOwner))
      assert.is_table(blockerFor("room:observation"))
      assert.is_table(blockerFor("test:retained"))

      boop.onPrompt()
      assert.is_false(boop.state.diag.operation)
      assert.is_nil(blockerFor(interrupt.blockerOwner))
      assert.is_table(blockerFor(pull.blockerOwner))
      assert.is_table(blockerFor("room:observation"))
      assert.is_table(blockerFor("test:retained"))

      interruptTimeout()
      assert.is_false(boop.state.diag.operation)
      assert.is_table(blockerFor(pull.blockerOwner))

      gmcp.Room.Info = {
        num = "1",
        area = "Test Area",
        exits = { north = "2" },
      }
      boop.onRoomInfo()

      assert.is_false(boop.state.combat.pullState)
      assert.is_nil(blockerFor(pull.blockerOwner))
      assert.is_table(blockerFor("room:observation"))
      assert.is_table(blockerFor("test:retained"))

      pullTimeout()
      assert.is_false(boop.state.combat.pullState)
      assert.are.equal(2, #sent_commands)
      assert.are.equal(2, #scheduled_callbacks)
      assert.are.equal(2, #gmcp_requests)
      assert.are.equal(0, countRaised("demonwalker.move"))
      assert.are.equal(0, countRaised("demonwalker.stop"))
    end)
  end

  local targetRemovalGoldPhases = {
    {
      name = "room-owned pickup",
      pack = "",
      prepare = function() end,
      expectedGoldSends = 1,
      stale = function()
        return boop.onGoldPutSuccess()
      end,
    },
    {
      name = "inventory-owned packing",
      pack = "pack",
      prepare = function()
        assert.is_true(boop.onGoldGetSuccess())
      end,
      expectedGoldSends = 2,
      stale = function()
        return boop.onGoldGetSuccess()
      end,
    },
  }

  for _, entry in ipairs(targetRemovalGoldPhases) do
    local case = entry
    it("preserves target-removal queue drift during " .. case.name, function()
      helper.setArea("Test Area")
      helper.setClass("Occultist")
      helper.learnSkills({
        { name = "Lycantha", group = "Domination" },
        { name = "harry", group = "Attainment" },
      })
      helper.setDenizens({
        { id = "42", name = "a first denizen" },
        { id = "43", name = "a second denizen" },
      })
      helper.setTarget("42", "a first denizen", "80%")
      seedSettledGoldRoom("1", 1)
      boop.config.targetingMode = "auto"
      boop.config.prequeueEnabled = true
      boop.config.goldPack = case.pack
      helper.setRuntimeBlocker({
        owner = "test:retained",
        code = "interrupt_pending",
        label = "retained unrelated owner",
        systems = { audit = true },
        waitsFor = { timeout = true },
      })

      boop.onGoldDropLine("A handful of sovereigns spills onto the ground.")
      case.prepare()
      assert.are.equal(case.expectedGoldSends, countGoldSends())
      local operation = copyGoldOperation(boop.state.gold.operation)

      gmcp.Char.Items.Remove = {
        location = "room",
        item = { id = "42", name = "a first denizen", attrib = "m" },
      }
      boop.onRoomItemsRemove()

      local retargetCallback = scheduled_callbacks[#scheduled_callbacks].callback
      assert.is_function(retargetCallback)
      assert.are.equal("43", boop.state.targeting.currentTargetId)
      assert.are.same(operation, copyGoldOperation(boop.state.gold.operation))
      assert.is_table(blockerFor("test:retained"))
      assert.are.equal(0, countSent("queue clear"))
      assert.are.equal(0, countSent("command hound at 43"))
      assert.are.equal(0, countSent("harry 43"))
      assert.are.equal(0, countSent("setalias BOOP_ATTACK command hound at 43"))

      retargetCallback()

      assert.are.equal(case.expectedGoldSends, countGoldSends())
      assert.are.equal(0, countSent("queue clear"))
      assert.are.equal(0, countSent("command hound at 43"))
      assert.are.equal(0, countSent("harry 43"))
      assert.are.equal(0, countSent("setalias BOOP_ATTACK command hound at 43"))
      assert.is_false(case.stale())
      assert.are.same(operation, copyGoldOperation(boop.state.gold.operation))
      assert.is_table(blockerFor("test:retained"))
      assert.are.equal(0, countRaised("demonwalker.move"))
    end)
  end

  it("settles walk once after gold and denizen evidence clear in order", function()
    _G.demonwalker = {
      enabled = true,
      init = function() return true end,
    }
    boop.config.enabled = true
    boop.config.autoGrabGold = true
    boop.config.useQueueing = false
    boop.config.goldPack = ""
    boop.config.targetingMode = "auto"
    boop.config.targetCall = false
    helper.setTarget("", "", "100%")
    helper.seedRoomObservation("1", {
      generation = 7,
      infoSeen = true,
      itemsSeen = false,
    })
    local state = boop.runtime.state()
    state.walk.active = true
    state.walk.owned = false
    state.walk.roomSettled = false
    state.walk.moveQueued = false
    state.walk.arrivalRoom = "1"
    state.walk.generation = 12
    state.walk.roomGeneration = 7
    state.walk.moveIssuedForRoomGeneration = false
    state.walk.reservationId = 0
    helper.setRuntimeBlocker({
      owner = "walk:12",
      code = "walk_room_unsettled",
      label = "current room evidence is incomplete",
      systems = { walk = true },
      waitsFor = { room = true, items = true },
    })
    helper.setRuntimeBlocker({
      owner = "test:retained",
      code = "interrupt_pending",
      label = "retained unrelated owner",
      systems = { audit = true },
      waitsFor = { timeout = true },
    })

    gmcp.Char.Items.List = {
      location = "room",
      items = {
        { id = "42", name = "a denizen", attrib = "m" },
        goldItem("9001"),
      },
    }
    boop.onRoomItemsList()

    assert.are.equal(1, countGoldSends())
    assert.are.equal(0, state.walk.reservationId)
    assert.is_false(state.walk.moveQueued)
    assert.are.equal(0, countRaised("demonwalker.move"))
    local goldGeneration = boop.state.gold.operation.generation

    assert.is_true(boop.onGoldGetSuccess())
    local goldTerminal = scheduled_callbacks[#scheduled_callbacks].callback
    assert.is_function(goldTerminal)

    assert.is_false(boop.state.gold.operation)
    assert.is_nil(blockerFor("gold:" .. tostring(goldGeneration)))
    assert.are.equal(0, state.walk.reservationId)
    assert.are.equal(0, countRaised("demonwalker.move"))

    gmcp.Char.Items.List = {
      location = "room",
      items = {},
    }
    boop.onRoomItemsList()

    assert.are.equal(1, state.walk.reservationId)
    assert.is_true(state.walk.moveQueued)
    assert.are.equal("walk_move_pending", blockerFor("walk:12").code)
    assert.is_table(blockerFor("test:retained"))
    local emitter = callbackForTimer(state.walk.emitterTimer)
    assert.is_function(emitter)

    goldTerminal()
    emitter()
    emitter()

    assert.are.equal(1, countRaised("demonwalker.move"))
    assert.are.equal(0, countRaised("demonwalker.stop"))
    assert.are.equal(1, countGoldSends())
    assert.is_table(blockerFor("test:retained"))
  end)

  it("makes old gold and walker callbacks no-ops after new room and run generations", function()
    _G.demonwalker = {
      enabled = true,
      init = function() return true end,
    }
    boop.config.enabled = true
    boop.config.autoGrabGold = true
    boop.config.useQueueing = false
    boop.config.goldPack = ""
    boop.config.targetingMode = "auto"
    helper.setTarget("", "", "100%")
    helper.setDenizens({})
    seedSettledGoldRoom("1", 1)
    helper.setRuntimeBlocker({
      owner = "test:retained",
      code = "interrupt_pending",
      label = "retained unrelated owner",
      systems = { audit = true },
      waitsFor = { timeout = true },
    })

    local state = boop.runtime.state()
    state.walk.active = true
    state.walk.owned = false
    state.walk.roomSettled = true
    state.walk.moveQueued = false
    state.walk.arrivalRoom = "1"
    state.walk.generation = 30
    state.walk.roomGeneration = 1
    state.walk.moveIssuedForRoomGeneration = false
    state.walk.reservationId = 4
    assert.is_true(boop.walk.maybeAdvance("old generation seed"))
    local oldEmitter = callbackForTimer(state.walk.emitterTimer)
    assert.is_function(oldEmitter)
    boop.runtime.clearBlocker(
      "walk:" .. tostring(state.walk.generation),
      "cross-lifecycle callback setup"
    )

    boop.onGoldDropLine("A handful of sovereigns spills onto the ground.")
    local oldGold = copyGoldOperation(boop.state.gold.operation)
    local oldGoldTimeout = callbackForTimer(oldGold.timeoutTimer)
    assert.is_function(oldGoldTimeout)

    gmcp.Room.Info = {
      num = "2",
      area = "Test Area",
      exits = { south = "1" },
    }
    boop.onRoomInfo()
    assert.is_false(boop.state.gold.operation)
    assert.is_true(boop.walk.stop(true, true))
    assert.is_true(boop.walk.start())

    gmcp.Char.Items.List = {
      location = "room",
      items = { goldItem("9002") },
    }
    boop.onRoomItemsList()

    local currentGold = copyGoldOperation(boop.state.gold.operation)
    local currentWalk = {
      active = state.walk.active,
      owned = state.walk.owned,
      generation = state.walk.generation,
      roomGeneration = state.walk.roomGeneration,
      reservationId = state.walk.reservationId,
      moveQueued = state.walk.moveQueued,
      emitterTimer = state.walk.emitterTimer,
    }
    local sendCount = #sent_commands
    local eventCount = #raised_events
    local timerCount = #scheduled_callbacks
    assert.is_true(currentGold.generation > oldGold.generation)
    assert.is_true(currentWalk.generation > 30)

    oldGoldTimeout()
    oldEmitter()

    assert.are.same(currentGold, copyGoldOperation(boop.state.gold.operation))
    assert.are.same(currentWalk, {
      active = state.walk.active,
      owned = state.walk.owned,
      generation = state.walk.generation,
      roomGeneration = state.walk.roomGeneration,
      reservationId = state.walk.reservationId,
      moveQueued = state.walk.moveQueued,
      emitterTimer = state.walk.emitterTimer,
    })
    assert.are.equal(sendCount, #sent_commands)
    assert.are.equal(eventCount, #raised_events)
    assert.are.equal(timerCount, #scheduled_callbacks)
    assert.are.equal(0, countRaised("demonwalker.move"))
    assert.are.equal(0, countRaised("demonwalker.stop"))
    assert.is_table(blockerFor("test:retained"))
  end)

  it("treats Mudlet event names as adapter metadata instead of generation tokens", function()
    local arrivedRunGeneration = "unset"
    local arrivedRoomGeneration = "unset"
    local finishedRunGeneration = "unset"
    walk_arrived_adapter_stub = stub(boop.walk, "onArrived", function(runGeneration, roomGeneration)
      arrivedRunGeneration = runGeneration
      arrivedRoomGeneration = roomGeneration
      return true
    end)
    walk_finished_adapter_stub = stub(boop.walk, "onFinished", function(runGeneration)
      finishedRunGeneration = runGeneration
      return true
    end)

    assert.is_true(boop.onWalkArrived("demonwalker.arrived"))
    assert.is_true(boop.onWalkFinished("demonwalker.finished"))

    assert.is_nil(arrivedRunGeneration)
    assert.is_nil(arrivedRoomGeneration)
    assert.is_nil(finishedRunGeneration)
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
