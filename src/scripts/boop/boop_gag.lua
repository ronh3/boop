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
  local prevLine = boop.state.gag.lastRawLine or ""
  local prevTs = tonumber(boop.state.gag.lastAt) or 0
  if prevLine == lineText and (ts - prevTs) <= 0.05 then
    return true
  end
  boop.state.gag.lastRawLine = lineText
  boop.state.gag.lastAt = ts
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
  mobs = {
    who = "gagMobColorWho",
    ability = "gagMobColorAbility",
    target = "gagMobColorTarget",
    meta = "gagMobColorMeta",
    separator = "gagMobColorSeparator",
    background = "gagMobColorBackground",
  },
}

local GAG_SCOPE_ALIASES = {
  own = "own",
  self = "own",
  mine = "own",
  others = "others",
  other = "others",
  mobs = "mobs",
  mob = "mobs",
  incoming = "mobs",
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
  mobs = "mobs",
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
  local normalizedScope = normalizeGagScope(scope)
  if normalizedScope == "mobs" then
    if role == "who" then return renderSegment(normalizedScope, role, "Mob") end
    if role == "ability" then return renderSegment(normalizedScope, role, "Damage") end
    if role == "target" then return renderSegment(normalizedScope, role, "You") end
    if role == "meta" then return renderSegment(normalizedScope, role, " (649 asphyxiation)") end
  end

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
  for _, scope in ipairs({ "own", "others", "mobs" }) do
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
  if normalizedScope == "" then
    boop.util.warn("gag color scope: use own|others|mobs")
    return
  end
  local sampleWho = normalizedScope == "own" and "You" or normalizedScope == "mobs" and "Mob" or "Someone"
  local sampleAbility = normalizedScope == "mobs" and "Damage" or "Attack"
  local sampleTarget = normalizedScope == "mobs" and "You" or "a denizen"
  local sampleMeta = normalizedScope == "mobs" and " (649 asphyxiation)" or " (1234 cutting - 8xCRIT) (Bal: 2.1s)"
  if cecho then
    if boop.ui and boop.ui._setScreen then
      boop.ui._setScreen("gag-colors")
    end
    if boop.ui and boop.ui._printHeader then
      boop.ui._printHeader("gag colors > " .. normalizedScope)
      boop.ui._printSection("sample")
      cecho(
        "\n  "
        .. renderSegment(normalizedScope, "who", sampleWho)
        .. renderSegment(normalizedScope, "separator", ": ")
        .. renderSegment(normalizedScope, "ability", sampleAbility)
        .. renderSegment(normalizedScope, "separator", " -> ")
        .. renderSegment(normalizedScope, "target", sampleTarget)
        .. renderSegment(normalizedScope, "meta", sampleMeta)
      )
      renderGagScopeLinks(normalizedScope)
      boop.ui._printSection("roles")
      renderGagColorRows(normalizedScope)
      if boop.ui and boop.ui._printFooter then
        boop.ui._printFooter("Type: boop gag colors <own|others|mobs> | boop gag color [own|others|mobs] <role> <color|off> | boop gag color [own|others|mobs] <role> | boop gag color [own|others|mobs] reset")
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
      .. renderSegment(normalizedScope, "who", sampleWho)
      .. renderSegment(normalizedScope, "separator", ": ")
      .. renderSegment(normalizedScope, "ability", sampleAbility)
      .. renderSegment(normalizedScope, "separator", " -> ")
      .. renderSegment(normalizedScope, "target", sampleTarget)
      .. renderSegment(normalizedScope, "meta", sampleMeta)
    )
  else
    boop.util.echo("  sample: " .. sampleWho .. ": " .. sampleAbility .. " -> " .. sampleTarget .. sampleMeta)
  end
end

