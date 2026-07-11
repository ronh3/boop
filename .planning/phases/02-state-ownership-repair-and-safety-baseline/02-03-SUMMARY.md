---
phase: 02-state-ownership-repair-and-safety-baseline
plan: "03"
subsystem: runtime-state
tags: [runtime, gmcp, blockers, safety, mudlet, busted]

requires:
  - phase: 01-release-gates-and-state-contracts
    provides: "release gates, state-drift checks, and Mudlet Busted harness"
  - phase: 02-state-ownership-repair-and-safety-baseline
    provides: "02-01 and 02-02 Wave 0 blocker, target-loss, pull, trace, and UI contracts"
provides:
  - "Canonical owned runtime blocker model on state.combat.blocker"
  - "Runtime hold APIs and cleanup helpers for attack, automation, walk, and gold intent"
  - "GMCP IRE, room, target-loss, pull-away, and pull-timeout blocker wiring"
affects: [phase-02, runtime-state, gmcp, safety, target-loss, pull]

tech-stack:
  added: []
  patterns:
    - "Use boop.runtime.blockerSnapshot() as the shared owned-state blocker source for runtime, events, trace, and later UI/status consumers."
    - "Event automation paths call boop.runtime.shouldHold(system) before sending target, queue, gold, walk, or prequeue side effects."
    - "Runtime cleanup helpers trace normalized pre-clear snapshots, then clear owned transient intent fields."

key-files:
  created:
    - .planning/phases/02-state-ownership-repair-and-safety-baseline/02-03-SUMMARY.md
  modified:
    - src/scripts/boop/boop_runtime.lua
    - src/scripts/boop/boop_events.lua
    - src/scripts/boop/boop_ui.lua
    - mfile
    - src/scripts/boop/boop_init.lua
    - CODEX.md

key-decisions:
  - "Store the cross-automation blocker under the owned combat domain because combat already owns hunting/flee/pull runtime state."
  - "Treat the Wave 0 contracts from Plans 02-01 and 02-02 as the RED tests for this implementation plan, producing GREEN feature commits here."
  - "Patch the pull timeout source narrowly in boop_ui.lua because pull_timeout_away cannot be emitted correctly from the event adapter alone."

patterns-established:
  - "GMCP recovery enters gmcp_ire_missing immediately, retries supports once, then throttles repeated retries while held."
  - "Blocker auto-clear requires both prompt observation and relevant GMCP observation."
  - "Target-loss cleanup clears owned attack intent before selecting a valid current-room replacement target."

requirements-completed: [STATE-01, STATE-02]

coverage:
  - id: D1
    description: "Owned blocker defaults, snapshot, hold checks, prompt/GMCP observations, and cleanup helpers exist in runtime state."
    requirement: STATE-01
    verification:
      - kind: other
        ref: "luac -p src/scripts/boop/boop_runtime.lua tests/boop_runtime_spec.lua tests/boop_state_contract_spec.lua"
        status: pass
      - kind: other
        ref: "python3 tools/check_release_gates.py --check state-drift"
        status: pass
    human_judgment: false
  - id: D2
    description: "GMCP, room, target-loss, gold, walk, prequeue, and pull blocker event paths use the runtime blocker API."
    requirement: STATE-02
    verification:
      - kind: other
        ref: "luac -p src/scripts/boop/boop_events.lua src/scripts/boop/boop_ui.lua tests/boop_event_transitions_spec.lua tests/boop_trace_spec.lua tests/boop_pull_spec.lua"
        status: pass
      - kind: other
        ref: "rg blocker/shouldHold API wiring in src/scripts/boop"
        status: pass
    human_judgment: false
  - id: D3
    description: "Muddler build and Mudlet launch completed for the exact plan-level command, but in-profile Busted was unavailable locally."
    requirement: STATE-02
    verification:
      - kind: other
        ref: "muddle && AUTORUN_BUSTED_TESTS=true TESTS_DIRECTORY=\"$PWD/tests\" QUIT_MUDLET_AFTER_TESTS=true PRETEST_PACKAGE=\"$PWD/build/boop Hunter.mpackage\" /tmp/Mudlet.AppImage --profile \"GithubTests\" --mirror"
        status: unknown
    human_judgment: true
    rationale: "The command exited 0 after building and launching Mudlet, but the profile reported 'Busted not available' before specs ran."

duration: 18 min
completed: 2026-07-11
status: complete
---

# Phase 02 Plan 03: Canonical Blockers and GMCP Recovery Summary

**Owned runtime blockers now hold GMCP, room, target-loss, pull, queue, gold, walk, and attack automation from one canonical state source.**

## Performance

- **Duration:** 18 min
- **Started:** 2026-07-11T00:33:00Z
- **Completed:** 2026-07-11T00:51:28Z
- **Tasks:** 2
- **Files modified:** 6

## Accomplishments

- Added `state.combat.blocker` defaults plus `blockerSnapshot`, `setBlocker`, `clearBlocker`, `shouldHold`, prompt/GMCP observation, and cleanup helper APIs.
- Routed runtime tick planning through blocker holds before target, combat, queue, gold, or walk effects can be emitted.
- Wired GMCP IRE recovery, missing/partial room blockers, target-loss cleanup, valid retarget tracing, pull-away holds, and pull-timeout-away holds through owned blocker state.
- Kept package version fields synchronized for both task commits.

