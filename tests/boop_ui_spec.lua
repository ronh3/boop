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
  local rage_menu_stub
  local debug_stub
  local trace_show_stub
  local trace_clear_stub
  local append_cmd_stub
  local clear_cmd_stub

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
    if rage_menu_stub then
      rage_menu_stub:revert()
      rage_menu_stub = nil
    end
    if debug_stub then
      debug_stub:revert()
      debug_stub = nil
    end
    if trace_show_stub then
      trace_show_stub:revert()
      trace_show_stub = nil
    end
    if trace_clear_stub then
      trace_clear_stub:revert()
      trace_clear_stub = nil
    end
    if append_cmd_stub then
      append_cmd_stub:revert()
      append_cmd_stub = nil
    end
    if clear_cmd_stub then
      clear_cmd_stub:revert()
      clear_cmd_stub = nil
    end
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

  it("shows a dedicated control dashboard", function()
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
    boop.state.calledTargetId = "42"
    boop.ui.setConfigValue("partySize", "3")
    boop.stats.trip.stopwatch = 88
    boop.stats.trip.kills = 3
    boop.stats.trip.gold = 125
    boop.stats.trip.rawExperience = 28376

    echoes = {}
    boop.ui.controlCommand("")

    assert.are.equal("CONTROL DASHBOARD", echoes[1])
    assert.is_true(echoes[3]:find("State: on | mode: leader%-call | blocker: engaged target | next: let boop attack") ~= nil)
    assert.is_true(echoes[4]:find("Combat: class occultist | targeting whitelist | ragemode simple | queue OFF | prequeue ON", 1, true) ~= nil)
    assert.is_true(echoes[5]:find("Party: assist ON -> Leader | targetcall ON | size 3 | walk INSTALL | theme occultist", 1, true) ~= nil)
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
    boop.state.calledTargetId = "42"
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
    assert.is_true(joined:find("[7] Appearance               [ theme occultist ]", 1, true) ~= nil)
    assert.is_true(joined:find("Type: boop config home", 1, true) ~= nil)
    assert.is_true(joined:find("Type: boop party | boop theme | boop control", 1, true) ~= nil)
  end)

  it("treats bare numeric config commands as root navigation after entering a section", function()
    boop.ui.config("1")

    assert.are.equal("combat", boop.ui.configScreen)

    echoes = {}
    boop.ui.config("2")

    local joined = table.concat(echoes, "\n")
    assert.are.equal("targeting", boop.ui.configScreen)
    assert.is_true(joined:find("CONFIGURATION > Targeting", 1, true) ~= nil)
  end)

  it("still supports explicit section option syntax", function()
    local called = 0
    rage_menu_stub = stub(boop.ui, "showRageModeMenu", function()
      called = called + 1
    end)

    boop.ui.config("1 2")

    assert.are.equal(1, called)
    assert.are.equal("combat", boop.ui.configScreen)
  end)

  it("shows a hunting subsection with overview context first", function()
    helper.setTarget("42", "a vicious gnoll soldier", "100%")
    boop.ui.setEnabled(true, true)

    echoes = {}
    boop.ui.config("combat")

    local joined = table.concat(echoes, "\n")
    assert.is_true(joined:find("CONFIGURATION > Hunting", 1, true) ~= nil)
    assert.is_true(joined:find("Hunting: ON | rage simple | blocker: engaged target", 1, true) ~= nil)
    assert.is_true(joined:find("Target: 42 | a vicious gnoll soldier | next: let boop attack", 1, true) ~= nil)
    assert.is_true(joined:find("[1] Toggle hunting", 1, true) ~= nil)
    assert.is_true(joined:find("Type: boop config home | boop config combat <number> | boop config back", 1, true) ~= nil)
  end)

  it("shows a targeting subsection with live target context", function()
    helper.setDenizens({
      { id = "42", name = "a vicious gnoll soldier" },
      { id = "43", name = "a lesser gnoll" },
    })
    boop.ui.setEnabled(true, true)
    boop.state.calledTargetId = "43"

    echoes = {}
    boop.ui.config("targeting")

    local joined = table.concat(echoes, "\n")
    assert.is_true(joined:find("CONFIGURATION > Targeting", 1, true) ~= nil)
    assert.is_true(joined:find("Mode: whitelist | order: order | blocker: ready", 1, true) ~= nil)
    assert.is_true(joined:find("Called target: 43 | room denizens: 2 | next: let boop attack", 1, true) ~= nil)
    assert.is_true(joined:find("[6] Whitelist manager         [ OPEN ]", 1, true) ~= nil)
    assert.is_true(joined:find("Type: boop config home | boop config targeting <number> | boop config back", 1, true) ~= nil)
  end)

  it("keeps rich debug section callbacks scoped to debug actions", function()
    local callbacks = {}
    local debug_calls = 0
    local trace_show_calls = 0

    _G.cecho = function(_) end
    _G.cechoLink = function(_, cb, _, _)
      callbacks[#callbacks + 1] = cb
    end

    debug_stub = stub(boop.ui, "debug", function()
      debug_calls = debug_calls + 1
    end)
    trace_show_stub = stub(boop.trace, "show", function()
      trace_show_calls = trace_show_calls + 1
    end)

    boop.ui.config("debug")

    assert.is_true(type(callbacks[2]) == "function")
    assert.is_true(type(callbacks[3]) == "function")

    callbacks[2]()
    callbacks[3]()

    assert.are.equal(1, debug_calls)
    assert.are.equal(1, trace_show_calls)
    assert.are.equal("debug", boop.ui.configScreen)
  end)

  it("shows a cleaner debug snapshot", function()
    helper.setClass("Unnamable")
    helper.setDenizens({
      { id = "42", name = "a ghost bat" },
    })

    echoes = {}
    boop.ui.debug()

    local joined = table.concat(echoes, "\n")
    assert.are.equal("DEBUG SNAPSHOT", echoes[1])
    assert.is_true(joined:find("Runtime: enabled off | mode whitelist | class Unnamable", 1, true) ~= nil)
    assert.is_true(joined:find("Flow: blocker boop disabled | next boop on", 1, true) ~= nil)
    assert.is_true(joined:find("Combat: eq/bal 1/1 | rage 0 | denizens 1", 1, true) ~= nil)
    assert.is_true(joined:find("Target: (none)", 1, true) ~= nil)
    assert.is_true(joined:find("Quick: boop config home | boop config debug | boop trace show | boop debug attacks", 1, true) ~= nil)
  end)

  it("shows a rewritten help home with guided entry points", function()
    echoes = {}

    boop.ui.help("")

    local joined = table.concat(echoes, "\n")
    assert.are.equal("HELP", echoes[1])
    assert.is_true(joined:find("Start: boop | boop control | boop config | boop party | boop stats", 1, true) ~= nil)
    assert.is_true(joined:find("[1] Start Here -> Core entrypoints and the fastest way to get oriented.", 1, true) ~= nil)
    assert.is_true(joined:find("[4] Party & Leader -> Assist, leader target calls, roster management, and movement coordination.", 1, true) ~= nil)
    assert.is_true(joined:find("Type: boop help home", 1, true) ~= nil)
  end)

  it("shows a rewritten help topic with summary and notes", function()
    echoes = {}

    boop.ui.help("stats")

    local joined = table.concat(echoes, "\n")
    assert.are.equal("HELP > Stats & Optimization", echoes[1])
    assert.is_true(joined:find("Trip, session, lifetime, area, ability, target, and rage analytics.", 1, true) ~= nil)
    assert.is_true(joined:find("  boop stats compare [left] [right]", 1, true) ~= nil)
    assert.is_true(joined:find("    Compare two scopes, defaulting to trip versus lasttrip.", 1, true) ~= nil)
    assert.is_true(joined:find("Notes:", 1, true) ~= nil)
    assert.is_true(joined:find("Type: boop help home | boop help back", 1, true) ~= nil)
  end)

  it("adds rich hover descriptions to help command rows", function()
    local hints = {}

    _G.cecho = function(_) end
    _G.cechoLink = function(_, _, hint, _)
      hints[#hints + 1] = hint
    end

    boop.ui.help("party")

    local joined = table.concat(hints, "\n")
    assert.is_true(joined:find("Open the party dashboard with leader, assist, walk, target%-call, auto%-call, and roster state%.") ~= nil)
    assert.is_true(joined:find("Switch between solo hunting, assist mode, leader auto%-calling, and leader%-following target mode%.") ~= nil)
    assert.is_true(joined:find("Require a leader%-called target before boop starts attacking when following another leader%.") ~= nil)
    assert.is_true(joined:find("Inspect or control external autowalker integration when the walker package is available%.") ~= nil)
    assert.is_true(joined:find("Install the required demonnicAutoWalker package into Mudlet%.") ~= nil)
  end)

  it("shows the walker install note in party help notes", function()
    echoes = {}

    boop.ui.help("party")

    local joined = table.concat(echoes, "\n")
    assert.is_true(joined:find("If the walker package is missing, use `boop walk install` from inside Mudlet%.") ~= nil)
  end)

  it("makes rich footer command breadcrumbs clickable", function()
    local callbacks = {}
    local cmdline = {}

    _G.cecho = function(_) end
    _G.cechoLink = function(_, cb, _, _)
      callbacks[#callbacks + 1] = cb
    end
    append_cmd_stub = stub(_G, "appendCmdLine", function(text)
      cmdline[#cmdline + 1] = text
    end)
    clear_cmd_stub = stub(_G, "clearCmdLine", function()
      cmdline[#cmdline + 1] = "<clear>"
    end)

    boop.ui.printFooter("Type: boop config home | boop config debug <number> | boop trace show | boop debug attacks")

    assert.are.equal(4, #callbacks)

    callbacks[1]()
    callbacks[2]()
    callbacks[3]()
    callbacks[4]()

    assert.are.same({
      "<clear>", "boop config home",
      "<clear>", "boop config debug",
      "<clear>", "boop trace show",
      "<clear>", "boop debug attacks",
    }, cmdline)
  end)

  it("does not split help footer placeholders into fake commands", function()
    local callbacks = {}
    local cmdline = {}

    _G.cecho = function(_) end
    _G.cechoLink = function(_, cb, _, _)
      callbacks[#callbacks + 1] = cb
    end
    append_cmd_stub = stub(_G, "appendCmdLine", function(text)
      cmdline[#cmdline + 1] = text
    end)
    clear_cmd_stub = stub(_G, "clearCmdLine", function()
      cmdline[#cmdline + 1] = "<clear>"
    end)

    boop.ui.printFooter("Type: boop help home | boop help <number|topic>")

    assert.are.equal(2, #callbacks)

    callbacks[1]()
    callbacks[2]()

    assert.are.same({
      "<clear>", "boop help home",
      "<clear>", "boop help",
    }, cmdline)
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
    assert.is_true(echoes[3]:find("Coordination: mode leader%-call | leader Leader | assist ON %-?> Leader") ~= nil)
    assert.is_true(echoes[4]:find("Target gate: ON | called target: 43 | aff calls: ON", 1, true) ~= nil)
    assert.is_true(echoes[5]:find("Movement: walk INSTALL | blocker waiting for leader target call", 1, true) ~= nil)
    assert.is_true(echoes[6]:find("Next: wait for pt target line", 1, true) ~= nil)
    assert.is_true(echoes[7]:find("Party size: 3 | roster entries: 1", 1, true) ~= nil)
    assert.is_true(echoes[8]:find("Roster: infernal", 1, true) ~= nil)
    assert.are.equal("Quick: boop party assist <leader> | boop party targetcall on|off | boop party affcalls on|off | boop party walk | boop walk install | boop roster | boop combos", echoes[9])
  end)

  it("routes party affcalls subcommands through the party dashboard", function()
    boop.ui.partyCommand("affcalls off")

    assert.is_false(boop.config.rageAffCalloutsEnabled)
    assert.are.equal("[OK] rage affliction callouts: off", echoes[#echoes])
  end)

  it("switches operating modes with one command", function()
    boop.ui.assistCommand("Leader")
    boop.ui.modeCommand("leader-call")

    assert.is_true(boop.config.assistEnabled)
    assert.is_true(boop.config.targetCall)
    assert.are.equal("Leader", boop.config.assistLeader)
    assert.are.equal("[OK] mode: leader-call -> Leader", echoes[#echoes])
  end)

  it("supports leader mode for automatic target calling", function()
    boop.ui.assistCommand("Leader")

    boop.ui.modeCommand("leader")

    assert.is_false(boop.config.assistEnabled)
    assert.is_true(boop.config.autoTargetCall)
    assert.is_false(boop.config.targetCall)
    assert.are.equal("[OK] mode: leader", echoes[#echoes])
  end)

  it("applies the solo preset as a baseline bundle", function()
    boop.ui.assistCommand("Leader")
    boop.ui.modeCommand("leader-call")
    boop.ui.setConfigValue("partySize", "4")
    boop.ui.setRageMode("tempo")
    boop.ui.setConfigValue("useQueueing", "on")

    boop.ui.presetCommand("solo")

    assert.are.equal("whitelist", boop.config.targetingMode)
    assert.is_false(boop.config.useQueueing)
    assert.is_true(boop.config.prequeueEnabled)
    assert.are.equal(1, boop.config.attackLeadSeconds)
    assert.are.equal("simple", boop.config.attackMode)
    assert.are.equal(1, boop.config.partySize)
    assert.is_false(boop.config.rageAffCalloutsEnabled)
    assert.is_false(boop.config.assistEnabled)
    assert.is_false(boop.config.targetCall)
    assert.are.equal("[OK] preset applied: solo", echoes[#echoes])
  end)

  it("requires a leader before applying the leader-call preset", function()
    boop.ui.presetCommand("leader-call")

    assert.are.equal("[WARN] leader-call preset needs a leader; use: boop assist <name>", echoes[#echoes])
    assert.is_false(boop.config.assistEnabled)
    assert.is_false(boop.config.targetCall)
  end)

  it("applies the leader-call preset when a leader is configured", function()
    boop.ui.assistCommand("Leader")

    boop.ui.presetCommand("leader-call")

    assert.is_true(boop.config.assistEnabled)
    assert.is_true(boop.config.targetCall)
    assert.are.equal(2, boop.config.partySize)
    assert.are.equal("simple", boop.config.attackMode)
    assert.is_false(boop.config.rageAffCalloutsEnabled)
    assert.are.equal("[OK] preset applied: leader-call", echoes[#echoes])
  end)

  it("applies the leader preset without needing an assist leader", function()
    boop.ui.presetCommand("leader")

    assert.is_false(boop.config.assistEnabled)
    assert.is_true(boop.config.autoTargetCall)
    assert.is_false(boop.config.targetCall)
    assert.are.equal(2, boop.config.partySize)
    assert.are.equal("[OK] preset applied: leader", echoes[#echoes])
  end)

  it("sets and reports the active theme", function()
    boop.ui.themeCommand("ocean")

    assert.are.equal("ocean", boop.config.uiTheme)
    assert.are.equal("[OK] theme: ocean", echoes[#echoes])
  end)

  it("accepts adb palette names as boop themes", function()
    boop.ui.themeCommand("ashtan")

    assert.are.equal("ashtan", boop.config.uiTheme)
    assert.are.equal("[OK] theme: ashtan", echoes[#echoes])
    assert.is_true(boop.theme.exists("depthswalker"))
    assert.is_true(boop.theme.exists("targossas"))
  end)
end)
