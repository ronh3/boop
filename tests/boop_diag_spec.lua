local helper = dofile(os.getenv("TESTS_DIRECTORY") .. "/support/boop_test_helper.lua")

describe("boop diagnose pause and resume", function()
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

  local function triggerPath(name)
    return os.getenv("TESTS_DIRECTORY") .. "/../src/triggers/boop/Diag/" .. name
  end

  local function runTrigger(name)
    dofile(triggerPath(name))
  end

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
    info_messages = {}
    ok_messages = {}
    warn_messages = {}
    tick_count = 0
  end

  local function blockerFor(owner)
    for _, blocker in ipairs(boop.runtime.blockersSnapshot()) do
      if blocker.owner == owner then
        return blocker
      end
    end
    return nil
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
    kill_timer_stub = stub(_G, "killTimer", function(_) end)
    send_stub = stub(_G, "send", function(command, echo_back)
      sent[#sent + 1] = {
        command = command,
        echoBack = echo_back,
      }
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

  after_each(function()
    if tick_stub then tick_stub:revert() tick_stub = nil end
    if warn_stub then warn_stub:revert() warn_stub = nil end
    if ok_stub then ok_stub:revert() ok_stub = nil end
    if info_stub then info_stub:revert() info_stub = nil end
    if send_stub then send_stub:revert() send_stub = nil end
    if timer_stub then timer_stub:revert() timer_stub = nil end
    if kill_timer_stub then kill_timer_stub:revert() kill_timer_stub = nil end
  end)

  it("materializes independent generation, operation, and evidence defaults on reset", function()
    local first = boop.runtime.state()
    assert.are.equal(0, first.diag.generation)
    assert.is_false(first.diag.operation)
    assert.are.same({}, first.diag.evidenceQueue)

    local first_queue = first.diag.evidenceQueue
    first.diag.generation = 9
    first.diag.operation = {
      generation = 9,
      name = "mutated",
    }
    first.diag.evidenceQueue[1] = {
      generation = 9,
      resultSeen = true,
      terminal = true,
      tombstone = true,
    }

    helper.reset()

    local fresh = boop.runtime.state()
    assert.are.equal(0, fresh.diag.generation)
    assert.is_false(fresh.diag.operation)
    assert.are.same({}, fresh.diag.evidenceQueue)
    assert.is_false(first_queue == fresh.diag.evidenceQueue)
  end)

  it("requires a real zero-argument result trigger before diagnose can complete on prompt", function()
    helper.setRuntimeBlocker({
      owner = "test:unrelated",
      code = "pull_active",
      label = "unrelated hold",
      systems = { combat = true, queue = true },
      waitsFor = { room = true },
    })

    boop.ui.diag()

    local operation = boop.state.diag.operation
    assert.is_table(operation)
    assert.are.equal(1, operation.generation)
    assert.are.equal("diag", operation.name)
    assert.are.equal("diagnose", operation.command)
    assert.are.equal("result_then_prompt", operation.completionMode)
    assert.is_false(operation.resultSeen)
    assert.is_false(operation.terminal)
    assert.are.equal("interrupt:1", operation.blockerOwner)
    assert.are.equal(1, operation.timeoutTimer)
    assert.is_number(operation.startedAt)
    assert.are.same({
      {
        generation = 1,
        resultSeen = false,
        terminal = false,
        tombstone = false,
      },
    }, boop.state.diag.evidenceQueue)
    assert.are.equal("queue clear", sent[1].command)
    assert.are.equal(false, sent[1].echoBack)
    assert.are.equal("queue addclearfull freestand diagnose", sent[2].command)
    assert.are.equal(false, sent[2].echoBack)

    boop.onPrompt()

    assert.is_table(boop.state.diag.operation)
    assert.is_false(boop.state.diag.operation.resultSeen)
    assert.is_false(boop.state.diag.awaitPrompt)
    assert.are.equal(0, tick_count)
    assert.are.equal(0, #ok_messages)

    runTrigger("Diag_Result_Perfect.lua")

    assert.is_true(boop.state.diag.operation.resultSeen)
    assert.is_true(boop.state.diag.evidenceQueue[1].resultSeen)
    assert.is_true(boop.state.diag.awaitPrompt)

    boop.onPrompt()

    assert.is_false(boop.state.diag.operation)
    assert.are.same({}, boop.state.diag.evidenceQueue)
    assert.is_nil(blockerFor("interrupt:1"))
    assert.is_table(blockerFor("test:unrelated"))
    assert.are.equal(1, tick_count)
    assert.are.same({ "diag complete; attacks resumed" }, ok_messages)
    assert.are.equal(0, #warn_messages)

    local trace_count = #boop.state.trace.buffer
    scheduled[1].callback()
    assert.are.equal(trace_count, #boop.state.trace.buffer)
    assert.are.equal(1, #ok_messages)
    assert.are.equal(0, #warn_messages)
    assert.are.equal(1, tick_count)
  end)

  it("never scans past an unresolved or already-result-seen FIFO head", function()
    boop.ui.diag()
    scheduled[1].callback()
    boop.ui.diag()

    assert.are.equal(2, #boop.state.diag.evidenceQueue)
    assert.is_false(boop.state.diag.evidenceQueue[1].resultSeen)
    assert.is_false(boop.state.diag.evidenceQueue[2].resultSeen)

    boop.onPrompt()

    assert.are.equal(2, #boop.state.diag.evidenceQueue)
    assert.are.equal(2, boop.state.diag.operation.generation)
    assert.is_false(boop.state.diag.operation.resultSeen)
    assert.are.equal(0, tick_count)

    runTrigger("Diag_Result_Detail.lua")
    runTrigger("Diag_Result_Perfect.lua")

    assert.is_true(boop.state.diag.evidenceQueue[1].resultSeen)
    assert.is_false(boop.state.diag.evidenceQueue[2].resultSeen)
    assert.is_false(boop.state.diag.operation.resultSeen)

    boop.onPrompt()

    assert.are.equal(1, #boop.state.diag.evidenceQueue)
    assert.are.equal(2, boop.state.diag.evidenceQueue[1].generation)
    assert.is_false(boop.state.diag.evidenceQueue[1].resultSeen)
    assert.are.equal(2, boop.state.diag.operation.generation)
    assert.is_false(boop.state.diag.operation.resultSeen)
    assert.are.equal(0, tick_count)

    runTrigger("Diag_Result_Perfect.lua")
    boop.onPrompt()

    assert.is_false(boop.state.diag.operation)
    assert.are.same({}, boop.state.diag.evidenceQueue)
    assert.are.equal(1, tick_count)
  end)
end)
