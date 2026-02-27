boop.rage = boop.rage or {}

local function keyForAbility(ability)
  local name = ability and (ability.name or ability.skill) or ""
  return boop.util.safeLower(name)
end

function boop.rage.init()
  boop.state.rageReady = boop.state.rageReady or {}
  boop.state.rageTimers = boop.state.rageTimers or {}
end

function boop.rage.setReady(name, ready)
  if not name or name == "" then return end
  local key = boop.util.safeLower(name)
  boop.state.rageReady = boop.state.rageReady or {}
  boop.state.rageReady[key] = ready and true or false
end

function boop.rage.onRageUsed(ability)
  local key = ""
  if type(ability) == "table" then
    key = keyForAbility(ability)
  elseif type(ability) == "string" then
    key = boop.util.safeLower(ability)
  end
  if key == "" then return end

  boop.rage.setReady(key, false)

  local seconds = tonumber(boop.config.rageFallbackSeconds) or 26
  if seconds <= 0 then return end

  local timers = boop.state.rageTimers or {}
  if timers[key] then
    killTimer(timers[key])
  end
  timers[key] = tempTimer(seconds, function()
    boop.rage.setReady(key, true)
    boop.state.rageTimers[key] = nil
  end)
  boop.state.rageTimers = timers
end

function boop.rage.onReadyList(list)
  for _, name in ipairs(list or {}) do
    boop.rage.setReady(name, true)
  end
end

function boop.rage.onHoundMaulUsed()
  boop.rage.setReady("maul", false)
  if boop.trace and boop.trace.log then
    boop.trace.log("hound maul used")
  end
end

function boop.rage.onHoundMaulReady()
  boop.rage.setReady("maul", true)
  if boop.trace and boop.trace.log then
    boop.trace.log("hound maul ready")
  end
end

function boop.rage.onHoundMaulNotReady()
  boop.rage.setReady("maul", false)
  if boop.trace and boop.trace.log then
    boop.trace.log("hound maul not ready")
  end
end
