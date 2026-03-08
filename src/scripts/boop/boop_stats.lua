boop.stats = boop.stats or {}

local function nowSeconds()
  if getEpoch then return getEpoch() end
  return os.clock()
end

local function currentArea()
  if gmcp and gmcp.Room and gmcp.Room.Info and gmcp.Room.Info.area then
    return tostring(gmcp.Room.Info.area)
  end
  return "UNKNOWN"
end

local function newScope(startedAt)
  return {
    gold = 0,
    experience = 0,
    rawExperience = 0,
    kills = 0,
    targets = 0,
    retargets = 0,
    abandoned = 0,
    flees = 0,
    roomMoves = 0,
    totalTtk = 0,
    bestTtk = nil,
    worstTtk = nil,
    startedAt = startedAt or nowSeconds(),
    endedAt = nil,
    areas = {},
  }
end

local function ensureScope(scope, defaultStart)
  if type(scope) ~= "table" then
    scope = newScope(defaultStart)
  end

  scope.gold = tonumber(scope.gold) or 0
  scope.experience = tonumber(scope.experience) or 0
  scope.rawExperience = tonumber(scope.rawExperience) or 0
  scope.kills = tonumber(scope.kills) or 0
  scope.targets = tonumber(scope.targets) or 0
  scope.retargets = tonumber(scope.retargets) or 0
  scope.abandoned = tonumber(scope.abandoned) or 0
  scope.flees = tonumber(scope.flees) or 0
  scope.roomMoves = tonumber(scope.roomMoves) or 0
  scope.totalTtk = tonumber(scope.totalTtk) or 0
  if scope.bestTtk ~= nil then
    scope.bestTtk = tonumber(scope.bestTtk)
  end
  if scope.worstTtk ~= nil then
    scope.worstTtk = tonumber(scope.worstTtk)
  end
  scope.startedAt = tonumber(scope.startedAt) or defaultStart or nowSeconds()
  scope.endedAt = tonumber(scope.endedAt) or nil
  scope.areas = scope.areas or {}
  return scope
end

local function ensureArea(scope, area)
  scope = ensureScope(scope)
  local key = tostring(area or "UNKNOWN")
  scope.areas[key] = ensureScope(scope.areas[key], scope.startedAt)
  scope.areas[key].areas = nil
  return scope.areas[key]
end

local function eachScope(fn)
  fn(boop.stats.session)
  fn(boop.stats.trip)
  fn(boop.stats.lifetime)
end

local function withArea(scope, area, fn)
  fn(scope)
  if area and area ~= "" then
    fn(ensureArea(scope, area))
  end
end

local function persistLifetime()
  if boop.db and boop.db.saveStats then
    boop.db.saveStats()
  end
end

local function addGold(delta, area)
  if not delta or delta <= 0 then return end
  eachScope(function(scope)
    withArea(scope, area, function(bucket)
      bucket.gold = bucket.gold + delta
    end)
  end)
  persistLifetime()
end

local function addExperience(delta, area)
  if not delta or delta == 0 then return end
  eachScope(function(scope)
    withArea(scope, area, function(bucket)
      bucket.experience = bucket.experience + delta
    end)
  end)
  persistLifetime()
end

local function addRawExperience(delta, area)
  if not delta or delta <= 0 then return end
  eachScope(function(scope)
    withArea(scope, area, function(bucket)
      bucket.rawExperience = (tonumber(bucket.rawExperience) or 0) + delta
    end)
  end)
  persistLifetime()
end

local function incrementCounter(name, area, amount)
  local delta = tonumber(amount) or 1
  eachScope(function(scope)
    withArea(scope, area, function(bucket)
      bucket[name] = (tonumber(bucket[name]) or 0) + delta
    end)
  end)
  if name ~= "roomMoves" then
    persistLifetime()
  end
end

local function recordKill(seconds, area)
  local elapsed = tonumber(seconds) or 0
  if elapsed < 0 then elapsed = 0 end
  eachScope(function(scope)
    withArea(scope, area, function(bucket)
      bucket.kills = (tonumber(bucket.kills) or 0) + 1
      bucket.totalTtk = (tonumber(bucket.totalTtk) or 0) + elapsed
      if not bucket.bestTtk or elapsed < bucket.bestTtk then
        bucket.bestTtk = elapsed
      end
      if not bucket.worstTtk or elapsed > bucket.worstTtk then
        bucket.worstTtk = elapsed
      end
    end)
  end)
  persistLifetime()
