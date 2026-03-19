local commands = {
  "boop",
  "boop control",
  "boop config",
  "boop config combat",
  "boop config targeting",
  "boop config loot",
  "boop config debug",
  "boop party",
  "boop help home",
  "boop help start",
  "boop help control",
  "boop help hunting",
  "boop help party",
  "boop help stats",
  "boop help diagnostics",
  "boop stats",
}

local wrappedPaths = {
  "appendCmdLine",
  "clearCmdLine",
  "boop.ui.partyCommand",
  "boop.ui.modeCommand",
  "boop.ui.themeCommand",
  "boop.ui.controlCommand",
  "boop.ui.config",
  "boop.ui.walkCommand",
  "boop.ui.rosterCommand",
  "boop.ui.help",
  "boop.ui.showRageModeMenu",
  "boop.ui.diag",
  "boop.ui.targetCallCommand",
  "boop.ui.affCallCommand",
  "boop.ui.assistCommand",
  "boop.ui.setEnabled",
  "boop.ui.toggleConfigBool",
  "boop.ui.setPrequeueEnabled",
  "boop.ui.setGoldPack",
  "boop.ui.testGoldPack",
  "boop.ui.debug",
  "boop.ui.combos",
  "boop.stats.command",
  "boop.stats.startTrip",
  "boop.trace.show",
  "boop.trace.clear",
  "boop.targets.displayWhitelist",
  "boop.targets.displayWhitelistBrowse",
  "boop.targets.displayBlacklist",
  "boop.gag.setOwn",
  "boop.gag.setOthers",
}

local function fail(message)
  error("boop menu sweep: " .. tostring(message), 0)
end

if type(expandAlias) ~= "function" then
  fail("expandAlias() is unavailable")
end

if type(getMudletHomeDir) ~= "function" then
  fail("getMudletHomeDir() is unavailable")
end

local home = tostring(getMudletHomeDir() or "")
if home == "" then
  fail("profile home directory is empty")
end

local sep = home:sub(-1) == "/" and "" or "/"
local outputPath = home .. sep .. "boop_menu_sweep.txt"

local originalEcho = {
  cecho = _G.cecho,
  cechoLink = _G.cechoLink,
  decho = _G.decho,
  dechoLink = _G.dechoLink,
  hecho = _G.hecho,
  hechoLink = _G.hechoLink,
  echo = _G.echo,
  echoLink = _G.echoLink,
  insertText = _G.insertText,
}

local lines = {}
local pending = ""
local currentCallbacks = {}
local STRIPPABLE_EXACT_TAGS = {}
local STRIPPABLE_TAGS = {
  reset = true,
  white = true,
  cyan = true,
  yellow = true,
  green = true,
  red = true,
  grey = true,
  gray = true,
  light_grey = true,
  light_gray = true,
  dark_grey = true,
  dark_gray = true,
  dark_turquoise = true,
  dark_orchid = true,
  alice_blue = true,
  cadet_blue = true,
  spring_green = true,
  khaki = true,
  tomato = true,
  slate_gray = true,
  slate_grey = true,
  firebrick = true,
  maroon = true,
  misty_rose = true,
  rosy_brown = true,
  goldenrod = true,
  salmon = true,
  dark_slate_grey = true,
  dark_slate_gray = true,
  royal_blue = true,
  peru = true,
  light_slate_gray = true,
  light_slate_grey = true,
  olive_drab = true,
  dark_olive_green = true,
  honeydew = true,
  dark_sea_green = true,
  medium_sea_green = true,
  orchid = true,
  dark_slate_blue = true,
  lavender = true,
  thistle = true,
  plum = true,
  dim_grey = true,
  dim_gray = true,
  deep_sky_blue = true,
  steel_blue = true,
  light_steel_blue = true,
  cornflower_blue = true,
  forest_green = true,
  saddle_brown = true,
  beige = true,
  tan = true,
}

if boop and boop.theme and type(boop.theme.tags) == "function" then
  local ok, themeTags = pcall(boop.theme.tags)
  if ok and type(themeTags) == "table" then
    for _, value in pairs(themeTags) do
      local text = tostring(value or "")
      if text:match("^<[^>]+>$") then
        STRIPPABLE_EXACT_TAGS[text] = true
      end
    end
  end
end

local function stripMarkup(text)
  text = tostring(text or "")
  text = text:gsub("\27%[[0-9;]*m", "")
  text = text:gsub("<[^>]+>", function(fullTag)
    if STRIPPABLE_EXACT_TAGS[fullTag] then
      return ""
    end
    return fullTag
  end)
  text = text:gsub("<([^>]+)>", function(tag)
    local key = tostring(tag or ""):lower()
    if STRIPPABLE_TAGS[key] then
      return ""
    end
    return "<" .. tag .. ">"
  end)
  text = text:gsub("\r", "")
  return text
end

local function trim(text)
  text = tostring(text or "")
  text = text:gsub("^%s+", "")
  text = text:gsub("%s+$", "")
  return text
end

