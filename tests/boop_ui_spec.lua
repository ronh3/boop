local helper = dofile(os.getenv("TESTS_DIRECTORY") .. "/support/boop_test_helper.lua")

describe("boop ui home", function()
  local echo_stub
  local echoes

  before_each(function()
    helper.reset()
    echoes = {}
    echo_stub = stub(boop.util, "echo", function(msg)
      echoes[#echoes + 1] = msg
    end)
  end)

  after_each(function()
    if echo_stub then
      echo_stub:revert()
      echo_stub = nil
    end
  end)

  it("shows a compact operations dashboard on bare boop", function()
    helper.setClass("occultist")
    helper.setArea("Test Area")
    helper.setTarget("42", "a vicious gnoll soldier", "100%")
    boop.state.denizens = {
      { id = "42", name = "a vicious gnoll soldier" },
      { id = "43", name = "a lesser gnoll" },
    }
    boop.ui.setEnabled(true, true)
    boop.stats.trip.stopwatch = 88
    boop.stats.trip.kills = 3
    boop.stats.trip.gold = 125
    boop.stats.trip.rawExperience = 28376

    boop.ui.home()

    assert.are.equal("BOOP", echoes[1])
    assert.is_true(echoes[3]:find("State: on | class: occultist | targeting: whitelist | ragemode: simple", 1, true) ~= nil)
    assert.is_true(echoes[4]:find("Target: 42 | a vicious gnoll soldier | room denizens: 2", 1, true) ~= nil)
    assert.is_true(echoes[5]:find("Trip: running | kills 3 | gold 125 | xp 28376", 1, true) ~= nil)
    assert.are.equal("Quick: boop status | boop config | boop stats | boop help", echoes[6])
  end)
end)
