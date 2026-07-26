---
phase: 03-queue-interrupt-gold-and-autowalk-regression-coverage
plan: "06"
subsystem: runtime-safety
tags: [lua, mudlet, autowalk, reservations, room-evidence, blocker-ownership, regression-tests]
requires:
  - phase: 03-queue-interrupt-gold-and-autowalk-regression-coverage
    plan: "05"
    provides: shared room observations, owner-keyed blockers, staged gold ownership, and aggregate all-clear runtime effects
provides:
  - Canonical walker run, room-generation, reservation, refresh, and emitter state
  - One shared automatic/manual all-clear evaluator with stable reason codes and labels
  - Exact-reservation deferred movement with stale callback and duplicate-emission guards
  - Generation-owned walker blocker transitions for settlement, reservation, package loss, and invalidation
  - Explicit-only optional walker installation with no status/start/move/loss package mutation
affects: [03-07, 03-08, 03-09, 06-docs-help-and-live-release-verification]
tech-stack:
  added: []
  patterns:
    - Normal movement treats every queued reservation as blocked; only the exact reserved emitter excludes its own owner.
    - Room settlement derives solely from current shared Room.Info plus complete current room items.
    - Deferred movement captures run generation, room generation, and monotonic reservation ID and rechecks all safety state before emission.
key-files:
  created:
    - .planning/phases/03-queue-interrupt-gold-and-autowalk-regression-coverage/03-06-SUMMARY.md
  modified:
    - src/scripts/boop/boop_runtime.lua
    - src/scripts/boop/boop_walk.lua
    - tests/support/boop_test_helper.lua
    - tests/boop_runtime_spec.lua
    - tests/boop_walk_spec.lua
    - mfile
    - src/scripts/boop/boop_init.lua
    - CODEX.md
key-decisions:
  - "Use shared current-room observation as the only settlement authority; the capped timer may warn but never stamps settlement."
  - "Keep moveQueued blocking in the public evaluator and allow only the matching run/room/reservation emitter to exclude walk:<generation>."
  - "Preserve a monotonic reservation ID across generation invalidation while canceling both refresh and emitter callback authority."
  - "Keep demonnicAutoWalker package mutation explicit: install is the only path allowed to call installPackage, and no path auto-updates."
patterns-established:
  - "Walker reservation: increment ID, capture run/room/reservation, update the exact owner, then schedule one guarded emitter."
  - "Walker invalidation: invalidate callback authority before clearing the captured owner or producing an external lifecycle effect."
  - "Missing room evidence: request one capped refresh, warn/trace once on exhaustion, and remain held."
requirements-completed: [WALK-01, WALK-02, WALK-03]
coverage:
  - id: D1
    description: Runtime reset and context expose an independent canonical walker domain with run, room, reservation, timer, and warning state.
    requirement: WALK-01
    verification:
      - kind: unit
        ref: "tests/boop_runtime_spec.lua#resets every walk field and materializes an independent domain"
        status: pass
      - kind: unit
        ref: "tests/boop_runtime_spec.lua#includes the current walk reservation in immutable runtime context"
        status: pass
    human_judgment: false
  - id: D2
    description: Automatic and manual movement share exact denials for package, mode, room, target, leader, gold, interrupt, pull, flee, and runtime-owner holds.
    requirement: WALK-02
    verification:
      - kind: unit
        ref: "tests/boop_walk_spec.lua table-driven automatic/manual denial matrix"
        status: pass
      - kind: other
        ref: "BOOP_REPO_ROOT=\"$PWD\" TESTS_DIRECTORY=\"$PWD/tests\" busted --helper=/tmp/boop_host_helper_0306.lua tests/boop_runtime_spec.lua tests/boop_walk_spec.lua"
        status: pass
    human_judgment: false
  - id: D3
    description: One current room cycle creates one run/room/reservation-bound emitter; stale, unrelated-owner, and duplicate callbacks emit no movement.
    requirement: WALK-01
    verification:
      - kind: unit
        ref: "tests/boop_walk_spec.lua reservation, stale generation, unrelated owner, duplicate callback, and new-room rearm cases"
        status: pass
    human_judgment: false
  - id: D4
    description: Walker ownership transitions through unsettled, move-pending, unavailable, and exact-owner clear while a capped room refresh never invents settlement.
    requirement: WALK-02
    verification:
      - kind: unit
        ref: "tests/boop_walk_spec.lua start, Room.Info, settlement, package loss, stop/detach/finish, and refresh-exhaustion cases"
        status: pass
      - kind: other
        ref: "luac -p src/scripts/boop/boop_runtime.lua src/scripts/boop/boop_walk.lua tests/support/boop_test_helper.lua tests/boop_runtime_spec.lua tests/boop_walk_spec.lua"
        status: pass
    human_judgment: false
  - id: D5
    description: demonnicAutoWalker remains optional and only explicit install may request package mutation; status, start, move, and package-loss paths never install or update.
    requirement: WALK-03
    verification:
      - kind: unit
        ref: "tests/boop_walk_spec.lua explicit install throw/return/success and no-implicit-mutation cases"
        status: pass
      - kind: other
        ref: "python3 tools/check_release_gates.py"
        status: pass
    human_judgment: false
  - id: D6
    description: The generated 0.1.407 package loads and executes the walker contracts inside a real Mudlet profile.
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
duration: 16m
completed: 2026-07-26
status: complete
---

# Phase 03 Plan 06: Walker Core and Guarded Emitter Summary

