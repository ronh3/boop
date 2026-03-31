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

local function selfName()
  if gmcp and gmcp.Char and gmcp.Char.Status and gmcp.Char.Status.name then
    return boop.util.trim(gmcp.Char.Status.name)
  end
  if gmcp and gmcp.Char and gmcp.Char.Name and gmcp.Char.Name.name then
    return boop.util.trim(gmcp.Char.Name.name)
  end
  return ""
end

local function configuredLeader()
  return boop.util.trim((boop.config and boop.config.assistLeader) or "")
end

local function targetCallEnabled()
  return not not (boop.config and boop.config.targetCall and boop.config.targetingMode ~= "manual")
end

local function autoTargetCallEnabled()
  return not not (boop.config and boop.config.autoTargetCall)
end

local WHITELIST_SHARE_PREFIX = "BOOPWL"
local WHITELIST_SHARE_VERSION = "1"
local WHITELIST_SHARE_LINE_LIMIT = 180

local function storeCalledTarget(caller, targetId)
  boop.state = boop.state or {}
  boop.state.targeting.calledTargetId = targetId
  boop.state.targeting.calledTargetRoom = currentRoomId()
  boop.state.targeting.calledTargetBy = caller
  boop.state.targeting.calledTargetAt = os.clock()
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

local function packetEncode(value)
  local text = tostring(value or "")
  return (text:gsub("([^%w%-_%.~])", function(ch)
    return string.format("%%%02X", string.byte(ch))
  end))
end

local function packetDecode(value)
  local text = tostring(value or "")
  return (text:gsub("%%(%x%x)", function(hex)
    return string.char(tonumber(hex, 16))
  end))
end

