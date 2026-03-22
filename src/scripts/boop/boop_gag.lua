boop.gag = boop.gag or {}

local function nowSeconds()
  if getEpoch then
    return getEpoch()
  end
  return os.clock()
end

local function resolveCapture(expr, matchTable)
  if type(expr) ~= "table" then return "" end
  if expr.kind == "match" then
    local idx = tonumber(expr.index)
    if not idx or type(matchTable) ~= "table" then return "" end
    return tostring(matchTable[idx] or "")
  end
  if expr.kind == "literal" then
    return tostring(expr.value or "")
  end
  return ""
end

local function normName(name)
  local value = boop.util.trim(tostring(name or ""))
  value = value:gsub("\226\128\152", "'")
  value = value:gsub("\226\128\153", "'")
  return boop.util.safeLower(value)
end

local function isSelfActor(actor, rawLine)
  local value = boop.util.trim(actor or "")
  local lower = boop.util.safeLower(value)
  if lower == "you" then
    return true
  end

  local me = gmcp and gmcp.Char and gmcp.Char.Name and gmcp.Char.Name.name or ""
  if me ~= "" and boop.util.safeLower(me) == lower then
    return true
  end

  local lineText = boop.util.safeLower(boop.util.trim(rawLine or ""))
  if boop.util.starts(lineText, "you ") or boop.util.starts(lineText, "you:") then
    return true
  end

  return false
end

local function findLikelyActor(matchTable)
  if type(matchTable) ~= "table" then return "" end
  local me = gmcp and gmcp.Char and gmcp.Char.Name and gmcp.Char.Name.name or ""
  local meLower = boop.util.safeLower(me)
  for i = 2, #matchTable do
    local text = boop.util.trim(tostring(matchTable[i] or ""))
    local lower = boop.util.safeLower(text)
    if lower == "you" then
      return "You"
    end
    if text ~= "" and meLower ~= "" and lower == meLower then
      return me
    end
  end
  for i = 2, #matchTable do
    local text = boop.util.trim(tostring(matchTable[i] or ""))
    if text ~= "" then
      return text
    end
  end
  return ""
end

local function findLikelyTarget(matchTable, actor)
  if type(matchTable) ~= "table" then return "" end
  local actorNorm = normName(actor)

  if boop.targets and boop.targets.isDenizenName then
    for i = 2, #matchTable do
      local text = boop.util.trim(tostring(matchTable[i] or ""))
      if text ~= "" and normName(text) ~= actorNorm and boop.targets.isDenizenName(text) then
        return text
      end
    end
  end

  for i = 2, #matchTable do
    local text = boop.util.trim(tostring(matchTable[i] or ""))
    if text ~= "" and normName(text) ~= actorNorm then
      return text
    end
  end
  return ""
end

local function shouldSuppressDuplicate(rawLine)
  boop.state = boop.state or {}
  local lineText = tostring(rawLine or "")
  local ts = nowSeconds()
  local prevLine = boop.state.lastGagRawLine or ""
  local prevTs = tonumber(boop.state.lastGagAt) or 0
  if prevLine == lineText and (ts - prevTs) <= 0.05 then
    return true
  end
  boop.state.lastGagRawLine = lineText
  boop.state.lastGagAt = ts
  return false
end

local GAG_COLOR_KEYS = {
  own = {
    who = "gagColorWho",
    ability = "gagColorAbility",
    target = "gagColorTarget",
    meta = "gagColorMeta",
    separator = "gagColorSeparator",
    background = "gagColorBackground",
  },
  others = {
    who = "gagOtherColorWho",
    ability = "gagOtherColorAbility",
    target = "gagOtherColorTarget",
    meta = "gagOtherColorMeta",
    separator = "gagOtherColorSeparator",
    background = "gagOtherColorBackground",
  },
}

local GAG_SCOPE_ALIASES = {
  own = "own",
  self = "own",
  mine = "own",
  others = "others",
  other = "others",
}

