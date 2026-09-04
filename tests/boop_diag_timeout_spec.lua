local helper = dofile(os.getenv("TESTS_DIRECTORY") .. "/support/boop_test_helper.lua")

describe("boop diagnose timeout", function()
  local send_stub
  local timer_stub
  local kill_timer_stub
  local info_stub
  local ok_stub
  local warn_stub
  local tick_stub
  local sent
  local scheduled
  local info_messages
  local ok_messages
  local warn_messages
  local tick_count
  local native_queue

  local function runDetailTrigger()
    dofile(os.getenv("TESTS_DIRECTORY") .. "/../src/triggers/boop/Diag/Diag_Result_Detail.lua")
  end

  local function runVenomConfusionTrigger()
    return dofile(
      os.getenv("TESTS_DIRECTORY")
        .. "/../src/triggers/boop/Diag/Venom_Confusion.lua"
    )
  end

  local function blockerFor(owner)
    for _, blocker in ipairs(boop.locks.blockersSnapshot()) do
      if blocker.owner == owner then
        return blocker
      end
    end
    return nil
  end

  before_each(function()
    helper.reset()
    boop.config.diagTimeoutSeconds = 8
    boop.config.traceEnabled = true
    sent = {}
    scheduled = {}
    info_messages = {}
    ok_messages = {}
    warn_messages = {}
    tick_count = 0
    native_queue = helper.newNativeQueue()

    send_stub = stub(_G, "send", function(command, echo_back)
      sent[#sent + 1] = {
        command = command,
        echoBack = echo_back,
      }
      native_queue.send(command, echo_back)
    end)
    timer_stub = stub(_G, "tempTimer", function(delay, callback)
      local timer_id = #scheduled + 1
      scheduled[timer_id] = {
        delay = delay,
        callback = callback,
      }
      return timer_id
    end)
    kill_timer_stub = stub(_G, "killTimer", function(_) end)
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

  after_each(function()
    if tick_stub then tick_stub:revert() tick_stub = nil end
    if warn_stub then warn_stub:revert() warn_stub = nil end
    if ok_stub then ok_stub:revert() ok_stub = nil end
    if info_stub then info_stub:revert() info_stub = nil end
    if send_stub then send_stub:revert() send_stub = nil end
    if timer_stub then timer_stub:revert() timer_stub = nil end
    if kill_timer_stub then kill_timer_stub:revert() kill_timer_stub = nil end
  end)

  it("retains a terminal tombstone and releases only the timed-out owner", function()
    helper.setRuntimeBlocker({
      owner = "pull:unrelated",
      code = "pull_active",
      label = "unrelated hold",
      systems = { combat = true, queue = true },
      waitsFor = { room = true },
    })

    native_queue.apply("queue add full get sovereigns")
    native_queue.apply("queue add eqbal jab 42")
    boop.ui.diag()
    local generation = boop.state.diag.operation.generation
    scheduled[1].callback()

    assert.is_false(boop.state.diag.operation)
    assert.is_false(boop.state.diag.hold)
    assert.is_false(boop.state.diag.awaitPrompt)
    assert.is_nil(boop.state.diag.timeoutTimer)
    assert.is_nil(blockerFor("interrupt:" .. generation))
    assert.is_table(blockerFor("pull:unrelated"))
    assert.are.same({
      {
        generation = generation,
        resultSeen = false,
        terminal = true,
        tombstone = true,
      },
    }, boop.state.diag.evidenceQueue)
    assert.are.same({ "diag timeout; attacks resumed" }, warn_messages)
    assert.are.equal(0, #ok_messages)
    assert.are.equal(1, tick_count)
    assert.are.equal(2, #sent)
    assert.are.equal("clearqueue all", sent[1].command)
    assert.are.equal("queue addclearfull freestand diagnose", sent[2].command)
    assert.are.same({
      freestand = { "diagnose" },
    }, native_queue.snapshot())
    assert.are.same({}, native_queue.errorsSnapshot())
  end)

  it("keeps the venom-confusion threshold armed after diagnose timeout", function()
    runVenomConfusionTrigger()
    runVenomConfusionTrigger()
    assert.are.equal(2, boop.state.diag.venomConfusionCount)

    scheduled[1].callback()

    assert.is_false(boop.state.diag.operation)
    assert.are.equal(2, boop.state.diag.venomConfusionCount)
    runVenomConfusionTrigger()
    assert.are.equal("diag", boop.state.diag.operation.name)
    assert.are.equal(2, boop.state.diag.venomConfusionCount)
    assert.are.equal("clearqueue all", sent[3].command)
    assert.are.equal(
      "queue addclearfull freestand diagnose",
      sent[4].command
    )
  end)

  it("does not let N's missing result consume diagnose N+1 forever", function()
    helper.setRuntimeBlocker({
      owner = "pull:unrelated",
      code = "pull_active",
      label = "unrelated hold",
      systems = { combat = true, queue = true },
      waitsFor = { room = true },
    })

    boop.config.enabled = true
    boop.ui.diag()
    local first_generation = boop.state.diag.operation.generation
    scheduled[1].callback()

    boop.ui.diag()
    local operation = boop.state.diag.operation
    local second_generation = operation.generation

    assert.are.equal(first_generation + 1, second_generation)
    assert.are.equal(1, #boop.state.diag.evidenceQueue)
    assert.are.equal(second_generation, boop.state.diag.evidenceQueue[1].generation)
    assert.is_false(boop.state.diag.evidenceQueue[1].resultSeen)

    gmcp.Char.Afflictions = {
      List = {
        { name = "weariness" },
      },
    }
    assert.is_true(boop.onDiagAfflictionsList())

    assert.is_true(boop.state.diag.evidenceQueue[1].resultSeen)
    assert.is_true(boop.state.diag.operation.resultSeen)

    boop.onPrompt()

    assert.is_false(boop.state.diag.operation)
    assert.are.same({}, boop.state.diag.evidenceQueue)
    assert.is_nil(blockerFor("interrupt:" .. second_generation))
    assert.is_table(blockerFor("pull:unrelated"))
    assert.are.equal(2, tick_count)
    assert.are.same({ "diag timeout; attacks resumed" }, warn_messages)
    assert.are.same({ "diag complete; attacks resumed" }, ok_messages)
  end)

  it("drains a timed-out head once and makes every later terminal call a no-op", function()
    boop.config.enabled = true
    boop.ui.diag()
    local generation = boop.state.diag.operation.generation
    scheduled[1].callback()

    local warning_count = #warn_messages
    local trace_count = #boop.state.trace.buffer
    local send_count = #sent

    runDetailTrigger()
    boop.onPrompt()

    assert.are.same({}, boop.state.diag.evidenceQueue)
    assert.is_false(boop.state.diag.operation)
    assert.are.equal(1, tick_count)
    assert.are.equal(warning_count, #warn_messages)
    assert.are.equal(0, #ok_messages)
    assert.are.equal(trace_count + 2, #boop.state.trace.buffer)
    assert.are.equal(send_count, #sent)

    local drained_trace_count = #boop.state.trace.buffer
    assert.is_false(boop.runtime.completeInterrupt(generation, "diagnose_result_prompt"))
    assert.is_false(boop.runtime.markOldestDiagEvidenceResult())
    assert.is_false(boop.runtime.consumeOldestDiagEvidencePrompt())
    assert.are.equal(warning_count, #warn_messages)
    assert.are.equal(drained_trace_count, #boop.state.trace.buffer)
    assert.are.equal(send_count, #sent)
    assert.are.equal(1, tick_count)
  end)
end)
