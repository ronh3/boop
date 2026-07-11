# Phase 02: State Ownership Repair and Safety Baseline - Pattern Map

**Mapped:** 2026-07-10T23:08:57Z
**Files analyzed:** 19
**Analogs found:** 19 / 19

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `src/scripts/boop/boop_runtime.lua` | service/coordinator | event-driven, transform | `src/scripts/boop/boop_runtime.lua` | exact |
| `src/scripts/boop/boop_safety.lua` | service | event-driven, command side effects | `src/scripts/boop/boop_safety.lua` + `src/scripts/boop/boop_events.lua` gold cleanup | exact |
| `src/scripts/boop/boop_events.lua` | event adapter/controller | event-driven | `src/scripts/boop/boop_events.lua` | exact |
| `src/scripts/boop/boop_walk.lua` | service/adapter | event-driven, external package bridge | `src/scripts/boop/boop_walk.lua` | exact, contains anti-patterns to remove |
| `src/scripts/boop/boop_targets.lua` | service/model | CRUD, transform, event-driven | `src/scripts/boop/boop_targets.lua` | exact |
| `src/scripts/boop/boop_attacks.lua` | service/planner | transform, request-response | `src/scripts/boop/boop_attacks.lua` | exact, contains fallback anti-patterns to remove |
| `src/scripts/boop/boop_ui.lua` | component/controller | request-response | `src/scripts/boop/boop_ui.lua` | exact, blocker source should change |
| `src/scripts/boop/boop_trace.lua` | utility | event-driven, batch buffer | `src/scripts/boop/boop_util.lua` trace block | role-match, new file |
| `src/scripts/boop/boop_util.lua` | utility | command side effects, transform | `src/scripts/boop/boop_util.lua` | exact |
| `src/scripts/boop/boop_state.lua` | model/bootstrap | initialization | `src/scripts/boop/boop_state.lua` + `boop_runtime.lua` | exact |
| `src/scripts/boop/scripts.json` | config | load-order | `src/scripts/boop/scripts.json` | exact |
| `tools/check_release_gates.py` | utility | batch, file-I/O, transform | `tools/check_release_gates.py` | exact |
| `tests/boop_event_transitions_spec.lua` | test | event-driven | `tests/boop_event_transitions_spec.lua` | exact |
| `tests/boop_safety_spec.lua` | test | event-driven, side-effect ordering | `tests/boop_safety_spec.lua` | exact |
| `tests/boop_walk_spec.lua` | test | event-driven | `tests/boop_tick_spec.lua` + `tests/boop_event_transitions_spec.lua` | role-match |
| `tests/boop_trace_spec.lua` | test | event-driven, buffer assertions | `tests/boop_trace_spec.lua` | exact |
| `tests/boop_ui_spec.lua` | test | request-response rendering | `tests/boop_ui_spec.lua` | exact |
| `tests/support/boop_test_helper.lua` | test utility | fixture setup/reset | `tests/support/boop_test_helper.lua` | exact |
| `tests/boop_runtime_spec.lua` | test | state-contract, event-driven effects | `tests/boop_runtime_spec.lua` + `tests/boop_state_contract_spec.lua` | exact |

## Pattern Assignments

### `src/scripts/boop/boop_runtime.lua` (service/coordinator, event-driven transform)

**Analog:** `src/scripts/boop/boop_runtime.lua`

**Namespace/import pattern** (lines 1-3):
```lua
boop.runtime = boop.runtime or {}

local function deepCopy(value, seen)
```

**Owned-domain defaults pattern** (lines 19-90):
```lua
local DOMAIN_DEFAULTS = {
  combat = {
    hunting = false,
    attacking = false,
    fleeing = false,
    class = "",
    spec = "",
    limiters = {
      hunting = false,
      targeting = false,
      setting = false,
      rage = false,
    },
    openerUsedByClass = {},
    pullState = false,
    lastComboTraceKey = nil,
    lastOpenerTraceKey = nil,
    lastRageDecision = nil,
  },
  targeting = {
    currentTargetId = "",
    targetName = "",
    targetShield = false,
    denizens = {},
    room = "",
    lastRoom = "",
    lastRoomDir = "",
    movedRooms = false,
    calledTargetId = "",
    calledTargetRoom = "",
    calledTargetBy = "",
    calledTargetAt = nil,
    incomingWhitelistShares = {},
    pendingWhitelistShare = nil,
  },
  gold = {
    dropped = false,
    shardsDropped = false,
    autoGrabPending = false,
```

**State materialization pattern** (lines 124-140):
```lua
function boop.runtime.ensureState()
  boop.state = boop.state or {}
  local state = boop.state

  for domain, defaults in pairs(DOMAIN_DEFAULTS) do
    local current = rawget(state, domain)
    if type(current) ~= "table" then
      current = {}
      rawset(state, domain, current)
    end
    for key, default in pairs(defaults) do
      if current[key] == nil then
        current[key] = deepCopy(default)
      end
    end
  end
  return state
end
```

**Context snapshot pattern** (lines 177-235):
```lua
function boop.runtime.context()
  local state = boop.runtime.ensureState()
  local room = currentRoom()
  local targetInfo = gmcp and gmcp.IRE and gmcp.IRE.Target and gmcp.IRE.Target.Info or {}
  local currentTargetId = tostring(state.targeting.currentTargetId or "")
  local targetInfoId = tostring(targetInfo.id or "")
  local hpperc = ""
  if targetInfo.hpperc ~= nil then
    if currentTargetId == "" then
      hpperc = targetInfoId == "" and tostring(targetInfo.hpperc or "") or ""
    elseif targetInfoId == currentTargetId then
      hpperc = tostring(targetInfo.hpperc or "")
    end
  end
...
    target = {
      id = currentTargetId,
      infoId = targetInfoId,
      name = tostring(state.targeting.targetName or ""),
      shield = state.targeting.targetShield,
      hpperc = tostring(hpperc or ""),
    },
    denizens = state.targeting.denizens or {},
```

**Core effect pattern** (lines 253-286):
```lua
local function tickStep(context)
  local state = context.state
  local effects = {}

  if not (context.config and context.config.enabled) then
    return { effects = effects, didAction = false }
  end
  if state.diag.hold then
    return { effects = effects, didAction = false }
  end
  if boop.maybeFlushPendingGold and boop.maybeFlushPendingGold("tick pending age") then
    return { effects = effects, didAction = false }
  end
  if state.gold.getPending or state.gold.putPending then
    return { effects = effects, didAction = false }
  end

  if boop.safety and boop.safety.shouldFlee and boop.safety.shouldFlee() then
    effects[#effects + 1] = { kind = "flee" }
    return { effects = effects, didAction = false }
  end
```

