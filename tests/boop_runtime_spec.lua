local helper = dofile(os.getenv("TESTS_DIRECTORY") .. "/support/boop_test_helper.lua")

describe("boop runtime coordinator", function()
  local send_stub
  local timer_stub
  local kill_timer_stub

  local function effectKinds(result)
    local kinds = {}
    for _, effect in ipairs((result and result.effects) or {}) do
      kinds[effect.kind] = true
    end
    return kinds
  end

  before_each(function()
    helper.reset()
    timer_stub = stub(_G, "tempTimer", function(_, _)
      return 1
    end)
    kill_timer_stub = stub(_G, "killTimer", function(_) end)
    send_stub = stub(_G, "send", function(_, _) end)
  end)

  after_each(function()
    if send_stub then send_stub:revert() send_stub = nil end
    if timer_stub then timer_stub:revert() timer_stub = nil end
    if kill_timer_stub then kill_timer_stub:revert() kill_timer_stub = nil end
  end)

  it("initializes owned domains and the canonical blocker snapshot", function()
    local state = boop.runtime.state()
    local domains = {
      "combat",
      "targeting",
      "queue",
      "gold",
      "walk",
      "diag",
      "trace",
      "rage",
      "inventory",
      "ih",
      "gag",
    }

    for _, domain in ipairs(domains) do
      assert.is_table(state[domain])
    end

    assert.is_table(state.combat.blocker)
    assert.are.equal("", state.combat.blocker.code)
    assert.are.equal("", state.combat.blocker.label)
    assert.is_table(state.combat.blocker.systems)
    assert.is_table(state.combat.blocker.waitsFor)
    assert.is_table(state.combat.blocker.observed)

    local snapshot = boop.runtime.blockerSnapshot()
    assert.are.equal("", snapshot.code)
    assert.are.equal("", snapshot.label)
    assert.is_table(snapshot.systems)
    assert.is_table(snapshot.waitsFor)
    assert.is_table(snapshot.observed)
  end)

  it("maps legacy state aliases onto owned runtime domains", function()
    local state = boop.runtime.state()

    state.targeting.currentTargetId = "42"
    state.queue.prequeuedStandard = true
    boop.state.targeting.calledTargetId = "99"

    assert.are.equal("42", boop.state.targeting.currentTargetId)
    assert.is_true(boop.state.queue.prequeuedStandard)
    assert.are.equal("99", state.targeting.calledTargetId)
  end)

  it("returns target and combat effects for the main tick path", function()
    helper.setClass("Occultist")
    helper.setTargetHp("80%")
    helper.setRage(14)
    helper.learnSkills({
      { name = "Lycantha", group = "Domination" },
      { name = "Warp", group = "Occultism" },
      { name = "harry", group = "Attainment" },
    })
    helper.setDenizens({
      { id = "42", name = "a test denizen" },
    })

    boop.config.enabled = true
    boop.config.targetingMode = "auto"
    boop.config.attackMode = "simple"

    local result = boop.runtime.step({ type = "tick", context = boop.runtime.context() })

    assert.are.equal("target", result.effects[1].kind)
    assert.are.equal("42", result.effects[1].id)
    assert.are.equal("combat_plan", result.effects[2].kind)
    assert.are.equal("command hound at 42", result.effects[2].plan.standard)
    assert.are.equal("harry 42", result.effects[2].plan.rage)
  end)

  it("holds automation effects while the owned blocker affects runtime systems", function()
    helper.setClass("Occultist")
    helper.setTargetHp("80%")
    helper.setRage(14)
    helper.learnSkills({
      { name = "Lycantha", group = "Domination" },
      { name = "Warp", group = "Occultism" },
      { name = "harry", group = "Attainment" },
    })
    helper.setDenizens({
      { id = "42", name = "a test denizen" },
    })
    helper.setRuntimeBlocker({
      code = "gmcp_ire_missing",
      label = "GMCP IRE missing",
      systems = {
        target = true,
        combat = true,
        queue = true,
        gold = true,
        walk = true,
      },
      waitsFor = {
        gmcp = true,
        prompt = true,
      },
      observed = {
        ire = false,
        room = "1",
      },
    })

    boop.config.enabled = true
    boop.config.targetingMode = "auto"
    boop.config.attackMode = "simple"
    boop.config.useQueueing = true
    boop.state.gold.autoGrabPending = true

    assert.is_true(boop.runtime.shouldHold("target"))
    assert.is_true(boop.runtime.shouldHold("combat"))
    assert.is_true(boop.runtime.shouldHold("queue"))
    assert.is_true(boop.runtime.shouldHold("gold"))
    assert.is_true(boop.runtime.shouldHold("walk"))

    local result = boop.runtime.step({ type = "tick", context = boop.runtime.context() })
    local kinds = effectKinds(result)

    assert.is_nil(kinds.target)
    assert.is_nil(kinds.combat_plan)
    assert.is_nil(kinds.flush_gold)
    assert.is_nil(kinds.walk_advance)
    assert.is_false(result.didAction)
  end)

  it("releases diagnose hold from prompt effects", function()
    boop.state.diag.hold = true
    boop.state.diag.awaitPrompt = true
    boop.state.diag.label = "matic"
    boop.state.diag.timeoutTimer = 44

    local result = boop.runtime.step({ type = "prompt", context = boop.runtime.context() })
    boop.runtime.applyEffects(result, boop.runtime.context())

    assert.is_false(boop.state.diag.hold)
    assert.is_false(boop.state.diag.awaitPrompt)
    assert.are.equal("", boop.state.diag.label)
    assert.stub(kill_timer_stub).was_called_with(44)
  end)
end)
