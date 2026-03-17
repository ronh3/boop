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

local function currentPartySize()
  local size = tonumber(boop and boop.config and boop.config.partySize) or 1
  size = math.floor(size)
  if size < 1 then
    return 1
  end
  return size
end

local function currentClass()
  if gmcp and gmcp.Char and gmcp.Char.Status and gmcp.Char.Status.class then
    local class = boop.util.safeLower(gmcp.Char.Status.class)
    if class ~= "" then
      return class
    end
  end
  if boop and boop.state and boop.state.class then
    local class = boop.util.safeLower(boop.state.class)
    if class ~= "" then
      return class
    end
  end
  return "unknown"
end

local CORPSE_NAME_PATTERNS = {
  "^the corpse of%s+",
  "^corpse of%s+",
  "^the remains of%s+",
  "^remains of%s+",
}

local function normalizeTrackedMobName(name)
  local value = boop.util.trim(tostring(name or ""))
  if value == "" then
    return ""
  end

  for _, pattern in ipairs(CORPSE_NAME_PATTERNS) do
    local updated = value:gsub(pattern, "")
    if updated ~= value then
      value = boop.util.trim(updated)
      break
    end
  end

  return value
end

local function formatStatValue(value, decimals)
  local num = tonumber(value)
  if not num then
    return "0"
  end
  if math.abs(num - math.floor(num)) < 0.000001 then
    return tostring(math.floor(num))
  end
  return string.format("%." .. tostring(decimals or 1) .. "f", num)
end

local function newRageStats()
  return {
    decisions = 0,
    uses = 0,
    suppressed = 0,
    holds = 0,
    shieldbreaks = 0,
    totalCost = 0,
    comboConditional = 0,
    comboPrimers = 0,
    comboFallbacks = 0,
    tempoAffs = 0,
    tempoSqueezes = 0,
    tempoFallbacks = 0,
    byMode = {},
    byOutcome = {},
    byDesc = {},
    byAbility = {},
  }
end

local function currentScopeMeta(startedAt)
  return {
    attackMode = tostring((boop.config and boop.config.attackMode) or "simple"),
    partySize = currentPartySize(),
    class = currentClass(),
    area = currentArea(),
    startedAt = tonumber(startedAt) or nowSeconds(),
  }
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
    activeSeconds = 0,
    activeSince = nil,
    areas = {},
    abilities = {},
    targetStats = {},
    rage = newRageStats(),
    records = {
      bestHit = nil,
      fastestKill = nil,
      slowestKill = nil,
    },
    meta = currentScopeMeta(startedAt),
    currentArea = nil,
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
  scope.activeSeconds = tonumber(scope.activeSeconds) or 0
  scope.activeSince = tonumber(scope.activeSince) or nil
  scope.areas = scope.areas or {}
  scope.abilities = scope.abilities or {}
  scope.targetStats = scope.targetStats or {}
  scope.rage = scope.rage or newRageStats()
  scope.records = scope.records or { bestHit = nil, fastestKill = nil, slowestKill = nil }
  scope.meta = scope.meta or currentScopeMeta(scope.startedAt)
  scope.currentArea = scope.currentArea or nil
  return scope
end

local function ensureArea(scope, area)
  scope = ensureScope(scope)
  local key = tostring(area or "UNKNOWN")
  scope.areas[key] = ensureScope(scope.areas[key], scope.startedAt)
  scope.areas[key].areas = nil
  return scope.areas[key]
end

local function ensureAbility(scope, ability)
  scope = ensureScope(scope)
  local key = boop.util.trim(tostring(ability or ""))
  if key == "" then
    key = "Attack"
  end
  scope.abilities[key] = scope.abilities[key] or {
    uses = 0,
    kills = 0,
    totalDamage = 0,
    hitsWithDamage = 0,
    maxDamage = nil,
    minDamage = nil,
    totalBalance = 0,
    balances = 0,
    crits = 0,
    critTiers = {},
  }
  local entry = scope.abilities[key]
  entry.uses = tonumber(entry.uses) or 0
  entry.kills = tonumber(entry.kills) or 0
  entry.totalDamage = tonumber(entry.totalDamage) or 0
  entry.hitsWithDamage = tonumber(entry.hitsWithDamage) or 0
  entry.maxDamage = entry.maxDamage ~= nil and tonumber(entry.maxDamage) or nil
  entry.minDamage = entry.minDamage ~= nil and tonumber(entry.minDamage) or nil
  entry.totalBalance = tonumber(entry.totalBalance) or 0
  entry.balances = tonumber(entry.balances) or 0
  entry.crits = tonumber(entry.crits) or 0
  entry.critTiers = entry.critTiers or {}
  return entry
end

local function ensureRageStats(scope)
  scope = ensureScope(scope)
  scope.rage = scope.rage or newRageStats()
  local rage = scope.rage
  rage.decisions = tonumber(rage.decisions) or 0
  rage.uses = tonumber(rage.uses) or 0
  rage.suppressed = tonumber(rage.suppressed) or 0
  rage.holds = tonumber(rage.holds) or 0
  rage.shieldbreaks = tonumber(rage.shieldbreaks) or 0
  rage.totalCost = tonumber(rage.totalCost) or 0
  rage.comboConditional = tonumber(rage.comboConditional) or 0
  rage.comboPrimers = tonumber(rage.comboPrimers) or 0
  rage.comboFallbacks = tonumber(rage.comboFallbacks) or 0
  rage.tempoAffs = tonumber(rage.tempoAffs) or 0
  rage.tempoSqueezes = tonumber(rage.tempoSqueezes) or 0
  rage.tempoFallbacks = tonumber(rage.tempoFallbacks) or 0
  rage.byMode = rage.byMode or {}
  rage.byOutcome = rage.byOutcome or {}
  rage.byDesc = rage.byDesc or {}
  rage.byAbility = rage.byAbility or {}
  return rage
end

local function ensureTargetEntry(scope, area, partySize, name)
  scope = ensureScope(scope)
  local areaKey = tostring(area or "UNKNOWN")
  local sizeKey = tonumber(partySize) or 1
  if sizeKey < 1 then sizeKey = 1 end
  local nameKey = normalizeTrackedMobName(name)
  if nameKey == "" then
    nameKey = "(unknown)"
  end

  scope.targetStats[areaKey] = scope.targetStats[areaKey] or {}
  scope.targetStats[areaKey][sizeKey] = scope.targetStats[areaKey][sizeKey] or {}
  scope.targetStats[areaKey][sizeKey][nameKey] = scope.targetStats[areaKey][sizeKey][nameKey] or {
    kills = 0,
    totalTtk = 0,
    bestTtk = nil,
    worstTtk = nil,
    lastTtk = nil,
    gold = 0,
    rawExperience = 0,
    bestGold = nil,
    bestRawExperience = nil,
  }

  local entry = scope.targetStats[areaKey][sizeKey][nameKey]
  entry.kills = tonumber(entry.kills) or 0
  entry.totalTtk = tonumber(entry.totalTtk) or 0
  entry.bestTtk = entry.bestTtk ~= nil and tonumber(entry.bestTtk) or nil
  entry.worstTtk = entry.worstTtk ~= nil and tonumber(entry.worstTtk) or nil
  entry.lastTtk = entry.lastTtk ~= nil and tonumber(entry.lastTtk) or nil
  entry.gold = tonumber(entry.gold) or 0
  entry.rawExperience = tonumber(entry.rawExperience) or 0
  entry.bestGold = entry.bestGold ~= nil and tonumber(entry.bestGold) or nil
  entry.bestRawExperience = entry.bestRawExperience ~= nil and tonumber(entry.bestRawExperience) or nil
  return entry
end

local function eachScope(fn)
  fn(boop.stats.session)
  fn(boop.stats.login)
  fn(boop.stats.trip)
  fn(boop.stats.lifetime)
end

local function eachActiveScope(fn)
  if boop.stats.session and boop.stats.session.activeSince then
    fn(boop.stats.session)
  end
  if boop.stats.login and boop.stats.login.activeSince then
    fn(boop.stats.login)
  end
  if boop.stats.trip and boop.stats.trip.activeSince then
    fn(boop.stats.trip)
  end
  if boop.stats.lifetime and boop.stats.lifetime.activeSince then
    fn(boop.stats.lifetime)
  end
end

local function hasActiveScopes()
  return (boop.stats.session and boop.stats.session.activeSince)
    or (boop.stats.login and boop.stats.login.activeSince)
    or (boop.stats.trip and boop.stats.trip.activeSince)
    or (boop.stats.lifetime and boop.stats.lifetime.activeSince)
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

local findMobXpTarget

local function addGold(delta, area)
  if not delta or delta <= 0 then return end
  eachActiveScope(function(scope)
    withArea(scope, area, function(bucket)
      bucket.gold = bucket.gold + delta
    end)
  end)
  local rewardArea, rewardName, rewardPartySize = findMobXpTarget(area)
  if rewardArea and rewardName then
    eachActiveScope(function(scope)
      local entry = ensureTargetEntry(scope, rewardArea, rewardPartySize, rewardName)
      entry.gold = entry.gold + delta
      if not entry.bestGold or delta > entry.bestGold then
        entry.bestGold = delta
      end
    end)
  end
  persistLifetime()
end

local function addExperience(delta, area)
  if not delta or delta == 0 then return end
  eachActiveScope(function(scope)
    withArea(scope, area, function(bucket)
      bucket.experience = bucket.experience + delta
    end)
  end)
  persistLifetime()
