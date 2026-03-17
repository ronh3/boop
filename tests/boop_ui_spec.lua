local helper = dofile(os.getenv("TESTS_DIRECTORY") .. "/support/boop_test_helper.lua")

describe("boop ui home", function()
  local echo_stub
  local ok_stub
  local warn_stub
  local info_stub
  local echoes
  local saved_cecho
  local saved_cecho_link
  local saved_echo
  local saved_echo_link

  before_each(function()
    helper.reset()
    echoes = {}
    echo_stub = stub(boop.util, "echo", function(msg)
      echoes[#echoes + 1] = msg
    end)
    ok_stub = stub(boop.util, "ok", function(msg)
      echoes[#echoes + 1] = "[OK] " .. msg
    end)
    warn_stub = stub(boop.util, "warn", function(msg)
      echoes[#echoes + 1] = "[WARN] " .. msg
    end)
    info_stub = stub(boop.util, "info", function(msg)
      echoes[#echoes + 1] = "[INFO] " .. msg
    end)

    saved_cecho = _G.cecho
    saved_cecho_link = _G.cechoLink
    saved_echo = _G.echo
    saved_echo_link = _G.echoLink
    _G.cecho = nil
    _G.cechoLink = nil
    _G.echo = nil
    _G.echoLink = nil
  end)

  after_each(function()
    if echo_stub then
      echo_stub:revert()
      echo_stub = nil
    end
    if ok_stub then ok_stub:revert() ok_stub = nil end
    if warn_stub then warn_stub:revert() warn_stub = nil end
    if info_stub then info_stub:revert() info_stub = nil end
    _G.cecho = saved_cecho
    _G.cechoLink = saved_cecho_link
    _G.echo = saved_echo
    _G.echoLink = saved_echo_link
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
    assert.is_true(echoes[3]:find("State: on | mode: solo | blocker: engaged target | next: let boop attack", 1, true) ~= nil)
    assert.is_true(echoes[4]:find("Class: occultist | targeting: whitelist | ragemode: simple", 1, true) ~= nil)
    assert.is_true(echoes[5]:find("Target: 42 | a vicious gnoll soldier | room denizens: 2", 1, true) ~= nil)
    assert.is_true(echoes[6]:find("Trip: running | kills 3 | gold 125 | xp 28376", 1, true) ~= nil)
    assert.are.equal("Quick: boop control | boop party | boop roster | boop mode | boop stats", echoes[7])
  end)

  it("shows a dedicated control center dashboard", function()
    helper.setClass("occultist")
    helper.setArea("Test Area")
    helper.setTarget("42", "a vicious gnoll soldier", "100%")
    boop.state.denizens = {
      { id = "42", name = "a vicious gnoll soldier" },
      { id = "43", name = "a lesser gnoll" },
    }
    boop.ui.setEnabled(true, true)
    boop.ui.assistCommand("Leader")
    boop.ui.modeCommand("leader-call")
    boop.ui.setConfigValue("partySize", "3")
    boop.stats.trip.stopwatch = 88
    boop.stats.trip.kills = 3
    boop.stats.trip.gold = 125
    boop.stats.trip.rawExperience = 28376

    echoes = {}
    boop.ui.controlCommand("")

    assert.are.equal("CONTROL CENTER", echoes[1])
    assert.is_true(echoes[3]:find("State: on | mode: leader%-call | blocker: engaged target | next: let boop attack") ~= nil)
    assert.is_true(echoes[4]:find("Combat: class occultist | targeting whitelist | ragemode simple | queue OFF | prequeue ON", 1, true) ~= nil)
    assert.is_true(echoes[5]:find("Party: assist ON -> Leader | targetcall ON | size 3 | walk OFF | theme default", 1, true) ~= nil)
    assert.is_true(echoes[6]:find("Target: 42 | a vicious gnoll soldier | room denizens: 2", 1, true) ~= nil)
    assert.is_true(echoes[7]:find("Trip: running | kills 3 | gold 125 | xp 28376", 1, true) ~= nil)
    assert.are.equal("Quick: boop config | boop party | boop roster | boop stats | boop theme", echoes[8])
  end)

  it("shows a cleaner configuration hub", function()
    helper.setClass("occultist")
    helper.setTarget("42", "a vicious gnoll soldier", "100%")
    boop.state.denizens = {
      { id = "42", name = "a vicious gnoll soldier" },
      { id = "43", name = "a lesser gnoll" },
    }
    boop.ui.setEnabled(true, true)
    boop.ui.assistCommand("Leader")
    boop.ui.modeCommand("leader-call")
    boop.ui.setConfigValue("partySize", "3")

    echoes = {}
    boop.ui.config("")

    local joined = table.concat(echoes, "\n")

    assert.are.equal("CONFIGURATION", echoes[1])
    assert.is_true(joined:find("Hunting: on | rage simple | queue OFF | prequeue ON", 1, true) ~= nil)
    assert.is_true(joined:find("Targeting: whitelist | order order | retarget ON | blocker: engaged target", 1, true) ~= nil)
    assert.is_true(joined:find("Target: 42 | a vicious gnoll soldier | next: let boop attack", 1, true) ~= nil)
    assert.is_true(joined:find("[4] Diagnostics              [ trace OFF | gag own OFF | gag others OFF ]", 1, true) ~= nil)
    assert.is_true(joined:find("[5] Party dashboard          [ leader-call | leader Leader | size 3 ]", 1, true) ~= nil)
    assert.is_true(joined:find("[7] Appearance               [ theme default ]", 1, true) ~= nil)
    assert.is_true(joined:find("Type: boop config party | boop config theme | boop config control", 1, true) ~= nil)
  end)

  it("shows a consolidated party dashboard and separate roster manager", function()
    helper.setClass("occultist")
    boop.ui.setEnabled(true, true)
    boop.ui.assistCommand("Leader")
    boop.ui.modeCommand("leader-call")
    boop.ui.setConfigValue("partySize", "3")
    boop.ui.rosterCommand("occultist infernal")
    boop.state.calledTargetId = "43"

    echoes = {}
    boop.ui.partyCommand("")

    assert.are.equal("PARTY", echoes[1])
    assert.is_true(echoes[3]:find("Mode: leader-call | leader: Leader | assist: ON -> Leader | targetcall: ON", 1, true) ~= nil)
    assert.is_true(echoes[4]:find("Walk: OFF | blocker: waiting for leader target call | next: wait for pt target line", 1, true) ~= nil)
    assert.is_true(echoes[5]:find("Party size: 3 | called target: 43", 1, true) ~= nil)
    assert.is_true(echoes[6]:find("Roster: infernal", 1, true) ~= nil)
  end)

  it("switches operating modes with one command", function()
    boop.ui.assistCommand("Leader")
    boop.ui.modeCommand("leader-call")

    assert.is_true(boop.config.assistEnabled)
    assert.is_true(boop.config.targetCall)
    assert.are.equal("Leader", boop.config.assistLeader)
    assert.are.equal("[OK] mode: leader-call -> Leader", echoes[#echoes])
  end)

  it("sets and reports the active theme", function()
    boop.ui.themeCommand("ocean")

    assert.are.equal("ocean", boop.config.uiTheme)
    assert.are.equal("[OK] theme: ocean", echoes[#echoes])
  end)
end)
