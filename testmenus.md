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
local currentRenderLines = nil
local totalChecks = 0
local failedChecks = 0
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
    if currentRenderLines then
      currentRenderLines[#currentRenderLines + 1] = pending
    end
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
    if currentRenderLines then
      currentRenderLines[#currentRenderLines + 1] = pending
    end
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

local function captureArgs(...)
  local args = {}
  for i = 1, select("#", ...) do
    args[i] = select(i, ...)
  end
  return args
end

local function formatArgs(args)
  local parts = {}
  for i = 1, #args do
    parts[#parts + 1] = quote(args[i])
  end
  return table.concat(parts, ", ")
end

local function action(path, ...)
  return string.format("%s(%s)", path, formatArgs(captureArgs(...)))
end

local function seedActions(seed)
  return {
    action("clearCmdLine"),
    action("appendCmdLine", seed),
  }
end

local function contains(haystack, needle)
  return tostring(haystack or ""):find(tostring(needle or ""), 1, true) ~= nil
end

local function walkCommandAction(defaultCommand)
  local command = defaultCommand
  if boop.walk and boop.walk.isAvailable and not boop.walk.isAvailable() then
    command = "install"
  end
  return { action("boop.ui.walkCommand", command) }
end

local function statsDashboardCallbacks(renderedText)
  local callbacks
  if contains(renderedText, "Trip vs last trip") then
    callbacks = {
      { source = "[13] Trip vs last trip", actions = { action("boop.stats.command", "compare trip lasttrip") } },
      { source = "[14] Area rankings", actions = { action("boop.stats.command", "areas trip 5 xp") } },
      { source = "[15] Target breakdown", actions = { action("boop.stats.command", "targets trip 5") } },
      { source = "[16] Ability breakdown", actions = { action("boop.stats.command", "abilities trip 5") } },
      { source = "[17] Rage report", actions = { action("boop.stats.command", "rage trip") } },
    }
  elseif contains(renderedText, "Lifetime summary") then
    callbacks = {
      { source = "[13] Lifetime summary", actions = { action("boop.stats.command", "lifetime") } },
      { source = "[14] Lifetime areas", actions = { action("boop.stats.command", "areas lifetime 5 xp") } },
      { source = "[15] Lifetime abilities", actions = { action("boop.stats.command", "abilities lifetime 5") } },
      { source = "[16] Lifetime crits", actions = { action("boop.stats.command", "crits lifetime") } },
      { source = "[17] Start a trip", actions = { action("boop.stats.startTrip") } },
    }
  else
    callbacks = {
      { source = "[13] Enable boop", actions = { action("boop.ui.setEnabled", true) } },
      { source = "[14] Start a trip", actions = { action("boop.stats.startTrip") } },
      { source = "[15] Lifetime summary", actions = { action("boop.stats.command", "lifetime") } },
      { source = "[16] Lifetime areas", actions = { action("boop.stats.command", "areas lifetime 5 xp") } },
      { source = "[17] Lifetime abilities", actions = { action("boop.stats.command", "abilities lifetime 5") } },
    }
  end
  callbacks[#callbacks + 1] = { source = "boop stats areas", actions = seedActions("boop stats areas") }
  callbacks[#callbacks + 1] = { source = "boop stats targets", actions = seedActions("boop stats targets") }
  callbacks[#callbacks + 1] = { source = "boop stats abilities", actions = seedActions("boop stats abilities") }
  callbacks[#callbacks + 1] = { source = "boop stats compare", actions = seedActions("boop stats compare") }
  return callbacks
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
        events[#events + 1] = string.format("%s(%s)", path, formatArgs(captureArgs(...)))
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

local HELP_TOPICS = {
  start = {
    title = "HELP > START HERE",
    commands = {
      "boop",
      "boop control",
      "boop on",
      "boop off",
      "boop status",
      "boop config",
      "boop config home",
      "boop party",
      "boop preset <solo|party|leader|leader-call>",
      "boop help <topic>",
    },
  },
  control = {
    title = "HELP > CONTROL & CONFIG",
    commands = {
      "boop control",
      "boop config",
      "boop config home",
      "boop config combat",
      "boop config targeting",
      "boop config loot",
      "boop config debug",
      "boop preset <solo|party|leader|leader-call>",
      "boop get",
      "boop set <key> <value>",
    },
  },
  hunting = {
    title = "HELP > HUNTING & TARGETING",
    commands = {
      "boop config combat",
      "boop config targeting",
      "boop ragemode",
      "boop ragemode <simple|big|small|aff|tempo|combo|hybrid|none>",
      "boop prequeue [on|off]",
      "boop lead <seconds>",
      "boop targeting <manual|whitelist|blacklist|auto>",
      "boop whitelist",
      "boop whitelist browse [tag]",
      "boop blacklist",
      "diag",
      "boop prefer",
      "boop prefer <dam|shield> <option>",
    },
  },
  party = {
    title = "HELP > PARTY & LEADER",
    commands = {
      "boop party",
      "boop preset party",
      "boop preset leader",
      "boop preset leader-call",
      "boop mode solo|assist|leader|leader-call",
      "boop assist <leader>",
      "boop assist on|off|clear",
      "boop targetcall on|off",
      "boop affcalls on|off",
      "boop walk [status|start|stop|move]",
      "boop walk install",
      "boop roster",
      "boop roster <class...>",
      "boop roster clear",
      "boop combos",
      "boop combos <class...>",
      "boop combos list",
    },
    required = {
      "boop walk install",
    },
    hintOverrides = {
      ["boop walk install"] = "Install the required demonnicAutoWalker package into Mudlet.",
    },
  },
  stats = {
    title = "HELP > STATS & OPTIMIZATION",
    commands = {
      "boop stats",
      "boop stats help",
      "boop stats session|login|trip|lifetime",
      "boop stats lasttrip",
      "boop stats compare [left] [right]",
      "boop stats areas [scope] [limit] [metric]",
      "boop stats targets [scope] [limit]",
      "boop stats abilities [scope] [limit]",
      "boop stats crits [scope]",
      "boop stats rage [scope]",
      "boop stats records [scope]",
      "boop trip start",
      "boop trip stop",
      "boop stats reset session|login|trip|lifetime|all",
    },
  },
  diagnostics = {
    title = "HELP > DIAGNOSTICS & ADVANCED",
    commands = {
      "boop config debug",
      "boop debug",
      "boop debug attacks",
      "boop debug skills",
      "boop debug skills dump",
      "boop trace on|off|show [n]|clear",
      "boop gag on|off|own|others|all",
      "boop get",
      "boop set <key> <value>",
      "boop import foxhunt [merge|overwrite|dryrun]",
      "boop pack test",
      "boop theme <name|auto|list>",
    },
  },
}

local function helpTopicExpectation(topic)
  local callbacks = {}
  for _, command in ipairs(topic.commands or {}) do
    callbacks[#callbacks + 1] = {
      source = command,
      actions = seedActions(command),
      hint = topic.hintOverrides and topic.hintOverrides[command] or nil,
    }
  end
  callbacks[#callbacks + 1] = {
    source = "boop help home",
    actions = seedActions("boop help home"),
  }
  callbacks[#callbacks + 1] = {
    source = "boop help back",
    actions = seedActions("boop help back"),
  }
  callbacks[#callbacks + 1] = {
    source = "boop help <number|topic>",
    actions = seedActions("boop help"),
  }
  return {
    required = topic.required or { topic.title },
    callbacks = callbacks,
  }
end

local expectedByCommand = {
  ["boop"] = {
    required = { "BOOP", "QUICK ACTIONS" },
    callbacks = {
      { source = "[18] Party", actions = { action("boop.ui.partyCommand", "") }, hint = "Open the party dashboard" },
      { source = "[19] Mode controls", actions = { action("boop.ui.modeCommand", "") } },
      { source = "[20] Stats", actions = { action("boop.stats.command", "") } },
      { source = "[21] Theme controls", actions = { action("boop.ui.themeCommand", "") } },
      { source = "boop control", actions = seedActions("boop control") },
      { source = "boop party", actions = seedActions("boop party") },
      { source = "boop roster", actions = seedActions("boop roster") },
      { source = "boop mode", actions = seedActions("boop mode") },
      { source = "boop stats", actions = seedActions("boop stats") },
    },
  },
  ["boop control"] = {
    required = { "BOOP > CONTROL", "NAVIGATION" },
    callbacks = {
      { source = "[1] Hunting", actions = { action("boop.ui.setEnabled", true) } },
      { source = "[2] Mode", actions = { action("boop.ui.modeCommand", "") } },
      { source = "[7] Targeting", actions = { action("boop.ui.config", "targeting") } },
      { source = "[8] Ragemode", actions = { action("boop.ui.config", "combat") } },
      { source = "[9] Queueing", actions = { action("boop.ui.config", "combat") } },
      { source = "[10] Prequeue", actions = { action("boop.ui.config", "combat") } },
      { source = "[13] Assist", actions = { action("boop.ui.partyCommand", "") } },
      { source = "[14] Leader target gate", actions = { action("boop.ui.partyCommand", "") } },
      { source = "[15] Party size", actions = { action("boop.ui.partyCommand", "") } },
      { source = "[16] Walk", actions = walkCommandAction("") },
      { source = "[17] Theme", actions = { action("boop.ui.themeCommand", "") } },
      { source = "[18] Party dashboard", actions = { action("boop.ui.partyCommand", "") } },
      { source = "[19] Roster manager", actions = { action("boop.ui.rosterCommand", "") } },
      { source = "[20] Settings hub", actions = { action("boop.ui.config", "") } },
      { source = "[21] Stats dashboard", actions = { action("boop.stats.command", "") } },
      { source = "boop control config", actions = seedActions("boop control config") },
      { source = "boop control party", actions = seedActions("boop control party") },
      { source = "boop control roster", actions = seedActions("boop control roster") },
      { source = "boop control stats", actions = seedActions("boop control stats") },
    },
  },
  ["boop config"] = {
    required = { "CONFIGURATION", "RELATED CONTROLS" },
    callbacks = {
      { source = "[1] Hunting", actions = { action("boop.ui.config", "combat") } },
      { source = "[2] Targeting", actions = { action("boop.ui.config", "targeting") } },
      { source = "[6] Hunting settings", actions = { action("boop.ui.config", "combat") } },
      { source = "[7] Targeting settings", actions = { action("boop.ui.config", "targeting") } },
      { source = "[8] Loot settings", actions = { action("boop.ui.config", "loot") } },
      { source = "[9] Diagnostics", actions = { action("boop.ui.config", "debug") } },
      { source = "[10] Party dashboard", actions = { action("boop.ui.partyCommand", "") } },
      { source = "[11] Roster manager", actions = { action("boop.ui.rosterCommand", "") } },
      { source = "[12] Appearance", actions = { action("boop.ui.themeCommand", "") } },
      { source = "[13] Control dashboard", actions = { action("boop.ui.controlCommand", "") } },
      { source = "[14] Stats dashboard", actions = { action("boop.stats.command", "") } },
      { source = "boop config home", actions = seedActions("boop config home") },
      { source = "boop config <number>", actions = seedActions("boop config") },
      { source = "boop config <name>", actions = seedActions("boop config") },
      { source = "boop party", actions = seedActions("boop party") },
      { source = "boop theme", actions = seedActions("boop theme") },
      { source = "boop control", actions = seedActions("boop control") },
    },
  },
  ["boop config combat"] = {
    required = { "CONFIGURATION > HUNTING", "ACTIONS" },
    callbacks = {
      { source = "[6] Toggle hunting", actions = { action("boop.ui.config", "combat 1") }, contract = "then toggles hunting enabled" },
      { source = "[7] Change rage mode", actions = { action("boop.ui.config", "combat 2") }, contract = "then opens the ragemode menu" },
      { source = "[8] Run diag", actions = { action("boop.ui.config", "combat 3") }, contract = "then queues diag" },
      { source = "[9] Queueing", actions = { action("boop.ui.config", "combat 4") }, contract = "then toggles queueing" },
      { source = "[10] Prequeue", actions = { action("boop.ui.config", "combat 5") }, contract = "then toggles prequeue" },
      { source = "[11] Attack lead", actions = { action("boop.ui.config", "combat 6") }, contract = "then prepares: boop lead " },
      { source = "[12] Diag timeout", actions = { action("boop.ui.config", "combat 7") }, contract = "then prepares: boop set diagtimeout " },
      { source = "[13] Tempo window", actions = { action("boop.ui.config", "combat 8") }, contract = "then prepares: boop set tempoRageWindowSeconds " },
      { source = "[14] Tempo squeeze ETA", actions = { action("boop.ui.config", "combat 9") }, contract = "then prepares: boop set tempoSqueezeEtaSeconds " },
      { source = "[15] Assist leader", actions = { action("boop.ui.config", "combat 10") }, contract = "then prepares: boop assist " },
      { source = "[16] Rage aff calls", actions = { action("boop.ui.config", "combat 11") }, contract = "then toggles affliction callouts" },
      { source = "boop config home", actions = seedActions("boop config home") },
      { source = "boop config combat <number>", actions = seedActions("boop config combat") },
      { source = "boop config back", actions = seedActions("boop config back") },
    },
  },
  ["boop config targeting"] = {
    required = { "CONFIGURATION > TARGETING", "LIST TOOLS" },
    callbacks = {
      { source = "[6] Targeting mode", actions = { action("boop.ui.config", "targeting 1") }, contract = "then cycles targeting mode" },
      { source = "[7] Whitelist priority order", actions = { action("boop.ui.config", "targeting 2") }, contract = "then toggles whitelist priority order" },
      { source = "[8] Target order", actions = { action("boop.ui.config", "targeting 3") }, contract = "then cycles target order" },
      { source = "[9] Retarget on higher priority", actions = { action("boop.ui.config", "targeting 4") }, contract = "then toggles retarget-on-priority" },
      { source = "[10] Leader target gate", actions = { action("boop.ui.config", "targeting 5") }, contract = "then toggles leader target gate" },
      { source = "[11] Whitelist manager", actions = { action("boop.ui.config", "targeting 6") }, contract = "then opens the whitelist manager" },
      { source = "[12] Whitelist browse", actions = { action("boop.ui.config", "targeting 7") }, contract = "then opens the whitelist browser" },
      { source = "[13] Blacklist manager", actions = { action("boop.ui.config", "targeting 8") }, contract = "then opens the blacklist manager" },
      { source = "boop config home", actions = seedActions("boop config home") },
      { source = "boop config targeting <number>", actions = seedActions("boop config targeting") },
      { source = "boop config back", actions = seedActions("boop config back") },
    },
  },
  ["boop config loot"] = {
    required = { "CONFIGURATION > LOOT", "ACTIONS" },
    callbacks = {
      { source = "[4] Auto grab sovereigns", actions = { action("boop.ui.config", "loot 1") }, contract = "then toggles automatic gold pickup" },
      { source = "[5] Gold pack container", actions = { action("boop.ui.config", "loot 2") }, contract = "then prepares: boop pack " },
      { source = "[6] Clear gold pack", actions = { action("boop.ui.config", "loot 3") }, contract = "then clears the gold pack" },
      { source = "[7] Gold pack test", actions = { action("boop.ui.config", "loot 4") }, contract = "then runs the gold pack test" },
      { source = "boop config home", actions = seedActions("boop config home") },
      { source = "boop config loot <number>", actions = seedActions("boop config loot") },
      { source = "boop config back", actions = seedActions("boop config back") },
    },
  },
  ["boop config debug"] = {
    required = { "CONFIGURATION > DEBUG", "ACTIONS" },
    callbacks = {
      { source = "[5] Toggle trace logging", actions = { action("boop.ui.config", "debug 1") }, contract = "then toggles trace logging" },
      { source = "[6] Debug snapshot", actions = { action("boop.ui.config", "debug 2") }, contract = "then shows the debug snapshot" },
      { source = "[7] Trace buffer", actions = { action("boop.ui.config", "debug 3") }, contract = "then shows the trace buffer" },
      { source = "[8] Clear trace", actions = { action("boop.ui.config", "debug 4") }, contract = "then clears the trace buffer" },
      { source = "[9] Toggle gag own attacks", actions = { action("boop.ui.config", "debug 5") }, contract = "then toggles self-attack gagging" },
      { source = "[10] Toggle gag others attacks", actions = { action("boop.ui.config", "debug 6") }, contract = "then toggles other-attack gagging" },
      { source = "boop config home", actions = seedActions("boop config home") },
      { source = "boop config debug <number>", actions = seedActions("boop config debug") },
      { source = "boop config back", actions = seedActions("boop config back") },
    },
  },
  ["boop party"] = {
    required = { "BOOP > PARTY", "PARTY DATA" },
    callbacks = {
      { source = "[1] Mode", actions = { action("boop.ui.modeCommand", "") } },
      { source = "[2] Leader", actions = seedActions("boop assist ") },
      { source = "[3] Assist", actions = { action("boop.ui.modeCommand", "assist") } },
      { source = "[4] Leader target gate", actions = { action("boop.ui.targetCallCommand", "on") } },
      { source = "[6] Party size", actions = seedActions("boop party size ") },
      { source = "[7] Walk", actions = walkCommandAction("start") },
      { source = "[8] Blocker", actions = { action("boop.ui.walkCommand", "status") } },
      { source = "[10] Force move", actions = { action("boop.ui.walkCommand", "move") } },
      { source = "[11] Rage aff calls", actions = { action("boop.ui.affCallCommand", "on") } },
      { source = "[12] Roster", actions = { action("boop.ui.rosterCommand", "") } },
      { source = "[13] Combos", actions = { action("boop.ui.combos", "party") } },
      { source = "[14] Config hub", actions = { action("boop.ui.config", "party") } },
      { source = "[15] Control dashboard", actions = { action("boop.ui.controlCommand", "") } },
      { source = "boop party assist <leader>", actions = seedActions("boop party assist") },
      { source = "boop party targetcall on|off", actions = seedActions("boop party targetcall on|off") },
      { source = "boop party affcalls on|off", actions = seedActions("boop party affcalls on|off") },
      { source = "boop party walk <cmd>", actions = seedActions("boop party walk") },
      { source = "boop walk install", actions = seedActions("boop walk install") },
      { source = "boop roster", actions = seedActions("boop roster") },
      { source = "boop combos", actions = seedActions("boop combos") },
    },
  },
  ["boop help home"] = {
    required = { "HELP", "TOPICS" },
    callbacks = {
      { source = "[1] Open boop", actions = seedActions("boop") },
      { source = "[2] Control dashboard", actions = seedActions("boop control") },
      { source = "[3] Settings hub", actions = seedActions("boop config") },
      { source = "[4] Party dashboard", actions = seedActions("boop party") },
      { source = "[5] Stats dashboard", actions = seedActions("boop stats") },
      { source = "[6] Start Here", actions = { action("boop.ui.help", "start") } },
      { source = "[7] Control & Config", actions = { action("boop.ui.help", "control") } },
      { source = "[8] Hunting & Targeting", actions = { action("boop.ui.help", "hunting") } },
      { source = "[9] Party & Leader", actions = { action("boop.ui.help", "party") } },
      { source = "[10] Stats & Optimization", actions = { action("boop.ui.help", "stats") } },
      { source = "[11] Diagnostics & Advanced", actions = { action("boop.ui.help", "diagnostics") } },
      { source = "boop help home", actions = seedActions("boop help home") },
      { source = "boop help <number|topic>", actions = seedActions("boop help") },
    },
  },
  ["boop stats"] = function(renderedText)
    return {
      required = { "BOOP STATS", "NEXT VIEWS" },
      callbacks = statsDashboardCallbacks(renderedText),
    }
  end,
}

expectedByCommand["boop help start"] = helpTopicExpectation(HELP_TOPICS.start)
expectedByCommand["boop help control"] = helpTopicExpectation(HELP_TOPICS.control)
expectedByCommand["boop help hunting"] = helpTopicExpectation(HELP_TOPICS.hunting)
expectedByCommand["boop help party"] = helpTopicExpectation(HELP_TOPICS.party)
expectedByCommand["boop help stats"] = helpTopicExpectation(HELP_TOPICS.stats)
expectedByCommand["boop help diagnostics"] = helpTopicExpectation(HELP_TOPICS.diagnostics)

local function compareActions(expected, observed)
  if #expected ~= #observed then
    return false
  end
  for i = 1, #expected do
    if tostring(expected[i]) ~= tostring(observed[i]) then
      return false
    end
  end
  return true
end

local function sourceMatches(expectedSource, observed)
  local wanted = tostring(expectedSource or "")
  if wanted == "" then
    return true
  end
  if contains(observed.context, wanted) then
    return true
  end
  if contains(observed.button, wanted) then
    return true
  end
  return false
end

local function recordCheck(label, ok, detail)
  totalChecks = totalChecks + 1
  if ok then
    appendLine(string.format("  [OK] %s", label))
  else
    failedChecks = failedChecks + 1
    appendLine(string.format("  [MISMATCH] %s", label))
    if detail and detail ~= "" then
      appendLine("             " .. detail)
    end
  end
end

local function verifyCommand(command, renderedText, observedCallbacks)
  local expectation = expectedByCommand[command]
  if type(expectation) == "function" then
    expectation = expectation(renderedText, observedCallbacks)
  end
  if not expectation then
    appendLine("verification:")
    appendLine("  (no expectations defined for this command)")
    return
  end

  appendLine("verification:")

  for _, fragment in ipairs(expectation.required or {}) do
    recordCheck(
      "render contains " .. quote(fragment),
      contains(renderedText, fragment),
      "Missing rendered fragment: " .. quote(fragment)
    )
  end

  recordCheck(
    "callback count == " .. tostring(#(expectation.callbacks or {})),
    #observedCallbacks == #(expectation.callbacks or {}),
    string.format("Observed %d callbacks", #observedCallbacks)
  )

  for index, expected in ipairs(expectation.callbacks or {}) do
    local observed = observedCallbacks[index]
    if not observed then
      recordCheck(
        string.format("callback %02d exists", index),
        false,
        "Missing callback; expected source fragment " .. quote(expected.source or "")
      )
    else
      if expected.source then
        recordCheck(
          string.format("callback %02d source contains %s", index, quote(expected.source)),
          sourceMatches(expected.source, observed),
          "Observed source/button: " .. quote(observed.context) .. " / " .. quote(observed.button)
        )
      end
      if expected.button then
        recordCheck(
          string.format("callback %02d button contains %s", index, quote(expected.button)),
          contains(observed.button, expected.button),
          "Observed button: " .. quote(observed.button)
        )
      end
      if expected.hint then
        recordCheck(
          string.format("callback %02d hint contains %s", index, quote(expected.hint)),
          contains(observed.hint, expected.hint),
          "Observed hint: " .. quote(observed.hint)
        )
      end
      recordCheck(
        string.format("callback %02d action log matches", index),
        compareActions(expected.actions or {}, observed.events or {}),
        "Observed: " .. table.concat(observed.events or {}, " || ")
      )
      if expected.contract then
        appendLine("  [EXPECT] callback " .. string.format("%02d", index) .. " downstream contract: " .. expected.contract)
      end
    end
  end
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
  currentRenderLines = {}

  appendLine(string.rep("=", 96))
  appendLine(string.format("[%02d/%02d] %s", index, #commands, command))
  appendLine(string.rep("-", 96))
  if index == 1 then
    appendLine("loaded boop version: " .. tostring(boop and boop.version or "(unknown)"))
    appendLine("")
  end

  local ok, err = pcall(expandAlias, command)
  flushPending()
  local renderedText = table.concat(currentRenderLines, "\n")
  currentRenderLines = nil

  if not ok then
    appendLine("[SCRIPT ERROR] " .. tostring(err))
  end

  local observedCallbacks = {}
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

      local callbackOk, callbackErr, events = withWrappedPaths(function()
        if type(item.callback) == "function" then
          item.callback()
        else
          fail("callback " .. tostring(callbackIndex) .. " is not callable")
        end
      end)

      local observed = {
        context = item.context,
        button = item.button,
        hint = item.hint,
        events = {},
      }

      if not callbackOk then
        observed.events = { "[SCRIPT ERROR] " .. tostring(callbackErr) }
        appendLine("       action: [SCRIPT ERROR] " .. tostring(callbackErr))
      elseif #events == 0 then
        appendLine("       action: (no observable wrapped call)")
      else
        observed.events = events
        for eventIndex, event in ipairs(events) do
          local prefix = eventIndex == 1 and "       action: " or "               "
          appendLine(prefix .. event)
        end
      end

      observedCallbacks[#observedCallbacks + 1] = observed
    end
  end

  verifyCommand(command, renderedText, observedCallbacks)
  appendLine("")
end

appendLine(string.rep("=", 96))
appendLine("SUMMARY")
appendLine(string.rep("-", 96))
appendLine(string.format("checks: %d", totalChecks))
appendLine(string.format("mismatches: %d", failedChecks))

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
