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
  local observe_outbound

  local function commandCount(command)
    local count = 0
    for _, entry in ipairs(sent or {}) do
      if entry.command == command then
        count = count + 1
      end
    end
    return count
  end

  local function observeSent(firstIndex)
    for index = firstIndex or 1, #(sent or {}) do
      boop.onDataSendRequest(
        "sysDataSendRequest",
        sent[index].command
      )
    end
  end

  local function blockerFor(owner)
    return boop.runtime.state().combat.blockersByOwner[owner]
  end

  local function seedOperation(owner, code, label, systems, waitsFor)
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
      if observe_outbound then
        boop.onDataSendRequest("sysDataSendRequest", command)
      end
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
    observe_outbound = nil
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

  it("keeps a queued standard alias fixed when the target shields", function()
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
    assert.stub(send_stub).was_not_called_with("setalias BOOP_ATTACK touch hammer 42", false)
    assert.stub(send_stub).was_called_with("queue addclearfull freestand BOOP_ATTACK", false)
    assert.are.equal("warp 42", boop.state.queue.aliasAction)
    assert.is_true(boop.state.queue.prequeuedStandard)
    assert.is_false(boop.state.targeting.targetShield.attempted)
  end)

  it("keeps a queued class alias fixed across shield-mode changes", function()
    helper.reset()
    dofile(
      os.getenv("TESTS_DIRECTORY")
        .. "/../src/scripts/boop/attacks/infernal.lua"
    )
    helper.setArea("Test Area")
    helper.setClass("Infernal")
    helper.setSpec("Sword and Shield")
    helper.setTargetHp("80%")
    helper.learnSkill("Combination", "Weaponmastery")
    helper.setDenizens({
      { id = "42", name = "a test denizen" },
    })

    boop.config.enabled = true
    boop.config.targetingMode = "auto"
    boop.config.prequeueEnabled = true
    gmcp.Char.Vitals.bal = "0"
    gmcp.Char.Vitals.eq = "0"

    boop.prequeueStandard()
    local trackedShield = { attempted = false }
    boop.state.targeting.targetShield = trackedShield

    boop.ui.shieldModeCommand("break")
    assert.are.equal(
      "combination 42 rend smash",
      boop.state.queue.aliasAction
    )

    boop.ui.shieldModeCommand("bypass")
    assert.are.equal(
      "combination 42 rend smash",
      boop.state.queue.aliasAction
    )
    assert.are.equal(trackedShield, boop.state.targeting.targetShield)
    assert.are.equal(
      0,
      commandCount("setalias BOOP_ATTACK combination 42 raze smash")
    )
    assert.are.equal(
      1,
      commandCount("setalias BOOP_ATTACK combination 42 rend smash")
    )
  end)

  it("does not rebound or rebind a pending damage prequeue", function()
    helper.reset()
    dofile(
      os.getenv("TESTS_DIRECTORY")
        .. "/../src/scripts/boop/attacks/infernal.lua"
    )
    helper.setArea("Test Area")
    helper.setClass("Infernal")
    helper.setSpec("Dual Cutting")
    helper.setTargetHp("80%")
    helper.learnSkills({
      { name = "Duality", group = "Weaponmastery" },
      { name = "Raze", group = "Weaponmastery" },
      { name = "Maul", group = "Malignity" },
    })
    boop.rage.setReady("maul", true)
    helper.setDenizens({
      { id = "42", name = "a test denizen" },
    })

    boop.config.enabled = true
    boop.config.targetingMode = "auto"
    boop.config.prequeueEnabled = true
    boop.config.attackLeadSeconds = 1
    gmcp.Char.Vitals.bal = "0"
    gmcp.Char.Vitals.eq = "0"

    boop.prequeueStandard()
    boop.targets.onShielded("a test denizen")
    boop.targets.onShielded("a test denizen")
    local timersBeforeOutcome = #scheduled
    boop.onBalanceUsed("equilibrium", 1.7)

    assert.are.equal(timersBeforeOutcome, #scheduled)
    assert.are.equal("hyena maul 42/dsl 42", boop.state.queue.aliasAction)
    assert.are.equal(
      1,
      commandCount("setalias BOOP_ATTACK hyena maul 42/dsl 42")
    )
    assert.are.equal(
      0,
      commandCount("setalias BOOP_ATTACK hyena maul 42/raze 42")
    )
    assert.is_false(boop.state.targeting.targetShield.attempted)
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
      name = "pull plus interrupt",
      owners = {
        {
          owner = "pull:13",
          code = "pull_away",
          label = "pull away",
          systems = { combat = true, queue = true, target = true, walk = true },
          waitsFor = { room = true },
        },
        {
          owner = "interrupt:14",
          code = "interrupt_pending",
          label = "interrupt pending",
          systems = { combat = true, queue = true },
          waitsFor = { prompt = true },
        },
      },
    },
    {
      name = "gold plus pull",
      owners = {
        {
          owner = "gold:14",
          code = "gold_pack_pending",
          label = "gold pack pending",
          systems = { combat = true, gold = true, queue = true, walk = true },
          waitsFor = { inventory = true },
        },
        {
          owner = "pull:15",
          code = "pull_active",
          label = "pull active",
          systems = {
            walk = true,
            combat = true,
            queue = true,
            target = true,
          },
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
        seedOperation(
          pair.owners[1].owner,
          pair.owners[1].code,
          pair.owners[1].label,
          pair.owners[1].systems,
          pair.owners[1].waitsFor
        )
        seedOperation(
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

        assert.is_true(boop.runtime.clearOperationLock(
          first.owner,
          "first lifecycle complete"
        ))
        boop.onBalanceUsed("balance", 3)
        boop.prequeueStandard()

        assert.are.equal(0, #scheduled)
        assert.are.equal(0, #sent)
        assert.is_table(blockerFor(second.owner))
        assert.is_false(boop.state.queue.prequeuedStandard)

        assert.is_true(boop.runtime.clearOperationLock(
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

    seedOperation(
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
      seedOperation(
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
        assert.is_true(boop.runtime.clearOperationLock(
          "pull:99",
          "unrelated owner released"
        ))
      else
        assert.is_true(boop.runtime.clearOperationLock(
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

  describe("G-03-21 prompt-reconciled ADDCLEARFULL lifecycle", function()
    local function queueOwnedStandard()
      gmcp.Char.Vitals.bal = "0"
      gmcp.Char.Vitals.eq = "0"
      observe_outbound = true
      assert.is_true(boop.prequeueStandard())
      local standard = boop.runtime.standardSnapshot()
      assert.is_table(standard)
      assert.are.equal("queued", standard.status)
      assert.are.equal("queued", standard.mode)
      assert.are.equal("42", standard.targetId)
      assert.are.equal(
        "command hound at 42",
        standard.aliasBinding
      )
      assert.are.equal(
        "queue addclearfull freestand BOOP_ATTACK",
        standard.baseline.command
      )
      return standard
    end

    local denialCases = {
      {
        name = "paralysis",
        line = "You are paralysed and cannot do that.",
      },
      {
        name = "stun",
        line = "You are stunned and cannot do that.",
      },
      {
        name = "prone",
        line = "You must be standing first.",
      },
      {
        name = "web",
        line = "You are too tangled in webs to do that.",
      },
      {
        name = "impale",
        line = "You are impaled and cannot do that.",
      },
      {
        name = "arms",
        line = "You do not have the free arms required to do that.",
      },
    }

    for _, denialCase in ipairs(denialCases) do
      local case = denialCase
      it("attributes the exact " .. case.name .. " denial candidate", function()
        queueOwnedStandard()

        assert.is_true(boop.onStandardCommandOutcome(case.line))
        local candidate = boop.runtime.standardSnapshot().candidate
        assert.is_table(candidate)
        assert.are.equal("denial", candidate.kind)
        assert.are.equal(case.name, candidate.obstacle)
      end)
    end

    it("records transformed direct wire parts and keeps rage dispatch semantic", function()
      helper.setTarget("42", "a test denizen", "80%")
      boop.config.useQueueing = true
      observe_outbound = true
      sent = {}

      assert.is_true(boop.executeAction(
        " command hound at 42 / touch hammer 42 ",
        nil,
        {
          dispatchMode = "direct",
          outcomeRegistration = {
            owner = "standard:test",
            generation = 77,
            dispatchId = "standard:test:77",
            kind = "standard",
          },
        }
      ))

      assert.are.same({
        "command hound at 42",
        "touch hammer 42",
      }, {
        sent[1].command,
        sent[2].command,
      })
      local standard = boop.runtime.standardSnapshot()
      assert.are.equal("direct", standard.mode)
      assert.are.same({
        { command = "command hound at 42" },
        { command = "touch hammer 42" },
      }, standard.expectedWireCommands)
      assert.are.equal(2, #standard.observedWireCommands)
      assert.are.equal(
        standard.observedWireCommands[2].sequence,
        standard.finalOwnedWireSequence
      )
      assert.are.equal(
        "touch hammer 42",
        standard.baseline.command
      )

      assert.is_true(boop.onStandardCommandOutcome(
        "Balance used: 3.0s"
      ))
      boop.runtime.reconcileStandardPrompt(false)
      assert.are.equal(
        "executed",
        boop.runtime.standardSnapshot().status
      )

      sent = {}
      assert.is_true(boop.executeAction(
        " harry 42 / temper 42 ",
        nil,
        {
          dispatchMode = "direct",
          outcomeRegistration = {
            owner = "rage:test",
            generation = 78,
            dispatchId = "rage:test:78",
            kind = "rage",
          },
        }
      ))
      assert.are.same({ "harry 42", "temper 42" }, {
        sent[1].command,
        sent[2].command,
      })
      assert.are.equal(
        77,
        boop.runtime.standardSnapshot().generation
      )

      local dispatches = boop.runtime.outboundSnapshot().dispatches
      local rageDispatch = dispatches[#dispatches]
      assert.are.equal("rage", rageDispatch.kind)
      assert.are.same({
        { command = "harry 42" },
        { command = "temper 42" },
      }, rageDispatch.expectedWireCommands)
      assert.are.equal(2, #rageDispatch.observedWireCommands)
    end)

    it("owns the exact wire baseline and blocks competing dispatch until the next prompt confirms success", function()
      local standard = queueOwnedStandard()

      assert.is_false(boop.executeAction("command hound at 42", true))
      assert.is_false(boop.executeRageAction("harry 42"))
      assert.are.equal(1, commandCount(
        "queue addclearfull freestand BOOP_ATTACK"
      ))

      boop.onBalanceUsed("balance", 3)
      assert.is_true(boop.state.queue.prequeuedStandard)
      assert.are.equal("queued", boop.runtime.standardSnapshot().status)

      boop.onPrompt()
      local terminal = boop.runtime.standardSnapshot()
      assert.are.equal(standard.generation, terminal.generation)
      assert.are.equal("executed", terminal.status)
      assert.is_true(terminal.terminal)
      assert.is_false(boop.state.queue.prequeuedStandard)

      boop.onPrompt()
      assert.are.equal(
        standard.generation,
        boop.runtime.standardSnapshot().generation
      )
      assert.are.equal("executed", boop.runtime.standardSnapshot().status)
    end)

    it("commits a denial only at its following prompt and retries once after matching recovery", function()
      local standard = queueOwnedStandard()

      assert.is_true(boop.onStandardCommandOutcome(
        "You are paralysed and cannot do that."
      ))
      assert.are.equal("queued", boop.runtime.standardSnapshot().status)
      boop.onPrompt()

      local denied = boop.runtime.standardSnapshot()
      assert.are.equal(standard.generation, denied.generation)
      assert.are.equal("denied", denied.status)
      assert.are.equal("paralysis", denied.obstacle)
      assert.is_false(boop.state.queue.prequeuedStandard)
      assert.are.equal(1, commandCount(
        "queue addclearfull freestand BOOP_ATTACK"
      ))

      gmcp.Char.Vitals.bal = "1"
      gmcp.Char.Vitals.eq = "1"
      boop.onPrompt()
      assert.are.equal(1, commandCount(
        "queue addclearfull freestand BOOP_ATTACK"
      ))

      assert.is_true(boop.onStandardCommandRecovery(
        "You are no longer paralysed."
      ))
      boop.onPrompt()
      assert.are.equal(2, commandCount(
        "queue addclearfull freestand BOOP_ATTACK"
      ))
      local retry = boop.runtime.standardSnapshot()
      assert.is_true(retry.generation > denied.generation)
      assert.are.equal(0, retry.retryBudget)

      boop.onStandardCommandRecovery(
        "You are no longer paralysed."
      )
      boop.onPrompt()
      assert.are.equal(2, commandCount(
        "queue addclearfull freestand BOOP_ATTACK"
      ))
    end)

    it("starts one grace only at the first ready prompt and lets its stale callback expire once", function()
      queueOwnedStandard()
      local timersBeforeGrace = #scheduled

      boop.onPrompt()
      assert.are.equal(timersBeforeGrace, #scheduled)

      gmcp.Char.Vitals.bal = "1"
      gmcp.Char.Vitals.eq = "1"
      boop.onPrompt()
      assert.are.equal(timersBeforeGrace + 1, #scheduled)
      local grace = scheduled[#scheduled].callback

      boop.onPrompt()
      assert.are.equal(timersBeforeGrace + 1, #scheduled)
      grace()

      assert.are.equal(2, commandCount(
        "queue addclearfull freestand BOOP_ATTACK"
      ))
      local retry = boop.runtime.standardSnapshot()
      assert.are.equal("queued", retry.status)
      assert.are.equal(0, retry.retryBudget)

      grace()
      assert.are.equal(2, commandCount(
        "queue addclearfull freestand BOOP_ATTACK"
      ))
    end)

    it("rejects a generic success candidate contaminated by later manual outbound traffic", function()
      local standard = queueOwnedStandard()
      boop.onDataSendRequest(
        "sysDataSendRequest",
        "say unrelated manual command"
      )

      assert.is_true(boop.onStandardCommandOutcome(
        "Balance used: 3.0s"
      ))
      boop.onPrompt()

      local retained = boop.runtime.standardSnapshot()
      assert.are.equal(standard.generation, retained.generation)
      assert.are.equal("queued", retained.status)
      assert.is_false(retained.terminal)
      assert.is_nil(retained.candidate)
      assert.is_false(retained.graceStarted)
    end)
  end)

end)
