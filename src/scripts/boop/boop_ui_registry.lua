boop.ui = boop.ui or {}
boop.config = boop.config or {}
boop.registry = boop.registry or {}
boop.registry.config = boop.registry.config or {}
boop.registry.ui = boop.registry.ui or {}

boop.registry.config.schema = boop.registry.config.schema or {
  order = {
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
    "ragePoolThreshold",
    "pullRageReserve",
    "breakShields",
    "fleeEnabled",
    "fleeKeepEnabled",
    "fleeAt",
    "tempoRageWindowSeconds",
    "tempoSqueezeEtaSeconds",
    "focusVerb",
    "traceEnabled",
    "gagOwnAttacks",
    "gagOthersAttacks",
    "gagMobAttacks",
    "gagColorWho",
    "gagColorAbility",
    "gagColorTarget",
    "gagColorMeta",
    "gagColorSeparator",
    "gagColorBackground",
    "gagOtherColorWho",
    "gagOtherColorAbility",
    "gagOtherColorTarget",
    "gagOtherColorMeta",
    "gagOtherColorSeparator",
    "gagOtherColorBackground",
    "gagMobColorWho",
    "gagMobColorAbility",
    "gagMobColorTarget",
    "gagMobColorMeta",
    "gagMobColorSeparator",
    "gagMobColorBackground",
    "diagTimeoutSeconds",
    "partySize",
    "partyRoster",
    "targetCall",
    "autoTargetCall",
    "rageAffCalloutsEnabled",
    "assistEnabled",
    "assistLeader",
    "uiTheme",
    "gameSeparator",
  },
  aliases = {
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
    ragepool = "ragePoolThreshold",
    ragepoolthreshold = "ragePoolThreshold",
    trace = "traceEnabled",
    traceenabled = "traceEnabled",
    gag = "gagOwnAttacks",
    gagown = "gagOwnAttacks",
    gagownattacks = "gagOwnAttacks",
    gagothers = "gagOthersAttacks",
    gagothersattacks = "gagOthersAttacks",
    gagmob = "gagMobAttacks",
    gagmobs = "gagMobAttacks",
    gagmobattacks = "gagMobAttacks",
    gagmobsattacks = "gagMobAttacks",
    incominggag = "gagMobAttacks",
    gagcolorwho = "gagColorWho",
    gagcolorability = "gagColorAbility",
    gagcolortarget = "gagColorTarget",
    gagcolormeta = "gagColorMeta",
    gagcolorseparator = "gagColorSeparator",
    gagcolorbg = "gagColorBackground",
    gagcolorbackground = "gagColorBackground",
    gagothercolorwho = "gagOtherColorWho",
    gagothercolorability = "gagOtherColorAbility",
    gagothercolortarget = "gagOtherColorTarget",
    gagothercolormeta = "gagOtherColorMeta",
    gagothercolorseparator = "gagOtherColorSeparator",
    gagothercolorbg = "gagOtherColorBackground",
    gagothercolorbackground = "gagOtherColorBackground",
    gagmobcolorwho = "gagMobColorWho",
    gagmobcolorability = "gagMobColorAbility",
    gagmobcolortarget = "gagMobColorTarget",
    gagmobcolormeta = "gagMobColorMeta",
    gagmobcolorseparator = "gagMobColorSeparator",
    gagmobcolorbg = "gagMobColorBackground",
    gagmobcolorbackground = "gagMobColorBackground",
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
    pullreserve = "pullRageReserve",
    pullragereserve = "pullRageReserve",
    breakshields = "breakShields",
    breakshield = "breakShields",
    shieldbreak = "breakShields",
    shieldbreaks = "breakShields",
    flee = "fleeEnabled",
    fleeenabled = "fleeEnabled",
    fleekeepenabled = "fleeKeepEnabled",
    keepenabledafterflee = "fleeKeepEnabled",
    fleeat = "fleeAt",
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
    gameseparator = "gameSeparator",
    focus = "focusVerb",
    focusverb = "focusVerb",
  },
}

do
  local schema = boop.registry.config.schema
  local found = false
  for _, key in ipairs(schema.order or {}) do
    if key == "ragePoolThreshold" then
      found = true
      break
    end
  end
  if not found then
    local inserted = false
    for index, key in ipairs(schema.order or {}) do
      if key == "attackMode" then
        table.insert(schema.order, index + 1, "ragePoolThreshold")
        inserted = true
        break
      end
    end
    if not inserted then
      schema.order[#schema.order + 1] = "ragePoolThreshold"
    end
  end
  schema.aliases = schema.aliases or {}
  schema.aliases.ragepool = "ragePoolThreshold"
  schema.aliases.ragepoolthreshold = "ragePoolThreshold"
end

boop.registry.ui.modes = boop.registry.ui.modes or {
  solo = {
    key = "solo",
    requiresLeader = false,
    summary = "Disable assist and leader target coordination.",
    values = {
      assistEnabled = false,
      autoTargetCall = false,
      targetCall = false,
    },
    clearTargetCall = true,
    message = function()
      return "mode: solo"
    end,
  },
  assist = {
    key = "assist",
    requiresLeader = true,
    summary = "Prefix attacks with assist and do not wait for leader target calls.",
    values = {
      assistEnabled = true,
      autoTargetCall = false,
      targetCall = false,
    },
    clearTargetCall = true,
    message = function(leader)
      return "mode: assist -> " .. tostring(leader)
    end,
  },
  leader = {
    key = "leader",
    aliases = { "leading" },
    requiresLeader = false,
    summary = "Automatically party-call each new target you engage.",
    values = {
      assistEnabled = false,
      autoTargetCall = true,
      targetCall = false,
    },
    clearTargetCall = true,
    message = function()
      return "mode: leader"
    end,
  },
  ["leader-call"] = {
    key = "leader-call",
    aliases = { "leadercall", "lead" },
    requiresLeader = true,
    summary = "Wait for a called target from your configured leader.",
    values = {
      assistEnabled = true,
      autoTargetCall = false,
      targetCall = true,
    },
    clearTargetCall = false,
    message = function(leader)
      return "mode: leader-call -> " .. tostring(leader)
    end,
  },
}

boop.registry.ui.presets = boop.registry.ui.presets or {
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
    requiresLeader = true,
  },
}

local function configBoolSetter(opts)
  return function(raw, ctx)
    local parsed = ctx.parseBool(raw)
    if parsed == nil then
      boop.util.warn(opts.warn or (tostring(opts.key or "value") .. " expects on/off"))
      return
    end

    if opts.apply then
      opts.apply(parsed, ctx)
      return
    end

    local key = opts.saveKey or opts.key
    ctx.save(key, parsed)
    boop.util.ok((opts.okLabel or key) .. ": " .. (parsed and "on" or "off"))

    if opts.reopen then
      ctx.reopen(opts.reopen.screen, opts.reopen.prefix)
    end
  end
end

