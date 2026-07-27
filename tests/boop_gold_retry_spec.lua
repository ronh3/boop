local helper = dofile(os.getenv("TESTS_DIRECTORY") .. "/support/boop_test_helper.lua")

describe("boop generation-owned gold retry handling", function()
  local send_stub
  local send_gmcp_stub
  local err_stub
  local warn_stub
  local timer_stub
  local kill_timer_stub
  local raise_event_stub
  local sent
  local scheduled
  local raised_events

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
    boop.config.enabled = true
    boop.config.autoGrabGold = true
    boop.config.useQueueing = false

    send_stub = stub(_G, "send", function(command, echoBack)
      sent[#sent + 1] = {
        command = command,
        echoBack = echoBack,
      }
    end)
    send_gmcp_stub = stub(_G, "sendGMCP", function(_) end)
    err_stub = stub(boop.util, "err", function(_) end)
    warn_stub = stub(boop.util, "warn", function(_) end)
    timer_stub = stub(_G, "tempTimer", function(delay, callback)
      local id = 200 + #scheduled + 1
      scheduled[#scheduled + 1] = {
        id = id,
        delay = delay,
        callback = callback,
      }
      return id
    end)
    kill_timer_stub = stub(_G, "killTimer", function(_) end)
    raise_event_stub = stub(_G, "raiseEvent", function(name, ...)
      raised_events[#raised_events + 1] = {
        name = name,
        args = { ... },
      }
    end)
  end)

  after_each(function()
    if send_stub then send_stub:revert() send_stub = nil end
    if send_gmcp_stub then send_gmcp_stub:revert() send_gmcp_stub = nil end
    if err_stub then err_stub:revert() err_stub = nil end
    if warn_stub then warn_stub:revert() warn_stub = nil end
    if timer_stub then timer_stub:revert() timer_stub = nil end
    if kill_timer_stub then kill_timer_stub:revert() kill_timer_stub = nil end
    if raise_event_stub then raise_event_stub:revert() raise_event_stub = nil end
  end)

  it("retries get under its exact owner and exhausts at the existing limit", function()
    startPickup("")

    boop.onGoldCommandFailure("missing sovereigns")

    assert.are.equal(2, #sent)
    assert.are.equal("queue add freestand get sovereigns", sent[2].command)
    assert.are.equal(1, currentOperation().getRetries)

    boop.onGoldCommandFailure("still missing sovereigns")
    assert.are.equal(3, #sent)
    assert.are.equal(2, currentOperation().getRetries)

    boop.onGoldCommandFailure("gone")
    assert.is_false(boop.state.gold.operation)
    assert.are.equal(3, #sent)
    assert.stub(err_stub).was_called_with("auto gold: unable to get sovereigns; check room loot/line timing")
  end)

  it("holds put retry across movement, resumes after settlement, and exhausts at the existing limit", function()
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

    assert.are.equal(sendsBeforeRetry, #sent)
    assert.are.equal(0, currentOperation().putRetries)

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

    assert.are.equal(sendsBeforeRetry, #sent)
    assert.are.equal("pack_pending", currentOperation().phase)
    assert.are.equal(0, currentOperation().putRetries)

    boop.onGoldCommandFailure("pack closed")
    assert.are.equal(sendsBeforeRetry + 1, #sent)
    assert.are.equal("queue add freestand put sovereigns in pack", sent[#sent].command)
    assert.are.equal(1, currentOperation().putRetries)

    boop.onGoldCommandFailure("still closed")
    assert.is_false(boop.state.gold.operation)
    assert.are.equal(sendsBeforeRetry + 1, #sent)
    assert.stub(err_stub).was_called_with("auto gold: unable to put sovereigns in pack; use `boop pack test`")
  end)

  it("does not consume get retries while any unrelated owner holds gold", function()
    local owners = {
      "room:observation",
      "flee:active",
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

  it("does not consume put retries while any unrelated owner holds gold", function()
    local owners = {
      "room:observation",
      "flee:active",
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
      command = "queue add freestand get sovereigns",
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
