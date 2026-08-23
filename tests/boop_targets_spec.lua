local helper = dofile(os.getenv("TESTS_DIRECTORY") .. "/support/boop_test_helper.lua")

describe("boop target selection", function()
  local tick_stub
  local save_list_stub
  local send_stub
  local timer_stub
  local kill_timer_stub
  local sent
  local scheduled

  local function countSent(command)
    local count = 0
    for _, entry in ipairs(sent or {}) do
      if entry.command == command then
        count = count + 1
      end
    end
    return count
  end

  before_each(function()
    helper.reset()
    sent = {}
    scheduled = {}
    helper.setArea("Test Area")
    helper.setDenizens({
      { id = "10", name = "goblin" },
      { id = "11", name = "orc" },
      { id = "12", name = "rat" },
    })
    send_stub = stub(_G, "send", function(command, echoBack)
      sent[#sent + 1] = {
        command = command,
        echoBack = echoBack,
      }
    end)
    timer_stub = stub(_G, "tempTimer", function(delay, callback)
      local id = 700 + #scheduled + 1
      scheduled[#scheduled + 1] = {
        id = id,
        delay = delay,
        callback = callback,
      }
      return id
    end)
    kill_timer_stub = stub(_G, "killTimer", function(_) end)
  end)

  after_each(function()
    if tick_stub then
      tick_stub:revert()
      tick_stub = nil
    end
    if save_list_stub then
      save_list_stub:revert()
      save_list_stub = nil
    end
    if send_stub then
      send_stub:revert()
      send_stub = nil
    end
    if timer_stub then
      timer_stub:revert()
      timer_stub = nil
    end
    if kill_timer_stub then
      kill_timer_stub:revert()
      kill_timer_stub = nil
    end
  end)

  it("coalesces repeated gameside target synchronization", function()
    helper.setTarget("10", "goblin")
    gmcp.IRE.Target.Set = ""
    gmcp.IRE.Target.Info.id = "99"

    for _ = 1, 5 do
      boop.targets.setTarget("10")
    end

    local sync = boop.runtime.state().targeting.gameTargetSync
    assert.are.equal(1, countSent("settarget 10"))
    assert.is_true(sync.pending)
    assert.are.equal(1, sync.attempts)
    assert.are.equal(4, sync.suppressed)
    assert.are.equal(1, #scheduled)
    assert.are.equal(0.75, scheduled[1].delay)
  end)

  it("acknowledges Target.Set and ignores delayed stale Target.Info", function()
    boop.config.enabled = true
    helper.setTarget("10", "goblin")
    gmcp.IRE.Target.Set = ""
    gmcp.IRE.Target.Info.id = "99"
    boop.targets.setTarget("10")

    gmcp.IRE.Target.Set = "10"
    boop.onTargetSet()
    gmcp.IRE.Target.Info.id = "99"
    boop.onTargetInfo()

    local sync = boop.runtime.state().targeting.gameTargetSync
    assert.are.equal("10", boop.state.targeting.currentTargetId)
    assert.are.equal("10", sync.confirmedId)
    assert.is_false(sync.pending)
    assert.are.equal(1, countSent("settarget 10"))
    assert.is_false(boop.targets.needsGameTargetSync("10"))
  end)

  it("accepts Target.Info as synchronization acknowledgement", function()
    boop.config.enabled = true
    helper.setTarget("10", "goblin")
    gmcp.IRE.Target.Set = ""
    gmcp.IRE.Target.Info.id = "99"
    boop.targets.setTarget("10")

    gmcp.IRE.Target.Info.id = "10"
    boop.onTargetInfo()

    local sync = boop.runtime.state().targeting.gameTargetSync
    assert.are.equal("10", sync.confirmedId)
    assert.is_false(sync.pending)
    assert.are.equal(1, countSent("settarget 10"))
  end)

  it("allows one target synchronization retry and then suppresses", function()
    helper.setTarget("10", "goblin")
    gmcp.IRE.Target.Set = ""
    gmcp.IRE.Target.Info.id = "99"
    boop.targets.setTarget("10")

    scheduled[1].callback()
    boop.targets.setTarget("10")
    assert.are.equal(2, countSent("settarget 10"))
    assert.are.equal(2, #scheduled)

    scheduled[2].callback()
    for _ = 1, 5 do
      boop.targets.setTarget("10")
    end

    local sync = boop.runtime.state().targeting.gameTargetSync
    assert.are.equal(2, countSent("settarget 10"))
    assert.is_true(sync.exhausted)
    assert.are.equal(2, sync.attempts)
    assert.are.equal(5, sync.suppressed)
  end)

  it("starts a fresh synchronization budget for a new target", function()
    helper.setTarget("10", "goblin")
    gmcp.IRE.Target.Set = ""
    gmcp.IRE.Target.Info.id = "99"
    boop.targets.setTarget("10")
    scheduled[1].callback()
    boop.targets.setTarget("10")
    scheduled[2].callback()

    boop.targets.setTarget("11")

    local sync = boop.runtime.state().targeting.gameTargetSync
    assert.are.equal(1, countSent("settarget 11"))
    assert.are.equal("11", sync.desiredId)
    assert.are.equal(1, sync.attempts)
    assert.is_true(sync.pending)
    assert.is_false(sync.exhausted)
  end)

  it("uses whitelist priority order when enabled", function()
    boop.config.targetingMode = "whitelist"
    boop.config.whitelistPriorityOrder = true
    helper.setWhitelist("Test Area", { "orc", "goblin" })

    assert.are.equal("11", boop.targets.choose())
  end)

  it("keeps the current valid target when retargetOnPriority is off", function()
    boop.config.targetingMode = "whitelist"
    boop.config.whitelistPriorityOrder = true
    boop.config.retargetOnPriority = false
    helper.setWhitelist("Test Area", { "orc", "goblin" })
    helper.setTarget("10", "goblin")

    assert.are.equal("10", boop.targets.choose())
  end)

  it("lets the global blacklist override whitelist eligibility", function()
    boop.config.targetingMode = "whitelist"
    boop.config.whitelistPriorityOrder = true
    helper.setWhitelist("Test Area", { "orc" })
    helper.setGlobalBlacklist({ "orc" })
    helper.setTarget("11", "orc")

    assert.are.equal("", boop.targets.choose())
    assert.is_false(boop.targets.isCurrentTargetEligible())
  end)

  it("lets the global blacklist override manual targeting", function()
    boop.config.targetingMode = "manual"
    helper.setGlobalBlacklist({ "orc" })
    helper.setTarget("11", "orc")

    assert.are.equal("", boop.targets.choose())
    assert.is_false(boop.targets.isCurrentTargetEligible())
  end)

  it("clears a newly globally blacklisted target without stopping walk", function()
    boop.config.enabled = true
    boop.config.targetingMode = "whitelist"
    helper.setWhitelist("Test Area", { "orc", "goblin" })
    helper.setTarget("11", "orc")
    boop.state.walk.active = true
    boop.state.walk.owned = true
    boop.state.walk.generation = 7
    boop.state.combat.attacking = true
    boop.state.combat.pendingStandard = "attack 11"
    boop.state.queue.prequeuedStandard = true
    boop.state.queue.aliasAction = "attack 11"
    boop.state.queue.aliasDirty = false

    local tickCalls = 0
    tick_stub = stub(boop, "tick", function()
      tickCalls = tickCalls + 1
      return false
    end)
    save_list_stub = stub(boop.db, "saveList", function() end)

    assert.is_true(boop.targets.addBlacklist("global", "orc"))

    assert.are.equal("", boop.state.targeting.currentTargetId)
    assert.are.equal("", boop.state.targeting.targetName)
    assert.is_false(boop.state.combat.attacking)
    assert.is_nil(boop.state.combat.pendingStandard)
    assert.is_false(boop.state.queue.prequeuedStandard)
    assert.are.equal("", boop.state.queue.aliasAction)
    assert.is_true(boop.state.queue.aliasDirty)
    assert.is_true(boop.state.walk.active)
    assert.is_true(boop.state.walk.owned)
    assert.are.equal(7, boop.state.walk.generation)
    assert.are.equal(1, tickCalls)
    assert.is_nil(
      boop.runtime.state().combat.blockersByOwner["target:loss"]
    )
  end)

  it("preserves an active pull target across accepted room contents", function()
    boop.config.targetingMode = "auto"
    helper.setTarget("11", "orc")
    boop.state.queue.prequeuedStandard = true
    boop.state.queue.aliasAction = "attack 11"
    boop.state.combat.pullState = {
      active = true,
      terminal = false,
      phase = "away",
    }

    boop.targets.updateRoomItems({}, {
      applicationId = 2,
      roomId = "2",
      observationGeneration = 2,
    })

    assert.are.equal("11", boop.state.targeting.currentTargetId)
    assert.are.equal("orc", boop.state.targeting.targetName)
    assert.is_true(boop.state.queue.prequeuedStandard)
    assert.are.equal("attack 11", boop.state.queue.aliasAction)
  end)
end)
