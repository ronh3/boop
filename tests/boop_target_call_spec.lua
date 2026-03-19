local helper = dofile(os.getenv("TESTS_DIRECTORY") .. "/support/boop_test_helper.lua")

describe("boop leader target call mode", function()
  local send_stub
  local send_gmcp_stub
  local timer_stub

  before_each(function()
    helper.reset()
    helper.setArea("Test Area")
    helper.setClass("Occultist")
    helper.learnSkills({
      { name = "Warp", group = "Occultism" },
      { name = "harry", group = "Attainment" },
    })
    helper.setDenizens({
      { id = "42", name = "first denizen" },
      { id = "43", name = "called denizen" },
    })
    boop.config.enabled = true
    boop.config.targetingMode = "auto"
    boop.config.targetCall = true
    boop.config.assistLeader = "Person"

    timer_stub = stub(_G, "tempTimer", function(_, callback)
      if callback then
        callback()
      end
      return 1
    end)
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
  end)

  it("does not choose a target before the leader calls one", function()
    assert.are.equal("", boop.targets.choose())
    boop.tick()
    assert.stub(send_stub).was_not_called()
    assert.stub(send_gmcp_stub).was_not_called()
  end)

  it("chooses the called target id after the designated leader calls it", function()
    local accepted = boop.targets.onPartyTargetCall("Person", "43", [[(Party): Person says, "Target: 43."]])

    assert.is_true(accepted)
    assert.are.equal("43", boop.targets.choose())
  end)

  it("ignores target calls from other party members", function()
    local accepted = boop.targets.onPartyTargetCall("SomeoneElse", "43", [[(Party): SomeoneElse says, "Target: 43."]])

    assert.is_false(accepted)
    assert.are.equal("", boop.targets.choose())
  end)

  it("attacks the called target once the leader target call arrives", function()
    boop.targets.onPartyTargetCall("Person", "43", [[(Party): Person says, "Target: 43."]])

    assert.stub(send_stub).was_called_with("settarget 43", false)
    assert.stub(send_stub).was_called_with("warp 43", false)
  end)

  it("clears the leader call when the room changes", function()
    boop.targets.onPartyTargetCall("Person", "43", [[(Party): Person says, "Target: 43."]])

    gmcp.Room.Info.num = 2
    boop.onRoomInfo()

    assert.are.equal("", boop.state.calledTargetId)
    assert.are.equal("", boop.targets.choose())
  end)

  it("automatically party-calls a newly engaged target in leader mode", function()
    boop.config.targetCall = false
    boop.config.assistLeader = ""
    boop.config.autoTargetCall = true

    boop.tick()

    assert.stub(send_stub).was_called_with("settarget 42", false)
    assert.stub(send_stub).was_called_with("pt Target: 42.", false)
    assert.stub(send_stub).was_called_with("warp 42", false)
    assert.are.equal("42", boop.state.calledTargetId)
  end)
end)
