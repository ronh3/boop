# Architecture Research: boop Hunter Pre-1.0 Hardening

**Project:** boop Hunter
**Domain:** Standalone Mudlet package for Achaea hunting/bashing
**Researched:** 2026-07-09
**Mode:** Architecture dimension
**Overall confidence:** HIGH for local architecture from repo maps/current code; MEDIUM for external Mudlet/GMCP runtime constraints

## Executive Summary

boop should stay a manifest-loaded Mudlet package built around the existing global `boop` namespace, thin aliases/triggers, owned runtime state domains, domain modules, and a runtime coordinator that emits effects before applying Mudlet side effects. This is already the right architecture for pre-1.0 hardening because it matches Mudlet's event-driven model, keeps source under `src/`, and lets risky gameplay behavior be tested through domain functions instead of scattered Mudlet object scripts.

The next milestone should not introduce a broad rewrite, `require`-based module system, new framework dependency, or bundled walker. The architecture problem is not shape; it is ownership consistency at integration boundaries. Current maps and code inspection show the intended domains in `boop.runtime.ensureState()`, but some room, inventory, pull, and walk paths still read or write flat state fields. That drift is the root dependency for autowalk regressions, pull return detection, flee direction recovery, gold/diag blockers, and release confidence.

The safe build sequence is: add low-risk release gates, lock state-domain expectations with tests, migrate remaining flat state users to owned domains, then harden autowalk and gag summarization against those stable contracts. Command-fragment validation should be added as a shared utility and used before values are persisted or sent. Gag summarization work should be fixture-first because its timers and pending-line state are intentionally compact but timing-sensitive.

## Recommended Architecture

```text
Mudlet package manifests
  mfile, src/scripts/**/scripts.json, src/aliases/**/aliases.json,
  src/triggers/**/triggers.json
        |
        v
Thin Mudlet adapters
  aliases: user commands -> boop.ui/domain calls
  triggers: game text/prompt -> boop.gag/rage/targets/events calls
  GMCP handlers: registerAnonymousEventHandler -> boop.on*
        |
        v
Runtime state and coordinator
  boop.runtime.ensureState()
  boop.runtime.context()
  boop.runtime.step()
  boop.runtime.applyEffects()
        |
        v
Domain modules
  targets, attacks, rage, safety, stats, gag, walk, db, skills, ih, ui
        |
        v
Mudlet/Achaea/external effects
  send(), sendGMCP(), queue add freestand, tempTimer(), raiseEvent(),
  Mudlet DB, gmcp.*, demonnicAutoWalker
```

The package should continue to use one shared `boop` namespace and manifest order instead of Lua `require`. Mudlet runs package scripts in a Lua 5.1 environment, and its aliases/triggers expose globals such as `command`, `line`, and `matches`; the existing adapter pattern fits that runtime and remains testable when behavior stays in `src/scripts/boop/*.lua`.

## Component Boundaries

