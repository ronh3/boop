<!-- refreshed: 2026-07-09 -->
# Architecture

**Analysis Date:** 2026-07-09

## System Overview

```text
+-------------------------------------------------------------+
|              Mudlet package: boop Hunter                     |
|              `mfile`, `src/**/scripts.json`                  |
+-------------------+-------------------+---------------------+
| Aliases           | Triggers          | GMCP handlers        |
| `src/aliases`     | `src/triggers`    | `boop_events.lua`    |
+---------+---------+---------+---------+----------+----------+
          |                   |                    |
          v                   v                    v
+-------------------------------------------------------------+
| Bootstrap, Runtime Context, and Effect Coordinator           |
| `src/scripts/boop/boop_init.lua`                             |
| `src/scripts/boop/boop_runtime.lua`                          |
| `src/scripts/boop/boop_events.lua`                           |
+----------------+----------------+---------------------------+
                 |                |
                 v                v
+-------------------------------------------------------------+
| Domain Modules                                               |
| `boop_targets.lua`, `boop_attacks.lua`, `boop_rage.lua`,      |
| `boop_safety.lua`, `boop_stats.lua`, `boop_db.lua`,           |
| `boop_ui.lua`, `boop_gag.lua`, `boop_walk.lua`                |
+----------------+----------------+---------------------------+
                 |                |
                 v                v
+-------------------------------------------------------------+
| Mudlet DB, GMCP, Game Commands, and External Mudlet Packages  |
| Mudlet `db`, `gmcp.*`, `send()`, `sendGMCP()`, `demonwalker`  |
+-------------------------------------------------------------+
```

## Component Responsibilities

| Component | Responsibility | File |
|-----------|----------------|------|
| Package metadata | Defines package name, title, version, and Muddler output behavior. | `mfile` |
| Script manifest | Controls load order for all boop Lua modules; keep this order intentional. | `src/scripts/boop/scripts.json` |
| Bootstrap | Creates `boop`, defaults, trigger controls, GMCP support requests, and one-time init. | `src/scripts/boop/boop_init.lua` |
| Bootstrap entry | Runs `boop.bootstrap()` after all prior scripts and attack profiles load. | `src/scripts/boop/boop_bootstrap.lua` |
| Runtime state | Owns canonical state domains and builds the runtime context snapshot. | `src/scripts/boop/boop_runtime.lua` |
| Runtime coordinator | Converts tick/prompt events into effects and applies side effects through domain APIs. | `src/scripts/boop/boop_runtime.lua` |
| Event adapter | Registers GMCP/Mudlet event handlers and mutates room, target, gold, inventory, and queue state. | `src/scripts/boop/boop_events.lua` |
| Persistence | Creates Mudlet DB tables and loads/saves config, lists, whitelist tags, mob XP, and lifetime stats. | `src/scripts/boop/boop_db.lua` |
| Targeting | Tracks denizens, target id/name/shield state, whitelist/blacklist priority, party target calls, and whitelist sharing. | `src/scripts/boop/boop_targets.lua` |
| Combat planner | Registers class profiles, gates skills, selects standard/rage plans, applies class modifiers, and executes plans. | `src/scripts/boop/boop_attacks.lua` |
| Attack profiles | Data-only class attack and rage definitions loaded into `boop.attacks.registry`. | `src/scripts/boop/attacks/*.lua` |
| Rage tracking | Tracks fallback readiness, rage gain samples, free-rage state, maul readiness, and affliction ingestion. | `src/scripts/boop/boop_rage.lua` |
| Skill gating | Requests and caches `Char.Skills.*` GMCP data for attack/profile requirements. | `src/scripts/boop/boop_skills.lua` |
| Safety | Parses flee thresholds and disables boop before sending the flee chain. | `src/scripts/boop/boop_safety.lua` |
| Stats | Tracks session/login/trip/lifetime hunting metrics, target stats, rage decisions, and dashboards. | `src/scripts/boop/boop_stats.lua` |
| UI | Implements command handlers, dashboards, config screens, help, party, stats routing, and interrupt commands. | `src/scripts/boop/boop_ui.lua` |
| UI registry | Defines config schema, setters, modes, presets, help topics, and config screen metadata. | `src/scripts/boop/boop_ui_registry.lua` |
| Output theming | Resolves built-in boop and ADB-style themes for `cecho` output. | `src/scripts/boop/boop_theme.lua` |
| Info-Here capture | Enables IH capture triggers and re-renders lines with whitelist/blacklist click actions. | `src/scripts/boop/boop_ih.lua` |
| Gag summarizer | Condenses own/other/mob attack lines into compact summaries and feeds stats hooks. | `src/scripts/boop/boop_gag.lua` |
| Walker integration | Integrates with `demonnicAutoWalker` and raises move events after clear-room checks. | `src/scripts/boop/boop_walk.lua` |
| Aliases | Thin Mudlet command entry points that call `boop.ui.*` or domain APIs. | `src/aliases/boop/**` |
| Triggers | Thin Mudlet text adapters that pass matches into domain handlers. | `src/triggers/boop/**` |
| Tests | Real-Mudlet busted coverage for runtime, planner, targeting, UI, DB, triggers, and regressions. | `tests/*.lua`, `tests/support/boop_test_helper.lua` |

