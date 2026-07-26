---
phase: 03-queue-interrupt-gold-and-autowalk-regression-coverage
verified: 2026-07-26T15:41:47Z
status: gaps_found
score: 4/5 must-haves verified
behavior_unverified: 0
overrides_applied: 0
gaps:
  - truth: "Regression coverage catches unsafe movement, attacks during holds, wrong-room loot commands, target-removal queue drift, and permanent walk stalls."
    status: failed
    reason: "A current gold pending timeout that fires while an unrelated gold/walk owner is active returns without consuming or rearming operation.timeoutTimer. After the unrelated owner releases, tick still refuses flush_gold because the expired timer token remains, and walk remains blocked by the non-terminal gold operation. Existing tests cover hold release and timeout separately but not this ordering."
    requirements:
      - SAFE-04
      - WALK-02
    artifacts:
      - path: "src/scripts/boop/boop_events.lua"
        issue: "armGoldPendingTimeout returns at lines 611-612 when authorization is held, leaving the expired timeout token installed."
      - path: "src/scripts/boop/boop_runtime.lua"
        issue: "tick emits flush_gold only when timeoutTimer is false, so the expired token permanently suppresses recovery."
      - path: "src/scripts/boop/boop_walk.lua"
        issue: "Any non-terminal gold operation remains goldPending and blocks automatic and reserved movement."
      - path: "tests/boop_gold_retry_spec.lua"
        issue: "Tests timeout without a concurrent owner and owners without firing the pending timeout; the interaction is absent."
      - path: "tests/boop_tick_spec.lua"
        issue: "Owner-release fixtures manually clear timeoutTimer for affected stages, bypassing the real expired-timer state."
    missing:
      - "Consume, clear, or safely rearm the matching gold pending timeout when it fires under another current owner."
      - "Add a deterministic regression that fires the current timeout under a gold/walk hold, releases the final unrelated owner, and proves the gold lifecycle clears or resumes exactly once."
      - "Assert that the same sequence cannot leave boop walk status permanently blocked by gold_pending and that one safe move can be reserved after recovery."
---

# Phase 3: Queue, Interrupt, Gold, and Autowalk Regression Coverage Verification Report

**Phase Goal:** Timing-sensitive command paths cannot attack, loot, or walk while another safety hold or room-state blocker owns the next action.
**Verified:** 2026-07-26T15:41:47Z
**Status:** gaps_found
**Re-verification:** No — initial verification
**Verified HEAD:** `a8c304d6fc49f3f90828d7aa6346b9235f6f8e7e`

## Goal Achievement

The owner-keyed safety architecture is substantive, wired, and well tested. It prevents unsafe attack, loot, and movement sends in the covered orderings. The phase nevertheless fails one roadmap must-have: a reproducible gold-timeout/hold ordering leaves a stale non-terminal gold operation forever, which in turn can permanently stall autowalk. The existing suite does not catch that interaction.

### Observable Truths

| # | Roadmap truth | Status | Evidence |
|---|---|---|---|
| 1 | `diag`, queued interrupts, `pull`, and manual holds prevent attacks until their exact release condition. | ✓ VERIFIED | Exact-owner interrupt and pull lifecycles are wired in `boop_runtime.lua` and `boop_ui.lua`. Passing tests exercise prompt/timeout races, repeats, stale generations, both owner-clear orders, disabled state, and manual targeting. |
| 2 | Gold pickup, packing, retries, warning, and stale evidence cannot send in the wrong room or bypass a safety hold. | ✓ VERIFIED | Room generation and exact-owner authorization gate get/put/retry. Tests prove complete-current-list authorization, wrong-room invalidation, unrelated-owner holds, get-confirm-put staging, pack-after-movement, and stale callback no-ops. The blocker below is liveness, not an observed unsafe send. |
| 3 | Walk start/stop/move/status reflects settled rooms and blockers; `demonwalker.move` emits only when safe. | ✓ VERIFIED | Walk evaluation and the reserved emitter recheck run/room/reservation identity and all safety domains. Passing tests prove one move per room generation, stale emitter no-ops, package loss, owned stop, attached detach, manual denial, and refresh exhaustion. |
| 4 | `demonnicAutoWalker` is optional, explicit to install, and never silently updated. | ✓ VERIFIED | Only `boop.walk.install()` calls `installPackage`; status/start/move do not install or update. Explicit install success/failure and missing-package feedback are tested. |
| 5 | Regression coverage catches unsafe movement, attacks during holds, wrong-room loot, target-removal queue drift, and permanent walk stalls. | ✗ FAILED | The standard focused suite passes, but a disposable adversarial test reproduces an uncaught permanent stale-gold/walk stall when a pending timeout fires during another owner’s hold. |