| Component | Responsibility | Owns | Communicates With |
|-----------|----------------|------|-------------------|
| Package/load manifests | Muddler object membership and script load order. | `mfile`, `src/**/scripts.json`, `aliases.json`, `triggers.json` | CI build, Mudlet package import |
| Bootstrap | Create `boop`, defaults, version, trigger sync, DB/state init, GMCP support requests, event registration. | `boop_init.lua`, `boop_bootstrap.lua` | DB, runtime, skills, events, stats, triggers |
| Runtime state | Canonical volatile state domains. | `boop.state.combat`, `targeting`, `gold`, `queue`, `walk`, `diag`, `trace`, `ui`, `rage`, `inventory`, `ih`, `gag` | Every domain module |
| Runtime coordinator | Convert prompt/tick context into effects and apply them through domain APIs. | `boop.runtime.context/step/applyEffects` | targets, attacks, safety, walk, gag, trace |
| Event adapters | Translate GMCP, connection, walker, prompt, inventory, room, gold, and target events into domain state updates. | `boop_events.lua` callback surface | runtime, targets, gold, stats, walk, skills |
| Targeting | Denizen list, current target id/name/shield, priority lists, party calls, whitelist sharing. | `boop.state.targeting`, `boop.lists`, DB list helpers | GMCP room/item/target events, attacks, UI |
| Combat planner/executor | Class profile selection, standard/rage planning, queue/direct send execution. | `boop.attacks.registry`, planner contracts | runtime, rage, skills, inventory, targets |
| Gag summarizer | Attack/kill/mob summary state, suppression, prompt flush, stats hooks, gag colors. | `boop.state.gag`, gag config keys | text triggers, prompt effect, stats, UI |
| Walker adapter | Optional demonnicAutoWalker integration and room-clear advance decisions. | `boop.state.walk` only | runtime `walk_advance`, GMCP room/items, external walker events |
| Safety/interruption | Flee threshold, diag/matic/fly/leap/ts holds, pull lifecycle. | `boop.state.combat`, `boop.state.diag`, queue state | UI commands, runtime, GMCP room info |
| Persistence | Mudlet DB schema and load/save helpers for config, lists, tags, stats. | `boop_db.lua` DB sheets | bootstrap, UI, targets, stats |
| UI/commands | Operator dashboards, command handlers, config/help registries. | UI routes and registry metadata | aliases, domain APIs, persistence |
| Tests/CI | Busted in Mudlet, manifest/version gates, high-risk regression fixtures. | `tests/`, `.github/workflows/main.yml` | build, source manifests, package runtime |

## Canonical Data Flow

### Hunting Tick

1. GMCP vitals, prompt, target, room, or timer paths call `boop.tick()` or `boop.onPrompt()`.
2. `boop.runtime.context()` snapshots `boop.state`, `boop.config`, GMCP room/target/vitals, queue, gold, diag, inventory, and rage.
3. `boop.runtime.step()` decides effects: trace, flush gold, walk advance, flee, set target, execute combat plan, complete diag, flush gag prompt.
4. `boop.runtime.applyEffects()` is the side-effect boundary. It calls `boop.targets.setTarget`, `boop.attacks.execute`, `boop.safety.flee`, `boop.walk.maybeAdvance`, `boop.gag.onPrompt`, or `boop.flushPendingGold`.
5. Domain modules perform Mudlet effects through guarded APIs such as `send`, `sendGMCP`, `tempTimer`, `queue add freestand`, `raiseEvent`, and DB helpers.

Architectural implication: new high-risk behavior should enter through context/effects when it affects hunting decisions. Avoid direct sends from event handlers unless the handler is explicitly an adapter for a game line or UI command.

### Room, Target, Gold, and Walk

1. `gmcp.Room.Info` updates `boop.state.targeting.room`, movement flags, last room, and return direction.
2. `gmcp.Char.Items.List/Add/Remove/Update` updates room denizens, inventory/wield state, gold state, and room-settled state.
3. Target GMCP updates apply through `boop.targets.applyTarget` so current id/name/shield stay centralized.
4. Gold pickup sets `boop.state.gold.*` and blocks combat/walk until success, failure, or stale timeout clears it.
5. When runtime sees no valid target, it emits `walk_advance`; the walker adapter checks blockers and raises `demonwalker.move` only when room state is settled and clear.

Architectural implication: walk cannot be safely fixed until state ownership is repaired. `boop_walk.lua` should read `state.walk.*`, `state.diag.*`, `state.combat.fleeing`, `state.gold.*`, and `state.targeting.currentTargetId`, not flat `state.walkActive`, `state.diagHold`, `state.fleeing`, `state.goldGetPending`, or `state.currentTargetId`.

### Gag Summaries

1. Class/category gag triggers stay thin and call `boop.gag.onAttackLine()` or focused domain handlers.
2. `boop.gag` stores pending self attack, kill, mob attack, duplicate suppression, and timer state in `boop.state.gag`.
3. Short timers and prompt flush merge related game lines into compact summaries while preserving damage, crits, slain/XP, and unusual failures.
4. Stats hooks consume the summarized events, but source line matching remains under gag trigger fixtures.