local function configNumberSetter(opts)
  return function(raw, ctx)
    local value = tonumber(boop.util.trim(raw or ""))
    if not value then
      boop.util.warn(opts.warn)
      return
    end
    if opts.integer and value ~= math.floor(value) then
      boop.util.warn(opts.warn)
      return
    end
    if opts.min ~= nil and value < opts.min then
      boop.util.warn(opts.warn)
      return
    end
    if opts.strictMin ~= nil and value <= opts.strictMin then
      boop.util.warn(opts.warn)
      return
    end
    if opts.max ~= nil and value > opts.max then
      boop.util.warn(opts.warn)
      return
    end

    ctx.save(opts.saveKey or opts.key, value)
    if opts.ok then
      boop.util.ok(opts.ok(value))
    end
    if opts.reopen then
      ctx.reopen(opts.reopen.screen, opts.reopen.prefix)
    end
  end
end

local function gagColorSetter(scope, role)
  return function(raw)
    boop.gag.setColor(scope, role, raw)
  end
end

local shieldModeConfigSetter = configBoolSetter({
  key = "breakShields",
  warn = "breakShields expects on/off",
  apply = function(parsed)
    boop.ui.shieldModeCommand(parsed and "break" or "bypass")
  end,
})

local function ragePoolConfigSetter(raw)
  boop.ui.ragePoolCommand(raw)
end

boop.registry.config.setters = boop.registry.config.setters or {
  enabled = configBoolSetter({
    key = "enabled",
    warn = "enabled expects on/off",
    apply = function(parsed)
      boop.ui.setEnabled(parsed)
    end,
  }),
  targetingMode = function(raw)
    boop.ui.setTargetingMode(raw)
  end,
  useQueueing = configBoolSetter({
    key = "useQueueing",
    warn = "useQueueing expects on/off",
    okLabel = "use queueing",
  }),
  prequeueEnabled = configBoolSetter({
    key = "prequeueEnabled",
    warn = "prequeue expects on/off",
    apply = function(parsed)
      boop.ui.setPrequeueEnabled(parsed)
    end,
  }),
  attackLeadSeconds = function(raw)
    boop.ui.setAttackLeadSeconds(raw)
  end,
  autoGrabGold = configBoolSetter({
    key = "autoGrabGold",
    warn = "autogold expects on/off",
    apply = function(parsed)
      boop.ui.setAutoGrabGold(parsed)
    end,
  }),
  goldPack = function(raw)
    boop.ui.setGoldPack(raw)
  end,
  whitelistPriorityOrder = configBoolSetter({
    key = "whitelistPriorityOrder",
    warn = "whitelistPriorityOrder expects on/off",
  }),
  retargetOnPriority = configBoolSetter({
    key = "retargetOnPriority",
    warn = "retargetOnPriority expects on/off",
  }),
  targetOrder = function(raw, ctx)
    local order = boop.util.safeLower(boop.util.trim(raw or ""))
    if order ~= "order" and order ~= "numeric" and order ~= "reverse" then
      boop.util.warn("targetOrder expects order|numeric|reverse")
      return
    end
    ctx.save("targetOrder", order)
    boop.util.ok("targetOrder: " .. order)
  end,
  attackMode = function(raw)
    boop.ui.setRageMode(raw)
  end,
  ragePoolThreshold = ragePoolConfigSetter,
  pullRageReserve = configBoolSetter({
    key = "pullRageReserve",
    warn = "pullRageReserve expects on/off",
    okLabel = "pull rage reserve",
    reopen = { screen = "combat" },
  }),
  breakShields = shieldModeConfigSetter,
  fleeEnabled = configBoolSetter({
    key = "fleeEnabled",
    warn = "flee expects on/off",
    apply = function(parsed)
      boop.ui.fleeCommand(parsed and "on" or "off")
    end,
  }),
  fleeKeepEnabled = configBoolSetter({
    key = "fleeKeepEnabled",
    warn = "fleeKeepEnabled expects on/off",
    okLabel = "keep boop enabled after flee",
    reopen = { screen = "combat" },
  }),
  fleeAt = function(raw)
    boop.ui.fleeCommand(raw)
  end,
  tempoRageWindowSeconds = configNumberSetter({
    key = "tempoRageWindowSeconds",
    warn = "tempoRageWindowSeconds expects number > 0",
    strictMin = 0,
    ok = function(value)
      return string.format("tempo rage window: %.2fs", value)
    end,
    reopen = { screen = "combat", prefix = "boop set tempoRageWindowSeconds " },
  }),
  tempoSqueezeEtaSeconds = configNumberSetter({
    key = "tempoSqueezeEtaSeconds",
    warn = "tempoSqueezeEtaSeconds expects number >= 0",
    min = 0,
    ok = function(value)
      return string.format("tempo squeeze eta: %.2fs", value)
    end,
    reopen = { screen = "combat", prefix = "boop set tempoSqueezeEtaSeconds " },
  }),
  focusVerb = function(raw)
    boop.ui.focusVerbCommand(raw)
  end,
  traceEnabled = configBoolSetter({
    key = "traceEnabled",
    warn = "trace expects on/off",
    apply = function(parsed)
      boop.ui.setTraceEnabled(parsed)
    end,
  }),
  gagOwnAttacks = configBoolSetter({
    key = "gagOwnAttacks",
    warn = "gagOwnAttacks expects on/off",
    apply = function(parsed)
      boop.gag.setOwn(parsed)
    end,
  }),
  gagOthersAttacks = configBoolSetter({
    key = "gagOthersAttacks",
    warn = "gagOthersAttacks expects on/off",
    apply = function(parsed)
      boop.gag.setOthers(parsed)
    end,
  }),
  gagMobAttacks = configBoolSetter({
    key = "gagMobAttacks",
    warn = "gagMobAttacks expects on/off",
    apply = function(parsed)
      boop.gag.setMobs(parsed)
    end,
  }),
  gagColorWho = gagColorSetter("own", "who"),
  gagColorAbility = gagColorSetter("own", "ability"),
  gagColorTarget = gagColorSetter("own", "target"),
  gagColorMeta = gagColorSetter("own", "meta"),
  gagColorSeparator = gagColorSetter("own", "separator"),
  gagColorBackground = gagColorSetter("own", "background"),
  gagOtherColorWho = gagColorSetter("others", "who"),
  gagOtherColorAbility = gagColorSetter("others", "ability"),
  gagOtherColorTarget = gagColorSetter("others", "target"),
  gagOtherColorMeta = gagColorSetter("others", "meta"),
  gagOtherColorSeparator = gagColorSetter("others", "separator"),
  gagOtherColorBackground = gagColorSetter("others", "background"),
  gagMobColorWho = gagColorSetter("mobs", "who"),
  gagMobColorAbility = gagColorSetter("mobs", "ability"),
  gagMobColorTarget = gagColorSetter("mobs", "target"),
  gagMobColorMeta = gagColorSetter("mobs", "meta"),
  gagMobColorSeparator = gagColorSetter("mobs", "separator"),
  gagMobColorBackground = gagColorSetter("mobs", "background"),
  diagTimeoutSeconds = configNumberSetter({
    key = "diagTimeoutSeconds",
    warn = "diagTimeoutSeconds expects number >= 0",
    min = 0,
    ok = function(value)
      return string.format("diag timeout: %.2fs", value)
    end,
    reopen = { screen = "combat", prefix = "boop set diagtimeout " },
  }),
  partySize = configNumberSetter({
    key = "partySize",
    warn = "partySize expects integer >= 1",
    min = 1,
    integer = true,
    ok = function(value)
      return "party size: " .. tostring(value)
    end,
  }),
  partyRoster = function(raw)
    boop.ui.rosterCommand(raw or "")
  end,
  targetCall = function(raw, ctx)
    local parsed = ctx.parseBool(raw)
    if parsed == nil then
      boop.util.warn("targetCall expects on/off")
      return
    end
    if parsed and boop.ui and boop.ui.assistLeader and boop.ui.assistLeader() == "" then
      boop.util.warn("target call mode needs a leader; use: boop assist <name>")
      return
    end
    ctx.save("targetCall", parsed)
    if parsed and boop.config.autoTargetCall then
      ctx.save("autoTargetCall", false)
    end
    if not parsed and boop.targets and boop.targets.clearTargetCall then
      boop.targets.clearTargetCall("target call disabled")
    end
    boop.util.ok("leader target call gate: " .. (parsed and "on" or "off"))
  end,
  autoTargetCall = function(raw, ctx)
    local parsed = ctx.parseBool(raw)
    if parsed == nil then
      boop.util.warn("autoTargetCall expects on/off")
      return
    end
    local hadTargetCall = not not boop.config.targetCall
    ctx.save("autoTargetCall", parsed)
    if parsed and hadTargetCall then
      ctx.save("targetCall", false)
      if boop.targets and boop.targets.clearTargetCall then
        boop.targets.clearTargetCall("auto target call enabled")
      end
    end
    boop.util.ok("auto target calls: " .. (parsed and "on" or "off"))
  end,
  assistEnabled = function(raw, ctx)
    local parsed = ctx.parseBool(raw)
    if parsed == nil then
      boop.util.warn("assist expects on/off")
      return
    end
    if parsed and boop.ui and boop.ui.assistLeader and boop.ui.assistLeader() == "" then
      boop.util.warn("assist needs a leader; use: boop assist <name>")
      return
    end
    ctx.save("assistEnabled", parsed)
    boop.util.ok("assist: " .. (parsed and "on" or "off"))
  end,
  assistLeader = function(raw, ctx)
    local leader = boop.util.trim(raw or "")
    ctx.save("assistLeader", leader)
    if leader == "" then
      ctx.save("assistEnabled", false)
      boop.util.ok("assist leader cleared")
      return
    end
    ctx.save("assistEnabled", true)
    boop.util.ok("assist leader: " .. leader)
  end,
  uiTheme = function(raw)
    boop.ui.themeCommand(raw)
  end,
  gameSeparator = function(raw)
    boop.ui.gameSeparatorCommand(raw)
  end,
  rageAffCalloutsEnabled = configBoolSetter({
    key = "rageAffCalloutsEnabled",
    warn = "affcalls expects on/off",
    okLabel = "rage affliction callouts",
  }),
}

