---
phase: 03-queue-interrupt-gold-and-autowalk-regression-coverage
plan: "07"
subsystem: runtime-safety
tags: [lua, mudlet, autowalk, lifecycle, ownership, generations, regression-tests]
requires:
  - phase: 03-queue-interrupt-gold-and-autowalk-regression-coverage
    plan: "06"
    provides: canonical walker generations, room observations, reservations, exact-owner blockers, and guarded deferred movement
provides:
  - Ownership-aware stop that ends only boop-owned demonwalker runs
  - Attached-run detach that preserves the external walker
  - Fresh restart state with no inherited room, settlement, blocker, reservation, or timer authority
  - Run- and room-generation guards across Room.Info, complete-list, arrived, and finished callbacks
  - External finish and package-loss invalidation before exact-owner cleanup or replacement
affects: [03-08, 03-09, 06-docs-help-and-live-release-verification]
tech-stack:
  added: []
  patterns:
    - Capture walker ownership and exact owner before invalidating callback authority and performing external effects.
    - Treat every new run as a fresh room-observation lifecycle.
    - Normalize Mudlet event-name metadata before forwarding optional numeric generation tokens.
key-files:
  created:
    - .planning/phases/03-queue-interrupt-gold-and-autowalk-regression-coverage/03-07-SUMMARY.md
  modified:
    - src/scripts/boop/boop_walk.lua
    - src/scripts/boop/boop_events.lua
    - tests/boop_walk_spec.lua
    - tests/boop_event_transitions_spec.lua
    - mfile
    - src/scripts/boop/boop_init.lua
    - CODEX.md
key-decisions:
  - "Invalidate the current walker generation and exact reservation before owner cleanup, operator output, or an owned external stop event."
  - "Detach attached runs locally without changing demonwalker.enabled or raising demonwalker.stop."
  - "Require a new shared Room.Info plus complete room-item observation after every restart, even when the room number is unchanged."
  - "Normalize nonnumeric Mudlet event-name arguments to absent generation tokens while preserving numeric stale-callback guards."
patterns-established:
  - "Walker stop boundary: snapshot ownership and owner, invalidate, clear the exact owner, reset local state, then emit an owned-only external stop."
  - "Walker restart boundary: clear prior owner authority, start a fresh room observation, and hold walk:<generation> as unsettled until current complete evidence."
  - "Event adapter boundary: compare captured run and room generations before any callback mutation."
requirements-completed: [WALK-01, WALK-02, WALK-03]
coverage:
  - id: D1
    description: Owned stop invalidates timers, reservation, generation, and exact owner before raising one external stop, while attached stop performs a local detach with no external stop.
    requirement: WALK-01
    verification:
      - kind: unit
        ref: "tests/boop_walk_spec.lua#owned stop and attached detach ordering, counts, state, and exact operator output"
        status: pass
      - kind: other
        ref: "TESTS_DIRECTORY=\"$PWD/tests\" BOOP_REPO_ROOT=\"$PWD\" busted --helper=/tmp/boop_host_helper_0307.lua tests/boop_walk_spec.lua tests/boop_event_transitions_spec.lua"
        status: pass
    human_judgment: false
  - id: D2
    description: Restart creates fresh run and room generations, an unsettled exact owner, and no inherited callback, reservation, timer, settlement, or queued-move authority.
    requirement: WALK-02
    verification:
      - kind: unit
        ref: "tests/boop_walk_spec.lua#restart requires fresh Room.Info and complete room items and rejects old callbacks"
        status: pass
      - kind: unit
        ref: "tests/boop_event_transitions_spec.lua#current same-room Room.Info and complete list advance only the new generation"
        status: pass
    human_judgment: false
  - id: D3
    description: Room.Info, complete-list, arrived, and finished handlers reject stale run or room generations without state, output, timer, or external-event effects.
    requirement: WALK-01
    verification:
      - kind: unit
        ref: "tests/boop_walk_spec.lua#stale arrived, settled, room-change, and finished callback snapshots"
        status: pass
      - kind: unit
        ref: "tests/boop_event_transitions_spec.lua#stale event adapters and Mudlet event-name metadata"
        status: pass
    human_judgment: false
  - id: D4
    description: Mid-run package loss and external finish invalidate deferred movement first, then update or clear only the captured owner without package installation or update.
    requirement: WALK-03
    verification:
      - kind: unit
        ref: "tests/boop_walk_spec.lua#external finish and package-loss invalidation, owner, event, install, and update assertions"
        status: pass
      - kind: other
        ref: "python3 tools/check_release_gates.py"
        status: pass
    human_judgment: false
  - id: D5
    description: The generated 0.1.409 package contains the ownership-aware lifecycle and current-generation event wiring.
    requirement: WALK-03
    verification:
      - kind: other
        ref: "muddle"
        status: pass
      - kind: integration
        ref: "Real Mudlet/Busted focused walker and full suite"
        status: unknown
    human_judgment: true
    rationale: "The local /tmp/Mudlet.AppImage is unavailable; authoritative Mudlet execution remains assigned to the parent exact-final-HEAD CI gate."
duration: 14m
completed: 2026-07-26
status: complete
---

# Phase 03 Plan 07: Ownership-Aware Walker Lifecycle Summary

**Autowalk now invalidates stale authority before stop, detach, restart, finish, or package-loss effects while current-generation room evidence exclusively controls the next move.**

## Performance

- **Duration:** 14m
- **Started:** 2026-07-26T14:46:40Z
- **Completed:** 2026-07-26T15:00:40Z
- **Tasks:** 2
- **Files modified:** 8

## Accomplishments

