---
phase: 03-queue-interrupt-gold-and-autowalk-regression-coverage
verified: 2026-07-27T03:07:43Z
status: human_needed
score: 5/5 must-haves verified
behavior_unverified: 0
overrides_applied: 0
re_verification:
  previous_status: human_needed
  previous_score: 5/5
  gaps_closed:
    - "G-03-1: Serialized Inv-to-Room response fences now reject pre-barrier Lists, drain invalidated epochs FIFO, preserve complete same-room evidence, make tokenless arrival non-authorizing, and release one guarded move."
    - "G-03-2: Canonical copied room evidence now owns gold acquisition; same-room Info preserves pickup, actual room change alone cancels room ownership, confirmed success alone creates roomless packing, and either removal order produces one put."
    - "The trace fixture now publishes room data through the production response fence instead of bypassing the accepted-observation contract."
  gaps_remaining: []
  regressions: []
human_verification:
  - test: "Repeat the live cross-owner walk flow that exposed G-03-1, including an observed room List before Room.Info, a same-room Info refresh, stop/restart, and diag/interrupt/pull ownership."
    expected: "Pre-barrier and stale responses authorize nothing; the requested Inv-to-Room pair settles the current room; no attack, loot, or move occurs while any owner remains; aggregate all-clear releases exactly one next action and one walker move."
    why_human: "Real Achaea GMCP ordering, server queue completion, and the external demonwalker process are outside the diagnostic host harness."
  - test: "Repeat the live gold flow that exposed G-03-2: acquire current-room gold, receive same-room Info, exercise removal-before-success and success-before-removal, then separately move before pickup and after confirmed pickup."
    expected: "Current-room evidence queues one get; same-room Info preserves it; actual movement cancels room-owned acquisition once; removal alone cannot transfer ownership; confirmed pickup permits one roomless put after movement; no loot command is chained with combat."
    why_human: "Real Achaea item lines, inventory confirmation, and room/inventory GMCP timing require a live profile."
---

# Phase 3: Queue, Interrupt, Gold, and Autowalk Regression Coverage Verification Report

**Phase Goal:** Timing-sensitive command paths cannot attack, loot, or walk while another safety hold or room-state blocker owns the next action.
**Verified:** 2026-07-27T03:07:43Z
**Status:** human_needed
**Re-verification:** Yes — after UAT gap Plans 03-11, 03-12, and 03-13 plus the trace-fixture regression
**Verified HEAD:** `d9a3fc9c7e48632f42e838489e75f619534a57b3`
**Branch:** `codex/pre-1.0-hardening-pass`
**Package version:** `0.1.423`

## Goal Achievement

The phase goal is implemented and behaviorally exercised at the current HEAD. The prior live UAT defects are no longer present in the code path: ambiguous room Lists cannot become authority, current evidence is accepted only through a serialized response fence, same-room Info is preserving, tokenless walker arrival cannot settle or move, and gold ownership crosses from room to inventory only on confirmed pickup.

All five roadmap truths have passing behavioral evidence. The overall status remains `human_needed` because the two live Achaea flows that originally found G-03-1 and G-03-2 have not been repeated after their fixes. The already-passed optional-walker UAT is not carried forward. No implementation gap remains, and this report makes no exact-final-HEAD GitHub CI claim.

### Observable Truths

| # | Roadmap truth | Status | Evidence |
|---|---|---|---|
| 1 | `diag`, queued interrupts, `pull`, and manual holds prevent automatic attacks until their exact release condition is satisfied. | ✓ VERIFIED | Owner-keyed aggregate gating is implemented by `shouldHold` in `boop_runtime.lua:768`. The exact aggregate attack test passed 1/1, and the broader state/runtime/safety/event/trace/UI/walk run passed 153/153. |
| 2 | Gold pickup, pack/stash, retry, warning, and stale-pending behavior cannot send in the wrong room or bypass active safety holds. | ✓ VERIFIED | `canonicalGoldEvidence` and `goldDispatchAuthorized` (`boop_events.lua:510-541`) require copied accepted items plus exact room/generation/item identity and aggregate all-clear. Both exact same-room pipeline tests passed 1/1; the focused aggregate passed 132/132. |
| 3 | `boop walk` start, stop, move, and status reflect room settlement and blocker reasons, and emit `demonwalker.move` only when safe. | ✓ VERIFIED | Start opens a fresh fence, arrival is hint-only, settlement requires the accepted observation, and the emitter rechecks run/room/reservation/all-clear (`boop_walk.lua:495-822`). The stop/restart stale-drain-to-one-move test passed 1/1. |
| 4 | `demonnicAutoWalker` remains optional, with explicit install/status feedback and no silent auto-update behavior. | ✓ VERIFIED | `boop.walk.install` is the sole install path (`boop_walk.lua:396`); status/start/move do not install or update. The exact optional-walker test passed 1/1, and the corresponding live UAT previously passed. |
| 5 | Regression coverage catches unsafe movement, attacks during holds, wrong-room loot, target-removal queue drift, stale callbacks/retries, and permanent walk stalls. | ✓ VERIFIED | Named fence, gold, aggregate-owner, timeout, optional-walker, and trace tests passed 9/9 in separate exact-name invocations; the 132- and 153-case aggregates also passed with zero failures/errors/pending. |