Architectural implication: gag changes should be fixture-first. Do not tune timers, delete-line behavior, merge ordering, or trigger breadth without replay cases in `tests/boop_gag_spec.lua` from live combat lines.

### Command Validation

1. Aliases remain thin and pass parsed text to `boop.ui.*`.
2. UI/config handlers normalize and validate user-controlled command fragments before saving config or sending commands.
3. A shared validator should live in `boop_util.lua` or a small `boop_validation.lua` loaded before UI/events. It should be called by registry setters and command handlers.
4. Invalid values should leave state unchanged and use `[ERR]`/`[WARN]` feedback.

Architectural implication: validation belongs below UI but above persistence/effects. Do not bury validation in each send path only; persisted unsafe values are the problem.

## Integration Points

| Integration | Current Role | Boundary Rule | Hardening Need |
|-------------|--------------|---------------|----------------|
| GMCP `Char.Items.*` | Room denizens, gold, inventory/wield tracking. | Event handler mutates owned state and delegates to targets/gold/inventory helpers. | Ensure inventory writes use `state.inventory.*`, not flat wield fields. |
| GMCP `Room.Info` | Room id/area/exits, moved-room detection, pull return, walk room-change hooks. | Update `state.targeting.*` and `state.combat.pullState`; clear target/gold/shield via domain APIs. | Repair flat `vars.room`, `vars.pullState`, `vars.fleeing` paths. |
| GMCP `IRE.Target.*` | Target id/name/hp percent. | Apply through `boop.targets.applyTarget`. | Keep target id as denizen id; do not fall back to name targeting. |
| GMCP `Char.Vitals` / `Char.Skills.*` | Rage amount, class/spec, skill gates. | Skills module owns requests/cache; runtime context reads observed values. | Keep support re-request guarded on reconnect/missing modules. |
| Mudlet trigger engine | Game text, prompt, gag, rage, shield, gold, diag lines. | Trigger scripts are adapters only. | Add manifest parity tests before expanding coverage. |
| Mudlet event engine | GMCP and walker events. | Register/kill anonymous handlers centrally in `boop.events.register()`. | Keep handler IDs tracked and avoid duplicate registration on reload. |
| `tempTimer()` | Recovery timers, gag flush, gold stale clear, prequeue, walk settle fallback. | Store timer IDs in owned domain state and kill before replacing. | Tests should assert timers clear state and do not resurrect stale work. |
| `raiseEvent("demonwalker.move")` | Tells demonnicAutoWalker to move. | Only walker adapter raises it after blocker checks. | Contract-test move emission and blocker reasons. |
| `installPackage()` | Optional `boop walk install`. | Guard API existence and expose exact URL. | Prefer pinned/trusted release URL before 1.0 if release security is in scope. |
| Mudlet DB | Config, lists, tags, stats. | Only `boop_db.lua` uses raw DB APIs. | Avoid schema churn before 1.0 except validation metadata if required. |
| Muddler manifests | Package membership/load order. | Do not auto-sort `src/scripts/boop/scripts.json`; do test membership. | Add CI manifest parity gate. |

## Build-Order Implications

### 1. Add Low-Risk Release Gates First

Add CI checks for synchronized version fields and manifest parity before broad hardening edits. These are cheap, low-behavior-risk gates that protect the rest of the milestone:

- `mfile.version`, `mfile.title`, and `boop.version` must match.
- Every script/alias/trigger manifest entry must resolve to a source file.
- Every source alias/trigger Lua file under packaged folders should be reachable from a manifest.
- `src/scripts/boop/scripts.json` should be exempt from sort normalization but checked for required order anchors.

This work does not change gameplay behavior and gives the milestone earlier release confidence.

### 2. Lock State Ownership With Tests

Before migrating code, add focused tests that make the desired contracts explicit:

