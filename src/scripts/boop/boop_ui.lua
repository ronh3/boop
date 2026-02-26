boop.ui = boop.ui or {}

local function saveConfigValue(key, value)
  boop.config[key] = value
  if boop.db and boop.db.saveConfig then
    boop.db.saveConfig(key, boop.config[key])
  end
end

local function boolText(value)
  return value and "ON" or "OFF"
end

local function boolColor(value)
  return value and "green" or "red"
end

local function currentClass()
  return boop.state.class or (gmcp and gmcp.Char and gmcp.Char.Status and gmcp.Char.Status.class) or "unknown"
end

local UI_RULE_WIDTH = 56
local UI_LABEL_COL_WIDTH = 40
local UI_BUTTON_INNER_WIDTH = 10

local function uiPadRight(text, width)
  text = tostring(text or "")
  if #text >= width then
    return text:sub(1, width)
  end
  return text .. string.rep(" ", width - #text)
end

local function uiRule()
  return string.rep("-", UI_RULE_WIDTH)
end

local function uiButtonLabel(value)
  return "[ " .. uiPadRight(value or "", UI_BUTTON_INNER_WIDTH) .. " ]"
end

local function uiSetCommandLine(prefix)
  if not appendCmdLine then return end
  if clearCmdLine then clearCmdLine() end
  appendCmdLine(prefix or "")
end

function boop.ui.statusLine(context)
  local enabled = boop.config.enabled and "on" or "off"
  local mode = boop.config.targetingMode or "unknown"
  local class = currentClass()
  local msg = string.format("%s | class: %s | targeting: %s | flee: %s", enabled, class, mode, tostring(boop.config.fleeAt))
  if context then
    msg = context .. " | " .. msg
  end
  return msg
end

function boop.ui.status(context)
  local msg = boop.ui.statusLine(context)
  boop.util.echo(msg)
end

local function uiPrintHeader(title)
  if cecho then
    cecho("\n<white>" .. string.upper(tostring(title or "")) .. "<reset>")
    cecho("\n<grey>" .. uiRule() .. "<reset>")
  else
    boop.util.echo(tostring(title) .. " | class: " .. tostring(currentClass()))
  end
end

local function uiPrintSection(title)
  if cecho then
    cecho("\n\n<cyan>" .. string.upper(tostring(title or "")) .. "<reset>")
  else
    boop.util.echo(tostring(title) .. ":")
  end
end

local function uiPrintRow(index, label, buttonText, buttonColor, onClick, hint)
  if cecho then
    local prefix = ""
    if index then
      prefix = string.format("[%d] ", tonumber(index) or 0)
    end
    local left = uiPadRight(prefix .. tostring(label or ""), UI_LABEL_COL_WIDTH)
    cecho("\n<white>" .. left .. "<reset>")
    local coloredButton = "<" .. tostring(buttonColor or "white") .. ">" .. uiButtonLabel(buttonText or "") .. "<reset>"
    if cechoLink and onClick then
      cechoLink(coloredButton, onClick, hint or "", true)
    else
      cecho(coloredButton)
    end
    return
  end

  local prefix = index and ("[" .. tostring(index) .. "] ") or ""
  local row = prefix .. tostring(label or "") .. " " .. uiButtonLabel(buttonText or "")
  boop.util.echo(row)
end

local function uiPrintFooter(text)
  if cecho then
    cecho("\n<grey>" .. uiRule() .. "<reset>")
    cecho("\n<white>" .. tostring(text or "") .. "<reset>")
  else
    boop.util.echo(text or "")
  end
end

local function cycleTargetingMode(step, noRefresh)
  local order = { "manual", "whitelist", "blacklist", "auto" }
  local current = boop.util.safeLower(boop.config.targetingMode or "whitelist")
  local idx = 1
  for i, mode in ipairs(order) do
    if mode == current then
      idx = i
      break
    end
  end
  idx = idx + (tonumber(step) or 1)
  while idx < 1 do idx = idx + #order end
  while idx > #order do idx = idx - #order end
  boop.ui.setTargetingMode(order[idx], true)
  if not noRefresh then
    boop.ui.config()
  end
end

function boop.ui.setEnabled(value, quiet)
  boop.config.enabled = value and true or false
  if not boop.config.enabled then
    if boop.state.prequeueTimer then
      killTimer(boop.state.prequeueTimer)
      boop.state.prequeueTimer = nil
    end
    boop.state.prequeuedStandard = false
  else
    boop.state.queueAliasDirty = true
  end
  if boop.db and boop.db.saveConfig then
    boop.db.saveConfig("enabled", boop.config.enabled)
  end
  if not quiet then
    boop.ui.status("boop")
  end
end

function boop.ui.toggle()
  boop.ui.setEnabled(not boop.config.enabled)
end

function boop.ui.setTargetingMode(mode, quiet)
  mode = boop.util.safeLower(boop.util.trim(mode))
  local valid = { manual = true, whitelist = true, blacklist = true, auto = true }
  if not valid[mode] then
    boop.util.echo("Invalid targeting mode: " .. tostring(mode))
    return
  end
  boop.config.targetingMode = mode
  if boop.db and boop.db.saveConfig then
    boop.db.saveConfig("targetingMode", boop.config.targetingMode)
  end
  if not quiet then
    boop.ui.status("targeting")
  end
end

function boop.ui.setAttackMode(mode)
  mode = boop.util.safeLower(boop.util.trim(mode))
  if mode == "" then return end
  boop.config.attackMode = mode
  if boop.db and boop.db.saveConfig then
    boop.db.saveConfig("attackMode", boop.config.attackMode)
  end
  boop.ui.status("attack")
end

function boop.ui.setRageMode(mode)
  mode = boop.util.safeLower(boop.util.trim(mode))
  if mode == "" then return end
  boop.ui.setAttackMode(mode)
end

function boop.ui.setAutoGrabGold(value)
  saveConfigValue("autoGrabGold", value and true or false)
  boop.util.echo("auto grab gold: " .. (boop.config.autoGrabGold and "on" or "off"))
end

function boop.ui.toggleAutoGrabGold()
  boop.ui.setAutoGrabGold(not boop.config.autoGrabGold)
end

function boop.ui.setPrequeueEnabled(value)
  saveConfigValue("prequeueEnabled", value and true or false)
  if not boop.config.prequeueEnabled then
    if boop.state.prequeueTimer then
      killTimer(boop.state.prequeueTimer)
      boop.state.prequeueTimer = nil
    end
    boop.state.prequeuedStandard = false
  elseif boop.schedulePrequeue then
    boop.schedulePrequeue()
  end
  boop.util.echo("prequeue: " .. (boop.config.prequeueEnabled and "on" or "off"))
end

function boop.ui.showPrequeue()
  local lead = tonumber(boop.config.attackLeadSeconds) or 0
  boop.util.echo(string.format("prequeue: %s | lead: %.2fs", boop.config.prequeueEnabled and "on" or "off", lead))
end

function boop.ui.setAttackLeadSeconds(raw)
  local value = tonumber(boop.util.trim(raw or ""))
  if not value or value < 0 then
    boop.util.echo("Usage: boop lead <seconds> (0 or higher)")
    return
  end
  saveConfigValue("attackLeadSeconds", value)
  if boop.config.prequeueEnabled and boop.schedulePrequeue then
    boop.schedulePrequeue()
  end
  boop.util.echo(string.format("attack lead: %.2fs", value))
end

function boop.ui.setTraceEnabled(value)
  saveConfigValue("traceEnabled", value and true or false)
  boop.util.echo("trace: " .. (boop.config.traceEnabled and "on" or "off"))
end

function boop.ui.setGoldPack(value)
  local pack = boop.util.trim(value or "")
  local key = boop.util.safeLower(pack)
  if key == "off" or key == "none" or key == "clear" then
    pack = ""
  end
  saveConfigValue("goldPack", pack)
  if pack == "" then
    boop.util.echo("gold pack: (off)")
  else
    boop.util.echo("gold pack: " .. pack)
  end
end

function boop.ui.testGoldPack()
  local pack = boop.util.trim(boop.config.goldPack or "")
  if pack == "" then
    boop.util.echo("gold pack: (off) | set one with boop pack <container>")
    return
  end
  send("queue add freestand look in " .. pack, false)
  boop.util.echo("gold pack test queued: look in " .. pack)
end

function boop.ui.showGoldPack()
  local pack = boop.util.trim(boop.config.goldPack or "")
  if pack == "" then
    boop.util.echo("gold pack: (off)")
  else
    boop.util.echo("gold pack: " .. pack)
  end
end

function boop.ui.diag()
  boop.state = boop.state or {}
  if boop.state.prequeueTimer then
    killTimer(boop.state.prequeueTimer)
    boop.state.prequeueTimer = nil
  end
  boop.state.prequeuedStandard = false
  boop.state.diagHold = true
  boop.state.diagAwaitPrompt = false
  boop.state.queueAliasDirty = true

  if boop.state.diagTimeoutTimer then
    killTimer(boop.state.diagTimeoutTimer)
    boop.state.diagTimeoutTimer = nil
  end

  local timeout = tonumber(boop.config.diagTimeoutSeconds) or 8
  if timeout > 0 then
    boop.state.diagTimeoutTimer = tempTimer(timeout, function()
      boop.state.diagTimeoutTimer = nil
      if boop.state.diagHold then
        boop.state.diagHold = false
        boop.state.diagAwaitPrompt = false
        boop.util.echo("diag timeout; attacks resumed")
        boop.trace.log("diag timeout resume")
      end
    end)
  end

  send("queue clear", false)
  send("queue addclearfull freestand diagnose", false)
  boop.util.echo("diag queued; attacks paused until diagnose line + prompt")
  boop.trace.log("diag queued")
end

local function parseBool(raw)
  local value = boop.util.safeLower(boop.util.trim(raw or ""))
  if value == "on" or value == "true" or value == "1" or value == "yes" then return true end
  if value == "off" or value == "false" or value == "0" or value == "no" then return false end
  return nil
end

local function canonConfigKey(raw)
  local key = boop.util.safeLower(boop.util.trim(raw or ""))
  local map = {
    enabled = "enabled",
    targeting = "targetingMode",
    targetingmode = "targetingMode",
    usequeueing = "useQueueing",
    queueing = "useQueueing",
    prequeue = "prequeueEnabled",
    prequeueenabled = "prequeueEnabled",
    lead = "attackLeadSeconds",
    attacklead = "attackLeadSeconds",
    attackleadseconds = "attackLeadSeconds",
    autogold = "autoGrabGold",
    autograbgold = "autoGrabGold",
    pack = "goldPack",
    goldpack = "goldPack",
    whitelistpriorityorder = "whitelistPriorityOrder",
    targetorder = "targetOrder",
    ragemode = "attackMode",
    attackmode = "attackMode",
    trace = "traceEnabled",
    traceenabled = "traceEnabled",
    diagtimeout = "diagTimeoutSeconds",
    diagtimeoutseconds = "diagTimeoutSeconds",
  }
  return map[key] or ""
end

function boop.ui.getConfigValue(key)
  local canonical = canonConfigKey(key)
  if canonical == "" then
    boop.util.echo("Unknown key: " .. tostring(key))
    boop.util.echo("Try: boop get")
    return
  end
  boop.util.echo(canonical .. ": " .. tostring(boop.config[canonical]))
end

function boop.ui.listConfigValues()
  local keys = {
    "enabled",
    "targetingMode",
    "useQueueing",
    "prequeueEnabled",
    "attackLeadSeconds",
    "autoGrabGold",
    "goldPack",
    "whitelistPriorityOrder",
    "targetOrder",
    "attackMode",
    "traceEnabled",
    "diagTimeoutSeconds",
  }
  boop.util.echo("config keys:")
  for _, key in ipairs(keys) do
    boop.util.echo("  " .. key .. ": " .. tostring(boop.config[key]))
  end
end

function boop.ui.setConfigValue(key, value)
  local canonical = canonConfigKey(key)
  if canonical == "" then
    boop.util.echo("Unknown key: " .. tostring(key))
    boop.util.echo("Try: boop get")
    return
  end

  if canonical == "enabled" then
    local parsed = parseBool(value)
    if parsed == nil then
      boop.util.echo("enabled expects on/off")
      return
    end
    boop.ui.setEnabled(parsed)
    return
  end

  if canonical == "targetingMode" then
    boop.ui.setTargetingMode(value)
    return
  end

  if canonical == "useQueueing" then
    local parsed = parseBool(value)
    if parsed == nil then
      boop.util.echo("useQueueing expects on/off")
      return
    end
    saveConfigValue("useQueueing", parsed)
    boop.util.echo("use queueing: " .. (parsed and "on" or "off"))
    return
  end

  if canonical == "prequeueEnabled" then
    local parsed = parseBool(value)
    if parsed == nil then
      boop.util.echo("prequeue expects on/off")
      return
    end
    boop.ui.setPrequeueEnabled(parsed)
    return
  end

  if canonical == "attackLeadSeconds" then
    boop.ui.setAttackLeadSeconds(value)
    return
  end

  if canonical == "autoGrabGold" then
    local parsed = parseBool(value)
    if parsed == nil then
      boop.util.echo("autogold expects on/off")
      return
    end
    boop.ui.setAutoGrabGold(parsed)
    return
  end

  if canonical == "goldPack" then
    boop.ui.setGoldPack(value)
    return
  end

  if canonical == "whitelistPriorityOrder" then
    local parsed = parseBool(value)
    if parsed == nil then
      boop.util.echo(canonical .. " expects on/off")
      return
    end
    saveConfigValue(canonical, parsed)
    boop.util.echo(canonical .. ": " .. (parsed and "on" or "off"))
    return
  end

  if canonical == "targetOrder" then
    local order = boop.util.safeLower(boop.util.trim(value or ""))
    if order ~= "order" and order ~= "numeric" and order ~= "reverse" then
      boop.util.echo("targetOrder expects order|numeric|reverse")
      return
    end
    saveConfigValue("targetOrder", order)
    boop.util.echo("targetOrder: " .. order)
    return
  end

  if canonical == "attackMode" then
    boop.ui.setRageMode(value)
    return
  end

  if canonical == "traceEnabled" then
    local parsed = parseBool(value)
    if parsed == nil then
      boop.util.echo("trace expects on/off")
      return
    end
    boop.ui.setTraceEnabled(parsed)
    return
  end

  if canonical == "diagTimeoutSeconds" then
    local timeout = tonumber(boop.util.trim(value or ""))
    if not timeout or timeout < 0 then
      boop.util.echo("diagTimeoutSeconds expects number >= 0")
      return
    end
    saveConfigValue("diagTimeoutSeconds", timeout)
    boop.util.echo(string.format("diag timeout: %.2fs", timeout))
    return
  end
end

function boop.ui.traceCommand(sub, arg)
  local cmd = boop.util.safeLower(boop.util.trim(sub or ""))
  if cmd == "" then
    boop.util.echo("trace: " .. (boop.config.traceEnabled and "on" or "off"))
    boop.util.echo("  boop trace on|off|show [n]|clear")
    return
  end
  if cmd == "on" then
    boop.ui.setTraceEnabled(true)
    return
  end
  if cmd == "off" then
    boop.ui.setTraceEnabled(false)
    return
  end
  if cmd == "clear" then
    boop.trace.clear()
    return
  end
  if cmd == "show" then
    boop.trace.show(arg)
    return
  end
  boop.util.echo("trace: unknown option " .. tostring(sub))
end

local function copyList(list)
  local out = {}
  for i, name in ipairs(list or {}) do
    out[i] = name
  end
  return out
end

local function countListMap(map)
  local areas, entries = 0, 0
  for _, list in pairs(map or {}) do
    areas = areas + 1
    entries = entries + #list
  end
  return areas, entries
end

local function safeFetchRows(dbtable, orderBy)
  local ok, rows = pcall(function()
    return db:fetch(dbtable, nil, orderBy)
  end)
  if not ok then
    return nil, tostring(rows)
  end
  return rows or {}, nil
end

local function loadFoxhuntListMap(dbtable, tableName)
  local out = {}
  if not dbtable then
    return nil, "missing table handle: " .. tostring(tableName or "unknown")
  end
  local rows, err = safeFetchRows(dbtable, { dbtable.area, dbtable.pos })
  if err then
    return nil, string.format("fetch failed for %s: %s", tostring(tableName or "unknown"), tostring(err))
  end
  for _, row in ipairs(rows or {}) do
    local area = boop.util.trim(row.area or "")
    local name = boop.util.trim(row.name or "")
    if area ~= "" and name ~= "" then
      out[area] = out[area] or {}
      out[area][#out[area] + 1] = name
    end
  end
  return out, nil
end

local function dbLocationHint(dbName)
  local name = boop.util.trim(dbName or "")
  if name == "" then name = "hunting" end
  local filename = "Database_" .. name .. ".db"
  if type(getMudletHomeDir) == "function" then
    local home = boop.util.trim(getMudletHomeDir() or "")
    if home ~= "" then
      return string.format("Expected `%s` under your profile folder in `%s`.", filename, home)
    end
  end
  return string.format("Expected `%s` under your Mudlet profile folder.", filename)
end

local function dbFilePath(dbName)
  local name = boop.util.trim(dbName or "")
  if name == "" then return "" end
  if type(getMudletHomeDir) ~= "function" then return "" end
  local home = boop.util.trim(getMudletHomeDir() or "")
  if home == "" then return "" end
  local slash = home:sub(-1)
  local sep = (slash == "/" or slash == "\\") and "" or "/"
  return home .. sep .. "Database_" .. name .. ".db"
end

local function fileExists(path)
  if not path or path == "" then return false end
  local f = io.open(path, "rb")
  if not f then return false end
  f:close()
  return true
end

local function huntingSchema()
  return {
    whitelist = {
      area = "",
      pos = 0,
      name = "",
      ignore = 0,
      _index = { "area" },
    },
    blacklist = {
      area = "",
      pos = 0,
      name = "",
      ignore = 0,
      _index = { "area" },
    },
    hconfig = {
      name = "",
      value = "",
      _unique = { "name" },
      _violations = "IGNORE",
    },
  }
end

local function attachKnownDatabase(name)
  if name ~= "hunting" then
    return false, "no attach schema for `" .. tostring(name) .. "`"
  end
  if not db or not db.create then
    return false, "Mudlet DB create API unavailable"
  end
  local path = dbFilePath(name)
  if path == "" then
    return false, "Mudlet home directory unavailable"
  end
  if not fileExists(path) then
    return false, "database file not found at " .. path
  end
  local ok, err = pcall(function()
    db:create(name, huntingSchema())
  end)
  if not ok then
    return false, tostring(err)
  end
  return true, nil
end

local function safeGetDatabase(name)
  if not db or not db.get_database then
    return nil, "Mudlet DB unavailable."
  end
  local ok, handleOrErr = pcall(function()
    return db:get_database(name)
  end)
  if ok and handleOrErr then
    return handleOrErr, nil
  end

  local firstErr = ok and ("database `" .. tostring(name) .. "` not registered in current session") or tostring(handleOrErr)
  local attached, attachErr = attachKnownDatabase(name)
  if not attached then
    return nil, firstErr .. " | attach attempt failed: " .. tostring(attachErr)
  end

  local retryOk, retryHandleOrErr = pcall(function()
    return db:get_database(name)
  end)
  if not retryOk then
    return nil, tostring(retryHandleOrErr)
  end
  if not retryHandleOrErr then
    return nil, "database `" .. tostring(name) .. "` still unavailable after attach"
  end
  return retryHandleOrErr, nil
end

local function safeGetDbTable(dbHandle, tableName)
  if not dbHandle then
    return nil, "missing database handle"
  end
  local ok, tableOrErr = pcall(function()
    return dbHandle[tableName]
  end)
  if not ok then
    return nil, tostring(tableOrErr)
  end
  if not tableOrErr then
    return nil, "table `" .. tostring(tableName) .. "` not found"
  end
  return tableOrErr, nil
end

local function clearBoopStoredLists()
  if not boop.db or not boop.db.handle then return end
  local wlTable = boop.db.handle.whitelist
  local blTable = boop.db.handle.blacklist

  for _, row in ipairs(db:fetch(wlTable, nil) or {}) do
    db:delete(wlTable, row._row_id)
  end
  for _, row in ipairs(db:fetch(blTable, nil) or {}) do
    db:delete(blTable, row._row_id)
  end
end

function boop.ui.importFoxhunt(mode)
  local importMode = boop.util.safeLower(boop.util.trim(mode or ""))
  if importMode == "" then
    importMode = "merge"
  end
  if importMode ~= "merge" and importMode ~= "overwrite" and importMode ~= "dryrun" then
    boop.util.echo("Usage: boop import foxhunt [merge|overwrite|dryrun]")
    return
  end

  boop.util.echo("foxhunt import: starting (" .. importMode .. ")")

  local foxDb, dbErr = safeGetDatabase("hunting")
  if dbErr then
    boop.util.echo("foxhunt import failed: " .. dbErr)
    boop.util.echo(dbLocationHint("hunting"))
    return
  end
  if not foxDb then
    boop.util.echo("foxhunt import failed: DB `hunting` not found. " .. dbLocationHint("hunting"))
    return
  end

  local whitelistTable, wlTableErr = safeGetDbTable(foxDb, "whitelist")
  if wlTableErr then
    boop.util.echo("foxhunt import failed: cannot access `hunting.whitelist` (" .. wlTableErr .. ")")
    return
  end
  local blacklistTable, blTableErr = safeGetDbTable(foxDb, "blacklist")
  if blTableErr then
    boop.util.echo("foxhunt import failed: cannot access `hunting.blacklist` (" .. blTableErr .. ")")
    return
  end

  local fhWhitelist, wlErr = loadFoxhuntListMap(whitelistTable, "whitelist")
  if wlErr then
    boop.util.echo("foxhunt import failed: " .. wlErr)
    return
  end
  local fhBlacklist, blErr = loadFoxhuntListMap(blacklistTable, "blacklist")
  if blErr then
    boop.util.echo("foxhunt import failed: " .. blErr)
    return
  end
  local wlAreas, wlEntries = countListMap(fhWhitelist)
  local blAreas, blEntries = countListMap(fhBlacklist)

  boop.util.echo(string.format("foxhunt import %s | whitelist %d areas/%d entries | blacklist %d areas/%d entries",
    importMode, wlAreas, wlEntries, blAreas, blEntries))
  if wlEntries == 0 and blEntries == 0 then
    boop.util.echo("foxhunt import: source lists are empty; nothing to import")
  end

  if importMode == "dryrun" then
    boop.util.echo("dryrun only; no changes applied")
    return
  end

  if not boop.db or not boop.db.saveList then
    boop.util.echo("foxhunt import failed: boop DB unavailable; cannot persist imported lists.")
    return
  end

  local ok, applyErr = pcall(function()
    if importMode == "overwrite" then
      clearBoopStoredLists()
      boop.lists.whitelist = {}
      boop.lists.blacklist = {}
      boop.lists.globalBlacklist = {}
    end

    local importedWlAreas = 0
    for area, list in pairs(fhWhitelist) do
      local copied = copyList(list)
      boop.lists.whitelist[area] = copied
      boop.db.saveList("whitelist", area, copied)
      importedWlAreas = importedWlAreas + 1
    end

    local importedBlAreas = 0
    for area, list in pairs(fhBlacklist) do
      local copied = copyList(list)
      if area == "GLOBAL" then
        boop.lists.globalBlacklist = copied
      else
        boop.lists.blacklist[area] = copied
      end
      boop.db.saveList("blacklist", area, copied)
      importedBlAreas = importedBlAreas + 1
    end

    boop.util.echo(string.format("import applied | whitelist areas: %d | blacklist areas: %d",
      importedWlAreas, importedBlAreas))
    boop.trace.log("import foxhunt " .. importMode .. " applied")
  end)
  if not ok then
    boop.util.echo("foxhunt import failed: " .. tostring(applyErr))
    boop.trace.log("import foxhunt failed: " .. tostring(applyErr))
    return
  end
end

local HELP_TOPICS = {
  {
    key = "targeting",
    title = "Targeting",
    aliases = { "targeting" },
    commands = {
      "boop targeting manual",
      "boop targeting whitelist",
      "boop targeting blacklist",
      "boop targeting auto",
    },
    notes = {
      "Use boop config for clickable mode switching.",
    },
  },
  {
    key = "whitelist",
    title = "Whitelist",
    aliases = { "whitelist" },
    commands = {
      "boop whitelist",
      "boop whitelist add <name>",
      "boop whitelist remove <name>",
      "boop whitelist browse [tag]",
      "boop whitelist tags <area>",
      "boop whitelist tag list",
      "boop whitelist tag add <area> | <tag[,tag2,...]>",
      "boop whitelist tag remove <area> | <tag[,tag2,...]>",
    },
    notes = {
      "Whitelist display supports clickable up/down/remove ordering.",
      "Priority order applies when whitelistPriorityOrder is ON.",
      "Tags normalize to lowercase with dashes.",
    },
  },
  {
    key = "blacklist",
    title = "Blacklist",
    aliases = { "blacklist" },
    commands = {
      "boop blacklist",
      "boop blacklist add <name>",
      "boop blacklist remove <name>",
    },
    notes = {
      "Blacklist display supports clickable up/down/remove ordering.",
      "Blacklist mode attacks valid denizens except blacklisted entries.",
    },
  },
  {
    key = "ragemode",
    title = "Ragemode",
    aliases = { "ragemode", "rage", "attackmode" },
    commands = {
      "boop ragemode <simple|dam|big|small|aff|cond|buff|pool|none>",
      "boop ragemode simple",
      "boop ragemode big",
      "boop ragemode none",
    },
    notes = {},
  },
  {
    key = "queueing",
    title = "Queueing",
    aliases = { "queue", "queueing" },
    commands = {
      "boop config",
      "boop prequeue [on|off]",
      "boop lead <seconds>",
    },
    notes = {
      "Use queueing is controlled under boop config.",
      "Rage actions are still sent directly.",
    },
  },
  {
    key = "prequeue",
    title = "Prequeue",
    aliases = { "prequeue", "lead" },
    commands = {
      "boop prequeue",
      "boop prequeue on",
      "boop prequeue off",
      "boop lead <seconds>",
    },
    notes = {
      "Prequeue schedules standard attack queueing before recovery.",
      "Default lead is 1.00 seconds.",
    },
  },
  {
    key = "gold",
    title = "Gold",
    aliases = { "gold", "autogold", "loot" },
    commands = {
      "boop autogold",
      "boop autogold on",
      "boop autogold off",
      "boop pack <container>",
      "boop pack off",
      "boop pack test",
    },
    notes = {
      "Auto pickup uses sovereigns keyword.",
      "In queueing mode this prepends get sovereigns/<attack>.",
    },
  },
  {
    key = "pack",
    title = "Gold Pack",
    aliases = { "pack", "goldpack" },
    commands = {
      "boop pack",
      "boop pack <container>",
      "boop pack off",
      "boop pack test",
    },
    notes = {
      "Sets optional auto-stash container for sovereigns.",
    },
  },
  {
    key = "import",
    title = "Import",
    aliases = { "import", "foxhunt" },
    commands = {
      "boop import foxhunt",
      "boop import foxhunt merge",
      "boop import foxhunt overwrite",
      "boop import foxhunt dryrun",
    },
    notes = {
      "merge: replace boop list data for imported areas, keep other boop areas.",
      "overwrite: clear boop lists first, then import all areas.",
      "dryrun: report counts only.",
    },
  },
  {
    key = "diag",
    title = "Diag",
    aliases = { "diag", "diagnose" },
    commands = {
      "diag",
    },
    notes = {
      "Clears queue, queues diagnose, and pauses boop attacks.",
      "Attacking resumes after diagnose line + prompt.",
    },
  },
  {
    key = "trace",
    title = "Trace",
    aliases = { "trace" },
    commands = {
      "boop trace",
      "boop trace on",
      "boop trace off",
      "boop trace show [n]",
      "boop trace clear",
    },
    notes = {
      "Tracks recent boop decisions/commands for debugging.",
    },
  },
  {
    key = "setget",
    title = "Set/Get",
    aliases = { "setget", "set", "get" },
    commands = {
      "boop get",
      "boop get <key>",
      "boop set <key> <value>",
      "boop set prequeue off",
      "boop set lead 0.8",
    },
    notes = {},
  },
  {
    key = "ih",
    title = "IH",
    aliases = { "ih" },
    commands = {
      "ih",
      "boop ih",
    },
    notes = {
      "Shows room items and denizens.",
      "Denizens get clickable whitelist/blacklist actions.",
    },
  },
  {
    key = "aff",
    title = "Afflictions",
    aliases = { "aff", "afflictions" },
    commands = {
      "boop aff",
      "boop aff add <a/b/c>",
      "boop aff remove <a/b/c>",
      "boop aff clear",
    },
    notes = {},
  },
  {
    key = "trip",
    title = "Trip/Stats",
    aliases = { "trip", "stats" },
    commands = {
      "boop trip start",
      "boop trip stop",
    },
    notes = {
      "Tracks trip/session/lifetime gains from GMCP status updates.",
    },
  },
  {
    key = "debug",
    title = "Debug",
    aliases = { "debug" },
    commands = {
      "boop debug",
      "boop debug attacks",
      "boop debug skills",
      "boop debug skills dump",
    },
    notes = {},
  },
  {
    key = "config",
    title = "Config",
    aliases = { "config" },
    commands = {
      "boop config",
      "boop config <number>",
      "boop config <section>",
      "boop config <section> <number>",
      "boop config back",
      "boop config home",
    },
    notes = {
      "First screen is section menu, then each section has numbered actions.",
    },
  },
}

local function helpResolveTopic(raw)
  local token = boop.util.safeLower(boop.util.trim(raw or ""))
  if token == "" then return nil end

  local idx = tonumber(token)
  if idx and HELP_TOPICS[idx] then
    return HELP_TOPICS[idx]
  end

  for _, topic in ipairs(HELP_TOPICS) do
    for _, alias in ipairs(topic.aliases or {}) do
      if token == alias then
        return topic
      end
    end
  end
  return nil
end

local function helpRenderHome()
  if cecho then
    uiPrintHeader("help")
    uiPrintSection("topics")
    for i, topic in ipairs(HELP_TOPICS) do
      local key = topic.key
      uiPrintRow(i, topic.title, "OPEN", "cyan", function()
        boop.ui.help(key)
      end, "Open help for " .. topic.title)
    end
    uiPrintFooter("Type: boop help <number|topic> | boop config | boop status")
    return
  end

  boop.util.echo("HELP")
  boop.util.echo("----------------------------------------")
  for i, topic in ipairs(HELP_TOPICS) do
    boop.util.echo(string.format("[%d] %s", i, topic.title))
  end
  boop.util.echo("----------------------------------------")
  boop.util.echo("Type: boop help <number>  (example: boop help 2)")
  boop.util.echo("Type: boop help <topic>   (example: boop help whitelist)")
end

local function helpRenderTopic(topic)
  if not topic then
    helpRenderHome()
    return
  end

  if cecho then
    uiPrintHeader("help > " .. topic.title)
    uiPrintSection("commands")
    for i, cmd in ipairs(topic.commands or {}) do
      local value = cmd
      uiPrintRow(i, value, "COPY", "yellow", function()
        uiSetCommandLine(value)
      end, "Copy command: " .. value)
    end
    if topic.notes and #topic.notes > 0 then
      uiPrintSection("notes")
      for i, note in ipairs(topic.notes) do
        uiPrintRow(i, note, "INFO", "cyan", nil, note)
      end
    end
    uiPrintFooter("Type: boop help back | boop help home | boop help <number|topic>")
    return
  end

  boop.util.echo("HELP > " .. topic.title)
  boop.util.echo("----------------------------------------")
  for _, cmd in ipairs(topic.commands or {}) do
    boop.util.echo("  " .. cmd)
  end
  if topic.notes and #topic.notes > 0 then
    boop.util.echo("Notes:")
    for _, note in ipairs(topic.notes) do
      boop.util.echo("  - " .. note)
    end
  end
  boop.util.echo("----------------------------------------")
  boop.util.echo("Type: boop help back | boop help home")
end

function boop.ui.help(topic)
  local t = boop.util.safeLower(boop.util.trim(topic or ""))

  if t == "" or t == "main" or t == "general" or t == "home" or t == "topics" or t == "topic" or t == "back" then
    helpRenderHome()
    return
  end

  local resolved = helpResolveTopic(t)
  if resolved then
    helpRenderTopic(resolved)
    return
  end

  boop.util.echo("Unknown help topic: " .. tostring(topic))
  helpRenderHome()
end

function boop.ui.home()
  boop.ui.status("status")
  boop.ui.help("main")
end

local CONFIG_SECTIONS = {
  { id = 1, key = "combat", label = "Combat" },
  { id = 2, key = "targeting", label = "Targeting" },
  { id = 3, key = "queueing", label = "Queueing" },
  { id = 4, key = "loot", label = "Loot" },
  { id = 5, key = "debug", label = "Debug" },
}

local function configSectionByKey(key)
  local k = boop.util.safeLower(boop.util.trim(key or ""))
  for _, section in ipairs(CONFIG_SECTIONS) do
    if section.key == k then
      return section
    end
  end
  return nil
end

local function configSectionById(id)
  local n = tonumber(id)
  if not n then return nil end
  for _, section in ipairs(CONFIG_SECTIONS) do
    if section.id == n then
      return section
    end
  end
  return nil
end

local function normalizeConfigToken(token)
  local t = boop.util.safeLower(boop.util.trim(token or ""))
  t = t:gsub("[%s_%-]+", "")
  return t
end

local function configResolveSection(token)
  local raw = boop.util.trim(token or "")
  if raw == "" then return nil end
  local byId = configSectionById(raw)
  if byId then return byId end
  local normalized = normalizeConfigToken(raw)
  for _, section in ipairs(CONFIG_SECTIONS) do
    if normalizeConfigToken(section.key) == normalized then
      return section
    end
    if normalizeConfigToken(section.label) == normalized then
      return section
    end
  end
  return nil
end

local function configGetScreen()
  boop.ui = boop.ui or {}
  local key = boop.ui.configScreen or (boop.state and boop.state.configScreen) or "home"
  if key ~= "home" and not configSectionByKey(key) then
    key = "home"
  end
  boop.ui.configScreen = key
  boop.state = boop.state or {}
  boop.state.configScreen = key
  return key
end

local function configSetScreen(key)
  boop.ui = boop.ui or {}
  boop.state = boop.state or {}
  local screen = boop.util.safeLower(boop.util.trim(key or "home"))
  if screen ~= "home" and not configSectionByKey(screen) then
    screen = "home"
  end
  boop.ui.configScreen = screen
  boop.state.configScreen = screen
  return screen
end

local function configRenderHome()
  configSetScreen("home")
  if cecho then
    uiPrintHeader("configuration")
    for _, section in ipairs(CONFIG_SECTIONS) do
      local sec = section
      uiPrintRow(sec.id, sec.label, "OPEN", "cyan", function()
        boop.ui.config(sec.key)
      end, "Open " .. sec.label .. " settings")
    end
    uiPrintFooter("Type: boop config <number> | boop config <name>")
    return
  end
  boop.util.echo("CONFIGURATION")
  boop.util.echo("----------------------------------------")
  for _, section in ipairs(CONFIG_SECTIONS) do
    boop.util.echo(string.format("[%d] %s", section.id, section.label))
  end
  boop.util.echo("----------------------------------------")
  boop.util.echo("Type: boop config <number>  (example: boop config 1)")
  boop.util.echo("Type: boop config <name>    (example: boop config combat)")
end

local function configRenderCombatSection()
  configSetScreen("combat")
  if cecho then
    uiPrintHeader("configuration > combat")
    uiPrintSection("controls")
    uiPrintRow(1, "Hunting enabled", boolText(boop.config.enabled), boolColor(boop.config.enabled), function()
      boop.ui.config("1")
    end, "Toggle hunting enabled")
    uiPrintRow(2, "Rage mode", tostring(boop.config.attackMode or "simple"), "yellow", function()
      boop.ui.config("2")
    end, "Prepare boop ragemode command")
    uiPrintRow(3, "Run diag", "RUN", "yellow", function()
      boop.ui.config("3")
    end, "Queue diagnose and pause attacks")
    uiPrintFooter("Type: boop config <number> to change | boop config back | boop config home")
    return
  end
  boop.util.echo("CONFIGURATION > Combat")
  boop.util.echo("----------------------------------------")
  boop.util.echo("[1] Hunting enabled           [ " .. boolText(boop.config.enabled) .. " ]")
  boop.util.echo("[2] Rage mode                 [ " .. tostring(boop.config.attackMode or "simple") .. " ]")
  boop.util.echo("[3] Run diag                  [ RUN ]")
  boop.util.echo("----------------------------------------")
  boop.util.echo("Type: boop config <number> to change | boop config back | boop config home")
end

local function configRenderTargetingSection()
  configSetScreen("targeting")
  if cecho then
    uiPrintHeader("configuration > targeting")
    uiPrintSection("target controls")
    uiPrintRow(1, "Targeting mode", boop.config.targetingMode or "whitelist", "cyan", function()
      boop.ui.config("1")
    end, "Cycle targeting mode")
    uiPrintRow(2, "Whitelist priority order", boolText(not not boop.config.whitelistPriorityOrder), boolColor(not not boop.config.whitelistPriorityOrder), function()
      boop.ui.config("2")
    end, "Toggle whitelist priority ordering")
    uiPrintRow(3, "Target order", boop.config.targetOrder or "order", "cyan", function()
      boop.ui.config("3")
    end, "Cycle target order")
    uiPrintSection("list managers")
    uiPrintRow(4, "Whitelist manager", "OPEN", "green", function()
      boop.ui.config("4")
    end, "Open whitelist manager")
    uiPrintRow(5, "Whitelist browse", "OPEN", "green", function()
      boop.ui.config("5")
    end, "Open whitelist area browser")
    uiPrintRow(6, "Blacklist manager", "OPEN", "green", function()
      boop.ui.config("6")
    end, "Open blacklist manager")
    uiPrintFooter("Type: boop config <number> to change | boop config back | boop config home")
    return
  end
  boop.util.echo("CONFIGURATION > Targeting")
  boop.util.echo("----------------------------------------")
  boop.util.echo("[1] Targeting mode            [ " .. tostring(boop.config.targetingMode or "whitelist") .. " ]")
  boop.util.echo("[2] Whitelist priority order  [ " .. boolText(not not boop.config.whitelistPriorityOrder) .. " ]")
  boop.util.echo("[3] Target order              [ " .. tostring(boop.config.targetOrder or "order") .. " ]")
  boop.util.echo("[4] Whitelist manager         [ OPEN ]")
  boop.util.echo("[5] Whitelist browse          [ OPEN ]")
  boop.util.echo("[6] Blacklist manager         [ OPEN ]")
  boop.util.echo("----------------------------------------")
  boop.util.echo("Type: boop config <number> to change | boop config back | boop config home")
end

local function configRenderQueueingSection()
  configSetScreen("queueing")
  local lead = tonumber(boop.config.attackLeadSeconds) or 0
  local diagTimeout = tonumber(boop.config.diagTimeoutSeconds) or 0
  if cecho then
    uiPrintHeader("configuration > queueing")
    uiPrintSection("queue controls")
    uiPrintRow(1, "Use queueing", boolText(not not boop.config.useQueueing), boolColor(not not boop.config.useQueueing), function()
      boop.ui.config("1")
    end, "Toggle queueing mode")
    uiPrintRow(2, "Prequeue", boolText(not not boop.config.prequeueEnabled), boolColor(not not boop.config.prequeueEnabled), function()
      boop.ui.config("2")
    end, "Toggle prequeue")
    uiPrintRow(3, string.format("Attack lead (%.2fs)", lead), "SET", "yellow", function()
      boop.ui.config("3")
    end, "Prepare boop lead command")
    uiPrintRow(4, string.format("Diag timeout (%.2fs)", diagTimeout), "SET", "yellow", function()
      boop.ui.config("4")
    end, "Prepare boop set diagtimeout command")
    uiPrintFooter("Type: boop config <number> to change | boop config back | boop config home")
    return
  end
  boop.util.echo("CONFIGURATION > Queueing")
  boop.util.echo("----------------------------------------")
  boop.util.echo("[1] Use queueing              [ " .. boolText(not not boop.config.useQueueing) .. " ]")
  boop.util.echo("[2] Prequeue                  [ " .. boolText(not not boop.config.prequeueEnabled) .. " ]")
  boop.util.echo(string.format("[3] Attack lead               [ %.2fs ]", lead))
  boop.util.echo(string.format("[4] Diag timeout              [ %.2fs ]", diagTimeout))
  boop.util.echo("----------------------------------------")
  boop.util.echo("Type: boop config <number> to change | boop config back | boop config home")
end

local function configRenderLootSection()
  configSetScreen("loot")
  local pack = boop.util.trim(boop.config.goldPack or "")
  local shownPack = pack ~= "" and pack or "(off)"
  if cecho then
    uiPrintHeader("configuration > loot")
    uiPrintSection("gold controls")
    uiPrintRow(1, "Auto grab sovereigns", boolText(not not boop.config.autoGrabGold), boolColor(not not boop.config.autoGrabGold), function()
      boop.ui.config("1")
    end, "Toggle automatic sovereign pickup")
    uiPrintRow(2, "Gold pack container", shownPack, "yellow", function()
      boop.ui.config("2")
    end, "Prepare boop pack command")
    uiPrintRow(3, "Clear gold pack", "OFF", "red", function()
      boop.ui.config("3")
    end, "Disable auto stashing")
    uiPrintRow(4, "Gold pack test", "RUN", "yellow", function()
      boop.ui.config("4")
    end, "Queue look in pack")
    uiPrintFooter("Type: boop config <number> to change | boop config back | boop config home")
    return
  end
  boop.util.echo("CONFIGURATION > Loot")
  boop.util.echo("----------------------------------------")
  boop.util.echo("[1] Auto grab sovereigns      [ " .. boolText(not not boop.config.autoGrabGold) .. " ]")
  boop.util.echo("[2] Gold pack container       [ " .. shownPack .. " ]")
  boop.util.echo("[3] Clear gold pack           [ OFF ]")
  boop.util.echo("[4] Gold pack test            [ RUN ]")
  boop.util.echo("----------------------------------------")
  boop.util.echo("Type: boop config <number> to change | boop config back | boop config home")
end

local function configRenderDebugSection()
  configSetScreen("debug")
  if cecho then
    uiPrintHeader("configuration > debug")
    uiPrintSection("debug controls")
    uiPrintRow(1, "Trace logging", boolText(not not boop.config.traceEnabled), boolColor(not not boop.config.traceEnabled), function()
      boop.ui.config("1")
    end, "Toggle trace logging")
    uiPrintRow(2, "Debug snapshot", "SHOW", "cyan", function()
      boop.ui.config("2")
    end, "Show boop debug snapshot")
    uiPrintRow(3, "Trace buffer", "SHOW", "cyan", function()
      boop.ui.config("3")
    end, "Show trace entries")
    uiPrintRow(4, "Clear trace", "CLEAR", "red", function()
      boop.ui.config("4")
    end, "Clear trace buffer")
    uiPrintFooter("Type: boop config <number> to change | boop config back | boop config home")
    return
  end
  boop.util.echo("CONFIGURATION > Debug")
  boop.util.echo("----------------------------------------")
  boop.util.echo("[1] Trace logging             [ " .. boolText(not not boop.config.traceEnabled) .. " ]")
  boop.util.echo("[2] Debug snapshot            [ SHOW ]")
  boop.util.echo("[3] Trace buffer              [ SHOW ]")
  boop.util.echo("[4] Clear trace               [ CLEAR ]")
  boop.util.echo("----------------------------------------")
  boop.util.echo("Type: boop config <number> to change | boop config back | boop config home")
end

local function configRenderSection(key)
  if key == "combat" then
    configRenderCombatSection()
    return
  end
  if key == "targeting" then
    configRenderTargetingSection()
    return
  end
  if key == "queueing" then
    configRenderQueueingSection()
    return
  end
  if key == "loot" then
    configRenderLootSection()
    return
  end
  if key == "debug" then
    configRenderDebugSection()
    return
  end
  configRenderHome()
end

local function configApplySectionOption(sectionKey, option)
  local n = tonumber(option)
  if not n then return false end

  if sectionKey == "combat" then
    if n == 1 then
      boop.ui.setEnabled(not boop.config.enabled, true)
      return true
    elseif n == 2 then
      uiSetCommandLine("boop ragemode ")
      return true
    elseif n == 3 then
      boop.ui.diag()
      return true
    end
    return false
  end

  if sectionKey == "targeting" then
    if n == 1 then
      cycleTargetingMode(1, true)
      return true
    elseif n == 2 then
      boop.ui.toggleConfigBool("whitelistPriorityOrder", true)
      return true
    elseif n == 3 then
      boop.ui.cycleTargetOrder(1, true)
      return true
    elseif n == 4 then
      boop.targets.displayWhitelist()
      return true
    elseif n == 5 then
      boop.targets.displayWhitelistBrowse()
      return true
    elseif n == 6 then
      boop.targets.displayBlacklist()
      return true
    end
    return false
  end

  if sectionKey == "queueing" then
    if n == 1 then
      boop.ui.toggleConfigBool("useQueueing", true)
      return true
    elseif n == 2 then
      boop.ui.setPrequeueEnabled(not boop.config.prequeueEnabled)
      return true
    elseif n == 3 then
      uiSetCommandLine("boop lead ")
      return true
    elseif n == 4 then
      uiSetCommandLine("boop set diagtimeout ")
      return true
    end
    return false
  end

  if sectionKey == "loot" then
    if n == 1 then
      boop.ui.toggleAutoGrabGold()
      return true
    elseif n == 2 then
      uiSetCommandLine("boop pack ")
      return true
    elseif n == 3 then
      boop.ui.setGoldPack("")
      return true
    elseif n == 4 then
      boop.ui.testGoldPack()
      return true
    end
    return false
  end

  if sectionKey == "debug" then
    if n == 1 then
      boop.ui.setTraceEnabled(not boop.config.traceEnabled)
      return true
    elseif n == 2 then
      boop.ui.debug()
      return true
    elseif n == 3 then
      if boop.trace and boop.trace.show then
        boop.trace.show()
      else
        boop.util.echo("trace unavailable")
      end
      return true
    elseif n == 4 then
      if boop.trace and boop.trace.clear then
        boop.trace.clear()
      else
        boop.util.echo("trace unavailable")
      end
      return true
    end
    return false
  end

  return false
end

function boop.ui.toggleConfigBool(key, noRefresh)
  local value = boop.config[key]
  if type(value) ~= "boolean" then
    boop.util.echo("Config key is not boolean: " .. tostring(key))
    return
  end
  saveConfigValue(key, not value)
  if not noRefresh then
    boop.ui.config()
  end
end

function boop.ui.cycleTargetOrder(step, noRefresh)
  local order = { "order", "numeric", "reverse" }
  local current = boop.util.safeLower(boop.config.targetOrder or "order")
  local idx = 1
  for i, value in ipairs(order) do
    if current == value then
      idx = i
      break
    end
  end
  step = tonumber(step) or 1
  idx = idx + step
  while idx < 1 do idx = idx + #order end
  while idx > #order do idx = idx - #order end
  saveConfigValue("targetOrder", order[idx])
  if not noRefresh then
    boop.ui.config()
  end
end

function boop.ui.config(arg)
  local raw = boop.util.trim(arg or "")
  local token = boop.util.safeLower(raw)
  local current = configGetScreen()

  if token == "" then
    configRenderSection(current)
    return
  end

  if token == "home" or token == "main" then
    configRenderHome()
    return
  end

  if token == "back" then
    configRenderHome()
    return
  end

  local sectionPart, optionPart = raw:match("^%s*([%a_%-]+)%s+(%d+)%s*$")
  if sectionPart and optionPart then
    local requestedExplicit = configResolveSection(sectionPart)
    if requestedExplicit and configApplySectionOption(requestedExplicit.key, optionPart) then
      configRenderSection(requestedExplicit.key)
      return
    end
  end

  if current ~= "home" then
    if configApplySectionOption(current, token) then
      configRenderSection(current)
      return
    end
    local requestedByName = configResolveSection(token)
    if requestedByName and not tonumber(token) then
      configRenderSection(requestedByName.key)
      return
    end
    boop.util.echo("Unknown option for " .. tostring(current) .. ": " .. tostring(arg))
    boop.util.echo("Use: boop config <number> | boop config back | boop config home")
    configRenderSection(current)
    return
  end

  local requestedSection = configResolveSection(token)
  if requestedSection then
    configRenderSection(requestedSection.key)
    return
  end

  if current == "home" then
    boop.util.echo("Unknown config section: " .. tostring(arg))
    boop.util.echo("Use: boop config <number> | boop config <name>")
    configRenderHome()
    return
  end
end

function boop.ui.debug()
  local enabled = boop.config.enabled and "on" or "off"
  local mode = boop.config.targetingMode or "unknown"
  local denizenCount = boop.state.denizens and #boop.state.denizens or 0
  local currentTargetId = boop.state.currentTargetId or ""
  local currentTargetName = boop.state.targetName or ""
  local class = boop.state.class or (gmcp and gmcp.Char and gmcp.Char.Status and gmcp.Char.Status.class) or "unknown"
  local eq = gmcp and gmcp.Char and gmcp.Char.Vitals and gmcp.Char.Vitals.eq or "?"
  local bal = gmcp and gmcp.Char and gmcp.Char.Vitals and gmcp.Char.Vitals.bal or "?"
  local rage = boop.attacks and boop.attacks.getRage and boop.attacks.getRage() or 0
  local msg = string.format(
    "enabled:%s | mode:%s | class:%s | eq:%s bal:%s | denizens:%s | target:%s (%s) | rage:%s",
    enabled, mode, class, tostring(eq), tostring(bal),
    tostring(denizenCount), tostring(currentTargetId), tostring(currentTargetName), tostring(rage)
  )
  boop.util.echo("debug | " .. msg)
end

local function skillStatus(name)
  if not name or name == "" then
    return "n/a"
  end
  local key = boop.util.safeLower(name)
  local known = boop.skills and boop.skills.known and boop.skills.known[key]
  local group = boop.skills and boop.skills.skillToGroup and boop.skills.skillToGroup[key]
  if known == nil then
    return string.format("unknown (group:%s)", tostring(group))
  end
  return string.format("%s (group:%s)", tostring(known), tostring(group))
end

local function entrySummary(label, entry)
  if type(entry) == "table" and (entry.cmd or entry.skill or entry.name) then
    boop.util.echo(string.format("debug attacks | %s cmd:%s | skill:%s", label, tostring(entry.cmd or ""), skillStatus(entry.skill or entry.name)))
    return
  end
  if type(entry) == "table" then
    for i, option in ipairs(entry) do
      local optLabel = string.format("%s[%s]", label, i)
      entrySummary(optLabel, option)
    end
    return
  end
  boop.util.echo(string.format("debug attacks | %s cmd:%s", label, tostring(entry or "")))
end

function boop.ui.debugAttacks()
  local class = boop.util.safeLower(boop.state.class or (gmcp and gmcp.Char and gmcp.Char.Status and gmcp.Char.Status.class) or "")
  local profile = boop.attacks and boop.attacks.registry and boop.attacks.registry[class] or nil
  if not profile then
    boop.util.echo("debug attacks | no profile for class: " .. tostring(class))
    return
  end

  if profile.standard then
    entrySummary("dam", profile.standard.dam)
    entrySummary("shield", profile.standard.shield)
  end

  if profile.rage and profile.rage.abilities then
    local rage = boop.attacks and boop.attacks.getRage and boop.attacks.getRage() or 0
    for key, ability in pairs(profile.rage.abilities) do
      local skillName = ability.skill or ability.name or key
      local status = skillStatus(skillName)
      local ready = boop.attacks and boop.attacks.rageReady and boop.attacks.rageReady(ability, rage) or false
      boop.util.echo(string.format(
        "debug attacks | rage %s desc:%s rage:%s ready:%s skill:%s",
        tostring(key), tostring(ability.desc or ""), tostring(ability.rage or 0), tostring(ready), status
      ))
    end
  end

  local actions = boop.attacks.choose()
  local rageName = actions.rageAbility and (actions.rageAbility.name or actions.rageAbility.skill) or ""
  boop.util.echo(string.format("debug attacks | chosen standard:%s | chosen rage:%s | rage ability:%s",
    tostring(actions.standard or ""), tostring(actions.rage or ""), tostring(rageName)))
end

function boop.ui.debugSkills()
  local lastInfoSkill = boop.skills and boop.skills.lastInfo and (boop.skills.lastInfo.skill or boop.skills.lastInfo.name) or "nil"
  local lastInfoGroup = boop.skills and boop.skills.lastInfo and boop.skills.lastInfo.group or "nil"
  local lastListGroup = boop.skills and boop.skills.lastList and boop.skills.lastList.group or "nil"
  local lastListCount = boop.skills and boop.skills.lastList and boop.skills.lastList.list and #boop.skills.lastList.list or 0
  local pendingCount = 0
  if boop.skills and boop.skills.pending then
    for _, _ in pairs(boop.skills.pending) do
      pendingCount = pendingCount + 1
    end
  end
  boop.util.echo(string.format(
    "debug skills | pending:%s | lastList group:%s count:%s | lastInfo skill:%s group:%s",
    tostring(pendingCount), tostring(lastListGroup), tostring(lastListCount),
    tostring(lastInfoSkill), tostring(lastInfoGroup)
  ))
end

function boop.ui.debugSkillsDump()
  if not gmcp or not gmcp.Char or not gmcp.Char.Skills then
    boop.util.echo("debug skills dump | gmcp.Char.Skills not available")
    return
  end
  if display then
    display(gmcp.Char.Skills)
  else
    boop.util.echo("debug skills dump | display() not available")
  end
end
