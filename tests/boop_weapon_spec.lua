local helper = dofile(os.getenv("TESTS_DIRECTORY") .. "/support/boop_test_helper.lua")

describe("boop weapon designations", function()
  local ok_stub
  local warn_stub
  local info_stub
  local echo_stub
  local saved
  local deleted
  local echoes

  before_each(function()
    helper.reset()
    helper.setClass("Depthswalker")
    echoes = {}
    saved = {}
    deleted = {}
    ok_stub = stub(boop.util, "ok", function(msg) echoes[#echoes + 1] = "[OK] " .. msg end)
    warn_stub = stub(boop.util, "warn", function(msg) echoes[#echoes + 1] = "[WARN] " .. msg end)
    info_stub = stub(boop.util, "info", function(msg) echoes[#echoes + 1] = "[INFO] " .. msg end)
    echo_stub = stub(boop.util, "echo", function(msg) echoes[#echoes + 1] = msg end)
    boop.db.saveConfig = function(key, value) saved[#saved + 1] = { key = key, value = value } end
    boop.db.deleteConfig = function(key) deleted[#deleted + 1] = key end
  end)

  after_each(function()
    if ok_stub then ok_stub:revert() ok_stub = nil end
    if warn_stub then warn_stub:revert() warn_stub = nil end
    if info_stub then info_stub:revert() info_stub = nil end
    if echo_stub then echo_stub:revert() echo_stub = nil end
  end)

  it("saves a weapon designation for the current class", function()
    boop.ui.weaponCommand("scythe 47177")

    local key = boop.attacks.weaponConfigKey("depthswalker", "scythe")
    assert.are.equal("47177", boop.config[key])
    assert.are.same({ key = key, value = "47177" }, saved[1])
  end)

  it("clears a saved weapon designation", function()
    local key = boop.attacks.weaponConfigKey("depthswalker", "dagger")
    boop.config[key] = "12345"

    boop.ui.weaponCommand("clear dagger")

    assert.is_nil(boop.config[key])
    assert.are.equal(key, deleted[1])
  end)
end)
