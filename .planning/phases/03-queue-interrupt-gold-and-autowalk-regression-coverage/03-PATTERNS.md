# Phase 03: Queue, Interrupt, Gold, and Autowalk Regression Coverage - Pattern Map

**Mapped:** 2026-07-25
**Files analyzed:** 24 existing files expected to be modified
**Analogs found:** 24 / 24
**Scope:** Existing files only. No new source module, test framework, manifest entry, dependency, or built artifact is needed.

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `src/scripts/boop/boop_runtime.lua` | service/coordinator | event-driven transform | `src/scripts/boop/boop_runtime.lua` | role-match; owner-keyed collection is new |
| `src/scripts/boop/boop_events.lua` | controller/event adapter | event-driven | `src/scripts/boop/boop_events.lua` | exact baseline |
| `src/scripts/boop/boop_walk.lua` | service/integration adapter | event-driven | `src/scripts/boop/boop_walk.lua` | exact baseline |
| `src/scripts/boop/boop_ui.lua` | controller | request-response + event-driven | `src/scripts/boop/boop_ui.lua` | exact baseline |
| `src/scripts/boop/boop_util.lua` | utility/command dispatcher | request-response | `src/scripts/boop/boop_util.lua` | exact baseline |
| `src/scripts/boop/boop_ui_registry.lua` | config/provider | request-response | `src/scripts/boop/boop_ui_registry.lua` | exact baseline |
| `README.md` | config/operator contract | request-response | `README.md` | exact baseline |
| `DESIGN.md` | config/design contract | request-response | `DESIGN.md` | exact baseline |
| `UIDESIGN.md` | config/UI contract | request-response | `UIDESIGN.md` | exact baseline |
| `tests/support/boop_test_helper.lua` | test utility | transform | `tests/support/boop_test_helper.lua` | exact |
| `tests/boop_runtime_spec.lua` | test | event-driven transform | `tests/boop_runtime_spec.lua` | exact |
| `tests/boop_trace_spec.lua` | test | event-driven | `tests/boop_trace_spec.lua` | exact |
| `tests/boop_ui_spec.lua` | test | request-response | `tests/boop_ui_spec.lua` | exact |
| `tests/boop_interrupt_spec.lua` | test | event-driven | `tests/boop_interrupt_spec.lua` | exact |
| `tests/boop_diag_spec.lua` | test | event-driven | `tests/boop_interrupt_spec.lua` | role/data-flow match |
| `tests/boop_diag_timeout_spec.lua` | test | event-driven | `tests/boop_interrupt_spec.lua` | role/data-flow match |
| `tests/boop_pull_spec.lua` | test | event-driven | `tests/boop_pull_spec.lua` | exact |
| `tests/boop_gold_spec.lua` | test | event-driven | `tests/boop_gold_spec.lua` | exact |
| `tests/boop_gold_retry_spec.lua` | test | event-driven | `tests/boop_gold_retry_spec.lua` | exact |
| `tests/boop_walk_spec.lua` | test | event-driven | `tests/boop_walk_spec.lua` | exact |
| `tests/boop_event_transitions_spec.lua` | test | event-driven | `tests/boop_event_transitions_spec.lua` | exact |
| `tests/boop_prequeue_spec.lua` | test | event-driven | `tests/boop_prequeue_spec.lua` | exact |
| `tests/boop_tick_spec.lua` | test | event-driven | `tests/boop_tick_spec.lua` | exact |
| `tests/README.md` | config/test inventory | batch | `tests/README.md` | exact |

All 24 files already exist. The planner should prefer modifications over creating parallel runtime, room-observation, walker, or test-support modules.

## Pattern Assignments

### `src/scripts/boop/boop_runtime.lua` (service/coordinator, event-driven transform)

**Analog:** `src/scripts/boop/boop_runtime.lua`

**Namespace and state-default pattern** (lines 1-2, 19-48, 139-160):

