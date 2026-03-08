boop.db = boop.db or {}

local function whitelistTagsSchema()
  return {
    area = "",
    pos = 0,
    tag = "",
    _index = { "area" },
  }
end

local function mobXpSchema()
  return {
    area = "",
    name = "",
    xp = 0,
    count = 0,
    _index = { "area", "name" },
  }
end

local function mobXpV2Schema()
  return {
    area = "",
    party_size = 1,
    name = "",
    xp = 0,
    count = 0,
    _index = { "area", "party_size", "name" },
  }
end

local function warnDb(message)
  if boop and boop.util and boop.util.warn then
    boop.util.warn(message)
  elseif boop and boop.util and boop.util.echo then
    boop.util.echo(message)
  end
end

function boop.db.ensureWhitelistTagsTable()
  if not db then
    return false, "Mudlet DB unavailable"
  end

  if not boop.db.handle then
    local ok, handleOrErr = pcall(function() return db:get_database("boop") end)
    if not ok then
      return false, tostring(handleOrErr)
    end
    boop.db.handle = handleOrErr
  end

  if not boop.db.handle then
    return false, "boop DB handle unavailable"
  end

  local function verifySheet()
    if not boop.db.handle.whitelist_tags then
      return false, "whitelist_tags handle missing"
    end
    local ok, err = pcall(function()
      db:fetch(boop.db.handle.whitelist_tags, nil, { boop.db.handle.whitelist_tags.area, boop.db.handle.whitelist_tags.pos })
    end)
    if not ok then
      return false, tostring(err)
    end
    return true, nil
  end

  local ok, err = verifySheet()
  if ok then
    return true, nil
  end

  local created, createErr = pcall(function()
    db:create("boop", { whitelist_tags = whitelistTagsSchema() })
  end)
  if not created then
    return false, tostring(createErr)
  end

  local handleOk, handleOrErr = pcall(function() return db:get_database("boop") end)
  if not handleOk then
    return false, tostring(handleOrErr)
  end
  boop.db.handle = handleOrErr

  local verifyOk, verifyErr = verifySheet()
  if not verifyOk then
    return false, tostring(verifyErr or err)
  end
  return true, nil
end

function boop.db.ensureMobXpTable()
  if not db then
    return false, "Mudlet DB unavailable"
  end

  if not boop.db.handle then
    local ok, handleOrErr = pcall(function() return db:get_database("boop") end)
    if not ok then
      return false, tostring(handleOrErr)
    end
    boop.db.handle = handleOrErr
  end

  if not boop.db.handle then
    return false, "boop DB handle unavailable"
  end

  local function verifySheet()
    if not boop.db.handle.mob_xp_v2 then
      return false, "mob_xp_v2 handle missing"
    end
    local ok, err = pcall(function()
      db:fetch(boop.db.handle.mob_xp_v2, nil, {
        boop.db.handle.mob_xp_v2.area,
        boop.db.handle.mob_xp_v2.party_size,
        boop.db.handle.mob_xp_v2.name,
        boop.db.handle.mob_xp_v2.xp,
      })
    end)
    if not ok then
      return false, tostring(err)
    end
    return true, nil
  end

  local ok, err = verifySheet()
  if ok then
    return true, nil
  end

  local created, createErr = pcall(function()
    db:create("boop", { mob_xp_v2 = mobXpV2Schema() })
  end)
  if not created then
    return false, tostring(createErr)
  end

  local handleOk, handleOrErr = pcall(function() return db:get_database("boop") end)
  if not handleOk then
    return false, tostring(handleOrErr)
  end
  boop.db.handle = handleOrErr

  local verifyOk, verifyErr = verifySheet()
  if not verifyOk then
    return false, tostring(verifyErr or err)
  end
  return true, nil
end

local function castValue(raw, default)
  if raw == nil then return default end
  local t = type(default)
  if t == "boolean" then
    return raw == "true"
  elseif t == "number" then
    return tonumber(raw) or default
  else
    return tostring(raw)
  end
end

function boop.db.init()
  if not db then
    boop.util.warn("Mudlet DB not available; config will not persist.")
    return
  end

  db:create("boop", {
    config = {
      name = "",
      value = "",
      _unique = { "name" },
      _violations = "IGNORE",
    },
    whitelist = {
      area = "",
      pos = 0,
      name = "",
      ignore = 0,
      _index = { "area" },
    },
    blacklist = {
      area = "",
      pos = 0,
      name = "",
      ignore = 0,
      _index = { "area" },
    },
    whitelist_tags = whitelistTagsSchema(),
    mob_xp = mobXpSchema(),
    mob_xp_v2 = mobXpV2Schema(),
    stats = {
      name = "",
      value = "",
      _unique = { "name" },
      _violations = "IGNORE",
    }
  })

  boop.db.handle = db:get_database("boop")

  local tagOk, tagErr = boop.db.ensureWhitelistTagsTable()
  if not tagOk then
    warnDb("boop: warning: whitelist tag storage unavailable (" .. tostring(tagErr) .. ")")
  end

  local mobOk, mobErr = boop.db.ensureMobXpTable()
  if not mobOk then
    warnDb("boop: warning: mob xp storage unavailable (" .. tostring(mobErr) .. ")")
  end

  boop.db.loadConfig()
  boop.db.loadLists()
  boop.db.loadStats()