-- Refresh changed command behavior when a package update reuses the live registry.
boop.registry.config.setters.breakShields = shieldModeConfigSetter
boop.registry.config.setters.ragePoolThreshold = ragePoolConfigSetter

local function helpSeedCommand(command)
  local seed = boop.util.trim(tostring(command or ""))
  seed = seed:gsub("%s*%b[]", "")
  local requiredAt = seed:find("<", 1, true)
  local needsValue = requiredAt ~= nil
  if requiredAt then
    seed = seed:sub(1, requiredAt - 1)
  end
  seed = seed:gsub("%S+", function(token)
    return token:match("^([^|]+)|") or token
  end)
  seed = boop.util.trim(seed:gsub("%s+", " "))
  if needsValue and seed ~= "" then
    seed = seed .. " "
  end
  return seed
end

boop.registry.ui.helpSeedCommand = helpSeedCommand

local function helpCommand(command, description, seed)
  local display = tostring(command or "")
  return {
    command = display,
    description = tostring(description or ""),
    seed = seed ~= nil and tostring(seed) or helpSeedCommand(display),
  }
end

boop.registry.ui.helpTopics = {
  {
    key = "start",
    title = "Start Here",
    summary = "Get from a fresh install to a safe first hunt without guessing which screen to open.",
    aliases = { "start", "gettingstarted", "intro", "basics", "general", "main", "home" },
    steps = {
      helpCommand("boop", "Open the home dashboard. Read `Status`, active operations, and `Next action`; they explain why boop will or will not attack."),
      helpCommand("boop preset solo", "Apply the conservative solo baseline: whitelist targeting, simple rage, prequeue, autogold, and no party gates."),
      helpCommand("boop config targeting", "Check target mode, target order, and whitelist/blacklist tools before enabling attacks."),
      helpCommand("ih", "Scan the room. Denizens get clickable whitelist/blacklist actions in boop's info-here output."),
      helpCommand("boop whitelist add <name>", "Allow one denizen name in the current area if the whitelist is empty or missing the mob you want."),
      helpCommand("boop on", "Enable hunting once the target rules look right."),
    },
    commands = {
      helpCommand("boop", "Home dashboard: computed state, target, active operations, and the best next screen."),
      helpCommand("boop control", "Live dashboard for hunting, movement, queueing, active operations, and runtime state."),
      helpCommand("boop config", "Settings hub for combat, targeting, loot, diagnostics, party, theme, and stats routes."),
      helpCommand("boop party", "Party dashboard for assist, leader target calls, walker state, and roster."),
      helpCommand("boop stats", "Stats dashboard for current hunt performance and drill-downs."),
      helpCommand("boop status", "Open the full status dashboard with computed readiness and active operation details."),
      helpCommand("boop help <goal>", "Open a focused help page such as `solo`, `targeting`, `rage`, `gold`, `party`, or `diagnostics`."),
    },
    notes = {
      "If there is no target, start with `boop help targeting`. If there is a target but no attack, start with `boop help combat`.",
      "Whitelists are area-specific. Move to the hunting area before running `ih` or adding names.",
      "Most daily use should move between `boop`, `boop control`, `boop config`, `boop party`, and `boop stats`.",
    },
  },
  {
    key = "control",
    title = "Dashboards & Settings",
    summary = "Where to look for current state, live controls, and guided settings.",
    aliases = { "control", "controls", "config", "settings", "dashboard" },
    steps = {
      helpCommand("boop", "Start here when you are unsure what boop is doing; the home dashboard shows computed status, active operations, and the next useful surface."),
      helpCommand("boop control", "Use this while hunting. It combines enabled state, target, active operations, queueing, party, walk, and quick navigation."),
      helpCommand("boop config", "Use this when you intend to change settings rather than inspect live state."),
      helpCommand("boop control <route>", "Jump straight to a related surface such as `combat`, `targeting`, `loot`, `debug`, `party`, `stats`, or `mode`."),
    },
    commands = {
      helpCommand("boop status", "Open the full status dashboard with configuration, readiness, target, and active operation details."),
      helpCommand("boop control status", "Open the fuller status dashboard from the control route, including active operation systems and waits."),
      helpCommand("boop control combat|targeting|loot|debug", "Jump from control to the matching config subsection."),
      helpCommand("boop control party|roster|stats|theme|mode", "Jump from control to related operator surfaces."),
      helpCommand("boop config home", "Return to the top-level config hub."),
      helpCommand("boop config combat", "Open combat and queueing settings."),
      helpCommand("boop config targeting", "Open targeting mode, order, and list-management settings."),
      helpCommand("boop config loot", "Open sovereign pickup and gold-pack settings."),
      helpCommand("boop config debug", "Open trace, gag, and debug settings."),
      helpCommand("boop config <section> <number>", "Run one numbered config action directly, for example `boop config combat 5`."),
      helpCommand("boop preset list", "Show the shipped baseline presets and what each one changes."),
      helpCommand("boop preset <solo|party|leader|leader-call>", "Apply a curated baseline without stepping through each setting."),
      helpCommand("boop theme <name|auto|list>", "Inspect or change the UI theme."),
    },
    notes = {
      "Status/control screens answer `what is happening now?`; config screens answer `what should boop do next time?`.",
      "Numbered config rows apply immediately unless the row seeds a command for you to finish typing.",
    },
  },
  {
    key = "solo",
    title = "Start Solo Hunting",
    summary = "Recommended one-character hunting flow with whitelist targeting and basic safety.",
    aliases = { "solo", "hunt", "hunting" },
    steps = {
      helpCommand("boop preset solo", "Set the normal solo baseline before tuning anything else."),
      helpCommand("boop targeting whitelist", "Use the safest target mode: attack only names saved for the current area."),
      helpCommand("ih", "Scan the room and add/remove denizen names with the clickable list actions."),
      helpCommand("boop config loot", "Confirm autogold and optional pack stashing before you start killing."),
      helpCommand("boop trip start", "Start a tracked hunt if you want this run to be comparable later."),
      helpCommand("boop on", "Start hunting; use `boop control` if you need to watch the live state."),
    },
    commands = {
      helpCommand("bh", "Toggle boop on/off with the compact hunting summary."),
      helpCommand("boop on|off", "Enable or disable hunting explicitly without changing saved settings."),
      helpCommand("boop off", "Stop hunting without clearing settings."),
      helpCommand("boop status", "Open the full status dashboard for enabled state, class/profile readiness, targeting, rage, loot, and active operations."),
      helpCommand("boop control", "Watch target, active operations, queue, party, and walker state while hunting."),
      helpCommand("boop flee <on|off|percent>", "Control auto-flee and set its HP threshold, for example `boop flee 25%`."),
      helpCommand("boop flee keepenabled <on|off|toggle>", "Choose whether boop remains enabled after it flees; the default is off."),
      helpCommand("bflee", "Immediately run boop's flee action using the last room direction and apply the configured keep-enabled policy."),
      helpCommand("boop autogold on|off", "Control automatic pickup of dropped sovereigns."),
      helpCommand("boop pack <container>", "Set a container for automatic sovereign stashing after pickup."),
      helpCommand("boop stats", "Review session/trip performance and suggested drill-downs."),
    },
    notes = {
      "Whitelist mode only attacks names saved for the current area. If boop finds no target, check the area whitelist first.",
      "Targeting uses denizen ids internally, so target calls and traces usually show numeric ids.",
      "Solo mode does not stop you from hunting near other players; it only disables assist/leader target coordination.",
    },
  },
  {
    key = "targeting",
    title = "Targeting & Lists",
    summary = "How boop chooses denizens, why it may refuse to target, and how list data is managed.",
    aliases = { "targeting", "targets", "whitelist", "blacklist", "ih" },
    steps = {
      helpCommand("boop config targeting", "Open the guided targeting screen; it shows mode, order, room denizen count, and leader target gate."),
      helpCommand("boop targeting whitelist", "Use whitelist mode when you want explicit per-area permission before boop attacks."),
      helpCommand("ih", "Capture denizens in the current room and show clickable whitelist/blacklist actions."),
      helpCommand("boop whitelist", "Review the current area's allowed names and adjust ordering with the clickable manager."),
      helpCommand("boop whitelist add <name>", "Allow a denizen name in the current area."),
      helpCommand("boop blacklist add <name>", "Block a denizen name in the current area."),
    },
    commands = {
      helpCommand("boop targeting", "Show the current targeting mode and valid mode names."),
      helpCommand("boop targeting <manual|whitelist|blacklist|auto>", "Set the target-selection mode for this profile session; each new session starts in whitelist mode."),
      helpCommand("boop whitelist", "Open or print the current area whitelist."),
      helpCommand("boop whitelist add <name>", "Add a denizen name to the current area's whitelist."),
      helpCommand("boop whitelist remove <name>", "Remove a name from the current area's whitelist."),
      helpCommand("boop whitelist browse [tag]", "Browse whitelist areas, optionally filtered by tag."),
      helpCommand("boop whitelist tags <area>", "Show tags saved for one whitelist area."),
      helpCommand("boop whitelist tag list", "Show all known whitelist tags and the areas using them."),
      helpCommand("boop whitelist tag add <area> | <tag[,tag2,...]>", "Add tags to a whitelist area."),
      helpCommand("boop whitelist tag remove <area> | <tag[,tag2,...]>", "Remove tags from a whitelist area."),
      helpCommand("boop blacklist", "Open or print the current area blacklist."),
      helpCommand("boop blacklist add|remove <name>", "Manage the current area's deny list."),
      helpCommand("boop blacklist global", "Open the global blacklist that applies in every area."),
      helpCommand("boop blacklist global add|remove <name>", "Manage names blocked in every area."),
    },
    advanced = {
      helpCommand("boop whitelist share [area]", "Share an area's ordered whitelist to party chat."),
      helpCommand("boop whitelist receive [merge|merge-reorder|overwrite|reject]", "Review or apply the latest incoming whitelist share."),
      helpCommand("boop set whitelistPriorityOrder on|off", "Choose whether whitelist order changes target priority."),
      helpCommand("boop set retargetOnPriority on|off", "on = switch to a higher-priority allowed denizen when one appears; off = stay on your current target until it dies or leaves."),
      helpCommand("boop set targetOrder order|numeric|reverse", "Choose how room denizens are ordered before whitelist priority is applied."),
    },
    notes = {
      "Each new profile session starts in whitelist mode. A mode selected with `boop targeting` lasts for the current session only.",
      "`manual` means boop will not choose targets. `auto` may attack any valid denizen not blocked by blacklist rules.",
      "`blacklist` mode attacks valid denizens except names on the current or global blacklist.",
      "A departed target quarantines its fixed queued alias until old result/grace terminal evidence, without clearing or rebinding the server queue.",
      "An explicit blacklist or other forbidden-target revocation sends one traced `clearqueue all`, even when current-room presence is unknown, before replacement targeting resumes.",
      "Target list displays support clickable management for whitelist, blacklist, and tags.",
      "Whitelist sharing currently uses party chat only and transfers the ordered mob list, not whitelist tags.",
    },
  },
  {
    key = "combat",
    title = "Combat, Rage & Queueing",
    summary = "How boop chooses standard attacks, rage actions, prequeue timing, and combat safety settings.",
    aliases = { "combat", "rage", "ragemode", "attackmode", "ragepool", "queue", "queueing", "prequeue", "flee", "pull", "focus", "prefer", "weapon", "aff" },
    steps = {
      helpCommand("boop config combat", "Open guided hunting, rage, queueing, interrupt, pull, focus, and flee controls."),
      helpCommand("boop ragemode", "Open the rage-mode chooser; numbered rows can be clicked or typed as `boop ragemode 1`."),
      helpCommand("boop prequeue on", "Let boop prepare standard attacks shortly before balance returns."),
      helpCommand("boop flee 30%", "Enable auto-flee and set the health threshold in one command."),
      helpCommand("boop prefer", "Show class/spec standard attack options before overriding damage or shieldbreak preference."),
    },
    commands = {
      helpCommand("boop ragemode <number|simple|big|small|aff|tempo|combo|hybrid|none>", "Set how boop chooses battlerage actions; unavailable class modes are marked and rejected."),
      helpCommand("boop ragepool <0-100|off>", "Reserve this much rage after ordinary battlerage spending."),
      helpCommand("boop prequeue [on|off]", "Show, enable, or disable early standard-attack queueing."),
      helpCommand("boop lead [seconds]", "Show or set how early boop should prequeue before balance returns."),
      helpCommand("boop prefer", "Show standard attack preference options for your current class/spec."),
      helpCommand("boop prefer <dam|shield> <option>", "Prefer one valid standard damage or shield attack over another."),
      helpCommand("boop prefer clear <dam|shield>", "Return one standard attack preference to the profile default."),
      helpCommand("boop prefer temp <dam|shield> <option>", "Override the current class/spec preference for this session only."),
      helpCommand("boop prefer temp clear [dam|shield]", "Clear temporary preference overrides and reveal saved preferences."),
      helpCommand("boop shieldmode break|bypass|toggle", "Use shieldbreaks or keep the current class/spec's normal attacks for this session."),
      helpCommand("boop aff", "Show manually tracked target afflictions used by aff/combo/hybrid rage logic."),
      helpCommand("boop aff add|remove <a/b>", "Manually add or remove one or more slash-separated target afflictions."),
      helpCommand("boop aff clear", "Clear manually tracked target afflictions."),
    },
    advanced = {
      helpCommand("boop set queueing on|off", "Toggle Mudlet/game queue usage directly; most users should use `boop config combat`."),
      helpCommand("boop weapon", "Show Depthswalker dagger and scythe designations."),
      helpCommand("boop weapon <dagger|scythe> <item-id>", "Save a Depthswalker weapon id, such as `scythe 47177`."),
      helpCommand("boop weapon clear <dagger|scythe>", "Clear one saved Depthswalker weapon designation."),
      helpCommand("boop focus <speed|precision>", "Choose which battlefury focus verb two-handed standards prepend when Focus is known."),
      helpCommand("boop separator <text>", "Set the game-side separator used by pull, such as `|`."),
      helpCommand("pull <mobname> <direction>", "Move in, use a ready damage battlerage attack on the typed mob name, then leap back."),
      helpCommand("boop set pullRageReserve on|off", "Reserve enough rage for a pull-capable damage hit."),
      helpCommand("boop set ragePoolThreshold <0-100>", "Compatibility form of `boop ragepool`; zero disables the threshold."),
      helpCommand("boop set breakShields on|off", "Compatibility form of session-only `boop shieldmode break|bypass`."),
      helpCommand("boop set tempoRageWindowSeconds <seconds>", "Tune tempo mode's rage recovery prediction window."),
      helpCommand("boop set tempoSqueezeEtaSeconds <seconds>", "Tune when tempo mode may spend damage while preserving affliction tempo."),
    },
    notes = {
      "Standard attacks and rage actions are independent; boop may use both when balance/rage/state allow.",
      "Queued standards replace the whole balance/equilibrium queue with `queue addclearfull freestand BOOP_ATTACK`; observed success or denial becomes terminal only at the following prompt, while ready-only silence uses one bounded grace/retry.",
      "A pending queued standard generation serializes target, alias, standard, Rage, and direct-dispatch mutation until that exact generation terminates.",
      "`simple` is the default rage mode. `combo` and `hybrid` are party-aware and depend on roster/profile affliction data.",
      "`aff` is unavailable when the active class profile has no affliction rage ability; stale cross-class `aff` settings use `simple` until changed.",
      "`none` disables rage attacks only; it does not disable standard attacks.",
      "A rage-pool reserve permits normal damage, affliction, and conditional rage actions only when their cost leaves the configured amount; shieldbreaks and Triumph free rage remain immediate.",
      "A causally owned generic Rage cooldown closes the global Battlerage gate until an exact Available-list recovery; the independent Triumph credit is generation-owned and expires if it is not consumed.",
      "Temporary attack preferences reset on package reload or reconnect and never replace the saved class/spec preference.",
      "Shield mode resets to `break` on package reload or reconnect; `bypass` applies to every class profile.",
      "Bypass mode only keeps normal attack selection; it does not make those attacks pierce shields.",
      "Queueing and prequeue are different: queueing changes how actions are sent; prequeue controls when the next standard attack is prepared.",
      "`pull` uses your configured separator and the typed mob name directly inside the rage command.",
      "`pull` releases on timeout only when you are back in the origin room; timing out elsewhere keeps combat held until matching return-room GMCP arrives.",
    },
  },
  {
    key = "interrupts",
    title = "Interrupts & Recovery",
    summary = "Commands that pause boop long enough to run a defensive or utility action cleanly.",
    aliases = { "interrupt", "interrupts", "diag", "diagnose", "matic", "catarin", "fly", "ts", "shield", "leap" },
    steps = {
      helpCommand("diag", "Send `clearqueue all`, replace the full balance/equilibrium queue with diagnose, and pause attacks until diagnose evidence plus prompt."),
      helpCommand("matic", "Replace the full balance/equilibrium queue with `ldeck draw matic` and resume on prompt or timeout."),
      helpCommand("fly", "Replace the full balance/equilibrium queue with `fly` and pause attacks until prompt or timeout."),
      helpCommand("leap <direction>", "Clear every server queue, queue the leap, and pause attacks until room change or timeout."),
      helpCommand("boop config combat", "Use the combat config screen if you need to tune the interrupt timeout."),
    },
    commands = {
      helpCommand("diag", "Clear every server queue, replace the full balance/equilibrium queue with diagnose, and pause boop until diagnose completes or times out."),
      helpCommand("matic", "Replace the full balance/equilibrium queue with `ldeck draw matic`."),
      helpCommand("catarin", "Replace the full balance/equilibrium queue with `ldeck draw catarin`."),
      helpCommand("fly", "Replace the full balance/equilibrium queue with `fly` and pause attacks until prompt or timeout."),
      helpCommand("ts", "Replace the full balance/equilibrium queue with `touch shield` and pause attacks until prompt or timeout."),
      helpCommand("leap <direction>", "Clear every server queue, queue the leap, and pause attacks until changed Room.Info or timeout."),
    },
    advanced = {
      helpCommand("boop set diagtimeout <seconds>", "Set the timeout used by diag and queued interrupt holds."),
    },
    notes = {
      "These commands are meant for quick intervention while boop is otherwise managing attacks.",
      "Pending interrupts are operation-owned; repeats do not resend or restart the timer.",
      "`diag` and `leap` send `clearqueue all`; every interrupt then uses `queue addclearfull freestand` regardless of boop's normal queue setting.",
      "`leap` ignores unrelated prompts and resumes after changed-room GMCP, an exact causally owned command-denial line, or timeout; ambiguous denial remains diagnostic until timeout.",
      "`diag` prefers the GMCP affliction snapshot and retains visible diagnose lines as fallback evidence.",
      "Two `You are confused as to the effects of the venom.` lines automatically force `diag`; successful completion resets that counter.",
    },
  },
  {
    key = "loot",
    title = "Loot, Packs & Import",
    summary = "Automatic sovereign pickup, optional pack stashing, and Foxhunt list import.",
    aliases = { "loot", "gold", "autogold", "pack", "sovereigns", "import", "foxhunt" },
    steps = {
      helpCommand("boop config loot", "Open guided loot controls and see whether pickup or pack stashing is enabled."),
      helpCommand("boop autogold on", "Pick up newly dropped gold sovereigns automatically."),
      helpCommand("boop pack <container>", "After pickup, put sovereigns into this container."),
      helpCommand("boop pack test", "Queue a look-in command for the configured pack to verify the container text/id."),
      helpCommand("boop import foxhunt dryrun", "Preview how many Foxhunt whitelist/blacklist entries can be imported before changing boop data."),
    },
    commands = {
      helpCommand("boop autogold", "Toggle automatic sovereign pickup."),
      helpCommand("boop autogold status", "Show automatic pickup, pack, and current gold-operation state without changing settings."),
      helpCommand("boop autogold on|off", "Enable or disable automatic pickup of newly dropped sovereigns."),
      helpCommand("boop pack", "Show the current automatic sovereign stash container."),
      helpCommand("boop pack <container>", "Set the container used by `put sovereigns in <container>` after pickup."),
      helpCommand("boop pack off|clear|none", "Disable automatic pack stashing without disabling sovereign pickup."),
      helpCommand("boop pack test", "Queue `look in <pack>` for the current configured pack."),
      helpCommand("boop import foxhunt [merge|overwrite|dryrun]", "Import whitelist and blacklist data from Foxhunt's Mudlet DB."),
    },
    notes = {
      "Autogold reacts to room items whose names contain `gold sovereign` and sovereign lines ending with `flying into your hands before they can reach the ground.`",
      "Room gold is get-confirm-put; direct-to-hands gold skips get. Packing and attacks remain separate queued effects.",
      "If a replayed pack command times out, boop releases its holds into a nonblocking quarantine. Prompts do not replay it: the first ready prompt, following result prompt, bounded grace, and a newer complete inventory list must finish before a later safe gold opportunity can pack once.",
      "`merge` is the normal Foxhunt import mode. Use `dryrun` first if you want counts without changing boop lists.",
    },
  },
  {
    key = "party",
    title = "Party & Leader",
    summary = "Follow a leader, call targets for others, coordinate walking, and inspect party combo data.",
    aliases = { "party", "leader", "assist", "targetcall", "leadercall", "walk", "roster", "combos", "combo" },
    steps = {
      helpCommand("boop party", "Open the party dashboard and inspect current mode, leader, target gate, walker state, roster, and whitelist sync."),
      helpCommand("boop preset party", "Use this for grouped hunting where everyone chooses their own targets."),
      helpCommand("boop assist <leader>", "Set the leader name before enabling assist or leader-call mode."),
      helpCommand("boop preset leader-call", "Use this when following someone else's called target ids; it requires an assist leader first."),
      helpCommand("boop preset leader", "Use this when you are leading and want boop to party-call each new target you engage."),
      helpCommand("boop roster <class...>", "Save party classes so combo and conditional help can reason about the group."),
    },
    commands = {
      helpCommand("boop preset party", "Apply the default party baseline without leader gating."),
      helpCommand("boop preset leader", "Apply the leader baseline; boop will automatically party-call each new target it engages."),
      helpCommand("boop preset leader-call", "Apply the leader-call baseline; requires an assist leader to already be set."),
      helpCommand("boop mode solo|assist|leader|leader-call", "Switch between solo hunting, assist mode, leader auto-calling, and leader-following target mode."),
      helpCommand("boop assist <leader>", "Set the assist leader boop should follow for assist-mode attacks."),
      helpCommand("boop assist on|off|clear", "Enable, disable, or clear assist mode without changing other party settings."),
      helpCommand("boop targetcall on|off", "Require a leader-called target before boop starts attacking when following another leader."),
      helpCommand("boop party size <n>", "Set the session-local party size used by stats and party summaries."),
      helpCommand("boop affcalls on|off", "Enable or suppress battlerage affliction party callouts."),
      helpCommand("boop walk [status|start|stop|move]", "Inspect or control external autowalker integration when the walker package is available."),
      helpCommand("boop walk install", "Install the optional demonnicAutoWalker package required only for autowalk."),
      helpCommand("boop roster", "Show the stored party roster and your combo-relevant party composition."),
      helpCommand("boop roster <class...>", "Set the party roster classes used for combo and conditional help."),
      helpCommand("boop roster clear", "Clear the stored party roster."),
      helpCommand("boop combos", "Show combo/conditional information using your current roster and class."),
      helpCommand("boop combos <class...>", "Inspect combo and conditional relationships for an explicit set of classes."),
    },
    advanced = {
      helpCommand("boop combos list", "List known class names supported by the combo helper."),
      helpCommand("boop whitelist share [area]", "Share your current or named whitelist area to party chat."),
      helpCommand("boop whitelist receive [merge|merge-reorder|overwrite|reject]", "Review or apply the latest incoming whitelist share."),
    },
    notes = {
      "`assist` prefixes attacks with assist. `leader-call` also waits for the leader's called target id in the current room.",
      "`leader` mode makes boop party-call each new target you engage.",
      "Movement requires current Room.Info plus a complete current room item list; prompts and timers never settle the room.",
      "Walk stop ends a boop-owned run or detaches from an externally owned run.",
      "Walker install is explicit; status, start, move, and package-loss paths never install or update it.",
      "Use quotes for multi-word class names when setting a roster.",
    },
  },
  {
    key = "stats",
    title = "Stats & Optimization",
    summary = "Use trip, session, area, target, ability, crit, and rage data to compare hunts and tune choices.",
    aliases = { "stats", "trip", "records", "areas", "mobs", "targets", "abilities", "crits", "compare" },
    steps = {
      helpCommand("boop trip start", "Start a tracked hunt before you turn boop on."),
      helpCommand("boop stats", "Open the stats dashboard and use the suggested drill-downs for the current data state."),
      helpCommand("boop stats areas trip 10 xphr", "Find which areas produced the best trip XP rate."),
      helpCommand("boop stats targets trip 10", "Find which targets were efficient, slow, or unusually profitable."),
      helpCommand("boop trip stop", "Finish the tracked hunt and save it as lasttrip."),
      helpCommand("boop stats compare", "Compare the current trip with the previous completed trip."),
    },
    commands = {
      helpCommand("boop stats help", "Show the dedicated stats command overview."),
      helpCommand("boop stats session|login|trip|lifetime", "Show totals and efficiency for a specific stats scope."),
      helpCommand("boop stats lasttrip", "Show the snapshot of the most recently completed trip."),
      helpCommand("boop stats compare", "Compare trip versus lasttrip."),
      helpCommand("boop stats compare <left> <right>", "Compare two explicit scopes such as `session lifetime`."),
      helpCommand("boop stats areas [scope] [limit]", "Rank hunting areas by the default kills-per-hour metric."),
      helpCommand("boop stats mobs [area] [limit]", "Inspect learned mob XP values for an area."),
      helpCommand("boop stats targets [scope] [limit]", "Inspect per-target kill efficiency and profitability."),
      helpCommand("boop stats abilities [scope] [limit]", "Inspect per-ability usage, damage, crits, and kills."),
      helpCommand("boop stats crits [scope]", "Show crit distributions and crit-rate summaries."),
      helpCommand("boop stats rage [scope]", "Show rage-usage and rage-mode behavior summaries."),
      helpCommand("boop stats records [scope]", "Show best-hit, fastest-kill, and similar record values."),
      helpCommand("boop trip stop", "Stop the current trip and show its final summary."),
    },
    advanced = {
      helpCommand("boop stats areas <scope> <limit> <metric>", "Rank areas by `gold`, `xp`, `goldhr`, `xphr`, `ttk`, or default `killshr`."),
      helpCommand("boop stats reset session|login|trip|lifetime|all", "Reset one or more stats scopes."),
      helpCommand("boop stats show <scope>", "Show the named totals scope through the explicit `show` route."),
    },
    notes = {
      "`session` is the current enabled run, `login` covers this Mudlet login, `trip` is explicit, and `lifetime` is persisted.",
      "`lasttrip` exists only after a trip has been stopped.",
      "Use `compare`, `areas`, `targets`, and `abilities` when you want to choose a better hunting setup instead of just reading totals.",
    },
  },
  {
    key = "diagnostics",
    title = "Troubleshooting & Advanced",
    summary = "Find out why boop made a decision, inspect state, adjust gagging, or use raw config tools.",
    aliases = { "diagnostics", "debug", "trace", "perf", "gag", "advanced", "set", "get" },
    steps = {
      helpCommand("boop config debug", "Open guided diagnostics controls for trace logging, snapshots, and gag palettes."),
      helpCommand("boop trace on", "Enable persisted collection of recent decisions, commands, and GMCP events before reproducing the problem."),
      helpCommand("boop trace live on", "Stream lifecycle and changed entries for this session; unchanged routine fingerprints collapse only in live output and collection must already be enabled."),
      helpCommand("boop trace show", "Review recent decisions after the problem happens."),
      helpCommand("boop perf on", "Start session-local timing and fixed-counter collection before reproducing a slowdown."),
      helpCommand("boop perf show", "Review prompt, tick, handler, planning, dispatch, and persistence measurements without enabling trace."),
      helpCommand("boop debug", "Show a current runtime-state snapshot with computed status, active operations, target, class, balances, rage, and trace count."),
      helpCommand("boop debug attacks", "Check which profile, standard attacks, rage options, and preferences are currently loaded."),
    },
    commands = {
      helpCommand("boop debug", "Show the debug snapshot for current runtime state, including every active operation and its waits-for state."),
      helpCommand("boop debug attacks", "Show the currently loaded attack profile and attack options."),
      helpCommand("boop debug skills", "Show current skill knowledge and skill-state summaries."),
      helpCommand("boop debug skills dump", "Dump the raw skill tables boop is using."),
      helpCommand("boop trace on|off|show [n]|clear", "Control persisted trace collection, inspect the bounded buffer, or clear its retained entries."),
      helpCommand("boop trace live on|off", "Toggle session-only live streaming without changing retained trace collection; repeated routine fingerprints are live-collapsed."),
      helpCommand("boop perf on|off|show|reset", "Control session-local bounded performance measurements; package reload always resets collection off."),
      helpCommand("boop gag on|off|own|others|mobs|all", "Control attack-line and known mob damage gagging behavior."),
      helpCommand("boop gag colors [own|others|mobs]", "Open the interactive gag palette browser for your own, other-player, or mob gag lines."),
      helpCommand("boop gag color [own|others|mobs] <who|ability|target|meta|separator|bg> <color|off>", "Set one gag color role directly."),
      helpCommand("boop gag color [own|others|mobs] <role>", "Open the picker for one gag color role."),
    },
    advanced = {
      helpCommand("boop get", "List raw config values."),
      helpCommand("boop get <key>", "Inspect one raw config value after alias resolution."),
      helpCommand("boop set <key> <value>", "Set a raw config value directly when there is no better guided control for it yet."),
      helpCommand("boop help audit", "Dump every help topic, alias, command, and note into a review-friendly audit view."),
    },
    notes = {
      "Use trace when you need decision-flow history; use status/debug for computed readiness and active operation state.",
      "Operation enter/exit plus exact interrupt success, failure, and timeout terminals always render live once per accepted producer event, before prompt gag summaries flush.",
      "The retained 100-entry buffer keeps every accepted routine event; only unchanged `target_lost`, `room_partial`, and no-target fingerprints collapse from the live stream, while changed state and unexpected denial/authority failures stay visible.",
      "Use `boop debug skills` when an expected attack is missing and `boop debug attacks` when the wrong attack profile or preference is suspected.",
      "Raw `boop get` / `boop set` access is for gaps in the guided UI and for troubleshooting.",
    },
  },
}

