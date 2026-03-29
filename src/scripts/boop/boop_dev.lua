_G.BoopLiveUpdate = _G.BoopLiveUpdate or {}

local helper = _G.BoopLiveUpdate
local PROJECT_NAME = "boop"
local HELPER_NAME = "BoopMuddlerHelper"
local ENABLED_KEY = "devHelperEnabled"
local PATH_KEY = "devHelperPath"

boop.dev = helper

local function trim(value)
  if _G.boop and _G.boop.util and _G.boop.util.trim then
    return _G.boop.util.trim(value or "")
  end
  return tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function emit(level, message)
  local prefix = "dev helper: " .. tostring(message)
  if _G.boop and _G.boop.util and type(_G.boop.util[level]) == "function" then
    _G.boop.util[level](prefix)
    return
  end

  local fallback = string.format("[%s] %s", PROJECT_NAME, prefix)
  if cecho then
    cecho(fallback .. "\n")
  elseif debugc then
    debugc(fallback)
  end
end

local function logInfo(message)
  emit("info", message)
end

local function logOk(message)
  emit("ok", message)
end

local function logWarn(message)
  emit("warn", message)
end

local function fileExists(path)
  local handle = io.open(path, "r")
  if handle then
    handle:close()
    return true
  end
  return false
end

local function saveConfigValue(key, value)
  if not _G.boop then
    return
  end

  _G.boop.config = _G.boop.config or {}
  _G.boop.config[key] = value
  if _G.boop.db and _G.boop.db.saveConfig then
    _G.boop.db.saveConfig(key, value)
  end
end

local function helperInstance()
  return _G[HELPER_NAME]
end

local function setHelperInstance(instance)
  _G[HELPER_NAME] = instance
  helper.instance = instance
end

local function configuredPath()
  if not _G.boop or not _G.boop.config then
    return ""
  end
  return trim(_G.boop.config[PATH_KEY] or "")
end

local function clearPackageLoaded()
  for pkgName in pairs(package.loaded) do
    if tostring(pkgName):lower():find("boop", 1, true) then
      package.loaded[pkgName] = nil
    end
  end
end

function helper.isAvailable()
  return type(Muddler) == "table" and type(Muddler.new) == "function"
end

function helper.cleanup()
  clearPackageLoaded()
  _G.boop = nil
  collectgarbage("collect")
  logInfo("cleared cached globals after package removal")
end

function helper.stopWatcher(quiet)
  local instance = helperInstance()
  if instance and type(instance.stop) == "function" then
    instance:stop()
  end
  setHelperInstance(nil)
  if not quiet then
    logInfo("stopped local build watcher")
  end
end

function helper.createWatcher(opts)
  opts = opts or {}

  if not helper.isAvailable() then
    if not opts.quiet then
      logWarn("Muddler.mpackage is not installed or not loaded yet")
    end
    return nil
  end

  local path = configuredPath()
  if path == "" then
    if not opts.quiet then
      logWarn("repo path is not set; use: boop dev path <repo-root>")
    end
    return nil
  end

  if not fileExists(path .. "/mfile") then
    if not opts.quiet then
      logWarn("project path does not look valid: " .. path)
    end
    return nil
  end

  helper.stopWatcher(true)

  local instance = Muddler:new({
    path = path,
    postremove = helper.cleanup,
    postinstall = function()
      logOk("installed newest local build")
    end,
  })

  setHelperInstance(instance)
  if not opts.quiet then
    logOk("watching " .. path .. " for new local builds")
  end
  return instance
end

function helper.startConfiguredWatcher(opts)
  opts = opts or {}
  if not (_G.boop and _G.boop.config and _G.boop.config[ENABLED_KEY]) then
    return nil
  end
  return helper.createWatcher(opts)
end

function helper.status()
  local instance = helperInstance()
  return {
    enabled = not not (_G.boop and _G.boop.config and _G.boop.config[ENABLED_KEY]),
    available = helper.isAvailable(),
    active = instance ~= nil,
    path = configuredPath(),
    watching = not not (instance and instance.watch),
  }
end

local function showStatus()
  local status = helper.status()
  logInfo(status.enabled and "enabled" or "off")
  logInfo("muddler: " .. (status.available and "available" or "missing"))
  logInfo("watcher: " .. (status.active and (status.watching and "watching" or "created") or "inactive"))
  logInfo("path: " .. (status.path ~= "" and status.path or "(unset)"))
  emit("info", "Usage: boop dev [status|path <repo-root>|on|off|restart]")
end

function helper.command(raw)
  local text = trim(raw)
  local cmd, tail = text:match("^(%S+)%s*(.-)%s*$")
  if _G.boop and _G.boop.util and _G.boop.util.safeLower then
    cmd = _G.boop.util.safeLower(cmd or "")
  else
    cmd = tostring(cmd or ""):lower()
  end
  tail = trim(tail)

  if cmd == "" or cmd == "status" or cmd == "show" or cmd == "help" then
    showStatus()
    return
  end

  if cmd == "path" then
    if tail == "" then
      logInfo("path: " .. (configuredPath() ~= "" and configuredPath() or "(unset)"))
      emit("info", "Usage: boop dev path <repo-root>")
      return
    end
    saveConfigValue(PATH_KEY, tail)
    logOk("path: " .. tail)
    if _G.boop and _G.boop.config and _G.boop.config[ENABLED_KEY] then
      helper.createWatcher()
    end
    return
  end

  if cmd == "on" or cmd == "enable" or cmd == "start" then
    saveConfigValue(ENABLED_KEY, true)
    if configuredPath() == "" then
      logWarn("repo path is not set; use: boop dev path <repo-root>")
      return
    end
    helper.createWatcher()
    return
  end

  if cmd == "off" or cmd == "disable" or cmd == "stop" then
    saveConfigValue(ENABLED_KEY, false)
    helper.stopWatcher()
    return
  end

  if cmd == "restart" or cmd == "reload" then
    if not (_G.boop and _G.boop.config and _G.boop.config[ENABLED_KEY]) then
      logWarn("helper is off; use: boop dev on")
      return
    end
    helper.createWatcher()
    return
  end

  emit("warn", "Usage: boop dev [status|path <repo-root>|on|off|restart]")
end

if not helper._loadHandler and type(registerAnonymousEventHandler) == "function" then
  helper._loadHandler = registerAnonymousEventHandler("sysLoadEvent", function()
    if _G.BoopLiveUpdate and _G.BoopLiveUpdate.startConfiguredWatcher then
      _G.BoopLiveUpdate.startConfiguredWatcher({ quiet = true })
    end
  end)
end
