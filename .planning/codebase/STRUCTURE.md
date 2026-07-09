# Codebase Structure

**Analysis Date:** 2026-07-09

## Directory Layout

```text
boop/
|-- AGENTS.md                 # Repository-local agent instructions
|-- CODEX.md                  # Codex workflow, structure, versioning, and project memory
|-- DESIGN.md                 # Product scope, architecture intent, data model, and flow notes
|-- README.md                 # User-facing command reference and package notes
|-- UIDESIGN.md               # UI/UX contract for command surfaces
|-- LICENSE                   # Project license
|-- mfile                     # Muddler package metadata and synchronized version field
|-- src/                      # Mudlet package source of truth
|   |-- scripts/              # Lua modules and script manifests
|   |   |-- scripts.json      # Top-level scripts manifest
|   |   `-- boop/             # Runtime modules and attack profiles
|   |-- aliases/              # Mudlet alias manifests and thin alias scripts
|   |   |-- aliases.json      # Top-level aliases manifest
|   |   `-- boop/             # Command category folders
|   `-- triggers/             # Mudlet trigger manifests and thin trigger scripts
|       |-- triggers.json     # Top-level trigger manifest; boop folder inactive by default
|       `-- boop/             # Trigger category/class folders
|-- tests/                    # Real-Mudlet busted specs and support helper
|-- tools/                    # Repository maintenance scripts
|-- .github/workflows/        # CI build/test workflow
|-- Basher/                   # Reference implementation material, not packaged boop runtime
|-- Bashing/                  # Reference implementation material, not packaged boop runtime
|-- Foxhunt/                  # Reference implementation material, not packaged boop runtime
`-- .planning/codebase/       # Generated codebase maps for GSD workflows
```

## Directory Purposes

**Root:**
- Purpose: Project docs, package metadata, CI, source, tests, and reference folders.
- Contains: `README.md`, `DESIGN.md`, `CODEX.md`, `UIDESIGN.md`, `mfile`, `src/`, `tests/`, `tools/`, `.github/workflows/main.yml`.
- Key files: `mfile`, `CODEX.md`, `README.md`, `DESIGN.md`.

**`src/`:**
- Purpose: Packaged source of truth for boop.
- Contains: Mudlet scripts, aliases, triggers, and manifests.
- Key files: `src/scripts/scripts.json`, `src/aliases/aliases.json`, `src/triggers/triggers.json`.

**`src/scripts/`:**
- Purpose: Top-level Mudlet script folder manifest.
- Contains: `src/scripts/scripts.json` with the `boop` folder entry.
- Key files: `src/scripts/scripts.json`.

**`src/scripts/boop/`:**
- Purpose: Runtime Lua modules loaded into the global `boop` namespace.
- Contains: Bootstrap, utilities, DB, runtime state, targets, attacks, safety, stats, UI, events, walk, theme, and profile registry.
- Key files: `src/scripts/boop/boop_init.lua`, `src/scripts/boop/boop_runtime.lua`, `src/scripts/boop/boop_events.lua`, `src/scripts/boop/boop_targets.lua`, `src/scripts/boop/boop_attacks.lua`, `src/scripts/boop/boop_ui.lua`, `src/scripts/boop/scripts.json`.

**`src/scripts/boop/attacks/`:**
- Purpose: One data profile per supported class/form.
- Contains: Lua files that call `boop.attacks.register()` plus `src/scripts/boop/attacks/scripts.json`.
- Key files: `src/scripts/boop/attacks/occultist.lua`, `src/scripts/boop/attacks/infernal.lua`, `src/scripts/boop/attacks/scripts.json`.

**`src/aliases/`:**
- Purpose: Top-level Mudlet alias manifest.
- Contains: `src/aliases/aliases.json` and the `boop` alias folder.
- Key files: `src/aliases/aliases.json`.

**`src/aliases/boop/`:**
- Purpose: Command entry points grouped by operator workflow.
- Contains: Category folders `Combat`, `Core`, `Diagnostics`, `Loot`, `Queueing`, `Stats`, and `Targeting`, each with `aliases.json` and thin Lua scripts.
- Key files: `src/aliases/boop/aliases.json`, `src/aliases/boop/Core/Boop.lua`, `src/aliases/boop/Core/Boop_Control.lua`, `src/aliases/boop/Combat/Diag.lua`.

**`src/triggers/`:**
- Purpose: Top-level Mudlet trigger manifest.
- Contains: `src/triggers/triggers.json` and the `boop` trigger folder.
- Key files: `src/triggers/triggers.json`.

**`src/triggers/boop/`:**
- Purpose: Text/prompt triggers grouped by behavior and class/category.
- Contains: `Core`, `Diag`, `Gag`, `Gold`, `IH`, `Rage`, and `Shield` trigger folders.
- Key files: `src/triggers/boop/triggers.json`, `src/triggers/boop/Core/triggers.json`, `src/triggers/boop/Rage/triggers.json`, `src/triggers/boop/Gag/triggers.json`, `src/triggers/boop/Shield/triggers.json`.

**`src/triggers/boop/Gag/`:**
- Purpose: Attack-line summary trigger coverage.
- Contains: Class/category subfolders with local `triggers.json` files and generated thin scripts calling `boop.gag.onAttackLine()`.
- Key files: `src/triggers/boop/Gag/Occultist/Occultist_Battlerage_Harry.lua`, `src/triggers/boop/Gag/Combat/triggers.json`, `src/triggers/boop/Gag/Mobs/triggers.json`.

**`src/triggers/boop/Rage/Afflictions/`:**
- Purpose: Rage-affliction gain/loss trigger coverage.
- Contains: Class/category subfolders with local `triggers.json` files and scripts calling `boop.rage.onAfflictionTrigger()`.
- Key files: `src/triggers/boop/Rage/Afflictions/Occultist/Occultist_Temperance.lua`, `src/triggers/boop/Rage/Afflictions/General/triggers.json`.

**`src/triggers/boop/Shield/`:**
- Purpose: Shield-down/no-shield trigger coverage.
- Contains: Class/category subfolders with local `triggers.json` files and scripts calling `boop.targets.onShieldDownTrigger()`.
- Key files: `src/triggers/boop/Shield/Occultist/Occultist_Battlerage_Ruin.lua`, `src/triggers/boop/Shield/General/triggers.json`.

**`tests/`:**
- Purpose: Real-Mudlet busted regression suite.
- Contains: `tests/*_spec.lua`, `tests/README.md`, and `tests/support/boop_test_helper.lua`.
- Key files: `tests/boop_runtime_spec.lua`, `tests/boop_planner_spec.lua`, `tests/boop_targets_spec.lua`, `tests/boop_ui_spec.lua`, `tests/support/boop_test_helper.lua`.

**`tools/`:**
- Purpose: Maintenance helpers.
- Contains: `tools/sort_manifests.sh`.
- Key files: `tools/sort_manifests.sh`.

**`.github/workflows/`:**
- Purpose: Build and test automation.
- Contains: GitHub Actions workflow that builds with Muddler and runs busted in Mudlet.
- Key files: `.github/workflows/main.yml`.

**`Basher/`, `Bashing/`, `Foxhunt/`:**
- Purpose: Reference implementations and source material for behavior/profile extraction.
- Contains: Separate source trees under each folder.
- Key files: Reference-only; do not place packaged boop code here.

## Key File Locations

**Entry Points:**
- `src/scripts/boop/boop_bootstrap.lua`: Calls `boop.bootstrap()` after scripts and attack profiles load.
- `src/scripts/boop/boop_init.lua`: Defines defaults, bootstrap, GMCP support requests, trigger folder controls, and version.
- `src/aliases/boop/Core/Boop.lua`: `boop` home dashboard entry.
- `src/aliases/boop/Core/Boop_Control.lua`: `boop control` router.
- `src/triggers/boop/Core/Prompt.lua`: Prompt trigger entry into `boop.onPrompt()`.
- `src/scripts/boop/boop_events.lua`: GMCP and Mudlet event registration.

**Configuration:**
- `mfile`: Package `version`, `title`, `package`, and Muddler output metadata.
- `src/scripts/boop/boop_init.lua`: `boop.defaults` and `boop.version`.
- `src/scripts/boop/boop_ui_registry.lua`: Config schema, setters, modes, presets, help topics, and config screen definitions.
- `src/scripts/boop/boop_db.lua`: DB schema and config/list/stat persistence.
- `src/scripts/boop/scripts.json`: Load-order-sensitive script manifest.

**Core Logic:**
- `src/scripts/boop/boop_runtime.lua`: Domain state defaults, context snapshots, tick/prompt step logic, and effect application.
- `src/scripts/boop/boop_events.lua`: GMCP adapters, gold queue state, inventory/wield tracking, prequeue, tick and prompt entry points.
- `src/scripts/boop/boop_targets.lua`: Denizen tracking, target selection, lists, shield tracking, party target calls, whitelist share protocol.
- `src/scripts/boop/boop_attacks.lua`: Combat planner, rage modes, standard/rage selection, class modifiers, action execution.
- `src/scripts/boop/boop_rage.lua`: Rage readiness fallback, free-rage flag, rage sampling, and affliction trigger ingestion.
- `src/scripts/boop/boop_safety.lua`: Auto-flee threshold and flee command chain.
- `src/scripts/boop/boop_stats.lua`: Session/login/trip/lifetime stats and dashboards.
- `src/scripts/boop/boop_ui.lua`: Command handlers, dashboards, config/help/party/stat surfaces.
- `src/scripts/boop/boop_gag.lua`: Attack/gold/mob summary output and stats hooks.

**Testing:**
- `tests/README.md`: Coverage map for the busted suite.
- `tests/support/boop_test_helper.lua`: Test reset/setup helpers.
- `tests/boop_runtime_spec.lua`: Runtime domain/effect contract tests.
- `tests/boop_planner_spec.lua`: Planner/modifier/execution tests.
- `tests/boop_profile_matrix_spec.lua`: Class/spec profile matrix tests.
- `tests/boop_event_transitions_spec.lua`: GMCP room/target transition tests.

**Build/CI:**
- `.github/workflows/main.yml`: CI Muddler build and in-Mudlet busted test run.
- `tools/sort_manifests.sh`: Safe manifest sorter for aliases, triggers, and attack scripts.

## Naming Conventions

**Files:**
- Runtime modules use lowercase `boop_<domain>.lua`: `src/scripts/boop/boop_targets.lua`, `src/scripts/boop/boop_attacks.lua`.
- Attack profiles use lowercase class/form keys with underscores: `src/scripts/boop/attacks/blue_dragon.lua`, `src/scripts/boop/attacks/air_elemental_lord.lua`.
- Alias scripts use Mudlet display names converted to underscores and Pascal words: `src/aliases/boop/Core/Boop_Control.lua`, `src/aliases/boop/Combat/Touch_Shield.lua`.
- Trigger scripts use category/class/ability names with underscores: `src/triggers/boop/Gag/Occultist/Occultist_Battlerage_Harry.lua`.
- Tests use `boop_<area>_spec.lua`: `tests/boop_targets_spec.lua`, `tests/boop_runtime_spec.lua`.
- Manifest files are named `scripts.json`, `aliases.json`, or `triggers.json` in each Mudlet object folder.

**Directories:**
- Alias category directories use workflow labels: `src/aliases/boop/Core`, `src/aliases/boop/Combat`, `src/aliases/boop/Targeting`.
- Trigger behavior directories use functional labels: `src/triggers/boop/Core`, `src/triggers/boop/Rage`, `src/triggers/boop/Shield`, `src/triggers/boop/Gag`.
- Class trigger directories use class/category display names with underscores: `src/triggers/boop/Gag/Dragon_Blue_Dragon`, `src/triggers/boop/Shield/Weaponmastery_Two_Handed`.
- Rage affliction triggers nest class folders under `src/triggers/boop/Rage/Afflictions/`.

## Where to Add New Code

**New Runtime Feature:**
- Primary code: Add or extend a domain module under `src/scripts/boop/`.
- State: Add defaults to `DOMAIN_DEFAULTS` in `src/scripts/boop/boop_runtime.lua`.
- Tests: Add a focused `tests/boop_<feature>_spec.lua` and use `tests/support/boop_test_helper.lua`.

**New Command:**
- Alias manifest: Add regex entry to the appropriate `src/aliases/boop/<Category>/aliases.json`.
- Alias script: Add a thin script in the same category, for example `src/aliases/boop/Core/New_Command.lua`.
- Handler: Add command behavior to `src/scripts/boop/boop_ui.lua` or the owning domain module.
- Registry/help: Add config/help/preset data to `src/scripts/boop/boop_ui_registry.lua` when the command is user-facing.
- Docs: Update `README.md` and `UIDESIGN.md` for command-surface changes.

**New Config Setting:**
- Default: Add to `boop.defaults` in `src/scripts/boop/boop_init.lua`.
- Persistence: Let `boop.db.loadConfig()` / `boop.db.saveConfig()` in `src/scripts/boop/boop_db.lua` handle normal values.
- UI registry: Add schema and setter entries in `src/scripts/boop/boop_ui_registry.lua`.
- UI surface: Add display/control wiring in `src/scripts/boop/boop_ui.lua`.
- Tests: Extend `tests/boop_persistence_spec.lua`, `tests/boop_ui_registry_spec.lua`, or a feature-specific spec.

**New Class/Profile:**
- Implementation: Add `src/scripts/boop/attacks/<class_key>.lua` with `boop.attacks.register("<class_key>", profile)`.
- Manifest: Add the profile to `src/scripts/boop/attacks/scripts.json`.
- Planner support: Add shared planner/modifier behavior to `src/scripts/boop/boop_attacks.lua` only when profile data cannot express it.
- Tests: Extend `tests/boop_profiles_spec.lua`, `tests/boop_profile_matrix_spec.lua`, `tests/boop_rage_contract_spec.lua`, and `tests/boop_openers_contract_spec.lua` as applicable.

**New GMCP Event Handling:**
- Registration: Add the event to `boop.events.register()` in `src/scripts/boop/boop_events.lua`.
- Handler: Add a `boop.on<EventName>()` function in `src/scripts/boop/boop_events.lua` if it coordinates multiple domains, or in the owning domain module if isolated.
- State: Use existing domain state or add a `DOMAIN_DEFAULTS` field in `src/scripts/boop/boop_runtime.lua`.
- Tests: Add or extend event specs such as `tests/boop_event_transitions_spec.lua`.

**New Text Trigger:**
- Category: Choose `src/triggers/boop/Core`, `Diag`, `Gold`, `IH`, `Rage`, `Shield`, or `Gag`.
- Class-specific gag/shield/rage-affliction triggers: Add files under the class-local folder and update that folder's `triggers.json`.
- Script body: Keep it thin and call `boop.gag.onAttackLine()`, `boop.rage.onAfflictionTrigger()`, `boop.targets.onShieldDownTrigger()`, or another domain handler.
- Manifest: Update the local `triggers.json`; use `tools/sort_manifests.sh` for safe sorting.

**New UI Screen or Menu Row:**
- Registry data: Add schema/routes/actions/help data to `src/scripts/boop/boop_ui_registry.lua`.
- Renderer/handler: Add rendering or action code to `src/scripts/boop/boop_ui.lua`.
- Style: Use existing `cecho`/`cechoLink` helpers, sectioned rows, and boop theme tags.
- Tests: Extend `tests/boop_ui_spec.lua`, `tests/boop_ui_registry_spec.lua`, or `tests/boop_menu_wiring_spec.lua`.

**New Persistence Table:**
- Schema/init: Add schema creation and verification helpers to `src/scripts/boop/boop_db.lua`.
- Domain API: Expose save/load helpers through `boop.db.*`; do not call `db:*` directly from UI or alias scripts.
- Tests: Add DB guard and persistence coverage in `tests/boop_db_spec.lua` or `tests/boop_persistence_spec.lua`.

**Utilities:**
- Shared string/output/action helpers: `src/scripts/boop/boop_util.lua`.
- Theme definitions: `src/scripts/boop/boop_theme.lua`.
- Manifest maintenance: `tools/sort_manifests.sh`.

## Special Directories

**`build/`:**
- Purpose: Generated Muddler output when present.
- Generated: Yes.
- Committed: Not source of truth.
- Guidance: Do not edit built artifacts; make package changes under `src/`.

**`Basher/`, `Bashing/`, `Foxhunt/`:**
- Purpose: Reference source material for behavior and trigger/profile extraction.
- Generated: No.
- Committed: Yes.
- Guidance: Do not add packaged boop runtime code here.

**`.planning/codebase/`:**
- Purpose: Generated architecture/structure/quality/stack maps for GSD planning.
- Generated: Yes.
- Committed: Project-dependent planning artifact.
- Guidance: Mapper runs write uppercase markdown files here only.

**`tests/`:**
- Purpose: Real-Mudlet busted specs.
- Generated: No.
- Committed: Yes.
- Guidance: Add focused specs for runtime, planner, GMCP, UI, and persistence behavior changes.

**`.github/workflows/`:**
- Purpose: CI build and Mudlet test runner.
- Generated: No.
- Committed: Yes.
- Guidance: Keep workflow changes separate from package behavior unless build/test requirements change.

**`tools/`:**
- Purpose: Local maintenance scripts.
- Generated: No.
- Committed: Yes.
- Guidance: `tools/sort_manifests.sh` is safe for aliases, triggers, and attack profile manifests; it intentionally skips `src/scripts/boop/scripts.json`.

---

*Structure analysis: 2026-07-09*
