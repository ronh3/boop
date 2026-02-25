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

local function cycleTargetingMode(step)
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
  boop.ui.config()
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

  if not db or not db.get_database then
    boop.util.echo("foxhunt import failed: Mudlet DB unavailable.")
    return
  end

  local foxDb = db:get_database("hunting")
  if not foxDb then
    boop.util.echo("foxhunt import failed: DB `hunting` not found. " .. dbLocationHint("hunting"))
    return
  end
  if not foxDb.whitelist or not foxDb.blacklist then
    boop.util.echo("foxhunt import failed: DB `hunting` missing whitelist/blacklist tables.")
    return
  end

  local fhWhitelist, wlErr = loadFoxhuntListMap(foxDb.whitelist, "whitelist")
  if wlErr then
    boop.util.echo("foxhunt import failed: " .. wlErr)
    return
  end
  local fhBlacklist, blErr = loadFoxhuntListMap(foxDb.blacklist, "blacklist")
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

local function helpTopicLinks()
  local topics = { "targeting", "whitelist", "blacklist", "ragemode", "queueing", "prequeue", "gold", "pack", "import", "diag", "trace", "setget", "ih", "aff", "trip", "debug", "config" }
  if cecho and cechoLink then
    cecho("\n<white>  topics: ")
    for _, topic in ipairs(topics) do
      local t = topic
      cechoLink("<cyan>[" .. t .. "]<reset>", function() boop.ui.help(t) end, "Show boop help for " .. t, true)
      cecho(" ")
    end
    return
  end
  boop.util.echo("topics: targeting | whitelist | blacklist | ragemode | queueing | prequeue | gold | pack | import | diag | trace | setget | ih | aff | trip | debug | config")
end

