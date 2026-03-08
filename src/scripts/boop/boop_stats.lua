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

local function ensureTargetEntry(scope, area, partySize, name)
  scope = ensureScope(scope)
  local areaKey = tostring(area or "UNKNOWN")
  local sizeKey = tonumber(partySize) or 1
  if sizeKey < 1 then sizeKey = 1 end
  local nameKey = boop.util.trim(tostring(name or ""))
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
  }

  local entry = scope.targetStats[areaKey][sizeKey][nameKey]
  entry.kills = tonumber(entry.kills) or 0
  entry.totalTtk = tonumber(entry.totalTtk) or 0
  entry.bestTtk = entry.bestTtk ~= nil and tonumber(entry.bestTtk) or nil
  entry.worstTtk = entry.worstTtk ~= nil and tonumber(entry.worstTtk) or nil
  entry.lastTtk = entry.lastTtk ~= nil and tonumber(entry.lastTtk) or nil
  return entry
end

local function eachScope(fn)
  fn(boop.stats.session)
  fn(boop.stats.trip)
  fn(boop.stats.lifetime)
end

local function eachActiveScope(fn)
  if boop.stats.session and boop.stats.session.activeSince then
    fn(boop.stats.session)
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

local function addGold(delta, area)
  if not delta or delta <= 0 then return end
  eachActiveScope(function(scope)
    withArea(scope, area, function(bucket)
      bucket.gold = bucket.gold + delta
    end)
  end)
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
  local key = tostring(name or "")
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
  end)
end

local function findMobXpTarget(area)
  local active = boop.stats.activeTarget
  if active then
    local activeArea = boop.util.trim(active.area or area or "")
    local activeName = boop.util.trim(active.name or "")
    if activeArea ~= "" and activeName ~= "" then
      return activeArea, activeName
    end
  end

  local lastKill = boop.stats.lastKill
  if lastKill and nowSeconds() - (tonumber(lastKill.at) or 0) <= 5 then
    local killArea = boop.util.trim(lastKill.area or area or "")
    local killName = boop.util.trim(lastKill.name or "")
    if killArea ~= "" and killName ~= "" then
      return killArea, killName
    end
  end

  return nil, nil
end

local function observeMobXp(area, name, amount, partySize)
  local cleanArea = boop.util.trim(area or "")
  local cleanName = boop.util.trim(name or "")
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
  boop.stats.trip = ensureScope(boop.stats.trip, now)
  boop.stats.lifetime = ensureScope(boop.stats.lifetime, now)
  boop.stats.mobXp = boop.stats.mobXp or {}
  boop.stats.lastGold = nil
  boop.stats.lastXp = nil
  boop.stats.activeTarget = boop.stats.activeTarget or nil
  boop.stats.lastKill = boop.stats.lastKill or nil
  boop.stats.pendingAttack = nil
  boop.stats.lastResolvedAttack = nil
  if boop.config and boop.config.enabled then
    scopeStart(boop.stats.session, now)
    scopeStart(boop.stats.lifetime, now)
  else
    scopeStop(boop.stats.session, now)
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
  local name = boop.util.trim(targetName or current.name or "")
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
  incrementCounter("roomMoves", currentArea())
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
    local mobArea, mobName = findMobXpTarget(resolvedArea)
    if mobArea and mobName then
      observeMobXp(mobArea, mobName, gained, currentPartySize())
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
  boop.stats.lifetime = ensureScope(boop.stats.lifetime, now)

  if active then
    if not boop.stats.session.activeSince then
      boop.stats.session = newScope(now)
      scopeStart(boop.stats.session, now)
    end
    scopeStart(boop.stats.lifetime, now)
  else
    scopeStop(boop.stats.session, now)
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
    if boopActive then
      scopeStart(boop.stats.session, now)
    end
    boop.stats.trip = resetScopeData(boop.stats.trip, now)
    if hadTripStopwatch then
      resetTripStopwatch(boop.stats.trip)
      scopeStart(boop.stats.trip, now)
    end
    boop.stats.lifetime = resetScopeData(nil, now)
    if boopActive then
      scopeStart(boop.stats.lifetime, now)
    end
    boop.stats.mobXp = {}
    boop.stats.lastKill = nil
    boop.stats.activeTarget = nil
    boop.stats.pendingAttack = nil
    boop.stats.lastResolvedAttack = nil
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
    end
    boop.stats.lastKill = nil
    boop.stats.pendingAttack = nil
    boop.stats.lastResolvedAttack = nil
    seedBaselinesFromStatus()
    boop.util.ok("stats reset: trip")
    return
  end

  if key == "lifetime" or key == "life" then
    boop.stats.lifetime = resetScopeData(nil, now)
    if boopActive then
      scopeStart(boop.stats.lifetime, now)
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

function boop.stats.getMobXp(area, name, partySize)
  local cleanArea = tostring(area or "")
  local cleanName = tostring(name or "")
  local size = tonumber(partySize) or currentPartySize()
  if size < 1 then size = 1 end
  if cleanArea == "" or cleanName == "" then
    return nil
  end
  local areaMobs = boop.stats.mobXp and boop.stats.mobXp[cleanArea]
  if not areaMobs then
    return nil
  end
  local sizeMobs = areaMobs[size]
  if not sizeMobs then
    return nil
  end
  return sizeMobs[cleanName]
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

  local areaMobs = boop.stats.mobXp and boop.stats.mobXp[area] and boop.stats.mobXp[area][partySize] or {}
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
  local buckets = scope.targetStats and scope.targetStats[area] and scope.targetStats[area][partySize] or {}
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
    boop.util.info(string.format(
      "  %d. %s | kills %d | avg ttk %ss | best %ss | worst %ss%s",
      i,
      row.name,
      row.kills,
      formatStatValue(row.avgTtk, 2),
      formatStatValue(row.bestTtk, 2),
      formatStatValue(row.worstTtk, 2),
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

  boop.util.info("Usage: boop stats [session|trip|lifetime|areas [scope] [limit]|mobs [area] [limit]|targets [scope] [limit]|abilities [scope] [limit]|reset <session|trip|lifetime|all>]")
end

function boop.stats.startTrip()
  if boop.stats.trip.stopwatch then
    boop.util.warn("Trip already running.")
    return
  end
  boop.stats.trip = newScope(nowSeconds())
  scopeStart(boop.stats.trip, nowSeconds())
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
  scopeStop(boop.stats.trip, nowSeconds())
  boop.util.ok("Stopped hunting trip.")
  boop.stats.show("trip")
  boop.stats.trip.stopwatch = nil
end