**Side-effect boundary pattern** (lines 366-410):
```lua
function boop.runtime.applyEffects(result, context)
  local state = (context and context.state) or boop.runtime.ensureState()
  local didAction = false

  for _, effect in ipairs((result and result.effects) or {}) do
    if effect.kind == "trace" then
      if boop.trace and boop.trace.log then
        boop.trace.log(effect.message or "")
      end
    elseif effect.kind == "flush_gold" then
      if boop.flushPendingGold then
        boop.flushPendingGold(effect.reason or "runtime")
      end
    elseif effect.kind == "walk_advance" then
      if boop.walk and boop.walk.maybeAdvance then
        boop.walk.maybeAdvance(effect.reason or "runtime")
      end
```

**Apply to Phase 02:** Add blocker defaults under an owned domain here, expose a normalized blocker snapshot through `boop.runtime.context()`, and make `tickStep()` short-circuit attacks, walk, queue/prequeue, and gold based on that snapshot before emitting side effects.

---

### `src/scripts/boop/boop_safety.lua` (service, event-driven command side effects)

**Analog:** `src/scripts/boop/boop_safety.lua`

**Namespace and threshold pattern** (lines 1-20):
```lua
boop.safety = boop.safety or {}

function boop.safety.parseThreshold(value)
  if type(value) == "string" and value:find("%%") then
    local pct = tonumber(value:match("(%d+)") or "0")
    if gmcp and gmcp.Char and gmcp.Char.Vitals and gmcp.Char.Vitals.maxhp then
      return pct * gmcp.Char.Vitals.maxhp / 100
    end
    return pct
  end
  return tonumber(value) or 0
end

function boop.safety.shouldFlee()
  if not boop.config.enabled or not boop.config.fleeEnabled or not boop.config.fleeAt then return false end
  if not gmcp or not gmcp.Char or not gmcp.Char.Vitals then return false end
```

**Current flee pattern to preserve and strengthen** (lines 23-58):
```lua
function boop.safety.flee()
  boop.state.combat.attacking = false
  boop.config.enabled = false
  if boop.clearGoldQueueIntent then
    boop.clearGoldQueueIntent()
  end
...
  local action = "wake/wake/apply mending to legs/stand/" .. dir
  boop.executeAction(action)
  boop.util.ok("fleeing " .. dir .. " (boop disabled)")
  boop.state.combat.fleeing = true
  if boop.stats and boop.stats.onFlee then
    boop.stats.onFlee()
  end
  tempTimer(2, function() boop.state.combat.fleeing = false end)
end
```

**Gold cleanup analog from events** (`src/scripts/boop/boop_events.lua` lines 217-235):
```lua
function boop.clearGoldQueueIntent()
  boop.state = boop.state or {}
  if boop.state.gold.autoGrabTimer then
    killTimer(boop.state.gold.autoGrabTimer)
    boop.state.gold.autoGrabTimer = nil
  end
  boop.state.gold.autoGrabPending = false
  boop.state.gold.autoGrabPendingAt = nil
  boop.state.gold.dropped = false
...
  boop.state.gold.getPending = false
  boop.state.gold.putPending = false
  boop.state.gold.getRetries = 0
  boop.state.gold.putRetries = 0
  boop.state.gold.packTarget = ""
end
```

**Apply to Phase 02:** Extract a testable `clearAutomationIntent(reason)`-style helper before `boop.executeAction(action)`. It should clear combat plans, queue/prequeue, target-call intent, walk advancement, and gold intent before any `send()` can happen.

---

### `src/scripts/boop/boop_events.lua` (event adapter/controller, event-driven)

**Analog:** `src/scripts/boop/boop_events.lua`

**Event registration pattern** (lines 480-512):
```lua
function boop.events.register()
  if boop.handlers then
    for _, id in ipairs(boop.handlers) do
      if killAnonymousEventHandler then
        killAnonymousEventHandler(id)
      end
    end
  end
  boop.handlers = {}

  if not registerAnonymousEventHandler then return end

  local function add(event, fn)
    local id = registerAnonymousEventHandler(event, fn)
    boop.handlers[#boop.handlers + 1] = id
  end

  add("gmcp.Char.Items.List", "boop.onRoomItemsList")
  add("gmcp.Char.Items.Add", "boop.onRoomItemsAdd")
  add("gmcp.Char.Items.Remove", "boop.onRoomItemsRemove")
```

**Room item list/add/remove pattern** (lines 523-546):
```lua
function boop.onRoomItemsList()
  if not gmcp or not gmcp.Char or not gmcp.Char.Items or not gmcp.Char.Items.List then return end
  if gmcp.Char.Items.List.location == "inv" then
    rebuildWieldedFromInventory(gmcp.Char.Items.List.items, "inventory list")
    return
  end
  if gmcp.Char.Items.List.location ~= "room" then return end
  local items = gmcp.Char.Items.List.items
  boop.targets.updateRoomItems(items)
...
  if boop.walk and boop.walk.onRoomSettled then
    boop.walk.onRoomSettled("room items list")
  end
end
```

**Target-loss cleanup starting point** (lines 561-628):
```lua
function boop.onRoomItemsRemove()
...
  boop.targets.removeRoomItem(removed)
...
  local current = tostring(boop.state.targeting.currentTargetId or "")
  if current == "" or current ~= removedId then
    return
  end

  if boop.stats and boop.stats.onTargetRemoved then
    boop.stats.onTargetRemoved(removedId, removedName)
  end
  boop.state.targeting.currentTargetId = ""
  boop.state.targeting.targetName = ""
  boop.state.queue.prequeuedStandard = false
  boop.state.queue.aliasDirty = true
...
  local nextTarget = boop.targets and boop.targets.choose and boop.targets.choose() or ""
  if nextTarget ~= "" then
    boop.targets.setTarget(nextTarget)
  end

  tempTimer(0, function()
    if boop and boop.tick then
      boop.tick()
    end
  end)
end
```