end

local function elapsedFor(scope)
  scope = ensureScope(scope)
  local finish = scope.endedAt or nowSeconds()
  local elapsed = finish - (scope.startedAt or finish)
  if elapsed < 0 then
    return 0
  end
  return elapsed
end

local function avgTtk(scope)
  scope = ensureScope(scope)
  if scope.kills <= 0 then return 0 end
  return scope.totalTtk / scope.kills
end

local function perHour(value, elapsed)
  if not elapsed or elapsed <= 0 then return 0 end
  return (tonumber(value) or 0) * 3600 / elapsed
end

local function scopeByName(name)
  local key = boop.util.safeLower(boop.util.trim(name or "session"))
  if key == "" then key = "session" end
  if key == "lifetime" or key == "life" then
    return boop.stats.lifetime, "lifetime"
  end
  if key == "trip" then
    return boop.stats.trip, "trip"
  end
  return boop.stats.session, "session"
end

local function formatNumber(value, decimals)
  local num = tonumber(value) or 0
  return string.format("%." .. tostring(decimals or 1) .. "f", num)
end

local function currentGoldFromStatus()
  if gmcp and gmcp.Char and gmcp.Char.Status then
    return tonumber(gmcp.Char.Status.gold)
  end
  return nil
end

local function currentXpFromStatus()
  if not gmcp or not gmcp.Char or not gmcp.Char.Status then
    return nil
  end
  local levelRaw = tostring(gmcp.Char.Status.level or "")
  local xpRaw = tostring(gmcp.Char.Status.xp or "")
  local levelMatch = levelRaw:match("^(%d+)")
  local xpMatch = xpRaw:match("([%d%.]+)")
  if not levelMatch or not xpMatch then
    return nil
  end
  local lvl = tonumber(levelMatch)
  local xp = tonumber(xpMatch)
  if lvl == nil or xp == nil then
    return nil
  end
  return lvl * 100 + xp
end

local function seedBaselinesFromStatus()
  local gold = currentGoldFromStatus()
  if gold ~= nil then
    boop.stats.lastGold = gold
  end

  local xp = currentXpFromStatus()
  if xp ~= nil then
    boop.stats.lastXp = xp
  end
end

function boop.stats.init()
  local now = nowSeconds()
  boop.stats.session = ensureScope(boop.stats.session, now)
  boop.stats.trip = ensureScope(boop.stats.trip, now)
  boop.stats.lifetime = ensureScope(boop.stats.lifetime, now)
  boop.stats.lastGold = nil
  boop.stats.lastXp = nil
  boop.stats.activeTarget = boop.stats.activeTarget or nil
  boop.stats.lastKill = boop.stats.lastKill or nil
  seedBaselinesFromStatus()
end

function boop.stats.onCharStatus()
  if not gmcp or not gmcp.Char or not gmcp.Char.Status then return end
  local area = currentArea()

  local goldNumber = tonumber(gmcp.Char.Status.gold)
  if goldNumber then
    if boop.stats.lastGold ~= nil then
      local delta = goldNumber - boop.stats.lastGold
      addGold(delta, area)
    end
    boop.stats.lastGold = goldNumber
  end

  local lvl = tonumber((gmcp.Char.Status.level or ""):match("^(%d+)") or 0)
  local xp = tonumber((gmcp.Char.Status.xp or ""):match("([%d%.]+)") or 0)
  local newXp = lvl * 100 + xp

  if boop.stats.lastXp ~= nil then
    local delta = newXp - boop.stats.lastXp
    addExperience(delta, area)
  end

  boop.stats.lastXp = newXp
end

function boop.stats.onTargetSet(targetId, targetName)
  local tid = boop.util.trim(tostring(targetId or ""))
  if tid == "" then return end

  boop.stats.activeTarget = boop.stats.activeTarget or nil
  local current = boop.stats.activeTarget
  if current and tostring(current.id or "") == tid then
    if boop.util.trim(targetName or "") ~= "" then
      current.name = targetName
    end
    return
  end

  if current and tostring(current.id or "") ~= "" then
    incrementCounter("retargets", current.area)
    incrementCounter("abandoned", current.area)
  end

  incrementCounter("targets", currentArea())
  boop.stats.activeTarget = {
    id = tid,
    name = boop.util.trim(targetName or ""),
    area = currentArea(),
    startedAt = nowSeconds(),
  }
