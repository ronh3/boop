boop.render = boop.render or {}

local RULE_WIDTH = 56
local LABEL_COL_WIDTH = 40

local function trim(value)
  return boop.util.trim(tostring(value or ""))
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

local function indexPrefix(index)
  if index == nil then
    return ""
  end
  return string.format("[%d] ", tonumber(index) or 0)
end

local function padRight(text, width)
  text = tostring(text or "")
  if #text >= width then
    return text
  end
  return text .. string.rep(" ", width - #text)
end

local function rule()
  return string.rep("-", RULE_WIDTH)
end

local function buttonLabel(value)
  return "[ " .. trim(value) .. " ]"
end

local function helpSeedCommand(command)
  local seed = trim(command)
  seed = seed:gsub("%s*%b[]", "")
  local requiredAt = seed:find("<", 1, true)
  local needsValue = requiredAt ~= nil
  if requiredAt then
    seed = seed:sub(1, requiredAt - 1)
  end
  seed = seed:gsub("%S+", function(token)
    return token:match("^([^|]+)|") or token
  end)
  seed = trim(seed:gsub("%s+", " "))
  if needsValue and seed ~= "" then
    seed = seed .. " "
  end
  return seed
end

local function footerSeedCommand(text)
  local value = trim(text)
  if value == "" then
    return ""
  end
  local boopStart = value:find("boop ", 1, true)
  if not boopStart then
    return ""
  end
  local command = trim(value:sub(boopStart))
  if command == "" then
    return ""
  end
  return helpSeedCommand(command)
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
    local commandText = trim(piece)
    if boopStart and boopStart > 1 then
      prefix = piece:sub(1, boopStart - 1)
      commandText = trim(piece:sub(boopStart))
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

local function setCommandLine(prefix)
  if not appendCmdLine then return end
  if clearCmdLine then clearCmdLine() end
  appendCmdLine(prefix or "")
end

function boop.render.themeTags()
  return themeTags()
end

function boop.render.semanticTag(name)
  return semanticTag(name)
end

function boop.render.setCommandLine(prefix)
  return setCommandLine(prefix)
end

function boop.render.computeLabelWidth(rows, minWidth, maxWidth)
  local width = tonumber(minWidth) or LABEL_COL_WIDTH
  local hardMax = tonumber(maxWidth) or 140
  for _, row in ipairs(rows or {}) do
    local label = tostring((row and row.label) or "")
    local index = row and row.index or nil
    local total = #(indexPrefix(index) .. label)
    if total > width then
      width = total
    end
  end
  if width > hardMax then
    width = hardMax
  end
  return width
end

function boop.render.printHeader(title, context)
  if cecho then
    local theme = themeTags()
    cecho("\n" .. theme.accent .. string.upper(tostring(title or "")) .. theme.reset)
    cecho("\n" .. theme.border .. rule() .. theme.reset)
  else
    local class = type(context) == "table" and context.class or "unknown"
    boop.util.echo(tostring(title) .. " | class: " .. tostring(class))
  end
end

function boop.render.printSection(title)
  if cecho then
    local theme = themeTags()
    cecho("\n\n" .. theme.info .. string.upper(tostring(title or "")) .. theme.reset)
  else
    boop.util.echo(tostring(title) .. ":")
  end
end

function boop.render.printRow(index, label, buttonText, buttonColor, onClick, hint, labelWidth)
  if cecho then
    local theme = themeTags()
    local width = tonumber(labelWidth) or LABEL_COL_WIDTH
    local prefix = indexPrefix(index)
    local leftRaw = prefix .. tostring(label or "")
    local left = padRight(leftRaw, width)
    cecho("\n" .. theme.text .. left .. " " .. theme.reset)
    local colorTag = semanticTag(tostring(buttonColor or "text"))
    local coloredButton = colorTag .. buttonLabel(buttonText or "") .. theme.reset
    if cechoLink and onClick then
      cechoLink(coloredButton, onClick, hint or "", true)
    else
      cecho(coloredButton)
    end
    return
  end

  local prefix = index and ("[" .. tostring(index) .. "] ") or ""
  boop.util.echo(prefix .. tostring(label or "") .. " " .. buttonLabel(buttonText or ""))
end

function boop.render.printControlRow(index, label, currentText, currentColor, actions, labelWidth, valueClick, valueHint)
  local prefix = indexPrefix(index)
  local valueText = tostring(currentText or "")
  local leftRaw = prefix .. tostring(label or "") .. ": " .. valueText

  if cecho then
    local theme = themeTags()
    local width = tonumber(labelWidth) or LABEL_COL_WIDTH
    local valueTag = semanticTag(tostring(currentColor or "text"))
    cecho("\n" .. theme.text .. padRight(prefix .. tostring(label or "") .. ":", width) .. " ")
    if cechoLink and valueClick then
      cechoLink(valueTag .. valueText .. theme.reset, valueClick, valueHint or tostring(label or ""), true)
    else
      cecho(valueTag .. valueText .. theme.reset)
    end
    for _, action in ipairs(actions or {}) do
      cecho(" ")
      local rendered = semanticTag(tostring(action.color or "info")) .. tostring(action.label or "") .. theme.reset
      if cechoLink and action.onClick then
        cechoLink(rendered, action.onClick, action.hint or "", true)
      else
        cecho(rendered)
      end
    end
    return
  end

  local parts = { leftRaw }
  for _, action in ipairs(actions or {}) do
    parts[#parts + 1] = tostring(action.label or "")
  end
  boop.util.echo(table.concat(parts, " "))
end

function boop.render.printToggleControl(index, label, enabled, onClick, hint, labelWidth)
  boop.render.printControlRow(index, label, enabled and "ON" or "OFF", enabled and "green" or "red", {
    { label = "[toggle]", color = "info", onClick = onClick, hint = hint or "Toggle " .. tostring(label or "") },
  }, labelWidth, onClick, hint or "Toggle " .. tostring(label or ""))
end

function boop.render.printActionControl(index, label, currentText, currentColor, actionLabel, actionColor, onClick, hint, labelWidth)
  boop.render.printControlRow(index, label, currentText, currentColor, {
    { label = tostring(actionLabel or "[open]"), color = tostring(actionColor or "info"), onClick = onClick, hint = hint or tostring(label or "") },
  }, labelWidth, onClick, hint or tostring(label or ""))
end

function boop.render.printNumberControl(index, label, currentText, currentColor, decClick, incClick, labelWidth)
  boop.render.printControlRow(index, label, currentText, currentColor, {
    { label = "[-]", color = "info", onClick = decClick, hint = "Decrease " .. tostring(label or "") },
    { label = "[+]", color = "info", onClick = incClick, hint = "Increase " .. tostring(label or "") },
  }, labelWidth)
end

function boop.render.printFooter(text)
  if cecho then
    local theme = themeTags()
    cecho("\n" .. theme.border .. rule() .. theme.reset)
    cecho("\n")
    local parts = footerClickableParts(text)
    if cechoLink and #parts > 0 then
      for _, part in ipairs(parts) do
        if part.prefix ~= "" then
          cecho(theme.muted .. part.prefix .. theme.reset)
        end
        if part.seed ~= "" then
          cechoLink(theme.info .. part.command .. theme.reset, function()
            setCommandLine(part.seed)
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
