local helper = dofile(os.getenv("TESTS_DIRECTORY") .. "/support/boop_test_helper.lua")

describe("boop Locks admission owner", function()
  local savedBoop
  local savedGmcp

  before_each(function()
    helper.reset()
    savedBoop = _G.boop
    savedGmcp = _G.gmcp
  end)

  after_each(function()
    _G.boop = savedBoop
    _G.gmcp = savedGmcp
  end)

  it("keeps the empty operationHolds path ahead of sorting and projection", function()
    local state = boop.runtime.state()
    state.combat.blockersByOwner = {}
    local operationProjection = state.combat.operationLock
    local blockerProjection = state.combat.blocker
    local originalSort = table.sort
    local sortCalls = 0
    local sortStub = stub(table, "sort", function(values, comparator)
      sortCalls = sortCalls + 1
      return originalSort(values, comparator)
    end)

    assert.is_false(boop.locks.operationHolds("combat"))
    assert.are.equal(0, sortCalls)
    assert.are.equal(operationProjection, state.combat.operationLock)
    assert.are.equal(blockerProjection, state.combat.blocker)
    sortStub:revert()
  end)

  it("holds one operation by system and exposes its operation snapshot", function()
    local created = boop.locks.setOperationLock(
      "interrupt:7",
      "interrupt_pending",
      "diagnostic pending",
      { combat = true, queue = true },
      { prompt = true },
      { source = "focused lock spec" }
    )
    assert.is_table(created)
    assert.is_true(boop.locks.operationHolds("combat"))
    assert.is_true(boop.locks.operationHolds("queue"))
    assert.is_false(boop.locks.operationHolds("walk"))
    assert.is_false(boop.locks.operationHolds("combat", "interrupt:7"))

    local snapshot = boop.locks.operationLockSnapshot()
    assert.are.equal("interrupt:7", snapshot.owner)
    assert.are.equal("interrupt_pending", snapshot.code)
    assert.are.same({ prompt = true }, snapshot.waitsFor)
  end)

  it("orders multiple blockers by contract priority and deterministic ties", function()
    boop.locks.setBlocker(
      "walk:z",
      "walk_move_pending",
      "walk z",
      { walk = true },
      {}
    )
    boop.locks.setBlocker(
      "interrupt:z",
      "interrupt_pending",
      "interrupt z",
      { combat = true },
      {}
    )
    boop.locks.setBlocker(
      "lifecycle:z",
      "missing_room",
      "room missing",
      { combat = true },
      {}
    )
    boop.locks.setBlocker(
      "lifecycle:a",
      "missing_room",
      "room missing tie",
      { target = true },
      {}
    )

    local blockers = boop.locks.blockersSnapshot()
    assert.are.same({
      "lifecycle:a",
      "lifecycle:z",
      "interrupt:z",
      "walk:z",
    }, {
      blockers[1].owner,
      blockers[2].owner,
      blockers[3].owner,
      blockers[4].owner,
    })
    assert.are.equal("lifecycle:a", boop.locks.blockerSnapshot().owner)
  end)

  it("replaces one owner in place and clears/releases only that owner", function()
    boop.locks.setBlocker(
      "compat:test",
      "room_partial",
      "first",
      { combat = true },
      { prompt = true },
      { since = 123 }
    )
    local replaced = boop.locks.setBlocker(
      "compat:test",
      "target_lost",
      "replacement",
      { target = true },
      { gmcp = true },
      { since = 456 }
    )
    assert.are.equal(1, #boop.locks.blockersSnapshot())
    assert.are.equal("replacement", replaced.label)
    assert.are.equal(456, replaced.since)
    assert.is_false(boop.locks.shouldHold("combat"))
    assert.is_true(boop.locks.shouldHold("target"))
    assert.is_true(boop.locks.clearBlocker("compat:test", "done"))
    assert.is_false(boop.locks.clearBlocker("compat:test", "stale clear"))
    assert.is_false(boop.locks.shouldHold("target"))
  end)

  it("auto-clears only after all prompt, GMCP, and arbitrary evidence", function()
    boop.locks.setBlocker(
      "interrupt:evidence",
      "interrupt_pending",
      "evidence",
      { combat = true },
      { prompt = true, gmcp = true, room = true },
      { observed = { custom = "retained" } }
    )
    assert.is_true(boop.locks.notePromptObserved())
    local pending = boop.state.combat.blockersByOwner["interrupt:evidence"]
    assert.is_table(pending)
    assert.is_true(pending.promptSeen)
    assert.are.equal("retained", pending.observed.custom)

    gmcp.Room.Info.num = "77"
    assert.is_true(boop.locks.noteGmcpObserved("interrupt:evidence", "room"))
    assert.is_nil(boop.state.combat.blockersByOwner["interrupt:evidence"])
    assert.is_false(boop.locks.operationHolds("combat"))
  end)

  it("ignores stale-owner evidence without clearing a newer owner", function()
    boop.locks.setOperationLock(
      "interrupt:old",
      "interrupt_pending",
      "old",
      { combat = true },
      { gmcp = true }
    )
    assert.is_true(boop.locks.clearOperationLock("interrupt:old", "replaced"))
    boop.locks.setOperationLock(
      "interrupt:new",
      "interrupt_pending",
      "new",
      { combat = true },
      { prompt = true }
    )

    assert.is_false(boop.locks.noteGmcpObserved("interrupt:old", "ire"))
    assert.are.equal("interrupt:new", boop.locks.operationLockSnapshot().owner)
    assert.is_true(boop.locks.operationHolds("combat"))
    assert.is_true(boop.locks.notePromptObserved())
    assert.is_false(boop.locks.operationHolds("combat"))
  end)

  it("applies interrupt admission tiers without owning interrupt lifecycle", function()
    local active = { name = "diag", tier = "diagnostic", terminal = false }
    assert.are.equal("reject", boop.locks.interruptAdmission(active, {
      name = "matic",
    }).decision)
    assert.are.equal("supersede", boop.locks.interruptAdmission(active, {
      name = "leap",
    }).decision)
    assert.are.equal("reject", boop.locks.interruptAdmission(active, {
      name = "catarin",
      tier = "diagnostic",
    }).decision)
    assert.are.equal("supersede", boop.locks.interruptAdmission(active, {
      name = "diag",
      replaceSame = true,
    }).decision)
    assert.are.equal("start", boop.locks.interruptAdmission({
      name = "diag",
      terminal = true,
    }, {
      name = "matic",
    }).decision)
    assert.is_nil(boop.locks.beginInterrupt)
    assert.is_nil(boop.locks.completeInterrupt)
  end)

  it("loads and exercises Locks admission without the Combat loop", function()
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
    assert.is_false(boop.locks.operationHolds("combat"))
    assert.is_table(boop.locks.setOperationLock(
      "interrupt:isolated",
      "interrupt_pending",
      "isolated",
      { combat = true },
      { prompt = true }
    ))
    assert.is_true(boop.locks.operationHolds("combat"))
    assert.are.equal("supersede", boop.locks.interruptAdmission({
      name = "diag",
    }, {
      name = "flee",
    }).decision)
    assert.is_true(boop.locks.notePromptObserved())
    assert.is_false(boop.locks.operationHolds("combat"))
  end)
end)