**Score:** 5/5 roadmap truths verified (0 present-but-behavior-unverified)

### Gap Closure Mapping

| Gap | Required outcome | Current code/test evidence | Status |
|---|---|---|---|
| G-03-1 | Resolve live List/Info ordering without stale-room authority, preserve same-room state, and emit one move after stop/restart. | `startRoomObservation` invalidates but retains old fences (`boop_runtime.lua:221`); `beginRoomResponseFence` records authority before sends (`boop_runtime.lua:270`, `boop_events.lua:295`); `observeRoomItemsList` consumes only the queue head in Inv→Room order (`boop_runtime.lua:328`); same-room `onRoomInfo` preserves complete evidence (`boop_events.lua:1317`); `onWalkArrived` discards all event arguments (`boop_events.lua:1465`). Exact serialized-fence and tokenless-restart tests each passed 1/1. | ✓ CLOSED |
| G-03-2 | Preserve current pickup across same-room Info, cancel only actual movement, use confirmed success as the inventory transfer, and issue one independent put. | `onRoomInfo` determines same-room before lifecycle cancellation; `canonicalGoldEvidence` reads only accepted copied items; `transferGoldToPacking` clears room identity; room removal remains observational; get success is the transfer authority (`boop_events.lua:510-541`, `929-985`, `1089`, `1221`, `1317`). Exact either-order and wrong-room/movement tests each passed 1/1. | ✓ CLOSED |
| Trace fixture | Exercise, rather than bypass, the response-fence contract. | `tests/boop_trace_spec.lua:35` opens the fence and publishes Inv then Room before trace assertions. The exact trace test passed 1/1 and is included in the 153/153 aggregate. | ✓ CLOSED |

## Required Artifacts

All 13 PLAN frontmatter checks passed: **63/63 artifact declarations** and **35/35 key-link declarations**.

| Artifact | Expected | Status | Details |
|---|---|---|---|
| `src/scripts/boop/boop_runtime.lua` | Owner aggregation, serialized response-fence queue, copied accepted observations, exact releases | ✓ VERIFIED | Substantive and wired through events, gold, targets, tick, and walker. Invalid fences remain drain-only queue records; accepted snapshots are deep copies. |
| `src/scripts/boop/boop_events.lua` | Fence request/consumption, actual-room-change detection, staged gold lifecycle, tokenless walker adapter | ✓ VERIFIED | Substantive and wired. The fence is recorded before exact `Char.Items.Inv` then `Char.Items.Room` sends; only an `accepted` room transition reaches targets, gold, settlement, and tick. |
| `src/scripts/boop/boop_walk.lua` | Optional integration, lifecycle ownership, shared safety evaluator, one-shot guarded emitter | ✓ VERIFIED | Substantive and wired. Start/stop/arrival/room-settlement paths retain generation and reservation identity through final emission. |
| `src/scripts/boop/boop_util.lua` | Combat action dispatch independent from gold commands | ✓ VERIFIED | No get/put chaining is added to supplied combat actions; gold sends through its separate freestand command path. |
| `tests/boop_event_transitions_spec.lua` | Fence ordering, wrong-room cancellation, owner/event interleavings, target-removal drift | ✓ VERIFIED | Current assertions cover pre-barrier, invalidated, delayed, duplicate, same-room, stale-callback, and one-shot terminal behavior. |
| `tests/boop_gold_spec.lua`, `tests/boop_gold_retry_spec.lua`, `tests/boop_tick_spec.lua` | Canonical evidence, get-confirm-put ordering, retry/timer/owner behavior | ✓ VERIFIED | Both removal orders, removal non-authority, roomless packing, actual-change cancellation, fired-token consumption, and unchanged-stage resumption are exercised. |
| `tests/boop_walk_spec.lua` | Arrival, stop/restart, stale drains/timers, blockers, one move, optional package behavior | ✓ VERIFIED | Current tests assert same-room reservation preservation, invalidated response draining, exact one move, stale no-ops, timeout visibility, and no implicit install/update. |
| `tests/boop_trace_spec.lua` | Trace behavior through canonical room acceptance | ✓ VERIFIED | HEAD `d9a3fc9` routes trace room fixtures through the production Inv→Room fence. |

## Key Link Verification