**Score:** 4/5 roadmap truths verified (0 present-but-behavior-unverified)

### Plan Must-Have Consolidation

All 49 PLAN frontmatter truths were inspected. They are consolidated under the five roadmap truths above rather than allowed to narrow the roadmap contract.

| Plan | Result | Notes |
|---|---|---|
| 03-01 | 5/5 verified | Aggregate owners, exact-owner exclusion, deterministic primary blocker, and current room evidence are implemented and tested. |
| 03-02 | 5/5 verified | Interrupt generations, FIFO/tombstones, repeat rejection, and first-terminal behavior are tested. |
| 03-03 | 4/4 verified | Pull owns all relevant systems without mutating saved enable intent; return/timeout races are tested. |
| 03-04 | 5/5 verified | Room-owned pickup, inventory-owned packing, duplicate coalescing, settled evidence, and get-confirm-put staging are tested. |
| 03-05 | 4/5 verified | Flee destruction and normal owner-release paths pass. The “final owner release resumes one unchanged stage” truth fails when the real pending timeout fired during the hold. |
| 03-06 | 5/5 verified | Shared automatic/manual movement gating, reservations, explicit install, and current room settlement pass. |
| 03-07 | 5/5 verified | Owned stop, attached detach, pre-effect invalidation, fresh restart, and stale callback no-ops pass. |
| 03-08 | 6/6 verified | Deterministic status/trace, aggregate attack/prequeue holds, fresh interrupt generation, manual holds, and help wording pass. |
| 03-09 | Local checks verified; terminal authority outstanding | Release gates, syntax, Muddler, docs, and focused host tests pass. Real-Mudlet execution was unavailable; immutable-final-HEAD CI remains parent-owned, and live Achaea evidence is assigned to Phase 6. |

## Required Artifacts

The GSD artifact checks reported 47/47 declared artifacts present and matching their required patterns across plans 03-01 through 03-09. Manual inspection checked substance and wiring rather than accepting those pattern results alone.

| Artifact | Expected | Status | Details |
|---|---|---|---|
| `src/scripts/boop/boop_runtime.lua` | Owner-keyed blocker registry, interrupt lifecycle, runtime effect gate | ✓ VERIFIED | Substantive and used by events, UI, tick, gold, prequeue, and walk paths. `shouldHold(system, exceptOwner)` scans all sorted owners. |
| `src/scripts/boop/boop_events.lua` | Room observation, gold lifecycle, GMCP adapters, target-loss handling | ⚠️ PARTIAL | Core data flow is real and wired, but the pending-timeout callback has the permanent-stall defect detailed below. |
| `src/scripts/boop/boop_walk.lua` | Shared safety evaluator and reserved external movement emitter | ✓ VERIFIED | Substantive, wired to GMCP room adapters and `demonwalker.*` events, and behaviorally tested. |
| `src/scripts/boop/boop_ui.lua` | Interrupt, pull, status, and operator command surfaces | ✓ VERIFIED | Creates exact generation owners, arms timers, sends operator commands once, and routes release transitions. |
| `tests/boop_runtime_spec.lua`, `tests/boop_interrupt_spec.lua`, `tests/boop_diag_spec.lua`, `tests/boop_pull_spec.lua`, `tests/boop_prequeue_spec.lua` | Attack/queue ownership regressions | ✓ VERIFIED | Passing assertions cover both clear orders, exact-owner exclusion, prompt/timeout races, repeats, FIFO evidence, saved intent, and prequeue callbacks. |
| `tests/boop_gold_retry_spec.lua`, `tests/boop_event_transitions_spec.lua`, `tests/boop_tick_spec.lua` | Gold/room/cross-owner regressions | ⚠️ INCOMPLETE | Extensive passing coverage exists, but timeout-under-hold followed by final-owner release is missing. |
| `tests/boop_walk_spec.lua`, `tests/boop_ui_spec.lua` | Walker lifecycle, feedback, help, and optional-package regressions | ✓ VERIFIED | Passing assertions cover gates, reservations, stale callbacks, stop/detach/restart, refresh warning, package loss, install/status, and no update calls. |
| `README.md`, `DESIGN.md`, `UIDESIGN.md`, `tests/README.md` | Operator and maintainer contract | ✓ VERIFIED | Current ownership, room evidence, get-confirm-put, owned/detached stop, optional install, and test authority language is present. |

## Key Link Verification

The mechanical PLAN key-link checks reported 20/20 matches. Manual behavior tracing found one link that is syntactically present but semantically broken.

