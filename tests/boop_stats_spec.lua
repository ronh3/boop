local helper = dofile(os.getenv("TESTS_DIRECTORY") .. "/support/boop_test_helper.lua")

describe("boop stats", function()
  local epoch_stub
  local send_gmcp_stub
  local info_stub
  local echo_stub
  local save_stats_stub
  local record_mob_xp_stub
  local clear_mob_xp_stub
  local messages
  local echoes
  local saved_cecho
  local saved_cecho_link

  before_each(function()
    helper.reset()
    messages = {}
    echoes = {}

    send_gmcp_stub = stub(_G, "sendGMCP", function(_) end)
    info_stub = stub(boop.util, "info", function(msg)
      messages[#messages + 1] = msg
    end)
    echo_stub = stub(boop.util, "echo", function(msg)
      echoes[#echoes + 1] = msg
    end)
    save_stats_stub = stub(boop.db, "saveStats", function() end)
    record_mob_xp_stub = stub(boop.db, "recordMobXpObservation", function() end)
    clear_mob_xp_stub = stub(boop.db, "clearMobXpStats", function() end)
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
    if echo_stub then
      echo_stub:revert()
      echo_stub = nil
    end
    if save_stats_stub then
      save_stats_stub:revert()
      save_stats_stub = nil
    end
    if record_mob_xp_stub then
      record_mob_xp_stub:revert()
      record_mob_xp_stub = nil
    end
    if clear_mob_xp_stub then
      clear_mob_xp_stub:revert()
      clear_mob_xp_stub = nil
    end
    if saved_cecho ~= nil then
      _G.cecho = saved_cecho
      saved_cecho = nil
    end
    if saved_cecho_link ~= nil then
      _G.cechoLink = saved_cecho_link
      saved_cecho_link = nil
    end
  end)

  it("accumulates gold and experience deltas into session trip lifetime and area buckets", function()
    helper.setArea("Test Area")
    boop.ui.setEnabled(true, true)
    boop.stats.startTrip()

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
    boop.stats.startTrip()

    boop.stats.onExperienceGain("28,376")

    assert.are.equal(28376, boop.stats.session.rawExperience)
    assert.are.equal(28376, boop.stats.trip.rawExperience)
    assert.are.equal(28376, boop.stats.lifetime.rawExperience)
    assert.are.equal(28376, boop.stats.session.areas["Test Area"].rawExperience)
  end)

  it("tracks per-mob xp observations with mean median and mode", function()
    helper.setArea("Test Area")
    boop.ui.setEnabled(true, true)
    boop.stats.onTargetSet("42", "a vicious gnoll soldier")

    boop.stats.onExperienceGain("28,000")
    boop.stats.onExperienceGain("28,000")
    boop.stats.onExperienceGain("29,000")
    boop.stats.onExperienceGain("31,000")

    local entry = boop.stats.getMobXp("Test Area", "a vicious gnoll soldier")
    assert.is_not_nil(entry)
    assert.are.equal(4, entry.observations)
    assert.are.equal(116000, entry.total)
    assert.are.equal(28000, entry.min)
    assert.are.equal(31000, entry.max)
    assert.are.equal("xp mean 29000 | median 28500 | mode 28000 (2x) | seen 4 | p1", boop.stats.formatMobXp("Test Area", "a vicious gnoll soldier"))
    assert.stub(record_mob_xp_stub).was.called(4)
  end)

  it("buckets mob xp observations by configured party size", function()
    helper.setArea("Test Area")
    boop.ui.setEnabled(true, true)
    boop.stats.onTargetSet("42", "a vicious gnoll soldier")
    boop.config.partySize = 1
    boop.stats.onExperienceGain("28,000")

    boop.config.partySize = 3
    boop.stats.onTargetSet("42", "a vicious gnoll soldier")
    boop.stats.onExperienceGain("9,500")

    assert.are.equal(28000, boop.stats.getMobXp("Test Area", "a vicious gnoll soldier", 1).total)
    assert.are.equal(9500, boop.stats.getMobXp("Test Area", "a vicious gnoll soldier", 3).total)
    assert.are.equal("xp mean 9500 | median 9500 | mode 9500 (1x) | seen 1 | p3", boop.stats.formatMobXp("Test Area", "a vicious gnoll soldier", 3))
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
    helper.setArea("Test Area")
    boop.ui.setEnabled(true, true)

    local ticks = { 100, 104, 110 }
    local idx = 0
    epoch_stub = stub(_G, "getEpoch", function()
      idx = idx + 1
      return ticks[idx] or ticks[#ticks]
    end)

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

    assert.is_true(messages[1]:find("session stats: 4 kills | 5 targets | 200 gold | 2.50% xp | 28376 xp", 1, true) ~= nil)
    assert.is_true(messages[2]:find("raw xp/kill 7094.0", 1, true) ~= nil)
    assert.is_true(messages[3]:find("851280.0 xp/hr", 1, true) ~= nil)
    assert.is_true(messages[6]:find("Test Area | 4 kills | 120.0 kills/hr | 200 gold | 6000.0 gold/hr | 28376 xp | 851280.0 xp/hr | avg ttk 4.00s", 1, true) ~= nil)
  end)

  it("shows ranked area performance with richer rate output", function()
    boop.stats.session.areas["Fast Area"] = {
      kills = 8,
      gold = 800,
      rawExperience = 40000,
      totalTtk = 20,
      startedAt = 0,
      endedAt = 120,
      activeSeconds = 120,
    }
    boop.stats.session.areas["Slow Area"] = {
      kills = 6,
      gold = 1200,
      rawExperience = 70000,
      totalTtk = 60,
      startedAt = 0,
      endedAt = 600,
      activeSeconds = 600,
    }

    boop.stats.showAreas("session", 5, "goldhr")

    assert.are.equal("session areas (sorted by goldhr):", messages[1])
    assert.is_true(messages[2]:find("Fast Area | 8 kills | 240.0 kills/hr | 800 gold | 24000.0 gold/hr | 40000 xp | 1200000.0 xp/hr | avg ttk 2.50s", 1, true) ~= nil)
    assert.is_true(messages[3]:find("Slow Area | 6 kills | 36.0 kills/hr | 1200 gold | 7200.0 gold/hr | 70000 xp | 420000.0 xp/hr | avg ttk 10.00s", 1, true) ~= nil)
  end)

  it("shows current-area mob xp summaries", function()
    helper.setArea("Test Area")
    boop.ui.setEnabled(true, true)
    boop.stats.onTargetSet("42", "a vicious gnoll soldier")
    boop.stats.onExperienceGain("28,000")
    boop.stats.onExperienceGain("29,000")
    boop.stats.onExperienceGain("29,000")
    boop.stats.onTargetSet("43", "a lesser gnoll")
    boop.stats.onExperienceGain("12,500")

    boop.stats.showMobs("Test Area", 5)

    assert.are.equal("mob xp stats for Test Area (party size 1):", messages[1])
    assert.is_true(messages[2]:find("a vicious gnoll soldier | seen 3 | mean 28666.7 | median 29000 | mode 29000 (2x)", 1, true) ~= nil)
    assert.is_true(messages[3]:find("a lesser gnoll | seen 1 | mean 12500 | median 12500 | mode 12500 (1x)", 1, true) ~= nil)
  end)

  it("shows per-target kill efficiency joined with current party-size xp stats", function()
    helper.setArea("Test Area")
    boop.ui.setEnabled(true, true)

    boop.stats.onTargetSet("42", "a vicious gnoll soldier")
    boop.stats.onExperienceGain("28,000")
    boop.stats.onTargetRemoved("42", "a vicious gnoll soldier")

    boop.stats.onTargetSet("42", "a vicious gnoll soldier")
    boop.stats.onExperienceGain("29,000")
    boop.stats.onTargetRemoved("42", "a vicious gnoll soldier")

    boop.stats.showTargets("session", 5)

    assert.are.equal("session target stats for Test Area (party size 1):", messages[1])
    assert.is_true(messages[2]:find("a vicious gnoll soldier | kills 2 | avg ttk 0s | best 0s | worst 0s | avg gold 0 | avg raw xp 28500 | best raw xp 29000", 1, true) ~= nil)
    assert.is_true(messages[2]:find("| xp mean 28500 | median 28500 | mode 28000 (1x)", 1, true) ~= nil)
  end)

  it("attributes gold deltas onto the recent target summary", function()
    helper.setArea("Test Area")
    boop.ui.setEnabled(true, true)
    boop.stats.startTrip()

    gmcp.Char.Status.gold = "1000"
    boop.stats.onCharStatus()

    boop.stats.onTargetSet("42", "a vicious gnoll soldier")
    boop.stats.onExperienceGain("28,000")
    boop.stats.onTargetRemoved("42", "a vicious gnoll soldier")

    gmcp.Char.Status.gold = "1125"
    boop.stats.onCharStatus()

    local entry = boop.stats.session.targetStats["Test Area"][1]["a vicious gnoll soldier"]
    assert.is_not_nil(entry)
    assert.are.equal(125, entry.gold)
    assert.are.equal(28000, entry.rawExperience)
    assert.are.equal(125, entry.bestGold)
    assert.are.equal(28000, entry.bestRawExperience)
  end)

  it("tracks per-ability combat stats from attack damage crit balance and kill lines", function()
    helper.setArea("Test Area")
    boop.ui.setEnabled(true, true)
    boop.config.gagOwnAttacks = false

    boop.gag.onAttackLine({
      ability = "Slaughter",
      actor = { kind = "literal", value = "You" },
      target = { kind = "match", index = 2 },
    }, { "line", "a vicious gnoll soldier" }, "You swing at a vicious gnoll soldier.")
    boop.gag.onDamageLine("12,345", "cutting", "Damage line")
    boop.gag.onCriticalLine("obliterating critical", "Crit line")
    boop.gag.onBalanceUsed("2.9", "Balance line")
    boop.gag.onSlainLine("a vicious gnoll soldier", "Slain line")

    local entry = boop.stats.session.abilities["Slaughter"]
    assert.is_not_nil(entry)
    assert.are.equal(1, entry.uses)
    assert.are.equal(1, entry.kills)
    assert.are.equal(12345, entry.totalDamage)
    assert.are.equal(12345, entry.maxDamage)
    assert.are.equal(12345, entry.minDamage)
    assert.are.equal(1, entry.hitsWithDamage)
    assert.are.equal(2.9, entry.totalBalance)
    assert.are.equal(1, entry.balances)
    assert.are.equal(1, entry.crits)
    assert.are.equal(1, entry.critTiers["8xCRIT"])
  end)

  it("shows per-ability summaries for a stat scope", function()
    boop.stats.session.abilities = {
      Slaughter = {
        uses = 3,
        kills = 2,
        totalDamage = 30000,
        hitsWithDamage = 3,
        maxDamage = 12345,
        minDamage = 8000,
        totalBalance = 8.7,
        balances = 3,
        crits = 2,
        critTiers = { ["8xCRIT"] = 1, ["32xCRIT"] = 1 },
      },
      Warp = {
        uses = 2,
        kills = 1,
        totalDamage = 9000,
        hitsWithDamage = 2,
        maxDamage = 5000,
        minDamage = 4000,
        totalBalance = 5.0,
        balances = 2,
        crits = 0,
        critTiers = {},
      },
    }

    boop.stats.showAbilities("session", 5)

    assert.are.equal("session ability stats:", messages[1])
    assert.is_true(messages[2]:find("Slaughter | uses 3 | kills 2 | avg dmg 10000 | max dmg 12345 | crit 66.7% | avg bal 2.90s | best crit 32xCRIT", 1, true) ~= nil)
    assert.is_true(messages[3]:find("Warp | uses 2 | kills 1 | avg dmg 4500 | max dmg 5000 | crit 0% | avg bal 2.50s", 1, true) ~= nil)
  end)

  it("shows crit summaries derived from ability usage", function()
    boop.stats.session.abilities = {
      Slaughter = {
        uses = 3,
        kills = 2,
        totalDamage = 30000,
        hitsWithDamage = 3,
        maxDamage = 12345,
        minDamage = 8000,
        totalBalance = 8.7,
        balances = 3,
        crits = 2,
        critTiers = { ["8xCRIT"] = 1, ["32xCRIT"] = 1 },
      },
      Warp = {
        uses = 2,
        kills = 1,
        totalDamage = 9000,
        hitsWithDamage = 2,
        maxDamage = 5000,
        minDamage = 4000,
        totalBalance = 5.0,
        balances = 2,
        crits = 1,
        critTiers = { ["2xCRIT"] = 1 },
      },
    }

    boop.stats.showCrits("session")

    assert.are.equal("session crits: 3 crits across 5 uses (60%)", messages[1])
    assert.are.equal("session crit tiers: 2x 1 | 4x 0 | 8x 1 | 16x 0 | 32x 1", messages[2])
  end)

  it("shows best-hit and kill-speed records for a stat scope", function()
    boop.stats.session.records = {
      bestHit = {
        ability = "Slaughter",
        target = "a vicious gnoll soldier",
        area = "Test Area",
        partySize = 3,
        damage = 12345,
        critTier = "32xCRIT",
      },
      fastestKill = {
        target = "a lesser gnoll",
        area = "Test Area",
        partySize = 1,
        ttk = 1.25,
      },
      slowestKill = {
        target = "a hulking troll",
        area = "Deep Dungeon",
        partySize = 2,
        ttk = 9.5,
      },
    }

    boop.stats.showRecords("session")

    assert.are.equal("session records:", messages[1])
    assert.are.equal("  best hit: 12345 dmg | Slaughter -> a vicious gnoll soldier | Test Area | p3 | 32xCRIT", messages[2])
    assert.are.equal("  fastest kill: 1.25s | a lesser gnoll | Test Area | p1", messages[3])
    assert.are.equal("  slowest kill: 9.50s | a hulking troll | Deep Dungeon | p2", messages[4])
  end)

  it("shows rage efficiency summaries", function()
    boop.ui.setEnabled(true, true)
    local ticks = { 10, 11, 12, 13 }
    local idx = 0
    epoch_stub = stub(_G, "getEpoch", function()
      idx = idx + 1
      return ticks[idx] or ticks[#ticks]
    end)

    boop.stats.onRageDecision({ mode = "combo", outcome = "combo_conditional", ability = { name = "fluctuate" }, targetId = "42" })
    boop.stats.onRageExecuted({ name = "fluctuate", desc = "Conditional", rage = 24 }, { mode = "combo", outcome = "combo_conditional" })
    boop.stats.onRageDecision({ mode = "tempo", outcome = "tempo_squeeze", ability = { name = "harry" }, targetId = "42" })
    boop.stats.onRageExecuted({ name = "harry", desc = "Big Damage", rage = 18 }, { mode = "tempo", outcome = "tempo_squeeze" })
    boop.stats.onRageDecision({ mode = "combo", outcome = "combo_hold", ability = nil, targetId = "42" })

    boop.stats.showRage("session")

    assert.are.equal("session rage: 3 decisions | 2 uses | 42 rage spent | avg cost 21 | holds 1 | suppressed 0 | shieldbreaks 0", messages[1])
    assert.are.equal("session rage flow: combo cond 1 | combo prime 0 | combo fallback 0 | tempo aff 0 | tempo squeeze 1 | tempo fallback 0", messages[2])
    assert.are.equal("session rage modes: combo 1 | tempo 1", messages[3])
    assert.are.equal("session rage abilities: fluctuate 1 | harry 1", messages[4])
  end)

  it("compares the current trip against the last trip snapshot", function()
    boop.stats.trip.meta = { attackMode = "combo", class = "occultist", partySize = 1, area = "Mhaldor" }
    boop.stats.trip.kills = 10
    boop.stats.trip.gold = 500
    boop.stats.trip.rawExperience = 40000
    boop.stats.trip.totalTtk = 30
    boop.stats.trip.retargets = 2
    boop.stats.trip.flees = 0
    boop.stats.trip.startedAt = 0
    boop.stats.trip.endedAt = 300
    boop.stats.trip.activeSeconds = 300

    boop.stats.lastTrip = {
      meta = { attackMode = "tempo", class = "occultist", partySize = 1, area = "Mhaldor" },
      kills = 8,
      gold = 440,
      rawExperience = 36000,
      totalTtk = 40,
      retargets = 3,
      flees = 1,
      startedAt = 0,
      endedAt = 400,
      activeSeconds = 400,
      areas = {},
      abilities = {},
      targetStats = {},
      rage = {},
      records = {},
    }

    boop.stats.showCompare("trip", "lasttrip")

    assert.are.equal("compare trip vs lasttrip: mode combo | class occultist | p1 | area Mhaldor || mode tempo | class occultist | p1 | area Mhaldor", messages[1])
    assert.are.equal("kills: 10 vs 8 (+2 | +25%)", messages[2])
    assert.are.equal("gold: 500 vs 440 (+60 | +13.6%)", messages[3])
    assert.are.equal("raw xp: 40000 vs 36000 (+4000 | +11.1%)", messages[4])
    assert.are.equal("avg ttk: 3 vs 5 (-2 | -40%)", messages[5])
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

  it("clears mob xp telemetry on lifetime reset", function()
    helper.setArea("Test Area")
    boop.ui.setEnabled(true, true)
    boop.stats.onTargetSet("42", "a vicious gnoll soldier")
    boop.stats.onExperienceGain("28,376")

    boop.stats.reset("lifetime")

    assert.is_nil(boop.stats.getMobXp("Test Area", "a vicious gnoll soldier"))
    assert.stub(clear_mob_xp_stub).was.called(1)
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

  it("shows mob xp summaries in plain whitelist output", function()
    helper.setArea("Test Area")
    helper.setWhitelist("Test Area", { "a vicious gnoll soldier" })
    boop.ui.setEnabled(true, true)
    boop.stats.onTargetSet("42", "a vicious gnoll soldier")
    boop.stats.onExperienceGain("28,000")
    boop.stats.onExperienceGain("29,000")
    saved_cecho = _G.cecho
    saved_cecho_link = _G.cechoLink
    _G.cecho = nil
    _G.cechoLink = nil

    boop.targets.displayWhitelist("Test Area")

    assert.are.equal("Whitelist for Test Area:", echoes[1])
    assert.is_true(echoes[2]:find("a vicious gnoll soldier | xp mean 28500 | median 28500 | mode 28000 (1x) | seen 2 | p1", 1, true) ~= nil)
  end)
end)
