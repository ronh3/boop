<!-- refreshed: 2026-08-30 -->
# Architecture

**Analysis Date:** 2026-08-30
**Source verified against:** commit `96384bc` (package `0.1.490`)

> **Authoritative source:** `/ARCHITECTURE.md` at the repository root describes boop as it is today, including the API-surface classification, the full dependency analysis, and the outbound-egress inventory. `/TARGET-ARCHITECTURE.md` describes the intended shape, `/REFACTOR-ROADMAP.md` the path there, and `/ARCHITECTURE-RULES.md` the rules to follow while working. This file is a summary for planning sessions; where it disagrees with the root documents, the root documents win.

## System Overview

```text
+---------------------------------------------------------------+
| Mudlet package: boop Hunter                                   |
| mfile, src/**/*.json manifests (hand-ordered load sequence)   |
+-------------------+-------------------+-----------------------+
| Aliases (82)      | Triggers (513)    | GMCP + system events  |
| src/aliases       | src/triggers      | 20 handlers           |
+---------+---------+---------+---------+----------+------------+
          |                   |                    |
          v                   v                    v
+---------------------------------------------------------------+
| boop_events.lua  -- adapter, gold pipeline, inventory,        |
|                     prequeue engine, boop.tick, boop.onPrompt |
| boop_runtime.lua -- state schema, room authority, operation   |
|                     locks, standard lifecycle, combat loop    |
+----------------+----------------+-----------------------------+
                 |                |
                 v                v
+---------------------------------------------------------------+
| Domain modules                                                |
| targets, attacks (+35 profiles), rage, safety, walk, skills,  |
| afflictions, stats, gag, ih, db, ui, ui_registry, theme, util |
+----------------+----------------+-----------------------------+
                 |                |
                 v                v
+---------------------------------------------------------------+
| Mudlet db (7 sheets), gmcp.*, send(), sendGMCP(),             |
| demonnicAutoWalker, mmp, agnosticdb                           |
+---------------------------------------------------------------+
```

**Important correction to the previous revision of this file:** `boop_events.lua` is not a thin GMCP layer. It is also the gold subsystem (~1250 lines), the wielded-inventory tracker, the prequeue engine, and the tick entry point.

## Component Responsibilities

| Component | File | Responsibility |
|---|---|---|
| State, room authority, locks, standard lifecycle, combat loop | `boop_runtime.lua` (4167) | Six distinct subsystems in one module |
| GMCP adapter, gold, inventory, prequeue, tick | `boop_events.lua` (3429) | Four subsystems plus the adapter |
| Screens, config mutation, interrupt/pull machine, command routing | `boop_ui.lua` (5546) | Presentation plus domain logic |
| Stats model and stats rendering | `boop_stats.lua` (2948) | ~1300 lines model, ~1650 lines presentation |
| Attack profiles, planning, selection, execution | `boop_attacks.lua` (2119) + `attacks/*` | Decision plus dispatch |
| Denizen selection, lists, party share | `boop_targets.lua` (2035) | Three concerns |
| Line condensation and combat-line parsing | `boop_gag.lua` (1795) | Display filter plus telemetry ingestion |
| Config/UI registries | `boop_ui_registry.lua` (1352) | Schema, routes, metatable bridge |
| Rage, walk, db, util, theme, init, skills, ih, afflictions, safety | remaining modules | Broadly match their names; `boop_util` also holds trace and the command dispatcher |

## Pattern Overview

- Single global namespace, `boop.<ns> = boop.<ns> or {}`. No `require()`.
- Canonical state tree of 13 owned domains under `boop.state`, hydrated by `boop.runtime.ensureState()`.
- Planner/executor split inside `boop.attacks` (`plan` -> `applyModifiers` -> `choose`, then `execute`).
- Effect-list coordination: `runtime.step()` returns effects, `runtime.applyEffects()` performs them.
- Generation-owned asynchronous operations: room observation, target sync, standard dispatch, interrupts, gold, walk.
- Registry-driven config and UI routing.

## Layers

Of 20 script modules, `boop_bootstrap` is the composition root with zero incoming edges. The other **19 form a single strongly-connected component**, containing **nineteen directly reciprocal pairs** (`A ↔ B`) plus many longer directed cycles. Graph analysis must attribute both namespaced and top-level `boop.*` symbols; a namespace-only graph misses six pairs caused by `boop_events`' 42 top-level functions. There is no enforced layering today. `/TARGET-ARCHITECTURE.md` §3 defines the intended DAG, the allowed/legacy/forbidden edge classification, and the three residual cycles that need a decision.