| From | To | Via | Status | Details |
|---|---|---|---|---|
| Room boundary | Response authority | `startRoomObservation` → `beginRoomResponseFence` before two ordered GMCP requests | ✓ WIRED | Fresh start or actual room change owns generation reset; same-room complete Info does not reset. |
| GMCP item Lists | Accepted room data | Queue-head `await_inv` → `await_room`, exact generation/room/current-GMCP checks, deep copy | ✓ WIRED | Pre-barrier, out-of-order, invalidated, duplicate, nil, and stale responses do not reach consumers. |
| Accepted room data | Targets, gold, tick, walker | `onRoomItemsList` branches only on `transition.status == "accepted"` | ✓ WIRED | No persistent `gmcp.Char.Items.List` fallback authorizes current-room behavior. |
| Tokenless arrival | Current incomplete epoch | Event adapter drops all arguments; `onArrived` may only call the already-capped fence requester | ✓ WIRED | Arrival never creates evidence, advances a generation, settles, reserves, or emits. |
| Gold evidence | Get/retry | Exact copied accepted item + operation room/generation/item + aggregate owner checks | ✓ WIRED | Same-room acquisition survives; actual movement cancels; wrong-room and stale callbacks send nothing. |
| Pickup success | Packing | `onGoldGetSuccess` → roomless `PACK_PENDING` → one guarded put | ✓ WIRED | Removal alone is observational. Packing can survive movement and remains independent from combat actions. |
| Aggregate all-clear | Attack/gold/walk boundaries | Every relevant owner checked; only the lifecycle's exact owner may be excluded | ✓ WIRED | Clearing one of two owners cannot emit; one normal reevaluation occurs only after final release. |
| Walker reservation | `demonwalker.move` | Run generation + room generation + reservation + package + full final safety recheck | ✓ WIRED | Stale timers and callbacks are zero-effect; an accepted clear room emits one move. |

## Data-Flow Trace (Level 4)

| Artifact | Data | Source | Produces authoritative data | Status |
|---|---|---|---|---|
| `boop_runtime.lua` | `roomObservation.fenceQueue` / `acceptedItems` | Explicit request fence and copied GMCP Inv→Room responses | Yes; FIFO queue-head acceptance tied to current room and generation | ✓ FLOWING |
| `boop_events.lua` | `state.gold.operation` | Accepted copied room observation, gold item identity, success/failure/removal/room events | Yes; room-owned acquisition becomes roomless packing only on success | ✓ FLOWING |
| `boop_runtime.lua` | `combat.blockersByOwner` | Diag, interrupt, pull, room, gold, target, flee, and walker lifecycles | Yes; sorted snapshots and aggregate `shouldHold` retain every unrelated owner | ✓ FLOWING |
| `boop_walk.lua` | Run/room/reservation state | Operator lifecycle plus accepted room observation | Yes; one timer callback performs the final all-clear recheck before the external event | ✓ FLOWING |
| `boop_trace_spec.lua` | Trace room item fixture | Production fence helper at current HEAD | Yes; no direct persistent-GMCP shortcut | ✓ FLOWING |

## Behavioral Spot-Checks

| Behavior | Command/check | Result | Status |
|---|---|---|---|
| Plan 03-13 focused aggregate | Host Busted: gold + gold retry + event transitions + tick + walk | 132 successes, 0 failures, 0 errors, 0 pending | ✓ PASS |
| Broader parent-equivalent regression | Host Busted: state contract + runtime + safety + event transitions + trace + UI + walk | 153 successes, 0 failures, 0 errors, 0 pending | ✓ PASS |
| Serialized invalidated-fence draining | Exact Busted name in `boop_event_transitions_spec.lua` | 1 success | ✓ PASS |
| Tokenless stop/restart to one move | Exact Busted name in `boop_walk_spec.lua` | 1 success | ✓ PASS |
| Gold success/removal either order | Exact Busted name in `boop_gold_spec.lua` | 1 success | ✓ PASS |
| Wrong-room gold and actual-change cancellation | Exact Busted name in `boop_event_transitions_spec.lua` | 1 success | ✓ PASS |
| Aggregate attack and gold/walk ownership | Two exact Busted names in runtime/tick specs | 2/2 successes | ✓ PASS |
| Fired timeout to one guarded move | Exact Busted name in `boop_walk_spec.lua` | 1 success | ✓ PASS |
| Optional walker no implicit install/update | Exact Busted name in `boop_walk_spec.lua` | 1 success | ✓ PASS |
| Trace fixture through response fence | Exact Busted name in `boop_trace_spec.lua` | 1 success | ✓ PASS |
| Lua syntax | `luac -p` over every Lua file under `src/` and `tests/` | Exit 0 | ✓ PASS |
| Release/version/state gates | `python3 tools/check_release_gates.py` | `[OK] versions`, `[OK] manifests`, `[OK] state-drift` | ✓ PASS |
| Package construction | `muddle` under PTY | Muddler 1.1.0 built `build/boop Hunter.mpackage` at 0.1.423 | ✓ PASS |

