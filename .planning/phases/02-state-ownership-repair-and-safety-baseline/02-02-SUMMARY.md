---
phase: 02-state-ownership-repair-and-safety-baseline
plan: "02"
subsystem: testing
tags: [runtime-state, gmcp, target-loss, pull, trace, ui, busted]

requires:
  - phase: 01-release-gates-and-state-contracts
    provides: "state-drift gate and owned-domain test helpers"
  - phase: 02-state-ownership-repair-and-safety-baseline
    provides: "02-01 Wave 0 runtime, flee, and walk safety contracts"
provides:
  - "Wave 0 GMCP recovery, target-loss cleanup, and pull lifecycle contract specs"
  - "Wave 0 trace and UI canonical blocker/status contract specs"
  - "Synchronized package version progression through 0.1.358 for task commits"
affects: [phase-02, runtime-state, safety, trace, ui, tests]

tech-stack:
  added: []
  patterns:
    - "Wave 0 plans add RED-style Busted contracts and verify them with luac plus release gates before production implementation."
    - "Canonical blocker assertions use stable `code -- label`, affected systems, waits-for state, and owned-domain snapshots."

key-files:
  created:
    - .planning/phases/02-state-ownership-repair-and-safety-baseline/02-02-SUMMARY.md
  modified:
    - tests/boop_event_transitions_spec.lua
    - tests/boop_pull_spec.lua
    - tests/boop_trace_spec.lua
    - tests/boop_ui_spec.lua
    - mfile
    - src/scripts/boop/boop_init.lua
    - CODEX.md

key-decisions:
  - "Keep Plan 02-02 production behavior unchanged; add RED-style Wave 0 contracts for downstream Phase 02 implementation."
  - "Use stable canonical blocker text in UI expectations: `code -- label`, plus explicit systems and waits-for state."
  - "Apply the repo version rule on each task commit despite the plan output block delegating version/commit handling to the orchestrator."

patterns-established:
  - "Task-level contract commits carry synchronized package patch bumps even when only tests and metadata change."
  - "Trace contracts assert normalized owned-state values instead of raw GMCP table contents."

requirements-completed: [STATE-02, STATE-03, SAFE-03]

coverage:
  - id: D1
    description: "GMCP recovery, partial room state, target-loss cleanup, valid retargeting, and active-pull target-loss exceptions are pinned by event/pull contract specs."
    requirement: STATE-02
    verification:
      - kind: unit
        ref: "luac -p tests/boop_event_transitions_spec.lua tests/boop_pull_spec.lua"
        status: pass
      - kind: other
        ref: "python3 tools/check_release_gates.py --check state-drift"
        status: pass
    human_judgment: false
  - id: D2
    description: "Trace contracts require blocker enter/exit, cleanup, pull hold, GMCP recovery, and retarget decisions from canonical owned-state values."
    requirement: STATE-03
    verification:
      - kind: unit
        ref: "luac -p tests/boop_trace_spec.lua"
        status: pass
      - kind: other
        ref: "python3 tools/check_release_gates.py --check state-drift"
        status: pass
    human_judgment: false
  - id: D3
    description: "UI contracts require status, home, control, config, party, and debug surfaces to render blocker code, label, affected systems, and resume wait state from one canonical snapshot."
    requirement: STATE-03
    verification:
      - kind: unit
        ref: "luac -p tests/boop_ui_spec.lua"
        status: pass
      - kind: other
        ref: "python3 tools/check_release_gates.py --check state-drift"
        status: pass
    human_judgment: false
  - id: D4
    description: "Target disappearance contracts require stale attack intent cleanup before retargeting only to valid current-room denizens."
    requirement: SAFE-03
    verification:
      - kind: unit
        ref: "luac -p tests/boop_event_transitions_spec.lua"
        status: pass
    human_judgment: false

duration: 7 min
completed: 2026-07-11
status: complete
---

# Phase 02 Plan 02: GMCP, Target-Loss, Pull, Trace, and UI Contract Summary

**Wave 0 Busted contract specs now pin canonical missing-state blockers, target-loss cleanup, pull holds, trace entries, and blocker/status rendering before production repair work.**

## Performance

- **Duration:** 7 min
- **Started:** 2026-07-11T00:28:09Z
- **Completed:** 2026-07-11T00:35:22Z
- **Tasks:** 2
- **Files modified:** 7

## Accomplishments

- Added event-transition contracts for missing `gmcp.IRE`, missing target/display support, recovery retry throttling, prompt-plus-GMCP clearing, missing/partial room blockers, target-loss cleanup ordering, valid retargeting, and active-pull target-loss exceptions.
- Added pull lifecycle contracts for preserving pull-owned target state while away and holding automation after away-timeout until return plus trustworthy room state clears the blocker.
- Added trace contracts for blocker enter/exit, target-loss cleanup, flee cleanup, pull holds, GMCP recovery, and retarget decisions using normalized owned-domain values.
- Updated UI expectations toward canonical blocker rendering across status, home, control, config, party, and debug surfaces.

