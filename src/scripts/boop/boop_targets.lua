boop.targets = boop.targets or {}

local function normalizeName(name)
  if not name then return "" end
  local v = boop.util.trim(tostring(name))
  v = v:gsub("\226\128\152", "'") -- left single quotation mark
  v = v:gsub("\226\128\153", "'") -- right single quotation mark
  return boop.util.safeLower(v)
end

local function currentRoomId()
  if gmcp and gmcp.Room and gmcp.Room.Info and gmcp.Room.Info.num then
    return tostring(gmcp.Room.Info.num or "")
  end
  return ""
end

local function configuredLeader()
  return boop.util.trim((boop.config and boop.config.assistLeader) or "")
end

local function targetCallEnabled()
  return not not (boop.config and boop.config.targetCall and boop.config.targetingMode ~= "manual")
end

local function sameName(a, b)
  local na = normalizeName(a)
  local nb = normalizeName(b)
  if na == "" or nb == "" then return false end
  return na == nb
end

local function sameSpeaker(a, b)
  return sameName(a, b)
end

local function findDenizenById(denizens, id)
  local targetId = tostring(id or "")
  if targetId == "" then return nil end
  for _, denizen in ipairs(denizens or {}) do
    if tostring(denizen.id or "") == targetId then
      return denizen
    end
  end
  return nil
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
  local nextId = tostring(id)
  local prevId = tostring(boop.state.currentTargetId or "")
  local changed = (prevId ~= "" and prevId ~= nextId) or (prevId == "" and nextId ~= "")
  if changed and boop.targets.clearTargetShield then
    boop.targets.clearTargetShield("target changed")
  end
  if changed and boop.afflictions and boop.afflictions.clearTarget then
    boop.afflictions.clearTarget()
    if boop.trace and boop.trace.log then
      boop.trace.log("target afflictions cleared: target changed")
    end
  end
  boop.state.currentTargetId = nextId
  for _, v in ipairs(boop.state.denizens) do
    if v.id == boop.state.currentTargetId then
      boop.state.targetName = v.name
      break
    end
  end

  if changed and boop.stats and boop.stats.onTargetSet then
    boop.stats.onTargetSet(boop.state.currentTargetId, boop.state.targetName or "")
  end

  if changed and send then
    send("settarget " .. boop.state.currentTargetId, false)
  end
end

function boop.targets.clearTargetCall(reason)
  boop.state = boop.state or {}
  boop.state.calledTargetId = ""
  boop.state.calledTargetRoom = ""
  boop.state.calledTargetBy = ""
  boop.state.calledTargetAt = nil
  if reason and boop.trace and boop.trace.log then
    boop.trace.log("target call cleared: " .. tostring(reason))
  end
end

function boop.targets.waitingForTargetCall()
  if not targetCallEnabled() then
    return false
  end

  local calledId = tostring(boop.state and boop.state.calledTargetId or "")
  if calledId == "" then
    return true
  end

  local calledRoom = tostring(boop.state and boop.state.calledTargetRoom or "")
  local roomId = currentRoomId()
  if calledRoom ~= "" and roomId ~= "" and calledRoom ~= roomId then
    return true
  end

  return findDenizenById(boop.state and boop.state.denizens or {}, calledId) == nil
end

function boop.targets.onPartyTargetCall(speaker, targetId, _rawLine)
  local leader = configuredLeader()
  local caller = boop.util.trim(speaker or "")
  local calledId = boop.util.trim(tostring(targetId or ""))

  if not targetCallEnabled() then
    return false
  end
  if leader == "" or caller == "" or calledId == "" then
    return false
  end
  if not sameSpeaker(caller, leader) then
    return false
  end

  boop.state = boop.state or {}
  boop.state.calledTargetId = calledId
  boop.state.calledTargetRoom = currentRoomId()
  boop.state.calledTargetBy = caller
  boop.state.calledTargetAt = os.clock()

  if boop.trace and boop.trace.log then
    boop.trace.log(string.format("leader target call: %s -> %s", caller, calledId))
  end

  if boop.util and boop.util.info then
    boop.util.info(string.format("leader target: %s (%s)", calledId, caller))
  end

  if boop.config and boop.config.enabled and not (boop.state and boop.state.diagHold) and tempTimer then
    tempTimer(0, function()
      if boop and boop.tick then
        boop.tick()
      end
    end)
  end
  return true
end

local function listContains(list, name)
  if not list then return false end
  for _, v in ipairs(list) do
    if sameName(v, name) then return true end
  end
  return false
end