boop.registry.ui.screens = boop.registry.ui.screens or {}
boop.registry.ui.screens.configSections = boop.registry.ui.screens.configSections or {
    { id = 1, key = "combat", label = "Hunting", aliases = { "combat", "hunting", "queueing", "queue" } },
    { id = 2, key = "targeting", label = "Targeting", aliases = { "targeting", "targets" } },
    { id = 3, key = "loot", label = "Loot", aliases = { "loot", "gold", "import" } },
    { id = 4, key = "debug", label = "Diagnostics", aliases = { "debug", "diagnostics", "trace", "gag" } },
}
boop.registry.ui.screens.configHomeRoutes = boop.registry.ui.screens.configHomeRoutes or {
    ["5"] = "party",
    party = "party",
    assist = "party",
    leader = "party",
    ["6"] = "roster",
    roster = "roster",
    ["7"] = "theme",
    theme = "theme",
    appearance = "theme",
    ["8"] = "control",
    control = "control",
    ["9"] = "stats",
    stats = "stats",
    mode = "mode",
}

local function toggleShieldModeAction()
  boop.ui.shieldModeCommand("toggle")
  return "refresh"
end

boop.registry.ui.screens.configActions = boop.registry.ui.screens.configActions or {
    combat = {
      [1] = function()
        boop.ui.setEnabled(not boop.config.enabled, true)
        return "refresh"
      end,
      [2] = function(ctx)
        ctx.rememberReturn("combat")
        boop.ui.showRageModeMenu()
        return "handled"
      end,
      [3] = function()
        boop.ui.diag()
        return "refresh"
      end,
      [4] = function()
        boop.ui.toggleConfigBool("useQueueing", true)
        return "refresh"
      end,
      [5] = function()
        boop.ui.setPrequeueEnabled(not boop.config.prequeueEnabled)
        return "refresh"
      end,
      [6] = function(ctx)
        ctx.seed("combat", "boop lead ")
        return "seed"
      end,
      [7] = function(ctx)
        ctx.seed("combat", "boop set diagtimeout ")
        return "seed"
      end,
      [8] = function(ctx)
        ctx.seed("combat", "boop set tempoRageWindowSeconds ")
        return "seed"
      end,
      [9] = function(ctx)
        ctx.seed("combat", "boop set tempoSqueezeEtaSeconds ")
        return "seed"
      end,
      [10] = function(ctx)
        ctx.seed("combat", "boop assist ")
        return "seed"
      end,
      [11] = function()
        boop.ui.toggleConfigBool("rageAffCalloutsEnabled", true)
        return "refresh"
      end,
      [12] = function()
        boop.ui.toggleConfigBool("pullRageReserve", true)
        return "refresh"
      end,
      [13] = toggleShieldModeAction,
      [14] = function()
        boop.ui.fleeCommand((boop.config and boop.config.fleeEnabled) and "off" or "on")
        return "refresh"
      end,
      [15] = function(ctx)
        ctx.seed("combat", "boop flee ")
        return "seed"
      end,
      [16] = function(ctx)
        ctx.seed("combat", "boop focus ")
        return "seed"
      end,
      [17] = function(ctx)
        ctx.seed("combat", "boop separator ")
        return "seed"
      end,
      [18] = function(ctx)
        ctx.seed("combat", "boop ragepool ")
        return "seed"
      end,
      [19] = function()
        boop.ui.fleeCommand("keepenabled toggle")
        return "refresh"
      end,
    },
    targeting = {
      [1] = function()
        boop.ui.cycleTargetingMode(1, true)
        return "refresh"
      end,
      [2] = function()
        boop.ui.toggleConfigBool("whitelistPriorityOrder", true)
        return "refresh"
      end,
      [3] = function()
        boop.ui.cycleTargetOrder(1, true)
        return "refresh"
      end,
      [4] = function()
        boop.ui.toggleConfigBool("retargetOnPriority", true)
        return "refresh"
      end,
      [5] = function()
        boop.ui.targetCallCommand(boop.config.targetCall and "off" or "on")
        return "refresh"
      end,
      [6] = function()
        boop.targets.displayWhitelist()
        return "handled"
      end,
      [7] = function()
        boop.targets.displayWhitelistBrowse()
        return "handled"
      end,
      [8] = function()
        boop.targets.displayBlacklist()
        return "handled"
      end,
    },
    loot = {
      [1] = function()
        boop.ui.toggleAutoGrabGold()
        return "refresh"
      end,
      [2] = function(ctx)
        ctx.seed("loot", "boop pack ")
        return "seed"
      end,
      [3] = function()
        boop.ui.setGoldPack("")
        return "refresh"
      end,
      [4] = function()
        boop.ui.testGoldPack()
        return "refresh"
      end,
    },
    debug = {
      [1] = function()
        boop.ui.setTraceEnabled(not boop.config.traceEnabled)
        return "refresh"
      end,
      [2] = function()
        boop.ui.debug()
        return "handled"
      end,
      [3] = function()
        if boop.trace and boop.trace.show then
          boop.trace.show()
        else
          boop.util.echo("trace unavailable")
        end
        return "handled"
      end,
      [4] = function()
        if boop.trace and boop.trace.clear then
          boop.trace.clear()
        else
          boop.util.echo("trace unavailable")
        end
        return "refresh"
      end,
      [5] = function()
        boop.gag.setOwn(not boop.config.gagOwnAttacks)
        return "refresh"
      end,
      [6] = function()
        boop.gag.setOthers(not boop.config.gagOthersAttacks)
        return "refresh"
      end,
      [7] = function()
        boop.gag.setMobs(not boop.config.gagMobAttacks)
        return "refresh"
      end,
      [8] = function(ctx)
        ctx.rememberReturn("debug")
        boop.gag.showColors("own")
        return "handled"
      end,
      [9] = function(ctx)
        ctx.rememberReturn("debug")
        boop.gag.showColors("others")
        return "handled"
      end,
      [10] = function(ctx)
        ctx.rememberReturn("debug")
        boop.gag.showColors("mobs")
        return "handled"
      end,
    },
}

