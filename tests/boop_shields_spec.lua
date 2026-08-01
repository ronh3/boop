local helper = dofile(os.getenv("TESTS_DIRECTORY") .. "/support/boop_test_helper.lua")

describe("boop shield tracking", function()
  local timer_stub
  local kill_timer_stub
  local refresh_stub

  before_each(function()
    helper.reset()
    helper.setTarget("42", "a test denizen", "80%")
    helper.setDenizens({
      { id = "42", name = "a test denizen" },
    })

    timer_stub = stub(_G, "tempTimer", function(_, _)
      return 101
    end)
    kill_timer_stub = stub(_G, "killTimer", function(_) end)
    refresh_stub = stub(boop, "refreshPrequeuedStandard", function(_)
      return true
    end)
  end)

  after_each(function()
    if timer_stub then
      timer_stub:revert()
      timer_stub = nil
    end
    if kill_timer_stub then
      kill_timer_stub:revert()
      kill_timer_stub = nil
    end
    if refresh_stub then
      refresh_stub:revert()
      refresh_stub = nil
    end
  end)

  it("tracks a shield when it is seen on the current target", function()
    boop.targets.onShielded("a test denizen")

    assert.is_table(boop.state.targeting.targetShield)
    assert.is_false(boop.state.targeting.targetShield.attempted)
    assert.are.equal(101, boop.state.targeting.targetShield.timer)
    assert.stub(refresh_stub).was_called_with("shield seen")
  end)

  it("clears tracked shield state when a matching shield-down trigger fires", function()
    boop.state.targeting.targetShield = { attempted = false, timer = 77 }

    local cleared = boop.targets.onShieldDownTrigger({
      source = "test shield trigger",
      target = { kind = "match", index = 2 },
    }, { "line", "a test denizen" }, "the shield falls away")

    assert.is_true(cleared)
    assert.is_false(boop.state.targeting.targetShield)
    assert.stub(kill_timer_stub).was_called_with(77)
  end)

  it("marks the tracked shield as attempted after a shieldbreak try", function()
    boop.state.targeting.targetShield = { attempted = false }

    boop.targets.onShieldbreakAttempt()

    assert.is_true(boop.state.targeting.targetShield.attempted)
    assert.is_number(boop.state.targeting.targetShield.lastAttempt)
  end)

  it("does not treat Magi staffcast damage as shield-down evidence", function()
    local root = os.getenv("TESTS_DIRECTORY") .. "/.."
    local manifestPath = root
      .. "/src/triggers/boop/Shield/Magi/triggers.json"
    local manifestHandle = assert(io.open(manifestPath, "r"))
    local manifest = manifestHandle:read("*a")
    manifestHandle:close()

    assert.is_nil(manifest:find("Magi General Staffcast", 1, true))

    local scriptPath = root
      .. "/src/triggers/boop/Shield/Magi/Magi_General_Staffcast.lua"
    local scriptHandle = io.open(scriptPath, "r")
    if scriptHandle then scriptHandle:close() end
    assert.is_nil(scriptHandle)
  end)
end)
