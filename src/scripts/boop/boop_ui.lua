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

    cecho("\n<white>  use queueing: ")
    cechoLink("<" .. boolColor(not not boop.config.useQueueing) .. ">[" .. boolText(not not boop.config.useQueueing) .. "]<reset>",
      function() boop.ui.toggleConfigBool("useQueueing") end,
      "Toggle queueing mode", true
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
  boop.util.echo("  useQueueing: " .. tostring(boop.config.useQueueing))
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