boop.registry.ui.screens.configActions.combat[13] = toggleShieldModeAction
boop.registry.ui.screens.configActions.combat[18] = function(ctx)
  ctx.seed("combat", "boop ragepool ")
  return "seed"
end

local function attachRegistryFallback(target, public)
  if type(target) ~= "table" or type(public) ~= "table" then
    return
  end

  local meta = getmetatable(target) or {}
  meta.__boopRegistryFallback = meta.__boopRegistryFallback or {}
  for key, value in pairs(public) do
    meta.__boopRegistryFallback[key] = value
  end

  if meta.__boopRegistryFallbackInstalled then
    setmetatable(target, meta)
    return
  end

  local previous = meta.__index
  meta.__boopRegistryPreviousIndex = previous
  meta.__boopRegistryFallbackInstalled = true
  meta.__index = function(self, key)
    local registryMeta = getmetatable(self) or {}
    local value = registryMeta.__boopRegistryFallback and registryMeta.__boopRegistryFallback[key] or nil
    if value ~= nil then
      return value
    end
    local previousIndex = registryMeta.__boopRegistryPreviousIndex
    if type(previousIndex) == "function" then
      return previousIndex(self, key)
    end
    if type(previousIndex) == "table" then
      return previousIndex[key]
    end
    return nil
  end

  setmetatable(target, meta)