function boop.gag.showColorPicker(scope, role)
  if role == nil then
    role = scope
    scope = "own"
  end
  local normalizedScope = normalizeGagScope(scope)
  local normalizedRole = normalizeGagRole(role)
  if normalizedScope == "" then
    boop.util.warn("gag color scope: use own|others|mobs")
    return
  end
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
  if normalizedScope == "" then
    boop.util.warn("gag color scope: use own|others|mobs")
    return
  end
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
  if normalizedScope == "" then
    boop.util.warn("gag color scope: use own|others|mobs")
    return
  end
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

local function formatDamageText(amount, dtype)
  local num = boop.util.trim(tostring(amount or "")):gsub(",", "")
  local kind = boop.util.trim(dtype or "")
  if num ~= "" and kind ~= "" then
    return num .. " " .. kind
  end
  if num ~= "" then
    return num
  end
  return kind
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
  local showPartSources = type(entry.abilityParts) == "table" and #entry.abilityParts > 1
  if type(entry.damageParts) == "table" and #entry.damageParts > 0 then
    for _, part in ipairs(entry.damageParts) do
      local partDamage = boop.util.trim(part and part.damageText or "")
      local partCrit = boop.util.trim(part and part.critText or "")
      local partSource = boop.util.trim(part and part.source or "")
      local label = ""
      if showPartSources and partSource ~= "" then
        label = partSource .. ": "
      end
      if partDamage ~= "" and partCrit ~= "" then
        suffix = suffix .. " (" .. label .. partDamage .. " - " .. partCrit .. ")"
      elseif partDamage ~= "" then
        suffix = suffix .. " (" .. label .. partDamage .. ")"
      elseif partCrit ~= "" then
        suffix = suffix .. " (" .. label .. partCrit .. ")"
      end
    end
  else
    if damage ~= "" and crit ~= "" then
      suffix = suffix .. " (" .. damage .. " - " .. crit .. ")"
    elseif damage ~= "" then
      suffix = suffix .. " (" .. damage .. ")"
    elseif crit ~= "" then
      suffix = suffix .. " (" .. crit .. ")"
    end
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

local function emitMobDamageSummary(mob, damageText)
  local actor = boop.util.trim(mob or "")
  if actor == "" then actor = "Mob" end

  local damage = boop.util.trim(damageText or "")
  local suffix = ""
  if damage ~= "" then
    suffix = " (" .. damage .. ")"
  end

  if cecho then
    cecho(
      "\n"
      .. renderSegment("mobs", "who", actor)
      .. renderSegment("mobs", "separator", ": ")
      .. renderSegment("mobs", "ability", "Damage")
      .. renderSegment("mobs", "separator", " -> ")
      .. renderSegment("mobs", "target", "You")
      .. renderSegment("mobs", "meta", suffix)
    )
  else
    echo("\n" .. string.format("%s: Damage -> You%s", actor, suffix))
  end
end

local function deleteCurrent()
  if selectCurrentLine then
    selectCurrentLine()
  end
  if deleteLine then
    deleteLine()
  end
  if deselect then
    deselect()
  end
end

local function scheduleGagTimer(seconds, fn)
  if type(tempTimer) ~= "function" then
    return nil
  end
  local ok, timerId = pcall(tempTimer, seconds, fn)
  if not ok then
    if boop.trace and boop.trace.log then
      boop.trace.log("gag timer failed: " .. tostring(timerId or "unknown error"))
    end
    return nil
  end
  return timerId
end

local function cancelAttackSummaryTimer()
  boop.state = boop.state or {}
  boop.state.gag = boop.state.gag or {}
  if boop.state.gag.pendingAttackTimer and type(killTimer) == "function" then
    killTimer(boop.state.gag.pendingAttackTimer)
  end
  boop.state.gag.pendingAttackTimer = nil
end

local function cancelMobDamageTimer()
  boop.state = boop.state or {}
  boop.state.gag = boop.state.gag or {}
  if boop.state.gag.pendingMobDamageTimer and type(killTimer) == "function" then
    killTimer(boop.state.gag.pendingMobDamageTimer)
  end
  boop.state.gag.pendingMobDamageTimer = nil
