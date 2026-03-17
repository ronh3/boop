local helper = dofile(os.getenv("TESTS_DIRECTORY") .. "/support/boop_test_helper.lua")

describe("boop tick", function()
  local send_stub
  local send_gmcp_stub
  local timer_stub
  local kill_timer_stub

  before_each(function()
    helper.reset()
    helper.setArea("Test Area")
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

    timer_stub = stub(_G, "tempTimer", function(_, _)
      return 1
    end)
    kill_timer_stub = stub(_G, "killTimer", function(_) end)
    send_stub = stub(_G, "send", function(_, _) end)
    send_gmcp_stub = stub(_G, "sendGMCP", function(_) end)
  end)

  after_each(function()
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
  end)

  it("targets the denizen and sends standard plus rage actions", function()
    boop.tick()

    assert.stub(send_stub).was_called_with("settarget 42", false)
    assert.stub(send_stub).was_called_with("command hound at 42", false)
    assert.stub(send_stub).was_called_with("harry 42", false)
  end)

  it("does not send attacks while gold handling is pending", function()
    boop.state.goldGetPending = true

    boop.tick()

    assert.stub(send_stub).was_not_called()
  end)
end)