**Room transition and pull lifecycle pattern** (lines 637-713):
```lua
function boop.onRoomInfo()
  if not gmcp or not gmcp.Room or not gmcp.Room.Info then return end
  if boop.runtime and boop.runtime.ensureState then
    boop.runtime.ensureState()
  end
...
  if previousRoomText ~= currentRoomText then
    targeting.movedRooms = true
    targeting.lastRoom = previousRoom
    boop.clearGoldQueueIntent()
...
    if boop.walk and boop.walk.onRoomChange then
      boop.walk.onRoomChange()
    end
  else
    targeting.movedRooms = false
  end

  targeting.room = info.num
  traceRoomInfo(info, targeting.movedRooms, previousRoom)
...
  local pull = combat.pullState
  if type(pull) == "table" and pull.active then
```

**GMCP recovery analog** (lines 764-771):
```lua
function boop.onCharStatus()
  if not gmcp or not gmcp.Char or not gmcp.Char.Status then return end
  if boop.requestCoreSupports and (not gmcp.IRE or not gmcp.IRE.Target or not gmcp.IRE.Display) then
    boop.requestCoreSupports({
      requestSkills = true,
      minInterval = 0,
      force = true,
    })
  end
```

**Prequeue gate pattern** (lines 858-899):
```lua
function boop.prequeueStandard()
  if not boop.config.enabled then return end
  if not boop.config.prequeueEnabled then return end
  if boop.state.diag.hold then return end
  if boop.state.gold.getPending or boop.state.gold.putPending then return end
  if boop.state.queue.prequeuedStandard then return end
...
  local targetId = boop.targets.choose()
  if not targetId or targetId == "" then
    if boop.config.useQueueing and boop.state.gold.autoGrabPending then
      flushPendingGold("prequeue no target")
    end
```

**Apply to Phase 02:** Keep event handlers thin, but call canonical runtime blocker/cleanup helpers from room item removal, room info, prompt, char status, and prequeue. Use existing `boop.requestCoreSupports()` for GMCP recovery; add structured blocker state and warning throttling around it.

---

### `src/scripts/boop/boop_walk.lua` (service/adapter, event-driven)

**Analog:** `src/scripts/boop/boop_walk.lua`

**Namespace and availability pattern** (lines 1-18):
```lua
boop.walk = boop.walk or {}

local WALKER_PACKAGE_URL = "https://github.com/demonnic/demonnicAutoWalker/releases/latest/download/demonnicAutoWalker.mpackage"
boop.walk.packageUrl = boop.walk.packageUrl or WALKER_PACKAGE_URL

local function walkState()
  boop.state = boop.state or {}
  return boop.state
end

local function currentRoomId()
  if gmcp and gmcp.Room and gmcp.Room.Info and gmcp.Room.Info.num then
    return tostring(gmcp.Room.Info.num or "")
```

**Current blocker anti-pattern to migrate** (lines 70-109):
```lua
local function blockedReason()
  local state = walkState()
...
  if state.diagHold then
    return "diag pause is active"
  end
  if state.fleeing then
    return "flee is active"
  end
  if state.autoGrabGoldPending or state.goldGetPending or state.goldPutPending then
    return "loot handling is still pending"
  end
  if tostring(state.currentTargetId or "") ~= "" then
    return "current target still set"
  end
  local targetId = boop.targets and boop.targets.choose and boop.targets.choose() or ""
```

**Start/stop pattern** (lines 184-225):
```lua
function boop.walk.start(options)
  if not available() then
    boop.util.warn("demonnicAutoWalker is not available")
    boop.util.info("Install it with: boop walk install")
    return false
  end

  local state = walkState()
  if state.walkActive and attached() then
    boop.walk.status()
    return true
  end

  state.walkActive = true
  state.walkOwned = not attached()
  state.walkMoveQueued = false
  state.walkRoomSettled = false
```

**Advance pattern** (lines 266-285):
```lua
function boop.walk.maybeAdvance(reason)
  local state = walkState()
  local blocked = blockedReason()
  if blocked then
    return false, blocked
  end

  state.walkMoveQueued = true
  state.walkRoomSettled = false
  boop.trace.log("walk advance: " .. tostring(reason or "unspecified"))
  tempTimer(0, function()
    local liveState = walkState()
    if not liveState.walkActive then
      return
    end
    if raiseEvent then
      raiseEvent("demonwalker.move")
    end
```

**Apply to Phase 02:** Preserve the adapter shape, but make `walkState()` return `boop.runtime.ensureState().walk` or a tuple of domain tables. Replace `state.walkActive`, `state.diagHold`, `state.fleeing`, `state.goldGetPending`, and `state.currentTargetId` with `state.walk.active`, `state.diag.hold`, `state.combat.fleeing`, `state.gold.*`, and `state.targeting.currentTargetId`, or defer to the canonical runtime blocker snapshot.

---

### `src/scripts/boop/boop_targets.lua` (service/model, CRUD/transform/event-driven)

**Analog:** `src/scripts/boop/boop_targets.lua`

**Namespace and helper pattern** (lines 1-12):
```lua
boop.targets = boop.targets or {}

local function normalizeName(name)
  if not name then return "" end
  local v = boop.util.trim(tostring(name))
  v = v:gsub("\226\128\152", "'") -- left single quotation mark
  v = v:gsub("\226\128\153", "'") -- right single quotation mark
  return boop.util.safeLower(v)
end
```

**Room denizen CRUD pattern** (lines 140-174):
```lua
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
...
function boop.targets.removeRoomItem(item)
```

**Apply-target pattern** (lines 177-207):
```lua
function boop.targets.applyTarget(id, opts)
  opts = opts or {}
  boop.state = boop.state or {}
  boop.state.targeting = boop.state.targeting or {}

  local nextId = boop.util.trim(tostring(id or ""))
  local prevId = boop.util.trim(tostring(boop.state.targeting.currentTargetId or ""))
  local changed = prevId ~= nextId
  local targetName = nextId ~= "" and resolveTargetName(nextId, opts.name) or ""

  if changed and boop.targets.clearTargetShield then
    boop.targets.clearTargetShield(opts.reason or "target changed")
  end
  if changed and boop.afflictions and boop.afflictions.clearTarget then
    boop.afflictions.clearTarget()
```

**Selection pattern** (lines 933-995):
```lua
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
...
  return ""
end
```

**Shield cleanup pattern** (lines 1553-1560):
```lua
function boop.targets.clearTargetShield(reason)
  if boop.state and type(boop.state.targeting.targetShield) == "table" and boop.state.targeting.targetShield.timer then
    killTimer(boop.state.targeting.targetShield.timer)
  end
  boop.state.targeting.targetShield = false
  if reason and boop.trace and boop.trace.log then
    boop.trace.log("shield cleared: " .. tostring(reason))
  end
end
```

