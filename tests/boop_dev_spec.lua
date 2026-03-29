local helper = dofile(os.getenv("TESTS_DIRECTORY") .. "/support/boop_test_helper.lua")

local function repoRoot()
  return assert(os.getenv("TESTS_DIRECTORY")):gsub("/tests$", "")
end

describe("boop dev helper", function()
  local saved_muddler
  local ok_stub
  local info_stub
  local warn_stub
  local save_config_stub
  local saved_configs
  local created_opts
  local stop_count

  before_each(function()
    helper.reset()

    saved_muddler = _G.Muddler
    _G.BoopMuddlerHelper = nil

    saved_configs = {}
    created_opts = nil
    stop_count = 0

    save_config_stub = stub(boop.db, "saveConfig", function(key, value)
      saved_configs[#saved_configs + 1] = { key = key, value = value }
    end)
    ok_stub = stub(boop.util, "ok", function(_) end)
    info_stub = stub(boop.util, "info", function(_) end)
    warn_stub = stub(boop.util, "warn", function(_) end)

    _G.Muddler = {
      new = function(_, opts)
        created_opts = opts
        return {
          watch = true,
          stop = function(self)
            stop_count = stop_count + 1
            self.watch = false
          end,
        }
      end,
    }
  end)

  after_each(function()
    _G.Muddler = saved_muddler
    _G.BoopMuddlerHelper = nil

    if save_config_stub then
      save_config_stub:revert()
      save_config_stub = nil
    end
    if ok_stub then
      ok_stub:revert()
      ok_stub = nil
    end
    if info_stub then
      info_stub:revert()
      info_stub = nil
    end
    if warn_stub then
      warn_stub:revert()
      warn_stub = nil
    end
  end)

  it("stores helper state on a durable host table", function()
    assert.are.equal(_G.BoopLiveUpdate, boop.dev)
    assert.is_function(boop.dev.command)
  end)

  it("starts a watcher from the configured repo root", function()
    boop.dev.command("path " .. repoRoot())
    boop.dev.command("on")

    assert.is_true(boop.config.devHelperEnabled)
    assert.are.equal(repoRoot(), boop.config.devHelperPath)
    assert.are.equal(repoRoot(), created_opts.path)
    assert.are.equal(boop.dev.cleanup, created_opts.postremove)
    assert.is_not_nil(_G.BoopMuddlerHelper)
    assert.are.same({ key = "devHelperPath", value = repoRoot() }, saved_configs[1])
    assert.are.same({ key = "devHelperEnabled", value = true }, saved_configs[2])
  end)

  it("restarts the watcher when the path changes while enabled", function()
    boop.config.devHelperEnabled = true
    _G.BoopMuddlerHelper = {
      watch = true,
      stop = function(self)
        stop_count = stop_count + 1
        self.watch = false
      end,
    }

    boop.dev.command("path " .. repoRoot())

    assert.are.equal(1, stop_count)
    assert.are.equal(repoRoot(), created_opts.path)
  end)

  it("stops the watcher and disables the helper", function()
    boop.config.devHelperEnabled = true
    _G.BoopMuddlerHelper = {
      watch = true,
      stop = function(self)
        stop_count = stop_count + 1
        self.watch = false
      end,
    }

    boop.dev.command("off")

    assert.is_false(boop.config.devHelperEnabled)
    assert.are.equal(1, stop_count)
    assert.is_nil(_G.BoopMuddlerHelper)
    assert.are.same({ key = "devHelperEnabled", value = false }, saved_configs[1])
  end)

  it("warns when enabling without a configured path", function()
    boop.dev.command("on")

    assert.is_true(boop.config.devHelperEnabled)
    assert.is_nil(created_opts)
    assert.stub(warn_stub).was_called_with("dev helper: repo path is not set; use: boop dev path <repo-root>")
  end)
end)
