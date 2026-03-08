local helper = dofile(os.getenv("TESTS_DIRECTORY") .. "/support/boop_test_helper.lua")

describe("boop stats", function()
  local epoch_stub
  local send_gmcp_stub
  local info_stub
  local save_stats_stub
  local messages

  before_each(function()
    helper.reset()
    messages = {}

    send_gmcp_stub = stub(_G, "sendGMCP", function(_) end)
    info_stub = stub(boop.util, "info", function(msg)
      messages[#messages + 1] = msg
    end)
    save_stats_stub = stub(boop.db, "saveStats", function() end)
  end)

  after_each(function()
    if epoch_stub then
      epoch_stub:revert()
      epoch_stub = nil
    end
    if send_gmcp_stub then
      send_gmcp_stub:revert()
      send_gmcp_stub = nil
    end
    if info_stub then
      info_stub:revert()
      info_stub = nil
    end
    if save_stats_stub then
      save_stats_stub:revert()
      save_stats_stub = nil
    end
  end)

  it("accumulates gold and experience deltas into session trip lifetime and area buckets", function()
    helper.setArea("Test Area")
    boop.ui.setEnabled(true, true)

    gmcp.Char.Status.gold = "1000"
    gmcp.Char.Status.level = "80"
    gmcp.Char.Status.xp = "50.0"
    boop.stats.onCharStatus()

    gmcp.Char.Status.gold = "1125"
    gmcp.Char.Status.level = "80"
    gmcp.Char.Status.xp = "51.5"
    boop.stats.onCharStatus()

    assert.are.equal(125, boop.stats.session.gold)
    assert.are.equal(1.5, boop.stats.session.experience)
    assert.are.equal(125, boop.stats.trip.areas["Test Area"].gold)
    assert.are.equal(1.5, boop.stats.trip.areas["Test Area"].experience)
    assert.are.equal(125, boop.stats.lifetime.gold)
    assert.are.equal(1.5, boop.stats.lifetime.experience)
  end)

  it("tracks raw xp gains separately from percent-based gmcp xp", function()
    helper.setArea("Test Area")
    boop.ui.setEnabled(true, true)

    boop.stats.onExperienceGain("28,376")

    assert.are.equal(28376, boop.stats.session.rawExperience)
    assert.are.equal(28376, boop.stats.trip.rawExperience)
    assert.are.equal(28376, boop.stats.lifetime.rawExperience)
    assert.are.equal(28376, boop.stats.session.areas["Test Area"].rawExperience)
  end)

  it("reseeds status baselines on init so existing wealth and xp are not counted as gains", function()
    gmcp.Char.Status.gold = "2500"
    gmcp.Char.Status.level = "80"
    gmcp.Char.Status.xp = "55.0"
    boop.stats.lastGold = 100
    boop.stats.lastXp = 10

    boop.stats.init()

    assert.are.equal(2500, boop.stats.lastGold)
    assert.are.equal(8055, boop.stats.lastXp)
    assert.are.equal(0, boop.stats.session.gold)
    assert.are.equal(0, boop.stats.session.experience)

    boop.stats.onCharStatus()

    assert.are.equal(0, boop.stats.session.gold)
    assert.are.equal(0, boop.stats.session.experience)
  end)

  it("does not seed percent-xp baseline from missing status values", function()
    helper.reset()

    assert.is_nil(boop.stats.lastXp)
    assert.are.equal(0, boop.stats.session.experience)

    gmcp.Char.Status.level = "80"
    gmcp.Char.Status.xp = "50.0"
    boop.stats.onCharStatus()

    assert.are.equal(0, boop.stats.session.experience)
    assert.are.equal(8050, boop.stats.lastXp)
  end)

  it("tracks retargets kills and time-to-kill across target cycles", function()
    local ticks = { 100, 104, 110 }
    local idx = 0
    epoch_stub = stub(_G, "getEpoch", function()
      idx = idx + 1
      return ticks[idx] or ticks[#ticks]
    end)

    helper.setArea("Test Area")
    boop.ui.setEnabled(true, true)

    boop.stats.onTargetSet("42", "first denizen")
    boop.stats.onTargetSet("43", "second denizen")
    boop.stats.onTargetRemoved("43", "second denizen")

    assert.are.equal(2, boop.stats.session.targets)
    assert.are.equal(1, boop.stats.session.retargets)
    assert.are.equal(1, boop.stats.session.abandoned)
    assert.are.equal(1, boop.stats.session.kills)
    assert.are.equal(6, boop.stats.session.totalTtk)
    assert.are.equal(6, boop.stats.session.bestTtk)
    assert.are.equal(6, boop.stats.session.worstTtk)
    assert.are.equal("second denizen", boop.stats.lastKill.name)
  end)

  it("shows a human-readable summary and area breakdown", function()
    helper.setArea("Test Area")
    boop.stats.session.gold = 200
    boop.stats.session.experience = 2.5
    boop.stats.session.rawExperience = 28376
    boop.stats.session.kills = 4
    boop.stats.session.targets = 5
    boop.stats.session.retargets = 1
    boop.stats.session.abandoned = 1
    boop.stats.session.roomMoves = 3
    boop.stats.session.flees = 0
    boop.stats.session.totalTtk = 16
    boop.stats.session.startedAt = 0
    boop.stats.session.endedAt = 120
    boop.stats.session.areas["Test Area"] = {
      gold = 200,
      experience = 2.5,
      rawExperience = 28376,
      kills = 4,
      totalTtk = 16,
      startedAt = 0,
      endedAt = 120,
    }

    boop.stats.show("session")
    boop.stats.showAreas("session", 3)

    assert.is_true(messages[1]:find("session stats: 4 kills | 5 targets | 200 gold | 2.50%% xp | 28376 xp", 1, true) ~= nil)
    assert.is_true(messages[2]:find("raw xp/kill 7094.0", 1, true) ~= nil)
    assert.is_true(messages[3]:find("851280.0 xp/hr", 1, true) ~= nil)
    assert.is_true(messages[5]:find("Test Area | 4 kills | 200 gold | 2.50%% xp | 28376 xp | avg ttk 4.00s", 1, true) ~= nil)
  end)

  it("starts and stops session and lifetime timing with boop enabled state", function()
    local ticks = { 100, 140, 200, 260 }
    local idx = 0
    epoch_stub = stub(_G, "getEpoch", function()
      idx = idx + 1
      return ticks[idx] or ticks[#ticks]
    end)

    boop.ui.setEnabled(true, true)
    boop.ui.setEnabled(false, true)
    boop.ui.setEnabled(true, true)
    boop.ui.setEnabled(false, true)

    assert.are.equal(100, boop.stats.lifetime.activeSeconds)
    assert.are.equal(60, boop.stats.session.activeSeconds)
    assert.is_nil(boop.stats.lifetime.activeSince)
    assert.is_nil(boop.stats.session.activeSince)
  end)

  it("resets requested stat scopes without touching the others", function()
    boop.stats.session.gold = 50
    boop.stats.session.rawExperience = 100
    boop.stats.trip.gold = 60
    boop.stats.lifetime.gold = 70

    boop.stats.reset("session")

    assert.are.equal(0, boop.stats.session.gold)
    assert.are.equal(0, boop.stats.session.rawExperience)
    assert.are.equal(60, boop.stats.trip.gold)
    assert.are.equal(70, boop.stats.lifetime.gold)
  end)

  it("resets all stat scopes and reseeds baselines", function()
    gmcp.Char.Status.gold = "3000"
    gmcp.Char.Status.level = "80"
    gmcp.Char.Status.xp = "60.0"
    boop.stats.session.gold = 50
    boop.stats.trip.gold = 60
    boop.stats.lifetime.gold = 70

    boop.stats.reset("all")

    assert.are.equal(0, boop.stats.session.gold)
    assert.are.equal(0, boop.stats.trip.gold)
    assert.are.equal(0, boop.stats.lifetime.gold)
    assert.are.equal(3000, boop.stats.lastGold)
    assert.are.equal(8060, boop.stats.lastXp)
  end)
end)
