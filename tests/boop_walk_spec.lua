local helper = dofile(os.getenv("TESTS_DIRECTORY") .. "/support/boop_test_helper.lua")

describe("boop walk integration", function()
  local saved_temp_timer
  local saved_kill_timer
  local saved_send_gmcp
  local saved_feedback
  local saved_trace_log
  local timers
  local walker
  local sent_gmcp
  local feedback
  local trace_lines

  local function countRaised(name)
    local count = 0
    for _, event in ipairs((walker and walker.raisedEvents) or {}) do
      if event.name == name then
        count = count + 1
      end
    end
    return count
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
    sent_gmcp = {}
    feedback = {
      err = {},
      info = {},
      ok = {},
      warn = {},
    }
    trace_lines = {}

    _G.tempTimer = timers.tempTimer
    _G.killTimer = timers.killTimer
    _G.sendGMCP = function(command)
      sent_gmcp[#sent_gmcp + 1] = command
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

  before_each(function()
    saved_temp_timer = _G.tempTimer
    saved_kill_timer = _G.killTimer
    saved_send_gmcp = _G.sendGMCP
    saved_feedback = {
      err = boop.util.err,
      info = boop.util.info,
      ok = boop.util.ok,
      warn = boop.util.warn,
    }
    saved_trace_log = boop.trace.log

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
    _G.sendGMCP = saved_send_gmcp
    boop.util.err = saved_feedback.err
    boop.util.info = saved_feedback.info
    boop.util.ok = saved_feedback.ok
    boop.util.warn = saved_feedback.warn
    boop.trace.log = saved_trace_log
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
    assert.are.equal(1, #sent_gmcp)
    assert.are.equal("Char.Items.Room", sent_gmcp[1])

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
    local owner = currentWalkOwner()
    local emitter = state.walk.emitterTimer
    local warningCount = #feedback.warn
    local transitionCount = countContaining(trace_lines, "walker_unavailable")

    walker.setAvailable(false)
    timers.run(emitter)

    assert.are.equal(0, countRaised("demonwalker.move"))
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

  it("requests one room refresh, then warns and remains held", function()
    assert.is_true(boop.walk.start())
    local state = boop.runtime.state()
    local owner = currentWalkOwner()
    local refreshTimer = state.walk.refreshTimer
    assert.is_number(refreshTimer)
    assert.are.equal(1, #sent_gmcp)
    local warningCount = #feedback.warn
    local traceCount = countContaining(trace_lines, "room_refresh_exhausted")

    timers.run(refreshTimer)

    assert.is_false(state.walk.roomSettled)
    assert.is_false(state.walk.moveQueued)
    assert.is_nil(state.walk.refreshTimer)
    assert.is_true(state.walk.refreshWarned)
    assert.are.equal(0, countRaised("demonwalker.move"))
    assert.are.equal(1, #sent_gmcp)
    assert.are.equal(1, #feedback.warn - warningCount)
    assert.is_true(
      feedback.warn[#feedback.warn]:find(
        "room item refresh completed without settlement",
        1,
        true
      ) ~= nil
    )
    assert.are.equal(
      1,
      countContaining(trace_lines, "room_refresh_exhausted") - traceCount
    )
    assertOwner(owner, "walk_room_unsettled", "current room evidence is incomplete")

    timers.run(refreshTimer)
    assert.are.equal(1, #feedback.warn - warningCount)
    assert.are.equal(
      1,
      countContaining(trace_lines, "room_refresh_exhausted") - traceCount
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
