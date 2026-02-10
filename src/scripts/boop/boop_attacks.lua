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

  if gmcp and gmcp.IRE and gmcp.IRE.Display and gmcp.IRE.Display.ButtonActions then
    local key = boop.util.safeLower(ability.name or ability.skill or "")
    if key == "" then return false end
    for _, button in pairs(gmcp.IRE.Display.ButtonActions) do
      local text = boop.util.safeLower(button.text or "")
      if text == key then
        return button.highlight == 1 or button.highlight == true or tostring(button.highlight) == "1"
      end
    end
    return false
  end

  local key = boop.util.safeLower(ability.name or ability.skill or "")
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

function boop.attacks.canUseConditional(ability)
  if not ability or not ability.needs then return true end
  if boop.afflictions and boop.afflictions.meetsNeeds then
    return boop.afflictions.meetsNeeds(ability.needs)
  end
  return false
end

function boop.attacks.selectRage(profile, rage)
  if not profile then return nil end

  if boop.state.targetShield then
    local ability = findByDesc(profile, "Shieldbreak", rage)
    if ability then return ability end
    if profile.nrshieldbreak and profile.nrshieldbreak.cmd ~= "" then
      return profile.nrshieldbreak
    end
  end

  local mode = boop.config.attackMode or "dam"

  if mode == "big" then
    return findByDescList(profile, {"Big Damage", "Mid Damage", "Small Damage"}, rage)
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

function boop.attacks.selectStandard(profile)
  if not profile then return "" end
  if boop.state.targetShield and profile.shield then
    local cmd = standardCommand(profile.shield)
    if cmd ~= "" then return cmd end
  end
  if profile.dam then
    local cmd = standardCommand(profile.dam)
    if cmd ~= "" then return cmd end
  end
  return ""
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
  if profile.standard then
    standard = boop.attacks.selectStandard(profile.standard)
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

  return { standard = standard, rage = rageAction, rageAbility = rageAbility }
end