local GAG_COLOR_ALIASES = {
  who = "who",
  actor = "who",
  name = "who",
  ability = "ability",
  action = "ability",
  what = "ability",
  target = "target",
  victim = "target",
  meta = "meta",
  suffix = "meta",
  details = "meta",
  separator = "separator",
  separators = "separator",
  sep = "separator",
  punctuation = "separator",
  punct = "separator",
  background = "background",
  bg = "background",
  highlight = "background",
}

local GAG_THEME_DEFAULTS = {
  who = "ok",
  ability = "info",
  target = "err",
  meta = "text",
  separator = "muted",
}

local GAG_FALLBACK_COLORS = {
  who = "green",
  ability = "cyan",
  target = "red",
  meta = "white",
  separator = "light_grey",
}

local GAG_COLOR_ORDER = { "who", "ability", "target", "meta", "separator", "background" }

local GAG_COLOR_LABELS = {
  who = "who",
  ability = "ability",
  target = "target",
  meta = "meta",
  separator = "separator",
  background = "background",
}

local GAG_SCOPE_LABELS = {
  own = "own",
  others = "others",
}

local GAG_ROLE_SAMPLE_TEXT = {
  who = "You",
  ability = "Attack",
  target = "a denizen",
  meta = " (1234 cutting - 8xCRIT) (Bal: 2.1s)",
  separator = ":  -> ",
  background = "sample highlight",
}

local function gagColorPalette()
  if agnosticdb and agnosticdb.colors and type(agnosticdb.colors.list) == "function" then
    local listed = agnosticdb.colors.list()
    if type(listed) == "table" and #listed > 0 then
      return listed
    end
  end
  return {
    "white", "silver", "grey", "light_grey", "dark_grey",
    "cyan", "light_blue", "cornflower_blue", "royal_blue", "midnight_blue",
    "forest_green", "green", "spring_green", "olive_drab", "pale_green",
    "yellow", "khaki", "orange", "gold", "goldenrod",
    "red", "tomato", "firebrick", "pink", "purple", "orchid",
  }
end

local function gagColorGroups()
  if agnosticdb and agnosticdb.colors and type(agnosticdb.colors.grouped) == "function" then
    local grouped = agnosticdb.colors.grouped()
    if type(grouped) == "table" and #grouped > 0 then
      return grouped
    end
  end
  return {
    { label = "Colors", colors = gagColorPalette() }
  }
end

local function normalizeGagRole(raw)
  local key = boop.util.safeLower(boop.util.trim(raw or ""))
  return GAG_COLOR_ALIASES[key] or ""
end

local function normalizeGagScope(raw)
  local key = boop.util.safeLower(boop.util.trim(raw or ""))
  if key == "" then
    return "own"
  end
  return GAG_SCOPE_ALIASES[key] or ""
end

local function unwrapColorToken(raw)
  local text = boop.util.trim(tostring(raw or ""))
  if text:sub(1, 1) == "<" and text:sub(-1) == ">" then
    text = text:sub(2, -2)
  end
  return boop.util.trim(text)
end

local function normalizeConfiguredColor(raw)
  local text = unwrapColorToken(raw)
  local lower = boop.util.safeLower(text)
  if lower == "" or lower == "off" or lower == "none" or lower == "clear" or lower == "inherit" or lower == "auto" or lower == "default" then
    return ""
  end
  return text
end

local function activeThemeTags()
  if boop.theme and boop.theme.tags then
    return boop.theme.tags()
  end
  return nil
end

local function defaultColorForRole(role)
  local theme = activeThemeTags() or {}
  local themeKey = GAG_THEME_DEFAULTS[role]
  local themed = themeKey and unwrapColorToken(theme[themeKey] or "") or ""
  if themed ~= "" then
    return themed
  end
  return GAG_FALLBACK_COLORS[role] or "white"
end

local function configuredColorForRole(scope, role)
  local normalizedScope = normalizeGagScope(scope)
  local key = GAG_COLOR_KEYS[normalizedScope] and GAG_COLOR_KEYS[normalizedScope][role]
  if key == nil or not boop.config then
    return ""
  end
  return normalizeConfiguredColor(boop.config[key])
end

local function effectiveColorForRole(scope, role)
  local configured = configuredColorForRole(scope, role)
  if configured ~= "" then
    return configured
  end
  if role == "background" then
    return ""
  end
  return defaultColorForRole(role)
