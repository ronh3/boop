---
phase: 03-queue-interrupt-gold-and-autowalk-regression-coverage
plan: 23
subsystem: gold-queue-ownership
tags: [lua, mudlet, native-queue, gold, ownership, stale-timer]

requires:
  - phase: 03-20
    provides: generation-owned copied room applications
  - phase: 03-21
    provides: exact room authority through irreversible dispatch
  - phase: 03-22
    provides: target-loss recovery from authoritative fresh room evidence
provides:
  - deterministic native queue replacement and validation model for host tests
  - phase-specific full pickup and freestand packing queues
  - exact interrupt-owned displacement and single replay for sent pickup or pack work
  - nonterminal explicit-evidence hold after a replay's fresh timeout
affects: [03-24, gold, diag, live-uat]

tech-stack:
  added: []
  patterns:
    - destructive native queue replacement transfers exact operation ownership before clearing
    - every gold dispatch has monotonic identity and explicit initial, retry, or displacement-replay provenance
    - elapsed time consumes replay timer authority but cannot terminally abandon gold work

key-files:
  created: []
  modified:
    - tests/support/boop_test_helper.lua
    - tests/boop_gold_spec.lua
    - tests/boop_gold_retry_spec.lua
    - tests/boop_walk_spec.lua
    - tests/boop_tick_spec.lua
    - tests/boop_event_transitions_spec.lua
    - tests/boop_runtime_spec.lua
    - src/scripts/boop/boop_events.lua
    - mfile
    - src/scripts/boop/boop_init.lua
    - CODEX.md

key-decisions:
  - "Pickup dispatch uses the full queue while packing remains an independent freestand command."
  - "A destructive queue replacement invalidates only the exact sent dispatch timer and preserves the gold operation's owner, generation, phase, evidence, and retry authority."
  - "A fresh displacement-replay timeout enters an actionable explicit-evidence wait instead of completing with pending_timeout or becoming automatically replayable."

patterns-established:
  - "Gold dispatch identity: timer callbacks require exact operation generation, phase, timer token, and dispatch ID."
  - "Replay timeout recovery: normal ticks remain inert until explicit result/failure or stage-valid movement, disable, or flee evidence."

requirements-completed: [SAFE-02, SAFE-04, WALK-02]

coverage:
  - id: G03-8-D1
    description: "The host queue model applies clearqueue all and addclearfull as global removals and rejects a nameless queue clear."
    requirement: SAFE-02
    verification:
      - kind: unit
        ref: "tests/boop_gold_retry_spec.lua#models native global queue replacement and rejects a nameless clear"
        status: pass
    human_judgment: false
  - id: G03-8-D2
    description: "Pickup and pack preserve exact ownership and replay once after both stale-timeout/release orderings."
    requirement: SAFE-04
    verification:
      - kind: integration
        ref: "tests/boop_gold_retry_spec.lua#displacement ordering matrix"
        status: pass
    human_judgment: false
  - id: G03-8-D3
    description: "A replay's fresh timeout is nonterminal, warning-backed, nonduplicating, and releasable exactly once by movement or disable."
    requirement: SAFE-04
    verification:
      - kind: integration
        ref: "tests/boop_gold_retry_spec.lua#fresh replay timeout and invalidation matrix"
        status: pass
    human_judgment: false
  - id: G03-8-D4
    description: "Initial, retry, and replay pickup uses full while every packing path remains on freestand."
    requirement: WALK-02
    verification:
      - kind: integration
        ref: "required six-spec focused Busted run"
        status: pass
    human_judgment: false

duration: 31m
completed: 2026-07-29
status: complete
---

# Phase 03 Plan 23: Exact Gold Queue Displacement Summary

**Generation-owned pickup and pack dispatches now survive destructive native queue replacement, replay once after exact owner release, and remain held for explicit evidence when a fresh replay timer expires.**

## Performance

- **Duration:** 31m
- **Started:** 2026-07-29T06:35:00Z
- **Completed:** 2026-07-29T07:06:14Z
- **Tasks:** 1
- **Files modified:** 11

## Accomplishments

- Added a deterministic native queue adapter that snapshots named queues, models global `clearqueue all` and `queue addclearfull` removal, and records invalid nameless clear commands.
- Changed initial, retried, and displacement-replayed pickup to `queue add full get sovereigns` while retaining `queue add freestand put sovereigns in <pack>` for packing.
- Added exact dispatch identity, displacement owner/phase provenance, single post-release replay, and stale old-timer rejection for pickup and pack.
- Made a replay's fresh timeout consume only its exact token, retain the gold owner/evidence/retry budget, expose stage-specific recovery status, and prohibit duplicate replay.
- Synchronized package version `0.1.446`.

## Task Commits

