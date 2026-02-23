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

local function normName(value)
  return boop.util.safeLower(boop.util.trim(value or ""))
end

local function decodeIgnoredPlayers()
  local raw = boop.config.ignoredPlayers or ""
  local list = {}
  local seen = {}
  for _, part in ipairs(boop.util.split(raw, "/")) do
    local name = boop.util.trim(part)
    local key = normName(name)
    if key ~= "" and not seen[key] then
      seen[key] = true
      list[#list + 1] = name
    end
  end
  table.sort(list, function(a, b) return normName(a) < normName(b) end)
  return list, seen
end

local function refreshPlayerSafety()
  if boop.events and boop.events.refreshPlayerSafety then
    boop.events.refreshPlayerSafety()
  end
end

function boop.ui.getIgnoredPlayers()
  local list = decodeIgnoredPlayers()
  return list
end

function boop.ui.isIgnoredPlayer(name)
  local key = normName(name)
  if key == "" then return false end
  local _, seen = decodeIgnoredPlayers()
  return seen[key] == true
end

function boop.ui.displayIgnoredPlayers()
  local list = decodeIgnoredPlayers()
  boop.util.echo("Ignored player whitelist:")
  if #list == 0 then
    boop.util.echo("  (empty)")
    boop.util.echo("  add: boop players add <name>")
    return
  end
  for i, name in ipairs(list) do
    boop.util.echo("  " .. i .. ". " .. name)
  end
end

function boop.ui.addIgnoredPlayer(name)
  local raw = boop.util.trim(name or "")
  local key = normName(raw)
  if key == "" then
    boop.util.echo("Usage: boop players add <name>")
    return
  end

  local list, seen = decodeIgnoredPlayers()
  if seen[key] then
    boop.util.echo("Already in ignored-player whitelist: " .. raw)
    return
  end

  list[#list + 1] = raw
  table.sort(list, function(a, b) return normName(a) < normName(b) end)
  saveConfigValue("ignoredPlayers", table.concat(list, "/"))
  refreshPlayerSafety()
end

function boop.ui.removeIgnoredPlayer(name)
  local key = normName(name)
  if key == "" then
    boop.util.echo("Usage: boop players remove <name>")
    return
  end

  local list = decodeIgnoredPlayers()
  local out = {}
  local removed = false
  for _, item in ipairs(list) do
    if normName(item) == key then
      removed = true
    else
      out[#out + 1] = item
    end
  end

  if not removed then
    boop.util.echo("Not found in ignored-player whitelist: " .. tostring(name))
    return
  end

  saveConfigValue("ignoredPlayers", table.concat(out, "/"))
  refreshPlayerSafety()
end

function boop.ui.status(context)
  local enabled = boop.config.enabled and "on" or "off"
  local mode = boop.config.targetingMode or "unknown"
  local class = boop.state.class or (gmcp and gmcp.Char and gmcp.Char.Status and gmcp.Char.Status.class) or "unknown"
  local msg = string.format("%s | class: %s | targeting: %s | flee: %s", enabled, class, mode, tostring(boop.config.fleeAt))
  if context then
    msg = context .. " | " .. msg
  end
  boop.util.echo(msg)
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

local function helpTopicLinks()
  local topics = { "targeting", "players", "whitelist", "blacklist", "ragemode", "queueing", "gold", "ih", "aff", "trip", "debug", "config" }
  if cecho and cechoLink then
    cecho("\n<green>boop<reset>: <white>topics: ")
    for _, topic in ipairs(topics) do
      local t = topic
      cechoLink("<cyan>[" .. t .. "]<reset>", function() boop.ui.help(t) end, "Show boop help for " .. t, true)
      cecho(" ")
    end
    return
  end
  boop.util.echo("topics: targeting | players | whitelist | blacklist | ragemode | queueing | gold | ih | aff | trip | debug | config")
end

function boop.ui.help(topic)
  local t = boop.util.safeLower(boop.util.trim(topic or ""))

  if t == "" or t == "main" or t == "general" then
    boop.util.echo("Help: boop command interface")
    boop.util.echo("  Toggle hunting: bh")
    boop.util.echo("  Main controls: boop on | boop off | boop status | boop config")
    boop.util.echo("  Target controls: boop targeting <manual|whitelist|blacklist|auto>")
    boop.util.echo("  Player controls: boop players | boop players add/remove <name>")
    boop.util.echo("  List controls: boop whitelist | boop blacklist")
    boop.util.echo("  Loot controls: boop autogold [on|off]")
    boop.util.echo("  Combat controls: boop ragemode <simple|dam|big|small|aff|cond|buff|pool|none>")
    boop.util.echo("  Other: boop ih | boop aff | boop trip start/stop | boop debug")
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

  if t == "players" or t == "player" then
    boop.util.echo("Help: players")
    boop.util.echo("  boop players")
    boop.util.echo("  boop players add <name>")
    boop.util.echo("  boop players remove <name>")
    boop.util.echo("Notes:")
    boop.util.echo("  This is an ignored-player whitelist used when ignoreOtherPlayers is OFF.")
    boop.util.echo("  Whitelisted players will not pause hunting when present in room.")
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
    boop.util.echo("When ON: standard attacks are queued via BOOP_ATTACK alias.")
    boop.util.echo("Optimization: boop skips redundant setalias when action is unchanged.")
    boop.util.echo("Rage actions are still sent directly.")
    return
  end

  if t == "gold" or t == "autogold" or t == "loot" then
    boop.util.echo("Help: auto gold pickup")
    boop.util.echo("  boop autogold")
    boop.util.echo("  boop autogold on")
    boop.util.echo("  boop autogold off")
    boop.util.echo("When enabled, boop auto-picks up newly dropped gold sovereign items in room.")
    boop.util.echo("In queueing mode, this is prepended to the next standard attack as: get sovereigns/<attack>.")
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
    boop.util.echo("whitelist priority order, ignore other players, and target order.")
    boop.util.echo("Includes quick links into whitelist/blacklist managers.")
    return
  end

  boop.util.echo("Unknown help topic: " .. tostring(topic))
  boop.util.echo("Use: boop help topics")
  helpTopicLinks()
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
  local class = boop.state.class or (gmcp and gmcp.Char and gmcp.Char.Status and gmcp.Char.Status.class) or "unknown"

  if cecho and cechoLink then
    cecho("\n<green>boop<reset>: <yellow>Configuration")
    cecho("\n<white>  class: <cyan>" .. tostring(class) .. "<reset>")

    cecho("\n<white>  enabled: ")
    cechoLink("<" .. boolColor(boop.config.enabled) .. ">[" .. boolText(boop.config.enabled) .. "]<reset>",
      function() boop.ui.setEnabled(not boop.config.enabled, true); boop.ui.config() end,
      "Toggle boop on/off", true
    )

    cecho("\n<white>  targeting: ")
    local targetingModes = { "manual", "whitelist", "blacklist", "auto" }
    for _, mode in ipairs(targetingModes) do
      local modeName = mode
      local active = boop.config.targetingMode == modeName
      local modeColor = active and "green" or "grey"
      cechoLink("<" .. modeColor .. ">[" .. modeName .. "]<reset>",
        function() boop.ui.setTargetingMode(modeName, true); boop.ui.config() end,
        "Set targeting mode to " .. modeName, true
      )
      cecho(" ")
    end

    cecho("\n<white>  whitelist priority order: ")
    cechoLink("<" .. boolColor(boop.config.whitelistPriorityOrder) .. ">[" .. boolText(boop.config.whitelistPriorityOrder) .. "]<reset>",
      function() boop.ui.toggleConfigBool("whitelistPriorityOrder") end,
      "Toggle whitelist order priority", true
    )

    cecho("\n<white>  ignore other players: ")
    cechoLink("<" .. boolColor(not not boop.config.ignoreOtherPlayers) .. ">[" .. boolText(not not boop.config.ignoreOtherPlayers) .. "]<reset>",
      function() boop.ui.toggleConfigBool("ignoreOtherPlayers") end,
      "Toggle ignoring other players in room", true
    )

    local ignoredPlayers = boop.ui.getIgnoredPlayers()
    cecho("\n<white>  ignored-player whitelist: <cyan>" .. tostring(#ignoredPlayers) .. "<reset> ")
    cechoLink("<yellow>[show]<reset>",
      function() boop.ui.displayIgnoredPlayers() end,
      "Show ignored-player whitelist", true
    )
    if appendCmdLine then
      cecho(" ")
      cechoLink("<yellow>[add]<reset>",
        function()
          if clearCmdLine then clearCmdLine() end
          appendCmdLine("boop players add ")
        end,
        "Fill command line with boop players add", true
      )
    end

    cecho("\n<white>  use queueing: ")
    cechoLink("<" .. boolColor(not not boop.config.useQueueing) .. ">[" .. boolText(not not boop.config.useQueueing) .. "]<reset>",
      function() boop.ui.toggleConfigBool("useQueueing") end,
      "Toggle queueing mode", true
    )

    cecho("\n<white>  auto grab gold: ")
    cechoLink("<" .. boolColor(not not boop.config.autoGrabGold) .. ">[" .. boolText(not not boop.config.autoGrabGold) .. "]<reset>",
      function() boop.ui.toggleAutoGrabGold(); boop.ui.config() end,
      "Toggle auto pickup of dropped gold", true
    )

    cecho("\n<white>  target order: ")
    local targetOrders = { "order", "numeric", "reverse" }
    for _, order in ipairs(targetOrders) do
      local orderName = order
      local active = boop.config.targetOrder == orderName
      local orderColor = active and "green" or "grey"
      cechoLink("<" .. orderColor .. ">[" .. orderName .. "]<reset>",
        function() saveConfigValue("targetOrder", orderName); boop.ui.config() end,
        "Set target order to " .. orderName, true
      )
      cecho(" ")
    end

    cecho("\n<white>  rage mode: <cyan>" .. tostring(boop.config.attackMode or "simple") .. "<reset> ")
    if appendCmdLine then
      cechoLink("<yellow>[set]<reset>",
        function()
          if clearCmdLine then
            clearCmdLine()
          end
          appendCmdLine("boop ragemode ")
        end,
        "Fill command line with boop ragemode", true
      )
    end

    cecho("\n<white>  quick lists: ")
    cechoLink("<cyan>[whitelist]<reset>", function() boop.targets.displayWhitelist() end, "Show whitelist manager", true)
    cecho(" ")
    cechoLink("<cyan>[blacklist]<reset>", function() boop.targets.displayBlacklist() end, "Show blacklist manager", true)
    cecho("\n<white>  quick commands: boop status | boop debug | boop trip start/stop")
    return
  end

  boop.util.echo("Config for " .. tostring(class) .. ":")
  boop.util.echo("  enabled: " .. tostring(boop.config.enabled))
  boop.util.echo("  targeting: " .. tostring(boop.config.targetingMode))
  boop.util.echo("  whitelistPriorityOrder: " .. tostring(boop.config.whitelistPriorityOrder))
  boop.util.echo("  ignoreOtherPlayers: " .. tostring(boop.config.ignoreOtherPlayers))
  boop.util.echo("  ignoredPlayers: " .. tostring(boop.config.ignoredPlayers or ""))
  boop.util.echo("  useQueueing: " .. tostring(boop.config.useQueueing))
  boop.util.echo("  autoGrabGold: " .. tostring(boop.config.autoGrabGold))
  boop.util.echo("  targetOrder: " .. tostring(boop.config.targetOrder))
  boop.util.echo("  ragemode: " .. tostring(boop.config.attackMode))
end

function boop.ui.debug()
  local enabled = boop.config.enabled and "on" or "off"
  local mode = boop.config.targetingMode or "unknown"
  local denizenCount = boop.state.denizens and #boop.state.denizens or 0
  local currentTargetId = boop.state.currentTargetId or ""
  local currentTargetName = boop.state.targetName or ""
  local ignoreOthers = boop.config.ignoreOtherPlayers and "yes" or "no"
  local newPeople = boop.state.newPeopleInRoom and "yes" or "no"
  local class = boop.state.class or (gmcp and gmcp.Char and gmcp.Char.Status and gmcp.Char.Status.class) or "unknown"
  local eq = gmcp and gmcp.Char and gmcp.Char.Vitals and gmcp.Char.Vitals.eq or "?"
  local bal = gmcp and gmcp.Char and gmcp.Char.Vitals and gmcp.Char.Vitals.bal or "?"
  local rage = boop.attacks and boop.attacks.getRage and boop.attacks.getRage() or 0
  local msg = string.format(
    "enabled:%s | mode:%s | class:%s | eq:%s bal:%s | denizens:%s | target:%s (%s) | rage:%s | ignoreOthers:%s newPeople:%s",
    enabled, mode, class, tostring(eq), tostring(bal),
    tostring(denizenCount), tostring(currentTargetId), tostring(currentTargetName), tostring(rage),
    ignoreOthers, newPeople
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