## Pattern Overview

**Overall:** Manifest-loaded Mudlet package with a global `boop` namespace, event-driven adapters, domain modules, and data-driven class profiles.

**Key Characteristics:**
- Use the shared `boop` namespace; do not use Lua `require` or external module loaders in package code.
- Keep Mudlet aliases/triggers as adapter scripts; put behavior in `src/scripts/boop/*.lua`.
- Use `boop.runtime.context()` and domain state tables for planning decisions.
- Let `boop.runtime.step()` return effects and `boop.runtime.applyEffects()` perform side effects where practical.
- Register combat profiles through `boop.attacks.register()` in one file per class under `src/scripts/boop/attacks/`.
- Store persistent operator configuration and hunting data in Mudlet DB through `boop_db.lua`.

## Layers

**Package/Manifest Layer:**
- Purpose: Defines package metadata and Mudlet object load order.
- Location: `mfile`, `src/scripts/scripts.json`, `src/scripts/boop/scripts.json`, `src/aliases/**/*.json`, `src/triggers/**/*.json`
- Contains: Muddler metadata and object manifests.
- Depends on: Muddler's manifest naming rules.
- Used by: CI build workflow in `.github/workflows/main.yml` and local `muddle` builds.

**Bootstrap Layer:**
- Purpose: Initializes global tables, config defaults, GMCP supports, DB, state domains, events, stats, triggers, and ready output.
- Location: `src/scripts/boop/boop_init.lua`, `src/scripts/boop/boop_bootstrap.lua`
- Contains: `boop.defaults`, `boop.requestCoreSupports()`, `boop.bootstrap()`, trigger enable/sync helpers.
- Depends on: Prior manifest load order and Mudlet APIs such as `sendGMCP()`, `enableTrigger()`, and `disableTrigger()`.
- Used by: Package load through `src/scripts/boop/boop_bootstrap.lua`.

**State/Runtime Layer:**
- Purpose: Owns canonical runtime domains and coordinates tick/prompt work.
- Location: `src/scripts/boop/boop_runtime.lua`, `src/scripts/boop/boop_state.lua`
- Contains: Domain defaults for `combat`, `targeting`, `gold`, `queue`, `walk`, `diag`, `trace`, `ui`, `rage`, `inventory`, `ih`, and `gag`.
- Depends on: GMCP, `boop.config`, and domain modules.
- Used by: `boop.tick()`, `boop.onPrompt()`, tests such as `tests/boop_runtime_spec.lua`.

**Event Adapter Layer:**
- Purpose: Converts GMCP, connection, walker, prompt, and text-trigger events into boop state changes and runtime ticks.
- Location: `src/scripts/boop/boop_events.lua`, `src/triggers/boop/**`
- Contains: `boop.events.register()`, GMCP handlers, prequeue scheduling, gold retry state, inventory/wield tracking, prompt handling.
- Depends on: Mudlet `registerAnonymousEventHandler()`, `tempTimer()`, `send()`, `gmcp.*`, and trigger matches.
- Used by: Runtime coordinator, target module, stats, rage, safety, walk integration.