**Apply to Phase 02:** Target-loss cleanup should call this module for `applyTarget("")`, shield/affliction clearing, and valid-retarget choice. Do not duplicate denizen validity or list-mode logic inside events or runtime.

---

### `src/scripts/boop/boop_attacks.lua` (service/planner, transform/request-response)

**Analog:** `src/scripts/boop/boop_attacks.lua`

**Namespace and context pattern** (lines 1-24):
```lua
boop.attacks = boop.attacks or {}
boop.attacks.registry = boop.attacks.registry or {}
boop.attacks.pendingRegistry = boop.attacks.pendingRegistry or {}

local planningContext = nil

local function withContext(context, fn)
  local previous = planningContext
  planningContext = context
  local ok, a, b, c, d, e, f = pcall(fn)
  planningContext = previous
  if not ok then
    error(a)
  end
  return a, b, c, d, e, f
end
```

**Current no-context fallback anti-pattern** (lines 39-64):
```lua
local function planningSpec()
...
  local state = planningState()
  if state and state.combat and state.combat.spec ~= nil then
    return boop.util.trim(tostring(state.combat.spec or ""))
  end
  return boop.util.trim(tostring(state and state.spec or ""))
end

local function planningTargetId()
...
  local state = planningState()
  return boop.util.trim(tostring(state and state.currentTargetId or ""))
end

local function planningTargetShield()
...
  local state = planningState()
  return state and state.targetShield or false
end
```

**Plan/build pattern** (lines 1496-1540):
```lua
function boop.attacks.plan(context)
  return withContext(context, function()
    local class = planningContext and planningContext.class or ""
    if class == "" and gmcp and gmcp.Char and gmcp.Char.Status then
      class = boop.util.safeLower(gmcp.Char.Status.class)
    end
    if class == "" then
      return { standard = "", rage = "" }
    end

    local profile = boop.attacks.registry[class]
    if not profile then
      return { standard = "", rage = "" }
    end
...
    return {
      class = class,
      standard = standard,
      standardShieldbreak = standardShieldbreak,
      standardIsOpener = standardIsOpener,
      rage = rageAction,
      rageAbility = rageAbility,
      rageDecision = rageDecision
    }
  end)
end
```

**Execute pattern** (lines 1599-1627):
```lua
function boop.attacks.execute(plan, context)
  if type(plan) ~= "table" then
    return false
  end

  local activeContext = context or (boop.runtime and boop.runtime.context and boop.runtime.context()) or nil
  local didAction = false

  if plan.standard and plan.standard ~= "" then
    local prequeued = activeContext and activeContext.queue and activeContext.queue.prequeuedStandard or false
    if not prequeued and boop.canAct and boop.canAct() then
      boop.executeAction(plan.standard)
...
```

**Apply to Phase 02:** Keep planner context injection. Remove Phase 02-owned flat fallbacks by reading `state.combat.spec`, `state.targeting.currentTargetId`, `state.targeting.targetShield`, and `state.inventory.*` only. Blocker checks should happen before calling `choose()`/`execute()`, not inside profile data.

---

### `src/scripts/boop/boop_ui.lua` (component/controller, request-response)

**Analog:** `src/scripts/boop/boop_ui.lua`

**Current blocker anti-pattern to replace** (lines 329-374):
```lua
local function currentBlocker()
  if not boop.config.enabled then
    return "boop disabled", "boop on"
  end
  if boop.state and boop.state.diag.hold then
    return "diagnose pause active", "wait for diag or use diag"
  end
  if boop.state and boop.state.combat.fleeing then
    return "flee in progress", "let flee resolve"
  end
...
  local targetId = tostring(boop.state and boop.state.targeting.currentTargetId or "")
  if targetId ~= "" then
    return "engaged target", "let boop attack"
  end
```

**Row rendering pattern** (lines 710-731):
```lua
uiPrintRow = function(index, label, buttonText, buttonColor, onClick, hint, labelWidth)
  if cecho then
    local theme = themeTags()
    local width = tonumber(labelWidth) or UI_LABEL_COL_WIDTH
    local prefix = uiIndexPrefix(index)
    local leftRaw = prefix .. tostring(label or "")
    local left = uiPadRight(leftRaw, width)
    cecho("\n" .. theme.text .. left .. " " .. theme.reset)
    local colorTag = semanticTag(tostring(buttonColor or "text"))
    local coloredButton = colorTag .. uiButtonLabel(buttonText or "") .. theme.reset
...
  local row = prefix .. tostring(label or "") .. " " .. uiButtonLabel(buttonText or "")
  boop.util.echo(row)
end
```

**Status/dashboard pattern** (lines 400-455):
```lua
local blocker, nextAction = currentBlocker()
...
if cecho then
  local row = 1
  uiPrintHeader("boop > status")

  uiPrintSection("core")
  uiPrintRow(row, "Enabled", boolText(boop.config.enabled), boolColor(boop.config.enabled))
...
  uiPrintRow(row, "Blocker", blocker, blocker == "ready" and "green" or "yellow")
  row = row + 1
  uiPrintRow(row, "Next action", nextAction, "cyan")
```

**Home dashboard pattern** (lines 3614-3676):
```lua
function boop.ui.home()
...
  local blocker, nextAction = currentBlocker()
...
    uiPrintRow(3, "Blocker", blocker, blocker == "ready" and "green" or "yellow")
    uiPrintRow(4, "Next action", nextAction, "cyan")
...
  boop.util.echo(string.format("State: %s | mode: %s | blocker: %s | next: %s", enabled, modeShown, blocker, nextAction))
```

**Pull lifecycle pattern** (lines 1267-1310, 1463-1486):
```lua
function boop.ui.clearPullState(reason)
  boop.state = boop.state or {}
  local pull = boop.state.combat and boop.state.combat.pullState or nil
  if type(pull) == "table" then
    stopPullTimeout(pull)
  end
  if boop.state.combat then
    boop.state.combat.pullState = false
  end
  if reason and reason ~= "" then
    boop.trace.log("pull: cleared " .. tostring(reason))
  end
end
...
  boop.state.combat.pullState = {
    active = true,
    phase = "outbound",
    originRoom = originRoom,
    direction = dir,
    returnDirection = back,
    restoreEnabled = restoreEnabled,
  }
  armPullTimeout(boop.state.combat.pullState)

  local command = table.concat({ dir, rageAction, "leap " .. back }, separator)
  send(command, false)
```