- Made stop ownership-aware: boop-owned runs emit exactly one external stop after invalidation, while attached runs detach locally and preserve the external walker.
- Made every restart begin with a fresh room observation and exact unsettled owner, with stale timers and run/room callbacks reduced to no-ops.
- Routed current Room.Info, complete room items, arrival, and finish through captured generation checks, including same-room transitions after a reserved move.
- Failed closed on mid-run walker package loss without any implicit package installation or update.
- Expanded deterministic lifecycle and event-ordering coverage and finished with 117 passing cross-domain host checks.

## Task Commits

Each task was committed atomically:

1. **Task 1: Pin owned stop, attached detach, restart, and event ordering** - `78f5e0a` (test)
2. **Task 2: Implement ownership-aware stop/restart and current-generation event wiring** - `d0a8e3c` (feat)

**Plan metadata:** committed separately with this summary and state closeout.

## Files Created/Modified

- `.planning/phases/03-queue-interrupt-gold-and-autowalk-regression-coverage/03-07-SUMMARY.md` - Records lifecycle decisions, verification, coverage, deviations, and closeout evidence.
- `src/scripts/boop/boop_walk.lua` - Implements ownership-aware stop/detach, fresh restart, generation-guarded callbacks, exact-owner cleanup, and package-loss invalidation.
- `src/scripts/boop/boop_events.lua` - Captures current walk generations for room evidence and normalizes Mudlet callback metadata.
- `tests/boop_walk_spec.lua` - Covers exact stop/detach ordering, fresh restart, stale callbacks, manual denial, external finish, and package loss.
- `tests/boop_event_transitions_spec.lua` - Covers same-room Room.Info/List transitions, stale adapters, and Mudlet event-name forwarding.
- `mfile` - Advances package title/version through the required task increments to `0.1.409`.
- `src/scripts/boop/boop_init.lua` - Keeps `boop.version` synchronized at `0.1.409`.
- `CODEX.md` - Keeps the package-version checkpoint synchronized at `0.1.409`.

## Decisions Made

- Stop and finish capture the current owner before invalidating generation authority; exact-owner cleanup precedes any operator or external effect.
- Attached stop never owns the external walker lifecycle, so it clears only boop state and leaves `demonwalker.enabled` untouched.
- Restart always opens a new room observation, including same-room restarts, so old complete evidence cannot authorize movement.
- Event adapters accept numeric generation tokens for deterministic stale-callback tests but discard Mudlet's nonnumeric event-name metadata.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Removed the walk owner's self-block on complete room evidence**
- **Found during:** Task 2 (Implement ownership-aware stop/restart and current-generation event wiring)
- **Issue:** `boop.onRoomItemsList` checked the aggregate walk hold before calling `onRoomSettled`, so the walk owner's own unsettled blocker prevented current complete evidence from ever clearing it.
- **Fix:** Route current captured generations directly through `onRoomSettled`, then trace only if a hold remains.
- **Files modified:** `src/scripts/boop/boop_events.lua`
- **Verification:** Current same-room Room.Info plus complete-list transition passes and creates exactly one fresh reservation.
- **Committed in:** `d0a8e3c`

**2. [Rule 1 - Bug] Normalized Mudlet event-name callback metadata**
- **Found during:** Task 2 (Implement ownership-aware stop/restart and current-generation event wiring)
- **Issue:** Mudlet supplies the event name as the first anonymous-handler argument; forwarding that string as a run generation made live arrived/finished events look stale.
- **Fix:** Convert adapter arguments to optional numeric tokens before delegation and add a regression proving event names are treated as metadata.
- **Files modified:** `src/scripts/boop/boop_events.lua`, `tests/boop_event_transitions_spec.lua`
- **Verification:** Focused walker/event execution passes 71/71 checks, including stale numeric tokens and nonnumeric event names.
- **Committed in:** `d0a8e3c`

**3. [Rule 1 - Bug] Cleared stranded inactive exact owners on complete evidence**
- **Found during:** Task 2 (Implement ownership-aware stop/restart and current-generation event wiring)
- **Issue:** A complete current list could reach an inactive walk fixture with no reservation while leaving its exact owner stranded.
- **Fix:** Allow generation-current inactive settlement to clear only its exact unreserved owner before returning the stable inactive result.
- **Files modified:** `src/scripts/boop/boop_walk.lua`
- **Verification:** The full focused event-transition suite passes without weakening stale-generation rejection.
- **Committed in:** `d0a8e3c`

---

**Total deviations:** 3 auto-fixed (3 Rule 1 bugs)
**Impact on plan:** All fixes were required for correct event delivery or exact-owner lifecycle behavior; no new command, state field, API, dependency, or package-mutation path was added.

## Issues Encountered

- The authoritative local real-Mudlet suite could not run because `/tmp/Mudlet.AppImage` is absent. The package build and 117 focused cross-domain host checks passed; the parent workflow retains exact-final-HEAD Mudlet CI authority.

## User Setup Required

None - `demonnicAutoWalker` remains optional, and installation remains an explicit existing operator action.

## Next Phase Readiness

- Plan 03-08 can render the stable ownership outcomes and current exact-owner state without duplicating lifecycle logic.
- Plan 03-09 can consolidate Phase 03 regressions around the now-complete walker lifecycle.
- No implementation blocker remains. Real Mudlet focused/full-suite execution stays assigned to the parent exact-HEAD CI gate.

## Self-Check: PASSED

- Summary artifact exists and declares `status: complete`.
- Task commits `78f5e0a` and `d0a8e3c` exist.
- All created/modified key files referenced by the summary exist.
- Coverage metadata validates with four automated deliverables and one intentionally deferred real-Mudlet integration check.

---
*Phase: 03-queue-interrupt-gold-and-autowalk-regression-coverage*
*Completed: 2026-07-26*