**Autowalk now derives readiness from current room evidence and emits only from the exact live run, room generation, and reservation after a final all-clear check.**

## Performance

- **Duration:** 16m
- **Started:** 2026-07-26T14:26:53Z
- **Completed:** 2026-07-26T14:43:02Z
- **Tasks:** 2
- **Files modified:** 8

## Accomplishments

- Added canonical walk defaults and immutable runtime context for generations, reservations, refresh/emitter timers, and one-per-room issuance state.
- Replaced divergent automatic/manual movement checks with stable three-value all-clear results across every safety and ownership condition.
- Bound the sole deferred movement emitter to exact run, room, and reservation identity, including final package/room/target/gold/interrupt/pull/flee/unrelated-owner rechecks.
- Added real `walk:<generation>` lifecycle transitions, capped room evidence recovery, package-loss invalidation, and explicit-only install behavior.
- Expanded deterministic fixtures and focused regressions to 45 passing runtime/walker checks.

## Task Commits

Each task was committed atomically:

1. **Task 1: Build walker core, package-boundary, and movement-gate contracts** - `0d69f55` (test)
2. **Task 2: Implement one all-clear evaluator and guarded move emitter** - `0f4dfb8` (feat)

**Plan metadata:** committed separately with this summary and state closeout.

## Files Created/Modified

- `.planning/phases/03-queue-interrupt-gold-and-autowalk-regression-coverage/03-06-SUMMARY.md` - Records walker-core decisions, verification, coverage, and closeout evidence.
- `src/scripts/boop/boop_runtime.lua` - Adds canonical walker state, generation-safe automation clearing, and immutable walk context.
- `src/scripts/boop/boop_walk.lua` - Implements stable reasons, shared all-clear evaluation, exact reservations, guarded emission, room refresh, ownership transitions, and package boundaries.
- `tests/support/boop_test_helper.lua` - Adds deterministic timer queues and walker/install/event fixtures.
- `tests/boop_runtime_spec.lua` - Covers every canonical walk default, reset independence, and immutable reservation context.
- `tests/boop_walk_spec.lua` - Covers gate parity, lifecycle ownership, one-per-room emission, stale callbacks, package loss, refresh exhaustion, and explicit install outcomes.
- `mfile` - Advances package title/version through the required task patch increments to `0.1.407`.
- `src/scripts/boop/boop_init.lua` - Keeps `boop.version` synchronized at `0.1.407`.
- `CODEX.md` - Keeps the package-version checkpoint synchronized at `0.1.407`.

## Decisions Made

- Only complete current shared room observation may authorize settlement; neither prompts nor timers can set `roomSettled`.
- `moveQueued` always blocks normal evaluation. The private reserved evaluator bypasses only that condition and the exact matching `walk:<generation>` owner after capture identity matches.
- Reservation IDs remain monotonic across run invalidation, while generation changes and timer cancellation remove all stale callback authority.
- Package loss fails closed on the current owner and warns once. Installation remains an explicit operator action, and no automatic update path was added.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Corrected unavailable walker fixture selection**
- **Found during:** Task 1 (Build walker core, package-boundary, and movement-gate contracts)
- **Issue:** A Lua `and nil or walker` expression made `available=false` fall through to the walker object, masking missing-package cases.
- **Fix:** Replaced the expression with an explicit availability branch.
- **Files modified:** `tests/support/boop_test_helper.lua`
- **Verification:** RED execution began failing on the intended missing-package production behavior; final focused execution passed all 45 checks.
- **Committed in:** `0d69f55`

**2. [Rule 1 - Bug] Seeded enabled hunting state for ready lifecycle fixtures**
- **Found during:** Task 2 (Implement one all-clear evaluator and guarded move emitter)
- **Issue:** Lifecycle success cases inherited the package's intentionally disabled default even though they modeled an all-clear hunting run.
- **Fix:** Set enabled/automatic targeting in the walk suite's common ready setup; explicit denial rows continue to override those values.
- **Files modified:** `tests/boop_walk_spec.lua`
- **Verification:** Focused runtime/walk execution passed 45/45 checks without weakening the hunting-disabled denial row.
- **Committed in:** `0f4dfb8`

---

**Total deviations:** 2 auto-fixed (2 Rule 1 bugs)
**Impact on plan:** Both fixes corrected deterministic test setup and preserved the planned production scope and safety behavior.

## Issues Encountered

- The repository's authoritative real-Mudlet path could not run because `/tmp/Mudlet.AppImage` is absent. The temporary host harness was extended to load the package's existing room-event refresh API for focused sampling; the parent workflow retains exact-final-HEAD Mudlet CI authority.

## User Setup Required

None - `demonnicAutoWalker` remains optional and installation is explicitly operator-triggered through the existing command.

## Next Phase Readiness

- Plan 03-07 can consume the stable generation/reservation API and exact `walk:<generation>` owner to finish stop/detach/restart and event-adapter ordering.
- Plan 03-08 can render the stable reason codes and aggregate owner state without reproducing movement safety logic.
- No implementation blocker remains. Real Mudlet focused/full-suite execution stays assigned to the parent exact-HEAD CI gate.

## Self-Check: PASSED

- Summary artifact exists and declares `status: complete`.
- Task commits `0d69f55` and `0f4dfb8` exist.
- All created/modified key files referenced by the summary exist.
- Coverage metadata validates with five automated deliverables and one intentionally deferred real-Mudlet integration check.

---
*Phase: 03-queue-interrupt-gold-and-autowalk-regression-coverage*
*Completed: 2026-07-26*