1. **Task 1: Model native queue displacement and make gold replay exact, then bump the synchronized package version** - `6456f34` (fix)

## Files Created/Modified

- `tests/support/boop_test_helper.lua` - Adds the deterministic native queue model and snapshots.
- `tests/boop_gold_retry_spec.lua` - Covers queue semantics, both stages, both old-timeout orderings, fresh replay timeouts, explicit failure/result evidence, and exact invalidation.
- `tests/boop_gold_spec.lua` - Asserts canonical queue types and drives generation-owned zero-delay room applications.
- `tests/boop_walk_spec.lua` - Updates held-gold pickup assertions to the full queue.
- `tests/boop_tick_spec.lua` - Updates real flee-stage pickup assertions to the full queue.
- `tests/boop_event_transitions_spec.lua` - Updates integrated gold dispatch expectations to the full queue.
- `tests/boop_runtime_spec.lua` - Updates runtime effect expectations to the full queue.
- `src/scripts/boop/boop_events.lua` - Implements phase queues, exact displacement/replay ownership, dispatch identity, and explicit-evidence timeout hold.
- `mfile` - Synchronizes package title and version at `0.1.446`.
- `src/scripts/boop/boop_init.lua` - Synchronizes runtime package version at `0.1.446`.
- `CODEX.md` - Updates the synchronized package-version checkpoint.

## Decisions Made

- Replay remains on the ordinary tick/flush path; releasing an interrupt does not directly dispatch gold.
- The destructive coordinator must supply an already-active exact blocker owner to `boop.displaceGoldQueueIntent`; absent, stale, deferred-room, or already-held operations are rejected.
- Replay provenance, rather than elapsed time or a longer timeout, selects the nonterminal fresh-timeout behavior.
- Stage-specific status keeps the existing gold owner/code while changing label, waits-for evidence, and observations to show the safe recovery route.

## Automated Evidence

- Test-first RED: `7 successes / 5 failures / 3 errors`; failures showed the old freestand pickup behavior and missing displacement entry point.
- Final focused Busted:
  - `tests/boop_gold_spec.lua`: 9 successes.
  - `tests/boop_gold_retry_spec.lua`: 17 successes.
  - `tests/boop_walk_spec.lua`: 45 successes.
  - `tests/boop_tick_spec.lua`: 30 successes.
  - `tests/boop_event_transitions_spec.lua`: 55 successes.
  - `tests/boop_runtime_spec.lua`: 14 successes.
  - Total: 170 successes, 0 failures, 0 errors.
- `luac -p` passed for every modified Lua source and spec.
- `git diff --check` passed.
- `python3 tools/check_release_gates.py` passed versions, manifests, and state-drift immediately before commit.
- Direct `muddle` built `boop Hunter 0.1.446` successfully.
- Acceptance scan found no remaining `queue add freestand get sovereigns` in `src/` or `tests/`.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Updated stale synchronous room-application fixtures**

- **Found during:** Task 1 focused verification
- **Issue:** Three existing `boop_gold_spec.lua` cases failed at the pre-task HEAD because they expected room evidence to apply synchronously, but Plans 03-20 and 03-21 moved accepted copied room applications behind exact zero-delay callbacks.
- **Fix:** Drove the newly scheduled zero-delay application callback and preserved the accepted copied item identity in the same-room pipeline.
- **Files modified:** `tests/boop_gold_spec.lua`, `tests/boop_gold_retry_spec.lua`
- **Verification:** Gold specs pass 9/9 and gold retry specs pass 17/17 without changing target-loss production behavior.
- **Committed in:** `6456f34`

**Total deviations:** 1 auto-fixed blocking fixture issue.

**Impact on plan:** The fixture adjustment was required to run the plan's mandated focused suites against the already-committed generation-owned room-application contract. No feature scope was added.

## Known Stubs

None. Empty values found by the stub scan are normal runtime initialization, reset state, or deterministic test fixtures.

## Issues Encountered

- The first direct `muddle` invocation lacked a terminal and failed before the build started. Re-running the same command with a TTY attached built package `0.1.446` successfully.

## User Setup Required

None.

## Next Phase Readiness

- Plan 03-24 can call `boop.displaceGoldQueueIntent` with its exact diag interrupt owner immediately before destructive native queue replacement.
- The native queue adapter is ready for real diag integration tests covering valid `clearqueue all` plus `queue addclearfull freestand diagnose`.
- No package push or exact-SHA CI was performed, per the explicit Plan 03-23 request; parent final-phase orchestration retains that gate.

## Self-Check: PASSED

- All eleven planned task files and this summary exist.
- Task commit `6456f34` exists and contains no tracked-file deletions.
- Focused Busted, Lua syntax, diff hygiene, release gates, and direct `muddle` verification passed.