**Trace command pattern** (lines 1657-1678):
```lua
function boop.ui.traceCommand(sub, arg)
  local cmd = boop.util.safeLower(boop.util.trim(sub or ""))
  if cmd == "" then
    boop.util.info("trace: " .. (boop.config.traceEnabled and "on" or "off"))
    boop.util.info("boop trace on|off|show [n]|clear")
    return
...
  if cmd == "show" then
    boop.trace.show(arg)
    return
```

**Apply to Phase 02:** Preserve compact UI rows and plain fallback text, but replace `currentBlocker()` internals with a call into the runtime blocker snapshot. Keep blocker code/label stable, for example `target_lost -- target left room`, and show affected systems/wait state in status/debug surfaces.

---

### `src/scripts/boop/boop_trace.lua` (utility, event-driven batch buffer)

**Analog:** `src/scripts/boop/boop_util.lua` trace block. `src/scripts/boop/boop_trace.lua` does not exist yet.

**Trace namespace and append pattern** (`src/scripts/boop/boop_util.lua` lines 106-124):
```lua
boop.trace = boop.trace or {}

function boop.trace.log(msg)
  if not msg or msg == "" then return end
  if not boop.config or not boop.config.traceEnabled then return end

  boop.state = boop.state or {}
  boop.state.trace.buffer = boop.state.trace.buffer or {}

  local ts = os.date("%H:%M:%S")
  local line = string.format("%s | %s", ts, tostring(msg))
  local buf = boop.state.trace.buffer
  buf[#buf + 1] = line

  local limit = 100
  while #buf > limit do
    table.remove(buf, 1)
  end
end
```

**Trace display/clear pattern** (`src/scripts/boop/boop_util.lua` lines 126-148):
```lua
function boop.trace.show(count)
  boop.state = boop.state or {}
  boop.state.trace.buffer = boop.state.trace.buffer or {}
  local buf = boop.state.trace.buffer
  local total = #buf
  if total == 0 then
    boop.util.info("trace: (empty)")
    return
  end
...
function boop.trace.clear()
  boop.state = boop.state or {}
  boop.state.trace.buffer = {}
  boop.util.ok("trace: cleared")
end
```

**Manifest load-order pattern** (`src/scripts/boop/scripts.json` lines 1-8):
```json
[
  {"name": "boop_init", "isActive": "yes", "isFolder": "no", "script": ""},
  {"name": "boop_util", "isActive": "yes", "isFolder": "no", "script": ""},
  {"name": "boop_theme", "isActive": "yes", "isFolder": "no", "script": ""},
  {"name": "boop_skills", "isActive": "yes", "isFolder": "no", "script": ""},
  {"name": "boop_db", "isActive": "yes", "isFolder": "no", "script": ""},
```

**Apply to Phase 02:** If creating this file, move trace methods out of `boop_util.lua` without changing the `boop.trace.*` public API. Insert `boop_trace` after `boop_util` and before modules that call `boop.trace.log`.

---

### `src/scripts/boop/boop_util.lua` (utility, command side effects/transform)

**Analog:** `src/scripts/boop/boop_util.lua`

**Compact feedback pattern** (lines 45-84):
```lua
local FEEDBACK_STYLE = {
  INFO = { themeKey = "info", textKey = "text", fallbackTag = "cyan", fallbackText = "white" },
  OK = { themeKey = "ok", textKey = "text", fallbackTag = "green", fallbackText = "white" },
  WARN = { themeKey = "warn", textKey = "text", fallbackTag = "yellow", fallbackText = "white" },
  ERR = { themeKey = "err", textKey = "text", fallbackTag = "red", fallbackText = "white" },
}

function boop.util.feedback(kind, msg)
...
function boop.util.warn(msg)
  boop.util.feedback("WARN", msg)
end
```

**Queue/gold command gate pattern** (lines 198-247):
```lua
function boop.executeAction(action, forceQueue)
  if not action or action == "" then return end
  action = prependAssist(action)
...
  if boop.config.useQueueing or forceQueue then
    boop.state = boop.state or {}
    if boop.config.useQueueing and boop.state.gold.autoGrabPending then
...
      send("queue addclearfull freestand BOOP_ATTACK", false)
      boop.trace.log("std queue: " .. queuedAction)
      markUnnamableMaulUsed(queuedAction)
      return
    end
    if boop.config.useQueueing and (boop.state.gold.getPending or boop.state.gold.putPending) then
      boop.trace.log("std queue blocked: gold pending")
      return
    end
```

**Apply to Phase 02:** Keep `[WARN]`/`[OK]` output helpers for one-line blocker warnings. If queue execution must hard-hold on blockers, add that check here or higher in runtime before `executeAction()`, but avoid a second source of blocker truth.

---

### `src/scripts/boop/boop_state.lua` (model/bootstrap, initialization)

**Analog:** `src/scripts/boop/boop_state.lua`

**State init pattern** (lines 1-16):
```lua
boop.state = boop.state or {}

function boop.state.init()
  if boop.registry and boop.registry.attachUiConfigRegistries then
    boop.registry.attachUiConfigRegistries()
  end

  if boop.runtime and boop.runtime.ensureState then
    boop.state = boop.runtime.ensureState()
    return
  end

  boop.state = boop.state or { combat = {} }
  boop.state.combat = boop.state.combat or {}
  boop.state.combat.hunting = boop.state.combat.hunting or false
end
```

**Apply to Phase 02:** Do not recreate flat compatibility keys here. Any new blocker defaults should live in `boop_runtime.lua` `DOMAIN_DEFAULTS` and be materialized through `ensureState()`.

---

### `src/scripts/boop/scripts.json` (config, load-order)

**Analog:** `src/scripts/boop/scripts.json`

**Current load-order pattern** (lines 1-22):
```json
[
  {"name": "boop_init", "isActive": "yes", "isFolder": "no", "script": ""},
  {"name": "boop_util", "isActive": "yes", "isFolder": "no", "script": ""},
  {"name": "boop_theme", "isActive": "yes", "isFolder": "no", "script": ""},
...
  {"name": "boop_runtime", "isActive": "yes", "isFolder": "no", "script": ""},
  {"name": "boop_state", "isActive": "yes", "isFolder": "no", "script": ""},
...
  {"name": "boop_ui", "isActive": "yes", "isFolder": "no", "script": ""},
  {"name": "boop_events", "isActive": "yes", "isFolder": "no", "script": ""},
  {"name": "boop_bootstrap", "isActive": "yes", "isFolder": "no", "script": ""}
]
```

