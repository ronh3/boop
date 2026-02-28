boop.gag = boop.gag or {}

local function nowSeconds()
  if getEpoch then
    return getEpoch()
  end
  return os.clock()
end

local function resolveCapture(expr, matchTable)
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

local function normName(name)
  local value = boop.util.trim(tostring(name or ""))
  value = value:gsub("\226\128\152", "'")
  value = value:gsub("\226\128\153", "'")
  return boop.util.safeLower(value)
end

local function isSelfActor(actor, rawLine)
  local value = boop.util.trim(actor or "")
  local lower = boop.util.safeLower(value)
  if lower == "you" then
    return true
  end

  local me = gmcp and gmcp.Char and gmcp.Char.Name and gmcp.Char.Name.name or ""
  if me ~= "" and boop.util.safeLower(me) == lower then
    return true
  end

  local lineText = boop.util.safeLower(boop.util.trim(rawLine or ""))
  if boop.util.starts(lineText, "you ") or boop.util.starts(lineText, "you:") then
    return true
  end

  return false
end

local function findLikelyActor(matchTable)
  if type(matchTable) ~= "table" then return "" end
  local me = gmcp and gmcp.Char and gmcp.Char.Name and gmcp.Char.Name.name or ""
  local meLower = boop.util.safeLower(me)
  for i = 2, #matchTable do
    local text = boop.util.trim(tostring(matchTable[i] or ""))
    local lower = boop.util.safeLower(text)
    if lower == "you" then
      return "You"
    end
    if text ~= "" and meLower ~= "" and lower == meLower then
      return me
    end
  end
  for i = 2, #matchTable do
    local text = boop.util.trim(tostring(matchTable[i] or ""))
    if text ~= "" then
      return text
    end
  end
  return ""
end

local function findLikelyTarget(matchTable, actor)
  if type(matchTable) ~= "table" then return "" end
  local actorNorm = normName(actor)

  if boop.targets and boop.targets.isDenizenName then
    for i = 2, #matchTable do
      local text = boop.util.trim(tostring(matchTable[i] or ""))
      if text ~= "" and normName(text) ~= actorNorm and boop.targets.isDenizenName(text) then
        return text
      end
    end
  end

  for i = 2, #matchTable do
    local text = boop.util.trim(tostring(matchTable[i] or ""))
    if text ~= "" and normName(text) ~= actorNorm then
      return text
    end
  end
  return ""
end

local function shouldSuppressDuplicate(rawLine)
  boop.state = boop.state or {}
  local lineText = tostring(rawLine or "")
  local ts = nowSeconds()
  local prevLine = boop.state.lastGagRawLine or ""
  local prevTs = tonumber(boop.state.lastGagAt) or 0
  if prevLine == lineText and (ts - prevTs) <= 0.05 then
    return true
  end
  boop.state.lastGagRawLine = lineText
  boop.state.lastGagAt = ts
  return false
end

local function emitReplacement(actor, ability, victim, selfActor)
  local who = boop.util.trim(actor or "")
  if who == "" then
    who = selfActor and "You" or "Unknown"
  end

  local what = boop.util.trim(ability or "")
  if what == "" then
    what = "Attack"
  end

  local target = boop.util.trim(victim or "")
  if target == "" then
    target = "(none)"
  end

  local msg = string.format("%s: %s -> %s", who, what, target)
  if cecho then
    local color = selfActor and "#6ecb5a" or "#d4d4d4"
    cecho("\n<" .. color .. ">" .. msg .. "<reset>")
  else
    echo("\n" .. msg)
  end
end

function boop.gag.showStatus()
  boop.util.echo("gag own attacks: " .. (boop.config.gagOwnAttacks and "on" or "off"))
  boop.util.echo("gag others attacks: " .. (boop.config.gagOthersAttacks and "on" or "off"))
end

function boop.gag.setOwn(value)
  local enabled = value and true or false
  boop.config.gagOwnAttacks = enabled
  if boop.db and boop.db.saveConfig then
    boop.db.saveConfig("gagOwnAttacks", enabled)
  end
  boop.util.echo("gag own attacks: " .. (enabled and "on" or "off"))
end

function boop.gag.setOthers(value)
  local enabled = value and true or false
  boop.config.gagOthersAttacks = enabled
  if boop.db and boop.db.saveConfig then
    boop.db.saveConfig("gagOthersAttacks", enabled)
  end
  boop.util.echo("gag others attacks: " .. (enabled and "on" or "off"))
end

function boop.gag.setBoth(value)
  boop.gag.setOwn(value)
  boop.gag.setOthers(value)
end

function boop.gag.onAttackLine(spec, matchTable, rawLine)
  if not boop.config then return end
  if not boop.config.gagOwnAttacks and not boop.config.gagOthersAttacks then
    return
  end
  if shouldSuppressDuplicate(rawLine) then
    return
  end

  local actor = boop.util.trim(resolveCapture(spec and spec.actor, matchTable))
  if actor == "" then
    actor = findLikelyActor(matchTable)
  end
  local selfActor = isSelfActor(actor, rawLine)

  if selfActor and not boop.config.gagOwnAttacks then
    return
  end
  if (not selfActor) and not boop.config.gagOthersAttacks then
    return
  end

  local victim = boop.util.trim(resolveCapture(spec and spec.target, matchTable))
  if victim == "" then
    victim = findLikelyTarget(matchTable, actor)
  end
  if victim == "" and selfActor then
    victim = boop.state and boop.state.targetName or ""
  end

  local ability = boop.util.trim(spec and spec.ability or "")

  if selectCurrentLine then
    selectCurrentLine()
  end
  if deleteLine then
    deleteLine()
  end

  emitReplacement(actor, ability, victim, selfActor)

  if boop.trace and boop.trace.log then
    boop.trace.log(string.format("gag: %s | actor=%s | ability=%s | target=%s", selfActor and "self" or "other", actor ~= "" and actor or "?", ability ~= "" and ability or "?", victim ~= "" and victim or "?"))
  end
end