**Domain Logic Layer:**
- Purpose: Implements hunting behavior independent of Mudlet object registration.
- Location: `src/scripts/boop/boop_targets.lua`, `src/scripts/boop/boop_attacks.lua`, `src/scripts/boop/boop_rage.lua`, `src/scripts/boop/boop_safety.lua`, `src/scripts/boop/boop_stats.lua`, `src/scripts/boop/boop_gag.lua`, `src/scripts/boop/boop_ih.lua`, `src/scripts/boop/boop_walk.lua`, `src/scripts/boop/boop_skills.lua`
- Contains: Target choice, combat planning, rage selection, skill gates, safety checks, stats, UI helper behavior, and external walker bridging.
- Depends on: `boop.util`, `boop.state`, `boop.config`, `gmcp`, and Mudlet send/timer APIs.
- Used by: Aliases, triggers, event handlers, runtime effects, and tests.

**UI/Command Layer:**
- Purpose: Presents operator surfaces and command handlers.
- Location: `src/scripts/boop/boop_ui.lua`, `src/scripts/boop/boop_ui_registry.lua`, `src/aliases/boop/**`
- Contains: Home/control/config/help/party/stats dashboards, config setters, mode/preset registries, and command routers.
- Depends on: Domain modules, `cecho`, `cechoLink`, `appendCmdLine`, `boop.theme`, `boop.config`.
- Used by: Alias scripts such as `src/aliases/boop/Core/Boop.lua` and `src/aliases/boop/Core/Boop_Control.lua`.

**Persistence Layer:**
- Purpose: Persists operator config and durable hunting data.
- Location: `src/scripts/boop/boop_db.lua`
- Contains: Mudlet DB sheets `config`, `whitelist`, `blacklist`, `whitelist_tags`, `mob_xp`, `mob_xp_v2`, and `stats`.
- Depends on: Mudlet `db` API and schema verification helpers.
- Used by: Bootstrap, UI config setters, target list operations, whitelist tags, stats persistence.

## Data Flow

### Primary Hunting Tick

1. GMCP vitals, prompt, or timer path calls `boop.tick()` (`src/scripts/boop/boop_events.lua:934`).
2. `boop.runtime.context()` snapshots `boop.state`, `boop.config`, GMCP class/spec/room/target/rage, queue, gold, diag, assist, and inventory state (`src/scripts/boop/boop_runtime.lua:177`).
3. `boop.runtime.step({ type = "tick" })` runs `tickStep()` (`src/scripts/boop/boop_runtime.lua:242`, `src/scripts/boop/boop_runtime.lua:345`).
4. Safety runs before combat through `boop.safety.shouldFlee()` (`src/scripts/boop/boop_safety.lua`).
5. Target selection calls `boop.targets.choose()` (`src/scripts/boop/boop_targets.lua:933`).
6. Target changes emit a `target` effect and apply through `boop.targets.setTarget()` (`src/scripts/boop/boop_targets.lua:209`).
7. Combat planning calls `boop.attacks.choose(context)` (`src/scripts/boop/boop_attacks.lua:1563`).
8. The runtime emits a `combat_plan` effect, and `boop.runtime.applyEffects()` calls `boop.attacks.execute()` (`src/scripts/boop/boop_runtime.lua:355`, `src/scripts/boop/boop_attacks.lua:1572`).
9. Standard actions go through `boop.executeAction()` for direct send or freestand queue aliasing (`src/scripts/boop/boop_util.lua:198`).
10. Rage actions go through `boop.executeRageAction()` and notify rage/stats state (`src/scripts/boop/boop_util.lua`, `src/scripts/boop/boop_attacks.lua:1572`).

### Bootstrap and Load Path

1. Muddler reads `mfile` and `src/scripts/scripts.json`.
2. `src/scripts/boop/scripts.json` loads `boop_init`, utility/theme/skills/db/runtime/state, domain modules, attack profiles, UI, events, then `boop_bootstrap`.
3. `src/scripts/boop/boop_bootstrap.lua:1` calls `boop.bootstrap()`.
4. `boop.bootstrap()` in `src/scripts/boop/boop_init.lua:122` requests GMCP supports, initializes DB/state/afflictions/rage/IH/stats/events, requests skills, syncs trigger folder state, and prints ready status.
5. `boop.events.register()` installs GMCP and walker event handlers (`src/scripts/boop/boop_events.lua:475`).

### GMCP Room and Target Updates

