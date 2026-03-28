local helper = dofile(os.getenv("TESTS_DIRECTORY") .. "/support/boop_test_helper.lua")

describe("boop runtime coordinator", function()
  local send_stub
  local timer_stub
  local kill_timer_stub

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

  it("maps legacy state aliases onto owned runtime domains", function()
    local state = boop.runtime.state()

    state.targeting.currentTargetId = "42"
    state.queue.prequeuedStandard = true
    boop.state.calledTargetId = "99"

    assert.are.equal("42", boop.state.currentTargetId)
    assert.is_true(boop.state.prequeuedStandard)
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

  it("releases diagnose hold from prompt effects", function()
    boop.state.diagHold = true
    boop.state.diagAwaitPrompt = true
    boop.state.diagLabel = "matic"
    boop.state.diagTimeoutTimer = 44

    local result = boop.runtime.step({ type = "prompt", context = boop.runtime.context() })
    boop.runtime.applyEffects(result, boop.runtime.context())

    assert.is_false(boop.state.diagHold)
    assert.is_false(boop.state.diagAwaitPrompt)
    assert.are.equal("", boop.state.diagLabel)
    assert.stub(kill_timer_stub).was_called_with(44)
  end)
end)