local function normalizeBlacklistArea(area)
  local raw = boop.util.safeLower(boop.util.trim(area or ""))
  if raw == "" then
    return boop.targets.getArea()
  end
  if raw == "global" or raw == "all" or raw == "*" then
    return "GLOBAL"
  end
  return area
end

local function blacklistListForArea(area)
  local resolved = normalizeBlacklistArea(area)
  boop.lists = boop.lists or {}
  if resolved == "GLOBAL" then
    boop.lists.globalBlacklist = boop.lists.globalBlacklist or {}
    return boop.lists.globalBlacklist, resolved
  end
  boop.lists.blacklist = boop.lists.blacklist or {}
  boop.lists.blacklist[resolved] = boop.lists.blacklist[resolved] or {}
  return boop.lists.blacklist[resolved], resolved
end

function boop.targets.isGloballyBlacklisted(name)
  return listContains(boop.lists and boop.lists.globalBlacklist, name)
end

function boop.targets.isWhitelisted(area, name)
  local resolvedArea = area or boop.targets.getArea()
  local list = boop.lists and boop.lists.whitelist and boop.lists.whitelist[resolvedArea] or {}
  return listContains(list, name)
end

function boop.targets.isBlacklisted(area, name)
  if boop.targets.isGloballyBlacklisted(name) then
    return true
  end
  local resolvedArea = area or boop.targets.getArea()
  local list = boop.lists and boop.lists.blacklist and boop.lists.blacklist[resolvedArea] or {}
  return listContains(list, name)
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

local function currentTargetEligible(mode, area, denizens)
  local currentId = tostring(boop.state.currentTargetId or "")
  if currentId == "" then return "" end

  local current = findDenizenById(denizens, currentId)
  if not current then return "" end

  if mode == "whitelist" then
    local whitelist = boop.lists.whitelist[area]
    if not whitelist or #whitelist == 0 then return "" end
    if listContains(whitelist, current.name) then
      return current.id
    end
    return ""
  end

  if mode == "blacklist" then
    local blacklist = boop.lists.blacklist[area] or {}
    if listContains(blacklist, current.name) or listContains(boop.lists.globalBlacklist, current.name) then
      return ""
    end
    return current.id
  end

  if mode == "auto" then
    if listContains(boop.lists.globalBlacklist, current.name) then
      return ""
    end
    return current.id
  end

  return ""
end

local function calledTargetEligible(mode, area, denizens)
  if not targetCallEnabled() then
    return ""
  end

  local calledId = tostring(boop.state and boop.state.calledTargetId or "")
  if calledId == "" then
    return ""
  end

  local calledRoom = tostring(boop.state and boop.state.calledTargetRoom or "")
  local roomId = currentRoomId()
  if calledRoom ~= "" and roomId ~= "" and calledRoom ~= roomId then
    return ""
  end

  local denizen = findDenizenById(denizens, calledId)
  if not denizen then
    return ""
  end

  if mode == "whitelist" then
    local whitelist = boop.lists.whitelist[area]
    if whitelist and #whitelist > 0 and listContains(whitelist, denizen.name) then
      return denizen.id
    end
    return ""
  end

  if mode == "blacklist" then
    local blacklist = boop.lists.blacklist[area] or {}
    if not listContains(blacklist, denizen.name) and not listContains(boop.lists.globalBlacklist, denizen.name) then
      return denizen.id
    end
    return ""
  end

  if mode == "auto" then
    if not boop.targets.isGloballyBlacklisted(denizen.name) then
      return denizen.id
    end
    return ""
  end

  return denizen.id
end

function boop.targets.choose()
  local mode = boop.config.targetingMode
  local area = boop.targets.getArea()
  local denizens = sortedDenizens(boop.config.targetOrder)

  if mode == "manual" then
    return boop.state.currentTargetId
  end

  if targetCallEnabled() then
    return calledTargetEligible(mode, area, denizens)
  end

  if boop.config.retargetOnPriority == false then
    local keep = currentTargetEligible(mode, area, denizens)
    if keep ~= "" then
      return keep
    end
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
      if not boop.targets.isGloballyBlacklisted(denizen.name) then
        return denizen.id
      end
    end
  end

  return ""
end