end

local function clearPendingMobDamage()
  boop.state = boop.state or {}
  boop.state.gag = boop.state.gag or {}
  cancelMobDamageTimer()
  boop.state.gag.pendingMobAttack = nil
end

local function scheduleMobDamageTimer()
  boop.state = boop.state or {}
  boop.state.gag = boop.state.gag or {}
  cancelMobDamageTimer()
  boop.state.gag.pendingMobDamageTimer = scheduleGagTimer(1.2, function()
    boop.state.gag.pendingMobDamageTimer = nil
    boop.state.gag.pendingMobAttack = nil
  end)
end

local flushPendingKill

local function flushPendingAttack()
  boop.state = boop.state or {}
  boop.state.gag = boop.state.gag or {}
  local pending = boop.state.gag.pendingAttack
  if not pending then return end
  boop.state.gag.pendingAttack = nil
  cancelAttackSummaryTimer()
  emitAttackSummary(pending)
  if flushPendingKill then
    flushPendingKill()
  end
end

local function samePendingAttack(pending, who, ability, target)
  if type(pending) ~= "table" then
    return false
  end
  if normName(pending.who or "") ~= normName(who or "") then
    return false
  end
  if normName(pending.target or "") ~= normName(target or "") then
    return false
  end
  local pendingAbility = normName(pending.ability or "")
  local nextAbility = normName(ability or "")
  if boop.util.trim(pending.balanceText or "") ~= "" then
    return pendingAbility == "razeslash" and nextAbility == "jab"
  end
  if pendingAbility == "razeslash" and nextAbility == "jab" then
    return true
  end
  return (pendingAbility == "jab" or pendingAbility == "dsl")
    and (nextAbility == "jab" or nextAbility == "dsl")
end

