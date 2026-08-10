local helper = dofile(os.getenv("TESTS_DIRECTORY") .. "/support/boop_test_helper.lua")

describe("boop tick", function()
  local send_stub
  local send_gmcp_stub
  local timer_stub
  local kill_timer_stub
  local save_config_stub
  local sync_enabled_stub
  local flush_gold_stub
  local walk_advance_stub
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

  local function seedOperation(owner, code, label, systems, waitsFor)
    helper.setRuntimeBlocker({
      owner = owner,
      code = code,
      label = label,
      systems = systems or { combat = true, queue = true },
      waitsFor = waitsFor or {},
    })
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

  local function scheduledEntry(timerId)
    for _, entry in ipairs(scheduled) do
      if entry.id == timerId then
        return entry
      end
    end
    return nil
  end

  local function seedGoldEvidence()
    helper.seedRoomObservation("1", {
      generation = 1,
      infoSeen = true,
      itemsSeen = true,
      acceptedItems = { goldItem("9001") },
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
    boop.onPrompt()

    if stage == "put" or stage == "put_retry" then
      assert.is_true(boop.onGoldGetSuccess())
    end
    if stage == "get_retry" or stage == "put_retry" then
      assert.is_true(boop.onGoldCommandFailure("retry fixture"))
      if stage == "get_retry" then
        boop.onPrompt()
      end
    end
    return currentOperation()
  end

  local function readyBlockedStage(stage, owner)
    local operation = startGoldStage(stage)
    helper.setRuntimeBlocker({
      owner = owner,
      code = "test_gold_hold",
      systems = { combat = true, queue = true, gold = true, walk = true },
    })

    local expiredTimer = operation.timeoutTimer
    local expiredEntry = scheduledEntry(expiredTimer)
    assert.is_table(expiredEntry)
    assert.is_function(expiredEntry.callback)
    expiredEntry.callback()

    operation = currentOperation()
    assert.is_false(
      operation.timeoutTimer,
      "TIMEOUT_UNDER_OWNER_TOKEN_NOT_CONSUMED"
    )
    assert.is_nil(boop.state.gold.pendingTimer)
    return operation, expiredTimer
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
      if not tostring(command or ""):match("^%s*$") then
        sent[#sent + 1] = {
          command = command,
          echoBack = echoBack,
        }
      end
    end)
    send_gmcp_stub = stub(_G, "sendGMCP", function(_) end)
    save_config_stub = stub(boop.db, "saveConfig", function(_, _) end)
    sync_enabled_stub = stub(boop.triggers, "syncEnabled", function() end)
  end)

  after_each(function()
    if walk_advance_stub then
      walk_advance_stub:revert()
      walk_advance_stub = nil
    end
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

  it("resynchronizes GMCP while attacking an unchanged local target", function()
    helper.setTarget("42", "a test denizen", "80%")
    gmcp.IRE.Target.Set = ""
    gmcp.IRE.Target.Info.id = "64840"

    boop.tick()

    assert.are.equal("42", boop.state.targeting.currentTargetId)
    assert.stub(send_stub).was_called_with("settarget 42", false)
    assert.stub(send_stub).was_called_with("command hound at 42", false)
    assert.stub(send_stub).was_called_with("harry 42", false)
  end)

  it("does not send attacks while gold commands are pending", function()
    boop.state.gold.getPending = true

    boop.tick()

    assert.stub(send_stub).was_not_called()
  end)

  local aggregatePairs = {
    {
      name = "interrupt plus gold",
      owners = {
        {
          owner = "interrupt:31",
          code = "interrupt_pending",
          label = "interrupt pending",
          systems = { combat = true, queue = true },
          waitsFor = { prompt = true },
        },
        {
          owner = "gold:32",
          code = "gold_pickup_pending",
          label = "gold pickup pending",
          systems = { combat = true, gold = true, queue = true, walk = true },
          waitsFor = { gold = true },
        },
      },
    },
    {
      name = "pull plus interrupt",
      owners = {
        {
          owner = "pull:33",
          code = "pull_away",
          label = "pull away",
          systems = { combat = true, queue = true, target = true, walk = true },
          waitsFor = { room = true },
        },
        {
          owner = "interrupt:34",
          code = "interrupt_pending",
          label = "interrupt pending",
          systems = { combat = true, queue = true },
          waitsFor = { prompt = true },
        },
      },
    },
    {
      name = "gold plus pull",
      owners = {
        {
          owner = "gold:34",
          code = "gold_pack_pending",
          label = "gold pack pending",
          systems = { combat = true, gold = true, queue = true, walk = true },
          waitsFor = { inventory = true },
        },
        {
          owner = "pull:35",
          code = "pull_active",
          label = "pull active",
          systems = {
            combat = true,
            queue = true,
            target = true,
            walk = true,
          },
          waitsFor = { room = true },
        },
      },
    },
  }

  for _, pairEntry in ipairs(aggregatePairs) do
    for _, firstIndex in ipairs({ 1, 2 }) do
      local pair = pairEntry
      local clearFirst = firstIndex
      local clearSecond = firstIndex == 1 and 2 or 1
      it("keeps combat effects at zero for " .. pair.name .. " when owner " .. clearFirst .. " clears first", function()
        local first = pair.owners[clearFirst]
        local second = pair.owners[clearSecond]
        boop.config.useQueueing = true
        helper.setTarget("42", "a test denizen", "80%")
        seedOperation(
          pair.owners[1].owner,
          pair.owners[1].code,
          pair.owners[1].label,
          pair.owners[1].systems,
          pair.owners[1].waitsFor
        )
        seedOperation(
          pair.owners[2].owner,
          pair.owners[2].code,
          pair.owners[2].label,
          pair.owners[2].systems,
          pair.owners[2].waitsFor
        )

        boop.tick()
        assert.are.equal(0, #sent)
        assert.are.equal(0, #scheduled)

        assert.is_true(boop.runtime.clearOperationLock(
          first.owner,
          "first lifecycle complete"
        ))
        boop.tick()

        assert.are.equal(0, #sent)
        assert.are.equal(0, #scheduled)
        assert.is_table(
          boop.runtime.state().combat.blockersByOwner[second.owner]
        )

        assert.is_true(boop.runtime.clearOperationLock(
          second.owner,
          "final lifecycle complete"
        ))
        boop.tick()

        assert.are.equal(
          1,
          countSent("setalias BOOP_ATTACK command hound at 42")
        )
        assert.are.equal(
          1,
          countSent("queue addclearfull freestand BOOP_ATTACK")
        )
        assert.are.equal(0, countSent("harry 42"))
        assert.are.equal(0, countSent("command hound at 42"))
      end)
    end
  end

  local manualReleaseCases = {
    {
      name = "disabled",
      hold = function()
        boop.ui.setEnabled(false, true)
      end,
      release = function()
        boop.ui.setEnabled(true, true)
      end,
    },
    {
      name = "manual targeting",
      hold = function()
        boop.ui.setTargetingMode("manual", true)
      end,
      release = function()
        boop.ui.setTargetingMode("auto", true)
      end,
    },
  }

  for _, releaseEntry in ipairs(manualReleaseCases) do
    local case = releaseEntry
    it("permits one fresh evaluation only after explicit " .. case.name .. " release", function()
      gmcp.Char.Vitals.bal = "0"
      gmcp.Char.Vitals.eq = "0"
      boop.state.queue.aliasAction = "existing queued action"
      boop.state.queue.aliasDirty = false
      boop.onBalanceUsed("balance", 3)
      assert.are.equal(1, #scheduled)
      local capturedPrequeue = scheduled[1].callback

      case.hold()
      capturedPrequeue()
      boop.tick()

      assert.are.equal(0, #sent)
      assert.are.equal("existing queued action", boop.state.queue.aliasAction)
      assert.is_false(boop.state.queue.prequeuedStandard)

      case.release()
      gmcp.Char.Vitals.bal = "1"
      gmcp.Char.Vitals.eq = "1"
      boop.tick()

      assert.are.equal(1, countSent("settarget 42"))
      assert.are.equal(1, countSent("command hound at 42"))
      assert.are.equal(1, countSent("harry 42"))
      assert.are.equal(0, countSent(
        "setalias BOOP_ATTACK command hound at 42"
      ))
    end)
  end

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
    { name = "pull", owner = "pull:8" },
    { name = "interrupt", owner = "interrupt:9" },
  }

  for _, ownerEntry in ipairs(ownerCases) do
    for _, stageName in ipairs(fleeStages) do
      local case = ownerEntry
      local stage = stageName
      it("timeout-under-owner resumes one unchanged " .. stage .. " stage after the current " .. case.name .. " owner clears", function()
        local operation, expiredTimer = readyBlockedStage(stage, case.owner)
        local generation = operation.generation
        local phase = operation.phase
        local getRetries = operation.getRetries
        local putRetries = operation.putRetries
        local command = phase == "pack_pending"
          and "queue add freestand put sovereigns in pack"
          or "queue add full get sovereigns"
        local sendsBeforeHold = countSent(command)
        local goldSendsBeforeHold = countGoldSends()
        local scheduledBeforeRelease = #scheduled
        local originalFlush = boop.flushPendingGold
        flush_gold_stub = stub(boop, "flushPendingGold", function(reason)
          return originalFlush(reason)
        end)
        walk_advance_stub = stub(boop.walk, "maybeAdvance", function(_)
          return true
        end)

        helper.setRuntimeBlocker({
          owner = "interrupt:remaining",
          code = "test_remaining_hold",
          systems = { combat = true, queue = true, gold = true, walk = true },
        })

        boop.tick()
        boop.runtime.clearOperationLock(
          case.owner,
          "real owner released"
        )
        boop.tick()

        assert.are.equal(sendsBeforeHold, countSent(command))
        assert.are.equal(goldSendsBeforeHold, countGoldSends())
        assert.stub(flush_gold_stub).was_not_called()
        assert.stub(walk_advance_stub).was_not_called()
        assert.are.equal(generation, currentOperation().generation)
        assert.are.equal(phase, currentOperation().phase)
        assert.are.equal(getRetries, currentOperation().getRetries)
        assert.are.equal(putRetries, currentOperation().putRetries)
        assert.is_false(currentOperation().timeoutTimer)
        assert.is_nil(boop.state.gold.pendingTimer)
        assert.are.equal(0, countSent("command hound at 42"))
        assert.are.equal(0, countSent("harry 42"))

        boop.runtime.clearOperationLock(
          "interrupt:remaining",
          "final owner released"
        )
        boop.tick()

        if phase == "pickup_pending" then
          assert.is_true(currentOperation().awaitingQueueExecution)
          assert.is_false(currentOperation().timeoutTimer)
          boop.onPrompt()
        end

        assert.stub(flush_gold_stub).was_called(1)
        assert.stub(walk_advance_stub).was_not_called()
        assert.are.equal(sendsBeforeHold + 1, countSent(command))
        assert.are.equal(goldSendsBeforeHold + 1, countGoldSends())
        assert.are.equal(generation, currentOperation().generation)
        assert.are.equal(phase, currentOperation().phase)
        assert.are.equal(getRetries, currentOperation().getRetries)
        assert.are.equal(putRetries, currentOperation().putRetries)
        assert.is_number(currentOperation().timeoutTimer)
        assert.is_true(currentOperation().timeoutTimer ~= expiredTimer)
        assert.are.equal(
          currentOperation().timeoutTimer,
          boop.state.gold.pendingTimer
        )
        assert.are.equal(scheduledBeforeRelease + 1, #scheduled)
        assert.are.equal(0, countSent("command hound at 42"))
        assert.are.equal(0, countSent("harry 42"))
      end)
    end
  end

end)