function boop.ui.help(topic)
  local t = boop.util.safeLower(boop.util.trim(topic or ""))

  if t == "" or t == "main" or t == "general" then
    if cecho then
      local row = 1
      uiPrintHeader("boop > help")

      uiPrintSection("core")
      uiPrintRow(row, "Hunting status", boop.config.enabled and "ON" or "OFF", boolColor(boop.config.enabled), function() boop.ui.toggle(); boop.ui.help("main") end, "Toggle boop hunting")
      row = row + 1
      uiPrintRow(row, "Show status line", "SHOW", "cyan", function() boop.ui.status("status") end, "Show boop status")
      row = row + 1
      uiPrintRow(row, "Open config dashboard", "OPEN", "green", function() boop.ui.config() end, "Open boop config")
      row = row + 1
      uiPrintRow(row, "List config keys", "SHOW", "cyan", function() boop.ui.listConfigValues() end, "Show boop get output")
      row = row + 1
      uiPrintRow(row, "Set config key", "SET", "yellow", function() uiSetCommandLine("boop set ") end, "Fill command line with boop set")
      row = row + 1

      uiPrintSection("targeting")
      uiPrintRow(row, "Targeting mode", tostring(boop.config.targetingMode or "auto"), "cyan", function() uiSetCommandLine("boop targeting ") end, "Set targeting mode")
      row = row + 1
      uiPrintRow(row, "Whitelist manager", "OPEN", "green", function() boop.targets.displayWhitelist() end, "Open whitelist manager")
      row = row + 1
      uiPrintRow(row, "Blacklist manager", "OPEN", "green", function() boop.targets.displayBlacklist() end, "Open blacklist manager")
      row = row + 1

      uiPrintSection("combat / loot")
      uiPrintRow(row, "Auto gold pickup", boop.config.autoGrabGold and "ON" or "OFF", boolColor(not not boop.config.autoGrabGold), function() boop.ui.toggleAutoGrabGold(); boop.ui.help("main") end, "Toggle automatic gold pickup")
      row = row + 1
      uiPrintRow(row, "Gold pack container", "SET", "yellow", function() uiSetCommandLine("boop pack ") end, "Set boop pack container")
      row = row + 1
      uiPrintRow(row, "Foxhunt import", "RUN", "yellow", function() uiSetCommandLine("boop import foxhunt ") end, "Run foxhunt import")
      row = row + 1
      uiPrintRow(row, "Rage mode", "SET", "yellow", function() uiSetCommandLine("boop ragemode ") end, "Set rage mode")
      row = row + 1
      uiPrintRow(row, "Run diag", "RUN", "yellow", function() boop.ui.diag() end, "Queue diagnose and pause attacks")
      row = row + 1

      uiPrintSection("timing / debug")
      uiPrintRow(row, "Prequeue", boop.config.prequeueEnabled and "ON" or "OFF", boolColor(not not boop.config.prequeueEnabled), function() boop.ui.setPrequeueEnabled(not boop.config.prequeueEnabled); boop.ui.help("main") end, "Toggle prequeue")
      row = row + 1
      uiPrintRow(row, "Attack lead", "SET", "yellow", function() uiSetCommandLine("boop lead ") end, "Set prequeue lead seconds")
      row = row + 1
      uiPrintRow(row, "Trace logging", boop.config.traceEnabled and "ON" or "OFF", boolColor(not not boop.config.traceEnabled), function() boop.ui.setTraceEnabled(not boop.config.traceEnabled); boop.ui.help("main") end, "Toggle trace logging")
      row = row + 1
      uiPrintRow(row, "Debug snapshot", "SHOW", "cyan", function() boop.ui.debug() end, "Show boop debug snapshot")

      uiPrintFooter("Type: boop help (topic) | boop config | boop status")
      helpTopicLinks()
      return
    end

    boop.util.echo("Help: boop command interface")
    boop.util.echo("  Toggle hunting: bh")
    boop.util.echo("  Main controls: boop | boop on | boop off | boop status | boop config")
    boop.util.echo("  Target controls: boop targeting <manual|whitelist|blacklist|auto>")
    boop.util.echo("  List controls: boop whitelist | boop blacklist")
    boop.util.echo("  Loot controls: boop autogold [on|off]")
    boop.util.echo("  Gold pack: boop pack [container|off|test]")
    boop.util.echo("  Import: boop import foxhunt [merge|overwrite|dryrun]")
    boop.util.echo("  Queue controls: boop prequeue [on|off] | boop lead <seconds>")
    boop.util.echo("  Config io: boop get [key] | boop set <key> <value>")
    boop.util.echo("  Combat controls: boop ragemode <simple|dam|big|small|aff|cond|buff|pool|none>")
    boop.util.echo("  Other: diag | boop trace ... | boop ih | boop aff | boop trip start/stop | boop debug")
    boop.util.echo("Use: boop help <topic>")
    helpTopicLinks()
    return
  end

  if t == "topics" or t == "topic" then
    boop.util.echo("Help topics:")
    helpTopicLinks()
    return
  end

  if t == "targeting" then
    boop.util.echo("Help: targeting")
    boop.util.echo("  boop targeting manual      -> keep your current manual target")
    boop.util.echo("  boop targeting whitelist   -> only attack mobs in area whitelist")
    boop.util.echo("  boop targeting blacklist   -> attack anything not blacklisted")
    boop.util.echo("  boop targeting auto        -> attack any valid denizen")
    boop.util.echo("  boop config -> quick clickable mode switch")
    return
  end

  if t == "whitelist" then
    boop.util.echo("Help: whitelist")
    boop.util.echo("  boop whitelist")
    boop.util.echo("  boop whitelist add <name>")
    boop.util.echo("  boop whitelist remove <name>")
    boop.util.echo("Notes:")
    boop.util.echo("  In the whitelist display, each entry has clickable [up] [down] [remove].")
    boop.util.echo("  Priority order is used when whitelistPriorityOrder is ON (see boop config).")
    return
  end

  if t == "blacklist" then
    boop.util.echo("Help: blacklist")
    boop.util.echo("  boop blacklist")
    boop.util.echo("  boop blacklist add <name>")
    boop.util.echo("  boop blacklist remove <name>")
    boop.util.echo("Notes:")
    boop.util.echo("  In the blacklist display, each entry has clickable [up] [down] [remove].")
    boop.util.echo("  Blacklist mode attacks valid denizens except blacklisted entries.")
    return
  end

  if t == "ragemode" or t == "rage" or t == "attackmode" then
    boop.util.echo("Help: ragemode")
    boop.util.echo("  boop ragemode <simple|dam|big|small|aff|cond|buff|pool|none>")
    boop.util.echo("Examples:")
    boop.util.echo("  boop ragemode simple")
    boop.util.echo("  boop ragemode big")
    boop.util.echo("  boop ragemode none")
    return
  end

  if t == "queue" or t == "queueing" then
    boop.util.echo("Help: queueing")
    boop.util.echo("  Toggle in: boop config -> use queueing")
    boop.util.echo("When ON: normal standard attacks are queued via BOOP_ATTACK alias.")
    boop.util.echo("When OFF: normal standard attacks are sent directly.")
    boop.util.echo("Prequeue is controlled separately (boop prequeue, boop lead).")
    boop.util.echo("Optimization: boop skips redundant setalias when action is unchanged.")
    boop.util.echo("Rage actions are still sent directly.")
    return
  end

  if t == "prequeue" or t == "lead" then
    boop.util.echo("Help: prequeue")
    boop.util.echo("  boop prequeue")
    boop.util.echo("  boop prequeue on")
    boop.util.echo("  boop prequeue off")
    boop.util.echo("  boop lead <seconds>")
    boop.util.echo("Prequeue schedules standard attack queueing before recovery using Balance/Equilibrium used lines.")
    boop.util.echo("Lead controls how early the prequeue fires (default 1.00).")
    return
  end

  if t == "gold" or t == "autogold" or t == "loot" then
    boop.util.echo("Help: auto gold pickup")
    boop.util.echo("  boop autogold")
    boop.util.echo("  boop autogold on")
    boop.util.echo("  boop autogold off")
    boop.util.echo("  boop pack <container>  (optional auto-stash target)")
    boop.util.echo("  boop pack off")
    boop.util.echo("  boop pack test")
    boop.util.echo("When enabled, boop auto-picks up newly dropped gold sovereign items in room.")
    boop.util.echo("In queueing mode, this is prepended to the next standard attack as: get sovereigns/<attack>.")
    boop.util.echo("If gold pack is set, boop adds: put sovereigns in <container>.")
    boop.util.echo("If no standard attack is sent quickly, boop falls back to queued get/put commands.")
    return
  end

  if t == "pack" or t == "goldpack" then
    boop.util.echo("Help: gold pack")
    boop.util.echo("  boop pack")
    boop.util.echo("  boop pack <container>")
    boop.util.echo("  boop pack off")
    boop.util.echo("  boop pack test")
    boop.util.echo("Sets optional container for auto-stashing sovereigns after pickup.")
    return
  end

  if t == "import" or t == "foxhunt" then
    boop.util.echo("Help: foxhunt import")
    boop.util.echo("  boop import foxhunt")
    boop.util.echo("  boop import foxhunt merge")
    boop.util.echo("  boop import foxhunt overwrite")
    boop.util.echo("  boop import foxhunt dryrun")
    boop.util.echo("merge: replace boop list data for imported Foxhunt areas, keep other boop areas.")
    boop.util.echo("overwrite: clear boop lists first, then import all Foxhunt areas.")
    boop.util.echo("dryrun: report counts only; no changes.")
    return
  end

  if t == "diag" or t == "diagnose" then
    boop.util.echo("Help: diag")
    boop.util.echo("  diag")
    boop.util.echo("Clears queue, queues diagnose next, and pauses boop attacks.")
    boop.util.echo("Attacking resumes after a diagnose result line and the next prompt.")
    boop.util.echo("Timeout fallback uses diagTimeoutSeconds (see boop set/get).")
    return
  end

  if t == "trace" then
    boop.util.echo("Help: trace")
    boop.util.echo("  boop trace")
    boop.util.echo("  boop trace on")
    boop.util.echo("  boop trace off")
    boop.util.echo("  boop trace show [n]")
    boop.util.echo("  boop trace clear")
    boop.util.echo("Tracks recent boop decisions/commands for debugging.")
    return
  end

  if t == "setget" or t == "set" or t == "get" then
    boop.util.echo("Help: config set/get")
    boop.util.echo("  boop get")
    boop.util.echo("  boop get <key>")
    boop.util.echo("  boop set <key> <value>")
    boop.util.echo("Examples:")
    boop.util.echo("  boop set prequeue off")
    boop.util.echo("  boop set lead 0.8")
    boop.util.echo("  boop set pack satchel")
    boop.util.echo("  boop get diagtimeout")
    return
  end

  if t == "ih" then
    boop.util.echo("Help: ih integration")
    boop.util.echo("  ih (overridden) or boop ih")
    boop.util.echo("Shows room items and denizens.")
    boop.util.echo("Denizens get clickable [+whitelist]/[-whitelist]/[+blacklist] actions.")
    return
  end

  if t == "aff" or t == "afflictions" then
    boop.util.echo("Help: aff target list")
    boop.util.echo("  boop aff")
    boop.util.echo("  boop aff add <a/b/c>")
    boop.util.echo("  boop aff remove <a/b/c>")
    boop.util.echo("  boop aff clear")
    return
  end

  if t == "trip" or t == "stats" then
    boop.util.echo("Help: trip/stats")
    boop.util.echo("  boop trip start")
    boop.util.echo("  boop trip stop")
    boop.util.echo("Tracks trip/session/lifetime gains from GMCP status updates.")
    return
  end

  if t == "debug" then
    boop.util.echo("Help: debug")
    boop.util.echo("  boop debug")
    boop.util.echo("  boop debug attacks")
    boop.util.echo("  boop debug skills")
    boop.util.echo("  boop debug skills dump")
    return
  end

  if t == "config" then
    boop.util.echo("Help: config dashboard")
    boop.util.echo("  boop config")
    boop.util.echo("Clickable controls for enable, targeting mode, queueing,")
    boop.util.echo("whitelist priority order and target order.")
    boop.util.echo("Includes quick links into whitelist/blacklist managers.")
    return
  end

  boop.util.echo("Unknown help topic: " .. tostring(topic))
  boop.util.echo("Use: boop help topics")
  helpTopicLinks()
