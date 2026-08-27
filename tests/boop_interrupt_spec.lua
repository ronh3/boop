local helper = dofile(os.getenv("TESTS_DIRECTORY") .. "/support/boop_test_helper.lua")

describe("boop queued interrupts", function()
  local LEAP_DENIAL = "Both of your legs must be free and unhindered to do that."
  local FLY_SUCCESS = "The gauntlets carry you up into the skies."
  local send_stub
  local timer_stub
  local kill_timer_stub
  local info_stub
  local ok_stub
  local warn_stub
  local tick_stub
  local sent
  local scheduled
  local killed
  local info_messages
  local ok_messages
  local warn_messages
  local tick_count
  local native_queue

  local prompt_interrupts = {
    {
      name = "matic",
      command = "ldeck draw matic",
      tier = "utility",
      invoke = function() boop.ui.matic() end,
    },
    {
      name = "catarin",
      command = "ldeck draw catarin",
      tier = "utility",
      invoke = function() boop.ui.catarin() end,
    },
    {
      name = "fly",
      command = "fly",
      tier = "emergency",
      invoke = function() boop.ui.fly() end,
    },
    {
      name = "ts",
      command = "touch shield",
      tier = "utility",
      invoke = function() boop.ui.touchShield() end,
    },
  }

  local function configureScenario()
    helper.reset()
    helper.setArea("Test Area")
    helper.setClass("Occultist")
    helper.setTarget("42", "a test denizen", "80%")
    helper.setDenizens({
      { id = "42", name = "a test denizen" },
    })
    helper.learnSkill("Lycantha", "Domination")
    boop.config.enabled = true
    boop.config.attackMode = "simple"
    boop.config.targetingMode = "auto"
    boop.config.diagTimeoutSeconds = 8
    boop.config.traceEnabled = true

    sent = {}
    scheduled = {}
    killed = {}
    info_messages = {}
    ok_messages = {}
    warn_messages = {}
    tick_count = 0
    native_queue = helper.newNativeQueue()
  end

  local function blockerFor(owner)
    for _, blocker in ipairs(boop.runtime.blockersSnapshot()) do
      if blocker.owner == owner then
        return blocker
      end
    end
    return nil
  end

  local function seedUnrelatedOwner()
    helper.setRuntimeBlocker({
      owner = "pull:unrelated",
      code = "pull_active",
      label = "unrelated hold",
      systems = { combat = true, queue = true },
      waitsFor = { room = true },
    })
  end

  local function readRepoFile(path)
    local handle = io.open(helper.repoRoot() .. "/" .. path, "r")
    if not handle then
      return nil
    end
    local content = handle:read("*a")
    handle:close()
    return content
  end

  local function observeLatestLeapDispatch()
    assert.is_true(#sent >= 2)
    boop.onDataSendRequest(
      "sysDataSendRequest",
      sent[#sent - 1].command
    )
    boop.onDataSendRequest(
      "sysDataSendRequest",
      sent[#sent].command
    )
  end

  local function countTrace(fragment)
    local count = 0
    for _, entry in ipairs(boop.state.trace.buffer or {}) do
      if tostring(entry):find(fragment, 1, true) then
        count = count + 1
      end
    end
    return count
  end

  local function leapDenialHandler()
    assert.is_function(boop.runtime.onLeapCommandDenied)
    return boop.runtime.onLeapCommandDenied
  end

  local function assertActiveOperation(row, timer_id)
    local operation = boop.state.diag.operation
    assert.is_table(operation)
    assert.are.equal(1, boop.state.diag.generation)
    assert.are.equal(1, operation.generation)
    assert.are.equal(row.name, operation.name)
    assert.are.equal(row.tier, operation.tier)
    assert.are.equal("operator", operation.source)
    assert.are.equal(row.command, operation.command)
    assert.are.equal("prompt", operation.completionMode)
    assert.is_false(operation.resultSeen)
    assert.is_false(operation.terminal)
    assert.are.equal("interrupt:1", operation.blockerOwner)
    assert.are.equal(timer_id, operation.timeoutTimer)
    assert.is_number(operation.startedAt)
    assert.is_true(boop.state.diag.hold)
    assert.is_true(boop.state.diag.awaitPrompt)
    assert.are.equal(row.name, boop.state.diag.label)
    assert.are.equal(timer_id, boop.state.diag.timeoutTimer)

    local blocker = blockerFor("interrupt:1")
    assert.is_table(blocker)
    assert.are.equal("interrupt_pending", blocker.code)
    assert.is_true(blocker.systems.combat)
    assert.is_true(blocker.systems.queue)
  end

  before_each(function()
    configureScenario()

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
      sent[#sent + 1] = {
        command = command,
        echoBack = echo_back,
      }
      native_queue.send(command, echo_back)
    end)
    info_stub = stub(boop.util, "info", function(message)
      info_messages[#info_messages + 1] = message
    end)
    ok_stub = stub(boop.util, "ok", function(message)
      ok_messages[#ok_messages + 1] = message
    end)
    warn_stub = stub(boop.util, "warn", function(message)
      warn_messages[#warn_messages + 1] = message
    end)
    tick_stub = stub(boop, "tick", function()
      tick_count = tick_count + 1
    end)
  end)

  it("keeps interrupt admission independent from blocker display priority", function()
    local cases = {
      {
        active = false,
        incoming = { name = "diag", tier = "diagnostic" },
        decision = "start",
      },
      {
        active = { name = "matic", tier = "utility" },
        incoming = { name = "diag", tier = "diagnostic" },
        decision = "supersede",
      },
      {
        active = { name = "diag", tier = "diagnostic" },
        incoming = { name = "leap", tier = "emergency" },
        decision = "supersede",
      },
      {
        active = { name = "leap", tier = "emergency" },
        incoming = { name = "diag", tier = "diagnostic" },
        decision = "reject",
      },
      {
        active = { name = "leap", tier = "emergency" },
        incoming = {
          name = "leap",
          tier = "emergency",
          replaceSame = true,
        },
        decision = "supersede",
      },
      {
        active = { name = "leap", tier = "emergency" },
        incoming = { name = "fly", tier = "emergency" },
        decision = "reject",
      },
    }
    for _, row in ipairs(cases) do
      local result = boop.runtime.interruptAdmission(
        row.active,
        row.incoming
      )
      assert.are.equal(row.decision, result.decision)
    end
  end)

  after_each(function()
    if tick_stub then tick_stub:revert() tick_stub = nil end
    if warn_stub then warn_stub:revert() warn_stub = nil end
    if ok_stub then ok_stub:revert() ok_stub = nil end
    if info_stub then info_stub:revert() info_stub = nil end
    if send_stub then send_stub:revert() send_stub = nil end
    if timer_stub then timer_stub:revert() timer_stub = nil end
    if kill_timer_stub then kill_timer_stub:revert() kill_timer_stub = nil end
  end)

  it("rejects repeated utility interrupts without disturbing their generation", function()
    for _, row in ipairs(prompt_interrupts) do
      if row.tier == "utility" then
        configureScenario()
        seedUnrelatedOwner()

        row.invoke()
        assertActiveOperation(row, 1)
        local original_operation = boop.state.diag.operation
        row.invoke()

        assert.is_true(original_operation == boop.state.diag.operation)
        assert.are.equal(1, boop.state.diag.generation)
        assert.are.equal(1, #sent)
        assert.are.equal(1, #scheduled)
        assert.are.equal(2, #info_messages)
        assert.is_table(blockerFor("pull:unrelated"))
      end
    end
  end)

  it("lets diagnose supersede utility and rejects utility behind diagnose", function()
    boop.ui.matic()
    local utility = boop.state.diag.operation
    local utility_timeout = scheduled[1].callback

    assert.is_true(boop.ui.diag())
    local diagnostic = boop.state.diag.operation
    assert.are.equal(2, diagnostic.generation)
    assert.are.equal("diag", diagnostic.name)
    assert.are.equal("diagnostic", diagnostic.tier)
    assert.is_true(utility.terminal)
    assert.is_nil(blockerFor("interrupt:1"))
    assert.is_table(blockerFor("interrupt:2"))
    assert.are.same({ 1 }, killed)

    boop.ui.matic()
    assert.is_true(diagnostic == boop.state.diag.operation)
    assert.are.equal(3, #sent)
    assert.are.equal(2, #scheduled)

    utility_timeout()
    assert.is_true(diagnostic == boop.state.diag.operation)
  end)

  it("lets leap supersede diagnose while stale diagnose evidence stays inert", function()
    assert.is_true(boop.ui.diag())
    local diagnostic = boop.state.diag.operation
    local diagnostic_timeout = scheduled[1].callback

    boop.ui.leap("north")
    local leap = boop.state.diag.operation
    assert.are.equal(2, leap.generation)
    assert.are.equal("leap", leap.name)
    assert.are.equal("emergency", leap.tier)
    assert.is_true(diagnostic.terminal)
    assert.are.equal("superseded_by:leap", diagnostic.terminalReason)
    assert.is_nil(blockerFor("interrupt:1"))
    assert.is_table(blockerFor("interrupt:2"))
    assert.are.same({ 1 }, killed)
    assert.are.equal(1, #boop.state.diag.evidenceQueue)
    assert.is_true(boop.state.diag.evidenceQueue[1].terminal)
    assert.is_true(boop.state.diag.evidenceQueue[1].tombstone)
    assert.are.same({
      "clearqueue all",
      "queue addclearfull freestand diagnose",
      "clearqueue all",
      "queue addclearfull freestand leap north",
    }, {
      sent[1].command,
      sent[2].command,
      sent[3].command,
      sent[4].command,
    })

    diagnostic_timeout()
    boop.runtime.markOldestDiagEvidenceResult("late old result")
    boop.onPrompt()
    assert.is_true(leap == boop.state.diag.operation)
    assert.are.equal(0, #warn_messages)
  end)

  it("restarts an active leap instead of inheriting its timeout", function()
    boop.ui.leap("north")
    local first = boop.state.diag.operation
    local first_timeout = scheduled[1].callback

    boop.ui.leap("east")
    local second = boop.state.diag.operation
    assert.are.equal(2, second.generation)
    assert.are.equal("leap east", second.command)
    assert.are.equal("emergency", second.tier)
    assert.is_true(first.terminal)
    assert.are.equal("superseded_by:leap", first.terminalReason)
    assert.are.same({ 1 }, killed)
    assert.is_nil(blockerFor("interrupt:1"))
    assert.is_table(blockerFor("interrupt:2"))
    assert.are.equal(4, #sent)
    assert.are.equal(2, #scheduled)

    first_timeout()
    assert.is_true(second == boop.state.diag.operation)
    assert.are.equal(0, #warn_messages)
  end)

  it("rejects a different same-tier emergency and lower-priority work", function()
    boop.ui.leap("north")
    local leap = boop.state.diag.operation

    boop.ui.fly()
    assert.is_false(boop.ui.diag())
    boop.ui.matic()

    assert.is_true(leap == boop.state.diag.operation)
    assert.are.equal(2, #sent)
    assert.are.equal(1, #scheduled)
    assert.are.equal(4, #info_messages)
  end)

  it("lets prompt completion win once and makes the captured timeout a no-op", function()
    for _, row in ipairs(prompt_interrupts) do
      configureScenario()
      seedUnrelatedOwner()
      row.invoke()

      local generation = boop.state.diag.operation.generation
      local timeout_callback = scheduled[1].callback
      boop.onPrompt()

      assert.is_false(boop.state.diag.operation)
      assert.is_false(boop.state.diag.hold)
      assert.is_false(boop.state.diag.awaitPrompt)
      assert.are.equal("", boop.state.diag.label)
      assert.is_nil(boop.state.diag.timeoutTimer)
      assert.is_nil(blockerFor("interrupt:" .. generation))
      assert.is_table(blockerFor("pull:unrelated"))
      assert.are.equal(1, #ok_messages)
      assert.are.equal(0, #warn_messages)
      assert.are.equal(1, tick_count)

      local trace_count = #boop.state.trace.buffer
      local killed_count = #killed
      timeout_callback()

      assert.is_false(boop.runtime.completeInterrupt(generation, "timeout"))
      assert.are.equal(1, #ok_messages)
      assert.are.equal(0, #warn_messages)
      assert.are.equal(1, tick_count)
      assert.are.equal(trace_count, #boop.state.trace.buffer)
      assert.are.equal(killed_count, #killed)
      assert.are.equal(1, #sent)
      assert.is_table(blockerFor("pull:unrelated"))
    end
  end)

  it("completes only the active fly from its exact success line", function()
    boop.ui.fly()
    local operation = boop.state.diag.operation
    local timeout_callback = scheduled[1].callback

    assert.is_false(boop.runtime.onFlyCommandSucceeded("You begin to fly."))
    assert.is_false(
      boop.runtime.onFlyCommandSucceeded(FLY_SUCCESS, operation.generation + 1)
    )
    assert.is_true(operation == boop.state.diag.operation)

    assert.is_true(
      boop.runtime.onFlyCommandSucceeded(FLY_SUCCESS, operation.generation)
    )
    assert.is_false(boop.state.diag.operation)
    assert.is_false(boop.state.diag.hold)
    assert.are.equal("command_succeeded", operation.terminalReason)
    assert.are.same({ 1 }, killed)
    assert.are.equal(1, #ok_messages)
    assert.are.equal(0, #warn_messages)

    assert.is_false(boop.runtime.onFlyCommandSucceeded(FLY_SUCCESS))
    timeout_callback()
    boop.onPrompt()
    assert.are.equal(1, #ok_messages)
    assert.are.equal(0, #warn_messages)

    assert.are.equal(2, #scheduled)
    scheduled[2].callback()
    assert.are.equal(1, tick_count)
  end)

  it("lets timeout win once without removing server queue work or releasing another owner", function()
    for _, row in ipairs(prompt_interrupts) do
      configureScenario()
      seedUnrelatedOwner()
      row.invoke()

      local generation = boop.state.diag.operation.generation
      local timeout_callback = scheduled[1].callback
      timeout_callback()

      assert.is_false(boop.state.diag.operation)
      assert.is_false(boop.state.diag.hold)
      assert.is_false(boop.state.diag.awaitPrompt)
      assert.are.equal("", boop.state.diag.label)
      assert.is_nil(boop.state.diag.timeoutTimer)
      assert.is_nil(blockerFor("interrupt:" .. generation))
      assert.is_table(blockerFor("pull:unrelated"))
      assert.are.equal(0, #ok_messages)
      assert.are.same({ row.name .. " timeout; attacks resumed" }, warn_messages)
      assert.are.equal(0, tick_count)
      assert.are.equal(1, #sent)
      assert.are.equal("queue addclearfull freestand " .. row.command, sent[1].command)

      local trace_count = #boop.state.trace.buffer
      boop.onPrompt()

      assert.is_false(boop.runtime.completeInterrupt(generation, "prompt_complete"))
      assert.are.equal(0, #ok_messages)
      assert.are.equal(1, #warn_messages)
      assert.are.equal(1, tick_count)
      assert.are.equal(trace_count, #boop.state.trace.buffer)
      assert.are.equal(1, #sent)
      assert.is_table(blockerFor("pull:unrelated"))
    end
  end)

  it("keeps leap ahead of hunting until a room change confirms movement", function()
    native_queue.apply("queue addclearfull freestand BOOP_ATTACK")

    boop.ui.leap("northeast")

    assert.are.equal(2, #sent)
    assert.are.same({
      command = "clearqueue all",
      echoBack = false,
    }, sent[1])
    assert.are.same({
      command = "queue addclearfull freestand leap northeast",
      echoBack = false,
    }, sent[2])
    assert.are.same({
      freestand = { "leap northeast" },
    }, native_queue.snapshot())

    local operation = boop.state.diag.operation
    assert.is_table(operation)
    assert.are.equal("room_change", operation.completionMode)
    assert.are.equal("1", operation.originRoomId)
    assert.is_true(blockerFor("interrupt:1").waitsFor.room)

    local outbound = boop.runtime.outboundSnapshot()
    assert.are.equal(0, outbound.sequence)
    assert.are.equal(2, #outbound.expectations)
    assert.are.equal("interrupt:1", outbound.expectations[1].owner)
    assert.are.equal("clearqueue all", outbound.expectations[1].command)
    assert.are.equal(
      "queue addclearfull freestand leap northeast",
      outbound.expectations[2].command
    )

    boop.onPrompt()

    assert.is_true(operation == boop.state.diag.operation)
    assert.are.equal(0, tick_count)
    assert.are.same({
      freestand = { "leap northeast" },
    }, native_queue.snapshot())

    gmcp.Room.Info = {
      area = "Test Area",
      num = 2,
      exits = { southwest = 1 },
    }
    boop.onRoomInfo()

    assert.is_false(boop.state.diag.operation)
    assert.is_nil(blockerFor("interrupt:1"))
    assert.are.same({ "leap complete; attacks resumed" }, ok_messages)
    assert.are.same({
      freestand = { "leap northeast" },
    }, native_queue.snapshot())
  end)

  it("releases an unconfirmed leap only through its timeout", function()
    boop.ui.leap("north")
    local timeout_callback = scheduled[1].callback

    boop.onPrompt()
    assert.is_table(boop.state.diag.operation)

    timeout_callback()

    assert.is_false(boop.state.diag.operation)
    assert.are.same({ "leap timeout; attacks resumed" }, warn_messages)
    assert.are.equal(0, tick_count)
  end)

  it("terminalizes one causally owned leap denial and makes later evidence inert", function()
    local denyLeap = leapDenialHandler()
    seedUnrelatedOwner()
    boop.ui.leap("north")

    local operation = boop.state.diag.operation
    local generation = operation.generation
    local timeout_callback = scheduled[1].callback
    assert.is_table(operation.causal)
    assert.are.equal("interrupt:1", operation.causal.owner)
    assert.are.equal(generation, operation.causal.generation)
    assert.are.equal("leap north", operation.causal.command)
    assert.are.equal("1", operation.causal.roomId)
    assert.are.equal(
      boop.state.targeting.roomObservation.generation,
      operation.causal.roomGeneration
    )
    assert.are.equal(1, operation.causal.timeoutToken)
    assert.is_false(operation.causal.windowOpen)

    observeLatestLeapDispatch()

    assert.is_true(operation.causal.windowOpen)
    assert.are.equal(2, operation.causal.baseline.sequence)
    assert.are.equal(
      "queue addclearfull freestand leap north",
      operation.causal.baseline.command
    )
    assert.is_true(denyLeap(LEAP_DENIAL))

    assert.is_false(boop.state.diag.operation)
    assert.is_true(operation.terminal)
    assert.is_true(operation.causal.terminal)
    assert.is_false(operation.causal.windowOpen)
    assert.are.equal("command_failed", operation.causal.terminalReason)
    assert.is_nil(blockerFor("interrupt:" .. generation))
    assert.is_table(blockerFor("pull:unrelated"))
    assert.are.same({ 1 }, killed)
    assert.are.same({ "leap command failed; attacks resumed" }, warn_messages)
    assert.are.equal(2, #scheduled)
    assert.are.equal(0, scheduled[2].delay)
    assert.are.equal(1, countTrace("interrupt terminal:"))

    scheduled[2].callback()
    assert.are.equal(1, tick_count)

    assert.is_false(denyLeap(LEAP_DENIAL))
    timeout_callback()
    gmcp.Room.Info = {
      area = "Test Area",
      num = 2,
      exits = { south = 1 },
    }
    boop.onRoomInfo()

    assert.are.equal(1, countTrace("interrupt terminal:"))
    assert.are.equal(1, #warn_messages)
    assert.are.equal(1, #killed)
    assert.are.equal(1, tick_count)
    assert.is_table(blockerFor("pull:unrelated"))
  end)

  it("keeps an outbound-contaminated denial diagnostic until bounded timeout", function()
    local denyLeap = leapDenialHandler()
    boop.ui.leap("north")
    local operation = boop.state.diag.operation
    local timeout_callback = scheduled[1].callback
    observeLatestLeapDispatch()
    boop.onDataSendRequest("sysDataSendRequest", "look")

    assert.is_false(denyLeap(LEAP_DENIAL))
    assert.is_false(denyLeap(LEAP_DENIAL))
    assert.is_true(operation == boop.state.diag.operation)
    assert.is_nil(operation.causal.terminalReason)
    assert.are.equal(3, operation.causal.contaminatedAt)
    assert.are.equal("look", operation.causal.contaminatedCommand)
    assert.are.equal(1, countTrace("leap denial ambiguous:"))
    assert.are.equal(0, #killed)
    assert.are.equal(1, #scheduled)

    timeout_callback()

    assert.is_false(boop.state.diag.operation)
    assert.are.same({ "leap timeout; attacks resumed" }, warn_messages)
    assert.are.equal(1, countTrace("interrupt terminal:"))
    assert.are.equal(0, tick_count)
  end)

  it("keeps a denial arriving after timeout diagnostic-only", function()
    local denyLeap = leapDenialHandler()
    boop.ui.leap("north")
    observeLatestLeapDispatch()

    scheduled[1].callback()
    assert.is_false(boop.state.diag.operation)
    assert.are.equal(1, countTrace("interrupt terminal:"))
    assert.are.same({ "leap timeout; attacks resumed" }, warn_messages)

    assert.is_false(denyLeap(LEAP_DENIAL))
    assert.is_false(boop.state.diag.operation)
    assert.are.equal(1, countTrace("interrupt terminal:"))
    assert.are.equal(1, #warn_messages)
    assert.are.equal(1, #scheduled)
    assert.are.equal(0, tick_count)
  end)

  it("ignores denial without an open current leap window", function()
    local denyLeap = leapDenialHandler()
    assert.is_false(denyLeap(LEAP_DENIAL))

    boop.ui.matic()
    local matic = boop.state.diag.operation
    assert.is_false(denyLeap(LEAP_DENIAL))
    assert.is_true(matic == boop.state.diag.operation)
    scheduled[1].callback()

    configureScenario()
    boop.ui.leap("north")
    local leap = boop.state.diag.operation
    assert.is_false(denyLeap(LEAP_DENIAL))
    assert.is_true(leap == boop.state.diag.operation)
    assert.is_false(leap.causal.windowOpen)
    assert.are.equal(0, #killed)
  end)

  it("permits an immediate next diag while stale generation callbacks stay inert", function()
    local denyLeap = leapDenialHandler()
    boop.ui.leap("north")
    local old_generation = boop.state.diag.operation.generation
    local old_timeout = scheduled[1].callback
    observeLatestLeapDispatch()
    assert.is_true(denyLeap(LEAP_DENIAL))

    assert.is_true(boop.ui.diag())
    local current = boop.state.diag.operation
    assert.are.equal(old_generation + 1, current.generation)
    assert.are.equal("diag", current.name)

    assert.is_false(
      denyLeap(LEAP_DENIAL, old_generation)
    )
    old_timeout()
    assert.is_false(
      boop.runtime.completeInterrupt(old_generation, "room_changed")
    )
    assert.is_true(current == boop.state.diag.operation)
    assert.are.equal(1, countTrace("interrupt terminal:"))
    assert.are.equal(1, #warn_messages)
  end)

  it("keeps a newer leap safe from denial and callbacks captured by the prior generation", function()
    local denyLeap = leapDenialHandler()
    boop.ui.leap("north")
    local old_generation = boop.state.diag.operation.generation
    local old_timeout = scheduled[1].callback
    observeLatestLeapDispatch()
    assert.is_true(denyLeap(LEAP_DENIAL))

    boop.ui.leap("east")
    local current = boop.state.diag.operation
    observeLatestLeapDispatch()

    assert.is_false(
      denyLeap(LEAP_DENIAL, old_generation)
    )
    old_timeout()
    assert.is_false(
      boop.runtime.completeInterrupt(old_generation, "room_changed")
    )
    assert.is_true(current == boop.state.diag.operation)
    assert.is_true(current.causal.windowOpen)
    assert.are.equal(1, countTrace("interrupt terminal:"))

    assert.is_true(
      denyLeap(LEAP_DENIAL, current.generation)
    )
    assert.is_false(boop.state.diag.operation)
    assert.are.equal(2, countTrace("interrupt terminal:"))
  end)

  it("pairs the exact leap denial manifest stem with a thin runtime adapter", function()
    local manifest = readRepoFile("src/triggers/boop/Diag/triggers.json")
    local adapter = readRepoFile(
      "src/triggers/boop/Diag/Leap_Command_Denied.lua"
    )

    assert.is_string(manifest)
    assert.is_truthy(manifest:find('"name": "Leap Command Denied"', 1, true))
    assert.is_truthy(manifest:find(LEAP_DENIAL, 1, true))
    assert.is_string(adapter)
    assert.is_truthy(
      adapter:find("boop.runtime.onLeapCommandDenied", 1, true)
    )
    assert.is_falsy(adapter:find("completeInterrupt", 1, true))
    assert.is_falsy(adapter:find("clearqueue", 1, true))
  end)

  it("pairs the exact fly success manifest stem with a thin runtime adapter", function()
    local manifest = readRepoFile("src/triggers/boop/Diag/triggers.json")
    local adapter = readRepoFile(
      "src/triggers/boop/Diag/Fly_Command_Succeeded.lua"
    )

    assert.is_string(manifest)
    assert.is_truthy(manifest:find('"name": "Fly Command Succeeded"', 1, true))
    assert.is_truthy(manifest:find(FLY_SUCCESS, 1, true))
    assert.is_string(adapter)
    assert.is_truthy(
      adapter:find("boop.runtime.onFlyCommandSucceeded", 1, true)
    )
    assert.is_falsy(adapter:find("completeInterrupt", 1, true))
    assert.is_falsy(adapter:find("clearqueue", 1, true))
  end)
end)