end

local function renderTagForRole(scope, role)
  local foreground = effectiveColorForRole(scope, role)
  if foreground == "" then
    return ""
  end
  local background = effectiveColorForRole(scope, "background")
  if background ~= "" then
    return "<" .. foreground .. ":" .. background .. ">"
  end
  return "<" .. foreground .. ">"
end

local function renderSegment(scope, role, text)
  local value = tostring(text or "")
  if value == "" then
    return ""
  end
  local tag = renderTagForRole(scope, role)
  if tag == "" then
    return value
  end
  return tag .. value .. "<reset>"
end

local function configuredOrAutoText(scope, role)
  local configured = configuredColorForRole(scope, role)
  if configured ~= "" then
    return configured
  end
  if role == "background" then
    return "off"
  end
  return "auto (" .. defaultColorForRole(role) .. ")"
end

function boop.gag.paletteSummary(scope)
  local normalizedScope = normalizeGagScope(scope)
  local hasCustom = false
  for _, role in ipairs(GAG_COLOR_ORDER) do
    if configuredColorForRole(normalizedScope, role) ~= "" then
      hasCustom = true
      break
    end
  end
  return hasCustom and "CUSTOM" or "AUTO"
end

local function gagRoleStatusText(scope, role)
  local configured = configuredColorForRole(scope, role)
  if configured ~= "" then
    return configured
  end
  if role == "background" then
    return "off"
  end
  return "auto"
end

local function gagRoleSample(scope, role)
  local text = GAG_ROLE_SAMPLE_TEXT[role] or role
  return renderSegment(scope, role, text)
end

local function gagRowAutoLabel(role)
  if role == "background" then
    return "[ off ]"
  end
  return "[ auto ]"
end

local function gagRowAutoHint(role)
  if role == "background" then
    return "Disable the shared background highlight"
  end
  return "Use the theme-driven default color"
end

local function renderGagScopeLinks(currentScope)
  local theme = boop.theme and boop.theme.tags and boop.theme.tags() or {
    text = "<white>",
    info = "<cyan>",
    muted = "<light_grey>",
    reset = "<reset>",
  }

  cecho("\n  " .. theme.text .. "Scope: " .. theme.reset)
  for _, scope in ipairs({ "own", "others" }) do
    if scope == currentScope then
      cecho(theme.muted .. "[" .. GAG_SCOPE_LABELS[scope] .. "]" .. theme.reset)
    else
      cechoLink(theme.info .. "[" .. GAG_SCOPE_LABELS[scope] .. "]" .. theme.reset, function()
        boop.gag.showColors(scope)
      end, "Show " .. GAG_SCOPE_LABELS[scope] .. " gag colors", true)
    end
    cecho(" ")
  end
end

local function renderGagColorRows(scope)
  local theme = boop.theme and boop.theme.tags and boop.theme.tags() or {
    text = "<white>",
    muted = "<light_grey>",
    info = "<cyan>",
    reset = "<reset>",
  }

  for _, role in ipairs(GAG_COLOR_ORDER) do
    local label = GAG_COLOR_LABELS[role]
    cecho("\n" .. theme.text .. "  " .. string.format("%-10s", label) .. " " .. theme.reset)
    cecho(gagRoleSample(scope, role))
    cecho(theme.muted .. "  " .. gagRoleStatusText(scope, role) .. theme.reset)
    cecho(" ")
    cechoLink(theme.info .. "[color]" .. theme.reset, function()
      boop.gag.showColorPicker(scope, role)
    end, "Open color picker for " .. label, true)
    cecho(" ")
    cechoLink(theme.info .. gagRowAutoLabel(role) .. theme.reset, function()
      boop.gag.setColor(scope, role, "off")
    end, gagRowAutoHint(role), true)
  end
end

