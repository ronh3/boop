local helper = dofile(os.getenv("TESTS_DIRECTORY") .. "/support/boop_test_helper.lua")

describe("boop db guards", function()
  local ensure_stub
  local warn_stub
  local warnings

  before_each(function()
    helper.reset()
    warnings = {}
    ensure_stub = stub(boop.db, "ensureMobXpTable", function()
      return true, nil
    end)
    warn_stub = stub(boop.util, "warn", function(msg)
      warnings[#warnings + 1] = msg
    end)
  end)

  after_each(function()
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
end)