end

function boop.stats.onTargetRemoved(targetId, targetName)
  local current = boop.stats.activeTarget
  if not current then return end

  local removedId = boop.util.trim(tostring(targetId or ""))
  if removedId == "" or tostring(current.id or "") ~= removedId then
    return
  end

  local finishedAt = nowSeconds()
  local elapsed = finishedAt - (tonumber(current.startedAt) or finishedAt)
  local area = current.area or currentArea()
  recordKill(elapsed, area)
  boop.stats.lastKill = {
    id = removedId,
    name = boop.util.trim(targetName or current.name or ""),
    area = area,
    ttk = elapsed,
    at = finishedAt,
  }
  boop.stats.activeTarget = nil
end

function boop.stats.onRoomChange()
  incrementCounter("roomMoves", currentArea())
end

function boop.stats.onFlee()
  incrementCounter("flees", currentArea())
end

function boop.stats.onExperienceGain(amount, area)
  local cleaned = tostring(amount or ""):gsub(",", "")
  local gained = tonumber(cleaned)
  if not gained or gained <= 0 then return end
  addRawExperience(gained, area or currentArea())
end

local function resetScopeData(scope, startedAt)
  local fresh = newScope(startedAt or nowSeconds())
  local stopwatch = scope and scope.stopwatch or nil
  fresh.stopwatch = stopwatch
  return fresh
end

local function resetTripStopwatch(scope)
  if not scope then return end
  if scope.stopwatch and stopStopWatch then
    stopStopWatch(scope.stopwatch)
  end
  if createStopWatch then
    scope.stopwatch = createStopWatch()
  else
    scope.stopwatch = nil
  end
  if scope.stopwatch and startStopWatch then
    startStopWatch(scope.stopwatch)
  end
end

function boop.stats.reset(scopeName)
  local key = boop.util.safeLower(boop.util.trim(scopeName or "session"))
  local now = nowSeconds()

  if key == "all" then
    local hadTripStopwatch = boop.stats.trip and boop.stats.trip.stopwatch
    boop.stats.session = resetScopeData(nil, now)
    boop.stats.trip = resetScopeData(boop.stats.trip, now)
    if hadTripStopwatch then
      resetTripStopwatch(boop.stats.trip)
    end
    boop.stats.lifetime = resetScopeData(nil, now)
    boop.stats.lastKill = nil
    boop.stats.activeTarget = nil
    seedBaselinesFromStatus()
    persistLifetime()
    boop.util.ok("stats reset: all")
    return
  end

  if key == "session" then
    boop.stats.session = resetScopeData(nil, now)
    boop.stats.lastKill = nil
    seedBaselinesFromStatus()
    boop.util.ok("stats reset: session")
    return
  end

  if key == "trip" then
    local hadStopwatch = boop.stats.trip and boop.stats.trip.stopwatch
    boop.stats.trip = resetScopeData(boop.stats.trip, now)
    if hadStopwatch then
      resetTripStopwatch(boop.stats.trip)
    end
    boop.stats.lastKill = nil
    seedBaselinesFromStatus()
    boop.util.ok("stats reset: trip")
    return
  end

  if key == "lifetime" or key == "life" then
    boop.stats.lifetime = resetScopeData(nil, now)
    seedBaselinesFromStatus()
    persistLifetime()
    boop.util.ok("stats reset: lifetime")
    return
  end

  boop.util.info("Usage: boop stats reset <session|trip|lifetime|all>")
end

function boop.stats.show(scopeName)
  local scope, label = scopeByName(scopeName)
  local elapsed = elapsedFor(scope)
  local avg = avgTtk(scope)
  local goldPerKill = scope.kills > 0 and (scope.gold / scope.kills) or 0
  local xpPerKill = scope.kills > 0 and (scope.experience / scope.kills) or 0
  local rawXpPerKill = scope.kills > 0 and ((scope.rawExperience or 0) / scope.kills) or 0

  boop.util.info(string.format(
    "%s stats: %d kills | %d targets | %d gold | %s%% xp | %d xp",
    label, scope.kills, scope.targets, scope.gold, formatNumber(scope.experience, 2), tonumber(scope.rawExperience) or 0
  ))
  boop.util.info(string.format(
    "%s efficiency: avg ttk %ss | gold/kill %s | xp/kill %s%% | raw xp/kill %s",
    label, formatNumber(avg, 2), formatNumber(goldPerKill, 1), formatNumber(xpPerKill, 2), formatNumber(rawXpPerKill, 1)
  ))
  boop.util.info(string.format(
    "%s rates: %s kills/hr | %s gold/hr | %s%% xp/hr | %s xp/hr",
    label,
    formatNumber(perHour(scope.kills, elapsed), 1),
    formatNumber(perHour(scope.gold, elapsed), 1),
    formatNumber(perHour(scope.experience, elapsed), 2),
    formatNumber(perHour(scope.rawExperience or 0, elapsed), 1)
  ))
  boop.util.info(string.format(
    "%s friction: %d retargets | %d abandoned | %d room moves | %d flees",
    label, scope.retargets, scope.abandoned, scope.roomMoves, scope.flees
  ))