local function addPendingAbilityPart(pending, ability)
  if type(pending) ~= "table" then
    return
  end

  local label = boop.util.trim(ability or "")
  if label == "" then
    return
  end

  pending.abilityParts = pending.abilityParts or {}
  for _, existing in ipairs(pending.abilityParts) do
    if normName(existing) == normName(label) then
      return
    end
  end

  pending.abilityParts[#pending.abilityParts + 1] = label
  pending.ability = table.concat(pending.abilityParts, " + ")
end

local function pendingHasAbilityPart(pending, ability)
  if type(pending) ~= "table" or type(pending.abilityParts) ~= "table" then
    return false
  end

  local wanted = normName(ability or "")
  if wanted == "" then
    return false
  end

  for _, existing in ipairs(pending.abilityParts) do
    if normName(existing) == wanted then
      return true
    end
  end
  return false
end

local function isDualBluntAbility(ability)
  local value = normName(ability or "")
  return value == "doublewhirl" or value == "whirl"
end

local function canAppendPsionShatterPrefix(pending, who, ability, target)
  if type(pending) ~= "table" then
    return false
  end
  if normName(pending.who or "") ~= normName(who or "") then
    return false
  end
  if normName(pending.target or "") ~= normName(target or "") then
    return false
  end
  if boop.util.trim(pending.balanceText or "") ~= "" then
    return false
  end

  local firstAbility = pending.abilityParts and pending.abilityParts[1] or pending.ability
  local pendingAbility = normName(firstAbility or "")
  local nextAbility = normName(ability or "")
  return pendingAbility == "shatter" and nextAbility ~= "" and nextAbility ~= "shatter"
end

local function canAppendDualBluntHit(pending, who, ability, target)
  if type(pending) ~= "table" then
    return false
  end
  if not isDualBluntAbility(ability) then
    return false
  end
  if normName(pending.who or "") ~= normName(who or "") then
    return false
  end
  if normName(pending.target or "") ~= normName(target or "") then
    return false
  end
  if boop.util.trim(pending.balanceText or "") ~= "" then
    return false
  end

  return pendingHasAbilityPart(pending, ability)
    or pendingHasAbilityPart(pending, "Hyena Maul")
    or pendingHasAbilityPart(pending, "Hound Maul")
end

local function rescheduleAttackSummaryTimer()
  cancelAttackSummaryTimer()
  boop.state.gag.pendingAttackTimer = scheduleGagTimer(1.2, function()
    boop.state.gag.pendingAttackTimer = nil
    flushPendingAttack()
  end)
  return boop.state.gag.pendingAttackTimer == nil
end

local function setPendingAttack(who, ability, target)
  boop.state = boop.state or {}
  boop.state.gag = boop.state.gag or {}
  local normalizedWho = boop.util.trim(who or "You")
  local normalizedAbility = boop.util.trim(ability or "Attack")
  local normalizedTarget = boop.util.trim(target or "(none)")

  if samePendingAttack(boop.state.gag.pendingAttack, normalizedWho, normalizedAbility, normalizedTarget) then
    boop.state.gag.pendingAttack.hitCount = (tonumber(boop.state.gag.pendingAttack.hitCount) or 1) + 1
    boop.state.gag.pendingAttack.currentHitHasDamage = false
    if normName(boop.state.gag.pendingAttack.ability or "") ~= "razeslash" then
      boop.state.gag.pendingAttack.ability = "DSL"
      boop.state.gag.pendingAttack.abilityParts = { "DSL" }
      boop.state.gag.pendingAttack.currentSource = "DSL"
    end
    return rescheduleAttackSummaryTimer()
  end

  if canAppendPsionShatterPrefix(boop.state.gag.pendingAttack, normalizedWho, normalizedAbility, normalizedTarget) then
    boop.state.gag.pendingAttack.hitCount = (tonumber(boop.state.gag.pendingAttack.hitCount) or 1) + 1
    boop.state.gag.pendingAttack.currentHitHasDamage = false
    addPendingAbilityPart(boop.state.gag.pendingAttack, normalizedAbility)
    boop.state.gag.pendingAttack.currentSource = normalizedAbility
    return rescheduleAttackSummaryTimer()
  end

  if canAppendDualBluntHit(boop.state.gag.pendingAttack, normalizedWho, normalizedAbility, normalizedTarget) then
    boop.state.gag.pendingAttack.hitCount = (tonumber(boop.state.gag.pendingAttack.hitCount) or 1) + 1
    boop.state.gag.pendingAttack.currentHitHasDamage = false
    addPendingAbilityPart(boop.state.gag.pendingAttack, normalizedAbility)
    boop.state.gag.pendingAttack.currentSource = normalizedAbility
    return rescheduleAttackSummaryTimer()
  end

  if boop.state.gag.pendingAttack then
    flushPendingAttack()
  end

  boop.state.gag.pendingAttack = {
    who = normalizedWho,
    ability = normalizedAbility,
    target = normalizedTarget,
    hitCount = 1,
    currentHitHasDamage = false,
    damageParts = {},
    abilityParts = { normalizedAbility },
    currentSource = normalizedAbility,
    nextCritText = "",
    damageText = "",
    critText = "",
    balanceText = "",
  }

  return rescheduleAttackSummaryTimer()
end

local function cancelKillSummaryTimer()
  boop.state = boop.state or {}
  boop.state.gag = boop.state.gag or {}
  if boop.state.gag.pendingKillTimer and type(killTimer) == "function" then
    killTimer(boop.state.gag.pendingKillTimer)
  end
  boop.state.gag.pendingKillTimer = nil
end

local function scheduleKillSummaryRetry()
  boop.state = boop.state or {}
  boop.state.gag = boop.state.gag or {}
  cancelKillSummaryTimer()
  boop.state.gag.pendingKillTimer = scheduleGagTimer(0.25, function()
    boop.state.gag.pendingKillTimer = nil
    if flushPendingKill then
      flushPendingKill()
    end
  end)
end

flushPendingKill = function()
  boop.state = boop.state or {}
  boop.state.gag = boop.state.gag or {}
  local pending = boop.state.gag.pendingKill
  if not pending then return end
  if boop.state.gag.pendingAttack then
    scheduleKillSummaryRetry()
    return
  end
  boop.state.gag.pendingKill = nil
  cancelKillSummaryTimer()
  emitKillSummary(pending.target or "", pending.xp or "")
end

local function setPendingKill(target)
  boop.state = boop.state or {}
  boop.state.gag = boop.state.gag or {}
  boop.state.gag.pendingKill = {
    target = boop.util.trim(target or ""),
    xp = "",
  }
  cancelKillSummaryTimer()
  boop.state.gag.pendingKillTimer = scheduleGagTimer(1.2, function()
    boop.state.gag.pendingKillTimer = nil
    flushPendingKill()
  end)
  return boop.state.gag.pendingKillTimer == nil
end

function boop.gag.clearPending()
  boop.state = boop.state or {}
  boop.state.gag = boop.state.gag or {}
  cancelAttackSummaryTimer()
  cancelKillSummaryTimer()
  clearPendingMobDamage()
  boop.state.gag.pendingAttack = nil
  boop.state.gag.pendingKill = nil
  boop.state.gag.razeslashIntent = nil
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
    ["PLANE RAZING CRITICAL"] = "64xCRIT",
  }

  return map[key] or ""
