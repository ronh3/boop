local helper = dofile(os.getenv("TESTS_DIRECTORY") .. "/support/boop_test_helper.lua")

describe("boop menu wiring", function()
  local saved_cecho
  local saved_cecho_link
  local saved_echo
  local saved_echo_link
  local callbacks
  local calls
  local active_stubs

  local function helpTopicCommands(topic)
    local commands = {}
    for _, section in ipairs({ topic.steps or {}, topic.commands or {}, topic.advanced or {} }) do
      for _, entry in ipairs(section) do
        commands[#commands + 1] = tostring((type(entry) == "table" and entry.command) or entry or "")
      end
    end
    return commands
  end

  local function helpTopics()
    local topics = {}
    for _, topic in ipairs(boop.ui.helpTopics or {}) do
      topics[#topics + 1] = {
        key = topic.key,
        commands = helpTopicCommands(topic),
      }
    end
    return topics
  end

  local function clearCalls()
    calls = {}
  end

  local function captureArgs(...)
    local args = {}
    for i = 1, select("#", ...) do
      args[i] = select(i, ...)
    end
    return args
  end

  local function seedExpectation(seed)
    return {
      { label = "clearCmdLine", args = {} },
      { label = "appendCmdLine", args = { seed } },
    }
  end

  local function assertCallLog(expected)
    assert.are.equal(#expected, #calls)
    for i, entry in ipairs(expected) do
      assert.are.equal(entry.label, calls[i].label)
      assert.are.same(entry.args or {}, calls[i].args or {})
    end
  end

  local function expectCallback(callback, expected)
    clearCalls()
    callback()
    assertCallLog(expected)
  end

  local function addStub(target, key, label)
    active_stubs[#active_stubs + 1] = stub(target, key, function(...)
      calls[#calls + 1] = {
        label = label or key,
        args = captureArgs(...),
      }
    end)
  end

  local function captureCallbacks(render)
    callbacks = {}
    _G.cecho = function(_) end
    _G.cechoLink = function(text, cb, hint, _)
      callbacks[#callbacks + 1] = {
        text = tostring(text or ""),
        callback = cb,
        hint = tostring(hint or ""),
      }
    end
    render()
    return callbacks
  end

  before_each(function()
    helper.reset()
    callbacks = {}
    calls = {}
    active_stubs = {}

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
    for i = #active_stubs, 1, -1 do
      active_stubs[i]:revert()
      active_stubs[i] = nil
    end

    _G.cecho = saved_cecho
    _G.cechoLink = saved_cecho_link
    _G.echo = saved_echo
    _G.echoLink = saved_echo_link
  end)

  it("wires the home dashboard quick actions and footer seeds", function()
    captureCallbacks(function()
      boop.ui.home()
    end)

    assert.are.equal(10, #callbacks)

    addStub(boop.ui, "walkCommand", "walkCommand")
    addStub(boop.ui, "partyCommand", "partyCommand")
    addStub(boop.ui, "modeCommand", "modeCommand")
    addStub(boop.stats, "command", "stats.command")
    addStub(boop.ui, "themeCommand", "themeCommand")
    addStub(_G, "appendCmdLine", "appendCmdLine")
    addStub(_G, "clearCmdLine", "clearCmdLine")

    expectCallback(callbacks[1].callback, { { label = "walkCommand", args = { "install" } } })
    expectCallback(callbacks[2].callback, { { label = "partyCommand", args = { "" } } })
    expectCallback(callbacks[3].callback, { { label = "modeCommand", args = { "" } } })
    expectCallback(callbacks[4].callback, { { label = "stats.command", args = { "" } } })
    expectCallback(callbacks[5].callback, { { label = "themeCommand", args = { "" } } })

    expectCallback(callbacks[6].callback, seedExpectation("boop control"))
    expectCallback(callbacks[7].callback, seedExpectation("boop party"))
    expectCallback(callbacks[8].callback, seedExpectation("boop roster"))
    expectCallback(callbacks[9].callback, seedExpectation("boop mode"))
    expectCallback(callbacks[10].callback, seedExpectation("boop stats"))
  end)

  it("wires the control dashboard rows and footer seeds", function()
    captureCallbacks(function()
      boop.ui.controlCommand("")
    end)

    assert.are.equal(19, #callbacks)

    addStub(boop.ui, "setEnabled", "setEnabled")
    addStub(boop.ui, "modeCommand", "modeCommand")
    addStub(boop.ui, "config", "config")
    addStub(boop.ui, "partyCommand", "partyCommand")
    addStub(boop.ui, "walkCommand", "walkCommand")
    addStub(boop.ui, "themeCommand", "themeCommand")
    addStub(boop.ui, "rosterCommand", "rosterCommand")
    addStub(boop.stats, "command", "stats.command")
    addStub(_G, "appendCmdLine", "appendCmdLine")
    addStub(_G, "clearCmdLine", "clearCmdLine")

    expectCallback(callbacks[1].callback, { { label = "setEnabled", args = { true } } })
    expectCallback(callbacks[2].callback, { { label = "modeCommand", args = { "" } } })
    expectCallback(callbacks[3].callback, { { label = "config", args = { "targeting" } } })
    expectCallback(callbacks[4].callback, { { label = "config", args = { "combat" } } })
    expectCallback(callbacks[5].callback, { { label = "config", args = { "combat" } } })
    expectCallback(callbacks[6].callback, { { label = "config", args = { "combat" } } })
    expectCallback(callbacks[7].callback, { { label = "partyCommand", args = { "" } } })
    expectCallback(callbacks[8].callback, { { label = "partyCommand", args = { "" } } })
    expectCallback(callbacks[9].callback, { { label = "partyCommand", args = { "" } } })
    expectCallback(callbacks[10].callback, { { label = "walkCommand", args = { "install" } } })
    expectCallback(callbacks[11].callback, { { label = "themeCommand", args = { "" } } })
    expectCallback(callbacks[12].callback, { { label = "partyCommand", args = { "" } } })
    expectCallback(callbacks[13].callback, { { label = "rosterCommand", args = { "" } } })
    expectCallback(callbacks[14].callback, { { label = "config", args = { "" } } })
    expectCallback(callbacks[15].callback, { { label = "stats.command", args = { "" } } })

    expectCallback(callbacks[16].callback, seedExpectation("boop control config"))
    expectCallback(callbacks[17].callback, seedExpectation("boop control party"))
    expectCallback(callbacks[18].callback, seedExpectation("boop control roster"))
    expectCallback(callbacks[19].callback, seedExpectation("boop control stats"))
  end)

  it("wires the party dashboard rows and footer seeds", function()
    captureCallbacks(function()
      boop.ui.partyCommand("")
    end)

    assert.are.equal(19, #callbacks)

    addStub(boop.ui, "modeCommand", "modeCommand")
    addStub(boop.ui, "targetCallCommand", "targetCallCommand")
    addStub(boop.ui, "walkCommand", "walkCommand")
    addStub(boop.ui, "affCallCommand", "affCallCommand")
    addStub(boop.ui, "rosterCommand", "rosterCommand")
    addStub(boop.ui, "combos", "combos")
    addStub(boop.ui, "config", "config")
    addStub(boop.ui, "controlCommand", "controlCommand")
    addStub(boop.targets, "displayWhitelist", "displayWhitelist")
    addStub(_G, "appendCmdLine", "appendCmdLine")
    addStub(_G, "clearCmdLine", "clearCmdLine")

    expectCallback(callbacks[1].callback, { { label = "modeCommand", args = { "" } } })
    expectCallback(callbacks[2].callback, seedExpectation("boop assist "))
    expectCallback(callbacks[3].callback, { { label = "modeCommand", args = { "assist" } } })
    expectCallback(callbacks[4].callback, { { label = "targetCallCommand", args = { "on" } } })
    expectCallback(callbacks[5].callback, seedExpectation("boop party size "))
    expectCallback(callbacks[6].callback, { { label = "walkCommand", args = { "install" } } })
    expectCallback(callbacks[7].callback, { { label = "walkCommand", args = { "status" } } })
    expectCallback(callbacks[8].callback, { { label = "walkCommand", args = { "move" } } })
    expectCallback(callbacks[9].callback, { { label = "affCallCommand", args = { "off" } } })
    expectCallback(callbacks[10].callback, { { label = "rosterCommand", args = { "" } } })
    expectCallback(callbacks[11].callback, { { label = "combos", args = { "party" } } })
    expectCallback(callbacks[12].callback, { { label = "config", args = { "party" } } })
    expectCallback(callbacks[13].callback, { { label = "controlCommand", args = { "" } } })
    expectCallback(callbacks[14].callback, { { label = "displayWhitelist", args = {} } })

    expectCallback(callbacks[15].callback, seedExpectation("boop party assist"))
    expectCallback(callbacks[16].callback, seedExpectation("boop party targetcall on|off"))
    expectCallback(callbacks[17].callback, seedExpectation("boop party affcalls on|off"))
    expectCallback(callbacks[18].callback, seedExpectation("boop whitelist share [area]"))
    expectCallback(callbacks[19].callback, seedExpectation("boop whitelist receive"))
  end)

  it("wires the config home rows and footer seeds", function()
    captureCallbacks(function()
      boop.ui.config("")
    end)

    assert.are.equal(17, #callbacks)

    addStub(boop.ui, "config", "config")
    addStub(boop.ui, "partyCommand", "partyCommand")
    addStub(boop.ui, "rosterCommand", "rosterCommand")
    addStub(boop.ui, "themeCommand", "themeCommand")
    addStub(boop.ui, "controlCommand", "controlCommand")
    addStub(boop.stats, "command", "stats.command")
    addStub(_G, "appendCmdLine", "appendCmdLine")
    addStub(_G, "clearCmdLine", "clearCmdLine")

    expectCallback(callbacks[1].callback, { { label = "config", args = { "combat" } } })
    expectCallback(callbacks[2].callback, { { label = "config", args = { "targeting" } } })
    expectCallback(callbacks[3].callback, { { label = "config", args = { "combat" } } })
    expectCallback(callbacks[4].callback, { { label = "config", args = { "targeting" } } })
    expectCallback(callbacks[5].callback, { { label = "config", args = { "loot" } } })
    expectCallback(callbacks[6].callback, { { label = "config", args = { "debug" } } })
    expectCallback(callbacks[7].callback, { { label = "partyCommand", args = { "" } } })
    expectCallback(callbacks[8].callback, { { label = "rosterCommand", args = { "" } } })
    expectCallback(callbacks[9].callback, { { label = "themeCommand", args = { "" } } })
    expectCallback(callbacks[10].callback, { { label = "controlCommand", args = { "" } } })
    expectCallback(callbacks[11].callback, { { label = "stats.command", args = { "" } } })

    expectCallback(callbacks[12].callback, seedExpectation("boop config home"))
    expectCallback(callbacks[13].callback, seedExpectation("boop config"))
    expectCallback(callbacks[14].callback, seedExpectation("boop config"))
    expectCallback(callbacks[15].callback, seedExpectation("boop party"))
    expectCallback(callbacks[16].callback, seedExpectation("boop theme"))
    expectCallback(callbacks[17].callback, seedExpectation("boop control"))
  end)

  it("wires the config hunting rows and footer seeds", function()
    captureCallbacks(function()
      boop.ui.config("combat")
    end)

    assert.are.equal(39, #callbacks)

    addStub(boop.ui, "config", "config")
    addStub(_G, "appendCmdLine", "appendCmdLine")
    addStub(_G, "clearCmdLine", "clearCmdLine")

    for i = 1, 18 do
      expectCallback(callbacks[(i * 2) - 1].callback, {
        { label = "config", args = { "combat " .. tostring(i) } },
      })
      expectCallback(callbacks[i * 2].callback, {
        { label = "config", args = { "combat " .. tostring(i) } },
      })
    end

    expectCallback(callbacks[37].callback, seedExpectation("boop config home"))
    expectCallback(callbacks[38].callback, seedExpectation("boop config combat"))
    expectCallback(callbacks[39].callback, seedExpectation("boop config back"))
  end)

  it("wires the config targeting rows and footer seeds", function()
    captureCallbacks(function()
      boop.ui.config("targeting")
    end)

    assert.are.equal(11, #callbacks)

    addStub(boop.ui, "config", "config")
    addStub(_G, "appendCmdLine", "appendCmdLine")
    addStub(_G, "clearCmdLine", "clearCmdLine")

    for i = 1, 8 do
      expectCallback(callbacks[i].callback, {
        { label = "config", args = { "targeting " .. tostring(i) } },
      })
    end

    expectCallback(callbacks[9].callback, seedExpectation("boop config home"))
    expectCallback(callbacks[10].callback, seedExpectation("boop config targeting"))
    expectCallback(callbacks[11].callback, seedExpectation("boop config back"))
  end)

  it("wires the config loot rows and footer seeds", function()
    captureCallbacks(function()
      boop.ui.config("loot")
    end)

    assert.are.equal(11, #callbacks)

    addStub(boop.ui, "config", "config")
    addStub(_G, "appendCmdLine", "appendCmdLine")
    addStub(_G, "clearCmdLine", "clearCmdLine")

    for i = 1, 4 do
      expectCallback(callbacks[(i * 2) - 1].callback, {
        { label = "config", args = { "loot " .. tostring(i) } },
      })
      expectCallback(callbacks[i * 2].callback, {
        { label = "config", args = { "loot " .. tostring(i) } },
      })
    end

    expectCallback(callbacks[9].callback, seedExpectation("boop config home"))
    expectCallback(callbacks[10].callback, seedExpectation("boop config loot"))
    expectCallback(callbacks[11].callback, seedExpectation("boop config back"))
  end)

  it("wires the config debug rows and footer seeds", function()
    captureCallbacks(function()
      boop.ui.config("debug")
    end)

    assert.are.equal(23, #callbacks)

    addStub(boop.ui, "config", "config")
    addStub(_G, "appendCmdLine", "appendCmdLine")
    addStub(_G, "clearCmdLine", "clearCmdLine")

    for i = 1, 10 do
      expectCallback(callbacks[(i * 2) - 1].callback, {
        { label = "config", args = { "debug " .. tostring(i) } },
      })
      expectCallback(callbacks[i * 2].callback, {
        { label = "config", args = { "debug " .. tostring(i) } },
      })
    end

    expectCallback(callbacks[21].callback, seedExpectation("boop config home"))
    expectCallback(callbacks[22].callback, seedExpectation("boop config debug"))
    expectCallback(callbacks[23].callback, seedExpectation("boop config back"))
  end)

  it("wires the help home rows and footer seeds", function()
    captureCallbacks(function()
      boop.ui.help("")
    end)

    assert.are.equal(17, #callbacks)

    addStub(boop.ui, "help", "help")
    addStub(_G, "appendCmdLine", "appendCmdLine")
    addStub(_G, "clearCmdLine", "clearCmdLine")

    expectCallback(callbacks[1].callback, { { label = "help", args = { "start" } } })
    expectCallback(callbacks[2].callback, { { label = "help", args = { "control" } } })
    expectCallback(callbacks[3].callback, { { label = "help", args = { "solo" } } })
    expectCallback(callbacks[4].callback, { { label = "help", args = { "targeting" } } })
    expectCallback(callbacks[5].callback, { { label = "help", args = { "combat" } } })
    expectCallback(callbacks[6].callback, { { label = "help", args = { "interrupts" } } })
    expectCallback(callbacks[7].callback, { { label = "help", args = { "loot" } } })
    expectCallback(callbacks[8].callback, { { label = "help", args = { "party" } } })
    expectCallback(callbacks[9].callback, { { label = "help", args = { "stats" } } })
    expectCallback(callbacks[10].callback, { { label = "help", args = { "diagnostics" } } })

    expectCallback(callbacks[11].callback, seedExpectation("boop"))
    expectCallback(callbacks[12].callback, seedExpectation("boop control"))
    expectCallback(callbacks[13].callback, seedExpectation("boop config"))
    expectCallback(callbacks[14].callback, seedExpectation("boop party"))
    expectCallback(callbacks[15].callback, seedExpectation("boop stats"))

    expectCallback(callbacks[16].callback, seedExpectation("boop help"))
    expectCallback(callbacks[17].callback, seedExpectation("boop help diagnostics"))
  end)

  it("wires every help topic command row to its seeded command", function()
    addStub(_G, "appendCmdLine", "appendCmdLine")
    addStub(_G, "clearCmdLine", "clearCmdLine")

    for _, topic in ipairs(helpTopics()) do
      captureCallbacks(function()
        boop.ui.help(topic.key)
      end)

      assert.are.equal(#topic.commands + 2, #callbacks)

      for i, command in ipairs(topic.commands) do
        expectCallback(callbacks[i].callback, seedExpectation(command))
      end

      expectCallback(callbacks[#topic.commands + 1].callback, seedExpectation("boop help home"))
      expectCallback(callbacks[#topic.commands + 2].callback, seedExpectation("boop help"))
    end
  end)

  it("wires the stats dashboard next views during an active trip", function()
    boop.stats.trip.stopwatch = true
    boop.stats.trip.kills = 2
    boop.stats.trip.rawExperience = 500

    captureCallbacks(function()
      boop.stats.command("")
    end)

    assert.are.equal(9, #callbacks)

    addStub(boop.stats, "command", "stats.command")
    addStub(_G, "appendCmdLine", "appendCmdLine")
    addStub(_G, "clearCmdLine", "clearCmdLine")

    expectCallback(callbacks[1].callback, { { label = "stats.command", args = { "compare trip lasttrip" } } })
    expectCallback(callbacks[2].callback, { { label = "stats.command", args = { "areas trip 5 xp" } } })
    expectCallback(callbacks[3].callback, { { label = "stats.command", args = { "targets trip 5" } } })
    expectCallback(callbacks[4].callback, { { label = "stats.command", args = { "abilities trip 5" } } })
    expectCallback(callbacks[5].callback, { { label = "stats.command", args = { "rage trip" } } })

    expectCallback(callbacks[6].callback, seedExpectation("boop stats areas"))
    expectCallback(callbacks[7].callback, seedExpectation("boop stats targets"))
    expectCallback(callbacks[8].callback, seedExpectation("boop stats abilities"))
    expectCallback(callbacks[9].callback, seedExpectation("boop stats compare"))
  end)

  it("wires the stats dashboard lifetime view actions when trip data is absent", function()
    boop.stats.lifetime.kills = 7
    boop.stats.lifetime.rawExperience = 1200

    captureCallbacks(function()
      boop.stats.command("")
    end)

    assert.are.equal(9, #callbacks)

    addStub(boop.stats, "command", "stats.command")
    addStub(boop.stats, "startTrip", "startTrip")
    addStub(_G, "appendCmdLine", "appendCmdLine")
    addStub(_G, "clearCmdLine", "clearCmdLine")

    expectCallback(callbacks[1].callback, { { label = "stats.command", args = { "lifetime" } } })
    expectCallback(callbacks[2].callback, { { label = "stats.command", args = { "areas lifetime 5 xp" } } })
    expectCallback(callbacks[3].callback, { { label = "stats.command", args = { "abilities lifetime 5" } } })
    expectCallback(callbacks[4].callback, { { label = "stats.command", args = { "crits lifetime" } } })
    expectCallback(callbacks[5].callback, { { label = "startTrip", args = {} } })

    expectCallback(callbacks[6].callback, seedExpectation("boop stats areas"))
    expectCallback(callbacks[7].callback, seedExpectation("boop stats targets"))
    expectCallback(callbacks[8].callback, seedExpectation("boop stats abilities"))
    expectCallback(callbacks[9].callback, seedExpectation("boop stats compare"))
  end)

  it("wires the stats dashboard idle actions before any activity exists", function()
    captureCallbacks(function()
      boop.stats.command("")
    end)

    assert.are.equal(9, #callbacks)

    addStub(boop.ui, "setEnabled", "setEnabled")
    addStub(boop.stats, "startTrip", "startTrip")
    addStub(boop.stats, "command", "stats.command")
    addStub(_G, "appendCmdLine", "appendCmdLine")
    addStub(_G, "clearCmdLine", "clearCmdLine")

    expectCallback(callbacks[1].callback, { { label = "setEnabled", args = { true } } })
    expectCallback(callbacks[2].callback, { { label = "startTrip", args = {} } })
    expectCallback(callbacks[3].callback, { { label = "stats.command", args = { "lifetime" } } })
    expectCallback(callbacks[4].callback, { { label = "stats.command", args = { "areas lifetime 5 xp" } } })
    expectCallback(callbacks[5].callback, { { label = "stats.command", args = { "abilities lifetime 5" } } })

    expectCallback(callbacks[6].callback, seedExpectation("boop stats areas"))
    expectCallback(callbacks[7].callback, seedExpectation("boop stats targets"))
    expectCallback(callbacks[8].callback, seedExpectation("boop stats abilities"))
    expectCallback(callbacks[9].callback, seedExpectation("boop stats compare"))
  end)
end)
