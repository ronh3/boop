local helper = dofile(os.getenv("TESTS_DIRECTORY") .. "/support/boop_test_helper.lua")

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

  if entry.cmd or entry.skill or entry.name then
    local skill = entry.skill or entry.name
    if skill and skill ~= "" then
      helper.learnSkill(skill, entry.group)
    end
    if type(entry.skills) == "table" then
      for _, requirement in ipairs(entry.skills) do
        if type(requirement) == "table" then
          local requirementSkill = requirement.skill or requirement.name
          if requirementSkill and requirementSkill ~= "" then
            helper.learnSkill(requirementSkill, requirement.group)
          end
        elseif type(requirement) == "string" and requirement ~= "" then
          helper.learnSkill(requirement, entry.group)
        end
      end
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

local openerAt100Profiles = {}
local openerProfiles = {}
for classKey, profile in pairs(boop.attacks.registry or {}) do
  local standard = profile and profile.standard or nil
  if standard and standard.openerAt100 then
    openerAt100Profiles[#openerAt100Profiles + 1] = {
      class = classKey,
      opener = standard.openerAt100,
      standard = standard,
    }
  end
  if standard and standard.opener then
    openerProfiles[#openerProfiles + 1] = {
      class = classKey,
      opener = standard.opener,
      standard = standard,
    }
  end
end
table.sort(openerAt100Profiles, function(a, b)
  return a.class < b.class
end)
table.sort(openerProfiles, function(a, b)
  return a.class < b.class
end)

describe("boop opener contracts", function()
  for _, case in ipairs(openerAt100Profiles) do
    it("uses the full-hp opener at full hp for " .. case.class, function()
      helper.reset()
      helper.setClass(case.class)
      helper.setTarget("42", "a test denizen", "100%")
      learnEntrySkills(case.standard)

      local actions = boop.attacks.choose()

      assert.are.equal(targetFormat(case.opener.cmd), actions.standard)
      assert.is_true(actions.standardIsOpener)
    end)

    it("skips the full-hp opener below full hp for " .. case.class, function()
      helper.reset()
      helper.setClass(case.class)
      helper.setTarget("42", "a test denizen", "80%")
      learnEntrySkills(case.standard)

      local actions = boop.attacks.choose()

      assert.are_not.equal(targetFormat(case.opener.cmd), actions.standard)
      assert.is_false(actions.standardIsOpener)
    end)
  end

  for _, case in ipairs(openerProfiles) do
    it("uses the first-hit opener at full hp for " .. case.class, function()
      helper.reset()
      helper.setClass(case.class)
      helper.setTarget("42", "a test denizen", "100%")
      learnEntrySkills(case.standard)

      local actions = boop.attacks.choose()

      assert.are.equal(targetFormat(case.opener.cmd), actions.standard)
      assert.is_true(actions.standardIsOpener)
    end)

    it("uses the first-hit opener below full hp for " .. case.class, function()
      helper.reset()
      helper.setClass(case.class)
      helper.setTarget("42", "a test denizen", "80%")
      learnEntrySkills(case.standard)

      local actions = boop.attacks.choose()

      assert.are.equal(targetFormat(case.opener.cmd), actions.standard)
      assert.is_true(actions.standardIsOpener)
    end)

    it("does not reuse the opener once marked for " .. case.class, function()
      helper.reset()
      helper.setClass(case.class)
      helper.setTarget("42", "a test denizen", "100%")
      learnEntrySkills(case.standard)
      boop.attacks.markOpenerUsed(case.class, "42")

      local actions = boop.attacks.choose()

      assert.are_not.equal(targetFormat(case.opener.cmd), actions.standard)
      assert.is_false(actions.standardIsOpener)
    end)
  end
end)
