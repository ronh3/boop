local helper = dofile(os.getenv("TESTS_DIRECTORY") .. "/support/boop_test_helper.lua")

describe("boop safety", function()
  local send_stub
  local timer_stub
  local save_config_stub
  local saved_disable_trigger
  local trigger_calls
  local first_send_snapshot

  local function boop_folder_trigger_calls()
    local calls = {}
    for _, call in ipairs(trigger_calls) do
      if call.name == "boop" then
        calls[#calls + 1] = call
      end
    end
    return calls
  end

  local function automation_intent_snapshot()
    local state = boop.runtime.state()
    return {
      attacking = state.combat.attacking,
      pendingStandard = state.combat.pendingStandard,
      pendingRage = state.combat.pendingRage,
      attackPlan = state.combat.attackPlan,
      calledTargetId = state.targeting.calledTargetId,
      prequeuedStandard = state.queue.prequeuedStandard,
      aliasAction = state.queue.aliasAction,
      walkActive = state.walk.active,
      walkMoveQueued = state.walk.moveQueued,
      goldAutoGrabPending = state.gold.autoGrabPending,
      goldGetPending = state.gold.getPending,
      goldPutPending = state.gold.putPending,
      goldPackTarget = state.gold.packTarget,
    }
  end

  before_each(function()
    helper.reset()
    boop.config.enabled = true
    trigger_calls = {}
    first_send_snapshot = nil

    send_stub = stub(_G, "send", function(_, _)
      if not first_send_snapshot then
        first_send_snapshot = automation_intent_snapshot()
      end
    end)
    timer_stub = stub(_G, "tempTimer", function(_, _)
      return 1
    end)
    save_config_stub = stub(boop.db, "saveConfig", function(_, _) end)
    saved_disable_trigger = _G.disableTrigger
    _G.disableTrigger = function(name)
      trigger_calls[#trigger_calls + 1] = { op = "disable", name = name }
    end
  end)

  after_each(function()
    _G.disableTrigger = saved_disable_trigger
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
    boop.state.targeting.lastRoomDir = "north"

    boop.tick()

    assert.stub(save_config_stub).was_called_with("enabled", false)
    assert.stub(send_stub).was_called_with("wake", false)
    assert.stub(send_stub).was_called_with("apply mending to legs", false)
    assert.stub(send_stub).was_called_with("stand", false)
    assert.stub(send_stub).was_called_with("north", false)
    assert.is_false(boop.config.enabled)
    assert.is_true(boop.state.combat.fleeing)
    assert.is_false(boop.state.combat.attacking)
    assert.are.same({ { op = "disable", name = "boop" } }, boop_folder_trigger_calls())
  end)

  it("clears automation intent before the first flee command is sent", function()
    helper.seedAutomationIntent()
    boop.state.targeting.lastRoomDir = "north"

    boop.safety.flee()

    assert.is_table(first_send_snapshot)
    assert.is_false(first_send_snapshot.attacking)
    assert.is_nil(first_send_snapshot.pendingStandard)
    assert.is_nil(first_send_snapshot.pendingRage)
    assert.is_nil(first_send_snapshot.attackPlan)
    assert.are.equal("", first_send_snapshot.calledTargetId)
    assert.is_false(first_send_snapshot.prequeuedStandard)
    assert.are.equal("", first_send_snapshot.aliasAction)
    assert.is_false(first_send_snapshot.walkActive)
    assert.is_false(first_send_snapshot.walkMoveQueued)
    assert.is_false(first_send_snapshot.goldAutoGrabPending)
    assert.is_false(first_send_snapshot.goldGetPending)
    assert.is_false(first_send_snapshot.goldPutPending)
    assert.are.equal("", first_send_snapshot.goldPackTarget)
    assert.stub(send_stub).was_called_with("wake", false)
  end)

  it("does not auto-flee when auto flee is disabled", function()
    gmcp.Char.Vitals.hp = 1000
    gmcp.Char.Vitals.maxhp = 5000
    boop.config.fleeEnabled = false
    boop.config.fleeAt = "30%"
    boop.state.targeting.lastRoomDir = "north"

    boop.tick()

    assert.stub(send_stub).was_not_called()
    assert.is_true(boop.config.enabled)
  end)
end)
