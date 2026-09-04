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
  local walk_install_stub
  local gag_picker_stub
  local walker_fixture
  local saved_temp_timer
  local saved_kill_timer
  local saved_send_gmcp

  local function countOccurrences(text, expected)
    local count = 0
    local offset = 1
    while true do
      local found = text:find(expected, offset, true)
      if not found then
        return count
      end
      count = count + 1
      offset = found + #expected
    end
  end

  local function seedCanonicalOperations()
    helper.setRuntimeBlocker({
      owner = "gold:5",
      code = "gold_pack_pending",
      label = "gold pack pending",
      systems = { combat = true, gold = true, queue = true, walk = true },
      waitsFor = { inventory = true },
    })
    helper.setRuntimeBlocker({
      owner = "interrupt:9",
      code = "interrupt_pending",
      label = "interrupt nine pending",
      systems = { combat = true, queue = true },
      waitsFor = { prompt = true },
    })
    helper.setRuntimeBlocker({
      owner = "interrupt:2",
      code = "interrupt_pending",
      label = "interrupt two pending",
      systems = { combat = true, queue = true },
      waitsFor = { prompt = true },
    })
  end

  local function assertCompactCanonicalOperationOutput(render)
    echoes = {}
    boop.ui.setEnabled(true, true)
    seedCanonicalOperations()

    render()

    local joined = table.concat(echoes, "\n")
    assert.are.equal(
      1,
      countOccurrences(
        joined,
        "interrupt_pending -- interrupt two pending | +2 more"
      )
    )
    assert.is_true(joined:find("systems: combat, queue", 1, true) ~= nil)
    assert.is_true(joined:find("waits: prompt", 1, true) ~= nil)
    assert.is_nil(joined:find("interrupt nine pending", 1, true))
    assert.is_nil(joined:find("gold pack pending", 1, true))
    assert.is_nil(joined:find("ACTIVE OPERATIONS", 1, true))
  end

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
    saved_temp_timer = _G.tempTimer
    saved_kill_timer = _G.killTimer
    saved_send_gmcp = _G.sendGMCP
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
    if walk_install_stub then
      walk_install_stub:revert()
      walk_install_stub = nil
    end
    if gag_picker_stub then
      gag_picker_stub:revert()
      gag_picker_stub = nil
    end
    if walker_fixture then
      walker_fixture.restore()
      walker_fixture = nil
    end
    _G.cecho = saved_cecho
    _G.cechoLink = saved_cecho_link
    _G.echo = saved_echo
    _G.echoLink = saved_echo_link
    _G.tempTimer = saved_temp_timer
    _G.killTimer = saved_kill_timer
    _G.sendGMCP = saved_send_gmcp
  end)

  it("shows a compact operations dashboard on bare boop", function()
    helper.setClass("occultist")
    helper.learnSkill("Warp", "Occultism")
    helper.setArea("Test Area")
    helper.setTarget("42", "a vicious gnoll soldier", "100%")
    boop.state.targeting.denizens = {
      { id = "42", name = "a vicious gnoll soldier" },
      { id = "43", name = "a lesser gnoll" },
    }
    helper.setWhitelist("Test Area", { "a vicious gnoll soldier" })
    boop.ui.setEnabled(true, true)
    boop.stats.trip.stopwatch = 88
    boop.stats.trip.kills = 3
    boop.stats.trip.gold = 125
    boop.stats.trip.rawExperience = 28376

    boop.ui.home()

    assert.are.equal("BOOP", echoes[1])
    assert.is_true(echoes[3]:find("State: on | mode: solo | status: engaged_target -- engaged target | next: let boop attack", 1, true) ~= nil)
    assert.is_true(echoes[4]:find("Class: occultist | targeting: whitelist | ragemode: simple", 1, true) ~= nil)
    assert.is_true(echoes[5]:find("Target: 42 | a vicious gnoll soldier | room denizens: 2", 1, true) ~= nil)
    assert.is_true(echoes[6]:find("Trip: running | kills 3 | gold 125 | xp 28376", 1, true) ~= nil)
    assert.are.equal("Quick: boop control | boop party | boop roster | boop mode | boop stats", echoes[7])
  end)

  it("shows the installed version in compact and full status", function()
    boop.ui.status()
    assert.is_true(
      echoes[1]:find(
        "version: " .. tostring(boop.version),
        1,
        true
      ) ~= nil
    )

    echoes = {}
    boop.ui.status("status")
    local joined = table.concat(echoes, "\n")
    assert.is_true(
      joined:find(
        "version: " .. tostring(boop.version),
        1,
        true
      ) ~= nil
    )
  end)

  it("does not report an absent target as engaged", function()
    walker_fixture = helper.setWalker({
      available = true,
      attached = true,
    })
    helper.setTarget("152345", "Thierry, the ferryman", "80%")
    helper.setDenizens({})
    local observation = boop.room.roomObservationSnapshot()
    boop.state.walk.active = true
    boop.state.walk.owned = false
    boop.state.walk.arrivalRoom = observation.roomId
    boop.state.walk.roomGeneration = observation.generation
    boop.ui.setEnabled(true, true)

    boop.ui.status("status")

    local joined = table.concat(echoes, "\n")
    assert.is_nil(joined:find("engaged_target", 1, true))
    assert.is_true(joined:find("status: room_clear -- room clear", 1, true) ~= nil)
  end)

  it("reports a missing attack profile without creating an operation hold", function()
    helper.setClass("Futureclass")
    helper.setTarget("42", "a test denizen", "80%")
    helper.setDenizens({
      { id = "42", name = "a test denizen" },
    })
    boop.config.targetingMode = "auto"
    boop.ui.setEnabled(true, true)

    boop.ui.status("status")

    local joined = table.concat(echoes, "\n")
    assert.is_true(joined:find(
      "unsupported_class -- attack profile unavailable",
      1,
      true
    ) ~= nil)
    assert.is_true(joined:find("attackProfile: MISSING", 1, true) ~= nil)
    assert.are.equal(0, #boop.locks.operationLocksSnapshot())
  end)

  it("makes the home dashboard walk install row clickable when the walker package is missing", function()
    local links = {}
    local install_calls = 0

    _G.cecho = function(_) end
    _G.cechoLink = function(text, cb, hint, _)
      links[#links + 1] = { text = text, cb = cb, hint = hint }
    end
    walk_install_stub = stub(boop.walk, "install", function()
      install_calls = install_calls + 1
      return true
    end)

    boop.ui.home()

    local walk_link
    for _, link in ipairs(links) do
      if link.hint == "Install demonnicAutoWalker for walk controls" then
        walk_link = link
        break
      end
    end

    assert.is_not_nil(walk_link)
    assert.is_true(type(walk_link.cb) == "function")

    walk_link.cb()

    assert.are.equal(1, install_calls)
  end)

  it("shows a dedicated control dashboard", function()
    helper.setClass("occultist")
    helper.learnSkill("Warp", "Occultism")
    helper.setArea("Test Area")
    helper.setTarget("42", "a vicious gnoll soldier", "100%")
    boop.state.targeting.denizens = {
      { id = "42", name = "a vicious gnoll soldier" },
      { id = "43", name = "a lesser gnoll" },
    }
    helper.setWhitelist("Test Area", { "a vicious gnoll soldier" })
    boop.ui.setEnabled(true, true)
    boop.ui.assistCommand("Leader")
    boop.ui.modeCommand("leader-call")
    boop.state.targeting.calledTargetId = "42"
    boop.ui.setConfigValue("partySize", "3")
    boop.stats.trip.stopwatch = 88
    boop.stats.trip.kills = 3
    boop.stats.trip.gold = 125
    boop.stats.trip.rawExperience = 28376

    echoes = {}
    boop.ui.controlCommand("")

    assert.are.equal("CONTROL DASHBOARD", echoes[1])
    assert.is_true(echoes[3]:find("State: on | mode: leader%-call | status: engaged_target %-%- engaged target | next: let boop attack") ~= nil)
    assert.is_true(echoes[4]:find("Combat: class occultist | targeting whitelist | ragemode simple | queue OFF | prequeue ON", 1, true) ~= nil)
    assert.is_true(echoes[5]:find("Party: assist ON -> Leader | targetcall ON | size 3 | walk INSTALL | theme occultist", 1, true) ~= nil)
    assert.is_true(echoes[6]:find("Target: 42 | a vicious gnoll soldier | room denizens: 2", 1, true) ~= nil)
    assert.is_true(echoes[7]:find("Trip: running | kills 3 | gold 125 | xp 28376", 1, true) ~= nil)
    assert.are.equal("Quick: boop config | boop party | boop roster | boop stats | boop theme", echoes[8])
  end)

  it("shows a cleaner configuration hub", function()
    helper.setClass("occultist")
    helper.learnSkill("Warp", "Occultism")
    helper.setTarget("42", "a vicious gnoll soldier", "100%")
    boop.state.targeting.denizens = {
      { id = "42", name = "a vicious gnoll soldier" },
      { id = "43", name = "a lesser gnoll" },
    }
    helper.setWhitelist("UNKNOWN", { "a vicious gnoll soldier" })
    boop.ui.setEnabled(true, true)
    boop.ui.assistCommand("Leader")
    boop.ui.modeCommand("leader-call")
    boop.state.targeting.calledTargetId = "42"
    boop.ui.setConfigValue("partySize", "3")

    echoes = {}
    boop.ui.config("")

    local joined = table.concat(echoes, "\n")

    assert.are.equal("CONFIGURATION", echoes[1])
    assert.is_true(joined:find("Hunting: on | rage simple | queue OFF | prequeue ON", 1, true) ~= nil)
    assert.is_true(joined:find("Targeting: whitelist | order order | retarget ON | status: engaged_target -- engaged target", 1, true) ~= nil)
    assert.is_true(joined:find("Target: 42 | a vicious gnoll soldier | next: let boop attack", 1, true) ~= nil)
    assert.is_true(joined:find("[4] Diagnostics              [ trace OFF | gag own OFF | gag others OFF | gag mobs OFF ]", 1, true) ~= nil)
    assert.is_true(joined:find("[5] Party dashboard          [ leader-call | leader Leader | size 3 ]", 1, true) ~= nil)
    assert.is_true(joined:find("[7] Appearance               [ theme occultist ]", 1, true) ~= nil)
    assert.is_true(joined:find("Type: boop config home", 1, true) ~= nil)
    assert.is_true(joined:find("Type: boop party | boop theme | boop control", 1, true) ~= nil)
  end)

  it("treats bare numeric config commands as section actions after entering a section", function()
    local called = 0
    rage_menu_stub = stub(boop.ui, "showRageModeMenu", function()
      called = called + 1
    end)

    boop.ui.config("1")

    assert.are.equal("combat", boop.ui.configScreen)

    echoes = {}
    boop.ui.config("2")

    assert.are.equal(1, called)
    assert.are.equal("combat", boop.ui.configScreen)
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

  it("shows a hunting subsection with live context and inline controls", function()
    helper.setClass("occultist")
    helper.learnSkill("Warp", "Occultism")
    helper.setTarget("42", "a vicious gnoll soldier", "100%")
    helper.setDenizens({
      { id = "42", name = "a vicious gnoll soldier" },
    })
    helper.setWhitelist("UNKNOWN", { "a vicious gnoll soldier" })
    boop.ui.setEnabled(true, true)

    echoes = {}
    boop.ui.config("combat")

    local joined = table.concat(echoes, "\n")
    assert.is_true(joined:find("CONFIGURATION > Combat", 1, true) ~= nil)
    assert.is_true(joined:find("Hunting: ON | rage simple | status: engaged_target -- engaged target", 1, true) ~= nil)
    assert.is_true(joined:find("Target: 42 | a vicious gnoll soldier | next: let boop attack", 1, true) ~= nil)
    assert.is_true(joined:find("[1] Hunting                  [ ON ] [toggle]", 1, true) ~= nil)
    assert.is_true(joined:find("[13] Shield mode             [ BREAK ] [toggle]", 1, true) ~= nil)
    assert.is_true(joined:find("[17] Game separator          [ | ] [set]", 1, true) ~= nil)
    assert.is_true(joined:find("[18] Rage pool               [ off ] [set]", 1, true) ~= nil)
    assert.is_true(joined:find("[19] Keep boop enabled       [ OFF ] [toggle]", 1, true) ~= nil)
    assert.is_true(joined:find("Type: boop config home | boop config combat <number> | boop config back", 1, true) ~= nil)
  end)

  it("sets, reports, and clears temporary attack preferences", function()
    helper.setClass("Occultist")
    local key = boop.attacks.preferenceConfigKey("occultist", "dam", "")
    boop.config[key] = "warp"

    boop.ui.attackPreferenceCommand("temp dam lycantha")

    local details = boop.attacks.getStandardPreferenceDetails(
      "occultist",
      "dam"
    )
    assert.are.equal("temporary", details.source)
    assert.are.equal("lycantha", details.value)
    assert.are.equal("warp", boop.config[key])
    assert.are.equal(
      "[OK] temporary dam preference: lycantha (default, session only)",
      echoes[#echoes]
    )

    echoes = {}
    boop.ui.attackPreferenceCommand("")
    local joined = table.concat(echoes, "\n")
    assert.is_true(joined:find(
      "damage: lycantha (temporary; saved: warp)",
      1,
      true
    ) ~= nil)

    boop.ui.attackPreferenceCommand("temp clear dam")
    details = boop.attacks.getStandardPreferenceDetails(
      "occultist",
      "dam"
    )
    assert.are.equal("saved", details.source)
    assert.are.equal("warp", details.value)
  end)

  it("canonicalizes unique preference prefixes and rejects ambiguous aliases", function()
    dofile(
      os.getenv("TESTS_DIRECTORY")
        .. "/../src/scripts/boop/attacks/magi.lua"
    )
    helper.setClass("Magi")

    boop.ui.attackPreferenceCommand("dam horri")

    local key = boop.attacks.preferenceConfigKey("magi", "dam", "")
    assert.are.equal("horripilation", boop.config[key])
    assert.are.equal(
      "[OK] dam preference: horripilation (default)",
      echoes[#echoes]
    )

    echoes = {}
    boop.ui.attackPreferenceCommand("dam staffcast")

    assert.are.equal("horripilation", boop.config[key])
    assert.is_true(echoes[1]:find(
      "[WARN] Ambiguous dam preference `staffcast` for magi:",
      1,
      true
    ) ~= nil)
  end)

  it("rejects an aff rage mode when the active profile cannot use it", function()
    dofile(
      os.getenv("TESTS_DIRECTORY")
        .. "/../src/scripts/boop/attacks/infernal.lua"
    )
    helper.setClass("Infernal")
    boop.config.attackMode = "simple"

    assert.is_false(boop.ui.setAttackMode("aff"))

    assert.are.equal("simple", boop.config.attackMode)
    assert.are.equal(
      "[WARN] ragemode aff unavailable for Infernal: no affliction rage ability",
      echoes[#echoes]
    )
  end)

  it("validates and updates the rage pool threshold", function()
    assert.is_true(boop.ui.ragePoolCommand("40"))
    assert.are.equal(40, boop.config.ragePoolThreshold)
    assert.are.equal("[OK] rage pool threshold: 40", echoes[#echoes])

    assert.is_false(boop.ui.ragePoolCommand("40.5"))
    assert.are.equal(40, boop.config.ragePoolThreshold)
    assert.are.equal(
      "[WARN] Usage: boop ragepool <0-100|off>",
      echoes[#echoes]
    )

    assert.is_true(boop.ui.ragePoolCommand("off"))
    assert.are.equal(0, boop.config.ragePoolThreshold)
    assert.are.equal("[OK] rage pool threshold: off", echoes[#echoes])
  end)

  it("shows a targeting subsection with live target context", function()
    helper.setDenizens({
      { id = "42", name = "a vicious gnoll soldier" },
      { id = "43", name = "a lesser gnoll" },
    })
    helper.setWhitelist("UNKNOWN", { "a vicious gnoll soldier" })
    boop.ui.setEnabled(true, true)
    boop.state.targeting.calledTargetId = "43"

    echoes = {}
    boop.ui.config("targeting")

    local joined = table.concat(echoes, "\n")
    assert.is_true(joined:find("CONFIGURATION > Targeting", 1, true) ~= nil)
    assert.is_true(joined:find("Mode: whitelist | order: order | status: ready -- ready", 1, true) ~= nil)
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

    assert.is_true(type(callbacks[3]) == "function")
    assert.is_true(type(callbacks[5]) == "function")

    callbacks[3]()
    callbacks[5]()

    assert.are.equal(1, debug_calls)
    assert.are.equal(1, trace_show_calls)
    assert.are.equal("debug", boop.ui.configScreen)
  end)

  it("returns to combat config after changing rage mode from the combat screen", function()
    boop.ui.config("combat 2")

    echoes = {}
    boop.ui.setAttackMode("tempo")

    local joined = table.concat(echoes, "\n")
    assert.is_true(joined:find("%[OK%] ragemode: tempo") ~= nil)
    assert.is_true(joined:find("CONFIGURATION > Combat", 1, true) ~= nil)
    assert.are.equal("combat", boop.ui.configScreen)
  end)

  it("seeds rage pool edits and returns to combat config", function()
    local seeded = ""
    clear_cmd_stub = stub(_G, "clearCmdLine", function() end)
    append_cmd_stub = stub(_G, "appendCmdLine", function(text)
      seeded = text
    end)

    boop.ui.config("combat 18")
    assert.are.equal("boop ragepool ", seeded)

    echoes = {}
    boop.ui.ragePoolCommand("50")

    local joined = table.concat(echoes, "\n")
    assert.is_true(joined:find("%[OK%] rage pool threshold: 50") ~= nil)
    assert.is_true(joined:find("CONFIGURATION > Combat", 1, true) ~= nil)
    assert.are.equal("combat", boop.ui.configScreen)
  end)

  it("returns to loot config after setting a seeded pack value", function()
    clear_cmd_stub = stub(_G, "clearCmdLine", function() end)
    append_cmd_stub = stub(_G, "appendCmdLine", function() end)

    boop.ui.config("loot 2")

    echoes = {}
    boop.ui.setGoldPack("tophat")

    local joined = table.concat(echoes, "\n")
    assert.is_true(joined:find("%[OK%] gold pack: tophat") ~= nil)
    assert.is_true(joined:find("CONFIGURATION > Loot", 1, true) ~= nil)
    assert.are.equal("loot", boop.ui.configScreen)
  end)

  it("reports autogold settings without changing them", function()
    boop.config.autoGrabGold = true
    boop.config.goldPack = "tophat"
    boop.state.gold.getPending = true

    boop.ui.autoGoldStatus()

    assert.is_true(boop.config.autoGrabGold)
    assert.are.equal("tophat", boop.config.goldPack)
    assert.are.equal(
      "[INFO] autogold: on | pack: tophat | operation: pickup pending",
      echoes[#echoes]
    )
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
    assert.is_true(joined:find("Flow: status boop_disabled -- boop disabled | next boop on", 1, true) ~= nil)
    assert.is_true(joined:find("Combat: eq/bal 1/1 | rage 0 | denizens 1", 1, true) ~= nil)
    assert.is_true(joined:find("Target: (none)", 1, true) ~= nil)
    assert.is_true(joined:find("Quick: boop config home | boop config debug | boop trace show | boop debug attacks", 1, true) ~= nil)
  end)

  it("shows a rewritten help home with guided entry points", function()
    echoes = {}

    boop.ui.help("")

    local joined = table.concat(echoes, "\n")
    assert.are.equal("HELP", echoes[1])
    assert.is_true(joined:find("Common goals:", 1, true) ~= nil)
    assert.is_true(joined:find("[1] Start Here -> Get from a fresh install to a safe first hunt without guessing which screen to open.", 1, true) ~= nil)
    assert.is_true(joined:find("[4] Targeting & Lists -> How boop chooses denizens, why it may refuse to target, and how list data is managed.", 1, true) ~= nil)
    assert.is_true(joined:find("[7] Loot, Packs & Import -> Automatic sovereign pickup, optional pack stashing, and Foxhunt list import.", 1, true) ~= nil)
    assert.is_true(joined:find("Dashboards: boop | boop control | boop config | boop party | boop stats", 1, true) ~= nil)
    assert.is_true(joined:find("Type: boop help <topic>   (example: boop help targeting)", 1, true) ~= nil)
  end)

  it("shows a rewritten workflow help topic with first steps, commands, and notes", function()
    echoes = {}

    boop.ui.help("stats")

    local joined = table.concat(echoes, "\n")
    assert.are.equal("HELP > Stats & Optimization", echoes[1])
    assert.is_true(joined:find("Use trip, session, area, target, ability, crit, and rage data to compare hunts and tune choices.", 1, true) ~= nil)
    assert.is_true(joined:find("First steps:", 1, true) ~= nil)
    assert.is_true(joined:find("  boop stats", 1, true) ~= nil)
    assert.is_true(joined:find("Common commands:", 1, true) ~= nil)
    assert.is_true(joined:find("  boop stats compare <left> <right>", 1, true) ~= nil)
    assert.is_true(joined:find("    Compare two explicit scopes such as `session lifetime`.", 1, true) ~= nil)
    assert.is_true(joined:find("Notes:", 1, true) ~= nil)
    assert.is_true(joined:find("Type: boop help home | boop help <topic>", 1, true) ~= nil)
  end)

  it("renders a review-friendly help audit dump", function()
    echoes = {}

    boop.ui.help("audit")

    local joined = table.concat(echoes, "\n")
    assert.are.equal("HELP AUDIT", echoes[1])
    assert.is_true(joined:find("Review prompts: title fit | first useful command | command discoverability | next%-step clarity") ~= nil)
    assert.is_true(joined:find("%[1%] Start Here") ~= nil)
    assert.is_true(joined:find("Aliases: start, gettingstarted, intro, basics, general, main, home") ~= nil)
    assert.is_true(joined:find("First steps:", 1, true) ~= nil)
    assert.is_true(joined:find("Advanced:", 1, true) ~= nil)
    assert.is_true(joined:find("  boop help audit", 1, true) ~= nil)
    assert.is_true(joined:find("Dump every help topic, alias, command, and note into a review%-friendly audit view%.") ~= nil)
    assert.is_true(joined:find("Type: boop help <topic> | boop help audit", 1, true) ~= nil)
  end)

  it("adds rich hover descriptions to help command rows", function()
    local hints = {}

    _G.cecho = function(_) end
    _G.cechoLink = function(_, _, hint, _)
      hints[#hints + 1] = hint
    end

    boop.ui.help("party")

    local joined = table.concat(hints, "\n")
    assert.is_true(joined:find("Open the party dashboard and inspect current mode, leader, target gate, walker state, roster, and whitelist sync%.") ~= nil)
    assert.is_true(joined:find("Switch between solo hunting, assist mode, leader auto%-calling, and leader%-following target mode%.") ~= nil)
    assert.is_true(joined:find("Require a leader%-called target before boop starts attacking when following another leader%.") ~= nil)
    assert.is_true(joined:find("Inspect or control external autowalker integration when the walker package is available%.") ~= nil)
    assert.is_true(joined:find("Install the optional demonnicAutoWalker package required only for autowalk%.") ~= nil)
  end)

  it("states operation-owned interrupt timing without stale broad release wording", function()
    echoes = {}

    boop.ui.help("interrupts")

    local joined = table.concat(echoes, "\n")
    assert.is_true(joined:find(
      "Pending interrupts are operation-owned; repeats do not resend or restart the timer.",
      1,
      true
    ) ~= nil)
    assert.is_nil(joined:find(
      "If the expected confirmation line is missed, the timeout releases the attack hold.",
      1,
      true
    ))
  end)

  it("distinguishes room pickup from direct-to-hands gold without attack chaining", function()
    echoes = {}

    boop.ui.help("loot")

    local joined = table.concat(echoes, "\n")
    assert.is_true(joined:find(
      "Room gold is get-confirm-put; direct-to-hands gold skips get. Packing and attacks remain separate queued effects.",
      1,
      true
    ) ~= nil)
    assert.is_true(joined:find(
      "sovereign lines ending with `flying into your hands before they can reach the ground.`",
      1,
      true
    ) ~= nil)
    assert.is_nil(joined:find(
      "With queueing on, pickup is prepended to the next queued standard attack; otherwise boop falls back to the game-side freestand queue.",
      1,
      true
    ))
  end)

  it("states current-evidence, owned-stop, and explicit-install walker timing", function()
    echoes = {}

    boop.ui.help("party")

    local joined = table.concat(echoes, "\n")
    assert.is_true(joined:find(
      "Movement requires current Room.Info plus a complete current room item list; prompts and timers never settle the room.",
      1,
      true
    ) ~= nil)
    assert.is_true(joined:find(
      "Walk stop ends a boop-owned run or detaches from an externally owned run.",
      1,
      true
    ) ~= nil)
    assert.is_true(joined:find(
      "Walker install is explicit; status, start, move, and package-loss paths never install or update it.",
      1,
      true
    ) ~= nil)
    assert.is_nil(joined:find("prompt marks the room settled", 1, true))
    assert.is_nil(joined:find("timer marks the room settled", 1, true))
    assert.is_nil(joined:find(
      "boop walk stop always stops the external run",
      1,
      true
    ))
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

    boop.render.printFooter("Type: boop config home | boop config debug <number> | boop trace show | boop debug attacks")

    assert.are.equal(4, #callbacks)

    callbacks[1]()
    callbacks[2]()
    callbacks[3]()
    callbacks[4]()

    assert.are.same({
      "<clear>", "boop config home",
      "<clear>", "boop config debug ",
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

    boop.render.printFooter("Type: boop help home | boop help <number|topic>")

    assert.are.equal(2, #callbacks)

    callbacks[1]()
    callbacks[2]()

    assert.are.same({
      "<clear>", "boop help home",
      "<clear>", "boop help ",
    }, cmdline)
  end)

  it("shows a consolidated party dashboard and separate roster manager", function()
    helper.setClass("")
    boop.ui.setEnabled(true, true)
    boop.ui.assistCommand("Leader")
    boop.ui.modeCommand("leader-call")
    boop.ui.setConfigValue("partySize", "3")
    boop.ui.rosterCommand("occultist")
    boop.state.targeting.calledTargetId = "43"

    echoes = {}
    boop.ui.partyCommand("")

    assert.are.equal("PARTY", echoes[1])
    assert.is_true(echoes[3]:find("Coordination: mode leader%-call | leader Leader | assist ON %-?> Leader") ~= nil)
    assert.is_true(echoes[4]:find("Target gate: ON | called target: 43 | aff calls: ON", 1, true) ~= nil)
    assert.is_true(echoes[5]:find("Movement: walk INSTALL | status waiting_leader_target -- waiting for leader target call", 1, true) ~= nil)
    assert.is_true(echoes[6]:find("Next: wait for pt target line", 1, true) ~= nil)
    local joined = table.concat(echoes, "\n")
    assert.is_true(
      joined:find("Party size: 3 | roster entries: 1", 1, true) ~= nil,
      joined
    )
    assert.is_true(joined:find("Whitelist sync: NONE", 1, true) ~= nil)
    assert.is_true(joined:find("Roster: occultist", 1, true) ~= nil)
    assert.is_true(joined:find("Quick: boop party assist <leader> | boop party targetcall on|off | boop party affcalls on|off | boop whitelist share [area] | boop whitelist receive", 1, true) ~= nil)
  end)

  it("renders one canonical primary plus count across every compact status surface", function()
    assertCompactCanonicalOperationOutput(function()
      boop.ui.status("status")
    end)

    assertCompactCanonicalOperationOutput(function()
      boop.ui.home()
    end)

    assertCompactCanonicalOperationOutput(function()
      boop.ui.controlCommand("")
    end)

    assertCompactCanonicalOperationOutput(function()
      boop.ui.config("")
    end)

    assertCompactCanonicalOperationOutput(function()
      boop.ui.partyCommand("")
    end)

    assertCompactCanonicalOperationOutput(function()
      boop.ui.config("debug")
    end)
  end)

  it("renders every sorted operation under the full debug heading", function()
    boop.ui.setEnabled(true, true)
    seedCanonicalOperations()
    echoes = {}

    boop.ui.debug()

    local joined = table.concat(echoes, "\n")
    assert.are.equal(1, countOccurrences(joined, "ACTIVE OPERATIONS"))
    assert.are.equal(
      1,
      countOccurrences(
        joined,
        "interrupt_pending -- interrupt two pending | +2 more"
      )
    )
    local interruptTwoPos = assert(joined:find(
      "interrupt:2 | interrupt_pending -- interrupt two pending | systems: combat, queue | waits: prompt",
      1,
      true
    ))
    local interruptNinePos = assert(joined:find(
      "interrupt:9 | interrupt_pending -- interrupt nine pending | systems: combat, queue | waits: prompt",
      1,
      true
    ))
    local goldPos = assert(joined:find(
      "gold:5 | gold_pack_pending -- gold pack pending | systems: combat, gold, queue, walk | waits: inventory",
      1,
      true
    ))
    assert.is_true(interruptTwoPos < interruptNinePos)
    assert.is_true(interruptNinePos < goldPos)
  end)

  it("decrements the count for non-primary release and promotes the next owner", function()
    boop.ui.setEnabled(true, true)
    seedCanonicalOperations()

    echoes = {}
    boop.ui.status("status")
    local joined = table.concat(echoes, "\n")
    assert.is_true(joined:find(
      "interrupt_pending -- interrupt two pending | +2 more",
      1,
      true
    ) ~= nil)

    assert.is_true(boop.locks.clearBlocker(
      "interrupt:9",
      "non-primary complete"
    ))
    echoes = {}
    boop.ui.status("status")
    joined = table.concat(echoes, "\n")
    assert.is_true(joined:find(
      "interrupt_pending -- interrupt two pending | +1 more",
      1,
      true
    ) ~= nil)
    assert.is_nil(joined:find("| +2 more", 1, true))

    assert.is_true(boop.locks.clearBlocker(
      "interrupt:2",
      "primary recovered"
    ))
    echoes = {}
    boop.ui.status("status")
    joined = table.concat(echoes, "\n")
    assert.is_true(joined:find(
      "gold_pack_pending -- gold pack pending",
      1,
      true
    ) ~= nil)
    assert.is_nil(joined:find("interrupt two pending", 1, true))
  end)

  it("renders computed walker state and transition trace", function()
    local timers = helper.newTimerQueue()
    local sentGmcp = {}
    _G.tempTimer = timers.tempTimer
    _G.killTimer = timers.killTimer
    _G.sendGMCP = function(command)
      sentGmcp[#sentGmcp + 1] = command
    end
    walker_fixture = helper.setWalker({
      available = true,
      attached = true,
    })
    boop.config.enabled = true
    boop.config.targetingMode = "auto"
    boop.config.traceEnabled = true
    helper.setTarget("", "", "100%")
    helper.setDenizens({})

    assert.is_true(boop.walk.start())
    local state = boop.runtime.state()
    local generation = state.walk.generation
    echoes = {}
    boop.ui.status("status")
    local joined = table.concat(echoes, "\n")
    assert.is_true(joined:find(
      "room_partial -- current room evidence is incomplete",
      1,
      true
    ) ~= nil)

    gmcp.Room.Info.num = 2
    local observation = boop.room.startRoomObservation(2)
    assert.is_true(boop.walk.onRoomChange(generation, observation.generation))
    helper.seedRoomObservation(2, {
      generation = state.walk.roomGeneration,
      infoSeen = true,
      itemsSeen = true,
    })
    assert.is_true(boop.walk.onRoomSettled(
      "complete current room items",
      generation,
      state.walk.roomGeneration
    ))
    echoes = {}
    boop.ui.status("status")
    joined = table.concat(echoes, "\n")
    assert.is_true(joined:find(
      "move_pending -- move already queued",
      1,
      true
    ) ~= nil)

    local emitter = state.walk.emitterTimer
    assert.is_number(emitter)
    walker_fixture.setAvailable(false)
    timers.run(emitter)
    echoes = {}
    boop.ui.status("status")
    joined = table.concat(echoes, "\n")
    assert.is_true(joined:find(
      "walk_missing -- walk package missing",
      1,
      true
    ) ~= nil)
    assert.are.equal(0, #walker_fixture.installCalls)
    assert.are.equal(0, #walker_fixture.updateCalls)
    assert.is_true(#sentGmcp >= 1)

    local trace = table.concat(boop.state.trace.buffer or {}, "\n")
    assert.is_true(trace:find(
      "walk advance: complete current room items",
      1,
      true
    ) ~= nil)
    assert.is_true(trace:find(
      "walk generation invalidated: external_lost",
      1,
      true
    ) ~= nil)
    assert.are.equal(0, #boop.locks.operationLocksSnapshot())
  end)

  it("routes inactive walk stop through one non-silent info response", function()
    boop.runtime.state().walk.active = false

    boop.ui.walkCommand("stop")

    assert.are.same({
      "[INFO] walk stop: no active boop walk",
    }, echoes)
  end)

  it("projects the shared manual-targeting walk hold instead of room clear", function()
    walker_fixture = helper.setWalker({
      available = true,
      attached = true,
    })
    boop.config.enabled = true
    boop.config.targetingMode = "manual"
    helper.setTarget("", "", "100%")
    helper.setDenizens({})
    helper.seedRoomObservation("1", {
      generation = 9,
      infoSeen = true,
      itemsSeen = true,
    })
    local state = boop.runtime.state()
    state.walk.active = true
    state.walk.owned = false
    state.walk.roomSettled = true
    state.walk.arrivalRoom = "1"
    state.walk.generation = 7
    state.walk.roomGeneration = 9
    state.walk.moveQueued = false
    state.walk.moveIssuedForRoomGeneration = false
    state.walk.reservationId = 0

    boop.ui.status("status")

    local joined = table.concat(echoes, "\n")
    assert.is_true(joined:find(
      "manual_targeting -- manual targeting is active",
      1,
      true
    ) ~= nil)
    assert.is_true(joined:find("boop targeting auto", 1, true) ~= nil)
    assert.is_nil(joined:find("room_clear -- room clear", 1, true))
    assert.are.equal(0, state.walk.reservationId)
    assert.is_false(state.walk.moveQueued)
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

  it("supports setting the two-handed focus verb directly", function()
    boop.ui.focusVerbCommand("precision")

    assert.are.equal("precision", boop.config.focusVerb)
    assert.are.equal("[OK] focus verb: precision", echoes[#echoes])
  end)

  it("supports setting and toggling auto flee directly", function()
    boop.ui.fleeCommand("25%")

    assert.are.equal("25%", boop.config.fleeAt)
    assert.is_true(boop.config.fleeEnabled)
    assert.are.equal("[OK] auto flee: 25%", echoes[#echoes])

    boop.ui.fleeCommand("off")

    assert.is_false(boop.config.fleeEnabled)
    assert.are.equal("[OK] auto flee: off", echoes[#echoes])
  end)

  it("supports keeping boop enabled after auto flee", function()
    boop.ui.fleeCommand("keepenabled on")

    assert.is_true(boop.config.fleeKeepEnabled)
    assert.are.equal("[OK] keep boop enabled after flee: on", echoes[#echoes])

    boop.ui.fleeCommand("keepenabled toggle")

    assert.is_false(boop.config.fleeKeepEnabled)
    assert.are.equal("[OK] keep boop enabled after flee: off", echoes[#echoes])
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

  it("updates gag palette colors through the gag command", function()
    boop.ui.gagCommand("color separator khaki")

    assert.are.equal("khaki", boop.config.gagColorSeparator)
    assert.is_true(table.concat(echoes, "\n"):find("%[OK%] gag own separator color: khaki") ~= nil)
    assert.is_true(table.concat(echoes, "\n"):find("%[INFO%] gag colors %(own%)") ~= nil)
    assert.is_true(table.concat(echoes, "\n"):find("sample: You: Attack %-%> a denizen %(1234 cutting %- 8xCRIT%) %(Total: 1234%) %(Bal: 2%.1s%)") ~= nil)

    boop.ui.gagCommand("color bg off")

    assert.are.equal("", boop.config.gagColorBackground)
    assert.is_true(table.concat(echoes, "\n"):find("%[OK%] gag own background color: off") ~= nil)
  end)

  it("updates the others gag palette through the gag command", function()
    boop.ui.gagCommand("color others separator tomato")

    assert.are.equal("tomato", boop.config.gagOtherColorSeparator)
    assert.is_true(table.concat(echoes, "\n"):find("%[OK%] gag others separator color: tomato") ~= nil)
    assert.is_true(table.concat(echoes, "\n"):find("%[INFO%] gag colors %(others%)") ~= nil)
  end)

  it("updates the mobs gag palette through the gag command", function()
    boop.ui.gagCommand("color mobs who orange")

    assert.are.equal("orange", boop.config.gagMobColorWho)
    assert.is_true(table.concat(echoes, "\n"):find("%[OK%] gag mobs who color: orange") ~= nil)
    assert.is_true(table.concat(echoes, "\n"):find("%[INFO%] gag colors %(mobs%)") ~= nil)
    assert.is_true(table.concat(echoes, "\n"):find("sample: Mob: Damage %-%> You %(649 asphyxiation%)") ~= nil)
  end)

  it("opens a scoped gag role picker instead of treating the scope as a role", function()
    gag_picker_stub = stub(boop.ui, "showGagColorPicker")

    boop.ui.gagCommand("color others who")

    assert.stub(gag_picker_stub).was_called_with("others", "who")
  end)

  it("renders gag colors as an interactive browser", function()
    local rendered = {}
    local callbacks = {}

    _G.cecho = function(msg)
      rendered[#rendered + 1] = msg
    end
    _G.cechoLink = function(text, cb, _, _)
      rendered[#rendered + 1] = text
      callbacks[#callbacks + 1] = cb
    end

    boop.ui.gagCommand("colors")

    local joined = table.concat(rendered, "")
    assert.is_true(joined:find("GAG COLORS", 1, true) ~= nil)
    assert.is_true(joined:find("[others]", 1, true) ~= nil)
    assert.is_true(joined:find("[mobs]", 1, true) ~= nil)
    assert.is_true(joined:find("[color]", 1, true) ~= nil)
    assert.is_true(joined:find("[ auto ]", 1, true) ~= nil)
    assert.is_true(joined:find("[ off ]", 1, true) ~= nil)
    assert.is_true(joined:find("You", 1, true) ~= nil)
    assert.is_true(#callbacks > 6)
  end)

  it("renders theme list as a clickable sample browser", function()
    local rendered = {}
    local callbacks = {}

    _G.cecho = function(msg)
      rendered[#rendered + 1] = msg
    end
    _G.cechoLink = function(text, cb, _, _)
      rendered[#rendered + 1] = text
      callbacks[#callbacks + 1] = cb
    end

    boop.ui.themeCommand("list")

    local joined = table.concat(rendered, "")
    assert.is_true(joined:find("THEME SAMPLES", 1, true) ~= nil)
    assert.is_true(joined:find("[auto]", 1, true) ~= nil)
    assert.is_true(joined:find("[use]", 1, true) ~= nil)
    assert.is_true(joined:find("Ashtan", 1, true) ~= nil)
    assert.is_true(#callbacks > 10)
  end)
end)