1. `gmcp.Char.Items.List` runs `boop.onRoomItemsList()` (`src/scripts/boop/boop_events.lua:492`, `src/scripts/boop/boop_events.lua:518`).
2. Room items update `boop.state.targeting.denizens` through `boop.targets.updateRoomItems()` (`src/scripts/boop/boop_targets.lua`).
3. Gold items run the gold detection path in `boop_events.lua`, which queues `get sovereigns` directly or prefixes the next queued standard action.
4. `gmcp.Room.Info` runs `boop.onRoomInfo()` (`src/scripts/boop/boop_events.lua:496`, `src/scripts/boop/boop_events.lua:632`), clearing stale target/gold/shield state and updating walk/stats movement hooks.
5. `gmcp.IRE.Target.Set` and `gmcp.IRE.Target.Info` run target apply paths (`src/scripts/boop/boop_events.lua:497`, `src/scripts/boop/boop_events.lua:498`, `src/scripts/boop/boop_events.lua:711`, `src/scripts/boop/boop_events.lua:731`).

### Command Surface

1. Alias manifests under `src/aliases/boop/**/aliases.json` define regex entry points.
2. Alias scripts call UI/domain functions directly, for example `src/aliases/boop/Core/Boop.lua` calls `boop.ui.home()`.
3. `boop.ui.*` handlers mutate config through registry setters, save DB config, print feedback, and call domain modules as needed (`src/scripts/boop/boop_ui.lua`, `src/scripts/boop/boop_ui_registry.lua`).
4. Command-surface changes need matching alias JSON, alias script, UI/help text, README/UIDESIGN docs when user-facing behavior changes.

### Trigger Ingestion

1. Trigger manifests under `src/triggers/boop/**/triggers.json` define Mudlet match patterns.
2. Trigger scripts stay thin; examples call `boop.onPrompt()`, `boop.onBalanceUsed()`, `boop.rage.onAfflictionTrigger()`, `boop.gag.onAttackLine()`, and `boop.targets.onShieldDownTrigger()`.
3. Class/category trigger folders keep generated Foxhunt-derived gag, rage-affliction, and shield patterns close to their manifests.
4. `src/triggers/triggers.json` has the top-level `boop` folder inactive by default; `boop.triggers.syncEnabled()` enables/disables hunting triggers from config.

**State Management:**
- Canonical state domains are defined in `src/scripts/boop/boop_runtime.lua:19` and materialized by `boop.runtime.ensureState()` at `src/scripts/boop/boop_runtime.lua:124`.
- Use domain paths such as `boop.state.targeting.currentTargetId`, `boop.state.queue.prequeuedStandard`, `boop.state.gold.getPending`, and `boop.state.rage.ready`.
- Persistent config lives in `boop.config` and is backed by `boop.db.saveConfig()` in `src/scripts/boop/boop_db.lua`.
- Persistent lists live in `boop.lists` and are backed by `boop.db.saveList()` / `boop.db.saveWhitelistTags()` in `src/scripts/boop/boop_db.lua`.

## Key Abstractions

**`boop` Namespace:**
- Purpose: Shared global namespace for all package modules.
- Examples: `src/scripts/boop/boop_init.lua`, `src/scripts/boop/boop_targets.lua`, `src/scripts/boop/boop_ui.lua`
- Pattern: Each module starts with `boop.<domain> = boop.<domain> or {}` and attaches public functions.

**Runtime Context and Effects:**
- Purpose: Keep tick/prompt decisions inspectable before applying Mudlet side effects.
- Examples: `boop.runtime.context()`, `boop.runtime.step()`, `boop.runtime.applyEffects()` in `src/scripts/boop/boop_runtime.lua`
- Pattern: Plan first, emit effects such as `target`, `combat_plan`, `flee`, `walk_advance`, then apply through domain APIs.

**Attack Profile:**
- Purpose: Data contract for per-class standard and rage actions.
- Examples: `src/scripts/boop/attacks/occultist.lua`, `src/scripts/boop/attacks/infernal.lua`
- Pattern: `boop.attacks.register("class", { standard = {...}, rage = {...} })` with `dam`, `shield`, `opener`, `openerAt100`, `bySpec`, `skill`, `group`, `cmd`, `desc`, `rage`, `needs`, and `aff` fields.

