local helper = dofile(os.getenv("TESTS_DIRECTORY") .. "/support/boop_test_helper.lua")

describe("boop assist mode", function()
  local send_stub
  local save_config_stub

  before_each(function()
    helper.reset()
    send_stub = stub(_G, "send", function(_, _) end)
    save_config_stub = stub(boop.db, "saveConfig", function(_, _) end)
  end)

  after_each(function()
    if send_stub then
      send_stub:revert()
      send_stub = nil
    end
    if save_config_stub then
      save_config_stub:revert()
      save_config_stub = nil
    end
  end)

  it("prefixes direct standard attacks with assist", function()
    boop.config.assistEnabled = true
    boop.config.assistLeader = "Leader"

    boop.executeAction("command hound at 42")

    assert.stub(send_stub).was_called_with("assist Leader", false)
    assert.stub(send_stub).was_called_with("command hound at 42", false)
  end)

  it("prefixes queued standard attacks with assist", function()
    boop.config.useQueueing = true
    boop.config.assistEnabled = true
    boop.config.assistLeader = "Leader"

    boop.executeAction("command hound at 42")

    assert.stub(send_stub).was_called_with("setalias BOOP_ATTACK assist Leader/command hound at 42", false)
    assert.stub(send_stub).was_called_with("queue addclearfull freestand BOOP_ATTACK", false)
  end)

  it("prefixes rage attacks with assist", function()
    boop.config.assistEnabled = true
    boop.config.assistLeader = "Leader"

    boop.executeRageAction("harry 42")

    assert.stub(send_stub).was_called_with("assist Leader", false)
    assert.stub(send_stub).was_called_with("harry 42", false)
  end)

  it("stores leader names and toggles assist state from the ui command", function()
    boop.ui.assistCommand("Leader")

    assert.are.equal("Leader", boop.config.assistLeader)
    assert.is_true(boop.config.assistEnabled)
    assert.stub(save_config_stub).was_called_with("assistLeader", "Leader")
    assert.stub(save_config_stub).was_called_with("assistEnabled", true)

    boop.ui.assistCommand("off")
    assert.is_false(boop.config.assistEnabled)

    boop.ui.assistCommand("clear")
    assert.are.equal("", boop.config.assistLeader)
    assert.is_false(boop.config.assistEnabled)
  end)
end)