Host Busted is diagnostic evidence only. It does not replace the real Mudlet execution environment.

## Probe Execution

Step 7c was skipped: no Phase 03 PLAN/SUMMARY declares a probe, and repository discovery found no `scripts/**/tests/probe-*.sh` files.

## Requirements Coverage

| Requirement | Source plans | Status | Evidence |
|---|---|---|---|
| SAFE-02 | 03-01, 03-02, 03-03, 03-08, 03-09 | ✓ SATISFIED | Exact-owner interrupt/pull/diag/manual gates and two-owner attack/prequeue release behavior are implemented and included in the 153/153 regression. |
| SAFE-04 | 03-01, 03-04, 03-05, 03-08 through 03-11, 03-13 | ✓ SATISFIED | Canonical response-fenced gold evidence, actual-change cancellation, get-confirm-put transfer, retries, stale callbacks, and aggregate holds pass the named and 132-case checks. |
| WALK-01 | 03-01, 03-06, 03-07, 03-09, 03-11, 03-12 | ✓ SATISFIED | Start/stop/move/status, settlement, blocker reasons, tokenless arrival, stale generations, and event emission are implemented and tested. |
| WALK-02 | 03-01, 03-06 through 03-13 | ✓ SATISFIED | Target, denizen, leader, gold, diag, pull, flee, room, package, and aggregate owners are rechecked through reservation emission; one safe move follows release. |
| WALK-03 | 03-06 through 03-09, 03-11, 03-12 | ✓ SATISFIED | The walker remains optional; only explicit install uses the package API; status/start/move never install or update. |

No Phase 03 requirement is orphaned. All five IDs are mapped exclusively to Phase 03 in `REQUIREMENTS.md` and are claimed by phase plans.

## Anti-Patterns Found

| File/scope | Pattern | Severity | Impact |
|---|---|---|---|
| Phase 03 source/tests/docs | `TBD`, `FIXME`, `XXX` | None | No unresolved debt marker or blocker. |
| Phase 03 source/tests/docs | `TODO`, `HACK`, `PLACEHOLDER`, user-visible placeholder wording | None | No incomplete implementation found. Existing “not available” messages are intentional fail-closed operator diagnostics. |
| Focused host tests | Synthetic GMCP, timer, package, and event stubs | ℹ️ Info | Intentional deterministic test infrastructure; it is why live Achaea confirmation remains required. |

## Human Verification Required

### 1. Live serialized room fence and aggregate release

**Test:** Repeat the UAT flow that exposed G-03-1 with tracing enabled: observe a room List before Room.Info, repeat same-room Info, exercise stop/restart, and overlap diag, interrupt, or pull with target/gold ownership.

**Expected:** Early and stale Lists authorize nothing. Room.Info requests one Inv→Room pair, the accepted pair settles the current room, same-room Info preserves it, and no attack/loot/move occurs before aggregate all-clear. Exactly one next action and one walker move then occur.

**Why human:** Real GMCP ordering, server queue timing, and demonwalker execution are external to the host harness.

### 2. Live canonical same-room gold pipeline

**Test:** Repeat the UAT flow that exposed G-03-2. Verify current-room acquisition through same-room Info; exercise removal-before-success and success-before-removal; move before pickup in one run and after confirmed pickup in another.

**Expected:** One current-room get is sent. Same-room Info does not cancel it. Actual movement cancels room-owned acquisition once. Removal alone never creates packing. Confirmed pickup permits one roomless put even after movement. Combat commands contain no get/put chaining.

**Why human:** Achaea item lines, inventory confirmation, and room/inventory GMCP callback timing require a live profile.

## External Authority Boundaries

- `/tmp/Mudlet.AppImage` is absent, so no local real-Mudlet suite was run.
- The independently passing 132/132 and 153/153 host Busted runs are diagnostic, not Mudlet-equivalent authority.
- The optional walker/stop-ownership live UAT already passed and is not an outstanding item.
- Phase 6 owns recorded real-Mudlet and live-release evidence.
- The parent owns the immutable-final-HEAD push and `tools/wait_for_exact_ci.sh` gate after this uncommitted report is inspected and committed. This report does not claim exact-final-HEAD GitHub CI.
- Verification commands left the worktree clean before this report was written. Generated Muddler output is ignored and unstaged.

## Gaps Summary

No code or regression gap remains. G-03-1, G-03-2, and the trace-fixture mismatch are closed at HEAD `d9a3fc9` with synchronized package version `0.1.423`. Automated score is 5/5 with no behavior-unverified truth. Status is `human_needed` solely for the two post-fix live Achaea UAT reruns.

---

_Verified: 2026-07-27T03:07:43Z_
_Verifier: Codex (gsd-verifier)_
