---
phase: 03-queue-interrupt-gold-and-autowalk-regression-coverage
plan: "01"
subsystem: runtime-safety
tags: [lua, mudlet, blocker-ownership, gmcp, room-observation, regression-tests]
requires:
  - phase: 02-state-ownership-repair-and-safety-baseline
    provides: canonical blocker coordination, owned runtime domains, fail-closed GMCP handling, and walk holds
provides:
  - Owner-keyed blocker registry with exact-owner set, clear, exclusion, and immutable sorted snapshots
  - Stable GMCP IRE, room-observation, and target-loss event owners with owner-specific traces
  - Current-generation room observation requiring Room.Info followed by a complete room item list
  - One capped Char.Items.Room refresh per generation while gold and movement remain held
affects: [03-02, 03-03, 03-04, 03-05, 03-06, 03-07, 03-08, 03-09]
tech-stack:
  added: []
  patterns:
    - Active blockers are authoritative by exact owner; the singular blocker is a derived compatibility snapshot.
    - Room settlement is ordered evidence, not a prompt or timer assumption.
    - Recovery requests mutate the current observation generation once and never stamp settlement.
key-files:
  created:
    - .planning/phases/03-queue-interrupt-gold-and-autowalk-regression-coverage/03-01-SUMMARY.md
  modified:
    - src/scripts/boop/boop_runtime.lua
    - src/scripts/boop/boop_events.lua
    - tests/boop_runtime_spec.lua
    - tests/boop_trace_spec.lua
    - tests/boop_event_transitions_spec.lua
    - tests/support/boop_test_helper.lua
key-decisions:
  - "Use state.combat.blockersByOwner as the sole authoritative active blocker collection and retain state.combat.blocker only as a derived primary snapshot."
  - "Identify blocker release and lifecycle self-exclusion only by exact owner key; blocker code, family, and subsystem names never authorize exclusion."
  - "Require each Room.Info generation to receive a later complete room item list before room evidence can authorize gold or movement."
  - "Issue at most one Char.Items.Room recovery request per room generation, with duplicate attempts warning once and remaining fail closed."
patterns-established:
  - "Blocker ordering: configured priority, then code, then owner."
  - "Room evidence: Room.Info starts and invalidates; complete current-cycle room List stamps; prompt, timer, Add, and Remove do not stamp."
requirements-completed: [SAFE-02, SAFE-04, WALK-01, WALK-02]
coverage:
  - id: D1
    description: Exact-owner blocker aggregation preserves unrelated attack, queue, gold, and movement holds in either clear order.
    requirement: SAFE-02
    verification:
      - kind: unit
        ref: "lua -e owner and room runtime diagnostic"
        status: pass
      - kind: integration
        ref: "tests/boop_runtime_spec.lua in Mudlet/Busted"
        status: unknown
    human_judgment: true
    rationale: "Core owner semantics passed the direct Lua diagnostic, but the observable send/timer/event cases require the matching real-Mudlet Busted run."
  - id: D2
    description: GMCP IRE, room observation, and target-loss events mutate only their stable owner records and retain unrelated owners.
    requirement: SAFE-02
    verification:
      - kind: other
        ref: "luac -p src/scripts/boop/boop_events.lua tests/boop_trace_spec.lua tests/boop_event_transitions_spec.lua"
        status: pass
      - kind: integration
        ref: "tests/boop_trace_spec.lua and tests/boop_event_transitions_spec.lua in Mudlet/Busted"
        status: unknown
    human_judgment: true
    rationale: "Event-boundary assertions are authored and syntax-valid, but the local Mudlet AppImage needed to execute them is unavailable."
  - id: D3
    description: Current-generation Room.Info plus a later complete room item list is the only room-settlement evidence path.
    requirement: WALK-01
    verification:
      - kind: unit
        ref: "lua -e owner and room runtime diagnostic"
        status: pass
      - kind: integration
        ref: "tests/boop_event_transitions_spec.lua room generation, prompt, timer, stale-list, and duplicate-list cases"
        status: unknown
    human_judgment: true
    rationale: "Runtime generation and stamping passed directly; real-Mudlet event ordering remains assigned to GitHub Actions."
  - id: D4
    description: Incomplete room evidence requests Char.Items.Room once per generation and emits no loot command or movement event.
    requirement: SAFE-04
    verification:
      - kind: other
        ref: "python3 tools/check_release_gates.py"
        status: pass
      - kind: integration
        ref: "tests/boop_event_transitions_spec.lua capped-refresh and held-loot cases"
        status: unknown
    human_judgment: true
    rationale: "Static gates and direct API diagnostics pass; exact Mudlet sendGMCP/send/raiseEvent counts require the authoritative CI profile."
  - id: D5
    description: Walk-affecting owners aggregate deterministically and movement remains held until every unrelated owner clears.
    requirement: WALK-02
    verification:
      - kind: other
        ref: "luac -p tests/boop_runtime_spec.lua tests/boop_event_transitions_spec.lua"
        status: pass
      - kind: integration
        ref: "tests/boop_runtime_spec.lua both-clear-order movement cases in Mudlet/Busted"
        status: unknown
    human_judgment: true
    rationale: "The movement contracts are syntax-valid but require real-Mudlet event and timer stubs for authoritative execution."
