boop.attacks = boop.attacks or {}
boop.attacks.registry = boop.attacks.registry or {}

function boop.attacks.register(class, profile)
  if not class or class == "" then return end
  local key = boop.util.safeLower(class)
  boop.attacks.registry[key] = profile or {}
end

local function normalizedSpecKey(spec)
  local key = boop.util.safeLower(boop.util.trim(spec or ""))
  key = key:gsub("%s+", "_")
  key = key:gsub("[^%w_%-]", "")
  if key == "" then
    key = "default"
  end
  return key
end

local function standardPreferenceKey(classKey, section, spec)
  local cls = boop.util.safeLower(boop.util.trim(classKey or ""))
  local sec = boop.util.safeLower(boop.util.trim(section or ""))
  if cls == "" or sec == "" then
    return ""
  end
  return string.format("attackPreference.%s.%s.%s", cls, normalizedSpecKey(spec), sec)
end

local function standardPreferenceValue(classKey, section)
  local spec = boop.state and boop.state.spec or ""
  local specKey = standardPreferenceKey(classKey, section, spec)
  if specKey ~= "" and boop.config and boop.config[specKey] and boop.config[specKey] ~= "" then
    return boop.config[specKey], specKey
  end

  local fallbackKey = standardPreferenceKey(classKey, section, "")
  if fallbackKey ~= "" and boop.config and boop.config[fallbackKey] and boop.config[fallbackKey] ~= "" then
    return boop.config[fallbackKey], fallbackKey
  end

  return "", specKey ~= "" and specKey or fallbackKey
end

function boop.attacks.preferenceConfigKey(classKey, section, spec)
  return standardPreferenceKey(classKey, section, spec)
end

function boop.attacks.getStandardPreference(classKey, section)
  local value = standardPreferenceValue(classKey, section)
  return value
end

function boop.attacks.weaponConfigKey(classKey, role)
  local cls = boop.util.safeLower(boop.util.trim(classKey or ""))
  local slot = boop.util.safeLower(boop.util.trim(role or ""))
  if cls == "" or slot == "" then
    return ""
  end
  return string.format("weapon.%s.%s", cls, slot)
end

function boop.attacks.getDesignatedWeapon(classKey, role)
  local key = boop.attacks.weaponConfigKey(classKey, role)
  if key == "" or not boop.config then
    return ""
  end
  return boop.util.trim(boop.config[key] or "")
end

local function addEntryToken(tokens, raw)
  local text = boop.util.safeLower(boop.util.trim(raw or ""))
  if text == "" then return end
  tokens[text] = true
  for token in text:gmatch("[%w_%-]+") do
    if token ~= "" then
      tokens[token] = true
    end
  end
end

local function entryMatchesPreference(entry, preference)
  local pref = boop.util.safeLower(boop.util.trim(preference or ""))
  if pref == "" or type(entry) ~= "table" then
    return false
  end

  local tokens = {}
  addEntryToken(tokens, entry.name)
  addEntryToken(tokens, entry.skill)
  addEntryToken(tokens, entry.cmd)
  return tokens[pref] == true
end

local function describeEntry(entry)
  if type(entry) ~= "table" then
    return tostring(entry or "")
  end
  local label = boop.util.trim(entry.name or entry.skill or entry.cmd or "")
  local cmd = boop.util.trim(entry.cmd or "")
  if label == "" then
    label = cmd
  end
  if cmd ~= "" and label ~= cmd then
    return string.format("%s -> %s", label, cmd)
  end
  return label
end

local function appendStandardOptions(entry, out, seen)
  if type(entry) ~= "table" then
    return
  end

  if entry.bySpec then
    local spec = boop.state and boop.state.spec or ""
    local specEntry = entry.bySpec[spec]
    if not specEntry then
      specEntry = entry.default or entry.bySpec.default
    end
    if specEntry then
      appendStandardOptions(specEntry, out, seen)
    end
    return
  end

  if entry.cmd or entry.skill or entry.name then
    local desc = describeEntry(entry)
    local key = boop.util.safeLower(desc)
    if desc ~= "" and not seen[key] then
      seen[key] = true
      out[#out + 1] = {
        label = desc,
        skill = entry.skill or entry.name or "",
        command = entry.cmd or "",
      }
    end
    return
  end

  for _, option in ipairs(entry) do
    appendStandardOptions(option, out, seen)
  end