function boop.gag.showColors(scope)
  local normalizedScope = normalizeGagScope(scope)
  if cecho then
    if boop.ui and boop.ui._setScreen then
      boop.ui._setScreen("gag-colors")
    end
    if boop.ui and boop.ui._printHeader then
      boop.ui._printHeader("gag colors > " .. normalizedScope)
      boop.ui._printSection("sample")
      cecho(
        "\n  "
        .. renderSegment(normalizedScope, "who", normalizedScope == "own" and "You" or "Someone")
        .. renderSegment(normalizedScope, "separator", ": ")
        .. renderSegment(normalizedScope, "ability", "Attack")
        .. renderSegment(normalizedScope, "separator", " -> ")
        .. renderSegment(normalizedScope, "target", "a denizen")
        .. renderSegment(normalizedScope, "meta", " (1234 cutting - 8xCRIT) (Bal: 2.1s)")
      )
      renderGagScopeLinks(normalizedScope)
      boop.ui._printSection("roles")
      renderGagColorRows(normalizedScope)
      if boop.ui and boop.ui._printFooter then
        boop.ui._printFooter("Type: boop gag colors <own|others> | boop gag color [own|others] <role> <color|off> | boop gag color [own|others] <role> | boop gag color [own|others] reset")
      end
      return
    end
  end

  boop.util.info("gag colors (" .. normalizedScope .. "):")
  for _, role in ipairs(GAG_COLOR_ORDER) do
    boop.util.echo("  " .. GAG_COLOR_LABELS[role] .. ": " .. configuredOrAutoText(normalizedScope, role))
  end
  if cecho then
    cecho(
      "\n  sample: "
      .. renderSegment(normalizedScope, "who", normalizedScope == "own" and "You" or "Someone")
      .. renderSegment(normalizedScope, "separator", ": ")
      .. renderSegment(normalizedScope, "ability", "Attack")
      .. renderSegment(normalizedScope, "separator", " -> ")
      .. renderSegment(normalizedScope, "target", "a denizen")
      .. renderSegment(normalizedScope, "meta", " (1234 cutting - 8xCRIT) (Bal: 2.1s)")
    )
  else
    echo("\n  sample: " .. (normalizedScope == "own" and "You" or "Someone") .. ": Attack -> a denizen (1234 cutting - 8xCRIT) (Bal: 2.1s)")
  end
end

function boop.gag.showColorPicker(scope, role)
  if role == nil then
    role = scope
    scope = "own"
  end
  local normalizedScope = normalizeGagScope(scope)
  local normalizedRole = normalizeGagRole(role)
  if normalizedRole == "" then
    boop.util.warn("gag color role: use who|ability|target|meta|separator|bg")
    return
  end

  if not cecho or not boop.ui or not boop.ui._printHeader then
    boop.util.info("Use: boop gag color " .. normalizedScope .. " " .. normalizedRole .. " <color|off>")
    return
  end

  if boop.ui and boop.ui._setScreen then
    boop.ui._setScreen("gag-color-picker")
  end

  local theme = boop.theme and boop.theme.tags and boop.theme.tags() or {
    text = "<white>",
    info = "<cyan>",
    muted = "<light_grey>",
    reset = "<reset>",
  }

  boop.ui._printHeader("gag colors > " .. normalizedScope .. " > " .. normalizedRole)
  boop.ui._printSection("picker")
  cecho(theme.text .. "  Scope: " .. normalizedScope .. " | role: " .. normalizedRole .. " | current: " .. gagRoleStatusText(normalizedScope, normalizedRole) .. theme.reset)
  cecho(" ")
  cechoLink(theme.info .. "[back]" .. theme.reset, function()
    boop.gag.showColors(normalizedScope)
  end, "Back to gag colors", true)
  cecho("\n")
  cecho(theme.text .. "  Sample: " .. theme.reset .. gagRoleSample(normalizedScope, normalizedRole) .. "\n")
  cecho(theme.text .. "  ")
  cechoLink(theme.info .. gagRowAutoLabel(normalizedRole) .. theme.reset, function()
    boop.gag.setColor(normalizedScope, normalizedRole, "off")
  end, gagRowAutoHint(normalizedRole), true)
  cecho("\n")

  for _, group in ipairs(gagColorGroups()) do
    boop.ui._printSection(group.label or "colors")
    cecho(theme.text .. "  " .. theme.reset)
    local lineLen = 2
    for _, color in ipairs(group.colors or {}) do
      local label = tostring(color)
      local entryLen = #label + 2
      if lineLen + entryLen > 72 then
        cecho("\n" .. theme.text .. "  " .. theme.reset)
        lineLen = 2
      end
      cechoLink("<" .. label .. ">[" .. label .. "]<reset>", function()
        boop.gag.setColor(normalizedScope, normalizedRole, label)
      end, "Set " .. normalizedRole .. " to " .. label, true)
      cecho("  ")
      lineLen = lineLen + entryLen
    end
    cecho("\n")
  end
