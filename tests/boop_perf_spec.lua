local helper = dofile(os.getenv("TESTS_DIRECTORY") .. "/support/boop_test_helper.lua")

describe("boop performance instrumentation", function()
  local originalEpoch
  local originalClock
  local originalCecho

  before_each(function()
    helper.reset()
    originalEpoch = _G.getEpoch
    originalClock = os.clock
    originalCecho = _G.cecho
  end)

  after_each(function()
    boop.perf.setEnabled(false)
    boop.perf.reset()
    _G.getEpoch = originalEpoch
    os.clock = originalClock
    _G.cecho = originalCecho
  end)

  local function advancingWallClock(start)
    local now = tonumber(start) or 1
    _G.getEpoch = function()
      local sampled = now
      now = now + 0.001
      return sampled
    end
    return function(amount)
      now = now + (tonumber(amount) or 0)
    end
  end

  local function runNormalPromptEpoch()
    boop.config.enabled = true
    boop.onVitals()
    boop.onPrompt()
    return boop.perf.snapshot()
  end

  it("keeps real probe functions direct and invokes no clock while disabled", function()
    boop.perf.setEnabled(false)
    local directContext = boop.runtime.context
    local epochCalls = 0
    local clockCalls = 0
    _G.getEpoch = function()
      epochCalls = epochCalls + 1
      error("disabled perf called getEpoch")
    end
    os.clock = function()
      clockCalls = clockCalls + 1
      error("disabled perf called os.clock")
    end

    assert.has_no.errors(function() boop.runtime.context() end)
    assert.are.equal(directContext, boop.runtime.context)
    assert.are.equal(0, epochCalls)
    assert.are.equal(0, clockCalls)

    boop.perf.setEnabled(true)
    assert.are_not.equal(directContext, boop.runtime.context)
    boop.perf.setEnabled(false)
    assert.are.equal(directContext, boop.runtime.context)
  end)

  it("uses opaque span tokens and cannot pop a valid span after overflow", function()
    local now = 1
    os.clock = function() return now end
    boop.perf.setEnabled(true)
    local tokens = {}
    for index = 1, 8 do
      tokens[index] = boop.perf.enter("context")
      assert.is_number(tokens[index])
    end
    local rejected = boop.perf.enter("context")
    assert.is_false(rejected)
    assert.is_false(boop.perf.exit(rejected))
    assert.is_false(boop.perf.exit(tokens[1]))
    for index = 8, 1, -1 do
      now = now + 0.001
      assert.is_number(boop.perf.exit(tokens[index]))
    end
    local snapshot = boop.perf.snapshot()
    assert.are.equal(8, snapshot.records.context.count)
    assert.are.equal(0, snapshot.records.context.activeDepth)
    assert.are.equal(1, snapshot.droppedSpans)
  end)

  it("unwinds a real probe after an exception and rethrows the original error", function()
    local failure = { marker = "original" }
    local oldEnsureState = boop.runtime.ensureState
    os.clock = function() return 5 end
    boop.perf.setEnabled(true)
    boop.runtime.ensureState = function() error(failure, 0) end

    local ok, err = pcall(boop.runtime.context)
    boop.runtime.ensureState = oldEnsureState
    assert.is_false(ok)
    assert.are.equal(failure, err)
    local record = boop.perf.snapshot().records.context
    assert.are.equal(1, record.count)
    assert.are.equal(0, record.activeDepth)
  end)

  it("preserves nil and multiple return values", function()
    boop.perf.setEnabled(true)
    local count = 0
    local function returns()
      count = count + 1
      return "a", nil, "c", nil
    end
    local a, b, c, d = boop.perf.measure("context", nil, returns)
    assert.are.equal("a", a)
    assert.is_nil(b)
    assert.are.equal("c", c)
    assert.is_nil(d)
    assert.are.equal(1, count)
  end)

  it("keeps timing and counter storage bounded to reviewed names", function()
    boop.perf.setEnabled(true)
    local before = 0
    for _ in pairs(boop.perf._records) do before = before + 1 end
    for index = 1, 100 do
      assert.is_false(boop.perf.enter("dynamic." .. tostring(index)))
      assert.is_false(boop.perf.count("dynamic." .. tostring(index)))
    end
    local after = 0
    for _ in pairs(boop.perf._records) do after = after + 1 end
    assert.are.equal(before, after)
    assert.is_nil(boop.perf._records["dynamic.1"])
  end)

  it("correlates real Vitals then Prompt callbacks without idle or nested sums", function()
    local advance = advancingWallClock(10)
    boop.perf.setEnabled(true)
    boop.config.enabled = true

    boop.onVitals()
    advance(50)
    boop.onPrompt()

    local snapshot = boop.perf.snapshot()
    assert.are.equal("leading", snapshot.correlationMode)
    assert.are.equal(1, snapshot.promptSeq)
    assert.are.equal(1, snapshot.completedPromptEpochs)
    assert.is_true(math.abs(
      snapshot.records.prompt_total.totalSeconds
        - snapshot.records["gmcp.Char.Vitals"].totalSeconds
        - snapshot.records["prompt.callback"].totalSeconds
    ) < 0.000001)
    assert.are.equal(snapshot.correlatedTicks, snapshot.ticksPerPrompt)
    assert.are.equal(
      snapshot.correlatedTicks,
      snapshot.records.tick.sources.vitals
        + snapshot.records.tick.sources.prompt
    )
    assert.is_true(snapshot.records.prompt_total.totalSeconds < 50)
  end)

  it("handles reversed Prompt then Vitals order deterministically", function()
    local advance = advancingWallClock(20)
    boop.perf.setEnabled(true)
    boop.config.enabled = true

    boop.onPrompt()
    local firstPrompt = boop.perf.snapshot().records["prompt.callback"].lastSeconds
    advance(25)
    boop.onVitals()
    local vitals = boop.perf.snapshot().records["gmcp.Char.Vitals"].lastSeconds
    local pending = boop.perf.snapshot()
    assert.are.equal("trailing", pending.correlationMode)
    assert.are.equal(0, pending.completedPromptEpochs)
    assert.is_true(pending.pendingPromptEpoch)

    advance(25)
    boop.onPrompt()
    local snapshot = boop.perf.snapshot()
    assert.are.equal(1, snapshot.completedPromptEpochs)
    assert.is_true(math.abs(
      snapshot.records.prompt_total.totalSeconds - firstPrompt - vitals
    ) < 0.000001)
    assert.is_true(snapshot.pendingPromptEpoch)
  end)

  it("discards incomplete correlation epochs on disable and reset", function()
    advancingWallClock(25)
    boop.perf.setEnabled(true)
    boop.config.enabled = true

    boop.onPrompt()
    assert.is_true(boop.perf.snapshot().pendingPromptEpoch)
    boop.perf.setEnabled(false)
    boop.perf.setEnabled(true)
    local disabled = boop.perf.snapshot()
    assert.is_false(disabled.pendingPromptEpoch)
    assert.is_false(disabled.correlationMode)
    assert.are.equal(0, disabled.completedPromptEpochs)

    boop.onPrompt()
    assert.is_true(boop.perf.snapshot().pendingPromptEpoch)
    boop.perf.reset()
    local reset = boop.perf.snapshot()
    assert.is_false(reset.pendingPromptEpoch)
    assert.is_false(reset.correlationMode)
  end)

  it("handles missing and multiple Vitals segments", function()
    advancingWallClock(30)
    boop.perf.setEnabled(true)
    boop.config.enabled = true

    boop.onVitals()
    boop.onVitals()
    boop.onPrompt()
    local first = boop.perf.snapshot()
    assert.are.equal(1, first.completedPromptEpochs)
    assert.are.equal(2, first.records["gmcp.Char.Vitals"].count)
    assert.is_true(math.abs(
      first.records.prompt_total.totalSeconds
        - first.records["gmcp.Char.Vitals"].totalSeconds
        - first.records["prompt.callback"].totalSeconds
    ) < 0.000001)

    local priorTotal = first.records.prompt_total.totalSeconds
    local priorPromptTotal = first.records["prompt.callback"].totalSeconds
    boop.onPrompt()
    local second = boop.perf.snapshot()
    assert.are.equal(2, second.completedPromptEpochs)
    assert.is_true(math.abs(
      (second.records.prompt_total.totalSeconds - priorTotal)
        - (second.records["prompt.callback"].totalSeconds - priorPromptTotal)
    ) < 0.000001)
  end)

  it("excludes unrelated and timer-deferred ticks from ticks_per_prompt", function()
    advancingWallClock(40)
    boop.perf.setEnabled(true)
    local baseline = runNormalPromptEpoch()
    local correlated = baseline.correlatedTicks
    local ratio = baseline.ticksPerPrompt
    local tickCount = baseline.records.tick.count

    boop.tick(nil, nil, "room")
    boop.tick(nil, nil, "target")
    boop.tick(nil, nil, "other")

    local snapshot = boop.perf.snapshot()
    assert.are.equal(tickCount + 3, snapshot.records.tick.count)
    assert.are.equal(correlated, snapshot.correlatedTicks)
    assert.are.equal(ratio, snapshot.ticksPerPrompt)
  end)

  it("resets every timing counter and correlation value", function()
    advancingWallClock(50)
    boop.perf.setEnabled(true)
    runNormalPromptEpoch()
    boop.perf.count("contexts_built", 3)
    boop.perf.reset()
    local snapshot = boop.perf.snapshot()
    assert.is_true(snapshot.on)
    assert.are.equal(0, snapshot.promptSeq)
    assert.are.equal(0, snapshot.completedPromptEpochs)
    assert.are.equal(0, snapshot.correlatedTicks)
    assert.are.equal(0, snapshot.records.prompt_total.count)
    assert.are.equal(0, snapshot.counters.contexts_built)
  end)

  it("counts full diagnostic copies but not lightweight readiness snapshots", function()
    boop.perf.setEnabled(true)
    boop.state.targeting.roomObservation.acceptedItems = { {}, {} }
    boop.state.targeting.roomObservation.fenceQueue = {
      {
        invItems = { {}, {} },
        roomItems = { {}, {}, {} },
        roomDeltas = { {} },
      },
    }
    boop.state.targeting.roomObservation.lastCompletedFence = {
      invItems = { {} },
      roomItems = { {}, {} },
      roomDeltas = { {}, {} },
    }
    boop.state.targeting.roomObservation.activeApplication = {
      items = { {}, {}, {}, {} },
    }

    boop.room.roomObservationSnapshot()
    assert.are.equal(17, boop.perf.snapshot().counters.deepcopy_items)

    boop.runtime.readinessSnapshot()
    assert.are.equal(17, boop.perf.snapshot().counters.deepcopy_items)
  end)

  it("increments context and limiter counters at their real production sites", function()
    boop.perf.setEnabled(true)
    boop.runtime.context()
    boop.state.combat.limiters.hunting = true
    assert.is_false(boop.combat.canAct())
    boop.state.combat.limiters.hunting = false

    local counters = boop.perf.snapshot().counters
    assert.are.equal(1, counters.contexts_built)
    assert.are.equal(1, counters.ticks_suppressed_by_limiter)
  end)

  it("measures combatlog parsing before stats publication and rendering", function()
    local cpu = 1
    os.clock = function() return cpu end
    local oldStats = boop.stats.onAttackLine
    boop.stats.onAttackLine = function() cpu = cpu + 100 end
    boop.config.gagOwnAttacks = false
    boop.config.gagOthersAttacks = false
    boop.perf.setEnabled(true)

    boop.gag.onAttackLine({
      ability = "Test",
      actor = { kind = "literal", value = "Other" },
      target = { kind = "literal", value = "Target" },
    }, {}, "Other attacks Target uniquely.")

    boop.stats.onAttackLine = oldStats
    local record = boop.perf.snapshot().records["combatlog.line"]
    assert.are.equal(1, record.count)
    assert.is_true(record.totalSeconds < 100)
  end)

  it("removes stale reserved perf rows during a real DB reload", function()
    if not db or not boop.db.handle then
      pending("requires the real Mudlet DB harness")
      return
    end
    local configTable = boop.db.handle.config
    db:add(configTable, { name = "perf", value = "true" })
    db:add(configTable, { name = "perf.on", value = "true" })
    db:add(configTable, { name = "perf.future", value = "external" })
    boop.config.perf = nil

    boop.db.loadConfig()

    assert.is_nil(boop.config.perf)
    assert.is_nil(boop.config["perf.on"])
    assert.is_nil(boop.config["perf.future"])
    assert.are.equal(0, #db:fetch(configTable, db:eq(configTable.name, "perf")))
    assert.are.equal(0, #db:fetch(configTable, db:eq(configTable.name, "perf.on")))
    assert.are.equal(0, #db:fetch(configTable, db:eq(configTable.name, "perf.future")))
    assert.is_nil(boop.db.saveConfig("perf.future", "no"))
  end)

  it("routes commands without touching trace and resets off at bootstrap", function()
    local output = {}
    _G.cecho = function(text) output[#output + 1] = text end
    boop.config.traceEnabled = true
    boop.state.trace.buffer = {}

    assert.is_true(boop.perf.command("on"))
    boop.perf.count("contexts_built")
    assert.are.equal(0, #boop.state.trace.buffer)
    assert.is_true(boop.perf.command("show"))
    assert.is_true(boop.perf.command("reset"))
    assert.is_true(boop.perf.command("off"))

    boop.perf.setEnabled(true)
    local oldBootstrapped = boop.bootstrapped
    boop.bootstrapped = true
    dofile(helper.repoRoot() .. "/src/scripts/boop/boop_bootstrap.lua")
    boop.bootstrapped = oldBootstrapped
    assert.is_false(boop.perf.on)
    assert.is_truthy(table.concat(output):find("PERFORMANCE", 1, true))
  end)

  it("installs the alias and documents perf beside trace help", function()
    local aliasPath = helper.repoRoot()
      .. "/src/aliases/boop/Diagnostics/Boop_Perf.lua"
    local aliasFile = assert(io.open(aliasPath, "r"))
    local aliasSource = aliasFile:read("*a")
    aliasFile:close()
    assert.is_truthy(aliasSource:find("boop.perf.command", 1, true))

    local diagnostics
    for _, topic in ipairs(boop.ui.helpTopics or {}) do
      if topic.key == "diagnostics" then diagnostics = topic; break end
    end
    assert.is_table(diagnostics)
    local commands = {}
    for _, item in ipairs(diagnostics.steps or {}) do
      commands[#commands + 1] = item.command or ""
    end
    for _, item in ipairs(diagnostics.commands or {}) do
      commands[#commands + 1] = item.command or ""
    end
    local installedHelp = table.concat(commands, " ")
    assert.is_truthy(installedHelp:find("boop trace", 1, true))
    assert.is_truthy(installedHelp:find("boop perf", 1, true))
  end)
end)