end

function boop.attacks.standardOptions(classKey, section)
  local cls = boop.util.safeLower(boop.util.trim(classKey or ""))
  local sec = boop.util.safeLower(boop.util.trim(section or ""))
  if cls == "" or sec == "" then
    return {}
  end

  local profile = boop.attacks.registry[cls]
  local standard = profile and profile.standard
  local entry = standard and standard[sec]
  local out, seen = {}, {}
  appendStandardOptions(entry, out, seen)
  return out
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

local function selectDamageForHp(profile, rageBudget)
  local hp = boop.attacks.getTargetHpPerc()
  local cfg = profile.configRage or { bigDamage = 101, smallDamage = 0 }

  if hp >= (cfg.bigDamage or 101) then
    return findByDescList(profile, {"Big Damage", "Mid Damage", "Small Damage"}, rageBudget)
  end

  if hp >= (cfg.smallDamage or 0) then
    return findByDescList(profile, {"Small Damage", "Mid Damage", "Big Damage"}, rageBudget)
  end

  return findByDescList(profile, {"Small Damage", "Mid Damage", "Big Damage"}, rageBudget)
end

local function pullReserveAbility(profile)
  if not profile then return nil end
  return findByDescList(profile, {"Small Damage", "Mid Damage", "Big Damage"}, nil)
end

local function pullReserveCost(profile)
  if not boop.config or not boop.config.pullRageReserve then
    return 0
  end
  local ability = pullReserveAbility(profile)
  if not ability then
    return 0
  end
  return tonumber(ability.rage) or 0
end

local function normalizeAffName(raw)
  local key = boop.util.safeLower(boop.util.trim(raw or ""))
  if key == "stunned" then
    return "stun"
  end
  return key
end