**Apply to Phase 02:** If `boop_trace.lua` is added, insert it after `boop_util` so `boop.trace` exists before runtime/events/targets/walk call it. Keep `boop_bootstrap` last and do not sort this manifest.

---

### `tools/check_release_gates.py` (utility, batch/file-I/O/transform)

**Analog:** `tools/check_release_gates.py`

**Owned domain list and baseline pattern** (lines 29-71):
```python
OWNED_STATE_DOMAINS = {
    "combat",
    "targeting",
    "gold",
    "queue",
    "walk",
    "diag",
    "trace",
    "ui",
    "rage",
    "inventory",
    "ih",
    "gag",
}

# Reviewed legacy flat-state accesses that still exist before Phase 2 behavior
# repair work. The gate fails when this baseline grows or shrinks without review.
KNOWN_FLAT_STATE_ACCESS = {
    "src/scripts/boop/boop_events.lua": {},
```

**Flat-state scanner pattern** (lines 241-253):
```python
def scan_flat_state_access(path: Path) -> Counter[str]:
    pattern = re.compile(
        r"\b(?:state|vars|liveState)\.([A-Za-z_][A-Za-z0-9_]*)"
        r"|\bboop\.state\.([A-Za-z_][A-Za-z0-9_]*)"
    )
    counts: Counter[str] = Counter()
    for raw_line in path.read_text().splitlines():
        line = raw_line.split("--", 1)[0]
        for match in pattern.finditer(line):
            key = match.group(1) or match.group(2)
            if key not in OWNED_STATE_DOMAINS:
                counts[key] += 1
    return counts
```

**Check and CLI pattern** (lines 256-330):
```python
def check_state_drift() -> list[str]:
    errors: list[str] = []
    for file_name, expected in KNOWN_FLAT_STATE_ACCESS.items():
        path = ROOT / file_name
...
CHECKS = {
    "versions": check_versions,
    "manifests": check_manifests,
    "state-drift": check_state_drift,
}
...
        if errors:
            failed = True
            print(f"[FAIL] {name}")
            for error in errors:
                print(f"  - {error}")
        else:
            print(f"[OK] {name}")
```

**Apply to Phase 02:** For migrated files, reduce or remove baseline entries intentionally. To enforce "no flat state in this migrated file", keep the file in `KNOWN_FLAT_STATE_ACCESS` with `{}` so the scanner fails on reintroduced flat keys.

---

### `tests/support/boop_test_helper.lua` (test utility, fixture setup/reset)

**Analog:** `tests/support/boop_test_helper.lua`

**Reset pattern** (lines 93-166):
```lua
function M.reset()
  assert(boop, "boop package is not loaded")
  local desiredGroups = boop.skills and boop.skills.desiredGroups or nil

  resetDb()

  gmcp = {
    Char = {
...
    IRE = {
      Target = {
        Set = "",
        Info = {
          id = "",
          hpperc = "100%",
        },
      },
      Display = {
        ButtonActions = {},
      },
    },
  }
...
  resetTableData(boop.state)
  boop.state.init()
```

**Owned fixture setters** (lines 173-222):
```lua
function M.setClass(className)
  gmcp.Char.Status.class = className
  boop.state.combat.class = className
end
...
function M.setTarget(id, name, hpperc)
  local targetId = tostring(id or "")
  boop.state.targeting.currentTargetId = targetId
  boop.state.targeting.targetName = tostring(name or "")
  gmcp.IRE.Target.Set = targetId
  gmcp.IRE.Target.Info.id = targetId
...
function M.setDenizens(denizens)
  boop.state.targeting.denizens = {}
```

**Apply to Phase 02:** Add blocker/pull/walk/gold helpers here only if tests repeat setup. Seed and assert owned domains only; do not add old flat keys for convenience.

---

### `tests/boop_event_transitions_spec.lua` (test, event-driven)

**Analog:** `tests/boop_event_transitions_spec.lua`

**Harness/stub pattern** (lines 1-20):
```lua
local helper = dofile(os.getenv("TESTS_DIRECTORY") .. "/support/boop_test_helper.lua")

describe("boop event-driven state transitions", function()
  local send_stub
  local send_gmcp_stub
  local timer_stub
  local kill_timer_stub
  local scheduled_callback

  before_each(function()
    helper.reset()
    scheduled_callback = nil

    send_stub = stub(_G, "send", function(_, _) end)
    send_gmcp_stub = stub(_G, "sendGMCP", function(_) end)
    timer_stub = stub(_G, "tempTimer", function(_, callback)
```

**Target removal assertion pattern** (lines 42-78):
```lua
it("retargets without clearing the server queue when the current denizen is removed from the room", function()
  helper.setArea("Test Area")
  helper.setClass("Occultist")
  helper.learnSkill("Lycantha", "Domination")
  helper.setDenizens({
    { id = "42", name = "a first denizen" },
    { id = "43", name = "a second denizen" },
  })
  helper.setTarget("42", "a first denizen", "80%")
...
  boop.onRoomItemsRemove()

  assert.are.equal("43", boop.state.targeting.currentTargetId)
  assert.are.equal("a second denizen", boop.state.targeting.targetName)
  assert.is_false(boop.state.targeting.targetShield)
```

**Room/gold transition pattern** (lines 125-153):
```lua
it("clears gold intent and remembers the return exit when the room changes", function()
  boop.state.targeting.room = 100
  boop.state.combat.fleeing = false
  boop.state.targeting.targetShield = { attempted = false, timer = 57 }
  boop.state.gold.getPending = true
  boop.state.gold.putPending = true
...
  boop.onRoomInfo()

  assert.is_true(boop.state.targeting.movedRooms)
  assert.are.equal(100, boop.state.targeting.lastRoom)
  assert.are.equal("north", boop.state.targeting.lastRoomDir)
  assert.are.equal(200, boop.state.targeting.room)
```

