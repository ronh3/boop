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
  local walk_settled_stub
  local walk_arrived_adapter_stub
  local walk_finished_adapter_stub
  local targets_update_stub
  local util_warn_stub
  local trace_log_stub
  local validate_authority_stub
  local current_authority_stub
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
    if walk_settled_stub then
      walk_settled_stub:revert()
      walk_settled_stub = nil
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
    if targets_update_stub then
      targets_update_stub:revert()
      targets_update_stub = nil
    end
    if util_warn_stub then
      util_warn_stub:revert()
      util_warn_stub = nil
    end
    if trace_log_stub then
      trace_log_stub:revert()
      trace_log_stub = nil
    end
    if validate_authority_stub then
      validate_authority_stub:revert()
      validate_authority_stub = nil
    end
    if current_authority_stub then
      current_authority_stub:revert()
      current_authority_stub = nil
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

  local function countGmcpRequest(command)
    local count = 0
    for _, request in ipairs(gmcp_requests) do
      if request == command then
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

  local function runPendingRoomApplication()
    if not boop.runtime.roomApplicationSnapshot then
      return false
    end
    local application = boop.runtime.roomApplicationSnapshot()
    local callback = application
      and callbackForTimer(application.pendingTimer)
      or nil
    if not callback then
      return false
    end
    callback()
    return true
  end

  local function sourceAuthority(applicationId, roomId, generation)
    return {
      applicationId = applicationId,
      roomId = tostring(roomId),
      observationGeneration = generation,
    }
  end

  local function assertSourceAuthority(expected, actual)
    assert.are.same(expected, {
      applicationId = actual and actual.applicationId,
      roomId = actual and actual.roomId,
      observationGeneration = actual and actual.observationGeneration,
    })
    local count = 0
    for _ in pairs(actual or {}) do
      count = count + 1
    end
    assert.are.equal(3, count)
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

  local function denizenItem(id, name)
    return {
      id = tostring(id or "42"),
      name = tostring(name or "a test denizen"),
      attrib = "m",
    }
  end

  local function inventoryItem(id, name, attrib)
    return {
      id = tostring(id or "7001"),
      name = tostring(name or "a test weapon"),
      attrib = tostring(attrib or "l"),
      icon = "weapon",
    }
  end

  local function publishItemsList(location, items)
    gmcp.Char.Items.List = {
      location = location,
      items = items,
    }
    return boop.onRoomItemsList()
  end

  local function publishAcceptedRoomList(items)
    local observation = boop.runtime.roomObservationSnapshot()
    if observation.itemsSeen
        and #observation.fenceQueue == 0 then
      observation = boop.runtime.startRoomObservation(
        observation.roomId,
        {
          boundary = "fresh_start",
          reason = "test accepted room response",
        }
      )
    end
    if not observation.itemsSeen and not observation.refreshAttempted then
      boop.requestRoomItemsOnce("test accepted room response")
    end
    local guard = 0
    while true do
      observation = boop.runtime.roomObservationSnapshot()
      local fence = observation.fenceQueue[1]
      if not fence then break end
      guard = guard + 1
      assert.is_true(guard < 20)
      if fence.phase == "await_inv" then
        publishItemsList("inv", {})
      end
      observation = boop.runtime.roomObservationSnapshot()
      fence = observation.fenceQueue[1]
      if fence and fence.phase == "await_room" then
        local acceptedItems = fence.valid ~= false
            and tonumber(fence.fenceId) == tonumber(observation.activeFenceId)
          and items
          or {}
        publishItemsList("room", acceptedItems)
      end
    end
    runPendingRoomApplication()
  end

  local function copyWalkState()
    local walk = boop.runtime.state().walk
    return {
      active = walk.active,
      owned = walk.owned,
      roomSettled = walk.roomSettled,
      moveQueued = walk.moveQueued,
      arrivalRoom = walk.arrivalRoom,
      generation = walk.generation,
      roomGeneration = walk.roomGeneration,
      moveIssuedForRoomGeneration = walk.moveIssuedForRoomGeneration,
      reservationId = walk.reservationId,
      refreshTimer = walk.refreshTimer,
      emitterTimer = walk.emitterTimer,
      refreshWarned = walk.refreshWarned,
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
      revalidationAttempted = operation.revalidationAttempted,
      revalidationFenceId = operation.revalidationFenceId,
      sourceAuthority = operation.sourceAuthority and {
        applicationId = operation.sourceAuthority.applicationId,
        roomId = operation.sourceAuthority.roomId,
        observationGeneration =
          operation.sourceAuthority.observationGeneration,
      } or false,
    }
  end

  local function seedSettledGoldRoom(roomId, generation)
    local room = tostring(roomId or "1")
    local items = { goldItem("9001") }
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
      acceptedItems = items,
    })
    gmcp.Char.Items.List = {
      location = "room",
      items = items,
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
    it("tracks lifecycle readiness when " .. case.name, function()
      local support_calls = stubCoreSupports()
      boop.config.enabled = true
      case.seed()
      captureRuntimeBlockerCalls()

      boop.onCharStatus()

      assert.are.equal(1, #support_calls)
      assert.is_true(support_calls[1].requestSkills)
      local lifecycle = boop.runtime.lifecycleSnapshot()
      assert.is_false(lifecycle.ireSeen)
      assert.is_true(lifecycle.promptSeen)
      assert.is_false(lifecycle.ready)
      assert.are.equal(0, #set_blocker_calls)
      assert.are.equal(0, #boop.runtime.operationLocksSnapshot())
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
    assert.is_true(boop.runtime.lifecycleSnapshot().ready)
  end)

  it("accepts IRE.Target as readiness evidence when IRE.Display has not emitted data", function()
    local support_calls = stubCoreSupports()
    boop.config.enabled = true
    gmcp.IRE.Display = nil

    boop.onCharStatus()

    assert.are.equal(0, #support_calls)
    assert.are.equal("", blockerSnapshot().code)
    assert.is_true(boop.runtime.lifecycleSnapshot().ready)
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

  it("becomes lifecycle-ready after one requested IRE module and a prompt have arrived", function()
    stubCoreSupports()
    boop.config.enabled = true
    boop.runtime.beginConnectionLifecycle("test reconnect")
    gmcp.IRE = nil
    captureRuntimeBlockerCalls()

    boop.onCharStatus()
    local lifecycle = boop.runtime.lifecycleSnapshot()
    assert.is_false(lifecycle.ireSeen)
    assert.is_false(lifecycle.promptSeen)
    assert.is_false(lifecycle.ready)

    gmcp.IRE = {
      Display = {
        ButtonActions = {},
      },
    }
    boop.onCharStatus()

    lifecycle = boop.runtime.lifecycleSnapshot()
    assert.is_true(lifecycle.ireSeen)
    assert.is_false(lifecycle.promptSeen)
    assert.is_false(lifecycle.ready)

    boop.onPrompt()

    assert.is_true(boop.runtime.lifecycleSnapshot().ready)
    assert.are.equal(0, #boop.runtime.operationLocksSnapshot())
    assert.are.equal(0, #set_blocker_calls)
    assert.are.equal(0, #clear_blocker_calls)
  end)

  it("preserves an observed prompt across repeated missing IRE checks", function()
    stubCoreSupports()
    boop.config.enabled = true
    boop.runtime.beginConnectionLifecycle("test reconnect")
    gmcp.IRE = nil

    boop.onCharStatus()
    boop.onPrompt()
    assert.is_true(boop.runtime.lifecycleSnapshot().promptSeen)

    boop.onCharStatus()
    assert.is_true(boop.runtime.lifecycleSnapshot().promptSeen)

    gmcp.IRE = {
      Display = {
        ButtonActions = {},
      },
    }
    boop.onCharStatus()

    assert.is_true(boop.runtime.lifecycleSnapshot().ready)
    assert.are.equal(0, #boop.runtime.operationLocksSnapshot())
  end)

  it("computes missing and partial room readiness directly", function()
    boop.config.enabled = true
    gmcp.Room.Info = nil
    captureRuntimeBlockerCalls()

    boop.onRoomInfo()

    local missing = boop.runtime.readinessSnapshot().room
    assert.is_false(missing.ready)
    assert.are.equal("missing_room", missing.code)
    assert.are.equal("missing room state", missing.label)

    gmcp.Room.Info = {
      num = 101,
      area = "Test Area",
    }
    boop.onRoomInfo()

    local partial = boop.runtime.readinessSnapshot().room
    assert.is_false(partial.ready)
    assert.are.equal("room_partial", partial.code)
    assert.are.equal("current room evidence is incomplete", partial.label)
    assert.are.equal(0, #set_blocker_calls)
    assert.are.equal(0, #boop.runtime.operationLocksSnapshot())
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
    local readiness = boop.runtime.readinessSnapshot().room
    assert.is_false(readiness.ready)
    assert.are.equal("room_partial", readiness.code)
    assert.are.equal(0, #boop.runtime.operationLocksSnapshot())
    assert.are.same({ [[Char.Items.Inv]], [[Char.Items.Room]] }, gmcp_requests)
    assert.is_false(boop.requestRoomItemsOnce("duplicate refresh"))
    assert.are.same({ [[Char.Items.Inv]], [[Char.Items.Room]] }, gmcp_requests)
    assert.is_false(boop.runtime.roomObservationSnapshot().warned)
    assert.are.equal(0, #sent_commands)
    assert.are.equal(0, countRaised("demonwalker.move"))

    local immutable = boop.runtime.roomObservationSnapshot()
    immutable.roomId = "mutated"
    immutable.itemsSeen = true
    assert.are.equal("200", boop.runtime.roomObservationSnapshot().roomId)
    assert.is_false(boop.runtime.roomObservationSnapshot().itemsSeen)
  end)

  it("accepts only a complete room list after the current room info generation", function()
    publishAcceptedRoomList({})
    local settled = boop.runtime.roomObservationSnapshot()
    local settledGeneration = settled.generation
    assert.is_true(settled.itemsSeen)
    gmcp_requests = {}

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
    assert.are.equal(settledGeneration + 1, current.generation)
    assert.are.equal("2", current.roomId)
    assert.is_false(current.itemsSeen)
    assert.are.same({ [[Char.Items.Inv]], [[Char.Items.Room]] }, gmcp_requests)

    boop.onPrompt()
    assert.is_false(boop.runtime.roomObservationSnapshot().itemsSeen)
    assert.is_function(arrival_callback)
    arrival_callback()
    assert.is_false(boop.runtime.roomObservationSnapshot().itemsSeen)
    assert.are.equal(0, countRaised("demonwalker.move"))

    gmcp.Char.Items.List = {
      location = "room",
      items = nil,
    }
    boop.onRoomItemsList()
    assert.is_false(boop.runtime.roomObservationSnapshot().itemsSeen)
    assert.are.same({ [[Char.Items.Inv]], [[Char.Items.Room]] }, gmcp_requests)

    gmcp.Char.Items.List = {
      location = "inv",
      items = {},
    }
    boop.onRoomItemsList()
    assert.is_false(boop.runtime.roomObservationSnapshot().itemsSeen)

    boop.state.walk.active = false
    gmcp.Char.Items.List = {
      location = "room",
      items = {},
    }
    boop.onRoomItemsList()
    assert.is_true(runPendingRoomApplication())
    local complete = boop.runtime.roomObservationSnapshot()
    assert.are.equal(settledGeneration + 1, complete.generation)
    assert.is_true(complete.itemsSeen)
    assert.are.equal("", blockerSnapshot().code)

    boop.onRoomItemsList()
    assert.are.equal(
      settledGeneration + 1,
      boop.runtime.roomObservationSnapshot().generation
    )
    assert.is_true(boop.runtime.roomObservationSnapshot().itemsSeen)
    assert.are.same({ [[Char.Items.Inv]], [[Char.Items.Room]] }, gmcp_requests)
    assert.are.equal(0, #sent_commands)
    assert.are.equal(0, countRaised("demonwalker.move"))
  end)

  local roomResponseOrders = {
    {
      name = "Inv then Room",
      firstLocation = "inv",
      secondLocation = "room",
    },
    {
      name = "Room then Inv",
      firstLocation = "room",
      secondLocation = "inv",
    },
  }

  for _, entry in ipairs(roomResponseOrders) do
    local case = entry
    it("room-response-fence settles one copied pair exactly once for "
        .. case.name, function()
      boop.config.enabled = true
      boop.config.autoGrabGold = true
      boop.config.useQueueing = false
      boop.config.goldPack = ""
      boop.state.targeting.room = "1"
      helper.setDenizens({
        { id = "10", name = "the prior-room denizen" },
      })

      local targetUpdates = 0
      local walkSettlements = 0
      local tickCalls = 0
      local originalUpdate = boop.targets.updateRoomItems
      targets_update_stub = stub(boop.targets, "updateRoomItems", function(items)
        targetUpdates = targetUpdates + 1
        return originalUpdate(items)
      end)
      walk_settled_stub = stub(boop.walk, "onRoomSettled", function()
        walkSettlements = walkSettlements + 1
        return false
      end)
      tick_stub = stub(boop, "tick", function()
        tickCalls = tickCalls + 1
      end)

      gmcp.Room.Info = {
        num = "2",
        area = "Test Area",
        exits = { south = "1" },
      }
      boop.onRoomInfo()

      local invItems = {
        inventoryItem("7001", "the accepted fenced weapon", "l"),
      }
      local roomItems = {
        denizenItem("21", "the accepted current denizen"),
        goldItem("9021"),
      }
      local firstItems = case.firstLocation == "inv" and invItems or roomItems
      local secondItems = case.secondLocation == "inv" and invItems or roomItems

      publishItemsList(case.firstLocation, firstItems)
      publishItemsList(case.firstLocation, {
        case.firstLocation == "inv"
          and inventoryItem("7999", "a duplicate replacement weapon", "l")
          or denizenItem("299", "a duplicate replacement denizen"),
      })
      firstItems[1].name = "mutated after first latch"
      publishItemsList(case.secondLocation, secondItems)
      secondItems[1].name = "mutated after second latch"

      assert.is_function(
        boop.runtime.roomApplicationSnapshot,
        "ROOM_RESPONSE_LATCH_MISSING: completed pairs need one application"
      )
      local application = boop.runtime.roomApplicationSnapshot()
      assert.is_table(application)
      assert.are.equal(0, targetUpdates)
      assert.are.equal(0, walkSettlements)
      assert.are.equal(0, tickCalls)
      assert.are.equal(0, countGoldSends())
      assert.are.equal("7001", boop.state.inventory.wieldedLeft.id)
      assert.are.equal(
        "the accepted current denizen",
        application.items[1].name
      )

      local applicationCallback = callbackForTimer(application.pendingTimer)
      assert.is_function(applicationCallback)
      applicationCallback()
      applicationCallback()

      local accepted = boop.runtime.roomObservationSnapshot()
      local acceptedApplication = boop.runtime.roomApplicationSnapshot(
        application.applicationId
      )
      local timerCount = #scheduled_callbacks
      publishItemsList(case.firstLocation, firstItems)
      publishItemsList(case.secondLocation, secondItems)

      assert.are.same({
        requests = { "Char.Items.Inv", "Char.Items.Room" },
        updates = 1,
        settlements = 1,
        ticks = 1,
        goldSends = 1,
        wielded = "7001",
        denizen = "the accepted current denizen",
        acceptedName = "the accepted current denizen",
        queueDepth = 0,
        timerCount = timerCount,
        applicationId = application.applicationId,
        claimed = true,
        consumed = true,
      }, {
        requests = gmcp_requests,
        updates = targetUpdates,
        settlements = walkSettlements,
        ticks = tickCalls,
        goldSends = countGoldSends(),
        wielded = boop.state.inventory.wieldedLeft
          and boop.state.inventory.wieldedLeft.id,
        denizen = boop.state.targeting.denizens[1]
          and boop.state.targeting.denizens[1].name,
        acceptedName = accepted.acceptedItems[1]
          and accepted.acceptedItems[1].name,
        queueDepth = #accepted.fenceQueue,
        timerCount = #scheduled_callbacks,
        applicationId = acceptedApplication.applicationId,
        claimed = acceptedApplication.claimed,
        consumed = acceptedApplication.consumed,
      }, "ROOM_RESPONSE_LATCH_BROKEN: unordered pair was not exact-once")
    end)
  end

  it("G-03-7 post-Inv pre-Info application invalidation", function()
    boop.config.enabled = true
    boop.config.autoGrabGold = true
    boop.config.useQueueing = false
    boop.config.goldPack = ""
    boop.config.targetingMode = "auto"
    boop.state.targeting.room = "4255"
    gmcp.Room.Info = {
      num = "4255",
      area = "Old Room",
      exits = { south = "4249" },
    }
    helper.seedRoomObservation("4255", {
      generation = 45,
      infoSeen = true,
      itemsSeen = false,
      acceptedItems = {},
    })
    boop.requestRoomItemsOnce("G-03-7 generation 45")

    local targetUpdates = 0
    local walkSettlements = 0
    local tickCalls = 0
    local originalUpdate = boop.targets.updateRoomItems
    targets_update_stub = stub(boop.targets, "updateRoomItems", function(items)
      targetUpdates = targetUpdates + 1
      return originalUpdate(items)
    end)
    walk_settled_stub = stub(boop.walk, "onRoomSettled", function()
      walkSettlements = walkSettlements + 1
      return false
    end)
    tick_stub = stub(boop, "tick", function()
      tickCalls = tickCalls + 1
    end)

    publishItemsList("inv", {
      inventoryItem("7455", "generation 45 weapon", "l"),
    })
    local oldRoomItems = {
      denizenItem("44026", "the generation 45 denizen"),
      goldItem("9455"),
    }
    publishItemsList("room", oldRoomItems)
    oldRoomItems[1].name = "mutated after generation 45 latch"

    assert.is_function(
      boop.runtime.roomApplicationSnapshot,
      "ROOM_APPLICATION_MISSING: accepted evidence escaped synchronously"
    )
    assert.is_function(boop.runtime.validateRoomSourceAuthority)
    local oldApplication = boop.runtime.roomApplicationSnapshot()
    local oldAuthority = sourceAuthority(
      oldApplication.applicationId,
      "4255",
      45
    )
    assertSourceAuthority(oldAuthority, oldApplication.sourceAuthority)
    assert.are.equal("the generation 45 denizen", oldApplication.items[1].name)
    assert.are.same({ 0, 0, 0, 0 }, {
      targetUpdates,
      walkSettlements,
      tickCalls,
      countGoldSends(),
    })

    local oldContext = boop.runtime.context(oldAuthority)
    local oldResult = boop.runtime.step({
      type = "tick",
      context = oldContext,
    })
    assertSourceAuthority(oldAuthority, oldContext.sourceAuthority)
    for _, effect in ipairs(oldResult.effects or {}) do
      if effect.kind == "target"
          or effect.kind == "combat_plan"
          or effect.kind == "walk_advance"
          or effect.kind == "flush_gold" then
        assertSourceAuthority(oldAuthority, effect.sourceAuthority)
      end
    end
    local oldCallback = callbackForTimer(oldApplication.pendingTimer)
    assert.is_function(oldCallback)

    gmcp.Room.Info = {
      num = "4249",
      area = "Destination Room",
      exits = { north = "4255" },
    }
    boop.onRoomInfo()
    assert.is_false(boop.runtime.validateRoomSourceAuthority(oldAuthority))
    assertSourceAuthority(oldAuthority, oldApplication.sourceAuthority)
    assertSourceAuthority(oldAuthority, oldContext.sourceAuthority)
    oldCallback()
    boop.runtime.applyEffects(oldResult, oldContext)

    assert.are.same({ 0, 0, 0, 0, 0 }, {
      targetUpdates,
      walkSettlements,
      tickCalls,
      countGoldSends(),
      #sent_commands,
    })
    assert.are.equal(0, countSent("queue clear"))
    assert.is_false(boop.state.queue.prequeuedStandard)
    assert.are.equal("", boop.state.queue.aliasAction)

    local newRoomItems = {
      denizenItem("44901", "the generation 46 denizen"),
      goldItem("9460"),
    }
    publishItemsList("room", newRoomItems)
    publishItemsList("inv", {
      inventoryItem("7460", "generation 46 weapon", "l"),
    })
    local newApplication = boop.runtime.roomApplicationSnapshot()
    local newAuthority = sourceAuthority(
      newApplication.applicationId,
      "4249",
      46
    )
    assert.is_true(newApplication.applicationId > oldApplication.applicationId)
    assertSourceAuthority(newAuthority, newApplication.sourceAuthority)
    local newCallback = callbackForTimer(newApplication.pendingTimer)
    assert.is_function(newCallback)
    newCallback()
    newCallback()

    local settled = boop.runtime.roomObservationSnapshot()
    local consumed = boop.runtime.roomApplicationSnapshot(
      newApplication.applicationId
    )
    assert.is_true(boop.runtime.validateRoomSourceAuthority(newAuthority))
    assert.is_false(boop.runtime.validateRoomSourceAuthority(oldAuthority))
    assertSourceAuthority(newAuthority, settled.acceptedSourceAuthority)
    assertSourceAuthority(newAuthority, consumed.sourceAuthority)
    assert.are.same({
      updates = 1,
      settlements = 1,
      ticks = 1,
      goldSends = 1,
      roomId = "4249",
      generation = 46,
      queueDepth = 0,
      applicationId = newApplication.applicationId,
      claimed = true,
      consumed = true,
    }, {
      updates = targetUpdates,
      settlements = walkSettlements,
      ticks = tickCalls,
      goldSends = countGoldSends(),
      roomId = settled.roomId,
      generation = settled.generation,
      queueDepth = #settled.fenceQueue,
      applicationId = consumed.applicationId,
      claimed = consumed.claimed,
      consumed = consumed.consumed,
    })
  end)

  describe("G-03-7 4255-to-4249 external dispatch fence", function()
    local function automaticOptions(authority)
      return {
        roomOwned = true,
        sourceAuthority = authority,
      }
    end

    local function settleAcceptedRoom(roomId, generation, items)
      boop.config.enabled = false
      boop.config.autoGrabGold = false
      boop.config.useQueueing = true
      boop.config.goldPack = ""
      boop.config.targetingMode = "auto"
      boop.state.targeting.room = tostring(roomId)
      gmcp.Room.Info = {
        num = tostring(roomId),
        area = "Authority Test Room",
        exits = {},
      }
      helper.seedRoomObservation(roomId, {
        generation = generation,
        infoSeen = true,
        itemsSeen = false,
        acceptedItems = {},
      })
      boop.requestRoomItemsOnce(
        "G-03-7 accepted authority " .. tostring(generation)
      )
      publishItemsList("inv", {})
      publishItemsList("room", items or {})

      local application = boop.runtime.roomApplicationSnapshot()
      assert.is_table(application)
      local callback = callbackForTimer(application.pendingTimer)
      assert.is_function(callback)
      callback()

      local authority = sourceAuthority(
        application.applicationId,
        roomId,
        generation
      )
      assert.is_true(boop.runtime.validateRoomSourceAuthority(authority))
      boop.config.enabled = true
      return authority
    end

    local function moveToDestination()
      gmcp.Room.Info = {
        num = "4249",
        area = "Destination Room",
        exits = { north = "4255" },
      }
      boop.onRoomInfo()
    end

    it("rejects stale target, standard, alias, queue, and rage boundaries without local mutation", function()
      helper.setClass("Occultist")
      helper.learnSkills({
        { name = "Lycantha", group = "Domination" },
        { name = "harry", group = "Attainment" },
      })
      helper.setRage(100)
      local authority = settleAcceptedRoom("4255", 45, {
        denizenItem("44026", "the generation 45 denizen"),
      })

      moveToDestination()
      assert.is_false(boop.runtime.validateRoomSourceAuthority(authority))
      sent_commands = {}

      local before = {
        targetId = boop.state.targeting.currentTargetId,
        targetName = boop.state.targeting.targetName,
        aliasAction = boop.state.queue.aliasAction,
        aliasDirty = boop.state.queue.aliasDirty,
        huntingLimiter = boop.state.combat.limiters.hunting,
        rageLimiter = boop.state.combat.limiters.rage,
        opener = boop.state.combat.openerUsedByClass.occultist,
        shield = boop.state.targeting.targetShield,
      }
      local context = boop.runtime.context(authority)
      context.target = {
        id = "44026",
        name = "the generation 45 denizen",
        shield = { attempted = false },
        hpperc = "100%",
      }
      local plan = {
        class = "occultist",
        standard = "command hound at 44026",
        standardShieldbreak = true,
        standardIsOpener = true,
        rage = "harry 44026",
        rageAbility = { name = "harry", desc = "Shieldbreak" },
        rageDecision = { mode = "simple" },
      }

      assert.is_false(
        boop.targets.setTarget("44026", automaticOptions(authority))
      )
      assert.is_false(boop.executeAction(
        plan.standard,
        true,
        automaticOptions(authority)
      ))
      assert.is_false(boop.executeRageAction(
        plan.rage,
        automaticOptions(authority)
      ))
      assert.is_false(boop.attacks.execute(plan, context, authority))
      assert.is_false(boop.executeAction(
        plan.standard,
        true,
        automaticOptions(false)
      ))
      assert.is_false(boop.runtime.applyEffects({
        effects = {
          {
            kind = "target",
            id = "44026",
            roomOwned = true,
          },
        },
      }, boop.runtime.context(false, {
        roomOwned = true,
      })))

      assert.are.same(before, {
        targetId = boop.state.targeting.currentTargetId,
        targetName = boop.state.targeting.targetName,
        aliasAction = boop.state.queue.aliasAction,
        aliasDirty = boop.state.queue.aliasDirty,
        huntingLimiter = boop.state.combat.limiters.hunting,
        rageLimiter = boop.state.combat.limiters.rage,
        opener = boop.state.combat.openerUsedByClass.occultist,
        shield = boop.state.targeting.targetShield,
      })
      assert.are.equal(0, #sent_commands)
      assert.are.equal(0, countSent("queue clear"))

      boop.config.useQueueing = false
      assert.is_true(boop.executeAction("intentional non-room command"))
      assert.are.equal(1, countSent("intentional non-room command"))
    end)

    it("keeps every delayed generation-45 callback on its captured authority after movement", function()
      helper.setClass("Occultist")
      helper.learnSkill("Lycantha", "Domination")
      local authority = settleAcceptedRoom("4255", 45, {
        denizenItem("44026", "the generation 45 denizen"),
        denizenItem("44027", "the generation 45 replacement"),
      })
      boop.config.targetCall = true
      boop.config.assistLeader = "Leader"
      boop.config.prequeueEnabled = true
      boop.config.attackLeadSeconds = 1
      gmcp.Char.Vitals.bal = "0"
      gmcp.Char.Vitals.eq = "0"

      assert.is_true(boop.targets.onPartyTargetCall(
        "Leader",
        "44026",
        [[(Party): Leader says, "Target: 44026."]]
      ))
      local leaderCallback = scheduled_callbacks[#scheduled_callbacks].callback
      assert.is_function(leaderCallback)

      boop.onBalanceUsed("balance", 2)
      local prequeueCallback = scheduled_callbacks[#scheduled_callbacks].callback
      assert.is_function(prequeueCallback)

      helper.setTarget("44026", "the generation 45 denizen", "80%")
      gmcp.Char.Items.Remove = {
        location = "room",
        item = denizenItem("44026", "the generation 45 denizen"),
      }
      local sendsBeforeRemoval = #sent_commands
      boop.onRoomItemsRemove()
      local retargetCallback = scheduled_callbacks[#scheduled_callbacks].callback
      assert.is_function(retargetCallback)
      assert.are.equal(
        sendsBeforeRemoval,
        #sent_commands,
        "retarget must remain deferred until its captured callback"
      )

      boop.state.queue.prequeuedStandard = true
      boop.state.queue.prequeueSourceAuthority = sourceAuthority(
        authority.applicationId,
        authority.roomId,
        authority.observationGeneration
      )
      helper.setRuntimeBlocker({
        owner = "interrupt:unrelated",
        code = "interrupt_pending",
        label = "unrelated queue owner",
        systems = { queue = true },
        waitsFor = { timeout = true },
      })

      local originalValidate = boop.runtime.validateRoomSourceAuthority
      local validations = {}
      validate_authority_stub = stub(
        boop.runtime,
        "validateRoomSourceAuthority",
        function(actual)
          validations[#validations + 1] = sourceAuthority(
            actual and actual.applicationId,
            actual and actual.roomId,
            actual and actual.observationGeneration
          )
          return originalValidate(actual)
        end
      )
      local originalCurrentAuthority =
        boop.runtime.currentRoomSourceAuthority
      local currentAuthorityCalls = 0
      current_authority_stub = stub(
        boop.runtime,
        "currentRoomSourceAuthority",
        function()
          currentAuthorityCalls = currentAuthorityCalls + 1
          return originalCurrentAuthority()
        end
      )

      moveToDestination()
      sent_commands = {}
      validations = {}
      currentAuthorityCalls = 0
      local afterMove = {
        targetId = boop.state.targeting.currentTargetId,
        targetName = boop.state.targeting.targetName,
        aliasAction = boop.state.queue.aliasAction,
        prequeued = boop.state.queue.prequeuedStandard,
        blocker = blockerFor("interrupt:unrelated"),
      }

      leaderCallback()
      prequeueCallback()
      assert.is_false(boop.refreshPrequeuedStandard("stale shield refresh"))
      retargetCallback()

      assert.are.equal(0, currentAuthorityCalls)
      assert.is_true(#validations >= 3)
      for _, actual in ipairs(validations) do
        assertSourceAuthority(authority, actual)
      end
      assert.are.same(afterMove, {
        targetId = boop.state.targeting.currentTargetId,
        targetName = boop.state.targeting.targetName,
        aliasAction = boop.state.queue.aliasAction,
        prequeued = boop.state.queue.prequeuedStandard,
        blocker = blockerFor("interrupt:unrelated"),
      })
      assert.are.equal(0, #sent_commands)
      assert.are.equal(0, countSent("queue clear"))
    end)

    it("keeps current generation-46 target, combat, prequeue, refresh, and retarget paths live", function()
      helper.setClass("Occultist")
      helper.learnSkills({
        { name = "Lycantha", group = "Domination" },
        { name = "Warp", group = "Occultism" },
        { name = "Hammer", group = "Tattoos" },
        { name = "harry", group = "Attainment" },
      })
      helper.setRage(100)
      local authority = settleAcceptedRoom("4249", 46, {
        denizenItem("44901", "the generation 46 denizen"),
        denizenItem("44902", "the generation 46 replacement"),
      })
      boop.config.prequeueEnabled = true
      boop.config.attackLeadSeconds = 1
      gmcp.Char.Vitals.bal = "0"
      gmcp.Char.Vitals.eq = "0"
      sent_commands = {}

      assert.is_true(
        boop.targets.setTarget("44901", automaticOptions(authority))
      )
      assert.are.equal(1, countSent("settarget 44901"))
      assert.is_true(boop.executeAction(
        "command hound at 44901",
        true,
        automaticOptions(authority)
      ))
      assert.are.equal(
        1,
        countSent("setalias BOOP_ATTACK command hound at 44901")
      )
      assert.are.equal(
        1,
        countSent("queue addclearfull freestand BOOP_ATTACK")
      )
      assert.is_true(boop.executeRageAction(
        "harry 44901",
        automaticOptions(authority)
      ))
      assert.are.equal(1, countSent("harry 44901"))

      sent_commands = {}
      boop.onBalanceUsed("balance", 2)
      local prequeueCallback = scheduled_callbacks[#scheduled_callbacks].callback
      assert.is_function(prequeueCallback)
      prequeueCallback()
      assert.is_true(boop.state.queue.prequeuedStandard)
      assertSourceAuthority(
        authority,
        boop.state.queue.prequeueSourceAuthority
      )
      assert.are.equal(
        1,
        countSent("queue addclearfull freestand BOOP_ATTACK")
      )

      boop.state.targeting.targetShield = {
        gained = os.clock(),
        attempted = false,
      }
      assert.is_true(boop.refreshPrequeuedStandard(
        "current shield refresh"
      ))
      assert.are.equal(
        2,
        countSent("queue addclearfull freestand BOOP_ATTACK")
      )

      sent_commands = {}
      gmcp.Char.Items.Remove = {
        location = "room",
        item = denizenItem("44901", "the generation 46 denizen"),
      }
      boop.onRoomItemsRemove()
      assert.are.equal(0, countSent("settarget 44902"))
      local retargetCallback = scheduled_callbacks[#scheduled_callbacks].callback
      assert.is_function(retargetCallback)
      retargetCallback()
      assert.are.equal(1, countSent("settarget 44902"))
    end)
  end)

  it("room-response-fence drains an invalidated epoch before the next epoch", function()
    boop.config.enabled = false
    boop.state.targeting.room = "1"
    helper.setDenizens({
      { id = "10", name = "the retained denizen" },
    })

    local targetUpdates = 0
    local walkSettlements = 0
    local tickCalls = 0
    local originalUpdate = boop.targets.updateRoomItems
    targets_update_stub = stub(boop.targets, "updateRoomItems", function(items)
      targetUpdates = targetUpdates + 1
      return originalUpdate(items)
    end)
    walk_settled_stub = stub(boop.walk, "onRoomSettled", function()
      walkSettlements = walkSettlements + 1
      return false
    end)
    tick_stub = stub(boop, "tick", function()
      tickCalls = tickCalls + 1
    end)

    gmcp.Room.Info = {
      num = "2",
      area = "Room A",
      exits = { south = "1" },
    }
    boop.onRoomInfo()
    gmcp.Room.Info = {
      num = "3",
      area = "Room B",
      exits = { south = "2" },
    }
    boop.onRoomInfo()

    publishItemsList("inv", {
      inventoryItem("7101", "room A delayed inventory", "l"),
    })
    publishItemsList("room", {
      denizenItem("201", "room A stale denizen"),
    })
    publishItemsList("room", {
      denizenItem("301", "room B early denizen"),
    })
    local afterDrainedA = {
      updates = targetUpdates,
      settlements = walkSettlements,
      ticks = tickCalls,
      denizen = boop.state.targeting.denizens[1]
        and boop.state.targeting.denizens[1].name,
      wielded = boop.state.inventory.wieldedLeft
        and boop.state.inventory.wieldedLeft.id
        or false,
    }

    publishItemsList("inv", {
      inventoryItem("7102", "room B current inventory", "l"),
    })
    local roomBApplication = boop.runtime.roomApplicationSnapshot()
    local roomBCallback = callbackForTimer(
      roomBApplication and roomBApplication.pendingTimer
    )
    assert.is_function(roomBCallback)
    publishItemsList("inv", {
      inventoryItem("7199", "room B duplicate inventory", "l"),
    })
    local afterBInventory = boop.state.inventory.wieldedLeft
      and boop.state.inventory.wieldedLeft.id
      or false

    gmcp.Room.Info = {
      num = "4",
      area = "Room C",
      exits = { south = "3" },
    }
    boop.onRoomInfo()
    roomBCallback()
    publishItemsList("room", {
      denizenItem("401", "room C accepted denizen"),
    })
    publishItemsList("inv", {
      inventoryItem("7103", "room C current inventory", "l"),
    })
    assert.is_true(runPendingRoomApplication())

    local observation = boop.runtime.roomObservationSnapshot()
    assert.are.same({
      requests = {
        "Char.Items.Inv",
        "Char.Items.Room",
        "Char.Items.Inv",
        "Char.Items.Room",
        "Char.Items.Inv",
        "Char.Items.Room",
      },
      afterDrainedA = {
        updates = 0,
        settlements = 0,
        ticks = 0,
        denizen = "the retained denizen",
        wielded = false,
      },
      afterBInventory = "7102",
      finalUpdates = 1,
      finalSettlements = 1,
      finalTicks = 1,
      finalDenizen = "room C accepted denizen",
      finalWielded = "7103",
      roomId = "4",
      itemsSeen = true,
      queueDepth = 0,
    }, {
      requests = gmcp_requests,
      afterDrainedA = afterDrainedA,
      afterBInventory = afterBInventory,
      finalUpdates = targetUpdates,
      finalSettlements = walkSettlements,
      finalTicks = tickCalls,
      finalDenizen = boop.state.targeting.denizens[1]
        and boop.state.targeting.denizens[1].name,
      finalWielded = boop.state.inventory.wieldedLeft
        and boop.state.inventory.wieldedLeft.id
        or false,
      roomId = observation.roomId,
      itemsSeen = observation.itemsSeen,
      queueDepth = type(observation.fenceQueue) == "table"
        and #observation.fenceQueue
        or -1,
    }, "ROOM_RESPONSE_FENCE_BROKEN: invalidated epochs were not drain-only")
  end)

  it("room-response-fence preserves complete same-room evidence and caps missing responses", function()
    boop.config.enabled = true
    boop.config.autoGrabGold = true
    boop.config.useQueueing = false
    boop.config.goldPack = ""
    boop.state.targeting.room = ""

    gmcp.Room.Info = {
      num = "1",
      area = "Test Area",
      exits = {},
    }
    boop.onRoomInfo()
    publishItemsList("inv", {})
    publishItemsList("room", {
      denizenItem("41", "the complete same-room denizen"),
      goldItem("9041"),
    })
    assert.is_true(runPendingRoomApplication())

    local state = boop.runtime.state()
    state.walk.active = true
    state.walk.owned = false
    state.walk.roomSettled = true
    state.walk.moveQueued = true
    state.walk.arrivalRoom = "1"
    state.walk.generation = 12
    state.walk.roomGeneration =
      boop.runtime.roomObservationSnapshot().generation
    state.walk.moveIssuedForRoomGeneration = true
    state.walk.reservationId = 5
    state.walk.refreshTimer = 333
    state.walk.emitterTimer = 334
    state.walk.refreshWarned = false
    local beforeSame = {
      observation = boop.runtime.roomObservationSnapshot(),
      denizens = boop.state.targeting.denizens,
      gold = copyGoldOperation(boop.state.gold.operation),
      blockers = boop.runtime.blockersSnapshot(),
      walk = copyWalkState(),
      requests = #gmcp_requests,
      sends = #sent_commands,
      events = #raised_events,
      timers = #scheduled_callbacks,
    }

    boop.onRoomInfo()

    local afterSame = {
      observation = boop.runtime.roomObservationSnapshot(),
      denizens = boop.state.targeting.denizens,
      gold = copyGoldOperation(boop.state.gold.operation),
      blockers = boop.runtime.blockersSnapshot(),
      walk = copyWalkState(),
      requests = #gmcp_requests,
      sends = #sent_commands,
      events = #raised_events,
      timers = #scheduled_callbacks,
    }

    state.walk.active = false
    state.walk.moveQueued = false
    state.walk.moveIssuedForRoomGeneration = false
    state.walk.refreshTimer = nil
    state.walk.emitterTimer = nil
    local warnings = {}
    local traces = {}
    util_warn_stub = stub(boop.util, "warn", function(message)
      warnings[#warnings + 1] = tostring(message)
    end)
    trace_log_stub = stub(boop.trace, "log", function(message)
      traces[#traces + 1] = tostring(message)
    end)

    gmcp.Room.Info = {
      num = "2",
      area = "Missing Response Room",
      exits = { south = "1" },
    }
    boop.onRoomInfo()
    local warningBaseline = #warnings
    local traceBaseline = #traces
    publishItemsList("room", {
      denizenItem("99", "an out-of-order room denizen"),
    })
    local timeoutObservation = boop.runtime.roomObservationSnapshot()
    local timeoutCallback = callbackForTimer(
      timeoutObservation.refreshTimeoutTimer
    )
    if timeoutCallback then
      timeoutCallback()
    end
    local missing = boop.runtime.roomObservationSnapshot()
    local timeoutTraceCount = 0
    for i = traceBaseline + 1, #traces do
      if traces[i]:find("room response fence", 1, true) then
        timeoutTraceCount = timeoutTraceCount + 1
      end
    end

    assert.are.same({
      beforeSame = beforeSame,
      afterSame = beforeSame,
      missing = {
        requests = 4,
        itemsSeen = false,
        warned = true,
        refreshAttempted = true,
        warningCount = 1,
        timeoutTraceCount = 1,
        roomOwnerPresent = false,
        denizen = "the complete same-room denizen",
      },
    }, {
      beforeSame = beforeSame,
      afterSame = afterSame,
      missing = {
        requests = #gmcp_requests,
        itemsSeen = missing.itemsSeen,
        warned = missing.warned,
        refreshAttempted = missing.refreshAttempted,
        warningCount = #warnings - warningBaseline,
        timeoutTraceCount = timeoutTraceCount,
        roomOwnerPresent = blockerFor("room:observation") ~= nil,
        denizen = boop.state.targeting.denizens[1]
          and boop.state.targeting.denizens[1].name,
      },
    }, "ROOM_RESPONSE_FENCE_BROKEN: same-room evidence reset or missing response escaped the cap")
  end)

  it("arrival-tokenless-fence requests no authorizing evidence", function()
    _G.demonwalker = {
      enabled = true,
      init = function() return true end,
    }
    boop.config.enabled = true
    boop.config.targetingMode = "auto"
    boop.config.targetCall = false
    boop.state.targeting.room = "1"
    helper.setTarget("", "", "100%")
    helper.setDenizens({})
    helper.seedRoomObservation("1", {
      generation = 7,
      infoSeen = true,
      itemsSeen = true,
      acceptedItems = {},
    })
    gmcp.Room.Info = {
      num = "1",
      area = "Test Area",
      exits = {},
    }
    gmcp.Char.Items.List = {
      location = "room",
      items = {
        denizenItem("901", "persistent stale arrival denizen"),
        goldItem("9901"),
      },
    }

    local startOk = boop.walk.start()
    local state = boop.runtime.state()
    local owner = "walk:" .. tostring(state.walk.generation)
    local afterStart = {
      observation = boop.runtime.roomObservationSnapshot(),
      walk = copyWalkState(),
      blockers = boop.runtime.blockersSnapshot(),
      denizens = boop.state.targeting.denizens,
      requests = #gmcp_requests,
      sends = #sent_commands,
      events = #raised_events,
    }

    publishItemsList("room", {})
    local beforeArrival = {
      observation = boop.runtime.roomObservationSnapshot(),
      walk = copyWalkState(),
      blockers = boop.runtime.blockersSnapshot(),
      denizens = boop.state.targeting.denizens,
      requests = #gmcp_requests,
      sends = #sent_commands,
      events = #raised_events,
    }

    local eventArrival = boop.onWalkArrived("demonwalker.arrived")
    local numericArrival = boop.onWalkArrived(999, 999)
    local afterArrival = {
      observation = boop.runtime.roomObservationSnapshot(),
      walk = copyWalkState(),
      blockers = boop.runtime.blockersSnapshot(),
      denizens = boop.state.targeting.denizens,
      requests = #gmcp_requests,
      sends = #sent_commands,
      events = #raised_events,
    }

    publishItemsList("inv", {
      inventoryItem("7201", "arrival-fenced weapon", "l"),
    })
    local afterInventory = {
      itemsSeen = boop.runtime.roomObservationSnapshot().itemsSeen,
      wielded = boop.state.inventory.wieldedLeft
        and boop.state.inventory.wieldedLeft.id
        or false,
      reservationId = state.walk.reservationId,
      moveCount = countRaised("demonwalker.move"),
    }

    publishItemsList("room", {})
    assert.is_true(runPendingRoomApplication())
    local emitter = state.walk.emitterTimer
    local emitterCallback = callbackForTimer(emitter)
    if emitterCallback then
      emitterCallback()
      emitterCallback()
    end

    local settled = boop.runtime.roomObservationSnapshot()
    local walkOwner = blockerFor(owner)
    assert.are.same({
      startOk = true,
      arrivals = { true, true },
      start = {
        itemsSeen = false,
        acceptedCount = 0,
        queueDepth = 1,
        requestPair = { "Char.Items.Inv", "Char.Items.Room" },
        refreshTimer = nil,
      },
      preBarrier = {
        itemsSeen = false,
        roomSeen = true,
        queueDepth = 1,
        denizenCount = 0,
        sends = 0,
        events = 0,
      },
      arrivalPreserved = beforeArrival,
      inventory = {
        itemsSeen = true,
        wielded = "7201",
        reservationId = 0,
        moveCount = 0,
      },
      settled = {
        itemsSeen = true,
        queueDepth = 0,
        reservationId = 1,
        moveQueued = true,
        moveIssued = true,
        ownerCode = false,
        moveCount = 1,
        requestCount = 2,
        timerCount = 3,
        denizenCount = 0,
        goldSendCount = 0,
      },
    }, {
      startOk = startOk,
      arrivals = { eventArrival, numericArrival },
      start = {
        itemsSeen = afterStart.observation.itemsSeen,
        acceptedCount = #afterStart.observation.acceptedItems,
        queueDepth = #afterStart.observation.fenceQueue,
        requestPair = gmcp_requests,
        refreshTimer = afterStart.walk.refreshTimer,
      },
      preBarrier = {
        itemsSeen = beforeArrival.observation.itemsSeen,
        roomSeen = beforeArrival.observation.fenceQueue[1]
          and beforeArrival.observation.fenceQueue[1].roomSeen
          or false,
        queueDepth = #beforeArrival.observation.fenceQueue,
        denizenCount = #beforeArrival.denizens,
        sends = beforeArrival.sends,
        events = beforeArrival.events,
      },
      arrivalPreserved = afterArrival,
      inventory = afterInventory,
      settled = {
        itemsSeen = settled.itemsSeen,
        queueDepth = #settled.fenceQueue,
        reservationId = state.walk.reservationId,
        moveQueued = state.walk.moveQueued,
        moveIssued = state.walk.moveIssuedForRoomGeneration,
        ownerCode = walkOwner and walkOwner.code or false,
        moveCount = countRaised("demonwalker.move"),
        requestCount = #gmcp_requests,
        timerCount = #scheduled_callbacks,
        denizenCount = #boop.state.targeting.denizens,
        goldSendCount = countGoldSends(),
      },
    }, "ARRIVAL_TOKENLESS_FENCE_BROKEN: tokenless arrival created authority or rearmed")
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

    assert.are.equal(0, countSent("queue add full get sovereigns"))
    publishAcceptedRoomList({
      { id = "99", name = "some gold sovereigns" },
    })

    assert.is_true(boop.runtime.roomObservationSnapshot().itemsSeen)
    assert.are.equal(1, countSent("queue add full get sovereigns"))
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

    publishAcceptedRoomList({ goldItem("9001") })

    assert.are.equal("pickup_pending", boop.state.gold.operation.phase)
    assert.is_nil(boop.state.combat.blockersByOwner["room:observation"])
    assert.are.equal(1, tickCalls)
    assert.are.equal(0, flushCalls)
    assert.are.equal(0, countSent("queue add full get sovereigns"))

    boop.runtime.clearBlocker("interrupt:remaining", "final owner released")
    boop.tick()

    assert.are.equal(2, tickCalls)
    assert.are.equal(1, flushCalls)
    assert.are.equal(1, countSent("queue add full get sovereigns"))
    assert.are.equal(operation.generation, boop.state.gold.operation.generation)
    assert.are.equal(0, boop.state.gold.operation.getRetries)
  end)

  it("resumes one unchanged gold stage when lifecycle readiness returns", function()
    seedSettledGoldRoom("1", 1)
    boop.config.goldPack = ""
    boop.runtime.beginConnectionLifecycle("gold reconnect test")
    gmcp.IRE = nil
    boop.onCharStatus()
    assert.is_false(boop.runtime.lifecycleSnapshot().ready)
    assert.are.equal(0, #boop.runtime.operationLocksSnapshot())
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

    local lifecycle = boop.runtime.lifecycleSnapshot()
    assert.is_true(lifecycle.ireSeen)
    assert.is_false(lifecycle.promptSeen)
    assert.is_false(lifecycle.ready)
    assert.are.equal(0, tickCalls)
    assert.are.equal(0, flushCalls)
    assert.are.equal(0, countGoldSends())

    boop.onPrompt()

    assert.is_true(boop.runtime.lifecycleSnapshot().ready)
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

  it("keeps current gold unchanged when a late old-room List arrives before its barrier", function()
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

    publishItemsList("room", { goldItem("9001") })

    assert.are.same(current, copyGoldOperation(boop.state.gold.operation))
    assert.are.equal(sendCount, countGoldSends())
  end)

  it("invalidates a current room-owned stage on an actual room change and makes its captured timers stale", function()
    seedSettledGoldRoom("1", 1)
    boop.config.goldPack = ""
    boop.onGoldDropLine("A handful of sovereigns spills onto the ground.")
    local operation = copyGoldOperation(boop.state.gold.operation)
    local callbacks = {}
    for _, entry in ipairs(scheduled_callbacks) do
      callbacks[#callbacks + 1] = entry.callback
    end

    gmcp.Room.Info = {
      num = 2,
      area = "Test Area",
      exits = { south = 1 },
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

  it("same-room-gold-pipeline rejects wrong-room gold and cancels actual movement once", function()
    _G.demonwalker = {
      enabled = true,
      init = function() return true end,
    }
    boop.config.enabled = true
    boop.config.autoGrabGold = true
    boop.config.useQueueing = false
    boop.config.goldPack = "pack"
    boop.config.targetingMode = "auto"
    boop.state.targeting.room = ""

    gmcp.Room.Info = {
      num = "1",
      area = "Room A",
      exits = {},
    }
    boop.onRoomInfo()
    publishItemsList("inv", {})
    publishItemsList("room", {
      denizenItem("101", "the retained room A denizen"),
      goldItem("9001"),
    })
    assert.is_true(runPendingRoomApplication())

    local operation = copyGoldOperation(boop.state.gold.operation)
    assert.are.equal("pickup_pending", operation.phase)
    assert.are.equal(1, countSent("queue add full get sovereigns"))
    local oldTimeout = callbackForTimer(operation.timeoutTimer)
    assert.is_function(oldTimeout)

    local state = boop.runtime.state()
    state.walk.active = true
    state.walk.owned = false
    state.walk.roomSettled = true
    state.walk.moveQueued = false
    state.walk.arrivalRoom = "1"
    state.walk.generation = 44
    state.walk.roomGeneration =
      boop.runtime.roomObservationSnapshot().generation
    state.walk.moveIssuedForRoomGeneration = false
    state.walk.reservationId = 7
    captureRuntimeBlockerCalls()

    gmcp.Room.Info = {
      num = "2",
      area = "Room B",
      exits = { south = "1" },
    }
    boop.onRoomInfo()
    gmcp.Room.Info = {
      num = "3",
      area = "Room C",
      exits = { south = "2" },
    }
    boop.onRoomInfo()

    local function goldOwnerClearCount()
      local count = 0
      for _, call in ipairs(clear_blocker_calls) do
        if tostring(call[1] or "") == tostring(operation.blockerOwner) then
          count = count + 1
        end
      end
      return count
    end

    assert.is_false(boop.state.gold.operation)
    assert.are.equal(1, goldOwnerClearCount())
    local sendsAfterMove = countGoldSends()
    local denizenAfterMove = boop.state.targeting.denizens[1]
      and boop.state.targeting.denizens[1].name
      or false
    local reservationAfterMove = state.walk.reservationId

    publishItemsList("room", {
      denizenItem("201", "a pre-barrier wrong-room denizen"),
      goldItem("9201"),
    })
    publishItemsList("inv", {})
    publishItemsList("room", {
      denizenItem("202", "an invalidated-fence denizen"),
      goldItem("9202"),
    })
    publishItemsList("room", {
      denizenItem("203", "an early current-fence denizen"),
      goldItem("9203"),
    })
    oldTimeout()
    assert.is_false(boop.onGoldGetSuccess())
    assert.is_false(boop.onGoldCommandFailure("late wrong-room retry"))

    assert.are.equal(sendsAfterMove, countGoldSends())
    assert.are.equal(denizenAfterMove, boop.state.targeting.denizens[1].name)
    assert.are.equal(reservationAfterMove, state.walk.reservationId)
    assert.are.equal(0, countRaised("demonwalker.move"))
    assert.are.equal(1, goldOwnerClearCount())
    assert.is_nil(blockerFor("walk:44"))
    assert.are.equal(0, #boop.runtime.operationLocksSnapshot())

    boop.config.useQueueing = true
    boop.executeAction("warp 42")
    boop.executeRageAction("harry 42")
    assert.are.equal(
      "setalias BOOP_ATTACK warp 42",
      sent_commands[#sent_commands - 2].command
    )
    assert.are.equal(
      "queue addclearfull freestand BOOP_ATTACK",
      sent_commands[#sent_commands - 1].command
    )
    assert.are.equal("harry 42", sent_commands[#sent_commands].command)
    for i = #sent_commands - 2, #sent_commands do
      assert.is_nil(sent_commands[i].command:find("sovereigns", 1, true))
    end

    helper.reset()
    sent_commands = {}
    gmcp_requests = {}
    raised_events = {}
    scheduled_callbacks = {}
    scheduled_callback = nil
    boop.config.enabled = true
    boop.config.autoGrabGold = false
    boop.config.useQueueing = false
    boop.config.goldPack = ""
    boop.state.targeting.room = ""
    gmcp.Room.Info = {
      num = "1",
      area = "Canonical Room",
      exits = {},
    }
    boop.onRoomInfo()
    publishItemsList("inv", {})
    publishItemsList("room", { goldItem("9301") })
    assert.is_false(boop.state.gold.operation)

    boop.state.targeting.room = "2"
    boop.config.autoGrabGold = true
    boop.onGoldDropLine("Wrong-room sovereigns appear.")

    assert.are.equal(
      0,
      countGoldSends(),
      "GOLD_SAME_ROOM_PIPELINE_BROKEN: persistent GMCP authorized wrong-room gold"
    )
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

  it("keeps computed readiness independent from an active operation", function()
    boop.config.enabled = true
    boop.runtime.beginConnectionLifecycle("event boundary test")
    gmcp.IRE = nil
    helper.setRuntimeBlocker({
      owner = "interrupt:88",
      code = "interrupt_pending",
      label = "interrupt pending",
      systems = { combat = true, walk = true },
      waitsFor = { prompt = true },
    })

    boop.onCharStatus()
    assert.is_false(boop.runtime.lifecycleSnapshot().ready)
    assert.are.equal("interrupt:88", blockerSnapshot().owner)

    gmcp.Room.Info = {
      num = "2",
      area = "Test Area",
      exits = { south = "1" },
    }
    boop.onRoomInfo()
    assert.is_false(boop.runtime.readinessSnapshot().room.ready)
    assert.are.equal("interrupt:88", blockerSnapshot().owner)

    publishAcceptedRoomList({})
    assert.is_true(boop.runtime.readinessSnapshot().room.ready)
    assert.are.equal("interrupt:88", blockerSnapshot().owner)

    gmcp.IRE = {
      Display = { ButtonActions = {} },
    }
    boop.onIreSupportObserved("gmcp.IRE.Display.ButtonActions")
    assert.is_false(boop.runtime.lifecycleSnapshot().ready)
    boop.onPrompt()
    assert.is_true(boop.runtime.lifecycleSnapshot().ready)
    assert.are.equal("interrupt:88", blockerSnapshot().owner)
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
    it("keeps operations independent from " .. case.name .. " evidence", function()
      helper.setTarget("42", "a removed denizen", "80%")
      helper.setDenizens({
        { id = "42", name = "a removed denizen" },
        { id = "77", name = "a set replacement" },
        { id = "78", name = "an info replacement" },
      })
      helper.setRuntimeBlocker({
        owner = "interrupt:88",
        code = "interrupt_pending",
        systems = { combat = true },
        waitsFor = { timeout = true },
      })
      boop.config.enabled = true
      boop.config.targetingMode = "auto"

      case.invoke()

      local blockers = boop.runtime.operationLocksSnapshot()
      assert.are.equal(1, #blockers)
      assert.are.equal("interrupt:88", blockers[1].owner)
      assert.is_nil(blockerFor("target:loss"))
      assert.is_nil(blockerFor("room:observation"))
    end)
  end

  it("clears old-room target identity on movement without stopping walk", function()
    helper.setArea("Test Area")
    helper.setTarget("42", "Thierry, the ferryman", "80%")
    helper.setDenizens({
      { id = "42", name = "Thierry, the ferryman" },
    })
    boop.state.targeting.room = "1"
    boop.state.walk.active = true
    boop.state.walk.owned = true
    boop.state.walk.generation = 17
    boop.config.enabled = true
    boop.config.targetingMode = "whitelist"
    helper.setWhitelist("Test Area", { "Thierry, the ferryman" })

    gmcp.Room.Info = {
      num = "2",
      area = "Test Area",
      exits = { west = "1" },
    }
    boop.onRoomInfo()

    assert.are.equal("", boop.state.targeting.currentTargetId)
    assert.are.equal("", boop.state.targeting.targetName)
    assert.is_true(boop.state.walk.active)
    assert.is_true(boop.state.walk.owned)
    assert.are.equal(17, boop.state.walk.generation)
    assert.is_nil(blockerFor("room:observation"))
    assert.is_nil(blockerFor("target:loss"))
    assert.is_nil(blockerFor("walk:17"))
  end)

  it("reconciles an absent target from accepted room contents", function()
    helper.setArea("Test Area")
    helper.setTarget("42", "Thierry, the ferryman", "80%")
    helper.setDenizens({
      { id = "42", name = "Thierry, the ferryman" },
    })
    boop.state.targeting.room = "1"
    boop.config.enabled = false
    boop.config.targetingMode = "whitelist"
    helper.setWhitelist("Test Area", { "Thierry, the ferryman" })

    boop.runtime.startRoomObservation("1", {
      boundary = "fresh_start",
      reason = "accepted empty room test",
    })
    publishAcceptedRoomList({})

    assert.are.equal("", boop.state.targeting.currentTargetId)
    assert.are.equal("", boop.state.targeting.targetName)
    assert.are.equal(0, #boop.state.targeting.denizens)
    assert.are.equal(0, #boop.runtime.operationLocksSnapshot())
  end)

  it("recovers an empty room after target removal without stopping walk or creating a target owner", function()
    helper.setArea("Test Area")
    helper.setTarget("42", "a departing denizen", "80%")
    helper.setDenizens({
      { id = "42", name = "a departing denizen" },
    })
    helper.seedRoomObservation("1", {
      generation = 5,
      infoSeen = true,
      itemsSeen = true,
      acceptedItems = {
        denizenItem("42", "a departing denizen"),
      },
    })
    boop.state.targeting.room = "1"
    boop.state.walk.active = true
    boop.state.walk.owned = true
    boop.state.walk.generation = 23
    boop.state.walk.roomGeneration = 5
    boop.state.walk.arrivalRoom = "1"
    boop.config.enabled = true
    boop.config.targetingMode = "auto"

    gmcp.Char.Items.Remove = {
      location = "room",
      item = denizenItem("42", "a departing denizen"),
    }
    boop.onRoomItemsRemove()

    assert.are.equal("", boop.state.targeting.currentTargetId)
    assert.is_true(boop.state.walk.active)
    assert.is_nil(blockerFor("target:loss"))

    local callback = scheduled_callbacks[#scheduled_callbacks]
      and scheduled_callbacks[#scheduled_callbacks].callback
    assert.is_function(callback)
    callback()

    assert.is_true(boop.state.walk.active)
    assert.are.equal(23, boop.state.walk.generation)
    assert.is_nil(blockerFor("target:loss"))
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

    assert.are.equal("", boop.state.targeting.currentTargetId)
    assert.is_function(scheduled_callback)
    scheduled_callback()

    assert.are.equal("43", boop.state.targeting.currentTargetId)
    assert.are.equal("a second denizen", boop.state.targeting.targetName)
    assert.is_false(boop.state.targeting.targetShield)
    assert.is_false(boop.afflictions.hasTarget("stupidity"))
    assert.stub(kill_timer_stub).was_called_with(77)
    assert.stub(send_stub).was_called_with("settarget 43", false)
    assert.stub(send_stub).was_not_called_with("queue clear", false)

    assert.stub(send_stub).was_called_with("setalias BOOP_ATTACK command hound at 43", false)
    assert.stub(send_stub).was_called_with("queue addclearfull freestand BOOP_ATTACK", false)
  end)

  it("retargets only after fresh room evidence replaces a lost target", function()
    helper.setArea("Test Area")
    helper.setClass("Occultist")
    helper.learnSkill("Lycantha", "Domination")
    helper.setDenizens({
      { id = "42", name = "a departing denizen" },
    })
    helper.setTarget("42", "a departing denizen", "80%")
    helper.seedRoomObservation("1", {
      generation = 5,
      infoSeen = true,
      itemsSeen = true,
      acceptedItems = {
        denizenItem("42", "a departing denizen"),
      },
    })
    boop.state.targeting.room = "1"
    boop.config.enabled = true
    boop.config.useQueueing = true
    boop.config.targetingMode = "auto"
    captureRuntimeBlockerCalls()

    gmcp.Char.Items.Remove = {
      location = "room",
      item = denizenItem("42", "a departing denizen"),
    }
    boop.onRoomItemsRemove()
    local lossCallback = scheduled_callbacks[#scheduled_callbacks].callback
    assert.is_function(lossCallback)
    lossCallback()
    assert.is_nil(blockerFor("target:loss"))
    assert.are.equal("", boop.state.targeting.currentTargetId)

    helper.setRuntimeBlocker({
      owner = "interrupt:retained",
      code = "interrupt_pending",
      systems = {},
      waitsFor = { timeout = true },
    })
    boop.onPrompt()
    assert.is_nil(blockerFor("target:loss"))

    gmcp.Room.Info = {
      num = "2",
      area = "Test Area",
      exits = { west = "1" },
    }
    boop.onRoomInfo()
    assert.is_nil(blockerFor("target:loss"))
    assert.is_nil(blockerFor("room:observation"))
    assert.is_false(boop.runtime.readinessSnapshot().room.ready)

    publishAcceptedRoomList({
      denizenItem("43", "a fresh denizen"),
    })

    assert.is_nil(blockerFor("target:loss"))
    assert.is_nil(blockerFor("room:observation"))
    assert.is_table(blockerFor("interrupt:retained"))
    assert.are.equal("43", boop.state.targeting.currentTargetId)
    assert.are.equal("a fresh denizen", boop.state.targeting.targetName)
    assert.are.equal(1, countSent("settarget 43"))
    assert.are.equal(
      1,
      countSent("setalias BOOP_ATTACK command hound at 43")
    )
    assert.are.equal(
      1,
      countSent("queue addclearfull freestand BOOP_ATTACK")
    )
    assert.are.equal(0, countSent("settarget 42"))
  end)

  it("wakes targeting when a valid denizen is added", function()
    helper.setArea("Test Area")
    helper.setClass("Occultist")
    helper.learnSkill("Lycantha", "Domination")
    helper.setDenizens({})
    helper.setTarget("", "", "100%")
    boop.state.targeting.room = "1"
    boop.config.enabled = true
    boop.config.useQueueing = true
    boop.config.targetingMode = "auto"
    gmcp.Char.Items.Add = {
      location = "room",
      item = denizenItem("44", "an arriving denizen"),
    }
    boop.onRoomItemsAdd()

    assert.is_nil(blockerFor("target:loss"))
    assert.are.equal("44", boop.state.targeting.denizens[1].id)
    local wakeCallback = scheduled_callbacks[#scheduled_callbacks].callback
    assert.is_function(wakeCallback)
    wakeCallback()
    assert.are.equal("44", boop.state.targeting.currentTargetId)
    assert.are.equal(1, countSent("settarget 44"))
    assert.are.equal(
      1,
      countSent("setalias BOOP_ATTACK command hound at 44")
    )
    assert.are.equal(
      1,
      countSent("queue addclearfull freestand BOOP_ATTACK")
    )
  end)

  it("G-03-11 preserves a denizen Add newer than the pending room snapshot", function()
    helper.setArea("Test Area")
    helper.setClass("Occultist")
    helper.learnSkill("Lycantha", "Domination")
    helper.setDenizens({})
    helper.setTarget("", "", "100%")
    boop.state.targeting.room = "1"
    boop.config.enabled = true
    boop.config.useQueueing = true
    boop.config.targetingMode = "auto"

    gmcp.Room.Info = {
      num = "2",
      area = "Test Area",
      exits = { west = "1" },
    }
    boop.onRoomInfo()
    publishItemsList("inv", {})

    gmcp.Char.Items.Add = {
      location = "room",
      item = denizenItem("44", "an arriving denizen"),
    }
    boop.onRoomItemsAdd()

    publishItemsList("room", {
      {
        id = "7001",
        name = "an unrelated room item",
        attrib = "t",
      },
    })
    assert.is_true(runPendingRoomApplication())

    assert.are.equal(1, #boop.state.targeting.denizens)
    assert.are.equal("44", boop.state.targeting.denizens[1].id)
    assert.are.equal("44", boop.state.targeting.currentTargetId)
    assert.are.equal(1, countSent("settarget 44"))
    assert.are.equal(
      1,
      countSent("setalias BOOP_ATTACK command hound at 44")
    )
    assert.are.equal(
      1,
      countSent("queue addclearfull freestand BOOP_ATTACK")
    )
    assert.are.equal("Char.Items.Inv", gmcp_requests[1])
    assert.are.equal("Char.Items.Room", gmcp_requests[2])
    assert.are.equal(1, countGmcpRequest("Char.Items.Room"))
  end)

  it("G-03-11 preserves a denizen Remove newer than the pending room snapshot", function()
    helper.setArea("Test Area")
    helper.setClass("Occultist")
    helper.learnSkill("Lycantha", "Domination")
    helper.setDenizens({})
    helper.setTarget("", "", "100%")
    boop.state.targeting.room = "1"
    boop.config.enabled = true
    boop.config.useQueueing = true
    boop.config.targetingMode = "auto"

    gmcp.Room.Info = {
      num = "2",
      area = "Test Area",
      exits = { west = "1" },
    }
    boop.onRoomInfo()
    publishItemsList("inv", {})

    gmcp.Char.Items.Remove = {
      location = "room",
      item = denizenItem("44", "a departing denizen"),
    }
    boop.onRoomItemsRemove()

    publishItemsList("room", {
      denizenItem("44", "a departing denizen"),
    })
    assert.is_true(runPendingRoomApplication())

    assert.are.equal(0, #boop.state.targeting.denizens)
    assert.are.equal("", boop.state.targeting.currentTargetId)
    assert.are.equal(0, countSent("settarget 44"))
    assert.are.equal(
      0,
      countSent("setalias BOOP_ATTACK command hound at 44")
    )
    assert.are.equal("Char.Items.Inv", gmcp_requests[1])
    assert.are.equal("Char.Items.Room", gmcp_requests[2])
    assert.are.equal(1, countGmcpRequest("Char.Items.Room"))
  end)

  it("G-03-11 preserves an Add received after the room snapshot response", function()
    helper.setArea("Test Area")
    helper.setClass("Occultist")
    helper.learnSkill("Lycantha", "Domination")
    helper.setDenizens({})
    helper.setTarget("", "", "100%")
    boop.state.targeting.room = "1"
    boop.config.enabled = true
    boop.config.useQueueing = true
    boop.config.targetingMode = "auto"

    gmcp.Room.Info = {
      num = "2",
      area = "Test Area",
      exits = { west = "1" },
    }
    boop.onRoomInfo()
    publishItemsList("inv", {})
    publishItemsList("room", {})

    gmcp.Char.Items.Add = {
      location = "room",
      item = denizenItem("44", "an arriving denizen"),
    }
    boop.onRoomItemsAdd()
    assert.is_true(runPendingRoomApplication())

    assert.are.equal(1, #boop.state.targeting.denizens)
    assert.are.equal("44", boop.state.targeting.currentTargetId)
    assert.are.equal(1, countSent("settarget 44"))
    assert.are.equal(1, countGmcpRequest("Char.Items.Room"))
  end)

  it("G-03-11 keeps restrictive snapshot attributes for duplicate Add ids", function()
    helper.setArea("Test Area")
    helper.setClass("Occultist")
    helper.learnSkill("Lycantha", "Domination")
    helper.setDenizens({})
    helper.setTarget("", "", "100%")
    boop.state.targeting.room = "1"
    boop.config.enabled = true
    boop.config.useQueueing = true
    boop.config.targetingMode = "auto"

    gmcp.Room.Info = {
      num = "2",
      area = "Test Area",
      exits = { west = "1" },
    }
    boop.onRoomInfo()
    publishItemsList("inv", {})

    gmcp.Char.Items.Add = {
      location = "room",
      item = denizenItem("44", "a protected denizen"),
    }
    boop.onRoomItemsAdd()
    publishItemsList("room", {
      {
        id = "44",
        name = "a protected denizen",
        attrib = "mx",
      },
    })
    assert.is_true(runPendingRoomApplication())

    assert.are.equal(0, #boop.state.targeting.denizens)
    assert.are.equal("", boop.state.targeting.currentTargetId)
    assert.are.equal(0, countSent("settarget 44"))
  end)

  describe("G-03-5 settled-add-revalidation", function()
    local function seedSettledNonGoldRoom()
      _G.demonwalker = {
        enabled = true,
        init = function() return true end,
      }
      boop.config.enabled = true
      boop.config.autoGrabGold = true
      boop.config.useQueueing = false
      boop.config.goldPack = ""
      boop.config.targetingMode = "auto"
      boop.config.prequeueEnabled = true
      boop.state.targeting.room = "1"
      gmcp.Room.Info = {
        num = "1",
        area = "Test Area",
        exits = {},
      }
      local denizens = {
        denizenItem("42", "a first denizen"),
        denizenItem("43", "a second denizen"),
      }
      helper.setDenizens(denizens)
      helper.setTarget("42", "a first denizen", "80%")
      helper.seedRoomObservation("1", {
        generation = 5,
        infoSeen = true,
        itemsSeen = true,
        acceptedItems = denizens,
      })
      local state = boop.runtime.state()
      state.walk.active = true
      state.walk.owned = false
      state.walk.roomSettled = true
      state.walk.moveQueued = false
      state.walk.arrivalRoom = "1"
      state.walk.generation = 44
      state.walk.roomGeneration = 5
      state.walk.moveIssuedForRoomGeneration = false
      state.walk.reservationId = 0
      helper.setRuntimeBlocker({
        owner = "interrupt:retained-audit",
        code = "interrupt_pending",
        label = "retained unrelated owner",
        systems = {
          combat = true,
          queue = true,
          gold = true,
          walk = true,
        },
        waitsFor = { timeout = true },
      })
      captureRuntimeBlockerCalls()
      return denizens
    end

    local function publishGoldAdd(id)
      gmcp.Char.Items.Add = {
        location = "room",
        item = goldItem(id),
      }
      boop.onRoomItemsAdd()
    end

    it("retargets while exact gold and unrelated owners keep all downstream work held", function()
      local denizens = seedSettledNonGoldRoom()
      publishGoldAdd("9001")

      local operation = copyGoldOperation(boop.state.gold.operation)
      assert.are.equal("deferred_room", operation.phase)
      assert.are.equal("gold:1", operation.blockerOwner)
      assert.is_true(operation.revalidationAttempted)
      assert.are.same({ "Char.Items.Room" }, gmcp_requests)
      assert.is_table(blockerFor(operation.blockerOwner))
      assert.is_table(blockerFor("interrupt:retained-audit"))

      gmcp.Char.Items.Remove = {
        location = "room",
        item = denizens[1],
      }
      boop.onRoomItemsRemove()
      assert.are.equal("", boop.state.targeting.currentTargetId)
      assert.is_table(blockerFor(operation.blockerOwner))
      assert.is_true(boop.runtime.shouldHold("queue"))

      local retargetCallback = scheduled_callbacks[#scheduled_callbacks].callback
      assert.is_function(retargetCallback)
      retargetCallback()
      assert.are.equal("43", boop.state.targeting.currentTargetId)
      assert.are.equal(0, countGoldSends())
      assert.are.equal(0, countSent("queue clear"))
      assert.are.equal(0, countSent("command hound at 43"))
      assert.are.equal(0, countSent("harry 43"))
      assert.are.equal(0, countSent("setalias BOOP_ATTACK command hound at 43"))
      assert.are.equal(0, countRaised("demonwalker.move"))

      publishItemsList("room", {
        denizens[2],
        goldItem("9001"),
      })
      assert.is_true(runPendingRoomApplication())

      local accepted = copyGoldOperation(boop.state.gold.operation)
      assert.are.equal(operation.generation, accepted.generation)
      assert.are.equal("pickup_pending", accepted.phase)
      assert.is_table(blockerFor(accepted.blockerOwner))
      assert.is_table(blockerFor("interrupt:retained-audit"))
      assert.are.equal(0, countGoldSends())
      assert.are.equal(0, countRaised("demonwalker.move"))

      boop.runtime.clearOperationLock(
        "interrupt:retained-audit",
        "real release"
      )
      assert.is_true(boop.flushPendingGold("unrelated owner released"))
      assert.are.equal(1, countGoldSends())
      assert.are.equal(0, countSent("queue clear"))
      assert.are.equal(0, countRaised("demonwalker.move"))
    end)

    it("drains a moved-room response without gold, attack, or walk side effects", function()
      seedSettledNonGoldRoom()
      publishGoldAdd("9001")

      local operation = copyGoldOperation(boop.state.gold.operation)
      local oldFence = boop.runtime.roomObservationSnapshot().fenceQueue[1]
      assert.is_table(oldFence)
      assert.are.equal("await_room", oldFence.phase)
      assert.are.equal(operation.revalidationFenceId, oldFence.fenceId)

      publishGoldAdd("9001")
      assert.are.same({ "Char.Items.Room" }, gmcp_requests)

      gmcp.Room.Info = {
        num = "2",
        area = "Moved Room",
        exits = { south = "1" },
      }
      boop.onRoomInfo()

      assert.is_false(boop.state.gold.operation)
      assert.is_nil(blockerFor(operation.blockerOwner))
      assert.is_table(blockerFor("interrupt:retained-audit"))
      local moved = boop.runtime.roomObservationSnapshot()
      assert.is_false(moved.itemsSeen)
      assert.are.equal(0, boop.runtime.state().walk.reservationId)

      publishItemsList("room", { goldItem("9001") })

      local drained = boop.runtime.roomObservationSnapshot()
      assert.is_false(drained.itemsSeen)
      assert.is_false(boop.state.gold.operation)
      assert.is_table(blockerFor("interrupt:retained-audit"))
      assert.are.equal(0, countGoldSends())
      assert.are.equal(0, countSent("queue clear"))
      assert.are.equal(0, countRaised("demonwalker.move"))
      assert.are.equal(0, countRaised("demonwalker.stop"))
    end)
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

    assert.are.equal("", boop.state.targeting.currentTargetId)
    assert.is_false(boop.afflictions.hasTarget("stupidity"))
    assert.is_function(scheduled_callback)
    assert.are.equal(0, countSent("queue clear"))
    assert.are.equal(0, countSent("command hound at 43"))
    assert.are.equal(0, countSent("harry 43"))
    assert.are.equal(0, countSent("setalias BOOP_ATTACK command hound at 43"))

    scheduled_callback()

    assert.are.equal("43", boop.state.targeting.currentTargetId)
    assert.are.equal(0, countSent("queue clear"))
    assert.are.equal(0, countSent("command hound at 43"))
    assert.are.equal(0, countSent("harry 43"))
    assert.are.equal(0, countSent("setalias BOOP_ATTACK command hound at 43"))
  end)

  it("clears stale attack intent before same-tick retargeting from valid current-room denizens", function()
    helper.setArea("Test Area")
    helper.setClass("Occultist")
    helper.learnSkill("Lycantha", "Domination")
    publishAcceptedRoomList({
      { id = "42", name = "a first denizen", attrib = "m" },
      { id = "43", name = "an excluded denizen", attrib = "mx" },
      { id = "44", name = "a valid replacement", attrib = "m" },
    })
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
    local retargetCallback = scheduled_callbacks[#scheduled_callbacks].callback
    assert.is_function(retargetCallback)
    retargetCallback()

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
    boop.config.enabled = true
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
    assert.are.equal(0, #boop.runtime.operationLocksSnapshot())
  end)

  it("clears tracked shield state when gmcp target info changes", function()
    boop.config.enabled = true
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
    assert.are.equal(0, #boop.runtime.operationLocksSnapshot())
  end)

  it("clears stale target name when gmcp target set clears", function()
    boop.config.enabled = true
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

  it("routes current Room.Info and complete List through walker state", function()
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
    local oldEmitter = state.walk.emitterTimer
    local oldEmitterCallback
    for _, entry in ipairs(scheduled_callbacks) do
      if entry.id == oldEmitter then
        oldEmitterCallback = entry.callback
      end
    end
    assert.is_function(oldEmitterCallback)
    assert.are.equal(0, #boop.runtime.operationLocksSnapshot())

    gmcp.Room.Info = {
      num = 2,
      area = "Test Area",
      exits = { south = 1 },
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
    assert.is_false(boop.runtime.readinessSnapshot().room.ready)
    assert.are.equal(0, #boop.runtime.operationLocksSnapshot())

    local roomGeneration = state.walk.roomGeneration
    local reservationAfterRoomInfo = state.walk.reservationId
    oldEmitterCallback()
    assert.are.equal(0, countRaised("demonwalker.move"))
    assert.are.equal(12, state.walk.generation)
    assert.are.equal(roomGeneration, state.walk.roomGeneration)
    assert.are.equal(reservationAfterRoomInfo, state.walk.reservationId)

    publishAcceptedRoomList({})

    assert.is_true(boop.runtime.roomObservationSnapshot().itemsSeen)
    assert.is_true(state.walk.roomSettled)
    assert.is_true(state.walk.moveQueued)
    assert.is_true(state.walk.moveIssuedForRoomGeneration)
    assert.are.equal(reservationAfterRoomInfo + 1, state.walk.reservationId)
    assert.are.equal(0, #boop.runtime.operationLocksSnapshot())
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

  it("ignores a stale finished adapter callback after restart", function()
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
        owner = "interrupt:retained-audit",
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
      assert.is_nil(blockerFor("room:observation"))
      assert.is_false(boop.runtime.readinessSnapshot().room.ready)
      assert.is_table(blockerFor("interrupt:retained-audit"))

      boop.onPrompt()
      assert.is_false(boop.state.diag.operation)
      assert.is_nil(blockerFor(interrupt.blockerOwner))
      assert.is_table(blockerFor(pull.blockerOwner))
      assert.is_nil(blockerFor("room:observation"))
      assert.is_table(blockerFor("interrupt:retained-audit"))

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
      assert.is_nil(blockerFor("room:observation"))
      assert.is_table(blockerFor("interrupt:retained-audit"))

      pullTimeout()
      assert.is_false(boop.state.combat.pullState)
      assert.are.equal(2, #sent_commands)
      assert.are.equal(4, #scheduled_callbacks)
      assert.are.equal(4, #gmcp_requests)
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
        owner = "interrupt:retained-audit",
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
      assert.are.equal("", boop.state.targeting.currentTargetId)
      assert.are.same(operation, copyGoldOperation(boop.state.gold.operation))
      assert.is_table(blockerFor("interrupt:retained-audit"))
      assert.are.equal(0, countSent("queue clear"))
      assert.are.equal(0, countSent("command hound at 43"))
      assert.are.equal(0, countSent("harry 43"))
      assert.are.equal(0, countSent("setalias BOOP_ATTACK command hound at 43"))

      retargetCallback()

      assert.are.equal("43", boop.state.targeting.currentTargetId)
      assert.are.equal(case.expectedGoldSends, countGoldSends())
      assert.are.equal(0, countSent("queue clear"))
      assert.are.equal(0, countSent("command hound at 43"))
      assert.are.equal(0, countSent("harry 43"))
      assert.are.equal(0, countSent("setalias BOOP_ATTACK command hound at 43"))
      assert.is_false(case.stale())
      assert.are.same(operation, copyGoldOperation(boop.state.gold.operation))
      assert.is_table(blockerFor("interrupt:retained-audit"))
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
      owner = "interrupt:retained-audit",
      code = "interrupt_pending",
      label = "retained unrelated owner",
      systems = { audit = true },
      waitsFor = { timeout = true },
    })

    publishAcceptedRoomList({
      { id = "42", name = "a denizen", attrib = "m" },
      goldItem("9001"),
    })

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

    gmcp.Char.Items.Remove = {
      location = "room",
      item = { id = "42", name = "a denizen", attrib = "m" },
    }
    boop.onRoomItemsRemove()
    goldTerminal()

    assert.are.equal(1, state.walk.reservationId)
    assert.is_true(state.walk.moveQueued)
    assert.is_nil(blockerFor("walk:12"))
    assert.is_table(blockerFor("interrupt:retained-audit"))
    local emitter = callbackForTimer(state.walk.emitterTimer)
    assert.is_function(emitter)

    emitter()
    emitter()

    assert.are.equal(1, countRaised("demonwalker.move"))
    assert.are.equal(0, countRaised("demonwalker.stop"))
    assert.are.equal(1, countGoldSends())
    assert.is_table(blockerFor("interrupt:retained-audit"))
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
      owner = "interrupt:retained-audit",
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

    publishAcceptedRoomList({ goldItem("9002") })

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
    assert.is_table(blockerFor("interrupt:retained-audit"))
  end)

  it("treats Mudlet event names as adapter metadata instead of generation tokens", function()
    local arrivedArgumentCounts = {}
    local finishedRunGeneration = "unset"
    walk_arrived_adapter_stub = stub(boop.walk, "onArrived", function(...)
      arrivedArgumentCounts[#arrivedArgumentCounts + 1] = select("#", ...)
      return true
    end)
    walk_finished_adapter_stub = stub(boop.walk, "onFinished", function(runGeneration)
      finishedRunGeneration = runGeneration
      return true
    end)

    assert.is_true(boop.onWalkArrived("demonwalker.arrived"))
    assert.is_true(boop.onWalkArrived(999, 999))
    assert.is_true(boop.onWalkFinished("demonwalker.finished"))

    assert.are.same({ 0, 0 }, arrivedArgumentCounts)
    assert.is_nil(finishedRunGeneration)
  end)

  it("re-announces core gmcp supports on connection-ready events", function()
    boop.onConnectionEvent()

    assert.stub(send_gmcp_stub).was_called_with('Core.Supports.Add ["IRE.Target 1"]')
    assert.stub(send_gmcp_stub).was_called_with('Core.Supports.Add ["IRE.Display 3"]')
    assert.stub(send_gmcp_stub).was_called_with('Core.Supports.Add ["Char.Afflictions 1"]')
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