| From | To | Via | Status | Details |
|---|---|---|---|---|
| `boop_ui.lua` interrupt/pull commands | `boop_runtime.lua` owner registry | `setBlocker`, generation records, exact completion | ✓ WIRED | Timers and prompt/room evidence release only the matching owner; tests pass stale and first-terminal races. |
| `boop_events.lua` Room.Info/List adapters | Runtime room observation | new generation plus current complete item list | ✓ WIRED | A Room.Info starts the generation; only its complete room list stamps `itemsSeen` and can advance loot/walk. |
| Runtime owner registry | attack/prequeue/gold/walk dispatch | aggregate `shouldHold` checks | ✓ WIRED | Both clear orders and exact-owner exclusion are behaviorally tested. |
| Gold pending timer | Gold terminal/retry recovery | `goldDispatchAuthorized` then `completeGoldOperation` | ✗ BROKEN | When another owner holds gold/walk, the callback returns with the expired token still stored; no later path consumes it. |
| Walk settlement | External `demonwalker.move` | `maybeAdvance` reservation then final emitter recheck | ✓ WIRED | The emitter clears its token and raises exactly one event only after current run/room/reservation and safety checks pass. |
| Target removal | Queue/target cleanup | `clearLostTargetIntent`, retarget, zero-delay tick | ✓ WIRED | Tests assert no `queue clear`, no held attack/prequeue, and stable behavior across lifecycle owners. |

## Data-Flow Trace (Level 4)

| Artifact | Data variable | Source | Produces real data | Status |
|---|---|---|---|---|
| `boop_runtime.lua` | `combat.blockersByOwner` | UI commands, GMCP events, gold, flee, target loss, and walker lifecycle | Yes; owner records are sorted, snapshotted, and consumed by dispatch gates | ✓ FLOWING |
| `boop_events.lua` | `roomObservation` | Actual `gmcp.Room.Info` and complete `gmcp.Char.Items.List` adapters | Yes; room ID/generation and info/items evidence gate loot and walk | ✓ FLOWING |
| `boop_events.lua` | `gold.operation` | Gold text/GMCP evidence, get/put results, failures, room changes, and timers | Mostly; real commands and lifecycle transitions flow, but timeout-under-hold deadlocks the operation | ✗ BROKEN |
| `boop_walk.lua` | Walk run/room/reservation state | Room observation, demonwalker lifecycle, operator start/stop/move | Yes; final recheck raises `demonwalker.move` | ✓ FLOWING |

### Blocker Trace

1. `armGoldPendingTimeout` captures the current generation, phase, and timer ID.
2. If an unrelated owner is active when the timer fires, `goldDispatchAuthorized(active)` is false and the callback returns without clearing or replacing `active.timeoutTimer` (`boop_events.lua:605-618`).
3. After that owner releases, runtime tick sees the current non-terminal gold operation but emits `flush_gold` only when `timeoutTimer` is false (`boop_runtime.lua:1094-1112`).
4. The same operation keeps `goldPending` true (`boop_walk.lua:76-83`), so both normal and reserved walk evaluation remain blocked (`boop_walk.lua:345-346`, `407-408`).

This is a permanent state transition failure, not a visual uncertainty.

## Behavioral Spot-Checks

| Behavior | Command/check | Result | Status |
|---|---|---|---|
| Release/version/state gates | `python3 tools/check_release_gates.py` | `[OK] versions`, `[OK] manifests`, `[OK] state-drift` | ✓ PASS |
| Lua syntax | `luac -p` over every `src/scripts/boop/**/*.lua` | 56/56 files parsed | ✓ PASS |
| Focused Phase 03 behavior | Busted host run of runtime, interrupt, diag, pull, gold retry, event transition, tick, prequeue, walk, and UI specs | 202 successes, 0 failures, 0 errors, 0 pending | ✓ PASS |
| Gold timeout under unrelated hold | Disposable Busted probe: start current pickup, add interrupt owner, fire matching timeout, release owner, tick | 0 successes / 1 failure: expired `timeoutTimer` remained and recovery did not run | ✗ FAIL |
| Package build | `muddle` | Muddler 1.1.0 built `build/boop Hunter.mpackage` successfully | ✓ PASS |
| Real Mudlet suite | Canonical AppImage command | `/tmp/Mudlet.AppImage` is absent | ? SKIPPED |

The host Busted loader and adversarial probe were temporary verification files under `/tmp` and were removed after execution. No package source or test file was changed.

## Probe Execution

No Phase 03 PLAN/SUMMARY declares a `probe-*.sh`, and no conventional `scripts/*/tests/probe-*.sh` exists. Step 7c is not applicable.

## Requirements Coverage

