boop.db = boop.db or {}

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
    boop.util.echo("Mudlet DB not available; config will not persist.")
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
    stats = {
      name = "",
      value = "",
      _unique = { "name" },
      _violations = "IGNORE",
    }
  })

  boop.db.handle = db:get_database("boop")

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
end
