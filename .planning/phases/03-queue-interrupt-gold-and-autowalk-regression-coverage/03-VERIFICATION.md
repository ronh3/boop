---
phase: 03-queue-interrupt-gold-and-autowalk-regression-coverage
verified: 2026-07-26T21:42:51Z
status: human_needed
score: 5/5 must-haves verified
behavior_unverified: 0
overrides_applied: 0
re_verification:
  previous_status: gaps_found
  previous_score: 4/5
  gaps_closed:
    - "A matching current gold timeout fired under an unrelated owner now consumes operation.timeoutTimer, permitting one later normal flush_gold and eliminating the permanent gold_pending walk stall."
  gaps_remaining: []
  regressions: []
human_verification:
  - test: "Exercise diag, a queued interrupt, and pull while a real target or gold lifecycle coexists with autogold and demonnicAutoWalker."
    expected: "No automatic attack, get/put command, or walker move occurs until the exact owner and every other relevant owner release; exactly one next action then resumes."
    why_human: "Achaea server queue completion, real GMCP callback ordering, and the external walker process are outside the host Busted harness."
  - test: "Create gold evidence in room A, move to room B before pickup/retry evidence, then separately confirm pickup before moving prior to packing."
    expected: "No room-A get/retry is sent in room B; an inventory-owned put may finish after movement; loot is never chained with an attack."
    why_human: "Real Achaea item lines and room/inventory GMCP timing require a live profile."
  - test: "Check walk status/start/move/install without demonnicAutoWalker, then compare stopping a boop-owned run with detaching from an already-running external run."
    expected: "Only explicit install requests package installation, no path silently updates, owned stop emits once, and attached stop does not stop the external run."
    why_human: "Mudlet package-manager prompts and a real demonnicAutoWalker process are external integrations."
---

# Phase 3: Queue, Interrupt, Gold, and Autowalk Regression Coverage Verification Report

**Phase Goal:** Timing-sensitive command paths cannot attack, loot, or walk while another safety hold or room-state blocker owns the next action.
**Verified:** 2026-07-26T21:42:51Z
**Status:** human_needed
**Re-verification:** Yes — after Plan 03-10 gap closure
**Verified HEAD:** `8412e4164995ccb9356f009be2fdbba7f9bb976b`
**Package version:** `0.1.416`

## Goal Achievement

The previous deterministic implementation gap is closed. The current timeout callback relinquishes only its matching timer authority before checking other owners. Runtime can therefore resume one unchanged gold stage after aggregate all-clear, while attacks and walk remain held. The no-pack terminal path then reaches the existing guarded walker reservation and emitter exactly once.

All five roadmap truths have implementation and passing behavioral evidence. The report remains `human_needed`, rather than `passed`, because the verifier contract requires human confirmation for the real Achaea/Mudlet and external walker boundaries. Phase 6 owns the recorded real-Mudlet and live-release evidence; these items are not implementation gaps and no terminal CI claim is made here.

### Observable Truths

| # | Roadmap truth | Status | Evidence |
|---|---|---|---|
| 1 | `diag`, queued interrupts, `pull`, and manual holds prevent automatic attacks until their prompt, room, or timeout release condition is satisfied. | ✓ VERIFIED | Quick regression: the clean Phase 03 host aggregate passed 207/207, and 11 exact-name pull lifecycle tests passed. Owner exclusion and aggregate hold logic remain wired through `boop_runtime.lua`; Plan 03-10 did not modify runtime or pull code. |
| 2 | Gold pickup, pack/stash, retry, warning, and stale-pending behavior cannot send in the wrong room or bypass active safety holds. | ✓ VERIFIED | Full re-check: pickup and packing exact-name cases passed; the 16 owner/stage matrix cases passed; generation, phase, room identity, inventory boundary, retry counts, zero-send behavior, and replacement timer identity are asserted. |
| 3 | `boop walk` start, stop, move, and status reflect room settlement and blockers, and emit `demonwalker.move` only when safe. | ✓ VERIFIED | The exact no-pack recovery test passed through public gold entry points, terminal reevaluation, `maybeAdvance`, and the guarded emitter: zero movement before terminal, one reservation, one event, duplicate emitter no-op. |
| 4 | `demonnicAutoWalker` remains optional, with explicit install/status feedback and no silent auto-update behavior. | ✓ VERIFIED | `boop.walk.install()` is still the only package-install path. Walk/UI regression tests passed in the 207-case aggregate; `boop_walk.lua` is unchanged by Plan 03-10. |
| 5 | Regression coverage catches unsafe movement, attacks during holds, wrong-room loot commands, target-removal queue drift, and permanent walk stalls. | ✓ VERIFIED | The formerly absent timeout-under-owner ordering is now covered by three exact-name tests, 19 escaped-group cases, the 76-case focused aggregate, stale-generation coverage, the two-owner release matrix, and the final one-move walk path. |