## Task Commits

Each task was committed atomically:

1. **Task 1: Add GMCP, target-loss, and pull lifecycle tests** - `35b981d` (test)
2. **Task 2: Add trace and UI canonical blocker tests** - `cabd7df` (test)

**Plan metadata:** pending final metadata commit

## Files Created/Modified

- `tests/boop_event_transitions_spec.lua` - Adds missing-GMCP recovery, room blocker, target-loss cleanup, valid retargeting, and active-pull exception contracts.
- `tests/boop_pull_spec.lua` - Adds pull-away target-loss exception and timeout-away blocker lifecycle contracts.
- `tests/boop_trace_spec.lua` - Adds canonical blocker and owned-domain trace contracts.
- `tests/boop_ui_spec.lua` - Updates blocker expectations to `code -- label` and adds shared systems/waits-for assertions across status surfaces.
- `mfile` - Synchronized package version through `0.1.358` for task commits.
- `src/scripts/boop/boop_init.lua` - Synchronized runtime package version through `0.1.358`.
- `CODEX.md` - Synchronized current package version checkpoint through `0.1.358`.

## Verification

- `luac -p tests/boop_event_transitions_spec.lua tests/boop_pull_spec.lua` - pass
- `luac -p tests/boop_trace_spec.lua tests/boop_ui_spec.lua` - pass
- `luac -p tests/boop_event_transitions_spec.lua tests/boop_pull_spec.lua tests/boop_trace_spec.lua tests/boop_ui_spec.lua` - pass
- `python3 tools/check_release_gates.py --check state-drift` - pass
- `python3 tools/check_release_gates.py` - pass (`versions`, `manifests`, `state-drift`)
- `python3 tools/check_release_gates.py --check versions` before each task commit - pass

Full Mudlet Busted was not run for this Wave 0 plan; the plan and repo constraints specify syntax plus state-drift gates here, with full Mudlet validation deferred to later phase validation.

## Decisions Made

- Keep the work test-only, matching the Wave 0 objective to define contracts before production event/UI/runtime changes.
- Assert canonical blocker rendering as `code -- label`, with separate systems and waits-for text, so future status/dashboard/trace implementation cannot infer state independently.
- Treat the user/orchestrator conflict-resolution block and `AGENTS.md` version rule as authoritative over the plan output block that said not to commit or synchronize versions.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Required Repo Workflow] Applied version synchronization and commits in executor**
- **Found during:** Plan setup
- **Issue:** The plan output block said the orchestrator owned version synchronization and commits, but this sequential `$gsd-execute-phase` run explicitly delegated atomic commits to the executor and required version bumps before each commit.
- **Fix:** Bumped and synchronized `mfile.version`, `mfile.title`, `boop.version`, and the `CODEX.md` checkpoint before each task commit.
- **Files modified:** `mfile`, `src/scripts/boop/boop_init.lua`, `CODEX.md`
- **Verification:** `python3 tools/check_release_gates.py --check versions` before each commit
- **Committed in:** `35b981d`, `cabd7df`

---

**Total deviations:** 1 auto-fixed (Rule 2)
**Impact on plan:** Required to satisfy repository hard constraints and the explicit sequential executor instructions; no production behavior was changed.

## TDD Gate Compliance

The plan frontmatter type is `execute`, while both tasks are marked `tdd="true"` as Wave 0 contract work. This run produced RED-style `test(02-02)` commits only; no GREEN production commit was expected because the plan objective explicitly says these tests are written before production event/UI/runtime implementation.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Known Stubs

None. Stub-pattern scans only found existing default empty-string configuration values and test-local nil/empty-table setup, not incomplete shipped UI/data wiring.

## Next Phase Readiness

Ready for Plan 02-03. The next implementation plans can now use these contracts to build canonical blocker state, GMCP recovery holds, target-loss cleanup, trace output, and status/dashboard rendering.

## Self-Check: PASSED

- Summary file exists: `.planning/phases/02-state-ownership-repair-and-safety-baseline/02-02-SUMMARY.md`
- Task commits found: `35b981d`, `cabd7df`
- Key modified test files exist: `tests/boop_event_transitions_spec.lua`, `tests/boop_pull_spec.lua`, `tests/boop_trace_spec.lua`, `tests/boop_ui_spec.lua`
- No missing items found.

---
*Phase: 02-state-ownership-repair-and-safety-baseline*
*Completed: 2026-07-11*