end

function boop.gag.setColor(scope, role, rawValue)
  if rawValue == nil then
    rawValue = role
    role = scope
    scope = "own"
  end
  local normalizedScope = normalizeGagScope(scope)
  local normalizedRole = normalizeGagRole(role)
  if normalizedRole == "" then
    boop.util.warn("gag color role: use who|ability|target|meta|separator|bg")
    return
  end

  local value = normalizeConfiguredColor(rawValue)
  local key = GAG_COLOR_KEYS[normalizedScope] and GAG_COLOR_KEYS[normalizedScope][normalizedRole]
  boop.config[key] = value
  if boop.db and boop.db.saveConfig then
    boop.db.saveConfig(key, value)
  end

  if normalizedRole == "background" then
    boop.util.ok("gag " .. normalizedScope .. " background color: " .. (value ~= "" and value or "off"))
  else
    boop.util.ok("gag " .. normalizedScope .. " " .. GAG_COLOR_LABELS[normalizedRole] .. " color: " .. (value ~= "" and value or "auto"))
  end
  local returnScreen = boop.ui and boop.ui.consumeConfigReturnScreen and boop.ui.consumeConfigReturnScreen("debug") or ""
  if returnScreen == "debug" and boop.ui and boop.ui.config then
    boop.ui.config("debug")
    return
  end
  boop.gag.showColors(normalizedScope)
end

function boop.gag.resetColors(scope)
  local normalizedScope = normalizeGagScope(scope)
  for _, role in ipairs(GAG_COLOR_ORDER) do
    local key = GAG_COLOR_KEYS[normalizedScope] and GAG_COLOR_KEYS[normalizedScope][role]
    boop.config[key] = ""
    if boop.db and boop.db.saveConfig then
      boop.db.saveConfig(key, "")
    end
  end
  boop.util.ok("gag " .. normalizedScope .. " colors: reset")
  local returnScreen = boop.ui and boop.ui.consumeConfigReturnScreen and boop.ui.consumeConfigReturnScreen("debug") or ""
  if returnScreen == "debug" and boop.ui and boop.ui.config then
    boop.ui.config("debug")
    return
  end
  boop.gag.showColors(normalizedScope)
end

local function emitReplacement(actor, ability, victim, selfActor)
  local who = boop.util.trim(actor or "")
  if selfActor then
    who = "You"
  elseif who == "" then
    who = "Unknown"
  end

  local what = boop.util.trim(ability or "")
  if what == "" then
    what = "Attack"
  end

  local target = boop.util.trim(victim or "")
  if target == "" then
    target = "(none)"
  end

  local msg = string.format("%s: %s -> %s", who, what, target)
  if cecho then
    local scope = selfActor and "own" or "others"
    cecho(
      "\n"
      .. renderSegment(scope, "who", who)
      .. renderSegment(scope, "separator", ": ")
      .. renderSegment(scope, "ability", what)
      .. renderSegment(scope, "separator", " -> ")
      .. renderSegment(scope, "target", target)
    )
  else
    echo("\n" .. msg)
  end
end

local function emitSimple(who, ability)
  local actor = boop.util.trim(who or "")
  if actor == "" then actor = "You" end
  local what = boop.util.trim(ability or "")
  if what == "" then what = "Action" end

  if cecho then
    cecho("\n" .. renderSegment("own", "who", actor) .. renderSegment("own", "separator", ": ") .. renderSegment("own", "ability", what))
  else
    echo("\n" .. actor .. ": " .. what)
  end
end

