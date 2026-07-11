local helper = dofile(os.getenv("TESTS_DIRECTORY") .. "/support/boop_test_helper.lua")

describe("boop trace gmcp events", function()
  before_each(function()
    helper.reset()
    boop.config.traceEnabled = true
  end)

  local function traceText()
    return table.concat(boop.state.trace.buffer or {}, "\n")
  end

  local function assertTraceContains(expected)
    assert.is_true(traceText():find(expected, 1, true) ~= nil)
  end

  local function setBlocker(blocker)
    assert.is_function(boop.runtime.setBlocker)
    boop.runtime.setBlocker(blocker)
  end

  local function clearBlocker(reason)
    assert.is_function(boop.runtime.clearBlocker)
    boop.runtime.clearBlocker(reason)
  end

  it("logs room info transitions and room item gmcp events", function()
    gmcp.Room.Info = {
      num = 15,
      area = "Test Area",
      exits = { n = 16, s = 14 },
    }

    boop.onRoomInfo()

    gmcp.Char.Items.List = {
      location = "room",
      items = {
        { id = "1", name = "a gold sovereign" },
        { id = "42", name = "a vicious gnoll soldier", attrib = "m" },
      },
    }
    boop.onRoomItemsList()

    gmcp.Char.Items.Add = {
      location = "room",
      item = { id = "2", name = "a small pile of sovereigns" },
    }
    boop.onRoomItemsAdd()

    gmcp.Char.Items.Remove = {
      location = "room",
      item = { id = "42", name = "a vicious gnoll soldier" },
    }
    boop.onRoomItemsRemove()

    local trace = table.concat(boop.state.trace.buffer or {}, "\n")
    assert.is_true(trace:find("gmcp room info:", 1, true) ~= nil)
    assert.is_true(trace:find("| area=Test Area | exits=2 | moved=yes", 1, true) ~= nil)
    assert.is_true(trace:find("gmcp room items list: count=2 | gold=yes | gold=a gold sovereign (1)", 1, true) ~= nil)
    assert.is_true(trace:find("gmcp room item add: a small pile of sovereigns (2) | gold=yes", 1, true) ~= nil)
    assert.is_true(trace:find("gmcp room item remove: a vicious gnoll soldier (42) | gold=no", 1, true) ~= nil)
  end)

  it("logs canonical blocker enter and exit transitions once per state change", function()
    setBlocker({
      code = "gmcp_ire_missing",
      label = "GMCP IRE missing",
      systems = {
        target = true,
        combat = true,
        queue = true,
        gold = true,
        walk = true,
      },
      waitsFor = {
        gmcp = true,
        prompt = true,
      },
      observed = {
        ire = false,
        room = "1",
      },
    })

    setBlocker({
      code = "gmcp_ire_missing",
      label = "GMCP IRE missing",
      systems = {
        target = true,
        combat = true,
        queue = true,
        gold = true,
        walk = true,
      },
      waitsFor = {
        gmcp = true,
        prompt = true,
      },
      observed = {
        ire = false,
        room = "1",
      },
    })

    clearBlocker("gmcp recovered")

    local trace = traceText()
    local first_enter = trace:find("blocker enter: gmcp_ire_missing -- GMCP IRE missing | systems=combat,gold,queue,target,walk | waitsFor=gmcp,prompt | observed=ire:false,room:1", 1, true)
    assert.is_true(first_enter ~= nil)
    assert.is_nil(trace:find("blocker enter: gmcp_ire_missing", first_enter + 1, true))
    assertTraceContains("blocker exit: gmcp_ire_missing -- GMCP IRE missing | reason=gmcp recovered")
  end)

  it("logs target-loss cleanup, recovery, and valid retarget decisions from owned state", function()
    helper.setArea("Test Area")
    helper.setClass("Occultist")
    helper.learnSkill("Lycantha", "Domination")
    gmcp.Char.Items.List = {
      location = "room",
      items = {
        { id = "42", name = "a first denizen", attrib = "m" },
        { id = "43", name = "an excluded denizen", attrib = "mx" },
        { id = "44", name = "a valid replacement", attrib = "m" },
      },
    }
    boop.onRoomItemsList()
    helper.setTarget("42", "a first denizen", "80%")
    helper.seedAutomationIntent()
    boop.config.enabled = true
    boop.config.targetingMode = "auto"

    gmcp.Char.Items.Remove = {
      location = "room",
      item = { id = "42", name = "a first denizen", attrib = "m" },
    }

    boop.onRoomItemsRemove()

    assertTraceContains("target lost: 42 -- a first denizen")
    assertTraceContains("automation intent cleared: target_lost | target=42 | queue=prequeued aliasDirty=false | walk=active moveQueued=true | gold=get,put | diag=clear | gag=clear")
    assertTraceContains("retarget selected: 44 -- a valid replacement | reason=target_lost")
    assert.is_nil(traceText():find("an excluded denizen", 1, true))
  end)

  it("logs flee cleanup, pull holds, and GMCP recovery using normalized owned values", function()
    local state = helper.seedAutomationIntent()
    state.diag.hold = true
    state.diag.label = "diag"
    state.gag.pendingAttack = {
      source = "self",
      ability = "hound",
      target = "a first denizen",
    }

    assert.is_function(boop.runtime.clearAutomationIntent)
    boop.runtime.clearAutomationIntent("flee", {
      source = "auto-flee",
    })

    setBlocker({
      code = "pull_away",
      label = "pull in progress",
      systems = {
        target = true,
        combat = true,
        walk = true,
      },
      waitsFor = {
        room = true,
      },
      observed = {
        originRoom = "1",
        currentRoom = "2",
      },
    })

    setBlocker({
      code = "gmcp_ire_missing",
      label = "GMCP IRE missing",
      systems = {
        target = true,
        combat = true,
        queue = true,
        gold = true,
        walk = true,
      },
      waitsFor = {
        gmcp = true,
        prompt = true,
      },
      observed = {
        ire = false,
      },
    })

    local trace = traceText()
    assert.is_true(trace:find("automation intent cleared: flee | source=auto-flee | target=42 | queue=prequeued aliasDirty=false | walk=active moveQueued=true | gold=get,put | diag=hold:diag | gag=pending:self/hound/a first denizen", 1, true) ~= nil)
    assert.is_true(trace:find("blocker enter: pull_away -- pull in progress | systems=combat,target,walk | waitsFor=room | observed=currentRoom:2,originRoom:1", 1, true) ~= nil)
    assert.is_true(trace:find("blocker enter: gmcp_ire_missing -- GMCP IRE missing | systems=combat,gold,queue,target,walk | waitsFor=gmcp,prompt | observed=ire:false", 1, true) ~= nil)
    assert.is_nil(trace:find("gmcp.IRE.Target.Info", 1, true))
    assert.is_nil(trace:find("ButtonActions", 1, true))
  end)
end)
