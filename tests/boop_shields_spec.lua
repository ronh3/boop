local helper = dofile(os.getenv("TESTS_DIRECTORY") .. "/support/boop_test_helper.lua")

describe("boop shield tracking", function()
  local timer_stub
  local kill_timer_stub
  local refresh_stub
  local delete_config_stub
  local refresh_calls

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
    refresh_calls = {}
    refresh_stub = stub(boop, "refreshPrequeuedStandard", function(reason, authority, options)
      refresh_calls[#refresh_calls + 1] = {
        reason = reason,
        authority = authority,
        options = options,
      }
      return true
    end)
    delete_config_stub = stub(boop.db, "deleteConfig", function(_) end)
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
    if delete_config_stub then
      delete_config_stub:revert()
      delete_config_stub = nil
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

  it("changes the session shield mode without clearing tracked shield state", function()
    local trackedShield = boop.state.targeting.targetShield

    assert.are.equal("break", boop.getShieldMode())
    assert.is_true(boop.ui.shieldModeCommand("bypass"))
    assert.are.equal("bypass", boop.getShieldMode())
    assert.are.equal(trackedShield, boop.state.targeting.targetShield)
    assert.are.equal("shield mode bypass", refresh_calls[1].reason)
    assert.is_false(refresh_calls[1].options.requireShieldbreak)
    assert.stub(delete_config_stub).was_called_with("breakShields")

    assert.is_true(boop.ui.shieldModeCommand("toggle"))
    assert.are.equal("break", boop.getShieldMode())
    assert.are.equal(trackedShield, boop.state.targeting.targetShield)
    assert.are.equal("shield mode break", refresh_calls[2].reason)
  end)

  it("resets bypass mode on package reload and reconnect", function()
    local testsDirectory = tostring(os.getenv("TESTS_DIRECTORY") or "")
    local repoRoot = os.getenv("BOOP_REPO_ROOT")
      or testsDirectory:match("^(.*)/tests/?$")
    repoRoot = assert(repoRoot, "boop repository root is required")
    local priorBootstrapped = boop.bootstrapped

    boop.config.breakShields = false
    boop.bootstrapped = true
    assert.has_no.errors(function()
      dofile(repoRoot .. "/src/scripts/boop/boop_bootstrap.lua")
    end)
    boop.bootstrapped = priorBootstrapped
    assert.are.equal("break", boop.getShieldMode())

    boop.config.breakShields = false
    boop.onConnectionEvent()
    assert.are.equal("break", boop.getShieldMode())
  end)

  it("packages the shieldmode alias", function()
    local root = os.getenv("TESTS_DIRECTORY") .. "/.."
    local manifestHandle = assert(io.open(
      root .. "/src/aliases/boop/Combat/aliases.json",
      "r"
    ))
    local manifest = manifestHandle:read("*a")
    manifestHandle:close()
    local scriptHandle = assert(io.open(
      root .. "/src/aliases/boop/Combat/Boop_Shieldmode.lua",
      "r"
    ))
    local script = scriptHandle:read("*a")
    scriptHandle:close()

    assert.is_true(manifest:find("Boop Shieldmode", 1, true) ~= nil)
    assert.is_true(manifest:find("boop\\\\s+shieldmode", 1, true) ~= nil)
    assert.is_true(script:find("boop.ui.shieldModeCommand", 1, true) ~= nil)
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
