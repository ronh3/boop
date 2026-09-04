local helper = dofile(os.getenv("TESTS_DIRECTORY") .. "/support/boop_test_helper.lua")

describe("boop Wire transport boundary", function()
  local send_stub
  local begin_stub
  local complete_stub
  local gag_stub
  local record_binding_stub

  before_each(function()
    helper.reset()
    boop.config.enabled = true
    boop.config.useQueueing = false
    helper.setTarget("42", "current target", "80%")
    send_stub = stub(_G, "send")
    begin_stub = stub(boop.runtime, "beginStandardDispatch", function(options)
      return {
        owner = "test",
        generation = 1,
        dispatchId = 1,
        kind = "standard",
        targetId = options.targetId,
      }
    end)
    complete_stub = stub(boop.runtime, "completeStandardDispatch", function()
      return true
    end)
    local recordStandardAliasBinding = boop.runtime.recordStandardAliasBinding
    record_binding_stub = stub(
      boop.runtime,
      "recordStandardAliasBinding",
      function(...)
        return recordStandardAliasBinding(...)
      end
    )
    gag_stub = stub(boop.gag, "noteStandardIntent")
  end)

  after_each(function()
    gag_stub:revert()
    record_binding_stub:revert()
    complete_stub:revert()
    begin_stub:revert()
    send_stub:revert()
  end)

  it("uses the caller-supplied target identity instead of targeting state", function()
    assert.is_true(boop.wire.executeAction("jab 900", "900", false))

    local call = begin_stub.calls[1]
    assert.is_table(call)
    assert.are.equal("900", call.vals[1].targetId)
    assert.are.equal("42", boop.state.targeting.currentTargetId)
    assert.stub(send_stub).was_called_with("jab 900", false)
  end)

  it("keeps compatibility gag notification in the external forwarder", function()
    assert.is_true(boop.wire.executeAction("jab 42", "42", false))
    assert.stub(gag_stub).was_not_called()

    assert.is_true(boop.executeAction("jab 42", false))
    assert.stub(gag_stub).was_called_with("jab 42")
  end)

  it("preserves queued alias output, binding state, target identity, and assist prefix", function()
    boop.config.useQueueing = true
    boop.config.assistEnabled = true
    boop.config.assistLeader = "Leader"
    boop.state.queue.aliasAction = "stale action"
    boop.state.queue.aliasDirty = true

    assert.is_true(boop.wire.executeAction(
      "command hound at 900",
      "900",
      false
    ))

    assert.are.equal(2, #send_stub.calls)
    assert.are.equal(
      "setalias BOOP_ATTACK assist Leader/command hound at 900",
      send_stub.calls[1].vals[1]
    )
    assert.is_false(send_stub.calls[1].vals[2])
    assert.are.equal(
      "queue addclearfull freestand BOOP_ATTACK",
      send_stub.calls[2].vals[1]
    )
    assert.is_false(send_stub.calls[2].vals[2])
    assert.stub(record_binding_stub).was_called_with(
      "assist Leader/command hound at 900",
      false
    )
    assert.are.equal(
      "assist Leader/command hound at 900",
      boop.state.queue.aliasAction
    )
    assert.is_false(boop.state.queue.aliasDirty)
    assert.are.equal("900", begin_stub.calls[1].vals[1].targetId)
    assert.are.equal("42", boop.state.targeting.currentTargetId)

    send_stub:clear()
    record_binding_stub:clear()
    assert.is_true(boop.wire.executeAction(
      "command hound at 900",
      "900",
      false
    ))
    assert.are.equal(1, #send_stub.calls)
    assert.are.equal(
      "queue addclearfull freestand BOOP_ATTACK",
      send_stub.calls[1].vals[1]
    )
    assert.stub(record_binding_stub).was_not_called()
    assert.are.equal(
      "assist Leader/command hound at 900",
      boop.state.queue.aliasAction
    )
    assert.is_false(boop.state.queue.aliasDirty)

    boop.runtime.markStandardAliasDirty()
    send_stub:clear()
    record_binding_stub:clear()
    assert.is_true(boop.wire.executeAction(
      "command hound at 900",
      "900",
      false
    ))
    assert.are.equal(2, #send_stub.calls)
    assert.are.equal(
      "setalias BOOP_ATTACK assist Leader/command hound at 900",
      send_stub.calls[1].vals[1]
    )
    assert.are.equal(
      "queue addclearfull freestand BOOP_ATTACK",
      send_stub.calls[2].vals[1]
    )
    assert.stub(record_binding_stub).was_called_with(
      "assist Leader/command hound at 900",
      false
    )
    assert.is_false(boop.state.queue.aliasDirty)
  end)

  it("keeps direct transport separate from queued alias binding", function()
    boop.state.queue.aliasAction = "retained queued action"
    boop.state.queue.aliasDirty = false

    assert.is_true(boop.wire.executeAction(
      "jab 900/kick 900",
      "900",
      false
    ))

    assert.are.equal(2, #send_stub.calls)
    assert.are.equal("jab 900", send_stub.calls[1].vals[1])
    assert.are.equal("kick 900", send_stub.calls[2].vals[1])
    assert.stub(record_binding_stub).was_not_called()
    assert.are.equal("retained queued action", boop.state.queue.aliasAction)
    assert.is_false(boop.state.queue.aliasDirty)
  end)

  it("owns the game command separator outside list persistence", function()
    assert.are.equal("/", boop.wire.separator)
    assert.is_nil(boop.lists.separator)
  end)
end)
