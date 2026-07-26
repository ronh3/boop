local helper = dofile(os.getenv("TESTS_DIRECTORY") .. "/support/boop_test_helper.lua")

describe("boop tick", function()
  local send_stub
  local send_gmcp_stub
  local timer_stub
  local kill_timer_stub
  local save_config_stub
  local sync_enabled_stub
  local flush_gold_stub
  local sent
  local scheduled

  local function goldItem(id)
    return {
      id = tostring(id or "9001"),
      name = "some gold sovereigns",
      attrib = "t",
    }
  end

  local function countSent(command)
    local count = 0
    for _, entry in ipairs(sent) do
      if entry.command == command then
        count = count + 1
      end
    end
    return count
  end

  local function countGoldSends(fromIndex)
    local count = 0
    for index = fromIndex or 1, #sent do
      if tostring(sent[index].command or ""):find("sovereigns", 1, true) then
        count = count + 1
      end
    end
    return count
  end

  local function currentOperation()
    assert.is_table(boop.state.gold.operation)
    return boop.state.gold.operation
  end

  local function seedGoldEvidence()
    helper.seedRoomObservation("1", {
      generation = 1,
      infoSeen = true,
      itemsSeen = true,
    })
    gmcp.Char.Items.List = {
      location = "room",
      items = { goldItem("9001") },
    }
    boop.config.autoGrabGold = true
    boop.config.useQueueing = false
  end

  local function startGoldStage(stage)
    seedGoldEvidence()
    boop.config.goldPack = (stage == "initial_get" or stage == "get_retry")
      and ""
      or "pack"
    boop.onGoldDropLine("A handful of sovereigns spills onto the ground.")

    if stage == "put" or stage == "put_retry" then
      assert.is_true(boop.onGoldGetSuccess())
    end
    if stage == "get_retry" or stage == "put_retry" then
      assert.is_true(boop.onGoldCommandFailure("retry fixture"))
    end
    return currentOperation()
  end

  local function readyBlockedStage(stage, owner)
    seedGoldEvidence()
    boop.config.goldPack = (stage == "initial_get" or stage == "get_retry")
      and ""
      or "pack"

    if stage == "initial_get" then
      helper.setRuntimeBlocker({
        owner = owner,
        code = "test_gold_hold",
        systems = { combat = true, queue = true, gold = true, walk = true },
      })
      boop.onGoldDropLine("A handful of sovereigns spills onto the ground.")
    else
      boop.onGoldDropLine("A handful of sovereigns spills onto the ground.")
      if stage == "put" or stage == "put_retry" then
        boop.onGoldGetSuccess()
      end
      if stage == "get_retry" or stage == "put_retry" then
        boop.onGoldCommandFailure("retry fixture")
        local operation = currentOperation()
        operation.timeoutTimer = false
        boop.markGoldQueueIntent(operation.packTarget)
      end
      helper.setRuntimeBlocker({
        owner = owner,
        code = "test_gold_hold",
        systems = { combat = true, queue = true, gold = true, walk = true },
      })
      if stage == "put" then
        local operation = currentOperation()
        operation.timeoutTimer = false
        boop.markGoldQueueIntent(operation.packTarget)
      end
    end
    return currentOperation()
  end

  before_each(function()
    helper.reset()
    sent = {}
    scheduled = {}
    helper.setArea("Test Area")
    helper.setClass("Occultist")
    helper.setTargetHp("80%")
    helper.setRage(14)
    helper.learnSkills({
      { name = "Lycantha", group = "Domination" },
      { name = "Warp", group = "Occultism" },
      { name = "harry", group = "Attainment" },
    })
    helper.setDenizens({
      { id = "42", name = "a test denizen" },
    })

    boop.config.enabled = true
    boop.config.targetingMode = "auto"
    boop.config.attackMode = "simple"

    timer_stub = stub(_G, "tempTimer", function(delay, callback)
      local id = 300 + #scheduled + 1
      scheduled[#scheduled + 1] = {
        id = id,
        delay = delay,
        callback = callback,
      }
      return id
    end)
    kill_timer_stub = stub(_G, "killTimer", function(_) end)
    send_stub = stub(_G, "send", function(command, echoBack)
      sent[#sent + 1] = {
        command = command,
        echoBack = echoBack,
      }
    end)
    send_gmcp_stub = stub(_G, "sendGMCP", function(_) end)
    save_config_stub = stub(boop.db, "saveConfig", function(_, _) end)
    sync_enabled_stub = stub(boop.triggers, "syncEnabled", function() end)
  end)

  after_each(function()
    if flush_gold_stub then
      flush_gold_stub:revert()
      flush_gold_stub = nil
    end
    if sync_enabled_stub then
      sync_enabled_stub:revert()
      sync_enabled_stub = nil
    end
    if save_config_stub then
      save_config_stub:revert()
      save_config_stub = nil
    end
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
  end)

  it("targets the denizen and sends standard plus rage actions", function()
    boop.tick()

    assert.stub(send_stub).was_called_with("settarget 42", false)
    assert.stub(send_stub).was_called_with("command hound at 42", false)
    assert.stub(send_stub).was_called_with("harry 42", false)
  end)

  it("does not send attacks while gold commands are pending", function()
    boop.state.gold.getPending = true

    boop.tick()

    assert.stub(send_stub).was_not_called()
  end)

  local fleeStages = {
    "initial_get",
    "put",
    "get_retry",
    "put_retry",
  }

  for _, stageName in ipairs(fleeStages) do
    local stage = stageName
    it("destructively cancels " .. stage .. " gold during the real auto-flee path", function()
      local operation = startGoldStage(stage)
      local generation = operation.generation
      local owner = operation.blockerOwner
      local callbacks = {}
      for _, entry in ipairs(scheduled) do
        callbacks[#callbacks + 1] = entry.callback
      end
      local firstFleeSend = #sent + 1
      local originalFlush = boop.flushPendingGold
      flush_gold_stub = stub(boop, "flushPendingGold", function(reason)
        return originalFlush(reason)
      end)

      gmcp.Char.Vitals.hp = 1000
      gmcp.Char.Vitals.maxhp = 5000
      boop.config.fleeEnabled = true
      boop.config.fleeAt = "30%"
      boop.state.targeting.lastRoomDir = "north"

      boop.tick()

      assert.is_false(boop.config.enabled)
      assert.is_false(boop.state.gold.operation)
      assert.is_nil(boop.state.combat.blockersByOwner[owner])
      assert.are.equal(generation, boop.state.gold.generation)
      assert.are.equal(0, boop.state.gold.getRetries)
      assert.are.equal(0, boop.state.gold.putRetries)
      assert.is_nil(boop.state.gold.pendingTimer)
      assert.are.equal(0, countGoldSends(firstFleeSend))
      assert.stub(flush_gold_stub).was_not_called()

      for _, callback in ipairs(callbacks) do
        callback()
      end

      assert.is_false(boop.config.enabled)
      assert.is_false(boop.state.gold.operation)
      assert.are.equal(0, countGoldSends(firstFleeSend))
      assert.stub(flush_gold_stub).was_not_called()

      boop.ui.setEnabled(true, true)
      assert.is_true(boop.config.enabled)
    end)
  end

  local ownerCases = {
    { name = "GMCP", owner = "gmcp:ire" },
    { name = "room", owner = "room:observation" },
    { name = "pull", owner = "pull:8" },
    { name = "interrupt", owner = "interrupt:9" },
  }

  for _, ownerEntry in ipairs(ownerCases) do
    for _, stageName in ipairs(fleeStages) do
      local case = ownerEntry
      local stage = stageName
      it("resumes one unchanged " .. stage .. " stage after the current " .. case.name .. " owner clears", function()
        local operation = readyBlockedStage(stage, case.owner)
        local generation = operation.generation
        local phase = operation.phase
        local getRetries = operation.getRetries
        local putRetries = operation.putRetries
        local command = phase == "pack_pending"
          and "queue add freestand put sovereigns in pack"
          or "queue add freestand get sovereigns"
        local sendsBeforeHold = countSent(command)
        local originalFlush = boop.flushPendingGold
        flush_gold_stub = stub(boop, "flushPendingGold", function(reason)
          return originalFlush(reason)
        end)

        helper.setRuntimeBlocker({
          owner = "test:remaining",
          code = "test_remaining_hold",
          systems = { combat = true, queue = true, gold = true, walk = true },
        })

        boop.tick()
        boop.runtime.clearBlocker(case.owner, "real owner released")
        boop.tick()

        assert.are.equal(sendsBeforeHold, countSent(command))
        assert.stub(flush_gold_stub).was_not_called()
        assert.are.equal(generation, currentOperation().generation)
        assert.are.equal(phase, currentOperation().phase)
        assert.are.equal(getRetries, currentOperation().getRetries)
        assert.are.equal(putRetries, currentOperation().putRetries)

        boop.runtime.clearBlocker("test:remaining", "final owner released")
        boop.tick()

        assert.stub(flush_gold_stub).was_called(1)
        assert.are.equal(sendsBeforeHold + 1, countSent(command))
        assert.are.equal(generation, currentOperation().generation)
        assert.are.equal(phase, currentOperation().phase)
        assert.are.equal(getRetries, currentOperation().getRetries)
        assert.are.equal(putRetries, currentOperation().putRetries)
        assert.are.equal(0, countSent("command hound at 42"))
        assert.are.equal(0, countSent("harry 42"))
      end)
    end
  end

end)
