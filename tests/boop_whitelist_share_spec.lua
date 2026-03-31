local helper = dofile(os.getenv("TESTS_DIRECTORY") .. "/support/boop_test_helper.lua")

describe("boop whitelist sharing", function()
  before_each(function()
    helper.reset()
    helper.setArea("Test Area")
  end)

  it("shares the current area's whitelist as party packets", function()
    helper.setWhitelist("Test Area", { "goblin", "orc", "troll" })

    local sent = {}
    local send_stub = stub(_G, "send", function(command, echoBack)
      sent[#sent + 1] = { command = command, echoBack = echoBack }
    end)

    local ok = boop.targets.shareWhitelist("")

    send_stub:revert()

    assert.is_true(ok)
    assert.are.equal(3, #sent)
    assert.are.equal(1, sent[1].command:find("pt BOOPWL|S|1|", 1, true))
    assert.is_not_nil(sent[1].command:match("|Test%%20Area|3$"))
    local token = sent[1].command:match("^pt BOOPWL|S|1|([^|]+)|")
    assert.are.equal("pt BOOPWL|D|1|" .. token .. "|goblin|orc|troll", sent[2].command)
    assert.are.equal("pt BOOPWL|E|1|" .. token, sent[3].command)
    assert.is_false(sent[1].echoBack)
  end)

  it("merges incoming whitelist entries without disturbing local order", function()
    helper.setWhitelist("Test Area", { "troll", "rat", "goblin" })

    boop.targets.onPartyWhitelistShare("Leader", "BOOPWL|S|1|tok1|Test%20Area|3", "")
    boop.targets.onPartyWhitelistShare("Leader", "BOOPWL|D|1|tok1|goblin|orc|troll", "")
    boop.targets.onPartyWhitelistShare("Leader", "BOOPWL|E|1|tok1", "")

    local ok = boop.targets.receiveWhitelistShare("merge")

    assert.is_true(ok)
    assert.are.same({ "troll", "rat", "goblin", "orc" }, boop.lists.whitelist["Test Area"])
  end)

  it("reorders shared entries, adds missing ones, and keeps local extras at the bottom", function()
    helper.setWhitelist("Test Area", { "troll", "rat", "goblin" })

    boop.targets.onPartyWhitelistShare("Leader", "BOOPWL|S|1|tok2|Test%20Area|3", "")
    boop.targets.onPartyWhitelistShare("Leader", "BOOPWL|D|1|tok2|goblin|orc|troll", "")
    boop.targets.onPartyWhitelistShare("Leader", "BOOPWL|E|1|tok2", "")

    local ok = boop.targets.receiveWhitelistShare("merge-reorder")

    assert.is_true(ok)
    assert.are.same({ "goblin", "troll", "orc", "rat" }, boop.lists.whitelist["Test Area"])
  end)

  it("overwrites the area's whitelist when requested", function()
    helper.setWhitelist("Test Area", { "rat", "goblin" })

    boop.targets.onPartyWhitelistShare("Leader", "BOOPWL|S|1|tok3|Test%20Area|2", "")
    boop.targets.onPartyWhitelistShare("Leader", "BOOPWL|D|1|tok3|orc|troll", "")
    boop.targets.onPartyWhitelistShare("Leader", "BOOPWL|E|1|tok3", "")

    local ok = boop.targets.receiveWhitelistShare("overwrite")

    assert.is_true(ok)
    assert.are.same({ "orc", "troll" }, boop.lists.whitelist["Test Area"])
  end)
end)