**Score:** 5/5 roadmap truths verified (0 present-but-behavior-unverified)

### Re-verification Scope

| Scope | Result | Notes |
|---|---|---|
| Previous failed truth | ✓ CLOSED | Fully checked at implementation, artifact, wiring, data-flow, and behavioral levels. |
| Previous truths 1-4 | ✓ NO REGRESSION | Quick source sanity plus focused behavioral regression. |
| Plan 03-10 truths | 5/5 verified | Matching-token consumption, fail-closed ownership, lifecycle identity, one resumed stage, and terminal walker progress all have passing behavior tests. |
| PLAN artifact declarations | 52/52 passed | `verify.artifacts` passed every declaration across plans 03-01 through 03-10. |
| PLAN key-link declarations | 24/24 passed | `verify.key-links` passed every declaration; the previously semantically broken timer/runtime link was also traced manually. |
| Plan 03-09 terminal authority | Parent-owned, not claimed | The parent must push immutable final HEAD and run `tools/wait_for_exact_ci.sh` after this report and any phase/UAT planning mutations are committed. |

## Required Artifacts

| Artifact | Expected | Status | Details |
|---|---|---|---|
| `src/scripts/boop/boop_events.lua` | Generation/phase/token-owned gold timeout, pickup, packing, retry, and terminal lifecycle | ✓ VERIFIED | Substantive and wired. The Plan 03-10 production diff is exactly the two-line token consumption/synchronization before authorization. |
| `src/scripts/boop/boop_runtime.lua` | Aggregate owner gates and one `flush_gold` effect when a live gold stage has no timer | ✓ VERIFIED | Unchanged by Plan 03-10; current non-terminal gold returns before attack/walk and flushes only after all unrelated owners clear. |
| `src/scripts/boop/boop_walk.lua` | Shared safety evaluator, reservation identity, and guarded external event emitter | ✓ VERIFIED | Unchanged by Plan 03-10; both automatic and reserved checks reject non-terminal gold and all other unsafe state. |
| `tests/support/boop_host_busted_helper.lua` | Tracked, diagnostic-only focused host bootstrap | ✓ VERIFIED | Requires `BOOP_REPO_ROOT`, loads the allowlisted source modules in package order, and contains no `/tmp`, install, network, or manifest mutation path. |
| `tests/boop_gold_retry_spec.lua` | Pickup/packing fired-token, duplicate, stale, identity, retry, and replacement-token checks | ✓ VERIFIED | The exact cases invoke captured callbacks and never assign `operation.timeoutTimer`. |
| `tests/boop_tick_spec.lua` | Four gold stages × four owner classes with real timeout and two-owner release ordering | ✓ VERIFIED | `readyBlockedStage` resolves the current timer ID and invokes its callback; no manual token clearing remains. |
| `tests/boop_walk_spec.lua` | No-pack terminal recovery through normal walker reservation/emitter | ✓ VERIFIED | Uses public gold success and normal terminal tick; it does not clear the operation or call the private emitter directly. |
| `README.md`, `DESIGN.md`, `UIDESIGN.md`, `tests/README.md` | Operator, architecture, UI, and test-authority contracts | ✓ VERIFIED | Quick sanity confirms owner, room-evidence, staged-gold, optional-walker, and authority-boundary wording remains present. |

## Key Link Verification

| From | To | Via | Status | Details |
|---|---|---|---|---|
| Gold timeout callback | Current gold operation | Captured generation + phase + exact timer ID | ✓ WIRED | A stale generation/phase/token returns before mutation. A matching callback clears `timeoutTimer` and synchronizes `pendingTimer` before authorization. |
| `boop_events.lua` | `boop_runtime.lua` | Cleared timer allows `tickStep` to emit one `flush_gold` | ✓ WIRED | While another owner remains, tick returns held. After final release, one normal tick delegates to `boop.flushPendingGold`. |
| Runtime `flush_gold` | Gold command/retry stage | `applyEffects` → `flushPendingGold` → `queueGoldCommands` | ✓ WIRED | Exactly one unchanged get/put send occurs and a distinct replacement timer is armed without changing retries. |
| Gold terminal | Walker evaluator | Generation-guarded terminal tick after `state.gold.operation = false` | ✓ WIRED | Walk is unreachable while gold is non-terminal; no-pack success schedules normal reevaluation, then one reservation. |
| Walker reservation | External event | Run/room/reservation identity plus final safety recheck | ✓ WIRED | The emitter raises `demonwalker.move` once and becomes inert after clearing its token. |
| Room/target adapters | Loot, queue, and walk gates | Current room observation and exact owner records | ✓ WIRED | Passing event-transition tests cover wrong-room evidence, target-removal queue drift, and stale callback no-ops. |