end

function boop.ui.home()
  boop.ui.status("status")
  boop.ui.help("main")
end

function boop.ui.toggleConfigBool(key)
  local value = boop.config[key]
  if type(value) ~= "boolean" then
    boop.util.echo("Config key is not boolean: " .. tostring(key))
    return
  end
  saveConfigValue(key, not value)
  boop.ui.config()
end

function boop.ui.cycleTargetOrder(step)
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
  boop.ui.config()
end

function boop.ui.config()
  local class = currentClass()

  if cecho then
    local row = 1
    local lead = tonumber(boop.config.attackLeadSeconds) or 0
    local diagTimeout = tonumber(boop.config.diagTimeoutSeconds) or 0
    local pack = boop.util.trim(boop.config.goldPack or "")
    local shownPack = pack ~= "" and pack or "(off)"

    uiPrintHeader("configuration > boop")

    uiPrintSection("targeting")
    uiPrintRow(row, "Hunting enabled", boolText(boop.config.enabled), boolColor(boop.config.enabled), function()
      boop.ui.setEnabled(not boop.config.enabled, true)
      boop.ui.config()
    end, "Toggle boop on/off")
    row = row + 1
    uiPrintRow(row, "Targeting mode", boop.config.targetingMode or "whitelist", "cyan", function()
      cycleTargetingMode(1)
    end, "Cycle targeting mode")
    row = row + 1
    uiPrintRow(row, "Whitelist priority order", boolText(boop.config.whitelistPriorityOrder), boolColor(boop.config.whitelistPriorityOrder), function()
      boop.ui.toggleConfigBool("whitelistPriorityOrder")
    end, "Toggle whitelist priority order")
    row = row + 1
    uiPrintRow(row, "Target order", boop.config.targetOrder or "order", "cyan", function()
      boop.ui.cycleTargetOrder(1)
    end, "Cycle target order")
    row = row + 1

    uiPrintSection("queueing")
    uiPrintRow(row, "Use queueing", boolText(not not boop.config.useQueueing), boolColor(not not boop.config.useQueueing), function()
      boop.ui.toggleConfigBool("useQueueing")
    end, "Toggle queueing mode")
    row = row + 1
    uiPrintRow(row, "Prequeue", boolText(not not boop.config.prequeueEnabled), boolColor(not not boop.config.prequeueEnabled), function()
      boop.ui.setPrequeueEnabled(not boop.config.prequeueEnabled)
      boop.ui.config()
    end, "Toggle prequeue mode")
    row = row + 1
    uiPrintRow(row, string.format("Attack lead (%.2fs)", lead), "SET", "yellow", function()
      uiSetCommandLine("boop lead ")
    end, "Fill command line with boop lead")
    row = row + 1
    uiPrintRow(row, string.format("Diag timeout (%.2fs)", diagTimeout), "SET", "yellow", function()
      uiSetCommandLine("boop set diagtimeout ")
    end, "Fill command line with boop set diagtimeout")
    row = row + 1

    uiPrintSection("loot")
    uiPrintRow(row, "Auto grab gold", boolText(not not boop.config.autoGrabGold), boolColor(not not boop.config.autoGrabGold), function()
      boop.ui.toggleAutoGrabGold()
      boop.ui.config()
    end, "Toggle auto pickup of dropped gold")
    row = row + 1
    uiPrintRow(row, "Gold pack: " .. shownPack, "SET", "yellow", function()
      uiSetCommandLine("boop pack ")
    end, "Fill command line with boop pack")
    row = row + 1
    if pack ~= "" then
      uiPrintRow(row, "Clear gold pack", "OFF", "red", function()
        boop.ui.setGoldPack("")
        boop.ui.config()
      end, "Disable gold pack auto-stash")
      row = row + 1
    end

    uiPrintSection("combat / debug")
    uiPrintRow(row, "Rage mode: " .. tostring(boop.config.attackMode or "simple"), "SET", "yellow", function()
      uiSetCommandLine("boop ragemode ")
    end, "Fill command line with boop ragemode")
    row = row + 1
    uiPrintRow(row, "Trace logging", boolText(not not boop.config.traceEnabled), boolColor(not not boop.config.traceEnabled), function()
      boop.ui.setTraceEnabled(not boop.config.traceEnabled)
      boop.ui.config()
    end, "Toggle trace logging")
    row = row + 1
    uiPrintRow(row, "Whitelist manager", "OPEN", "green", function()
      boop.targets.displayWhitelist()
    end, "Show whitelist manager")
    row = row + 1
    uiPrintRow(row, "Blacklist manager", "OPEN", "green", function()
      boop.targets.displayBlacklist()
    end, "Show blacklist manager")

    uiPrintFooter("Type: boop set <key> <value> | boop get [key] | boop help config")
    return
  end

  boop.util.echo("Config for " .. tostring(class) .. ":")
  boop.util.echo("  enabled: " .. tostring(boop.config.enabled))
  boop.util.echo("  targeting: " .. tostring(boop.config.targetingMode))
  boop.util.echo("  whitelistPriorityOrder: " .. tostring(boop.config.whitelistPriorityOrder))
  boop.util.echo("  useQueueing: " .. tostring(boop.config.useQueueing))
  boop.util.echo("  prequeueEnabled: " .. tostring(boop.config.prequeueEnabled))
  boop.util.echo("  attackLeadSeconds: " .. tostring(boop.config.attackLeadSeconds))
  boop.util.echo("  autoGrabGold: " .. tostring(boop.config.autoGrabGold))
  boop.util.echo("  goldPack: " .. tostring(boop.config.goldPack or ""))
  boop.util.echo("  traceEnabled: " .. tostring(boop.config.traceEnabled))
  boop.util.echo("  diagTimeoutSeconds: " .. tostring(boop.config.diagTimeoutSeconds))
  boop.util.echo("  targetOrder: " .. tostring(boop.config.targetOrder))
  boop.util.echo("  ragemode: " .. tostring(boop.config.attackMode))
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
