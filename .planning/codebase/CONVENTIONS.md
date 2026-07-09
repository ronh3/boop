# Coding Conventions

**Analysis Date:** 2026-07-09

## Naming Patterns

**Files:**
- Use lower snake-case for core package scripts under `src/scripts/boop/`, with the domain in the filename: `src/scripts/boop/boop_attacks.lua`, `src/scripts/boop/boop_targets.lua`, `src/scripts/boop/boop_ui_registry.lua`.
- Use lower snake-case class/profile filenames under `src/scripts/boop/attacks/`: `src/scripts/boop/attacks/occultist.lua`, `src/scripts/boop/attacks/blue_dragon.lua`, `src/scripts/boop/attacks/air_elemental_lord.lua`.
- Use title-case Mudlet object filenames with underscores for aliases/triggers where the Mudlet object name contains spaces: `src/aliases/boop/Core/Boop_Set.lua`, `src/aliases/boop/Combat/Pull.lua`, `src/triggers/boop/Core/Party_Target_Call.lua`.
- Use `boop_<domain>_spec.lua` for tests in `tests/`: `tests/boop_attacks_spec.lua`, `tests/boop_ui_registry_spec.lua`, `tests/boop_profile_matrix_spec.lua`.

**Functions:**
- Public runtime functions live on the global `boop` namespace, grouped by domain: `boop.attacks.choose` in `src/scripts/boop/boop_attacks.lua`, `boop.safety.flee` in `src/scripts/boop/boop_safety.lua`, `boop.ui.setConfigValue` in `src/scripts/boop/boop_ui.lua`.
- Event callbacks exposed to Mudlet use `boop.on<Name>` or domain-specific handler names: `boop.onPrompt()` from `src/triggers/boop/Core/Prompt.lua`, `boop.onSkillsInfo()` in `src/scripts/boop/boop_skills.lua`, `boop.targets.onPartyWhitelistShare(...)` in `src/triggers/boop/Core/Party_Whitelist_Share.lua`.
- Private helpers are `local function` declarations in camelCase: `planningTargetId()` in `src/scripts/boop/boop_attacks.lua`, `queueGoldCommand()` in `src/scripts/boop/boop_events.lua`, `configBoolSetter()` in `src/scripts/boop/boop_ui_registry.lua`.
- Test helper functions are exported from the `M` table in `tests/support/boop_test_helper.lua`, using camelCase names such as `M.setTarget`, `M.setDenizens`, `M.learnSkills`, and `M.addTargetAfflictions`.

**Variables:**
- Local variables use lower camelCase: `queuedAction` in `src/scripts/boop/boop_util.lua`, `currentTargetId` in `src/scripts/boop/boop_runtime.lua`, `send_gmcp_stub` only in tests such as `tests/boop_tick_spec.lua`.
- Constants use upper snake-case: `AUTO_GOLD_FLUSH_SECONDS` and `GOLD_READY_QUEUE` in `src/scripts/boop/boop_events.lua`, `DOMAIN_DEFAULTS` in `src/scripts/boop/boop_runtime.lua`, `IH_TRIGGER_NAMES` in `src/scripts/boop/boop_ih.lua`.
- Persisted config keys use lower camelCase and must stay consistent across defaults, setters, persistence, UI, and tests: `prequeueEnabled`, `targetingMode`, `rageAffCalloutsEnabled`, and `gameSeparator` in `src/scripts/boop/boop_init.lua`, `src/scripts/boop/boop_ui_registry.lua`, and `tests/boop_persistence_spec.lua`.
- State domains use stable lower-case domain tables created by `boop.runtime.ensureState()`: `boop.state.combat`, `boop.state.targeting`, `boop.state.gold`, `boop.state.queue`, `boop.state.diag`, `boop.state.rage`, `boop.state.inventory` in `src/scripts/boop/boop_runtime.lua`.

**Types:**
- There is no formal type system; use table-shaped contracts documented by local schemas and tests. Config defaults live in `src/scripts/boop/boop_init.lua`; runtime state defaults live in `src/scripts/boop/boop_runtime.lua`; DB schemas live in `src/scripts/boop/boop_db.lua`.
- Attack profiles are data tables registered with `boop.attacks.register(...)` and use `cmd`, `skill`, `group`, `rage`, `desc`, `aff`, `needs`, and `bySpec` keys: `src/scripts/boop/attacks/occultist.lua`, `src/scripts/boop/attacks/infernal.lua`, `tests/boop_profile_matrix_spec.lua`.

