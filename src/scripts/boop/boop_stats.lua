boop.stats = boop.stats or {}

function boop.stats.init()
  boop.stats.session = boop.stats.session or { gold = 0, experience = 0 }
  boop.stats.trip = boop.stats.trip or { gold = 0, experience = 0 }
  boop.stats.lifetime = boop.stats.lifetime or { gold = 0, experience = 0 }
  boop.stats.lastGold = boop.stats.lastGold or nil
  boop.stats.lastXp = boop.stats.lastXp or nil
end

function boop.stats.onCharStatus()
  if not gmcp or not gmcp.Char or not gmcp.Char.Status then return end

  local goldNumber = tonumber(gmcp.Char.Status.gold)
  if goldNumber then
    if boop.stats.lastGold ~= nil then
      local delta = goldNumber - boop.stats.lastGold
      if delta > 0 then
        boop.stats.session.gold = boop.stats.session.gold + delta
        boop.stats.trip.gold = boop.stats.trip.gold + delta
        boop.stats.lifetime.gold = boop.stats.lifetime.gold + delta
        if boop.db and boop.db.saveStats then boop.db.saveStats() end
      end
    end
    boop.stats.lastGold = goldNumber
  end

  local lvl = tonumber((gmcp.Char.Status.level or ""):match("^(%d+)") or 0)
  local xp = tonumber((gmcp.Char.Status.xp or ""):match("([%d%.]+)") or 0)
  local newXp = lvl * 100 + xp

  if boop.stats.lastXp ~= nil then
    local delta = newXp - boop.stats.lastXp
    boop.stats.session.experience = boop.stats.session.experience + delta
    boop.stats.trip.experience = boop.stats.trip.experience + delta
    boop.stats.lifetime.experience = boop.stats.lifetime.experience + delta
    if boop.db and boop.db.saveStats then boop.db.saveStats() end
  end

  boop.stats.lastXp = newXp
end

function boop.stats.startTrip()
  if boop.stats.trip.stopwatch then
    boop.util.warn("Trip already running.")
    return
  end
  boop.stats.trip = { gold = 0, experience = 0, stopwatch = createStopWatch() }
  startStopWatch(boop.stats.trip.stopwatch)
  boop.util.ok("Started a new hunting trip.")
end

function boop.stats.stopTrip()
  if not boop.stats.trip.stopwatch then
    boop.util.warn("No trip running.")
    return
  end
  stopStopWatch(boop.stats.trip.stopwatch)
  boop.util.ok("Stopped hunting trip.")
  boop.util.info("Trip gains: " .. boop.stats.trip.gold .. " gold, " .. string.format("%.1f", boop.stats.trip.experience) .. "% xp")
  boop.stats.trip.stopwatch = nil
end