duration: 17m
completed: 2026-07-26
status: complete
---

# Phase 03 Plan 01: Exact-Owner and Current-Room Evidence Foundation Summary

**Owner-keyed aggregate blockers and generation-bound room evidence now keep attacks, loot, and movement fail closed until every relevant owner and current room observation clears.**

## Performance

- **Duration:** 17m
- **Started:** 2026-07-26T12:57:50Z
- **Completed:** 2026-07-26T13:14:30Z
- **Tasks:** 3
- **Files modified:** 12

## Accomplishments

- Replaced singular active-blocker authority with an exact-owner registry, deterministic priority/code/owner ordering, immutable all-owner snapshots, and a derived compatibility primary.
- Migrated GMCP IRE, room-observation, and target-loss event boundaries to stable owners with owner-specific evidence, clear calls, and trace transitions.
- Added current-generation room evidence and one capped `Char.Items.Room` refresh so only a complete room list after current `Room.Info` can release room-bound gold and movement holds.
- Added RED/GREEN regression coverage for both owner-clear orders, exact-owner exclusion, immutable snapshots, stable event owners, stale room evidence, prompt/timer non-settlement, duplicate lists, and exact side-effect counts.

## Task Commits

Each task was committed atomically:

1. **Task 1: Pin exact-owner and observable all-clear contracts** - `d531391` (test)
2. **Task 2: Implement canonical blocker ownership and snapshots** - `a0f3cba` (feat)
3. **Task 3: Establish current-generation room evidence and capped refresh** - `b84c205` (feat)

**Plan metadata:** committed separately with this summary.

## Files Created/Modified

- `.planning/phases/03-queue-interrupt-gold-and-autowalk-regression-coverage/03-01-SUMMARY.md` - Records implementation, evidence, deviations, and downstream readiness.
- `src/scripts/boop/boop_runtime.lua` - Owns the blocker registry, deterministic snapshots, exact-owner holds, and room-observation APIs.
- `src/scripts/boop/boop_events.lua` - Routes stable event owners and current room evidence through one capped refresh boundary.
- `src/scripts/boop/boop_ui.lua` - Passes the active pull generation owner at the timeout blocker transition.
- `tests/support/boop_test_helper.lua` - Seeds exact blockers and deterministic room-observation cycles.
- `tests/boop_runtime_spec.lua` - Covers all-clear side effects, exclusion identity, ordering, and immutable snapshots.
- `tests/boop_trace_spec.lua` - Covers owner-specific enter/exit traces and deterministic all-owner snapshots.
- `tests/boop_event_transitions_spec.lua` - Covers stable event owners and current-generation room evidence ordering.
- `tests/boop_gold_spec.lua` - Uses an exact test owner for the owner-aware blocker API fixture.
- `mfile` - Advances package title and version through the three required patch increments.
- `src/scripts/boop/boop_init.lua` - Keeps `boop.version` synchronized at `0.1.397`.
- `CODEX.md` - Keeps the package-version checkpoint synchronized at `0.1.397`.

## Decisions Made