end

function boop.db.loadConfig()
  for k, v in pairs(boop.defaults) do
    boop.config[k] = v
  end

  if not boop.db.handle then return end
  local rows = db:fetch(boop.db.handle.config, nil, { boop.db.handle.config.name })
  for _, row in ipairs(rows) do
    local key = row.name
    if boop.defaults[key] ~= nil then
      boop.config[key] = castValue(row.value, boop.defaults[key])
    else
      boop.config[key] = row.value
    end
  end

  for k, v in pairs(boop.defaults) do
    if boop.config[k] == nil then
      boop.config[k] = v
    end
    boop.db.saveConfig(k, boop.config[k])
  end
end

function boop.db.saveConfig(key, value)
  if not boop.db.handle then return end
  local dbtable = boop.db.handle.config
  local row = db:fetch(dbtable, db:eq(dbtable.name, key))[1]
  local strValue = tostring(value)
  if not row then
    db:add(dbtable, { name = key, value = strValue })
  else
    if row.value ~= strValue then
      row.value = strValue
      db:update(dbtable, row)
    end
  end
end

function boop.db.loadLists()
  boop.lists.whitelist = {}
  boop.lists.blacklist = {}
  boop.lists.globalBlacklist = {}
  boop.lists.whitelistTags = {}

  if not boop.db.handle then return end

  local wl = db:fetch(boop.db.handle.whitelist, nil, { boop.db.handle.whitelist.area, boop.db.handle.whitelist.pos })
  for _, row in ipairs(wl) do
    local area = row.area
    boop.lists.whitelist[area] = boop.lists.whitelist[area] or {}
    boop.lists.whitelist[area][#boop.lists.whitelist[area] + 1] = row.name
  end

  local bl = db:fetch(boop.db.handle.blacklist, nil, { boop.db.handle.blacklist.area, boop.db.handle.blacklist.pos })
  for _, row in ipairs(bl) do
    if row.area == "GLOBAL" then
      boop.lists.globalBlacklist[#boop.lists.globalBlacklist + 1] = row.name
    else
      local area = row.area
      boop.lists.blacklist[area] = boop.lists.blacklist[area] or {}
      boop.lists.blacklist[area][#boop.lists.blacklist[area] + 1] = row.name
    end
  end

  local tagOk = boop.db.ensureWhitelistTagsTable()
  if tagOk and boop.db.handle.whitelist_tags then
    local fetched, tagsOrErr = pcall(function()
      return db:fetch(boop.db.handle.whitelist_tags, nil, { boop.db.handle.whitelist_tags.area, boop.db.handle.whitelist_tags.pos })
    end)
    if fetched then
      for _, row in ipairs(tagsOrErr) do
        local area = row.area
        local tag = row.tag
        if area and area ~= "" and tag and tag ~= "" then
          boop.lists.whitelistTags[area] = boop.lists.whitelistTags[area] or {}
          boop.lists.whitelistTags[area][#boop.lists.whitelistTags[area] + 1] = tag
        end
      end
    else
      warnDb("boop: warning: failed loading whitelist tags (" .. tostring(tagsOrErr) .. ")")
    end
  end
end

function boop.db.saveList(kind, area, list)
  if not boop.db.handle then return end
  local dbtable
  if kind == "whitelist" then
    dbtable = boop.db.handle.whitelist
  else
    dbtable = boop.db.handle.blacklist
  end

  local rows = db:fetch(dbtable, db:eq(dbtable.area, area))
  for _, row in ipairs(rows) do
    db:delete(dbtable, row._row_id)
  end

  for i, name in ipairs(list) do
    db:add(dbtable, { area = area, pos = i, name = name })
  end
end

function boop.db.saveWhitelistTags(area, tags)
  local ok, err = boop.db.ensureWhitelistTagsTable()
  if not ok then
    warnDb("boop: warning: cannot save whitelist tags (" .. tostring(err) .. ")")
    return
  end
  if not boop.db.handle or not boop.db.handle.whitelist_tags then return end
  local dbtable = boop.db.handle.whitelist_tags
  local fetched, rowsOrErr = pcall(function()
    return db:fetch(dbtable, db:eq(dbtable.area, area))
  end)
  if not fetched then
    warnDb("boop: warning: cannot fetch existing whitelist tags (" .. tostring(rowsOrErr) .. ")")
    return
  end
  local rows = rowsOrErr
  for _, row in ipairs(rows) do
    local deleted = pcall(function() db:delete(dbtable, row._row_id) end)
    if not deleted then
      warnDb("boop: warning: failed deleting old whitelist tag row")
    end
  end
  for i, tag in ipairs(tags or {}) do
    local added, addErr = pcall(function()
      db:add(dbtable, { area = area, pos = i, tag = tag })
    end)
    if not added then
      warnDb("boop: warning: failed saving whitelist tag `" .. tostring(tag) .. "` (" .. tostring(addErr) .. ")")
    end
  end
end

function boop.db.loadStats()
  boop.stats = boop.stats or {}
  boop.stats.lifetime = boop.stats.lifetime or { gold = 0, experience = 0 }
  boop.stats.mobXp = {}

  if not boop.db.handle then return end
  local rows = db:fetch(boop.db.handle.stats, nil, { boop.db.handle.stats.name })
  for _, row in ipairs(rows) do
    if row.name == "lifetime_gold" then
      boop.stats.lifetime.gold = tonumber(row.value) or 0
    elseif row.name == "lifetime_experience" then
      boop.stats.lifetime.experience = tonumber(row.value) or 0
    elseif row.name == "lifetime_raw_experience" then
      boop.stats.lifetime.rawExperience = tonumber(row.value) or 0
    elseif row.name == "lifetime_active_seconds" then
      boop.stats.lifetime.activeSeconds = tonumber(row.value) or 0
    elseif row.name == "lifetime_kills" then
      boop.stats.lifetime.kills = tonumber(row.value) or 0
    elseif row.name == "lifetime_targets" then
      boop.stats.lifetime.targets = tonumber(row.value) or 0
    elseif row.name == "lifetime_retargets" then
      boop.stats.lifetime.retargets = tonumber(row.value) or 0
    elseif row.name == "lifetime_abandoned" then
      boop.stats.lifetime.abandoned = tonumber(row.value) or 0
    elseif row.name == "lifetime_flees" then
      boop.stats.lifetime.flees = tonumber(row.value) or 0
    elseif row.name == "lifetime_room_moves" then
      boop.stats.lifetime.roomMoves = tonumber(row.value) or 0
    elseif row.name == "lifetime_total_ttk" then
      boop.stats.lifetime.totalTtk = tonumber(row.value) or 0
    elseif row.name == "lifetime_best_ttk" then
      boop.stats.lifetime.bestTtk = tonumber(row.value) or nil
    elseif row.name == "lifetime_worst_ttk" then
      boop.stats.lifetime.worstTtk = tonumber(row.value) or nil
    end
  end

  local mobOk = boop.db.ensureMobXpTable()
  if not mobOk or not boop.db.handle.mob_xp_v2 then
    return
  end

  local fetched, mobRowsOrErr = pcall(function()
    return db:fetch(boop.db.handle.mob_xp_v2, nil, {
      boop.db.handle.mob_xp_v2.area,
      boop.db.handle.mob_xp_v2.party_size,
      boop.db.handle.mob_xp_v2.name,
      boop.db.handle.mob_xp_v2.xp,
    })
  end)
  if not fetched then
    warnDb("boop: warning: failed loading mob xp stats (" .. tostring(mobRowsOrErr) .. ")")
    return
  end

  for _, row in ipairs(mobRowsOrErr) do
    local area = tostring(row.area or "")
    local partySize = tonumber(row.party_size) or 1
    local name = tostring(row.name or "")
    local xp = tonumber(row.xp)
    local count = tonumber(row.count) or 0
    if area ~= "" and name ~= "" and xp and count > 0 then
      boop.stats.mobXp[area] = boop.stats.mobXp[area] or {}
      boop.stats.mobXp[area][partySize] = boop.stats.mobXp[area][partySize] or {}
      local entry = boop.stats.mobXp[area][partySize][name]
      if not entry then
        entry = {
          observations = 0,
          total = 0,
          min = nil,
          max = nil,
          values = {},
        }
        boop.stats.mobXp[area][partySize][name] = entry
      end
      entry.observations = entry.observations + count
      entry.total = entry.total + (xp * count)
      entry.values[tostring(xp)] = (tonumber(entry.values[tostring(xp)]) or 0) + count
      if not entry.min or xp < entry.min then
        entry.min = xp
      end
      if not entry.max or xp > entry.max then
        entry.max = xp
      end
    end
  end
end

function boop.db.recordMobXpObservation(area, partySize, name, xp, delta)
  local ok, err = boop.db.ensureMobXpTable()
  if not ok then
    warnDb("boop: warning: cannot save mob xp observation (" .. tostring(err) .. ")")
    return
  end
  if not boop.db.handle or not boop.db.handle.mob_xp_v2 then return end

  local cleanArea = tostring(area or "")
  local size = tonumber(partySize) or 1
  if size < 1 then size = 1 end
  local cleanName = tostring(name or "")
  local xpValue = tonumber(xp)
  local addCount = tonumber(delta) or 1
  if cleanArea == "" or cleanName == "" or not xpValue or addCount <= 0 then
    return
  end

  local dbtable = boop.db.handle.mob_xp_v2
  local fetched, rowsOrErr = pcall(function()
    return db:fetch(dbtable, db:eq(dbtable.area, cleanArea))
  end)
  if not fetched then
    warnDb("boop: warning: cannot fetch mob xp rows (" .. tostring(rowsOrErr) .. ")")
    return
  end

  local row
  for _, candidate in ipairs(rowsOrErr) do
    if (tonumber(candidate.party_size) or 1) == size
      and tostring(candidate.name or "") == cleanName
      and tonumber(candidate.xp) == xpValue
    then
      row = candidate
      break
    end
  end

  if not row then
    local added, addErr = pcall(function()
      db:add(dbtable, {
        area = cleanArea,
        party_size = size,
        name = cleanName,
        xp = xpValue,
        count = addCount,
      })
    end)
    if not added then
      warnDb("boop: warning: cannot add mob xp row (" .. tostring(addErr) .. ")")
    end
    return
  end

  row.count = (tonumber(row.count) or 0) + addCount
  local updated, updateErr = pcall(function()
    db:update(dbtable, row)
  end)
  if not updated then
    warnDb("boop: warning: cannot update mob xp row (" .. tostring(updateErr) .. ")")
  end
end

function boop.db.clearMobXpStats()
  local ok, err = boop.db.ensureMobXpTable()
  if not ok then
    warnDb("boop: warning: cannot clear mob xp stats (" .. tostring(err) .. ")")
    return
  end
  if not boop.db.handle or not boop.db.handle.mob_xp_v2 then return end

  local dbtable = boop.db.handle.mob_xp_v2
  local fetched, rowsOrErr = pcall(function()
    return db:fetch(dbtable, nil)
  end)
  if not fetched then
    warnDb("boop: warning: cannot fetch mob xp rows for clear (" .. tostring(rowsOrErr) .. ")")
    return
  end

  for _, row in ipairs(rowsOrErr) do
    local deleted = pcall(function() db:delete(dbtable, row._row_id) end)
    if not deleted then
      warnDb("boop: warning: failed deleting mob xp row")
    end
  end
end

function boop.db.saveStats()
  if not boop.db.handle then return end
  local function nowSeconds()
    if getEpoch then return getEpoch() end
    return os.clock()
  end

  local function save(name, value)
    local dbtable = boop.db.handle.stats
    local row = db:fetch(dbtable, db:eq(dbtable.name, name))[1]
    local strValue = tostring(value)
    if not row then
      db:add(dbtable, { name = name, value = strValue })
    else
      if row.value ~= strValue then
        row.value = strValue
        db:update(dbtable, row)
      end
    end
  end

  local lifetimeActiveSeconds = boop.stats.lifetime.activeSeconds or 0
  if boop.stats.lifetime.activeSince then
    local delta = nowSeconds() - boop.stats.lifetime.activeSince
    if delta > 0 then
      lifetimeActiveSeconds = lifetimeActiveSeconds + delta
    end
  end

  save("lifetime_gold", boop.stats.lifetime.gold)
  save("lifetime_experience", boop.stats.lifetime.experience)
  save("lifetime_raw_experience", boop.stats.lifetime.rawExperience or 0)
  save("lifetime_active_seconds", lifetimeActiveSeconds)
  save("lifetime_kills", boop.stats.lifetime.kills or 0)
  save("lifetime_targets", boop.stats.lifetime.targets or 0)
  save("lifetime_retargets", boop.stats.lifetime.retargets or 0)
  save("lifetime_abandoned", boop.stats.lifetime.abandoned or 0)
  save("lifetime_flees", boop.stats.lifetime.flees or 0)
  save("lifetime_room_moves", boop.stats.lifetime.roomMoves or 0)
  save("lifetime_total_ttk", boop.stats.lifetime.totalTtk or 0)
  save("lifetime_best_ttk", boop.stats.lifetime.bestTtk or "")
  save("lifetime_worst_ttk", boop.stats.lifetime.worstTtk or "")
end