## Data-Flow Trace (Level 4)

| Artifact | Data variable | Source | Produces real data | Status |
|---|---|---|---|---|
| `boop_events.lua` | `state.gold.operation` | Gold text/GMCP room evidence, get/put result handlers, failures, room changes, and captured timers | Yes | ✓ FLOWING |
| `boop_events.lua` | `operation.timeoutTimer` / `state.gold.pendingTimer` | `tempTimer` ID and `markGoldQueueIntent` compatibility synchronization | Yes; a fired matching token becomes false/nil before any hold branch | ✓ FLOWING |
| `boop_runtime.lua` | `combat.blockersByOwner` | Interrupt, pull, room, gold, flee, target, and walk lifecycles | Yes; aggregate `shouldHold` checks all owners except only the exact lifecycle owner | ✓ FLOWING |
| `boop_runtime.lua` | `flush_gold` effect | Current non-terminal gold operation with no timer and aggregate all-clear | Yes; delegated to production `flushPendingGold` | ✓ FLOWING |
| `boop_walk.lua` | Run/room/reservation state | Current room observation, operator walk lifecycle, terminal tick, and timer emitter | Yes; final safety recheck raises one external event | ✓ FLOWING |

### Closed Gap Trace

1. `armGoldPendingTimeout(generation, expectedPhase)` captures the timer ID and re-resolves the current generation and phase when it fires.
2. A stale or replaced timer fails `active.timeoutTimer ~= timerId` and returns with no mutation.
3. A matching timer sets `active.timeoutTimer = false` and calls `markGoldQueueIntent`, making the compatibility `pendingTimer` nil before checking other owners.
4. If another owner still holds gold/walk, authorization returns false with zero sends, zero retry changes, zero movement, and the same lifecycle identity.
5. Runtime tick continues to hold while any unrelated owner remains.
6. After final-owner release, one normal tick sees no timer, emits one `flush_gold`, resumes the unchanged pickup/packing stage, and arms one distinct replacement timeout.
7. For no-pack pickup success, the gold lifecycle terminates and schedules its existing generation-guarded normal tick. Only then can walker evaluation reserve one move and the guarded emitter raise one event.

## Behavioral Spot-Checks

| Behavior | Command/check | Result | Status |
|---|---|---|---|
| Exact pickup timeout under owner | Busted JSON `--name` with tracked helper | 1 success, 0 failures/errors/pending; exact selected record | ✓ PASS |
| Exact packing timeout under owner | Busted JSON `--name` with tracked helper | 1 success, 0 failures/errors/pending; exact selected record | ✓ PASS |
| Exact timeout recovery to guarded walker move | Busted JSON `--name` with tracked helper | 1 success, 0 failures/errors/pending; exact selected record | ✓ PASS |
| Stale timeout cannot consume a replacement generation token | Exact-name Busted JSON case | 1 success, 0 failures/errors/pending | ✓ PASS |
| Escaped timeout-under-owner group | `--filter='timeout%-under%-owner'` over gold retry/tick/walk | 19 successes, 0 failures, 0 errors, 0 pending | ✓ PASS |
| Focused gap aggregate | Gold retry + tick + walk specs | 76 successes, 0 failures, 0 errors, 0 pending | ✓ PASS |
| Prior-passed Phase 03 regression | Runtime, interrupt, diag/timeout, gold, events, tick, prequeue, walk, UI, trace | 207 successes, 0 failures, 0 errors, 0 pending | ✓ PASS |
| Pull ownership lifecycle | 11 exact-name pull lifecycle cases | 11/11 passed | ✓ PASS |
| Lua syntax | `luac -p` over all 56 production Lua files plus helper and three changed specs | 60/60 parsed | ✓ PASS |
| Release/version/state gates | `python3 tools/check_release_gates.py` | `[OK] versions`, `[OK] manifests`, `[OK] state-drift` | ✓ PASS |
| Package construction | `muddle` under PTY | Muddler 1.1.0 built `build/boop Hunter.mpackage` at `0.1.416` | ✓ PASS |
| Plan 03-10 source scope | Git diff from `63fc2b9^` through HEAD | Runtime/walk byte-for-byte unchanged; only two behavior lines added to `boop_events.lua` | ✓ PASS |

The tracked helper intentionally loads the focused Occultist profile only. An exploratory command that also selected the full pull spec produced two out-of-scope Psion/Dragon profile-selection failures because those profiles are not in that helper's allowlist. This is a harness-scope result, not a Plan 03-10 regression: neither pull/profile production nor those tests changed, all 203 other selected records passed, the supported 207-case Phase 03 aggregate passed, and all 11 pull lifecycle/ownership cases passed by exact name.

