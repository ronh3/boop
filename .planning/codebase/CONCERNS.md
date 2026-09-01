<!-- refreshed: 2026-08-30 -->
# Codebase Concerns

**Analysis Date:** 2026-08-30
**Source verified against:** commit `96384bc` (package `0.1.490`)

> **Authoritative sources:** `/ARCHITECTURE.md` (as-is, including the API-surface classification), `/PERFORMANCE.md` (hot-path findings and the performance budget), `/REFACTOR-ROADMAP.md` (sequenced remediation). This file is a planning summary.

## Tech Debt

**The module dependency graph is a single strongly-connected component.**
- Issue: of 20 script modules, `boop_bootstrap` is the composition root (zero incoming edges); the other 19 form a single SCC in which every module can reach every other. There are **nineteen directly reciprocal pairs** (`A ↔ B`) plus many longer directed cycles. Three modules concentrate the problem: `boop_runtime` holds the combat loop and calls outward into `attacks`, `targets`, `safety`, and `walk`; `boop_util` holds the command dispatcher and calls into `runtime`, `gag`, and `rage`; and `boop_events` owns 42 top-level `boop.<function>` symbols that six other modules call, accounting for six pairs on its own. A namespace-only graph misses those six — top-level attribution is required.
- Files: `boop_runtime.lua`, `boop_util.lua`, `boop_events.lua`, and every decision module.
- Impact: no module can be reasoned about or tested in isolation; a change anywhere can reach anywhere.
- Fix approach: `/REFACTOR-ROADMAP.md` Phase 3 closes five pairs, Phase 4 nine, Phase 5 one, and **Phase 8 the final four**. The graph becomes acyclic at Phase 8, which is the architecture stopping point; DAG enforcement is staged until then.

**Large multipurpose modules.**
- Issue: `boop_ui.lua` (5546) contains screens, config mutation, the interrupt/pull state machine, and command routing. `boop_runtime.lua` (4167) contains six subsystems. `boop_events.lua` (3429) contains the gold pipeline, inventory tracking, the prequeue engine, and the tick entry point. `boop_stats.lua` (2948) is roughly 45% model and 55% presentation.
- Impact: small changes require editing broad, stateful files.
- Fix approach: Phases 3-12. Note that file size itself is **not** a runtime problem — see `/PERFORMANCE.md` §3.

**No single command egress point.**
- Issue: 15 production `send()` call sites across seven files, plus eight `sendGMCP()` calls across three.
- Files: `boop_util.lua`, `boop_events.lua`, `boop_targets.lua`, `boop_safety.lua`, `boop_rage.lua`, `boop_runtime.lua`, `boop_ui.lua`.
- Impact: outbound behaviour cannot be audited, instrumented, or gated in one place.
- Fix approach: Phase 4d moves the dispatcher out of `boop_util`; Phase 6 migrates the remaining fourteen sites through `boop.wire`.

**Divergent reimplementations of shared concepts.**
- Issue: `currentRoomId()` has five implementations with four different semantics; `currentClass()` has three with divergent precedence and normalization; `copySourceAuthority` has five copies, `deepCopy` four, `nowSeconds` four.
- Impact: behaviour depends on which module asks.
- Fix approach: Phase 7.

**`boop_state.lua` puts a service function under the data-only state tree.**
- Issue: `boop.state.init()` both violates the "no functions under `boop.state`" intent and performs a second registry attachment, duplicating the one at the tail of `boop_ui_registry.lua`. It is called from `boop.bootstrap()` (`boop_init.lua:164`) and from `tests/support/boop_test_helper.lua:168`.
- Fix approach: Phase 4b retires the file, moves both registry attachments to the composition root, replaces the call with `boop.runtime.ensureState()`, and migrates the test helper to the production initialization path.

**Manual trigger and manifest maintenance.**
- Issue: 513 trigger scripts across 107 manifests. `tools/check_release_gates.py --check manifests` catches orphans and unresolved entries, but membership correctness still depends on the author.
- Fix approach: keep the manifest gate in the pre-commit routine.

## Known Bugs

None outstanding at the architectural level. Five candidate defects were identified during the 2026-08-30 audit and are tracked as F1-F5 in `/REFACTOR-ROADMAP.md` §2:

