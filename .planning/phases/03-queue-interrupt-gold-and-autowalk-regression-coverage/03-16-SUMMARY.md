---
phase: 03-queue-interrupt-gold-and-autowalk-regression-coverage
plan: 16
subsystem: runtime
tags: [lua, busted, mudlet, gold, room-observation, response-fence, aggregate-blockers]

requires:
  - phase: 03-queue-interrupt-gold-and-autowalk-regression-coverage
    provides: "Plan 03-11 copied room-response authority and Plan 03-13 exact-room gold lifecycle coverage"
provides:
  - "One operation-scoped room-only response fence for a settled same-room gold Add"
  - "Canonical exact-item authorization only from the subsequent copied current-room List"
  - "Regression coverage for duplicate signals, aggregate owners, retargeting, and movement-before-response"
  - "Focused host, syntax, release-gate, and package-build evidence at 0.1.431"
affects: [phase-03-verification, gold-lifecycle, room-observation, walker-gating, exact-sha-ci, live-uat]

tech-stack:
  added: []
  patterns:
    - "Spend one exact-operation revalidation allowance before sending a room-only request"
    - "Start settled-Add fences at await_room while preserving ordinary Inv-to-Room fences"
    - "Authorize gold only through the existing deep-copied accepted room List"

key-files:
  created:
    - ".planning/phases/03-queue-interrupt-gold-and-autowalk-regression-coverage/03-16-SUMMARY.md"
  modified:
    - "tests/boop_gold_spec.lua"
    - "tests/boop_event_transitions_spec.lua"
    - "src/scripts/boop/boop_runtime.lua"
    - "src/scripts/boop/boop_events.lua"
    - "mfile"
    - "src/scripts/boop/boop_init.lua"
    - "CODEX.md"

key-decisions:
  - "A settled gold Add may request one Char.Items.Room response but never mutates acceptedItems or becomes canonical evidence itself."
  - "The revalidation fence is bound to the exact gold operation, room ID, and room generation and starts at await_room without weakening ordinary observation fences."
  - "Accepted evidence continues through the existing copied List transition, exact owner token, and aggregate all-clear checks."

patterns-established:
  - "Incremental room signals may trigger bounded revalidation but cannot directly authorize room-owned commands."
  - "Each gold operation records both whether revalidation was attempted and the exact fence ID it owns."

requirements-completed: [SAFE-04, WALK-02]

coverage:
  - id: D1
    description: "A settled non-gold room List followed by a same-room gold Add spends one exact-operation allowance and sends only one Char.Items.Room request."
    requirement: SAFE-04
    verification:
      - kind: unit
        ref: "tests/boop_gold_spec.lua#G-03-5 settled-add-revalidation"
        status: pass
    human_judgment: false
  - id: D2
    description: "Inventory, duplicate, stale, wrong-room, and movement-before-response signals cannot authorize get, put, attack, queue-clear, or walker movement."
    requirement: SAFE-04
    verification:
      - kind: integration
        ref: "tests/boop_event_transitions_spec.lua#G-03-5 settled-add-revalidation"
        status: pass
    human_judgment: false
  - id: D3
    description: "The exact fenced current-room List promotes the same gold generation through one get-confirm-put lifecycle while unrelated owners retain their holds."
    requirement: WALK-02
    verification:
      - kind: integration
        ref: "Focused gold/event-transition host run: 57 successes, 0 failures, 0 errors"
        status: pass
      - kind: integration
        ref: "Affected lifecycle/trace/walk host run: 48 successes, 0 failures, 0 errors"
        status: pass
    human_judgment: false
  - id: D4
    description: "Package 0.1.431 passes Lua syntax, synchronized release gates, diff hygiene, and Muddler construction."
    requirement: SAFE-04
    verification:
      - kind: other
        ref: "luac -p, python3 tools/check_release_gates.py, git diff --check, and Muddler 1.1.0"
        status: pass
    human_judgment: false
  - id: D5
    description: "The complete packaged real-Mudlet suite and live settled-Add flow pass at the immutable final SHA."
    requirement: WALK-02
    verification:
      - kind: integration
        ref: "Parent-owned tools/wait_for_exact_ci.sh and live Phase 03 UAT"
        status: unknown
    human_judgment: true
    rationale: "This sequential executor was explicitly forbidden to push; exact-final-SHA CI and live UAT remain parent-owned terminal gates."

duration: 6m
completed: 2026-07-28
status: complete
---

# Phase 03 Plan 16: Settled Gold Add Revalidation Summary

**One exact-operation `Char.Items.Room` fence now turns a settled same-room gold Add into canonical copied-List evidence without letting the room-ID-less Add authorize pickup.**

## Performance

- **Duration:** 6m
- **Started:** 2026-07-28T07:34:12Z
- **Completed:** 2026-07-28T07:40:42Z
- **Tasks:** 2
- **Files modified:** 7

## Accomplishments

