---
phase: 03-queue-interrupt-gold-and-autowalk-regression-coverage
plan: 20
subsystem: room-evidence-runtime
tags: [lua, mudlet, gmcp, room-fence, source-authority]

requires:
  - phase: 03-queue-interrupt-gold-and-autowalk-regression-coverage
    provides: Phase 03 queue, gold, walk, and room-response regression harness
provides:
  - Order-independent copied Inv/Room response latches with exact-once settlement
  - Deferred room-application records carrying immutable three-field source authority
  - Stale Room.Info invalidation before target, gold, walk, or tick effects
affects: [03-21, 03-22, 03-23, 03-24]

tech-stack:
  added: []
  patterns:
    - Independent copied response latches finalize only after both required halves arrive
    - Room-owned effects validate captured application authority before mutation
    - Zero-delay callbacks are invalidated by exact application identity on room movement

key-files:
  created: []
  modified:
    - src/scripts/boop/boop_runtime.lua
    - src/scripts/boop/boop_events.lua
    - tests/boop_event_transitions_spec.lua
    - src/scripts/boop/boop_init.lua
    - mfile
    - CODEX.md

key-decisions:
  - "Treat Inv and Room responses as independent copied latches so either arrival order settles exactly once."
  - "Apply accepted room evidence only through a zero-delay application record carrying applicationId, roomId, and observationGeneration."
  - "Invalidate moved-room applications and local attack intent without clearing unrelated shared queue ownership."

patterns-established:
  - "Room Application Authority: room-owned consumers and effects carry and validate the same immutable three-field authority."
  - "Fence Duplicate Suppression: first valid halves are copied, later duplicates are drain-only, and completed fences cannot settle twice."

requirements-completed: [SAFE-02, SAFE-04, WALK-01, WALK-02]

duration: 9m35s
completed: 2026-07-29
status: complete
---

# Phase 03 Plan 20: Order-Independent Room Evidence Summary

Copied Inv/Room latches now settle in either order through one deferred, provenance-checked room application that becomes inert after movement.

## Performance

- **Duration:** 9m35s
- **Started:** 2026-07-29T05:21:22Z
- **Completed:** 2026-07-29T05:30:57Z
- **Tasks:** 1
- **Files modified:** 6

## Accomplishments

- Replaced strict Inv-before-Room settlement with independent copied latches that accept either response order exactly once and suppress duplicates.
- Added zero-delay room-application records with immutable `{applicationId, roomId, observationGeneration}` authority propagated through contexts and room-owned effects.
- Made moved `Room.Info` invalidate stale applications, timers, and local attack intent before target, gold, walk, or tick mutation while preserving unrelated queue ownership.
- Added G-03-7 chronology coverage for rooms 4255 to 4249 plus room-only, FIFO drain, copied-payload, aggregate-blocker, and missing-scheduler regressions.

## Task Commits

Each task was committed atomically:

1. **Task 1: Make Room.List and Inv.List order-independent behind exact source authority** - `33fce00` (fix)

## Files Created/Modified

- `src/scripts/boop/boop_runtime.lua` - Adds independent fence latches, application lifecycle APIs, source-authority validation, and provenance-aware effects.
- `src/scripts/boop/boop_events.lua` - Defers accepted room consumption and propagates captured authority into target, gold, walk, and tick paths.
- `tests/boop_event_transitions_spec.lua` - Covers both response orders, duplicate suppression, copied evidence, stale application callbacks, and compatibility paths.
- `src/scripts/boop/boop_init.lua` - Synchronizes package version 0.1.442.
- `mfile` - Synchronizes package title and version 0.1.442.
- `CODEX.md` - Synchronizes the repository package-version checkpoint.

## Decisions Made

- Inv and Room evidence are copied independently and become authoritative only when the current fence has every required half.
- Accepted evidence never applies synchronously; one zero-delay callback must claim the exact application before any room-owned consumer runs.
- Provenance checks use the callback's captured authority rather than rereading destination state, preventing stale work from borrowing current-room authority.
- Room-only gold revalidation retains its one-half fence behavior and enters the same deferred application path.

## Verification

- `env BOOP_REPO_ROOT="$PWD" TESTS_DIRECTORY="$PWD/tests" busted --helper=tests/support/boop_host_busted_helper.lua tests/boop_event_transitions_spec.lua` - 50 successes, 0 failures, 0 errors.
- `luac -p src/scripts/boop/boop_runtime.lua` - passed.
- `luac -p src/scripts/boop/boop_events.lua` - passed.
- `git diff --check` - passed.
- `python3 tools/check_release_gates.py` - versions, manifests, and state-drift passed immediately before commit.
- `muddle` - package 0.1.442 built successfully in the required PTY.
- Added-code scan found no non-zero room-application delay and no queue-wide cleanup.

## Deviations from Plan

None - plan executed exactly as written.

## Known Stubs

None. Empty values found by the scan are existing runtime defaults or test fixtures, not unwired plan behavior.

## Issues Encountered

- Muddler requires a terminal for its container wrapper; the initial non-PTY invocation failed before building, and the identical command passed in a PTY.

## Next Phase Readiness

- G-03-7 is closed with host-level chronology evidence and a successful package build.
- Plans 03-21 through 03-24 can build on exact room-application authority without relying on strict GMCP response order.

## Self-Check: PASSED

- All six task files and this summary exist.
- Task commit `33fce00` exists and contains no file deletions.
