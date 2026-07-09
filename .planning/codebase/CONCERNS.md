# Codebase Concerns

**Analysis Date:** 2026-07-09

## Tech Debt

**Runtime state ownership drift:**
- Issue: `boop.runtime.ensureState()` defines owned state domains in `src/scripts/boop/boop_runtime.lua`, but movement and room handlers still read or write flat state fields such as `vars.room`, `vars.pullState`, `state.walkActive`, `state.diagHold`, `state.goldGetPending`, and `state.currentTargetId`.
- Files: `src/scripts/boop/boop_runtime.lua`, `src/scripts/boop/boop_events.lua`, `src/scripts/boop/boop_walk.lua`, `CODEX.md`
- Impact: room transitions, pull completion, flee return direction, and autowalk blockers can desynchronize from `boop.state.targeting`, `boop.state.combat`, `boop.state.gold`, `boop.state.diag`, and `boop.state.walk`.
- Fix approach: use only the owned domains from `src/scripts/boop/boop_runtime.lua`; move room fields to `boop.state.targeting`, pull state to `boop.state.combat.pullState`, and walk runtime flags to `boop.state.walk`.

**Large multipurpose modules:**
- Issue: `src/scripts/boop/boop_ui.lua` contains dashboard rendering, command parsing, config setters, help rendering, Foxhunt import, pull handling, diagnostics, and theme browsing in one 4504-line file. `src/scripts/boop/boop_stats.lua` similarly combines scope models, persistence-facing aggregation, rendering, and command parsing in one 2936-line file.
- Files: `src/scripts/boop/boop_ui.lua`, `src/scripts/boop/boop_stats.lua`, `src/scripts/boop/boop_ui_registry.lua`
- Impact: small command-surface changes require editing broad, stateful files and increase the chance of breaking unrelated UI or stats behavior.
- Fix approach: split by operator surface and responsibility, using `src/scripts/boop/boop_ui_registry.lua` as the stable contract for config/help routes.

**Manual trigger and manifest maintenance:**
- Issue: The package has 507 trigger Lua scripts and 105 `triggers.json` files under `src/triggers/boop/`; manifest sorting exists, but manifest membership is not broadly tested.
- Files: `src/triggers/boop/`, `tools/sort_manifests.sh`, `tests/boop_ih_spec.lua`, `CODEX.md`
- Impact: a trigger can be added without the matching local manifest entry, or a manifest can reference the wrong script, causing silent Mudlet package omissions.
- Fix approach: add a manifest parity test that checks every manifest entry resolves to an expected Lua file and every trigger/alias script is reachable from a manifest.

**Version synchronization is policy-only:**
- Issue: Version synchronization is required across `mfile.version`, `mfile.title`, and `boop.version`, but CI reads only `mfile` metadata and does not check `src/scripts/boop/boop_init.lua`.
- Files: `mfile`, `src/scripts/boop/boop_init.lua`, `.github/workflows/main.yml`, `AGENTS.md`, `CODEX.md`
- Impact: runtime `boop.version` can diverge from the packaged artifact name without a CI failure.
- Fix approach: add a CI step that parses all three fields and fails unless they match exactly.

## Known Bugs

**Room change handling writes the wrong state object:**
- Symptoms: `boop.onRoomInfo()` updates flat `boop.state.room`, `boop.state.lastRoom`, `boop.state.lastRoomDir`, and `boop.state.movedRooms`, while the rest of the code and tests use `boop.state.targeting.room`, `boop.state.targeting.lastRoomDir`, and related nested fields.
- Files: `src/scripts/boop/boop_events.lua`, `src/scripts/boop/boop_safety.lua`, `tests/boop_event_transitions_spec.lua`
- Trigger: GMCP `gmcp.Room.Info` events during movement.
- Workaround: None in package code; operators can avoid relying on `bflee` until a room-change pass repairs the nested state writes.

**Pull completion does not observe the stored pull state:**
- Symptoms: `boop.ui.pullCommand()` stores active pull state in `boop.state.combat.pullState`, but `boop.onRoomInfo()` checks `boop.state.pullState`; return-to-origin completion can be missed and recovery falls back to the timeout path.
- Files: `src/scripts/boop/boop_ui.lua`, `src/scripts/boop/boop_events.lua`, `tests/boop_pull_spec.lua`
- Trigger: `pull <mobname> <direction>` followed by normal GMCP room changes out and back.
- Workaround: Wait for the pull timeout or manually run `boop on` after confirming the character is back in the origin room.