| Requirement | Source plans | Status | Evidence |
|---|---|---|---|
| SAFE-02 | 03-01, 03-02, 03-03, 03-08 | ✓ SATISFIED | Aggregate owner tests, interrupt/diag prompt and timeout tests, pull room/timeout races, repeat rejection, and disabled/manual release tests all pass. |
| SAFE-04 | 03-01, 03-04, 03-05, 03-08 | ⚠️ BLOCKED (liveness edge) | Wrong-room sends and hold bypass are prevented in covered tests, but stale-pending recovery can deadlock after a timeout fires under another owner. |
| WALK-01 | 03-01, 03-06, 03-07, 03-08 | ✓ SATISFIED | Start, status, move, current settlement, blocker reasons, one-event reservation, stop/detach, restart, and stale callbacks are implemented and tested. |
| WALK-02 | 03-01, 03-05, 03-06, 03-07, 03-08 | ✗ BLOCKED | Unsafe movement is held correctly, but the stale non-terminal gold operation can continue reporting `gold_pending` after the final unrelated safety owner is gone, creating a permanent walk stall. |
| WALK-03 | 03-06, 03-07, 03-08 | ✓ SATISFIED | Missing package feedback is explicit; only explicit install calls `installPackage`; status/start/move/package-loss paths make zero install/update calls. |

All five requirement IDs are declared by Phase 03 plans and mapped to Phase 3 in `REQUIREMENTS.md`; there are no orphaned Phase 03 requirements.

## Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|---|---|---|---|---|
| — | — | No unreferenced `TBD`, `FIXME`, or `XXX` markers in relevant source/tests | — | No debt-marker blocker |
| `src/scripts/boop/boop_events.lua` | 611-612 | Early return retains expired timer identity | 🛑 BLOCKER | Prevents gold recovery and can permanently hold walk |

Static matches for “not available” are intentional operator feedback, and `return {}` matches are substantive utility defaults rather than user-visible stubs.

## Human Verification Required

The code gap above is deterministic and does not need human judgment. It must be fixed and covered automatically first.

After gap closure, these exact live checks remain appropriate because local host tests cannot reproduce Achaea server queues, GMCP ordering, or the external walker package:

### 1. Cross-owner attack/loot/walk release

**Test:** In a safe Achaea test area with autogold and demonnicAutoWalker enabled, exercise `diag`, one queued interrupt, and `pull` while a target or gold lifecycle is present. Inspect `boop status`, command output, and movement before and after the real prompt/return/current-room-list release.

**Expected:** No automatic standard/rage attack, get/put command, or `demonwalker.move` occurs while any relevant owner remains. Once the exact owner releases and every other relevant owner is clear, exactly one next action resumes.

**Why human:** Actual server queue completion, GMCP callback order, and external event timing are not represented by the local host harness.

### 2. Wrong-room gold and pack transfer

**Test:** Cause gold evidence in room A, move to room B before pickup/retry evidence, then separately confirm a pickup in room A and move before the configured pack/stash step.

**Expected:** No room-A get or retry is sent in room B. A confirmed inventory-owned put may finish after movement. No get/put command is chained with an attack.

**Why human:** This validates real Achaea item lines and GMCP room/inventory timing.

### 3. Optional walker and stop ownership

**Test:** In a profile without demonnicAutoWalker, run walk status/start/move; then test explicit install. In a profile with the package, compare stopping a boop-owned run with detaching from an already-running external walk.

**Expected:** Status/start/move never install or update the package; explicit install gives visible request/failure feedback. Owned stop emits one external stop; attached stop detaches without stopping the external run.

**Why human:** Package-manager prompts and a real demonwalker process are external integrations.

Phase 6 explicitly owns recorded real-Mudlet and live Achaea release evidence. These checks therefore remain outstanding UAT, but they do not replace the automated gap closure required here.

## External Authority and Deferred Validation

- `/tmp/Mudlet.AppImage` was confirmed absent. This report makes no claim of a local real-Mudlet run.
- The parent session still owns the mandatory immutable-final-HEAD push and `tools/wait_for_exact_ci.sh "$FINAL_SHA"` check. Writing this report mutates planning state, so any earlier CI result cannot be final evidence.
- Live Achaea UAT is assigned to Phase 6 by the roadmap. No later phase specifically addresses the gold timeout/hold defect, so that defect is not deferred.

## Gaps Summary

One root gap blocks Phase 03 completion. Gold timeout and unrelated-owner release are each tested independently, but their interaction is not. The production callback preserves an expired timer token when authorization is held; runtime then refuses every future gold flush, and walk continues to see a non-terminal `gold_pending` lifecycle. Fix the timer transition and add the missing cross-owner regression before re-verification.

---

_Verified: 2026-07-26T15:41:47Z_
_Verifier: Codex (gsd-verifier)_
