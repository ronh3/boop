boop.attacks = boop.attacks or {}
boop.attacks.registry = boop.attacks.registry or {}

function boop.attacks.register(class, profile)
  if not class or class == "" then return end
  local key = boop.util.safeLower(class)
  boop.attacks.registry[key] = profile or {}
end

local function abilityKnown(ability)
  if not ability then return false end
  local name = ability.skill or ability.name
  if not name or name == "" then return true end
  -- Rage abilities are in Attainment unless explicitly overridden.
  local group = ability.group or "Attainment"
  if boop.skills and boop.skills.ensureSkill then
    return boop.skills.ensureSkill(name, group)
  end
  if boop.skills and boop.skills.knownSkill then
    return boop.skills.knownSkill(name)
  end
  return true
end

function boop.attacks.rageReady(ability, rage)
  if not ability then return false end
  if rage ~= nil and ability.rage and rage < ability.rage then
    return false
  end

  local key = boop.util.safeLower(ability.name or ability.skill or "")
  if gmcp and gmcp.IRE and gmcp.IRE.Display and gmcp.IRE.Display.ButtonActions and key ~= "" then
    for _, button in pairs(gmcp.IRE.Display.ButtonActions) do
      local text = boop.util.safeLower(button.text or "")
      if text == key then
        return button.highlight == 1 or button.highlight == true or tostring(button.highlight) == "1"
      end
    end
  end
  if key == "" then return true end
  if boop.state and boop.state.rageReady and boop.state.rageReady[key] ~= nil then
    return boop.state.rageReady[key]
  end
  return true
end

local function findByDesc(profile, desc, rage)
  if not profile or not profile.abilities then return nil end
  for _, ability in pairs(profile.abilities) do
    if ability.desc == desc then
      if abilityKnown(ability) and boop.attacks.rageReady(ability, rage) then
        return ability
      end
    end
  end
  return nil
end

local function findByDescList(profile, descs, rage)
  for _, desc in ipairs(descs) do
    local ability = findByDesc(profile, desc, rage)
    if ability then return ability end
  end
  return nil
end

function boop.attacks.getRage()
  if gmcp and gmcp.Char and gmcp.Char.Vitals and gmcp.Char.Vitals.charstats then
    for _, stat in ipairs(gmcp.Char.Vitals.charstats) do
      local name, val = stat:match("^(%w+):%s*(%d+)")
      if name == "Rage" then
        return tonumber(val) or 0
      end
    end
  end
  return 0
end

function boop.attacks.getTargetHpPerc()
  if gmcp and gmcp.IRE and gmcp.IRE.Target and gmcp.IRE.Target.Info and gmcp.IRE.Target.Info.hpperc then
    local num = gmcp.IRE.Target.Info.hpperc:gsub("%%", "")
    return tonumber(num) or 100
  end
  return 100
end

function boop.attacks.getTargetHpPercKnown()
  if gmcp and gmcp.IRE and gmcp.IRE.Target and gmcp.IRE.Target.Info and gmcp.IRE.Target.Info.hpperc then
    local num = tostring(gmcp.IRE.Target.Info.hpperc or ""):gsub("%%", "")
    local val = tonumber(num)
    if val then
      return val
    end
  end
  return nil
end

function boop.attacks.isTargetAtFullHpKnown()
  local hp = boop.attacks.getTargetHpPercKnown()
  if hp == nil then
    return false
  end
  return hp >= 100
end

function boop.attacks.canUseConditional(ability)
  if not ability or not ability.needs then return true end
  if boop.afflictions and boop.afflictions.meetsNeeds then
    return boop.afflictions.meetsNeeds(ability.needs, ability.needsMode)
  end
  return false
end

function boop.attacks.selectRage(profile, rage)
  if not profile then return nil end

  if boop.state.targetShield and (type(boop.state.targetShield) ~= "table" or not boop.state.targetShield.attempted) then
    local ability = findByDesc(profile, "Shieldbreak", rage)
    if ability then return ability end
  end

  local mode = boop.config.attackMode or "dam"

  if mode == "none" or mode == "pool" then
    return nil
  end

  if mode == "simple" or mode == "dam" then
    local hp = boop.attacks.getTargetHpPerc()
    local cfg = profile.configRage or { bigDamage = 101, smallDamage = 0 }

    if hp >= (cfg.bigDamage or 101) then
      return findByDescList(profile, {"Big Damage", "Mid Damage", "Small Damage"}, rage)
    end

    if hp >= (cfg.smallDamage or 0) then
      return findByDescList(profile, {"Small Damage", "Mid Damage", "Big Damage"}, rage)
    end

    return findByDescList(profile, {"Small Damage", "Mid Damage", "Big Damage"}, rage)
  elseif mode == "big" then
    -- Pool rage until a big hit is affordable; only fall back to small while big is on cooldown.
    local big = findByDesc(profile, "Big Damage", rage)
    if big then
      return big
    end

    local bigReadyNoCost = findByDesc(profile, "Big Damage", nil)
    if bigReadyNoCost then
      return nil
    end

    return findByDesc(profile, "Small Damage", rage)
  elseif mode == "small" then
    return findByDescList(profile, {"Small Damage", "Mid Damage", "Big Damage"}, rage)
  elseif mode == "aff" then
    return findByDesc(profile, "Gives Affliction", rage)
  elseif mode == "cond" then
    local ability = findByDesc(profile, "Conditional", rage)
    if boop.attacks.canUseConditional(ability) then
      return ability
    end
    return nil
  elseif mode == "buff" then
    return findByDesc(profile, "Buff", rage)
  end

  local hp = boop.attacks.getTargetHpPerc()
  local cfg = profile.configRage or { bigDamage = 101, smallDamage = 0 }

  if hp >= (cfg.bigDamage or 101) then
    return findByDescList(profile, {"Big Damage", "Mid Damage", "Small Damage"}, rage)
  end

  if hp >= (cfg.smallDamage or 0) then
    return findByDescList(profile, {"Small Damage", "Mid Damage", "Big Damage"}, rage)
  end

  return findByDescList(profile, {"Small Damage", "Mid Damage", "Big Damage"}, rage)
