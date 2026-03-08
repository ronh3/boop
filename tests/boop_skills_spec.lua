local helper = dofile(os.getenv("TESTS_DIRECTORY") .. "/support/boop_test_helper.lua")

describe("boop skill ingestion", function()
  local send_gmcp_stub
  local timer_stub
  local kill_timer_stub
  local pending_callback

  before_each(function()
    helper.reset()
    pending_callback = nil

    send_gmcp_stub = stub(_G, "sendGMCP", function(_) end)
    timer_stub = stub(_G, "tempTimer", function(_, callback)
      pending_callback = callback
      return 88
    end)
    kill_timer_stub = stub(_G, "killTimer", function(_) end)
  end)

  after_each(function()
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
  end)

  it("requests the global skills list and the desired gating groups", function()
    boop.skills.desiredGroups = { "Domination", "Attainment", "domination" }

    boop.skills.requestAll()

    assert.stub(send_gmcp_stub).was_called_with([[Char.Skills.Get]])
    assert.stub(send_gmcp_stub).was_called_with([[Char.Skills.Get {"group":"domination"}]])
    assert.stub(send_gmcp_stub).was_called_with([[Char.Skills.Get {"group":"attainment"}]])
  end)

  it("learns skill-to-group mappings from keyed skill-list gmcp payloads", function()
    gmcp.Char.Skills.List = {
      group = "Weaponmastery",
      list = {
        attack = { name = "Slaughter" },
        utility = "Focus",
      },
    }

    boop.onSkillsList()

    assert.are.equal("weaponmastery", boop.skills.skillToGroup.slaughter)
    assert.are.equal("weaponmastery", boop.skills.skillToGroup.focus)
    assert.are.equal("Slaughter", boop.skills.skillOriginal.slaughter)
    assert.are.equal("Focus", boop.skills.skillOriginal.focus)
    assert.are.equal("weaponmastery", boop.skills.lastList.group)
  end)

  it("requests unknown mapped skills on first lookup", function()
    boop.skills.skillToGroup.slaughter = "weaponmastery"
    boop.skills.skillOriginal.slaughter = "Slaughter"

    assert.is_false(boop.skills.knownSkill("Slaughter"))
    assert.is_true(boop.skills.pending.slaughter)
    assert.are.equal(88, boop.skills.pendingTimers.slaughter)
    assert.is_function(pending_callback)
    assert.stub(send_gmcp_stub).was_called_with([[Char.Skills.Get {"group":"weaponmastery","name":"Slaughter"}]])
  end)

  it("marks skill info as not learned and clears the pending timer", function()
    boop.skills.pending.slive = true
    boop.skills.pendingTimers.slive = 73
    gmcp.Char.Skills.Info = {
      name = "Slive",
      info = "You have not learned this skill yet.",
    }

    boop.onSkillsInfo()

    assert.is_false(boop.skills.known.slive)
    assert.is_nil(boop.skills.pending.slive)
    assert.is_nil(boop.skills.pendingTimers.slive)
    assert.stub(kill_timer_stub).was_called_with(73)
  end)

  it("marks skill info as learned when gmcp reports it directly", function()
    gmcp.Char.Skills.Info = {
      name = "Lycantha",
      learned = true,
    }

    boop.onSkillsInfo()

    assert.is_true(boop.skills.known.lycantha)
  end)
end)
