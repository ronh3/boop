local helper = dofile(os.getenv("TESTS_DIRECTORY") .. "/support/boop_test_helper.lua")

describe("boop pull command", function()
  local send_stub
  local ok_stub
  local warn_stub
  local info_stub
  local echoes

  before_each(function()
    helper.reset()
    helper.setClass("Occultist")
    helper.setRage(18)
    helper.learnSkill("Harry", "Attainment")
    echoes = {}
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
    assert.stub(send_stub).was_called_with("north|harry mage|leap south", false)
    assert.is_true(table.concat(echoes, "\n"):find("%[OK%] pull queued: north|harry mage|leap south", 1, true) ~= nil)
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
    assert.is_true(table.concat(echoes, "\n"):find("%[OK%] pull complete; boop resumed", 1, true) ~= nil)
  end)

  it("shows usage when the separator command is queried bare", function()
    boop.ui.gameSeparatorCommand("")

    local joined = table.concat(echoes, "\n")
    assert.is_true(joined:find("%[INFO%] game separator: |", 1, true) ~= nil)
    assert.is_true(joined:find("%[INFO%] Usage: boop separator <text>", 1, true) ~= nil)
  end)
end)
