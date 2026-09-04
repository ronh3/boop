local helper = dofile(os.getenv("TESTS_DIRECTORY") .. "/support/boop_test_helper.lua")

describe("boop Room authority owner", function()
  local saved

  local function freshObservation(roomId)
    roomId = tostring(roomId or "1")
    gmcp.Room.Info.num = roomId
    return boop.room.startRoomObservation(roomId, {
      boundary = "fresh_start",
      reason = "room owner spec",
    })
  end

  local function acceptApplication(items)
    local fence = assert(boop.room.beginRoomResponseFence("room owner spec"))
    local inventory = boop.room.observeRoomItemsList("inv", {})
    local accepted = boop.room.observeRoomItemsList("room", items or {})
    assert.are.equal("inventory", inventory.status)
    assert.are.equal("accepted", accepted.status)
    assert.are.equal(fence.fenceId, inventory.fenceId)
    assert.are.equal(fence.fenceId, accepted.fenceId)
    return accepted
  end

  before_each(function()
    helper.reset()
    saved = {
      boop = _G.boop,
      gmcp = _G.gmcp,
      getEpoch = _G.getEpoch,
      killTimer = _G.killTimer,
      send = _G.send,
      sendGMCP = _G.sendGMCP,
      tempTimer = _G.tempTimer,
    }
  end)

  after_each(function()
    for name, value in pairs(saved or {}) do
      rawset(_G, name, value)
    end
  end)

  it("starts and advances observations without advancing duplicate Room.Info", function()
    local first = freshObservation("101")
    assert.are.equal("101", first.roomId)
    assert.is_true(first.infoSeen)
    assert.is_false(first.itemsSeen)

    local duplicate = boop.room.observeRoomInfo("101")
    assert.are.equal(first.generation, duplicate.generation)
    assert.is_true(duplicate.infoSeen)

    gmcp.Room.Info.num = "102"
    local nextRoom = boop.room.startRoomObservation("102", {
      boundary = "room_change",
      reason = "room changed",
    })
    assert.are.equal(first.generation + 1, nextRoom.generation)
    assert.are.equal("102", nextRoom.roomId)
  end)

  it("distinguishes orphan lists and accepts one paired response fence", function()
    freshObservation("101")
    local orphan = boop.room.observeRoomItemsList("room", {
      { id = "orphan", name = "an orphan item" },
    })
    assert.are.equal("orphan", orphan.status)

    local accepted = acceptApplication({
      { id = "valid", name = "a valid item" },
    })
    assert.are.same({
      applicationId = accepted.applicationId,
      roomId = "101",
      observationGeneration = accepted.generation,
    }, accepted.sourceAuthority)
    assert.are.equal("valid", accepted.items[1].id)
  end)

  it("drains a stale generation and invalidates its application authority", function()
    freshObservation("101")
    local oldFence = assert(boop.room.beginRoomResponseFence("old generation"))

    gmcp.Room.Info.num = "102"
    local current = boop.room.startRoomObservation("102", {
      boundary = "room_change",
      reason = "generation advanced",
    })
    assert.is_true(current.generation > oldFence.generation)
    assert.are.equal("drained", boop.room.observeRoomItemsList("inv", {}).status)
    assert.are.equal("drained", boop.room.observeRoomItemsList("room", {}).status)
    assert.is_false(boop.room.validateRoomSourceAuthority({
      applicationId = 1,
      roomId = "101",
      observationGeneration = oldFence.generation,
    }))
  end)

  it("preserves fence identity and supersedes only within the same room generation", function()
    freshObservation("101")
    local first = acceptApplication({ { id = "1", name = "first" } })
    local generation = first.generation
    local revalidation = assert(boop.room.beginRoomResponseFence(
      "same-room revalidation",
      {
        roomOnly = true,
        roomId = "101",
        generation = generation,
        operationGeneration = 7,
      }
    ))
    local second = boop.room.observeRoomItemsList("room", {
      { id = "2", name = "second" },
    })

    assert.are.equal(revalidation.fenceId, second.fenceId)
    assert.are.equal(generation, second.generation)
    assert.is_true(second.applicationId > first.applicationId)
    assert.is_false(boop.room.claimRoomApplication(
      first.applicationId,
      first.sourceAuthority
    ))
    local claimed = boop.room.claimRoomApplication(
      second.applicationId,
      second.sourceAuthority
    )
    assert.is_table(claimed)
    assert.is_true(claimed.claimed)
    assert.is_true(claimed.consumed)
    assert.is_true(boop.room.validateRoomSourceAuthority(second.sourceAuthority))
    local valid, reason = boop.room.sourceAuthorityDisposition(first.sourceAuthority)
    assert.is_true(valid)
    assert.are.equal("same-room application superseded", reason)
  end)

  it("claims and consumes exactly once and rejects stale timer ownership", function()
    freshObservation("101")
    local first = acceptApplication({ { id = "1", name = "first" } })
    assert.is_true(boop.room.setRoomApplicationTimer(first.applicationId, 11))

    local generation = boop.room.roomObservationSnapshot().generation
    assert(boop.room.beginRoomResponseFence("new application", {
      roomOnly = true,
      roomId = "101",
      generation = generation,
    }))
    local second = boop.room.observeRoomItemsList("room", {
      { id = "2", name = "second" },
    })
    assert.is_true(boop.room.setRoomApplicationTimer(second.applicationId, 22))

    assert.is_false(boop.room.claimRoomApplication(
      first.applicationId,
      first.sourceAuthority,
      11
    ))
    assert.is_false(boop.room.claimRoomApplication(
      second.applicationId,
      second.sourceAuthority,
      11
    ))
    local claimed = boop.room.claimRoomApplication(
      second.applicationId,
      second.sourceAuthority,
      22
    )
    assert.is_true(claimed.claimed)
    assert.is_true(claimed.consumed)
    assert.is_false(claimed.pendingTimer)
    assert.is_false(boop.room.claimRoomApplication(
      second.applicationId,
      second.sourceAuthority,
      22
    ))
  end)

  it("captures provisional movement items until a destination Room.Info arrives", function()
    freshObservation("101")
    local accepted = acceptApplication({ { id = "1", name = "origin" } })
    assert.is_table(boop.room.claimRoomApplication(
      accepted.applicationId,
      accepted.sourceAuthority
    ))
    assert.is_table(boop.room.noteMovementIntent("north"))

    local candidateItems = { { id = "2", name = "destination" } }
    local response = boop.room.observeRoomItemsList("room", candidateItems)
    assert.are.equal("duplicate", response.status)
    local captured = boop.room.captureMovementRoomItems(candidateItems, response)
    assert.is_table(captured)
    assert.are.equal("duplicate", captured.candidateStatus)

    local consumed = boop.room.consumeMovementRoomItems("102")
    assert.is_table(consumed)
    assert.are.equal("101", consumed.originRoomId)
    assert.are.equal("102", consumed.destinationRoomId)
    assert.are.equal("2", consumed.candidateItems[1].id)
    assert.is_false(boop.room.movementIntentSnapshot().active)
  end)

  it("deduplicates requestRoomItemsOnce and keeps Walk on the Room owner", function()
    freshObservation("101")
    local gmcpRequests = {}
    local flushes = 0
    _G.sendGMCP = function(command)
      gmcpRequests[#gmcpRequests + 1] = command
    end
    _G.send = function(command)
      if command == " " then flushes = flushes + 1 end
    end
    _G.tempTimer = function(_, _) return 77 end

    assert.is_true(boop.room.requestRoomItemsOnce("focused room request"))
    assert.is_false(boop.room.requestRoomItemsOnce("duplicate room request"))
    assert.are.same({
      [[Char.Items.Inv ""]],
      [[Char.Items.Room ""]],
    }, gmcpRequests)
    assert.are.equal(2, flushes)
    assert.is_nil(boop.requestRoomItemsOnce)
    assert.is_nil(boop.events.requestRoomItemsOnce)

    local handle = assert(io.open(
      helper.repoRoot() .. "/src/scripts/boop/boop_walk.lua",
      "r"
    ))
    local source = handle:read("*a")
    handle:close()
    assert.is_truthy(source:find("boop.room.requestRoomItemsOnce", 1, true))
    assert.is_falsy(source:find("boop.events", 1, true))
  end)

  it("loads and exercises Room authority without the Combat loop", function()
    _G.boop = {
      state = {},
      perf = {
        on = false,
        count = function() end,
        register = function() end,
      },
    }
    _G.gmcp = { Room = { Info = { num = "901", exits = {} } } }
    dofile(helper.repoRoot() .. "/src/scripts/boop/boop_runtime.lua")
    dofile(helper.repoRoot() .. "/src/scripts/boop/boop_room.lua")
    dofile(helper.repoRoot() .. "/src/scripts/boop/boop_locks.lua")
    boop.runtime.ensureState()

    assert.is_nil(boop.combat)
    local observation = boop.room.startRoomObservation("901", {
      boundary = "fresh_start",
    })
    local fence = boop.room.beginRoomResponseFence("isolated owner")
    boop.room.observeRoomItemsList("inv", {})
    local accepted = boop.room.observeRoomItemsList("room", {})
    local claimed = boop.room.claimRoomApplication(
      accepted.applicationId,
      accepted.sourceAuthority
    )

    assert.are.equal(observation.generation, fence.generation)
    assert.is_true(claimed.consumed)
    assert.is_true(boop.room.validateRoomSourceAuthority(
      accepted.sourceAuthority
    ))
  end)
end)
