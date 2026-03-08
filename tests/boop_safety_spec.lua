local helper = dofile(os.getenv("TESTS_DIRECTORY") .. "/support/boop_test_helper.lua")

describe("boop safety", function()
  local send_stub
  local timer_stub
  local save_config_stub

  before_each(function()
    helper.reset()
    boop.config.enabled = true

    send_stub = stub(_G, "send", function(_, _) end)
    timer_stub = stub(_G, "tempTimer", function(_, _)
      return 1
    end)
    save_config_stub = stub(boop.db, "saveConfig", function(_, _) end)
  end)

  after_each(function()
    if send_stub then
      send_stub:revert()
      send_stub = nil
    end
    if timer_stub then
      timer_stub:revert()
      timer_stub = nil
    end
    if save_config_stub then
      save_config_stub:revert()
      save_config_stub = nil
    end
  end)

  it("parses percentage flee thresholds against max health", function()
    gmcp.Char.Vitals.maxhp = 5000

    assert.are.equal(1500, boop.safety.parseThreshold("30%"))
  end)

  it("flees and disables boop when health crosses the configured threshold", function()
    gmcp.Char.Vitals.hp = 1000
    gmcp.Char.Vitals.maxhp = 5000
    boop.config.fleeAt = "30%"
    boop.state.lastRoomDir = "north"

    boop.tick()

    assert.stub(save_config_stub).was_called_with("enabled", false)
    assert.stub(send_stub).was_called_with("wake", false)
    assert.stub(send_stub).was_called_with("apply mending to legs", false)
    assert.stub(send_stub).was_called_with("stand", false)
    assert.stub(send_stub).was_called_with("north", false)
    assert.is_false(boop.config.enabled)
    assert.is_true(boop.state.fleeing)
    assert.is_false(boop.state.attacking)
  end)
end)