local function emitAttackSummary(entry)
  if type(entry) ~= "table" then return end
  local who = boop.util.trim(entry.who or "You")
  local what = boop.util.trim(entry.ability or "Attack")
  local target = boop.util.trim(entry.target or "(none)")
  local damage = boop.util.trim(entry.damageText or "")
  local crit = boop.util.trim(entry.critText or "")
  local bal = boop.util.trim(entry.balanceText or "")

  local suffix = ""
  if damage ~= "" and crit ~= "" then
    suffix = suffix .. " (" .. damage .. " - " .. crit .. ")"
  elseif damage ~= "" then
    suffix = suffix .. " (" .. damage .. ")"
  elseif crit ~= "" then
    suffix = suffix .. " (" .. crit .. ")"
  end
  if bal ~= "" then
    suffix = suffix .. " (Bal: " .. bal .. ")"
  end

  if cecho then
    cecho(
      "\n"
      .. renderSegment("own", "who", who)
      .. renderSegment("own", "separator", ": ")
      .. renderSegment("own", "ability", what)
      .. renderSegment("own", "separator", " -> ")
      .. renderSegment("own", "target", target)
      .. renderSegment("own", "meta", suffix)
    )
  else
    echo("\n" .. string.format("%s: %s -> %s%s", who, what, target, suffix))
  end
end

local function emitKillSummary(target, xp)
  local victim = boop.util.trim(target or "")
  if victim == "" then victim = "(unknown)" end
  local xpText = boop.util.trim(xp or "")

  local suffix = ""
  if xpText ~= "" then
    suffix = " (" .. xpText .. "xp)"
  end

  if cecho then
    cecho(
      "\n"
      .. renderSegment("own", "who", "You")
      .. renderSegment("own", "separator", ": ")
      .. renderSegment("own", "ability", "Killed")
      .. renderSegment("own", "separator", " -> ")
      .. renderSegment("own", "target", victim)
      .. renderSegment("own", "meta", suffix)
    )
  else
    echo("\nYou: Killed -> " .. victim .. suffix)
  end
end

local function deleteCurrent()
  if selectCurrentLine then
    selectCurrentLine()
  end
  if deleteLine then
    deleteLine()
  end
end

local function cancelAttackSummaryTimer()
  boop.state = boop.state or {}
  if boop.state.gagPendingAttackTimer then
    killTimer(boop.state.gagPendingAttackTimer)
    boop.state.gagPendingAttackTimer = nil
  end
end

local flushPendingKill

local function flushPendingAttack()
  boop.state = boop.state or {}
  local pending = boop.state.gagPendingAttack
  if not pending then return end
  boop.state.gagPendingAttack = nil
  cancelAttackSummaryTimer()
  emitAttackSummary(pending)
  if flushPendingKill then
    flushPendingKill()
  end
end

local function setPendingAttack(who, ability, target)
  boop.state = boop.state or {}
  if boop.state.gagPendingAttack then
    flushPendingAttack()
  end

  boop.state.gagPendingAttack = {
    who = boop.util.trim(who or "You"),
    ability = boop.util.trim(ability or "Attack"),
    target = boop.util.trim(target or "(none)"),
    damageText = "",
    critText = "",
    balanceText = "",
  }

  cancelAttackSummaryTimer()
  boop.state.gagPendingAttackTimer = tempTimer(1.2, function()
    boop.state.gagPendingAttackTimer = nil
    flushPendingAttack()
  end)
end

local function cancelKillSummaryTimer()
  boop.state = boop.state or {}
  if boop.state.gagPendingKillTimer then
    killTimer(boop.state.gagPendingKillTimer)
    boop.state.gagPendingKillTimer = nil
  end
end

local function scheduleKillSummaryRetry()
  boop.state = boop.state or {}
  cancelKillSummaryTimer()
  boop.state.gagPendingKillTimer = tempTimer(0.25, function()
    boop.state.gagPendingKillTimer = nil
    if flushPendingKill then
      flushPendingKill()
    end
  end)
end

flushPendingKill = function()
  boop.state = boop.state or {}
  local pending = boop.state.gagPendingKill
  if not pending then return end
  if boop.state.gagPendingAttack then
    scheduleKillSummaryRetry()
    return
  end
  boop.state.gagPendingKill = nil
  cancelKillSummaryTimer()
  emitKillSummary(pending.target or "", pending.xp or "")
