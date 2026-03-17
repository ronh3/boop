boop.rage = boop.rage or {}

local function keyForAbility(ability)
  local name = ability and (ability.name or ability.skill) or ""
  return boop.util.safeLower(name)
end

local function nowSeconds()
  if getEpoch then return getEpoch() end
  return os.clock()
end

function boop.rage.init()
  boop.state.rageReady = boop.state.rageReady or {}
  boop.state.rageTimers = boop.state.rageTimers or {}
  boop.state.rageSamples = boop.state.rageSamples or {}
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

function boop.rage.onRageObserved(value)
  local rage = tonumber(value)
  if not rage then return end

  boop.state = boop.state or {}
  boop.state.rageSamples = boop.state.rageSamples or {}
  local samples = boop.state.rageSamples
  local now = nowSeconds()

  if #samples > 0 and math.abs((samples[#samples].t or 0) - now) < 0.05 then
    samples[#samples].r = rage
  else
    samples[#samples + 1] = { t = now, r = rage }
  end

  local cutoff = now - 65
  while #samples > 0 and (samples[1].t or 0) < cutoff do
    table.remove(samples, 1)
  end
end

function boop.rage.getGainRate(windowSeconds)
  local window = tonumber(windowSeconds) or 10
  if window <= 0 then return 0 end

  local samples = boop.state and boop.state.rageSamples or {}
  if not samples or #samples < 2 then return 0 end

  local cutoff = nowSeconds() - window
  local prev = nil
  local firstT = nil
  local lastT = nil
  local gained = 0

  for _, sample in ipairs(samples) do
    local t = tonumber(sample.t) or 0
    local r = tonumber(sample.r) or 0
    if t >= cutoff then
      if not firstT then
        firstT = t
      end
      if prev then
        local delta = r - (tonumber(prev.r) or 0)
        if delta > 0 then
          gained = gained + delta
        end
      end
      lastT = t
    end
    prev = sample
  end

  if not firstT or not lastT then return 0 end
  local elapsed = lastT - firstT
  if elapsed <= 0 then return 0 end
  return gained / elapsed
end

function boop.rage.etaToRage(targetRage, currentRage, windowSeconds)
  local target = tonumber(targetRage)
  local current = tonumber(currentRage)
  if not target or not current then return nil end
  if current >= target then return 0 end

  local rate = boop.rage.getGainRate(windowSeconds or 10)
  if rate <= 0 then return nil end

  return (target - current) / rate
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

function boop.rage.onHyenaMaulUsed()
  boop.rage.setReady("maul", false)
  if boop.trace and boop.trace.log then
    boop.trace.log("hyena maul used")
  end
end

function boop.rage.onHyenaMaulReady()
  boop.rage.setReady("maul", true)
  if boop.trace and boop.trace.log then
    boop.trace.log("hyena maul ready")
  end
end

function boop.rage.onHyenaMaulNotReady()
  boop.rage.setReady("maul", false)
  if boop.trace and boop.trace.log then
    boop.trace.log("hyena maul not ready")
  end
end

local function normalizeEntityName(name)
  if not name then return "" end
  local value = boop.util.trim(tostring(name))
  value = value:gsub("\226\128\152", "'") -- left single quotation mark
  value = value:gsub("\226\128\153", "'") -- right single quotation mark
  return boop.util.safeLower(value)
end

local function sameEntityName(a, b)
  local left = normalizeEntityName(a)
  local right = normalizeEntityName(b)
  if left == "" or right == "" then return false end
  return left == right
end

local function resolveCapture(expr, matchTable)
  if type(expr) ~= "table" then return "" end
  local kind = expr.kind
  if kind == "match" then
    local idx = tonumber(expr.index)
    if not idx or type(matchTable) ~= "table" then return "" end
    return tostring(matchTable[idx] or "")
  end
  if kind == "literal" then
    return tostring(expr.value or "")
  end
  return ""
end

local function shouldTrackTarget(targetName)
  local captured = boop.util.trim(targetName or "")
  if captured == "" then return true end

  boop.state = boop.state or {}
  local current = boop.util.trim(boop.state.targetName or "")
  if current == "" and (boop.state.currentTargetId or "") ~= "" then
    -- Populate when we have an id but no name yet; this avoids dropping early lines.
    boop.state.targetName = captured
    current = captured
  end
  if current == "" then return false end
  return sameEntityName(captured, current)
end

local function sendAffCallout(mode, aff)
  if boop.config and boop.config.rageAffCalloutsEnabled == false then
    return
  end
  local key = boop.util.safeLower(boop.util.trim(aff or ""))
  if key == "stunned" then
    key = "stun"
  end
  if key == "" then return end
  local targetId = boop.util.trim(tostring((boop.state and boop.state.currentTargetId) or ""))
  if targetId == "" then return end

  local text
  if mode == "remove" then
    text = string.format("pt %s: %s down", targetId, key)
  else
    text = string.format("pt %s: %s", targetId, key)
  end
  send(text, false)
  if boop.util and boop.util.info then
    boop.util.info("callout: " .. text)
  end
end

function boop.rage.onAfflictionTrigger(spec, matchTable, _rawLine)
  if type(spec) ~= "table" then return end
  if not boop.afflictions then return end
  if boop.config and boop.config.enabled == false then return end

  local mode = boop.util.safeLower(spec.mode or "")
  local affs = spec.affs or {}
  if type(affs) ~= "table" or #affs == 0 then return end

  local target = resolveCapture(spec.target, matchTable)
  if not shouldTrackTarget(target) then return end

  local actor = resolveCapture(spec.user, matchTable)
  local source = boop.util.trim(spec.source or "battlerage")

  for _, aff in ipairs(affs) do
    local key = boop.util.safeLower(boop.util.trim(aff or ""))
    if key ~= "" then
      if mode == "add" then
        local changed = boop.afflictions.addTarget(key)
        if changed then
          sendAffCallout(mode, key)
        end
      elseif mode == "remove" then
        local changed = boop.afflictions.removeTarget(key)
        if changed then
          sendAffCallout(mode, key)
        end
      end
      if boop.trace and boop.trace.log then
        boop.trace.log(string.format("rage aff %s: %s (%s) actor=%s target=%s", mode, key, source, actor ~= "" and actor or "?", target ~= "" and target or "?"))
      end
    end
  end
end
