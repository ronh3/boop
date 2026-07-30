local helper = dofile(os.getenv("TESTS_DIRECTORY") .. "/support/boop_test_helper.lua")

describe("boop staged gold handling", function()
  local send_stub
  local send_gmcp_stub
  local timer_stub
  local kill_timer_stub
  local mark_intent_stub
  local sent
  local sent_gmcp
  local scheduled

  local function goldItem(id)
    return {
      id = tostring(id or "9001"),
      name = "a pile of golden sovereigns",
      attrib = "t",
    }
  end

  local function currentOperation()
    local operation = boop.state.gold.operation
    assert.is_table(operation)
    return operation
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
      revalidationAttempted = operation.revalidationAttempted,
      revalidationFenceId = operation.revalidationFenceId,
    }
  end

  local function setCurrentRoomEvidence(items, generation)
    helper.seedRoomObservation("1", {
      generation = generation or 1,
      infoSeen = true,
      itemsSeen = true,
      acceptedItems = items,
    })
    gmcp.Char.Items.List = {
      location = "room",
      items = items,
    }
  end

  local function runNewestZeroTimer(afterIndex)
    for index = #scheduled, (afterIndex or 0) + 1, -1 do
      local entry = scheduled[index]
      if entry and entry.delay == 0 then
        entry.callback()
        return true
      end
    end
    return false
  end

  local function publishRoomList(items)
    local observation = boop.runtime.roomObservationSnapshot()
    local fence = observation.fenceQueue[1]
    if fence and fence.phase == "await_inv" then
      gmcp.Char.Items.List = {
        location = "inv",
        items = {},
      }
      boop.onRoomItemsList()
    end
    gmcp.Char.Items.List = {
      location = "room",
      items = items,
    }
    local scheduledBeforeRoom = #scheduled
    boop.onRoomItemsList()
    runNewestZeroTimer(scheduledBeforeRoom)
  end

  local function publishGoldAdd(id)
    gmcp.Char.Items.Add = {
      location = "room",
      item = goldItem(id),
    }
    boop.onRoomItemsAdd()
  end

  local function startPickup(pack)
    boop.config.goldPack = pack or ""
    setCurrentRoomEvidence({ goldItem("9001") })
    boop.onGoldDropLine("A handful of sovereigns spills onto the ground.")
    return currentOperation()
  end

  local function addGoldBlocker(owner)
    helper.setRuntimeBlocker({
      owner = owner,
      code = owner == "flee:active" and "flee_active" or "test_gold_hold",
      label = "gold test hold",
      systems = {
        combat = true,
        queue = true,
        gold = true,
        walk = true,
      },
    })
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

  before_each(function()
    helper.reset()
    sent = {}
    sent_gmcp = {}
    scheduled = {}
    boop.config.enabled = true
    boop.config.autoGrabGold = true
    boop.config.useQueueing = false

    send_stub = stub(_G, "send", function(command, echoBack)
      sent[#sent + 1] = {
        command = command,
        echoBack = echoBack,
        phase = type(boop.state.gold.operation) == "table"
          and boop.state.gold.operation.phase
          or false,
      }
    end)
    send_gmcp_stub = stub(_G, "sendGMCP", function(command)
      sent_gmcp[#sent_gmcp + 1] = command
    end)
    timer_stub = stub(_G, "tempTimer", function(delay, callback)
      local id = 100 + #scheduled + 1
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
    if mark_intent_stub then mark_intent_stub:revert() mark_intent_stub = nil end
    if send_stub then send_stub:revert() send_stub = nil end
    if send_gmcp_stub then send_gmcp_stub:revert() send_gmcp_stub = nil end
    if timer_stub then timer_stub:revert() timer_stub = nil end
    if kill_timer_stub then kill_timer_stub:revert() kill_timer_stub = nil end
  end)

  it("waits for complete current-room evidence and coalesces duplicate text, Add, and List signals", function()
    local observation = boop.runtime.startRoomObservation("1", {
      boundary = "fresh_start",
    })
    boop.onGoldDropLine("A handful of sovereigns spills onto the ground.")

    assert.are.equal(0, #sent)
    assert.are.equal(2, #sent_gmcp)
    assert.are.equal("Char.Items.Inv", sent_gmcp[1])
    assert.are.equal("Char.Items.Room", sent_gmcp[2])
    local deferred = currentOperation()
    assert.are.equal(1, deferred.generation)
    assert.are.equal("deferred_room", deferred.phase)
    assert.is_false(deferred.terminal)
    assert.are.equal("gold:1", deferred.blockerOwner)
    assert.are.equal("1", deferred.roomId)
    assert.are.equal(observation.generation, deferred.roomGeneration)
    local deferredFlushTimer = deferred.flushTimer
    local deferredTimeoutTimer = deferred.timeoutTimer

    boop.onGoldDropLine("More sovereigns spill onto the ground.")
    publishGoldAdd("9001")

    local afterDuplicates = currentOperation()
    assert.are.equal(1, afterDuplicates.generation)
    assert.are.equal(deferredFlushTimer, afterDuplicates.flushTimer)
    assert.are.equal(deferredTimeoutTimer, afterDuplicates.timeoutTimer)
    assert.are.equal(0, #sent)
    assert.are.equal(2, #sent_gmcp)

    publishRoomList({ goldItem("9001") })

    local pickup = currentOperation()
    assert.are.equal("pickup_pending", pickup.phase)
    assert.are.equal("9001", pickup.goldItemId)
    assert.are.equal(1, #sent)
    assert.are.equal("queue add full get sovereigns", sent[1].command)
    assert.is_false(sent[1].echoBack)
    local pickupFlushTimer = pickup.flushTimer
    local pickupTimeoutTimer = pickup.timeoutTimer

    boop.onGoldDropLine("A third handful of sovereigns spills.")
    publishGoldAdd("9001")
    publishRoomList({ goldItem("9001") })

    local final = currentOperation()
    assert.are.equal(1, final.generation)
    assert.are.equal(pickupFlushTimer, final.flushTimer)
    assert.are.equal(pickupTimeoutTimer, final.timeoutTimer)
    assert.are.equal(1, #sent)
    assert.are.equal(2, #sent_gmcp)
  end)

  it("queues get, transfers to inventory-owned packing, then queues put", function()
    local pickup = startPickup("pack")

    assert.are.equal("pickup_pending", pickup.phase)
    assert.are.equal(1, #sent)
    assert.are.equal("queue add full get sovereigns", sent[1].command)
    assert.are.equal("pickup_pending", sent[1].phase)

    boop.onGoldGetSuccess()

    local packing = currentOperation()
    assert.are.equal("pack_pending", packing.phase)
    assert.are.equal("", packing.roomId)
    assert.are.equal(0, packing.roomGeneration)
    assert.are.equal("", packing.goldItemId)
    assert.are.equal("pack", packing.packTarget)
    assert.are.equal(2, #sent)
    assert.are.equal("queue add freestand put sovereigns in pack", sent[2].command)
    assert.are.equal("pack_pending", sent[2].phase)

    gmcp.Room.Info = {
      area = "TEST",
      num = 2,
      exits = {},
    }
    boop.onRoomInfo()

    assert.are.equal("pack_pending", currentOperation().phase)
    assert.are.equal(2, #sent)

    boop.onGoldPutSuccess()

    assert.is_false(boop.state.gold.operation)
    assert.is_nil(boop.state.combat.blockersByOwner["gold:1"])
    assert.are.equal(2, #sent)
  end)

  it("completes confirmed pickup without a pack and never queues put", function()
    startPickup("")

    boop.onGoldGetSuccess()

    assert.is_false(boop.state.gold.operation)
    assert.is_nil(boop.state.combat.blockersByOwner["gold:1"])
    assert.are.equal(1, #sent)
    assert.are.equal("queue add full get sovereigns", sent[1].command)
  end)

  it("invalidates room-owned pickup before success and ignores the late success", function()
    startPickup("pack")

    gmcp.Room.Info = {
      area = "TEST",
      num = 2,
      exits = {},
    }
    boop.onRoomInfo()

    assert.is_false(boop.state.gold.operation)
    assert.is_nil(boop.state.combat.blockersByOwner["gold:1"])
    local sendsAfterMove = #sent

    boop.onGoldGetSuccess()

    assert.is_false(boop.state.gold.operation)
    assert.are.equal(sendsAfterMove, #sent)
  end)

  it("authorizes initial get only after other operations release", function()
    local owners = {
      "pull:8",
      "interrupt:9",
    }

    for _, owner in ipairs(owners) do
      helper.reset()
      sent = {}
      sent_gmcp = {}
      scheduled = {}
      boop.config.enabled = true
      boop.config.autoGrabGold = true
      boop.config.useQueueing = false
      setCurrentRoomEvidence({ goldItem("9001") })
      addGoldBlocker(owner)

      boop.onGoldDropLine("A handful of sovereigns spills onto the ground.")

      local blocked = currentOperation()
      assert.are.equal("pickup_pending", blocked.phase)
      assert.are.equal(0, blocked.getRetries)
      assert.are.equal(0, #sent)

      boop.runtime.clearOperationLock(owner, "test release")
      assert.is_true(boop.flushPendingGold("test release"))
      assert.are.equal(1, #sent)
      assert.are.equal("queue add full get sovereigns", sent[1].command)
    end
  end)

  it("authorizes initial put only after other operations release", function()
    local owners = {
      "pull:8",
      "interrupt:9",
    }

    for _, owner in ipairs(owners) do
      helper.reset()
      sent = {}
      sent_gmcp = {}
      scheduled = {}
      boop.config.enabled = true
      boop.config.autoGrabGold = true
      boop.config.useQueueing = false
      startPickup("pack")
      addGoldBlocker(owner)
      local sendsBeforeSuccess = #sent

      boop.onGoldGetSuccess()

      local blocked = currentOperation()
      assert.are.equal("pack_pending", blocked.phase)
      assert.are.equal(0, blocked.putRetries)
      assert.are.equal(sendsBeforeSuccess, #sent)

      boop.runtime.clearOperationLock(owner, "test release")
      assert.is_true(boop.flushPendingGold("test release"))
      assert.are.equal(sendsBeforeSuccess + 1, #sent)
      assert.are.equal("queue add freestand put sovereigns in pack", sent[#sent].command)
    end
  end)

  it("same-room-gold-pipeline queues one inventory-owned put in either removal order", function()
    local function openFencedRoom(autoGrab)
      helper.reset()
      sent = {}
      sent_gmcp = {}
      scheduled = {}
      boop.config.enabled = true
      boop.config.autoGrabGold = autoGrab ~= false
      boop.config.useQueueing = false
      boop.config.goldPack = "pack"
      boop.state.targeting.room = ""
      gmcp.Room.Info = {
        area = "TEST",
        num = "1",
        exits = {},
      }

      boop.onRoomInfo()

      assert.are.same({
        "Char.Items.Inv",
        "Char.Items.Room",
      }, sent_gmcp)

      gmcp.Char.Items.List = {
        location = "room",
        items = { goldItem("9001") },
      }
      boop.onRoomItemsList()
      assert.is_false(boop.state.gold.operation)
      assert.are.equal(0, countSent("queue add full get sovereigns"))

      gmcp.Char.Items.List = {
        location = "inv",
        items = {},
      }
      local scheduledBeforeInv = #scheduled
      boop.onRoomItemsList()
      runNewestZeroTimer(scheduledBeforeInv)
      return boop.state.gold.operation
    end

    local function removeGold()
      gmcp.Char.Items.Remove = {
        location = "room",
        item = goldItem("9001"),
      }
      boop.onRoomItemsRemove()
    end

    local function runRemovalOrder(successFirst)
      local pickup = openFencedRoom(true)
      assert.is_table(pickup)
      assert.are.equal(1, pickup.generation)
      assert.are.equal("pickup_pending", pickup.phase)
      assert.are.equal("1", pickup.roomId)
      assert.are.equal("9001", pickup.goldItemId)
      assert.are.equal(1, countSent("queue add full get sovereigns"))

      boop.onGoldDropLine("More sovereigns spill onto the ground.")
      publishGoldAdd("9001")
      gmcp.Char.Items.List = {
        location = "room",
        items = { goldItem("9001") },
      }
      boop.onRoomItemsList()
      assert.are.equal(1, countSent("queue add full get sovereigns"))

      local beforeSameRoom = copyOperation(currentOperation())
      boop.onRoomInfo()
      assert.are.same(beforeSameRoom, copyOperation(currentOperation()))

      if successFirst then
        assert.is_true(boop.onGoldGetSuccess())
        removeGold()
      else
        removeGold()
        assert.are.same(beforeSameRoom, copyOperation(currentOperation()))
        assert.are.equal(
          0,
          countSent("queue add freestand put sovereigns in pack")
        )
        assert.is_true(boop.onGoldGetSuccess())
      end

      local packing = copyOperation(currentOperation())
      assert.are.equal("pack_pending", packing.phase)
      assert.are.equal("", packing.roomId)
      assert.are.equal(0, packing.roomGeneration)
      assert.are.equal("", packing.goldItemId)
      assert.are.equal(
        1,
        countSent("queue add freestand put sovereigns in pack")
      )

      assert.is_false(boop.onGoldGetSuccess())
      removeGold()
      assert.are.equal(
        1,
        countSent("queue add freestand put sovereigns in pack")
      )

      gmcp.Room.Info = {
        area = "TEST",
        num = "2",
        exits = { south = "1" },
      }
      boop.onRoomInfo()
      assert.are.same(packing, copyOperation(currentOperation()))
      assert.is_true(boop.onGoldPutSuccess())
      assert.is_false(boop.onGoldPutSuccess())
      assert.is_false(boop.state.gold.operation)
      assert.are.equal(
        1,
        countSent("queue add freestand put sovereigns in pack")
      )
    end

    runRemovalOrder(false)
    runRemovalOrder(true)

    openFencedRoom(false)
    assert.is_false(boop.state.gold.operation)
    gmcp.Room.Info.num = "stale-persistent-room"
    boop.config.autoGrabGold = true
    boop.onGoldDropLine("A final handful of sovereigns spills.")

    assert.are.equal(
      0,
      countSent("queue add full get sovereigns"),
      "GOLD_SAME_ROOM_PIPELINE_BROKEN: mismatched room state authorized pickup"
    )
    gmcp.Room.Info.num = "1"
    assert.is_true(boop.flushPendingGold("room identity restored"))
    assert.are.equal(1, countSent("queue add full get sovereigns"))
  end)

  describe("G-03-5 settled-add-revalidation", function()
    it("revalidates one exact settled Add without treating the Add as canonical evidence", function()
      boop.config.goldPack = "pack"
      local denizen = {
        id = "42",
        name = "a settled room denizen",
        attrib = "m",
      }
      setCurrentRoomEvidence({ denizen }, 7)

      publishGoldAdd("9001")

      local deferred = currentOperation()
      local observation = boop.runtime.roomObservationSnapshot()
      local fence = observation.fenceQueue[1]
      assert.are.equal(1, deferred.generation)
      assert.are.equal("deferred_room", deferred.phase)
      assert.are.equal("gold:1", deferred.blockerOwner)
      assert.are.equal("1", deferred.roomId)
      assert.are.equal(7, deferred.roomGeneration)
      assert.are.equal("9001", deferred.goldItemId)
      assert.is_true(deferred.revalidationAttempted)
      assert.are.equal(fence.fenceId, deferred.revalidationFenceId)
      assert.are.equal("await_room", fence.phase)
      assert.is_true(fence.roomOnly)
      assert.are.same({ denizen }, observation.acceptedItems)
      assert.are.same({ "Char.Items.Room" }, sent_gmcp)
      assert.are.equal(0, countSent("queue add full get sovereigns"))
      assert.are.equal(3, #scheduled)

      local generation = deferred.generation
      local fenceId = deferred.revalidationFenceId
      publishGoldAdd("9001")
      boop.onGoldDropLine("More sovereigns spill onto the ground.")
      local callbacks = {}
      for _, entry in ipairs(scheduled) do
        callbacks[#callbacks + 1] = entry.callback
      end
      for _, callback in ipairs(callbacks) do
        callback()
      end

      deferred = currentOperation()
      assert.are.equal(generation, deferred.generation)
      assert.are.equal(fenceId, deferred.revalidationFenceId)
      assert.are.same({ "Char.Items.Room" }, sent_gmcp)
      assert.are.equal(0, countSent("queue add full get sovereigns"))

      gmcp.Char.Items.List = {
        location = "inv",
        items = { goldItem("9001") },
      }
      boop.onRoomItemsList()

      observation = boop.runtime.roomObservationSnapshot()
      assert.are.same({ denizen }, observation.acceptedItems)
      assert.are.equal("deferred_room", currentOperation().phase)
      assert.are.equal(0, countSent("queue add full get sovereigns"))

      gmcp.Char.Items.List = {
        location = "room",
        items = { denizen, goldItem("9001") },
      }
      local scheduledBeforeRoom = #scheduled
      boop.onRoomItemsList()
      runNewestZeroTimer(scheduledBeforeRoom)

      local pickup = currentOperation()
      assert.are.equal(generation, pickup.generation)
      assert.are.equal("pickup_pending", pickup.phase)
      assert.are.equal("gold:1", pickup.blockerOwner)
      assert.are.equal(1, countSent("queue add full get sovereigns"))

      boop.onRoomItemsList()
      assert.are.equal(1, countSent("queue add full get sovereigns"))
      assert.is_true(boop.onGoldGetSuccess())
      assert.is_false(boop.onGoldGetSuccess())
      assert.are.equal(
        1,
        countSent("queue add freestand put sovereigns in pack")
      )
      assert.is_true(boop.onGoldPutSuccess())
      assert.is_false(boop.onGoldPutSuccess())
      assert.is_false(boop.state.gold.operation)

      local settled = boop.runtime.roomObservationSnapshot()
      helper.seedRoomObservation("1", {
        generation = settled.generation,
        infoSeen = true,
        itemsSeen = true,
        acceptedItems = { denizen },
        nextFenceId = settled.nextFenceId,
      })
      publishGoldAdd("9002")

      local later = currentOperation()
      assert.are.equal(generation + 1, later.generation)
      assert.is_true(later.revalidationAttempted)
      assert.are.same({
        "Char.Items.Room",
        "Char.Items.Room",
      }, sent_gmcp)
      assert.are.equal(1, countSent("queue add full get sovereigns"))
    end)
  end)

  it("dispatches only the supplied combat action without gold prefixing or mark-intent", function()
    boop.config.useQueueing = true
    boop.config.goldPack = "pack"
    boop.state.gold.autoGrabPending = true
    boop.state.gold.autoGrabPendingAt = -1
    boop.state.gold.dropped = true
    mark_intent_stub = stub(boop, "markGoldQueueIntent", function(_) end)

    boop.executeAction("warp 42")

    assert.are.equal(2, #sent)
    assert.are.equal("setalias BOOP_ATTACK warp 42", sent[1].command)
    assert.are.equal("queue addclearfull freestand BOOP_ATTACK", sent[2].command)
    assert.is_nil(sent[1].command:find("sovereigns", 1, true))
    assert.stub(mark_intent_stub).was_not_called()
  end)
end)