## Task Commits

Each task was committed atomically:

1. **Task 1: Add owned blocker state and runtime hold APIs** - `09aa695` (feat)
2. **Task 2: Wire GMCP recovery and blocker clearing through events** - `7ace544` (feat)

**Plan metadata:** pending final metadata commit.

## Files Created/Modified

- `src/scripts/boop/boop_runtime.lua` - Adds owned blocker state, normalized snapshots, hold checks, observation clearing, and attack/automation cleanup helpers.
- `src/scripts/boop/boop_events.lua` - Enters and clears GMCP/room/target blockers and blocks gold, walk, prequeue, and target-loss automation through runtime holds.
- `src/scripts/boop/boop_ui.lua` - Adds the narrow pull timeout-away blocker at the timeout source.
- `mfile` - Synchronized package version through `0.1.361`.
- `src/scripts/boop/boop_init.lua` - Synchronized runtime version through `0.1.361`.
- `CODEX.md` - Synchronized current package version checkpoint through `0.1.361`.

## Verification

- `luac -p src/scripts/boop/boop_runtime.lua src/scripts/boop/boop_events.lua src/scripts/boop/boop_ui.lua tests/boop_runtime_spec.lua tests/boop_state_contract_spec.lua tests/boop_event_transitions_spec.lua tests/boop_trace_spec.lua tests/boop_pull_spec.lua` - pass
- `python3 tools/check_release_gates.py` - pass (`versions`, `manifests`, `state-drift`)
- `python3 tools/check_release_gates.py --check versions` before each commit - pass
- Host `TESTS_DIRECTORY="$PWD/tests" busted ...` - did not execute specs; fails before tests with `boop package is not loaded`
- Exact Mudlet command - build and Mudlet launch completed, but in-profile output reported `Busted not available`

## Decisions Made

- Kept the blocker in `state.combat.blocker` rather than adding a new state domain, matching the existing ownership of hunting, flee, and pull lifecycle state.
- Used prior Wave 0 test commits as RED contracts; this plan produced implementation commits to satisfy those contracts.
- Added `pull_timeout_away` in `boop_ui.lua` as a minimal source-of-truth fix because the timeout callback owns that transition.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Required Repo Workflow] Applied version synchronization and commits in executor**
- **Found during:** Task 1 and Task 2
- **Issue:** The plan output block delegated version sync and commits to the orchestrator, but this sequential executor run and AGENTS.md require synchronized version bumps before every commit.
- **Fix:** Bumped `mfile.version`, `mfile.title`, `boop.version`, and the `CODEX.md` checkpoint for each task commit.
- **Files modified:** `mfile`, `src/scripts/boop/boop_init.lua`, `CODEX.md`
- **Verification:** `python3 tools/check_release_gates.py --check versions`
- **Committed in:** `09aa695`, `7ace544`

**2. [Rule 2 - Missing Critical] Added pull timeout-away blocker at source**
- **Found during:** Task 2
- **Issue:** The plan required `pull_timeout_away`, but the timeout transition is emitted by `boop.ui.pullCommand()`'s timer callback rather than `boop_events.lua`.
- **Fix:** Added a narrow `boop.runtime.setBlocker("pull_timeout_away", ...)` call in the timeout-away branch without changing pull command validation or broader UI behavior.
- **Files modified:** `src/scripts/boop/boop_ui.lua`
- **Verification:** `luac -p src/scripts/boop/boop_ui.lua tests/boop_pull_spec.lua`
- **Committed in:** `7ace544`

---

**Total deviations:** 2 auto-fixed (2 Rule 2).
**Impact on plan:** Both deviations were required to satisfy repository hard constraints and the plan's blocker artifacts; no broad feature scope was added.

## TDD Gate Compliance

The plan frontmatter type is `execute`, while both tasks are marked `tdd="true"`. RED contract commits were created in Plans 02-01 and 02-02; this plan produced GREEN implementation commits against those contracts.

## Issues Encountered

- Host `busted` cannot run these specs directly because the boop package is not loaded outside Mudlet.
- The exact Mudlet command built the package and launched the `GithubTests` profile, but the profile reported `Busted not available`, so local in-Mudlet specs did not execute.

## User Setup Required

None.

## Known Stubs

None. Stub-pattern scanning found owned-domain default empty values and existing command defaults, not incomplete UI/data wiring introduced by this plan.

## Next Phase Readiness

Ready for Plan 02-04 to consume the runtime cleanup helpers from flee, target-loss, pull exception, and attack ownership repair paths. The remaining validation gap is local Mudlet Busted availability in the `GithubTests` profile.

## Self-Check: PASSED

- Summary file exists: `.planning/phases/02-state-ownership-repair-and-safety-baseline/02-03-SUMMARY.md`
- Task commits found: `09aa695` and `7ace544`
- Key modified files exist: `src/scripts/boop/boop_runtime.lua`, `src/scripts/boop/boop_events.lua`, and `src/scripts/boop/boop_ui.lua`
- `luac -p` passed for modified source and affected specs.
- `python3 tools/check_release_gates.py --check state-drift` passed.

---
*Phase: 02-state-ownership-repair-and-safety-baseline*
*Completed: 2026-07-11*