**Target State:**
- Purpose: Track room denizens, selected target, shield status, party calls, and whitelist share packets.
- Examples: `src/scripts/boop/boop_targets.lua`, `src/scripts/boop/boop_runtime.lua`
- Pattern: GMCP room item updates populate `boop.state.targeting.denizens`; `boop.targets.choose()` returns an id; `boop.targets.setTarget()` sends `settarget <id>`.

**UI Registry:**
- Purpose: Keep config schema, setters, modes, presets, help topics, and config screen metadata data-driven.
- Examples: `src/scripts/boop/boop_ui_registry.lua`, `src/scripts/boop/boop_ui.lua`
- Pattern: Registry tables are attached via `boop.registry.attachUiConfigRegistries()` and consumed by UI renderers.

**Thin Mudlet Objects:**
- Purpose: Keep Mudlet aliases/triggers easy to audit and keep behavior in modules.
- Examples: `src/aliases/boop/Core/Boop_Control.lua`, `src/triggers/boop/Core/Prompt.lua`, `src/triggers/boop/Gold/Gold_Drop_Line.lua`
- Pattern: One or two lines that call `boop.ui.*`, `boop.on*`, or `boop.<domain>.*`.

## Entry Points

**Package Load:**
- Location: `mfile`, `src/scripts/scripts.json`, `src/scripts/boop/scripts.json`, `src/scripts/boop/boop_bootstrap.lua`
- Triggers: Mudlet package install/load through Muddler output.
- Responsibilities: Load modules in order and call `boop.bootstrap()`.

**Home Dashboard Command:**
- Location: `src/aliases/boop/Core/Boop.lua`
- Triggers: `boop`
- Responsibilities: Calls `boop.ui.home()`.

**Command Routers:**
- Location: `src/aliases/boop/Core/*.lua`, `src/aliases/boop/Combat/*.lua`, `src/aliases/boop/Targeting/*.lua`, `src/aliases/boop/Stats/*.lua`
- Triggers: User aliases defined in `src/aliases/boop/**/aliases.json`.
- Responsibilities: Route captured arguments into `boop.ui.*`, `boop.targets.*`, `boop.stats.*`, or `boop.afflictions.*`.

**GMCP Event Registration:**
- Location: `src/scripts/boop/boop_events.lua:475`
- Triggers: Bootstrap calls `boop.events.register()`.
- Responsibilities: Registers handlers for `gmcp.Char.Items.*`, `gmcp.Room.Info`, `gmcp.IRE.Target.*`, `gmcp.Char.Status`, `gmcp.Char.Vitals`, `gmcp.Char.Skills.*`, connection events, and demonwalker events.

**Prompt Trigger:**
- Location: `src/triggers/boop/Core/Prompt.lua`
- Triggers: Mudlet `isPrompt()` Lua trigger from `src/triggers/boop/Core/triggers.json`.
- Responsibilities: Calls `boop.onPrompt()` to complete diag holds, flush gag summaries, and run a tick when appropriate.

**Combat/Rage/Gag Text Triggers:**
- Location: `src/triggers/boop/Rage/**`, `src/triggers/boop/Shield/**`, `src/triggers/boop/Gag/**`
- Triggers: Class/category text patterns defined in local `triggers.json` files.
- Responsibilities: Update rage afflictions/readiness, shield state, and gag/stat summaries.

## Architectural Constraints

- **Threading:** Mudlet executes Lua in an event/timer-driven single client context; timers from `tempTimer()` create deferred callbacks but no parallel Lua threads.
- **Global state:** `boop`, `boop.config`, `boop.lists`, `boop.state`, `boop.attacks.registry`, `boop.handlers`, and `boop.skills.*` are module-level globals.
- **State domains:** New runtime state should be added to `DOMAIN_DEFAULTS` in `src/scripts/boop/boop_runtime.lua` and accessed through domain tables.
- **Load order:** `src/scripts/boop/scripts.json` is load-order sensitive; keep `boop_init` first, `boop_attacks` before `attacks`, UI registry before UI consumers, and `boop_bootstrap` last.
- **Circular imports:** Not applicable as Lua `require` is not used; dependencies are implicit through shared `boop` tables and manifest order.
- **Trigger activation:** The top-level trigger folder in `src/triggers/triggers.json` is inactive by default; `boop.triggers.syncEnabled()` controls active hunting triggers.
- **Build output:** Package content lives under `src/`; do not edit generated files under `build/`.
- **Version fields:** Before commits or pushes, keep `mfile.version`, `mfile.title`, and `src/scripts/boop/boop_init.lua` `boop.version` synchronized.

