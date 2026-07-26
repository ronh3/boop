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
    helper.setRuntimeBlocker(blocker)
  end

  local function clearBlocker(owner, reason)
    assert.is_function(boop.runtime.clearBlocker)
    boop.runtime.clearBlocker(owner, reason)
  end

  local function countTraceOccurrences(expected)
    local count = 0
    local offset = 1
    local trace = traceText()
    while true do
      local found = trace:find(expected, offset, true)
      if not found then
        return count
      end
      count = count + 1
      offset = found + #expected
    end
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
      owner = "gmcp:ire",
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
      owner = "gmcp:ire",
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

    clearBlocker("gmcp:ire", "gmcp recovered")

    local trace = traceText()
    local first_enter = trace:find("blocker enter: gmcp:ire | gmcp_ire_missing -- GMCP IRE missing | systems: combat, gold, queue, target, walk | waits: gmcp, prompt | observed: ire:false,room:1", 1, true)
    assert.is_true(first_enter ~= nil)
    assert.is_nil(trace:find("blocker enter: gmcp:ire | gmcp_ire_missing", first_enter + 1, true))
    assertTraceContains("blocker exit: gmcp:ire | gmcp_ire_missing -- GMCP IRE missing | reason=gmcp recovered")
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
      owner = "pull:4",
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
      owner = "gmcp:ire",
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
    assert.is_true(trace:find("blocker enter: pull:4 | pull_away -- pull in progress | systems: combat, target, walk | waits: room | observed: currentRoom:2,originRoom:1", 1, true) ~= nil)
    assert.is_true(trace:find("blocker enter: gmcp:ire | gmcp_ire_missing -- GMCP IRE missing | systems: combat, gold, queue, target, walk | waits: gmcp, prompt | observed: ire:false", 1, true) ~= nil)
    local blockers = boop.runtime.blockersSnapshot()
    assert.are.equal("gmcp:ire", blockers[1].owner)
    assert.are.equal("pull:4", blockers[2].owner)

    clearBlocker("pull:4", "returned")

    blockers = boop.runtime.blockersSnapshot()
    assert.are.equal(1, #blockers)
    assert.are.equal("gmcp:ire", blockers[1].owner)
    assertTraceContains("blocker exit: pull:4 | pull_away -- pull in progress | reason=returned")
    assert.is_nil(trace:find("gmcp.IRE.Target.Info", 1, true))
    assert.is_nil(trace:find("ButtonActions", 1, true))
  end)

  it("sorts every owner and traces exact non-primary release and primary promotion", function()
    setBlocker({
      owner = "gold:5",
      code = "gold_pack_pending",
      label = "gold pack pending",
      systems = { combat = true, gold = true, queue = true, walk = true },
      waitsFor = { inventory = true },
    })
    setBlocker({
      owner = "interrupt:9",
      code = "interrupt_pending",
      label = "interrupt nine pending",
      systems = { combat = true, queue = true },
      waitsFor = { prompt = true },
    })
    setBlocker({
      owner = "gmcp:ire",
      code = "gmcp_ire_missing",
      label = "GMCP IRE missing",
      systems = {
        target = true,
        combat = true,
        queue = true,
        gold = true,
        walk = true,
      },
      waitsFor = { gmcp = true, prompt = true },
    })
    setBlocker({
      owner = "interrupt:2",
      code = "interrupt_pending",
      label = "interrupt two pending",
      systems = { combat = true, queue = true },
      waitsFor = { prompt = true },
    })

    local blockers = boop.runtime.blockersSnapshot()
    assert.are.same({
      "gmcp:ire",
      "interrupt:2",
      "interrupt:9",
      "gold:5",
    }, {
      blockers[1].owner,
      blockers[2].owner,
      blockers[3].owner,
      blockers[4].owner,
    })
    local primary = boop.runtime.blockerSnapshot()
    assert.are.equal("gmcp:ire", primary.owner)
    assert.are.equal(3, primary.additionalCount)

    clearBlocker("interrupt:9", "non-primary complete")

    primary = boop.runtime.blockerSnapshot()
    assert.are.equal("gmcp:ire", primary.owner)
    assert.are.equal(2, primary.additionalCount)
    assert.are.equal(
      1,
      countTraceOccurrences(
        "blocker exit: interrupt:9 | interrupt_pending -- interrupt nine pending | reason=non-primary complete"
      )
    )
    assert.are.equal(0, countTraceOccurrences("blocker exit: gold:5"))

    clearBlocker("gmcp:ire", "primary recovered")

    primary = boop.runtime.blockerSnapshot()
    assert.are.equal("interrupt:2", primary.owner)
    assert.are.equal("interrupt_pending", primary.code)
    assert.are.equal(1, primary.additionalCount)
    assert.are.equal(
      1,
      countTraceOccurrences(
        "blocker exit: gmcp:ire | gmcp_ire_missing -- GMCP IRE missing | reason=primary recovered"
      )
    )
    assertTraceContains(
      "blocker enter: gold:5 | gold_pack_pending -- gold pack pending | systems: combat, gold, queue, walk | waits: inventory"
    )
    assertTraceContains(
      "blocker enter: interrupt:2 | interrupt_pending -- interrupt two pending | systems: combat, queue | waits: prompt"
    )
  end)
end)