## Code Style

**Formatting:**
- No formatter config is detected in `.prettierrc*`, `stylua.toml`, `.stylua.toml`, `.luacheckrc`, or `biome.json`.
- Use two-space indentation for Lua control blocks and table literals, matching `src/scripts/boop/boop_runtime.lua`, `src/scripts/boop/boop_ui_registry.lua`, and `tests/boop_attacks_spec.lua`.
- Prefer concise guard clauses for unavailable Mudlet globals, empty values, and disabled features: `if not sendGMCP then return end` in `src/scripts/boop/boop_skills.lua`, `if not action or action == "" then return end` in `src/scripts/boop/boop_util.lua`, `if type(item) ~= "table" then return end` in `src/scripts/boop/boop_events.lua`.
- Keep Muddler manifest JSON stable and two-space formatted in `src/scripts/boop/scripts.json`, `src/aliases/boop/aliases.json`, and `src/triggers/boop/Core/triggers.json`.

**Linting:**
- No lint runner or lint config is detected in `package.json`, `.luacheckrc`, `stylua.toml`, `.eslintrc*`, or `.github/workflows/main.yml`.
- Code quality enforcement comes from the Mudlet/Busted behavior suite under `tests/` and the Muddler build in `.github/workflows/main.yml`.

## Import Organization

**Order:**
1. Core package code is loaded by Muddler manifest order, not by `require(...)`. Keep `src/scripts/boop/scripts.json` dependency-aware: `boop_init`, utilities, theme/skills/db/runtime/state, behavior domains, attack registry, UI registry/UI, events, then `boop_bootstrap`.
2. Attack profile scripts are loaded through the attack manifest and register themselves with `boop.attacks.register(...)`: `src/scripts/boop/attacks/scripts.json`, `src/scripts/boop/attacks/occultist.lua`.
3. Alias and trigger files should remain small dispatchers into runtime functions, with object metadata in manifests: `src/aliases/boop/Core/Boop_Set.lua`, `src/aliases/boop/Combat/Pull.lua`, `src/triggers/boop/Core/Prompt.lua`, `src/triggers/boop/Core/triggers.json`.

**Path Aliases:**
- No Lua module path aliases are detected in `src/` or `tests/`.
- Tests load the shared helper explicitly with `dofile(os.getenv("TESTS_DIRECTORY") .. "/support/boop_test_helper.lua")` in files such as `tests/boop_attacks_spec.lua` and `tests/boop_tick_spec.lua`.
- Muddler object names map filenames through manifests; names with spaces map to underscore filenames, as documented in `CODEX.md` and used by `src/aliases/boop/Core/Boop_On_Off.lua`.

## Error Handling

**Patterns:**
- Guard Mudlet-only APIs before use and degrade cleanly where possible: `src/scripts/boop/boop_ih.lua` checks `cechoLink`, `cecho`, `echoLink`, and `echo`; `src/scripts/boop/boop_skills.lua` checks `sendGMCP`; `src/scripts/boop/boop_targets.lua` checks `send`.
- Wrap optional or profile-dependent Mudlet/DB operations in `pcall` and return status plus error text for callers to warn on: `src/scripts/boop/boop_db.lua` uses `pcall` around `db:get_database`, `db:create`, `db:fetch`, and sheet access.
- Prefer `boop.util.warn(...)` or `boop.util.err(...)` for operator-facing failure paths instead of raw `error(...)`: `src/scripts/boop/boop_ui_registry.lua`, `src/scripts/boop/boop_db.lua`, `src/scripts/boop/boop_targets.lua`.
- Use raw `error(...)` only when rethrowing an internal planning failure after restoring state, as in `withContext(...)` in `src/scripts/boop/boop_attacks.lua`.
- Validate command input before mutation and leave state unchanged on invalid input: boolean setters in `src/scripts/boop/boop_ui_registry.lua`, `boop.ui.fleeCommand` in `src/scripts/boop/boop_ui.lua`, `boop.ui.pullCommand` in `src/scripts/boop/boop_ui.lua`.

## Logging

