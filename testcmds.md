local commands = {
  "boop help",
  "boop help home",
  "boop help main",
  "boop help general",
  "boop help topics",
  "boop help topic",
  "boop help back",
  "boop help 1",
  "boop help 2",
  "boop help 3",
  "boop help 4",
  "boop help 5",
  "boop help 6",
  "boop help start",
  "boop help gettingstarted",
  "boop help intro",
  "boop help basics",
  "boop help control",
  "boop help controls",
  "boop help config",
  "boop help settings",
  "boop help dashboard",
  "boop help hunting",
  "boop help combat",
  "boop help targeting",
  "boop help targets",
  "boop help whitelist",
  "boop help blacklist",
  "boop help rage",
  "boop help ragemode",
  "boop help attackmode",
  "boop help queue",
  "boop help queueing",
  "boop help prequeue",
  "boop help diag",
  "boop help diagnose",
  "boop help ih",
  "boop help party",
  "boop help leader",
  "boop help assist",
  "boop help targetcall",
  "boop help walk",
  "boop help roster",
  "boop help combos",
  "boop help combo",
  "boop help stats",
  "boop help trip",
  "boop help records",
  "boop help areas",
  "boop help abilities",
  "boop help crits",
  "boop help compare",
  "boop help diagnostics",
  "boop help debug",
  "boop help trace",
  "boop help gag",
  "boop help advanced",
  "boop help set",
  "boop help get",
  "boop help import",
  "boop help foxhunt",
}

local function fail(message)
  error("boop help sweep: " .. tostring(message), 0)
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
local outputPath = home .. sep .. "boop_help_sweep.txt"

local original = {
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

local function stripMarkup(text)
  text = tostring(text or "")
  text = text:gsub("\27%[[0-9;]*m", "")
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

_G.cecho = function(text) pushChunk(text) end
_G.cechoLink = function(text) pushChunk(text) end
_G.decho = function(text) pushChunk(text) end
_G.dechoLink = function(text) pushChunk(text) end
_G.hecho = function(text) pushChunk(text) end
_G.hechoLink = function(text) pushChunk(text) end
_G.echo = function(text) pushChunk(text) end
_G.echoLink = function(text) pushChunk(text) end
_G.insertText = function(text) pushChunk(text) end

for index, command in ipairs(commands) do
  appendLine(string.rep("=", 96))
  appendLine(string.format("[%02d/%02d] %s", index, #commands, command))
  appendLine(string.rep("-", 96))

  local ok, err = pcall(expandAlias, command)
  flushPending()
  if not ok then
    appendLine("[SCRIPT ERROR] " .. tostring(err))
  end

  appendLine("")
end

_G.cecho = original.cecho
_G.cechoLink = original.cechoLink
_G.decho = original.decho
_G.dechoLink = original.dechoLink
_G.hecho = original.hecho
_G.hechoLink = original.hechoLink
_G.echo = original.echo
_G.echoLink = original.echoLink
_G.insertText = original.insertText

flushPending()

local handle, err = io.open(outputPath, "w")
if not handle then
  fail("unable to open output file: " .. tostring(err))
end

for _, line in ipairs(lines) do
  handle:write(line, "\n")
end
handle:close()

if type(original.cecho) == "function" then
  original.cecho("\n<green>boop help sweep written to:<reset> <cyan>" .. outputPath .. "<reset>\n")
elseif type(original.echo) == "function" then
  original.echo("\nboop help sweep written to: " .. outputPath .. "\n")
end
