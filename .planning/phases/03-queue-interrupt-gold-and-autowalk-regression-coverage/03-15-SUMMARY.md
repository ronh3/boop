---
phase: 03-queue-interrupt-gold-and-autowalk-regression-coverage
plan: 15
subsystem: testing
tags: [lua, busted, mudlet, lifecycle, diagnose, pull, timer-identity]

requires:
  - phase: 03-queue-interrupt-gold-and-autowalk-regression-coverage
    provides: "Plan 03-14 disabled-safe lifecycle observation and the 8.0-second room-response warning"
provides:
  - "Failure-safe lifecycle fixture restoration for boop package tables"
  - "Explicit enabled preconditions for diagnose prompt-consumption contracts"
  - "Operation-owned pull timeout identity independent of timer delay"
  - "Focused host, syntax, release-gate, and package-build evidence at 0.1.429"
affects: [phase-03-verification, exact-sha-ci, live-uat, release-hardening]

tech-stack:
  added: []
  patterns:
    - "Restore exact package-table references in test teardown"
    - "Identify asynchronous test work by operation-owned IDs, never equal timing"

key-files:
  created:
    - ".planning/phases/03-queue-interrupt-gold-and-autowalk-regression-coverage/03-15-SUMMARY.md"
  modified:
    - "tests/boop_lifecycle_spec.lua"
    - "tests/boop_diag_timeout_spec.lua"
    - "tests/boop_pull_spec.lua"
    - "mfile"
    - "src/scripts/boop/boop_init.lua"
    - "CODEX.md"

key-decisions:
  - "No-change assumption delta: exact owner and operation timer identity remain canonical; production pull, lifecycle, and walker behavior are unchanged."
  - "Host Busted is focused regression evidence only; Psion and Dragon remain authoritative only in the complete packaged real-Mudlet suite."
  - "Terminal CI and all live UAT remain parent-owned after the final immutable HEAD is pushed."

patterns-established:
  - "Shared-package tests snapshot and restore every replaced package table after each case."
  - "Pull fixtures record timeout ownership only from state.combat.pullState.timeoutTimer."

requirements-completed: [SAFE-02]

coverage:
  - id: D1
    description: "Lifecycle cases restore the exact pre-test boop.state, boop.config, boop.handlers, and boop.gmcp references before the next shared suite resets package state."
    requirement: SAFE-02
    verification:
      - kind: integration
        ref: "tests/boop_lifecycle_spec.lua followed by tests/boop_menu_wiring_spec.lua: 17 successes, 0 failures, 0 errors"
        status: pass
    human_judgment: false
  - id: D2
    description: "Diagnose timeout and tombstone prompt-consumption cases establish enabled runtime processing while the separate disabled lifecycle contract remains inert."
    requirement: SAFE-02
    verification:
      - kind: unit
        ref: "tests/boop_diag_timeout_spec.lua: 3 successes, 0 failures, 0 errors"
        status: pass
      - kind: unit
        ref: "tests/boop_lifecycle_spec.lua#gap-03-3 prompt evidence has zero disabled automation"
        status: pass
    human_judgment: false
  - id: D3
    description: "Pull timeout assertions use exact operation-owned timer IDs while equal-delay room-response timers remain present and unrelated."
    requirement: SAFE-02
    verification:
      - kind: unit
        ref: "Three exact actionable tests in tests/boop_pull_spec.lua, each in an isolated host process"
        status: pass
      - kind: integration
        ref: "Complete host pull diagnostic: 11 successes, 2 documented profile exclusions, 0 errors"
        status: pass
    human_judgment: false
  - id: D4
    description: "Package 0.1.429 passes affected focused suites, Lua syntax, release gates, diff hygiene, and Muddler construction without tracked generated output."
    requirement: SAFE-02
    verification:
      - kind: integration
        ref: "Affected isolated host suites: 102 successes, 0 failures, 0 errors"
        status: pass
      - kind: other
        ref: "luac -p, python3 tools/check_release_gates.py, git diff --check, and Muddler 1.1.0"
        status: pass
    human_judgment: false
  - id: D5
    description: "The complete packaged real-Mudlet suite, including Psion and Dragon pull profiles, passes at the immutable final SHA before live UAT."
    requirement: SAFE-02
    verification:
      - kind: integration
        ref: "Parent-owned tools/wait_for_exact_ci.sh against final pushed HEAD"
        status: unknown
    human_judgment: true
    rationale: "The local /tmp/Mudlet.AppImage is unavailable and the executor is forbidden to push; exact-final-SHA GitHub Actions and live UAT remain parent gates."