**GMCP recovery pattern** (lines 179-197):
```lua
it("re-announces core gmcp supports on connection-ready events", function()
  boop.onConnectionEvent()

  assert.stub(send_gmcp_stub).was_called_with('Core.Supports.Add ["IRE.Target 1"]')
  assert.stub(send_gmcp_stub).was_called_with('Core.Supports.Add ["IRE.Display 3"]')
  assert.stub(send_gmcp_stub).was_called_with('Core.Supports.Add ["Char.Skills 1"]')
  assert.stub(send_gmcp_stub).was_called_with([[Char.Skills.Get]])
end)
```

**Apply to Phase 02:** Extend this file for target-loss cleanup, pull exception behavior, prompt-plus-GMCP blocker clearing, and GMCP missing-IRE blocker entry. Keep assertions on owned state and outbound calls.

---

### `tests/boop_safety_spec.lua` (test, event-driven side-effect ordering)

**Analog:** `tests/boop_safety_spec.lua`

**Harness pattern** (lines 20-34):
```lua
before_each(function()
  helper.reset()
  boop.config.enabled = true
  trigger_calls = {}

  send_stub = stub(_G, "send", function(_, _) end)
  timer_stub = stub(_G, "tempTimer", function(_, _)
    return 1
  end)
  save_config_stub = stub(boop.db, "saveConfig", function(_, _) end)
  saved_disable_trigger = _G.disableTrigger
  _G.disableTrigger = function(name)
    trigger_calls[#trigger_calls + 1] = { op = "disable", name = name }
  end
end)
```

**Flee assertion pattern** (lines 58-75):
```lua
it("flees and disables boop when health crosses the configured threshold", function()
  gmcp.Char.Vitals.hp = 1000
  gmcp.Char.Vitals.maxhp = 5000
  boop.config.fleeAt = "30%"
  boop.state.targeting.lastRoomDir = "north"

  boop.tick()

  assert.stub(save_config_stub).was_called_with("enabled", false)
  assert.stub(send_stub).was_called_with("wake", false)
  assert.stub(send_stub).was_called_with("apply mending to legs", false)
  assert.stub(send_stub).was_called_with("stand", false)
  assert.stub(send_stub).was_called_with("north", false)
  assert.is_false(boop.config.enabled)
```

**Apply to Phase 02:** Add a call-order recorder for cleanup-before-send. Seed `state.queue.prequeuedStandard`, `state.queue.aliasAction`, `state.combat.pullState`, `state.targeting.calledTargetId`, `state.walk.*`, and `state.gold.*`, then assert they are cleared before the first `send("wake", false)`.

---

### `tests/boop_walk_spec.lua` (test, event-driven)

**Analog:** `tests/boop_tick_spec.lua` and `tests/boop_event_transitions_spec.lua`; current file is a placeholder.

**Current placeholder** (lines 1-3):
```lua
describe("boop walk integration", function()
  -- Walk coverage is intentionally disabled in CI for now.
end)
```

**Tick blocking analog** (`tests/boop_tick_spec.lua` lines 63-69):
```lua
it("does not send attacks while gold commands are pending", function()
  boop.state.gold.getPending = true

  boop.tick()

  assert.stub(send_stub).was_not_called()
end)
```

**Apply to Phase 02:** Replace the placeholder with focused `boop.walk.blockedReason()` and `boop.walk.maybeAdvance()` tests. Stub `raiseEvent` and `tempTimer`; seed `state.walk.active`, `state.walk.roomSettled`, `state.combat.fleeing`, `state.combat.pullState`, `state.targeting.currentTargetId`, and GMCP-missing blockers through owned domains.

---

### `tests/boop_trace_spec.lua` (test, event-driven buffer assertions)

**Analog:** `tests/boop_trace_spec.lua`

**Trace test pattern** (lines 1-45):
```lua
local helper = dofile(os.getenv("TESTS_DIRECTORY") .. "/support/boop_test_helper.lua")

describe("boop trace gmcp events", function()
  before_each(function()
    helper.reset()
    boop.config.traceEnabled = true
  end)

  it("logs room info transitions and room item gmcp events", function()
...
    boop.onRoomItemsRemove()

    local trace = table.concat(boop.state.trace.buffer or {}, "\n")
    assert.is_true(trace:find("gmcp room info:", 1, true) ~= nil)
    assert.is_true(trace:find("| area=Test Area | exits=2 | moved=yes", 1, true) ~= nil)
```

**Apply to Phase 02:** Add blocker enter/exit, target-loss cleanup, flee cleanup, pull holds, GMCP recovery, and retarget decision trace assertions here. Assert normalized owned-state values, not raw GMCP dumps.

---

### `tests/boop_ui_spec.lua` (test, request-response rendering)

**Analog:** `tests/boop_ui_spec.lua`

**UI harness pattern** (lines 21-45):
```lua
before_each(function()
  helper.reset()
  echoes = {}
  echo_stub = stub(boop.util, "echo", function(msg)
    echoes[#echoes + 1] = msg
  end)
  ok_stub = stub(boop.util, "ok", function(msg)
    echoes[#echoes + 1] = "[OK] " .. msg
  end)
  warn_stub = stub(boop.util, "warn", function(msg)
    echoes[#echoes + 1] = "[WARN] " .. msg
  end)
  info_stub = stub(boop.util, "info", function(msg)
    echoes[#echoes + 1] = "[INFO] " .. msg
  end)

  saved_cecho = _G.cecho
  saved_cecho_link = _G.cechoLink
...
  _G.cecho = nil
  _G.cechoLink = nil
```

**Home assertion pattern** (lines 89-110):
```lua
it("shows a compact operations dashboard on bare boop", function()
  helper.setClass("occultist")
  helper.setArea("Test Area")
  helper.setTarget("42", "a vicious gnoll soldier", "100%")
...
  boop.ui.home()

  assert.are.equal("BOOP", echoes[1])
  assert.is_true(echoes[3]:find("State: on | mode: solo | blocker: engaged target | next: let boop attack", 1, true) ~= nil)
```

**Config/status blocker assertion pattern** (lines 232-263):
```lua
boop.ui.config("combat")

local joined = table.concat(echoes, "\n")
assert.is_true(joined:find("CONFIGURATION > Combat", 1, true) ~= nil)
assert.is_true(joined:find("Hunting: ON | rage simple | blocker: engaged target", 1, true) ~= nil)
...
boop.ui.config("targeting")
...
assert.is_true(joined:find("Mode: whitelist | order: order | blocker: ready", 1, true) ~= nil)
```