end

function boop.stats.showAreas(scopeName, limit)
  local scope, label = scopeByName(scopeName)
  local rows = {}
  for area, data in pairs(scope.areas or {}) do
    if (tonumber(data.kills) or 0) > 0
      or (tonumber(data.gold) or 0) > 0
      or math.abs(tonumber(data.experience) or 0) > 0
      or (tonumber(data.rawExperience) or 0) > 0
    then
      rows[#rows + 1] = {
        area = area,
        kills = tonumber(data.kills) or 0,
        gold = tonumber(data.gold) or 0,
        experience = tonumber(data.experience) or 0,
        rawExperience = tonumber(data.rawExperience) or 0,
        avgTtk = avgTtk(data),
      }
    end
  end

  table.sort(rows, function(a, b)
    if a.kills == b.kills then
      return boop.util.safeLower(a.area) < boop.util.safeLower(b.area)
    end
    return a.kills > b.kills
  end)

  local maxRows = tonumber(limit) or 5
  if maxRows < 1 then maxRows = 1 end
  boop.util.info(string.format("%s areas:", label))
  if #rows == 0 then
    boop.util.info("  (no area activity yet)")
    return
  end
  for i = 1, math.min(#rows, maxRows) do
    local row = rows[i]
    boop.util.info(string.format(
      "  %d. %s | %d kills | %d gold | %s%% xp | %d xp | avg ttk %ss",
      i, row.area, row.kills, row.gold, formatNumber(row.experience, 2), row.rawExperience, formatNumber(row.avgTtk, 2)
    ))
  end
end

function boop.stats.command(raw)
  local text = boop.util.trim(raw or "")
  local first, rest = text:match("^(%S+)%s*(.-)$")
  local cmd = boop.util.safeLower(first or "")
  local arg = boop.util.trim(rest or "")

  if cmd == "" or cmd == "show" or cmd == "session" or cmd == "trip" or cmd == "lifetime" then
    boop.stats.show(cmd ~= "" and cmd or "session")
    return
  end

  if cmd == "reset" then
    boop.stats.reset(arg ~= "" and arg or "session")
    return
  end

  if cmd == "areas" then
    local scope, limit = arg:match("^(%S+)%s+(%d+)$")
    if scope then
      boop.stats.showAreas(scope, tonumber(limit))
      return
    end
    local maybeNumber = tonumber(arg)
    if maybeNumber then
      boop.stats.showAreas("session", maybeNumber)
      return
    end
    boop.stats.showAreas(arg ~= "" and arg or "session")
    return
  end

  boop.util.info("Usage: boop stats [session|trip|lifetime|areas [scope] [limit]|reset <session|trip|lifetime|all>]")
end

function boop.stats.startTrip()
  if boop.stats.trip.stopwatch then
    boop.util.warn("Trip already running.")
    return
  end
  boop.stats.trip = newScope(nowSeconds())
  if createStopWatch then
    boop.stats.trip.stopwatch = createStopWatch()
  end
  if boop.stats.trip.stopwatch and startStopWatch then
    startStopWatch(boop.stats.trip.stopwatch)
  end
  boop.util.ok("Started a new hunting trip.")
end

function boop.stats.stopTrip()
  if not boop.stats.trip.stopwatch then
    boop.util.warn("No trip running.")
    return
  end
  if stopStopWatch then
    stopStopWatch(boop.stats.trip.stopwatch)
  end
  boop.stats.trip.endedAt = nowSeconds()
  boop.util.ok("Stopped hunting trip.")
  boop.stats.show("trip")
  boop.stats.trip.stopwatch = nil
end
