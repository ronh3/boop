local helper = dofile(os.getenv("TESTS_DIRECTORY") .. "/support/boop_test_helper.lua")
dofile(helper.repoRoot() .. "/src/scripts/boop/attacks/psion.lua")
dofile(helper.repoRoot() .. "/src/scripts/boop/attacks/blue_dragon.lua")

describe("boop pull command", function()
  local send_stub
  local timer_stub
  local kill_timer_stub
  local set_enabled_stub
  local save_config_stub
  local trace_stub
  local tick_stub
  local ok_stub
  local warn_stub
  local info_stub
  local sent
  local scheduled
  local killed
  local enabled_calls
  local saved_enabled
  local traces
  local ok_messages
  local warn_messages
  local info_messages
  local tick_count
  local ownedPullTimerIds

  local function blockerFor(owner)
    for _, blocker in ipairs(boop.runtime.blockersSnapshot()) do
      if blocker.owner == owner then
        return blocker
      end
    end
    return nil
  end

  local function pullTraceCount()
    local count = 0
    for _, message in ipairs(traces) do
      if tostring(message):find("pull", 1, true) then
        count = count + 1
      end
    end
    return count
  end

  local function pullTimer()
    local pull = boop.state.combat.pullState
    local timer_id = type(pull) == "table" and pull.timeoutTimer or nil
    assert.is_number(timer_id)
    assert.is_table(scheduled[timer_id])
    assert.are.equal(boop.config.diagTimeoutSeconds, scheduled[timer_id].delay)
    ownedPullTimerIds[timer_id] = true
    return timer_id, scheduled[timer_id]
  end

  local function ownedPullTimerCount()
    local count = 0
    for _ in pairs(ownedPullTimerIds) do
      count = count + 1
    end
    return count
  end

  local function unrelatedScheduledTimerCount(expectedDelay)
    local count = 0
    for timer_id, timer in pairs(scheduled) do
      if not ownedPullTimerIds[timer_id]
          and (expectedDelay == nil or timer.delay == expectedDelay) then
        count = count + 1
      end
    end
    return count
  end

  local function killedCount(timer_id)
    local count = 0
    for _, killed_id in ipairs(killed) do
      if killed_id == timer_id then
        count = count + 1
      end
    end
    return count
  end

  local function seedUnrelatedOwner()
    helper.setRuntimeBlocker({
      owner = "interrupt:unrelated",
      code = "interrupt_pending",
      label = "unrelated hold",
      systems = { combat = true, queue = true, target = true, gold = true, walk = true },
      waitsFor = { prompt = true },
    })
  end

  local function assertActivePull(generation, phase, timer_id, command)
    local pull = boop.state.combat.pullState
    assert.are.same({
      active = true,
      generation = generation,
      blockerOwner = "pull:" .. tostring(generation),
      phase = phase,
      terminal = false,
      originRoom = "1",
      direction = "north",
      returnDirection = "south",
      command = command,
      timeoutTimer = timer_id,
    }, pull)
    assert.are.equal(generation, boop.state.combat.pullGeneration)
  end

  local function assertPullBlocker(generation, code)
    local blocker = blockerFor("pull:" .. tostring(generation))
    assert.is_table(blocker)
    assert.are.equal(code, blocker.code)
    assert.are.same({
      combat = true,
      queue = true,
      target = true,
      gold = true,
      walk = true,
    }, blocker.systems)
    assert.is_true(blocker.waitsFor.room)
    return blocker
  end

  local function moveTo(room)
    gmcp.Room.Info.num = tostring(room)
    boop.onRoomInfo()
  end

  before_each(function()
    helper.reset()
    helper.setClass("Occultist")
    helper.setRage(18)
    helper.learnSkill("Harry", "Attainment")
    helper.setSkillKnown("chaosgate", false, "Attainment")
    helper.setSkillKnown("fluctuate", false, "Attainment")
    boop.config.diagTimeoutSeconds = 8
    boop.config.gameSeparator = "|"
    boop.config.traceEnabled = true
    boop.state.targeting.room = "1"
    gmcp.Room.Info.num = "1"

    sent = {}
    scheduled = {}
    killed = {}
    enabled_calls = {}
    saved_enabled = {}
    traces = {}
    ok_messages = {}
    warn_messages = {}
    info_messages = {}
    tick_count = 0
    ownedPullTimerIds = {}

    timer_stub = stub(_G, "tempTimer", function(delay, callback)
      local timer_id = #scheduled + 1
      scheduled[timer_id] = {
        delay = delay,
        callback = callback,
      }
      return timer_id
    end)
    kill_timer_stub = stub(_G, "killTimer", function(timer_id)
      killed[#killed + 1] = timer_id
    end)
    send_stub = stub(_G, "send", function(command, echo_back)
      if not tostring(command or ""):match("^%s*$") then
        sent[#sent + 1] = {
          command = command,
          echoBack = echo_back,
        }
      end
    end)
    set_enabled_stub = stub(boop.ui, "setEnabled", function(value, quiet, opts)
      enabled_calls[#enabled_calls + 1] = {
        value = value,
        quiet = quiet,
        opts = opts,
      }
    end)
    save_config_stub = stub(boop.db, "saveConfig", function(key, value)
      if key == "enabled" then
        saved_enabled[#saved_enabled + 1] = value
      end
    end)
    trace_stub = stub(boop.trace, "log", function(message)
      traces[#traces + 1] = message
    end)
    tick_stub = stub(boop, "tick", function()
      tick_count = tick_count + 1
    end)
    ok_stub = stub(boop.util, "ok", function(msg)
      ok_messages[#ok_messages + 1] = msg
    end)
    warn_stub = stub(boop.util, "warn", function(msg)
      warn_messages[#warn_messages + 1] = msg
    end)
    info_stub = stub(boop.util, "info", function(msg)
      info_messages[#info_messages + 1] = msg
    end)
  end)

  after_each(function()
    if tick_stub then tick_stub:revert() tick_stub = nil end
    if send_stub then send_stub:revert() send_stub = nil end
    if timer_stub then timer_stub:revert() timer_stub = nil end
    if kill_timer_stub then kill_timer_stub:revert() kill_timer_stub = nil end
    if set_enabled_stub then set_enabled_stub:revert() set_enabled_stub = nil end
    if save_config_stub then save_config_stub:revert() save_config_stub = nil end
    if trace_stub then trace_stub:revert() trace_stub = nil end
    if ok_stub then ok_stub:revert() ok_stub = nil end
    if warn_stub then warn_stub:revert() warn_stub = nil end
    if info_stub then info_stub:revert() info_stub = nil end
  end)

  it("allocates one exact owner, record, timer, and unchanged command", function()
    boop.config.enabled = true
    seedUnrelatedOwner()

    boop.ui.pullCommand("mage", "north")

    local command = "north|harry mage|leap south"
    assertActivePull(1, "outbound", 1, command)
    assertPullBlocker(1, "pull_active")
    assert.is_table(blockerFor("interrupt:unrelated"))
    assert.are.same({
      { command = command, echoBack = false },
    }, sent)
    assert.are.equal(1, #scheduled)
    assert.are.equal(8, scheduled[1].delay)
    assert.are.same({ "pull queued: " .. command }, ok_messages)
    assert.are.equal(0, #warn_messages)
    assert.are.equal(0, #info_messages)
    assert.are.equal(0, #enabled_calls)
    assert.are.equal(0, #saved_enabled)
    assert.is_true(boop.config.enabled)
  end)

  it("prepends psion transcend shatter to pull rage commands", function()
    helper.setClass("Psion")
    helper.setRage(25)
    helper.learnSkill("whirlwind", "Attainment")
    boop.config.enabled = true

    boop.ui.pullCommand("mage", "north")

    assert.are.same({
      {
        command = "north|psi transcend shatter/weave whirlwind mage|leap south",
        echoBack = false,
      },
    }, sent)
  end)

  it("leaves dragon pull rage commands unchanged", function()
    helper.setClass("Blue Dragon")
    helper.setRage(14)
    helper.learnSkill("dragonchill", "Attainment")
    boop.config.enabled = true

    boop.ui.pullCommand("mage", "north")

    assert.are.same({
      {
        command = "north|dragonchill mage|leap south",
        echoBack = false,
      },
    }, sent)
  end)

  it("lets return win once and makes the captured timeout a zero-effect no-op", function()
    boop.config.enabled = true
    seedUnrelatedOwner()

    boop.ui.pullCommand("mage", "north")
    local generation = boop.state.combat.pullState.generation
    local timeout_id, timeout = pullTimer()
    local timeout_callback = timeout.callback

    moveTo("2")
    assertActivePull(generation, "away", timeout_id, "north|harry mage|leap south")
    assertPullBlocker(generation, "pull_active")

    moveTo("1")
    assert.is_true(boop.config.enabled)
    assert.is_false(boop.state.combat.pullState)
    assert.is_nil(blockerFor("pull:" .. tostring(generation)))
    assert.is_table(blockerFor("interrupt:unrelated"))
    assert.are.equal(1, killedCount(timeout_id))
    assert.are.same({ "pull queued: north|harry mage|leap south", "pull complete" }, ok_messages)
    assert.are.equal(0, #warn_messages)
    assert.are.equal(1, #sent)
    assert.are.equal(1, ownedPullTimerCount())
    assert.is_true(unrelatedScheduledTimerCount() >= 1)
    assert.is_true(
      unrelatedScheduledTimerCount(boop.config.diagTimeoutSeconds) >= 1
    )
    assert.are.equal(0, tick_count)
    assert.are.equal(5, pullTraceCount())
    assert.are.equal(0, #enabled_calls)
    assert.are.equal(0, #saved_enabled)

    local snapshot = {
      generation = boop.state.combat.pullGeneration,
      sends = #sent,
      timers = #scheduled,
      killed = #killed,
      oks = #ok_messages,
      warnings = #warn_messages,
      traces = #traces,
      ticks = tick_count,
    }

    timeout_callback()

    assert.is_false(boop.ui.completePull(generation, "timeout_at_origin"))
    assert.are.equal(snapshot.generation, boop.state.combat.pullGeneration)
    assert.are.equal(snapshot.sends, #sent)
    assert.are.equal(snapshot.timers, #scheduled)
    assert.are.equal(snapshot.killed, #killed)
    assert.are.equal(snapshot.oks, #ok_messages)
    assert.are.equal(snapshot.warnings, #warn_messages)
    assert.are.equal(snapshot.traces, #traces)
    assert.are.equal(snapshot.ticks, tick_count)
    assert.is_table(blockerFor("interrupt:unrelated"))
  end)

  it("preserves the active-pull target-loss exception while away and cleans up after return", function()
    helper.setDenizens({
      { id = "42", name = "a pulled mage" },
    })
    helper.setTarget("42", "a pulled mage", "70%")
    boop.state.queue.prequeuedStandard = true
    boop.state.queue.aliasAction = "command hound at 42"
    boop.state.queue.aliasDirty = false
    boop.config.enabled = true
    boop.config.targetingMode = "auto"

    boop.ui.pullCommand("mage", "north")

    moveTo("2")
    assert.are.equal("away", boop.state.combat.pullState.phase)

    gmcp.Char.Items.Remove = {
      location = "room",
      item = { id = "42", name = "a pulled mage", attrib = "m" },
    }
    boop.onRoomItemsRemove()

    assert.are.equal("42", boop.state.targeting.currentTargetId)
    assert.are.equal("a pulled mage", boop.state.targeting.targetName)
    assert.is_true(boop.state.queue.prequeuedStandard)
    assert.are.equal("command hound at 42", boop.state.queue.aliasAction)
    assert.is_truthy(boop.state.combat.pullState)

    moveTo("1")

    assert.is_false(boop.state.combat.pullState)
    assert.are.equal("", boop.state.targeting.currentTargetId)
    assert.are.equal("", boop.state.targeting.targetName)
    assert.is_false(boop.state.queue.prequeuedStandard)
    assert.are.equal("", boop.state.queue.aliasAction)
    assert.is_true(boop.state.queue.aliasDirty)
    assert.is_nil(blockerFor("pull:1"))
  end)

  it("terminates at origin on timeout without changing saved enabled intent", function()
    boop.config.enabled = true
    seedUnrelatedOwner()

    boop.ui.pullCommand("mage", "north")
    assert.is_function(scheduled[1].callback)

    scheduled[1].callback()

    assert.is_true(boop.config.enabled)
    assert.is_false(boop.state.combat.pullState)
    assert.is_nil(blockerFor("pull:1"))
    assert.is_table(blockerFor("interrupt:unrelated"))
    assert.are.same({ "pull timeout at origin; pull hold released" }, warn_messages)
    assert.are.equal(1, #sent)
    assert.are.equal(1, #scheduled)
    assert.are.equal(0, tick_count)
    assert.are.equal(0, #enabled_calls)
    assert.are.equal(0, #saved_enabled)
  end)

  it("keeps the same owner after timeout away and releases once on matching return", function()
    boop.config.enabled = true
    seedUnrelatedOwner()

    boop.ui.pullCommand("mage", "north")
    local timeout_id, timeout = pullTimer()
    moveTo("2")
    assert.are.equal("away", boop.state.combat.pullState.phase)

    timeout.callback()

    assert.is_true(boop.config.enabled)
    assertActivePull(1, "timed_out_away", nil, "north|harry mage|leap south")
    local blocker = assertPullBlocker(1, "pull_timeout_away")
    assert.are.equal("2", blocker.observed.currentRoom)
    assert.is_table(blockerFor("interrupt:unrelated"))
    assert.are.same({ "pull timeout; hold remains until return" }, warn_messages)
    assert.are.equal(0, killedCount(timeout_id))
    assert.are.equal(1, #sent)
    assert.are.equal(1, ownedPullTimerCount())
    assert.is_true(unrelatedScheduledTimerCount() >= 1)
    assert.is_true(
      unrelatedScheduledTimerCount(boop.config.diagTimeoutSeconds) >= 1
    )
    assert.are.equal(0, tick_count)

    moveTo("1")

    assert.is_false(boop.state.combat.pullState)
    assert.is_nil(blockerFor("pull:1"))
    assert.is_table(blockerFor("interrupt:unrelated"))
    assert.are.same({
      "pull queued: north|harry mage|leap south",
      "pull complete after timeout",
    }, ok_messages)
    assert.are.equal(1, #warn_messages)
    assert.are.equal(0, killedCount(timeout_id))
    assert.are.equal(1, #sent)
    assert.are.equal(1, ownedPullTimerCount())
    assert.is_true(unrelatedScheduledTimerCount() >= 1)
    assert.is_true(
      unrelatedScheduledTimerCount(boop.config.diagTimeoutSeconds) >= 1
    )
    assert.are.equal(0, tick_count)
    assert.are.equal(0, #enabled_calls)
    assert.are.equal(0, #saved_enabled)
  end)

  it("keeps a newer pull unchanged when the old timeout callback runs", function()
    boop.config.enabled = true
    seedUnrelatedOwner()

    boop.ui.pullCommand("mage", "north")
    local old_timeout_id, old_timeout_timer = pullTimer()
    local old_timeout = old_timeout_timer.callback
    moveTo("2")
    moveTo("1")

    boop.ui.pullCommand("mage", "north")
    local new_timeout_id = pullTimer()
    assert.are_not.equal(old_timeout_id, new_timeout_id)
    assertActivePull(2, "outbound", new_timeout_id, "north|harry mage|leap south")
    assertPullBlocker(2, "pull_active")

    local operation = boop.state.combat.pullState
    local snapshot = {
      generation = boop.state.combat.pullGeneration,
      phase = operation.phase,
      owner = operation.blockerOwner,
      timer = operation.timeoutTimer,
      command = operation.command,
      sends = #sent,
      timers = #scheduled,
      killed = #killed,
      warnings = #warn_messages,
      oks = #ok_messages,
      traces = #traces,
      ticks = tick_count,
    }

    old_timeout()

    assert.is_true(operation == boop.state.combat.pullState)
    assert.are.equal(snapshot.generation, boop.state.combat.pullGeneration)
    assert.are.equal(snapshot.phase, boop.state.combat.pullState.phase)
    assert.are.equal(snapshot.owner, boop.state.combat.pullState.blockerOwner)
    assert.are.equal(snapshot.timer, boop.state.combat.pullState.timeoutTimer)
    assert.are.equal(snapshot.command, boop.state.combat.pullState.command)
    assert.are.equal(snapshot.sends, #sent)
    assert.are.equal(snapshot.timers, #scheduled)
    assert.are.equal(snapshot.killed, #killed)
    assert.are.equal(snapshot.warnings, #warn_messages)
    assert.are.equal(snapshot.oks, #ok_messages)
    assert.are.equal(snapshot.traces, #traces)
    assert.are.equal(snapshot.ticks, tick_count)
    assertPullBlocker(2, "pull_active")
    assert.is_table(blockerFor("interrupt:unrelated"))
  end)

  it("rejects wrong-generation and already-terminal completion without effects", function()
    boop.config.enabled = true
    seedUnrelatedOwner()

    boop.ui.pullCommand("mage", "north")
    local pull = boop.state.combat.pullState
    local snapshot = {
      sends = #sent,
      timers = #scheduled,
      killed = #killed,
      warnings = #warn_messages,
      oks = #ok_messages,
      traces = #traces,
      ticks = tick_count,
    }

    assert.is_false(boop.ui.completePull(pull.generation + 1, "returned_origin"))
    assert.is_true(pull == boop.state.combat.pullState)
    assertPullBlocker(pull.generation, "pull_active")

    pull.active = false
    pull.phase = "terminal"
    pull.terminal = true
    assert.is_false(boop.ui.completePull(pull.generation, "returned_origin"))

    assert.is_true(pull == boop.state.combat.pullState)
    assert.is_table(blockerFor("pull:" .. tostring(pull.generation)))
    assert.is_table(blockerFor("interrupt:unrelated"))
    assert.are.equal(snapshot.sends, #sent)
    assert.are.equal(snapshot.timers, #scheduled)
    assert.are.equal(snapshot.killed, #killed)
    assert.are.equal(snapshot.warnings, #warn_messages)
    assert.are.equal(snapshot.oks, #ok_messages)
    assert.are.equal(snapshot.traces, #traces)
    assert.are.equal(snapshot.ticks, tick_count)
  end)

  it("rejects repeats without another send, timer, generation, or owner", function()
    boop.config.enabled = true
    seedUnrelatedOwner()

    boop.ui.pullCommand("mage", "north")
    local original = boop.state.combat.pullState
    local original_timer = original.timeoutTimer

    boop.ui.pullCommand("mage", "north")
    boop.ui.pullCommand("another mage", "south")

    assert.is_true(original == boop.state.combat.pullState)
    assert.are.equal(1, boop.state.combat.pullGeneration)
    assert.are.equal(original_timer, boop.state.combat.pullState.timeoutTimer)
    assert.are.equal("north|harry mage|leap south", boop.state.combat.pullState.command)
    assert.are.equal(1, #sent)
    assert.are.equal(1, #scheduled)
    assert.are.equal(0, #killed)
    assert.are.same({
      "pull already in progress",
      "pull already in progress",
    }, warn_messages)
    assertPullBlocker(1, "pull_active")
    assert.is_table(blockerFor("interrupt:unrelated"))
    assert.are.equal(0, #enabled_calls)
    assert.are.equal(0, #saved_enabled)
  end)

  it("keeps an operator-disabled session disabled after every terminal path", function()
    local terminal_scenarios = {
      function(_)
        moveTo("2")
        moveTo("1")
      end,
      function(timeout_id)
        scheduled[timeout_id].callback()
      end,
      function(timeout_id)
        moveTo("2")
        scheduled[timeout_id].callback()
        moveTo("1")
      end,
    }

    for generation, finish in ipairs(terminal_scenarios) do
      boop.ui.pullCommand("mage", "north")
      local timeout_id = pullTimer()
      assert.are.equal(generation, ownedPullTimerCount())
      finish(timeout_id)
      assert.is_false(boop.config.enabled)
      assert.is_false(boop.state.combat.pullState)
    end

    assert.are.equal(3, boop.state.combat.pullGeneration)
    assert.are.equal(3, #sent)
    assert.are.equal(3, ownedPullTimerCount())
    assert.is_true(unrelatedScheduledTimerCount() >= 1)
    assert.is_true(
      unrelatedScheduledTimerCount(boop.config.diagTimeoutSeconds) >= 1
    )
    assert.are.equal(0, #enabled_calls)
    assert.are.equal(0, #saved_enabled)
  end)

  it("rejects mob names that contain the configured command separator", function()
    boop.config.enabled = true

    boop.ui.pullCommand("mage|say unsafe", "north")

    assert.are.equal(0, #sent)
    assert.is_false(boop.state.combat.pullState)
    assert.are.same({
      "pull: mob name cannot contain the game separator or newlines",
    }, warn_messages)
  end)

  it("shows usage when the separator command is queried bare", function()
    boop.ui.gameSeparatorCommand("")

    assert.are.same({
      "game separator: |",
      "Usage: boop separator <text>",
    }, info_messages)
  end)
end)