end

local function commandIncludesRazeslash(action)
  local separator = boop.lists and boop.lists.separator or "/"
  for _, part in ipairs(boop.util.split(action or "", separator)) do
    local command = boop.util.safeLower(boop.util.trim(part))
    local verb = command:match("^(%S+)")
    if verb == "rsl" or verb == "razeslash" then
      return true
    end
  end
  return false
end

function boop.gag.noteStandardIntent(action)
  if not commandIncludesRazeslash(action) then
    return
  end
  boop.state = boop.state or {}
  boop.state.gag = boop.state.gag or {}
  boop.state.gag.razeslashIntent = {
    at = nowSeconds(),
  }
end

local function consumeRazeslashIntent()
  boop.state = boop.state or {}
  boop.state.gag = boop.state.gag or {}
  local intent = boop.state.gag.razeslashIntent
  if type(intent) ~= "table" then
    return false
  end
  boop.state.gag.razeslashIntent = nil
  return (nowSeconds() - (tonumber(intent.at) or 0)) <= 20
end

function boop.gag.showStatus()
  boop.util.info("gag own attacks: " .. (boop.config.gagOwnAttacks and "on" or "off"))
  boop.util.info("gag others attacks: " .. (boop.config.gagOthersAttacks and "on" or "off"))
  boop.util.info("gag mob attacks: " .. (boop.config.gagMobAttacks and "on" or "off"))
  boop.util.info("gag own palette: " .. boop.gag.paletteSummary("own"))
  boop.util.info("gag others palette: " .. boop.gag.paletteSummary("others"))
  boop.util.info("gag mobs palette: " .. boop.gag.paletteSummary("mobs"))
  boop.util.info("Use: boop gag colors [own|others|mobs] | boop gag color [own|others|mobs] <role> [<color|off>]")
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

function boop.gag.setMobs(value)
  local enabled = value and true or false
  boop.config.gagMobAttacks = enabled
  if boop.db and boop.db.saveConfig then
    boop.db.saveConfig("gagMobAttacks", enabled)
  end
  boop.util.ok("gag mob attacks: " .. (enabled and "on" or "off"))
end

function boop.gag.setBoth(value)
  boop.gag.setOwn(value)
  boop.gag.setOthers(value)
end

function boop.gag.setAll(value)
  boop.gag.setBoth(value)
  boop.gag.setMobs(value)
end

