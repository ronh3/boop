---
phase: 03-queue-interrupt-gold-and-autowalk-regression-coverage
plan: 22
subsystem: autowalk-targeting-integration
tags: [lua, mudlet, gmcp, autowalk, targeting]
requires:
  - phase: 03-20
    provides: generation-owned inventory and room snapshot settlement
  - phase: 03-21
    provides: room-owned combat dispatch after exact snapshot application
provides:
  - packaged manual-to-auto targeting transitions wake an active settled walker
  - real-alias regressions prove one reservation and one move across both GMCP response orders
  - early transitions, duplicate callbacks, and unrelated owner holds remain race-safe
  - accepted current-room evidence and valid denizen adds release stale target-loss ownership
affects: [03-23, 03-24, live-uat]
tech-stack:
  added: []
  patterns:
    - targeting mode transitions delegate one eligibility recheck to the walker
    - integration tests execute the packaged alias and exact deferred room application callback
key-files:
  created: []
  modified:
    - tests/boop_walk_spec.lua
    - tests/boop_event_transitions_spec.lua
    - src/scripts/boop/boop_ui.lua
    - src/scripts/boop/boop_events.lua
    - src/scripts/boop/boop_init.lua
    - mfile
    - CODEX.md
key-decisions:
  - Wake an active walk only on a true manual-to-nonmanual targeting transition.
  - Reuse boop.walk.maybeAdvance so existing snapshot and owner gates remain authoritative.
patterns-established:
  - "Command-surface wakeups: execute the real packaged alias, then assert reservation and movement counts."
requirements-completed: [WALK-01, WALK-02, WALK-03]
coverage:
  - id: G03-7-D1
    requirement: WALK-01
    verification: integration
    status: pass
    human: false
    evidence: Both Inv-to-Room and Room-to-Inv settlement orders wake exactly once after the real targeting alias switches to auto.
  - id: G03-7-D2
    requirement: WALK-02
    verification: integration
    status: pass
    human: false
    evidence: Early auto waits for exact application, duplicates stay idempotent, and unrelated owners hold until exact release.
  - id: G03-7-D3
    requirement: WALK-03
    verification: regression
    status: pass
    human: false
    evidence: The full helper-backed walk specification passes with existing stop, restart, owner, and reservation behavior intact.
duration: 8m
completed: 2026-07-29
status: complete
---

# Phase 03 Plan 22: Manual-to-Auto Walk Wake-Up Summary

**The real packaged targeting command now wakes a settled manual-blocked walker exactly once while preserving the existing snapshot, owner, and duplicate-event gates.**

## Performance

- **Duration:** 8m
- **Started:** 2026-07-29T05:52:42Z
- **Completed:** 2026-07-29T06:00:42Z
- **Tasks:** 1
- **Files modified:** 5

## Accomplishments

- Added real-alias walk regressions for both inventory/room response orders, early targeting changes, duplicate callbacks, prompts, same-room events, and unrelated owner holds.
- Added a narrow manual-to-nonmanual transition seam that asks the active walker to re-evaluate eligibility once.
- Preserved Plan 20's exact deferred room-application authority and proved one reservation and one `demonwalker.move` per settled transition.
- Synchronized the package version at `0.1.444`.

## Task Commits

Each task was committed atomically:

1. **Task 1: Cover the real targeting command and add the minimal walker wake-up seam** - `7cd0c14` (fix)

## Files Created/Modified

- `tests/boop_walk_spec.lua` - Executes the real targeting alias and covers response-order, timing, duplicate-event, and owner-hold behavior.
- `src/scripts/boop/boop_ui.lua` - Rechecks an active walk once after a true manual-to-nonmanual targeting transition.
- `src/scripts/boop/boop_init.lua` - Synchronizes `boop.version` at `0.1.444`.
- `mfile` - Synchronizes package version and title at `0.1.444`.
- `CODEX.md` - Updates the synchronized package-version checkpoint.

## Decisions Made

- Wake only when the previous targeting mode was `manual` and the new mode is nonmanual; repeated `auto` commands do not create another wake.
- Delegate the wake to `boop.walk.maybeAdvance("targeting mode changed")` instead of duplicating walk eligibility, snapshot, reservation, or owner logic in the UI layer.
- Exercise the packaged alias with Mudlet-style `matches` and the exact Plan 20 deferred application callback so tests cover the real command path without unrelated diagnostic commands.

