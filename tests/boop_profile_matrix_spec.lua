local helper = dofile(os.getenv("TESTS_DIRECTORY") .. "/support/boop_test_helper.lua")

local profileFiles = {
  "air_elemental_lady",
  "air_elemental_lord",
  "alchemist",
  "apostate",
  "bard",
  "black_dragon",
  "blademaster",
  "blue_dragon",
  "depthswalker",
  "druid",
  "earth_elemental_lady",
  "earth_elemental_lord",
  "fire_elemental_lady",
  "fire_elemental_lord",
  "golden_dragon",
  "green_dragon",
  "infernal",
  "jester",
  "magi",
  "monk",
  "occultist",
  "paladin",
  "pariah",
  "priest",
  "psion",
  "red_dragon",
  "runewarden",
  "sentinel",
  "serpent",
  "shaman",
  "silver_dragon",
  "sylvan",
  "unnamable",
  "water_elemental_lady",
  "water_elemental_lord",
}

for _, name in ipairs(profileFiles) do
  dofile(
    os.getenv("TESTS_DIRECTORY")
      .. "/../src/scripts/boop/attacks/"
      .. name
      .. ".lua"
  )
end

local baseClasses = {
  "alchemist",
  "apostate",
  "bard",
  "blademaster",
  "depthswalker",
  "druid",
  "infernal",
  "jester",
  "magi",
  "monk",
  "occultist",
  "paladin",
  "pariah",
  "priest",
  "psion",
  "runewarden",
  "sentinel",
  "serpent",
  "shaman",
  "sylvan",
  "unnamable",
}

local function learnEntrySkills(entry)
  if type(entry) ~= "table" then
    return
  end

  if entry.bySpec then
    for _, specEntry in pairs(entry.bySpec) do
      learnEntrySkills(specEntry)
    end
    learnEntrySkills(entry.default)
    return
  end


  if type(entry.needs) == "table" then
    helper.addTargetAfflictions(entry.needs)
  end

  if entry.cmd or entry.skill or entry.name then
    local skill = entry.skill or entry.name
    if skill and skill ~= "" then
      helper.learnSkill(skill, entry.group)
    end
    return
  end

  for _, option in ipairs(entry) do
    learnEntrySkills(option)
  end

  for key, value in pairs(entry) do
    if type(key) ~= "number" then
      learnEntrySkills(value)
    end
  end
end

local function targetFormat(cmd)
  return boop.util.formatTarget(cmd or "", "42")
end

local function firstExpectedCommand(entry)
  if type(entry) ~= "table" then
    return type(entry) == "string" and entry or ""
  end

  if entry.bySpec then
    local spec = boop.state and boop.state.combat.spec or ""
    local specEntry = entry.bySpec[spec]
    if not specEntry then
      specEntry = entry.default or entry.bySpec.default
    end
    return firstExpectedCommand(specEntry)
  end

  if entry.cmd or entry.skill or entry.name then
    return entry.cmd or ""
  end

  for _, option in ipairs(entry) do
    local cmd = firstExpectedCommand(option)
    if cmd ~= "" then
      return cmd
    end
  end

  return ""
end

local profileCases = {}
local allProfileCases = {}
for classKey, profile in pairs(boop.attacks.registry or {}) do
  local standard = profile and profile.standard or nil
  local damBySpec = standard and standard.dam and standard.dam.bySpec or nil
  if damBySpec then
    for spec, entry in pairs(damBySpec) do
      allProfileCases[#allProfileCases + 1] = {
        class = classKey,
        spec = spec,
        standard = standard,
      }
      profileCases[#profileCases + 1] = {
        class = classKey,
        spec = spec,
        dam = entry,
        shield = standard.shield and standard.shield.bySpec and standard.shield.bySpec[spec] or nil,
        standard = standard,
      }
    end
  elseif standard and standard.dam then
    allProfileCases[#allProfileCases + 1] = {
      class = classKey,
      spec = "",
      standard = standard,
    }
  end
end
table.sort(allProfileCases, function(a, b)
  if a.class == b.class then
    return a.spec < b.spec
  end
  return a.class < b.class
end)
table.sort(profileCases, function(a, b)
  if a.class == b.class then
    return a.spec < b.spec
  end
  return a.class < b.class
end)

describe("boop class profile matrix", function()
  it("loads every supported base class profile", function()
    for _, classKey in ipairs(baseClasses) do
      assert.is_table(boop.attacks.registry[classKey], classKey)
    end
  end)

  for _, case in ipairs(allProfileCases) do
    local caseLabel = case.spec ~= ""
        and (case.class .. " / " .. case.spec)
      or case.class
    it("provides a usable standard attack for " .. caseLabel, function()
      helper.reset()
      helper.setClass(case.class)
      helper.setSpec(case.spec)
      helper.setTarget("42", "a test denizen", "80%")
      learnEntrySkills(case.standard)

      local readiness = boop.attacks.profileReadiness(case.class)

      assert.is_true(readiness.ready)
      assert.is_true(readiness.command ~= "")
    end)
  end

  for _, case in ipairs(profileCases) do
    it("uses the standard command for " .. case.class .. " / " .. case.spec, function()
      helper.reset()
      helper.setClass(case.class)
      helper.setSpec(case.spec)
      helper.setTarget("42", "a test denizen", "80%")
      helper.setSkillKnown("Focus", false, "Weaponmastery")
      learnEntrySkills(case.standard)

      local actions = boop.attacks.choose()

      assert.are.equal(targetFormat(firstExpectedCommand(case.dam)), actions.standard)
    end)

    if case.shield then
      it("uses the shield command for " .. case.class .. " / " .. case.spec, function()
        helper.reset()
        helper.setClass(case.class)
        helper.setSpec(case.spec)
        helper.setTarget("42", "a test denizen", "80%")
        helper.setSkillKnown("Focus", false, "Weaponmastery")
        learnEntrySkills(case.standard)
        boop.state.targeting.targetShield = { attempted = false }

        local actions = boop.attacks.choose()

        assert.are.equal(targetFormat(firstExpectedCommand(case.shield)), actions.standard)
        assert.is_true(actions.standardShieldbreak)
      end)
    end
  end
end)