end

local function setPendingKill(target)
  boop.state = boop.state or {}
  boop.state.gagPendingKill = {
    target = boop.util.trim(target or ""),
    xp = "",
  }
  cancelKillSummaryTimer()
  boop.state.gagPendingKillTimer = tempTimer(1.2, function()
    boop.state.gagPendingKillTimer = nil
    flushPendingKill()
  end)
end

local function resolveCritText(rawCrit)
  local key = boop.util.safeLower(boop.util.trim(rawCrit or ""))
  if key == "" then return "" end
  key = key:gsub("%-", " ")
  key = key:gsub("%s+", " ")
  key = key:upper()

  local map = {
    ["CRITICAL"] = "2xCRIT",
    ["CRUSHING CRITICAL"] = "4xCRIT",
    ["OBLITERATING CRITICAL"] = "8xCRIT",
    ["ANNIHILATINGLY POWERFUL CRITICAL"] = "16xCRIT",
    ["WORLD SHATTERING CRITICAL"] = "32xCRIT",
  }

  return map[key] or ""
end

function boop.gag.showStatus()
  boop.util.info("gag own attacks: " .. (boop.config.gagOwnAttacks and "on" or "off"))
  boop.util.info("gag others attacks: " .. (boop.config.gagOthersAttacks and "on" or "off"))
  boop.util.info("gag own palette: " .. boop.gag.paletteSummary("own"))
  boop.util.info("gag others palette: " .. boop.gag.paletteSummary("others"))
  boop.util.info("Use: boop gag colors [own|others] | boop gag color [own|others] <role> <color|off>")
end

function boop.gag.setOwn(value)
  local enabled = value and true or false
  boop.config.gagOwnAttacks = enabled
  if boop.db and boop.db.saveConfig then
    boop.db.saveConfig("gagOwnAttacks", enabled)
  end
  boop.util.ok("gag own attacks: " .. (enabled and "on" or "off"))
end

function boop.gag.setOthers(value)
  local enabled = value and true or false
  boop.config.gagOthersAttacks = enabled
  if boop.db and boop.db.saveConfig then
    boop.db.saveConfig("gagOthersAttacks", enabled)
  end
  boop.util.ok("gag others attacks: " .. (enabled and "on" or "off"))
end

function boop.gag.setBoth(value)
  boop.gag.setOwn(value)
  boop.gag.setOthers(value)
end

function boop.gag.onAttackLine(spec, matchTable, rawLine)
  if shouldSuppressDuplicate(rawLine) then
    return
  end

  local actor = boop.util.trim(resolveCapture(spec and spec.actor, matchTable))
  if actor == "" then
    actor = findLikelyActor(matchTable)
  end
  local selfActor = isSelfActor(actor, rawLine)

  local victim = boop.util.trim(resolveCapture(spec and spec.target, matchTable))
  if victim == "" then
    victim = findLikelyTarget(matchTable, actor)
  end
  if victim == "" and selfActor then
    victim = boop.state and boop.state.targetName or ""
  end

  local ability = boop.util.trim(spec and spec.ability or "")

  if boop.stats and boop.stats.onAttackLine then
    boop.stats.onAttackLine(actor, selfActor, ability, victim)
  end

  if selfActor and not boop.config.gagOwnAttacks then
    return
  end
  if (not selfActor) and not boop.config.gagOthersAttacks then
    return
  end

  if not boop.config then return end
  if not boop.config.gagOwnAttacks and not boop.config.gagOthersAttacks then
    return
  end

  deleteCurrent()

  if selfActor then
    setPendingAttack("You", ability, victim)
  else
    emitReplacement(actor, ability, victim, false)
  end

  if boop.trace and boop.trace.log then
    boop.trace.log(string.format("gag: %s | actor=%s | ability=%s | target=%s", selfActor and "self" or "other", actor ~= "" and actor or "?", ability ~= "" and ability or "?", victim ~= "" and victim or "?"))
  end
end