function boop.gag.onMobAttackLine(spec, matchTable, rawLine)
  if shouldSuppressDuplicate(rawLine) then
    return
  end
  if not boop.config or not boop.config.gagMobAttacks then
    return
  end

  local actor = boop.util.trim(resolveCapture(spec and spec.actor, matchTable))
  if actor == "" then
    actor = findLikelyActor(matchTable)
  end
  if actor == "" then
    actor = "Mob"
  end

  boop.state = boop.state or {}
  boop.state.gag = boop.state.gag or {}
  boop.state.gag.pendingMobAttack = {
    mob = actor,
    at = nowSeconds(),
  }
  deleteCurrent()
  scheduleMobDamageTimer()

  if boop.trace and boop.trace.log then
    boop.trace.log("gag: mob attack | actor=" .. actor)
  end
end

function boop.gag.onHealthLostLine(amount, dtype, _rawLine)
  if not boop.config or not boop.config.gagMobAttacks then
    return
  end

  boop.state = boop.state or {}
  boop.state.gag = boop.state.gag or {}
  local pending = boop.state.gag.pendingMobAttack
  if type(pending) ~= "table" then
    return
  end
  if (nowSeconds() - (tonumber(pending.at) or 0)) > 5 then
    clearPendingMobDamage()
    return
  end

  deleteCurrent()
  local actor = boop.util.trim(pending.mob or "Mob")
  clearPendingMobDamage()
  emitMobDamageSummary(actor, formatDamageText(amount, dtype))

  if boop.trace and boop.trace.log then
    boop.trace.log("gag: mob damage | actor=" .. (actor ~= "" and actor or "Mob") .. " | damage=" .. formatDamageText(amount, dtype))
  end
end

function boop.gag.onAttackLine(spec, matchTable, rawLine)
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
    victim = boop.state and boop.state.targeting.targetName or ""
  end

  local ability = boop.util.trim(spec and spec.ability or "")
  local pending = boop.state and boop.state.gag and boop.state.gag.pendingAttack or nil
  if shouldSuppressDuplicate(rawLine)
    and not (selfActor and canAppendDualBluntHit(pending, "You", ability, victim)) then
    return
  end

  if selfActor and normName(ability) == "raze" and consumeRazeslashIntent() then
    ability = "Razeslash"
  end

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

  if selfActor then
    local flushNow = setPendingAttack("You", ability, victim)
    deleteCurrent()
    if flushNow then
      flushPendingAttack()
    end
  else
    deleteCurrent()
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

  boop.state = boop.state or {}
  boop.state.gag = boop.state.gag or {}
  local pending = boop.state.gag.pendingAttack
  if not pending then
    return
  end

  deleteCurrent()
  local damageText = formatDamageText(amount, dtype)
  if damageText ~= "" then
    pending.damageText = damageText
  end

  local critText = boop.util.trim(pending.nextCritText or "")
  pending.nextCritText = ""
  pending.damageParts = pending.damageParts or {}
  pending.damageParts[#pending.damageParts + 1] = {
    damageText = pending.damageText,
    critText = critText,
    source = boop.util.trim(pending.currentSource or pending.ability or ""),
  }
  pending.currentHitHasDamage = true
  if critText ~= "" then
    pending.critText = critText
  end
end