**Autowalk blockers read stale flat flags:**
- Symptoms: `boop.walk.blockedReason()` checks flat fields such as `state.diagHold`, `state.fleeing`, `state.autoGrabGoldPending`, `state.goldGetPending`, and `state.currentTargetId`, but active state lives in `boop.state.diag`, `boop.state.combat`, `boop.state.gold`, and `boop.state.targeting`.
- Files: `src/scripts/boop/boop_walk.lua`, `src/scripts/boop/boop_runtime.lua`, `tests/boop_walk_spec.lua`
- Trigger: `boop walk start` while diagnose, flee, gold pickup, or active-target state is present.
- Workaround: Use `boop walk stop` before interrupts, gold debugging, or manual target work.

## Security Considerations

**Broad CI permissions and moving dependencies:**
- Risk: The GitHub Actions workflow grants `permissions: write-all`, uses `demonnic/build-with-muddler@main`, installs LuaRocks packages at runtime, and clones `https://github.com/demonnic/test-in-mudlet.git` without a commit pin.
- Files: `.github/workflows/main.yml`
- Current mitigation: The workflow runs on `pull_request` and `push` and executes Mudlet/Busted tests before uploading artifacts.
- Recommendations: Reduce job permissions to the minimum required, pin third-party actions and cloned test assets to immutable SHAs, and keep PR commenting permissions scoped to pull requests.

**Remote Mudlet package install is unpinned:**
- Risk: `boop walk install` installs the latest `demonnicAutoWalker.mpackage` URL through Mudlet without a checksum or pinned release version.
- Files: `src/scripts/boop/boop_walk.lua`, `README.md`
- Current mitigation: The install is an explicit operator command and Mudlet may prompt before package installation.
- Recommendations: Pin a known release URL, display the exact package URL before install, and document the trusted version in `README.md`.

**User-controlled command fragments are sent directly:**
- Risk: Saved values such as `goldPack`, assist leader names, leap directions, and the configured game separator are concatenated into game commands. Pull validates the mob name against the separator and newlines, but gold-pack and several other command fragments do not share a central validator.
- Files: `src/scripts/boop/boop_ui.lua`, `src/scripts/boop/boop_events.lua`, `src/scripts/boop/boop_util.lua`
- Current mitigation: Most values are operator-entered, and `pull` rejects mob names containing the configured separator or newline characters.
- Recommendations: Add a shared command-token validator for container IDs, leader names, directions, separators, and any future command fragment before values are persisted or sent.

**Party whitelist share trust is permissive without a leader:**
- Risk: Incoming whitelist-share packets from any non-self party member are accepted into pending state when `assistLeader` is blank; applying `overwrite` can replace an area's whitelist.
- Files: `src/scripts/boop/boop_targets.lua`, `src/triggers/boop/Core/Party_Whitelist_Share.lua`, `tests/boop_whitelist_share_spec.lua`
- Current mitigation: Incoming shares remain pending until the operator runs `boop whitelist receive merge|merge-reorder|overwrite`.
- Recommendations: Require an explicit trusted sender for whitelist sharing, show sender/area/count prominently before apply, and cap incoming packet counts.

## Performance Bottlenecks

**Mob XP persistence scans area rows per observation:**
- Problem: `boop.db.recordMobXpObservation()` fetches all mob XP rows for an area and then scans for matching party size, mob name, and XP value.
- Files: `src/scripts/boop/boop_db.lua`, `src/scripts/boop/boop_stats.lua`
- Cause: The storage schema indexes broad columns but the write path fetches only by area before filtering in Lua.
- Improvement path: Fetch or index by area, party size, name, and XP bucket; keep a small in-memory dirty cache during a hunt and flush aggregated counts in batches.

**Stats renderers build and sort full result sets:**
- Problem: stats views collect all area, mob, target, ability, crit, rage, and record rows before limiting display output.
- Files: `src/scripts/boop/boop_stats.lua`, `tests/boop_stats_spec.lua`
- Cause: The stats model is optimized for rich local summaries rather than bounded incremental rendering.
- Improvement path: Apply limits earlier, cache sorted summaries per scope during a render, and invalidate those summaries only when scope counters change.

