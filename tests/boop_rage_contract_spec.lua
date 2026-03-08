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

local function cmdsForDesc(profile, desc)
  local cmds = {}
  for _, ability in pairs(profile.abilities or {}) do
    if ability.desc == desc and ability.cmd and ability.cmd ~= "" then
      cmds[#cmds + 1] = boop.util.formatTarget(ability.cmd, "42")
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

    local smallExpected = cmdsForDesc(case.rage, "Small Damage")
    if #smallExpected == 0 then
      smallExpected = cmdsForDesc(case.rage, "Mid Damage")
    end
    if #smallExpected == 0 then
      smallExpected = cmdsForDesc(case.rage, "Big Damage")
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

    local bigExpected = cmdsForDesc(case.rage, "Big Damage")
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

    local affExpected = cmdsForDesc(case.rage, "Gives Affliction")
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

    local conditionalExpected = cmdsForDesc(case.rage, "Conditional")
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
    for _, cmd in ipairs(cmdsForDesc(case.rage, "Small Damage")) do
      damageChoices[#damageChoices + 1] = cmd
    end
    for _, cmd in ipairs(cmdsForDesc(case.rage, "Mid Damage")) do
      damageChoices[#damageChoices + 1] = cmd
    end
    for _, cmd in ipairs(cmdsForDesc(case.rage, "Big Damage")) do
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