## Verification

- Test-first RED: `43 successes / 2 failures / 0 errors`; only the two response-order cases lacked the targeting transition wake.
- GREEN and final focused suite: `45 successes / 0 failures / 0 errors`.
- `luac -p src/scripts/boop/boop_ui.lua`
- `git diff --check`
- `python3 tools/check_release_gates.py` - versions, manifests, and state-drift all passed.
- Direct `muddle` - built `boop Hunter 0.1.444` successfully.
- Acceptance scan confirmed the new command-surface cases do not call `boop.walk.maybeAdvance` directly or depend on diagnostic commands or nonzero timers.

## Post-Plan Live UAT Hotfix

- Live trace from package `0.1.444` exposed a stale `target:loss` owner that retained prompt evidence but could never obtain target GMCP because it blocked the automatic `settarget` needed to generate that evidence.
- Accepted fenced room snapshots and validated denizen `Items.Add` events now satisfy the existing target-loss GMCP evidence contract. The owner remains fail closed during `room_partial`, and unrelated blocker owners are retained.
- Test-first evidence was `53 successes / 2 failures / 0 errors` before the fix and `55 successes / 0 failures / 0 errors` afterward. The adjacent runtime, tick, walk, and target suites passed `97/97`.
- Release gates and direct `muddle` passed at synchronized package `0.1.445`.
- **Commit:** `457aafc` (`fix(03-22): release target loss from fresh room evidence`)

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Updated the pre-Plan-20 restart fixture for deferred room application**

- **Found during:** Task 1 RED isolation
- **Issue:** The existing restart regression still expected synchronous room settlement and three timers, but Plan 20 made room application an exact generation-owned zero-delay callback.
- **Fix:** Ran the exact pending room-application callback in the fixture and updated the expected timer count from three to four.
- **Files modified:** `tests/boop_walk_spec.lua`
- **Verification:** The complete focused walk suite passes `45/45`.
- **Commit:** `7cd0c14`

**2. [Rule 1 - Bug] Released target-loss ownership from authoritative room evidence**

- **Found during:** Post-plan live UAT on package `0.1.444`
- **Issue:** `target:loss` required target GMCP plus a prompt while simultaneously blocking automatic retargeting, so accepted room snapshots, room changes, and new denizen adds could leave all automation permanently held.
- **Fix:** Count accepted fenced room snapshots and validated denizen adds as target-loss GMCP recovery evidence without clearing unrelated owners or weakening the room-partial fence.
- **Files modified:** `src/scripts/boop/boop_events.lua`, `tests/boop_event_transitions_spec.lua`, synchronized version files
- **Verification:** Event transitions pass `55/55`; adjacent suites pass `97/97`; release gates and `muddle` pass at `0.1.445`.
- **Commit:** `457aafc`

**Total deviations:** 2 auto-fixed issues: one blocking fixture update and one live-UAT blocker-lifecycle bug.

## Known Stubs

None. New empty tables and values are test fixtures or normal reset state and do not flow to user-facing rendering.

## Issues Encountered

- The first combined verification invocation reached the direct build without Docker socket access. Re-running the same required `muddle` command with approved Docker access completed successfully.

## User Setup Required

None.

## Next Phase Readiness

- Host-side G03-7 coverage and the discovered target-loss deadlock are closed; Plans 03-23 and 03-24 can build on the proven command-to-walker handoff.
- Package `0.1.445` still requires live Mudlet confirmation that a settled room or arriving denizen releases `target_lost` and resumes one target/attack.
- Final push, exact-SHA CI, and any live Mudlet UAT remain owned by the parent orchestrator.

## Self-Check: PASSED

- All original task files and post-plan hotfix files exist at the committed `0.1.445` package state.
- Task commit `7cd0c14` exists and contains no tracked-file deletions.
- Live-UAT hotfix commit `457aafc` exists and contains no tracked-file deletions.
- Focused Busted, syntax, diff, release-gate, and direct muddle verification all passed.