- `boop.runtime.ensureState()` owns all volatile domains.
- `boop.onRoomInfo()` updates `state.targeting.room`, `lastRoom`, `lastRoomDir`, and `movedRooms`.
- Pull lifecycle reads/writes `state.combat.pullState`.
- Walker blockers read `state.walk`, `state.diag`, `state.combat`, `state.gold`, and `state.targeting`.
- Inventory/wield helpers read/write `state.inventory.wieldedLeft` and `state.inventory.wieldedRight`.
- No runtime path needs old flat compatibility keys after migration.

This phase should not add feature behavior. It should make existing behavior observable.

### 3. Migrate Remaining Flat State Integration Paths

Repair the event and walker adapters against the tests:

- Move room fields from `boop.state.room`/`lastRoom`/`lastRoomDir`/`movedRooms` to `boop.state.targeting.*`.
- Move pull completion from `boop.state.pullState` to `boop.state.combat.pullState`.
- Move flee/movement flags from flat fields to `boop.state.combat.fleeing` and `boop.state.walk.*`.
- Move wield tracking from flat `boop.state.wieldedLeft/right` to `boop.state.inventory.wieldedLeft/right`.
- Keep gold, diag, queue, target, trace, and gag state inside existing owned domains.

Do not introduce a legacy bridge unless a live regression proves external compatibility is required. A bridge would hide drift and weaken the release-hardening goal.

### 4. Harden Autowalk After State Is Stable

Convert `tests/boop_walk_spec.lua` from the disabled placeholder into a real contract suite:

- start/stop status and owned/attached mode.
- missing walker package behavior.
- room-settled fallback from arrival and room change.
- `demonwalker.arrived` and `demonwalker.finished` handlers.
- blocker reasons for disabled boop, manual targeting, diag hold, flee active, gold get/put pending, active target, waiting leader call, room not settled, move already queued.
- exact condition under which `raiseEvent("demonwalker.move")` fires.

Only then adjust `boop_walk.lua`. Keep demonnicAutoWalker external; boop decides when a room is safe to leave, the walker decides pathing.

### 5. Add Shared Command-Fragment Validation

Add one validation surface and route all persisted command fragments through it:

- command separator: no newline, no empty text, no ambiguous multi-command separators beyond the intended game separator.
- directions: known direction aliases only, normalized before use.
- pack/container: conservative token/string rules, no newline or command separator.
- assist leader/sender names: character-name token rules.
- pull mob name: keep current separator/newline rejection and reuse the shared validator.
- future command fragments: must choose a validator before persistence.

Tests should cover accepted values, rejected newlines, rejected separators, and no state mutation on failure.

### 6. Expand Gag Regression Fixtures Before Timing Changes

Use live combat logs to add replay-style tests for:

- own attack + battlerage + damage + balance summary ordering.
- mob attack + health lost summary.
- kill summary and attack summary coexisting.
- crit tiers and total damage.
- known unusual/failure lines that must stay visible.
- duplicate-line suppression.

After fixtures exist, adjust merge logic narrowly. Avoid broad trigger tree churn unless a source line cannot be represented by the current handler contract.

### 7. Final Release Confidence Pass

End the milestone with a release validation pass:

- Busted in real Mudlet profile.
- Muddler package build.
- version sync gate.
- manifest parity gate.
- focused live Mudlet checklist for GMCP reconnect, room/target, gold/pack, diag, one queued interrupt, walk, and gag output.
- docs/help coherence only for user-facing command changes.

## Patterns to Follow

### Effect Boundary for Combat Decisions

**What:** Plan from a runtime context, then apply effects through domain APIs.

**When:** Any behavior that can set a target, attack, flee, move, flush gold, or complete an interrupt hold.

**Example:**

```lua
local context = boop.runtime.context()
local result = boop.runtime.step({ type = "tick", context = context })
boop.runtime.applyEffects(result, context)
```

### Owned Domain State

**What:** Add or use fields under `DOMAIN_DEFAULTS` and access them through domain tables.

**When:** Any volatile runtime state.

**Example:**

