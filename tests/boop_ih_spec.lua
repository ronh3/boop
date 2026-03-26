local helper = dofile(os.getenv("TESTS_DIRECTORY") .. "/support/boop_test_helper.lua")

describe("boop ih", function()
  local echo_stub
  local echoes
  local saved_cecho
  local saved_cecho_link
  local saved_echo
  local saved_echo_link
  local saved_enable_trigger
  local saved_disable_trigger
  local saved_temp_timer
  local saved_kill_timer
  local trigger_calls
  local next_timer_id

  before_each(function()
    helper.reset()
    helper.setArea("Test Area")
    helper.setDenizens({
      { id = "42", name = "a test denizen" },
    })

    echoes = {}
    echo_stub = stub(boop.util, "echo", function(msg)
      echoes[#echoes + 1] = msg
    end)

    saved_cecho = _G.cecho
    saved_cecho_link = _G.cechoLink
    saved_echo = _G.echo
    saved_echo_link = _G.echoLink
    saved_enable_trigger = _G.enableTrigger
    saved_disable_trigger = _G.disableTrigger
    saved_temp_timer = _G.tempTimer
    saved_kill_timer = _G.killTimer
    _G.cecho = nil
    _G.cechoLink = nil
    _G.echo = nil
    _G.echoLink = nil

    trigger_calls = {}
    next_timer_id = 0

    _G.enableTrigger = function(name)
      trigger_calls[#trigger_calls + 1] = { op = "enable", name = name }
    end

    _G.disableTrigger = function(name)
      trigger_calls[#trigger_calls + 1] = { op = "disable", name = name }
    end

    _G.tempTimer = function(_, fn)
      next_timer_id = next_timer_id + 1
      return { id = next_timer_id, callback = fn }
    end

    _G.killTimer = function(_) end
  end)

  after_each(function()
    if echo_stub then
      echo_stub:revert()
      echo_stub = nil
    end
    _G.cecho = saved_cecho
    _G.cechoLink = saved_cecho_link
    _G.echo = saved_echo
    _G.echoLink = saved_echo_link
    _G.enableTrigger = saved_enable_trigger
    _G.disableTrigger = saved_disable_trigger
    _G.tempTimer = saved_temp_timer
    _G.killTimer = saved_kill_timer
  end)

  it("suppresses ih whitelist and blacklist labels for globally blacklisted denizens", function()
    helper.setGlobalBlacklist({ "a test denizen" })

    boop.ih.printLine("42", "a test denizen", true, "42  a test denizen")

    assert.are.equal("42  a test denizen", echoes[1])
  end)

  it("shows ih whitelist and blacklist labels for non-global denizens", function()
    boop.ih.printLine("42", "a test denizen", true, "42  a test denizen")

    assert.are.equal("42  a test denizen [+whitelist] [+blacklist]", echoes[1])
  end)

  it("arms and disarms ih capture triggers only around boop ih capture", function()
    boop.ih.start()

    assert.is_true(boop.state.ihRequested)
    assert.is_false(boop.state.ihActive)
    assert.are.same({
      { op = "enable", name = "IH End" },
      { op = "enable", name = "IH Line" },
    }, trigger_calls)

    boop.ih.stop()

    assert.is_false(boop.state.ihRequested)
    assert.is_false(boop.state.ihActive)
    assert.are.same({
      { op = "enable", name = "IH End" },
      { op = "enable", name = "IH Line" },
      { op = "disable", name = "IH End" },
      { op = "disable", name = "IH Line" },
    }, trigger_calls)
  end)

  it("does not activate ih capture for non-ih timestamp lines", function()
    boop.ih.start()
    boop.ih.handleLine("2026/03/24", "00:55:30 - test", "2026/03/24 00:55:30 - test")

    assert.is_true(boop.state.ihRequested)
    assert.is_false(boop.state.ihActive)
    assert.are.equal(0, #echoes)
  end)

  it("activates ih capture for valid ih object rows", function()
    boop.ih.start()
    boop.ih.handleLine("dockworker79858", "a swarthy troll dockworker", "dockworker79858     a swarthy troll dockworker")

    assert.is_true(boop.state.ihRequested)
    assert.is_true(boop.state.ihActive)
    assert.are.equal("dockworker79858     a swarthy troll dockworker [+whitelist] [+blacklist]", echoes[1])
  end)

  it("keeps the ih trigger broad enough for apostrophes in object ids without matching timestamps", function()
    local testsDir = assert(os.getenv("TESTS_DIRECTORY"))
    local repoRoot = assert(testsDir:match("^(.*)/tests$"))
    local handle = assert(io.open(repoRoot .. "/src/triggers/boop/IH/triggers.json", "r"))
    local contents = assert(handle:read("*a"))
    handle:close()

    assert.is_true(contents:find([["pattern": "^([A-Za-z][A-Za-z0-9_'-]*\\d+)\\s+(.+)$"]], 1, true) ~= nil)
  end)
end)
