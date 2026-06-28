local helper = dofile(os.getenv("TESTS_DIRECTORY") .. "/support/boop_test_helper.lua")

describe("boop pull command", function()
  local send_stub
  local timer_stub
  local kill_timer_stub
  local ok_stub
  local warn_stub
  local info_stub
  local echoes
  local timeout_callback

  before_each(function()
    helper.reset()
    helper.setClass("Occultist")
    helper.setRage(18)
    helper.learnSkill("Harry", "Attainment")
    echoes = {}
    timeout_callback = nil
    timer_stub = stub(_G, "tempTimer", function(_, callback)
      timeout_callback = callback
      return 333
    end)
    kill_timer_stub = stub(_G, "killTimer", function(_) end)
    send_stub = stub(_G, "send", function(_, _) end)
    ok_stub = stub(boop.util, "ok", function(msg)
      echoes[#echoes + 1] = "[OK] " .. msg
    end)
    warn_stub = stub(boop.util, "warn", function(msg)
      echoes[#echoes + 1] = "[WARN] " .. msg
    end)
    info_stub = stub(boop.util, "info", function(msg)
      echoes[#echoes + 1] = "[INFO] " .. msg
    end)
  end)

  after_each(function()
    if send_stub then send_stub:revert() send_stub = nil end
    if timer_stub then timer_stub:revert() timer_stub = nil end
    if kill_timer_stub then kill_timer_stub:revert() kill_timer_stub = nil end
    if ok_stub then ok_stub:revert() ok_stub = nil end
    if warn_stub then warn_stub:revert() warn_stub = nil end
    if info_stub then info_stub:revert() info_stub = nil end
  end)

  it("uses the configured game separator and typed mob name", function()
    boop.config.enabled = true
    boop.state.targeting.room = "1"
    boop.ui.gameSeparatorCommand("|")

    boop.ui.pullCommand("mage", "north")

    assert.is_false(boop.config.enabled)
    assert.is_truthy(boop.state.combat.pullState)
    assert.are.equal("1", boop.state.combat.pullState.originRoom)
    assert.are.equal("outbound", boop.state.combat.pullState.phase)
    assert.are.equal(333, boop.state.combat.pullState.timeoutTimer)
    assert.stub(send_stub).was_called_with("north|harry mage|leap south", false)
    assert.is_true(table.concat(echoes, "\n"):find("%[OK%] pull queued: north|harry mage|leap south", 1, true) ~= nil)
  end)

  it("prepends psion transcend shatter to pull rage commands", function()
    helper.setClass("Psion")
    helper.setRage(25)
    helper.learnSkill("whirlwind", "Attainment")
    boop.config.enabled = true
    boop.state.targeting.room = "1"
    boop.ui.gameSeparatorCommand("|")

    boop.ui.pullCommand("mage", "north")

    assert.stub(send_stub).was_called_with("north|psi transcend shatter/weave whirlwind mage|leap south", false)
  end)

  it("leaves dragon pull rage commands unchanged", function()
    helper.setClass("Blue Dragon")
    helper.setRage(14)
    helper.learnSkill("dragonchill", "Attainment")
    boop.config.enabled = true
    boop.state.targeting.room = "1"
    boop.ui.gameSeparatorCommand("|")

    boop.ui.pullCommand("mage", "north")

    assert.stub(send_stub).was_called_with("north|dragonchill mage|leap south", false)
  end)

  it("restores boop after gmcp confirms the return to the origin room", function()
    boop.config.enabled = true
    boop.state.targeting.room = "1"
    boop.ui.gameSeparatorCommand("|")

    boop.ui.pullCommand("mage", "north")

    gmcp.Room.Info.num = "2"
    boop.onRoomInfo()
    assert.is_false(boop.config.enabled)
    assert.are.equal("away", boop.state.combat.pullState.phase)

    gmcp.Room.Info.num = "1"
    boop.onRoomInfo()
    assert.is_true(boop.config.enabled)
    assert.is_false(boop.state.combat.pullState)
    assert.stub(kill_timer_stub).was_called_with(333)
    assert.is_true(table.concat(echoes, "\n"):find("%[OK%] pull complete; boop resumed", 1, true) ~= nil)
  end)

  it("clears a stuck pull and resumes boop when the timeout still sees the origin room", function()
    boop.config.enabled = true
    boop.state.targeting.room = "1"
    boop.ui.gameSeparatorCommand("|")

    boop.ui.pullCommand("mage", "north")
    assert.is_false(boop.config.enabled)
    assert.is_function(timeout_callback)

    timeout_callback()

    assert.is_true(boop.config.enabled)
    assert.is_false(boop.state.combat.pullState)
    assert.is_true(table.concat(echoes, "\n"):find("%[WARN%] pull timeout; boop resumed at origin", 1, true) ~= nil)
  end)

  it("clears a stuck pull without resuming boop when timeout sees an away room", function()
    boop.config.enabled = true
    boop.state.targeting.room = "1"
    boop.ui.gameSeparatorCommand("|")

    boop.ui.pullCommand("mage", "north")
    gmcp.Room.Info.num = "2"
    boop.onRoomInfo()
    assert.are.equal("away", boop.state.combat.pullState.phase)

    timeout_callback()

    assert.is_false(boop.config.enabled)
    assert.is_false(boop.state.combat.pullState)
    assert.is_true(table.concat(echoes, "\n"):find("%[WARN%] pull timeout; boop remains paused", 1, true) ~= nil)
  end)

  it("rejects mob names that contain the configured command separator", function()
    boop.config.enabled = true
    boop.state.targeting.room = "1"
    boop.ui.gameSeparatorCommand("|")

    boop.ui.pullCommand("mage|say unsafe", "north")

    assert.stub(send_stub).was_not_called()
    assert.is_false(boop.state.combat.pullState)
    assert.is_true(table.concat(echoes, "\n"):find("%[WARN%] pull: mob name cannot contain the game separator or newlines", 1, true) ~= nil)
  end)

  it("shows usage when the separator command is queried bare", function()
    boop.ui.gameSeparatorCommand("")

    local joined = table.concat(echoes, "\n")
    assert.is_true(joined:find("%[INFO%] game separator: |", 1, true) ~= nil)
    assert.is_true(joined:find("%[INFO%] Usage: boop separator <text>", 1, true) ~= nil)
  end)
end)
