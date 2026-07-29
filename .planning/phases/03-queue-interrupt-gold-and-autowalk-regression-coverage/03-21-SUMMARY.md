---
phase: 03-queue-interrupt-gold-and-autowalk-regression-coverage
plan: 21
subsystem: combat-dispatch-authority
tags: [lua, mudlet, gmcp, source-authority, stale-dispatch]

requires:
  - phase: 03-queue-interrupt-gold-and-autowalk-regression-coverage
    provides: Plan 03-20 immutable room-application authority and moved-room invalidation
provides:
  - Exact room authority carried through automatic target, standard, rage, prequeue, refresh, and retarget dispatch
  - Final send-boundary validation for BOOP_ATTACK alias/queue commands and direct standard/rage segments
  - A 4255-to-4249 stale-dispatch regression with live generation-46 controls
affects: [03-22, 03-23, 03-24, live-uat]

tech-stack:
  added: []
  patterns:
    - Deferred room-owned callbacks close over immutable authority and never reacquire destination authority
    - Room-owned state and send boundaries return success only after exact authority validation
    - Explicit non-room command families retain their authority-free compatibility path

key-files:
  created: []
  modified:
    - tests/boop_event_transitions_spec.lua
    - src/scripts/boop/boop_runtime.lua
    - src/scripts/boop/boop_events.lua
    - src/scripts/boop/boop_targets.lua
    - src/scripts/boop/boop_attacks.lua
    - src/scripts/boop/boop_util.lua
    - src/scripts/boop/boop_init.lua
    - mfile
    - CODEX.md

key-decisions:
  - "Deferred leader-target, prequeue, refresh, and target-loss work reuses the exact authority captured at creation and never substitutes current-room authority."
  - "Queued standards validate before setalias and again before queue insertion; direct standard and rage segments validate before every send."
  - "Room-owned effects fail closed when explicitly missing authority, while intentional non-room/manual callers preserve their existing optionless path."

patterns-established:
  - "Final Dispatch Fence: every irreversible automatic target/combat send validates its immutable room application immediately before emission."
  - "Success-Gated Side Effects: target stats, opener/shield/rage state, gag intent, alias cache, and limiter success advance only after authorized downstream work."

requirements-completed: [SAFE-02, SAFE-04, WALK-02]

coverage:
  - id: D1
    description: "Generation-45 target and combat work emits no local or external effects after movement from room 4255 to 4249."
    requirement: SAFE-02
    verification:
      - kind: integration
        ref: "tests/boop_event_transitions_spec.lua#G-03-7 4255-to-4249 external dispatch fence"
        status: pass
    human_judgment: false
  - id: D2
    description: "Delayed leader-target, prequeue, refresh, and retarget callbacks retain generation-45 authority without destination-authority substitution."
    requirement: SAFE-04
    verification:
      - kind: integration
        ref: "tests/boop_event_transitions_spec.lua#keeps every delayed generation-45 callback on its captured authority after movement"
        status: pass
    human_judgment: false
  - id: D3
    description: "Current generation-46 target, combat, prequeue, refresh, and retarget paths remain live exactly once without queue-wide cleanup."
    requirement: WALK-02
    verification:
      - kind: integration
        ref: "tests/boop_event_transitions_spec.lua#keeps current generation-46 target, combat, prequeue, refresh, and retarget paths live"
        status: pass
    human_judgment: false

duration: 14m32s
completed: 2026-07-29
status: complete
---

# Phase 03 Plan 21: Room-Owned Combat Dispatch Summary

Immutable room authority now reaches every automatic target/combat send boundary, making stale generation-45 work inert after movement while generation 46 remains live.

## Performance

- **Duration:** 14m32s
- **Started:** 2026-07-29T05:34:27Z
- **Completed:** 2026-07-29T05:48:59Z
- **Tasks:** 1
- **Files modified:** 9

## Accomplishments

- Carried copied `{applicationId, roomId, observationGeneration}` authority through runtime target/combat effects, leader wake-up, delayed prequeue, shield refresh, and target-loss retarget work.
- Added final validation before target mutation/calls, BOOP_ATTACK alias and queue sends, every direct standard/rage segment, and success-dependent combat state/stat updates.
- Added exact 4255-to-4249 regression coverage proving zero stale dispatch, no destination-authority substitution, no queue-wide cleanup, and current generation-46 liveness.
- Synchronized package version 0.1.443 and built the package successfully with Muddler.

## Task Commits

Each task was committed atomically:

1. **Task 1: Revalidate exact room authority through target and combat dispatch** - `e8b8b62` (fix)

## Files Created/Modified

- `tests/boop_event_transitions_spec.lua` - Adds stale generation-45, delayed-callback provenance, missing-authority, non-room, and current generation-46 controls.
- `src/scripts/boop/boop_runtime.lua` - Carries room ownership and copied authority into effects and rejects stale or explicitly tokenless room-owned application.
- `src/scripts/boop/boop_events.lua` - Captures and threads authority through tick, prequeue, refresh, prompt, and deferred target-loss paths.
- `src/scripts/boop/boop_targets.lua` - Guards target mutation, stats, target calls, and sends; captures leader-target callback authority.
- `src/scripts/boop/boop_attacks.lua` - Counts combat only after authorized downstream emitters succeed and gates opener/shield/rage side effects.
- `src/scripts/boop/boop_util.lua` - Revalidates room-owned authority at every standard/rage send boundary.
- `src/scripts/boop/boop_init.lua` - Synchronizes package version 0.1.443.
- `mfile` - Synchronizes package title and version 0.1.443.
- `CODEX.md` - Synchronizes the repository package-version checkpoint.

## Decisions Made

- Scheduled room work closes over copied authority; callbacks do not call the current-authority accessor after creation.
- Automatic work with settled authority is room-owned and fail-closed; explicit non-room/manual command families retain optionless compatibility.
- State, stats, readiness, gag intent, alias cache, and limiter success are downstream-success effects, not optimistic pre-send effects.
- Stale rejection remains local and never sends `queue clear` or removes unrelated blocker/queue ownership.

## Verification

- Focused event-transition host spec: 53 successes, 0 failures, 0 errors.
- Adjacent prequeue, tick, target-call, and runtime host specs: 63 successes, 0 failures, 0 errors.
- `luac -p` passed for runtime, events, targets, attacks, and utility modules.
- `git diff --check` passed.
- `python3 tools/check_release_gates.py` passed versions, manifests, and state-drift immediately before commit.
- Direct `muddle` built `boop Hunter` 0.1.443 successfully after the final source adjustment.

## Deviations from Plan

None - plan executed exactly as written.

## Known Stubs

None. Stub-pattern scans found no placeholder or unwired plan behavior in the modified files.

## Issues Encountered

- The first sandboxed Muddler invocation could not access Docker. The required direct command was rerun with approved container access and completed successfully.
- Broad attack-profile host coverage remains subject to the pre-existing focused-helper limitation already recorded in `deferred-items.md`; all focused and adjacent authority-sensitive suites passed.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- G-03-7's stale external-dispatch half is closed with host chronology evidence and a successful package build.
- Plans 03-22 through 03-24 can rely on exact room authority through the final target/combat send boundary.
- Parent orchestration still owns the immutable-final-HEAD push, exact-SHA CI gate, and live 4255-to-4249 Mudlet/Achaea trace.

## Self-Check: PASSED

- All nine task files and this summary exist.
- Task commit `e8b8b62` exists and contains no file deletions.