- Added focused G-03-5 gold and cross-event regressions covering the settled non-gold List → gold Add boundary, duplicate signals, inventory rejection, exact get-confirm-put staging, aggregate owners, retargeting, and movement-before-response.
- Added a typed room-only response fence that starts at `await_room`, retains FIFO invalidation/drain semantics, and leaves ordinary capped Inv→Room observations unchanged.
- Bound each settled-Add revalidation to the exact gold operation, room ID, room generation, and one-request allowance while keeping `acceptedItems` authoritative.
- Synchronized all four package checkpoints through RED version `0.1.430` and final GREEN version `0.1.431`.

## Task Commits

Each implementation task was committed atomically:

1. **Task 1: Reproduce the settled-List then gold-Add stall and its race boundaries** - `77a19c3` (test, version `0.1.430`)
2. **Task 2: Fence and consume one operation-scoped room revalidation** - `c412291` (fix, version `0.1.431`)

## RED Evidence

- The focused host run retained 54 existing successes and produced exactly 3 named `G-03-5 settled-add-revalidation` failures with 0 errors.
- All failures were the missing behavior: no operation revalidation marker and no room-only fence after the settled Add.
- Release gates passed with all four synchronized version checkpoints at `0.1.430`.

## GREEN Evidence

- `tests/boop_gold_spec.lua` and `tests/boop_event_transitions_spec.lua`: 57 successes, 0 failures, 0 errors.
- Affected `boop_lifecycle_spec.lua`, `boop_trace_spec.lua`, and `boop_walk_spec.lua`: 48 successes, 0 failures, 0 errors.
- The accepted current room response preserves the original gold generation/owner, sends one get, transfers only on confirmed pickup, sends one put when configured, and ignores duplicates.
- Movement invalidates the old fence and gold owner; its delayed room response drains without gold, attack, queue-clear, or walker movement.

## Files Created/Modified

- `tests/boop_gold_spec.lua` - Proves one request allowance, non-canonical Add handling, exact response promotion, duplicate suppression, and a later operation's independent allowance.
- `tests/boop_event_transitions_spec.lua` - Proves retargeting remains possible while aggregate owners hold downstream work and stale moved-room responses remain effect-free.
- `src/scripts/boop/boop_runtime.lua` - Adds exact-room/generation room-only fences and timeout handling without weakening ordinary fences.
- `src/scripts/boop/boop_events.lua` - Requests, records, and consumes one settled-Add revalidation through the existing accepted-List transition.
- `mfile`, `src/scripts/boop/boop_init.lua`, `CODEX.md` - Synchronize package metadata at final version `0.1.431`.

## Decisions Made

- The Add is a trigger for revalidation, not evidence. Only a later fenced room List containing the exact item ID can promote pickup.
- Room-only revalidation skips `Char.Items.Inv`; ordinary room observation still requires serialized Inv then Room responses.
- Gold self-owner exclusion remains exact, and unrelated combat/queue/gold/walk owners continue blocking until their real release.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Test Contract] Narrowed an over-broad downstream-send assertion**
- **Found during:** Task 2 GREEN verification
- **Issue:** The cross-event RED test prohibited every `send`, but target removal is explicitly allowed to retarget and therefore may emit target-selection output.
- **Fix:** Asserted the intended safety boundary directly: no gold, queue-clear, attack, or walker movement while exact gold and unrelated owners remain active.
- **Files modified:** `tests/boop_event_transitions_spec.lua`
- **Commit:** `77a19c3` (amended before the GREEN commit)

## Issues Encountered

- The repository `muddle` container wrapper requires a TTY. The first non-PTY invocation stopped before building; rerunning the same command with a PTY built `build/boop Hunter.mpackage` successfully.

## Verification

- Focused host suites: 57 successes, 0 failures, 0 errors.
- Affected fence consumers: 48 successes, 0 failures, 0 errors.
- Lua syntax: `luac -p` passed for `boop_runtime.lua` and `boop_events.lua`.
- Release gates: versions, manifests, and state drift all `[OK]` at `0.1.431`.
- Diff hygiene: `git diff --check` passed.
- Muddler 1.1.0 built `build/boop Hunter.mpackage` successfully at `0.1.431`; ignored generated output was not staged or committed.
- Terminal exact-final-SHA CI and live UAT were intentionally not run or claimed by this executor.

## Known Stubs

- Empty fixture tables, synthetic GMCP values, and captured timer callbacks in the changed specs are intentional deterministic test infrastructure.
- Existing empty-string defaults in `boop_init.lua` are valid unset configuration values; this plan changed only its version line.

## User Setup Required

None - no dependency, command, help, or configuration surface changed.

## Next Phase Readiness

- G-03-5 now has executable RED→GREEN coverage and production wiring at package `0.1.431`.
- Plans 03-17 through 03-19 remain for the parent orchestrator's sequential execution.
- Exact-final-SHA CI and live Phase 03 UAT remain parent-owned after every planned repository mutation is complete.

## Self-Check: PASSED

- The summary and all seven implementation/version paths exist.
- Task commits `77a19c3` and `c412291` are present in RED → GREEN order.
- Focused, affected-consumer, syntax, release-gate, diff, version, and package-build claims match observed command output.
- Terminal exact-final-SHA CI and live UAT are explicitly reserved for the parent.

---
*Phase: 03-queue-interrupt-gold-and-autowalk-regression-coverage*
*Completed: 2026-07-28*
