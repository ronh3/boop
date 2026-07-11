boop.safety = boop.safety or {}

function boop.safety.parseThreshold(value)
  if type(value) == "string" and value:find("%%") then
    local pct = tonumber(value:match("(%d+)") or "0")
    if gmcp and gmcp.Char and gmcp.Char.Vitals and gmcp.Char.Vitals.maxhp then
      return pct * gmcp.Char.Vitals.maxhp / 100
    end
    return pct
  end
  return tonumber(value) or 0
end

function boop.safety.shouldFlee()
  if not boop.config.enabled or not boop.config.fleeEnabled or not boop.config.fleeAt then return false end
  if not gmcp or not gmcp.Char or not gmcp.Char.Vitals then return false end

  local hp = tonumber(gmcp.Char.Vitals.hp) or 0
  local threshold = boop.safety.parseThreshold(boop.config.fleeAt)
  return hp > 0 and hp <= threshold
end

function boop.safety.flee()
  local state = boop.runtime.ensureState()
  boop.runtime.clearAutomationIntent("flee", {
    includeWalk = true,
    includeGold = true,
    includeAttack = true,
  })
  boop.config.enabled = false
  if boop.clearGoldQueueIntent then
    boop.clearGoldQueueIntent()
  end
  if boop.ih and boop.ih.stop then
    boop.ih.stop()
  end
  if boop.gag and boop.gag.clearPending then
    boop.gag.clearPending()
  end
  if boop.triggers and boop.triggers.syncEnabled then
    boop.triggers.syncEnabled()
  end
  if boop.stats and boop.stats.onEnabledChanged then
    boop.stats.onEnabledChanged(false)
  end
  if boop.db and boop.db.saveConfig then
    boop.db.saveConfig("enabled", boop.config.enabled)
  end

  local dir = state.targeting.lastRoomDir
  if not dir or dir == "" then
    boop.util.warn("No flee direction set.")
    return
  end

  local action = "wake/wake/apply mending to legs/stand/" .. dir
  boop.executeAction(action)
  boop.util.ok("fleeing " .. dir .. " (boop disabled)")
  state.combat.fleeing = true
  if boop.stats and boop.stats.onFlee then
    boop.stats.onFlee()
  end
  tempTimer(2, function() state.combat.fleeing = false end)
end