end

local function standardCommand(entry)
  if type(entry) == "table" then
    if entry.bySpec then
      local spec = boop.state and boop.state.spec or ""
      local specEntry = entry.bySpec[spec]
      if not specEntry then
        specEntry = entry.default or entry.bySpec.default
      end
      if specEntry then
        return standardCommand(specEntry)
      end
    end
    if entry.cmd or entry.skill or entry.name then
      local cmd = entry.cmd or ""
      if cmd == "" then return "" end
    local skill = entry.skill or entry.name
    if skill and skill ~= "" then
      local ok = true
      if boop.skills and boop.skills.ensureSkill then
        ok = boop.skills.ensureSkill(skill, entry.group)
      elseif boop.skills and boop.skills.knownSkill then
        ok = boop.skills.knownSkill(skill)
      end
      if not ok then
        return ""
      end
    end
      return cmd
    else
      for _, option in ipairs(entry) do
        local cmd = standardCommand(option)
        if cmd ~= "" then return cmd end
      end
      return ""
    end
  end
  if type(entry) == "string" then
    return entry
  end
  return ""
end

function boop.attacks.openerUsedForTarget(classKey, targetId)
  local cls = boop.util.safeLower(boop.util.trim(classKey or ""))
  local tid = boop.util.trim(tostring(targetId or ""))
  if cls == "" or tid == "" then
    return false
  end
  boop.state = boop.state or {}
  boop.state.openerUsedByClass = boop.state.openerUsedByClass or {}
  return tostring(boop.state.openerUsedByClass[cls] or "") == tid
end

function boop.attacks.markOpenerUsed(classKey, targetId)
  local cls = boop.util.safeLower(boop.util.trim(classKey or ""))
  local tid = boop.util.trim(tostring(targetId or ""))
  if cls == "" or tid == "" then
    return
  end
  boop.state = boop.state or {}
  boop.state.openerUsedByClass = boop.state.openerUsedByClass or {}
  boop.state.openerUsedByClass[cls] = tid
end

local function traceOpenerDecision(classKey, targetId, reason)
  if not boop.config or not boop.config.traceEnabled then
    return
  end
  if not boop.trace or not boop.trace.log then
    return
  end

  local cls = boop.util.safeLower(boop.util.trim(classKey or ""))
  local tid = boop.util.trim(tostring(targetId or ""))
  local why = boop.util.trim(reason or "")
  if cls == "" then cls = "unknown" end
  if tid == "" then tid = "none" end
  if why == "" then why = "unknown" end

  boop.state = boop.state or {}
  local key = string.format("%s|%s|%s", cls, tid, why)
  if boop.state.lastOpenerTraceKey == key then
    return
  end
  boop.state.lastOpenerTraceKey = key
  boop.trace.log(string.format("opener %s (%s:%s)", why, cls, tid))
end

local function isTwoHandedSpec()
  local spec = boop.util.safeLower(boop.state and boop.state.spec or "")
  spec = boop.util.trim(spec)
  return spec == "two handed" or spec == "two-handed" or spec == "2h"
end

local function focusKnown()
  if boop.skills and boop.skills.ensureSkill then
    return boop.skills.ensureSkill("Focus", "Weaponmastery")
  end
  if boop.skills and boop.skills.knownSkill then
    return boop.skills.knownSkill("Focus")
  end
  return true
end

local function prependFocusSpeed(cmd)
  local trimmed = boop.util.trim(cmd)
  if trimmed == "" then return "" end
  local normalized = boop.util.safeLower(trimmed)
  if boop.util.starts(normalized, "battlefury focus speed/") then
    return trimmed
  end
  return "battlefury focus speed/" .. trimmed
end

local function unnamableMaulKnown()
  if boop.skills and boop.skills.ensureSkill then
    return boop.skills.ensureSkill("Maul", "Dominion")
  end
  if boop.skills and boop.skills.knownSkill then
    return boop.skills.knownSkill("Maul")
  end
  return true
