local helper = dofile(os.getenv("TESTS_DIRECTORY") .. "/support/boop_test_helper.lua")

describe("boop walk integration", function()
  local saved_temp_timer
  local saved_kill_timer
  local saved_send
  local saved_send_gmcp
  local saved_feedback
  local saved_trace_log
  local saved_save_config
  local saved_matches
  local timers
  local walker
  local sent_gmcp
  local sent
  local feedback
  local trace_lines
  local config_saves

  local function countRaised(name)
    local count = 0
    for _, event in ipairs((walker and walker.raisedEvents) or {}) do
      if event.name == name then
        count = count + 1
      end
    end
    return count
  end

  local function countSent(command)
    local count = 0
    for _, entry in ipairs(sent or {}) do
      if entry.command == command then
        count = count + 1
      end
    end
    return count
  end

  local function publishItemsList(location, items)
    gmcp.Char.Items.List = {
      location = location,
      items = items,
    }
    return boop.onRoomItemsList()
  end

  local function countContaining(lines, needle)
    local count = 0
    for _, line in ipairs(lines or {}) do
      if tostring(line):find(needle, 1, true) then
        count = count + 1
      end
    end
    return count
  end

  local function resetCase(opts)
    if walker then
      walker.restore()
    end
    helper.reset()
    timers = helper.newTimerQueue()
    sent = {}
    sent_gmcp = {}
    feedback = {
      err = {},
      info = {},
      ok = {},
      warn = {},
    }
    trace_lines = {}
    config_saves = {}

    _G.tempTimer = timers.tempTimer
    _G.killTimer = timers.killTimer
    _G.send = function(command, echoBack)
      sent[#sent + 1] = {
        command = command,
        echoBack = echoBack,
      }
    end
    _G.sendGMCP = function(command)
      sent_gmcp[#sent_gmcp + 1] = command
    end
    boop.db.saveConfig = function(key, value)
      config_saves[#config_saves + 1] = {
        key = key,
        value = value,
      }
    end
    walker = helper.setWalker(opts or {
      available = true,
      attached = true,
    })
  end

  local function walkStateSnapshot()
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
      blockers = boop.runtime.blockersSnapshot(),
    }
  end

  local function seedReadyWalk(opts)
    opts = opts or {}
    local roomId = tostring(opts.roomId or "101")
    local roomGeneration = tonumber(opts.roomGeneration) or 9
    local state = boop.runtime.state()

    boop.config.enabled = opts.enabled ~= false
    boop.config.targetingMode = opts.targetingMode or "auto"
    boop.config.targetCall = false
    boop.config.assistLeader = ""
    helper.seedRoomObservation(roomId, {
      generation = roomGeneration,
      infoSeen = true,
      itemsSeen = opts.itemsSeen ~= false,
    })
    helper.setTarget("", "", "100%")
    helper.setDenizens({})

    state.walk.active = opts.active ~= false
    state.walk.owned = opts.owned ~= false
    state.walk.roomSettled = opts.roomSettled ~= false
    state.walk.moveQueued = opts.moveQueued == true
    state.walk.arrivalRoom = roomId
    state.walk.generation = tonumber(opts.generation) or 7
    state.walk.roomGeneration = roomGeneration
    state.walk.moveIssuedForRoomGeneration =
      opts.moveIssuedForRoomGeneration == true
    state.walk.reservationId = tonumber(opts.reservationId) or 0
    state.walk.refreshTimer = opts.refreshTimer
    state.walk.emitterTimer = opts.emitterTimer
    state.walk.refreshWarned = opts.refreshWarned == true
    return state
  end

  local function currentWalkOwner()
    local walk = boop.runtime.state().walk
    return "walk:" .. tostring(walk.generation)
  end

  local function assertOwner(owner, code, label)
    local blocker = boop.runtime.state().combat.blockersByOwner[owner]
    assert.is_table(blocker)
    assert.are.equal(code, blocker.code)
    assert.are.equal(label, blocker.label)
    assert.are.same({ walk = true }, blocker.systems)
    return blocker
  end

  local function runTargetingAlias(mode)
    local previousMatches = _G.matches
    _G.matches = {
      "boop targeting " .. tostring(mode),
      tostring(mode),
    }
    local ok, err = pcall(
      dofile,
      os.getenv("BOOP_REPO_ROOT")
        .. "/src/aliases/boop/Targeting/Boop_Targeting.lua"
    )
    _G.matches = previousMatches
    assert.is_true(ok, tostring(err))
  end

  local function runCurrentRoomApplication()
    local application = boop.runtime.roomApplicationSnapshot()
    assert.is_table(application)
    assert.is_number(application.applicationId)
    assert.are.equal(
      boop.runtime.state().walk.roomGeneration,
      application.sourceAuthority.observationGeneration
    )
    assert.are.equal("1", application.sourceAuthority.roomId)
    assert.are.equal(0, timers.delays[application.pendingTimer])
    timers.run(application.pendingTimer)
    return boop.runtime.roomApplicationSnapshot(application.applicationId)
  end

  local function startManualWalk()
    boop.config.enabled = true
    boop.config.targetingMode = "manual"
    boop.config.targetCall = false
    helper.setTarget("", "", "100%")
    helper.setDenizens({})
    assert.is_true(boop.walk.start())
    assert.are.same({
      "Char.Items.Inv",
      "Char.Items.Room",
    }, sent_gmcp)
    return boop.runtime.state()
  end

  local function publishResponse(location)
    local items = {}
    if location == "inv" then
      items[1] = {
        id = "7001",
        name = "a carried test item",
        attrib = "l",
      }
    end
    return publishItemsList(location, items)
  end

  before_each(function()
    saved_temp_timer = _G.tempTimer
    saved_kill_timer = _G.killTimer
    saved_send = _G.send
    saved_send_gmcp = _G.sendGMCP
    saved_feedback = {
      err = boop.util.err,
      info = boop.util.info,
      ok = boop.util.ok,
      warn = boop.util.warn,
    }
    saved_trace_log = boop.trace.log
    saved_save_config = boop.db.saveConfig
    saved_matches = _G.matches

    boop.util.err = function(message)
      feedback.err[#feedback.err + 1] = tostring(message)
    end
    boop.util.info = function(message)
      feedback.info[#feedback.info + 1] = tostring(message)
    end
    boop.util.ok = function(message)
      feedback.ok[#feedback.ok + 1] = tostring(message)
    end
    boop.util.warn = function(message)
      feedback.warn[#feedback.warn + 1] = tostring(message)
    end
    boop.trace.log = function(message)
      trace_lines[#trace_lines + 1] = tostring(message)
    end

    resetCase({
      available = true,
      attached = true,
    })
    boop.config.enabled = true
    boop.config.targetingMode = "auto"
  end)

  after_each(function()
    if walker then
      walker.restore()
      walker = nil
    end
    _G.tempTimer = saved_temp_timer
    _G.killTimer = saved_kill_timer
    _G.send = saved_send
    _G.sendGMCP = saved_send_gmcp
    boop.util.err = saved_feedback.err
    boop.util.info = saved_feedback.info
    boop.util.ok = saved_feedback.ok
    boop.util.warn = saved_feedback.warn
    boop.trace.log = saved_trace_log
    boop.db.saveConfig = saved_save_config
    _G.matches = saved_matches
  end)

  local denialCases = {
    {
      name = "the walker package is unavailable",
      code = "walker_unavailable",
      label = "demonnicAutoWalker unavailable",
      seed = function(_, fixture)
        fixture.setAvailable(false)
      end,
    },
    {
      name = "walk mode is inactive",
      code = "walk_inactive",
      label = "walk mode is inactive",
      seed = function(state)
        state.walk.active = false
      end,
    },
    {
      name = "hunting is disabled",
      code = "hunting_disabled",
      label = "hunting is disabled",
      seed = function()
        boop.config.enabled = false
      end,
    },
    {
      name = "manual targeting is active",
      code = "manual_targeting",
      label = "manual targeting is active",
      seed = function()
        boop.config.targetingMode = "manual"
      end,
    },
    {
      name = "current room evidence is incomplete",
      code = "room_unsettled",
      label = "current room evidence is incomplete",
      seed = function(state)
        state.walk.roomSettled = false
        helper.seedRoomObservation("101", {
          generation = state.walk.roomGeneration,
          infoSeen = true,
          itemsSeen = false,
        })
      end,
    },
    {
      name = "a move is already reserved",
      code = "move_pending",
      label = "move already queued",
      seed = function(state)
        state.walk.moveQueued = true
        state.walk.moveIssuedForRoomGeneration = true
        state.walk.reservationId = 4
      end,
    },
    {
      name = "the current target remains set",
      code = "target_active",
      label = "current target still set",
      seed = function()
        helper.setTarget("42", "a test denizen", "80%")
      end,
    },
    {
      name = "a valid room denizen remains",
      code = "room_denizen_active",
      label = "valid room target remains",
      seed = function()
        helper.setDenizens({
          { id = "42", name = "a test denizen" },
        })
      end,
    },
    {
      name = "a leader target call is pending",
      code = "leader_call_pending",
      label = "waiting for leader target call",
      seed = function()
        boop.config.targetCall = true
      end,
    },
    {
      name = "gold handling is pending",
      code = "gold_pending",
      label = "loot handling is pending",
      seed = function(state)
        state.gold.operation = {
          generation = 3,
          phase = "pickup_pending",
          terminal = false,
          blockerOwner = "gold:3",
        }
      end,
    },
    {
      name = "an interrupt is pending",
      code = "interrupt_pending",
      label = "interrupt is pending",
      seed = function(state)
        state.diag.hold = true
      end,
    },
    {
      name = "a pull is pending",
      code = "pull_pending",
      label = "pull is pending",
      seed = function(state)
        state.combat.pullState = {
          active = true,
          generation = 5,
          terminal = false,
        }
      end,
    },
    {
      name = "flee is active",
      code = "flee_active",
      label = "flee is active",
      seed = function(state)
        state.combat.fleeing = true
      end,
    },
    {
      name = "a canonical runtime owner blocks movement",
      code = "gmcp_ire_missing",
      label = "GMCP IRE missing",
      seed = function()
        helper.setRuntimeBlocker({
          owner = "gmcp:ire",
          code = "gmcp_ire_missing",
          label = "GMCP IRE missing",
          systems = { walk = true },
          waitsFor = { gmcp = true },
        })
      end,
    },
  }

  for _, entry in ipairs(denialCases) do
    local case = entry
    it("returns the same automatic/manual denial while " .. case.name, function()
      local state = seedReadyWalk()
      case.seed(state, walker)
      local before = walkStateSnapshot()

      local autoOk, autoCode, autoLabel = boop.walk.maybeAdvance("automatic test")
      assert.is_false(autoOk)
      assert.are.equal(case.code, autoCode)
      assert.are.equal(case.label, autoLabel)
      assert.are.same(before, walkStateSnapshot())
      assert.are.equal(0, timers.nextId)
      assert.are.equal(0, countRaised("demonwalker.move"))
      assert.are.equal(0, #walker.installCalls)
      assert.are.equal(0, #walker.updateCalls)

      resetCase({
        available = true,
        attached = true,
      })
      state = seedReadyWalk()
      case.seed(state, walker)
      before = walkStateSnapshot()

      local manualOk, manualCode, manualLabel = boop.walk.move()
      assert.is_false(manualOk)
      assert.are.equal(case.code, manualCode)
      assert.are.equal(case.label, manualLabel)
      assert.are.same(before, walkStateSnapshot())
      assert.are.equal(0, timers.nextId)
      assert.are.equal(0, countRaised("demonwalker.move"))
      assert.are.equal(0, #walker.installCalls)
      assert.are.equal(0, #walker.updateCalls)
    end)
  end

  it("sets and updates one exact owner across start and current Room.Info", function()
    assert.is_true(boop.walk.start())

    local state = boop.runtime.state()
    local firstRun = state.walk.generation
    local owner = "walk:" .. tostring(firstRun)
    assert.is_true(state.walk.active)
    assert.is_false(state.walk.owned)
    assert.are.equal(1, firstRun)
    assert.are.equal(
      boop.runtime.roomObservationSnapshot().generation,
      state.walk.roomGeneration
    )
    assert.is_false(state.walk.roomSettled)
    assert.is_false(state.walk.moveQueued)
    assert.is_false(state.walk.moveIssuedForRoomGeneration)
    assert.are.equal(0, state.walk.reservationId)
    assert.are.equal(2, #sent_gmcp)
    assert.are.equal("Char.Items.Inv", sent_gmcp[1])
    assert.are.equal("Char.Items.Room", sent_gmcp[2])

    local blocker = assertOwner(
      owner,
      "walk_room_unsettled",
      "current room evidence is incomplete"
    )
    assert.are.same({ items = true, room = true }, blocker.waitsFor)
    assert.are.equal("1", blocker.observed.room)
    assert.is_false(blocker.observed.items)

    gmcp.Room.Info.num = 2
    local observation = boop.runtime.startRoomObservation(2)
    boop.walk.onRoomChange()

    state = boop.runtime.state()
    assert.are.equal(firstRun, state.walk.generation)
    assert.are.equal(observation.generation, state.walk.roomGeneration)
    assert.are.equal("2", state.walk.arrivalRoom)
    assert.is_false(state.walk.roomSettled)
    assert.is_false(state.walk.moveQueued)
    blocker = assertOwner(
      owner,
      "walk_room_unsettled",
      "current room evidence is incomplete"
    )
    assert.are.equal("2", blocker.observed.room)
    assert.are.equal(observation.generation, blocker.observed.roomGeneration)
  end)

  it("clears exact unsettled ownership when complete evidence cannot reserve", function()
    assert.is_true(boop.walk.start())
    local state = boop.runtime.state()
    local owner = currentWalkOwner()
    boop.config.enabled = false
    helper.seedRoomObservation(state.walk.arrivalRoom, {
      generation = state.walk.roomGeneration,
      infoSeen = true,
      itemsSeen = true,
    })

    local ok, code, label = boop.walk.onRoomSettled("complete room list")

    assert.is_false(ok)
    assert.are.equal("hunting_disabled", code)
    assert.are.equal("hunting is disabled", label)
    assert.is_true(state.walk.roomSettled)
    assert.is_false(state.walk.moveQueued)
    assert.is_nil(state.combat.blockersByOwner[owner])
    assert.is_nil(state.walk.refreshTimer)
    assert.are.equal(0, countRaised("demonwalker.move"))
  end)

  it("captures one reservation, emits once, and rearms only for a new room", function()
    assert.is_true(boop.walk.start())
    local state = boop.runtime.state()
    local owner = currentWalkOwner()
    helper.seedRoomObservation(state.walk.arrivalRoom, {
      generation = state.walk.roomGeneration,
      infoSeen = true,
      itemsSeen = true,
    })

    local ok = boop.walk.onRoomSettled("complete room list")

    assert.is_true(ok)
    assert.is_true(state.walk.moveQueued)
    assert.is_true(state.walk.moveIssuedForRoomGeneration)
    assert.are.equal(1, state.walk.reservationId)
    assert.is_number(state.walk.emitterTimer)
    assert.is_nil(state.walk.refreshTimer)
    assertOwner(owner, "walk_move_pending", "move already queued")

    local context = boop.runtime.context()
    assert.are.equal(1, context.walk.reservationId)

    local normalOk, normalCode, normalLabel = boop.walk.evaluateAllClear(
      state.walk.generation,
      state.walk.roomGeneration
    )
    assert.is_false(normalOk)
    assert.are.equal("move_pending", normalCode)
    assert.are.equal("move already queued", normalLabel)

    local firstEmitter = state.walk.emitterTimer
    timers.run(firstEmitter)
    assert.are.equal(1, countRaised("demonwalker.move"))
    assert.is_nil(state.walk.emitterTimer)
    assert.is_true(state.walk.moveQueued)
    assertOwner(owner, "walk_move_pending", "move already queued")

    timers.run(firstEmitter)
    assert.are.equal(1, countRaised("demonwalker.move"))

    gmcp.Room.Info.num = 2
    local nextObservation = boop.runtime.startRoomObservation(2)
    boop.walk.onRoomChange()
    assert.is_false(state.walk.moveQueued)
    assert.is_false(state.walk.moveIssuedForRoomGeneration)
    assert.are.equal(nextObservation.generation, state.walk.roomGeneration)
    assertOwner(owner, "walk_room_unsettled", "current room evidence is incomplete")

    helper.seedRoomObservation(2, {
      generation = state.walk.roomGeneration,
      infoSeen = true,
      itemsSeen = true,
    })
    assert.is_true(boop.walk.onRoomSettled("next room complete"))
    assert.are.equal(2, state.walk.reservationId)
    local secondEmitter = state.walk.emitterTimer
    assert.is_true(secondEmitter ~= firstEmitter)
    timers.run(secondEmitter)
    assert.are.equal(2, countRaised("demonwalker.move"))
  end)

  it("timeout-under-owner recovery permits one guarded walker move", function()
    local state = seedReadyWalk()
    boop.config.autoGrabGold = true
    boop.config.goldPack = ""
    boop.config.useQueueing = false
    gmcp.Char.Items.List = {
      location = "room",
      items = {
        {
          id = "9001",
          name = "some gold sovereigns",
          attrib = "t",
        },
      },
    }
    helper.seedRoomObservation(
      boop.runtime.roomObservationSnapshot().roomId,
      {
        generation = boop.runtime.roomObservationSnapshot().generation,
        infoSeen = true,
        itemsSeen = true,
        acceptedItems = gmcp.Char.Items.List.items,
      }
    )

    boop.onGoldDropLine("A handful of sovereigns spills onto the ground.")
    local operation = boop.state.gold.operation
    assert.is_table(operation)
    assert.are.equal("pickup_pending", operation.phase)
    local goldOwner = operation.blockerOwner
    local expiredTimer = operation.timeoutTimer
    local getCountBeforeTimeout = countSent(
      "queue add full get sovereigns"
    )
    assert.is_function(timers.callback(expiredTimer))

    helper.setRuntimeBlocker({
      owner = "interrupt:timeout-hold",
      code = "interrupt_pending",
      label = "interrupt pending",
      systems = {
        combat = true,
        queue = true,
        gold = true,
        walk = true,
      },
      waitsFor = { prompt = true },
    })

    timers.run(expiredTimer)

    operation = boop.state.gold.operation
    assert.is_table(operation)
    assert.is_false(
      operation.timeoutTimer,
      "TIMEOUT_UNDER_OWNER_TOKEN_NOT_CONSUMED"
    )
    assert.is_nil(boop.state.gold.pendingTimer)
    assert.are.equal(getCountBeforeTimeout, countSent(
      "queue add full get sovereigns"
    ))
    assert.are.equal(0, state.walk.reservationId)
    assert.is_false(state.walk.moveQueued)
    assert.are.equal(0, countRaised("demonwalker.move"))

    timers.run(expiredTimer)
    assert.is_false(operation.timeoutTimer)
    assert.are.equal(getCountBeforeTimeout, countSent(
      "queue add full get sovereigns"
    ))
    assert.are.equal(0, state.walk.reservationId)
    assert.are.equal(0, countRaised("demonwalker.move"))

    assert.is_true(boop.runtime.clearBlocker(
      "interrupt:timeout-hold",
      "timeout-under-owner released"
    ))
    boop.tick()

    operation = boop.state.gold.operation
    assert.is_table(operation)
    assert.are.equal("pickup_pending", operation.phase)
    assert.are.equal(getCountBeforeTimeout + 1, countSent(
      "queue add full get sovereigns"
    ))
    assert.is_number(operation.timeoutTimer)
    assert.is_true(operation.timeoutTimer ~= expiredTimer)
    assert.are.equal(0, state.walk.reservationId)
    assert.is_false(state.walk.moveQueued)
    assert.are.equal(0, countRaised("demonwalker.move"))

    local replacementTimer = operation.timeoutTimer
    assert.is_true(boop.onGoldGetSuccess())
    assert.is_false(boop.state.gold.operation)
    assert.is_nil(boop.state.combat.blockersByOwner[goldOwner])
    assert.is_true(timers.cancelled[replacementTimer])
    local terminalTick = timers.nextId
    assert.is_function(timers.callback(terminalTick))
    assert.are.equal(0, state.walk.reservationId)
    assert.are.equal(0, countRaised("demonwalker.move"))

    timers.run(terminalTick)

    assert.are.equal(1, state.walk.reservationId)
    assert.is_true(state.walk.moveQueued)
    assert.is_number(state.walk.emitterTimer)
    assert.are.equal(0, countRaised("demonwalker.move"))

    local emitter = state.walk.emitterTimer
    timers.run(emitter)
    assert.are.equal(1, countRaised("demonwalker.move"))

    timers.run(emitter)
    assert.are.equal(1, countRaised("demonwalker.move"))
  end)

  local staleCases = {
    {
      name = "run generation",
      mutate = function(state)
        state.walk.generation = state.walk.generation + 1
      end,
    },
    {
      name = "room generation",
      mutate = function(state)
        state.walk.roomGeneration = state.walk.roomGeneration + 1
      end,
    },
    {
      name = "reservation ID",
      mutate = function(state)
        state.walk.reservationId = state.walk.reservationId + 1
      end,
    },
  }

  for _, entry in ipairs(staleCases) do
    local case = entry
    it("makes a stale " .. case.name .. " emitter a zero-effect no-op", function()
      local state = seedReadyWalk()
      assert.is_true(boop.walk.maybeAdvance("reserve stale case"))
      local emitter = state.walk.emitterTimer
      case.mutate(state)
      local before = walkStateSnapshot()

      timers.run(emitter)

      assert.are.equal(0, countRaised("demonwalker.move"))
      assert.are.same(before, walkStateSnapshot())
      assert.are.equal(0, #walker.installCalls)
      assert.are.equal(0, #walker.updateCalls)
    end)
  end

  it("reserved evaluation bypasses only its own matching walker owner", function()
    local state = seedReadyWalk()
    assert.is_true(boop.walk.maybeAdvance("reserve with unrelated owner"))
    local owner = currentWalkOwner()
    local emitter = state.walk.emitterTimer
    assertOwner(owner, "walk_move_pending", "move already queued")

    helper.setRuntimeBlocker({
      owner = "interrupt:99",
      code = "interrupt_pending",
      label = "unrelated walk hold",
      systems = { walk = true },
      waitsFor = { prompt = true },
    })
    local before = walkStateSnapshot()

    timers.run(emitter)

    assert.are.equal(0, countRaised("demonwalker.move"))
    assert.are.same(before, walkStateSnapshot())
    assertOwner(owner, "walk_move_pending", "move already queued")
    assertOwner("interrupt:99", "interrupt_pending", "unrelated walk hold")
  end)

  it("invalidates a reservation and reports one transition on package loss", function()
    local state = seedReadyWalk()
    assert.is_true(boop.walk.maybeAdvance("package loss"))
    local oldRun = state.walk.generation
    local owner = currentWalkOwner()
    local emitter = state.walk.emitterTimer
    local warningCount = #feedback.warn
    local transitionCount = countContaining(trace_lines, "walker_unavailable")
    local invalidationCount = countContaining(trace_lines, "external_lost")

    walker.setAvailable(false)
    timers.run(emitter)

    assert.are.equal(0, countRaised("demonwalker.move"))
    assert.are.equal(oldRun + 1, state.walk.generation)
    assert.are.equal(0, state.walk.roomGeneration)
    assert.is_false(state.walk.moveQueued)
    assert.is_nil(state.walk.emitterTimer)
    assert.are.equal(1, #feedback.warn - warningCount)
    assert.is_true(
      feedback.warn[#feedback.warn]:find(
        "demonnicAutoWalker became unavailable",
        1,
        true
      ) ~= nil
    )
    assert.are.equal(
      1,
      countContaining(trace_lines, "walker_unavailable") - transitionCount
    )
    assert.are.equal(
      1,
      countContaining(trace_lines, "external_lost") - invalidationCount
    )
    assertOwner(
      owner,
      "walker_unavailable",
      "demonnicAutoWalker unavailable"
    )
    assert.are.equal(0, #walker.installCalls)
    assert.are.equal(0, #walker.updateCalls)

    timers.run(emitter)
    assert.are.equal(0, countRaised("demonwalker.move"))
    assert.are.equal(1, #feedback.warn - warningCount)
    assert.are.equal(
      1,
      countContaining(trace_lines, "walker_unavailable") - transitionCount
    )
  end)

  local invalidationCases = {
    {
      name = "owned stop",
      owned = true,
      action = function()
        boop.walk.stop(true, false)
      end,
    },
    {
      name = "attached detach",
      owned = false,
      action = function()
        boop.walk.stop(true, true)
      end,
    },
    {
      name = "external finish",
      owned = true,
      action = function()
        boop.walk.onFinished()
      end,
    },
  }

  for _, entry in ipairs(invalidationCases) do
    local case = entry
    it("invalidates the callback before exact-owner clear on " .. case.name, function()
      local state = seedReadyWalk({ owned = case.owned })
      assert.is_true(boop.walk.maybeAdvance(case.name))
      local oldRun = state.walk.generation
      local oldOwner = currentWalkOwner()
      local emitter = state.walk.emitterTimer

      case.action()

      assert.is_false(state.walk.active)
      assert.is_false(state.walk.moveQueued)
      assert.is_nil(state.walk.emitterTimer)
      assert.is_nil(state.combat.blockersByOwner[oldOwner])
      assert.is_true(state.walk.generation ~= oldRun)
      timers.run(emitter)
      assert.are.equal(0, countRaised("demonwalker.move"))
    end)
  end

  it("acknowledges only non-silent inactive stop requests", function()
    local state = boop.runtime.state()
    state.walk.active = false

    local infoCount = #feedback.info
    assert.is_false(boop.walk.stop(false, false))
    assert.are.equal(1, #feedback.info - infoCount)
    assert.are.equal(
      "walk stop: no active boop walk",
      feedback.info[#feedback.info]
    )

    infoCount = #feedback.info
    assert.is_false(boop.walk.stop(true, false))
    assert.are.equal(0, #feedback.info - infoCount)
    assert.are.equal(0, countRaised("demonwalker.stop"))
  end)

  local liveManualToAutoOrders = {
    {
      name = "Inv then Room",
      first = "inv",
      second = "room",
    },
    {
      name = "Room then Inv",
      first = "room",
      second = "inv",
    },
  }

  for _, entry in ipairs(liveManualToAutoOrders) do
    local case = entry
    it(
      "G-03-7 live manual-to-auto wake-up settles "
        .. case.name
        .. " and moves once",
      function()
        local state = startManualWalk()

        publishResponse(case.first)
        publishResponse(case.second)
        local application = runCurrentRoomApplication()
        local blocker = boop.walk.blockerDetails()

        assert.is_true(application.claimed)
        assert.is_true(application.consumed)
        assert.is_true(state.walk.roomSettled)
        assert.are.same({
          code = "manual_targeting",
          label = "manual targeting is active",
          nextAction = "boop targeting auto",
        }, blocker)
        assert.are.equal(0, state.walk.reservationId)
        assert.is_false(state.walk.moveQueued)
        assert.is_nil(state.walk.emitterTimer)
        assert.are.equal(0, countRaised("demonwalker.move"))

        local okCountBeforeAuto = #feedback.ok
        runTargetingAlias("auto")

        assert.are.equal("auto", boop.config.targetingMode)
        assert.are.same({
          {
            key = "targetingMode",
            value = "auto",
          },
        }, config_saves)
        assert.are.equal(1, #feedback.ok - okCountBeforeAuto)
        assert.are.equal(
          "targeting mode: auto",
          feedback.ok[#feedback.ok]
        )
        assert.are.equal(1, state.walk.reservationId)
        assert.is_true(state.walk.moveQueued)
        assert.is_true(state.walk.moveIssuedForRoomGeneration)
        assert.is_number(state.walk.emitterTimer)
        assert.are.equal(0, timers.delays[state.walk.emitterTimer])

        local emitter = state.walk.emitterTimer
        timers.run(emitter)
        assert.are.equal(1, countRaised("demonwalker.move"))

        runTargetingAlias("auto")
        publishResponse(case.first)
        publishResponse(case.second)
        boop.onPrompt()
        boop.onRoomInfo()
        timers.run(emitter)

        assert.are.equal(1, state.walk.reservationId)
        assert.are.equal(1, countRaised("demonwalker.move"))
        assert.are.equal(2, #config_saves)
        assert.are.equal(2, #feedback.ok - okCountBeforeAuto)
        assert.are.equal(4, #sent_gmcp)
      end
    )
  end

  it("G-03-7 early targeting auto waits for the exact room application", function()
    local state = startManualWalk()
    local okCountBeforeAuto = #feedback.ok

    runTargetingAlias("auto")

    assert.are.equal(0, state.walk.reservationId)
    assert.is_false(state.walk.moveQueued)
    assert.is_nil(state.walk.emitterTimer)
    assert.are.equal(0, countRaised("demonwalker.move"))

    publishResponse("room")
    publishResponse("inv")
    local application = runCurrentRoomApplication()

    assert.is_true(application.claimed)
    assert.is_true(application.consumed)
    assert.are.equal(1, state.walk.reservationId)
    assert.is_true(state.walk.moveQueued)
    assert.is_number(state.walk.emitterTimer)
    assert.are.equal(0, timers.delays[state.walk.emitterTimer])

    local emitter = state.walk.emitterTimer
    timers.run(emitter)
    boop.onPrompt()
    boop.onRoomInfo()
    publishResponse("room")
    publishResponse("inv")
    timers.run(emitter)

    assert.are.equal(1, state.walk.reservationId)
    assert.are.equal(1, countRaised("demonwalker.move"))
    assert.are.same({
      {
        key = "targetingMode",
        value = "auto",
      },
    }, config_saves)
    assert.are.equal(1, #feedback.ok - okCountBeforeAuto)
    assert.are.equal(
      "targeting mode: auto",
      feedback.ok[#feedback.ok]
    )
    assert.are.equal(4, #sent_gmcp)
  end)

  it("G-03-7 targeting auto retains an unrelated owner until exact release", function()
    local state = startManualWalk()
    publishResponse("inv")
    publishResponse("room")
    runCurrentRoomApplication()
    helper.setRuntimeBlocker({
      owner = "interrupt:manual-auto",
      code = "interrupt_pending",
      label = "unrelated walk hold",
      systems = { walk = true },
      waitsFor = { prompt = true },
    })

    local okCountBeforeAuto = #feedback.ok
    runTargetingAlias("auto")

    assertOwner(
      "interrupt:manual-auto",
      "interrupt_pending",
      "unrelated walk hold"
    )
    assert.are.equal(0, state.walk.reservationId)
    assert.is_false(state.walk.moveQueued)
    assert.is_nil(state.walk.emitterTimer)
    assert.are.equal(0, countRaised("demonwalker.move"))

    assert.is_true(boop.runtime.clearBlocker(
      "interrupt:manual-auto",
      "exact owner released"
    ))
    boop.tick()

    assert.is_nil(
      state.combat.blockersByOwner["interrupt:manual-auto"]
    )
    assert.are.equal(1, state.walk.reservationId)
    assert.is_true(state.walk.moveQueued)
    assert.is_number(state.walk.emitterTimer)
    assert.are.equal(0, timers.delays[state.walk.emitterTimer])

    local emitter = state.walk.emitterTimer
    timers.run(emitter)
    boop.onPrompt()
    timers.run(emitter)

    assert.are.equal(1, state.walk.reservationId)
    assert.are.equal(1, countRaised("demonwalker.move"))
    assert.are.same({
      {
        key = "targetingMode",
        value = "auto",
      },
    }, config_saves)
    assert.are.equal(1, #feedback.ok - okCountBeforeAuto)
    assert.are.equal(
      "targeting mode: auto",
      feedback.ok[#feedback.ok]
    )
    assert.are.equal(2, #sent_gmcp)
  end)

  it("holds manual targeting without a reservation then advances once in auto", function()
    local state = seedReadyWalk({ targetingMode = "manual" })

    local ok, code, label = boop.walk.maybeAdvance("manual targeting hold")

    assert.is_false(ok)
    assert.are.equal("manual_targeting", code)
    assert.are.equal("manual targeting is active", label)
    assert.are.equal(0, state.walk.reservationId)
    assert.is_false(state.walk.moveQueued)
    assert.is_false(state.walk.moveIssuedForRoomGeneration)
    assert.is_nil(state.walk.emitterTimer)
    assert.are.equal(0, countRaised("demonwalker.move"))

    boop.config.targetingMode = "auto"
    assert.is_true(boop.walk.maybeAdvance("automatic targeting selected"))
    assert.are.equal(1, state.walk.reservationId)
    assert.is_true(state.walk.moveQueued)
    assert.is_true(state.walk.moveIssuedForRoomGeneration)
    assert.is_number(state.walk.emitterTimer)

    timers.run(state.walk.emitterTimer)
    assert.are.equal(1, countRaised("demonwalker.move"))
    assert.is_false(boop.walk.maybeAdvance("duplicate settled room"))
    assert.are.equal(1, state.walk.reservationId)
    assert.are.equal(1, countRaised("demonwalker.move"))
  end)

  it("invalidates and clears ownership before one owned stop event", function()
    resetCase({
      available = true,
      attached = false,
    })
    local state = seedReadyWalk({ owned = true })
    local refreshTimer = timers.tempTimer(0.2, function() end)
    state.walk.refreshTimer = refreshTimer
    assert.is_true(boop.walk.maybeAdvance("owned stop ordering"))
    local oldRun = state.walk.generation
    local oldOwner = currentWalkOwner()
    local oldReservation = state.walk.reservationId
    local emitter = state.walk.emitterTimer
    local firstStopSnapshot

    _G.raiseEvent = function(name, ...)
      walker.raisedEvents[#walker.raisedEvents + 1] = {
        name = name,
        args = { ... },
      }
      if name == "demonwalker.stop" and not firstStopSnapshot then
        firstStopSnapshot = {
          active = state.walk.active,
          generation = state.walk.generation,
          roomGeneration = state.walk.roomGeneration,
          reservationId = state.walk.reservationId,
          refreshTimer = state.walk.refreshTimer,
          emitterTimer = state.walk.emitterTimer,
          refreshCancelled = timers.cancelled[refreshTimer] == true,
          emitterCancelled = timers.cancelled[emitter] == true,
          owner = state.combat.blockersByOwner[oldOwner],
        }
      end
    end

    boop.walk.stop(false, false)

    assert.are.equal(1, countRaised("demonwalker.stop"))
    assert.is_table(firstStopSnapshot)
    assert.is_false(firstStopSnapshot.active)
    assert.are.equal(oldRun + 1, firstStopSnapshot.generation)
    assert.are.equal(0, firstStopSnapshot.roomGeneration)
    assert.are.equal(oldReservation, firstStopSnapshot.reservationId)
    assert.is_nil(firstStopSnapshot.refreshTimer)
    assert.is_nil(firstStopSnapshot.emitterTimer)
    assert.is_true(firstStopSnapshot.refreshCancelled)
    assert.is_true(firstStopSnapshot.emitterCancelled)
    assert.is_nil(firstStopSnapshot.owner)
    assert.are.equal(
      "walk stopped -- boop-owned demonwalker run ended",
      feedback.ok[#feedback.ok]
    )

    timers.run(emitter)
    assert.are.equal(0, countRaised("demonwalker.move"))
  end)

  it("detaches without stopping or disabling an attached external run", function()
    resetCase({
      available = true,
      attached = true,
    })
    local state = seedReadyWalk({ owned = false })
    assert.is_true(boop.walk.maybeAdvance("attached detach ordering"))
    local oldOwner = currentWalkOwner()
    local emitter = state.walk.emitterTimer

    boop.walk.stop(false, false)

    assert.are.equal(0, countRaised("demonwalker.stop"))
    assert.is_true(walker.walker.enabled)
    assert.is_false(state.walk.active)
    assert.is_nil(state.combat.blockersByOwner[oldOwner])
    assert.is_true(timers.cancelled[emitter])
    assert.are.equal(
      "walk detached -- external demonwalker run remains active",
      feedback.ok[#feedback.ok]
    )

    timers.run(emitter)
    assert.are.equal(0, countRaised("demonwalker.move"))
  end)

  it("restarts with fresh room evidence and ignores the stopped emitter", function()
    resetCase({
      available = true,
      attached = false,
    })
    boop.config.enabled = true
    boop.config.targetingMode = "auto"
    assert.is_true(boop.walk.start())
    local state = boop.runtime.state()
    helper.seedRoomObservation(state.walk.arrivalRoom, {
      generation = state.walk.roomGeneration,
      infoSeen = true,
      itemsSeen = true,
    })
    assert.is_true(boop.walk.onRoomSettled("first run complete"))
    local oldRun = state.walk.generation
    local oldRoomGeneration = state.walk.roomGeneration
    local oldEmitter = state.walk.emitterTimer
    local oldReservation = state.walk.reservationId

    boop.walk.stop(true, false)
    walker.setAttached(false)
    assert.is_true(boop.walk.start())

    local newRun = state.walk.generation
    local newOwner = currentWalkOwner()
    local observation = boop.runtime.roomObservationSnapshot()
    assert.is_true(newRun > oldRun)
    assert.is_true(observation.generation > oldRoomGeneration)
    assert.is_true(observation.infoSeen)
    assert.is_false(observation.itemsSeen)
    assert.are.equal(observation.generation, state.walk.roomGeneration)
    assert.is_false(state.walk.roomSettled)
    assert.is_false(state.walk.moveQueued)
    assert.is_false(state.walk.moveIssuedForRoomGeneration)
    assert.are.equal(oldReservation, state.walk.reservationId)
    assertOwner(
      newOwner,
      "walk_room_unsettled",
      "current room evidence is incomplete"
    )

    local before = walkStateSnapshot()
    timers.run(oldEmitter)
    assert.are.same(before, walkStateSnapshot())
    assert.are.equal(0, countRaised("demonwalker.move"))
  end)

  it("arrival-tokenless-fence preserves a complete same-room reservation", function()
    local state = seedReadyWalk({
      moveQueued = true,
      moveIssuedForRoomGeneration = true,
      reservationId = 6,
      emitterTimer = 700,
    })
    boop.state.targeting.room = "101"
    helper.setRuntimeBlocker({
      owner = currentWalkOwner(),
      code = "walk_move_pending",
      label = "move already queued",
      systems = { walk = true },
      waitsFor = { room = true },
    })

    local before = {
      observation = boop.runtime.roomObservationSnapshot(),
      walk = walkStateSnapshot(),
      denizens = boop.state.targeting.denizens,
      requests = #sent_gmcp,
      sends = #sent,
      events = #walker.raisedEvents,
      timers = timers.nextId,
    }

    local firstArrival = boop.onWalkArrived("demonwalker.arrived")
    boop.onRoomInfo()
    local secondArrival = boop.onWalkArrived("demonwalker.arrived")
    local syntheticArrival = boop.onWalkArrived(999, 999)

    local after = {
      observation = boop.runtime.roomObservationSnapshot(),
      walk = walkStateSnapshot(),
      denizens = boop.state.targeting.denizens,
      requests = #sent_gmcp,
      sends = #sent,
      events = #walker.raisedEvents,
      timers = timers.nextId,
    }

    assert.are.same({
      arrivals = { true, true, true },
      before = before,
      after = before,
    }, {
      arrivals = { firstArrival, secondArrival, syntheticArrival },
      before = before,
      after = after,
    }, "ARRIVAL_TOKENLESS_FENCE_BROKEN: complete same-room reservation was rearmed")
  end)

  it("arrival-tokenless-fence restart drains old responses before one move", function()
    resetCase({
      available = true,
      attached = false,
    })
    boop.config.enabled = true
    boop.config.targetingMode = "auto"
    boop.config.targetCall = false
    boop.state.targeting.room = "1"
    helper.setTarget("", "", "100%")
    helper.setDenizens({})
    gmcp.Room.Info = {
      num = "1",
      area = "Test Area",
      exits = {},
    }

    local firstStart = boop.walk.start()
    local state = boop.runtime.state()
    local oldRun = state.walk.generation
    local oldObservation = boop.runtime.roomObservationSnapshot()
    local oldFenceTimer = oldObservation.refreshTimeoutTimer
    local oldArrivalTimer = state.walk.refreshTimer

    boop.walk.stop(true, false)
    local stoppedBeforeArrival = {
      observation = boop.runtime.roomObservationSnapshot(),
      walk = walkStateSnapshot(),
      requests = #sent_gmcp,
      timers = timers.nextId,
      events = #walker.raisedEvents,
    }
    local stoppedArrival = boop.onWalkArrived("demonwalker.arrived")
    local stoppedAfterArrival = {
      observation = boop.runtime.roomObservationSnapshot(),
      walk = walkStateSnapshot(),
      requests = #sent_gmcp,
      timers = timers.nextId,
      events = #walker.raisedEvents,
    }

    walker.setAttached(false)
    local secondStart = boop.walk.start()
    local newRun = state.walk.generation
    local newObservation = boop.runtime.roomObservationSnapshot()
    local newFenceTimer = newObservation.refreshTimeoutTimer
    local newArrivalTimer = state.walk.refreshTimer
    local restartArrival = boop.onWalkArrived("demonwalker.arrived")

    publishItemsList("inv", {
      { id = "7101", name = "old inventory response", attrib = "l" },
    })
    publishItemsList("room", {
      { id = "201", name = "old room response", attrib = "m" },
    })
    local afterOldResponses = {
      itemsSeen = boop.runtime.roomObservationSnapshot().itemsSeen,
      queueDepth = #boop.runtime.roomObservationSnapshot().fenceQueue,
      reservationId = state.walk.reservationId,
      moveQueued = state.walk.moveQueued,
      moveCount = countRaised("demonwalker.move"),
    }

    publishItemsList("inv", {
      { id = "7102", name = "new inventory response", attrib = "l" },
    })
    publishItemsList("room", {})
    local currentApplication = boop.runtime.roomApplicationSnapshot()
    assert.is_table(currentApplication)
    assert.are.equal(
      0,
      timers.delays[currentApplication.pendingTimer]
    )
    timers.run(currentApplication.pendingTimer)
    local currentEmitter = state.walk.emitterTimer
    if currentEmitter and timers.callback(currentEmitter) then
      timers.run(currentEmitter)
    end

    for _, timerId in ipairs({
      oldFenceTimer,
      oldArrivalTimer,
      newFenceTimer,
      newArrivalTimer,
    }) do
      if timerId and timerId ~= currentEmitter and timers.callback(timerId) then
        timers.run(timerId)
      end
    end
    if currentEmitter and timers.callback(currentEmitter) then
      timers.run(currentEmitter)
    end

    local completeArrival = boop.onWalkArrived("demonwalker.arrived")
    boop.onRoomInfo()
    publishItemsList("room", {
      { id = "999", name = "duplicate room response", attrib = "m" },
    })

    local finalObservation = boop.runtime.roomObservationSnapshot()
    local finalOwner = state.combat.blockersByOwner[
      "walk:" .. tostring(state.walk.generation)
    ]
    assert.are.same({
      starts = { true, true },
      stoppedArrival = false,
      stoppedPreserved = stoppedBeforeArrival,
      restartArrival = true,
      completeArrival = true,
      runAdvanced = true,
      freshGeneration = true,
      requests = {
        "Char.Items.Inv",
        "Char.Items.Room",
        "Char.Items.Inv",
        "Char.Items.Room",
      },
      afterOldResponses = {
        itemsSeen = false,
        queueDepth = 1,
        reservationId = 0,
        moveQueued = false,
        moveCount = 0,
      },
      final = {
        itemsSeen = true,
        queueDepth = 0,
        reservationId = 1,
        moveQueued = true,
        moveIssued = true,
        ownerCode = "walk_move_pending",
        moveCount = 1,
        timerCount = 4,
        warningCount = 0,
      },
    }, {
      starts = { firstStart, secondStart },
      stoppedArrival = stoppedArrival,
      stoppedPreserved = stoppedAfterArrival,
      restartArrival = restartArrival,
      completeArrival = completeArrival,
      runAdvanced = newRun > oldRun,
      freshGeneration = newObservation.generation > oldObservation.generation,
      requests = sent_gmcp,
      afterOldResponses = afterOldResponses,
      final = {
        itemsSeen = finalObservation.itemsSeen,
        queueDepth = #finalObservation.fenceQueue,
        reservationId = state.walk.reservationId,
        moveQueued = state.walk.moveQueued,
        moveIssued = state.walk.moveIssuedForRoomGeneration,
        ownerCode = finalOwner and finalOwner.code or false,
        moveCount = countRaised("demonwalker.move"),
        timerCount = timers.nextId,
        warningCount = #feedback.warn,
      },
    }, "ARRIVAL_TOKENLESS_FENCE_BROKEN: restart reused or rearmed stale arrival authority")
  end)

  it("makes stale settled, room-change, and finished callbacks no-ops", function()
    local state = seedReadyWalk({
      generation = 20,
      roomGeneration = 30,
      owned = true,
    })
    helper.setRuntimeBlocker({
      owner = currentWalkOwner(),
      code = "walk_room_unsettled",
      label = "current room evidence is incomplete",
      systems = { walk = true },
      waitsFor = { room = true, items = true },
    })
    local before = walkStateSnapshot()

    assert.is_false(boop.walk.onRoomSettled("stale list", 19, 30))
    assert.is_false(boop.walk.onRoomChange(19, 30))
    assert.is_false(boop.walk.onFinished(19))

    assert.are.same(before, walkStateSnapshot())
    assert.are.equal(0, timers.nextId)
    assert.are.equal(0, countRaised("demonwalker.move"))
    assert.are.equal(0, countRaised("demonwalker.stop"))
  end)

  it("reports the primary manual blocker and confirms no move was queued", function()
    local state = seedReadyWalk()
    helper.setRuntimeBlocker({
      owner = "gmcp:ire",
      code = "gmcp_ire_missing",
      label = "GMCP IRE missing",
      systems = { walk = true },
      waitsFor = { gmcp = true },
    })
    local before = walkStateSnapshot()

    local ok, code, label = boop.walk.move()

    assert.is_false(ok)
    assert.are.equal("gmcp_ire_missing", code)
    assert.are.equal("GMCP IRE missing", label)
    assert.are.same(before, walkStateSnapshot())
    assert.is_true(
      feedback.warn[#feedback.warn]:find("GMCP IRE missing", 1, true) ~= nil
    )
    assert.is_true(
      feedback.warn[#feedback.warn]:find("no move queued", 1, true) ~= nil
    )
    assert.are.equal(0, timers.nextId)
    assert.are.equal(0, countRaised("demonwalker.move"))
  end)

  it("caps one response fence, then warns and remains held", function()
    assert.is_true(boop.walk.start())
    local state = boop.runtime.state()
    local owner = currentWalkOwner()
    local refreshTimer =
      boop.runtime.roomObservationSnapshot().refreshTimeoutTimer
    assert.is_number(refreshTimer)
    assert.is_nil(state.walk.refreshTimer)
    assert.are.equal(2, #sent_gmcp)
    local warningCount = #feedback.warn
    local traceCount = countContaining(trace_lines, "room response fence timeout")

    timers.run(refreshTimer)

    assert.is_false(state.walk.roomSettled)
    assert.is_false(state.walk.moveQueued)
    assert.is_nil(state.walk.refreshTimer)
    assert.is_true(boop.runtime.roomObservationSnapshot().warned)
    assert.are.equal(0, countRaised("demonwalker.move"))
    assert.are.equal(2, #sent_gmcp)
    assert.are.equal(1, #feedback.warn - warningCount)
    assert.is_true(
      feedback.warn[#feedback.warn]:find(
        "room_partial -- room response fence incomplete",
        1,
        true
      ) ~= nil
    )
    assert.are.equal(
      1,
      countContaining(trace_lines, "room response fence timeout") - traceCount
    )
    assertOwner(owner, "walk_room_unsettled", "current room evidence is incomplete")

    timers.run(refreshTimer)
    assert.are.equal(1, #feedback.warn - warningCount)
    assert.are.equal(
      1,
      countContaining(trace_lines, "room response fence timeout") - traceCount
    )
  end)

  local installCases = {
    {
      name = "thrown failure",
      mode = "throw",
      expected = false,
    },
    {
      name = "false return failure",
      mode = "false_error",
      expected = false,
    },
    {
      name = "nil plus error failure",
      mode = "nil_error",
      expected = false,
    },
    {
      name = "successful request",
      mode = "success",
      expected = true,
    },
  }

  for _, entry in ipairs(installCases) do
    local case = entry
    it("handles explicit install " .. case.name, function()
      resetCase({
        available = false,
        installMode = case.mode,
      })

      assert.are.equal(case.expected, boop.walk.install())
      assert.are.equal(1, #walker.installCalls)
      assert.are.equal(0, #walker.updateCalls)
    end)
  end

  it("never installs or updates from status, start, or move", function()
    resetCase({
      available = false,
      installMode = "success",
    })

    boop.walk.status()
    assert.is_false(boop.walk.start())
    local ok, code, label = boop.walk.move()

    assert.is_false(ok)
    assert.are.equal("walker_unavailable", code)
    assert.are.equal("demonnicAutoWalker unavailable", label)
    assert.are.equal(0, #walker.installCalls)
    assert.are.equal(0, #walker.updateCalls)
    assert.are.equal(0, countRaised("demonwalker.move"))
  end)
end)
