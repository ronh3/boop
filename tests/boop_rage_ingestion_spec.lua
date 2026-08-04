local helper = dofile(os.getenv("TESTS_DIRECTORY") .. "/support/boop_test_helper.lua")

local NO_ABILITIES_RECOVERY =
  "You can use another Battlerage ability again, but none of your abilities are currently available."

local function deepCopy(value)
  if type(value) ~= "table" then
    return value
  end
  local out = {}
  for key, entry in pairs(value) do
    out[deepCopy(key)] = deepCopy(entry)
  end
  return out
end

local function readRepoFile(relativePath)
  local root = assert(os.getenv("BOOP_REPO_ROOT"))
  local handle = assert(io.open(root .. "/" .. relativePath, "r"))
  local contents = handle:read("*a")
  handle:close()
  return contents
end

local function rageOutcomePatterns()
  local manifestText = readRepoFile(
    "src/triggers/boop/Rage/triggers.json"
  )
  local startAt = assert(manifestText:find(
    '"name": "Rage Command Outcome"',
    1,
    true
  ))
  local endAt = assert(manifestText:find(
    '"name": "Triumph Free Rage"',
    startAt,
    true
  ))
  local triggerText = manifestText:sub(startAt, endAt - 1)
  local patterns = {}
  for encoded in triggerText:gmatch('"pattern"%s*:%s*"(.-)"') do
    patterns[#patterns + 1] = encoded:gsub("\\\\", "\\")
  end
  return patterns
end

local REGEX_META = {
  ["."] = true,
  ["["] = true,
  ["]"] = true,
  ["("] = true,
  [")"] = true,
  ["{"] = true,
  ["}"] = true,
  ["*"] = true,
  ["+"] = true,
  ["?"] = true,
  ["|"] = true,
  ["^"] = true,
  ["$"] = true,
}

local function anchoredLiteralRegexMatches(pattern, value)
  if pattern:sub(1, 1) ~= "^" or pattern:sub(-1) ~= "$" then
    return false
  end
  local body = pattern:sub(2, -2)
  local literal = {}
  local index = 1
  while index <= #body do
    local char = body:sub(index, index)
    if char == "\\" then
      if index == #body then
        return false
      end
      literal[#literal + 1] = body:sub(index + 1, index + 1)
      index = index + 2
    elseif REGEX_META[char] then
      return false
    else
      literal[#literal + 1] = char
      index = index + 1
    end
  end
  return table.concat(literal) == tostring(value or "")
end

local function matchingOutcomePatterns(rawLine)
  local matches = {}
  for _, pattern in ipairs(rageOutcomePatterns()) do
    if anchoredLiteralRegexMatches(pattern, rawLine) then
      matches[#matches + 1] = pattern
    end
  end
  return matches
end

local function seedNoAbilitiesRecoveryState()
  boop.state.rage = {
    ready = {
      harry = false,
      squeeze = true,
      firefall = false,
    },
    timers = { harry = 701 },
    timerGenerations = { harry = 4 },
    samples = {
      { t = 10, r = 12 },
      { t = 15, r = 18 },
    },
    dispatchGeneration = 19,
    pending = {
      owner = "rage:19",
      generation = 19,
      dispatchId = "rage:19:1",
      status = "pending",
      terminal = false,
      responseTimer = 702,
    },
    lastTerminal = {
      owner = "rage:18",
      generation = 18,
      status = "executed",
      terminal = true,
    },
    globalCooldownOpen = false,
    triumphGeneration = 8,
    triumph = {
      generation = 8,
      active = true,
      timer = 703,
      reason = "awaiting_expiry",
    },
    freeNext = true,
  }
  boop.state.combat.limiters.rage = 704
end

local function assertOnlyGlobalCooldownOpened(beforeRage, beforeLimiters)
  local expectedRage = deepCopy(beforeRage)
  expectedRage.globalCooldownOpen = true
  assert.are.same(expectedRage, boop.state.rage)
  assert.are.same(beforeLimiters, boop.state.combat.limiters)
end

local function runActualOutcomeAdapter(rawLine)
  local root = assert(os.getenv("BOOP_REPO_ROOT"))
  local adapterPath =
    root .. "/src/triggers/boop/Rage/Rage_Command_Outcome.lua"
  local priorLine = rawget(_G, "line")
  local priorMatches = rawget(_G, "matches")
  local parser = boop.rage.onCommandOutcome
  local calls = 0

  boop.rage.onCommandOutcome = function(candidate)
    calls = calls + 1
    return parser(candidate)
  end
  _G.line = rawLine
  _G.matches = { rawLine }

  local ok, err = pcall(dofile, adapterPath)

  boop.rage.onCommandOutcome = parser
  _G.line = priorLine
  _G.matches = priorMatches
  if not ok then
    error(err, 0)
  end
  return calls
end

describe("boop rage ingestion", function()
  local send_stub
  local timer_stub
  local kill_timer_stub
  local epoch_stub
  local info_stub
  local restore_callback
  local timer_callbacks
  local timer_durations
  local next_timer_id
  local observe_outbound

  local function emitRage(command, abilityName)
    boop.state.combat.limiters.rage = false
    return boop.attacks.execute({
      class = "test",
      rage = command,
      rageAbility = {
        name = abilityName,
        skill = abilityName,
      },
    })
  end

  before_each(function()
    helper.reset()
    boop.config.enabled = true
    restore_callback = nil
    timer_callbacks = {}
    timer_durations = {}
    next_timer_id = 45
    observe_outbound = true

    send_stub = stub(_G, "send", function(command, _)
      if observe_outbound then
        boop.onDataSendRequest(nil, command)
      end
    end)
    timer_stub = stub(_G, "tempTimer", function(seconds, callback)
      local timerId = next_timer_id
      next_timer_id = next_timer_id + 1
      restore_callback = callback
      timer_callbacks[timerId] = callback
      timer_durations[timerId] = seconds
      return timerId
    end)
    kill_timer_stub = stub(_G, "killTimer", function(timerId)
      timer_callbacks[timerId] = nil
    end)
    info_stub = stub(boop.util, "info", function(_) end)
  end)

  after_each(function()
    if send_stub then
      send_stub:revert()
      send_stub = nil
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
    if info_stub then
      info_stub:revert()
      info_stub = nil
    end
  end)

  it("marks rage abilities unavailable on use and restores them after the fallback timer", function()
    boop.config.rageFallbackSeconds = 12
    boop.rage.setReady("harry", true)

    boop.rage.onRageUsed({ name = "Harry" })

    assert.is_false(boop.state.rage.ready.harry)
    assert.are.equal(45, boop.state.rage.timers.harry)
    assert.is_function(restore_callback)

    restore_callback()

    assert.is_true(boop.state.rage.ready.harry)
    assert.is_nil(boop.state.rage.timers.harry)
  end)

  it("sets the Triumph free-rage flag and clears it on the next rage use", function()
    assert.is_false(boop.rage.hasFreeNext())

    boop.rage.onTriumphFreeRage()

    assert.is_true(boop.rage.hasFreeNext())

    boop.rage.onRageUsed({ name = "Harry" })

    assert.is_false(boop.rage.hasFreeNext())
  end)

  it("closes the global gate only for a clean causal cooldown denial and gates before local pacing", function()
    assert.is_function(boop.rage.onCommandOutcome)
    assert.is_function(boop.rage.isGlobalCooldownOpen)

    assert.is_true(emitRage("harry 42", "Harry"))
    assert.is_true(boop.rage.onCommandOutcome(
      "You must wait a short time before you can use a battlerage ability again."
    ))
    assert.is_false(boop.rage.isGlobalCooldownOpen())

    boop.state.combat.limiters.rage = false
    assert.is_false(boop.canUseRage())
    assert.is_false(boop.state.combat.limiters.rage)
  end)

  it("keeps a generic denial ambiguous after a later manual outbound command", function()
    assert.is_function(boop.rage.onCommandOutcome)
    assert.is_function(boop.rage.pendingSnapshot)
    assert.is_function(boop.rage.isGlobalCooldownOpen)

    assert.is_true(emitRage("harry 42", "Harry"))
    local pending = boop.rage.pendingSnapshot()
    assert.is_table(pending)

    boop.onDataSendRequest(nil, "look")
    assert.is_false(boop.rage.onCommandOutcome(
      "You must wait a short time before you can use a battlerage ability again."
    ))
    assert.is_true(boop.rage.isGlobalCooldownOpen())
    assert.are.equal(pending.generation, boop.rage.pendingSnapshot().generation)
  end)

  it("opens global rage on exact Available recovery and marks only listed abilities ready", function()
    assert.is_function(boop.rage.onCommandOutcome)
    assert.is_function(boop.rage.isGlobalCooldownOpen)

    assert.is_true(emitRage("harry 42", "Harry"))
    assert.is_true(boop.rage.onCommandOutcome(
      "You must wait a short time before you can use a battlerage ability again."
    ))
    boop.rage.setReady("harry", false)
    boop.rage.setReady("squeeze", false)
    boop.rage.setReady("firefall", false)

    assert.is_true(boop.rage.onCommandOutcome(
      "You can use another Battlerage ability again. Available abilities: Harry, Squeeze"
    ))
    assert.is_true(boop.rage.isGlobalCooldownOpen())
    assert.is_true(boop.state.rage.ready.harry)
    assert.is_true(boop.state.rage.ready.squeeze)
    assert.is_false(boop.state.rage.ready.firefall)
  end)

  it("rejects an empty or inexact Available recovery line", function()
    assert.is_function(boop.rage.onCommandOutcome)

    boop.state.rage.globalCooldownOpen = false
    boop.rage.setReady("harry", false)

    assert.is_false(boop.rage.onCommandOutcome(
      "You can use another Battlerage ability again. Available abilities:"
    ))
    assert.is_false(boop.rage.onCommandOutcome(
      "Available abilities: Harry"
    ))
    assert.is_false(boop.state.rage.globalCooldownOpen)
    assert.is_false(boop.state.rage.ready.harry)
  end)

  it("opens only the global gate for the exact no-abilities recovery sentence", function()
    seedNoAbilitiesRecoveryState()
    local beforeRage = deepCopy(boop.state.rage)
    local beforeLimiters = deepCopy(boop.state.combat.limiters)

    assert.are.equal(
      NO_ABILITIES_RECOVERY,
      boop.rage.NO_ABILITIES_RECOVERY
    )
    assert.is_true(boop.rage.onCommandOutcome(NO_ABILITIES_RECOVERY))
    assertOnlyGlobalCooldownOpened(beforeRage, beforeLimiters)
    assert.stub(kill_timer_stub).was_not_called()
  end)

  it("routes one exact manifest match through the existing adapter once", function()
    seedNoAbilitiesRecoveryState()
    local beforeRage = deepCopy(boop.state.rage)
    local beforeLimiters = deepCopy(boop.state.combat.limiters)
    local manifestMatches = matchingOutcomePatterns(NO_ABILITIES_RECOVERY)

    assert.are.equal(1, #manifestMatches)
    local adapterCalls = 0
    for _ = 1, #manifestMatches do
      adapterCalls = adapterCalls + runActualOutcomeAdapter(
        NO_ABILITIES_RECOVERY
      )
    end

    assert.are.equal(1, adapterCalls)
    assertOnlyGlobalCooldownOpened(beforeRage, beforeLimiters)
    assert.stub(kill_timer_stub).was_not_called()
  end)

  it("rejects no-abilities near matches at both manifest and parser boundaries", function()
    seedNoAbilitiesRecoveryState()
    local nearMatches = {
      "You can use another Battlerage ability again, but none of your abilities are currently available",
      "Notice: " .. NO_ABILITIES_RECOVERY,
      NO_ABILITIES_RECOVERY .. " Now.",
      "You can use another Battlerage ability again, but no abilities are currently available.",
    }

    for _, nearMatch in ipairs(nearMatches) do
      local beforeRage = deepCopy(boop.state.rage)
      local beforeLimiters = deepCopy(boop.state.combat.limiters)
      assert.are.equal(0, #matchingOutcomePatterns(nearMatch))
      assert.is_false(boop.rage.onCommandOutcome(nearMatch))
      assert.are.same(beforeRage, boop.state.rage)
      assert.are.same(beforeLimiters, boop.state.combat.limiters)
    end
    assert.stub(kill_timer_stub).was_not_called()
  end)

  it("bounds Triumph by generation and ignores a stale replaced timer", function()
    assert.is_function(boop.rage.onTriumphFreeRage)

    boop.rage.onTriumphFreeRage()
    local first = boop.state.rage.triumph
    assert.is_table(first)
    local firstGeneration = first.generation
    local firstCallback = timer_callbacks[first.timer]
    assert.is_function(firstCallback)

    boop.rage.onTriumphFreeRage()
    local second = boop.state.rage.triumph
    assert.is_true(second.generation > firstGeneration)
    assert.are.equal(26, timer_durations[second.timer])

    firstCallback()
    assert.is_true(boop.rage.hasFreeNext())

    timer_callbacks[second.timer]()
    assert.is_false(boop.rage.hasFreeNext())
  end)

  it("keeps Triumph through movement then clears it on exact expiry", function()
    assert.is_function(boop.rage.onCommandOutcome)

    boop.rage.onTriumphFreeRage()
    local generation = boop.state.rage.triumph.generation
    boop.onDataSendRequest(nil, "north")

    assert.is_true(boop.rage.hasFreeNext())
    assert.are.equal(generation, boop.state.rage.triumph.generation)
    assert.is_true(boop.rage.onCommandOutcome("Your rage fades away."))
    assert.is_false(boop.rage.hasFreeNext())
  end)

  it("consumes Triumph once on matching boop rage use", function()
    boop.rage.onTriumphFreeRage()

    assert.is_true(emitRage("harry 42", "Harry"))
    assert.is_false(boop.rage.hasFreeNext())

    boop.rage.onRageUsed({ name = "Squeeze" })
    assert.is_false(boop.rage.hasFreeNext())
  end)

  it("clears Triumph for causal insufficient rage but not after manual contamination", function()
    assert.is_function(boop.rage.onCommandOutcome)

    assert.is_true(emitRage("squeeze 42", "Squeeze"))
    boop.rage.onTriumphFreeRage()
    assert.is_true(boop.rage.onCommandOutcome(
      "Your Squeeze ability could be used again but you lack the necessary Rage."
    ))
    assert.is_false(boop.rage.hasFreeNext())

    boop.onPrompt()
    boop.state.combat.limiters.rage = false
    assert.is_true(emitRage("squeeze 42", "Squeeze"))
    boop.rage.onTriumphFreeRage()
    boop.onDataSendRequest(nil, "look")
    assert.is_false(boop.rage.onCommandOutcome(
      "Your Squeeze ability could be used again but you lack the necessary Rage."
    ))
    assert.is_true(boop.rage.hasFreeNext())
  end)

  it("terminalizes a pending rage at its response timeout without blocking later ordinary rage", function()
    assert.is_function(boop.rage.pendingSnapshot)
    assert.is_function(boop.rage.lastTerminalSnapshot)

    assert.is_true(emitRage("harry 42", "Harry"))
    local pending = boop.rage.pendingSnapshot()
    assert.is_table(pending)
    assert.is_function(timer_callbacks[pending.responseTimer])

    timer_callbacks[pending.responseTimer]()
    assert.is_false(boop.rage.pendingSnapshot())
    assert.are.equal("timeout", boop.rage.lastTerminalSnapshot().reason)

    boop.state.combat.limiters.rage = false
    assert.is_true(emitRage("squeeze 42", "Squeeze"))
  end)

  it("clears prior-connection pending cooldown and Triumph state on reconnect", function()
    assert.is_function(boop.rage.pendingSnapshot)
    assert.is_function(boop.rage.isGlobalCooldownOpen)

    assert.is_true(emitRage("harry 42", "Harry"))
    boop.rage.onTriumphFreeRage()
    boop.state.rage.globalCooldownOpen = false

    boop.onConnectionEvent()

    assert.is_false(boop.rage.pendingSnapshot())
    assert.is_true(boop.rage.isGlobalCooldownOpen())
    assert.is_false(boop.rage.hasFreeNext())
  end)

  it("packages one thin exact Rage command outcome trigger adapter", function()
    local root = assert(os.getenv("BOOP_REPO_ROOT"))
    local manifest = assert(io.open(root .. "/src/triggers/boop/Rage/triggers.json", "r"))
    local manifestText = manifest:read("*a")
    manifest:close()
    local adapter = io.open(root .. "/src/triggers/boop/Rage/Rage_Command_Outcome.lua", "r")

    assert.is_not_nil(adapter)
    local adapterText = adapter:read("*a")
    adapter:close()
    assert.is_truthy(manifestText:find("Rage Command Outcome", 1, true))
    assert.is_truthy(manifestText:find(
      "^You must wait a short time before you can use a battlerage ability again\\\\.$",
      1,
      true
    ))
    assert.is_truthy(manifestText:find(
      "^You can use another Battlerage ability again\\\\. Available abilities: (.+)$",
      1,
      true
    ))
    assert.is_truthy(manifestText:find("^Your rage fades away\\\\.$", 1, true))
    assert.is_truthy(manifestText:find(
      "^Your (\\\\w+) ability could be used again but you lack the necessary Rage\\\\.$",
      1,
      true
    ))
    assert.is_truthy(adapterText:find("boop.rage.onCommandOutcome", 1, true))
  end)

  it("records rage samples and computes gain rate and eta from them", function()
    local ticks = { 100, 105, 110 }
    local idx = 0
    epoch_stub = stub(_G, "getEpoch", function()
      idx = idx + 1
      return ticks[idx] or ticks[#ticks]
    end)

    boop.rage.onRageObserved(10)
    boop.rage.onRageObserved(16)
    boop.rage.onRageObserved(22)

    assert.are.equal(1.2, boop.rage.getGainRate(20))
    assert.are.equal(10, boop.rage.etaToRage(34, 22, 20))
  end)

  it("tracks matching rage affliction add and remove triggers and sends party callouts", function()
    helper.setTarget("42", "a test denizen", "80%")
    boop.config.enabled = true

    boop.rage.onAfflictionTrigger({
      mode = "add",
      affs = { "Stunned" },
      target = { kind = "match", index = 2 },
      source = "test add",
    }, { "line", "a test denizen" }, "add line")

    assert.is_true(boop.afflictions.hasTarget("stun"))
    assert.stub(send_stub).was_called_with("pt 42: stun", false)

    boop.rage.onAfflictionTrigger({
      mode = "remove",
      affs = { "Stunned" },
      target = { kind = "match", index = 2 },
      source = "test remove",
    }, { "line", "a test denizen" }, "remove line")

    assert.is_false(boop.afflictions.hasTarget("stun"))
    assert.stub(send_stub).was_called_with("pt 42: stun down", false)
  end)

  it("can suppress rage affliction party callouts while still tracking the affliction state", function()
    helper.setTarget("42", "a test denizen", "80%")
    boop.config.enabled = true
    boop.config.rageAffCalloutsEnabled = false

    boop.rage.onAfflictionTrigger({
      mode = "add",
      affs = { "Stunned" },
      target = { kind = "match", index = 2 },
      source = "test add",
    }, { "line", "a test denizen" }, "add line")

    assert.is_true(boop.afflictions.hasTarget("stun"))
    assert.stub(send_stub).was_not_called()
  end)

  it("ignores rage affliction triggers for other targets", function()
    helper.setTarget("42", "a test denizen", "80%")
    boop.config.enabled = true

    boop.rage.onAfflictionTrigger({
      mode = "add",
      affs = { "Stunned" },
      target = { kind = "match", index = 2 },
    }, { "line", "a different denizen" }, "other target line")

    assert.is_false(boop.afflictions.hasTarget("stun"))
    assert.stub(send_stub).was_not_called()
  end)

  it("does not process rage affliction triggers while boop is disabled", function()
    helper.setTarget("42", "a test denizen", "80%")
    boop.config.enabled = false

    boop.rage.onAfflictionTrigger({
      mode = "add",
      affs = { "Stunned" },
      target = { kind = "match", index = 2 },
    }, { "line", "a test denizen" }, "disabled line")

    assert.is_false(boop.afflictions.hasTarget("stun"))
    assert.stub(send_stub).was_not_called()
  end)
end)
