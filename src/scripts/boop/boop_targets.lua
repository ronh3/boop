boop.targets = boop.targets or {}

function boop.targets.getArea()
  if gmcp and gmcp.Room and gmcp.Room.Info then
    return gmcp.Room.Info.area
  end
  return "UNKNOWN"
end

function boop.targets.isValidDenizen(item)
  if not item or not item.attrib then return false end
  if not item.attrib:find("m") then return false end
  if item.attrib:find("x") then return false end
  if item.attrib:find("d") then return false end
  return true
end

function boop.targets.isDenizenName(name)
  if not name or name == "" then return false end
  for _, v in ipairs(boop.state.denizens or {}) do
    if v.name == name then
      return true
    end
  end
  return false
end

function boop.targets.updateRoomItems(items)
  boop.state.denizens = {}
  if not items then return end
  for _, item in ipairs(items) do
    if boop.targets.isValidDenizen(item) then
      boop.state.denizens[#boop.state.denizens + 1] = {
        id = tostring(item.id),
        name = item.name,
        attrib = item.attrib,
      }
    end
  end
end

function boop.targets.addRoomItem(item)
  if not boop.targets.isValidDenizen(item) then return end
  local id = tostring(item.id)
  for _, v in ipairs(boop.state.denizens) do
    if v.id == id then return end
  end
  boop.state.denizens[#boop.state.denizens + 1] = {
    id = id,
    name = item.name,
    attrib = item.attrib,
  }
end

function boop.targets.removeRoomItem(item)
  local id = tostring(item.id)
  for i, v in ipairs(boop.state.denizens) do
    if v.id == id then
      table.remove(boop.state.denizens, i)
      break
    end
  end
end

function boop.targets.setTarget(id)
  if not id or id == "" then return end
  boop.state.currentTargetId = tostring(id)
  for _, v in ipairs(boop.state.denizens) do
    if v.id == boop.state.currentTargetId then
      boop.state.targetName = v.name
      break
    end
  end

  if gmcp and gmcp.IRE and gmcp.IRE.Target then
    sendGMCP([[IRE.Target.Set "]] .. boop.state.currentTargetId .. [["]])
  end
end

local function listContains(list, name)
  if not list then return false end
  for _, v in ipairs(list) do
    if v == name then return true end
  end
  return false
end

local function sortedDenizens(order)
  local denizens = {}
  for _, v in ipairs(boop.state.denizens) do
    denizens[#denizens + 1] = v
  end

  if order == "numeric" then
    table.sort(denizens, function(a, b) return tonumber(a.id) < tonumber(b.id) end)
  elseif order == "reverse" then
    local rev = {}
    for i = #denizens, 1, -1 do
      rev[#rev + 1] = denizens[i]
    end
    denizens = rev
  end
  return denizens
end

function boop.targets.choose()
  local mode = boop.config.targetingMode
  local area = boop.targets.getArea()
  local denizens = sortedDenizens(boop.config.targetOrder)

  if mode == "manual" then
    return boop.state.currentTargetId
  end

  if mode == "whitelist" then
    local whitelist = boop.lists.whitelist[area]
    if not whitelist or #whitelist == 0 then return "" end

    if boop.config.whitelistPriorityOrder then
      for _, mob in ipairs(whitelist) do
        for _, denizen in ipairs(denizens) do
          if denizen.name == mob then
            return denizen.id
          end
        end
      end
    else
      for _, denizen in ipairs(denizens) do
        if listContains(whitelist, denizen.name) then
          return denizen.id
        end
      end
    end
    return ""
  end

  if mode == "blacklist" then
    local blacklist = boop.lists.blacklist[area] or {}
    for _, denizen in ipairs(denizens) do
      if not listContains(blacklist, denizen.name)
        and not listContains(boop.lists.globalBlacklist, denizen.name)
      then
        return denizen.id
      end
    end
    return ""
  end

  if mode == "auto" then
    for _, denizen in ipairs(denizens) do
      if not listContains(boop.lists.globalBlacklist, denizen.name) then
        return denizen.id
      end
    end
  end

  return ""
end

function boop.targets.addWhitelist(area, name)
  area = area or boop.targets.getArea()
  if not name or name == "" then return end

  boop.lists.whitelist[area] = boop.lists.whitelist[area] or {}
  if listContains(boop.lists.whitelist[area], name) then
    boop.util.echo("Already whitelisted: " .. name)
    return
  end

  boop.lists.whitelist[area][#boop.lists.whitelist[area] + 1] = name

  if boop.db and boop.db.saveList then
    boop.db.saveList("whitelist", area, boop.lists.whitelist[area])
  end
end

function boop.targets.removeWhitelist(area, name)
  area = area or boop.targets.getArea()
  local list = boop.lists.whitelist[area]
  if not list then return end
  for i, v in ipairs(list) do
    if v == name then
      table.remove(list, i)
      if boop.db and boop.db.saveList then
        boop.db.saveList("whitelist", area, list)
      end
      break
    end
  end
end

function boop.targets.addBlacklist(area, name)
  area = area or boop.targets.getArea()
  if not name or name == "" then return end

  boop.lists.blacklist[area] = boop.lists.blacklist[area] or {}
  if listContains(boop.lists.blacklist[area], name) then
    boop.util.echo("Already blacklisted: " .. name)
    return
  end

  boop.lists.blacklist[area][#boop.lists.blacklist[area] + 1] = name

  if boop.db and boop.db.saveList then
    boop.db.saveList("blacklist", area, boop.lists.blacklist[area])
  end
end

function boop.targets.removeBlacklist(area, name)
  area = area or boop.targets.getArea()
  local list = boop.lists.blacklist[area]
  if not list then return end
  for i, v in ipairs(list) do
    if v == name then
      table.remove(list, i)
      if boop.db and boop.db.saveList then
        boop.db.saveList("blacklist", area, list)
      end
      break
    end
  end
end

function boop.targets.displayWhitelist(area)
  area = area or boop.targets.getArea()
  local list = boop.lists.whitelist[area] or {}
  boop.util.echo("Whitelist for " .. area .. ":")
  if #list == 0 then
    boop.util.echo("  (empty)")
    return
  end
  for i, v in ipairs(list) do
    boop.util.echo("  " .. i .. ". " .. v)
  end
end

function boop.targets.displayBlacklist(area)
  area = area or boop.targets.getArea()
  local list = boop.lists.blacklist[area] or {}
  boop.util.echo("Blacklist for " .. area .. ":")
  if #list == 0 then
    boop.util.echo("  (empty)")
    return
  end
  for i, v in ipairs(list) do
    boop.util.echo("  " .. i .. ". " .. v)
  end
end

function boop.targets.onShielded(name)
  if not name then return end
  if boop.state.targetName ~= "" and boop.state.targetName == name then
    if boop.state.targetShield and boop.state.targetShield.timer then
      killTimer(boop.state.targetShield.timer)
    end
    boop.state.targetShield = { gained = os.clock() }
    boop.state.targetShield.timer = tempTimer(3, function() boop.state.targetShield = false end)
  end
end