## Data Flow

### Primary Hunting Tick

`gmcp.Char.Vitals` -> `boop.onVitals()` -> `boop.tick()`, and independently the prompt trigger -> `boop.onPrompt()` -> `promptStep` -> often `boop.tick()`. Each tick builds `runtime.context()`, runs `runtime.step()`, and applies effects, ending in `attacks.execute()` -> `boop.executeAction()` -> `send()`.

`onVitals` has no `enabled` guard, so a prompt currently drives two full decision passes; the `canAct` limiter suppresses only the second dispatch.

### Bootstrap and Load Path

`boop_bootstrap.lua` (loaded last) resets session-local flags, then `boop.bootstrap()` announces GMCP supports, initializes db, state, afflictions, rage, ih, triggers, skills, stats, and events, then reports ready.

### GMCP Room and Target Updates

`Room.Info` plus a complete `Char.Items.List` settle a room through a fence/application model with generation-owned source authority. Accepted contents rebuild `state.targeting.denizens`. Target sync sends `settarget <id>` and waits for `IRE.Target.Set` or `IRE.Target.Info`.

### Command Surface

Aliases call `boop.ui.*`. Config schema and screen routes live in `boop_ui_registry.lua`.

### Trigger Ingestion

471 of 513 triggers are one-line dispatches to three generic handlers: `boop.gag.onAttackLine` (263 files), `boop.targets.onShieldDownTrigger` (116), `boop.rage.onAfflictionTrigger` (92). 885 patterns total, all active whenever hunting is enabled.

## Key Abstractions

| Abstraction | Where |
|---|---|
| Owned state domains | `DOMAIN_DEFAULTS`, `boop_runtime.lua` |
| Source authority (room generation) | `boop.runtime.validateRoomSourceAuthority` |
| Operation locks and blockers | `boop.runtime.setOperationLock`, `operationHolds` |
| Standard dispatch lifecycle | `boop.runtime.beginStandardDispatch` and successors |
| Attack profile tables | `src/scripts/boop/attacks/*.lua` |
| Effect list | `runtime.step()` -> `runtime.applyEffects()` |
| Config/UI registries | `boop.registry.*` |

## Entry Points

- 20 anonymous event handlers registered by `boop.events.register()`.
- One always-on prompt trigger, `src/triggers/boop_lifecycle/Prompt.lua`.
- 512 gameplay triggers in the `boop` folder, toggled wholesale by `boop.triggers.setEnabled()`.
- 82 alias scripts.

## Architectural Constraints

- Mudlet Lua 5.1 semantics; Muddler packaging; hand-ordered `scripts.json`.
- No `require()`; load-time side effects limited to three documented registration mechanisms.
- Behavioural tests run inside a real Mudlet instance in CI and are treated as contracts.
- See `/ARCHITECTURE-RULES.md` for the binding rules.

## Anti-Patterns

### Behavior in Alias or Trigger Scripts
Aliases and triggers stay thin (82 aliases total 130 lines). Logic belongs in `src/scripts/boop/`.

### New Flat Runtime State Keys
Use the owned domains. `tools/check_release_gates.py --check state-drift` enforces this.

### Sorting Load-Order-Sensitive Scripts
`src/scripts/boop/scripts.json` is hand-ordered and excluded from `tools/sort_manifests.sh`.

### Profile Logic Outside Profiles and Planner
Class behaviour belongs in the profile table or the planner, not in dispatch or UI.

### New Cycles in the Module Graph
The graph is currently one SCC. Through roadmap Phase 7 the staged policy applies: no new reciprocal edge, SCC size may only decrease. From Phase 8 acceptance any cycle is a hard CI failure. `/TARGET-ARCHITECTURE.md` §3 defines the target DAG.

## Error Handling

`pcall` guards optional Mudlet APIs and DB operations, degrading to `boop.util.warn` rather than throwing. Asynchronous operations are generation-owned with timeout fallbacks, so a missed trigger terminalizes rather than deadlocks.

## Cross-Cutting Concerns

| Concern | Current owner |
|---|---|
| Tracing | `boop.trace.*`, defined in `boop_util.lua` |
| Performance instrumentation | none today; `boop.perf` is Phase 1 of the roadmap |
| Theming | `boop.theme` |
| Persistence | `boop.db`, though `boop_ui` bypasses it at five sites |
| Command egress | 15 `send()` sites across seven files; no single egress point |