function boop.targets.addWhitelist(area, name)
  area = area or boop.targets.getArea()
  name = boop.util.trim(name or "")
  if name == "" then
    boop.util.info("Usage: boop whitelist add <name>")
    return false
  end

  boop.lists.whitelist[area] = boop.lists.whitelist[area] or {}
  if listContains(boop.lists.whitelist[area], name) then
    boop.util.warn("Already whitelisted in " .. area .. ": " .. name)
    return false
  end

  boop.lists.whitelist[area][#boop.lists.whitelist[area] + 1] = name

  if boop.db and boop.db.saveList then
    boop.db.saveList("whitelist", area, boop.lists.whitelist[area])
  end
  boop.util.ok("Whitelisted in " .. area .. ": " .. name)
  return true
end

function boop.targets.removeWhitelist(area, name)
  area = area or boop.targets.getArea()
  name = boop.util.trim(name or "")
  if name == "" then
    boop.util.info("Usage: boop whitelist remove <name>")
    return false
  end
  local list = boop.lists.whitelist[area]
  if not list or #list == 0 then
    boop.util.warn("Whitelist is empty for " .. area)
    return false
  end
  for i, v in ipairs(list) do
    if sameName(v, name) then
      local removedName = v
      table.remove(list, i)
      if boop.db and boop.db.saveList then
        boop.db.saveList("whitelist", area, list)
      end
      boop.util.ok("Removed from whitelist in " .. area .. ": " .. removedName)
      return true
    end
  end
  boop.util.warn("Not found in whitelist for " .. area .. ": " .. name)
  return false
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
  local list
  list, area = blacklistListForArea(area)
  name = boop.util.trim(name or "")
  if name == "" then
    boop.util.info("Usage: boop blacklist add <name>")
    boop.util.info("Usage: boop blacklist global add <name>")
    return false
  end

  if listContains(list, name) then
    boop.util.warn("Already blacklisted in " .. area .. ": " .. name)
    return false
  end

  list[#list + 1] = name

  if boop.db and boop.db.saveList then
    boop.db.saveList("blacklist", area, list)
  end
  boop.util.ok("Blacklisted in " .. area .. ": " .. name)
  return true
end

function boop.targets.removeBlacklist(area, name)
  local list
  list, area = blacklistListForArea(area)
  name = boop.util.trim(name or "")
  if name == "" then
    boop.util.info("Usage: boop blacklist remove <name>")
    boop.util.info("Usage: boop blacklist global remove <name>")
    return false
  end
  if not list or #list == 0 then
    boop.util.warn("Blacklist is empty for " .. area)
    return false
  end
  for i, v in ipairs(list) do
    if sameName(v, name) then
      local removedName = v
      table.remove(list, i)
      if boop.db and boop.db.saveList then
        boop.db.saveList("blacklist", area, list)
      end
      boop.util.ok("Removed from blacklist in " .. area .. ": " .. removedName)
      return true
    end
  end
  boop.util.warn("Not found in blacklist for " .. area .. ": " .. name)
  return false
end

function boop.targets.shiftBlacklist(area, index, direction)
  local list
  list, area = blacklistListForArea(area)
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
      local xpSummary = boop.stats and boop.stats.formatMobXp and boop.stats.formatMobXp(area, name) or nil
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

      if xpSummary then
        cecho("\n     <grey>" .. xpSummary .. "<reset>")
      end
    end
    return
  end

  boop.util.echo("Whitelist for " .. area .. ":")
  if #list == 0 then
    boop.util.echo("  (empty)")
    return
  end
  for i, v in ipairs(list) do
    local xpSummary = boop.stats and boop.stats.formatMobXp and boop.stats.formatMobXp(area, v) or nil
    if xpSummary then
      boop.util.echo("  " .. i .. ". " .. v .. " | " .. xpSummary)
    else
      boop.util.echo("  " .. i .. ". " .. v)
    end
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
    boop.util.warn("Unknown whitelist area: " .. tostring(area))
    return
  end
  local tags = getAreaTags(resolved)
  if #tags == 0 then
    boop.util.info("Whitelist tags for " .. resolved .. ": (none)")
    boop.util.info("Add with: boop whitelist tag add " .. resolved .. " | <tag[,tag2,...]>")
    return
  end
  boop.util.info("Whitelist tags for " .. resolved .. ": " .. table.concat(tags, ", "))
end

function boop.targets.addWhitelistTags(area, rawTags)
  local resolved = findWhitelistArea(area)
  if resolved == "" then
    boop.util.warn("Unknown whitelist area: " .. tostring(area))
    boop.util.info("Use: boop whitelist browse")
    return
  end
  local list = boop.lists.whitelist[resolved] or {}
  if #list == 0 then
    boop.util.warn("Area has no whitelist entries: " .. resolved)
    return
  end

  local incoming = splitTags(rawTags)
  if #incoming == 0 then
    boop.util.info("Usage: boop whitelist tag add <area> | <tag[,tag2,...]>")
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
  boop.util.ok(string.format("Whitelist tags updated for %s: %s (added %d)", resolved, table.concat(tags, ", "), added))
end

function boop.targets.removeWhitelistTags(area, rawTags)
  local resolved = findWhitelistArea(area)
  if resolved == "" then
    boop.util.warn("Unknown whitelist area: " .. tostring(area))
    boop.util.info("Use: boop whitelist browse")
    return
  end

  local incoming = splitTags(rawTags)
  if #incoming == 0 then
    boop.util.info("Usage: boop whitelist tag remove <area> | <tag[,tag2,...]>")
    return
  end

  local tags = getAreaTags(resolved)
  if #tags == 0 then
    boop.util.warn("No tags set for " .. resolved)
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
    boop.util.ok(string.format("Whitelist tags cleared for %s (removed %d)", resolved, removed))
  else
    boop.util.ok(string.format("Whitelist tags updated for %s: %s (removed %d)", resolved, table.concat(out, ", "), removed))
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
  local list
  list, area = blacklistListForArea(area)
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
  local captured = boop.util.trim(tostring(name))
  if captured == "" then return end

  local current = boop.util.trim(boop.state.targetName or "")
  if current == "" and (boop.state.currentTargetId or "") ~= "" then
    boop.state.targetName = captured
    current = captured
  end

  if current ~= "" and sameName(current, captured) then
    if boop.state.targetShield and boop.state.targetShield.timer then
      killTimer(boop.state.targetShield.timer)
    end
    boop.state.targetShield = { gained = os.clock(), attempted = false }
    boop.state.targetShield.timer = tempTimer(3, function() boop.state.targetShield = false end)
    if boop.trace and boop.trace.log then
      boop.trace.log("shield seen: " .. captured)
    end
  end
end

local function resolveShieldCapture(expr, matchTable)
  if type(expr) ~= "table" then return "" end
  if expr.kind == "match" then
    local idx = tonumber(expr.index)
    if not idx or type(matchTable) ~= "table" then return "" end
    return tostring(matchTable[idx] or "")
  end
  if expr.kind == "literal" then
    return tostring(expr.value or "")
  end
  return ""
end

local function findTargetNameFromMatches(matchTable)
  if type(matchTable) ~= "table" then return "" end
  local current = boop.util.trim(boop.state and boop.state.targetName or "")
  if current == "" then return "" end
  for i = 2, #matchTable do
    local text = boop.util.trim(tostring(matchTable[i] or ""))
    if text ~= "" and sameName(text, current) then
      return text
    end
  end
  return ""
end

function boop.targets.onShieldDownTrigger(spec, matchTable, rawLine)
  boop.state = boop.state or {}
  local current = boop.util.trim(boop.state.targetName or "")
  if current == "" and (boop.state.currentTargetId or "") == "" then
    return false
  end

  local source = boop.util.trim(spec and spec.source or "shield trigger")
  local candidate = ""
  if type(spec) == "table" then
    candidate = boop.util.trim(resolveShieldCapture(spec.target, matchTable))
  end
  if candidate == "" then
    candidate = findTargetNameFromMatches(matchTable)
  end

  if current == "" and candidate ~= "" and (boop.state.currentTargetId or "") ~= "" then
    if boop.targets.isDenizenName and boop.targets.isDenizenName(candidate) then
      boop.state.targetName = candidate
      current = candidate
    end
  end

  if current == "" then
    return false
  end

  if current ~= "" and candidate ~= "" and not sameName(current, candidate) then
    local fallback = findTargetNameFromMatches(matchTable)
    if fallback == "" or not sameName(current, fallback) then
      return false
    end
    candidate = fallback
  end

  local lineText = boop.util.trim(rawLine or "")
  boop.targets.clearTargetShield(source .. (lineText ~= "" and (": " .. lineText) or ""))
  return true
end

function boop.targets.onShieldbreakAttempt()
  if not boop.state.targetShield then return end
  if type(boop.state.targetShield) ~= "table" then
    boop.state.targetShield = { gained = os.clock() }
  end
  boop.state.targetShield.attempted = true
  boop.state.targetShield.lastAttempt = os.clock()
end

function boop.targets.clearTargetShield(reason)
  if boop.state and type(boop.state.targetShield) == "table" and boop.state.targetShield.timer then
    killTimer(boop.state.targetShield.timer)
  end
  boop.state.targetShield = false
  if reason and boop.trace and boop.trace.log then
    boop.trace.log("shield cleared: " .. tostring(reason))
  end
end
