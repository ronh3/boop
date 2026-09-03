local helper = dofile(os.getenv("TESTS_DIRECTORY") .. "/support/boop_test_helper.lua")

local function normalizeAff(raw)
  local key = boop.util.safeLower(boop.util.trim(raw or ""))
  if key == "stunned" then
    return "stun"
  end
  return key
end

local function learnStandardSkills(entry)
  if type(entry) ~= "table" then
    return
  end

  if entry.bySpec then
    for _, specEntry in pairs(entry.bySpec) do
      learnStandardSkills(specEntry)
    end
    learnStandardSkills(entry.default)
    return
  end

  if entry.cmd or entry.skill or entry.name then
    local skill = entry.skill or entry.name
    if skill and skill ~= "" then
      helper.learnSkill(skill, entry.group)
    end
    return
  end

  for _, option in ipairs(entry) do
    learnStandardSkills(option)
  end

  for key, value in pairs(entry) do
    if type(key) ~= "number" then
      learnStandardSkills(value)
    end
  end
end

local function learnRageSkills(profile)
  for _, ability in pairs(profile.abilities or {}) do
    local skill = ability.skill or ability.name
    if skill and skill ~= "" then
      helper.learnSkill(skill, ability.group or "Attainment")
    end
  end
end

local function expectedRageCommand(classKey, cmd)
  local expected = boop.util.formatTarget(cmd, "42")
  if boop.util.safeLower(classKey or "") == "psion"
    and expected ~= ""
    and not boop.util.starts(boop.util.safeLower(expected), "psi transcend shatter/")
  then
    expected = "psi transcend shatter/" .. expected
  end
  return expected
end

