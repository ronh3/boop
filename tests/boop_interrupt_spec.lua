local helper = dofile(os.getenv("TESTS_DIRECTORY") .. "/support/boop_test_helper.lua")

describe("boop queued interrupts", function()
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

  local prompt_interrupts = {
    {
      name = "matic",
      command = "ldeck draw matic",
      invoke = function() boop.ui.matic() end,
    },
    {
      name = "catarin",
      command = "ldeck draw catarin",
      invoke = function() boop.ui.catarin() end,
    },
    {
      name = "fly",
      command = "fly",
      invoke = function() boop.ui.fly() end,
    },
    {
      name = "ts",
      command = "touch shield",
      invoke = function() boop.ui.touchShield() end,
    },
    {
      name = "leap",
      command = "leap north",
      invoke = function() boop.ui.leap("north") end,
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
      owner = "test:unrelated",
      code = "pull_active",
      label = "unrelated hold",
      systems = { combat = true, queue = true },
      waitsFor = { room = true },
    })
  end

  local function assertActiveOperation(row, timer_id)
    local operation = boop.state.diag.operation
    assert.is_table(operation)
    assert.are.equal(1, boop.state.diag.generation)
    assert.are.equal(1, operation.generation)
    assert.are.equal(row.name, operation.name)
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

  it("keeps one generation, send, owner, and timer for same and different repeats", function()
    for _, row in ipairs(prompt_interrupts) do
      configureScenario()
      seedUnrelatedOwner()

      row.invoke()
      assertActiveOperation(row, 1)
      assert.are.equal(1, #sent)
      assert.are.same({
        command = "queue addclearfull freestand " .. row.command,
        echoBack = false,
      }, sent[1])
      assert.are.equal(1, #scheduled)

      local original_operation = boop.state.diag.operation
      local original_timer = boop.state.diag.timeoutTimer
      local original_info_count = #info_messages
      row.invoke()
      boop.ui.diag()

      assert.are.equal(1, boop.state.diag.generation)
      assert.is_true(original_operation == boop.state.diag.operation)
      assert.are.equal(original_timer, boop.state.diag.timeoutTimer)
      assert.are.equal(1, #sent)
      assert.are.equal(1, #scheduled)
      assert.are.equal(original_info_count + 2, #info_messages)
      assert.is_true(info_messages[#info_messages]:find(row.name, 1, true) ~= nil)
      assert.is_table(blockerFor("test:unrelated"))
      assertActiveOperation(row, 1)
    end
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
      assert.is_table(blockerFor("test:unrelated"))
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
      assert.is_table(blockerFor("test:unrelated"))
    end
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
      assert.is_table(blockerFor("test:unrelated"))
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
      assert.is_table(blockerFor("test:unrelated"))
    end
  end)
end)
