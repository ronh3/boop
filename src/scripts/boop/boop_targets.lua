boop.targets = boop.targets or {}

local function normalizeName(name)
  if not name then return "" end
  local v = boop.util.trim(tostring(name))
  v = v:gsub("\226\128\152", "'") -- left single quotation mark
  v = v:gsub("\226\128\153", "'") -- right single quotation mark
  return boop.util.safeLower(v)
end

local function sameName(a, b)
  local na = normalizeName(a)
  local nb = normalizeName(b)
  if na == "" or nb == "" then return false end
  return na == nb
end

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
    if sameName(v.name, name) then
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
    if sameName(v, name) then return true end
  end
  return false
end

local function ensureLists()
  boop.lists = boop.lists or {}
  boop.lists.whitelist = boop.lists.whitelist or {}
  boop.lists.blacklist = boop.lists.blacklist or {}
  boop.lists.globalBlacklist = boop.lists.globalBlacklist or {}
  boop.lists.whitelistTags = boop.lists.whitelistTags or {}
  return boop.lists
end

local function normalizeTag(tag)
  local t = boop.util.safeLower(boop.util.trim(tag or ""))
  t = t:gsub("%s+", "-")
  t = t:gsub("[^%w%-%_]", "")
  return t
end

local function findWhitelistArea(area)
  local lists = ensureLists()
  local raw = boop.util.trim(area or "")
  if raw == "" then
    return boop.targets.getArea()
  end
  if lists.whitelist[raw] then
    return raw
  end

  local key = boop.util.safeLower(raw)
  local exact = {}
  for areaName, _ in pairs(lists.whitelist or {}) do
    if boop.util.safeLower(areaName) == key then
      exact[#exact + 1] = areaName
    end
  end
  if #exact == 1 then
    return exact[1]
  end
  if #exact > 1 then
    return ""
  end

  local partial = {}
  for areaName, _ in pairs(lists.whitelist or {}) do
    if boop.util.safeLower(areaName):find(key, 1, true) then
      partial[#partial + 1] = areaName
    end
  end
  if #partial == 1 then
    return partial[1]
  end
  return ""
end

local function getAreaTags(area)
  return ensureLists().whitelistTags[area] or {}
end

local function saveAreaTags(area, tags)
  ensureLists().whitelistTags[area] = tags
  if boop.db and boop.db.saveWhitelistTags then
    boop.db.saveWhitelistTags(area, tags)
  end
end

local function sortedWhitelistAreas()
  local lists = ensureLists()
  local areas = {}
  for area, list in pairs(lists.whitelist or {}) do
    if list and #list > 0 then
      areas[#areas + 1] = area
    end
  end
  table.sort(areas, function(a, b)
    return boop.util.safeLower(a) < boop.util.safeLower(b)
  end)
  return areas
end

local function splitTags(raw)
  local out = {}
  local seen = {}
  for part in tostring(raw or ""):gmatch("[^,]+") do
    local tag = normalizeTag(part)
    if tag ~= "" and not seen[tag] then
      seen[tag] = true
      out[#out + 1] = tag
    end
  end
  return out
end

local function listHasTag(tags, needle)
  for _, tag in ipairs(tags or {}) do
    if tag == needle then return true end
  end
  return false
end

local function shiftListEntry(list, index, direction)
  index = tonumber(index)
  if not list or not index then return false end
  if index < 1 or index > #list then return false end

  if direction == "up" then
    if index <= 1 then return false end
    list[index], list[index - 1] = list[index - 1], list[index]
    return true
  elseif direction == "down" then
    if index >= #list then return false end
    list[index], list[index + 1] = list[index + 1], list[index]
    return true
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
          if sameName(denizen.name, mob) then
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
  name = boop.util.trim(name or "")
  if name == "" then return end

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
  name = boop.util.trim(name or "")
  if name == "" then return end
  local list = boop.lists.whitelist[area]
  if not list then return end
  for i, v in ipairs(list) do
    if sameName(v, name) then
      table.remove(list, i)
      if boop.db and boop.db.saveList then
        boop.db.saveList("whitelist", area, list)
      end
      break
    end
  end
end

function boop.targets.shiftWhitelist(area, index, direction)
  area = area or boop.targets.getArea()
  local list = boop.lists.whitelist[area]
  if not list or #list == 0 then return false end
  local moved = shiftListEntry(list, index, direction)
  if moved and boop.db and boop.db.saveList then
    boop.db.saveList("whitelist", area, list)
  end
  return moved
end

function boop.targets.addBlacklist(area, name)
  area = area or boop.targets.getArea()
  name = boop.util.trim(name or "")
  if name == "" then return end

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
  name = boop.util.trim(name or "")
  if name == "" then return end
  local list = boop.lists.blacklist[area]
  if not list then return end
  for i, v in ipairs(list) do
    if sameName(v, name) then
      table.remove(list, i)
      if boop.db and boop.db.saveList then
        boop.db.saveList("blacklist", area, list)
      end
      break
    end
  end
end

function boop.targets.shiftBlacklist(area, index, direction)
  area = area or boop.targets.getArea()
  local list = boop.lists.blacklist[area]
  if not list or #list == 0 then return false end
  local moved = shiftListEntry(list, index, direction)
  if moved and boop.db and boop.db.saveList then
    boop.db.saveList("blacklist", area, list)
  end
  return moved
end

function boop.targets.displayWhitelist(area)
  area = area or boop.targets.getArea()
  local list = boop.lists.whitelist[area] or {}
  if cecho and cechoLink then
    cecho("\n<green>boop<reset>: <white>Whitelist for " .. area .. ":")
    if #list == 0 then
      cecho("\n  <grey>(empty)<reset>")
      return
    end
    for i, v in ipairs(list) do
      local idx = i
      local name = v
      cecho("\n  <yellow>" .. idx .. ".<reset> <white>" .. name .. "<reset> ")

      if idx > 1 then
        cechoLink("<cyan>[up]<reset>", function()
          boop.targets.shiftWhitelist(area, idx, "up")
          boop.targets.displayWhitelist(area)
        end, "Move " .. name .. " up", true)
      else
        cecho("<grey>[up]<reset>")
      end

      cecho(" ")

      if idx < #list then
        cechoLink("<cyan>[down]<reset>", function()
          boop.targets.shiftWhitelist(area, idx, "down")
          boop.targets.displayWhitelist(area)
        end, "Move " .. name .. " down", true)
      else
        cecho("<grey>[down]<reset>")
      end

      cecho(" ")
      cechoLink("<red>[remove]<reset>", function()
        boop.targets.removeWhitelist(area, name)
        boop.targets.displayWhitelist(area)
      end, "Remove " .. name .. " from whitelist", true)
    end
    return
  end

  boop.util.echo("Whitelist for " .. area .. ":")
  if #list == 0 then
    boop.util.echo("  (empty)")
    return
  end
  for i, v in ipairs(list) do
    boop.util.echo("  " .. i .. ". " .. v)
  end
end

function boop.targets.displayWhitelistBrowse(filterTag)
  local filter = normalizeTag(filterTag or "")
  local areas = sortedWhitelistAreas()
  local shown = 0

  if cecho and cechoLink then
    local title = "Whitelist browse"
    if filter ~= "" then
      title = title .. " [tag: " .. filter .. "]"
    end
    cecho("\n<green>boop<reset>: <white>" .. title)

    for _, areaName in ipairs(areas) do
      local list = boop.lists.whitelist[areaName] or {}
      local tags = getAreaTags(areaName)
      if filter == "" or listHasTag(tags, filter) then
        shown = shown + 1
        cecho(string.format("\n  <yellow>%d.<reset> <white>%s<reset> <grey>(%d mobs)<reset> ",
          shown, areaName, #list))
        cechoLink("<cyan>[open]<reset>", function() boop.targets.displayWhitelist(areaName) end, "Show whitelist for " .. areaName, true)
        cecho(" ")
        cechoLink("<cyan>[tags]<reset>", function() boop.targets.displayWhitelistTags(areaName) end, "Show tags for " .. areaName, true)
        if appendCmdLine then
          cecho(" ")
          cechoLink("<yellow>[tag+]<reset>", function()
            if clearCmdLine then clearCmdLine() end
            appendCmdLine("boop whitelist tag add " .. areaName .. " | ")
          end, "Add tag to " .. areaName, true)
        end
        if #tags > 0 then
          cecho("\n     <grey>tags:<reset> ")
          for _, tag in ipairs(tags) do
            cechoLink("<magenta>[" .. tag .. "]<reset>", function() boop.targets.displayWhitelistBrowse(tag) end, "Filter browse by " .. tag, true)
            cecho(" ")
          end
        end
      end
    end

    if shown == 0 then
      if filter == "" then
        cecho("\n  <grey>(no whitelist areas yet)<reset>")
      else
        cecho("\n  <grey>(no areas with that tag)<reset>")
      end
    end
    return
  end

  boop.util.echo("Whitelist browse" .. (filter ~= "" and (" [tag: " .. filter .. "]") or ""))
  for _, areaName in ipairs(areas) do
    local list = boop.lists.whitelist[areaName] or {}
    local tags = getAreaTags(areaName)
    if filter == "" or listHasTag(tags, filter) then
      shown = shown + 1
      local tagText = (#tags > 0) and (" | tags: " .. table.concat(tags, ", ")) or ""
      boop.util.echo(string.format("  %d. %s (%d mobs)%s", shown, areaName, #list, tagText))
    end
  end
  if shown == 0 then
    boop.util.echo(filter == "" and "  (no whitelist areas yet)" or "  (no areas with that tag)")
  end
end

function boop.targets.displayWhitelistTags(area)
  local resolved = findWhitelistArea(area)
  if resolved == "" then
    boop.util.echo("Unknown whitelist area: " .. tostring(area))
    return
  end
  local tags = getAreaTags(resolved)
  if #tags == 0 then
    boop.util.echo("Whitelist tags for " .. resolved .. ": (none)")
    boop.util.echo("Add with: boop whitelist tag add " .. resolved .. " | <tag[,tag2,...]>")
    return
  end
  boop.util.echo("Whitelist tags for " .. resolved .. ": " .. table.concat(tags, ", "))
end

function boop.targets.addWhitelistTags(area, rawTags)
  local resolved = findWhitelistArea(area)
  if resolved == "" then
    boop.util.echo("Unknown whitelist area: " .. tostring(area))
    boop.util.echo("Use: boop whitelist browse")
    return
  end
  local list = boop.lists.whitelist[resolved] or {}
  if #list == 0 then
    boop.util.echo("Area has no whitelist entries: " .. resolved)
    return
  end

  local incoming = splitTags(rawTags)
  if #incoming == 0 then
    boop.util.echo("Usage: boop whitelist tag add <area> | <tag[,tag2,...]>")
    return
  end

  local tags = getAreaTags(resolved)
  local added = 0
  for _, tag in ipairs(incoming) do
    if not listHasTag(tags, tag) then
      tags[#tags + 1] = tag
      added = added + 1
    end
  end
  table.sort(tags)
  saveAreaTags(resolved, tags)
  boop.util.echo(string.format("Whitelist tags updated for %s: %s (added %d)", resolved, table.concat(tags, ", "), added))
end

function boop.targets.removeWhitelistTags(area, rawTags)
  local resolved = findWhitelistArea(area)
  if resolved == "" then
    boop.util.echo("Unknown whitelist area: " .. tostring(area))
    boop.util.echo("Use: boop whitelist browse")
    return
  end

  local incoming = splitTags(rawTags)
  if #incoming == 0 then
    boop.util.echo("Usage: boop whitelist tag remove <area> | <tag[,tag2,...]>")
    return
  end

  local tags = getAreaTags(resolved)
  if #tags == 0 then
    boop.util.echo("No tags set for " .. resolved)
    return
  end

  local out = {}
  local removed = 0
  for _, existing in ipairs(tags) do
    local keep = true
    for _, kill in ipairs(incoming) do
      if existing == kill then
        keep = false
        removed = removed + 1
        break
      end
    end
    if keep then
      out[#out + 1] = existing
    end
  end
  saveAreaTags(resolved, out)
  if #out == 0 then
    boop.util.echo(string.format("Whitelist tags cleared for %s (removed %d)", resolved, removed))
  else
    boop.util.echo(string.format("Whitelist tags updated for %s: %s (removed %d)", resolved, table.concat(out, ", "), removed))
  end
end

function boop.targets.displayWhitelistTagSummary()
  local lists = ensureLists()
  local counts = {}
  local areasByTag = {}
  for area, tags in pairs(lists.whitelistTags or {}) do
    local wl = lists.whitelist[area] or {}
    if #wl > 0 then
      for _, tag in ipairs(tags) do
        counts[tag] = (counts[tag] or 0) + 1
        areasByTag[tag] = areasByTag[tag] or {}
        areasByTag[tag][#areasByTag[tag] + 1] = area
      end
    end
  end

  local tags = {}
  for tag, _ in pairs(counts) do
    tags[#tags + 1] = tag
  end
  table.sort(tags)

  if cecho and cechoLink then
    cecho("\n<green>boop<reset>: <white>Whitelist tag summary:")
    if #tags == 0 then
      cecho("\n  <grey>(no tags yet)<reset>")
      return
    end
    for i, tag in ipairs(tags) do
      cecho(string.format("\n  <yellow>%d.<reset> <magenta>%s<reset> <grey>(%d areas)<reset> ",
        i, tag, counts[tag] or 0))
      cechoLink("<cyan>[browse]<reset>", function() boop.targets.displayWhitelistBrowse(tag) end, "Browse whitelist areas tagged " .. tag, true)
    end
    return
  end

  boop.util.echo("Whitelist tag summary:")
  if #tags == 0 then
    boop.util.echo("  (no tags yet)")
    return
  end
  for i, tag in ipairs(tags) do
    local areas = areasByTag[tag] or {}
    table.sort(areas, function(a, b) return boop.util.safeLower(a) < boop.util.safeLower(b) end)
    boop.util.echo(string.format("  %d. %s (%d areas) -> %s", i, tag, counts[tag] or 0, table.concat(areas, " | ")))
  end
end

function boop.targets.displayBlacklist(area)
  area = area or boop.targets.getArea()
  local list = boop.lists.blacklist[area] or {}
  if cecho and cechoLink then
    cecho("\n<green>boop<reset>: <white>Blacklist for " .. area .. ":")
    if #list == 0 then
      cecho("\n  <grey>(empty)<reset>")
      return
    end
    for i, v in ipairs(list) do
      local idx = i
      local name = v
      cecho("\n  <yellow>" .. idx .. ".<reset> <white>" .. name .. "<reset> ")

      if idx > 1 then
        cechoLink("<cyan>[up]<reset>", function()
          boop.targets.shiftBlacklist(area, idx, "up")
          boop.targets.displayBlacklist(area)
        end, "Move " .. name .. " up", true)
      else
        cecho("<grey>[up]<reset>")
      end

      cecho(" ")

      if idx < #list then
        cechoLink("<cyan>[down]<reset>", function()
          boop.targets.shiftBlacklist(area, idx, "down")
          boop.targets.displayBlacklist(area)
        end, "Move " .. name .. " down", true)
      else
        cecho("<grey>[down]<reset>")
      end

      cecho(" ")
      cechoLink("<red>[remove]<reset>", function()
        boop.targets.removeBlacklist(area, name)
        boop.targets.displayBlacklist(area)
      end, "Remove " .. name .. " from blacklist", true)
    end
    return
  end

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