duration: 3m
completed: 2026-07-27
status: complete
---

# Phase 03 Plan 15: Diagnose, Pull Timer Identity, and Suite Isolation Summary

**Failure-safe lifecycle teardown and operation-owned pull timer assertions restore all affected regression contracts at synchronized package version 0.1.429 without changing shipped hunting behavior.**

## Performance

- **Duration:** 3m
- **Started:** 2026-07-27T12:07:03Z
- **Completed:** 2026-07-27T12:10:46Z
- **Tasks:** 3
- **Files modified:** 7

## Accomplishments

- Restored exact `boop.state`, `boop.config`, `boop.handlers`, and `boop.gmcp` references after every lifecycle case, eliminating the downstream `boop.state.init()` reset cascade.
- Made the two prompt-consuming diagnose timeout/tombstone fixtures explicitly enabled while retaining the separate disabled zero-automation lifecycle proof.
- Replaced pull delay heuristics with exact `pullState.timeoutTimer` identity and proved unrelated 8.0-second room-response timers coexist without affecting pull completion.
- Synchronized all four package checkpoints through `0.1.428` and final `0.1.429`; no production line changed except `boop.version`.

## Task Commits

Each implementation task was committed atomically:

1. **Task 1: Restore lifecycle suite isolation and executable diagnose contracts** - `d0f66f5` (test, version `0.1.428`)
2. **Task 2: Replace pull delay heuristics with operation-owned timer identity** - `a820563` (test, version `0.1.429`)
3. **Task 3: Prove affected-suite reachability and hand off exact-final-SHA authority** - planning-only metadata commit containing this summary and sequential tracking updates

## RED Evidence

- GitHub Actions run `30246963329` at exact head `efaeabad823c84da3dabeea69d1e35d6f7997dc8` reported 134 successes, 2 direct diagnose failures, and 552 errors after shared reset reached `tests/support/boop_test_helper.lua:164`.
- The bounded lifecycle→menu host canary reproduced 4 lifecycle successes followed by 26 reset/teardown errors.
- Isolated diagnose timeout execution reported 1 success and 2 failures because prompt-consuming fixtures left automation disabled.
- Isolated pull execution reported 8 successes and 5 failures: three actionable timer-count failures observed 3/2/7 instead of 1/1/3, plus the two known Psion/Dragon host-profile exclusions.

## GREEN Evidence

- `tests/boop_lifecycle_spec.lua`: 4 successes, 0 failures, 0 errors.
- Lifecycle→menu restoration canary: 17 successes, 0 failures, 0 errors.
- `tests/boop_diag_spec.lua`: 3 successes, 0 failures, 0 errors.
- `tests/boop_diag_timeout_spec.lua`: 3 successes, 0 failures, 0 errors.
- `tests/boop_interrupt_spec.lua`: 3 successes, 0 failures, 0 errors.
- `tests/boop_event_transitions_spec.lua`: 46 successes, 0 failures, 0 errors.
- `tests/boop_prequeue_spec.lua`: 13 successes, 0 failures, 0 errors.
- `tests/boop_tick_spec.lua`: 30 successes, 0 failures, 0 errors.
- Each of the three actionable pull cases passed independently with 1 success, 0 failures, and 0 errors.
- Complete host pull diagnostic: 11 successes, 2 failures, 0 errors. The failures are exactly `prepends psion transcend shatter to pull rage commands` and `leaves dragon pull rage commands unchanged`; the Occultist-only host bootstrap cannot load those profiles, so they remain unchanged and excluded from host authority.

## Files Created/Modified