local function flushPending()
  if pending ~= "" then
    lines[#lines + 1] = pending
    pending = ""
  end
end

local function pushChunk(text)
  local chunk = stripMarkup(text)
  while true do
    local pos = chunk:find("\n", 1, true)
    if not pos then
      pending = pending .. chunk
      break
    end
    pending = pending .. chunk:sub(1, pos - 1)
    lines[#lines + 1] = pending
    pending = ""
    chunk = chunk:sub(pos + 1)
  end
end

local function appendLine(text)
  flushPending()
  lines[#lines + 1] = tostring(text or "")
end

local function quote(value)
  if value == nil then
    return "nil"
  end
  local kind = type(value)
  if kind == "string" then
    return string.format("%q", value)
  end
  if kind == "boolean" or kind == "number" then
    return tostring(value)
  end
  return "<" .. kind .. ">"
end

local function formatArgs(args)
  local parts = {}
  for i = 1, #args do
    parts[#parts + 1] = quote(args[i])
  end
  return table.concat(parts, ", ")
end

local function resolvePath(path)
  local parent = _G
  local segments = {}
  for piece in tostring(path or ""):gmatch("[^.]+") do
    segments[#segments + 1] = piece
  end
  for i = 1, #segments - 1 do
    local key = segments[i]
    if type(parent) ~= "table" then
      return nil, nil, nil
    end
    parent = parent[key]
  end
  if type(parent) ~= "table" then
    return nil, nil, nil
  end
  local key = segments[#segments]
  return parent, key, parent[key]
end

local function withWrappedPaths(fn)
  local events = {}
  local originals = {}

  for _, path in ipairs(wrappedPaths) do
    local parent, key, original = resolvePath(path)
    if parent and type(original) == "function" then
      originals[#originals + 1] = { parent = parent, key = key, original = original }
      parent[key] = function(...)
        events[#events + 1] = string.format("%s(%s)", path, formatArgs({ ... }))
      end
    end
  end

  local ok, err = pcall(fn, events)

  for i = #originals, 1, -1 do
    local item = originals[i]
    item.parent[item.key] = item.original
  end

  return ok, err, events
end

_G.cecho = function(text) pushChunk(text) end
_G.cechoLink = function(text, cb, hint, _)
  currentCallbacks[#currentCallbacks + 1] = {
    context = trim(stripMarkup(pending)),
    button = trim(stripMarkup(text)),
    hint = trim(stripMarkup(hint)),
    callback = cb,
  }
  pushChunk(text)
end
_G.decho = function(text) pushChunk(text) end
_G.dechoLink = function(text) pushChunk(text) end
_G.hecho = function(text) pushChunk(text) end
_G.hechoLink = function(text) pushChunk(text) end
_G.echo = function(text) pushChunk(text) end
_G.echoLink = function(text) pushChunk(text) end
_G.insertText = function(text) pushChunk(text) end

for index, command in ipairs(commands) do
  currentCallbacks = {}

  appendLine(string.rep("=", 96))
  appendLine(string.format("[%02d/%02d] %s", index, #commands, command))
  appendLine(string.rep("-", 96))

  local ok, err = pcall(expandAlias, command)
  flushPending()
  if not ok then
    appendLine("[SCRIPT ERROR] " .. tostring(err))
  end

  if #currentCallbacks == 0 then
    appendLine("(no clickable menu items captured)")
  else
    appendLine("callbacks:")
    for callbackIndex, item in ipairs(currentCallbacks) do
      appendLine(string.format("  [%02d] source: %s", callbackIndex, item.context ~= "" and item.context or "(context unavailable)"))
      appendLine(string.format("       button: %s", item.button ~= "" and item.button or "(button unavailable)"))
      if item.hint ~= "" then
        appendLine(string.format("       hint: %s", item.hint))
      end

      local callbackOk, callbackErr, events = withWrappedPaths(function(log)
        if type(item.callback) == "function" then
          item.callback()
        else
          fail("callback " .. tostring(callbackIndex) .. " is not callable")
        end
      end)

      if not callbackOk then
        appendLine("       action: [SCRIPT ERROR] " .. tostring(callbackErr))
      elseif #events == 0 then
        appendLine("       action: (no observable wrapped call)")
      else
        for eventIndex, event in ipairs(events) do
          local prefix = eventIndex == 1 and "       action: " or "               "
          appendLine(prefix .. event)
        end
      end
    end
  end

  appendLine("")
end

_G.cecho = originalEcho.cecho
_G.cechoLink = originalEcho.cechoLink
_G.decho = originalEcho.decho
_G.dechoLink = originalEcho.dechoLink
_G.hecho = originalEcho.hecho
_G.hechoLink = originalEcho.hechoLink
_G.echo = originalEcho.echo
_G.echoLink = originalEcho.echoLink
_G.insertText = originalEcho.insertText

flushPending()

local handle, err = io.open(outputPath, "w")
if not handle then
  fail("unable to open output file: " .. tostring(err))
end

for _, line in ipairs(lines) do
  handle:write(line, "\n")
end
handle:close()

if type(originalEcho.cecho) == "function" then
  originalEcho.cecho("\n<green>boop menu sweep written to:<reset> <cyan>" .. outputPath .. "<reset>\n")
elseif type(originalEcho.echo) == "function" then
  originalEcho.echo("\nboop menu sweep written to: " .. outputPath .. "\n")
end
