boop = boop or {}

boop.version = boop.version or "0.1.269"

boop.defaults = {
  enabled = false,
  targetingMode = "whitelist",
  whitelistPriorityOrder = true,
  retargetOnPriority = true,
  targetOrder = "order",
  targetCall = false,
  useQueueing = false,
  prequeueEnabled = true,
  autoGrabGold = true,
  goldPack = "",
  traceEnabled = false,
  gagOwnAttacks = false,
  gagOthersAttacks = false,
  gagColorWho = "",
  gagColorAbility = "",
  gagColorTarget = "",
  gagColorMeta = "",
  gagColorSeparator = "",
  gagColorBackground = "",
  gagOtherColorWho = "",
  gagOtherColorAbility = "",
  gagOtherColorTarget = "",
  gagOtherColorMeta = "",
  gagOtherColorSeparator = "",
  gagOtherColorBackground = "",
  attackMode = "simple",
  pullRageReserve = false,
  fleeEnabled = true,
  fleeAt = "30%",
  rageFallbackSeconds = 26,
  tempoRageWindowSeconds = 10,
  tempoSqueezeEtaSeconds = 2.5,
  attackLeadSeconds = 1,
  diagTimeoutSeconds = 8,
  partySize = 1,
  partyRoster = "",
  rageAffCalloutsEnabled = true,
  assistEnabled = false,
  assistLeader = "",
  autoTargetCall = false,
  uiTheme = "",
  gameSeparator = "|",
  focusVerb = "speed",
}

boop.config = boop.config or {}
boop.lists = boop.lists or {}
boop.lists.whitelist = boop.lists.whitelist or {}
boop.lists.blacklist = boop.lists.blacklist or {}
boop.lists.globalBlacklist = boop.lists.globalBlacklist or {}
boop.lists.whitelistTags = boop.lists.whitelistTags or {}
boop.lists.separator = boop.lists.separator or "/"
boop.handlers = boop.handlers or {}

boop.bootstrap = boop.bootstrap or function()
  if boop.bootstrapped then return end
  boop.bootstrapped = true

  if sendGMCP then
    sendGMCP('Core.Supports.Add ["IRE.Target 1"]')
    sendGMCP('Core.Supports.Add ["IRE.Display 3"]')
    sendGMCP('Core.Supports.Add ["Char.Skills 1"]')
  end

  if boop.db and boop.db.init then
    boop.db.init()
  end

  if boop.state and boop.state.init then
    boop.state.init()
  end

  if boop.afflictions and boop.afflictions.init then
    boop.afflictions.init()
  end

  if boop.rage and boop.rage.init then
    boop.rage.init()
  end

  if boop.ih and boop.ih.init then
    boop.ih.init()
  end

  if boop.skills and boop.skills.init then
    boop.skills.init()
    boop.skills.desiredGroups = boop.skills.desiredGroups or {
      "Artificing",
      "Elementalism",
      "Occultism",
      "Domination",
      "Attainment",
    }
  end

  if boop.stats and boop.stats.init then
    boop.stats.init()
  end

  if boop.events and boop.events.register then
    boop.events.register()
  end

  if boop.skills and boop.skills.requestAll then
    boop.skills.requestAll()
  end

  if boop.ui and boop.ui.status then
    boop.ui.status("ready")
  end
end