## Anti-Patterns

### Behavior in Alias or Trigger Scripts

**What happens:** Alias/trigger scripts grow direct business logic instead of delegating.
**Why it's wrong:** It scatters behavior across Mudlet object files and bypasses testable domain modules.
**Do this instead:** Keep scripts thin like `src/aliases/boop/Core/Boop.lua` and `src/triggers/boop/Core/Prompt.lua`; put behavior in `src/scripts/boop/boop_ui.lua` or a domain module.

### New Flat Runtime State Keys

**What happens:** Code writes feature state directly as `boop.state.someKey`.
**Why it's wrong:** It bypasses `DOMAIN_DEFAULTS`, makes runtime context snapshots incomplete, and weakens `tests/boop_runtime_spec.lua`.
**Do this instead:** Add a domain/key under `DOMAIN_DEFAULTS` in `src/scripts/boop/boop_runtime.lua`, initialize through `boop.state.init()` in `src/scripts/boop/boop_state.lua`, and access it through `boop.state.<domain>.<key>`.

### Sorting Load-Order-Sensitive Scripts

**What happens:** `src/scripts/boop/scripts.json` is alphabetized like display-order manifests.
**Why it's wrong:** `boop_attacks.lua` must load before `src/scripts/boop/attacks/*.lua`, registries must exist before consumers, and bootstrap must run last.
**Do this instead:** Use `tools/sort_manifests.sh` for safe manifests only; leave `src/scripts/boop/scripts.json` in intentional load order.

### Profile Logic Outside Profiles and Planner

**What happens:** Class-specific combat behavior is added to command handlers, triggers, or UI rendering.
**Why it's wrong:** It makes class behavior hard to test across `tests/boop_profile_matrix_spec.lua`, `tests/boop_profiles_spec.lua`, and `tests/boop_rage_contract_spec.lua`.
**Do this instead:** Add data to `src/scripts/boop/attacks/<class>.lua` and planner/modifier support in `src/scripts/boop/boop_attacks.lua`.

## Error Handling

**Strategy:** Fail closed for combat automation, warn through boop UI feedback, and keep Mudlet callback failures contained where the API is optional or environment-dependent.

**Patterns:**
- Use `boop.util.info()`, `boop.util.ok()`, `boop.util.warn()`, and `boop.util.err()` from `src/scripts/boop/boop_util.lua`.
- Wrap optional DB/table creation and fetch paths in `pcall()` in `src/scripts/boop/boop_db.lua`.
- Guard unavailable Mudlet APIs such as `db`, `sendGMCP`, `installPackage`, `registerAnonymousEventHandler`, `enableTrigger`, and `disableTrigger`.
- Use timers as recovery paths for diag holds, gold pending state, maul readiness fallback, and walk arrival fallback.
- Clear stale target/shield/gold state on room changes and target removal in `src/scripts/boop/boop_events.lua`.
- Keep combat disabled after `boop.safety.flee()` and persist the disabled config.

## Cross-Cutting Concerns

**Logging:** `boop.trace.log()` in `src/scripts/boop/boop_util.lua` records compact trace lines in `boop.state.trace.buffer` only when `boop.config.traceEnabled` is true.

**Validation:** Config setters and screen metadata live in `src/scripts/boop/boop_ui_registry.lua`; input normalization is shared through `boop.util.trim()`, `safeLower()`, and command-specific UI handlers in `src/scripts/boop/boop_ui.lua`.

**Authentication:** Not applicable; this is a local Mudlet package. Party chat protocols trust configured leader/self checks in `src/scripts/boop/boop_targets.lua`.

**Persistence:** Mudlet DB persistence is isolated to `src/scripts/boop/boop_db.lua`; domain modules should call DB helpers rather than using `db:*` directly.

**Output:** User-facing output should use `boop.util.*`, `boop.theme`, and the established `cecho`/`cechoLink` style in `src/scripts/boop/boop_ui.lua` and `src/scripts/boop/boop_gag.lua`.

**External integrations:** `demonnicAutoWalker` remains an external package consumed through `boop_walk.lua`; boop raises `demonwalker.move` rather than taking over routing.

---

*Architecture analysis: 2026-07-09*