- Blocker owners are lifecycle identity. Codes remain presentation and ordering data, never mutation or exclusion keys.
- `state.combat.blockersByOwner` is authoritative; `state.combat.blocker` is regenerated as a compatibility view after every owner transition.
- Room observation belongs to `state.targeting`, because room identity and denizens are shared truth consumed by gold and walk.
- Every `Room.Info` event starts a fresh generation, resets prior item evidence, establishes a room hold, and may issue one item-list refresh.
- Only a table-valued `Char.Items.List` at `location == "room"` stamps current evidence. Item Add/Remove, prompt, and timer paths cannot settle the observation.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing Critical] Migrated remaining direct blocker callers**
- **Found during:** Task 2 (canonical blocker ownership)
- **Issue:** The pull-timeout UI transition and one gold test fixture still called the old code-first blocker signature, which would create incorrect owners after the public API migration.
- **Fix:** Passed the dynamic `pull:<generation>` owner from the UI transition and assigned the gold fixture an exact `test:gold` owner.
- **Files modified:** `src/scripts/boop/boop_ui.lua`, `tests/boop_gold_spec.lua`
- **Verification:** Lua syntax, owner API diagnostic, focused source scan, and full release gate passed.
- **Committed in:** `a0f3cba`

**2. [Rule 3 - Blocking] Started a deterministic room cycle in shared test reset**
- **Found during:** Task 3 (current-generation room evidence)
- **Issue:** Existing focused specs invoke complete room-list handlers directly after `helper.reset()`; without a current observation cycle those established fixtures could no longer represent valid ordered GMCP evidence.
- **Fix:** Reused the existing reset helper to start observation for its seeded `gmcp.Room.Info` without adding another helper API.
- **Files modified:** `tests/support/boop_test_helper.lua`
- **Verification:** Lua syntax, current-list diagnostic, event-spec source assertions, and full release gate passed.
- **Committed in:** `b84c205`

---

**Total deviations:** 2 auto-fixed (Rule 2: 1, Rule 3: 1)
**Impact on plan:** Both fixes were required to complete the owner-signature migration and preserve valid ordered GMCP fixtures; no command surface or unrelated feature scope was added.

## Issues Encountered

- `/tmp/Mudlet.AppImage` is unavailable in this environment, so the focused real-Mudlet Busted specs could not be executed locally. The matching GitHub Actions Mudlet/Busted run remains authoritative and is intentionally owned by the parent after the final immutable Phase 03 HEAD is pushed.
- The orchestrator's pre-existing Phase 03 `STATE.md` execution-start update was preserved for the normal closeout rather than reverted or split from project state.

## Verification

- `luac -p src/scripts/boop/boop_runtime.lua src/scripts/boop/boop_events.lua src/scripts/boop/boop_ui.lua tests/support/boop_test_helper.lua tests/boop_runtime_spec.lua tests/boop_trace_spec.lua tests/boop_event_transitions_spec.lua tests/boop_gold_spec.lua` - pass
- `python3 tools/check_release_gates.py --check versions` - pass after each package-affecting task
- `python3 tools/check_release_gates.py` - pass before every task commit and in the final plan-wide verification
- Direct Lua owner/room diagnostic - pass for deterministic ordering, exact exclusion, immutable snapshots, owner clear, room generation reset, and complete-list stamping
- Direct runtime/event room diagnostic - pass for one capped `Char.Items.Room` request, duplicate suppression, current-list settlement, room hold release, and no premature command send
- Focused Mudlet/Busted specs - pending authoritative GitHub Actions because the local Mudlet AppImage is unavailable

## Known Stubs

None. Empty maps, strings, and `nil` timer fields found by the stub scan are intentional runtime/test initializers; no placeholder data flows to a plan deliverable.

## User Setup Required

None - no external service configuration is required.

## Next Phase Readiness

- Plans 03-02 through 03-09 can use exact lifecycle owner keys without overwriting unrelated holds.
- Interrupt, pull, gold, and walk generations can now self-exclude only their exact owner while consulting immutable aggregate snapshots.
- Gold and walk plans have shared current-room evidence and capped refresh state available; the remaining focused Mudlet/Busted confirmation belongs to the parent repository CI gate.

## Self-Check: PASSED

- Summary file exists at `.planning/phases/03-queue-interrupt-gold-and-autowalk-regression-coverage/03-01-SUMMARY.md`.
- Task commits exist: `d531391`, `a0f3cba`, and `b84c205`.
- Key runtime, event, helper, and focused spec files exist.
- Final `python3 tools/check_release_gates.py` passed with synchronized package version `0.1.397`.

---
*Phase: 03-queue-interrupt-gold-and-autowalk-regression-coverage*
*Completed: 2026-07-26*