**Framework:** `boop.util` feedback helpers and gated trace buffer.

**Patterns:**
- Use `boop.util.info`, `boop.util.ok`, `boop.util.warn`, and `boop.util.err` for user-facing status. The feedback tags are `[INFO]`, `[OK]`, `[WARN]`, and `[ERR]` in `src/scripts/boop/boop_util.lua`.
- Use `boop.trace.log(...)` for diagnostic flow details that should appear only when `boop.config.traceEnabled` is true. The trace buffer is capped at 100 entries in `src/scripts/boop/boop_util.lua` and inspected by `tests/boop_trace_spec.lua`.
- Do not use plain `print` for shipped behavior. Output should route through `boop.util`, `cecho`, `cechoLink`, `echo`, or `echoLink` as in `src/scripts/boop/boop_ui.lua`, `src/scripts/boop/boop_targets.lua`, and `src/scripts/boop/boop_ih.lua`.

## Comments

**When to Comment:**
- Comments are sparse and should explain non-obvious product rules or platform constraints. Examples: party size persistence in `src/scripts/boop/boop_db.lua`, skill group prefetching in `src/scripts/boop/boop_skills.lua`, and manifest sort exclusions in `tools/sort_manifests.sh`.
- Avoid comments that repeat the code. Small one-line dispatch files such as `src/aliases/boop/Core/Boop_Set.lua` and `src/triggers/boop/Core/Prompt.lua` do not need comments.

**JSDoc/TSDoc:**
- Not applicable. This repository is Lua/JSON/Muddler-based; no JSDoc/TSDoc pattern is used in `src/` or `tests/`.

## Function Design

**Size:** Use small local helpers for parsing, normalization, and side-effect boundaries inside large modules. `src/scripts/boop/boop_events.lua`, `src/scripts/boop/boop_stats.lua`, and `src/scripts/boop/boop_ui.lua` organize complex behavior as many local helpers plus a smaller public surface.

**Parameters:** Prefer explicit scalar parameters and option tables for flexible calls. Examples: `boop.requestCoreSupports(opts)` in `src/scripts/boop/boop_init.lua`, `boop.walk.start(options)` in `src/scripts/boop/boop_walk.lua`, `boop.rage.onAfflictionTrigger(spec, matchTable, _rawLine)` in `src/scripts/boop/boop_rage.lua`.

**Return Values:** Return booleans for action success/failure where callers branch (`boop.triggers.setEnabled` in `src/scripts/boop/boop_init.lua`, `boop.targets.addWhitelist` as tested by `tests/boop_persistence_spec.lua`), return structured tables for planner/context data (`boop.runtime.context` in `src/scripts/boop/boop_runtime.lua`, `boop.attacks.choose` in `src/scripts/boop/boop_attacks.lua`), and return `nil` plus error text for DB handle failures (`src/scripts/boop/boop_db.lua`).

## Module Design

**Exports:** Initialize each domain with `boop.<domain> = boop.<domain> or {}` and attach public functions to that table, as in `src/scripts/boop/boop_rage.lua`, `src/scripts/boop/boop_safety.lua`, `src/scripts/boop/boop_ih.lua`, and `src/scripts/boop/boop_walk.lua`.

**Barrel Files:** No Lua barrel files are used. `src/scripts/boop/scripts.json`, `src/scripts/boop/attacks/scripts.json`, `src/aliases/boop/aliases.json`, and `src/triggers/boop/triggers.json` are the load/registration surface.

**State Ownership:** Use owned state domains from `boop.runtime.ensureState()` in `src/scripts/boop/boop_runtime.lua`. New code should read and write `boop.state.combat`, `boop.state.targeting`, `boop.state.gold`, `boop.state.queue`, `boop.state.diag`, `boop.state.trace`, `boop.state.rage`, `boop.state.inventory`, `boop.state.ih`, or `boop.state.gag` instead of adding flat `boop.state.<key>` values.

**UI Surface:** Add config/help/mode/preset metadata through `src/scripts/boop/boop_ui_registry.lua` and render through existing helpers in `src/scripts/boop/boop_ui.lua`; keep command help and docs in sync with `README.md` and `UIDESIGN.md`.

**Project Skills:** No project-local skill directories are detected at `.codex/skills/` or `.agents/skills/`.

---

*Convention analysis: 2026-07-09*
