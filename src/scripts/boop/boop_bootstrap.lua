local DESIRED_SKILL_GROUPS = {
  "Artificing",
  "Elementalism",
  "Occultism",
  "Domination",
  "Malignity",
  "Attainment",
}

local function currentTargetId()
  return boop.state
    and boop.state.targeting
    and boop.state.targeting.currentTargetId
    or ""
end

local function isStandardDispatch(options)
  local registration = type(options) == "table"
      and type(options.outcomeRegistration) == "table"
      and options.outcomeRegistration
    or nil
  return not registration
    or tostring(registration.kind or "standard") == "standard"
end

-- Supported external compatibility entry point. Production callers use Wire
-- directly and provide target identity explicitly.
function boop.executeAction(action, forceQueue, options)
  if not (boop.wire and boop.wire.executeAction) then
    return false
  end
  local emitted = boop.wire.executeAction(
    action,
    currentTargetId(),
    forceQueue,
    options
  )
  if emitted
      and isStandardDispatch(options)
      and boop.gag
      and boop.gag.noteStandardIntent then
    boop.gag.noteStandardIntent(action)
  end
  return emitted
end

local function refreshComposition(options)
  options = type(options) == "table" and options or {}

  if options.ireSupport ~= false
      and boop.triggers
      and boop.triggers.setIreSupportReconciler then
    boop.triggers.setIreSupportReconciler(function(...)
      return boop.reconcileIreSupport(...)
    end)
  end

  if options.registries ~= false then
    if boop.ui and boop.ui.registerRegistryHandlers then
      boop.ui.registerRegistryHandlers()
    end
    if boop.registry and boop.registry.attachUiConfigRegistries then
      boop.registry.attachUiConfigRegistries(boop.config, boop.ui)
    end
  end
end

function boop.bootstrap()
  if boop.bootstrapped then
    refreshComposition()
    return false
  end
  boop.bootstrapped = true

  boop.requestCoreSupports({ force = true })

  local persisted
  if boop.db and boop.db.init then
    persisted = boop.db.init()
  end
  if type(persisted) == "table" then
    if boop.targets and boop.targets.applyPersistedLists then
      boop.targets.applyPersistedLists(persisted.lists)
    end
    if boop.stats and boop.stats.applyPersistedData then
      boop.stats.applyPersistedData(persisted.stats)
    end
  end

  if boop.runtime and boop.runtime.ensureState then
    boop.runtime.ensureState()
  end

  if boop.afflictions and boop.afflictions.init then
    boop.afflictions.init()
  end

  if boop.rage and boop.rage.init then
    boop.rage.init()
  end

  if boop.ih and boop.ih.init then
    boop.ih.init()
  end

  refreshComposition({ registries = false })

  if boop.triggers and boop.triggers.syncEnabled then
    boop.triggers.syncEnabled()
  end

  if boop.skills and boop.skills.init then
    boop.skills.init()
    boop.skills.setDesiredGroups(DESIRED_SKILL_GROUPS)
  end

  if boop.stats and boop.stats.init then
    boop.stats.init()
  end

  if boop.events and boop.events.register then
    boop.events.register()
  end

  refreshComposition({ ireSupport = false })

  if boop.skills and boop.skills.requestAll then
    boop.skills.requestAll()
  end

  if boop.ui and boop.ui.status then
    boop.ui.status("ready")
  end
  return true
end

if boop.stats and boop.stats.flushPersistence then
  boop.stats.flushPersistence("package reload")
end
local state = boop.runtime.ensureState()
boop.perf.setEnabled(false)
state.trace.live = false
boop.runtime.resetVenomConfusionCount("package reload")
boop.resetShieldMode("package reload")
boop.attacks.clearTemporaryPreferences("package reload")

boop.bootstrap()
