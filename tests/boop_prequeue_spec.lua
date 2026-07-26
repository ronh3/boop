local helper = dofile(os.getenv("TESTS_DIRECTORY") .. "/support/boop_test_helper.lua")

describe("boop prequeue", function()
  local send_stub
  local send_gmcp_stub
  local timer_stub
  local kill_timer_stub
  local epoch_stub
  local last_delay
  local last_callback
  local sent
  local scheduled

  local function commandCount(command)
    local count = 0
    for _, entry in ipairs(sent or {}) do
      if entry.command == command then
        count = count + 1
      end
    end
    return count
  end

  local function blockerFor(owner)
    return boop.runtime.state().combat.blockersByOwner[owner]
  end

  local function seedLifecycleOwner(owner, code, label, systems, waitsFor)
    helper.setRuntimeBlocker({
      owner = owner,
      code = code,
      label = label,
      systems = systems or { combat = true, queue = true },
      waitsFor = waitsFor or {},
    })
  end

  before_each(function()
    helper.reset()
    helper.setArea("Test Area")
    helper.setClass("Occultist")
    helper.setTargetHp("80%")
    helper.learnSkill("Lycantha", "Domination")
    helper.setDenizens({
      { id = "42", name = "a test denizen" },
    })

    boop.config.enabled = true
    boop.config.targetingMode = "auto"
    boop.config.prequeueEnabled = true
    boop.config.attackLeadSeconds = 2

    sent = {}
    scheduled = {}
    send_stub = stub(_G, "send", function(command, echoBack)
      sent[#sent + 1] = {
        command = command,
        echoBack = echoBack,
      }
    end)
    send_gmcp_stub = stub(_G, "sendGMCP", function(_) end)
    timer_stub = stub(_G, "tempTimer", function(delay, callback)
      last_delay = delay
      last_callback = callback
      local timerId = 54 + #scheduled + 1
      scheduled[#scheduled + 1] = {
        id = timerId,
        delay = delay,
        callback = callback,
      }
      return timerId
    end)
    kill_timer_stub = stub(_G, "killTimer", function(_) end)
    epoch_stub = stub(_G, "getEpoch", function()
      return 100
    end)
  end)

  after_each(function()
    last_delay = nil
    last_callback = nil
    sent = nil
    scheduled = nil
    if send_stub then
      send_stub:revert()
      send_stub = nil
    end
    if send_gmcp_stub then
      send_gmcp_stub:revert()
      send_gmcp_stub = nil
    end
    if timer_stub then
      timer_stub:revert()
      timer_stub = nil
    end
    if kill_timer_stub then
      kill_timer_stub:revert()
      kill_timer_stub = nil
    end
    if epoch_stub then
      epoch_stub:revert()
      epoch_stub = nil
    end
  end)

  it("schedules a prequeue timer based on balance recovery and lead time", function()
    boop.onBalanceUsed("balance", 3)

    assert.are.equal(103, boop.state.queue.balanceReadyAt)
    assert.are.equal(1, last_delay)
    assert.are.equal(55, boop.state.queue.prequeueTimer)
    assert.is_function(last_callback)
  end)

  it("queues the next standard attack when prequeue fires while off balance", function()
    gmcp.Char.Vitals.bal = "0"
    gmcp.Char.Vitals.eq = "0"

    boop.prequeueStandard()

    assert.stub(send_stub).was_called_with("settarget 42", false)
    assert.stub(send_stub).was_called_with("setalias BOOP_ATTACK command hound at 42", false)
    assert.stub(send_stub).was_called_with("queue addclearfull freestand BOOP_ATTACK", false)
    assert.is_true(boop.state.queue.prequeuedStandard)
  end)

  it("rebuilds a queued standard as shieldbreak when the target shields after prequeue", function()
    helper.reset()
    helper.setArea("Test Area")
    helper.setClass("Occultist")
    helper.setTargetHp("80%")
    helper.learnSkill("Warp", "Occultism")
    helper.learnSkill("Hammer", "Tattoos")
    helper.setDenizens({
      { id = "42", name = "a test denizen" },
    })

    boop.config.enabled = true
    boop.config.targetingMode = "auto"
    boop.config.prequeueEnabled = true
    gmcp.Char.Vitals.bal = "0"
    gmcp.Char.Vitals.eq = "0"

    send_stub:clear()

    boop.prequeueStandard()
    boop.targets.onShielded("a test denizen")

    assert.stub(send_stub).was_called_with("setalias BOOP_ATTACK warp 42", false)
    assert.stub(send_stub).was_called_with("setalias BOOP_ATTACK touch hammer 42", false)
    assert.stub(send_stub).was_called_with("queue addclearfull freestand BOOP_ATTACK", false)
    assert.is_true(boop.state.queue.prequeuedStandard)
    assert.is_true(type(boop.state.targeting.targetShield) == "table" and boop.state.targeting.targetShield.attempted)
  end)

  it("does not prequeue attacks while gold commands are pending", function()
    gmcp.Char.Vitals.bal = "0"
    gmcp.Char.Vitals.eq = "0"
    boop.state.gold.getPending = true

    boop.prequeueStandard()

    assert.stub(send_stub).was_not_called()
    assert.is_false(boop.state.queue.prequeuedStandard)
  end)

  local lifecyclePairs = {
    {
      name = "interrupt plus gold",
      owners = {
        {
          owner = "interrupt:11",
          code = "interrupt_pending",
          label = "interrupt pending",
          systems = { combat = true, queue = true },
          waitsFor = { prompt = true },
        },
        {
          owner = "gold:12",
          code = "gold_pickup_pending",
          label = "gold pickup pending",
          systems = { combat = true, gold = true, queue = true, walk = true },
          waitsFor = { gold = true },
        },
      },
    },
    {
      name = "pull plus room",
      owners = {
        {
          owner = "pull:13",
          code = "pull_away",
          label = "pull away",
          systems = { combat = true, queue = true, target = true, walk = true },
          waitsFor = { room = true },
        },
        {
          owner = "room:observation",
          code = "room_partial",
          label = "partial room state",
          systems = {
            combat = true,
            gold = true,
            queue = true,
            target = true,
            walk = true,
          },
          waitsFor = { gmcp = true, room = true },
        },
      },
    },
    {
      name = "gold plus walk",
      owners = {
        {
          owner = "gold:14",
          code = "gold_pack_pending",
          label = "gold pack pending",
          systems = { combat = true, gold = true, queue = true, walk = true },
          waitsFor = { inventory = true },
        },
        {
          owner = "walk:15",
          code = "walk_move_pending",
          label = "move already queued",
          systems = { walk = true, combat = true, queue = true },
          waitsFor = { room = true },
        },
      },
    },
  }

  for _, pairEntry in ipairs(lifecyclePairs) do
    for _, firstIndex in ipairs({ 1, 2 }) do
      local pair = pairEntry
      local clearFirst = firstIndex
      local clearSecond = firstIndex == 1 and 2 or 1
      it("keeps prequeue at zero for " .. pair.name .. " when owner " .. clearFirst .. " clears first", function()
        local first = pair.owners[clearFirst]
        local second = pair.owners[clearSecond]
        seedLifecycleOwner(
          pair.owners[1].owner,
          pair.owners[1].code,
          pair.owners[1].label,
          pair.owners[1].systems,
          pair.owners[1].waitsFor
        )
        seedLifecycleOwner(
          pair.owners[2].owner,
          pair.owners[2].code,
          pair.owners[2].label,
          pair.owners[2].systems,
          pair.owners[2].waitsFor
        )
        gmcp.Char.Vitals.bal = "0"
        gmcp.Char.Vitals.eq = "0"

        boop.onBalanceUsed("balance", 3)
        assert.are.equal(0, #scheduled)
        assert.are.equal(0, #sent)

        assert.is_true(boop.runtime.clearBlocker(
          first.owner,
          "first lifecycle complete"
        ))
        boop.onBalanceUsed("balance", 3)
        boop.prequeueStandard()

        assert.are.equal(0, #scheduled)
        assert.are.equal(0, #sent)
        assert.is_table(blockerFor(second.owner))
        assert.is_false(boop.state.queue.prequeuedStandard)

        assert.is_true(boop.runtime.clearBlocker(
          second.owner,
          "final lifecycle complete"
        ))
        boop.onBalanceUsed("balance", 3)

        assert.are.equal(1, #scheduled)
        scheduled[1].callback()
        assert.are.equal(
          1,
          commandCount("setalias BOOP_ATTACK command hound at 42")
        )
        assert.are.equal(
          1,
          commandCount("queue addclearfull freestand BOOP_ATTACK")
        )
        assert.is_true(boop.state.queue.prequeuedStandard)
      end)
    end
  end

  it("rechecks aggregate owners when a previously captured prequeue callback fires", function()
    gmcp.Char.Vitals.bal = "0"
    gmcp.Char.Vitals.eq = "0"
    boop.state.queue.aliasAction = "existing queued action"
    boop.state.queue.aliasDirty = false

    boop.onBalanceUsed("balance", 3)
    assert.are.equal(1, #scheduled)
    local captured = scheduled[1].callback

    seedLifecycleOwner(
      "interrupt:21",
      "interrupt_pending",
      "interrupt pending",
      { combat = true, queue = true },
      { prompt = true }
    )
    captured()

    assert.are.equal(0, #sent)
    assert.are.equal("existing queued action", boop.state.queue.aliasAction)
    assert.is_false(boop.state.queue.aliasDirty)
    assert.is_false(boop.state.queue.prequeuedStandard)
    assert.is_table(blockerFor("interrupt:21"))
  end)

  for _, clearOrder in ipairs({
    "interrupt-first",
    "unrelated-first",
  }) do
    local order = clearOrder
    it("keeps timeout prequeue held until final release and starts one fresh interrupt for " .. order, function()
      seedLifecycleOwner(
        "pull:99",
        "pull_away",
        "unrelated pull hold",
        { combat = true, queue = true, target = true, walk = true },
        { room = true }
      )
      gmcp.Char.Vitals.bal = "0"
      gmcp.Char.Vitals.eq = "0"

      boop.ui.matic()
      assert.is_table(boop.state.diag.operation)
      local firstGeneration = boop.state.diag.generation
      local timeoutCallback = scheduled[1].callback
      assert.are.equal(1, firstGeneration)
      assert.are.equal(
        1,
        commandCount("queue addclearfull freestand ldeck draw matic")
      )

      boop.onBalanceUsed("balance", 3)
      assert.are.equal(1, #scheduled)
      assert.are.equal(0, commandCount(
        "setalias BOOP_ATTACK command hound at 42"
      ))

      if order == "interrupt-first" then
        timeoutCallback()
        assert.is_table(blockerFor("pull:99"))
        assert.is_nil(blockerFor("interrupt:1"))
        boop.onBalanceUsed("balance", 3)
        assert.are.equal(1, #scheduled)
        assert.is_true(boop.runtime.clearBlocker(
          "pull:99",
          "unrelated owner released"
        ))
      else
        assert.is_true(boop.runtime.clearBlocker(
          "pull:99",
          "unrelated owner released"
        ))
        boop.onBalanceUsed("balance", 3)
        assert.are.equal(1, #scheduled)
        assert.is_table(blockerFor("interrupt:1"))
        timeoutCallback()
        assert.is_nil(blockerFor("interrupt:1"))
      end

      assert.are.equal(0, commandCount(
        "setalias BOOP_ATTACK command hound at 42"
      ))
      boop.onBalanceUsed("balance", 3)
      assert.are.equal(2, #scheduled)
      scheduled[2].callback()
      assert.are.equal(
        1,
        commandCount("setalias BOOP_ATTACK command hound at 42")
      )
      assert.are.equal(
        1,
        commandCount("queue addclearfull freestand BOOP_ATTACK")
      )

      local timersBeforeFreshInterrupt = #scheduled
      boop.ui.fly()
      assert.is_table(boop.state.diag.operation)
      assert.are.equal(firstGeneration + 1, boop.state.diag.generation)
      assert.are.equal(timersBeforeFreshInterrupt + 1, #scheduled)
      assert.are.equal(
        scheduled[#scheduled].id,
        boop.state.diag.timeoutTimer
      )
      assert.are.equal(
        1,
        commandCount("queue addclearfull freestand fly")
      )
      assert.are.equal("interrupt:2", boop.state.diag.operation.blockerOwner)
    end)
  end

end)
