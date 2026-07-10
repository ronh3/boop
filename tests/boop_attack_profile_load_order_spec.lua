local helper = dofile(os.getenv("TESTS_DIRECTORY") .. "/support/boop_test_helper.lua")

describe("boop attack profile load order", function()
  local savedRegistry
  local savedPending

  before_each(function()
    helper.reset()
    helper.setTarget("42", "a test denizen", "80%")
    savedRegistry = nil
    savedPending = nil
  end)

  after_each(function()
    if savedRegistry then
      boop.attacks.registry = savedRegistry
      boop.attacks.pendingRegistry = savedPending
    end
  end)

  it("drains profiles queued before the real attack registry is loaded", function()
    savedRegistry = boop.attacks.registry
    savedPending = boop.attacks.pendingRegistry

    boop.attacks.registry = {}
    boop.attacks.pendingRegistry = {
      {
        class = "Load Order Test",
        profile = {
          standard = {
            dam = { cmd = "poke &tar" },
          },
        },
      },
    }

    boop.attacks.flushPendingProfiles()
    helper.setClass("Load Order Test")

    local actions = boop.attacks.choose()

    assert.are.equal("poke 42", actions.standard)
    assert.are.equal("", actions.rage)
  end)
end)
