local helper = dofile(os.getenv("TESTS_DIRECTORY") .. "/support/boop_test_helper.lua")

describe("boop generation-owned gold retry handling", function()
  local send_stub
  local send_gmcp_stub
  local err_stub
  local warn_stub
  local trace_stub
  local timer_stub
  local kill_timer_stub
  local raise_event_stub
  local clear_blocker_stub
  local tick_stub
  local sent
  local scheduled
  local raised_events
  local traces
  local warnings
  local tick_count
  local native_queue
  local timer_queue

  local function goldItem(id)
    return {
      id = tostring(id or "9001"),
      name = "some gold sovereigns",
      attrib = "t",
    }
  end

  local function copyOperation(operation)
    if type(operation) ~= "table" then
      return operation
    end
    return {
      generation = operation.generation,
      phase = operation.phase,
      terminal = operation.terminal,
      blockerOwner = operation.blockerOwner,
      source = operation.source,
      roomId = operation.roomId,
      roomGeneration = operation.roomGeneration,
      goldItemId = operation.goldItemId,
      packTarget = operation.packTarget,
      getRetries = operation.getRetries,
      putRetries = operation.putRetries,
      flushTimer = operation.flushTimer,
      timeoutTimer = operation.timeoutTimer,
    }
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

  local function countSent(command)
    local count = 0
    for _, entry in ipairs(sent) do
      if entry.command == command then
        count = count + 1
      end
    end
    return count
  end

  local function countRaised(name)
    local count = 0
    for _, event in ipairs(raised_events) do
      if event.name == name then
        count = count + 1
      end
    end
    return count
  end

  local function countTrace(fragment)
    local count = 0
    for _, message in ipairs(traces) do
      if tostring(message):find(fragment, 1, true) then
        count = count + 1
      end
    end
    return count
  end

  local function countWarning(fragment)
    local count = 0
    for _, message in ipairs(warnings) do
      if tostring(message):find(fragment, 1, true) then
        count = count + 1
      end
    end
    return count
  end

  local function runDiagResultTrigger()
    dofile(
      os.getenv("TESTS_DIRECTORY")
        .. "/../src/triggers/boop/Diag/Diag_Result_Perfect.lua"
    )
  end

  local function startPickup(pack, roomId, roomGeneration)
    local room = tostring(roomId or "1")
    local items = { goldItem("9001") }
    gmcp.Room.Info.num = room
    helper.seedRoomObservation(room, {
      generation = roomGeneration or 1,
      infoSeen = true,
      itemsSeen = true,
      acceptedItems = items,
    })
    gmcp.Char.Items.List = {
      location = "room",
      items = items,
    }
    boop.config.goldPack = pack or ""
    boop.onGoldDropLine("A handful of sovereigns spills onto the ground.")
    return currentOperation()
  end

  local function addGoldBlocker(owner)
    helper.setRuntimeBlocker({
      owner = owner,
      code = owner == "flee:active" and "flee_active" or "test_gold_hold",
      systems = {
        combat = true,
        queue = true,
        gold = true,
        walk = true,
      },
    })
  end

  before_each(function()
    helper.reset()
    sent = {}
    scheduled = {}
    raised_events = {}
    traces = {}
    warnings = {}
    tick_count = 0
    native_queue = helper.newNativeQueue()
    timer_queue = helper.newTimerQueue()
    boop.config.enabled = true
    boop.config.autoGrabGold = true
    boop.config.useQueueing = false

    send_stub = stub(_G, "send", function(command, echoBack)
      sent[#sent + 1] = {
        command = command,
        echoBack = echoBack,
      }
      native_queue.send(command, echoBack)
    end)
    send_gmcp_stub = stub(_G, "sendGMCP", function(_) end)
    err_stub = stub(boop.util, "err", function(_) end)
    warn_stub = stub(boop.util, "warn", function(message)
      warnings[#warnings + 1] = message
    end)
    trace_stub = stub(boop.trace, "log", function(message)
      traces[#traces + 1] = message
    end)
    timer_stub = stub(_G, "tempTimer", function(delay, callback)
      local id = timer_queue.tempTimer(delay, callback)
      scheduled[#scheduled + 1] = {
        id = id,
        delay = delay,
        callback = callback,
      }
      return id
    end)
    kill_timer_stub = stub(_G, "killTimer", function(id)
      return timer_queue.killTimer(id)
    end)
    raise_event_stub = stub(_G, "raiseEvent", function(name, ...)
      raised_events[#raised_events + 1] = {
        name = name,
        args = { ... },
      }
    end)
    local originalTick = boop.tick
    tick_stub = stub(boop, "tick", function(...)
      tick_count = tick_count + 1
      return originalTick(...)
    end)
  end)

  after_each(function()
    if send_stub then send_stub:revert() send_stub = nil end
    if send_gmcp_stub then send_gmcp_stub:revert() send_gmcp_stub = nil end
    if err_stub then err_stub:revert() err_stub = nil end
    if warn_stub then warn_stub:revert() warn_stub = nil end
    if trace_stub then trace_stub:revert() trace_stub = nil end
    if timer_stub then timer_stub:revert() timer_stub = nil end
    if kill_timer_stub then kill_timer_stub:revert() kill_timer_stub = nil end
    if raise_event_stub then raise_event_stub:revert() raise_event_stub = nil end
    if clear_blocker_stub then clear_blocker_stub:revert() clear_blocker_stub = nil end
    if tick_stub then tick_stub:revert() tick_stub = nil end
  end)

  it("models native global queue replacement and rejects a nameless clear", function()
    assert.is_true(native_queue.apply("queue add full get sovereigns"))
    assert.are.same({
      full = { "get sovereigns" },
    }, native_queue.snapshot())

    assert.is_true(native_queue.apply("clearqueue all"))
    assert.are.same({}, native_queue.snapshot())

    assert.is_true(native_queue.apply(
      "queue addclearfull freestand diagnose"
    ))
    assert.are.same({
      freestand = { "diagnose" },
    }, native_queue.snapshot())

    assert.is_false(native_queue.apply("queue clear"))
    assert.are.same({
      {
        command = "queue clear",
        message = "queue name is required",
      },
    }, native_queue.errorsSnapshot())
  end)

  it("retries get under its exact owner and exhausts at the existing limit", function()
    startPickup("")

    boop.onGoldCommandFailure("missing sovereigns")

    assert.are.equal(2, #sent)
    assert.are.equal("queue add full get sovereigns", sent[2].command)
    assert.are.equal(1, currentOperation().getRetries)

    boop.onGoldCommandFailure("still missing sovereigns")
    assert.are.equal(3, #sent)
    assert.are.equal(2, currentOperation().getRetries)

    boop.onGoldCommandFailure("gone")
    assert.is_false(boop.state.gold.operation)
    assert.are.equal(3, #sent)
    assert.stub(err_stub).was_called_with("auto gold: unable to get sovereigns; check room loot/line timing")
  end)

  it("keeps inventory-owned put retry live across movement and exhausts at the existing limit", function()
    startPickup("pack")
    boop.onGoldGetSuccess()

    gmcp.Room.Info = {
      area = "TEST",
      num = 2,
      exits = {},
    }
    boop.onRoomInfo()
    local sendsBeforeRetry = #sent

    boop.onGoldCommandFailure("pack closed")

    assert.are.equal(sendsBeforeRetry + 1, #sent)
    assert.are.equal(
      "queue add freestand put sovereigns in pack",
      sent[#sent].command
    )
    assert.are.equal(1, currentOperation().putRetries)

    gmcp.Char.Items.List = {
      location = "inv",
      items = {},
    }
    boop.onRoomItemsList()
    gmcp.Char.Items.List = {
      location = "room",
      items = {},
    }
    boop.onRoomItemsList()
    local roomApplication = scheduled[#scheduled]
    assert.is_table(roomApplication)
    assert.are.equal(0, roomApplication.delay)
    roomApplication.callback()

    assert.are.equal(sendsBeforeRetry + 1, #sent)
    assert.are.equal("pack_pending", currentOperation().phase)
    assert.are.equal(1, currentOperation().putRetries)

    boop.onGoldCommandFailure("still closed")
    assert.is_false(boop.state.gold.operation)
    assert.are.equal(sendsBeforeRetry + 1, #sent)
    assert.stub(err_stub).was_called_with("auto gold: unable to put sovereigns in pack; use `boop pack test`")
  end)

  it("does not consume get retries while another operation holds gold", function()
    local owners = {
      "pull:8",
      "interrupt:9",
    }

    for _, owner in ipairs(owners) do
      helper.reset()
      sent = {}
      scheduled = {}
      boop.config.enabled = true
      boop.config.autoGrabGold = true
      boop.config.useQueueing = false
      startPickup("")
      addGoldBlocker(owner)
      local before = copyOperation(currentOperation())
      local sendCount = #sent

      boop.onGoldCommandFailure("blocked retry")

      assert.are.same(before, copyOperation(currentOperation()))
      assert.are.equal(sendCount, #sent)
    end
  end)

  it("does not consume put retries while another operation holds gold", function()
    local owners = {
      "pull:8",
      "interrupt:9",
    }

    for _, owner in ipairs(owners) do
      helper.reset()
      sent = {}
      scheduled = {}
      boop.config.enabled = true
      boop.config.autoGrabGold = true
      boop.config.useQueueing = false
      startPickup("pack")
      boop.onGoldGetSuccess()
      addGoldBlocker(owner)
      local before = copyOperation(currentOperation())
      local sendCount = #sent

      boop.onGoldCommandFailure("blocked retry")

      assert.are.same(before, copyOperation(currentOperation()))
      assert.are.equal(sendCount, #sent)
    end
  end)

  local timeoutUnderOwnerCases = {
    {
      name = "pickup",
      command = "queue add full get sovereigns",
      queueName = "full",
      queueCommand = "get sovereigns",
      start = function()
        return startPickup("")
      end,
      assertOwnership = function(operation)
        assert.are.equal("1", operation.roomId)
        assert.are.equal(1, operation.roomGeneration)
        assert.are.equal("9001", operation.goldItemId)
      end,
    },
    {
      name = "packing",
      command = "queue add freestand put sovereigns in pack",
      queueName = "freestand",
      queueCommand = "put sovereigns in pack",
      start = function()
        startPickup("pack")
        assert.is_true(boop.onGoldGetSuccess())
        return currentOperation()
      end,
      assertOwnership = function(operation)
        assert.are.equal("", operation.roomId)
        assert.are.equal(0, operation.roomGeneration)
        assert.are.equal("", operation.goldItemId)
        assert.are.equal("pack", operation.packTarget)
      end,
    },
  }

  for _, entry in ipairs(timeoutUnderOwnerCases) do
    local case = entry
    it("timeout-under-owner " .. case.name .. " consumes fired token", function()
      local operation = case.start()
      local expiredTimer = operation.timeoutTimer
      local expiredEntry = scheduledEntry(expiredTimer)
      assert.is_table(expiredEntry)
      assert.is_function(expiredEntry.callback)
      addGoldBlocker("interrupt:timeout-hold")

      local generation = operation.generation
      local phase = operation.phase
      local owner = operation.blockerOwner
      local getRetries = operation.getRetries
      local putRetries = operation.putRetries
      local sendsBeforeTimeout = #sent
      local commandCountBeforeTimeout = countSent(case.command)
      local scheduledBeforeTimeout = #scheduled

      expiredEntry.callback()

      operation = currentOperation()
      assert.is_false(
        operation.timeoutTimer,
        "TIMEOUT_UNDER_OWNER_TOKEN_NOT_CONSUMED"
      )
      assert.is_nil(boop.state.gold.pendingTimer)
      assert.are.equal(generation, operation.generation)
      assert.are.equal(phase, operation.phase)
      assert.are.equal(owner, operation.blockerOwner)
      assert.are.equal(getRetries, operation.getRetries)
      assert.are.equal(putRetries, operation.putRetries)
      case.assertOwnership(operation)
      assert.are.equal(sendsBeforeTimeout, #sent)
      assert.are.equal(scheduledBeforeTimeout, #scheduled)
      assert.are.equal(0, countRaised("demonwalker.move"))

      local afterFirstCallback = copyOperation(operation)
      expiredEntry.callback()

      assert.are.same(afterFirstCallback, copyOperation(currentOperation()))
      assert.are.equal(sendsBeforeTimeout, #sent)
      assert.are.equal(scheduledBeforeTimeout, #scheduled)
      assert.are.equal(0, countRaised("demonwalker.move"))

      assert.is_true(boop.runtime.clearBlocker(
        "interrupt:timeout-hold",
        "timeout-under-owner released"
      ))
      boop.tick()

      operation = currentOperation()
      assert.are.equal(sendsBeforeTimeout + 1, #sent)
      assert.are.equal(
        commandCountBeforeTimeout + 1,
        countSent(case.command)
      )
      assert.are.equal(scheduledBeforeTimeout + 1, #scheduled)
      assert.is_number(operation.timeoutTimer)
      assert.is_true(operation.timeoutTimer ~= expiredTimer)
      assert.are.equal(operation.timeoutTimer, boop.state.gold.pendingTimer)
      assert.are.equal(generation, operation.generation)
      assert.are.equal(phase, operation.phase)
      assert.are.equal(owner, operation.blockerOwner)
      assert.are.equal(getRetries, operation.getRetries)
      assert.are.equal(putRetries, operation.putRetries)
      case.assertOwnership(operation)
      assert.are.equal(0, countRaised("demonwalker.move"))
    end)
  end

  local displacementCases = {
    {
      name = "pickup",
      command = "queue add full get sovereigns",
      queueName = "full",
      queueCommand = "get sovereigns",
      warning = "auto gold: replayed pickup timed out; move or disable/flee to cancel",
      start = function()
        local operation = startPickup("pack")
        operation.getRetries = 1
        boop.markGoldQueueIntent(operation.packTarget)
        return operation
      end,
      assertEvidence = function(operation)
        assert.are.equal("1", operation.roomId)
        assert.are.equal(1, operation.roomGeneration)
        assert.are.equal("9001", operation.goldItemId)
        assert.are.equal(1, operation.getRetries)
      end,
      invalidate = function()
        gmcp.Room.Info = {
          area = "TEST",
          num = 2,
          exits = {},
        }
        boop.onRoomInfo()
      end,
    },
    {
      name = "pack",
      command = "queue add freestand put sovereigns in pack",
      queueName = "freestand",
      queueCommand = "put sovereigns in pack",
      warning = "auto gold: replayed pack timed out; provide result/failure evidence or disable/flee to cancel",
      start = function()
        startPickup("pack")
        assert.is_true(boop.onGoldGetSuccess())
        return currentOperation()
      end,
      assertEvidence = function(operation)
        assert.are.equal("", operation.roomId)
        assert.are.equal(0, operation.roomGeneration)
        assert.are.equal("", operation.goldItemId)
        assert.are.equal("pack", operation.packTarget)
        assert.are.equal(0, operation.putRetries)
      end,
      invalidate = function()
        boop.ui.setEnabled(false)
      end,
    },
  }

  local displacementOrderings = {
    {
      name = "old timeout before interrupt release",
      run = function(oldTimeout, interruptOwner)
        oldTimeout()
        assert.is_true(boop.runtime.clearBlocker(
          interruptOwner,
          "synthetic interrupt released"
        ))
        boop.tick()
      end,
    },
    {
      name = "interrupt release and replay before old timeout",
      run = function(oldTimeout, interruptOwner)
        assert.is_true(boop.runtime.clearBlocker(
          interruptOwner,
          "synthetic interrupt released"
        ))
        boop.tick()
        oldTimeout()
      end,
    },
  }

  for _, stageEntry in ipairs(displacementCases) do
    local stage = stageEntry
    for _, orderingEntry in ipairs(displacementOrderings) do
      local ordering = orderingEntry
      it("holds displaced " .. stage.name .. " after " .. ordering.name, function()
        local operation = stage.start()
        local generation = operation.generation
        local phase = operation.phase
        local goldOwner = operation.blockerOwner
        local originalTimer = operation.timeoutTimer
        local oldTimeout = timer_queue.callback(originalTimer)
        local initialCommandCount = countSent(stage.command)
        local interruptOwner = "interrupt:gold-displacement"
        assert.is_function(oldTimeout)
        assert.are.equal(1, initialCommandCount)

        addGoldBlocker(interruptOwner)
        assert.is_true(boop.displaceGoldQueueIntent(
          interruptOwner,
          "synthetic native queue replacement"
        ))
        assert.is_true(timer_queue.cancelled[originalTimer])
        assert.is_false(operation.timeoutTimer)
        assert.are.equal(interruptOwner, operation.displacedByOwner)
        assert.are.equal(phase, operation.displacedPhase)
        assert.is_true(operation.replayPending)
        assert.are.equal(goldOwner, operation.blockerOwner)
        assert.are.equal(generation, operation.generation)
        stage.assertEvidence(operation)

        native_queue.apply("clearqueue all")
        assert.are.same({}, native_queue.snapshot())
        boop.tick()
        assert.are.equal(initialCommandCount, countSent(stage.command))

        ordering.run(oldTimeout, interruptOwner)

        operation = currentOperation()
        assert.are.equal(initialCommandCount + 1, countSent(stage.command))
        assert.are.equal(generation, operation.generation)
        assert.are.equal(phase, operation.phase)
        assert.are.equal(goldOwner, operation.blockerOwner)
        assert.are.equal("displacement_replay", operation.dispatchProvenance)
        assert.is_false(operation.replayPending)
        assert.is_nil(operation.displacedByOwner)
        assert.is_nil(operation.displacedPhase)
        stage.assertEvidence(operation)
        assert.are.same({
          [stage.queueName] = { stage.queueCommand },
        }, native_queue.snapshot())

        local freshTimer = operation.timeoutTimer
        local freshTimeout = timer_queue.callback(freshTimer)
        local timersBeforeFreshTimeout = #scheduled
        local sendsBeforeFreshTimeout = #sent
        assert.is_function(freshTimeout)
        assert.is_true(freshTimer ~= originalTimer)

        freshTimeout()

        operation = currentOperation()
        assert.is_false(operation.timeoutTimer)
        assert.is_true(operation.awaitingExplicitEvidence)
        assert.are.equal(generation, operation.generation)
        assert.are.equal(phase, operation.phase)
        assert.are.equal(goldOwner, operation.blockerOwner)
        assert.are.equal("displacement_replay", operation.dispatchProvenance)
        stage.assertEvidence(operation)
        local blocker = boop.state.combat.blockersByOwner[goldOwner]
        assert.is_table(blocker)
        assert.is_truthy(blocker.label:find("awaiting explicit evidence", 1, true))
        assert.stub(warn_stub).was_called_with(stage.warning)

        boop.tick()
        freshTimeout()
        oldTimeout()
        boop.tick()

        assert.are.equal(sendsBeforeFreshTimeout, #sent)
        assert.are.equal(timersBeforeFreshTimeout, #scheduled)
        assert.are.equal(initialCommandCount + 1, countSent(stage.command))
        assert.is_true(currentOperation().awaitingExplicitEvidence)
        assert.stub(warn_stub).was_called(1)
        assert.are.equal(
          1,
          countTrace("gold replay timeout: " .. stage.name)
        )
        assert.are.equal(0, countTrace("reason=pending_timeout"))

        local clearCount = 0
        local originalClearBlocker = boop.runtime.clearBlocker
        clear_blocker_stub = stub(boop.runtime, "clearBlocker", function(owner, reason)
          local cleared = originalClearBlocker(owner, reason)
          if owner == goldOwner and cleared then
            clearCount = clearCount + 1
          end
          return cleared
        end)

        stage.invalidate()
        stage.invalidate()
        freshTimeout()
        oldTimeout()

        assert.is_false(boop.state.gold.operation)
        assert.is_nil(boop.state.combat.blockersByOwner[goldOwner])
        assert.are.equal(1, clearCount)
      end)
    end
  end

  local diagTerminalCases = {
    {
      name = "prompt/result",
      complete = function(_)
        runDiagResultTrigger()
        boop.onPrompt()
      end,
      late = function(diagTimeout)
        diagTimeout()
      end,
    },
    {
      name = "timeout",
      complete = function(diagTimeout)
        diagTimeout()
      end,
      late = function()
        runDiagResultTrigger()
        boop.onPrompt()
      end,
    },
  }

  local oldGoldTimeoutOrderings = {
    {
      name = "old gold timeout before release",
      beforeRelease = true,
    },
    {
      name = "old gold timeout after release",
      beforeRelease = false,
    },
  }

  for _, stageEntry in ipairs(displacementCases) do
    local stage = stageEntry
    for _, terminalEntry in ipairs(diagTerminalCases) do
      local terminal = terminalEntry
      for _, orderingEntry in ipairs(oldGoldTimeoutOrderings) do
        local ordering = orderingEntry
        it(
          "real diag preserves "
            .. stage.name
            .. " through "
            .. terminal.name
            .. " with "
            .. ordering.name,
          function()
            local operation = stage.start()
            local generation = operation.generation
            local phase = operation.phase
            local goldOwner = operation.blockerOwner
            local originalTimer = operation.timeoutTimer
            local oldGoldTimeout = timer_queue.callback(originalTimer)
            local initialCommandCount = countSent(stage.command)
            assert.is_function(oldGoldTimeout)
            assert.are.equal(1, initialCommandCount)

            boop.ui.diag()
            local diagOperation = boop.state.diag.operation
            local interruptOwner = diagOperation.blockerOwner
            local diagTimeout = timer_queue.callback(
              diagOperation.timeoutTimer
            )
            assert.is_function(diagTimeout)
            assert.are.equal(interruptOwner, operation.displacedByOwner)
            assert.are.equal(phase, operation.displacedPhase)
            assert.is_true(operation.replayPending)
            assert.is_false(operation.timeoutTimer)
            assert.is_true(timer_queue.cancelled[originalTimer])
            stage.assertEvidence(operation)
            assert.are.same({
              freestand = { "diagnose" },
            }, native_queue.snapshot())
            assert.are.same({}, native_queue.errorsSnapshot())
            assert.are.equal(
              "clearqueue all",
              native_queue.commands[#native_queue.commands - 1]
            )
            assert.are.equal(
              "queue addclearfull freestand diagnose",
              native_queue.commands[#native_queue.commands]
            )

            if ordering.beforeRelease then
              oldGoldTimeout()
            end

            local ticksBeforeRelease = tick_count
            terminal.complete(diagTimeout)
            assert.are.equal(ticksBeforeRelease + 1, tick_count)

            operation = currentOperation()
            assert.are.equal(
              initialCommandCount + 1,
              countSent(stage.command)
            )
            assert.are.equal(generation, operation.generation)
            assert.are.equal(phase, operation.phase)
            assert.are.equal(goldOwner, operation.blockerOwner)
            assert.are.equal(
              "displacement_replay",
              operation.dispatchProvenance
            )
            assert.is_false(operation.replayPending)
            assert.is_nil(operation.displacedByOwner)
            assert.is_nil(operation.displacedPhase)
            stage.assertEvidence(operation)

            if not ordering.beforeRelease then
              oldGoldTimeout()
            end
            terminal.late(diagTimeout)

            assert.are.equal(ticksBeforeRelease + 1, tick_count)
            assert.are.equal(
              initialCommandCount + 1,
              countSent(stage.command)
            )
            assert.is_nil(boop.state.combat.blockersByOwner[interruptOwner])

            local freshTimer = operation.timeoutTimer
            local freshTimeout = timer_queue.callback(freshTimer)
            local timersBeforeFreshTimeout = #scheduled
            local sendsBeforeFreshTimeout = #sent
            assert.is_function(freshTimeout)
            assert.is_true(freshTimer ~= originalTimer)

            freshTimeout()

            operation = currentOperation()
            assert.is_false(operation.timeoutTimer)
            assert.is_true(operation.awaitingExplicitEvidence)
            assert.are.equal(generation, operation.generation)
            assert.are.equal(phase, operation.phase)
            assert.are.equal(goldOwner, operation.blockerOwner)
            stage.assertEvidence(operation)
            local blocker = boop.state.combat.blockersByOwner[goldOwner]
            assert.is_table(blocker)
            assert.is_truthy(
              blocker.label:find(
                "awaiting explicit evidence",
                1,
                true
              )
            )

            boop.tick()
            freshTimeout()
            oldGoldTimeout()
            terminal.late(diagTimeout)
            boop.tick()

            assert.are.equal(sendsBeforeFreshTimeout, #sent)
            assert.are.equal(timersBeforeFreshTimeout, #scheduled)
            assert.are.equal(
              initialCommandCount + 1,
              countSent(stage.command)
            )
            assert.is_true(currentOperation().awaitingExplicitEvidence)
            assert.are.equal(1, countWarning(stage.warning))
            assert.are.equal(
              1,
              countTrace("gold replay timeout: " .. stage.name)
            )
            assert.are.equal(0, countTrace("reason=pending_timeout"))

            local clearCount = 0
            local originalClearBlocker = boop.runtime.clearBlocker
            clear_blocker_stub = stub(
              boop.runtime,
              "clearBlocker",
              function(owner, reason)
                local cleared = originalClearBlocker(owner, reason)
                if owner == goldOwner and cleared then
                  clearCount = clearCount + 1
                end
                return cleared
              end
            )

            stage.invalidate()
            stage.invalidate()
            freshTimeout()
            oldGoldTimeout()
            terminal.late(diagTimeout)

            assert.is_false(boop.state.gold.operation)
            assert.is_nil(boop.state.combat.blockersByOwner[goldOwner])
            assert.are.equal(1, clearCount)
            assert.are.equal(
              1,
              countTrace("gold terminal: " .. goldOwner)
            )
          end
        )
      end
    end
  end

  it("real diag replay advances pickup through explicit get and put evidence", function()
    local operation = startPickup("pack")
    local oldGoldTimeout = timer_queue.callback(operation.timeoutTimer)
    boop.ui.diag()
    local diagOperation = boop.state.diag.operation
    local diagTimeout = timer_queue.callback(diagOperation.timeoutTimer)

    oldGoldTimeout()
    runDiagResultTrigger()
    boop.onPrompt()
    diagTimeout()

    assert.are.equal(2, countSent("queue add full get sovereigns"))
    assert.is_true(boop.onGoldGetSuccess())
    assert.are.equal("pack_pending", currentOperation().phase)
    assert.are.equal(
      1,
      countSent("queue add freestand put sovereigns in pack")
    )
    assert.is_true(boop.onGoldPutSuccess())
    assert.is_false(boop.state.gold.operation)
    assert.is_false(boop.state.diag.operation)
    assert.are.same({}, boop.state.diag.evidenceQueue)
  end)

  for _, stageEntry in ipairs(displacementCases) do
    local stage = stageEntry
    it("allows explicit failure to retry timed-out replayed " .. stage.name, function()
      local operation = stage.start()
      local interruptOwner = "interrupt:gold-failure"
      addGoldBlocker(interruptOwner)
      assert.is_true(boop.displaceGoldQueueIntent(
        interruptOwner,
        "synthetic native queue replacement"
      ))
      native_queue.apply("clearqueue all")
      assert.is_true(boop.runtime.clearBlocker(
        interruptOwner,
        "synthetic interrupt released"
      ))
      boop.tick()

      operation = currentOperation()
      local freshTimeout = timer_queue.callback(operation.timeoutTimer)
      local commandCountBeforeFailure = countSent(stage.command)
      assert.is_function(freshTimeout)
      freshTimeout()
      assert.is_true(currentOperation().awaitingExplicitEvidence)

      assert.is_true(boop.onGoldCommandFailure("explicit command failure"))

      operation = currentOperation()
      assert.is_false(operation.awaitingExplicitEvidence)
      assert.are.equal("retry", operation.dispatchProvenance)
      assert.is_number(operation.timeoutTimer)
      assert.are.equal(
        commandCountBeforeFailure + 1,
        countSent(stage.command)
      )
      if stage.name == "pickup" then
        assert.are.equal(2, operation.getRetries)
      else
        assert.are.equal(1, operation.putRetries)
      end
    end)
  end

  it("advances replayed pickup through explicit get and put evidence", function()
    local operation = startPickup("pack")
    local oldTimeout = timer_queue.callback(operation.timeoutTimer)
    local interruptOwner = "interrupt:gold-explicit-result"
    addGoldBlocker(interruptOwner)
    assert.is_true(boop.displaceGoldQueueIntent(
      interruptOwner,
      "synthetic native queue replacement"
    ))
    native_queue.apply("clearqueue all")
    assert.is_true(boop.runtime.clearBlocker(
      interruptOwner,
      "synthetic interrupt released"
    ))
    boop.tick()
    oldTimeout()

    assert.are.equal(2, countSent("queue add full get sovereigns"))
    assert.is_true(boop.onGoldGetSuccess())
    assert.are.equal("pack_pending", currentOperation().phase)
    assert.are.equal(
      1,
      countSent("queue add freestand put sovereigns in pack")
    )
    assert.is_true(boop.onGoldPutSuccess())
    assert.is_false(boop.state.gold.operation)
  end)

  it("makes an old timeout a zero-effect callback after a new generation starts", function()
    local first = startPickup("")
    local firstGeneration = first.generation
    local oldTimeout
    for _, entry in ipairs(scheduled) do
      if entry.id == first.timeoutTimer then
        oldTimeout = entry.callback
      end
    end
    assert.is_function(oldTimeout)

    gmcp.Room.Info = {
      area = "TEST",
      num = 2,
      exits = {},
    }
    boop.onRoomInfo()
    startPickup("", "2", 2)
    assert.is_true(currentOperation().generation > firstGeneration)
    local before = copyOperation(currentOperation())
    local currentTimer = currentOperation().timeoutTimer
    local sendCount = #sent
    local scheduledCount = #scheduled

    oldTimeout()

    assert.are.same(before, copyOperation(currentOperation()))
    assert.are.equal(currentTimer, currentOperation().timeoutTimer)
    assert.are.equal(sendCount, #sent)
    assert.are.equal(scheduledCount, #scheduled)
  end)

  it("makes retry-after-room-change a zero-effect callback", function()
    startPickup("")

    gmcp.Room.Info = {
      area = "TEST",
      num = 2,
      exits = {},
    }
    boop.onRoomInfo()
    local sendCount = #sent

    boop.onGoldCommandFailure("late failure")

    assert.is_false(boop.state.gold.operation)
    assert.are.equal(sendCount, #sent)
  end)

  it("clears only the matching current stage when its timeout fires", function()
    local operation = startPickup("")
    local timeout
    for _, entry in ipairs(scheduled) do
      if entry.id == operation.timeoutTimer then
        timeout = entry.callback
      end
    end
    assert.is_function(timeout)

    timeout()

    assert.is_false(boop.state.gold.operation)
    assert.is_nil(boop.state.combat.blockersByOwner[operation.blockerOwner])
    assert.stub(warn_stub).was_called_with("auto gold: clearing stale pending state")
  end)
end)
