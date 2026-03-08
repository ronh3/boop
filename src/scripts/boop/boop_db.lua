boop.db = boop.db or {}

local function whitelistTagsSchema()
  return {
    area = "",
    pos = 0,
    tag = "",
    _index = { "area" },
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

  if not boop.db.handle then return end
  local rows = db:fetch(boop.db.handle.stats, nil, { boop.db.handle.stats.name })
  for _, row in ipairs(rows) do
    if row.name == "lifetime_gold" then
      boop.stats.lifetime.gold = tonumber(row.value) or 0
    elseif row.name == "lifetime_experience" then
      boop.stats.lifetime.experience = tonumber(row.value) or 0
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
end

function boop.db.saveStats()
  if not boop.db.handle then return end
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

  save("lifetime_gold", boop.stats.lifetime.gold)
  save("lifetime_experience", boop.stats.lifetime.experience)
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