**Large trigger set increases every-line matching cost:**
- Problem: Gag, shield, and rage-affliction coverage is broad: 277 gag trigger scripts, 116 shield trigger scripts, and 101 rage trigger scripts live under `src/triggers/boop/`.
- Files: `src/triggers/boop/Gag/`, `src/triggers/boop/Shield/`, `src/triggers/boop/Rage/`
- Cause: Each supported class adds text-line triggers in parallel categories.
- Improvement path: Prefer shared trigger handlers and data-driven class pattern tables when adding new broad coverage, and keep live profiling focused on gag-heavy hunting sessions.

## Fragile Areas

**Gag summarization is timing-sensitive:**
- Files: `src/scripts/boop/boop_gag.lua`, `src/triggers/boop/Gag/`, `tests/boop_gag_spec.lua`
- Why fragile: Attack, damage, crit, balance, slain, and XP lines are correlated through pending state and short timers; new Achaea line variants can leave lines visible, delete the wrong line, or emit summaries in the wrong order.
- Safe modification: Add a replay-style Busted case in `tests/boop_gag_spec.lua` for every new live line shape before changing timer or merge logic.
- Test coverage: Good unit coverage exists for many line sequences, but live combat logs remain the main source for missing variants.

**Attack profile contracts are data-heavy:**
- Files: `src/scripts/boop/attacks/`, `src/scripts/boop/boop_attacks.lua`, `tests/boop_profile_matrix_spec.lua`, `tests/boop_rage_contract_spec.lua`
- Why fragile: Profile tables encode class/spec standards, rage descriptions, conditional needs, skill groups, shieldbreaks, openers, and command prefixes in a compact data shape.
- Safe modification: Add or update profile-matrix and rage-contract cases before changing a profile's table shape.
- Test coverage: Broad profile coverage exists, but game text and skill availability still depend on GMCP values observed in Mudlet.

**Load order is runtime-sensitive:**
- Files: `src/scripts/boop/scripts.json`, `tools/sort_manifests.sh`, `CODEX.md`
- Why fragile: `src/scripts/boop/scripts.json` intentionally stays unsorted because bootstrap, runtime, state, registry, UI, events, and attack registration depend on load order.
- Safe modification: Treat new script insertion as a dependency decision and run the Mudlet Busted suite after any order change.
- Test coverage: CI exercises the built package, but there is no dedicated load-order lint that explains dependency violations before Mudlet import.

**Mudlet DB schema changes are opportunistic:**
- Files: `src/scripts/boop/boop_db.lua`, `tests/boop_db_spec.lua`, `tests/boop_persistence_spec.lua`
- Why fragile: New sheets are created by helper functions and older missing-sheet paths degrade to warnings; there is no explicit schema version or migration ledger.
- Safe modification: Add schema-version metadata before adding more persistent tables or changing row meanings.
- Test coverage: Guard-path and save-hook tests exist; full DB migration coverage is limited.

## Scaling Limits

**Whitelist share packets have no TTL or total cap:**
- Current capacity: Data packets are capped by a 180-character line limit, but `incomingWhitelistShares` stores entries until an end packet or manual replacement.
- Limit: Malformed or excessive party packets can grow pending share state during a session.
- Scaling path: Add a maximum expected count, maximum packets per token, sender allowlist, and expiry timer to `src/scripts/boop/boop_targets.lua`.

**Stats detail structures grow with hunting diversity:**
- Current capacity: `newScope()` stores unbounded `areas`, `abilities`, `targetStats`, and rage breakdown tables per scope.
- Limit: Long sessions with many areas, mobs, and ability variants increase memory and rendering cost in `src/scripts/boop/boop_stats.lua`.
- Scaling path: Add caps or archival rules for high-cardinality detail tables, while preserving aggregate lifetime totals.

**Trace history is intentionally capped:**
- Current capacity: `boop.trace.log()` keeps the last 100 trace entries.
- Limit: Long reproduction sessions can lose the decision that caused a problem before the operator runs `boop trace show`.
- Scaling path: Add a configurable trace limit or optional file-backed export in `src/scripts/boop/boop_util.lua`.

## Dependencies at Risk

