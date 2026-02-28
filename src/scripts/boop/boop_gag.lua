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
  if selfActor then
    who = "You"
  elseif who == "" then
    who = "Unknown"
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
    cecho(
      "\n<green>" .. who .. "<reset>: <cyan>" .. what .. "<reset> -> <red>" .. target .. "<reset>"
    )
  else
    echo("\n" .. msg)
  end
end

local function emitSimple(who, ability)
  local actor = boop.util.trim(who or "")
  if actor == "" then actor = "You" end
  local what = boop.util.trim(ability or "")
  if what == "" then what = "Action" end

  if cecho then
    cecho("\n<green>" .. actor .. "<reset>: <cyan>" .. what .. "<reset>")
  else
    echo("\n" .. actor .. ": " .. what)
  end
end

local function emitAttackSummary(entry)
  if type(entry) ~= "table" then return end
  local who = boop.util.trim(entry.who or "You")
  local what = boop.util.trim(entry.ability or "Attack")
  local target = boop.util.trim(entry.target or "(none)")
  local damage = boop.util.trim(entry.damageText or "")
  local bal = boop.util.trim(entry.balanceText or "")

  local suffix = ""
  if damage ~= "" then
    suffix = suffix .. " (" .. damage .. ")"
  end
  if bal ~= "" then
    suffix = suffix .. " (Bal: " .. bal .. ")"
  end

  if cecho then
    cecho(
      "\n<green>" .. who .. "<reset>: <cyan>" .. what .. "<reset> -> <red>" .. target .. "<reset><white>" .. suffix .. "<reset>"
    )
  else
    echo("\n" .. string.format("%s: %s -> %s%s", who, what, target, suffix))
  end
end

local function emitKillSummary(target, xp)
  local victim = boop.util.trim(target or "")
  if victim == "" then victim = "(unknown)" end
  local xpText = boop.util.trim(xp or "")

  local suffix = ""
  if xpText ~= "" then
    suffix = " (" .. xpText .. "xp)"
  end

  if cecho then
    cecho(
      "\n<green>You<reset>: <cyan>Killed<reset> -> <red>" .. victim .. "<reset><white>" .. suffix .. "<reset>"
    )
  else
    echo("\nYou: Killed -> " .. victim .. suffix)
  end
end

local function deleteCurrent()
  if selectCurrentLine then
    selectCurrentLine()
  end
  if deleteLine then
    deleteLine()
  end
end

local function cancelAttackSummaryTimer()
  boop.state = boop.state or {}
  if boop.state.gagPendingAttackTimer then
    killTimer(boop.state.gagPendingAttackTimer)
    boop.state.gagPendingAttackTimer = nil
  end
end

local flushPendingKill

local function flushPendingAttack()
  boop.state = boop.state or {}
  local pending = boop.state.gagPendingAttack
  if not pending then return end
  boop.state.gagPendingAttack = nil
  cancelAttackSummaryTimer()
  emitAttackSummary(pending)
  if flushPendingKill then
    flushPendingKill()
  end
end

local function setPendingAttack(who, ability, target)
  boop.state = boop.state or {}
  if boop.state.gagPendingAttack then
    flushPendingAttack()
  end

  boop.state.gagPendingAttack = {
    who = boop.util.trim(who or "You"),
    ability = boop.util.trim(ability or "Attack"),
    target = boop.util.trim(target or "(none)"),
    damageText = "",
    balanceText = "",
  }

  cancelAttackSummaryTimer()
  boop.state.gagPendingAttackTimer = tempTimer(1.2, function()
    boop.state.gagPendingAttackTimer = nil
    flushPendingAttack()
  end)
end

local function cancelKillSummaryTimer()
  boop.state = boop.state or {}
  if boop.state.gagPendingKillTimer then
    killTimer(boop.state.gagPendingKillTimer)
    boop.state.gagPendingKillTimer = nil
  end
end

local function scheduleKillSummaryRetry()
  boop.state = boop.state or {}
  cancelKillSummaryTimer()
  boop.state.gagPendingKillTimer = tempTimer(0.25, function()
    boop.state.gagPendingKillTimer = nil
    if flushPendingKill then
      flushPendingKill()
    end
  end)
end

flushPendingKill = function()
  boop.state = boop.state or {}
  local pending = boop.state.gagPendingKill
  if not pending then return end
  if boop.state.gagPendingAttack then
    scheduleKillSummaryRetry()
    return
  end
  boop.state.gagPendingKill = nil
  cancelKillSummaryTimer()
  emitKillSummary(pending.target or "", pending.xp or "")
end

local function setPendingKill(target)
  boop.state = boop.state or {}
  boop.state.gagPendingKill = {
    target = boop.util.trim(target or ""),
    xp = "",
  }
  cancelKillSummaryTimer()
  boop.state.gagPendingKillTimer = tempTimer(1.2, function()
    boop.state.gagPendingKillTimer = nil
    flushPendingKill()
  end)
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

  deleteCurrent()

  if selfActor then
    setPendingAttack("You", ability, victim)
  else
    emitReplacement(actor, ability, victim, false)
  end

  if boop.trace and boop.trace.log then
    boop.trace.log(string.format("gag: %s | actor=%s | ability=%s | target=%s", selfActor and "self" or "other", actor ~= "" and actor or "?", ability ~= "" and ability or "?", victim ~= "" and victim or "?"))
  end
end

function boop.gag.onBattlefurySpeed(_rawLine)
  if not boop.config or not boop.config.gagOwnAttacks then
    return
  end
  deleteCurrent()
  emitSimple("You", "Battlefury (Speed)")
end

function boop.gag.onDamageLine(amount, dtype, _rawLine)
  if not boop.config or not boop.config.gagOwnAttacks then
    return
  end
  deleteCurrent()

  boop.state = boop.state or {}
  local pending = boop.state.gagPendingAttack
  if not pending then
    return
  end

  local num = boop.util.trim(tostring(amount or "")):gsub(",", "")
  local kind = boop.util.trim(dtype or "")
  if num ~= "" and kind ~= "" then
    pending.damageText = num .. " " .. kind
  elseif num ~= "" then
    pending.damageText = num
  elseif kind ~= "" then
    pending.damageText = kind
  end
end

function boop.gag.onBalanceUsed(seconds, _rawLine)
  if not boop.config or not boop.config.gagOwnAttacks then
    return
  end
  deleteCurrent()

  boop.state = boop.state or {}
  local pending = boop.state.gagPendingAttack
  if not pending then
    return
  end

  local sec = boop.util.trim(tostring(seconds or ""))
  if sec ~= "" then
    pending.balanceText = sec .. "s"
  end
  flushPendingAttack()
end

function boop.gag.onSlainLine(target, _rawLine)
  if not boop.config or not boop.config.gagOwnAttacks then
    return
  end
  deleteCurrent()
  setPendingKill(target or "")
end

function boop.gag.onExperienceLine(xp, _rawLine)
  if not boop.config or not boop.config.gagOwnAttacks then
    return
  end

  boop.state = boop.state or {}
  local pending = boop.state.gagPendingKill
  if not pending then
    return
  end

  deleteCurrent()
  pending.xp = boop.util.trim(tostring(xp or "")):gsub(",", "")
  flushPendingKill()
end