local function splitPacket(payload)
  local parts = {}
  for part in tostring(payload or ""):gmatch("[^|]+") do
    parts[#parts + 1] = part
  end
  return parts
end

local function shareState()
  boop.state = boop.state or {}
  boop.state.targeting = boop.state.targeting or {}
  boop.state.targeting.incomingWhitelistShares = boop.state.targeting.incomingWhitelistShares or {}
  return boop.state.targeting
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
  for _, v in ipairs(boop.state.targeting.denizens or {}) do
    if sameName(v.name, name) then
      return true
    end
  end
  return false
end

function boop.targets.updateRoomItems(items)
  boop.state.targeting.denizens = {}
  if not items then return end
  for _, item in ipairs(items) do
    if boop.targets.isValidDenizen(item) then
      boop.state.targeting.denizens[#boop.state.targeting.denizens + 1] = {
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
  for _, v in ipairs(boop.state.targeting.denizens) do
    if v.id == id then return end
  end
  boop.state.targeting.denizens[#boop.state.targeting.denizens + 1] = {
    id = id,
    name = item.name,
    attrib = item.attrib,
  }
end

function boop.targets.removeRoomItem(item)
  local id = tostring(item.id)
  for i, v in ipairs(boop.state.targeting.denizens) do
    if v.id == id then
      table.remove(boop.state.targeting.denizens, i)
      break
    end
  end
end

function boop.targets.setTarget(id)
  if not id or id == "" then return end
  local nextId = tostring(id)
  local prevId = tostring(boop.state.targeting.currentTargetId or "")
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
  boop.state.targeting.currentTargetId = nextId
  for _, v in ipairs(boop.state.targeting.denizens) do
    if v.id == boop.state.targeting.currentTargetId then
      boop.state.targeting.targetName = v.name
      break
    end
  end

  if changed and boop.stats and boop.stats.onTargetSet then
    boop.stats.onTargetSet(boop.state.targeting.currentTargetId, boop.state.targeting.targetName or "")
  end

  if changed and send then
    send("settarget " .. boop.state.targeting.currentTargetId, false)
  end
  if changed and autoTargetCallEnabled() and send then
    local caller = selfName()
    if caller == "" then
      caller = "self"
    end
    storeCalledTarget(caller, boop.state.targeting.currentTargetId)
    send("pt Target: " .. boop.state.targeting.currentTargetId .. ".", false)
    if boop.trace and boop.trace.log then
      boop.trace.log(string.format("auto target call: %s -> %s", caller, boop.state.targeting.currentTargetId))
    end
  end
end

function boop.targets.clearTargetCall(reason)
  boop.state = boop.state or {}
  boop.state.targeting.calledTargetId = ""
  boop.state.targeting.calledTargetRoom = ""
  boop.state.targeting.calledTargetBy = ""
  boop.state.targeting.calledTargetAt = nil
  if reason and boop.trace and boop.trace.log then
    boop.trace.log("target call cleared: " .. tostring(reason))
  end
end

function boop.targets.waitingForTargetCall()
  if not targetCallEnabled() then
    return false
  end

  local calledId = tostring(boop.state and boop.state.targeting.calledTargetId or "")
  if calledId == "" then
    return true
  end

  local calledRoom = tostring(boop.state and boop.state.targeting.calledTargetRoom or "")
  local roomId = currentRoomId()
  if calledRoom ~= "" and roomId ~= "" and calledRoom ~= roomId then
    return true
  end

  return findDenizenById(boop.state and boop.state.targeting.denizens or {}, calledId) == nil
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

  storeCalledTarget(caller, calledId)

  if boop.trace and boop.trace.log then
    boop.trace.log(string.format("leader target call: %s -> %s", caller, calledId))
  end

  if boop.util and boop.util.info then
    boop.util.info(string.format("leader target: %s (%s)", calledId, caller))
  end

  if boop.config and boop.config.enabled and not (boop.state and boop.state.diag.hold) and tempTimer then
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

local function copyList(list)
  local out = {}
  for _, value in ipairs(list or {}) do
    out[#out + 1] = value
  end
  return out
end

local function dedupeList(list)
  local out = {}
  local seen = {}
  for _, value in ipairs(list or {}) do
    local name = boop.util.trim(value or "")
    local key = normalizeName(name)
    if key ~= "" and not seen[key] then
      seen[key] = true
      out[#out + 1] = name
    end
  end
  return out
end

local function listKeySet(list)
  local out = {}
  for _, value in ipairs(list or {}) do
    local key = normalizeName(value)
    if key ~= "" then
      out[key] = true
    end
  end
  return out
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

local findWhitelistArea
local resolveWhitelistArea

local function pendingWhitelistShare()
  return shareState().pendingWhitelistShare
end

local function buildWhitelistShareToken()
  local stamp
  if getEpoch then
    stamp = tostring(math.floor(getEpoch()))
  else
    stamp = tostring(math.floor(os.clock() * 1000000))
  end
  return stamp
end

local function buildWhitelistDataPackets(token, list)
  local packets = {}
  local prefix = string.format("%s|D|%s|%s", WHITELIST_SHARE_PREFIX, WHITELIST_SHARE_VERSION, token)
  local current = prefix
  local count = 0

  for _, name in ipairs(list or {}) do
    local encoded = packetEncode(name)
    if count > 0 and (#current + 1 + #encoded) > WHITELIST_SHARE_LINE_LIMIT then
      packets[#packets + 1] = current
      current = prefix .. "|" .. encoded
      count = 1
    else
      current = current .. "|" .. encoded
      count = count + 1
    end
  end

  if count > 0 then
    packets[#packets + 1] = current
  end

  return packets
end

local function trustedWhitelistShareSpeaker(speaker)
  local caller = boop.util.trim(speaker or "")
  if caller == "" then
    return false
  end

  local me = selfName()
  if me ~= "" and sameSpeaker(caller, me) then
    return false
  end

  local leader = configuredLeader()
  if leader == "" then
    return true
  end
  return sameSpeaker(caller, leader)
end

local function buildWhitelistApplyResult(mode, currentList, incomingList)
  local current = dedupeList(currentList or {})
  local incoming = dedupeList(incomingList or {})
  local result = {}
  local stats = {
    added = 0,
    extras = 0,
    shared = 0,
  }

  if mode == "overwrite" then
    return copyList(incoming), stats
  end

  if mode == "merge" then
    result = copyList(current)
    local seen = listKeySet(current)
    for _, name in ipairs(incoming) do
      local key = normalizeName(name)
      if key ~= "" and not seen[key] then
        seen[key] = true
        result[#result + 1] = name
        stats.added = stats.added + 1
      end
    end
    return result, stats
  end

  local currentKeys = listKeySet(current)
  local seen = {}

  for _, name in ipairs(incoming) do
    local key = normalizeName(name)
    if key ~= "" and currentKeys[key] and not seen[key] then
      seen[key] = true
      result[#result + 1] = name
      stats.shared = stats.shared + 1
    end
  end

  for _, name in ipairs(incoming) do
    local key = normalizeName(name)
    if key ~= "" and not seen[key] then
      seen[key] = true
      result[#result + 1] = name
      stats.added = stats.added + 1
    end
  end

  for _, name in ipairs(current) do
    local key = normalizeName(name)
    if key ~= "" and not seen[key] then
      seen[key] = true
      result[#result + 1] = name
      stats.extras = stats.extras + 1
    end
  end

  return result, stats
end

local function clearIncomingWhitelistShare(token)
  if token == nil or token == "" then
    return
  end
  shareState().incomingWhitelistShares[token] = nil
end

local function showPendingWhitelistShare()
  local pending = pendingWhitelistShare()
  if type(pending) ~= "table" then
    boop.util.info("No pending whitelist share.")
    return false
  end

  local sender = boop.util.trim(pending.sender or "")
  local area = boop.util.trim(pending.area or "")
  local entries = pending.entries or {}
  local current = boop.lists and boop.lists.whitelist and boop.lists.whitelist[area] or {}

  if cecho and cechoLink then
    cecho("\n<green>boop<reset>: <white>Pending whitelist share")
    cecho("\n  <cyan>From:<reset> <white>" .. sender .. "<reset>")
    cecho("\n  <cyan>Area:<reset> <white>" .. area .. "<reset>")
    cecho(string.format("\n  <cyan>Entries:<reset> <white>%d incoming<reset> <grey>| current %d<reset>", #entries, #current))
    cecho("\n  <cyan>Apply:<reset> ")
    cechoLink("<green>[merge]<reset>", function() boop.targets.receiveWhitelistShare("merge") end, "Keep your order, append missing leader entries", true)
    cecho(" ")
    cechoLink("<yellow>[merge-reorder]<reset>", function() boop.targets.receiveWhitelistShare("merge-reorder") end, "Match shared priorities, append your extras at the bottom", true)
    cecho(" ")
    cechoLink("<red>[overwrite]<reset>", function() boop.targets.receiveWhitelistShare("overwrite") end, "Replace your area whitelist with the incoming list", true)
    cecho(" ")
    cechoLink("<grey>[reject]<reset>", function() boop.targets.receiveWhitelistShare("reject") end, "Discard the pending whitelist share", true)

    if #entries > 0 then
      cecho("\n  <cyan>Preview:<reset>")
      local limit = math.min(#entries, 10)
      for i = 1, limit do
        cecho(string.format("\n    <yellow>%d.<reset> <white>%s<reset>", i, entries[i]))
      end
      if #entries > limit then
        cecho(string.format("\n    <grey>... +%d more<reset>", #entries - limit))
      end
    end
    return true
  end

  boop.util.echo("Pending whitelist share:")
  boop.util.echo("  from: " .. sender)
  boop.util.echo("  area: " .. area)
  boop.util.echo(string.format("  entries: %d incoming | current %d", #entries, #current))
  boop.util.echo("  apply: boop whitelist receive merge|merge-reorder|overwrite|reject")
  return true
end

function boop.targets.getPendingWhitelistShare()
  return pendingWhitelistShare()
end

function boop.targets.shareWhitelist(area)
  local resolved = resolveWhitelistArea(area)
  if resolved == "" then
    boop.util.warn("Unknown whitelist area: " .. tostring(area))
    boop.util.info("Use: boop whitelist browse")
    return false
  end

  local list = dedupeList((boop.lists and boop.lists.whitelist and boop.lists.whitelist[resolved]) or {})
  if #list == 0 then
    boop.util.warn("Area has no whitelist entries: " .. resolved)
    return false
  end
  if not send then
    boop.util.err("Cannot share whitelist: send() is unavailable.")
    return false
  end

  local token = buildWhitelistShareToken()
  send(string.format("pt %s|S|%s|%s|%s|%d",
    WHITELIST_SHARE_PREFIX,
    WHITELIST_SHARE_VERSION,
    token,
    packetEncode(resolved),
    #list), false)
  for _, payload in ipairs(buildWhitelistDataPackets(token, list)) do
    send("pt " .. payload, false)
  end
  send(string.format("pt %s|E|%s|%s", WHITELIST_SHARE_PREFIX, WHITELIST_SHARE_VERSION, token), false)

  if boop.trace and boop.trace.log then
    boop.trace.log(string.format("whitelist share: %s (%d entries)", resolved, #list))
  end
  boop.util.ok(string.format("Shared whitelist for %s via pt (%d entries).", resolved, #list))
  return true
end

function boop.targets.onPartyWhitelistShare(speaker, payload, _rawLine)
  local caller = boop.util.trim(speaker or "")
  local parts = splitPacket(payload)
  if parts[1] ~= WHITELIST_SHARE_PREFIX then
    return false
  end

  local kind = tostring(parts[2] or "")
  local version = tostring(parts[3] or "")
  local token = tostring(parts[4] or "")
  if version ~= WHITELIST_SHARE_VERSION or token == "" then
    return false
  end
  if not trustedWhitelistShareSpeaker(caller) then
    return false
  end

  local state = shareState()
  if kind == "S" then
    local area = packetDecode(parts[5] or "")
    local expectedCount = tonumber(parts[6]) or 0
    if area == "" or expectedCount < 1 then
      return false
    end
    state.incomingWhitelistShares[token] = {
      token = token,
      sender = caller,
      area = area,
      expectedCount = expectedCount,
      entries = {},
    }
    if boop.trace and boop.trace.log then
      boop.trace.log(string.format("whitelist share start: %s -> %s (%d)", caller, area, expectedCount))
    end
    return true
  end

  local share = state.incomingWhitelistShares[token]
  if type(share) ~= "table" or not sameSpeaker(share.sender, caller) then
    return false
  end

  if kind == "D" then
    for i = 5, #parts do
      share.entries[#share.entries + 1] = packetDecode(parts[i] or "")
    end
    return true
  end

  if kind == "E" then
    local entries = dedupeList(share.entries)
    clearIncomingWhitelistShare(token)
    if #entries ~= share.expectedCount then
      boop.util.warn(string.format("Ignored incomplete whitelist share from %s for %s (%d/%d entries).",
        caller, share.area, #entries, share.expectedCount))
      return false
    end

    share.entries = entries
    state.pendingWhitelistShare = share
    if boop.trace and boop.trace.log then
      boop.trace.log(string.format("whitelist share ready: %s -> %s (%d)", caller, share.area, #entries))
    end
    boop.util.info(string.format("Received whitelist share from %s for %s (%d entries).", caller, share.area, #entries))
    boop.util.info("Use: boop whitelist receive")
    return true
  end

  return false
end

function boop.targets.receiveWhitelistShare(rawMode)
  local mode = boop.util.safeLower(boop.util.trim(rawMode or ""))
  if mode == "" or mode == "show" or mode == "status" then
    return showPendingWhitelistShare()
  end

  local pending = pendingWhitelistShare()
  if type(pending) ~= "table" then
    boop.util.info("No pending whitelist share.")
    return false
  end

  if mode == "reject" or mode == "clear" then
    shareState().pendingWhitelistShare = nil
    boop.util.ok(string.format("Rejected whitelist share from %s for %s.", tostring(pending.sender or "unknown"), tostring(pending.area or "UNKNOWN")))
    return true
  end

  if mode ~= "merge" and mode ~= "merge-reorder" and mode ~= "overwrite" then
    boop.util.info("Usage: boop whitelist receive [merge|merge-reorder|overwrite|reject]")
    return false
  end

  local area = boop.util.trim(pending.area or "")
  local current = (boop.lists and boop.lists.whitelist and boop.lists.whitelist[area]) or {}
  local result, stats = buildWhitelistApplyResult(mode, current, pending.entries or {})
  boop.lists.whitelist[area] = result
  if boop.db and boop.db.saveList then
    boop.db.saveList("whitelist", area, result)
  end
  shareState().pendingWhitelistShare = nil

  if boop.trace and boop.trace.log then
    boop.trace.log(string.format("whitelist share applied: %s mode=%s count=%d", area, mode, #result))
  end

  if mode == "merge" then
    boop.util.ok(string.format("Whitelist updated for %s via merge (%d added, %d total).", area, stats.added, #result))
  elseif mode == "merge-reorder" then
    boop.util.ok(string.format("Whitelist updated for %s via merge-reorder (%d shared reordered, %d added, %d local extras kept).",
      area, stats.shared, stats.added, stats.extras))
  else
    boop.util.ok(string.format("Whitelist overwritten for %s (%d entries).", area, #result))
  end
  return true
end

local function normalizeTag(tag)
  local t = boop.util.safeLower(boop.util.trim(tag or ""))
  t = t:gsub("%s+", "-")
  t = t:gsub("[^%w%-%_]", "")
  return t
end

findWhitelistArea = function(area)
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

resolveWhitelistArea = function(area)
  local raw = boop.util.trim(area or "")
  if raw == "" then
    return boop.targets.getArea()
  end
  return findWhitelistArea(raw)
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
  for _, v in ipairs(boop.state.targeting.denizens) do
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
  local currentId = tostring(boop.state.targeting.currentTargetId or "")
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

  local calledId = tostring(boop.state and boop.state.targeting.calledTargetId or "")
  if calledId == "" then
    return ""
  end

  local calledRoom = tostring(boop.state and boop.state.targeting.calledTargetRoom or "")
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
    return boop.state.targeting.currentTargetId
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
    cecho("\n<green>boop<reset>: <white>Whitelist for " .. area .. ": ")
    cechoLink("<cyan>[share pt]<reset>", function()
      boop.targets.shareWhitelist(area)
    end, "Share this area's whitelist to party chat", true)
    if pendingWhitelistShare() then
      cecho(" ")
      cechoLink("<yellow>[receive]<reset>", function()
        boop.targets.receiveWhitelistShare("")
      end, "Show the pending whitelist share", true)
    end
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
  boop.util.echo("  share: boop whitelist share " .. area)
  if pendingWhitelistShare() then
    boop.util.echo("  pending: boop whitelist receive")
  end
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

  local current = boop.util.trim(boop.state.targeting.targetName or "")
  if current == "" and (boop.state.targeting.currentTargetId or "") ~= "" then
    boop.state.targeting.targetName = captured
    current = captured
  end

  if current ~= "" and sameName(current, captured) then
    if boop.state.targeting.targetShield and boop.state.targeting.targetShield.timer then
      killTimer(boop.state.targeting.targetShield.timer)
    end
    boop.state.targeting.targetShield = { gained = os.clock(), attempted = false }
    boop.state.targeting.targetShield.timer = tempTimer(3, function() boop.state.targeting.targetShield = false end)
    if boop.trace and boop.trace.log then
      boop.trace.log("shield seen: " .. captured)
    end
    if boop.refreshPrequeuedStandard then
      boop.refreshPrequeuedStandard("shield seen")
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
  local current = boop.util.trim(boop.state and boop.state.targeting.targetName or "")
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
  local current = boop.util.trim(boop.state.targeting.targetName or "")
  if current == "" and (boop.state.targeting.currentTargetId or "") == "" then
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

  if current == "" and candidate ~= "" and (boop.state.targeting.currentTargetId or "") ~= "" then
    if boop.targets.isDenizenName and boop.targets.isDenizenName(candidate) then
      boop.state.targeting.targetName = candidate
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
  if not boop.state.targeting.targetShield then return end
  if type(boop.state.targeting.targetShield) ~= "table" then
    boop.state.targeting.targetShield = { gained = os.clock() }
  end
  boop.state.targeting.targetShield.attempted = true
  boop.state.targeting.targetShield.lastAttempt = os.clock()
end

function boop.targets.clearTargetShield(reason)
  if boop.state and type(boop.state.targeting.targetShield) == "table" and boop.state.targeting.targetShield.timer then
    killTimer(boop.state.targeting.targetShield.timer)
  end
  boop.state.targeting.targetShield = false
  if reason and boop.trace and boop.trace.log then
    boop.trace.log("shield cleared: " .. tostring(reason))
  end
end
