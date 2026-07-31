local helper = dofile(os.getenv("TESTS_DIRECTORY") .. "/support/boop_test_helper.lua")

describe("boop trace gmcp events", function()
  local timer_stub
  local scheduled

  before_each(function()
    helper.reset()
    boop.config.traceEnabled = true
    scheduled = {}
    timer_stub = stub(_G, "tempTimer", function(delay, callback)
      scheduled[#scheduled + 1] = {
        delay = delay,
        callback = callback,
      }
      return #scheduled
    end)
  end)

  after_each(function()
    if timer_stub then
      timer_stub:revert()
      timer_stub = nil
    end
  end)

  local function traceText()
    return table.concat(boop.state.trace.buffer or {}, "\n")
  end

  local function assertTraceContains(expected)
    assert.is_true(traceText():find(expected, 1, true) ~= nil)
  end

  local function setOperation(operation)
    assert.is_function(boop.runtime.setOperationLock)
    boop.runtime.setOperationLock(
      operation.owner,
      operation.code,
      operation.label,
      operation.systems,
      operation.waitsFor,
      {
        observed = operation.observed,
      }
    )
  end

  local function clearOperation(owner, reason)
    assert.is_function(boop.runtime.clearOperationLock)
    boop.runtime.clearOperationLock(owner, reason)
  end

  local function countTraceOccurrences(expected)
    local count = 0
    local offset = 1
    local trace = traceText()
    while true do
      local found = trace:find(expected, offset, true)
      if not found then
        return count
      end
      count = count + 1
      offset = found + #expected
    end
  end

  local function publishAcceptedRoomList(items)
    local observation = boop.runtime.roomObservationSnapshot()
    if observation.itemsSeen and not observation.activeFenceId then
      boop.runtime.startRoomObservation(observation.roomId, {
        boundary = "fresh_start",
      })
      observation = boop.runtime.roomObservationSnapshot()
    end
    if not observation.refreshAttempted then
      assert.is_true(boop.requestRoomItemsOnce("trace test room response"))
    end

    gmcp.Char.Items.List = {
      location = "inv",
      items = {},
    }
    boop.onRoomItemsList()

    gmcp.Char.Items.List = {
      location = "room",
      items = items,
    }
    boop.onRoomItemsList()

    for index = #scheduled, 1, -1 do
      if scheduled[index].delay == 0 then
        scheduled[index].callback()
        break
      end
    end
  end

  it("logs room info transitions and room item gmcp events", function()
    gmcp.Room.Info = {
      num = 15,
      area = "Test Area",
      exits = { n = 16, s = 14 },
    }

    boop.onRoomInfo()

    publishAcceptedRoomList({
      { id = "1", name = "a gold sovereign" },
      { id = "42", name = "a vicious gnoll soldier", attrib = "m" },
    })

    gmcp.Char.Items.Add = {
      location = "room",
      item = { id = "2", name = "a small pile of sovereigns" },
    }
    boop.onRoomItemsAdd()

    gmcp.Char.Items.Remove = {
      location = "room",
      item = { id = "42", name = "a vicious gnoll soldier" },
    }
    boop.onRoomItemsRemove()

    local trace = table.concat(boop.state.trace.buffer or {}, "\n")
    assert.is_true(trace:find("gmcp room info:", 1, true) ~= nil)
    assert.is_true(trace:find("| area=Test Area | exits=2 | moved=yes", 1, true) ~= nil)
    assert.is_true(trace:find("gmcp room items list: count=2 | gold=yes | gold=a gold sovereign (1)", 1, true) ~= nil)
    assert.is_true(trace:find("| denizens=1", 1, true) ~= nil)
    assert.is_true(trace:find("gmcp room item add: a small pile of sovereigns (2) | gold=yes", 1, true) ~= nil)
    assert.is_true(trace:find("gmcp room item remove: a vicious gnoll soldier (42) | gold=no", 1, true) ~= nil)
  end)

  it("logs pending room deltas and the reconciled denizen count", function()
    boop.runtime.startRoomObservation("1", {
      boundary = "fresh_start",
    })
    assert.is_true(boop.requestRoomItemsOnce(
      "trace pending room delta"
    ))

    gmcp.Char.Items.List = {
      location = "inv",
      items = {},
    }
    boop.onRoomItemsList()

    gmcp.Char.Items.Add = {
      location = "room",
      item = {
        id = "42",
        name = "an arriving denizen",
        attrib = "m",
      },
    }
    boop.onRoomItemsAdd()

    gmcp.Char.Items.List = {
      location = "room",
      items = {
        {
          id = "7001",
          name = "an unrelated room item",
          attrib = "t",
        },
      },
    }
    boop.onRoomItemsList()

    for index = #scheduled, 1, -1 do
      if scheduled[index].delay == 0 then
        scheduled[index].callback()
        break
      end
    end

    assertTraceContains(
      "gmcp room item add: an arriving denizen (42) | gold=no | attrib=m"
    )
    assertTraceContains(
      "room item delta recorded: add 42 | room=1"
    )
    assertTraceContains(
      "gmcp room items list: count=2 | gold=no | denizens=1"
    )
  end)

  it("logs operation enter and exit transitions once per state change", function()
    setOperation({
      owner = "interrupt:1",
      code = "interrupt_pending",
      label = "interrupt pending",
      systems = {
        combat = true,
        queue = true,
      },
      waitsFor = {
        prompt = true,
      },
      observed = {
        command = "diagnose",
      },
    })

    setOperation({
      owner = "interrupt:1",
      code = "interrupt_pending",
      label = "interrupt pending",
      systems = {
        combat = true,
        queue = true,
      },
      waitsFor = {
        prompt = true,
      },
      observed = {
        command = "diagnose",
      },
    })

    clearOperation("interrupt:1", "prompt observed")

    local trace = traceText()
    local first_enter = trace:find("operation enter: interrupt:1 | interrupt_pending -- interrupt pending | systems: combat, queue | waits: prompt | observed: command:diagnose", 1, true)
    assert.is_true(first_enter ~= nil)
    assert.is_nil(trace:find("operation enter: interrupt:1 | interrupt_pending", first_enter + 1, true))
    assertTraceContains("operation exit: interrupt:1 | interrupt_pending -- interrupt pending | reason=prompt observed")
  end)

  it("logs target-loss cleanup, recovery, and valid retarget decisions from owned state", function()
    helper.setArea("Test Area")
    helper.setClass("Occultist")
    helper.learnSkill("Lycantha", "Domination")
    publishAcceptedRoomList({
      { id = "42", name = "a first denizen", attrib = "m" },
      { id = "43", name = "an excluded denizen", attrib = "mx" },
      { id = "44", name = "a valid replacement", attrib = "m" },
    })
    helper.setTarget("42", "a first denizen", "80%")
    helper.seedAutomationIntent()
    boop.config.enabled = true
    boop.config.targetingMode = "auto"

    gmcp.Char.Items.Remove = {
      location = "room",
      item = { id = "42", name = "a first denizen", attrib = "m" },
    }

    boop.onRoomItemsRemove()
    for index = #scheduled, 1, -1 do
      if scheduled[index].delay == 0 then
        scheduled[index].callback()
        break
      end
    end

    assertTraceContains("target lost: 42 -- a first denizen")
    assertTraceContains("attack intent cleared: target_lost")
    assertTraceContains("retarget selected: 44 -- a valid replacement | reason=target_lost")
    assert.is_nil(traceText():find("an excluded denizen", 1, true))
  end)

  it("logs flee cleanup and concurrent operations using normalized owned values", function()
    local state = helper.seedAutomationIntent()
    state.diag.hold = true
    state.diag.label = "diag"
    state.gag.pendingAttack = {
      source = "self",
      ability = "hound",
      target = "a first denizen",
    }

    assert.is_function(boop.runtime.clearAutomationIntent)
    boop.runtime.clearAutomationIntent("flee", {
      source = "auto-flee",
    })

    setOperation({
      owner = "pull:4",
      code = "pull_away",
      label = "pull in progress",
      systems = {
        target = true,
        combat = true,
        walk = true,
      },
      waitsFor = {
        room = true,
      },
      observed = {
        originRoom = "1",
        currentRoom = "2",
      },
    })

    setOperation({
      owner = "interrupt:5",
      code = "interrupt_pending",
      label = "interrupt pending",
      systems = {
        combat = true,
        queue = true,
      },
      waitsFor = {
        prompt = true,
      },
      observed = {
        command = "diagnose",
      },
    })

    local trace = traceText()
    assert.is_true(trace:find("automation intent cleared: flee | source=auto-flee | target=42 | queue=prequeued aliasDirty=false | walk=active moveQueued=true | gold=get,put | diag=hold:diag | gag=pending:self/hound/a first denizen", 1, true) ~= nil)
    assert.is_true(trace:find("operation enter: pull:4 | pull_away -- pull in progress | systems: combat, target, walk | waits: room | observed: currentRoom:2,originRoom:1", 1, true) ~= nil)
    assert.is_true(trace:find("operation enter: interrupt:5 | interrupt_pending -- interrupt pending | systems: combat, queue | waits: prompt | observed: command:diagnose", 1, true) ~= nil)
    local blockers = boop.runtime.operationLocksSnapshot()
    assert.are.equal("pull:4", blockers[1].owner)
    assert.are.equal("interrupt:5", blockers[2].owner)

    clearOperation("pull:4", "returned")

    blockers = boop.runtime.operationLocksSnapshot()
    assert.are.equal(1, #blockers)
    assert.are.equal("interrupt:5", blockers[1].owner)
    assertTraceContains("operation exit: pull:4 | pull_away -- pull in progress | reason=returned")
    assert.is_nil(trace:find("gmcp.IRE.Target.Info", 1, true))
    assert.is_nil(trace:find("ButtonActions", 1, true))
  end)

  it("sorts every owner and traces exact non-primary release and primary promotion", function()
    setOperation({
      owner = "gold:5",
      code = "gold_pack_pending",
      label = "gold pack pending",
      systems = { combat = true, gold = true, queue = true, walk = true },
      waitsFor = { inventory = true },
    })
    setOperation({
      owner = "interrupt:9",
      code = "interrupt_pending",
      label = "interrupt nine pending",
      systems = { combat = true, queue = true },
      waitsFor = { prompt = true },
    })
    setOperation({
      owner = "pull:1",
      code = "pull_active",
      label = "pull active",
      systems = {
        target = true,
        combat = true,
        queue = true,
        walk = true,
      },
      waitsFor = { room = true },
    })
    setOperation({
      owner = "interrupt:2",
      code = "interrupt_pending",
      label = "interrupt two pending",
      systems = { combat = true, queue = true },
      waitsFor = { prompt = true },
    })

    local blockers = boop.runtime.operationLocksSnapshot()
    assert.are.same({
      "pull:1",
      "interrupt:2",
      "interrupt:9",
      "gold:5",
    }, {
      blockers[1].owner,
      blockers[2].owner,
      blockers[3].owner,
      blockers[4].owner,
    })
    local primary = boop.runtime.operationLockSnapshot()
    assert.are.equal("pull:1", primary.owner)
    assert.are.equal(3, primary.additionalCount)

    clearOperation("interrupt:9", "non-primary complete")

    primary = boop.runtime.operationLockSnapshot()
    assert.are.equal("pull:1", primary.owner)
    assert.are.equal(2, primary.additionalCount)
    assert.are.equal(
      1,
      countTraceOccurrences(
        "operation exit: interrupt:9 | interrupt_pending -- interrupt nine pending | reason=non-primary complete"
      )
    )
    assert.are.equal(0, countTraceOccurrences("operation exit: gold:5"))

    clearOperation("pull:1", "primary recovered")

    primary = boop.runtime.operationLockSnapshot()
    assert.are.equal("interrupt:2", primary.owner)
    assert.are.equal("interrupt_pending", primary.code)
    assert.are.equal(1, primary.additionalCount)
    assert.are.equal(
      1,
      countTraceOccurrences(
        "operation exit: pull:1 | pull_active -- pull active | reason=primary recovered"
      )
    )
    assertTraceContains(
      "operation enter: gold:5 | gold_pack_pending -- gold pack pending | systems: combat, gold, queue, walk | waits: inventory"
    )
    assertTraceContains(
      "operation enter: interrupt:2 | interrupt_pending -- interrupt two pending | systems: combat, queue | waits: prompt"
    )
  end)
end)

describe("boop trace live session semantics", function()
  local feedback
  local originalFeedback
  local originalSaveConfig

  before_each(function()
    helper.reset()
    feedback = {}
    originalFeedback = boop.util.feedback
    originalSaveConfig = boop.db.saveConfig
    boop.util.feedback = function(kind, message)
      feedback[#feedback + 1] = {
        kind = tostring(kind or ""),
        message = tostring(message or ""),
      }
    end
  end)

  after_each(function()
    boop.util.feedback = originalFeedback
    boop.db.saveConfig = originalSaveConfig
  end)

  local function feedbackMessages(kind)
    local messages = {}
    for _, entry in ipairs(feedback) do
      if not kind or entry.kind == kind then
        messages[#messages + 1] = entry.message
      end
    end
    return messages
  end

  local function feedbackText()
    local messages = {}
    for _, entry in ipairs(feedback) do
      messages[#messages + 1] = entry.kind .. " " .. entry.message
    end
    return table.concat(messages, "\n")
  end

  it("G-03-6 fresh runtime state keeps trace live off", function()
    assert.is_false(boop.state.trace.live)
  end)

  it("G-03-6 package reload reset executes before bootstrap early return", function()
    local testsDirectory = tostring(os.getenv("TESTS_DIRECTORY") or "")
    local repoRoot = os.getenv("BOOP_REPO_ROOT")
      or testsDirectory:match("^(.*)/tests/?$")
    repoRoot = assert(repoRoot, "boop repository root is required")
    local priorBootstrapped = boop.bootstrapped
    local buffer = {
      "10:11:12 | sentinel one",
      "10:11:13 | sentinel two",
    }
    boop.state.trace.buffer = buffer
    boop.state.trace.live = true
    boop.bootstrapped = true

    local ok, err = pcall(
      dofile,
      repoRoot .. "/src/scripts/boop/boop_bootstrap.lua"
    )
    boop.bootstrapped = priorBootstrapped

    assert.is_true(ok, tostring(err))
    assert.is_false(boop.state.trace.live)
    assert.are.equal(buffer, boop.state.trace.buffer)
    assert.are.same({
      "10:11:12 | sentinel one",
      "10:11:13 | sentinel two",
    }, boop.state.trace.buffer)
  end)

  it("G-03-6 trace live toggles session state without persistence or collection changes", function()
    local saved = {}
    boop.db.saveConfig = function(key, value)
      saved[#saved + 1] = {
        key = key,
        value = value,
      }
    end
    boop.config.traceEnabled = false

    boop.ui.traceCommand("live", "on")

    assert.is_true(boop.state.trace.live)
    assert.is_false(boop.config.traceEnabled)
    assert.are.same({}, saved)
    assert.is_true(
      feedbackText():find(
        "trace live: on | collection remains off",
        1,
        true
      ) ~= nil
    )

    boop.ui.traceCommand("live", "off")

    assert.is_false(boop.state.trace.live)
    assert.is_false(boop.config.traceEnabled)
    assert.are.same({}, saved)
    assert.is_true(
      feedbackText():find("trace live: off", 1, true) ~= nil
    )
  end)

  it("G-03-6 collection off suppresses both append and live output", function()
    boop.config.traceEnabled = false
    boop.state.trace.live = true

    boop.trace.log("collection disabled")

    assert.are.equal(0, #boop.state.trace.buffer)
    assert.are.equal(0, #feedback)
  end)

  it("G-03-6 live output matches each accepted append exactly once without recursion", function()
    boop.config.traceEnabled = true
    boop.state.trace.live = true

    boop.trace.log("first accepted entry")
    local first = boop.state.trace.buffer[1]

    assert.are.equal(1, #boop.state.trace.buffer)
    assert.are.same({
      "trace live: " .. first,
    }, feedbackMessages("INFO"))

    boop.trace.log("second accepted entry")
    local second = boop.state.trace.buffer[2]

    assert.are.equal(2, #boop.state.trace.buffer)
    assert.are.same({
      "trace live: " .. first,
      "trace live: " .. second,
    }, feedbackMessages("INFO"))
  end)

  it("G-03-6 live off keeps accepted appends silent", function()
    boop.config.traceEnabled = true
    boop.state.trace.live = false

    boop.trace.log("buffer only")

    assert.are.equal(1, #boop.state.trace.buffer)
    assert.is_true(
      boop.state.trace.buffer[1]:find(
        " | buffer only",
        1,
        true
      ) ~= nil
    )
    assert.are.equal(0, #feedback)
  end)

  it("G-03-6 show clear and trim preserve their existing buffer contract", function()
    boop.config.traceEnabled = true
    boop.state.trace.live = false
    for index = 1, 101 do
      boop.trace.log("trim entry " .. tostring(index))
    end

    assert.are.equal(100, #boop.state.trace.buffer)
    assert.is_nil(
      table.concat(boop.state.trace.buffer, "\n"):find(
        "trim entry 1\n",
        1,
        true
      )
    )
    assert.is_true(
      boop.state.trace.buffer[100]:find(
        " | trim entry 101",
        1,
        true
      ) ~= nil
    )

    boop.state.trace.live = true
    local beforeShow = boop.state.trace.buffer
    boop.trace.show(1)

    assert.are.equal(beforeShow, boop.state.trace.buffer)
    assert.are.equal(100, #boop.state.trace.buffer)
    assert.are.same({
      "trace: showing 1/100",
      "  " .. boop.state.trace.buffer[100],
    }, feedbackMessages("INFO"))

    boop.trace.clear()

    assert.are.equal(0, #boop.state.trace.buffer)
    assert.is_true(boop.state.trace.live)
    assert.is_true(
      feedbackText():find("trace: cleared", 1, true) ~= nil
    )
  end)

  it("G-03-6 bare status and invalid live values distinguish both modes", function()
    boop.config.traceEnabled = true
    boop.state.trace.live = false

    boop.ui.traceCommand("")
    boop.ui.traceCommand("live", "maybe")

    local text = feedbackText()
    assert.is_true(
      text:find("trace: collection on | live off", 1, true) ~= nil
    )
    assert.is_true(
      text:find("trace live expects on|off", 1, true) ~= nil
    )
    assert.is_true(
      text:find(
        "boop trace on|off|live on|off|show [n]|clear",
        1,
        true
      ) ~= nil
    )
  end)
end)
