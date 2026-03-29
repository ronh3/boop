local helper = dofile(os.getenv("TESTS_DIRECTORY") .. "/support/boop_test_helper.lua")

describe("boop prequeue", function()
  local send_stub
  local send_gmcp_stub
  local timer_stub
  local kill_timer_stub
  local epoch_stub
  local last_delay
  local last_callback

  before_each(function()
    helper.reset()
    helper.setArea("Test Area")
    helper.setClass("Occultist")
    helper.setTargetHp("80%")
    helper.learnSkill("Lycantha", "Domination")
    helper.setDenizens({
      { id = "42", name = "a test denizen" },
    })

    boop.config.enabled = true
    boop.config.targetingMode = "auto"
    boop.config.prequeueEnabled = true
    boop.config.attackLeadSeconds = 2

    send_stub = stub(_G, "send", function(_, _) end)
    send_gmcp_stub = stub(_G, "sendGMCP", function(_) end)
    timer_stub = stub(_G, "tempTimer", function(delay, callback)
      last_delay = delay
      last_callback = callback
      return 55
    end)
    kill_timer_stub = stub(_G, "killTimer", function(_) end)
    epoch_stub = stub(_G, "getEpoch", function()
      return 100
    end)
  end)

  after_each(function()
    last_delay = nil
    last_callback = nil
    if send_stub then
      send_stub:revert()
      send_stub = nil
    end
    if send_gmcp_stub then
      send_gmcp_stub:revert()
      send_gmcp_stub = nil
    end
    if timer_stub then
      timer_stub:revert()
      timer_stub = nil
    end
    if kill_timer_stub then
      kill_timer_stub:revert()
      kill_timer_stub = nil
    end
    if epoch_stub then
      epoch_stub:revert()
      epoch_stub = nil
    end
  end)

  it("schedules a prequeue timer based on balance recovery and lead time", function()
    boop.onBalanceUsed("balance", 3)

    assert.are.equal(103, boop.state.queue.balanceReadyAt)
    assert.are.equal(1, last_delay)
    assert.are.equal(55, boop.state.queue.prequeueTimer)
    assert.is_function(last_callback)
  end)

  it("queues the next standard attack when prequeue fires while off balance", function()
    gmcp.Char.Vitals.bal = "0"
    gmcp.Char.Vitals.eq = "0"

    boop.prequeueStandard()

    assert.stub(send_stub).was_called_with("settarget 42", false)
    assert.stub(send_stub).was_called_with("setalias BOOP_ATTACK command hound at 42", false)
    assert.stub(send_stub).was_called_with("queue addclearfull freestand BOOP_ATTACK", false)
    assert.is_true(boop.state.queue.prequeuedStandard)
  end)

  it("rebuilds a queued standard as shieldbreak when the target shields after prequeue", function()
    helper.reset()
    helper.setArea("Test Area")
    helper.setClass("Occultist")
    helper.setTargetHp("80%")
    helper.learnSkill("Warp", "Occultism")
    helper.learnSkill("Hammer", "Tattoos")
    helper.setDenizens({
      { id = "42", name = "a test denizen" },
    })

    boop.config.enabled = true
    boop.config.targetingMode = "auto"
    boop.config.prequeueEnabled = true
    gmcp.Char.Vitals.bal = "0"
    gmcp.Char.Vitals.eq = "0"

    send_stub:clear()

    boop.prequeueStandard()
    boop.targets.onShielded("a test denizen")

    assert.stub(send_stub).was_called_with("setalias BOOP_ATTACK warp 42", false)
    assert.stub(send_stub).was_called_with("setalias BOOP_ATTACK touch hammer 42", false)
    assert.stub(send_stub).was_called_with("queue addclearfull freestand BOOP_ATTACK", false)
    assert.is_true(boop.state.queue.prequeuedStandard)
    assert.is_true(type(boop.state.targeting.targetShield) == "table" and boop.state.targeting.targetShield.attempted)
  end)

  it("does not prequeue attacks while gold commands are pending", function()
    gmcp.Char.Vitals.bal = "0"
    gmcp.Char.Vitals.eq = "0"
    boop.state.gold.getPending = true

    boop.prequeueStandard()

    assert.stub(send_stub).was_not_called()
    assert.is_false(boop.state.queue.prequeuedStandard)
  end)

end)