end

local function addRawExperience(delta, area)
  if not delta or delta <= 0 then return end
  eachActiveScope(function(scope)
    withArea(scope, area, function(bucket)
      bucket.rawExperience = (tonumber(bucket.rawExperience) or 0) + delta
    end)
  end)
  local rewardArea, rewardName, rewardPartySize = findMobXpTarget(area)
  if rewardArea and rewardName then
    eachActiveScope(function(scope)
      local entry = ensureTargetEntry(scope, rewardArea, rewardPartySize, rewardName)
      entry.rawExperience = entry.rawExperience + delta
      if not entry.bestRawExperience or delta > entry.bestRawExperience then
        entry.bestRawExperience = delta
      end
    end)
  end
  persistLifetime()
end

local function incrementCounter(name, area, amount)
  local delta = tonumber(amount) or 1
  eachActiveScope(function(scope)
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
  eachActiveScope(function(scope)
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

local function scopeStart(scope, at)
  scope = ensureScope(scope, at)
  local now = tonumber(at) or nowSeconds()
  if scope.activeSince then
    return scope
  end
  scope.activeSince = now
  if not scope.startedAt or scope.startedAt <= 0 then
    scope.startedAt = now
  end
  scope.endedAt = nil
  return scope
end

local function scopeStop(scope, at)
  scope = ensureScope(scope, at)
  if not scope.activeSince then
    return scope
  end
  local now = tonumber(at) or nowSeconds()
  local delta = now - scope.activeSince
  if delta > 0 then
    scope.activeSeconds = (tonumber(scope.activeSeconds) or 0) + delta
  end
  scope.activeSince = nil
  scope.endedAt = now
  return scope
end

local function startAreaTracking(scope, area, at)
  scope = ensureScope(scope, at)
  local areaName = boop.util.trim(area or "")
  if areaName == "" then
    areaName = currentArea()
  end
  if areaName == "" then
    areaName = "UNKNOWN"
  end
  if scope.currentArea == areaName then
    return scope
  end
  if scope.currentArea and scope.currentArea ~= "" then
    scopeStop(ensureArea(scope, scope.currentArea), at)
  end
  scope.currentArea = areaName
  scopeStart(ensureArea(scope, areaName), at)
  return scope
end

local function stopAreaTracking(scope, at)
  scope = ensureScope(scope, at)
  if scope.currentArea and scope.currentArea ~= "" then
    scopeStop(ensureArea(scope, scope.currentArea), at)
  end
  scope.currentArea = nil
  return scope
end

local function switchAreaTracking(scope, area, at)
  scope = ensureScope(scope, at)
  local areaName = boop.util.trim(area or "")
  if areaName == "" then
    areaName = currentArea()
  end
  if areaName == "" then
    areaName = "UNKNOWN"
  end
  if scope.currentArea == areaName then
    return scope
  end
  return startAreaTracking(scope, areaName, at)
end

local function elapsedFor(scope)
  scope = ensureScope(scope)
  local elapsed = tonumber(scope.activeSeconds) or 0
  if scope.activeSince then
    local delta = nowSeconds() - scope.activeSince
    if delta > 0 then
      elapsed = elapsed + delta
    end
  elseif elapsed <= 0 and scope.startedAt then
    local finish = scope.endedAt or nowSeconds()
    local fallback = finish - scope.startedAt
    if fallback > 0 then
      elapsed = fallback
    end
  end
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
  if key == "lasttrip" or key == "last" then
    return boop.stats.lastTrip or newScope(nowSeconds()), "lasttrip"
  end
  if key == "login" then
    return boop.stats.login, "login"
  end
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

local function deepCopy(value, seen)
  if type(value) ~= "table" then
    return value
  end
  seen = seen or {}
  if seen[value] then
    return seen[value]
  end
  local out = {}
  seen[value] = out
  for key, inner in pairs(value) do
    out[deepCopy(key, seen)] = deepCopy(inner, seen)
  end
  return out
end

function boop.stats.cloneScope(scope)
  if type(scope) ~= "table" then
    return nil
  end
  return deepCopy(scope)
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

local function ensureMobArea(area, partySize)
  local key = tostring(area or "UNKNOWN")
  local sizeKey = tonumber(partySize) or 1
  if sizeKey < 1 then sizeKey = 1 end
  boop.stats.mobXp = boop.stats.mobXp or {}
  boop.stats.mobXp[key] = boop.stats.mobXp[key] or {}
  boop.stats.mobXp[key][sizeKey] = boop.stats.mobXp[key][sizeKey] or {}
  return boop.stats.mobXp[key][sizeKey]
end

local function ensureMobEntry(area, partySize, name)
  local mobs = ensureMobArea(area, partySize)
  local key = normalizeTrackedMobName(name)
  mobs[key] = mobs[key] or {
    observations = 0,
    total = 0,
    min = nil,
    max = nil,
    values = {},
  }
  local entry = mobs[key]
  entry.observations = tonumber(entry.observations) or 0
  entry.total = tonumber(entry.total) or 0
  entry.min = entry.min ~= nil and tonumber(entry.min) or nil
  entry.max = entry.max ~= nil and tonumber(entry.max) or nil
  entry.values = entry.values or {}
  return entry
end

local function mergeMobEntry(target, source)
  if not source then
    return target
  end
  target = target or {
    observations = 0,
    total = 0,
    min = nil,
    max = nil,
    values = {},
  }

  target.observations = (tonumber(target.observations) or 0) + (tonumber(source.observations) or 0)
  target.total = (tonumber(target.total) or 0) + (tonumber(source.total) or 0)

  local sourceMin = source.min ~= nil and tonumber(source.min) or nil
  local sourceMax = source.max ~= nil and tonumber(source.max) or nil
  if sourceMin ~= nil and (target.min == nil or sourceMin < target.min) then
    target.min = sourceMin
  end
  if sourceMax ~= nil and (target.max == nil or sourceMax > target.max) then
    target.max = sourceMax
  end

  for xp, count in pairs(source.values or {}) do
    target.values[tostring(xp)] = (tonumber(target.values[tostring(xp)]) or 0) + (tonumber(count) or 0)
  end

  return target
end

local function aggregatedMobEntries(area, partySize)
  local areaMobs = boop.stats.mobXp and boop.stats.mobXp[area] and boop.stats.mobXp[area][partySize] or {}
  local merged = {}
  for rawName, entry in pairs(areaMobs or {}) do
    local name = normalizeTrackedMobName(rawName)
    if name ~= "" then
      merged[name] = mergeMobEntry(merged[name], entry)
    end
  end
  return merged
end

local function mergeTargetEntry(target, source)
  if not source then
    return target
  end
  target = target or {
    kills = 0,
    totalTtk = 0,
    bestTtk = nil,
    worstTtk = nil,
    lastTtk = nil,
    gold = 0,
    rawExperience = 0,
    bestGold = nil,
    bestRawExperience = nil,
  }

  local sourceKills = tonumber(source.kills) or 0
  target.kills = (tonumber(target.kills) or 0) + sourceKills
  target.totalTtk = (tonumber(target.totalTtk) or 0) + (tonumber(source.totalTtk) or 0)
  target.gold = (tonumber(target.gold) or 0) + (tonumber(source.gold) or 0)
  target.rawExperience = (tonumber(target.rawExperience) or 0) + (tonumber(source.rawExperience) or 0)

  local sourceBest = source.bestTtk ~= nil and tonumber(source.bestTtk) or nil
  local sourceWorst = source.worstTtk ~= nil and tonumber(source.worstTtk) or nil
  local sourceLast = source.lastTtk ~= nil and tonumber(source.lastTtk) or nil
  local sourceBestGold = source.bestGold ~= nil and tonumber(source.bestGold) or nil
  local sourceBestRaw = source.bestRawExperience ~= nil and tonumber(source.bestRawExperience) or nil

  if sourceBest ~= nil and (target.bestTtk == nil or sourceBest < target.bestTtk) then
    target.bestTtk = sourceBest
  end
  if sourceWorst ~= nil and (target.worstTtk == nil or sourceWorst > target.worstTtk) then
    target.worstTtk = sourceWorst
  end
  if sourceLast ~= nil then
    target.lastTtk = sourceLast
  end
  if sourceBestGold ~= nil and (target.bestGold == nil or sourceBestGold > target.bestGold) then
    target.bestGold = sourceBestGold
  end
  if sourceBestRaw ~= nil and (target.bestRawExperience == nil or sourceBestRaw > target.bestRawExperience) then
    target.bestRawExperience = sourceBestRaw
  end

  return target
end

local function aggregatedTargetEntries(scope, area, partySize)
  local buckets = scope.targetStats and scope.targetStats[area] and scope.targetStats[area][partySize] or {}
  local merged = {}
  for rawName, entry in pairs(buckets or {}) do
    local name = normalizeTrackedMobName(rawName)
    if name ~= "" then
      merged[name] = mergeTargetEntry(merged[name], entry)
    end
  end
  return merged
end

local function sortedMobXpValues(entry)
  local rows = {}
  for xp, count in pairs(entry.values or {}) do
    local xpValue = tonumber(xp)
    local seen = tonumber(count) or 0
    if xpValue and seen > 0 then
      rows[#rows + 1] = { xp = xpValue, count = seen }
    end
  end
  table.sort(rows, function(a, b) return a.xp < b.xp end)
  return rows
end

local function meanMobXp(entry)
  if not entry or (tonumber(entry.observations) or 0) <= 0 then
    return 0
  end
  return (tonumber(entry.total) or 0) / (tonumber(entry.observations) or 1)
end

local function medianMobXp(entry)
  local observations = tonumber(entry and entry.observations) or 0
  if observations <= 0 then
    return 0
  end

  local rows = sortedMobXpValues(entry)
  local midpointA = math.floor((observations + 1) / 2)
  local midpointB = math.floor((observations + 2) / 2)
  local seen = 0
  local first
  local second
  for _, row in ipairs(rows) do
    seen = seen + row.count
    if not first and seen >= midpointA then
      first = row.xp
    end
    if seen >= midpointB then
      second = row.xp
      break
    end
  end
  if first and second then
    return (first + second) / 2
  end
  return first or second or 0
end

local function modeMobXp(entry)
  local rows = sortedMobXpValues(entry)
  local bestXp
  local bestCount = 0
  for _, row in ipairs(rows) do
    if row.count > bestCount or (row.count == bestCount and (not bestXp or row.xp < bestXp)) then
      bestXp = row.xp
      bestCount = row.count
    end
  end
  return bestXp or 0, bestCount
end

local function formatMobXpSummary(entry, partySize)
  if not entry or (tonumber(entry.observations) or 0) <= 0 then
    return nil
  end
  local modeXp, modeCount = modeMobXp(entry)
  return string.format(
    "xp mean %s | median %s | mode %s (%dx) | seen %d | p%d",
    formatStatValue(meanMobXp(entry), 1),
    formatStatValue(medianMobXp(entry), 1),
    formatStatValue(modeXp, 1),
    tonumber(modeCount) or 0,
    tonumber(entry.observations) or 0,
    tonumber(partySize) or 1
  )
end

local function resolveCritTier(rawCrit)
  local key = boop.util.safeLower(boop.util.trim(rawCrit or ""))
  if key == "" then return "" end
  key = key:gsub("%-", " ")
  key = key:gsub("%s+", " ")
  key = key:upper()

  local map = {
    ["CRITICAL"] = "2xCRIT",
    ["CRUSHING CRITICAL"] = "4xCRIT",
    ["OBLITERATING CRITICAL"] = "8xCRIT",
    ["ANNIHILATINGLY POWERFUL CRITICAL"] = "16xCRIT",
    ["WORLD SHATTERING CRITICAL"] = "32xCRIT",
    ["2XCRIT"] = "2xCRIT",
    ["4XCRIT"] = "4xCRIT",
    ["8XCRIT"] = "8xCRIT",
    ["16XCRIT"] = "16xCRIT",
    ["32XCRIT"] = "32xCRIT",
  }

  return map[key] or ""
end

local function parseDamageAmount(value)
  local cleaned = tostring(value or ""):gsub(",", "")
  local match = cleaned:match("(%d+)")
  return tonumber(match)
end

local function parseBalanceSeconds(value)
  local match = tostring(value or ""):match("([%d%.]+)")
  return tonumber(match)
end

local function critTierRank(tier)
  local num = tostring(tier or ""):match("^(%d+)")
  return tonumber(num) or 0
end

local function recordAbilityUse(ability, data)
  local name = boop.util.trim(ability or "")
  if name == "" then return end

  eachActiveScope(function(scope)
    local entry = ensureAbility(scope, name)
    entry.uses = entry.uses + 1

    local damage = tonumber(data and data.damage) or nil
    if damage and damage > 0 then
      entry.totalDamage = entry.totalDamage + damage
      entry.hitsWithDamage = entry.hitsWithDamage + 1
      if not entry.maxDamage or damage > entry.maxDamage then
        entry.maxDamage = damage
      end
      if not entry.minDamage or damage < entry.minDamage then
        entry.minDamage = damage
      end

      local bestHit = scope.records and scope.records.bestHit or nil
      if not bestHit or damage > (tonumber(bestHit.damage) or 0) then
        scope.records.bestHit = {
          ability = name,
          target = boop.util.trim(data and data.target or ""),
          area = boop.util.trim(data and data.area or currentArea()),
          partySize = currentPartySize(),
          damage = damage,
          critTier = boop.util.trim(data and data.critTier or ""),
        }
      end
    end

    local balance = tonumber(data and data.balance) or nil
    if balance and balance > 0 then
      entry.totalBalance = entry.totalBalance + balance
      entry.balances = entry.balances + 1
    end

    local critTier = boop.util.trim(data and data.critTier or "")
    if critTier ~= "" then
      entry.crits = entry.crits + 1
      entry.critTiers[critTier] = (tonumber(entry.critTiers[critTier]) or 0) + 1
    end
  end)
end

local function recordAbilityKill(ability)
  local name = boop.util.trim(ability or "")
  if name == "" then return end
  eachActiveScope(function(scope)
    local entry = ensureAbility(scope, name)
    entry.kills = entry.kills + 1
  end)
end

local function recordTargetKill(area, name, seconds, partySize)
  local cleanArea = boop.util.trim(area or "")
  local cleanName = boop.util.trim(name or "")
  local elapsed = tonumber(seconds) or 0
  local size = tonumber(partySize) or currentPartySize()
  if size < 1 then size = 1 end
  if cleanArea == "" or cleanName == "" then
    return
  end
  if elapsed < 0 then
    elapsed = 0
  end

  eachActiveScope(function(scope)
    local entry = ensureTargetEntry(scope, cleanArea, size, cleanName)
    entry.kills = entry.kills + 1
    entry.totalTtk = entry.totalTtk + elapsed
    entry.lastTtk = elapsed
    if not entry.bestTtk or elapsed < entry.bestTtk then
      entry.bestTtk = elapsed
    end
    if not entry.worstTtk or elapsed > entry.worstTtk then
      entry.worstTtk = elapsed
    end

    local records = scope.records or {}
    local fastest = records.fastestKill
    if not fastest or elapsed < (tonumber(fastest.ttk) or math.huge) then
      records.fastestKill = {
        target = cleanName,
        area = cleanArea,
        partySize = size,
        ttk = elapsed,
      }
    end
    local slowest = records.slowestKill
    if not slowest or elapsed > (tonumber(slowest.ttk) or -1) then
      records.slowestKill = {
        target = cleanName,
        area = cleanArea,
        partySize = size,
        ttk = elapsed,
      }
    end
    scope.records = records
  end)
end

findMobXpTarget = function(area)
  local active = boop.stats.activeTarget
  if active then
    local activeArea = boop.util.trim(active.area or area or "")
    local activeName = normalizeTrackedMobName(active.name or "")
    if activeArea ~= "" and activeName ~= "" then
      return activeArea, activeName, currentPartySize()
    end
  end

  local lastKill = boop.stats.lastKill
  if lastKill and nowSeconds() - (tonumber(lastKill.at) or 0) <= 5 then
    local killArea = boop.util.trim(lastKill.area or area or "")
    local killName = normalizeTrackedMobName(lastKill.name or "")
    if killArea ~= "" and killName ~= "" then
      return killArea, killName, tonumber(lastKill.partySize) or currentPartySize()
    end
  end

  return nil, nil, nil
end

local function observeMobXp(area, name, amount, partySize)
  local cleanArea = boop.util.trim(area or "")
  local cleanName = normalizeTrackedMobName(name)
  local gained = tonumber(amount)
  local size = tonumber(partySize) or currentPartySize()
  if size < 1 then size = 1 end
  if cleanArea == "" or cleanName == "" or not gained or gained <= 0 then
    return
  end

  local entry = ensureMobEntry(cleanArea, size, cleanName)
  entry.observations = entry.observations + 1
  entry.total = entry.total + gained
  entry.values[tostring(gained)] = (tonumber(entry.values[tostring(gained)]) or 0) + 1
  if not entry.min or gained < entry.min then
    entry.min = gained
  end
  if not entry.max or gained > entry.max then
    entry.max = gained
  end

  if boop.db and boop.db.recordMobXpObservation then
    boop.db.recordMobXpObservation(cleanArea, size, cleanName, gained, 1)
  end
end

function boop.stats.init()
  local now = nowSeconds()
  boop.stats.session = newScope(now)
  boop.stats.login = ensureScope(boop.stats.login, now)
  boop.stats.trip = ensureScope(boop.stats.trip, now)
  boop.stats.lifetime = ensureScope(boop.stats.lifetime, now)
  boop.stats.lastTrip = boop.stats.lastTrip or nil
  boop.stats.mobXp = boop.stats.mobXp or {}
  boop.stats.lastGold = nil
  boop.stats.lastXp = nil
  boop.stats.activeTarget = boop.stats.activeTarget or nil
  boop.stats.lastKill = boop.stats.lastKill or nil
  boop.stats.pendingAttack = nil
  boop.stats.lastResolvedAttack = nil
  boop.stats.lastRageDecision = nil
  if boop.config and boop.config.enabled then
    scopeStart(boop.stats.session, now)
    scopeStart(boop.stats.login, now)
    scopeStart(boop.stats.lifetime, now)
    startAreaTracking(boop.stats.session, currentArea(), now)
    startAreaTracking(boop.stats.login, currentArea(), now)
    startAreaTracking(boop.stats.lifetime, currentArea(), now)
  else
    stopAreaTracking(boop.stats.session, now)
    stopAreaTracking(boop.stats.login, now)
    stopAreaTracking(boop.stats.lifetime, now)
    scopeStop(boop.stats.session, now)
    scopeStop(boop.stats.login, now)
    scopeStop(boop.stats.lifetime, now)
  end
  seedBaselinesFromStatus()
end

local function resolvePendingAttack()
  local pending = boop.stats.pendingAttack
  if not pending then
    return nil
  end

  local resolved = {
    ability = boop.util.trim(pending.ability or ""),
    target = boop.util.trim(pending.target or ""),
    area = boop.util.trim(pending.area or currentArea()),
    at = tonumber(pending.at) or nowSeconds(),
    damage = tonumber(pending.damage) or nil,
    critTier = boop.util.trim(pending.critTier or ""),
    balance = tonumber(pending.balance) or nil,
  }

  boop.stats.pendingAttack = nil
  recordAbilityUse(resolved.ability, resolved)
  boop.stats.lastResolvedAttack = resolved
  return resolved
end

function boop.stats.onAttackLine(actor, selfActor, ability, target)
  if not selfActor then
    return
  end

  if boop.stats.pendingAttack then
    resolvePendingAttack()
  end

  boop.stats.pendingAttack = {
    actor = boop.util.trim(actor or "You"),
    ability = boop.util.trim(ability or ""),
    target = boop.util.trim(target or ""),
    area = currentArea(),
    at = nowSeconds(),
    damage = nil,
    critTier = "",
    balance = nil,
  }
end

function boop.stats.onAttackDamage(amount)
  local pending = boop.stats.pendingAttack
  if not pending then
    return
  end
  pending.damage = parseDamageAmount(amount)
end

function boop.stats.onAttackCritical(critLabel)
  local pending = boop.stats.pendingAttack
  if not pending then
    return
  end
  pending.critTier = resolveCritTier(critLabel)
end

function boop.stats.onAttackBalance(seconds)
  local pending = boop.stats.pendingAttack
  if not pending then
    return
  end
  pending.balance = parseBalanceSeconds(seconds)
  resolvePendingAttack()
end

function boop.stats.onKillLine(target)
  local victim = boop.util.trim(target or "")
  if victim == "" then
    return
  end

  local resolved = boop.stats.pendingAttack and resolvePendingAttack() or boop.stats.lastResolvedAttack
  if not resolved then
    return
  end

  if resolved.area ~= currentArea() then
    return
  end
  if nowSeconds() - (tonumber(resolved.at) or 0) > 5 then
    return
  end
  if boop.util.trim(resolved.target or "") ~= victim then
    return
  end

  recordAbilityKill(resolved.ability)
end

function boop.stats.onKillObserved(target, area)
  local victim = normalizeTrackedMobName(target)
  if victim == "" then
    return
  end

  local resolvedArea = boop.util.trim(area or currentArea())
  if resolvedArea == "" then
    resolvedArea = currentArea()
  end

  local observedAt = nowSeconds()
  local current = boop.stats.activeTarget
  local ttk = nil
  local observedId = ""
  if current and normalizeTrackedMobName(current.name or "") == victim then
    observedId = boop.util.trim(tostring(current.id or ""))
    ttk = observedAt - (tonumber(current.startedAt) or observedAt)
    if ttk < 0 then
      ttk = 0
    end
  end

  boop.stats.lastKill = {
    id = observedId,
    name = victim,
    area = resolvedArea,
    partySize = currentPartySize(),
    ttk = ttk,
    at = observedAt,
  }
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

  local newXp = currentXpFromStatus()
  if newXp ~= nil then
    if boop.stats.lastXp ~= nil then
      local delta = newXp - boop.stats.lastXp
      addExperience(delta, area)
    end
    boop.stats.lastXp = newXp
  end
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
  local name = normalizeTrackedMobName(targetName or current.name or "")
  local partySize = currentPartySize()
  recordKill(elapsed, area)
  recordTargetKill(area, name, elapsed, partySize)
  boop.stats.lastKill = {
    id = removedId,
    name = name,
    area = area,
    partySize = partySize,
    ttk = elapsed,
    at = finishedAt,
  }
  boop.stats.activeTarget = nil
end

function boop.stats.onRoomChange()
  local now = nowSeconds()
  incrementCounter("roomMoves", currentArea())
  if boop.stats.session and boop.stats.session.activeSince then
    switchAreaTracking(boop.stats.session, currentArea(), now)
  end
  if boop.stats.login and boop.stats.login.activeSince then
    switchAreaTracking(boop.stats.login, currentArea(), now)
  end
  if boop.stats.trip and boop.stats.trip.activeSince then
    switchAreaTracking(boop.stats.trip, currentArea(), now)
  end
  if boop.stats.lifetime and boop.stats.lifetime.activeSince then
    switchAreaTracking(boop.stats.lifetime, currentArea(), now)
  end
end

function boop.stats.onFlee()
  incrementCounter("flees", currentArea())
end

function boop.stats.onExperienceGain(amount, area)
  local cleaned = tostring(amount or ""):gsub(",", "")
  local gained = tonumber(cleaned)
  if not gained or gained <= 0 then return end
  local resolvedArea = area or currentArea()
  addRawExperience(gained, resolvedArea)
  if hasActiveScopes() then
    local mobArea, mobName, mobPartySize = findMobXpTarget(resolvedArea)
    if mobArea and mobName then
      observeMobXp(mobArea, mobName, gained, mobPartySize or currentPartySize())
    end
  end
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

function boop.stats.onEnabledChanged(enabled)
  local now = nowSeconds()
  local active = enabled and true or false
  boop.stats.session = ensureScope(boop.stats.session, now)
  boop.stats.login = ensureScope(boop.stats.login, now)
  boop.stats.lifetime = ensureScope(boop.stats.lifetime, now)

  if active then
    if not boop.stats.session.activeSince then
      boop.stats.session = newScope(now)
      scopeStart(boop.stats.session, now)
    end
    scopeStart(boop.stats.login, now)
    scopeStart(boop.stats.lifetime, now)
    startAreaTracking(boop.stats.session, currentArea(), now)
    startAreaTracking(boop.stats.login, currentArea(), now)
    startAreaTracking(boop.stats.lifetime, currentArea(), now)
  else
    stopAreaTracking(boop.stats.session, now)
    stopAreaTracking(boop.stats.login, now)
    stopAreaTracking(boop.stats.lifetime, now)
    scopeStop(boop.stats.session, now)
    scopeStop(boop.stats.login, now)
    scopeStop(boop.stats.lifetime, now)
    boop.stats.activeTarget = nil
    boop.stats.pendingAttack = nil
  end

  seedBaselinesFromStatus()
  persistLifetime()
end

function boop.stats.reset(scopeName)
  local key = boop.util.safeLower(boop.util.trim(scopeName or "session"))
  local now = nowSeconds()
  local boopActive = boop.config and boop.config.enabled

  if key == "all" then
    local hadTripStopwatch = boop.stats.trip and boop.stats.trip.stopwatch
    boop.stats.session = resetScopeData(nil, now)
    boop.stats.login = resetScopeData(nil, now)
    if boopActive then
      scopeStart(boop.stats.session, now)
      scopeStart(boop.stats.login, now)
    end
    boop.stats.trip = resetScopeData(boop.stats.trip, now)
    if hadTripStopwatch then
      resetTripStopwatch(boop.stats.trip)
      scopeStart(boop.stats.trip, now)
    end
    boop.stats.lifetime = resetScopeData(nil, now)
    if boopActive then
      scopeStart(boop.stats.lifetime, now)
      startAreaTracking(boop.stats.session, currentArea(), now)
      startAreaTracking(boop.stats.login, currentArea(), now)
      startAreaTracking(boop.stats.lifetime, currentArea(), now)
    end
    boop.stats.mobXp = {}
    boop.stats.lastTrip = nil
    boop.stats.lastKill = nil
    boop.stats.activeTarget = nil
    boop.stats.pendingAttack = nil
    boop.stats.lastResolvedAttack = nil
    boop.stats.lastRageDecision = nil
    seedBaselinesFromStatus()
    if boop.db and boop.db.clearMobXpStats then
      boop.db.clearMobXpStats()
    end
    persistLifetime()
    boop.util.ok("stats reset: all")
    return
  end

  if key == "session" then
    boop.stats.session = resetScopeData(nil, now)
    if boopActive then
      scopeStart(boop.stats.session, now)
      startAreaTracking(boop.stats.session, currentArea(), now)
    end
    boop.stats.lastKill = nil
    boop.stats.pendingAttack = nil
    boop.stats.lastResolvedAttack = nil
    seedBaselinesFromStatus()
    boop.util.ok("stats reset: session")
    return
  end

  if key == "trip" then
    local hadStopwatch = boop.stats.trip and boop.stats.trip.stopwatch
    boop.stats.trip = resetScopeData(boop.stats.trip, now)
    if hadStopwatch then
      resetTripStopwatch(boop.stats.trip)
      scopeStart(boop.stats.trip, now)
      startAreaTracking(boop.stats.trip, currentArea(), now)
    end
    boop.stats.lastKill = nil
    boop.stats.pendingAttack = nil
    boop.stats.lastResolvedAttack = nil
    seedBaselinesFromStatus()
    boop.util.ok("stats reset: trip")
    return
  end

  if key == "login" then
    boop.stats.login = resetScopeData(nil, now)
    if boopActive then
      scopeStart(boop.stats.login, now)
      startAreaTracking(boop.stats.login, currentArea(), now)
    end
    boop.stats.pendingAttack = nil
    boop.stats.lastResolvedAttack = nil
    seedBaselinesFromStatus()
    boop.util.ok("stats reset: login")
    return
  end

  if key == "lifetime" or key == "life" then
    boop.stats.lifetime = resetScopeData(nil, now)
    if boopActive then
      scopeStart(boop.stats.lifetime, now)
      startAreaTracking(boop.stats.lifetime, currentArea(), now)
    end
    boop.stats.mobXp = {}
    boop.stats.pendingAttack = nil
    boop.stats.lastResolvedAttack = nil
    seedBaselinesFromStatus()
    if boop.db and boop.db.clearMobXpStats then
      boop.db.clearMobXpStats()
    end
    persistLifetime()
    boop.util.ok("stats reset: lifetime")
    return
  end

  boop.util.info("Usage: boop stats reset <session|login|trip|lifetime|all>")
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
    "%s rates: %s kills/hr | %s targets/hr | %s rooms/hr | %s gold/hr | %s%% xp/hr | %s xp/hr",
    label,
    formatNumber(perHour(scope.kills, elapsed), 1),
    formatNumber(perHour(scope.targets, elapsed), 1),
    formatNumber(perHour(scope.roomMoves, elapsed), 1),
    formatNumber(perHour(scope.gold, elapsed), 1),
    formatNumber(perHour(scope.experience, elapsed), 2),
    formatNumber(perHour(scope.rawExperience or 0, elapsed), 1)
  ))
  boop.util.info(string.format(
    "%s friction: %d retargets | %d abandoned | %d room moves | %d flees",
    label, scope.retargets, scope.abandoned, scope.roomMoves, scope.flees
  ))
end

local function formatScopeMeta(scope)
  local meta = scope and scope.meta or {}
  return string.format(
    "mode %s | class %s | p%d | area %s",
    tostring(meta.attackMode or "simple"),
    tostring(meta.class or "unknown"),
    tonumber(meta.partySize) or 1,
    tostring(meta.area or "UNKNOWN")
  )
end

local function rageDecisionFingerprint(info)
  if type(info) ~= "table" then
    return ""
  end
  local ability = type(info.ability) == "table" and (info.ability.name or info.ability.skill or "") or tostring(info.ability or "")
  return table.concat({
    tostring(info.mode or ""),
    tostring(info.outcome or ""),
    tostring(info.targetId or (boop.state and boop.state.currentTargetId) or ""),
    tostring(ability),
  }, "|")
end

function boop.stats.onRageDecision(info)
  if type(info) ~= "table" then
    return
  end
  local now = nowSeconds()
  local fingerprint = rageDecisionFingerprint(info)
  local last = boop.stats.lastRageDecision
  if fingerprint ~= "" and last and last.fingerprint == fingerprint and (now - (tonumber(last.at) or 0)) < 0.4 then
    return
  end
  boop.stats.lastRageDecision = { fingerprint = fingerprint, at = now }

  local mode = boop.util.safeLower(info.mode or "simple")
  local outcome = boop.util.safeLower(info.outcome or "")
  eachActiveScope(function(scope)
    local rage = ensureRageStats(scope)
    rage.decisions = rage.decisions + 1
    rage.byOutcome[outcome] = (tonumber(rage.byOutcome[outcome]) or 0) + 1
    if outcome == "suppressed" then
      rage.suppressed = rage.suppressed + 1
    end
    if outcome == "combo_hold" or outcome == "big_hold" then
      rage.holds = rage.holds + 1
    end
  end)
end

function boop.stats.onRageExecuted(ability, info)
  if not ability then
    return
  end

  local mode = boop.util.safeLower((info and info.mode) or (boop.config and boop.config.attackMode) or "simple")
  local outcome = boop.util.safeLower((info and info.outcome) or "")
  local desc = tostring(ability.desc or "")
  local name = tostring(ability.name or ability.skill or "")
  local cost = tonumber(ability.rage) or 0

  eachActiveScope(function(scope)
    local rage = ensureRageStats(scope)
    rage.uses = rage.uses + 1
    rage.totalCost = rage.totalCost + cost
    rage.byMode[mode] = (tonumber(rage.byMode[mode]) or 0) + 1
    rage.byDesc[desc] = (tonumber(rage.byDesc[desc]) or 0) + 1
    rage.byAbility[name] = (tonumber(rage.byAbility[name]) or 0) + 1
    if desc == "Shieldbreak" then
      rage.shieldbreaks = rage.shieldbreaks + 1
    end
    if outcome == "combo_conditional" then
      rage.comboConditional = rage.comboConditional + 1
    elseif outcome == "combo_primer" or outcome == "combo_party_primer" then
      rage.comboPrimers = rage.comboPrimers + 1
    elseif outcome == "combo_fallback" or outcome == "combo_spend_overflow" or outcome == "hybrid_fallback" then
      rage.comboFallbacks = rage.comboFallbacks + 1
    elseif outcome == "tempo_aff" then
      rage.tempoAffs = rage.tempoAffs + 1
    elseif outcome == "tempo_squeeze" then
      rage.tempoSqueezes = rage.tempoSqueezes + 1
    elseif outcome == "tempo_fallback" then
      rage.tempoFallbacks = rage.tempoFallbacks + 1
    end
  end)
  persistLifetime()
end

local function topCounts(map, limit)
  local rows = {}
  for key, count in pairs(map or {}) do
    local n = tonumber(count) or 0
    if n > 0 then
      rows[#rows + 1] = { key = key, count = n }
    end
  end
  table.sort(rows, function(a, b)
    if a.count == b.count then
      return boop.util.safeLower(a.key) < boop.util.safeLower(b.key)
    end
    return a.count > b.count
  end)
  local pieces = {}
  local maxRows = tonumber(limit) or 4
  for i = 1, math.min(#rows, maxRows) do
    pieces[#pieces + 1] = string.format("%s %d", rows[i].key, rows[i].count)
  end
  return pieces
end

function boop.stats.showRage(scopeName)
  local scope, label = scopeByName(scopeName)
  local rage = ensureRageStats(scope)
  local avgCost = rage.uses > 0 and (rage.totalCost / rage.uses) or 0
  boop.util.info(string.format(
    "%s rage: %d decisions | %d uses | %d rage spent | avg cost %s | holds %d | suppressed %d | shieldbreaks %d",
    label,
    rage.decisions,
    rage.uses,
    rage.totalCost,
    formatStatValue(avgCost, 1),
    rage.holds,
    rage.suppressed,
    rage.shieldbreaks
  ))
  boop.util.info(string.format(
    "%s rage flow: combo cond %d | combo prime %d | combo fallback %d | tempo aff %d | tempo squeeze %d | tempo fallback %d",
    label,
    rage.comboConditional,
    rage.comboPrimers,
    rage.comboFallbacks,
    rage.tempoAffs,
    rage.tempoSqueezes,
    rage.tempoFallbacks
  ))
  local modeBits = topCounts(rage.byMode, 5)
  boop.util.info(string.format("%s rage modes: %s", label, #modeBits > 0 and table.concat(modeBits, " | ") or "(none)"))
  local abilityBits = topCounts(rage.byAbility, 5)
  boop.util.info(string.format("%s rage abilities: %s", label, #abilityBits > 0 and table.concat(abilityBits, " | ") or "(none)"))
end

local function aggregateCrits(scope)
  local totals = {
    uses = 0,
    crits = 0,
    tiers = {
      ["2xCRIT"] = 0,
      ["4xCRIT"] = 0,
      ["8xCRIT"] = 0,
      ["16xCRIT"] = 0,
      ["32xCRIT"] = 0,
    },
  }

  for _, entry in pairs(scope.abilities or {}) do
    totals.uses = totals.uses + (tonumber(entry.uses) or 0)
    totals.crits = totals.crits + (tonumber(entry.crits) or 0)
    for tier, count in pairs(entry.critTiers or {}) do
      totals.tiers[tier] = (tonumber(totals.tiers[tier]) or 0) + (tonumber(count) or 0)
    end
  end

  return totals
end

local function topAreaRow(scope)
  local best = nil
  for area, data in pairs(scope.areas or {}) do
    local elapsed = elapsedFor(data)
    local kills = tonumber(data.kills) or 0
    local rawXp = tonumber(data.rawExperience) or 0
    local killsPerHour = perHour(kills, elapsed)
    local rawXpPerHour = perHour(rawXp, elapsed)
    if kills > 0 or rawXp > 0 then
      local row = {
        area = area,
        kills = kills,
        killsPerHour = killsPerHour,
        rawXpPerHour = rawXpPerHour,
      }
      if not best
        or row.rawXpPerHour > best.rawXpPerHour
        or (math.abs(row.rawXpPerHour - best.rawXpPerHour) < 0.000001 and row.killsPerHour > best.killsPerHour)
      then
        best = row
      end
    end
  end
  return best
end

local function topAbilityRow(scope)
  local best = nil
  for ability, entry in pairs(scope.abilities or {}) do
    local uses = tonumber(entry.uses) or 0
    local kills = tonumber(entry.kills) or 0
    if uses > 0 then
      local row = {
        ability = ability,
        kills = kills,
        avgDamage = (tonumber(entry.hitsWithDamage) or 0) > 0 and ((tonumber(entry.totalDamage) or 0) / (tonumber(entry.hitsWithDamage) or 1)) or 0,
        critRate = uses > 0 and ((tonumber(entry.crits) or 0) * 100 / uses) or 0,
      }
      if not best
        or row.kills > best.kills
        or (row.kills == best.kills and row.avgDamage > best.avgDamage)
      then
        best = row
      end
    end
  end
  return best
end

local function topTargetRow(scope, area, partySize)
  local buckets = aggregatedTargetEntries(scope, area, partySize)
  local best = nil
  for name, entry in pairs(buckets or {}) do
    local kills = tonumber(entry.kills) or 0
    if kills > 0 then
      local row = {
        name = name,
        kills = kills,
        avgTtk = kills > 0 and ((tonumber(entry.totalTtk) or 0) / kills) or 0,
        avgRawXp = kills > 0 and ((tonumber(entry.rawExperience) or 0) / kills) or 0,
      }
      if not best
        or row.kills > best.kills
        or (row.kills == best.kills and row.avgRawXp > best.avgRawXp)
      then
        best = row
      end
    end
  end
  return best
end

local function topTargetAnyArea(scope, partySize)
  local merged = {}
  local sizeKey = tonumber(partySize) or currentPartySize()
  for areaName, bySize in pairs(scope.targetStats or {}) do
    local areaBuckets = bySize and bySize[sizeKey] or {}
    for rawName, entry in pairs(areaBuckets or {}) do
      local name = normalizeTrackedMobName(rawName)
      if name ~= "" then
        merged[name] = mergeTargetEntry(merged[name], entry)
      end
    end
  end

  local best = nil
  for name, entry in pairs(merged) do
    local kills = tonumber(entry.kills) or 0
    if kills > 0 then
      local row = {
        name = name,
        kills = kills,
        avgTtk = kills > 0 and ((tonumber(entry.totalTtk) or 0) / kills) or 0,
        avgRawXp = kills > 0 and ((tonumber(entry.rawExperience) or 0) / kills) or 0,
      }
      if not best
        or row.kills > best.kills
        or (row.kills == best.kills and row.avgRawXp > best.avgRawXp)
      then
        best = row
      end
    end
  end
  return best
end

local function scopeHasActivity(scope)
  scope = ensureScope(scope)
  if (tonumber(scope.kills) or 0) > 0 then return true end
  if (tonumber(scope.gold) or 0) > 0 then return true end
  if (tonumber(scope.rawExperience) or 0) > 0 then return true end
  if (tonumber(scope.targets) or 0) > 0 then return true end
  for _, data in pairs(scope.areas or {}) do
    if (tonumber(data.kills) or 0) > 0 or (tonumber(data.rawExperience) or 0) > 0 or (tonumber(data.gold) or 0) > 0 then
      return true
    end
  end
  return false
end

local function scopeSummaryLine(scope, label)
  local elapsed = elapsedFor(scope)
  return string.format(
    "%s: %d kills | %d gold | %d xp | %s kills/hr | avg ttk %ss",
    label,
    tonumber(scope.kills) or 0,
    tonumber(scope.gold) or 0,
    tonumber(scope.rawExperience) or 0,
    formatStatValue(perHour(scope.kills, elapsed), 1),
    formatNumber(avgTtk(scope), 2)
  )
end

function boop.stats.showCrits(scopeName)
  local scope, label = scopeByName(scopeName)
  local totals = aggregateCrits(scope)
  local rate = totals.uses > 0 and (totals.crits * 100 / totals.uses) or 0
  boop.util.info(string.format(
    "%s crits: %d crits across %d uses (%s%%)",
    label,
    totals.crits,
    totals.uses,
    formatStatValue(rate, 1)
  ))
  boop.util.info(string.format(
    "%s crit tiers: 2x %d | 4x %d | 8x %d | 16x %d | 32x %d",
    label,
    tonumber(totals.tiers["2xCRIT"]) or 0,
    tonumber(totals.tiers["4xCRIT"]) or 0,
    tonumber(totals.tiers["8xCRIT"]) or 0,
    tonumber(totals.tiers["16xCRIT"]) or 0,
    tonumber(totals.tiers["32xCRIT"]) or 0
  ))
end

function boop.stats.showRecords(scopeName)
  local scope, label = scopeByName(scopeName)
  local records = scope.records or {}
  local bestHit = records.bestHit
  local fastest = records.fastestKill
  local slowest = records.slowestKill

  boop.util.info(string.format("%s records:", label))
  if bestHit then
    local critText = boop.util.trim(bestHit.critTier or "")
    if critText ~= "" then
      critText = " | " .. critText
    end
    boop.util.info(string.format(
      "  best hit: %s dmg | %s -> %s | %s | p%d%s",
      formatStatValue(bestHit.damage, 1),
      tostring(bestHit.ability or "Attack"),
      tostring(bestHit.target or "(unknown)"),
      tostring(bestHit.area or "UNKNOWN"),
      tonumber(bestHit.partySize) or 1,
      critText
    ))
  else
    boop.util.info("  best hit: (none)")
  end

  if fastest then
    boop.util.info(string.format(
      "  fastest kill: %ss | %s | %s | p%d",
      formatStatValue(fastest.ttk, 2),
      tostring(fastest.target or "(unknown)"),
      tostring(fastest.area or "UNKNOWN"),
      tonumber(fastest.partySize) or 1
    ))
  else
    boop.util.info("  fastest kill: (none)")
  end

  if slowest then
    boop.util.info(string.format(
      "  slowest kill: %ss | %s | %s | p%d",
      formatStatValue(slowest.ttk, 2),
      tostring(slowest.target or "(unknown)"),
      tostring(slowest.area or "UNKNOWN"),
      tonumber(slowest.partySize) or 1
    ))
  else
    boop.util.info("  slowest kill: (none)")
  end
end

function boop.stats.showAreas(scopeName, limit, sortKey)
  local scope, label = scopeByName(scopeName)
  local rows = {}
  for area, data in pairs(scope.areas or {}) do
    local elapsed = elapsedFor(data)
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
        killsPerHour = perHour(tonumber(data.kills) or 0, elapsed),
        goldPerHour = perHour(tonumber(data.gold) or 0, elapsed),
        rawXpPerHour = perHour(tonumber(data.rawExperience) or 0, elapsed),
        elapsed = elapsed,
      }
    end
  end

  local sortMode = boop.util.safeLower(sortKey or "")
  if sortMode == "" then
    sortMode = "killshr"
  end
  table.sort(rows, function(a, b)
    local left
    local right
    if sortMode == "gold" then
      left, right = a.gold, b.gold
    elseif sortMode == "rawxp" or sortMode == "xp" then
      left, right = a.rawExperience, b.rawExperience
    elseif sortMode == "goldhr" then
      left, right = a.goldPerHour, b.goldPerHour
    elseif sortMode == "rawxphr" or sortMode == "xphr" then
      left, right = a.rawXpPerHour, b.rawXpPerHour
    elseif sortMode == "ttk" then
      left, right = a.avgTtk, b.avgTtk
    else
      left, right = a.killsPerHour, b.killsPerHour
    end
    if math.abs((left or 0) - (right or 0)) < 0.000001 then
      return boop.util.safeLower(a.area) < boop.util.safeLower(b.area)
    end
    if sortMode == "ttk" then
      return left < right
    end
    return left > right
  end)

  local maxRows = tonumber(limit) or 5
  if maxRows < 1 then maxRows = 1 end
  boop.util.info(string.format("%s areas (sorted by %s):", label, sortMode))
  if #rows == 0 then
    boop.util.info("  (no area activity yet)")
    return
  end
  for i = 1, math.min(#rows, maxRows) do
    local row = rows[i]
    boop.util.info(string.format(
      "  %d. %s | %d kills | %s kills/hr | %d gold | %s gold/hr | %d xp | %s xp/hr | avg ttk %ss",
      i,
      row.area,
      row.kills,
      formatNumber(row.killsPerHour, 1),
      row.gold,
      formatNumber(row.goldPerHour, 1),
      row.rawExperience,
      formatNumber(row.rawXpPerHour, 1),
      formatNumber(row.avgTtk, 2)
    ))
  end
end

function boop.stats.getMobXp(area, name, partySize)
  local cleanArea = tostring(area or "")
  local rawName = boop.util.trim(tostring(name or ""))
  local size = tonumber(partySize) or currentPartySize()
  if size < 1 then size = 1 end
  if cleanArea == "" or rawName == "" then
    return nil
  end

  local cleanName = normalizeTrackedMobName(rawName)
  if cleanName == "" or cleanName ~= rawName then
    return nil
  end
  return aggregatedMobEntries(cleanArea, size)[cleanName]
end

function boop.stats.formatMobXp(area, name, partySize)
  local size = tonumber(partySize) or currentPartySize()
  if size < 1 then size = 1 end
  return formatMobXpSummary(boop.stats.getMobXp(area, name, size), size)
end

function boop.stats.showMobs(areaName, limit)
  local area = boop.util.trim(areaName or "")
  if area == "" then
    area = currentArea()
  end
  local partySize = currentPartySize()

  local areaMobs = aggregatedMobEntries(area, partySize)
  local rows = {}
  for name, entry in pairs(areaMobs) do
    if (tonumber(entry.observations) or 0) > 0 then
      local modeXp, modeCount = modeMobXp(entry)
      rows[#rows + 1] = {
        name = name,
        observations = tonumber(entry.observations) or 0,
        mean = meanMobXp(entry),
        median = medianMobXp(entry),
        mode = modeXp,
        modeCount = modeCount,
      }
    end
  end

  table.sort(rows, function(a, b)
    if a.mean == b.mean then
      return boop.util.safeLower(a.name) < boop.util.safeLower(b.name)
    end
    return a.mean > b.mean
  end)

  local maxRows = tonumber(limit) or 10
  if maxRows < 1 then maxRows = 1 end
  boop.util.info(string.format("mob xp stats for %s (party size %d):", area, partySize))
  if #rows == 0 then
    boop.util.info("  (no observed mob xp yet)")
    return
  end
  for i = 1, math.min(#rows, maxRows) do
    local row = rows[i]
    boop.util.info(string.format(
      "  %d. %s | seen %d | mean %s | median %s | mode %s (%dx)",
      i,
      row.name,
      row.observations,
      formatStatValue(row.mean, 1),
      formatStatValue(row.median, 1),
      formatStatValue(row.mode, 1),
      tonumber(row.modeCount) or 0
    ))
  end
end

function boop.stats.showTargets(scopeName, limit)
  local scope, label = scopeByName(scopeName)
  local area = currentArea()
  local partySize = currentPartySize()
  local buckets = aggregatedTargetEntries(scope, area, partySize)
  local rows = {}

  for name, entry in pairs(buckets) do
    local kills = tonumber(entry.kills) or 0
    if kills > 0 then
      local xpEntry = boop.stats.getMobXp(area, name, partySize)
      local modeXp, modeCount = modeMobXp(xpEntry or {})
      rows[#rows + 1] = {
        name = name,
        kills = kills,
        avgTtk = kills > 0 and ((tonumber(entry.totalTtk) or 0) / kills) or 0,
        bestTtk = tonumber(entry.bestTtk) or 0,
        worstTtk = tonumber(entry.worstTtk) or 0,
        gold = tonumber(entry.gold) or 0,
        rawExperience = tonumber(entry.rawExperience) or 0,
        bestGold = tonumber(entry.bestGold) or 0,
        bestRawExperience = tonumber(entry.bestRawExperience) or 0,
        meanXp = meanMobXp(xpEntry),
        medianXp = medianMobXp(xpEntry),
        modeXp = modeXp,
        modeCount = tonumber(modeCount) or 0,
      }
    end
  end

  table.sort(rows, function(a, b)
    if a.kills == b.kills then
      if a.meanXp == b.meanXp then
        return boop.util.safeLower(a.name) < boop.util.safeLower(b.name)
      end
      return a.meanXp > b.meanXp
    end
    return a.kills > b.kills
  end)

  local maxRows = tonumber(limit) or 10
  if maxRows < 1 then maxRows = 1 end
  boop.util.info(string.format("%s target stats for %s (party size %d):", label, area, partySize))
  if #rows == 0 then
    boop.util.info("  (no recorded target kills yet)")
    return
  end

  for i = 1, math.min(#rows, maxRows) do
    local row = rows[i]
    local xpText = row.meanXp > 0 and string.format(
      " | xp mean %s | median %s | mode %s (%dx)",
      formatStatValue(row.meanXp, 1),
      formatStatValue(row.medianXp, 1),
      formatStatValue(row.modeXp, 1),
      tonumber(row.modeCount) or 0
    ) or ""
    local rewardText = ""
    if row.gold > 0 or row.rawExperience > 0 then
      rewardText = string.format(
        " | avg gold %s | avg raw xp %s",
        formatStatValue(row.kills > 0 and (row.gold / row.kills) or 0, 1),
        formatStatValue(row.kills > 0 and (row.rawExperience / row.kills) or 0, 1)
      )
      if row.bestGold > 0 then
        rewardText = rewardText .. string.format(" | best gold %s", formatStatValue(row.bestGold, 1))
      end
      if row.bestRawExperience > 0 then
        rewardText = rewardText .. string.format(" | best raw xp %s", formatStatValue(row.bestRawExperience, 1))
      end
    end
    boop.util.info(string.format(
      "  %d. %s | kills %d | avg ttk %ss | best %ss | worst %ss%s%s",
      i,
      row.name,
      row.kills,
      formatStatValue(row.avgTtk, 2),
      formatStatValue(row.bestTtk, 2),
      formatStatValue(row.worstTtk, 2),
      rewardText,
      xpText
    ))
  end
end

function boop.stats.showAbilities(scopeName, limit)
  local scope, label = scopeByName(scopeName)
  local rows = {}
  for ability, entry in pairs(scope.abilities or {}) do
    local uses = tonumber(entry.uses) or 0
    if uses > 0 then
      local bestCrit = ""
      local bestCritRank = 0
      for tier, count in pairs(entry.critTiers or {}) do
        if (tonumber(count) or 0) > 0 then
          local rank = critTierRank(tier)
          if rank > bestCritRank then
            bestCritRank = rank
            bestCrit = tier
          end
        end
      end
      rows[#rows + 1] = {
        ability = ability,
        uses = uses,
        kills = tonumber(entry.kills) or 0,
        avgDamage = (tonumber(entry.hitsWithDamage) or 0) > 0 and ((tonumber(entry.totalDamage) or 0) / (tonumber(entry.hitsWithDamage) or 1)) or 0,
        maxDamage = tonumber(entry.maxDamage) or 0,
        critRate = uses > 0 and ((tonumber(entry.crits) or 0) * 100 / uses) or 0,
        avgBalance = (tonumber(entry.balances) or 0) > 0 and ((tonumber(entry.totalBalance) or 0) / (tonumber(entry.balances) or 1)) or 0,
        bestCrit = bestCrit,
      }
    end
  end

  table.sort(rows, function(a, b)
    if a.kills == b.kills then
      if a.maxDamage == b.maxDamage then
        return boop.util.safeLower(a.ability) < boop.util.safeLower(b.ability)
      end
      return a.maxDamage > b.maxDamage
    end
    return a.kills > b.kills
  end)

  local maxRows = tonumber(limit) or 10
  if maxRows < 1 then maxRows = 1 end
  boop.util.info(string.format("%s ability stats:", label))
  if #rows == 0 then
    boop.util.info("  (no recorded ability usage yet)")
    return
  end

  for i = 1, math.min(#rows, maxRows) do
    local row = rows[i]
    local critText = row.bestCrit ~= "" and (" | best crit " .. row.bestCrit) or ""
    boop.util.info(string.format(
      "  %d. %s | uses %d | kills %d | avg dmg %s | max dmg %s | crit %s%% | avg bal %ss%s",
      i,
      row.ability,
      row.uses,
      row.kills,
      formatStatValue(row.avgDamage, 1),
      formatStatValue(row.maxDamage, 1),
      formatStatValue(row.critRate, 1),
      formatStatValue(row.avgBalance, 2),
      critText
    ))
  end
end

local function compareLine(name, left, right, decimals)
  left = tonumber(left) or 0
  right = tonumber(right) or 0
  local delta = left - right
  local percent = right ~= 0 and ((delta / right) * 100) or nil
  local deltaText = (delta >= 0 and "+" or "") .. formatStatValue(delta, decimals)
  local percentText = percent and string.format(" | %s%%", (percent >= 0 and "+" or "") .. formatStatValue(percent, 1)) or ""
  return string.format("%s: %s vs %s (%s%s)", name, formatStatValue(left, decimals), formatStatValue(right, decimals), deltaText, percentText)
end

local function compareSummaryBits(leftScope, rightScope)
  leftScope = ensureScope(leftScope)
  rightScope = ensureScope(rightScope)
  local leftElapsed = elapsedFor(leftScope)
  local rightElapsed = elapsedFor(rightScope)
  return {
    compareLine("kills", leftScope.kills, rightScope.kills, 0),
    compareLine("gold", leftScope.gold, rightScope.gold, 0),
    compareLine("raw xp", leftScope.rawExperience or 0, rightScope.rawExperience or 0, 0),
    compareLine("avg ttk", avgTtk(leftScope), avgTtk(rightScope), 2),
    compareLine("kills/hr", perHour(leftScope.kills, leftElapsed), perHour(rightScope.kills, rightElapsed), 1),
    compareLine("gold/hr", perHour(leftScope.gold, leftElapsed), perHour(rightScope.gold, rightElapsed), 1),
    compareLine("xp/hr", perHour(leftScope.rawExperience or 0, leftElapsed), perHour(rightScope.rawExperience or 0, rightElapsed), 1),
    compareLine("retargets", leftScope.retargets, rightScope.retargets, 0),
    compareLine("flees", leftScope.flees, rightScope.flees, 0),
  }
end

function boop.stats.showCompare(leftName, rightName)
  local leftScope, leftLabel = scopeByName(leftName)
  local rightScope, rightLabel = scopeByName(rightName)
  leftScope = ensureScope(leftScope)
  rightScope = ensureScope(rightScope)

  boop.util.info(string.format(
    "compare %s vs %s: %s || %s",
    leftLabel,
    rightLabel,
    formatScopeMeta(leftScope),
    formatScopeMeta(rightScope)
  ))
  for _, line in ipairs(compareSummaryBits(leftScope, rightScope)) do
    boop.util.info(line)
  end
end

function boop.stats.showDashboard()
  local area = currentArea()
  local partySize = currentPartySize()
  local session = ensureScope(boop.stats.session)
  local trip = ensureScope(boop.stats.trip)
  local lifetime = ensureScope(boop.stats.lifetime)
  local lastTrip = ensureScope(boop.stats.lastTrip)
  local focusScope = session
  local focusLabel = "session"
  if not scopeHasActivity(focusScope) and scopeHasActivity(trip) then
    focusScope = trip
    focusLabel = "trip"
  end
  if not scopeHasActivity(focusScope) and scopeHasActivity(lifetime) then
    focusScope = lifetime
    focusLabel = "lifetime"
  end
  local bestArea = topAreaRow(focusScope)
  local bestTarget = (area ~= "" and area ~= "UNKNOWN") and topTargetRow(focusScope, area, partySize) or nil
  if not bestTarget then
    bestTarget = topTargetAnyArea(focusScope, partySize)
  end
  local bestAbility = topAbilityRow(focusScope)
  local tripState = trip.stopwatch and "running" or "idle"
  local compareBits = compareSummaryBits(trip, lastTrip)
  local hasTripCompare = scopeHasActivity(trip) or scopeHasActivity(lastTrip)
  local shownArea = area
  if shownArea == "" or shownArea == "UNKNOWN" then
    shownArea = "(unknown)"
  end

  boop.util.info("stats dashboard:")
  boop.util.info(string.format("  hunt: %s | area %s | party size %d", tripState, shownArea, partySize))
  if scopeHasActivity(session) then
    boop.util.info("  " .. scopeSummaryLine(session, "session"))
  else
    boop.util.info("  session: no activity yet")
  end
  if scopeHasActivity(trip) then
    boop.util.info("  " .. scopeSummaryLine(trip, "trip") .. " | " .. tripState)
  else
    boop.util.info("  trip: no activity yet")
  end
  boop.util.info("  " .. scopeSummaryLine(lifetime, "lifetime"))
  if bestArea then
    boop.util.info(string.format(
      "  best %s area: %s | %s kills/hr | %s xp/hr",
      focusLabel,
      bestArea.area,
      formatStatValue(bestArea.killsPerHour, 1),
      formatStatValue(bestArea.rawXpPerHour, 1)
    ))
  else
    boop.util.info(string.format("  best %s area: (none yet)", focusLabel))
  end
  if bestTarget then
    boop.util.info(string.format(
      "  top %s target: %s | kills %d | avg ttk %ss | avg raw xp %s",
      focusLabel,
      bestTarget.name,
      bestTarget.kills,
      formatNumber(bestTarget.avgTtk, 2),
      formatStatValue(bestTarget.avgRawXp, 1)
    ))
  else
    boop.util.info(string.format("  top %s target: (none yet)", focusLabel))
  end
  if bestAbility then
    boop.util.info(string.format(
      "  top %s ability: %s | kills %d | avg dmg %s | crit %s%%",
      focusLabel,
      bestAbility.ability,
      bestAbility.kills,
      formatStatValue(bestAbility.avgDamage, 1),
      formatStatValue(bestAbility.critRate, 1)
    ))
  else
    boop.util.info(string.format("  top %s ability: (none yet)", focusLabel))
  end
  if hasTripCompare then
    boop.util.info("  compare trip vs lasttrip:")
    boop.util.info("    " .. compareBits[1])
    boop.util.info("    " .. compareBits[3])
    boop.util.info("    " .. compareBits[4])
    boop.util.info("    " .. compareBits[7])
  else
    boop.util.info("  trip compare: (no completed trips yet)")
  end
  boop.util.info("  next views:")
  if scopeHasActivity(trip) then
    boop.util.info("    boop stats compare trip lasttrip")
    boop.util.info("    boop stats areas trip 5 xp")
    boop.util.info("    boop stats targets trip 5")
    boop.util.info("    boop stats abilities trip 5")
    boop.util.info("    boop stats rage trip")
  elseif focusLabel == "lifetime" then
    boop.util.info("    boop stats lifetime")
    boop.util.info("    boop stats areas lifetime 5 xp")
    boop.util.info("    boop stats abilities lifetime 5")
    boop.util.info("    boop stats crits lifetime")
    boop.util.info("    boop trip start")
  else
    boop.util.info("    boop on")
    boop.util.info("    boop trip start")
    boop.util.info("    boop stats lifetime")
    boop.util.info("    boop stats areas lifetime 5 xp")
    boop.util.info("    boop stats abilities lifetime 5")
  end
end

function boop.stats.showHelp()
  boop.util.info("stats help:")
  boop.util.info("  boop stats            -> dashboard")
  boop.util.info("  boop stats session    -> session totals and rates")
  boop.util.info("  boop stats login      -> current-login totals across boop toggles")
  boop.util.info("  boop stats areas      -> ranked area performance")
  boop.util.info("  boop stats targets    -> target efficiency in current area")
  boop.util.info("  boop stats abilities  -> attack usage and damage")
  boop.util.info("  boop stats rage       -> rage-mode efficiency")
  boop.util.info("  boop stats compare    -> compare trip vs lasttrip by default")
  boop.util.info("  boop stats reset all  -> clear stored stats")
end

function boop.stats.command(raw)
  local text = boop.util.trim(raw or "")
  local first, rest = text:match("^(%S+)%s*(.-)$")
  local cmd = boop.util.safeLower(first or "")
  local arg = boop.util.trim(rest or "")

  if cmd == "" then
    boop.stats.showDashboard()
    return
  end

  if cmd == "help" or cmd == "?" then
    boop.stats.showHelp()
    return
  end

  if cmd == "show" then
    if arg == "" then
      boop.stats.showDashboard()
      return
    end
    boop.stats.show(arg)
    return
  end

  if cmd == "session" or cmd == "login" or cmd == "trip" or cmd == "lifetime" or cmd == "lasttrip" or cmd == "last" then
    boop.stats.show(cmd)
    return
  end

  if cmd == "reset" then
    boop.stats.reset(arg ~= "" and arg or "session")
    return
  end

  if cmd == "areas" then
    local scope, limit, metric = arg:match("^(%S+)%s+(%d+)%s+(%S+)$")
    if scope then
      boop.stats.showAreas(scope, tonumber(limit), metric)
      return
    end
    scope, limit = arg:match("^(%S+)%s+(%d+)$")
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

  if cmd == "mobs" then
    local targetArea, limit = arg:match("^(.-)%s+(%d+)$")
    if targetArea and boop.util.trim(targetArea) ~= "" then
      boop.stats.showMobs(targetArea, tonumber(limit))
      return
    end
    local maybeNumber = tonumber(arg)
    if maybeNumber then
      boop.stats.showMobs(currentArea(), maybeNumber)
      return
    end
    boop.stats.showMobs(arg ~= "" and arg or currentArea())
    return
  end

  if cmd == "abilities" or cmd == "attacks" then
    local scope, limit = arg:match("^(%S+)%s+(%d+)$")
    if scope then
      boop.stats.showAbilities(scope, tonumber(limit))
      return
    end
    local maybeNumber = tonumber(arg)
    if maybeNumber then
      boop.stats.showAbilities("session", maybeNumber)
      return
    end
    boop.stats.showAbilities(arg ~= "" and arg or "session")
    return
  end

  if cmd == "targets" or cmd == "mobsummary" then
    local scope, limit = arg:match("^(%S+)%s+(%d+)$")
    if scope then
      boop.stats.showTargets(scope, tonumber(limit))
      return
    end
    local maybeNumber = tonumber(arg)
    if maybeNumber then
      boop.stats.showTargets("session", maybeNumber)
      return
    end
    boop.stats.showTargets(arg ~= "" and arg or "session")
    return
  end

  if cmd == "crits" then
    boop.stats.showCrits(arg ~= "" and arg or "session")
    return
  end

  if cmd == "rage" then
    boop.stats.showRage(arg ~= "" and arg or "session")
    return
  end

  if cmd == "records" then
    boop.stats.showRecords(arg ~= "" and arg or "session")
    return
  end

  if cmd == "compare" then
    local left, right = arg:match("^(%S+)%s+(%S+)$")
    if left and right then
      boop.stats.showCompare(left, right)
      return
    end
    boop.stats.showCompare("trip", "lasttrip")
    return
  end

  boop.util.info("Usage: boop stats [help|session|login|trip|lifetime|lasttrip|areas [scope] [limit] [metric]|mobs [area] [limit]|targets [scope] [limit]|abilities [scope] [limit]|crits [scope]|rage [scope]|records [scope]|compare [left] [right]|reset <session|login|trip|lifetime|all>]")
end

function boop.stats.startTrip()
  if boop.stats.trip.stopwatch then
    boop.util.warn("Trip already running.")
    return
  end
  local now = nowSeconds()
  boop.stats.trip = newScope(now)
  scopeStart(boop.stats.trip, now)
  startAreaTracking(boop.stats.trip, currentArea(), now)
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
  local now = nowSeconds()
  stopAreaTracking(boop.stats.trip, now)
  scopeStop(boop.stats.trip, now)
  if boop.stats.cloneScope then
    boop.stats.lastTrip = boop.stats.cloneScope(boop.stats.trip)
    if boop.stats.lastTrip then
      boop.stats.lastTrip.stopwatch = nil
    end
  end
  boop.util.ok("Stopped hunting trip.")
  boop.stats.show("trip")
  boop.stats.trip.stopwatch = nil
end