local function cmdsForDesc(profile, desc, classKey)
  local cmds = {}
  for _, ability in pairs(profile.abilities or {}) do
    if ability.desc == desc and ability.cmd and ability.cmd ~= "" then
      cmds[#cmds + 1] = expectedRageCommand(classKey, ability.cmd)
    end
  end
  table.sort(cmds)
  return cmds
end

local function cheapestCost(profile, descs)
  local best = nil
  for _, ability in pairs(profile.abilities or {}) do
    for _, desc in ipairs(descs) do
      if ability.desc == desc then
        local cost = tonumber(ability.rage) or 0
        if not best or cost < best then
          best = cost
        end
      end
    end
  end
  return best
end

local function setContains(list, value)
  for _, item in ipairs(list or {}) do
    if item == value then
      return true
    end
  end
  return false
end

local function providerSupport(profile, conditional)
  local needs = conditional.needs or {}
  local providers = {}
  for _, ability in pairs(profile.abilities or {}) do
    local aff = normalizeAff(ability.aff or "")
    if aff ~= "" then
      providers[aff] = true
    end
  end

  local mode = boop.util.safeLower(boop.util.trim(conditional.needsMode or "any"))
  local supported = 0
  for _, need in ipairs(needs) do
    if providers[normalizeAff(need)] then
      supported = supported + 1
    end
  end

  if mode == "all" then
    return supported == #needs
  end
  return supported > 0
end

local rageProfiles = {}
for classKey, profile in pairs(boop.attacks.registry or {}) do
  if profile and profile.rage and profile.rage.abilities then
    rageProfiles[#rageProfiles + 1] = {
      class = classKey,
      standard = profile.standard,
      rage = profile.rage,
    }
  end
end
table.sort(rageProfiles, function(a, b)
  return a.class < b.class
end)

describe("boop rage mode contracts", function()
  for _, case in ipairs(rageProfiles) do
    it("suppresses rage output in none mode for " .. case.class, function()
      helper.reset()
      helper.setClass(case.class)
      helper.setTarget("42", "a test denizen", "80%")
      helper.setRage(100)
      learnStandardSkills(case.standard)
      learnRageSkills(case.rage)
      boop.config.attackMode = "none"

      local actions = boop.attacks.choose()

      assert.are.equal("", actions.rage)
    end)

    local smallExpected = cmdsForDesc(case.rage, "Small Damage", case.class)
    if #smallExpected == 0 then
      smallExpected = cmdsForDesc(case.rage, "Mid Damage", case.class)
    end
    if #smallExpected == 0 then
      smallExpected = cmdsForDesc(case.rage, "Big Damage", case.class)
    end
    if #smallExpected > 0 then
      it("uses a damage action in small mode for " .. case.class, function()
        helper.reset()
        helper.setClass(case.class)
        helper.setTarget("42", "a test denizen", "80%")
        helper.setRage(100)
        learnStandardSkills(case.standard)
        learnRageSkills(case.rage)
        boop.config.attackMode = "small"

        local actions = boop.attacks.choose()

        assert.is_true(setContains(smallExpected, actions.rage))
      end)
    end

    local bigExpected = cmdsForDesc(case.rage, "Big Damage", case.class)
    if #bigExpected > 0 then
      it("uses a big damage action in big mode when affordable for " .. case.class, function()
        helper.reset()
        helper.setClass(case.class)
        helper.setTarget("42", "a test denizen", "80%")
        helper.setRage(100)
        learnStandardSkills(case.standard)
        learnRageSkills(case.rage)
        boop.config.attackMode = "big"

        local actions = boop.attacks.choose()

        assert.is_true(setContains(bigExpected, actions.rage))
      end)
    end

    local affExpected = cmdsForDesc(case.rage, "Gives Affliction", case.class)
    if #affExpected > 0 then
      it("uses an affliction action in aff mode for " .. case.class, function()
        helper.reset()
        helper.setClass(case.class)
        helper.setTarget("42", "a test denizen", "80%")
        helper.setRage(100)
        learnStandardSkills(case.standard)
        learnRageSkills(case.rage)
        boop.config.attackMode = "aff"

        local actions = boop.attacks.choose()

        assert.is_true(setContains(affExpected, actions.rage))
      end)
    end

    local conditionalExpected = cmdsForDesc(case.rage, "Conditional", case.class)
    if #conditionalExpected > 0 then
      local conditional
      for _, ability in pairs(case.rage.abilities or {}) do
        if ability.desc == "Conditional" then
          conditional = ability
          break
        end
      end

      if conditional and providerSupport(case.rage, conditional) then
        it("uses the conditional in combo mode when available for " .. case.class, function()
          helper.reset()
          helper.setClass(case.class)
          helper.setTarget("42", "a test denizen", "80%")
          helper.setRage(tonumber(conditional.rage) or 100)
          learnStandardSkills(case.standard)
          learnRageSkills(case.rage)
          helper.addTargetAfflictions(conditional.needs or {})
          boop.config.attackMode = "combo"

          local actions = boop.attacks.choose()

          assert.is_true(setContains(conditionalExpected, actions.rage))
        end)
      end
    end

    local affCost = cheapestCost(case.rage, { "Gives Affliction" })
    local dmgCost = cheapestCost(case.rage, { "Small Damage", "Mid Damage", "Big Damage" })
    local damageChoices = {}
    for _, cmd in ipairs(cmdsForDesc(case.rage, "Small Damage", case.class)) do
      damageChoices[#damageChoices + 1] = cmd
    end
    for _, cmd in ipairs(cmdsForDesc(case.rage, "Mid Damage", case.class)) do
      damageChoices[#damageChoices + 1] = cmd
    end
    for _, cmd in ipairs(cmdsForDesc(case.rage, "Big Damage", case.class)) do
      damageChoices[#damageChoices + 1] = cmd
    end
    if affCost and dmgCost and #affExpected > 0 and #damageChoices > 0 then
      it("prioritizes an affliction in tempo mode when reserve cannot be preserved for " .. case.class, function()
        helper.reset()
        helper.setClass(case.class)
        helper.setTarget("42", "a test denizen", "80%")
        helper.setRage(affCost)
        learnStandardSkills(case.standard)
        learnRageSkills(case.rage)
        boop.config.attackMode = "tempo"

        local actions = boop.attacks.choose()

        assert.is_true(setContains(affExpected, actions.rage))
      end)

      it("spends a damage action in tempo mode when reserve can be preserved for " .. case.class, function()
        helper.reset()
        helper.setClass(case.class)
        helper.setTarget("42", "a test denizen", "80%")
        helper.setRage(affCost + dmgCost)
        learnStandardSkills(case.standard)
        learnRageSkills(case.rage)
        boop.config.attackMode = "tempo"

        local actions = boop.attacks.choose()

        assert.is_true(setContains(damageChoices, actions.rage))
      end)
    end
  end
end)

describe("boop exact rage dispatch contracts", function()
  local send_stub
  local timer_stub
  local kill_timer_stub
  local trace_stub
  local standard_intent_stub
  local hound_maul_stub
  local sent
  local traces
  local observe_outbound
  local fail_on_send
  local send_count
  local next_timer_id

  local function dispatchRage(command, abilityName)
    boop.state.combat.limiters.rage = false
    return boop.combat.execute({
      class = "test",
      rage = command,
      rageAbility = {
        name = abilityName,
        skill = abilityName,
      },
    })
  end

  local function commands(entries)
    local result = {}
    for _, entry in ipairs(entries or {}) do
      result[#result + 1] = entry.command
    end
    return result
  end

  local function assertCleanDispatch(expected, logicalAction, abilityName)
    assert.is_function(boop.rage.pendingSnapshot)
    assert.is_function(boop.rage.lastTerminalSnapshot)
    assert.is_function(boop.rage.onCommandOutcome)

    assert.is_true(dispatchRage(logicalAction, abilityName))
    assert.are.same(expected, sent)

    local pending = boop.rage.pendingSnapshot()
    assert.is_table(pending)
    assert.are.equal("rage", pending.kind)
    assert.are.equal("direct", pending.mode)
    assert.are.equal(logicalAction, pending.logicalAction)
    assert.are.equal("42", pending.targetId)
    assert.are.equal("1", pending.roomId)
    assert.are.equal(abilityName:lower(), pending.abilityKey)
    assert.are.same(expected, commands(pending.expectedWireCommands))
    assert.are.same(expected, commands(pending.observedWireCommands))
    assert.are.equal(
      pending.observedWireCommands[#pending.observedWireCommands].sequence,
      pending.finalOwnedWireSequence
    )

    for index, command in ipairs(expected) do
      assert.are.equal("rage direct: " .. command, traces[index])
    end
    assert.stub(standard_intent_stub).was_not_called()
    assert.stub(hound_maul_stub).was_not_called()

    assert.is_true(boop.rage.onCommandOutcome(
      "You must wait a short time before you can use a battlerage ability again."
    ))
    assert.is_false(boop.rage.pendingSnapshot())
    local terminal = boop.rage.lastTerminalSnapshot()
    assert.are.equal(pending.generation, terminal.generation)
    assert.are.equal("global_cooldown", terminal.reason)
    assert.is_true(terminal.terminal)
    assert.is_true(terminal.firstTerminal)
  end

  before_each(function()
    helper.reset()
    boop.config.enabled = true
    helper.setTarget("42", "a test denizen", "80%")
    sent = {}
    traces = {}
    observe_outbound = true
    fail_on_send = nil
    send_count = 0
    next_timer_id = 100

    send_stub = stub(_G, "send", function(command, _)
      send_count = send_count + 1
      if fail_on_send and send_count == fail_on_send then
        error("simulated rage part-send failure")
      end
      sent[#sent + 1] = command
      if observe_outbound then
        boop.onDataSendRequest(nil, command)
      end
    end)
    timer_stub = stub(_G, "tempTimer", function(_, _)
      local timerId = next_timer_id
      next_timer_id = next_timer_id + 1
      return timerId
    end)
    kill_timer_stub = stub(_G, "killTimer", function(_) end)
    trace_stub = stub(boop.trace, "log", function(message)
      traces[#traces + 1] = message
    end)
    standard_intent_stub = stub(boop.gag, "noteStandardIntent", function(_) end)
    hound_maul_stub = stub(boop.rage, "onHoundMaulUsed", function() end)
  end)

  after_each(function()
    send_stub:revert()
    timer_stub:revert()
    kill_timer_stub:revert()
    trace_stub:revert()
    standard_intent_stub:revert()
    hound_maul_stub:revert()
  end)

  it("owns one ordinary rage wire and terminalizes its matching generic denial", function()
    assertCleanDispatch({ "harry 42" }, "harry 42", "Harry")
  end)

  it("owns assist then rage wires without registering the unsplit logical expansion", function()
    boop.config.assistEnabled = true
    boop.config.assistLeader = "Ada"

    assertCleanDispatch({
      "assist Ada",
      "harry 42",
    }, "harry 42", "Harry")

    local snapshot = boop.runtime.outboundSnapshot()
    for _, expectation in ipairs(snapshot.expectations) do
      assert.are_not.equal("assist Ada/harry 42", expectation.command)
    end
  end)

  it("owns Psion assist transcend and rage wires in exact send order", function()
    boop.config.assistEnabled = true
    boop.config.assistLeader = "Ada"

    assertCleanDispatch({
      "assist Ada",
      "psi transcend shatter",
      "firefall 42",
    }, "psi transcend shatter/firefall 42", "Firefall")

    local snapshot = boop.runtime.outboundSnapshot()
    for _, expectation in ipairs(snapshot.expectations) do
      assert.are_not.equal(
        "assist Ada/psi transcend shatter/firefall 42",
        expectation.command
      )
      assert.are_not.equal(
        "psi transcend shatter/firefall 42",
        expectation.command
      )
    end
  end)

  it("leaves generic cooldown denial ambiguous after a differently owned boop wire", function()
    assert.is_function(boop.rage.onCommandOutcome)
    assert.is_function(boop.rage.pendingSnapshot)
    assert.is_function(boop.rage.isGlobalCooldownOpen)

    assert.is_true(dispatchRage("harry 42", "Harry"))
    local pending = boop.rage.pendingSnapshot()
    assert.is_true(boop.executeRageAction("temper 42"))

    assert.is_false(boop.rage.onCommandOutcome(
      "You must wait a short time before you can use a battlerage ability again."
    ))
    assert.is_true(boop.rage.isGlobalCooldownOpen())
    assert.are.equal(pending.generation, boop.rage.pendingSnapshot().generation)
  end)

  it("cancels only a partial failed rage generation and keeps its wires diagnostic", function()
    assert.is_function(boop.rage.pendingSnapshot)
    assert.is_function(boop.rage.lastTerminalSnapshot)
    fail_on_send = 2

    assert.is_false(dispatchRage("harry 42/temper 42", "Harry"))
    assert.are.same({ "harry 42" }, sent)
    assert.is_false(boop.rage.pendingSnapshot())
    local terminal = boop.rage.lastTerminalSnapshot()
    assert.are.equal("dispatch_failed", terminal.reason)
    assert.are.same({ "harry 42" }, commands(terminal.observedWireCommands))
    assert.is_false(boop.rage.onCommandOutcome(
      "You must wait a short time before you can use a battlerage ability again."
    ))
  end)

  it("refuses rage before pacing while a standard generation is pending", function()
    boop.config.useQueueing = true
    assert.is_true(boop.executeAction("jab 42", true))
    assert.is_true(boop.runtime.standardPending())
    sent = {}
    boop.state.combat.limiters.rage = false

    assert.is_false(boop.combat.execute({
      rage = "harry 42",
      rageAbility = { name = "Harry" },
    }))
    assert.are.same({}, sent)
    assert.is_false(boop.state.combat.limiters.rage)
    assert.is_false(boop.rage.pendingSnapshot())
  end)

  it("repeated attempts emit no rage while the global cooldown remains closed", function()
    assert.is_function(boop.rage.onCommandOutcome)

    assert.is_true(dispatchRage("harry 42", "Harry"))
    assert.is_true(boop.rage.onCommandOutcome(
      "You must wait a short time before you can use a battlerage ability again."
    ))
    sent = {}

    assert.is_false(dispatchRage("squeeze 42", "Squeeze"))
    assert.is_false(dispatchRage("firefall 42", "Firefall"))
    assert.are.same({}, sent)
  end)

  it("closes the causal result window at the first following prompt", function()
    assert.is_function(boop.rage.onPrompt)
    assert.is_function(boop.rage.onCommandOutcome)

    assert.is_true(dispatchRage("harry 42", "Harry"))
    assert.is_true(boop.rage.onPrompt())
    assert.is_false(boop.rage.onCommandOutcome(
      "You must wait a short time before you can use a battlerage ability again."
    ))
  end)
end)