```lua
local state = boop.runtime.ensureState()
state.walk.active = true
state.targeting.currentTargetId = tostring(targetId or "")
state.gold.getPending = true
```

### Thin Mudlet Objects

**What:** Keep alias/trigger Lua scripts as one- or two-line adapters.

**When:** New command entry points, gag lines, shield/rage triggers, prompt handling.

**Example:**

```lua
boop.gag.onAttackLine(matches, line)
```

### Fixture-First Gag Work

**What:** Capture a real line sequence, add a Busted replay expectation, then change summarization.

**When:** Any new gag pattern, delete-line behavior, prompt flush behavior, timer change, or summary format change.

### Walker Adapter Contract

**What:** Keep external walker API handling in `boop_walk.lua`; expose only `start`, `stop`, `status`, `move`, `onArrived`, `onFinished`, `onRoomChange`, `onRoomSettled`, and `maybeAdvance`.

**When:** Any autowalk behavior or external walker event handling.

## Anti-Patterns to Avoid

### Rewrite or Module-System Churn

**What goes wrong:** Replacing the global `boop` namespace with `require`, classes, or a new framework creates load-order and Mudlet packaging risk.

**Instead:** Keep manifest-loaded `boop.<domain>` modules and improve ownership/tests in place.

### Absorbing demonnicAutoWalker

**What goes wrong:** boop becomes a pathing/mapping package instead of a hunting package, and walker API risk moves into boop's release surface.

**Instead:** Keep `demonnicAutoWalker` optional and external. Contract-test the adapter.

### Flat State Compatibility Bridges

**What goes wrong:** Old keys such as `state.currentTargetId`, `state.diagHold`, or `state.walkActive` mask bugs and make context snapshots incomplete.

**Instead:** Update callers to owned domains and add tests that fail if old paths reappear.

### Gag Timer Tweaks Without Fixtures

**What goes wrong:** Compact summaries can hide warnings, delete the wrong line, reorder kill summaries, or miss damage/crit attribution.

**Instead:** Add replay tests from live logs first.

### Manifest Sorting of Runtime Scripts

**What goes wrong:** `boop_attacks.lua`, attack profiles, registries, UI, events, and bootstrap load in the wrong order.

**Instead:** Keep `src/scripts/boop/scripts.json` intentionally ordered. Use sort tooling only for safe display-order manifests.

### Command Validation at the Send Site Only

**What goes wrong:** Unsafe command fragments remain persisted and can be sent later by gold, pull, party, or interrupt paths.

**Instead:** Validate before persistence and again at high-risk send boundaries when cheap.

## Scalability and Release Considerations

| Concern | At Current Scale | Pre-1.0 Action | Later Action |
|---------|------------------|----------------|--------------|
| State ownership | Drift can break room, pull, walk, gold, diag, flee. | Repair owned domains and tests now. | Add a lightweight flat-key regression scan if needed. |
| Trigger count | Broad gag/shield/rage trigger tree is usable but easy to omit from manifests. | Add manifest parity gate. | Consider data-driven shared trigger generation only after 1.0. |
| Gag summarization | High-value but timing-sensitive. | Fixture-first narrow fixes. | Expand replay corpus by class/area. |
| Walker integration | Optional but safety-sensitive. | Contract-test adapter and blockers. | Pin trusted package URL/release if operationally required. |
| Stats DB/rendering | Good enough for release hardening. | Avoid schema churn. | Optimize high-cardinality summaries after 1.0. |
| UI/docs coherence | Stable workflow surfaces exist. | Update only for command-surface changes. | Split large UI/stats modules later if edits remain painful. |

## Roadmap Implications

Suggested phase structure for the next milestone:

1. **Release Gates and State Contracts** - Add version sync, manifest parity, and state-domain tests first.
   - Addresses: release confidence, state hardening.
   - Avoids: hidden package omissions and version drift during later edits.

2. **State Ownership Repair** - Migrate room, pull, walk, inventory, gold/diag/flee blockers to owned domains.
   - Addresses: state consistency, autowalk prerequisites.
   - Avoids: fixing walker symptoms while the underlying state paths are still split.