end

local function infernalMaulKnown()
  if boop.skills and boop.skills.ensureSkill then
    return boop.skills.ensureSkill("Maul", "Oppression")
  end
  if boop.skills and boop.skills.knownSkill then
    return boop.skills.knownSkill("Maul")
  end
  return true
end

local function unnamableMaulReady()
  if boop.attacks and boop.attacks.rageReady then
    return boop.attacks.rageReady({ name = "maul" }, nil)
  end
  return true
end

local function infernalMaulReady()
  if boop.attacks and boop.attacks.rageReady then
    return boop.attacks.rageReady({ name = "maul" }, nil)
  end
  return true
end

local function prependUnnamableMaul(cmd)
  local trimmed = boop.util.trim(cmd)
  if trimmed == "" then return "" end
  local normalized = boop.util.safeLower(trimmed)
  if boop.util.starts(normalized, "hound maul ")
    or boop.util.starts(normalized, "hound maul/")
    or boop.util.starts(normalized, "maul ")
    or boop.util.starts(normalized, "maul/")
    or boop.util.starts(normalized, "dominion maul ")
    or boop.util.starts(normalized, "dominion maul/")
  then
    return trimmed
  end
  return "hound maul &tar/" .. trimmed
end

local function prependInfernalHyenaMaul(cmd)
  local trimmed = boop.util.trim(cmd)
  if trimmed == "" then return "" end
  local normalized = boop.util.safeLower(trimmed)
  if boop.util.starts(normalized, "hyena maul ")
    or boop.util.starts(normalized, "hyena maul/")
  then
    return trimmed
  end
  return "hyena maul &tar/" .. trimmed
end

function boop.attacks.selectStandard(profile, classKey)
  if not profile then return "", false, false end

  local opener = profile.openerAt100 or profile.opener
  local targetId = boop.util.trim(tostring(boop.state and boop.state.currentTargetId or ""))
  if opener then
    if targetId == "" then
      traceOpenerDecision(classKey, targetId, "skip:no-target")
    else
      local hp = boop.attacks.getTargetHpPercKnown()
      if hp == nil then
        traceOpenerDecision(classKey, targetId, "skip:hp-unknown")
      elseif hp < 100 then
        traceOpenerDecision(classKey, targetId, "skip:hp-not-full")
      elseif boop.attacks.openerUsedForTarget(classKey, targetId) then
        traceOpenerDecision(classKey, targetId, "skip:already-used")
      else
        local cmd = standardCommand(opener)
        if cmd ~= "" then
          traceOpenerDecision(classKey, targetId, "selected")
          return cmd, false, true
        end
        traceOpenerDecision(classKey, targetId, "skip:unavailable")
      end
    end
  end

  if boop.state.targetShield
    and (type(boop.state.targetShield) ~= "table" or not boop.state.targetShield.attempted)
    and profile.shield
  then
    local cmd = standardCommand(profile.shield)
    if cmd ~= "" then return cmd, true, false end
  end
  if profile.dam then
    local cmd = standardCommand(profile.dam)
    if cmd ~= "" then
      if isTwoHandedSpec() and focusKnown() then
        cmd = prependFocusSpeed(cmd)
      end
      return cmd, false, false
    end
  end
  return "", false, false
end

function boop.attacks.choose()
  if not gmcp or not gmcp.Char or not gmcp.Char.Status then
    return { standard = "", rage = "" }
  end
  local class = boop.util.safeLower(gmcp.Char.Status.class)
  if class == "" then return { standard = "", rage = "" } end

  local profile = boop.attacks.registry[class]
  if not profile then return { standard = "", rage = "" } end

  local standard = ""
  local standardShieldbreak = false
  local standardIsOpener = false
  if profile.standard then
    standard, standardShieldbreak, standardIsOpener = boop.attacks.selectStandard(profile.standard, class)
  end

  if standard ~= "" and class == "unnamable" and unnamableMaulKnown() and unnamableMaulReady() then
    standard = prependUnnamableMaul(standard)
  end
  if standard ~= "" and class == "infernal" and infernalMaulKnown() and infernalMaulReady() then
    standard = prependInfernalHyenaMaul(standard)
  end

  local rageAction = ""
  local rageAbility = nil
  if profile.rage then
    local rage = boop.attacks.getRage()
    local ability = boop.attacks.selectRage(profile.rage, rage)
    if ability and ability.cmd and ability.cmd ~= "" then
      rageAction = ability.cmd
      rageAbility = ability
    end
  end

  local targetId = boop.state.currentTargetId or ""
  if standard ~= "" then
    standard = boop.util.formatTarget(standard, targetId)
  end
  if rageAction ~= "" then
    rageAction = boop.util.formatTarget(rageAction, targetId)
  end

  return {
    standard = standard,
    standardShieldbreak = standardShieldbreak,
    standardIsOpener = standardIsOpener,
    rage = rageAction,
    rageAbility = rageAbility
  }
end