**Debug assertion pattern** (lines 325-340):
```lua
boop.ui.debug()

local joined = table.concat(echoes, "\n")
assert.are.equal("DEBUG SNAPSHOT", echoes[1])
assert.is_true(joined:find("Runtime: enabled off | mode whitelist | class Unnamable", 1, true) ~= nil)
assert.is_true(joined:find("Flow: blocker boop disabled | next boop on", 1, true) ~= nil)
```

**Apply to Phase 02:** Update expected blocker strings to stable `code -- label` format and add status/dashboard assertions for affected systems and waits-for state. Keep rich/plain rendering test style unchanged.

---

### `tests/boop_runtime_spec.lua` (test, state-contract/effects)

**Analog:** `tests/boop_runtime_spec.lua` and `tests/boop_state_contract_spec.lua`

**Runtime effect pattern** (`tests/boop_runtime_spec.lua` lines 35-59):
```lua
it("returns target and combat effects for the main tick path", function()
  helper.setClass("Occultist")
  helper.setTargetHp("80%")
  helper.setRage(14)
...
  boop.config.enabled = true
  boop.config.targetingMode = "auto"
  boop.config.attackMode = "simple"

  local result = boop.runtime.step({ type = "tick", context = boop.runtime.context() })

  assert.are.equal("target", result.effects[1].kind)
  assert.are.equal("42", result.effects[1].id)
  assert.are.equal("combat_plan", result.effects[2].kind)
```

**Owned-domain contract pattern** (`tests/boop_state_contract_spec.lua` lines 8-27):
```lua
it("initializes owned runtime state domains", function()
  local state = boop.runtime.state()

  assert.are.equal(boop.state, state)
  for _, domain in ipairs({
    "combat",
    "targeting",
    "gold",
    "queue",
    "walk",
    "diag",
    "trace",
    "ui",
    "rage",
    "inventory",
    "ih",
    "gag",
  }) do
    assert.is_table(state[domain], domain .. " domain")
  end
end)
```

**Apply to Phase 02:** Add blocker default/context/effect tests here if the blocker API lives in runtime. Assert no `target`, `combat_plan`, `walk_advance`, `flush_gold`, or prequeue effects are emitted while a blocker affects those systems.

## Shared Patterns

### Owned Runtime Domains
**Source:** `src/scripts/boop/boop_runtime.lua` lines 19-90, 124-140; `tests/boop_state_contract_spec.lua` lines 8-43
**Apply to:** all runtime, event, safety, walk, target, attack, UI, trace, and test-helper changes.

```lua
local state = boop.runtime.ensureState()
local target = state.targeting
local combat = state.combat
```

Do not add compatibility writes like `boop.state.currentTargetId` or `state.walkActive`; use `state.targeting.currentTargetId` and `state.walk.active`.

### Runtime Effects Before Mudlet Side Effects
**Source:** `src/scripts/boop/boop_runtime.lua` lines 253-410
**Apply to:** blocker checks, target loss, flee, walk advancement, gold flushing, and attack execution.

```lua
effects[#effects + 1] = { kind = "flee" }
...
elseif effect.kind == "flee" then
  if boop.safety and boop.safety.flee then
    boop.safety.flee()
  end
```

### Compact Feedback
**Source:** `src/scripts/boop/boop_util.lua` lines 45-84
**Apply to:** blocker warnings, flee cleanup summary, target-loss warning, GMCP recovery warning, pull held warning.

```lua
function boop.util.warn(msg)
  boop.util.feedback("WARN", msg)
end
```

### UI Rows and Plain Fallbacks
**Source:** `src/scripts/boop/boop_ui.lua` lines 710-731, 3614-3676, 4411-4465
**Apply to:** status/dashboard/debug blocker rendering.

```lua
uiPrintRow(row, "Blocker", blocker, blocker == "ready" and "green" or "yellow")
boop.util.echo(string.format("Flow: blocker %s | next %s", blocker, nextAction))
```

### Trace Buffer
**Source:** `src/scripts/boop/boop_util.lua` lines 106-148; `tests/boop_trace_spec.lua` lines 1-45
**Apply to:** blocker transitions, target-loss cleanup, flee cleanup, pull holds, GMCP recovery, retarget decisions.

```lua
boop.trace.log("shield cleared: " .. tostring(reason))
local trace = table.concat(boop.state.trace.buffer or {}, "\n")
```

### Busted/Mudlet Test Harness
**Source:** `tests/support/boop_test_helper.lua` lines 93-166 and `tests/boop_event_transitions_spec.lua` lines 1-20
**Apply to:** all Phase 02 tests.

```lua
local helper = dofile(os.getenv("TESTS_DIRECTORY") .. "/support/boop_test_helper.lua")

before_each(function()
  helper.reset()
  send_stub = stub(_G, "send", function(_, _) end)
end)
```

### State-Drift Gate
**Source:** `tools/check_release_gates.py` lines 29-71, 241-288
**Apply to:** migrated Phase 02 files.

```python
"src/scripts/boop/boop_events.lua": {},
...
if key not in OWNED_STATE_DOMAINS:
    counts[key] += 1
```

Use `{}` for migrated files to keep CI failing on any new flat-state field outside owned domain names.

### Load Order
**Source:** `src/scripts/boop/scripts.json` lines 1-22
**Apply to:** new `boop_trace.lua`.

```json
{"name": "boop_util", "isActive": "yes", "isFolder": "no", "script": ""},
{"name": "boop_trace", "isActive": "yes", "isFolder": "no", "script": ""},
{"name": "boop_theme", "isActive": "yes", "isFolder": "no", "script": ""},
```

## No Analog Found

No Phase 02 surface lacks a usable codebase analog. `src/scripts/boop/boop_trace.lua` is a new file, but its direct source analog is the existing `boop.trace` block in `src/scripts/boop/boop_util.lua` lines 106-148.

## Metadata

**Analog search scope:** `src/scripts/boop/*.lua`, `src/scripts/boop/scripts.json`, `tools/check_release_gates.py`, `tests/*.lua`, `tests/support/*.lua`, `.planning/codebase/*.md`, Phase 01 pattern map.
**Files scanned:** 34 source/test/planning files plus `AGENTS.md`, `CODEX.md`, `README.md`, `DESIGN.md`, and `UIDESIGN.md`.
**Pattern extraction date:** 2026-07-10T23:08:57Z
**Read-only source constraint:** Source, tests, manifests, docs, version fields, built artifacts, git state, commits, and pushes were not modified. Only this planning artifact was written.