function boop.gag.onProcLine(ability, target, _rawLine)
  if not boop.config or not boop.config.gagOwnAttacks then
    return
  end

  local source = boop.util.trim(ability or "")
  if source == "" then
    source = "Extra Damage"
  end

  boop.state = boop.state or {}
  boop.state.gag = boop.state.gag or {}
  local pending = boop.state.gag.pendingAttack
  local seenTarget = boop.util.trim(target or "")

  if pending then
    if seenTarget == "" then
      seenTarget = boop.util.trim(pending.target or "")
    end
    local pendingTarget = normName(pending.target or "")
    if seenTarget ~= "" and pendingTarget ~= "" and pendingTarget ~= normName(seenTarget) then
      flushPendingAttack()
      pending = nil
    end
  end

  if not pending then
    if seenTarget == "" then
      seenTarget = boop.util.trim(boop.state and boop.state.targeting and boop.state.targeting.targetName or "")
    end
    if seenTarget == "" then
      seenTarget = "(unknown)"
    end

    local flushNow = setPendingAttack("You", source, seenTarget)
    deleteCurrent()
    if flushNow then
      flushPendingAttack()
    end
    return
  end

  addPendingAbilityPart(pending, source)
  pending.currentSource = source
  pending.currentHitHasDamage = false
  deleteCurrent()

  if rescheduleAttackSummaryTimer() then
    flushPendingAttack()
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
  local pending = boop.state.gag.pendingAttack
  if not pending then
    return
  end

  local critText = resolveCritText(critLabel or "")
  if critText == "" then
    return
  end

  deleteCurrent()
  pending.damageParts = pending.damageParts or {}
  local last = pending.damageParts[#pending.damageParts]
  if pending.currentHitHasDamage and last and boop.util.trim(last.critText or "") == "" then
    last.critText = critText
  else
    pending.nextCritText = critText
  end
  pending.critText = critText
end

function boop.gag.onCompanionMaulFlavor(target, _rawLine)
  if not boop.config or not boop.config.gagOwnAttacks then
    return
  end

  local lineText = boop.util.safeLower(boop.util.trim(_rawLine or ""))
  local inferredAbility = ""
  if lineText:find("hyena", 1, true) then
    inferredAbility = "Hyena Maul"
  elseif lineText:find("hound", 1, true) then
    inferredAbility = "Hound Maul"
  end

  boop.state = boop.state or {}
  local pending = boop.state.gag.pendingAttack
  if not pending then
    if inferredAbility == "" then
      return
    end
    local flushNow = setPendingAttack("You", inferredAbility, target)
    deleteCurrent()
    if flushNow then
      flushPendingAttack()
    end
    return
  end

  local ability = boop.util.safeLower(boop.util.trim(pending.ability or ""))
  if ability ~= "hound maul" and ability ~= "hyena maul" then
    if inferredAbility == "" then
      return
    end
    local flushNow = setPendingAttack("You", inferredAbility, target)
    deleteCurrent()
    if flushNow then
      flushPendingAttack()
    end
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

  boop.state = boop.state or {}
  boop.state.gag = boop.state.gag or {}
  local pending = boop.state.gag.pendingAttack
  if not pending then
    return
  end

  deleteCurrent()
  local sec = boop.util.trim(tostring(seconds or ""))
  if sec ~= "" then
    pending.balanceText = sec .. "s"
  end
  if normName(pending.ability or "") == "razeslash" then
    cancelAttackSummaryTimer()
    boop.state.gag.pendingAttackTimer = scheduleGagTimer(1.2, function()
      boop.state.gag.pendingAttackTimer = nil
      flushPendingAttack()
    end)
    if boop.state.gag.pendingAttackTimer ~= nil then
      return
    end
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
  local flushNow = setPendingKill(target or "")
  deleteCurrent()
  if flushNow then
    flushPendingKill()
  end
end

function boop.gag.onExperienceLine(xp, _rawLine)
  if not boop.config or not boop.config.gagOwnAttacks then
    return
  end

  boop.state = boop.state or {}
  local pending = boop.state.gag.pendingKill
  if not pending then
    return
  end

  deleteCurrent()
  pending.xp = boop.util.trim(tostring(xp or "")):gsub(",", "")
  flushPendingKill()
end

function boop.gag.onPrompt()
  if boop.config and boop.config.gagMobAttacks then
    clearPendingMobDamage()
  end
  if not boop.config or not boop.config.gagOwnAttacks then
    return
  end

  boop.state = boop.state or {}
  if boop.state.gag.pendingAttack then
    flushPendingAttack()
  elseif boop.state.gag.pendingKill then
    flushPendingKill()
  end
end