end

boop.registry.attachUiConfigRegistries = function()
  boop.registry.config = boop.registry.config or {}
  boop.registry.ui = boop.registry.ui or {}
  boop.registry.ui.screens = boop.registry.ui.screens or {}
  boop.config = boop.config or {}
  boop.ui = boop.ui or {}

  boop.config.schema = boop.registry.config.schema
  boop.config.setters = boop.registry.config.setters
  boop.ui.modes = boop.registry.ui.modes
  boop.ui.presets = boop.registry.ui.presets
  boop.ui.helpTopics = boop.registry.ui.helpTopics
  local publicScreens = rawget(boop.ui, "screens")
  if type(publicScreens) ~= "table" or publicScreens == boop.registry.ui.screens then
    publicScreens = {}
    boop.ui.screens = publicScreens
  end
  boop.ui.screens.configSections = boop.registry.ui.screens.configSections
  boop.ui.screens.configHomeRoutes = boop.registry.ui.screens.configHomeRoutes
  boop.ui.screens.configActions = boop.registry.ui.screens.configActions

  attachRegistryFallback(boop.config, {
    schema = boop.registry.config.schema,
    setters = boop.registry.config.setters,
  })
  attachRegistryFallback(boop.ui, {
    modes = boop.registry.ui.modes,
    presets = boop.registry.ui.presets,
    helpTopics = boop.registry.ui.helpTopics,
    screens = boop.registry.ui.screens,
  })
  attachRegistryFallback(boop.ui.screens, {
    configSections = boop.registry.ui.screens.configSections,
    configHomeRoutes = boop.registry.ui.screens.configHomeRoutes,
    configActions = boop.registry.ui.screens.configActions,
  })
end

boop.registry.attachUiConfigRegistries()
