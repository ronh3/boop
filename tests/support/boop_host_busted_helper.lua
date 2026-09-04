local repoRoot = assert(
  os.getenv("BOOP_REPO_ROOT"),
  "BOOP_REPO_ROOT env var is required"
)

echo = function(_) end
cecho = nil
getEpoch = function()
  return 0
end
killTimer = function(_)
  return false
end
raiseEvent = function(_, ...) end
send = function(_, _) end
sendGMCP = function(_) end
tempTimer = function(_, _)
  return 0
end

local function loadBoop(relativePath)
  return dofile(
    repoRoot .. "/src/scripts/boop/" .. relativePath
  )
end

loadBoop("boop_init.lua")
loadBoop("boop_util.lua")
loadBoop("boop_perf.lua")
loadBoop("boop_theme.lua")
loadBoop("boop_render.lua")
loadBoop("boop_skills.lua")
loadBoop("boop_db.lua")
loadBoop("boop_runtime.lua")
loadBoop("boop_wire.lua")
loadBoop("boop_afflictions.lua")
loadBoop("boop_rage.lua")
loadBoop("boop_ih.lua")
loadBoop("boop_targets.lua")
loadBoop("boop_gag.lua")
loadBoop("boop_attacks.lua")
loadBoop("attacks/attack_profile_bootstrap.lua")
loadBoop("attacks/occultist.lua")
loadBoop("boop_safety.lua")
loadBoop("boop_stats.lua")
loadBoop("boop_walk.lua")
loadBoop("boop_combat.lua")
loadBoop("boop_ui_registry.lua")
loadBoop("boop_ui.lua")
loadBoop("boop_events.lua")
loadBoop("boop_bootstrap.lua")
