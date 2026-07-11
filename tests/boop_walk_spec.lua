local helper = dofile(os.getenv("TESTS_DIRECTORY") .. "/support/boop_test_helper.lua")

describe("boop walk integration", function()
  local saved_demonwalker
  local saved_raise_event
  local saved_temp_timer
  local raised_events

  local function enableOwnedWalk()
    local state = boop.runtime.state()
    boop.config.enabled = true
    boop.config.targetingMode = "auto"

    state.walk.active = true
    state.walk.owned = true
    state.walk.roomSettled = true
    state.walk.moveQueued = false

    return state
  end

  local function wasRaised(name)
    for _, event in ipairs(raised_events) do
      if event.name == name then
        return true
      end
    end
    return false
  end

  local function assertWalkHeld(expectedReason)
    local ok, reason = boop.walk.maybeAdvance("test blocker")

    assert.is_false(ok)
    assert.are.equal(expectedReason, reason)
    assert.is_false(wasRaised("boop.walk.move"))
    assert.is_false(wasRaised("demonwalker.move"))
  end

  before_each(function()
    helper.reset()
    raised_events = {}

    saved_demonwalker = _G.demonwalker
    saved_raise_event = _G.raiseEvent
    saved_temp_timer = _G.tempTimer

    _G.demonwalker = {
      enabled = true,
      init = function(_) end,
    }
    _G.raiseEvent = function(name, ...)
      raised_events[#raised_events + 1] = {
        name = name,
        args = { ... },
      }
    end
    _G.tempTimer = function(_, _)
      return 1
    end
  end)

  after_each(function()
    _G.demonwalker = saved_demonwalker
    _G.raiseEvent = saved_raise_event
    _G.tempTimer = saved_temp_timer
  end)

  local blockerCases = {
    {
      name = "a target remains selected",
      expected = "current target still set",
      seed = function(state)
        state.targeting.currentTargetId = "42"
      end,
    },
    {
      name = "flee is active",
      expected = "flee is active",
      seed = function(state)
        state.combat.fleeing = true
      end,
    },
    {
      name = "GMCP recovery owns a walk blocker",
      expected = "GMCP IRE missing",
      seed = function(_)
        helper.setRuntimeBlocker({
          code = "gmcp_ire_missing",
          label = "GMCP IRE missing",
          systems = { walk = true },
          waitsFor = { gmcp = true, prompt = true },
          observed = { ire = false },
        })
      end,
    },
    {
      name = "pull is away from the origin room",
      expected = "pull in progress",
      seed = function(state)
        state.combat.pullState = {
          active = true,
          originRoom = "1",
          currentRoom = "2",
        }
        helper.setRuntimeBlocker({
          code = "pull_away",
          label = "pull in progress",
          systems = { walk = true },
          waitsFor = { room = true },
          observed = { originRoom = "1", currentRoom = "2" },
        })
      end,
    },
    {
      name = "the room has not settled",
      expected = "room has not settled yet",
      seed = function(state)
        state.walk.roomSettled = false
      end,
    },
    {
      name = "diagnose hold is active",
      expected = "diag pause is active",
      seed = function(state)
        state.diag.hold = true
      end,
    },
    {
      name = "gold handling is pending",
      expected = "loot handling is still pending",
      seed = function(state)
        state.gold.autoGrabPending = true
        state.gold.getPending = true
        state.gold.putPending = true
      end,
    },
  }

  for _, entry in ipairs(blockerCases) do
    local case = entry
    it("holds walk advancement while " .. case.name, function()
      local state = enableOwnedWalk()
      case.seed(state)

      assertWalkHeld(case.expected)
    end)
  end
end)