| # | Finding | Status |
|---|---|---|
| F1 | `boop_init.lua:118` divides `getEpoch()` by 1000 while every `nowSeconds()` treats it as seconds, so the `requestCoreSupports` throttle never engages | Approved, Phase 2c |
| F2 | `boop_ui.lua:72`'s `currentClass()` does not lowercase and defaults to `"unknown"`; latent because `profileReadiness` lowercases internally | Approved, Phase 7 |
| F3 | `boop.onVitals` lacks an `enabled` guard, so a disabled boop still builds two contexts per prompt | Approved, Phase 2c |
| F4 | `markUnnamableMaulUsed` runs only on the direct dispatch path | Investigate only; trigger-driven handlers may already cover the queued path |
| F5 | `schedulePrequeue` returns `nil` at `boop_events.lua:3146` where every other exit returns `false` | Approved, Phase 3 |
| F6 | `init ↔ ui`: `boop.bootstrap()` calls `boop.ui.status("ready")` at `boop_init.lua:207-208` | Approved, Phase 4a |

**Previously listed here and now resolved:** room handling writing flat `boop.state.room`; pull completion reading `boop.state.pullState`; autowalk blockers reading flat state flags. All three were fixed when the flat-state bridge was removed. `boop.onRoomInfo` writes `targeting.*`, and `boop.walk.blockedReason()` delegates to `evaluateAllClear`.

## Security Considerations

**Broad CI permissions and unpinned dependencies.**
- Risk: `.github/workflows/main.yml` grants `permissions: write-all`, uses `demonnic/build-with-muddler@main`, and clones `demonnic/test-in-mudlet` without a commit pin.
- Recommendation: reduce job permissions, pin third-party actions and cloned test assets to immutable SHAs.

**Remote Mudlet package install is unpinned.**
- Risk: `boop walk install` installs the latest `demonnicAutoWalker.mpackage` URL without a checksum or pinned release.
- Mitigation: the install is an explicit operator command.
- Recommendation: pin a known release URL and display it before install.

**User-controlled command fragments are concatenated into game commands.**
- Risk: `goldPack`, assist leader names, leap directions, and the configured separator reach `send()` without a shared validator. `pull` validates its mob name; most others do not.
- Files: `boop_ui.lua`, `boop_events.lua`, `boop_util.lua`.
- Recommendation: add a shared command-token validator. Phase 6 creates the natural home for it, since every outbound command will pass through `boop.wire`.

**Party whitelist share trust is permissive without a leader.**
- Risk: with `assistLeader` blank, any non-self party member's share packets enter pending state; applying `overwrite` replaces an area's whitelist.
- Mitigation: incoming shares stay pending until an explicit `boop whitelist receive`.
- Recommendation: require a trusted sender, show sender/area/count before apply, cap incoming packet counts.

## Performance Bottlenecks

Full analysis in `/PERFORMANCE.md`. **No measurements have been taken**; the items below are static-analysis findings.

**Synchronous SQLite on the retarget path.**
- Problem: `boop.db.saveStats()` performs 13 `db:fetch` plus up to 13 `db:update` per call, and `boop.stats.onTargetSet` calls `incrementCounter` three times, so **one retarget triggers 39 synchronous indexed SELECTs plus writes**.
- Files: `boop_db.lua:587`, `boop_stats.lua`.
- Improvement path: dirty-flag with a 5-second coalesced flush and immediate flush on the observable boundaries. `/REFACTOR-ROADMAP.md` Phase 2b.

**Room-item deep copies on every context build.**
- Problem: `roomObservationSnapshot()` deep-copies `acceptedItems`, `fenceQueue`, `lastCompletedFence`, and `activeApplication` (itself holding a copy of the room item list), while `readinessSnapshot()` reads four scalar fields from the result.
- Improvement path: a non-copying readiness snapshot. Phase 2a.

**`ensureState()` revalidates 13 domains on every call**, and `runtime.context()` calls it nine times — roughly 1,100 hash lookups per context, two to four contexts per prompt.
- Improvement path: schema-version sentinel plus domain integrity check, full hydration only on failure. Phase 2a.