function boop.gag.onBattlefurySpeed(_rawLine)
  if not boop.config or not boop.config.gagOwnAttacks then
    return
  end
  deleteCurrent()
  emitSimple("You", "Battlefury (Speed)")
end

function boop.gag.onDamageLine(amount, dtype, _rawLine)
  if boop.stats and boop.stats.onAttackDamage then
    boop.stats.onAttackDamage(amount)
  end
  if not boop.config or not boop.config.gagOwnAttacks then
    return
  end
  deleteCurrent()

  boop.state = boop.state or {}
  local pending = boop.state.gagPendingAttack
  if not pending then
    return
  end

  local num = boop.util.trim(tostring(amount or "")):gsub(",", "")
  local kind = boop.util.trim(dtype or "")
  if num ~= "" and kind ~= "" then
    pending.damageText = num .. " " .. kind
  elseif num ~= "" then
    pending.damageText = num
  elseif kind ~= "" then
    pending.damageText = kind
  end
end

function boop.gag.onCriticalLine(critLabel, _rawLine)
  if boop.stats and boop.stats.onAttackCritical then
    boop.stats.onAttackCritical(critLabel)
  end
  if not boop.config or not boop.config.gagOwnAttacks then
    return
  end

  boop.state = boop.state or {}
  local pending = boop.state.gagPendingAttack
  if not pending then
    return
  end

  local critText = resolveCritText(critLabel or "")
  if critText == "" then
    return
  end

  deleteCurrent()
  pending.critText = critText
end

function boop.gag.onCompanionMaulFlavor(target, _rawLine)
  if not boop.config or not boop.config.gagOwnAttacks then
    return
  end

  boop.state = boop.state or {}
  local pending = boop.state.gagPendingAttack
  if not pending then
    return
  end

  local ability = boop.util.safeLower(boop.util.trim(pending.ability or ""))
  if ability ~= "hound maul" and ability ~= "hyena maul" then
    return
  end

  local pendingTarget = normName(pending.target or "")
  local seenTarget = normName(target or "")
  if pendingTarget ~= "" and seenTarget ~= "" and pendingTarget ~= seenTarget then
    return
  end

  deleteCurrent()
end

function boop.gag.onBalanceUsed(seconds, _rawLine)
  if boop.stats and boop.stats.onAttackBalance then
    boop.stats.onAttackBalance(seconds)
  end
  if not boop.config or not boop.config.gagOwnAttacks then
    return
  end
  deleteCurrent()

  boop.state = boop.state or {}
  local pending = boop.state.gagPendingAttack
  if not pending then
    return
  end

  local sec = boop.util.trim(tostring(seconds or ""))
  if sec ~= "" then
    pending.balanceText = sec .. "s"
  end
  flushPendingAttack()
end

function boop.gag.onSlainLine(target, rawLine, killer)
  local actor = boop.util.trim(killer or "")
  local selfActor = true
  if actor ~= "" then
    selfActor = isSelfActor(actor, rawLine)
  elseif boop.util.trim(rawLine or "") ~= "" then
    selfActor = isSelfActor("you", rawLine)
  end

  if selfActor and boop.stats and boop.stats.onKillObserved then
    boop.stats.onKillObserved(target or "")
  end
  if selfActor and boop.stats and boop.stats.onKillLine then
    boop.stats.onKillLine(target or "")
  end
  if not selfActor then
    return
  end
  if not boop.config or not boop.config.gagOwnAttacks then
    return
  end
  deleteCurrent()
  setPendingKill(target or "")
end

function boop.gag.onExperienceLine(xp, _rawLine)
  if not boop.config or not boop.config.gagOwnAttacks then
    return
  end

  boop.state = boop.state or {}
  local pending = boop.state.gagPendingKill
  if not pending then
    return
  end

  deleteCurrent()
  pending.xp = boop.util.trim(tostring(xp or "")):gsub(",", "")
  flushPendingKill()
end

function boop.gag.onPrompt()
  if not boop.config or not boop.config.gagOwnAttacks then
    return
  end

  boop.state = boop.state or {}
  if boop.state.gagPendingAttack then
    flushPendingAttack()
  elseif boop.state.gagPendingKill then
    flushPendingKill()
  end
end
