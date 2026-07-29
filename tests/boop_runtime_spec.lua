local helper = dofile(os.getenv("TESTS_DIRECTORY") .. "/support/boop_test_helper.lua")

describe("boop runtime coordinator", function()
  local send_stub
  local timer_stub
  local kill_timer_stub
  local raise_event_stub
  local attack_execute_stub
  local flush_gold_stub
  local maybe_flush_gold_stub
  local walk_advance_stub
  local sent
  local scheduled
  local raised_events

  local function effectKinds(result)
    local kinds = {}
    for _, effect in ipairs((result and result.effects) or {}) do
      kinds[effect.kind] = true
    end
    return kinds
  end

  before_each(function()
    helper.reset()
    sent = {}
    scheduled = {}
    raised_events = {}
    timer_stub = stub(_G, "tempTimer", function(_, callback)
      scheduled[#scheduled + 1] = callback
      return #scheduled
    end)
    kill_timer_stub = stub(_G, "killTimer", function(_) end)
    send_stub = stub(_G, "send", function(command, echoBack)
      sent[#sent + 1] = {
        command = command,
        echoBack = echoBack,
      }
    end)
    raise_event_stub = stub(_G, "raiseEvent", function(name, ...)
      raised_events[#raised_events + 1] = {
        name = name,
        args = { ... },
      }
    end)
  end)

  after_each(function()
    if walk_advance_stub then walk_advance_stub:revert() walk_advance_stub = nil end
    if maybe_flush_gold_stub then maybe_flush_gold_stub:revert() maybe_flush_gold_stub = nil end
    if flush_gold_stub then flush_gold_stub:revert() flush_gold_stub = nil end
    if attack_execute_stub then attack_execute_stub:revert() attack_execute_stub = nil end
    if raise_event_stub then raise_event_stub:revert() raise_event_stub = nil end
    if send_stub then send_stub:revert() send_stub = nil end
    if timer_stub then timer_stub:revert() timer_stub = nil end
    if kill_timer_stub then kill_timer_stub:revert() kill_timer_stub = nil end
  end)

  local function seedTwoBlockers(system)
    helper.setRuntimeBlocker({
      owner = "interrupt:7",
      code = "interrupt_pending",
      label = "interrupt pending",
      systems = { [system] = true },
      waitsFor = { prompt = true },
    })
    helper.setRuntimeBlocker({
      owner = "pull:9",
      code = "pull_active",
      label = "pull active",
      systems = { [system] = true },
      waitsFor = { room = true },
    })
  end

  local function assertRetainedOwner(owner)
    local blockers = boop.runtime.blockersSnapshot()
    assert.are.equal(1, #blockers)
    assert.are.equal(owner, blockers[1].owner)
  end

  local function clearInBothOrders(system, setup, assertHeld, assertReleased)
    local orders = {
      { "interrupt:7", "pull:9" },
      { "pull:9", "interrupt:7" },
    }
    for _, order in ipairs(orders) do
      helper.reset()
      sent = {}
      scheduled = {}
      raised_events = {}
      if setup then
        setup()
      end
      seedTwoBlockers(system)

      assert.is_true(boop.runtime.clearBlocker(order[1], "first owner complete"))
      assertRetainedOwner(order[2])
      assertHeld(order)

      assert.is_true(boop.runtime.clearBlocker(order[2], "final owner complete"))
      assert.are.equal(0, #boop.runtime.blockersSnapshot())
      assertReleased(order)
    end
  end

  it("initializes owned domains and the canonical blocker snapshot", function()
    local state = boop.runtime.state()
    local domains = {
      "combat",
      "targeting",
      "queue",
      "gold",
      "walk",
      "diag",
      "trace",
      "rage",
      "inventory",
      "ih",
      "gag",
    }

    for _, domain in ipairs(domains) do
      assert.is_table(state[domain])
    end

    assert.is_table(state.combat.blocker)
    assert.is_table(state.combat.blockersByOwner)
    assert.are.equal("", state.combat.blocker.code)
    assert.are.equal("", state.combat.blocker.label)
    assert.is_table(state.combat.blocker.systems)
    assert.is_table(state.combat.blocker.waitsFor)
    assert.is_table(state.combat.blocker.observed)
    assert.are.equal(0, state.combat.pullGeneration)
    assert.is_false(state.combat.pullState)

    local snapshot = boop.runtime.blockerSnapshot()
    assert.are.equal("", snapshot.owner)
    assert.are.equal(0, snapshot.additionalCount)
    assert.are.equal("", snapshot.code)
    assert.are.equal("", snapshot.label)
    assert.is_table(snapshot.systems)
    assert.is_table(snapshot.waitsFor)
    assert.is_table(snapshot.observed)
  end)

  it("resets pull generation and active-record fields independently", function()
    local first = boop.runtime.state()
    assert.are.equal(0, first.combat.pullGeneration)
    assert.is_false(first.combat.pullState)

    first.combat.pullGeneration = 7
    first.combat.pullState = {
      active = true,
      generation = 7,
      blockerOwner = "pull:7",
      phase = "timed_out_away",
      terminal = false,
      originRoom = "101",
      direction = "north",
      returnDirection = "south",
      command = "north|harry mage|leap south",
      timeoutTimer = 707,
    }
    local first_record = first.combat.pullState

    helper.reset()

    local fresh = boop.runtime.state()
    assert.are.equal(0, fresh.combat.pullGeneration)
    assert.is_false(fresh.combat.pullState)
    assert.is_false(first_record == fresh.combat.pullState)
    assert.are.same({
      active = true,
      generation = 7,
      blockerOwner = "pull:7",
      phase = "timed_out_away",
      terminal = false,
      originRoom = "101",
      direction = "north",
      returnDirection = "south",
      command = "north|harry mage|leap south",
      timeoutTimer = 707,
    }, first_record)
  end)

  it("resets gold generation and operation fields independently", function()
    local first = boop.runtime.state()
    assert.are.equal(0, first.gold.generation)
    assert.is_false(first.gold.operation)

    first.gold.generation = 7
    first.gold.operation = {
      generation = 7,
      phase = "pack_pending",
      terminal = false,
      blockerOwner = "gold:7",
      source = "text line",
      roomId = "",
      roomGeneration = 0,
      goldItemId = "",
      packTarget = "pack",
      getRetries = 1,
      putRetries = 1,
      flushTimer = false,
      timeoutTimer = 707,
    }
    local first_operation = first.gold.operation
    first_operation.packTarget = "changed-after-reset"

    helper.reset()

    local fresh = boop.runtime.state()
    assert.are.equal(0, fresh.gold.generation)
    assert.is_false(fresh.gold.operation)
    assert.is_false(first_operation == fresh.gold.operation)
    assert.are.equal("changed-after-reset", first_operation.packTarget)
    assert.are.equal(707, first_operation.timeoutTimer)
  end)

  it("resets every walk field and materializes an independent domain", function()
    local first = boop.runtime.state()
    local firstWalk = first.walk

    assert.is_false(firstWalk.active)
    assert.is_false(firstWalk.owned)
    assert.is_false(firstWalk.roomSettled)
    assert.is_false(firstWalk.moveQueued)
    assert.are.equal("", firstWalk.arrivalRoom)
    assert.are.equal(0, firstWalk.generation)
    assert.are.equal(0, firstWalk.roomGeneration)
    assert.is_false(firstWalk.moveIssuedForRoomGeneration)
    assert.are.equal(0, firstWalk.reservationId)
    assert.is_nil(firstWalk.refreshTimer)
    assert.is_nil(firstWalk.emitterTimer)
    assert.is_false(firstWalk.refreshWarned)

    firstWalk.active = true
    firstWalk.owned = true
    firstWalk.roomSettled = true
    firstWalk.moveQueued = true
    firstWalk.arrivalRoom = "101"
    firstWalk.generation = 7
    firstWalk.roomGeneration = 9
    firstWalk.moveIssuedForRoomGeneration = true
    firstWalk.reservationId = 11
    firstWalk.refreshTimer = 13
    firstWalk.emitterTimer = 15
    firstWalk.refreshWarned = true

    helper.reset()

    local freshWalk = boop.runtime.state().walk
    assert.is_false(firstWalk == freshWalk)
    assert.is_false(freshWalk.active)
    assert.is_false(freshWalk.owned)
    assert.is_false(freshWalk.roomSettled)
    assert.is_false(freshWalk.moveQueued)
    assert.are.equal("", freshWalk.arrivalRoom)
    assert.are.equal(0, freshWalk.generation)
    assert.are.equal(0, freshWalk.roomGeneration)
    assert.is_false(freshWalk.moveIssuedForRoomGeneration)
    assert.are.equal(0, freshWalk.reservationId)
    assert.is_nil(freshWalk.refreshTimer)
    assert.is_nil(freshWalk.emitterTimer)
    assert.is_false(freshWalk.refreshWarned)

    assert.is_true(firstWalk.active)
    assert.are.equal(7, firstWalk.generation)
    assert.are.equal(11, firstWalk.reservationId)
    assert.are.equal(15, firstWalk.emitterTimer)
  end)

  it("includes the current walk reservation in immutable runtime context", function()
    local state = boop.runtime.state()
    state.walk.generation = 7
    state.walk.roomGeneration = 9
    state.walk.reservationId = 11
    state.walk.moveQueued = true

    local context = boop.runtime.context()
    assert.are.equal(7, context.walk.generation)
    assert.are.equal(9, context.walk.roomGeneration)
    assert.are.equal(11, context.walk.reservationId)
    assert.is_true(context.walk.moveQueued)

    context.walk.reservationId = 99
    assert.are.equal(11, boop.runtime.state().walk.reservationId)
  end)

  it("keeps attack sends held until both owners clear in either order", function()
    attack_execute_stub = stub(boop.attacks, "execute", function(_, _)
      send("attack 42", false)
      return true
    end)

    clearInBothOrders("combat", function()
      helper.setClass("Occultist")
      helper.setTarget("42", "a test denizen", "80%")
      helper.setRage(14)
      helper.learnSkills({
        { name = "Lycantha", group = "Domination" },
        { name = "Warp", group = "Occultism" },
        { name = "harry", group = "Attainment" },
      })
      helper.setSkillKnown("chaosgate", false, "Attainment")
      helper.setSkillKnown("fluctuate", false, "Attainment")
      helper.setDenizens({
        { id = "42", name = "a test denizen" },
      })
      boop.config.enabled = true
      boop.config.targetingMode = "auto"
      boop.config.attackMode = "simple"
      boop.config.useQueueing = true
    end, function()
      local result = boop.runtime.step({ type = "tick", context = boop.runtime.context() })
      boop.runtime.applyEffects(result, boop.runtime.context())
      assert.are.equal(0, #sent)
      assert.are.equal(0, #scheduled)
      assert.are.equal(0, #raised_events)
    end, function()
      local result = boop.runtime.step({ type = "tick", context = boop.runtime.context() })
      boop.runtime.applyEffects(result, boop.runtime.context())
      assert.are.equal(1, #sent)
      assert.are.equal("attack 42", sent[1].command)
      assert.are.equal(0, #scheduled)
      assert.are.equal(0, #raised_events)
    end)
  end)

  it("keeps gold sends held until both owners clear in either order", function()
    maybe_flush_gold_stub = stub(boop, "maybeFlushPendingGold", function(_)
      return false
    end)
    flush_gold_stub = stub(boop, "flushPendingGold", function(_)
      send("queue add full get sovereigns", false)
      return true
    end)
    walk_advance_stub = stub(boop.walk, "maybeAdvance", function(_)
      return false
    end)

    clearInBothOrders("gold", nil, function()
      boop.config.enabled = true
      boop.config.targetingMode = "auto"
      boop.config.useQueueing = true
      boop.state.gold.autoGrabPending = true
      local result = boop.runtime.step({ type = "tick", context = boop.runtime.context() })
      boop.runtime.applyEffects(result, boop.runtime.context())
      assert.are.equal(0, #sent)
      assert.are.equal(0, #scheduled)
      assert.are.equal(0, #raised_events)
    end, function()
      boop.config.enabled = true
      boop.config.targetingMode = "auto"
      boop.config.useQueueing = true
      boop.state.gold.autoGrabPending = true
      local result = boop.runtime.step({ type = "tick", context = boop.runtime.context() })
      boop.runtime.applyEffects(result, boop.runtime.context())
      assert.are.equal(1, #sent)
      assert.are.equal("queue add full get sovereigns", sent[1].command)
      assert.are.equal(0, #scheduled)
      assert.are.equal(0, #raised_events)
    end)
  end)

  it("keeps movement events held until both owners clear in either order", function()
    walk_advance_stub = stub(boop.walk, "maybeAdvance", function(_)
      tempTimer(0, function()
        raiseEvent("demonwalker.move")
      end)
      return true
    end)

    clearInBothOrders("walk", nil, function()
      boop.config.enabled = true
      boop.config.targetingMode = "auto"
      local result = boop.runtime.step({ type = "tick", context = boop.runtime.context() })
      boop.runtime.applyEffects(result, boop.runtime.context())
      assert.are.equal(0, #sent)
      assert.are.equal(0, #scheduled)
      assert.are.equal(0, #raised_events)
    end, function()
      boop.config.enabled = true
      boop.config.targetingMode = "auto"
      local result = boop.runtime.step({ type = "tick", context = boop.runtime.context() })
      boop.runtime.applyEffects(result, boop.runtime.context())
      assert.are.equal(0, #sent)
      assert.are.equal(1, #scheduled)
      assert.are.equal(0, #raised_events)
      scheduled[1]()
      assert.are.equal(1, #raised_events)
      assert.are.equal("demonwalker.move", raised_events[1].name)
    end)
  end)

  it("excludes only an exact owner from aggregate holds", function()
    helper.setRuntimeBlocker({
      owner = "interrupt:7",
      code = "interrupt_pending",
      systems = { combat = true, queue = true },
    })

    assert.is_false(boop.runtime.shouldHold("combat", "interrupt:7"))
    assert.is_true(boop.runtime.shouldHold("combat", "interrupt_pending"))
    assert.is_true(boop.runtime.shouldHold("combat", "interrupt"))
    assert.is_true(boop.runtime.shouldHold("combat", "combat"))

    helper.setRuntimeBlocker({
      owner = "pull:9",
      code = "pull_active",
      systems = { combat = true },
    })

    assert.is_true(boop.runtime.shouldHold("combat", "interrupt:7"))
    assert.is_true(boop.runtime.shouldHold("combat", "pull:9"))
  end)

  it("sorts blocker snapshots by priority, code, and owner without exposing state", function()
    local expected = {
      { owner = "gmcp:ire", code = "gmcp_ire_missing" },
      { owner = "room:missing", code = "missing_room" },
      { owner = "room:partial", code = "room_partial" },
      { owner = "target:loss", code = "target_lost" },
      { owner = "flee:1", code = "flee_active" },
      { owner = "pull:timeout", code = "pull_timeout_away" },
      { owner = "pull:away", code = "pull_away" },
      { owner = "pull:active", code = "pull_active" },
      { owner = "interrupt:1", code = "interrupt_pending" },
      { owner = "interrupt:2", code = "interrupt_pending" },
      { owner = "gold:deferred", code = "gold_deferred_room" },
      { owner = "gold:pickup", code = "gold_pickup_pending" },
      { owner = "gold:pack", code = "gold_pack_pending" },
      { owner = "walk:unsettled", code = "walk_room_unsettled" },
      { owner = "walk:move", code = "walk_move_pending" },
      { owner = "walk:missing", code = "walker_unavailable" },
      { owner = "custom:a", code = "alpha_custom" },
      { owner = "custom:z", code = "zeta_custom" },
    }

    for index = #expected, 1, -1 do
      helper.setRuntimeBlocker({
        owner = expected[index].owner,
        code = expected[index].code,
        label = expected[index].code,
        systems = { combat = true },
        observed = { current = true },
      })
    end

    local blockers = boop.runtime.blockersSnapshot()
    assert.are.equal(#expected, #blockers)
    for index, record in ipairs(expected) do
      assert.are.equal(record.owner, blockers[index].owner)
      assert.are.equal(record.code, blockers[index].code)
    end

    local primary = boop.runtime.blockerSnapshot()
    assert.are.equal("gmcp:ire", primary.owner)
    assert.are.equal(#expected - 1, primary.additionalCount)

    blockers[1].code = "mutated"
    blockers[1].systems.combat = false
    primary.owner = "mutated"
    primary.observed.current = false

    local freshBlockers = boop.runtime.blockersSnapshot()
    local freshPrimary = boop.runtime.blockerSnapshot()
    assert.are.equal("gmcp_ire_missing", freshBlockers[1].code)
    assert.is_true(freshBlockers[1].systems.combat)
    assert.are.equal("gmcp:ire", freshPrimary.owner)
    assert.is_true(freshPrimary.observed.current)
  end)

  it("maps legacy state aliases onto owned runtime domains", function()
    local state = boop.runtime.state()

    state.targeting.currentTargetId = "42"
    state.queue.prequeuedStandard = true
    boop.state.targeting.calledTargetId = "99"

    assert.are.equal("42", boop.state.targeting.currentTargetId)
    assert.is_true(boop.state.queue.prequeuedStandard)
    assert.are.equal("99", state.targeting.calledTargetId)
  end)

  it("returns target and combat effects for the main tick path", function()
    helper.setClass("Occultist")
    helper.setTargetHp("80%")
    helper.setRage(14)
    helper.learnSkills({
      { name = "Lycantha", group = "Domination" },
      { name = "Warp", group = "Occultism" },
      { name = "harry", group = "Attainment" },
    })
    helper.setDenizens({
      { id = "42", name = "a test denizen" },
    })

    boop.config.enabled = true
    boop.config.targetingMode = "auto"
    boop.config.attackMode = "simple"

    local result = boop.runtime.step({ type = "tick", context = boop.runtime.context() })

    assert.are.equal("target", result.effects[1].kind)
    assert.are.equal("42", result.effects[1].id)
    assert.are.equal("combat_plan", result.effects[2].kind)
    assert.are.equal("command hound at 42", result.effects[2].plan.standard)
    assert.are.equal("harry 42", result.effects[2].plan.rage)
  end)

  it("holds automation effects while the owned blocker affects runtime systems", function()
    helper.setClass("Occultist")
    helper.setTargetHp("80%")
    helper.setRage(14)
    helper.learnSkills({
      { name = "Lycantha", group = "Domination" },
      { name = "Warp", group = "Occultism" },
      { name = "harry", group = "Attainment" },
    })
    helper.setDenizens({
      { id = "42", name = "a test denizen" },
    })
    helper.setRuntimeBlocker({
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

    boop.config.enabled = true
    boop.config.targetingMode = "auto"
    boop.config.attackMode = "simple"
    boop.config.useQueueing = true
    boop.state.gold.autoGrabPending = true

    assert.is_true(boop.runtime.shouldHold("target"))
    assert.is_true(boop.runtime.shouldHold("combat"))
    assert.is_true(boop.runtime.shouldHold("queue"))
    assert.is_true(boop.runtime.shouldHold("gold"))
    assert.is_true(boop.runtime.shouldHold("walk"))

    local result = boop.runtime.step({ type = "tick", context = boop.runtime.context() })
    local kinds = effectKinds(result)

    assert.is_nil(kinds.target)
    assert.is_nil(kinds.combat_plan)
    assert.is_nil(kinds.flush_gold)
    assert.is_nil(kinds.walk_advance)
    assert.is_false(result.didAction)
  end)

  it("releases diagnose hold from prompt effects", function()
    boop.state.diag.generation = 1
    boop.state.diag.hold = true
    boop.state.diag.awaitPrompt = true
    boop.state.diag.label = "matic"
    boop.state.diag.timeoutTimer = 44
    boop.state.diag.operation = {
      generation = 1,
      name = "matic",
      command = "ldeck draw matic",
      completionMode = "prompt",
      resultSeen = false,
      terminal = false,
      blockerOwner = "interrupt:1",
      timeoutTimer = 44,
      startedAt = os.time(),
    }
    helper.setRuntimeBlocker({
      owner = "interrupt:1",
      code = "interrupt_pending",
      label = "matic pending",
      systems = { combat = true, queue = true },
    })

    local result = boop.runtime.step({ type = "prompt", context = boop.runtime.context() })
    boop.runtime.applyEffects(result, boop.runtime.context())

    assert.is_false(boop.state.diag.operation)
    assert.is_false(boop.state.diag.hold)
    assert.is_false(boop.state.diag.awaitPrompt)
    assert.are.equal("", boop.state.diag.label)
    assert.is_nil(boop.state.combat.blockersByOwner["interrupt:1"])
    assert.stub(kill_timer_stub).was_called_with(44)
  end)
end)