## Probe Execution

Step 7c was skipped: Phase 03 declares no probe scripts, and repository probe discovery found none.

## Requirements Coverage

| Requirement | Source plans | Description | Status | Evidence |
|---|---|---|---|---|
| SAFE-02 | 03-01, 03-02, 03-03, 03-08, 03-09 | Interrupt, pull, diag, and manual holds prevent attacks until exact release | ✓ SATISFIED | Runtime/interrupt/diag/prequeue regression plus 11 exact pull lifecycle tests pass; aggregate owners prevent attack effects. |
| SAFE-04 | 03-01, 03-04, 03-05, 03-08, 03-09, 03-10 | Gold pickup/packing/retry/stale behavior cannot use wrong-room evidence or bypass holds | ✓ SATISFIED | The repaired timer transition, room/generation/inventory guards, retry matrices, wrong-room event tests, and exact timeout cases pass. |
| WALK-01 | 03-01, 03-06, 03-07, 03-09 | Walk start/stop/move/status/settlement/event coverage | ✓ SATISFIED | Walk/UI tests cover lifecycle, settlement, blockers, reservations, stale callbacks, package loss, and event emission. |
| WALK-02 | 03-01, 03-06, 03-07, 03-08, 03-09, 03-10 | No walker advancement while any unsafe state remains | ✓ SATISFIED | Gold remains blocking through timeout recovery and resumes movement only after terminal; all evaluator and emitter gates are tested. |
| WALK-03 | 03-06, 03-08, 03-09 | Optional external walker with explicit install/status and no silent update | ✓ SATISFIED | Only explicit install calls the package API; status/start/move never install/update; regression tests pass. |

No Phase 03 requirement is orphaned: all five roadmap requirement IDs appear in phase plans and map to implementation plus behavioral evidence.

## Anti-Patterns Found

| File | Line/pattern | Severity | Impact |
|---|---|---|---|
| Plan 03-10 modified production/tests | `TBD`, `FIXME`, `XXX`, `TODO`, `HACK`, `PLACEHOLDER` scan | None | No unresolved debt marker or placeholder implementation found. |
| `tests/support/boop_host_busted_helper.lua` | No-op Mudlet globals | ℹ️ Info | Intentional diagnostic host substitutes only; they do not flow into shipped package behavior or claim Mudlet equivalence. |

## Human Verification Required

### 1. Cross-owner attack/loot/walk release

**Test:** In a safe Achaea test area with autogold and demonnicAutoWalker enabled, exercise `diag`, one queued interrupt, and `pull` while a target or gold lifecycle is present. Inspect status, command output, and movement before and after real prompt/return/current-room-list release.

**Expected:** No automatic standard/rage attack, get/put command, or walker movement occurs while any relevant owner remains. Once the exact owner and all other relevant owners clear, exactly one next action resumes.

**Why human:** Actual server queues, GMCP ordering, and the external walker process are not represented by the diagnostic host harness.

### 2. Wrong-room gold and pack transfer

**Test:** Cause gold evidence in room A, move to room B before pickup/retry evidence, then separately confirm pickup and move before the configured pack/stash step.

**Expected:** No room-A get or retry is sent in room B. A confirmed inventory-owned put may finish after movement. No loot command is chained with an attack.

**Why human:** This validates real Achaea item lines and room/inventory GMCP timing.

### 3. Optional walker and stop ownership

**Test:** In a profile without demonnicAutoWalker, run walk status/start/move and then explicit install. In a profile with the package, compare stopping a boop-owned run with detaching from an already-running external walk.

**Expected:** Status/start/move never install or update. Explicit install gives visible feedback. Owned stop emits one stop; attached stop detaches without stopping the external run.

**Why human:** Package-manager prompts and a real walker process are external integrations.

## External Authority and Deferred Validation

- `/tmp/Mudlet.AppImage` is absent. Host Busted is diagnostic evidence, not Mudlet-equivalent evidence.
- Phase 6 explicitly owns recorded Muddler, real-Mudlet-profile, and live Achaea release evidence. The human items above are preserved because they cross those external boundaries; they are not code gaps.
- The parent orchestrator owns the immutable-final-HEAD push and `tools/wait_for_exact_ci.sh` gate after this report and all planning/UAT mutations are committed. This report does not claim terminal CI.
- `git status` was clean after verification commands and before writing this report. No temporary verification files were created.

## Gaps Summary

No implementation gap remains. Plan 03-10 closes the only previous deterministic failure without modifying runtime or walker policy and without adding an alternate bypass. Automated goal evidence is 5/5; the phase is `human_needed` solely for the three real-environment checks above.

---

_Verified: 2026-07-26T21:42:51Z_
_Verifier: Codex (gsd-verifier)_