```lua
boop.runtime = boop.runtime or {}

local DOMAIN_DEFAULTS = {
  combat = {
    -- owned runtime fields
  },
  targeting = {
    -- room/target-owned fields
  },
}

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

Copy the global `boop` namespace, `DOMAIN_DEFAULTS`, `deepCopy`, `ensureState()`, and `state()` conventions. Do not add `require` or a second state store.

**Deterministic normalization pattern** (lines 168-209):

```lua
local function sortedKeys(map)
  local keys = {}
  for key, value in pairs(map or {}) do
    if value then
      keys[#keys + 1] = tostring(key)
    end
  end
  table.sort(keys)
  return keys
end

local function normalizeMap(values)
  local out = {}
  -- accepts arrays or maps and normalizes system aliases
  return out
end
```

Reuse `normalizeKey`, `normalizeMap`, `normalizeObserved`, and sorted-key formatting. New blocker snapshots must never depend on Lua table iteration order. Sort by fixed safety priority, then stable code, then owner.

**Current replacement seam** (lines 281-395):

```lua
local function currentBlocker()
  local state = boop.runtime.ensureState()
  state.combat.blocker = state.combat.blocker or deepCopy(DOMAIN_DEFAULTS.combat.blocker)
  return state.combat.blocker
end

function boop.runtime.shouldHold(system)
  local blocker = boop.runtime.blockerSnapshot()
  if blocker.code == "" then
    return false
  end
  return blocker.systems[normalizeKey(system)] == true
end
```

This is the exact API seam to preserve and the storage implementation to replace. Evolve it to an owner-keyed registry while retaining public calls through `setBlocker`, `clearBlocker`, `blockerSnapshot`, and `shouldHold`. `clearBlocker` must release one exact owner, not a code family or the whole registry.

**Coordinator hold-before-effect pattern** (lines 716-740, 839-888):

```lua
if boop.runtime.shouldHold("target")
  or boop.runtime.shouldHold("combat")
  or boop.runtime.shouldHold("queue")
  or boop.runtime.shouldHold("gold")
  or boop.runtime.shouldHold("walk")
then
  effects[#effects + 1] = heldEffect(context, "automation", "tick")
  return { effects = effects, didAction = false }
end
```

Keep decisions in `step()` and Mudlet side effects in `applyEffects()`. Update `context()` to carry immutable primary/all blocker and room-observation snapshots. Remove direct `state.diag.hold` gating only after interrupt-owned blockers cover the same contract.

**Required new owned fields:** use `state.combat` for blocker registry and interrupt/pull operations, `state.targeting` for shared room observation, `state.gold` for staged gold operation, and `state.walk` for walk generation/reservation. Do not put shared room truth under walk or gold.

---

### `src/scripts/boop/boop_events.lua` (controller/event adapter, event-driven)

**Analog:** `src/scripts/boop/boop_events.lua`

**Boundary-side-effect pattern** (lines 33-38):

```lua
local GOLD_READY_QUEUE = "freestand"

local function queueGoldCommand(command)
  send("queue add " .. GOLD_READY_QUEUE .. " " .. command, false)
end
```

Keep outbound Achaea commands in small boundary helpers and retain `false` as the `send()` echo argument. The caller must prove generation, owner, room, evidence, phase, and blockers before invoking this helper.

**Hold and trace pattern** (lines 106-135, 503-515):

```lua
local function shouldHold(system)
  return runtime() and boop.runtime.shouldHold and boop.runtime.shouldHold(system)
end

if shouldHold("gold") then
  traceHeld("gold", reason or "pending age exceeded")
  return false
end
```

Preserve the centralized runtime guard and compact trace path. Initial pickup, retries, timeout callbacks, post-pickup packing, and walk reevaluation must all use it.

**Current gold lifecycle seam to replace** (lines 415-483, 597-663):

```lua
function boop.markGoldQueueIntent(pack)
  boop.state.gold.getPending = true
  boop.state.gold.putPending = target ~= ""
  armGoldPendingTimeout()
end

local function queueGoldCommands()
  local pack = boop.util.trim(boop.config.goldPack or "")
  boop.markGoldQueueIntent(pack)
  queueGoldCommand("get sovereigns")
  if pack ~= "" then
    queueGoldCommand("put sovereigns in " .. pack)
  end
end
```

Keep the public trigger entry points (`onGoldDropLine`, `onGoldGetSuccess`, `onGoldPutSuccess`, `onGoldCommandFailure`) but replace simultaneous get/put booleans with:

1. provisional/deferred room detection;
2. `pickup_pending` owned by room ID + room generation;
3. confirmed pickup transfer to inventory-owned `pack_pending`;
4. one terminal function per generation.

Room changes cancel only provisional/acquisition stages. Inventory-owned packing survives room changes. Duplicate same-room signals coalesce.

**Shared room-list observation pattern** (lines 742-774):

```lua
function boop.onRoomItemsList()
  if gmcp.Char.Items.List.location ~= "room" then return end
  local items = gmcp.Char.Items.List.items
  if type(items) ~= "table" then
    enterRoomBlocker("room_partial", "partial room state", {
      room = tostring(gmcp.Room and gmcp.Room.Info and gmcp.Room.Info.num or ""),
      items = false,
    })
    return
  end
  noteRoomGmcpObserved()
  boop.targets.updateRoomItems(items)
end
```

Copy the strict `location == "room"` and `type(items) == "table"` guards. Extend this handler to stamp complete item evidence against the current room-observation generation before gold or walk may act.

**Room transition ordering pattern** (lines 908-1004):

`boop.onRoomInfo()` currently computes `previousRoom`, detects movement, clears stale domains, calls `boop.walk.onRoomChange()`, then updates `targeting.room`. Preserve explicit transition ordering, but start/reset the shared room observation before consumers can evaluate it. Replace broad `clearGoldQueueIntent()` with room-stage invalidation only.

**External event registration pattern** (lines 694-725):

```lua
local function add(event, fn)
  local id = registerAnonymousEventHandler(event, fn)
  boop.handlers[#boop.handlers + 1] = id
end

add("gmcp.Char.Items.List", "boop.onRoomItemsList")
add("gmcp.Room.Info", "boop.onRoomInfo")
add("demonwalker.arrived", "boop.onWalkArrived")
add("demonwalker.finished", "boop.onWalkFinished")
```

Preserve string-named handler registration and prior-handler cleanup. Do not absorb route selection or add a new event bus.

---

### `src/scripts/boop/boop_walk.lua` (service/integration adapter, event-driven)

**Analog:** `src/scripts/boop/boop_walk.lua`

**External availability/attachment pattern** (lines 122-129):

```lua
local function available()
  return type(demonwalker) == "table"
    and type(demonwalker.init) == "function"
end

local function attached()
  return type(demonwalker) == "table" and demonwalker.enabled and true or false
end
```

Retain explicit optional-package checks. Recheck availability immediately before every move/stop side effect. Missing integration must fail closed and must never invoke install or update implicitly.

**Existing all-clear inventory** (lines 131-179):

```lua
if not walk.roomSettled then return "room has not settled yet" end
if walk.moveQueued then return "move already queued" end
if runtimeWalkBlocker() then return runtimeWalkBlocker() end
if diag.hold then return "diag pause is active" end
if combat.fleeing then return "flee is active" end
if goldPending(gold) then return "loot handling is still pending" end
if currentTargetId(targeting) ~= "" then return "current target still set" end
```

Use this as the behavioral blocker inventory, not as the final architecture. Replace it with one side-effect-free evaluator over an immutable runtime/room snapshot. Return a stable reason code plus short label; both automatic and manual move paths must call the same evaluator.

**Owned-vs-attached start pattern** (lines 253-288):

```lua
walk.active = true
walk.owned = not attached()

if walk.owned then
  local ok, err = pcall(function()
    demonwalker:init(options or {})
  end)
  if not ok then
    resetRuntimeFlags()
    boop.util.err("walk start failed: " .. tostring(err))
    return false
  end
else
  boop.util.ok("walk attached to current demonwalker run")
end
```

Preserve ownership detection and `pcall` error handling. A fresh start/attach must increment a walk generation and clear all old room, settlement, refresh, blocker, and reservation observations.

**Current move seam to harden** (lines 335-354):

```lua
walk.moveQueued = true
walk.roomSettled = false
tempTimer(0, function()
  local liveWalk = walkState()
  if not liveWalk.active then
    return
  end
  if raiseEvent then
    raiseEvent("demonwalker.move")
  end
end)
```

Keep one deferred emitter, but make it capture and compare walk generation, room generation, and move reservation. Re-evaluate all-clear and package availability in the callback. A stale callback must not mutate live state or emit.

**Stop integration contract** (current seam lines 291-299):

Invalidate generation and queued reservation before any external call. If the captured run was boop-owned, emit exactly `raiseEvent("demonwalker.stop")`; if attached, only detach boop. Emit distinct compact confirmations. The existing `silent` calling convention should remain compatible.

**Install error pattern** (lines 189-218):

Keep explicit operator-triggered installation and `pcall`, but inspect both `pcall` success and `installPackage()`'s returned success/error values. Status/start/move/mid-run package loss must not call `installPackage()`.

---

### `src/scripts/boop/boop_ui.lua` (controller, request-response + event-driven)

**Analog:** `src/scripts/boop/boop_ui.lua`

**Stable blocker rendering pattern** (lines 339-391, 441-461):

```lua
local function blockerKeyText(map)
  local keys = sortedEnabledKeys(map)
  if #keys == 0 then return "none" end
  return table.concat(keys, ", ")
end

local text = normalizedCode .. " -- " .. normalizedLabel

blockerDetailText = function(details)
  local parts = {}
  if details.systemsText ~= "none" then
    parts[#parts + 1] = "systems: " .. details.systemsText
  end
  if details.waitsText ~= "none" then
    parts[#parts + 1] = "waits: " .. details.waitsText
  end
  return table.concat(parts, " | ")
end
```

Retain `code -- label`, sorted systems/waits, and deterministic plain text. Normal status/dashboard rows should render the runtime-selected primary blocker plus `+N more`; trace/debug should iterate the full sorted blocker snapshot with owner and affected systems. Remove ad hoc fallback blockers once their owned runtime equivalents exist.

**Interrupt command seam** (lines 1248-1287):

```lua
local function queueInterrupt(label, command, opts)
  -- clear prequeue, create hold, schedule timeout, then send
  boop.state.diag.timeoutTimer = tempTimer(timeout, function()
    if boop.state.diag.hold then
      -- broad release today
    end
  end)
  send("queue addclearfull freestand " .. command, false)
end
```

Preserve the shared command helper and operation-specific `awaitPrompt` configuration. Replace broad booleans with one generation-owned interrupt operation and one compare-and-terminal release function. Repeating the same request while pending must not resend or replace its timer; a different interrupt must not steal the lane.

**Pull ownership seam** (lines 1388-1448, 1553-1624):

`clearPullState`, `armPullTimeout`, and `pullCommand` are the exact lifecycle boundary. Preserve current validation and command construction. Replace `boop.ui.setEnabled(false/true)` with a runtime pull blocker so `config.enabled` and `boop.db.saveConfig("enabled", ...)` remain untouched. Capture pull generation in timeout and room-return callbacks.

**Walk routing pattern** (lines 1820-1860):

```lua
if cmd == "start" then boop.walk.start() end
if cmd == "stop" then boop.walk.stop(false, false) end
if cmd == "move" then boop.walk.move() end
if cmd == "install" then boop.walk.install() end
```

Keep UI routing thin. Safety, ownership, generation, and event emission remain in `boop_walk.lua`.

---

### `src/scripts/boop/boop_util.lua` (utility/command dispatcher, request-response)

**Analog:** `src/scripts/boop/boop_util.lua`

**Feedback pattern** (lines 45-85):

```lua
local FEEDBACK_STYLE = {
  INFO = { ... },
  OK = { ... },
  WARN = { ... },
  ERR = { ... },
}

function boop.util.warn(msg)
  boop.util.feedback("WARN", msg)
end
```

All new operator output must use `boop.util.info/ok/warn/err`; do not print raw or introduce another style.

**Trace pattern** (lines 106-124):

```lua
function boop.trace.log(msg)
  if not boop.config or not boop.config.traceEnabled then return end
  local line = string.format("%s | %s", os.date("%H:%M:%S"), tostring(msg))
  local buf = boop.state.trace.buffer
  buf[#buf + 1] = line
  while #buf > 100 do
    table.remove(buf, 1)
  end
end
```

Preserve bounded, transition-oriented trace output. Add owner/generation/room details to lifecycle transitions, not noisy per-tick dumps.

**Gold chaining seam to remove** (lines 198-227):

```lua
if boop.config.useQueueing and boop.state.gold.autoGrabPending then
  local prefix = "get sovereigns"
  if pack ~= "" then
    prefix = prefix .. "/put sovereigns in " .. pack
  end
  queuedAction = prefix .. "/" .. queuedAction
end
```

Delete this chaining behavior. `executeAction()` should respect aggregate combat/queue/gold holds and dispatch only the combat action it was given. Gold acquisition and packing are independently staged in `boop_events.lua`.

---

### `src/scripts/boop/boop_ui_registry.lua` (config/provider, request-response)

**Analog:** `src/scripts/boop/boop_ui_registry.lua`

Keep help content as ordered data returned by `helpCommand()` (lines 595-600) and attached through `boop.registry.attachUiConfigRegistries()` (lines 1195-1233). Update only stale behavior statements:

- interrupt timeout copy at lines 778-807;
- gold queue/chaining copy at lines 810-834;
- walker start/stop/install copy at lines 837-877.

Preserve workflow-first topic shape: summary, steps, commands, advanced, notes. Do not add a parallel help renderer.

---

### Operator documentation files

#### `README.md`

**Analog:** `README.md`

Update the existing contracts at:

- line 18: status blocker wording;
- lines 26-27 and 84-85: walk start/stop/move/install semantics;
- lines 86-91: gold pickup/pack/retry ordering;
- lines 99-106: interrupt and pull completion/timeout semantics;
- line 118: cross-surface blocker wording.

Replace the old “pickup is prepended to the next queued standard attack” statement with staged get-confirm-put behavior. Describe owned stop versus attached detach and primary blocker plus `+N more`. Keep command grammar unchanged.

#### `DESIGN.md`

**Analog:** `DESIGN.md`

Update current implementation notes at lines 103-115 and 126. Preserve the high-level architecture and external route-ownership boundary. The new text should describe shared room evidence, two-stage gold ownership, operation-owned interrupt/pull holds, and boop's safety-only walker role.

#### `UIDESIGN.md`

**Analog:** `UIDESIGN.md`

Extend line 27's stable blocker contract: normal surfaces show `primary_code -- label | +N more`; trace/debug show every sorted owner/blocker and affected systems. Preserve deterministic plain-text fallback (line 125) and compact operator clarity (line 224).

---

### `tests/support/boop_test_helper.lua` (test utility, transform)

**Analog:** `tests/support/boop_test_helper.lua`

**Reset and fixture pattern** (lines 93-166):

```lua
function M.reset()
  helper.resetDb()
  gmcp = { ... }
  boop.config = {}
  resetTableData(boop.state)
  boop.state.init()
  -- reset public tables and reattach registries
  return boop
end
```

Keep one full reset per test and owned-domain fixture writes. Extend the helper with:

- deterministic blocker owner seeding;
- deterministic operation generations;
- `Room.Info` + complete room-list observation cycle helpers;
- callback queue capture returning stable IDs;
- walker available/missing/owned/attached stubs;
- `installPackage` success, return-failure, and throw stubs.

Replace `setRuntimeBlocker()`'s direct single-record assignment (lines 225-234) with public owner-aware runtime APIs. Extend `seedAutomationIntent()` (lines 236-265) to seed generations/reservations without restoring removed flat state.

## Test File Assignments

Each spec keeps the repository pattern:

```lua
local helper = dofile(os.getenv("TESTS_DIRECTORY") .. "/support/boop_test_helper.lua")

describe("...", function()
  before_each(function()
    helper.reset()
    -- stub Mudlet boundaries
  end)

  after_each(function()
    -- revert every stub / restore every global
  end)
end)
```

| File | Analog and exact lines/symbols to copy | Required Phase 03 extension |
|---|---|---|
| `tests/boop_runtime_spec.lua` | self lines 31-64 (`runtime.state`, `blockerSnapshot`) and 104-156 (`shouldHold` across systems) | Seed 2+ owners, assert per-system all-clear, exact-owner release, fixed primary priority, immutable sorted all-blocker snapshot. |
| `tests/boop_trace_spec.lua` | self lines 65-113 (`blocker enter/exit` exact text) | Assert all owners appear in stable priority order; releasing one emits one owner-specific exit and preserves other entries. |
| `tests/boop_ui_spec.lua` | self lines 21-54 (`seedCanonicalBlocker`, cross-surface helper) and 537-561 (all surfaces) | Reuse one rendering helper; assert normal primary + `+N more`, trace/debug full list, sorted systems/waits, exact plain text. |
| `tests/boop_interrupt_spec.lua` | self lines 24-31 (capture timeout callback), 41-69 (send/prompt/timeout assertions) | Capture all callbacks, test same/different repeat idempotency, both terminal orders, one release/output/tick, unrelated blocker retention, and no attack/prequeue while another owner remains. |
| `tests/boop_diag_spec.lua` | `tests/boop_interrupt_spec.lua` lines 24-31, 41-69; self lines 44-69 | Keep diagnose line + prompt as its operation-specific completion evidence; add success→timeout and timeout→line/prompt orderings. |
| `tests/boop_diag_timeout_spec.lua` | `tests/boop_interrupt_spec.lua` lines 24-31, 57-70 | Assert timeout releases only diag's owner, does not clear another blocker, and late prompt/success is a no-op. |
| `tests/boop_pull_spec.lua` | self lines 13-16, 24-39, 93-109, 156-209 | Assert config/save state never changes; capture generations; test return→timeout and timeout-away→return; invoke an old callback after a new pull and prove it cannot clear current state. |
| `tests/boop_gold_spec.lua` | self lines 9-21 (ordered callback array), 51-80 (held detection), 82-121 (item/target callback ordering) | Replace chained expectations with get-only, confirmed get, put-only, terminal, then reevaluation. Add stable-room evidence, duplicate coalescing, room-change-before-success, and success-before-room-change cases. |
| `tests/boop_gold_retry_spec.lua` | self lines 11-22 and 47-91 | Capture every retry/timeout callback; assert old generation and wrong-room callbacks make zero sends and do not mutate the current operation; inventory pack retry may survive movement. |
| `tests/boop_walk_spec.lua` | self lines 9-38 (state/event helpers), 40-67 (external globals), 69-148 (table-driven blockers) | Keep table-driven blocker coverage and add start/attach, stop/detach, explicit install outcomes, shared auto/manual gate, one refresh, one move per room, stopped/restarted generations, package loss, and exact event counts. |
| `tests/boop_event_transitions_spec.lua` | self lines 14-58 (captured timer + Mudlet stubs), 243-279 (explicit deferred callback), 410-462 (gold/room transition baseline) | Add `Room.Info`/List/Add/text/gold/walk interleavings. Retain target-removal queue-drift test. Assert room observations and old callbacks cannot authorize new-room work. |
| `tests/boop_prequeue_spec.lua` | self lines 12-38, 65-83, 115-124 | Assert interrupt/pull/gold owner holds suppress scheduling and already-captured callbacks; clearing one owner does not prequeue while another affects queue/combat. |
| `tests/boop_tick_spec.lua` | self lines 9-34 and 55-69 | Add overlapping holds and staged-gold tests proving zero attack sends until all affecting owners clear. |
| `tests/README.md` | self lines 19-22, 33-56, 67-76 | Update coverage descriptions after tests exist; add walk lifecycle, race ordering, owner-keyed blockers, shared room observations, and staged gold ownership. |

## Shared Test Patterns

### Capture callbacks as an ordered queue

**Source:** `tests/boop_gold_spec.lua` lines 9-19
**Apply to:** interrupt, diag, pull, gold, walk, event-transition tests

```lua
scheduled = {}
timer_stub = stub(_G, "tempTimer", function(_, callback)
  scheduled[#scheduled + 1] = callback
  return #scheduled
end)
```

Do not keep only a `last_callback` when testing races. Store callback identity and invoke both terminal orderings explicitly. Assert the captured generation/owner after each invocation.

### Capture side effects to assert exact count and order

**Source:** `tests/boop_whitelist_share_spec.lua` lines 12-28
**Apply to:** gold command ordering and walker event ordering

```lua
local sent = {}
local send_stub = stub(_G, "send", function(command, echoBack)
  sent[#sent + 1] = { command = command, echoBack = echoBack }
end)

assert.are.equal(3, #sent)
assert.are.equal(expected, sent[2].command)
```

Use an ordered `sent`/`raisedEvents` array in addition to `assert.stub(...).was_called_with(...)`. Required gold order is get only → success → put only → pack terminal → combat/walk reevaluation.

### Prove cleanup/authorization precedes the first side effect

**Source:** `tests/boop_safety_spec.lua` lines 21-50, 102-123
**Apply to:** interrupt release, pull timeout, gold queueing, walk emission

```lua
send_stub = stub(_G, "send", function(_, _)
  if not first_send_snapshot then
    first_send_snapshot = automation_intent_snapshot()
  end
end)
```

At the first `send()` or `raiseEvent()`, snapshot live owner, generation, room observation, reservation, and blocker state. This proves ordering, rather than checking only final booleans.

### Preserve event-capture shape

**Source:** `tests/boop_walk_spec.lua` lines 44-57

```lua
_G.raiseEvent = function(name, ...)
  raised_events[#raised_events + 1] = {
    name = name,
    args = { ... },
  }
end
```

Assert exact counts for `demonwalker.move` and `demonwalker.stop`. Do not assert or emit the nonexistent `boop.walk.move` event.

### Preserve target-removal queue-drift regression

**Source:** `tests/boop_event_transitions_spec.lua` lines 243-279

The existing test proves target removal does not `queue clear`, then executes the captured callback and expects the new target alias. Keep this test intact while adding walk/gold interleavings around it.

## Shared Runtime Patterns

### Ownership identity

- Blocker code is presentation; owner key + generation is identity.
- Clear by exact owner/generation.
- Timer cancellation is cleanup only. Callback compare-and-terminal logic enforces correctness.
- First terminal signal changes state and emits output once; later callbacks return without mutation, sends, events, warnings, or ticks.

### Shared room observation

- `state.targeting` owns `roomId`, room generation, `infoSeen`, complete `itemsSeen`, refresh-attempt state, and observed item evidence.
- New `Room.Info` invalidates prior item evidence and increments generation.
- Only a complete room `Char.Items.List` observed in the current cycle can settle the room.
- Prompt and timer events never set settlement true.
- Missing items may issue exactly one `sendGMCP([[Char.Items.Room]])` refresh for the room cycle; continued absence warns/traces and remains held.

### Gold ownership transfer

- Provisional and pickup phases are room-owned.
- Only confirmed get success creates inventory-owned packing.
- Room changes invalidate room-owned pickup/retry/timeout callbacks.
- Room changes do not invalidate confirmed inventory-owned pack work.
- Same-room duplicate text/Add/List signals do not send or queue another get.

### Walker boundary

- boop owns safety, run generation, room-cycle reservation, and custom-event timing.
- `demonnicAutoWalker` owns route selection and physical movement.
- One guarded path emits `raiseEvent("demonwalker.move")`.
- boop-owned stop emits `raiseEvent("demonwalker.stop")`; attached stop detaches only.
- Install is explicit. Status/start/move/failure paths never install or update.

### Status, warnings, and trace

**Sources:** `src/scripts/boop/boop_util.lua` lines 45-85, 106-124; `src/scripts/boop/boop_ui.lua` lines 339-461

- Use `[OK]`, `[INFO]`, `[WARN]`, and `[ERR]` through utility functions.
- Normal output is transition-oriented and compact.
- Normal status uses stable `primary_code -- short label | +N more`.
- Trace/debug lists every active blocker with exact owner, generation where relevant, affected systems, waits-for state, and terminal/room evidence.
- Sort output deterministically; never expose raw `pairs()` order.

## Integration Order the Planner Should Preserve

1. Runtime blocker registry, room-observation defaults/helpers, and test-helper fixtures.
2. Runtime/trace/UI multi-owner tests and compact primary/all rendering.
3. Interrupt and pull generation-owned operations and callback-order tests.
4. Shared room event stamping and staged gold ownership; remove utility gold chaining.
5. Walker generation, shared evaluator/emitter, settlement refresh, and ownership-aware stop.
6. Cross-lifecycle event tests, prequeue/tick assertions, help/docs, and test inventory.

Do not parallelize plans that independently edit `boop_runtime.lua`, `boop_events.lua`, or shared helper state. Gold and walk must consume one room-observation contract.

## No Exact Behavioral Analog Found

All target files have structural analogs because they already exist, but these required mechanisms have no current in-repository implementation to copy verbatim:

| Required Pattern | Files | Planner Guidance |
|---|---|---|
| Owner-keyed multi-blocker registry with fixed primary priority | `boop_runtime.lua`, runtime/trace/UI specs | Extend existing normalization/snapshot APIs; use `03-RESEARCH.md` Pattern 1 for semantics. |
| Generation-owned first-terminal-wins operation | UI/events/walk and timing specs | Preserve existing timer/stub shapes; add captured generation + terminal compare before mutation. |
| Two-stage room/inventory gold ownership | events/util and gold specs | Preserve queue boundary helpers; replace simultaneous get/put and attack chaining. |
| Same-cycle `Room.Info` + complete room-list settlement | runtime/events/walk and event/walk specs | Store shared observation under targeting; one capped GMCP refresh; fail closed. |

## Metadata

**Analog search scope:** `src/scripts/boop/`, `tests/`, root operator/design docs, Phase 02 context, and `.planning/codebase/` architecture/testing guidance
**Files scanned for direct analogs:** 26 source/test/doc files (24 targets plus `tests/boop_safety_spec.lua` and `tests/boop_whitelist_share_spec.lua`)
**Pattern extraction date:** 2026-07-25
**Excluded:** built artifacts, manifests (no new package file), version fields, git history, and deferred Phase 04/05/06 feature work
