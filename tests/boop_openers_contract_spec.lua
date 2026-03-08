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
    return
  end

  for _, option in ipairs(entry) do
    learnEntrySkills(option)
  end
end

local function targetFormat(cmd)
  return boop.util.formatTarget(cmd or "", "42")
end

local openerProfiles = {}
for classKey, profile in pairs(boop.attacks.registry or {}) do
  local standard = profile and profile.standard or nil
  local opener = standard and (standard.openerAt100 or standard.opener) or nil
  if opener then
    openerProfiles[#openerProfiles + 1] = {
      class = classKey,
      opener = opener,
      standard = standard,
    }
  end
end
table.sort(openerProfiles, function(a, b)
  return a.class < b.class
end)

describe("boop opener contracts", function()
  for _, case in ipairs(openerProfiles) do
    it("uses the opener at full hp for " .. case.class, function()
      helper.reset()
      helper.setClass(case.class)
      helper.setTarget("42", "a test denizen", "100%")
      learnEntrySkills(case.standard)

      local actions = boop.attacks.choose()

      assert.are.equal(targetFormat(case.opener.cmd), actions.standard)
      assert.is_true(actions.standardIsOpener)
    end)

    it("skips the opener below full hp for " .. case.class, function()
      helper.reset()
      helper.setClass(case.class)
      helper.setTarget("42", "a test denizen", "80%")
      learnEntrySkills(case.standard)

      local actions = boop.attacks.choose()

      assert.are_not.equal(targetFormat(case.opener.cmd), actions.standard)
      assert.is_false(actions.standardIsOpener)
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
