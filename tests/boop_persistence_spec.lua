local helper = dofile(os.getenv("TESTS_DIRECTORY") .. "/support/boop_test_helper.lua")

describe("boop config and list persistence paths", function()
  local save_config_stub
  local delete_config_stub
  local save_list_stub
  local save_tags_stub
  local ok_stub
  local warn_stub
  local kill_timer_stub
  local saved_configs
  local saved_lists
  local saved_tags

  before_each(function()
    helper.reset()
    saved_configs = {}
    saved_lists = {}
    saved_tags = {}

    save_config_stub = stub(boop.db, "saveConfig", function(key, value)
      saved_configs[#saved_configs + 1] = { key = key, value = value }
    end)
    delete_config_stub = stub(boop.db, "deleteConfig", function(key)
      saved_configs[#saved_configs + 1] = { delete = key }
    end)
    save_list_stub = stub(boop.db, "saveList", function(kind, area, list)
      local copy = {}
      for i, name in ipairs(list or {}) do
        copy[i] = name
      end
      saved_lists[#saved_lists + 1] = { kind = kind, area = area, list = copy }
    end)
    save_tags_stub = stub(boop.db, "saveWhitelistTags", function(area, tags)
      local copy = {}
      for i, tag in ipairs(tags or {}) do
        copy[i] = tag
      end
      saved_tags[#saved_tags + 1] = { area = area, tags = copy }
    end)
    ok_stub = stub(boop.util, "ok", function(_) end)
    warn_stub = stub(boop.util, "warn", function(_) end)
    kill_timer_stub = stub(_G, "killTimer", function(_) end)
  end)

  after_each(function()
    if save_config_stub then
      save_config_stub:revert()
      save_config_stub = nil
    end
    if delete_config_stub then
      delete_config_stub:revert()
      delete_config_stub = nil
    end
    if save_list_stub then
      save_list_stub:revert()
      save_list_stub = nil
    end
    if save_tags_stub then
      save_tags_stub:revert()
      save_tags_stub = nil
    end
    if ok_stub then
      ok_stub:revert()
      ok_stub = nil
    end
    if warn_stub then
      warn_stub:revert()
      warn_stub = nil
    end
    if kill_timer_stub then
      kill_timer_stub:revert()
      kill_timer_stub = nil
    end
  end)

  it("persists canonicalized targeting, target-call gating, gold-pack, and rage aff callout edits, but keeps party size session-local", function()
    boop.config.assistLeader = "Person"
    boop.ui.setTargetingMode("wl", true)
    boop.ui.targetCallCommand("on")
    boop.ui.setGoldPack("pack")
    boop.ui.affCallCommand("off")
    boop.ui.setConfigValue("partySize", "3")

    assert.are.equal("whitelist", boop.config.targetingMode)
    assert.is_true(boop.config.targetCall)
    assert.are.equal("pack", boop.config.goldPack)
    assert.is_false(boop.config.rageAffCalloutsEnabled)
    assert.are.equal(3, boop.config.partySize)
    assert.are.same({ key = "targetingMode", value = "whitelist" }, saved_configs[1])
    assert.are.same({ key = "targetCall", value = true }, saved_configs[2])
    assert.are.same({ key = "goldPack", value = "pack" }, saved_configs[3])
    assert.are.same({ key = "rageAffCalloutsEnabled", value = false }, saved_configs[4])
    assert.are.same({ delete = "partySize" }, saved_configs[5])
    assert.stub(save_config_stub).was_not.called_with("partySize", 3)
  end)

  it("resets party size to the default on a fresh load", function()
    boop.config.partySize = 4

    helper.reset()

    assert.are.equal(1, boop.config.partySize)
  end)

  it("persists disabling boop and clears the outstanding prequeue timer", function()
    boop.state.prequeueTimer = 41
    boop.state.prequeuedStandard = true

    boop.ui.setEnabled(false, true)

    assert.is_false(boop.config.enabled)
    assert.is_nil(boop.state.prequeueTimer)
    assert.is_false(boop.state.prequeuedStandard)
    assert.stub(kill_timer_stub).was_called_with(41)
    assert.are.same({ key = "enabled", value = false }, saved_configs[1])
  end)

  it("persists whitelist add, remove, and reorder edits", function()
    helper.setArea("Test Area")

    assert.is_true(boop.targets.addWhitelist(nil, "orc"))
    assert.is_true(boop.targets.addWhitelist(nil, "goblin"))
    assert.is_true(boop.targets.shiftWhitelist("Test Area", 2, "up"))
    assert.is_true(boop.targets.removeWhitelist("Test Area", "orc"))

    assert.are.same({ "goblin" }, boop.lists.whitelist["Test Area"])
    assert.are.equal("whitelist", saved_lists[#saved_lists].kind)
    assert.are.equal("Test Area", saved_lists[#saved_lists].area)
    assert.are.same({ "goblin" }, saved_lists[#saved_lists].list)
  end)

  it("persists blacklist edits through the public target commands", function()
    helper.setArea("Test Area")

    assert.is_true(boop.targets.addBlacklist(nil, "rat"))
    assert.is_true(boop.targets.addBlacklist(nil, "snake"))
    assert.is_true(boop.targets.shiftBlacklist("Test Area", 2, "up"))
    assert.is_true(boop.targets.removeBlacklist("Test Area", "rat"))

    assert.are.same({ "snake" }, boop.lists.blacklist["Test Area"])
    assert.are.equal("blacklist", saved_lists[#saved_lists].kind)
    assert.are.equal("Test Area", saved_lists[#saved_lists].area)
    assert.are.same({ "snake" }, saved_lists[#saved_lists].list)
  end)

  it("persists global blacklist edits through the public target commands", function()
    assert.is_true(boop.targets.addBlacklist("GLOBAL", "rat"))
    assert.is_true(boop.targets.addBlacklist("GLOBAL", "snake"))
    assert.is_true(boop.targets.shiftBlacklist("GLOBAL", 2, "up"))
    assert.is_true(boop.targets.removeBlacklist("GLOBAL", "rat"))

    assert.are.same({ "snake" }, boop.lists.globalBlacklist)
    assert.are.equal("blacklist", saved_lists[#saved_lists].kind)
    assert.are.equal("GLOBAL", saved_lists[#saved_lists].area)
    assert.are.same({ "snake" }, saved_lists[#saved_lists].list)
  end)

  it("persists sorted deduplicated whitelist tag edits", function()
    helper.setWhitelist("Test Area", { "orc" })

    boop.targets.addWhitelistTags("Test Area", "undead, boss, undead")

    assert.are.same({ "boss", "undead" }, boop.lists.whitelistTags["Test Area"])
    assert.are.same({ area = "Test Area", tags = { "boss", "undead" } }, saved_tags[#saved_tags])

    boop.targets.removeWhitelistTags("Test Area", "boss")

    assert.are.same({ "undead" }, boop.lists.whitelistTags["Test Area"])
    assert.are.same({ area = "Test Area", tags = { "undead" } }, saved_tags[#saved_tags])
  end)
end)
