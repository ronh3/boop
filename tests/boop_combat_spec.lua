local helper = dofile(
  os.getenv("TESTS_DIRECTORY")
    .. "/support/boop_test_helper.lua"
)

describe("boop combat orchestration", function()
  local timer_stub

  local function seedCombat()
    helper.reset()
    helper.setArea("Test Area")
    helper.setClass("Occultist")
    helper.setTargetHp("80%")
    helper.learnSkills({
      { name = "Lycantha", group = "Domination" },
      { name = "Warp", group = "Occultism" },
      { name = "Hammer", group = "Tattoos" },
    })
    helper.setDenizens({
      { id = "42", name = "a test denizen" },
    })
    boop.config.enabled = true
    boop.config.prequeueEnabled = true
    boop.config.targetingMode = "auto"
    boop.config.attackMode = "simple"
    gmcp.Char.Vitals.bal = "0"
    gmcp.Char.Vitals.eq = "0"
  end

  before_each(function()
    seedCombat()
  end)

  after_each(function()
    if timer_stub then
      timer_stub:revert()
      timer_stub = nil
    end
  end)

  it("publishes the moved APIs only from Combat", function()
    assert.is_function(boop.combat.tickStep)
    assert.is_function(boop.combat.promptStep)
    assert.is_function(boop.combat.step)
    assert.is_function(boop.combat.applyEffects)
    assert.is_function(boop.combat.execute)
    assert.is_function(boop.combat.canAct)
    assert.is_function(boop.combat.canUseRage)
    assert.is_nil(boop.runtime.step)
    assert.is_nil(boop.runtime.applyEffects)
    assert.is_nil(boop.attacks.execute)
    assert.is_nil(boop.canAct)
    assert.is_nil(boop.canUseRage)
  end)

  it("keeps Runtime context canonical for bare attack planning", function()
    helper.setTarget("42", "a test denizen", "80%")
    local calls = 0
    local original = boop.runtime.context
    local context_stub = stub(
      boop.runtime,
      "context",
      function(...)
        calls = calls + 1
        return original(...)
      end
    )

    local plan = boop.attacks.choose()

    context_stub:revert()
    assert.are.equal(1, calls)
    assert.are.equal("command hound at 42", plan.standard)
  end)

  local sharedGateCases = {
    {
      name = "diag hold",
      expected = "diag_hold",
      setup = function()
        boop.state.diag.hold = true
      end,
    },
    {
      name = "Gold pending",
      expected = "gold_pending",
      setup = function()
        boop.state.gold.getPending = true
      end,
    },
    {
      name = "operation blocker",
      expected = "test_operation_hold",
      setup = function()
        helper.setRuntimeBlocker({
          owner = "interrupt:gate-test",
          code = "test_operation_hold",
          label = "test operation hold",
          systems = {
            target = true,
            combat = true,
            queue = true,
            gold = true,
            walk = true,
          },
        })
      end,
    },
    {
      name = "no target",
      expected = "no_target",
      setup = function()
        helper.setDenizens({})
      end,
    },
    {
      name = "flee threshold",
      expected = "flee",
      setup = function()
        boop.config.fleeEnabled = true
        boop.config.fleeAt = "20%"
        gmcp.Char.Vitals.hp = 500
        gmcp.Char.Vitals.maxhp = 5000
      end,
    },
    {
      name = "readiness failure",
      expected = "gmcp_ire_missing",
      setup = function()
        boop.state.lifecycle.promptSeen = false
        boop.state.lifecycle.ready = false
      end,
    },
  }

  for _, case in ipairs(sharedGateCases) do
    it("returns the independent " .. case.expected
        .. " verdict for tick and prequeue on " .. case.name, function()
      for _, kind in ipairs({ "tick", "prequeue" }) do
        seedCombat()
        case.setup()
        local result = boop.combat.evaluateGates({
          kind = kind,
          context = boop.runtime.context(),
          deferPlanning = kind == "prequeue",
        })
        assert.is_false(result.allowed, kind)
        assert.are.equal(case.expected, result.code, kind)
      end
    end)
  end

  it("preserves tick and prequeue gate precedence", function()
    boop.config.enabled = false
    boop.state.lifecycle.promptSeen = false
    boop.state.lifecycle.ready = false
    local context = boop.runtime.context()

    assert.are.equal("disabled", boop.combat.evaluateGates({
      kind = "tick",
      context = context,
    }).code)
    assert.are.equal("gmcp_ire_missing", boop.combat.evaluateGates({
      kind = "prequeue",
      context = context,
      deferPlanning = true,
    }).code)

    seedCombat()
    boop.state.diag.hold = true
    helper.setRuntimeBlocker({
      owner = "interrupt:precedence",
      code = "operation_first",
      systems = { combat = true, queue = true },
    })
    context = boop.runtime.context()
    assert.are.equal("diag_hold", boop.combat.evaluateGates({
      kind = "tick",
      context = context,
    }).code)
    assert.are.equal("operation_first", boop.combat.evaluateGates({
      kind = "prequeue",
      context = context,
      deferPlanning = true,
    }).code)
  end)

  it("preserves the active-Gold tick branch", function()
    boop.state.gold.operation = {
      terminal = false,
      timeoutTimer = false,
      blockerOwner = "gold:gate-test",
    }

    local result = boop.combat.evaluateGates({
      kind = "tick",
      context = boop.runtime.context(),
    })

    assert.is_false(result.allowed)
    assert.are.equal("gold_operation", result.code)
    assert.is_true(result.flushGold)
  end)

  it("allows shield planning and requires shieldbreak only for refresh", function()
    helper.setTarget("42", "a test denizen", "80%")
    boop.state.targeting.targetShield = {
      gained = os.clock(),
      attempted = false,
    }
    boop.state.queue.prequeuedStandard = true
    local context = boop.runtime.context()

    local tick = boop.combat.evaluateGates({
      kind = "tick",
      context = context,
    })
    local refresh = boop.combat.evaluateGates({
      kind = "refresh",
      context = context,
    })

    assert.is_true(tick.allowed)
    assert.is_true(tick.plan.standardShieldbreak)
    assert.is_true(refresh.allowed)
    assert.is_true(refresh.plan.standardShieldbreak)
  end)

  it("preserves refresh's intentional lack of a flee gate", function()
    helper.setTarget("42", "a test denizen", "80%")
    boop.state.targeting.targetShield = {
      gained = os.clock(),
      attempted = false,
    }
    boop.config.fleeEnabled = true
    boop.config.fleeAt = "20%"
    gmcp.Char.Vitals.hp = 500
    gmcp.Char.Vitals.maxhp = 5000

    local context = boop.runtime.context()
    assert.are.equal("flee", boop.combat.evaluateGates({
      kind = "prequeue",
      context = context,
      deferPlanning = true,
    }).code)
    boop.state.queue.prequeuedStandard = true
    context = boop.runtime.context()
    assert.is_true(boop.combat.evaluateGates({
      kind = "refresh",
      context = context,
    }).allowed)
  end)

  it("reports Standard pending and unavailable planning independently", function()
    local standard_stub = stub(
      boop.runtime,
      "standardPending",
      function() return true end
    )
    local pending = boop.combat.evaluateGates({
      kind = "tick",
      context = boop.runtime.context(),
    })
    standard_stub:revert()
    assert.are.equal("standard_pending", pending.code)

    helper.reset()
    helper.setArea("Test Area")
    helper.setClass("Occultist")
    helper.setDenizens({
      { id = "42", name = "a test denizen" },
    })
    boop.config.enabled = true
    boop.config.targetingMode = "auto"
    local unavailable = boop.combat.evaluateGates({
      kind = "tick",
      context = boop.runtime.context(),
    })
    assert.is_false(unavailable.allowed)
    assert.are.equal("no_attack_plan", unavailable.code)
  end)

  it("synchronizes a newly selected target even when no attack is available", function()
    local selectedTargets = {}
    local choose_stub = stub(
      boop.attacks,
      "choose",
      function()
        return { standard = "", rage = "" }
      end
    )
    local sync_stub = stub(
      boop.targets,
      "needsGameTargetSync",
      function() return false end
    )
    local target_stub = stub(
      boop.targets,
      "setTarget",
      function(id)
        selectedTargets[#selectedTargets + 1] = tostring(id)
        return true
      end
    )
    local execute_stub = stub(
      boop.combat,
      "execute",
      function() return true end
    )

    local first = boop.combat.tick()
    helper.setTarget("42", "a test denizen", "80%")
    local second = boop.combat.tick()

    choose_stub:revert()
    sync_stub:revert()
    target_stub:revert()
    execute_stub:revert()

    assert.is_false(first)
    assert.is_false(second)
    assert.same({ "42" }, selectedTargets)
    assert.stub(execute_stub).was_not_called()
  end)

  it("builds target-adjusted plans without mutating Runtime context", function()
    local captured
    local choose_stub = stub(
      boop.attacks,
      "choose",
      function(context)
        captured = context
        return { standard = "test 42", rage = "" }
      end
    )
    local canonical = boop.runtime.context()

    local result = boop.combat.evaluateGates({
      kind = "tick",
      context = canonical,
    })
    choose_stub:revert()

    assert.is_true(result.allowed)
    assert.are.equal("42", captured.target.id)
    assert.are.equal("a test denizen", captured.target.name)
    assert.is_false(captured.target.shield)
    assert.are.equal("", captured.target.hpperc)
    assert.are.equal("", canonical.target.id)
    assert.are.equal("", canonical.target.name)
    assert.are.equal("80%", canonical.target.hpperc)
  end)

  it("preserves shield and HP inputs when the target is already current", function()
    helper.setTarget("42", "a test denizen", "37%")
    local shield = { attempted = false }
    boop.state.targeting.targetShield = shield
    local captured
    local choose_stub = stub(
      boop.attacks,
      "choose",
      function(context)
        captured = context
        return { standard = "test 42", rage = "" }
      end
    )

    local result = boop.combat.evaluateGates({
      kind = "tick",
      context = boop.runtime.context(),
    })
    choose_stub:revert()

    assert.is_true(result.allowed)
    assert.are.equal("42", captured.target.id)
    assert.are.equal("a test denizen", captured.target.name)
    assert.are.equal(shield, captured.target.shield)
    assert.are.equal("37%", captured.target.hpperc)
  end)

  it("delegates the combat portion of the Events tick facade", function()
    local received = {}
    local tick_stub = stub(
      boop.combat,
      "tick",
      function(authority, options, source)
        received.authority = authority
        received.options = options
        received.source = source
        return true
      end
    )

    assert.is_true(boop.tick(nil, nil, "vitals"))
    tick_stub:revert()

    assert.is_table(received.authority)
    assert.are.equal("1", received.authority.roomId)
    assert.is_true(received.options.roomOwned)
    assert.is_false(received.options.provisionalCombat)
    assert.are.equal("vitals", received.source)
  end)

  it("preserves limiter timing and release behavior", function()
    local timers = {}
    timer_stub = stub(_G, "tempTimer", function(delay, callback)
      timers[#timers + 1] = {
        delay = delay,
        callback = callback,
      }
      return #timers
    end)
    gmcp.Char.Vitals.bal = "1"
    gmcp.Char.Vitals.eq = "1"

    assert.is_true(boop.combat.canAct())
    assert.is_false(boop.combat.canAct())
    assert.are.equal(0.4, timers[1].delay)
    timers[1].callback()
    assert.is_true(boop.combat.canAct())

    assert.is_true(boop.combat.canUseRage())
    assert.is_false(boop.combat.canUseRage())
    assert.are.equal(0.6, timers[3].delay)
    timers[3].callback()
    assert.is_true(boop.combat.canUseRage())
  end)
end)
