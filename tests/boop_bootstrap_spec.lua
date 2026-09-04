local helper = dofile(os.getenv("TESTS_DIRECTORY") .. "/support/boop_test_helper.lua")

describe("boop bootstrap composition", function()
  local stubs

  before_each(function()
    helper.reset()
    stubs = {}
  end)

  after_each(function()
    for index = #stubs, 1, -1 do
      stubs[index]:revert()
    end
  end)

  it("runs the production initialization sequence and attaches Registry once", function()
    local calls = {}
    local function replace(owner, name, label, result)
      local replacement = stub(owner, name, function(...)
        calls[#calls + 1] = { label = label, args = { ... } }
        if type(result) == "function" then
          return result(...)
        end
        return result
      end)
      stubs[#stubs + 1] = replacement
    end

    replace(boop, "requestCoreSupports", "supports", true)
    replace(boop.db, "init", "db", {
      lists = { whitelist = {}, blacklist = {}, globalBlacklist = {}, whitelistTags = {} },
      stats = { lifetime = { gold = 9 }, mobXp = {} },
    })
    replace(boop.targets, "applyPersistedLists", "lists", true)
    replace(boop.stats, "applyPersistedData", "stats-data", true)
    replace(boop.runtime, "ensureState", "state", boop.state)
    replace(boop.afflictions, "init", "afflictions", true)
    replace(boop.rage, "init", "rage", true)
    replace(boop.ih, "init", "ih", true)
    replace(boop.triggers, "setIreSupportReconciler", "trigger-wire", true)
    replace(boop.triggers, "syncEnabled", "triggers", true)
    replace(boop.skills, "init", "skills", true)
    replace(boop.skills, "setDesiredGroups", "skill-groups", true)
    replace(boop.stats, "init", "stats", true)
    replace(boop.events, "register", "events", true)
    replace(boop.ui, "registerRegistryHandlers", "registry-handlers", true)
    replace(boop.registry, "attachUiConfigRegistries", "registry-attach", true)
    replace(boop.skills, "requestAll", "skill-request", true)
    replace(boop.ui, "status", "ready", true)

    boop.bootstrapped = false
    assert.is_true(boop.bootstrap())

    local labels = {}
    for _, call in ipairs(calls) do
      labels[#labels + 1] = call.label
    end
    assert.are.same({
      "supports",
      "db",
      "lists",
      "stats-data",
      "state",
      "afflictions",
      "rage",
      "ih",
      "trigger-wire",
      "triggers",
      "skills",
      "skill-groups",
      "stats",
      "events",
      "registry-handlers",
      "registry-attach",
      "skill-request",
      "ready",
    }, labels)

    local attachmentCount = 0
    for _, label in ipairs(labels) do
      if label == "registry-attach" then
        attachmentCount = attachmentCount + 1
      end
    end
    assert.are.equal(1, attachmentCount)
    assert.are.equal("ready", calls[#calls].args[1])
    assert.are.equal("Artificing", calls[12].args[1][1])
    assert.are.equal("Attainment", calls[12].args[1][6])

    calls = {}
    assert.is_false(boop.bootstrap())
    labels = {}
    for _, call in ipairs(calls) do
      labels[#labels + 1] = call.label
    end
    assert.are.same({
      "trigger-wire",
      "registry-handlers",
      "registry-attach",
    }, labels)
  end)
end)
