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
    "pullRageReserve",
    "fleeEnabled",
    "fleeAt",
    "tempoRageWindowSeconds",
    "tempoSqueezeEtaSeconds",
    "focusVerb",
    "traceEnabled",
    "gagOwnAttacks",
    "gagOthersAttacks",
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
    gagothercolorwho = "gagOtherColorWho",
    gagothercolorability = "gagOtherColorAbility",
    gagothercolortarget = "gagOtherColorTarget",
    gagothercolormeta = "gagOtherColorMeta",
    gagothercolorseparator = "gagOtherColorSeparator",
    gagothercolorbg = "gagOtherColorBackground",
    gagothercolorbackground = "gagOtherColorBackground",
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
    flee = "fleeEnabled",
    fleeenabled = "fleeEnabled",
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
  pullRageReserve = configBoolSetter({
    key = "pullRageReserve",
    warn = "pullRageReserve expects on/off",
    okLabel = "pull rage reserve",
    reopen = { screen = "combat" },
  }),
  fleeEnabled = configBoolSetter({
    key = "fleeEnabled",
    warn = "flee expects on/off",
    apply = function(parsed)
      boop.ui.fleeCommand(parsed and "on" or "off")
    end,
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

local function helpCommand(command, description)
  return {
    command = tostring(command or ""),
    description = tostring(description or ""),
  }
end

boop.registry.ui.helpTopics = boop.registry.ui.helpTopics or {
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
      helpCommand("boop config combat", "Open combat and queueing settings."),
      helpCommand("boop config targeting", "Open targeting mode, order, and list-management settings."),
      helpCommand("boop config loot", "Open sovereign pickup and gold-pack settings."),
      helpCommand("boop config debug", "Open trace, gag, and debug settings."),
      helpCommand("boop preset <solo|party|leader|leader-call>", "Apply a curated baseline without stepping through each individual setting."),
    },
    notes = {
      "Use `boop control` for live state and `boop config` for guided settings changes.",
      "Use `boop config debug` when you need lower-level tools that do not fit the normal guided settings flow.",
    },
  },
  {
    key = "hunting",
    title = "Hunting & Targeting",
    summary = "Targeting modes, rage modes, queueing, and target list management.",
    aliases = { "hunting", "combat", "targeting", "targets", "whitelist", "blacklist", "rage", "ragemode", "attackmode", "queue", "queueing", "prequeue", "diag", "diagnose", "ih" },
    commands = {
      helpCommand("boop config combat", "Open the combat settings screen for toggles like queueing, prequeue, and rage mode."),
      helpCommand("boop config targeting", "Open the targeting settings screen for mode, order, and retarget behavior."),
      helpCommand("boop ragemode", "Show the rage-mode menu and current selection."),
      helpCommand("boop ragemode <simple|big|small|aff|tempo|combo|hybrid|none>", "Set how boop chooses battlerage attacks."),
      helpCommand("boop prequeue [on|off]", "Enable or disable standard-attack prequeueing."),
      helpCommand("boop lead <seconds>", "Set how early boop should prequeue before balance comes back."),
      helpCommand("boop targeting <manual|whitelist|blacklist|auto>", "Set the top-level target-selection mode."),
      helpCommand("boop whitelist", "Open or print the current area whitelist."),
      helpCommand("boop whitelist browse [tag]", "Browse whitelist entries, optionally filtered by tag."),
      helpCommand("boop whitelist share [area]", "Share an area's whitelist to party chat (`pt`) as a structured boop packet."),
      helpCommand("boop whitelist receive [merge|merge-reorder|overwrite|reject]", "Review or apply the latest incoming whitelist share for one area."),
      helpCommand("boop blacklist", "Open or print the current area blacklist."),
      helpCommand("diag", "Queue diagnose and temporarily pause attacking until diagnose completes or times out."),
      helpCommand("matic", "Queue `ldeck draw matic` on the attack queue and pause attacking until the next prompt or timeout."),
      helpCommand("catarin", "Queue `ldeck draw catarin` on the attack queue and pause attacking until the next prompt or timeout."),
      helpCommand("fly", "Queue `fly` on the attack queue and pause attacking until the next prompt or timeout."),
      helpCommand("leap <direction>", "Queue `leap <direction>` on the attack queue and pause attacking until the next prompt or timeout."),
      helpCommand("pull <mobname> <direction>", "Send `<direction><sep><damage rage><sep>leap <opposite>` using your configured game separator and the typed mob name as the rage target."),
      helpCommand("boop separator <text>", "Set the game-side command separator used by `pull`, such as `|`."),
      helpCommand("boop focus <speed|precision>", "Choose which battlefury focus verb two-handed standards prepend when Focus is known."),
      helpCommand("boop flee <on|off|toggle|percent>", "Control auto-flee and set its percentage threshold, for example `boop flee 25%`."),
      helpCommand("boop set pullRageReserve on|off", "Advanced toggle to keep enough rage reserved for a pull-capable damage battlerage attack."),
      helpCommand("boop prefer", "Show configurable attack-preference options for your current class/spec."),
      helpCommand("boop prefer <dam|shield> <option>", "Prefer a specific standard damage or shield attack when multiple valid options exist."),
      helpCommand("boop weapon", "Show saved weapon designations for your current class profile."),
      helpCommand("boop weapon <role> <item-id>", "Save a class-scoped weapon designation using a raw GMCP item id such as `scythe 47177`."),
    },
    notes = {
      "Use the config subsections when you want guided toggles; use the direct commands when you already know what you want.",
      "Target list displays support clickable management for whitelist, blacklist, and tags.",
      "Whitelist sharing currently uses party chat only and transfers the ordered mob list, not whitelist tags.",
      "`pull` uses your configured `boop separator` and the typed mob name directly inside the rage command.",
      "Enable pull reserve if you want normal rage usage to keep enough rage banked for `pull`.",
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
      helpCommand("boop whitelist share [area]", "Share your current or named whitelist area to party chat."),
      helpCommand("boop whitelist receive [merge|merge-reorder|overwrite|reject]", "Review or apply the latest incoming whitelist share."),
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
      helpCommand("boop gag colors [own|others]", "Open the interactive gag palette browser for your own or other players' gag lines."),
      helpCommand("boop gag color [own|others] <who|ability|target|meta|separator|bg> <color|off>", "Set one gag color role directly; use `boop gag color [own|others] <role>` to open the picker."),
      helpCommand("boop get", "Inspect raw config values when you need to verify the stored state directly."),
      helpCommand("boop set <key> <value>", "Set a raw config value directly when there is no better guided control for it yet."),
      helpCommand("boop help audit", "Dump every help topic, alias, command, and note into a review-friendly audit view."),
      helpCommand("boop import foxhunt [merge|overwrite|dryrun]", "Import whitelist and blacklist data from Foxhunt."),
      helpCommand("boop pack test", "Queue a look-in command for the current configured gold pack."),
      helpCommand("boop theme <name|auto|list>", "Inspect or change the active UI theme; list includes boop + built-in ADB palette names."),
    },
    notes = {
      "Use trace when you need decision-flow debugging; use the debug snapshot when you need current-state debugging.",
      "This is also the place for lower-level commands that do not fit the main control/config/party/stats flow, including raw `boop get` / `boop set` access.",
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
      [13] = function()
        boop.ui.fleeCommand((boop.config and boop.config.fleeEnabled) and "off" or "on")
        return "refresh"
      end,
      [14] = function(ctx)
        ctx.seed("combat", "boop flee ")
        return "seed"
      end,
      [15] = function(ctx)
        ctx.seed("combat", "boop focus ")
        return "seed"
      end,
      [16] = function(ctx)
        ctx.seed("combat", "boop separator ")
        return "seed"
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
      [7] = function(ctx)
        ctx.rememberReturn("debug")
        boop.gag.showColors("own")
        return "handled"
      end,
      [8] = function(ctx)
        ctx.rememberReturn("debug")
        boop.gag.showColors("others")
        return "handled"
      end,
    },
}

local function attachRegistryFallback(target, public)
  if type(target) ~= "table" or type(public) ~= "table" then
    return
  end

  local meta = getmetatable(target) or {}
  local previous = meta.__index

  if previous == public then
    return
  end

  meta.__index = function(self, key)
    local value = public[key]
    if value ~= nil then
      return value
    end
    if type(previous) == "function" then
      return previous(self, key)
    end
    if type(previous) == "table" then
      return previous[key]
    end
    return nil
  end

  setmetatable(target, meta)
end

boop.registry.attachUiConfigRegistries = boop.registry.attachUiConfigRegistries or function()
  boop.config = boop.config or {}
  boop.ui = boop.ui or {}

  boop.config.schema = boop.config.schema or boop.registry.config.schema
  boop.config.setters = boop.config.setters or boop.registry.config.setters
  boop.ui.modes = boop.ui.modes or boop.registry.ui.modes
  boop.ui.presets = boop.ui.presets or boop.registry.ui.presets
  boop.ui.helpTopics = boop.ui.helpTopics or boop.registry.ui.helpTopics
  boop.ui.screens = boop.ui.screens or {}
  boop.ui.screens.configSections = boop.ui.screens.configSections or boop.registry.ui.screens.configSections
  boop.ui.screens.configHomeRoutes = boop.ui.screens.configHomeRoutes or boop.registry.ui.screens.configHomeRoutes
  boop.ui.screens.configActions = boop.ui.screens.configActions or boop.registry.ui.screens.configActions

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
end

boop.registry.attachUiConfigRegistries()