**demonnicAutoWalker:**
- Risk: Walk behavior depends on an external package and event names such as `demonwalker.arrived`, `demonwalker.finished`, and `demonwalker.move`.
- Impact: Walker API changes can break `boop walk` without changing boop source.
- Migration plan: Keep `src/scripts/boop/boop_walk.lua` behind a small adapter and add contract tests in `tests/boop_walk_spec.lua`.

**Muddler build action:**
- Risk: CI uses `demonnic/build-with-muddler@main`, which can change independently of this repo.
- Impact: Package output or build behavior can change without a local code change.
- Migration plan: Pin the action to a known commit or vendor a local build wrapper documented in `CODEX.md`.

**Mudlet test profile and AppImage:**
- Risk: CI downloads or restores a Mudlet AppImage and clones an external Mudlet test profile.
- Impact: Test behavior can shift if the profile repository or AppImage changes.
- Migration plan: Pin `test-in-mudlet` and document the supported Mudlet version in `tests/README.md` and `.github/workflows/main.yml`.

## Missing Critical Features

**Automated version sync gate:**
- Problem: The required version sync rule is not enforced by CI.
- Blocks: Safe release automation and reliable package/runtime version reporting.
- Files: `mfile`, `src/scripts/boop/boop_init.lua`, `.github/workflows/main.yml`

**Active walk regression suite:**
- Problem: `tests/boop_walk_spec.lua` contains only a disabled placeholder while `boop walk` controls movement automation.
- Blocks: Confident fixes to autowalk state, blocker checks, event integration, and external walker adapter behavior.
- Files: `tests/boop_walk_spec.lua`, `src/scripts/boop/boop_walk.lua`, `src/scripts/boop/boop_events.lua`

**Manifest parity validation:**
- Problem: There is no full-repo test for `scripts.json`, `aliases.json`, and `triggers.json` membership.
- Blocks: Confident trigger, alias, and script additions across the Muddler package tree.
- Files: `src/scripts/boop/scripts.json`, `src/aliases/`, `src/triggers/`, `tools/sort_manifests.sh`

## Test Coverage Gaps

**Autowalk integration:**
- What's not tested: Start/stop state, blocker reasons, room-settled fallback, `demonwalker.move` event emission, and gold/diag/flee interaction.
- Files: `tests/boop_walk_spec.lua`, `src/scripts/boop/boop_walk.lua`
- Risk: Movement automation can advance at unsafe times or fail to resume when rooms clear.
- Priority: High

**State-domain migration regressions:**
- What's not tested: A focused assertion that `boop.onRoomInfo()` writes only `boop.state.targeting.*` and `boop.state.combat.*`, and that no live code relies on removed flat state keys.
- Files: `tests/boop_event_transitions_spec.lua`, `tests/boop_pull_spec.lua`, `src/scripts/boop/boop_events.lua`, `src/scripts/boop/boop_walk.lua`
- Risk: Room, pull, flee, and walk state regressions bypass the runtime coordinator.
- Priority: High

**Command-fragment validation:**
- What's not tested: Pack names, assist leaders, directions, and separators containing newlines, command separators, or other unsafe command fragments.
- Files: `tests/boop_ui_spec.lua`, `tests/boop_gold_spec.lua`, `tests/boop_pull_spec.lua`, `src/scripts/boop/boop_ui.lua`
- Risk: Operator-entered config can produce unintended game commands during automatic actions.
- Priority: Medium

**Manifest and generated package coverage:**
- What's not tested: Every source Lua file is included in a Muddler manifest and every manifest script entry resolves to a source file.
- Files: `src/scripts/`, `src/aliases/`, `src/triggers/`, `tests/boop_ih_spec.lua`
- Risk: A feature can pass source-level review but be absent from the built Mudlet package.
- Priority: Medium

**Live combat log replay breadth:**
- What's not tested: Broad real-world line streams for gag summaries, shield state, rage affliction ingestion, stats attribution, and target lifecycle.
- Files: `tests/boop_gag_spec.lua`, `tests/boop_rage_ingestion_spec.lua`, `tests/boop_shields_spec.lua`, `tests/boop_stats_spec.lua`, `tests/README.md`
- Risk: Supported class profiles can miss new or rare Achaea line variants.
- Priority: Medium

---

*Concerns audit: 2026-07-09*