3. **Autowalk Regression Coverage and Adapter Fixes** - Turn walk tests on and harden room-settled/move/blocker behavior.
   - Addresses: autowalk integration.
   - Avoids: unsafe movement during gold, diag, flee, active-target, or leader-call states.

4. **Command-Fragment Validation** - Centralize validators and enforce them before persistence.
   - Addresses: command safety and release hardening.
   - Avoids: repeated ad hoc rejection logic.

5. **Gag Summary Fixture Expansion and Focused Fixes** - Add live log replay fixtures, then tune compact summaries.
   - Addresses: spam reduction without hiding important output.
   - Avoids: fragile timing changes without line coverage.

6. **Docs/Help and Live Release Verification** - Update user-facing docs only where behavior changed and run the live checklist.
   - Addresses: operator clarity and release readiness.
   - Avoids: broad docs churn unrelated to user-visible changes.

## Rewrite and Churn Warnings

- Do not propose or plan a rewrite. The current product is brownfield and mostly built.
- Do not move package content outside `src/`.
- Do not edit generated artifacts.
- Do not collapse or flatten the class/category trigger folders.
- Do not sort `src/scripts/boop/scripts.json`.
- Do not split `boop_ui.lua` or `boop_stats.lua` as a prerequisite to this milestone; extract only if a focused change becomes unmanageable.
- Do not change attack profile table contracts unless profile-matrix and rage-contract tests change first.
- Do not add broad new hunting features before the hardening work above is stable.

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Existing boop architecture | HIGH | Based on `.planning/codebase/ARCHITECTURE.md`, `.planning/codebase/STRUCTURE.md`, `.planning/codebase/CONVENTIONS.md`, `.planning/codebase/CONCERNS.md`, and current source reads. |
| Current state drift | HIGH | Confirmed by code reads in `boop_runtime.lua`, `boop_events.lua`, `boop_walk.lua`, and the disabled `tests/boop_walk_spec.lua`. |
| Build-order recommendation | HIGH | Dependencies are visible in source manifests, runtime domains, and current test gaps. |
| Mudlet runtime constraints | MEDIUM | GSD classifier returned `MEDIUM` for verified websearch docs; sources are official Mudlet docs. |
| GMCP message constraints | MEDIUM | GSD classifier returned `MEDIUM` for verified websearch docs; source is current Iron Realms Nexus GMCP documentation. |

## Sources

Local source of truth:

- `.planning/PROJECT.md`
- `.planning/config.json`
- `.planning/codebase/ARCHITECTURE.md`
- `.planning/codebase/STRUCTURE.md`
- `.planning/codebase/CONVENTIONS.md`
- `.planning/codebase/CONCERNS.md`
- `README.md`
- `DESIGN.md`
- `CODEX.md`
- `src/scripts/boop/boop_runtime.lua`
- `src/scripts/boop/boop_events.lua`
- `src/scripts/boop/boop_walk.lua`
- `src/scripts/boop/boop_gag.lua`
- `tests/boop_walk_spec.lua`

External runtime constraints:

- Mudlet Advanced Lua, Lua 5.1 runtime: https://wiki.mudlet.org/w/Manual:Advanced_Lua
- Mudlet Trigger Engine, triggers vs aliases: https://wiki.mudlet.org/w/Manual:Trigger_Engine
- Mudlet Event Engine, `registerAnonymousEventHandler` and `raiseEvent`: https://wiki.mudlet.org/w/Manual:Event_Engine
- Mudlet Object Functions, `tempTimer`: https://wiki.mudlet.org/w/Manual:Mudlet_Object_Functions
- Mudlet Networking Functions, `sendGMCP`: https://wiki.mudlet.org/w/Manual:Networking_Functions
- Mudlet Supported Protocols, GMCP support/request behavior: https://wiki.mudlet.org/w/Manual:Supported_Protocols
- Iron Realms Nexus GMCP modules and messages: https://nexus.ironrealms.com/GMCP