- `tests/boop_lifecycle_spec.lua` - Snapshots and failure-safely restores exact package-table references after lifecycle cases.
- `tests/boop_diag_timeout_spec.lua` - Enables only the two runtime prompt-consumption cases.
- `tests/boop_pull_spec.lua` - Tracks exact operation-owned timeout IDs and asserts equal-delay room timers remain unrelated.
- `mfile`, `src/scripts/boop/boop_init.lua`, `CODEX.md` - Synchronize package metadata through final version `0.1.429`.
- `.planning/phases/03-queue-interrupt-gold-and-autowalk-regression-coverage/03-15-SUMMARY.md` - Records gap closure and the parent authority handoff.

## Decisions Made

- `decision: no-change` — exact owner keys and exact operation timer IDs remain canonical; optional walker semantics, pull behavior, profile expectations, and the 8.0-second room warning are unchanged.
- Host Busted remains bounded diagnostic evidence. It is not presented as a complete real-Mudlet authority.
- The parent owns immutable-final-HEAD push, exact-`headSha` CI, and all live UAT.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

- `/tmp/Mudlet.AppImage` is not available, so local complete-suite real-Mudlet execution was unavailable. Host Busted was not substituted as full authority.
- The complete host pull diagnostic intentionally exits nonzero for the unchanged Psion and Dragon checks because `tests/support/boop_host_busted_helper.lua` loads only the Occultist attack profile. It produced zero errors and no unexpected failures.

## Verification

- Lua syntax: `luac -p` passed for all three changed specs and synchronized `boop_init.lua`.
- Focused host suites: 102 isolated successes with zero failures/errors across lifecycle, diagnose, diagnose timeout, interrupt, event transitions, prequeue, and tick.
- Lifecycle→menu canary: 17 successes with zero reset or teardown errors.
- Pull identity: all three actionable cases pass in separate processes; unrelated response-fence callbacks remain present and outside `ownedPullTimerIds`.
- Release gates: versions, manifests, and state drift all `[OK]` at `0.1.429`.
- Diff hygiene: `git diff --check` passes.
- Muddler 1.1.0 built `build/boop Hunter.mpackage` successfully at `0.1.429`; build output and `.output` are not tracked or staged.
- Local real Mudlet: unavailable because `/tmp/Mudlet.AppImage` is absent.
- Terminal exact-final-SHA CI and live UAT: intentionally not run or claimed by this executor.

## Known Stubs

- Empty tables, synthetic GMCP values, captured callbacks, and Busted stubs in the changed specs are intentional deterministic test infrastructure.
- Existing empty-string defaults in `boop_init.lua` are valid unset configuration values; this plan changed only its version line.

## User Setup Required

None - no dependency, command, help, configuration, or production behavior changed.

## Parent Exact-SHA CI and UAT Handoff

After this summary and all sequential tracking mutations are committed:

1. Inspect any final staged paths and run `python3 tools/check_release_gates.py`.
2. Capture immutable `FINAL_SHA="$(git rev-parse HEAD)"`, verify the worktree is clean, and push that exact SHA.
3. Run `tools/wait_for_exact_ci.sh "$FINAL_SHA"`.
4. Require a successful `main.yml` run whose `headSha` exactly equals `FINAL_SHA`, with zero real-Mudlet failures and zero errors; this is where the unchanged Psion and Dragon checks become authoritative.
5. Report the run URL and SHA without committing CI evidence. Any later repository mutation invalidates the evidence and requires a rerun.
6. Do not begin or claim live UAT before the exact-SHA gate succeeds.

## Next Phase Readiness

- All 15 Phase 03 implementation plans have execution evidence, but the phase is not live-UAT complete.
- Parent exact-final-SHA CI remains blocking because local real Mudlet was unavailable.
- Existing Phase 03 live UAT remains pending and must not be marked complete by this plan closeout.

## Self-Check: PASSED

- The summary and all six implementation/version paths exist.
- Task commits `d0f66f5` and `a820563` are present in order.
- All focused, syntax, release, diff, version, build, and generated-artifact claims above match observed command output.
- No production behavior changed; `boop_init.lua` changed only from version `0.1.427` through `0.1.428` to final `0.1.429`.
- Terminal CI and live UAT are explicitly reserved for the parent.

---
*Phase: 03-queue-interrupt-gold-and-autowalk-regression-coverage*
*Completed: 2026-07-27*
