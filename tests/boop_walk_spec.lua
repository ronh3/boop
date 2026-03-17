local helper = dofile(os.getenv("TESTS_DIRECTORY") .. "/support/boop_test_helper.lua")

describe("boop walk integration", function()
  local raise_event_stub
  local timer_stub
  local kill_timer_stub
  local info_stub
  local ok_stub
  local warn_stub
  local scheduled
  local original_demonwalker

  before_each(function()
    helper.reset()
    scheduled = {}
    original_demonwalker = _G.demonwalker
    _G.demonwalker = {
      enabled = false,
      init = function()
        _G.demonwalker.enabled = true
      end,
    }

    raise_event_stub = stub(_G, "raiseEvent", function(name)
      scheduled[#scheduled + 1] = { event = name }
    end)
    timer_stub = stub(_G, "tempTimer", function(_, callback)
      scheduled[#scheduled + 1] = callback
      return #scheduled
    end)
    kill_timer_stub = stub(_G, "killTimer", function(_) end)
    info_stub = stub(boop.util, "info", function(_) end)
    ok_stub = stub(boop.util, "ok", function(_) end)
    warn_stub = stub(boop.util, "warn", function(_) end)

    boop.config.enabled = true
    boop.config.targetingMode = "auto"
  end)

  after_each(function()
    if raise_event_stub then raise_event_stub:revert() end
    if timer_stub then timer_stub:revert() end
    if kill_timer_stub then kill_timer_stub:revert() end
    if info_stub then info_stub:revert() end
    if ok_stub then ok_stub:revert() end
    if warn_stub then warn_stub:revert() end
    _G.demonwalker = original_demonwalker
  end)

  it("starts demonwalker from boop walk start", function()
    boop.ui.walkCommand("start")

    assert.is_true(boop.state.walkActive)
    assert.is_true(boop.state.walkOwned)
    assert.is_true(demonwalker.enabled)
    assert.stub(ok_stub).was_called_with("walk started")
  end)

  it("advances to the next room when the room list settles empty", function()
    boop.state.walkActive = true
    gmcp.Char.Items.List = {
      location = "room",
      items = {},
    }

    boop.onRoomItemsList()

    assert.is_true(boop.state.walkMoveQueued)
    assert.is_false(boop.state.walkRoomSettled)
    assert.is_function(scheduled[1])

    scheduled[1]()

    assert.stub(raise_event_stub).was_called_with("demonwalker.move")
  end)

  it("does not advance while a valid target remains in the room", function()
    boop.state.walkActive = true
    gmcp.Char.Items.List = {
      location = "room",
      items = {
        { id = "42", name = "a test denizen", attrib = "m" },
      },
    }

    boop.onRoomItemsList()

    assert.is_true(boop.state.walkRoomSettled)
    assert.is_false(boop.state.walkMoveQueued)
    assert.stub(raise_event_stub).was_not_called()
  end)

  it("waits for gold handling to finish before advancing", function()
    boop.state.walkActive = true
    boop.state.walkRoomSettled = true
    boop.state.goldGetPending = true

    local moved, reason = boop.walk.maybeAdvance("test pending gold")
    assert.is_false(moved)
    assert.are.equal("loot handling is still pending", reason)

    boop.onGoldGetSuccess()

    assert.is_true(boop.state.walkMoveQueued)
    assert.is_function(scheduled[1])

    scheduled[1]()

    assert.stub(raise_event_stub).was_called_with("demonwalker.move")
  end)

  it("waits for loot to settle before advancing", function()
    boop.state.walkActive = true
    boop.state.walkRoomSettled = true
    boop.state.goldSettlePending = true

    local moved, reason = boop.walk.maybeAdvance("test loot settle")
    assert.is_false(moved)
    assert.are.equal("waiting for loot settle", reason)
  end)

  it("arms a fallback settle timer on room change even if demonwalker arrived is missed", function()
    boop.state.walkActive = true
    gmcp.Room.Info.num = 200

    boop.walk.onRoomChange()

    assert.is_false(boop.state.walkRoomSettled)
    assert.is_function(scheduled[1])

    scheduled[1]()

    assert.is_true(boop.state.walkMoveQueued)
    assert.is_function(scheduled[2])
    scheduled[2]()
    assert.stub(raise_event_stub).was_called_with("demonwalker.move")
  end)
end)
