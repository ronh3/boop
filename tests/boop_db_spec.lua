local helper = dofile(os.getenv("TESTS_DIRECTORY") .. "/support/boop_test_helper.lua")

describe("boop db guards", function()
  local ensure_stub
  local warn_stub
  local warnings
  local saved_db

  before_each(function()
    helper.reset()
    saved_db = _G.db
    warnings = {}
    ensure_stub = stub(boop.db, "ensureMobXpTable", function()
      return true, nil
    end)
    warn_stub = stub(boop.util, "warn", function(msg)
      warnings[#warnings + 1] = msg
    end)
  end)

  after_each(function()
    _G.db = saved_db
    if ensure_stub then
      ensure_stub:revert()
      ensure_stub = nil
    end
    if warn_stub then
      warn_stub:revert()
      warn_stub = nil
    end
  end)

  it("warns instead of throwing when the mob xp sheet is unavailable during clear", function()
    boop.db.handle = setmetatable({}, {
      __index = function(_, key)
        if key == "mob_xp_v2" then
          error("Attempt to access sheet 'mob_xp_v2'in db 'boop' that does not exist.")
        end
        return nil
      end,
    })

    assert.has_no.errors(function()
      boop.db.clearMobXpStats()
    end)
    assert.is_true(#warnings > 0)
    assert.is_true(warnings[1]:find("cannot access mob xp sheet for clear", 1, true) ~= nil)
  end)

  it("returns stats data without mutating the Stats owner", function()
    local statsSheet = { name = "name" }
    local mobSheet = {
      area = "area",
      party_size = "party_size",
      name = "name",
      xp = "xp",
    }
    _G.db = {
      fetch = function(_, sheet)
        if sheet == statsSheet then
          return {
            { name = "lifetime_gold", value = "123" },
            { name = "lifetime_kills", value = "7" },
          }
        end
        if sheet == mobSheet then
          return {
            { area = "Test Area", party_size = 2, name = "a mob", xp = 45, count = 3 },
          }
        end
        return {}
      end,
    }
    boop.db.handle = { stats = statsSheet, mob_xp_v2 = mobSheet }
    boop.stats.lifetime = { sentinel = true }
    boop.stats.mobXp = { untouched = true }

    local loaded = boop.db.loadStats()

    assert.are.equal(123, loaded.lifetime.gold)
    assert.are.equal(7, loaded.lifetime.kills)
    assert.are.equal(3, loaded.mobXp["Test Area"][2]["a mob"].observations)
    assert.is_true(boop.stats.lifetime.sentinel)
    assert.is_true(boop.stats.mobXp.untouched)
  end)

  it("persists only the supplied Stats payload", function()
    local statsSheet = { name = "name" }
    local saved = {}
    _G.db = {
      eq = function(_, _, value) return value end,
      fetch = function() return {} end,
      add = function(_, _, row) saved[row.name] = row.value end,
      update = function(_, _, row) saved[row.name] = row.value end,
    }
    boop.db.handle = { stats = statsSheet }
    boop.stats.lifetime = { gold = 999, kills = 999 }

    assert.is_true(boop.db.saveStats({
      lifetime = {
        gold = 12,
        experience = 34,
        activeSeconds = 56,
        kills = 2,
      },
      mobXp = {},
    }))

    assert.are.equal("12", saved.lifetime_gold)
    assert.are.equal("34", saved.lifetime_experience)
    assert.are.equal("56", saved.lifetime_active_seconds)
    assert.are.equal("2", saved.lifetime_kills)
  end)

  it("returns list data without mutating the Targets owner", function()
    local whitelist = { area = "area", pos = "pos" }
    local blacklist = { area = "area", pos = "pos" }
    local tags = { area = "area", pos = "pos" }
    _G.db = {
      fetch = function(_, sheet)
        if sheet == whitelist then
          return { { area = "Test Area", pos = 1, name = "a friendly mob" } }
        end
        if sheet == blacklist then
          return {
            { area = "GLOBAL", pos = 1, name = "a forbidden mob" },
            { area = "Test Area", pos = 1, name = "a hostile mob" },
          }
        end
        if sheet == tags then
          return { { area = "Test Area", pos = 1, tag = "daily" } }
        end
        return {}
      end,
    }
    boop.db.handle = {
      whitelist = whitelist,
      blacklist = blacklist,
      whitelist_tags = tags,
    }
    boop.lists = { sentinel = true }

    local loaded = boop.db.loadLists()

    assert.are.same({ "a friendly mob" }, loaded.whitelist["Test Area"])
    assert.are.same({ "a hostile mob" }, loaded.blacklist["Test Area"])
    assert.are.same({ "a forbidden mob" }, loaded.globalBlacklist)
    assert.are.same({ "daily" }, loaded.whitelistTags["Test Area"])
    assert.is_true(boop.lists.sentinel)
  end)

  it("lets feature owners apply returned persistence data", function()
    local lists = {
      whitelist = { ["Test Area"] = { "one" } },
      blacklist = {},
      globalBlacklist = { "two" },
      whitelistTags = { ["Test Area"] = { "tag" } },
    }
    local stats = {
      lifetime = { gold = 88, kills = 4 },
      mobXp = { area = {} },
    }

    boop.targets.applyPersistedLists(lists)
    boop.stats.applyPersistedData(stats)

    assert.are.equal("one", boop.lists.whitelist["Test Area"][1])
    assert.are.equal("two", boop.lists.globalBlacklist[1])
    assert.are.equal(88, boop.stats.lifetime.gold)
    assert.are.equal(4, boop.stats.lifetime.kills)
    assert.are.equal(stats.mobXp, boop.stats.mobXp)
  end)
end)
