local helper = dofile(os.getenv("TESTS_DIRECTORY") .. "/support/boop_test_helper.lua")

describe("boop combat planner", function()
  local send_stub
  local timer_stub
  local kill_timer_stub

  before_each(function()
    helper.reset()
    helper.setClass("Occultist")
    helper.setTarget("42", "a test denizen", "80%")
    helper.setRage(14)
    helper.learnSkills({
      { name = "Lycantha", group = "Domination" },
      { name = "Warp", group = "Occultism" },
      { name = "harry", group = "Attainment" },
    })

    boop.config.enabled = true
    boop.config.targetingMode = "auto"
    boop.config.attackMode = "simple"

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

  it("builds a pure combat plan and then resolves modifiers separately", function()
    local context = boop.runtime.context()
    local plan = boop.attacks.plan(context)
    local resolved = boop.attacks.applyModifiers(plan, context)

    assert.are.equal("occultist", plan.class)
    assert.are.equal("command hound at &tar", plan.standard)
    assert.are.equal("harry &tar", plan.rage)
    assert.are.equal("command hound at 42", resolved.standard)
    assert.are.equal("harry 42", resolved.rage)
  end)

  it("executes an already planned combat decision", function()
    local context = boop.runtime.context()
    local plan = boop.attacks.choose(context)

    local did_action = boop.attacks.execute(plan, context)

    assert.is_true(did_action)
    assert.stub(send_stub).was_called_with("command hound at 42", false)
    assert.stub(send_stub).was_called_with("harry 42", false)
  end)
end)