**Duplicate ticks per prompt.** `onVitals` and `onPrompt` each drive a full decision pass; the `canAct` limiter discards the second dispatch but not the work. Measurement-gated; see `/PERFORMANCE.md` §5B.

**Large trigger set increases every-line matching cost.** 885 patterns across 512 triggers, all enabled together, roughly 95% class-irrelevant for any given character. Engine-side and invisible to Lua profiling. Deferred and measurement-gated; see `/PERFORMANCE.md` §5A, which records the naming-collision and mapping risks that make scoping non-trivial.

**Mob XP persistence scans area rows per observation.** `boop.db.recordMobXpObservation()` fetches all rows for an area then filters in Lua.

**Stats renderers build and sort full result sets** before limiting display output.

## Fragile Areas

**Gag summarization is timing-sensitive.**
- Files: `boop_gag.lua`, `src/triggers/boop/Gag/`, `tests/boop_gag_spec.lua`.
- Why: attack, damage, crit, balance, slain, and XP lines are correlated through pending state and short timers.
- Safe modification: add a replay case for every new live line shape before changing timer or merge logic.

**The queued-standard lifecycle.**
- Files: `boop_runtime.lua` (dispatch generations, baseline, candidate disposition, grace, retry, terminals).
- Why: the most intricate invariant in the package, with generation ownership and quarantine semantics.
- Safe modification: `tests/boop_prequeue_spec.lua` (1255 lines) is the contract. Extend it first.

**Attack profile contracts are data-heavy.**
- Files: `src/scripts/boop/attacks/`, `tests/boop_profile_matrix_spec.lua`, `tests/boop_rage_contract_spec.lua`.
- Safe modification: update the matrix and rage-contract cases before changing a profile's table shape.

**Load order is runtime-sensitive.**
- Files: `src/scripts/boop/scripts.json`.
- Why: three documented registration mechanisms execute at load. Note that with the current function bodies, definitions themselves are order-independent — but that is a property of the code, not a guarantee.

**Mudlet DB schema changes are opportunistic.**
- Why: new sheets are created by helper functions and missing-sheet paths degrade to warnings; there is no schema version or migration ledger.

## Scaling Limits

**Trigger count grows linearly with supported classes**, with no sharding mechanism. This is the only unbounded cost in the system.

**Stats detail structures grow with hunting diversity.** `newScope()` stores unbounded `areas`, `abilities`, `targetStats`, and rage breakdowns per scope.

**`runtime.context()` is one wide struct** handed to every consumer; each new field is paid for by every caller on every tick.

**Whitelist share packets have no TTL or total cap.**

**Trace history is intentionally capped** at 100 entries.

## Dependencies at Risk

**demonnicAutoWalker** — behaviour depends on external event names. Keep `boop_walk.lua` as a thin adapter with contract tests.

**Muddler build action** — CI uses `demonnic/build-with-muddler@main`, which can change independently.

**Mudlet test profile and AppImage** — CI downloads an AppImage and clones an external test profile; neither is pinned.

## Missing Critical Features

**Runtime performance instrumentation.** There is no way to answer "is boop fast enough" from a live session. `/REFACTOR-ROADMAP.md` Phase 1 adds `boop.perf`.

**Architecture guardrails.** `check_release_gates.py` covers versions, manifests, and state drift, but not module dependencies. Phase 1 adds `--check architecture` with DAG cycle detection.

**Automated version sync gate.** CI reads `mfile` only and does not verify `boop_init.lua`'s `boop.version`.

**Command-fragment validator.** No shared validation for operator-entered values that reach `send()`.

## Test Coverage Gaps

**Cross-path gate equivalence.** Nothing asserts that the tick path and the prequeue path reach the same verdict for the same state, though they reimplement the same gate sequence three times. Phase 3 adds a table-driven spec.

**Command-fragment validation.** Pack names, assist leaders, directions, and separators containing newlines or command separators are untested.

**Manifest and package parity.** `--check manifests` covers orphans and unresolved entries; there is no test that the built package contains what the source implies.

**Live combat log replay breadth.** Gag correlation has good unit coverage, but live logs remain the main source for missing line variants.