local function rosterClassKeys(selfClassKey)
  local classes = {}
  local seen = {}

  local function addClass(raw)
    local key = boop.util.safeLower(boop.util.trim(raw or ""))
    if key == "" then return end
    if not boop.attacks.registry[key] then return end
    if seen[key] then return end
    seen[key] = true
    classes[#classes + 1] = key
  end

  addClass(selfClassKey)
  local partyRaw = boop.util.trim((boop.config and boop.config.partyRoster) or "")
  for token in partyRaw:gmatch("([^,]+)") do
    addClass(token)
  end
  return classes
end

local function rosterPartyClassKeys(selfClassKey)
  local selfKey = boop.util.safeLower(boop.util.trim(selfClassKey or ""))
  local party = {}
  for _, classKey in ipairs(rosterClassKeys(selfClassKey)) do
    if classKey ~= selfKey then
      party[#party + 1] = classKey
    end
  end
  return party
end

local function classProfile(classKey)
  local key = boop.util.safeLower(boop.util.trim(classKey or ""))
  if key == "" then return nil end
  return boop.attacks.registry[key]
end

local function classProvidesNeed(classKey, aff)
  local key = normalizeAffName(aff or "")
  if key == "" then return false end

  local profile = classProfile(classKey)
  local abilities = profile and profile.rage and profile.rage.abilities or {}
  for _, ability in pairs(abilities) do
    if normalizeAffName(ability.aff or "") == key then
      return true
    end
  end
  return false
end

local function rosterProvidersByAff(selfClassKey)
  local providers = {}
  local classes = rosterClassKeys(selfClassKey)
  local selfKey = boop.util.safeLower(boop.util.trim(selfClassKey or ""))
  for _, classKey in ipairs(classes) do
    local classProfile = boop.attacks.registry[classKey]
    local rageProfile = classProfile and classProfile.rage
    local abilities = rageProfile and rageProfile.abilities or {}
    for _, ability in pairs(abilities) do
      local aff = normalizeAffName(ability.aff or "")
      local available = true
      if classKey == selfKey then
        available = abilityKnown(ability)
      end
      if aff ~= "" and available then
        providers[aff] = providers[aff] or {}
        providers[aff][classKey] = true
      end
    end
  end
  return providers
end

local function conditionalNeedsProviderSupport(selfClassKey, ability)
  if not ability or type(ability.needs) ~= "table" or #ability.needs == 0 then
    return false
  end

  local providersByAff = rosterProvidersByAff(selfClassKey)
  local mode = boop.util.safeLower(boop.util.trim(ability.needsMode or "any"))
  local supported = 0
  for _, need in ipairs(ability.needs) do
    local key = normalizeAffName(need or "")
    if key ~= "" and providersByAff[key] then
      supported = supported + 1
    end
  end

  if mode == "all" then
    return supported == #ability.needs
  end
  return supported > 0
end

local function traceComboDecision(classKey, reason)
  if not boop.config or not boop.config.traceEnabled then
    return
  end
  if not boop.trace or not boop.trace.log then
    return
  end

  local cls = boop.util.safeLower(boop.util.trim(classKey or ""))
  if cls == "" then cls = "unknown" end
  local targetId = boop.util.trim(tostring(boop.state and boop.state.currentTargetId or ""))
  if targetId == "" then targetId = "none" end
  local why = boop.util.trim(reason or "")
  if why == "" then why = "unknown" end

  boop.state = boop.state or {}
  local key = string.format("%s|%s|%s", cls, targetId, why)
  if boop.state.lastComboTraceKey == key then
    return
  end
  boop.state.lastComboTraceKey = key
  boop.trace.log("combo mode: " .. why)
end

local function finalizeRageDecision(mode, outcome, ability)
  local canonicalMode = boop.util.safeLower(boop.util.trim(mode or "simple"))
  local decision = {
    mode = canonicalMode ~= "" and canonicalMode or "simple",
    outcome = boop.util.safeLower(boop.util.trim(outcome or "")),
    ability = ability,
    targetId = boop.util.trim(tostring(boop.state and boop.state.currentTargetId or "")),
  }
  if boop.stats and boop.stats.onRageDecision then
    boop.stats.onRageDecision(decision)
  end
  return ability, decision
end

local function finalizeRageDecisionWithPullReserve(profile, mode, outcome, ability, rage)
  local chosen = ability
  local result = outcome
  local reserve = pullReserveCost(profile)
  local currentRage = tonumber(rage) or 0

  if chosen and reserve > 0 and chosen.desc ~= "Shieldbreak" then
    local cost = tonumber(chosen.rage) or 0
    if (currentRage - cost) < reserve then
      chosen = nil
      result = "pull_reserve"
    end
  end

  return finalizeRageDecision(mode, result, chosen)
end

local function conditionalMissingNeeds(ability)
  local missing = {}
  if not ability or type(ability.needs) ~= "table" then
    return missing
  end

  for _, need in ipairs(ability.needs) do
    local key = normalizeAffName(need or "")
    if key ~= "" then
      local hasAff = false
      if boop.afflictions and boop.afflictions.hasTarget then
        hasAff = boop.afflictions.hasTarget(key)
      end
      if not hasAff then
        missing[#missing + 1] = key
      end
    end
  end
  return missing
end

local function findConditionalPrimer(profile, conditionalAbility, rage)
  if not profile or not profile.abilities then
    return nil
  end

  local missing = conditionalMissingNeeds(conditionalAbility)
  if #missing == 0 then
    return nil
  end

  local missingSet = {}
  for _, aff in ipairs(missing) do
    missingSet[aff] = true
  end

  local best = nil
  local bestRage = nil
  local bestAff = nil
  for _, ability in pairs(profile.abilities) do
    if ability.desc == "Gives Affliction" then
      local aff = normalizeAffName(ability.aff or "")
      if aff ~= "" and missingSet[aff] and abilityKnown(ability) and boop.attacks.rageReady(ability, rage) then
        local cost = tonumber(ability.rage) or 999
        if not best or cost < bestRage or (cost == bestRage and aff < bestAff) then
          best = ability
          bestRage = cost
          bestAff = aff
        end
      end
    end
  end
  return best
end

local function conditionalNeedMatchedByClass(ability, classKey)
  if not ability or type(ability.needs) ~= "table" or #ability.needs == 0 then
    return false
  end

  local mode = boop.util.safeLower(boop.util.trim(ability.needsMode or "any"))
  local matched = 0
  for _, need in ipairs(ability.needs) do
    if classProvidesNeed(classKey, need) then
      matched = matched + 1
    end
  end

  if mode == "all" then
    return matched == #ability.needs
  end
  return matched > 0
end

local function findPartyPrimer(profile, selfClassKey, rage)
  if not profile or not profile.abilities then
    return nil
  end

  local partyClasses = rosterPartyClassKeys(selfClassKey)
  if #partyClasses == 0 then
    return nil
  end

  local ownConditional = findByDesc(profile, "Conditional", nil)
  local best = nil
  local bestCost = nil
  local bestMutual = false
  local bestCoverage = 0
  local bestAff = nil

  for _, ability in pairs(profile.abilities) do
    if ability.desc == "Gives Affliction" and abilityKnown(ability) and boop.attacks.rageReady(ability, rage) then
      local aff = normalizeAffName(ability.aff or "")
      if aff ~= "" and not (boop.afflictions and boop.afflictions.hasTarget and boop.afflictions.hasTarget(aff)) then
        local coverage = 0
        local mutual = false
        for _, partyClass in ipairs(partyClasses) do
          local partyProfile = classProfile(partyClass)
          local abilities = partyProfile and partyProfile.rage and partyProfile.rage.abilities or {}
          for _, partyAbility in pairs(abilities) do
            if partyAbility.desc == "Conditional" and type(partyAbility.needs) == "table" then
              for _, need in ipairs(partyAbility.needs) do
                if normalizeAffName(need or "") == aff then
                  coverage = coverage + 1
                  if ownConditional and conditionalNeedMatchedByClass(ownConditional, partyClass) then
                    mutual = true
                  end
                  break
                end
              end
            end
          end
        end

        if coverage > 0 then
          local cost = tonumber(ability.rage) or 999
          if not best
            or (mutual and not bestMutual)
            or (mutual == bestMutual and cost < bestCost)
            or (mutual == bestMutual and cost == bestCost and coverage > bestCoverage)
            or (mutual == bestMutual and cost == bestCost and coverage == bestCoverage and aff < bestAff)
          then
            best = ability
            bestCost = cost
            bestMutual = mutual
            bestCoverage = coverage
            bestAff = aff
          end
        end
      end
    end
  end

  return best
end

local function selectRageCombo(profile, rage, classKey, allowPriming, allowHold)
  local conditionalNow = findByDesc(profile, "Conditional", rage)
  if conditionalNow and boop.attacks.canUseConditional(conditionalNow) then
    traceComboDecision(classKey, "fire conditional")
    return conditionalNow, "combo_conditional"
  end

  local conditionalReady = findByDesc(profile, "Conditional", nil)
  local partyPrimerReady = nil
  local partyPrimerAny = nil
  if allowPriming then
    partyPrimerReady = findPartyPrimer(profile, classKey, rage)
    if partyPrimerReady then
      traceComboDecision(classKey, "prime party combo with " .. tostring(partyPrimerReady.name or partyPrimerReady.skill or partyPrimerReady.aff or "aff"))
      return partyPrimerReady, "combo_party_primer"
    end
    partyPrimerAny = findPartyPrimer(profile, classKey, nil)
  end

  if not conditionalReady then
    if partyPrimerAny then
      if allowHold then
        traceComboDecision(classKey, "hold rage for party primer")
        return nil, "combo_hold"
      end
      traceComboDecision(classKey, "fallback simple (party primer unmet)")
      return selectDamageForHp(profile, rage), "combo_fallback"
    end
    traceComboDecision(classKey, "fallback simple (conditional unavailable)")
    return selectDamageForHp(profile, rage), "combo_fallback"
  end

  if allowPriming then
    local primer = findConditionalPrimer(profile, conditionalReady, rage)
    if primer then
      traceComboDecision(classKey, "prime conditional with " .. tostring(primer.name or primer.skill or primer.aff or "aff"))
      return primer, "combo_primer"
    end
  end

  local selfPrimerAny = nil
  if allowPriming then
    selfPrimerAny = findConditionalPrimer(profile, conditionalReady, nil)
    if selfPrimerAny then
      if allowHold then
        traceComboDecision(classKey, "hold rage for self primer")
        return nil, "combo_hold"
      end
      traceComboDecision(classKey, "fallback simple (self primer unmet)")
      return selectDamageForHp(profile, rage), "combo_fallback"
    end
    if partyPrimerAny then
      if allowHold then
        traceComboDecision(classKey, "hold rage for party primer")
        return nil, "combo_hold"
      end
      traceComboDecision(classKey, "fallback simple (party primer unmet)")
      return selectDamageForHp(profile, rage), "combo_fallback"
    end
  end

  if not conditionalNeedsProviderSupport(classKey, conditionalReady) then
    traceComboDecision(classKey, "fallback simple (no provider support)")
    return selectDamageForHp(profile, rage), "combo_fallback"
  end

  local reserve = tonumber(conditionalReady.rage) or 0
  local budget = (tonumber(rage) or 0) - reserve
  if budget <= 0 then
    if allowHold then
      traceComboDecision(classKey, "hold rage for conditional")
      return nil, "combo_hold"
    end
    traceComboDecision(classKey, "fallback simple (reserve unmet)")
    return selectDamageForHp(profile, rage), "combo_fallback"
  end

  local spender = selectDamageForHp(profile, budget)
  if spender then
    traceComboDecision(classKey, "spend overflow rage")
    return spender, "combo_spend_overflow"
  end

  if allowHold then
    traceComboDecision(classKey, "hold rage (no overflow spender)")
    return nil, "combo_hold"
  end
  traceComboDecision(classKey, "fallback simple (no overflow spender)")
  return selectDamageForHp(profile, rage), "hybrid_fallback"
end

local function abilityRageCost(ability)
  return tonumber(ability and ability.rage) or 999
end

local function collectRageAbilitiesByDesc(profile, descSet, rageBudget)
  local out = {}
  if not profile or not profile.abilities then
    return out
  end

  for _, ability in pairs(profile.abilities) do
    if descSet[ability.desc] and abilityKnown(ability) and boop.attacks.rageReady(ability, rageBudget) then
      out[#out + 1] = ability
    end
  end
  return out
end

local function sortAbilitiesByCost(list, descending)
  table.sort(list, function(a, b)
    local ca = abilityRageCost(a)
    local cb = abilityRageCost(b)
    if ca == cb then
      local na = tostring(a.name or a.skill or "")
      local nb = tostring(b.name or b.skill or "")
      return na < nb
    end
    if descending then
      return ca > cb
    end
    return ca < cb
  end)
end

local function selectRageTempo(profile, rage, classKey)
  local tempoWindow = tonumber((boop.config and boop.config.tempoRageWindowSeconds) or 10) or 10
  local tempoEta = tonumber((boop.config and boop.config.tempoSqueezeEtaSeconds) or 2.5) or 2.5
  if tempoWindow <= 0 then tempoWindow = 10 end
  if tempoEta < 0 then tempoEta = 0 end

  local affChoices = collectRageAbilitiesByDesc(profile, { ["Gives Affliction"] = true }, rage)
  if #affChoices == 0 then
    traceComboDecision(classKey, "tempo fallback damage (no aff available)")
    return selectDamageForHp(profile, rage), "tempo_fallback"
  end
  sortAbilitiesByCost(affChoices, false)
  local aff = affChoices[1]
  local reserve = abilityRageCost(aff)

  local damageChoices = collectRageAbilitiesByDesc(profile, {
    ["Big Damage"] = true,
    ["Mid Damage"] = true,
    ["Small Damage"] = true,
  }, rage)
  sortAbilitiesByCost(damageChoices, true)

  for _, dmg in ipairs(damageChoices) do
    local cost = abilityRageCost(dmg)
    local post = (tonumber(rage) or 0) - cost
    if post >= reserve then
      traceComboDecision(classKey, "tempo squeeze damage (free reserve)")
      return dmg, "tempo_squeeze"
    end

    local eta = nil
    if boop.rage and boop.rage.etaToRage then
      eta = boop.rage.etaToRage(reserve, post, tempoWindow)
    end
    if eta and eta <= tempoEta then
      traceComboDecision(classKey, string.format("tempo squeeze damage (eta %.2fs)", eta))
      return dmg, "tempo_squeeze"
    end
  end

  traceComboDecision(classKey, "tempo prioritize aff")
  return aff, "tempo_aff"
end

function boop.attacks.selectRage(profile, rage, classKey, standardShieldbreak)
  if not profile then return nil, nil end

  if boop.state.targetShield and (type(boop.state.targetShield) ~= "table" or not boop.state.targetShield.attempted) then
    if boop.config and boop.config.pullRageReserve and standardShieldbreak then
      return finalizeRageDecision("shieldbreak", "pull_reserve", nil)
    end
    local ability = findByDesc(profile, "Shieldbreak", rage)
    if ability then return finalizeRageDecision("shieldbreak", "shieldbreak", ability) end
  end

  local mode = boop.util.safeLower(boop.util.trim(boop.config.attackMode or "simple"))
  local modeAliases = {
    damage = "simple",
    dam = "simple",
    condition = "combo",
    conditional = "combo",
    cond = "combo",
    affplus = "tempo",
    smartaff = "tempo",
    weave = "tempo",
    pool = "none",
    buff = "aff",
  }
  mode = modeAliases[mode] or mode

  if mode == "none" then
    return finalizeRageDecision(mode, "suppressed", nil)
  end

  if mode == "simple" then
    local hp = boop.attacks.getTargetHpPerc()
    local cfg = profile.configRage or { bigDamage = 101, smallDamage = 0 }

    if hp >= (cfg.bigDamage or 101) then
      return finalizeRageDecisionWithPullReserve(profile, mode, "damage", findByDescList(profile, {"Big Damage", "Mid Damage", "Small Damage"}, rage), rage)
    end

    if hp >= (cfg.smallDamage or 0) then
      return finalizeRageDecisionWithPullReserve(profile, mode, "damage", findByDescList(profile, {"Small Damage", "Mid Damage", "Big Damage"}, rage), rage)
    end

    return finalizeRageDecisionWithPullReserve(profile, mode, "damage", findByDescList(profile, {"Small Damage", "Mid Damage", "Big Damage"}, rage), rage)
  elseif mode == "big" then
    -- Pool rage until a big hit is affordable; only fall back to small while big is on cooldown.
    local big = findByDesc(profile, "Big Damage", rage)
    if big then
      return finalizeRageDecisionWithPullReserve(profile, mode, "big_damage", big, rage)
    end

    local bigReadyNoCost = findByDesc(profile, "Big Damage", nil)
    if bigReadyNoCost then
      return finalizeRageDecision(mode, "big_hold", nil)
    end

    return finalizeRageDecisionWithPullReserve(profile, mode, "small_damage", findByDesc(profile, "Small Damage", rage), rage)
  elseif mode == "small" then
    return finalizeRageDecisionWithPullReserve(profile, mode, "small_damage", findByDescList(profile, {"Small Damage", "Mid Damage", "Big Damage"}, rage), rage)
  elseif mode == "aff" then
    return finalizeRageDecisionWithPullReserve(profile, mode, "aff", findByDesc(profile, "Gives Affliction", rage), rage)
  elseif mode == "tempo" then
    local ability, outcome = selectRageTempo(profile, rage, classKey)
    return finalizeRageDecisionWithPullReserve(profile, mode, outcome, ability, rage)
  elseif mode == "combo" then
    local ability, outcome = selectRageCombo(profile, rage, classKey, true, true)
    return finalizeRageDecisionWithPullReserve(profile, mode, outcome, ability, rage)
  elseif mode == "hybrid" then
    local ability, outcome = selectRageCombo(profile, rage, classKey, true, false)
    return finalizeRageDecisionWithPullReserve(profile, mode, outcome, ability, rage)
  end

  return finalizeRageDecisionWithPullReserve(profile, mode, "damage", selectDamageForHp(profile, rage), rage)
end

local function standardCommand(entry, preference)
  if type(entry) == "table" then
    if entry.bySpec then
      local spec = boop.state and boop.state.spec or ""
      local specEntry = entry.bySpec[spec]
      if not specEntry then
        specEntry = entry.default or entry.bySpec.default
      end
      if specEntry then
        return standardCommand(specEntry, preference)
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

      if entry.needs then
        local meets = boop.afflictions
          and boop.afflictions.meetsNeeds
          and boop.afflictions.meetsNeeds(entry.needs, entry.needsMode)
        if not meets then
          return ""
        end
      end

      return cmd
    end

    local pref = boop.util.safeLower(boop.util.trim(preference or ""))
    if pref ~= "" then
      for _, option in ipairs(entry) do
        if entryMatchesPreference(option, pref) then
          local cmd = standardCommand(option)
          if cmd ~= "" then
            return cmd
          end
        end
      end
    end
    for _, option in ipairs(entry) do
      local cmd = standardCommand(option)
      if cmd ~= "" then return cmd end
    end
    return ""
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

local function normalizedFocusVerb()
  local raw = boop.config and boop.config.focusVerb or "speed"
  local value = boop.util.safeLower(boop.util.trim(raw or ""))
  if value ~= "precision" then
    return "speed"
  end
  return value
end

local function prependFocusVerb(cmd)
  local trimmed = boop.util.trim(cmd)
  if trimmed == "" then return "" end
  local normalized = boop.util.safeLower(trimmed)
  if boop.util.starts(normalized, "battlefury focus speed/")
    or boop.util.starts(normalized, "battlefury focus precision/")
  then
    return trimmed
  end
  return "battlefury focus " .. normalizedFocusVerb() .. "/" .. trimmed
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

local function wieldedNameContains(fragment)
  local needle = boop.util.safeLower(boop.util.trim(fragment or ""))
  if needle == "" then
    return false
  end

  local left = boop.getWieldedItem and boop.getWieldedItem("left") or (boop.state and boop.state.wieldedLeft) or nil
  local right = boop.getWieldedItem and boop.getWieldedItem("right") or (boop.state and boop.state.wieldedRight) or nil
  local items = {}
  if left then items[#items + 1] = left end
  if right then items[#items + 1] = right end
  for _, item in ipairs(items) do
    local name = boop.util.safeLower(item and item.name or "")
    if name ~= "" and name:find(needle, 1, true) then
      return true
    end
  end
  return false
end

local function wieldedMatchesDesignation(designation)
  local wanted = boop.util.trim(designation or "")
  if wanted == "" then
    return false
  end

  local wantedLower = boop.util.safeLower(wanted)
  local compactWanted = wantedLower:gsub("[^%w]+", "")
  local left = boop.getWieldedItem and boop.getWieldedItem("left") or (boop.state and boop.state.wieldedLeft) or nil
  local right = boop.getWieldedItem and boop.getWieldedItem("right") or (boop.state and boop.state.wieldedRight) or nil
  local items = {}
  if left then items[#items + 1] = left end
  if right then items[#items + 1] = right end
  for _, item in ipairs(items) do
    local itemId = tostring(item and item.id or "")
    local itemName = boop.util.safeLower(item and item.name or "")
    local compactName = itemName:gsub("[^%w]+", "")
    if itemId ~= "" and itemId == wanted then
      return true
    end
    if itemName ~= "" and itemName:find(wantedLower, 1, true) then
      return true
    end
    if compactWanted ~= "" and compactName ~= "" and compactName:find(compactWanted, 1, true) then
      return true
    end
    if itemId ~= "" and compactWanted:sub(-#itemId) == itemId then
      local prefix = compactWanted:sub(1, #compactWanted - #itemId)
      if prefix == "" then
        return true
      end
      if compactName ~= "" and compactName:find(prefix, 1, true) then
        return true
      end
    end
  end
  return false
end

local function depthswalkerNeededWeapon(cmd, standardShieldbreak)
  local normalized = boop.util.safeLower(boop.util.trim(cmd or ""))
  if normalized == "" then
    return ""
  end
  if boop.util.starts(normalized, "shadow strike ") or boop.util.starts(normalized, "shadow strike/") then
    return "dagger"
  end
  if boop.util.starts(normalized, "shadow reap ") or boop.util.starts(normalized, "shadow reap/")
    or boop.util.starts(normalized, "shadow cull ") or boop.util.starts(normalized, "shadow cull/")
  then
    return "scythe"
  end
  if standardShieldbreak then
    return "dagger"
  end
  return ""
end

local function prependDepthswalkerWeapon(cmd, standardShieldbreak)
  local trimmed = boop.util.trim(cmd)
  if trimmed == "" then return "" end

  local needed = depthswalkerNeededWeapon(trimmed, standardShieldbreak)
  if needed == "" then
    return trimmed
  end

  local designated = boop.attacks.getDesignatedWeapon("depthswalker", needed)
  if designated ~= "" then
    if wieldedMatchesDesignation(designated) then
      return trimmed
    end
  elseif wieldedNameContains(needed) then
    return trimmed
  end

  local normalized = boop.util.safeLower(trimmed)
  local wieldTarget = designated ~= "" and designated or needed
  if boop.util.starts(normalized, "wield " .. boop.util.safeLower(wieldTarget))
    or boop.util.starts(normalized, "quickwield " .. boop.util.safeLower(wieldTarget))
  then
    return trimmed
  end

  return "wield " .. wieldTarget .. "/" .. trimmed
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
    local cmd = standardCommand(profile.shield, boop.attacks.getStandardPreference(classKey, "shield"))
    if cmd ~= "" then return cmd, true, false end
  end
  if profile.dam then
      local cmd = standardCommand(profile.dam, boop.attacks.getStandardPreference(classKey, "dam"))
      if cmd ~= "" then
        if isTwoHandedSpec() and focusKnown() then
          cmd = prependFocusVerb(cmd)
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
  if standard ~= "" and class == "depthswalker" then
    standard = prependDepthswalkerWeapon(standard, standardShieldbreak)
  end

  local rageAction = ""
  local rageAbility = nil
  local rageDecision = nil
  if profile.rage then
    local rage = boop.attacks.getRage()
    local ability, decision = boop.attacks.selectRage(profile.rage, rage, class, standardShieldbreak)
    if ability and ability.cmd and ability.cmd ~= "" then
      rageAction = ability.cmd
      rageAbility = ability
    end
    rageDecision = decision
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
    rageAbility = rageAbility,
    rageDecision = rageDecision
  }
end

function boop.attacks.choosePullRage(targetToken)
  local target = boop.util.trim(targetToken or "")
  if target == "" then
    return "", nil
  end
  if not gmcp or not gmcp.Char or not gmcp.Char.Status then
    return "", nil
  end

  local class = boop.util.safeLower(gmcp.Char.Status.class or "")
  if class == "" then
    return "", nil
  end

  local profile = boop.attacks.registry[class]
  local rageProfile = profile and profile.rage
  if not rageProfile then
    return "", nil
  end

  local rage = boop.attacks.getRage()
  local ability = findByDescList(rageProfile, { "Big Damage", "Mid Damage", "Small Damage" }, rage)
  if not ability or not ability.cmd or ability.cmd == "" then
    return "", nil
  end

  return boop.util.formatTarget(ability.cmd, target), ability
end
