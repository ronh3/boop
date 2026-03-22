boop.ui = boop.ui or {}

local function saveConfigValue(key, value)
  boop.config[key] = value
  if key == "partySize" then
    if boop.db and boop.db.deleteConfig then
      boop.db.deleteConfig(key)
    end
    return
  end
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

local function assistLeader()
  return boop.util.trim(boop.config.assistLeader or "")
end

local function themeTags()
  if boop.theme and boop.theme.tags then
    return boop.theme.tags()
  end
  return {
    accent = "<cyan>",
    border = "<grey>",
    text = "<white>",
    muted = "<light_grey>",
    ok = "<green>",
    warn = "<yellow>",
    err = "<red>",
    info = "<cyan>",
    dim = "<dark_grey>",
    reset = "<reset>",
  }
end

local function semanticTag(name)
  local theme = themeTags()
  local key = tostring(name or "")
  if theme[key] then
    return theme[key]
  end
  if key ~= "" then
    return "<" .. key .. ">"
  end
  return theme.text
end

local function assistStatusText()
  local leader = assistLeader()
  if boop.config.assistEnabled and leader ~= "" then
    return "ON -> " .. leader
  end
  if leader ~= "" then
    return "OFF -> " .. leader
  end
  return "OFF"
end

local function partyRosterMembers()
  local raw = boop.util.trim(boop.config.partyRoster or "")
  local out = {}
  if raw == "" then
    return out
  end
  for part in raw:gmatch("([^,]+)") do
    local v = boop.util.trim(part)
    if v ~= "" then
      out[#out + 1] = v
    end
  end
  return out
end

local UI_RULE_WIDTH = 56
local UI_LABEL_COL_WIDTH = 40

local function uiIndexPrefix(index)
  if index == nil then
    return ""
  end
  return string.format("[%d] ", tonumber(index) or 0)
end

local function uiPadRight(text, width)
  text = tostring(text or "")
  if #text >= width then
    return text
  end
  return text .. string.rep(" ", width - #text)
end

local function uiRule()
  return string.rep("-", UI_RULE_WIDTH)
end

local function uiButtonLabel(value)
  return "[ " .. boop.util.trim(tostring(value or "")) .. " ]"
end

local function footerSeedCommand(text)
  local trimmed = boop.util.trim(tostring(text or ""))
  if trimmed == "" then
    return ""
  end
  local boopStart = trimmed:find("boop ", 1, true)
  if not boopStart then
    return ""
  end
  local command = boop.util.trim(trimmed:sub(boopStart))
  if command == "" then
    return ""
  end
  command = command:gsub("%s*<[^>]+>", "")
  command = command:gsub("%s+$", "")
  return boop.util.trim(command)
end

local function footerClickableParts(text)
  local raw = tostring(text or "")
  local parts = {}
  local segments = {}
  local cursor = 1
  while cursor <= #raw do
    local sepStart, sepEnd = raw:find(" | ", cursor, true)
    if not sepStart then
      segments[#segments + 1] = raw:sub(cursor)
      break
    end
    segments[#segments + 1] = raw:sub(cursor, sepStart - 1)
    cursor = sepEnd + 1
  end
  if #segments == 0 and raw ~= "" then
    segments[1] = raw
  end

  for i, segment in ipairs(segments) do
    local piece = tostring(segment or "")
    local seed = footerSeedCommand(piece)
    local boopStart = piece:find("boop ", 1, true)
    local prefix = ""
    local commandText = boop.util.trim(piece)
    if boopStart and boopStart > 1 then
      prefix = piece:sub(1, boopStart - 1)
      commandText = boop.util.trim(piece:sub(boopStart))
    end
    parts[#parts + 1] = {
      prefix = prefix,
      command = commandText,
      seed = seed,
      separator = (i < #segments) and " | " or "",
    }
  end
  return parts
end

local function uiComputeLabelWidth(rows, minWidth, maxWidth)
  local width = tonumber(minWidth) or UI_LABEL_COL_WIDTH
  local hardMax = tonumber(maxWidth) or 140
  for _, row in ipairs(rows or {}) do
    local label = tostring((row and row.label) or "")
    local index = row and row.index or nil
    local total = #(uiIndexPrefix(index) .. label)
    if total > width then
      width = total
    end
  end
  if width > hardMax then
    width = hardMax
  end
  return width
end

local function uiSetCommandLine(prefix)
  if not appendCmdLine then return end
  if clearCmdLine then clearCmdLine() end
  appendCmdLine(prefix or "")
end

local uiPrintHeader
local uiPrintSection
local uiPrintRow
local uiPrintFooter

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

local function activeThemeLabel()
  if not boop.theme or not boop.theme.resolve_name then
    return "default"
  end
  return tostring(boop.theme.resolve_name() or "default")
end

local function themeDisplayName(name)
  local label = tostring(name or "")
  if label == "" then
    return "Default"
  end
  label = label:gsub("_", " ")
  return label:gsub("(%a)([%w']*)", function(a, b)
    return a:upper() .. b:lower()
  end)
end

local function renderThemeSampleRow(name)
  local sample = boop.theme and boop.theme.tagsFor and boop.theme.tagsFor(name) or themeTags()
  cecho("\n" .. sample.border .. "[" .. sample.accent .. "##" .. sample.border .. "] " .. sample.reset)
  cecho(sample.text .. string.format("%-14s", themeDisplayName(name)) .. sample.reset)
  cecho(" ")
  cecho(sample.accent .. "A" .. sample.reset .. " ")
  cecho(sample.border .. "B" .. sample.reset .. " ")
  cecho(sample.text .. "T" .. sample.reset .. " ")
  cecho(sample.muted .. "M" .. sample.reset)
  cecho(" ")
  cechoLink(semanticTag("info") .. "[use]" .. sample.reset, function()
    boop.ui.themeCommand(name)
  end, "Apply theme", true)
end

local function renderThemeSamples()
  local configured = boop.util.trim(boop.config and boop.config.uiTheme or "")
  uiPrintHeader("theme samples")
  if configured == "" then
    boop.util.echo("Current: auto (" .. activeThemeLabel() .. ")")
  else
    boop.util.echo("Current: " .. configured)
  end

  cecho("\n")
  cechoLink(semanticTag("info") .. "[auto]" .. semanticTag("reset"), function()
    boop.ui.themeCommand("auto")
  end, "Use automatic class theme", true)
  cecho(semanticTag("text") .. " Follow the current class theme." .. semanticTag("reset"))

  local categories = (boop.theme and boop.theme.categories and boop.theme.categories()) or {}
  for _, category in ipairs(categories) do
    uiPrintSection(category.label)
    for _, name in ipairs(category.names or {}) do
      renderThemeSampleRow(name)
    end
  end
end

local function operatingModeLabel()
  local mode = "solo"
  if boop.config.targetCall then
    mode = "leader-call"
  elseif boop.config.autoTargetCall then
    mode = "leader"
  elseif boop.config.assistEnabled and assistLeader() ~= "" then
    mode = "assist"
  end
  if boop.walk and boop.walk.isActive and boop.walk.isActive() then
    mode = mode .. " + walk"
  end
  return mode
end

local function currentBlocker()
  if not boop.config.enabled then
    return "boop disabled", "boop on"
  end
  if boop.state and boop.state.diagHold then
    return "diagnose pause active", "wait for diag or use diag"
  end
  if boop.state and boop.state.fleeing then
    return "flee in progress", "let flee resolve"
  end
  if boop.state and (boop.state.autoGrabGoldPending or boop.state.goldGetPending or boop.state.goldPutPending) then
    return "loot handling pending", "wait for gold queue"
  end
  if boop.targets and boop.targets.waitingForTargetCall and boop.targets.waitingForTargetCall() then
    return "waiting for leader target call", "wait for pt target line"
  end
  if boop.walk and boop.walk.isActive and boop.walk.isActive() and boop.walk.blockedReason then
    local reason = boop.walk.blockedReason()
    if reason and reason ~= "" and reason ~= "walk is not active" then
      if reason == "room has not settled yet" then
        return reason, "wait for room gmcp"
      end
      if reason == "room still has a valid target" or reason == "current target still set" then
        return "engaged target", "let boop clear the room"
      end
      if reason == "move already queued" then
        return reason, "wait for movement"
      end
      return reason, "boop walk status"
    end
  end
  local targetId = tostring(boop.state and boop.state.currentTargetId or "")
  if targetId ~= "" then
    return "engaged target", "let boop attack"
  end
  local denizenCount = boop.state and boop.state.denizens and #boop.state.denizens or 0
  if denizenCount <= 0 then
    if boop.walk and boop.walk.isActive and boop.walk.isActive() then
      return "room clear", "autowalk should advance"
    end
    if boop.walk and boop.walk.isAvailable and not boop.walk.isAvailable() then
      return "walk package missing", "boop walk install"
    end
    return "room clear", "boop walk start"
  end
  return "ready", "let boop attack"
end

local function walkStatusLabel()
  if boop.walk and boop.walk.isAvailable and not boop.walk.isAvailable() then
    return "INSTALL"
  end
  if boop.walk and boop.walk.isActive and boop.walk.isActive() then
    return "ON"
  end
  return "OFF"
end

local function renderStatusDashboard()
  local class = currentClass()
  local lead = tonumber(boop.config.attackLeadSeconds) or 0
  local diagTimeout = tonumber(boop.config.diagTimeoutSeconds) or 0
  local tempoWindow = tonumber(boop.config.tempoRageWindowSeconds) or 10
  local tempoEta = tonumber(boop.config.tempoSqueezeEtaSeconds) or 2.5
  local pack = boop.util.trim(boop.config.goldPack or "")
  local partySize = tonumber(boop.config.partySize) or 1
  if partySize < 1 then partySize = 1 end
  local partyRaw = boop.util.trim(boop.config.partyRoster or "")
  local partyCount = 0
  for _ in partyRaw:gmatch("([^,]+)") do
    partyCount = partyCount + 1
  end
  local shownPack = pack ~= "" and pack or "(off)"
  local denizenCount = boop.state and boop.state.denizens and #boop.state.denizens or 0
  local targetId = boop.state and boop.state.currentTargetId or ""
  local targetName = boop.state and boop.state.targetName or ""
  local targetShown = targetId ~= "" and targetId or "(none)"
  local targetNameShown = targetName ~= "" and targetName or "(none)"
  local assistShown = assistStatusText()
  local calledTargetShown = tostring((boop.state and boop.state.calledTargetId) or "")
  local modeShown = operatingModeLabel()
  local themeShown = activeThemeLabel()
  local blocker, nextAction = currentBlocker()
  local walkShown = "IDLE"
  if boop.walk and boop.walk.isAvailable and not boop.walk.isAvailable() then
    walkShown = "INSTALL"
  elseif boop.walk and boop.walk.isActive and boop.walk.isActive() then
    walkShown = "ACTIVE"
  end
  if calledTargetShown == "" then calledTargetShown = "(none)" end

  if cecho then
    local row = 1
    uiPrintHeader("boop > status")

    uiPrintSection("core")
    uiPrintRow(row, "Enabled", boolText(boop.config.enabled), boolColor(boop.config.enabled))
    row = row + 1
    uiPrintRow(row, "Class", tostring(class), "cyan")
    row = row + 1
    uiPrintRow(row, "Operating mode", modeShown, "yellow")
    row = row + 1
    uiPrintRow(row, "Theme", themeShown, "cyan")
    row = row + 1
    uiPrintRow(row, "Walk", walkShown, walkShown == "ACTIVE" and "green" or (walkShown == "INSTALL" and "red" or "yellow"))
    row = row + 1
    uiPrintRow(row, "Party size", tostring(partySize), "cyan")
    row = row + 1
    uiPrintRow(row, "Party members", tostring(partyCount), "cyan")
    row = row + 1
    uiPrintRow(row, "Assist", assistShown, boop.config.assistEnabled and "green" or "yellow")
    row = row + 1
    uiPrintRow(row, "Targeting mode", tostring(boop.config.targetingMode or "whitelist"), "cyan")
    row = row + 1
    uiPrintRow(row, "Leader target gate", boolText(not not boop.config.targetCall), boolColor(not not boop.config.targetCall))
    row = row + 1
    uiPrintRow(row, "Called target id", calledTargetShown, "cyan")
    row = row + 1
    uiPrintRow(row, "Current target id", tostring(targetShown), "cyan")
    row = row + 1
    uiPrintRow(row, "Current target name", tostring(targetNameShown), "cyan")
    row = row + 1
    uiPrintRow(row, "Room denizens", tostring(denizenCount), "cyan")
    row = row + 1
    uiPrintRow(row, "Blocker", blocker, blocker == "ready" and "green" or "yellow")
    row = row + 1
    uiPrintRow(row, "Next action", nextAction, "cyan")
    row = row + 1

    uiPrintSection("queueing")
    uiPrintRow(row, "Use queueing", boolText(not not boop.config.useQueueing), boolColor(not not boop.config.useQueueing))
    row = row + 1
    uiPrintRow(row, "Prequeue", boolText(not not boop.config.prequeueEnabled), boolColor(not not boop.config.prequeueEnabled))
    row = row + 1
    uiPrintRow(row, "Attack lead", string.format("%.2fs", lead), "yellow")
    row = row + 1
    uiPrintRow(row, "Diag timeout", string.format("%.2fs", diagTimeout), "yellow")
    row = row + 1

    uiPrintSection("combat / loot")
    uiPrintRow(row, "Ragemode", tostring(boop.config.attackMode or "simple"), "cyan")
    row = row + 1
    uiPrintRow(row, "Tempo window", string.format("%.1fs", tempoWindow), "yellow")
    row = row + 1
    uiPrintRow(row, "Tempo squeeze ETA", string.format("%.2fs", tempoEta), "yellow")
    row = row + 1
    uiPrintRow(row, "Rage aff calls", boolText(not not boop.config.rageAffCalloutsEnabled), boolColor(not not boop.config.rageAffCalloutsEnabled))
    row = row + 1
    uiPrintRow(row, "Auto gold", boolText(not not boop.config.autoGrabGold), boolColor(not not boop.config.autoGrabGold))
    row = row + 1
    uiPrintRow(row, "Gold pack", tostring(shownPack), "cyan")
    row = row + 1
    uiPrintRow(row, "Whitelist priority", boolText(not not boop.config.whitelistPriorityOrder), boolColor(not not boop.config.whitelistPriorityOrder))
    row = row + 1
    uiPrintRow(row, "Retarget priority", boolText(not not boop.config.retargetOnPriority), boolColor(not not boop.config.retargetOnPriority))
    row = row + 1
    uiPrintRow(row, "Target order", tostring(boop.config.targetOrder or "order"), "cyan")
    row = row + 1
    uiPrintRow(row, "Trace logging", boolText(not not boop.config.traceEnabled), boolColor(not not boop.config.traceEnabled))
    row = row + 1
    uiPrintRow(row, "Gag own attacks", boolText(not not boop.config.gagOwnAttacks), boolColor(not not boop.config.gagOwnAttacks))
    row = row + 1
    uiPrintRow(row, "Gag others attacks", boolText(not not boop.config.gagOthersAttacks), boolColor(not not boop.config.gagOthersAttacks))

    uiPrintFooter("Type: boop config | boop help | boop get")
    return
  end

  boop.util.echo("Status > boop")
  boop.util.echo("  enabled: " .. tostring(boop.config.enabled))
  boop.util.echo("  class: " .. tostring(class))
  boop.util.echo("  mode: " .. tostring(modeShown))
  boop.util.echo("  theme: " .. tostring(themeShown))
  boop.util.echo("  walk: " .. tostring(walkShown))
  boop.util.echo("  partySize: " .. tostring(partySize))
  boop.util.echo("  partyMembers: " .. tostring(partyCount))
  boop.util.echo("  assist: " .. assistShown)
  boop.util.echo("  targetingMode: " .. tostring(boop.config.targetingMode))
  boop.util.echo("  targetCall: " .. tostring(boop.config.targetCall))
  boop.util.echo("  calledTargetId: " .. tostring(calledTargetShown))
  boop.util.echo("  currentTargetId: " .. tostring(targetShown))
  boop.util.echo("  currentTargetName: " .. tostring(targetNameShown))
  boop.util.echo("  roomDenizens: " .. tostring(denizenCount))
  boop.util.echo("  blocker: " .. tostring(blocker))
  boop.util.echo("  nextAction: " .. tostring(nextAction))
  boop.util.echo("  useQueueing: " .. tostring(boop.config.useQueueing))
  boop.util.echo("  prequeueEnabled: " .. tostring(boop.config.prequeueEnabled))
  boop.util.echo(string.format("  attackLeadSeconds: %.2f", lead))
  boop.util.echo(string.format("  diagTimeoutSeconds: %.2f", diagTimeout))
  boop.util.echo("  attackMode: " .. tostring(boop.config.attackMode))
  boop.util.echo(string.format("  tempoRageWindowSeconds: %.2f", tempoWindow))
  boop.util.echo(string.format("  tempoSqueezeEtaSeconds: %.2f", tempoEta))
  boop.util.echo("  rageAffCalloutsEnabled: " .. tostring(boop.config.rageAffCalloutsEnabled))
  boop.util.echo("  autoGrabGold: " .. tostring(boop.config.autoGrabGold))
  boop.util.echo("  goldPack: " .. tostring(shownPack))
  boop.util.echo("  whitelistPriorityOrder: " .. tostring(boop.config.whitelistPriorityOrder))
  boop.util.echo("  retargetOnPriority: " .. tostring(boop.config.retargetOnPriority))
  boop.util.echo("  targetOrder: " .. tostring(boop.config.targetOrder))
  boop.util.echo("  traceEnabled: " .. tostring(boop.config.traceEnabled))
  boop.util.echo("  gagOwnAttacks: " .. tostring(boop.config.gagOwnAttacks))
  boop.util.echo("  gagOthersAttacks: " .. tostring(boop.config.gagOthersAttacks))
end

local function renderStateSummary()
  local class = currentClass()
  local targetingMode = tostring(boop.config.targetingMode or "whitelist")
  local rageMode = tostring(boop.config.attackMode or "simple")

  if cecho then
    uiPrintHeader("boop > state")
    uiPrintSection("core")
    uiPrintRow(1, "Enabled", boolText(boop.config.enabled), boolColor(boop.config.enabled))
    uiPrintRow(2, "Class", tostring(class), "cyan")
    uiPrintRow(3, "Targeting mode", targetingMode, "cyan")
    uiPrintRow(4, "Ragemode", rageMode, "cyan")
    uiPrintFooter("Type: boop status | boop config")
    return
  end

  boop.util.echo(string.format(
    "state | enabled: %s | class: %s | targeting: %s | ragemode: %s",
    boop.config.enabled and "on" or "off",
    tostring(class),
    targetingMode,
    rageMode
  ))
end

function boop.ui.status(context)
  if boop.util.safeLower(boop.util.trim(context or "")) == "status" then
    renderStatusDashboard()
    return
  end
  local msg = boop.ui.statusLine(context)
  boop.util.echo(msg)
end

function boop.ui.controlCommand(raw)
  local cmd = boop.util.safeLower(boop.util.trim(raw or ""))
  if cmd == "status" or cmd == "show" then
    boop.ui.status("status")
    return
  end
  if cmd == "config" or cmd == "settings" then
    boop.ui.config("")
    return
  end
  if cmd == "combat" or cmd == "hunting" or cmd == "queueing" then
    boop.ui.config("combat")
    return
  end
  if cmd == "targeting" or cmd == "targets" then
    boop.ui.config("targeting")
    return
  end
  if cmd == "loot" or cmd == "gold" then
    boop.ui.config("loot")
    return
  end
  if cmd == "debug" or cmd == "diagnostics" then
    boop.ui.config("debug")
    return
  end
  if cmd == "party" then
    boop.ui.partyCommand("")
    return
  end
  if cmd == "roster" then
    boop.ui.rosterCommand("")
    return
  end
  if cmd == "stats" then
    boop.stats.command("")
    return
  end
  if cmd == "theme" then
    boop.ui.themeCommand("")
    return
  end
  if cmd == "mode" then
    boop.ui.modeCommand("")
    return
  end

  local class = currentClass()
  local targetingMode = tostring(boop.config.targetingMode or "whitelist")
  local rageMode = tostring(boop.config.attackMode or "simple")
  local enabled = boop.config.enabled and "on" or "off"
  local denizenCount = boop.state and boop.state.denizens and #boop.state.denizens or 0
  local targetId = boop.state and boop.state.currentTargetId or ""
  local targetName = boop.state and boop.state.targetName or ""
  local targetShown = targetId ~= "" and (targetId .. " | " .. (targetName ~= "" and targetName or "(unnamed)")) or "(none)"
  local trip = boop.stats and boop.stats.trip or {}
  local tripRunning = trip and trip.stopwatch and "running" or "idle"
  local tripKills = tonumber(trip and trip.kills) or 0
  local tripGold = tonumber(trip and trip.gold) or 0
  local tripXp = tonumber(trip and trip.rawExperience) or 0
  local assistShown = assistStatusText()
  local targetCallShown = boop.config.targetCall and "ON" or "OFF"
  local modeShown = operatingModeLabel()
  local themeShown = activeThemeLabel()
  local blocker, nextAction = currentBlocker()
  local walkShown = walkStatusLabel()
  local queueShown = boolText(not not boop.config.useQueueing)
  local prequeueShown = boolText(not not boop.config.prequeueEnabled)
  local partySize = tostring(tonumber(boop.config.partySize) or 1)
  local leadShown = string.format("%.2fs", tonumber(boop.config.attackLeadSeconds) or 0)

  if cecho then
    uiPrintHeader("boop > control")
    uiPrintSection("overview")
    uiPrintRow(1, "Hunting", enabled, boop.config.enabled and "green" or "red", function()
      boop.ui.setEnabled(not boop.config.enabled)
    end, "Toggle hunting on or off")
    uiPrintRow(2, "Mode", modeShown, "yellow", function() boop.ui.modeCommand("") end, "Show operating mode controls")
    uiPrintRow(3, "Blocker", blocker, blocker == "ready" and "green" or "yellow")
    uiPrintRow(4, "Next action", nextAction, "cyan")
    uiPrintRow(5, "Trip", string.format("%s | %d kills | %d gold | %d xp", tripRunning, tripKills, tripGold, tripXp), tripRunning == "running" and "green" or "yellow")

    uiPrintSection("combat controls")
    uiPrintRow(6, "Class", tostring(class), "cyan")
    uiPrintRow(7, "Targeting", targetingMode, "cyan", function() boop.ui.config("targeting") end, "Open targeting controls")
    uiPrintRow(8, "Ragemode", rageMode, "yellow", function() boop.ui.config("combat") end, "Open hunting controls")
    uiPrintRow(9, "Queueing", queueShown, boop.config.useQueueing and "green" or "yellow", function() boop.ui.config("combat") end, "Open queueing controls")
    uiPrintRow(10, "Prequeue", prequeueShown .. " | lead " .. leadShown, boop.config.prequeueEnabled and "green" or "yellow", function() boop.ui.config("combat") end, "Open prequeue controls")
    uiPrintRow(11, "Target", targetShown, "cyan")
    uiPrintRow(12, "Room denizens", tostring(denizenCount), "cyan")

    uiPrintSection("party & movement")
    uiPrintRow(13, "Assist", assistShown, boop.config.assistEnabled and "green" or "yellow", function() boop.ui.partyCommand("") end, "Open the party dashboard")
    uiPrintRow(14, "Leader target gate", targetCallShown, boop.config.targetCall and "green" or "yellow", function() boop.ui.partyCommand("") end, "Open the party dashboard")
    uiPrintRow(15, "Party size", partySize, "cyan", function() boop.ui.partyCommand("") end, "Open the party dashboard")
    uiPrintRow(16, "Walk", walkShown, walkShown == "ON" and "green" or (walkShown == "INSTALL" and "red" or "yellow"), function()
      boop.ui.walkCommand(walkShown == "INSTALL" and "install" or "")
    end, walkShown == "INSTALL" and "Install demonnicAutoWalker for walk controls" or "Open walk controls")
    uiPrintRow(17, "Theme", themeShown, "cyan", function() boop.ui.themeCommand("") end, "Open theme controls")

    uiPrintSection("navigation")
    uiPrintRow(18, "Party dashboard", "OPEN", "cyan", function() boop.ui.partyCommand("") end, "Open the party dashboard")
    uiPrintRow(19, "Roster manager", "OPEN", "cyan", function() boop.ui.rosterCommand("") end, "Open stored party roster")
    uiPrintRow(20, "Settings hub", "OPEN", "cyan", function() boop.ui.config("") end, "Open the settings hub")
    uiPrintRow(21, "Stats dashboard", "OPEN", "cyan", function() boop.stats.command("") end, "Open the stats dashboard")
    uiPrintFooter("Type: boop control config | boop control party | boop control roster | boop control stats")
    return
  end

  boop.util.echo("CONTROL DASHBOARD")
  boop.util.echo("----------------------------------------")
  boop.util.echo(string.format("State: %s | mode: %s | blocker: %s | next: %s", enabled, modeShown, blocker, nextAction))
  boop.util.echo(string.format("Combat: class %s | targeting %s | ragemode %s | queue %s | prequeue %s", tostring(class), targetingMode, rageMode, queueShown, prequeueShown))
  boop.util.echo(string.format("Party: assist %s | targetcall %s | size %s | walk %s | theme %s", assistShown, targetCallShown, partySize, walkShown, themeShown))
  boop.util.echo("Target: " .. targetShown .. " | room denizens: " .. tostring(denizenCount))
  boop.util.echo(string.format("Trip: %s | kills %d | gold %d | xp %d", tripRunning, tripKills, tripGold, tripXp))
  boop.util.echo("Quick: boop config | boop party | boop roster | boop stats | boop theme")
end

uiPrintHeader = function(title)
  if cecho then
    local theme = themeTags()
    cecho("\n" .. theme.accent .. string.upper(tostring(title or "")) .. theme.reset)
    cecho("\n" .. theme.border .. uiRule() .. theme.reset)
  else
    boop.util.echo(tostring(title) .. " | class: " .. tostring(currentClass()))
  end
end

uiPrintSection = function(title)
  if cecho then
    local theme = themeTags()
    cecho("\n\n" .. theme.info .. string.upper(tostring(title or "")) .. theme.reset)
  else
    boop.util.echo(tostring(title) .. ":")
  end
end

uiPrintRow = function(index, label, buttonText, buttonColor, onClick, hint, labelWidth)
  if cecho then
    local theme = themeTags()
    local width = tonumber(labelWidth) or UI_LABEL_COL_WIDTH
    local prefix = uiIndexPrefix(index)
    local leftRaw = prefix .. tostring(label or "")
    local left = uiPadRight(leftRaw, width)
    cecho("\n" .. theme.text .. left .. " " .. theme.reset)
    local colorTag = semanticTag(tostring(buttonColor or "text"))
    local coloredButton = colorTag .. uiButtonLabel(buttonText or "") .. theme.reset
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

uiPrintFooter = function(text)
  if cecho then
    local theme = themeTags()
    cecho("\n" .. theme.border .. uiRule() .. theme.reset)
    cecho("\n")
    local parts = footerClickableParts(text)
    if cechoLink and #parts > 0 then
      for _, part in ipairs(parts) do
        if part.prefix ~= "" then
          cecho(theme.muted .. part.prefix .. theme.reset)
        end
        if part.seed ~= "" then
          cechoLink(theme.info .. part.command .. theme.reset, function()
            uiSetCommandLine(part.seed)
          end, "Prepare command: " .. part.seed, true)
        else
          cecho(theme.muted .. part.command .. theme.reset)
        end
        if part.separator ~= "" then
          cecho(theme.muted .. part.separator .. theme.reset)
        end
      end
    else
      cecho(theme.muted .. tostring(text or "") .. theme.reset)
    end
    cecho("\n")
  else
    boop.util.echo(text or "")
  end
end

boop.ui.printHeader = uiPrintHeader
boop.ui.printSection = uiPrintSection
boop.ui.printRow = uiPrintRow
boop.ui.printFooter = uiPrintFooter
boop.ui.computeLabelWidth = uiComputeLabelWidth
boop.ui._printHeader = uiPrintHeader
boop.ui._printSection = uiPrintSection
boop.ui._printRow = uiPrintRow
boop.ui._printFooter = uiPrintFooter

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

local RAGE_MODE_OPTIONS = {
  { id = 1, key = "simple", label = "Simple", desc = "HP-aware damage selection." },
  { id = 2, key = "big", label = "Big", desc = "Pool for big hits; fallback small on cooldown." },
  { id = 3, key = "small", label = "Small", desc = "Prefer small/mid damage spenders." },
  { id = 4, key = "aff", label = "Aff", desc = "Spend rage on affliction attacks." },
  { id = 5, key = "tempo", label = "Tempo", desc = "Aff-first; squeeze damage when rage flow allows." },
  { id = 6, key = "combo", label = "Combo", desc = "Conditional-first with priming + reserve hold." },
  { id = 7, key = "hybrid", label = "Hybrid", desc = "Combo logic; fallback to damage when blocked." },
  { id = 8, key = "none", label = "None", desc = "Disable rage attacks." },
}

local function canonicalRageMode(raw)
  local mode = boop.util.safeLower(boop.util.trim(raw or ""))
  local aliases = {
    damage = "simple",
    dam = "simple",
    condition = "combo",
    conditional = "combo",
    cond = "combo",
    affplus = "tempo",
    smartaff = "tempo",
    weave = "tempo",
    pool = "none",
    buff = "aff",
  }
  return aliases[mode] or mode
end

local function rageModeById(id)
  local n = tonumber(id)
  if not n then return nil end
  for _, option in ipairs(RAGE_MODE_OPTIONS) do
    if option.id == n then
      return option
    end
  end
  return nil
end

function boop.ui.showRageModeMenu()
  local current = canonicalRageMode(boop.config.attackMode or "simple")

  if cecho then
    local rows = {}
    for _, option in ipairs(RAGE_MODE_OPTIONS) do
      rows[#rows + 1] = { index = option.id, label = option.label .. " - " .. option.desc }
    end
    local labelWidth = uiComputeLabelWidth(rows, 54, 120)

    uiPrintHeader("configuration > ragemode")
    uiPrintSection("modes")
    for _, option in ipairs(RAGE_MODE_OPTIONS) do
      local active = (current == option.key)
      uiPrintRow(option.id, option.label .. " - " .. option.desc, active and "ACTIVE" or "SET", active and "green" or "cyan", function()
        boop.ui.setAttackMode(tostring(option.id))
      end, "Set ragemode to " .. option.key, labelWidth)
    end
    uiPrintFooter("Type: boop ragemode <number|mode> | boop config hunting | boop help combat")
    return
  end

  boop.util.echo("CONFIGURATION > RAGEMODE")
  boop.util.echo("----------------------------------------")
  for _, option in ipairs(RAGE_MODE_OPTIONS) do
    local state = (current == option.key) and "ACTIVE" or "SET"
    boop.util.echo(string.format("[%d] %s - %s [%s]", option.id, option.label, option.desc, state))
  end
  boop.util.echo("----------------------------------------")
  boop.util.echo("Type: boop ragemode <number|mode> | boop config hunting | boop help combat")
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
  if boop.stats and boop.stats.onEnabledChanged then
    boop.stats.onEnabledChanged(boop.config.enabled)
  end
  if boop.db and boop.db.saveConfig then
    boop.db.saveConfig("enabled", boop.config.enabled)
  end
  if not quiet then
    renderStateSummary()
  end
end

function boop.ui.toggle()
  boop.ui.setEnabled(not boop.config.enabled)
end

function boop.ui.setTargetingMode(mode, quiet)
  mode = boop.util.safeLower(boop.util.trim(mode))
  if mode == "" then
    boop.util.info("targeting mode: " .. tostring(boop.config.targetingMode or "whitelist"))
    boop.util.info("Usage: boop targeting <manual|whitelist|blacklist|auto>")
    return
  end
  local aliases = {
    wl = "whitelist",
    bl = "blacklist",
  }
  mode = aliases[mode] or mode
  local valid = { manual = true, whitelist = true, blacklist = true, auto = true }
  if not valid[mode] then
    boop.util.warn("Invalid targeting mode: " .. tostring(mode))
    boop.util.info("Usage: boop targeting <manual|whitelist|blacklist|auto>")
    return
  end
  boop.config.targetingMode = mode
  if boop.db and boop.db.saveConfig then
    boop.db.saveConfig("targetingMode", boop.config.targetingMode)
  end
  if not quiet then
    boop.util.ok("targeting mode: " .. tostring(mode))
  end
end

function boop.ui.setAttackMode(mode)
  mode = boop.util.safeLower(boop.util.trim(mode))
  local chosenByNumber = false
  local optionById = rageModeById(mode)
  if optionById then
    mode = optionById.key
    chosenByNumber = true
  end

  mode = canonicalRageMode(mode)
  local valid = {
    simple = true,
    big = true,
    small = true,
    aff = true,
    tempo = true,
    combo = true,
    hybrid = true,
    none = true,
  }
  if mode == "" then
    boop.ui.showRageModeMenu()
    return
  end
  if not valid[mode] then
    boop.util.warn("Invalid ragemode: " .. tostring(mode))
    boop.util.info("Valid modes: simple, big, small, aff, tempo, combo, hybrid, none")
    boop.ui.showRageModeMenu()
    return
  end
  boop.config.attackMode = mode
  if boop.db and boop.db.saveConfig then
    boop.db.saveConfig("attackMode", boop.config.attackMode)
  end
  boop.util.ok("ragemode: " .. tostring(mode))
  if chosenByNumber then
    boop.ui.showRageModeMenu()
  end
end

function boop.ui.setRageMode(mode)
  mode = boop.util.safeLower(boop.util.trim(mode))
  boop.ui.setAttackMode(mode)
end

function boop.ui.setAutoGrabGold(value)
  saveConfigValue("autoGrabGold", value and true or false)
  boop.util.ok("auto grab sovereigns: " .. (boop.config.autoGrabGold and "on" or "off"))
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
  boop.util.ok("prequeue: " .. (boop.config.prequeueEnabled and "on" or "off"))
end

function boop.ui.showPrequeue()
  local lead = tonumber(boop.config.attackLeadSeconds) or 0
  boop.util.info(string.format("prequeue: %s | lead: %.2fs", boop.config.prequeueEnabled and "on" or "off", lead))
end

function boop.ui.setAttackLeadSeconds(raw)
  local value = tonumber(boop.util.trim(raw or ""))
  if not value or value < 0 then
    boop.util.warn("Invalid lead value: " .. tostring(raw))
    boop.util.info("Usage: boop lead <seconds> (0 or higher)")
    return
  end
  saveConfigValue("attackLeadSeconds", value)
  if boop.config.prequeueEnabled and boop.schedulePrequeue then
    boop.schedulePrequeue()
  end
  boop.util.ok(string.format("attack lead: %.2fs", value))
end

function boop.ui.setTraceEnabled(value)
  saveConfigValue("traceEnabled", value and true or false)
  boop.util.ok("trace: " .. (boop.config.traceEnabled and "on" or "off"))
end

function boop.ui.setGoldPack(value)
  local pack = boop.util.trim(value or "")
  local key = boop.util.safeLower(pack)
  if key == "off" or key == "none" or key == "clear" then
    pack = ""
  end
  saveConfigValue("goldPack", pack)
  if pack == "" then
    boop.util.ok("gold pack: (off)")
  else
    boop.util.ok("gold pack: " .. pack)
  end
end

function boop.ui.testGoldPack()
  local pack = boop.util.trim(boop.config.goldPack or "")
  if pack == "" then
    boop.util.warn("gold pack: (off)")
    boop.util.info("Set one with: boop pack <container>")
    return
  end
  send("queue add freestand look in " .. pack, false)
  boop.util.info("gold pack test queued: look in " .. pack)
end

function boop.ui.showGoldPack()
  local pack = boop.util.trim(boop.config.goldPack or "")
  if pack == "" then
    boop.util.info("gold pack: (off)")
  else
    boop.util.info("gold pack: " .. pack)
  end
end

local function queueInterrupt(label, command, opts)
  opts = opts or {}
  boop.state = boop.state or {}
  if boop.state.prequeueTimer then
    killTimer(boop.state.prequeueTimer)
    boop.state.prequeueTimer = nil
  end
  boop.state.prequeuedStandard = false
  boop.state.diagHold = true
  boop.state.diagAwaitPrompt = opts.awaitPrompt and true or false
  boop.state.diagLabel = tostring(label or "interrupt")
  boop.state.queueAliasDirty = true

  if boop.state.diagTimeoutTimer then
    killTimer(boop.state.diagTimeoutTimer)
    boop.state.diagTimeoutTimer = nil
  end

  local timeout = tonumber(boop.config.diagTimeoutSeconds) or 8
  if timeout > 0 then
    local timeoutLabel = boop.state.diagLabel
    boop.state.diagTimeoutTimer = tempTimer(timeout, function()
      boop.state.diagTimeoutTimer = nil
      if boop.state.diagHold then
        boop.state.diagHold = false
        boop.state.diagAwaitPrompt = false
        boop.state.diagLabel = ""
        boop.util.warn(timeoutLabel .. " timeout; attacks resumed")
        boop.trace.log(timeoutLabel .. " timeout resume")
      end
    end)
  end

  if opts.clearQueue then
    send("queue clear", false)
  end
  send("queue addclearfull freestand " .. command, false)
  boop.util.info(opts.infoMessage or (tostring(label) .. " queued; attacks paused"))
  boop.trace.log((opts.traceLabel or tostring(label)) .. " queued")
end

function boop.ui.diag()
  queueInterrupt("diag", "diagnose", {
    clearQueue = true,
    awaitPrompt = false,
    infoMessage = "diag queued; attacks paused until diagnose line + prompt",
  })
end

function boop.ui.matic()
  queueInterrupt("matic", "ldeck draw matic", {
    clearQueue = false,
    awaitPrompt = true,
    infoMessage = "matic queued; attacks paused until next prompt",
  })
end

function boop.ui.catarin()
  queueInterrupt("catarin", "ldeck draw catarin", {
    clearQueue = false,
    awaitPrompt = true,
    infoMessage = "catarin queued; attacks paused until next prompt",
  })
end

local function parseBool(raw)
  local value = boop.util.safeLower(boop.util.trim(raw or ""))
  if value == "on" or value == "true" or value == "1" or value == "yes" then return true end
  if value == "off" or value == "false" or value == "0" or value == "no" then return false end
  return nil
end

function boop.ui.gagCommand(raw)
  local text = boop.util.trim(raw or "")
  local token = boop.util.safeLower(text)
  if token == "" or token == "status" then
    boop.gag.showStatus()
    return
  end

  local scope, state = token:match("^(own|others|all)%s+(on|off)$")
  if scope and state then
    local enabled = (state == "on")
    if scope == "own" then
      boop.gag.setOwn(enabled)
      return
    end
    if scope == "others" then
      boop.gag.setOthers(enabled)
      return
    end
    boop.gag.setBoth(enabled)
    return
  end

  if token == "own" then
    boop.gag.setOwn(not boop.config.gagOwnAttacks)
    return
  end
  if token == "others" then
    boop.gag.setOthers(not boop.config.gagOthersAttacks)
    return
  end
  if token == "all" then
    local nextValue = not (boop.config.gagOwnAttacks and boop.config.gagOthersAttacks)
    boop.gag.setBoth(nextValue)
    return
  end
  if token == "on" then
    boop.gag.setBoth(true)
    return
  end
  if token == "off" then
    boop.gag.setBoth(false)
    return
  end

  if token == "colors" then
    boop.gag.showColors()
    return
  end

  local colorArgs = text:match("^[Cc][Oo][Ll][Oo]?[Uu]?[Rr]%s+(.+)$")
  if colorArgs then
    local lowerArgs = boop.util.safeLower(boop.util.trim(colorArgs))
    if lowerArgs == "reset" then
      boop.gag.resetColors()
      return
    end

    local role, value = colorArgs:match("^(%S+)%s+(.+)$")
    if role and value then
      boop.gag.setColor(role, value)
      return
    end

    local pickerRole = boop.util.trim(colorArgs)
    if pickerRole ~= "" and boop.gag and boop.gag.showColorPicker then
      boop.gag.showColorPicker(pickerRole)
      return
    end
  end

  boop.util.info("Usage: boop gag [status|on|off|own|others|all|<scope> on|off|colors|color <role> <color|off>|color reset]")
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
    retargetonpriority = "retargetOnPriority",
    retargetpriority = "retargetOnPriority",
    stickytarget = "retargetOnPriority",
    stickyoncurrent = "retargetOnPriority",
    targetorder = "targetOrder",
    ragemode = "attackMode",
    attackmode = "attackMode",
    trace = "traceEnabled",
    traceenabled = "traceEnabled",
    gag = "gagOwnAttacks",
    gagown = "gagOwnAttacks",
    gagownattacks = "gagOwnAttacks",
    gagothers = "gagOthersAttacks",
    gagothersattacks = "gagOthersAttacks",
    gagcolorwho = "gagColorWho",
    gagcolorability = "gagColorAbility",
    gagcolortarget = "gagColorTarget",
    gagcolormeta = "gagColorMeta",
    gagcolorseparator = "gagColorSeparator",
    gagcolorbg = "gagColorBackground",
    gagcolorbackground = "gagColorBackground",
    diagtimeout = "diagTimeoutSeconds",
    diagtimeoutseconds = "diagTimeoutSeconds",
    partysize = "partySize",
    partycount = "partySize",
    groupsize = "partySize",
    party = "partyRoster",
    partyroster = "partyRoster",
    assist = "assistEnabled",
    assistenabled = "assistEnabled",
    assistleader = "assistLeader",
    leader = "assistLeader",
    autotargetcall = "autoTargetCall",
    autocall = "autoTargetCall",
    leaderautocall = "autoTargetCall",
    leadermode = "autoTargetCall",
    leadtargets = "autoTargetCall",
    theme = "uiTheme",
    uitheme = "uiTheme",
    targetcall = "targetCall",
    leadertargetcall = "targetCall",
    affcalls = "rageAffCalloutsEnabled",
    rageaffcalls = "rageAffCalloutsEnabled",
    rageaffcallouts = "rageAffCalloutsEnabled",
    partyaffcalls = "rageAffCalloutsEnabled",
    tempowindow = "tempoRageWindowSeconds",
    temporagewindow = "tempoRageWindowSeconds",
    temporagewindowseconds = "tempoRageWindowSeconds",
    tempoeta = "tempoSqueezeEtaSeconds",
    temposqueezeeta = "tempoSqueezeEtaSeconds",
    temposqueezeetaseconds = "tempoSqueezeEtaSeconds",
  }
  return map[key] or ""
end

function boop.ui.getConfigValue(key)
  local canonical = canonConfigKey(key)
  if canonical == "" then
    boop.util.warn("Unknown key: " .. tostring(key))
    boop.util.info("Try: boop get")
    return
  end
  boop.util.info(canonical .. ": " .. tostring(boop.config[canonical]))
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
    "retargetOnPriority",
    "targetOrder",
    "attackMode",
    "tempoRageWindowSeconds",
    "tempoSqueezeEtaSeconds",
    "traceEnabled",
    "gagOwnAttacks",
    "gagOthersAttacks",
    "gagColorWho",
    "gagColorAbility",
    "gagColorTarget",
    "gagColorMeta",
    "gagColorSeparator",
    "gagColorBackground",
    "diagTimeoutSeconds",
    "partySize",
    "partyRoster",
    "targetCall",
    "autoTargetCall",
    "rageAffCalloutsEnabled",
    "assistEnabled",
    "assistLeader",
    "uiTheme",
  }
  boop.util.info("config keys:")
  for _, key in ipairs(keys) do
    boop.util.echo("  " .. key .. ": " .. tostring(boop.config[key]))
  end
end

function boop.ui.setConfigValue(key, value)
  local canonical = canonConfigKey(key)
  if canonical == "" then
    boop.util.warn("Unknown key: " .. tostring(key))
    boop.util.info("Try: boop get")
    return
  end

  if canonical == "enabled" then
    local parsed = parseBool(value)
    if parsed == nil then
      boop.util.warn("enabled expects on/off")
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
      boop.util.warn("useQueueing expects on/off")
      return
    end
    saveConfigValue("useQueueing", parsed)
    boop.util.ok("use queueing: " .. (parsed and "on" or "off"))
    return
  end

  if canonical == "prequeueEnabled" then
    local parsed = parseBool(value)
    if parsed == nil then
      boop.util.warn("prequeue expects on/off")
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
      boop.util.warn("autogold expects on/off")
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
      boop.util.warn(canonical .. " expects on/off")
      return
    end
    saveConfigValue(canonical, parsed)
    boop.util.ok(canonical .. ": " .. (parsed and "on" or "off"))
    return
  end

  if canonical == "retargetOnPriority" then
    local parsed = parseBool(value)
    if parsed == nil then
      boop.util.warn(canonical .. " expects on/off")
      return
    end
    saveConfigValue(canonical, parsed)
    boop.util.ok(canonical .. ": " .. (parsed and "on" or "off"))
    return
  end

  if canonical == "targetOrder" then
    local order = boop.util.safeLower(boop.util.trim(value or ""))
    if order ~= "order" and order ~= "numeric" and order ~= "reverse" then
      boop.util.warn("targetOrder expects order|numeric|reverse")
      return
    end
    saveConfigValue("targetOrder", order)
    boop.util.ok("targetOrder: " .. order)
    return
  end

  if canonical == "attackMode" then
    boop.ui.setRageMode(value)
    return
  end

  if canonical == "tempoRageWindowSeconds" then
    local seconds = tonumber(boop.util.trim(value or ""))
    if not seconds or seconds <= 0 then
      boop.util.warn("tempoRageWindowSeconds expects number > 0")
      return
    end
    saveConfigValue("tempoRageWindowSeconds", seconds)
    boop.util.ok(string.format("tempo rage window: %.2fs", seconds))
    return
  end

  if canonical == "tempoSqueezeEtaSeconds" then
    local seconds = tonumber(boop.util.trim(value or ""))
    if not seconds or seconds < 0 then
      boop.util.warn("tempoSqueezeEtaSeconds expects number >= 0")
      return
    end
    saveConfigValue("tempoSqueezeEtaSeconds", seconds)
    boop.util.ok(string.format("tempo squeeze eta: %.2fs", seconds))
    return
  end

  if canonical == "traceEnabled" then
    local parsed = parseBool(value)
    if parsed == nil then
      boop.util.warn("trace expects on/off")
      return
    end
    boop.ui.setTraceEnabled(parsed)
    return
  end

  if canonical == "gagOwnAttacks" then
    local parsed = parseBool(value)
    if parsed == nil then
      boop.util.warn("gagOwnAttacks expects on/off")
      return
    end
    boop.gag.setOwn(parsed)
    return
  end

  if canonical == "gagOthersAttacks" then
    local parsed = parseBool(value)
    if parsed == nil then
      boop.util.warn("gagOthersAttacks expects on/off")
      return
    end
    boop.gag.setOthers(parsed)
    return
  end

  if canonical == "gagColorWho" then
    boop.gag.setColor("who", value)
    return
  end

  if canonical == "gagColorAbility" then
    boop.gag.setColor("ability", value)
    return
  end

  if canonical == "gagColorTarget" then
    boop.gag.setColor("target", value)
    return
  end

  if canonical == "gagColorMeta" then
    boop.gag.setColor("meta", value)
    return
  end

  if canonical == "gagColorSeparator" then
    boop.gag.setColor("separator", value)
    return
  end

  if canonical == "gagColorBackground" then
    boop.gag.setColor("background", value)
    return
  end

  if canonical == "diagTimeoutSeconds" then
    local timeout = tonumber(boop.util.trim(value or ""))
    if not timeout or timeout < 0 then
      boop.util.warn("diagTimeoutSeconds expects number >= 0")
      return
    end
    saveConfigValue("diagTimeoutSeconds", timeout)
    boop.util.ok(string.format("diag timeout: %.2fs", timeout))
    return
  end

  if canonical == "partySize" then
    local size = tonumber(boop.util.trim(value or ""))
    if not size or size < 1 or size ~= math.floor(size) then
      boop.util.warn("partySize expects integer >= 1")
      return
    end
    saveConfigValue("partySize", size)
    boop.util.ok("party size: " .. tostring(size))
    return
  end

  if canonical == "partyRoster" then
    boop.ui.rosterCommand(value or "")
    return
  end

  if canonical == "targetCall" then
    local parsed = parseBool(value)
    if parsed == nil then
      boop.util.warn("targetCall expects on/off")
      return
    end
    if parsed and assistLeader() == "" then
      boop.util.warn("target call mode needs a leader; use: boop assist <name>")
      return
    end
    saveConfigValue("targetCall", parsed)
    if parsed and boop.config.autoTargetCall then
      saveConfigValue("autoTargetCall", false)
    end
    if not parsed and boop.targets and boop.targets.clearTargetCall then
      boop.targets.clearTargetCall("target call disabled")
    end
    boop.util.ok("leader target call gate: " .. (parsed and "on" or "off"))
    return
  end

  if canonical == "autoTargetCall" then
    local parsed = parseBool(value)
    if parsed == nil then
      boop.util.warn("autoTargetCall expects on/off")
      return
    end
    local hadTargetCall = not not boop.config.targetCall
    saveConfigValue("autoTargetCall", parsed)
    if parsed and hadTargetCall then
      saveConfigValue("targetCall", false)
      if boop.targets and boop.targets.clearTargetCall then
        boop.targets.clearTargetCall("auto target call enabled")
      end
    end
    boop.util.ok("auto target calls: " .. (parsed and "on" or "off"))
    return
  end

  if canonical == "assistEnabled" then
    local parsed = parseBool(value)
    if parsed == nil then
      boop.util.warn("assist expects on/off")
      return
    end
    if parsed and assistLeader() == "" then
      boop.util.warn("assist needs a leader; use: boop assist <name>")
      return
    end
    saveConfigValue("assistEnabled", parsed)
    boop.util.ok("assist: " .. (parsed and "on" or "off"))
    return
  end

  if canonical == "assistLeader" then
    local leader = boop.util.trim(value or "")
    saveConfigValue("assistLeader", leader)
    if leader == "" then
      saveConfigValue("assistEnabled", false)
      boop.util.ok("assist leader cleared")
    else
      saveConfigValue("assistEnabled", true)
      boop.util.ok("assist leader: " .. leader)
    end
    return
  end

  if canonical == "uiTheme" then
    boop.ui.themeCommand(value)
    return
  end

  if canonical == "rageAffCalloutsEnabled" then
    local parsed = parseBool(value)
    if parsed == nil then
      boop.util.warn("affcalls expects on/off")
      return
    end
    saveConfigValue("rageAffCalloutsEnabled", parsed)
    boop.util.ok("rage affliction callouts: " .. (parsed and "on" or "off"))
    return
  end
end

function boop.ui.traceCommand(sub, arg)
  local cmd = boop.util.safeLower(boop.util.trim(sub or ""))
  if cmd == "" then
    boop.util.info("trace: " .. (boop.config.traceEnabled and "on" or "off"))
    boop.util.info("boop trace on|off|show [n]|clear")
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
  boop.util.warn("trace: unknown option " .. tostring(sub))
end

function boop.ui.walkCommand(raw)
  local text = boop.util.trim(raw or "")
  local cmd = boop.util.safeLower(text)

  if cmd == "" or cmd == "status" then
    if boop.walk and boop.walk.status then
      boop.walk.status()
    end
    return
  end

  if cmd == "start" or cmd == "on" then
    if boop.walk and boop.walk.start then
      boop.walk.start()
    end
    return
  end

  if cmd == "stop" or cmd == "off" then
    if boop.walk and boop.walk.stop then
      boop.walk.stop(false, false)
    end
    return
  end

  if cmd == "move" then
    if boop.walk and boop.walk.move then
      boop.walk.move()
    end
    return
  end

  if cmd == "install" then
    if boop.walk and boop.walk.install then
      boop.walk.install()
    end
    return
  end

  boop.util.info("Usage: boop walk [status|start|stop|move|install]")
end

function boop.ui.modeCommand(raw)
  local text = boop.util.trim(raw or "")
  local cmd = boop.util.safeLower(text)

  if cmd == "" or cmd == "status" or cmd == "show" then
    local blocker, nextAction = currentBlocker()
    boop.util.info("mode: " .. operatingModeLabel())
    boop.util.info("blocker: " .. blocker)
    boop.util.info("next: " .. nextAction)
    boop.util.info("Usage: boop mode solo|assist|leader|leader-call")
    return
  end

  if cmd == "solo" then
    saveConfigValue("autoTargetCall", false)
    saveConfigValue("targetCall", false)
    if boop.targets and boop.targets.clearTargetCall then
      boop.targets.clearTargetCall("mode solo")
    end
    saveConfigValue("assistEnabled", false)
    boop.util.ok("mode: solo")
    return
  end

  if cmd == "assist" then
    local leader = assistLeader()
    if leader == "" then
      boop.util.warn("assist mode needs a leader; use: boop assist <name>")
      return
    end
    saveConfigValue("assistEnabled", true)
    saveConfigValue("autoTargetCall", false)
    saveConfigValue("targetCall", false)
    if boop.targets and boop.targets.clearTargetCall then
      boop.targets.clearTargetCall("mode assist")
    end
    boop.util.ok("mode: assist -> " .. leader)
    return
  end

  if cmd == "leader" or cmd == "leading" then
    saveConfigValue("assistEnabled", false)
    saveConfigValue("autoTargetCall", true)
    saveConfigValue("targetCall", false)
    if boop.targets and boop.targets.clearTargetCall then
      boop.targets.clearTargetCall("mode leader")
    end
    boop.util.ok("mode: leader")
    return
  end

  if cmd == "leader-call" or cmd == "leadercall" or cmd == "lead" then
    local leader = assistLeader()
    if leader == "" then
      boop.util.warn("leader-call mode needs a leader; use: boop assist <name>")
      return
    end
    saveConfigValue("assistEnabled", true)
    saveConfigValue("autoTargetCall", false)
    saveConfigValue("targetCall", true)
    boop.util.ok("mode: leader-call -> " .. leader)
    return
  end

  boop.util.warn("Usage: boop mode solo|assist|leader|leader-call")
end

local PRESET_DEFS = {
  solo = {
    label = "solo",
    summary = "Whitelist solo hunting with simple rage and no party gating.",
    values = {
      targetingMode = "whitelist",
      useQueueing = false,
      prequeueEnabled = true,
      attackLeadSeconds = 1,
      autoGrabGold = true,
      attackMode = "simple",
      partySize = 1,
      rageAffCalloutsEnabled = false,
      assistEnabled = false,
      autoTargetCall = false,
      targetCall = false,
    },
  },
  party = {
    label = "party",
    summary = "Party-friendly hunting without assist or leader target gating.",
    values = {
      targetingMode = "whitelist",
      useQueueing = false,
      prequeueEnabled = true,
      attackLeadSeconds = 1,
      autoGrabGold = true,
      attackMode = "simple",
      partySize = 2,
      rageAffCalloutsEnabled = false,
      assistEnabled = false,
      autoTargetCall = false,
      targetCall = false,
    },
  },
  leader = {
    label = "leader",
    summary = "Party hunting that automatically calls each new target you engage.",
    values = {
      targetingMode = "whitelist",
      useQueueing = false,
      prequeueEnabled = true,
      attackLeadSeconds = 1,
      autoGrabGold = true,
      attackMode = "simple",
      partySize = 2,
      rageAffCalloutsEnabled = false,
      assistEnabled = false,
      autoTargetCall = true,
      targetCall = false,
    },
  },
  ["leader-call"] = {
    label = "leader-call",
    summary = "Party hunting that waits for a called target from your configured leader.",
    values = {
      targetingMode = "whitelist",
      useQueueing = false,
      prequeueEnabled = true,
      attackLeadSeconds = 1,
      autoGrabGold = true,
      attackMode = "simple",
      partySize = 2,
      rageAffCalloutsEnabled = false,
      assistEnabled = true,
      autoTargetCall = false,
      targetCall = true,
    },
  },
}

local function canonicalPresetName(raw)
  local cmd = boop.util.safeLower(boop.util.trim(raw or ""))
  if cmd == "leadercall" or cmd == "lead" then
    return "leader-call"
  end
  return cmd
end

function boop.ui.presetCommand(raw)
  local cmd = canonicalPresetName(raw)

  if cmd == "" or cmd == "status" or cmd == "show" or cmd == "list" then
    boop.util.info("presets: solo | party | leader | leader-call")
    boop.util.info("Usage: boop preset <solo|party|leader|leader-call>")
    boop.util.echo("  solo        -> " .. PRESET_DEFS.solo.summary)
    boop.util.echo("  party       -> " .. PRESET_DEFS.party.summary)
    boop.util.echo("  leader      -> " .. PRESET_DEFS.leader.summary)
    boop.util.echo("  leader-call -> " .. PRESET_DEFS["leader-call"].summary)
    return
  end

  local preset = PRESET_DEFS[cmd]
  if not preset then
    boop.util.warn("unknown preset: " .. tostring(raw))
    boop.util.info("Usage: boop preset <solo|party|leader|leader-call>")
    return
  end

  if cmd == "leader-call" and assistLeader() == "" then
    boop.util.warn("leader-call preset needs a leader; use: boop assist <name>")
    return
  end

  for key, value in pairs(preset.values) do
    saveConfigValue(key, value)
  end

  if not preset.values.prequeueEnabled and boop.state and boop.state.prequeueTimer then
    killTimer(boop.state.prequeueTimer)
    boop.state.prequeueTimer = nil
  end

  if not preset.values.targetCall and boop.targets and boop.targets.clearTargetCall then
    boop.targets.clearTargetCall("preset " .. preset.label)
  end

  boop.util.ok("preset applied: " .. preset.label)
end

function boop.ui.themeCommand(raw)
  local text = boop.util.trim(raw or "")
  local cmd = boop.util.safeLower(text)

  if cmd == "" or cmd == "status" or cmd == "show" then
    boop.util.info("theme: " .. activeThemeLabel())
    boop.util.info("Usage: boop theme <name|auto|list>")
    return
  end

  if cmd == "list" then
    if cecho then
      renderThemeSamples()
    else
      boop.util.info("themes:")
      for _, name in ipairs((boop.theme and boop.theme.names and boop.theme.names()) or {}) do
        boop.util.echo("  " .. name)
      end
      boop.util.echo("  auto")
      boop.util.info("Includes boop themes plus the built-in ADB city/class palettes.")
    end
    return
  end

  if cmd == "auto" then
    saveConfigValue("uiTheme", "")
    boop.util.ok("theme: auto (" .. activeThemeLabel() .. ")")
    return
  end

  if not (boop.theme and boop.theme.exists and boop.theme.exists(cmd)) then
    boop.util.warn("unknown theme: " .. cmd)
    boop.util.info("Use: boop theme list")
    return
  end

  saveConfigValue("uiTheme", cmd)
  boop.util.ok("theme: " .. cmd)
end

function boop.ui.partyCommand(raw)
  local text = boop.util.trim(raw or "")
  local cmd = boop.util.safeLower(text)
  local roster = partyRosterMembers()
  local rosterShown = #roster > 0 and table.concat(roster, ", ") or "(none)"
  local leader = assistLeader()
  local assistShown = assistStatusText()
  local walkShown = walkStatusLabel()
  local blocker, nextAction = currentBlocker()
  local calledTarget = tostring((boop.state and boop.state.calledTargetId) or "")
  if calledTarget == "" then calledTarget = "(none)" end
  local targetCallShown = boop.config.targetCall and "ON" or "OFF"
  local affCallsShown = boop.config.rageAffCalloutsEnabled and "ON" or "OFF"
  local leaderShown = leader ~= "" and leader or "(unset)"
  local partySizeShown = tostring(tonumber(boop.config.partySize) or 1)
  local rosterSummary = string.format("%d | %s", #roster, rosterShown)

  if cmd ~= "" and cmd ~= "status" and cmd ~= "show" then
    local head, tail = text:match("^(%S+)%s*(.-)%s*$")
    local lowered = boop.util.safeLower(head or "")
    if lowered == "mode" then
      boop.ui.modeCommand(tail or "")
      return
    end
    if lowered == "walk" then
      boop.ui.walkCommand(tail or "")
      return
    end
    if lowered == "assist" or lowered == "leader" then
      boop.ui.assistCommand(tail or "")
      return
    end
    if lowered == "targetcall" then
      boop.ui.targetCallCommand(tail or "")
      return
    end
    if lowered == "affcalls" or lowered == "affcall" then
      boop.ui.affCallCommand(tail or "")
      return
    end
    if lowered == "size" or lowered == "partysize" then
      boop.ui.setConfigValue("partySize", tail or "")
      return
    end
    if lowered == "roster" then
      boop.ui.rosterCommand(tail or "")
      return
    end
    if lowered == "combos" or lowered == "combo" then
      boop.ui.combos(tail ~= "" and tail or "party")
      return
    end
    boop.util.info("Usage: boop party [status|mode ...|walk ...|assist ...|targetcall ...|affcalls ...|size <n>|roster ...|combos]")
    return
  end

  if cecho then
    uiPrintHeader("boop > party")

    uiPrintSection("overview")
    uiPrintRow(1, "Mode", operatingModeLabel(), "yellow", function() boop.ui.modeCommand("") end, "Show mode help")
    uiPrintRow(2, "Leader", leaderShown, leader ~= "" and "cyan" or "yellow", function()
      uiSetCommandLine("boop assist ")
    end, "Prepare assist leader command")
    uiPrintRow(3, "Assist", assistShown, boop.config.assistEnabled and "green" or "yellow", function()
      boop.ui.modeCommand(boop.config.assistEnabled and "solo" or "assist")
    end, "Toggle assist mode")
    uiPrintRow(4, "Leader target gate", targetCallShown, boop.config.targetCall and "green" or "yellow", function()
      boop.ui.targetCallCommand(boop.config.targetCall and "off" or "on")
    end, "Toggle leader target gating")
    uiPrintRow(5, "Called target", calledTarget, "cyan")
    uiPrintRow(6, "Party size", partySizeShown, "cyan", function()
      uiSetCommandLine("boop party size ")
    end, "Prepare party size command")

    uiPrintSection("movement")
    uiPrintRow(7, "Walk", walkShown, walkShown == "ON" and "green" or (walkShown == "INSTALL" and "red" or "yellow"), function()
      if walkShown == "INSTALL" then
        boop.ui.walkCommand("install")
      else
        boop.ui.walkCommand(walkShown == "ON" and "stop" or "start")
      end
    end, walkShown == "INSTALL" and "Install demonnicAutoWalker for walk controls" or "Start or stop autowalk")
    uiPrintRow(8, "Blocker", blocker, blocker == "ready" and "green" or "yellow", function()
      boop.ui.walkCommand("status")
    end, "Show walk status")
    uiPrintRow(9, "Next action", nextAction, "cyan")
    uiPrintRow(10, "Force move", "MOVE", "yellow", function()
      boop.ui.walkCommand("move")
    end, "Ask the external walker to advance once")

    uiPrintSection("party data")
    uiPrintRow(11, "Rage aff calls", affCallsShown, boop.config.rageAffCalloutsEnabled and "green" or "yellow", function()
      boop.ui.affCallCommand(boop.config.rageAffCalloutsEnabled and "off" or "on")
    end, "Toggle battlerage affliction party callouts")
    uiPrintRow(12, "Roster", rosterSummary, "cyan", function()
      boop.ui.rosterCommand("")
    end, "Open party roster screen")
    uiPrintRow(13, "Combos", "OPEN", "cyan", function()
      boop.ui.combos("party")
    end, "Open combo synergy dashboard")
    uiPrintRow(14, "Config hub", "OPEN", "cyan", function()
      boop.ui.config("party")
    end, "Open the broader config hub near party controls")
    uiPrintRow(15, "Control dashboard", "OPEN", "cyan", function()
      boop.ui.controlCommand("")
    end, "Open the control dashboard")
    uiPrintFooter("Type: boop party assist <leader> | boop party targetcall on|off | boop party affcalls on|off | boop party walk <cmd> | boop walk install | boop roster | boop combos")
    return
  end

  boop.util.echo("PARTY")
  boop.util.echo("----------------------------------------")
  boop.util.echo(string.format("Coordination: mode %s | leader %s | assist %s", operatingModeLabel(), leaderShown, assistShown))
  boop.util.echo(string.format("Target gate: %s | called target: %s | aff calls: %s", targetCallShown, calledTarget, affCallsShown))
  boop.util.echo(string.format("Movement: walk %s | blocker %s", walkShown, blocker))
  boop.util.echo("Next: " .. nextAction)
  boop.util.echo(string.format("Party size: %s | roster entries: %d", partySizeShown, #roster))
  boop.util.echo("Roster: " .. rosterShown)
  boop.util.echo("Quick: boop party assist <leader> | boop party targetcall on|off | boop party affcalls on|off | boop party walk | boop walk install | boop roster | boop combos")
end

function boop.ui.assistCommand(raw)
  local text = boop.util.trim(raw or "")
  local cmd = boop.util.safeLower(text)
  local leader = assistLeader()

  if cmd == "" or cmd == "status" or cmd == "show" then
    boop.util.info("assist: " .. assistStatusText())
    boop.util.info("Usage: boop assist <leader> | boop assist on|off|clear")
    return
  end

  if cmd == "help" then
    boop.util.echo("Usage: boop assist <leader> | boop assist on|off|clear")
    boop.util.echo("Example: boop assist Nikolais")
    boop.util.echo("Assist mode prepends `assist <leader>/` before each attack.")
    return
  end

  if cmd == "off" or cmd == "disable" then
    saveConfigValue("assistEnabled", false)
    boop.util.ok("assist: off")
    return
  end

  if cmd == "clear" or cmd == "none" then
    saveConfigValue("assistEnabled", false)
    saveConfigValue("assistLeader", "")
    boop.util.ok("assist cleared")
    return
  end

  if cmd == "on" or cmd == "enable" then
    if leader == "" then
      boop.util.warn("assist needs a leader; use: boop assist <name>")
      return
    end
    saveConfigValue("assistEnabled", true)
    boop.util.ok("assist: on -> " .. leader)
    return
  end

  saveConfigValue("assistLeader", text)
  saveConfigValue("assistEnabled", true)
  boop.util.ok("assist leader: " .. text)
end

function boop.ui.affCallCommand(raw)
  local text = boop.util.trim(raw or "")
  local cmd = boop.util.safeLower(text)

  if cmd == "" or cmd == "status" or cmd == "show" then
    boop.util.info("rage affliction callouts: " .. (boop.config.rageAffCalloutsEnabled and "on" or "off"))
    boop.util.info("Usage: boop affcalls on|off")
    return
  end

  local parsed = parseBool(cmd)
  if parsed == nil then
    boop.util.warn("Usage: boop affcalls on|off")
    return
  end

  saveConfigValue("rageAffCalloutsEnabled", parsed)
  boop.util.ok("rage affliction callouts: " .. (parsed and "on" or "off"))
end

function boop.ui.targetCallCommand(raw)
  local text = boop.util.trim(raw or "")
  local cmd = boop.util.safeLower(text)

  if cmd == "" or cmd == "status" or cmd == "show" then
    local calledId = tostring((boop.state and boop.state.calledTargetId) or "")
    if calledId == "" then calledId = "(none)" end
    boop.util.info("leader target call gate: " .. (boop.config.targetCall and "on" or "off"))
    boop.util.info("called target id: " .. calledId)
    boop.util.info("Usage: boop targetcall on|off")
    return
  end

  local parsed = parseBool(cmd)
  if parsed == nil then
    boop.util.warn("Usage: boop targetcall on|off")
    return
  end
  if parsed and assistLeader() == "" then
    boop.util.warn("target call mode needs a leader; use: boop assist <name>")
    return
  end

  saveConfigValue("targetCall", parsed)
  if parsed and boop.config.autoTargetCall then
    saveConfigValue("autoTargetCall", false)
  end
  if not parsed and boop.targets and boop.targets.clearTargetCall then
    boop.targets.clearTargetCall("target call disabled")
  end
  boop.util.ok("leader target call gate: " .. (parsed and "on" or "off"))
end

local function currentAttackPreferenceClass()
  local classKey = boop.util.safeLower(currentClass())
  if classKey == "" then
    return ""
  end
  if boop.attacks and boop.attacks.registry and boop.attacks.registry[classKey] then
    return classKey
  end
  return ""
end

local function currentWeaponConfigClass()
  local classKey = boop.util.safeLower(currentClass())
  if classKey == "" then
    return ""
  end
  if boop.attacks and boop.attacks.registry and boop.attacks.registry[classKey] then
    return classKey
  end
  return ""
end

function boop.ui.weaponCommand(raw)
  local text = boop.util.trim(raw or "")
  local lower = boop.util.safeLower(text)
  local classKey = currentWeaponConfigClass()

  if classKey == "" then
    boop.util.warn("No active class profile is loaded yet")
    return
  end

  local function showStatus()
    boop.util.info("weapon designations: " .. classKey)
    local found = false
    for key, value in pairs(boop.config or {}) do
      local prefix = "weapon." .. classKey .. "."
      if tostring(key):find(prefix, 1, true) == 1 then
        local role = tostring(key):sub(#prefix + 1)
        boop.util.echo(string.format("  %s: %s", role, tostring(value)))
        found = true
      end
    end
    if not found then
      boop.util.echo("  (none)")
    end
    boop.util.info("Usage: boop weapon <role> <item-id> | boop weapon clear <role>")
    boop.util.info("Prefer raw GMCP item ids for reliability.")
  end

  if text == "" or lower == "status" or lower == "show" or lower == "list" then
    showStatus()
    return
  end

  local clearRole = lower:match("^clear%s+(%S+)$")
  if clearRole then
    local key = boop.attacks.weaponConfigKey(classKey, clearRole)
    if key == "" then
      boop.util.warn("weapon clear expects a role")
      return
    end
    boop.config[key] = nil
    if boop.db and boop.db.deleteConfig then
      boop.db.deleteConfig(key)
    end
    boop.util.ok(string.format("weapon %s cleared for %s", clearRole, classKey))
    return
  end

  local role, value = text:match("^(%S+)%s+(.+)$")
  role = boop.util.safeLower(boop.util.trim(role or ""))
  value = boop.util.trim(value or "")
  if role == "" or value == "" then
    boop.util.warn("Usage: boop weapon <role> <item-id>")
    boop.util.info("Use: boop weapon")
    return
  end

  local key = boop.attacks.weaponConfigKey(classKey, role)
  if key == "" then
    boop.util.warn("Unable to save weapon designation")
    return
  end
  saveConfigValue(key, value)
  boop.util.ok(string.format("weapon %s: %s (%s)", role, value, classKey))
end

function boop.ui.attackPreferenceCommand(raw)
  local text = boop.util.trim(raw or "")
  local textLower = boop.util.safeLower(text)
  local classKey = currentAttackPreferenceClass()
  local spec = boop.util.trim(boop.state and boop.state.spec or "")

  if classKey == "" then
    boop.util.warn("No active class profile is loaded yet")
    return
  end

  local function showStatus()
    local specShown = spec ~= "" and spec or "(default)"
    local damPref = boop.attacks.getStandardPreference(classKey, "dam")
    local shieldPref = boop.attacks.getStandardPreference(classKey, "shield")
    boop.util.info(string.format("attack preferences: %s | spec: %s", classKey, specShown))
    boop.util.echo("  damage: " .. (damPref ~= "" and damPref or "(default)"))
    for _, option in ipairs(boop.attacks.standardOptions(classKey, "dam")) do
      boop.util.echo("    - " .. option.label)
    end
    boop.util.echo("  shield: " .. (shieldPref ~= "" and shieldPref or "(default)"))
    for _, option in ipairs(boop.attacks.standardOptions(classKey, "shield")) do
      boop.util.echo("    - " .. option.label)
    end
    boop.util.info("Usage: boop prefer <dam|shield> <option> | boop prefer clear <dam|shield>")
  end

  if text == "" or textLower == "status" or textLower == "show" then
    showStatus()
    return
  end

  local clearSection = textLower:match("^clear%s+(%S+)$")
  if clearSection then
    local section = boop.util.safeLower(boop.util.trim(clearSection))
    if section ~= "dam" and section ~= "shield" then
      boop.util.warn("clear expects dam or shield")
      return
    end
    local key = boop.attacks.preferenceConfigKey(classKey, section, spec)
    if key ~= "" then
      boop.config[key] = nil
      if boop.db and boop.db.deleteConfig then
        boop.db.deleteConfig(key)
      end
    end
    boop.util.ok(string.format("%s preference cleared for %s (%s)", section, classKey, spec ~= "" and spec or "default"))
    return
  end

  local section, choice = text:match("^(%S+)%s+(.+)$")
  section = boop.util.safeLower(boop.util.trim(section or ""))
  choice = boop.util.trim(choice or "")
  if (section ~= "dam" and section ~= "shield") or choice == "" then
    boop.util.warn("Usage: boop prefer <dam|shield> <option>")
    boop.util.info("Use: boop prefer")
    return
  end

  local options = boop.attacks.standardOptions(classKey, section)
  local known = false
  for _, option in ipairs(options) do
    local label = boop.util.safeLower(option.label)
    local skill = boop.util.safeLower(option.skill)
    local command = boop.util.safeLower(option.command)
    local wanted = boop.util.safeLower(choice)
    if label:find(wanted, 1, true) or skill == wanted or command:find(wanted, 1, true) then
      known = true
      break
    end
  end
  if not known then
    boop.util.warn(string.format("Unknown %s preference `%s` for %s", section, choice, classKey))
    showStatus()
    return
  end

  local key = boop.attacks.preferenceConfigKey(classKey, section, spec)
  if key == "" then
    boop.util.warn("Unable to save attack preference")
    return
  end
  boop.config[key] = choice
  if boop.db and boop.db.saveConfig then
    boop.db.saveConfig(key, choice)
  end
  boop.util.ok(string.format("%s preference: %s (%s)", section, choice, spec ~= "" and spec or "default"))
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
    boop.util.info("Usage: boop import foxhunt [merge|overwrite|dryrun]")
    return
  end

  boop.util.info("foxhunt import: starting (" .. importMode .. ")")

  local foxDb, dbErr = safeGetDatabase("hunting")
  if dbErr then
    boop.util.err("foxhunt import failed: " .. dbErr)
    boop.util.info(dbLocationHint("hunting"))
    return
  end
  if not foxDb then
    boop.util.err("foxhunt import failed: DB `hunting` not found.")
    boop.util.info(dbLocationHint("hunting"))
    return
  end

  local whitelistTable, wlTableErr = safeGetDbTable(foxDb, "whitelist")
  if wlTableErr then
    boop.util.err("foxhunt import failed: cannot access `hunting.whitelist` (" .. wlTableErr .. ")")
    return
  end
  local blacklistTable, blTableErr = safeGetDbTable(foxDb, "blacklist")
  if blTableErr then
    boop.util.err("foxhunt import failed: cannot access `hunting.blacklist` (" .. blTableErr .. ")")
    return
  end

  local fhWhitelist, wlErr = loadFoxhuntListMap(whitelistTable, "whitelist")
  if wlErr then
    boop.util.err("foxhunt import failed: " .. wlErr)
    return
  end
  local fhBlacklist, blErr = loadFoxhuntListMap(blacklistTable, "blacklist")
  if blErr then
    boop.util.err("foxhunt import failed: " .. blErr)
    return
  end
  local wlAreas, wlEntries = countListMap(fhWhitelist)
  local blAreas, blEntries = countListMap(fhBlacklist)

  boop.util.info(string.format("foxhunt import %s | whitelist %d areas/%d entries | blacklist %d areas/%d entries",
    importMode, wlAreas, wlEntries, blAreas, blEntries))
  if wlEntries == 0 and blEntries == 0 then
    boop.util.warn("foxhunt import: source lists are empty; nothing to import")
  end

  if importMode == "dryrun" then
    boop.util.info("dryrun only; no changes applied")
    return
  end

  if not boop.db or not boop.db.saveList then
    boop.util.err("foxhunt import failed: boop DB unavailable; cannot persist imported lists.")
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

    boop.util.ok(string.format("import applied | whitelist areas: %d | blacklist areas: %d",
      importedWlAreas, importedBlAreas))
    boop.trace.log("import foxhunt " .. importMode .. " applied")
  end)
  if not ok then
    boop.util.err("foxhunt import failed: " .. tostring(applyErr))
    boop.trace.log("import foxhunt failed: " .. tostring(applyErr))
    return
  end
end

local function comboNormToken(s)
  local token = boop.util.safeLower(boop.util.trim(s or ""))
  token = token:gsub("[^%w]+", "")
  return token
end

local function comboPrettyClass(classKey)
  local key = boop.util.safeLower(boop.util.trim(classKey or ""))
  if key == "" then
    return "(unknown)"
  end
  return (key:gsub("(%a)([%w']*)", function(first, rest)
    return string.upper(first) .. string.lower(rest)
  end))
end

local function comboPrettyTerm(value)
  local text = boop.util.trim(tostring(value or ""))
  if text == "" then
    return "(none)"
  end
  text = text:gsub("[_%-]+", " ")
  return (text:gsub("(%a)([%w']*)", function(first, rest)
    return string.upper(first) .. string.lower(rest)
  end))
end

local function comboAffSummary(data)
  local affs = (data and data.affs) or {}
  local affKeys = {}
  for aff, _ in pairs(affs) do
    affKeys[#affKeys + 1] = aff
  end
  table.sort(affKeys)
  if #affKeys == 0 then
    return "(none)"
  end

  local parts = {}
  for _, aff in ipairs(affKeys) do
    local abilities = affs[aff] or {}
    local shownAbilities = {}
    for _, ability in ipairs(abilities) do
      shownAbilities[#shownAbilities + 1] = comboPrettyTerm(ability)
    end
    local attackText = #shownAbilities > 0 and table.concat(shownAbilities, "/") or "unknown"
    parts[#parts + 1] = string.format("%s (%s)", comboPrettyTerm(aff), attackText)
  end
  return table.concat(parts, ", ")
end

local function comboTokenizeArgs(raw)
  local args = boop.util.trim(raw or "")
  local out = {}
  if args == "" then
    return out
  end

  local i = 1
  local n = #args
  while i <= n do
    while i <= n and args:sub(i, i):match("%s") do
      i = i + 1
    end
    if i > n then break end

    local ch = args:sub(i, i)
    if ch == "'" or ch == "\"" then
      local quote = ch
      local j = i + 1
      while j <= n and args:sub(j, j) ~= quote do
        j = j + 1
      end
      local token = boop.util.trim(args:sub(i + 1, (j <= n) and (j - 1) or n))
      if token ~= "" then
        out[#out + 1] = token
      end
      i = (j <= n) and (j + 1) or (n + 1)
    else
      local j = i
      while j <= n and not args:sub(j, j):match("[%s,]") do
        j = j + 1
      end
      local token = boop.util.trim(args:sub(i, j - 1))
      if token ~= "" then
        out[#out + 1] = token
      end
      i = j + 1
    end
  end

  return out
end

local function comboBuildAliasMap()
  local aliases = {}
  local classKeys = {}
  local registry = (boop.attacks and boop.attacks.registry) or {}

  for classKey, _ in pairs(registry) do
    local key = boop.util.safeLower(boop.util.trim(classKey or ""))
    if key ~= "" then
      classKeys[#classKeys + 1] = key
      aliases[comboNormToken(key)] = key
      aliases[comboNormToken(key:gsub("%s+", "-"))] = key
      aliases[comboNormToken(key:gsub("%s+", "_"))] = key

      local dragonColor = key:match("^(%a+)%s+dragon$")
      if dragonColor then
        aliases[comboNormToken(dragonColor)] = key
        aliases[comboNormToken(dragonColor .. " dragon")] = key
        aliases[comboNormToken(dragonColor .. "dragon")] = key
        if dragonColor == "golden" then
          aliases["gold"] = key
          aliases["golddragon"] = key
        end
      end
    end
  end

  local shorthand = {
    bm = "blademaster",
    dw = "depthswalker",
    occ = "occultist",
    rw = "runewarden",
    inf = "infernal",
    pal = "paladin",
    un = "unnamable",
    unna = "unnamable",
    psi = "psion",
    pri = "priest",
    sent = "sentinel",
    sham = "shaman",
    serp = "serpent",
    alc = "alchemist",
    apo = "apostate",
    jest = "jester",
    syl = "sylvan",
    bluedragon = "blue dragon",
    reddragon = "red dragon",
    blackdragon = "black dragon",
    greendragon = "green dragon",
    silverdragon = "silver dragon",
    golddragon = "golden dragon",
    goldendragon = "golden dragon",
  }
  for alias, classKey in pairs(shorthand) do
    if registry[classKey] then
      aliases[comboNormToken(alias)] = classKey
    end
  end

  table.sort(classKeys)
  return aliases, classKeys
end

local function comboResolveToken(token, aliases, classKeys)
  local normalized = comboNormToken(token)
  if normalized == "" then
    return nil, {}
  end

  local direct = aliases[normalized]
  if direct then
    return direct, {}
  end

  local candidates = {}
  for _, classKey in ipairs(classKeys or {}) do
    local classNorm = comboNormToken(classKey)
    if boop.util.starts(classNorm, normalized) or classNorm:find(normalized, 1, true) then
      candidates[#candidates + 1] = classKey
    end
  end

  if #candidates == 1 then
    return candidates[1], candidates
  end
  return nil, candidates
end

local function comboResolveClassTokens(tokens, aliases, classKeys)
  local selected = {}
  local selectedSeen = {}
  local unresolved = {}

  for _, token in ipairs(tokens or {}) do
    local classKey, candidates = comboResolveToken(token, aliases, classKeys)
    if classKey then
      if not selectedSeen[classKey] then
        selectedSeen[classKey] = true
        selected[#selected + 1] = classKey
      end
    else
      unresolved[#unresolved + 1] = {
        token = token,
        candidates = candidates or {},
      }
    end
  end

  table.sort(selected)
  return selected, unresolved
end

local function comboCurrentClassRaw()
  return boop.util.trim((boop.state and boop.state.class)
    or (gmcp and gmcp.Char and gmcp.Char.Status and gmcp.Char.Status.class)
    or "")
end

local function comboResolveCurrentClass(aliases, classKeys)
  local currentClass = comboCurrentClassRaw()
  if currentClass == "" then
    return "", ""
  end

  local token = comboNormToken(currentClass)
  local direct = aliases[token]
  if direct then
    return direct, currentClass
  end

  local resolved = comboResolveToken(currentClass, aliases, classKeys)
  if resolved then
    return resolved, currentClass
  end

  return "", currentClass
end

local function comboConfiguredPartyTokens()
  local raw = boop.util.trim(boop.config.partyRoster or "")
  local tokens = {}
  if raw == "" then
    return tokens
  end
  for token in raw:gmatch("([^,]+)") do
    local trimmed = boop.util.trim(token)
    if trimmed ~= "" then
      tokens[#tokens + 1] = trimmed
    end
  end
  return tokens
end

local function comboSerializeParty(classKeys)
  local out = {}
  for _, classKey in ipairs(classKeys or {}) do
    local key = boop.util.safeLower(boop.util.trim(classKey or ""))
    if key ~= "" then
      out[#out + 1] = key
    end
  end
  table.sort(out)
  return table.concat(out, ",")
end

local function comboConfiguredPartyMembers(aliases, classKeys)
  local tokens = comboConfiguredPartyTokens()
  if #tokens == 0 then
    return {}, {}, tokens
  end
  local selected, unresolved = comboResolveClassTokens(tokens, aliases, classKeys)
  return selected, unresolved, tokens
end

local function comboBuildEffectiveParty(aliases, classKeys)
  local members, unresolved = comboConfiguredPartyMembers(aliases, classKeys)
  local effective = {}
  local seen = {}
  local selfClass = comboResolveCurrentClass(aliases, classKeys)

  if selfClass ~= "" and not seen[selfClass] then
    seen[selfClass] = true
    effective[#effective + 1] = selfClass
  end
  for _, classKey in ipairs(members) do
    if not seen[classKey] then
      seen[classKey] = true
      effective[#effective + 1] = classKey
    end
  end

  table.sort(effective)
  return effective, selfClass, members, unresolved
end

local function comboCollectClassData(classKey)
  local registry = (boop.attacks and boop.attacks.registry) or {}
  local profile = registry[classKey]
  local data = {
    affs = {},
    conditionals = {},
  }

  if not profile or not profile.rage or not profile.rage.abilities then
    return data
  end

  for abilityKey, ability in pairs(profile.rage.abilities) do
    local abilityName = boop.util.safeLower(boop.util.trim(ability.name or abilityKey or ""))
    local aff = boop.util.safeLower(boop.util.trim(ability.aff or ""))
    if aff ~= "" and abilityName ~= "" then
      data.affs[aff] = data.affs[aff] or {}
      data.affs[aff][#data.affs[aff] + 1] = abilityName
    end

    local desc = boop.util.safeLower(boop.util.trim(ability.desc or ""))
    if desc == "conditional" and type(ability.needs) == "table" then
      local needs = {}
      for _, need in ipairs(ability.needs) do
        local needKey = boop.util.safeLower(boop.util.trim(need or ""))
        if needKey ~= "" then
          needs[#needs + 1] = needKey
        end
      end
      if #needs > 0 and abilityName ~= "" then
        table.sort(needs)
        data.conditionals[#data.conditionals + 1] = {
          name = abilityName,
          needs = needs,
          needsMode = boop.util.safeLower(boop.util.trim(ability.needsMode or "any")),
        }
      end
    end
  end

  for _, abilities in pairs(data.affs) do
    table.sort(abilities)
  end
  table.sort(data.conditionals, function(a, b)
    return tostring(a.name) < tostring(b.name)
  end)

  return data
end

local function comboAnalyze(selected)
  local classData = {}
  local providersByAff = {}
  for _, classKey in ipairs(selected) do
    local data = comboCollectClassData(classKey)
    classData[classKey] = data
    for aff, _ in pairs(data.affs) do
      providersByAff[aff] = providersByAff[aff] or {}
      providersByAff[aff][classKey] = true
    end
  end

  local comboRows = {}
  for _, classKey in ipairs(selected) do
    local data = classData[classKey]
    for _, conditional in ipairs(data.conditionals or {}) do
      local needsMode = boop.util.safeLower(boop.util.trim(conditional.needsMode or "any"))
      local requireAll = (needsMode == "all")
      local needsShown = {}
      local missing = {}
      local presentCount = 0
      for _, need in ipairs(conditional.needs or {}) do
        needsShown[#needsShown + 1] = need
        if providersByAff[need] then
          presentCount = presentCount + 1
        else
          missing[#missing + 1] = need
        end
      end

      local ready = false
      if requireAll then
        ready = (#missing == 0)
      else
        ready = (presentCount > 0)
      end

      local providerParts = {}
      for _, need in ipairs(conditional.needs or {}) do
        local providers = {}
        if providersByAff[need] then
          for providerClass, _ in pairs(providersByAff[need]) do
            providers[#providers + 1] = comboPrettyClass(providerClass)
          end
          table.sort(providers)
        end
        if #providers > 0 then
          providerParts[#providerParts + 1] = comboPrettyTerm(need) .. ": " .. table.concat(providers, "/")
        else
          providerParts[#providerParts + 1] = comboPrettyTerm(need) .. ": (none)"
        end
      end

      comboRows[#comboRows + 1] = {
        classKey = classKey,
        ability = conditional.name,
        needs = conditional.needs or {},
        requireAll = requireAll,
        label = string.format(
          "%s / %s needs %s: %s",
          comboPrettyClass(classKey),
          conditional.name,
          requireAll and "all" or "any",
          table.concat(needsShown, requireAll and " + " or " or ")
        ),
        status = ready and "READY" or "MISSING",
        color = ready and "green" or "red",
        detail = table.concat(providerParts, " | "),
      }
    end
  end

  table.sort(comboRows, function(a, b)
    if a.status ~= b.status then
      return a.status < b.status
    end
    return tostring(a.label) < tostring(b.label)
  end)

  return classData, comboRows
end

local function comboBuildSelfEnableRows(selfClassKey, selected, classData)
  if selfClassKey == "" or not classData[selfClassKey] then
    return {}
  end

  local selfAffs = (classData[selfClassKey] and classData[selfClassKey].affs) or {}
  local rows = {}
  for _, classKey in ipairs(selected or {}) do
    if classKey ~= selfClassKey then
      local data = classData[classKey] or {}
      for _, conditional in ipairs(data.conditionals or {}) do
        local needsMode = boop.util.safeLower(boop.util.trim(conditional.needsMode or "any"))
        local requireAll = (needsMode == "all")
        local provided = {}
        for _, need in ipairs(conditional.needs or {}) do
          if selfAffs[need] then
            provided[#provided + 1] = need
          end
        end
        if #provided > 0 then
          local enabled = requireAll and (#provided == #(conditional.needs or {})) or (#provided > 0)
          local providedDetails = {}
          for _, aff in ipairs(provided) do
            local abilities = selfAffs[aff] or {}
            local abilityNames = {}
            for _, ability in ipairs(abilities) do
              abilityNames[#abilityNames + 1] = comboPrettyTerm(ability)
            end
            local shownAbility = (#abilityNames > 0) and table.concat(abilityNames, "/") or "unknown"
            providedDetails[#providedDetails + 1] = string.format("%s (%s)", comboPrettyTerm(aff), shownAbility)
          end
          rows[#rows + 1] = {
            label = string.format(
              "%s / %s needs %s: %s",
              comboPrettyClass(classKey),
              conditional.name,
              requireAll and "all" or "any",
              table.concat(conditional.needs or {}, requireAll and " + " or " or ")
            ),
            status = enabled and "ENABLED" or "PARTIAL",
            color = enabled and "green" or "yellow",
            detail = "you provide: " .. table.concat(providedDetails, ", "),
          }
        end
      end
    end
  end

  local rank = { ENABLED = 1, PARTIAL = 2 }
  table.sort(rows, function(a, b)
    local aRank = rank[a.status] or 99
    local bRank = rank[b.status] or 99
    if aRank ~= bRank then
      return aRank < bRank
    end
    return tostring(a.label) < tostring(b.label)
  end)
  return rows
end

local function comboRenderClassList(classKeys)
  if cecho then
    uiPrintHeader("boop > combos")
    uiPrintSection("available classes")
    local rows = {}
    for i, classKey in ipairs(classKeys) do
      rows[#rows + 1] = { index = i, label = comboPrettyClass(classKey) }
    end
    local labelWidth = uiComputeLabelWidth(rows, UI_LABEL_COL_WIDTH, 120)
    for i, classKey in ipairs(classKeys) do
      local shown = comboPrettyClass(classKey)
      uiPrintRow(i, shown, "COPY", "cyan", function()
        uiSetCommandLine("boop combos " .. shown)
      end, "Copy class name into command line", labelWidth)
    end
    uiPrintFooter("Type: boop combos <class...>  |  Example: boop combos unnamable occultist bluedragon")
    return
  end

  boop.util.echo("BOOP > COMBOS")
  boop.util.echo("----------------------------------------")
  boop.util.echo("Available classes:")
  for _, classKey in ipairs(classKeys) do
    boop.util.echo("  - " .. comboPrettyClass(classKey))
  end
  boop.util.echo("----------------------------------------")
  boop.util.echo("Use: boop combos <class...>")
end

local function comboEchoUnresolved(unresolved, sourceLabel)
  for _, entry in ipairs(unresolved or {}) do
    if #entry.candidates == 0 then
      boop.util.echo(string.format("%s token not found: %s", sourceLabel, tostring(entry.token)))
    else
      local shown = {}
      for i = 1, math.min(5, #entry.candidates) do
        shown[#shown + 1] = comboPrettyClass(entry.candidates[i])
      end
      boop.util.echo(string.format("%s token '%s' is ambiguous: %s",
        sourceLabel, tostring(entry.token), table.concat(shown, ", ")))
    end
  end
end

local function comboRenderDashboard(selected, classData, comboRows, selfRows, footerText)
  if cecho then
    uiPrintHeader("boop > combos")
    uiPrintSection("party")
    local partyRows = {}
    for i, classKey in ipairs(selected) do
      local line = string.format("%s Affs - %s", comboPrettyClass(classKey), comboAffSummary(classData[classKey]))
      partyRows[#partyRows + 1] = { index = i, label = line }
    end
    local partyWidth = uiComputeLabelWidth(partyRows, UI_LABEL_COL_WIDTH, 180)
    for i, row in ipairs(partyRows) do
      uiPrintRow(i, row.label, "AFFS", "cyan", nil, nil, partyWidth)
    end

    if #selfRows > 0 then
      uiPrintSection("enabled by you")
      local widthRows = {}
      for i, row in ipairs(selfRows) do
        widthRows[#widthRows + 1] = { index = i, label = row.label }
      end
      local selfWidth = uiComputeLabelWidth(widthRows, UI_LABEL_COL_WIDTH, 150)
      for i, row in ipairs(selfRows) do
        uiPrintRow(i, row.label, row.status, row.color, nil, row.detail, selfWidth)
      end
    end

    uiPrintSection("conditional synergy")
    if #comboRows == 0 then
      uiPrintRow(1, "No conditional rage combos found for selected classes.", "INFO", "yellow")
    else
      local widthRows = {}
      for i, row in ipairs(comboRows) do
        widthRows[#widthRows + 1] = { index = i, label = row.label }
      end
      local labelWidth = uiComputeLabelWidth(widthRows, UI_LABEL_COL_WIDTH, 150)
      for i, row in ipairs(comboRows) do
        uiPrintRow(i, row.label, row.status, row.color, nil, row.detail, labelWidth)
      end
    end
    uiPrintFooter(footerText)
    return
  end

  boop.util.echo("BOOP > COMBOS")
  boop.util.echo("----------------------------------------")
  boop.util.echo("PARTY")
  for i, classKey in ipairs(selected) do
    boop.util.echo(string.format("[%d] %s Affs - %s", i, comboPrettyClass(classKey), comboAffSummary(classData[classKey])))
  end
  boop.util.echo("")
  if #selfRows > 0 then
    boop.util.echo("ENABLED BY YOU")
    for i, row in ipairs(selfRows) do
      boop.util.echo(string.format("[%d] %s [%s]", i, row.label, row.status))
      boop.util.echo("    " .. row.detail)
    end
    boop.util.echo("")
  end
  boop.util.echo("CONDITIONAL SYNERGY")
  if #comboRows == 0 then
    boop.util.echo("No conditional rage combos found for selected classes.")
  else
    for i, row in ipairs(comboRows) do
      boop.util.echo(string.format("[%d] %s [%s]", i, row.label, row.status))
      boop.util.echo("    " .. row.detail)
    end
  end
  boop.util.echo("----------------------------------------")
  boop.util.echo("Inferred from boop rage aff/needs data.")
end

function boop.ui.combos(rawArgs)
  local aliases, classKeys = comboBuildAliasMap()
  local raw = boop.util.trim(rawArgs or "")
  local lowered = boop.util.safeLower(raw)

  if lowered == "help" then
    boop.util.echo("Usage: boop combos [class...]")
    boop.util.echo("Example: boop combos unnamable occultist bluedragon")
    boop.util.echo("Tip: no args uses boop roster + your class.")
    boop.util.echo("Tip: use commas or quotes for multi-word classes.")
    boop.util.echo("Example: boop combos \"air elemental lady\", runewarden, serpent")
    boop.util.echo("Use: boop combos list")
    return
  end

  if lowered == "list" then
    comboRenderClassList(classKeys)
    return
  end

  local selected = {}
  local unresolved = {}
  local selfClass = ""
  local usingPartyRoster = false

  if raw == "" or lowered == "party" then
    usingPartyRoster = true
    selected, selfClass, _, unresolved = comboBuildEffectiveParty(aliases, classKeys)
  else
    local tokens = comboTokenizeArgs(raw)
    if #tokens == 0 then
      boop.util.echo("No classes provided. Use: boop combos <class...>")
      return
    end
    selected, unresolved = comboResolveClassTokens(tokens, aliases, classKeys)
    selfClass = comboResolveCurrentClass(aliases, classKeys)
  end

  if #unresolved > 0 then
    comboEchoUnresolved(unresolved, usingPartyRoster and "party roster" or "class")
    boop.util.echo("Use: boop combos list")
    if usingPartyRoster then
      boop.util.echo("Tip: reset roster with: boop roster clear")
    end
    return
  end

  if #selected == 0 then
    if usingPartyRoster then
      boop.util.echo("No party classes configured. Set with: boop roster <class...>")
      return
    end
    boop.util.echo("No valid classes found. Use: boop combos list")
    return
  end

  local classData, comboRows = comboAnalyze(selected)
  local selfRows = comboBuildSelfEnableRows(selfClass, selected, classData)
  local footer = "Inferred from boop rage aff/needs data. Use: boop combos list"
  if usingPartyRoster then
    footer = "Using boop roster + your class. Set with: boop roster <class...>"
  end
  comboRenderDashboard(selected, classData, comboRows, selfRows, footer)
end

function boop.ui.rosterCommand(rawArgs)
  local aliases, classKeys = comboBuildAliasMap()
  local raw = boop.util.trim(rawArgs or "")
  local lowered = boop.util.safeLower(raw)

  if lowered == "help" then
    boop.util.echo("Usage: boop roster <class...> | boop roster | boop roster clear")
    boop.util.echo("Example: boop roster depthswalker occultist silverdragon")
    boop.util.echo("Note: your own class is auto-included and does not need to be listed.")
    return
  end

  if lowered == "clear" or lowered == "off" or lowered == "none" then
    saveConfigValue("partyRoster", "")
    boop.util.echo("party roster cleared")
    boop.ui.rosterCommand("")
    return
  end

  local selfClass = comboResolveCurrentClass(aliases, classKeys)
  if raw ~= "" and lowered ~= "show" and lowered ~= "status" then
    local tokens = comboTokenizeArgs(raw)
    if #tokens == 0 then
      boop.util.echo("No classes provided. Use: boop roster <class...>")
      return
    end

    local selected, unresolved = comboResolveClassTokens(tokens, aliases, classKeys)
    if #unresolved > 0 then
      comboEchoUnresolved(unresolved, "party")
      boop.util.echo("Use: boop combos list")
      return
    end

    local filtered = {}
    for _, classKey in ipairs(selected) do
      if classKey ~= selfClass then
        filtered[#filtered + 1] = classKey
      end
    end

    saveConfigValue("partyRoster", comboSerializeParty(filtered))
    if #filtered == 0 then
      boop.util.echo("party roster saved: (none)")
    else
      local shown = {}
      for _, classKey in ipairs(filtered) do
        shown[#shown + 1] = comboPrettyClass(classKey)
      end
      boop.util.echo("party roster saved: " .. table.concat(shown, ", "))
    end
  end

  local effective, resolvedSelfClass, members, unresolvedMembers = comboBuildEffectiveParty(aliases, classKeys)
  if #unresolvedMembers > 0 then
    comboEchoUnresolved(unresolvedMembers, "stored party")
    boop.util.echo("Tip: set a clean roster with boop roster <class...> or boop roster clear")
  end

  local classData = {}
  for _, classKey in ipairs(effective) do
    classData[classKey] = comboCollectClassData(classKey)
  end
  local selfRows = comboBuildSelfEnableRows(resolvedSelfClass, effective, classData)

  if cecho then
    uiPrintHeader("boop > roster")
    uiPrintSection("roster")
    local rosterRows = {}
    rosterRows[#rosterRows + 1] = {
      index = 1,
      label = "You: " .. ((resolvedSelfClass ~= "" and comboPrettyClass(resolvedSelfClass)) or "(unknown)")
    }
    for i, classKey in ipairs(members) do
      rosterRows[#rosterRows + 1] = { index = i + 1, label = "Member: " .. comboPrettyClass(classKey) }
    end
    local rosterWidth = uiComputeLabelWidth(rosterRows, UI_LABEL_COL_WIDTH, 120)
    for _, row in ipairs(rosterRows) do
      uiPrintRow(row.index, row.label, "OK", "cyan", nil, nil, rosterWidth)
    end

    uiPrintSection("effective party")
    local effRows = {}
    for i, classKey in ipairs(effective) do
      effRows[#effRows + 1] = { index = i, label = comboPrettyClass(classKey) }
    end
    local effWidth = uiComputeLabelWidth(effRows, UI_LABEL_COL_WIDTH, 120)
    if #effRows == 0 then
      uiPrintRow(1, "(none)", "INFO", "yellow")
    else
      for i, row in ipairs(effRows) do
        uiPrintRow(i, row.label, "CLS", "cyan", nil, nil, effWidth)
      end
    end

    uiPrintSection("enabled by you")
    if #selfRows == 0 then
      uiPrintRow(1, "No party conditionals currently enabled by your rage affs.", "INFO", "yellow")
    else
      local widthRows = {}
      for i, row in ipairs(selfRows) do
        widthRows[#widthRows + 1] = { index = i, label = row.label }
      end
      local selfWidth = uiComputeLabelWidth(widthRows, UI_LABEL_COL_WIDTH, 150)
      for i, row in ipairs(selfRows) do
        uiPrintRow(i, row.label, row.status, row.color, nil, row.detail, selfWidth)
      end
    end
    uiPrintFooter("Type: boop roster <class...> | boop roster clear | boop combos")
    return
  end

  boop.util.echo("BOOP > ROSTER")
  boop.util.echo("----------------------------------------")
  boop.util.echo("ROSTER")
  boop.util.echo("You: " .. ((resolvedSelfClass ~= "" and comboPrettyClass(resolvedSelfClass)) or "(unknown)"))
  if #members == 0 then
    boop.util.echo("Members: (none)")
  else
    for i, classKey in ipairs(members) do
      boop.util.echo(string.format("[%d] %s", i, comboPrettyClass(classKey)))
    end
  end
  boop.util.echo("")
  boop.util.echo("ENABLED BY YOU")
  if #selfRows == 0 then
    boop.util.echo("No party conditionals currently enabled by your rage affs.")
  else
    for i, row in ipairs(selfRows) do
      boop.util.echo(string.format("[%d] %s [%s]", i, row.label, row.status))
      boop.util.echo("    " .. row.detail)
    end
  end
  boop.util.echo("----------------------------------------")
  boop.util.echo("Use: boop roster <class...> | boop roster clear | boop combos")
end

function boop.ui.party(rawArgs)
  boop.ui.partyCommand(rawArgs)
end

local function helpCommand(command, description)
  return {
    command = tostring(command or ""),
    description = tostring(description or ""),
  }
end

local HELP_TOPICS = {
  {
    key = "start",
    title = "Start Here",
    summary = "Core entrypoints and the fastest way to get oriented.",
    aliases = { "start", "gettingstarted", "intro", "basics", "general", "main", "home" },
    commands = {
      helpCommand("boop", "Open the home dashboard with the most important live state and next actions."),
      helpCommand("boop control", "Open the live control dashboard for hunting, movement, and runtime state."),
      helpCommand("boop on", "Enable boop hunting and start the active session timer."),
      helpCommand("boop off", "Disable boop hunting and stop the active session timer."),
      helpCommand("boop status", "Show the current state, target, queue, party, and movement summary."),
      helpCommand("boop config", "Open the guided settings hub."),
      helpCommand("boop config home", "Jump back to the root of the config hub from any config screen."),
      helpCommand("boop party", "Open the party dashboard for leader, assist, walk, and roster state."),
      helpCommand("boop preset <solo|party|leader|leader-call>", "Apply a recommended baseline for solo hunting, party hunting, leader target calling, or leader-following party play."),
      helpCommand("boop help <topic>", "Open help for a specific workflow or feature area."),
    },
    notes = {
      "Start with `boop`, then move to `boop control` for live operations or `boop config` for settings.",
      "Use `boop party` for leader/assist/walk coordination and `boop stats` for optimization data.",
    },
  },
  {
    key = "control",
    title = "Control & Config",
    summary = "Navigation between the main dashboards and the guided settings screens.",
    aliases = { "control", "controls", "config", "settings", "dashboard" },
    commands = {
      helpCommand("boop control", "Open the live control dashboard."),
      helpCommand("boop config", "Open the settings hub with summaries and links to each config area."),
      helpCommand("boop config home", "Return to the top-level config hub."),
      helpCommand("boop config combat", "Open hunting and queueing settings."),
      helpCommand("boop config targeting", "Open targeting mode, order, and list-management settings."),
      helpCommand("boop config loot", "Open sovereign pickup and gold-pack settings."),
      helpCommand("boop config debug", "Open trace, gag, and debug settings."),
      helpCommand("boop preset <solo|party|leader|leader-call>", "Apply a curated baseline without stepping through each individual setting."),
      helpCommand("boop get", "List or inspect raw config keys and values."),
      helpCommand("boop set <key> <value>", "Set a raw config value directly without using the guided screens."),
    },
    notes = {
      "Use `boop control` for live state and `boop config` for guided settings changes.",
      "Use `boop get` and `boop set` only when you want direct key/value control instead of the guided screens.",
    },
  },
  {
    key = "hunting",
    title = "Hunting & Targeting",
    summary = "Targeting modes, rage modes, queueing, and target list management.",
    aliases = { "hunting", "combat", "targeting", "targets", "whitelist", "blacklist", "rage", "ragemode", "attackmode", "queue", "queueing", "prequeue", "diag", "diagnose", "ih" },
    commands = {
      helpCommand("boop config combat", "Open the hunting settings screen for toggles like queueing, prequeue, and rage mode."),
      helpCommand("boop config targeting", "Open the targeting settings screen for mode, order, and retarget behavior."),
      helpCommand("boop ragemode", "Show the rage-mode menu and current selection."),
      helpCommand("boop ragemode <simple|big|small|aff|tempo|combo|hybrid|none>", "Set how boop chooses battlerage attacks."),
      helpCommand("boop prequeue [on|off]", "Enable or disable standard-attack prequeueing."),
      helpCommand("boop lead <seconds>", "Set how early boop should prequeue before balance comes back."),
      helpCommand("boop targeting <manual|whitelist|blacklist|auto>", "Set the top-level target-selection mode."),
      helpCommand("boop whitelist", "Open or print the current area whitelist."),
      helpCommand("boop whitelist browse [tag]", "Browse whitelist entries, optionally filtered by tag."),
      helpCommand("boop blacklist", "Open or print the current area blacklist."),
      helpCommand("diag", "Queue diagnose and temporarily pause attacking until diagnose completes or times out."),
      helpCommand("matic", "Queue `ldeck draw matic` on the attack queue and pause attacking until the next prompt or timeout."),
      helpCommand("catarin", "Queue `ldeck draw catarin` on the attack queue and pause attacking until the next prompt or timeout."),
      helpCommand("boop prefer", "Show configurable attack-preference options for your current class/spec."),
      helpCommand("boop prefer <dam|shield> <option>", "Prefer a specific standard damage or shield attack when multiple valid options exist."),
      helpCommand("boop weapon", "Show saved weapon designations for your current class profile."),
      helpCommand("boop weapon <role> <item-id>", "Save a class-scoped weapon designation using a raw GMCP item id such as `scythe 47177`."),
    },
    notes = {
      "Use the config subsections when you want guided toggles; use the direct commands when you already know what you want.",
      "Target list displays support clickable management for whitelist, blacklist, and tags.",
      "Use `boop prefer` if you want to bias standard attack choice within a profile.",
    },
  },
  {
    key = "party",
    title = "Party & Leader",
    summary = "Assist, leader target calls, roster management, and movement coordination.",
    aliases = { "party", "leader", "assist", "targetcall", "walk", "roster", "combos", "combo" },
    commands = {
      helpCommand("boop party", "Open the party dashboard with leader, assist, walk, target-call, auto-call, and roster state."),
      helpCommand("boop preset party", "Apply the default party baseline without leader gating."),
      helpCommand("boop preset leader", "Apply the leader baseline; boop will automatically party-call each new target it engages."),
      helpCommand("boop preset leader-call", "Apply the leader-call baseline; requires an assist leader to already be set."),
      helpCommand("boop mode solo|assist|leader|leader-call", "Switch between solo hunting, assist mode, leader auto-calling, and leader-following target mode."),
      helpCommand("boop assist <leader>", "Set the assist leader boop should follow for assist-mode attacks."),
      helpCommand("boop assist on|off|clear", "Enable, disable, or clear assist mode without changing other party settings."),
      helpCommand("boop targetcall on|off", "Require a leader-called target before boop starts attacking when following another leader."),
      helpCommand("boop affcalls on|off", "Enable or suppress battlerage affliction party callouts."),
      helpCommand("boop walk [status|start|stop|move]", "Inspect or control external autowalker integration when the walker package is available."),
      helpCommand("boop walk install", "Install the required demonnicAutoWalker package into Mudlet."),
      helpCommand("boop roster", "Show the stored party roster and your combo-relevant party composition."),
      helpCommand("boop roster <class...>", "Set the party roster classes used for combo and conditional help."),
      helpCommand("boop roster clear", "Clear the stored party roster."),
      helpCommand("boop combos", "Show combo/conditional information using your current roster and class."),
      helpCommand("boop combos <class...>", "Inspect combo and conditional relationships for an explicit set of classes."),
      helpCommand("boop combos list", "List known class names supported by the combo helper."),
    },
    notes = {
      "Use `boop party` as the party dashboard; it consolidates leader, assist, walk, target-call, auto-call, and roster state.",
      "Use `boop roster` to store party classes for combo/conditional assistance.",
      "If the walker package is missing, use `boop walk install` from inside Mudlet.",
      "Use quotes for multi-word classes when needed.",
    },
  },
  {
    key = "stats",
    title = "Stats & Optimization",
    summary = "Trip, session, lifetime, area, ability, target, and rage analytics.",
    aliases = { "stats", "trip", "records", "areas", "targets", "abilities", "crits", "compare" },
    commands = {
      helpCommand("boop stats", "Open the stats dashboard with current summaries and drill-down suggestions."),
      helpCommand("boop stats help", "Show the dedicated stats command overview."),
      helpCommand("boop stats session|login|trip|lifetime", "Show totals and efficiency for a specific stats scope."),
      helpCommand("boop stats lasttrip", "Show the snapshot of the most recently completed trip."),
      helpCommand("boop stats compare [left] [right]", "Compare two scopes, defaulting to trip versus lasttrip."),
      helpCommand("boop stats areas [scope] [limit] [metric]", "Rank or inspect hunting areas by the chosen metric."),
      helpCommand("boop stats targets [scope] [limit]", "Inspect per-target kill efficiency and profitability."),
      helpCommand("boop stats abilities [scope] [limit]", "Inspect per-ability usage, damage, crits, and kills."),
      helpCommand("boop stats crits [scope]", "Show crit distributions and crit-rate summaries."),
      helpCommand("boop stats rage [scope]", "Show rage-usage and rage-mode behavior summaries."),
      helpCommand("boop stats records [scope]", "Show best-hit, fastest-kill, and similar record values."),
      helpCommand("boop trip start", "Start an explicit trip timer and trip bucket for a hunt."),
      helpCommand("boop trip stop", "Stop the current trip and show its final summary."),
      helpCommand("boop stats reset session|login|trip|lifetime|all", "Reset one or more stats scopes."),
    },
    notes = {
      "Start with `boop stats` for the dashboard, then drill into the specific view that answers your optimization question.",
      "Use `compare`, `areas`, `targets`, and `abilities` when you want to choose a better hunting setup instead of just reading totals.",
    },
  },
  {
    key = "diagnostics",
    title = "Diagnostics & Advanced",
    summary = "Trace, gagging, debug tools, imports, and direct configuration.",
    aliases = { "diagnostics", "debug", "trace", "gag", "advanced", "set", "get", "import", "foxhunt" },
    commands = {
      helpCommand("boop config debug", "Open the guided diagnostics and debug settings screen."),
      helpCommand("boop debug", "Show the debug snapshot for current runtime state."),
      helpCommand("boop debug attacks", "Show the currently loaded attack profile and attack options."),
      helpCommand("boop debug skills", "Show current skill knowledge and skill-state summaries."),
      helpCommand("boop debug skills dump", "Dump the raw skill tables boop is using."),
      helpCommand("boop trace on|off|show [n]|clear", "Control or inspect the boop trace buffer used for decision-flow debugging."),
      helpCommand("boop gag on|off|own|others|all", "Control attack-line gagging behavior."),
      helpCommand("boop gag colors", "Open the interactive gag palette browser with per-role preview and picker links."),
      helpCommand("boop gag color <who|ability|target|meta|separator|bg> <color|off>", "Set one gag color role directly; use `boop gag color <role>` to open the picker."),
      helpCommand("boop get", "Inspect raw config values."),
      helpCommand("boop set <key> <value>", "Set raw config values directly."),
      helpCommand("boop import foxhunt [merge|overwrite|dryrun]", "Import whitelist and blacklist data from Foxhunt."),
      helpCommand("boop pack test", "Queue a look-in command for the current configured gold pack."),
      helpCommand("boop theme <name|auto|list>", "Inspect or change the active UI theme; list includes boop + built-in ADB palette names."),
    },
    notes = {
      "Use trace when you need decision-flow debugging; use the debug snapshot when you need current-state debugging.",
      "This is also the place for lower-level commands that do not fit the main control/config/party/stats flow.",
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
    uiPrintSection("start here")
    uiPrintRow(1, "Open boop", "boop", "cyan", function()
      uiSetCommandLine("boop")
    end, "Prepare: boop")
    uiPrintRow(2, "Control dashboard", "boop control", "cyan", function()
      uiSetCommandLine("boop control")
    end, "Prepare: boop control")
    uiPrintRow(3, "Settings hub", "boop config", "cyan", function()
      uiSetCommandLine("boop config")
    end, "Prepare: boop config")
    uiPrintRow(4, "Party dashboard", "boop party", "cyan", function()
      uiSetCommandLine("boop party")
    end, "Prepare: boop party")
    uiPrintRow(5, "Stats dashboard", "boop stats", "cyan", function()
      uiSetCommandLine("boop stats")
    end, "Prepare: boop stats")

    uiPrintSection("topics")
    local rows = {}
    for i, topic in ipairs(HELP_TOPICS) do
      rows[#rows + 1] = { index = i, label = topic.title }
    end
    local labelWidth = uiComputeLabelWidth(rows, UI_LABEL_COL_WIDTH, 100)
    for i, topic in ipairs(HELP_TOPICS) do
      local key = topic.key
      uiPrintRow(i + 5, topic.title, "OPEN", "cyan", function()
        boop.ui.help(key)
      end, topic.summary or ("Open help for " .. topic.title), labelWidth)
    end
    uiPrintFooter("Type: boop help home | boop help <number|topic>")
    return
  end

  boop.util.echo("HELP")
  boop.util.echo("----------------------------------------")
  boop.util.echo("Start: boop | boop control | boop config | boop party | boop stats")
  for i, topic in ipairs(HELP_TOPICS) do
    boop.util.echo(string.format("[%d] %s -> %s", i, topic.title, tostring(topic.summary or "")))
  end
  boop.util.echo("----------------------------------------")
  boop.util.echo("Type: boop help home")
  boop.util.echo("Type: boop help <number>  (example: boop help 2)")
  boop.util.echo("Type: boop help <topic>   (example: boop help targeting)")
end

local function helpRenderTopic(topic)
  if not topic then
    helpRenderHome()
    return
  end

  if cecho then
    uiPrintHeader("help > " .. topic.title)
    if topic.summary and topic.summary ~= "" then
      uiPrintSection("what this covers")
      uiPrintRow(1, topic.summary, "INFO", "cyan")
    end
    local commandRows = {}
    for i, entry in ipairs(topic.commands or {}) do
      local cmd = type(entry) == "table" and entry.command or tostring(entry or "")
      commandRows[#commandRows + 1] = { index = i, label = cmd }
    end
    local noteRows = {}
    for i, note in ipairs(topic.notes or {}) do
      noteRows[#noteRows + 1] = { index = i, label = note }
    end
    local commandWidth = uiComputeLabelWidth(commandRows, 56, 92)
    local noteWidth = uiComputeLabelWidth(noteRows, 56, 110)

    uiPrintSection("commands")
    for i, entry in ipairs(topic.commands or {}) do
      local value = type(entry) == "table" and entry.command or tostring(entry or "")
      local description = type(entry) == "table" and entry.description or ""
      local hint = description ~= "" and (description .. " | Click to seed this command.") or ("Copy command: " .. value)
      uiPrintRow(i, value, "COPY", "yellow", function()
        uiSetCommandLine(value)
      end, hint, commandWidth)
    end
    if topic.notes and #topic.notes > 0 then
      uiPrintSection("notes")
      for i, note in ipairs(topic.notes) do
        uiPrintRow(i, note, "INFO", "cyan", nil, note, noteWidth)
      end
    end
    uiPrintFooter("Type: boop help home | boop help back | boop help <number|topic>")
    return
  end

  boop.util.echo("HELP > " .. topic.title)
  boop.util.echo("----------------------------------------")
  if topic.summary and topic.summary ~= "" then
    boop.util.echo(topic.summary)
    boop.util.echo("")
  end
  for _, entry in ipairs(topic.commands or {}) do
    local cmd = type(entry) == "table" and entry.command or tostring(entry or "")
    local description = type(entry) == "table" and entry.description or ""
    boop.util.echo("  " .. cmd)
    if description ~= "" then
      boop.util.echo("    " .. description)
    end
  end
  if topic.notes and #topic.notes > 0 then
    boop.util.echo("Notes:")
    for _, note in ipairs(topic.notes) do
      boop.util.echo("  - " .. note)
    end
  end
  boop.util.echo("----------------------------------------")
  boop.util.echo("Type: boop help home | boop help back")
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
  local class = currentClass()
  local targetingMode = tostring(boop.config.targetingMode or "whitelist")
  local rageMode = tostring(boop.config.attackMode or "simple")
  local enabled = boop.config.enabled and "on" or "off"
  local denizenCount = boop.state and boop.state.denizens and #boop.state.denizens or 0
  local targetId = boop.state and boop.state.currentTargetId or ""
  local targetName = boop.state and boop.state.targetName or ""
  local targetShown = targetId ~= "" and (targetId .. " | " .. (targetName ~= "" and targetName or "(unnamed)")) or "(none)"
  local trip = boop.stats and boop.stats.trip or {}
  local tripRunning = trip and trip.stopwatch and "running" or "idle"
  local tripKills = tonumber(trip and trip.kills) or 0
  local tripGold = tonumber(trip and trip.gold) or 0
  local tripXp = tonumber(trip and trip.rawExperience) or 0
  local assistShown = assistStatusText()
  local targetCallShown = boop.config.targetCall and "ON" or "OFF"
  local modeShown = operatingModeLabel()
  local themeShown = activeThemeLabel()
  local blocker, nextAction = currentBlocker()
  local walkShown = walkStatusLabel()

  if cecho then
    uiPrintHeader("boop")
    uiPrintSection("operations")
    uiPrintRow(1, "Hunting", enabled, boop.config.enabled and "green" or "red")
    uiPrintRow(2, "Mode", modeShown, "yellow")
    uiPrintRow(3, "Blocker", blocker, blocker == "ready" and "green" or "yellow")
    uiPrintRow(4, "Next action", nextAction, "cyan")
    uiPrintRow(5, "Walk", walkShown, walkShown == "ON" and "green" or (walkShown == "INSTALL" and "red" or "yellow"))
    uiPrintRow(6, "Theme", themeShown, "cyan")

    uiPrintSection("combat state")
    uiPrintRow(7, "Class", tostring(class), "cyan")
    uiPrintRow(8, "Targeting", targetingMode, "cyan")
    uiPrintRow(9, "Ragemode", rageMode, "yellow")
    uiPrintRow(10, "Assist", assistShown, boop.config.assistEnabled and "green" or "yellow")
    uiPrintRow(11, "Leader target gate", targetCallShown, boop.config.targetCall and "green" or "yellow")
    uiPrintRow(12, "Target", targetShown, "cyan")
    uiPrintRow(13, "Room denizens", tostring(denizenCount), "cyan")

    uiPrintSection("trip snapshot")
    uiPrintRow(14, "Trip state", tripRunning, tripRunning == "running" and "green" or "yellow")
    uiPrintRow(15, "Trip kills", tostring(tripKills), "cyan")
    uiPrintRow(16, "Trip gold", tostring(tripGold), "yellow")
    uiPrintRow(17, "Trip raw xp", tostring(tripXp), "yellow")

    uiPrintSection("quick actions")
    uiPrintRow(18, "Party", "OPEN", "cyan", function() boop.ui.partyCommand("") end, "Open the party dashboard")
    uiPrintRow(19, "Mode controls", "OPEN", "cyan", function() boop.ui.modeCommand("") end, "Show operating mode summary")
    uiPrintRow(20, "Stats", "OPEN", "cyan", function() boop.stats.command("") end, "Open the stats dashboard")
    uiPrintRow(21, "Theme controls", "OPEN", "cyan", function() boop.ui.themeCommand("") end, "Show theme summary")
    uiPrintFooter("Type: boop control | boop party | boop roster | boop mode | boop stats")
    return
  end

  boop.util.echo("BOOP")
  boop.util.echo("----------------------------------------")
  boop.util.echo(string.format("State: %s | mode: %s | blocker: %s | next: %s", enabled, modeShown, blocker, nextAction))
  boop.util.echo(string.format("Class: %s | targeting: %s | ragemode: %s | assist: %s | targetcall: %s | walk: %s | theme: %s", tostring(class), targetingMode, rageMode, assistShown, targetCallShown, walkShown, themeShown))
  boop.util.echo("Target: " .. targetShown .. " | room denizens: " .. tostring(denizenCount))
  boop.util.echo(string.format("Trip: %s | kills %d | gold %d | xp %d", tripRunning, tripKills, tripGold, tripXp))
  boop.util.echo("Quick: boop control | boop party | boop roster | boop mode | boop stats")
end

local CONFIG_SECTIONS = {
  { id = 1, key = "combat", label = "Hunting", aliases = { "combat", "hunting", "queueing", "queue" } },
  { id = 2, key = "targeting", label = "Targeting", aliases = { "targeting", "targets" } },
  { id = 3, key = "loot", label = "Loot", aliases = { "loot", "gold", "import" } },
  { id = 4, key = "debug", label = "Diagnostics", aliases = { "debug", "diagnostics", "trace", "gag" } },
}

local function configSectionByKey(key)
  local k = boop.util.safeLower(boop.util.trim(key or ""))
  for _, section in ipairs(CONFIG_SECTIONS) do
    if section.key == k then
      return section
    end
    for _, alias in ipairs(section.aliases or {}) do
      if boop.util.safeLower(boop.util.trim(alias or "")) == k then
        return section
      end
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
    for _, alias in ipairs(section.aliases or {}) do
      if normalizeConfigToken(alias) == normalized then
        return section
      end
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

boop.ui._setScreen = configSetScreen

local function configHuntingSummary()
  return string.format(
    "%s | rage %s | queue %s | prequeue %s",
    boop.config.enabled and "on" or "off",
    tostring(boop.config.attackMode or "simple"),
    boolText(not not boop.config.useQueueing),
    boolText(not not boop.config.prequeueEnabled)
  )
end

local function configTargetingSummary()
  return string.format(
    "%s | order %s | retarget %s",
    tostring(boop.config.targetingMode or "whitelist"),
    tostring(boop.config.targetOrder or "order"),
    boolText(not not boop.config.retargetOnPriority)
  )
end

local function configLootSummary()
  local pack = boop.util.trim(boop.config.goldPack or "")
  if pack == "" then
    pack = "(off)"
  end
  return string.format(
    "autogold %s | pack %s",
    boolText(not not boop.config.autoGrabGold),
    pack
  )
end

local function configDebugSummary()
  return string.format(
    "trace %s | gag own %s | gag others %s",
    boolText(not not boop.config.traceEnabled),
    boolText(not not boop.config.gagOwnAttacks),
    boolText(not not boop.config.gagOthersAttacks)
  )
end

local function configPartySummary()
  local leader = assistLeader()
  if leader == "" then
    leader = "(none)"
  end
  return string.format(
    "%s | leader %s | size %s",
    operatingModeLabel(),
    leader,
    tostring(tonumber(boop.config.partySize) or 1)
  )
end

local function configThemeSummary()
  return "theme " .. activeThemeLabel()
end

local function configHomeRoute(token)
  local key = boop.util.safeLower(boop.util.trim(token or ""))
  if key == "" then
    return false
  end
  if key == "5" or key == "party" or key == "assist" or key == "leader" then
    boop.ui.partyCommand("")
    return true
  end
  if key == "6" or key == "roster" then
    boop.ui.rosterCommand("")
    return true
  end
  if key == "7" or key == "theme" or key == "appearance" then
    boop.ui.themeCommand("")
    return true
  end
  if key == "8" or key == "control" then
    boop.ui.controlCommand("")
    return true
  end
  if key == "9" or key == "stats" then
    boop.stats.command("")
    return true
  end
  if key == "mode" then
    boop.ui.modeCommand("")
    return true
  end
  return false
end

local function configRenderHome()
  configSetScreen("home")
  local blocker, nextAction = currentBlocker()
  local targetId = boop.state and boop.state.currentTargetId or ""
  local targetName = boop.state and boop.state.targetName or ""
  local targetShown = targetId ~= "" and (targetId .. " | " .. (targetName ~= "" and targetName or "(unnamed)")) or "(none)"

  if cecho then
    uiPrintHeader("configuration")

    uiPrintSection("overview")
    uiPrintRow(1, "Hunting", configHuntingSummary(), boop.config.enabled and "green" or "yellow", function()
      boop.ui.config("combat")
    end, "Open hunting settings")
    uiPrintRow(2, "Targeting", configTargetingSummary(), "cyan", function()
      boop.ui.config("targeting")
    end, "Open targeting settings")
    uiPrintRow(3, "Blocker", blocker, blocker == "ready" and "green" or "yellow")
    uiPrintRow(4, "Next action", nextAction, "cyan")
    uiPrintRow(5, "Target", targetShown, "cyan")

    uiPrintSection("settings")
    uiPrintRow(6, "Hunting settings", "OPEN", "cyan", function()
      boop.ui.config("combat")
    end, "Open hunting settings")
    uiPrintRow(7, "Targeting settings", "OPEN", "cyan", function()
      boop.ui.config("targeting")
    end, "Open targeting settings")
    uiPrintRow(8, "Loot settings", configLootSummary(), "yellow", function()
      boop.ui.config("loot")
    end, "Open loot settings")
    uiPrintRow(9, "Diagnostics", configDebugSummary(), "yellow", function()
      boop.ui.config("debug")
    end, "Open diagnostics settings")

    uiPrintSection("related controls")
    uiPrintRow(10, "Party dashboard", configPartySummary(), "cyan", function()
      boop.ui.partyCommand("")
    end, "Open the party dashboard")
    uiPrintRow(11, "Roster manager", tostring(#partyRosterMembers()) .. " entries", "cyan", function()
      boop.ui.rosterCommand("")
    end, "Open saved party roster")
    uiPrintRow(12, "Appearance", configThemeSummary(), "cyan", function()
      boop.ui.themeCommand("")
    end, "Open theme controls")
    uiPrintRow(13, "Control dashboard", "OPEN", "cyan", function()
      boop.ui.controlCommand("")
    end, "Open the control dashboard")
    uiPrintRow(14, "Stats dashboard", "OPEN", "cyan", function()
      boop.stats.command("")
    end, "Open the stats dashboard")
    uiPrintFooter("Type: boop config home | boop config <number> | boop config <name> | boop party | boop theme | boop control")
    return
  end

  boop.util.echo("CONFIGURATION")
  boop.util.echo("----------------------------------------")
  boop.util.echo(string.format("Hunting: %s", configHuntingSummary()))
  boop.util.echo(string.format("Targeting: %s | blocker: %s", configTargetingSummary(), blocker))
  boop.util.echo("Target: " .. targetShown .. " | next: " .. nextAction)
  boop.util.echo(string.format("[1] Hunting settings         [ OPEN ]"))
  boop.util.echo(string.format("[2] Targeting settings       [ OPEN ]"))
  boop.util.echo(string.format("[3] Loot settings            [ %s ]", configLootSummary()))
  boop.util.echo(string.format("[4] Diagnostics              [ %s ]", configDebugSummary()))
  boop.util.echo(string.format("[5] Party dashboard          [ %s ]", configPartySummary()))
  boop.util.echo(string.format("[6] Roster manager           [ %d entries ]", #partyRosterMembers()))
  boop.util.echo(string.format("[7] Appearance               [ %s ]", configThemeSummary()))
  boop.util.echo("[8] Control dashboard       [ OPEN ]")
  boop.util.echo("[9] Stats dashboard          [ OPEN ]")
  boop.util.echo("----------------------------------------")
  boop.util.echo("Type: boop config home")
  boop.util.echo("Type: boop config <number>  (example: boop config 1)")
  boop.util.echo("Type: boop config <name>    (example: boop config hunting)")
  boop.util.echo("Type: boop party | boop theme | boop control")
end

local function configRenderCombatSection()
  configSetScreen("combat")
  local tempoWindow = tonumber(boop.config.tempoRageWindowSeconds) or 10
  local tempoEta = tonumber(boop.config.tempoSqueezeEtaSeconds) or 2.5
  local lead = tonumber(boop.config.attackLeadSeconds) or 0
  local diagTimeout = tonumber(boop.config.diagTimeoutSeconds) or 0
  local blocker, nextAction = currentBlocker()
  local targetId = boop.state and boop.state.currentTargetId or ""
  local targetName = boop.state and boop.state.targetName or ""
  local targetShown = targetId ~= "" and (targetId .. " | " .. (targetName ~= "" and targetName or "(unnamed)")) or "(none)"
  if cecho then
    uiPrintHeader("configuration > hunting")
    uiPrintSection("overview")
    uiPrintRow(1, "Hunting", boolText(boop.config.enabled), boolColor(boop.config.enabled))
    uiPrintRow(2, "Rage mode", tostring(boop.config.attackMode or "simple"), "yellow")
    uiPrintRow(3, "Blocker", blocker, blocker == "ready" and "green" or "yellow")
    uiPrintRow(4, "Next action", nextAction, "cyan")
    uiPrintRow(5, "Target", targetShown, "cyan")

    uiPrintSection("actions")
    uiPrintRow(6, "Toggle hunting", boolText(boop.config.enabled), boolColor(boop.config.enabled), function()
      boop.ui.config("combat 1")
    end, "Toggle hunting enabled")
    uiPrintRow(7, "Change rage mode", tostring(boop.config.attackMode or "simple"), "yellow", function()
      boop.ui.config("combat 2")
    end, "Open ragemode menu")
    uiPrintRow(8, "Run diag", "RUN", "yellow", function()
      boop.ui.config("combat 3")
    end, "Queue diagnose and pause attacks")
    uiPrintRow(9, "Queueing", boolText(not not boop.config.useQueueing), boolColor(not not boop.config.useQueueing), function()
      boop.ui.config("combat 4")
    end, "Toggle queueing mode")
    uiPrintRow(10, "Prequeue", boolText(not not boop.config.prequeueEnabled), boolColor(not not boop.config.prequeueEnabled), function()
      boop.ui.config("combat 5")
    end, "Toggle prequeue")
    uiPrintRow(11, string.format("Attack lead (%.2fs)", lead), "SET", "yellow", function()
      boop.ui.config("combat 6")
    end, "Prepare boop lead command")
    uiPrintRow(12, string.format("Diag timeout (%.2fs)", diagTimeout), "SET", "yellow", function()
      boop.ui.config("combat 7")
    end, "Prepare boop set diagtimeout command")
    uiPrintRow(13, string.format("Tempo window (%.1fs)", tempoWindow), "SET", "yellow", function()
      boop.ui.config("combat 8")
    end, "Prepare boop set tempoRageWindowSeconds command")
    uiPrintRow(14, string.format("Tempo squeeze ETA (%.2fs)", tempoEta), "SET", "yellow", function()
      boop.ui.config("combat 9")
    end, "Prepare boop set tempoSqueezeEtaSeconds command")
    uiPrintRow(15, "Assist leader", assistStatusText(), boop.config.assistEnabled and "green" or "yellow", function()
      boop.ui.config("combat 10")
    end, "Prepare boop assist command")
    uiPrintRow(16, "Rage aff calls", boolText(not not boop.config.rageAffCalloutsEnabled), boolColor(not not boop.config.rageAffCalloutsEnabled), function()
      boop.ui.config("combat 11")
    end, "Toggle party affliction callouts")
    uiPrintFooter("Type: boop config home | boop config combat <number> | boop config back")
    return
  end
  boop.util.echo("CONFIGURATION > Hunting")
  boop.util.echo("----------------------------------------")
  boop.util.echo(string.format("Hunting: %s | rage %s | blocker: %s", boolText(boop.config.enabled), tostring(boop.config.attackMode or "simple"), blocker))
  boop.util.echo("Target: " .. targetShown .. " | next: " .. nextAction)
  boop.util.echo("[1] Toggle hunting           [ " .. boolText(boop.config.enabled) .. " ]")
  boop.util.echo("[2] Change rage mode         [ " .. tostring(boop.config.attackMode or "simple") .. " ]")
  boop.util.echo("[3] Run diag                 [ RUN ]")
  boop.util.echo("[4] Queueing                 [ " .. boolText(not not boop.config.useQueueing) .. " ]")
  boop.util.echo("[5] Prequeue                 [ " .. boolText(not not boop.config.prequeueEnabled) .. " ]")
  boop.util.echo(string.format("[6] Attack lead               [ %.2fs ]", lead))
  boop.util.echo(string.format("[7] Diag timeout              [ %.2fs ]", diagTimeout))
  boop.util.echo(string.format("[8] Tempo window              [ %.1fs ]", tempoWindow))
  boop.util.echo(string.format("[9] Tempo squeeze ETA         [ %.2fs ]", tempoEta))
  boop.util.echo("[10] Assist leader            [ " .. assistStatusText() .. " ]")
  boop.util.echo("[11] Rage aff calls           [ " .. boolText(not not boop.config.rageAffCalloutsEnabled) .. " ]")
  boop.util.echo("----------------------------------------")
  boop.util.echo("Type: boop config home | boop config combat <number> | boop config back")
end

local function configRenderTargetingSection()
  configSetScreen("targeting")
  local blocker, nextAction = currentBlocker()
  local denizenCount = boop.state and boop.state.denizens and #boop.state.denizens or 0
  local calledId = tostring((boop.state and boop.state.calledTargetId) or "")
  if calledId == "" then
    calledId = "(none)"
  end
  if cecho then
    uiPrintHeader("configuration > targeting")
    uiPrintSection("overview")
    uiPrintRow(1, "Mode", boop.config.targetingMode or "whitelist", "cyan")
    uiPrintRow(2, "Target order", boop.config.targetOrder or "order", "cyan")
    uiPrintRow(3, "Blocker", blocker, blocker == "ready" and "green" or "yellow")
    uiPrintRow(4, "Called target", calledId, "cyan")
    uiPrintRow(5, "Room denizens", tostring(denizenCount), "cyan")

    uiPrintSection("actions")
    uiPrintRow(6, "Targeting mode", boop.config.targetingMode or "whitelist", "cyan", function()
      boop.ui.config("targeting 1")
    end, "Cycle targeting mode")
    uiPrintRow(7, "Whitelist priority order", boolText(not not boop.config.whitelistPriorityOrder), boolColor(not not boop.config.whitelistPriorityOrder), function()
      boop.ui.config("targeting 2")
    end, "Toggle whitelist priority ordering")
    uiPrintRow(8, "Target order", boop.config.targetOrder or "order", "cyan", function()
      boop.ui.config("targeting 3")
    end, "Cycle target order")
    uiPrintRow(9, "Retarget on higher priority", boolText(not not boop.config.retargetOnPriority), boolColor(not not boop.config.retargetOnPriority), function()
      boop.ui.config("targeting 4")
    end, "Toggle retargeting when higher-priority mobs enter")
    uiPrintRow(10, "Leader target gate", boolText(not not boop.config.targetCall), boolColor(not not boop.config.targetCall), function()
      boop.ui.config("targeting 5")
    end, "Toggle waiting for leader target calls")
    uiPrintSection("list tools")
    uiPrintRow(11, "Whitelist manager", "OPEN", "green", function()
      boop.ui.config("targeting 6")
    end, "Open whitelist manager")
    uiPrintRow(12, "Whitelist browse", "OPEN", "green", function()
      boop.ui.config("targeting 7")
    end, "Open whitelist area browser")
    uiPrintRow(13, "Blacklist manager", "OPEN", "green", function()
      boop.ui.config("targeting 8")
    end, "Open blacklist manager")
    uiPrintFooter("Type: boop config home | boop config targeting <number> | boop config back")
    return
  end
  boop.util.echo("CONFIGURATION > Targeting")
  boop.util.echo("----------------------------------------")
  boop.util.echo(string.format("Mode: %s | order: %s | blocker: %s", tostring(boop.config.targetingMode or "whitelist"), tostring(boop.config.targetOrder or "order"), blocker))
  boop.util.echo("Called target: " .. calledId .. " | room denizens: " .. tostring(denizenCount) .. " | next: " .. nextAction)
  boop.util.echo("[1] Targeting mode            [ " .. tostring(boop.config.targetingMode or "whitelist") .. " ]")
  boop.util.echo("[2] Whitelist priority order  [ " .. boolText(not not boop.config.whitelistPriorityOrder) .. " ]")
  boop.util.echo("[3] Target order              [ " .. tostring(boop.config.targetOrder or "order") .. " ]")
  boop.util.echo("[4] Retarget on priority      [ " .. boolText(not not boop.config.retargetOnPriority) .. " ]")
  boop.util.echo("[5] Leader target gate        [ " .. boolText(not not boop.config.targetCall) .. " ]")
  boop.util.echo("[6] Whitelist manager         [ OPEN ]")
  boop.util.echo("[7] Whitelist browse          [ OPEN ]")
  boop.util.echo("[8] Blacklist manager         [ OPEN ]")
  boop.util.echo("----------------------------------------")
  boop.util.echo("Type: boop config home | boop config targeting <number> | boop config back")
end

local function configRenderLootSection()
  configSetScreen("loot")
  local pack = boop.util.trim(boop.config.goldPack or "")
  local shownPack = pack ~= "" and pack or "(off)"
  local pending = (boop.state and (boop.state.autoGrabGoldPending or boop.state.goldGetPending or boop.state.goldPutPending)) and "pending" or "idle"
  if cecho then
    uiPrintHeader("configuration > loot")
    uiPrintSection("overview")
    uiPrintRow(1, "Auto grab", boolText(not not boop.config.autoGrabGold), boolColor(not not boop.config.autoGrabGold))
    uiPrintRow(2, "Gold pack", shownPack, "yellow")
    uiPrintRow(3, "Gold queue", pending, pending == "idle" and "green" or "yellow")

    uiPrintSection("actions")
    uiPrintRow(4, "Auto grab sovereigns", boolText(not not boop.config.autoGrabGold), boolColor(not not boop.config.autoGrabGold), function()
      boop.ui.config("loot 1")
    end, "Toggle automatic sovereign pickup")
    uiPrintRow(5, "Gold pack container", shownPack, "yellow", function()
      boop.ui.config("loot 2")
    end, "Prepare boop pack command")
    uiPrintRow(6, "Clear gold pack", "OFF", "red", function()
      boop.ui.config("loot 3")
    end, "Disable auto stashing")
    uiPrintRow(7, "Gold pack test", "RUN", "yellow", function()
      boop.ui.config("loot 4")
    end, "Queue look in pack")
    uiPrintFooter("Type: boop config home | boop config loot <number> | boop config back")
    return
  end
  boop.util.echo("CONFIGURATION > Loot")
  boop.util.echo("----------------------------------------")
  boop.util.echo(string.format("Loot: autogold %s | pack %s | queue %s", boolText(not not boop.config.autoGrabGold), shownPack, pending))
  boop.util.echo("[1] Auto grab sovereigns      [ " .. boolText(not not boop.config.autoGrabGold) .. " ]")
  boop.util.echo("[2] Gold pack container       [ " .. shownPack .. " ]")
  boop.util.echo("[3] Clear gold pack           [ OFF ]")
  boop.util.echo("[4] Gold pack test            [ RUN ]")
  boop.util.echo("----------------------------------------")
  boop.util.echo("Type: boop config home | boop config loot <number> | boop config back")
end

local function configRenderDebugSection()
  configSetScreen("debug")
  local traceCount = boop.state and boop.state.traceBuffer and #boop.state.traceBuffer or 0
  if cecho then
    uiPrintHeader("configuration > debug")
    uiPrintSection("overview")
    uiPrintRow(1, "Trace logging", boolText(not not boop.config.traceEnabled), boolColor(not not boop.config.traceEnabled))
    uiPrintRow(2, "Trace entries", tostring(traceCount), "cyan")
    uiPrintRow(3, "Gag own attacks", boolText(not not boop.config.gagOwnAttacks), boolColor(not not boop.config.gagOwnAttacks))
    uiPrintRow(4, "Gag others attacks", boolText(not not boop.config.gagOthersAttacks), boolColor(not not boop.config.gagOthersAttacks))
    uiPrintRow(5, "Gag palette", boop.gag and boop.gag.paletteSummary and boop.gag.paletteSummary() or "AUTO", "cyan")

    uiPrintSection("actions")
    uiPrintRow(6, "Toggle trace logging", boolText(not not boop.config.traceEnabled), boolColor(not not boop.config.traceEnabled), function()
      boop.ui.config("debug 1")
    end, "Toggle trace logging")
    uiPrintRow(7, "Debug snapshot", "SHOW", "cyan", function()
      boop.ui.config("debug 2")
    end, "Show boop debug snapshot")
    uiPrintRow(8, "Trace buffer", "SHOW", "cyan", function()
      boop.ui.config("debug 3")
    end, "Show trace entries")
    uiPrintRow(9, "Clear trace", "CLEAR", "red", function()
      boop.ui.config("debug 4")
    end, "Clear trace buffer")
    uiPrintRow(10, "Toggle gag own attacks", boolText(not not boop.config.gagOwnAttacks), boolColor(not not boop.config.gagOwnAttacks), function()
      boop.ui.config("debug 5")
    end, "Toggle gagging your own attack lines")
    uiPrintRow(11, "Toggle gag others attacks", boolText(not not boop.config.gagOthersAttacks), boolColor(not not boop.config.gagOthersAttacks), function()
      boop.ui.config("debug 6")
    end, "Toggle gagging other players' attack lines")
    uiPrintRow(12, "Gag colors", boop.gag and boop.gag.paletteSummary and boop.gag.paletteSummary() or "AUTO", "cyan", function()
      boop.ui.config("debug 7")
    end, "Show gag color roles and sample output")
    uiPrintFooter("Type: boop config home | boop config debug <number> | boop config back")
    return
  end
  boop.util.echo("CONFIGURATION > Debug")
  boop.util.echo("----------------------------------------")
  boop.util.echo(string.format("Trace: %s | entries: %d | gag own %s | gag others %s | palette %s", boolText(not not boop.config.traceEnabled), traceCount, boolText(not not boop.config.gagOwnAttacks), boolText(not not boop.config.gagOthersAttacks), boop.gag and boop.gag.paletteSummary and boop.gag.paletteSummary() or "AUTO"))
  boop.util.echo("[1] Trace logging             [ " .. boolText(not not boop.config.traceEnabled) .. " ]")
  boop.util.echo("[2] Debug snapshot            [ SHOW ]")
  boop.util.echo("[3] Trace buffer              [ SHOW ]")
  boop.util.echo("[4] Clear trace               [ CLEAR ]")
  boop.util.echo("[5] Gag own attacks           [ " .. boolText(not not boop.config.gagOwnAttacks) .. " ]")
  boop.util.echo("[6] Gag others attacks        [ " .. boolText(not not boop.config.gagOthersAttacks) .. " ]")
  boop.util.echo("[7] Gag colors                [ " .. (boop.gag and boop.gag.paletteSummary and boop.gag.paletteSummary() or "AUTO") .. " ]")
  boop.util.echo("----------------------------------------")
  boop.util.echo("Type: boop config home | boop config debug <number> | boop config back")
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
      boop.ui.showRageModeMenu()
      return true
    elseif n == 3 then
      boop.ui.diag()
      return true
    elseif n == 4 then
      boop.ui.toggleConfigBool("useQueueing", true)
      return true
    elseif n == 5 then
      boop.ui.setPrequeueEnabled(not boop.config.prequeueEnabled)
      return true
    elseif n == 6 then
      uiSetCommandLine("boop lead ")
      return true
    elseif n == 7 then
      uiSetCommandLine("boop set diagtimeout ")
      return true
    elseif n == 8 then
      uiSetCommandLine("boop set tempoRageWindowSeconds ")
      return true
    elseif n == 9 then
      uiSetCommandLine("boop set tempoSqueezeEtaSeconds ")
      return true
    elseif n == 10 then
      uiSetCommandLine("boop assist ")
      return true
    elseif n == 11 then
      boop.ui.toggleConfigBool("rageAffCalloutsEnabled", true)
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
      boop.ui.toggleConfigBool("retargetOnPriority", true)
      return true
    elseif n == 5 then
      boop.ui.targetCallCommand(boop.config.targetCall and "off" or "on")
      return true
    elseif n == 6 then
      boop.targets.displayWhitelist()
      return true
    elseif n == 7 then
      boop.targets.displayWhitelistBrowse()
      return true
    elseif n == 8 then
      boop.targets.displayBlacklist()
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
    elseif n == 5 then
      boop.gag.setOwn(not boop.config.gagOwnAttacks)
      return true
    elseif n == 6 then
      boop.gag.setOthers(not boop.config.gagOthersAttacks)
      return true
    elseif n == 7 then
      boop.gag.showColors()
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

  if current == "home" and configHomeRoute(token) then
    return
  end

  local sectionPart, optionPart = raw:match("^%s*([%w_%-]+)%s+(%d+)%s*$")
  if sectionPart and optionPart then
    local requestedExplicit = configResolveSection(sectionPart)
    if requestedExplicit and configApplySectionOption(requestedExplicit.key, optionPart) then
      configRenderSection(requestedExplicit.key)
      return
    end
  end

  if current ~= "home" then
    local requestedByName = configResolveSection(token)
    if requestedByName then
      configRenderSection(requestedByName.key)
      return
    end
    if tonumber(token) and configHomeRoute(token) then
      return
    end
    if configApplySectionOption(current, token) then
      configRenderSection(current)
      return
    end
    boop.util.echo("Unknown option for " .. tostring(current) .. ": " .. tostring(arg))
    boop.util.echo("Use: boop config " .. tostring(current) .. " <number> | boop config back | boop config home")
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
  local blocker, nextAction = currentBlocker()
  local traceCount = boop.state and boop.state.traceBuffer and #boop.state.traceBuffer or 0
  local targetShown = "(none)"
  if currentTargetId ~= "" and currentTargetName ~= "" then
    targetShown = currentTargetId .. " | " .. currentTargetName
  elseif currentTargetId ~= "" then
    targetShown = currentTargetId
  elseif currentTargetName ~= "" then
    targetShown = currentTargetName
  end

  if cecho then
    uiPrintHeader("boop > debug snapshot")
    uiPrintSection("runtime")
    uiPrintRow(1, "Enabled", enabled, enabled == "on" and "green" or "yellow")
    uiPrintRow(2, "Mode", tostring(mode), "cyan")
    uiPrintRow(3, "Class", tostring(class), "cyan")
    uiPrintRow(4, "Blocker", blocker, blocker == "ready" and "green" or "yellow")
    uiPrintRow(5, "Next action", nextAction, "cyan")

    uiPrintSection("combat state")
    uiPrintRow(6, "Eq / Bal", string.format("%s / %s", tostring(eq), tostring(bal)), "cyan")
    uiPrintRow(7, "Rage", tostring(rage), "yellow")
    uiPrintRow(8, "Denizens", tostring(denizenCount), "cyan")
    uiPrintRow(9, "Target", targetShown, "cyan")

    uiPrintSection("diagnostics")
    uiPrintRow(10, "Trace entries", tostring(traceCount), "cyan")
    uiPrintRow(11, "Gag own", boolText(not not boop.config.gagOwnAttacks), boolColor(not not boop.config.gagOwnAttacks))
    uiPrintRow(12, "Gag others", boolText(not not boop.config.gagOthersAttacks), boolColor(not not boop.config.gagOthersAttacks))
    uiPrintFooter("Type: boop config home | boop config debug | boop trace show | boop debug attacks")
    return
  end

  boop.util.echo("DEBUG SNAPSHOT")
  boop.util.echo("----------------------------------------")
  boop.util.echo(string.format("Runtime: enabled %s | mode %s | class %s", enabled, tostring(mode), tostring(class)))
  boop.util.echo(string.format("Flow: blocker %s | next %s", blocker, nextAction))
  boop.util.echo(string.format("Combat: eq/bal %s/%s | rage %s | denizens %s", tostring(eq), tostring(bal), tostring(rage), tostring(denizenCount)))
  boop.util.echo("Target: " .. targetShown)
  boop.util.echo(string.format("Diagnostics: trace %d | gag own %s | gag others %s", traceCount, boolText(not not boop.config.gagOwnAttacks), boolText(not not boop.config.gagOthersAttacks)))
  boop.util.echo("Quick: boop config home | boop config debug | boop trace show | boop debug attacks")
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
