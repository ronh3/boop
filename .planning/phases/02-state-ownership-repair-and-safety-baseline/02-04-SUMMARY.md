---
phase: 02-state-ownership-repair-and-safety-baseline
plan: 04
subsystem: runtime-state
tags: [runtime, safety, target-loss, attacks, state-drift, mudlet]

requires:
  - phase: 02-state-ownership-repair-and-safety-baseline/02-03
    provides: Canonical runtime blocker and cleanup helpers used by safety and target-loss paths.
provides:
  - Flee cleanup now clears automation intent before escape movement is sent.
  - Target disappearance now clears attack intent through the canonical runtime helper before retargeting.
  - Phase 02-owned attack fallback reads now use owned runtime domains and a tightened state-drift baseline.
affects: [phase-02, safety, target-loss, attacks, release-gates]

tech-stack:
  added: []
  patterns:
    - Runtime cleanup helpers own cross-domain automation cleanup.
    - Target-loss retargeting is held behind trustworthy current-room denizen state.
    - Migrated attack helpers use runtime context or owned state domains rather than flat fallback fields.

key-files:
  created:
    - .planning/phases/02-state-ownership-repair-and-safety-baseline/02-04-SUMMARY.md
  modified:
    - src/scripts/boop/boop_safety.lua
    - src/scripts/boop/boop_events.lua
    - src/scripts/boop/boop_attacks.lua
    - tools/check_release_gates.py
    - mfile
    - src/scripts/boop/boop_init.lua
    - CODEX.md

key-decisions:
  - "Use the Plan 02-03 runtime helper as the source of truth; this plan did not modify boop_runtime.lua."
  - "Target loss clears attack intent with clearAttackIntent rather than broad automation cleanup."
  - "Attack fallback migration is enforced by reducing boop_attacks.lua flat-state drift allowance to zero."
  - "Sequential execution applied mandatory repo version synchronization and commits despite the plan output block delegating those to the orchestrator."

patterns-established:
  - "Cleanup before side effects: safety escape movement is sent only after runtime automation intent is cleared."
  - "Narrow pull exception: active pull lifecycle remains held, then normal target-loss cleanup applies after return if the target is still absent."
  - "Owned-domain fallback: no-context attack helpers fall back to boop.state.combat, targeting, rage, and inventory domains."

requirements-completed: [STATE-01, SAFE-01, SAFE-03]

coverage:
  - id: D1
    description: "Auto-flee clears queue, walk, gold, target-call, rage, and attack intent before escape movement while leaving hunting disabled."
    requirement: SAFE-01
    verification:
      - kind: unit
        ref: "luac -p src/scripts/boop/boop_safety.lua tests/boop_safety_spec.lua"
        status: pass
      - kind: other
        ref: "python3 tools/check_release_gates.py --check state-drift"
        status: pass
      - kind: unit
        ref: "TESTS_DIRECTORY=\"$PWD/tests\" busted tests/boop_safety_spec.lua"
        status: unknown
    human_judgment: true
    rationale: "Host Busted failed before loading the package; Mudlet-backed verification is still needed for behavioral confirmation."
  - id: D2
    description: "Target disappearance clears stale attack intent before retargeting and preserves the active pull exception lifecycle."
    requirement: SAFE-03
    verification:
      - kind: unit
        ref: "luac -p src/scripts/boop/boop_events.lua src/scripts/boop/boop_targets.lua tests/boop_event_transitions_spec.lua tests/boop_pull_spec.lua"
        status: pass
      - kind: other
        ref: "python3 tools/check_release_gates.py --check state-drift"
        status: pass
      - kind: unit
        ref: "TESTS_DIRECTORY=\"$PWD/tests\" busted tests/boop_event_transitions_spec.lua tests/boop_pull_spec.lua"
        status: unknown
    human_judgment: true
    rationale: "Host Busted failed before loading the package; Mudlet-backed target-loss and pull behavior still needs runtime confirmation."
  - id: D3
    description: "Phase 02-owned attack fallback reads now use owned state domains and boop_attacks.lua has no allowed flat-state drift."
    requirement: STATE-01
    verification:
      - kind: unit
        ref: "luac -p src/scripts/boop/boop_attacks.lua tests/boop_attacks_spec.lua tests/boop_runtime_spec.lua"
        status: pass
      - kind: other
        ref: "rg flat fallback tokens in src/scripts/boop/boop_attacks.lua"
        status: pass
      - kind: other
        ref: "python3 tools/check_release_gates.py --check state-drift"
        status: pass
    human_judgment: false

duration: 6m 27s
completed: 2026-07-11
status: complete
---

# Phase 02 Plan 04: Flee, Target-Loss, and Attack Fallback Cleanup Summary

**Flee and target-loss cleanup now flow through canonical runtime intent helpers before movement, retargeting, or queued attacks can continue.**

## Performance

- **Duration:** 6m 27s
- **Started:** 2026-07-11T00:58:31Z
- **Completed:** 2026-07-11T01:04:58Z
- **Tasks:** 3
- **Files modified:** 7

## Accomplishments

- `boop.safety.flee()` now clears automation intent with `includeWalk`, `includeGold`, and `includeAttack` before reading the flee direction or sending escape movement.
- Target-loss handling now clears attack intent with the canonical runtime helper, emits one `target_lost` warning, and retargets only when current-room denizen state is trustworthy.
- Attack planning fallbacks for class/spec, target id, shield, rage readiness, wielded items, and opener trace state now read owned runtime domains, and the release gate baseline enforces zero allowed drift for `boop_attacks.lua`.

## Task Commits

Each task was committed atomically:

1. **Task 1: Move auto-flee cleanup before escape movement** - `8f2459a` (`feat`)
2. **Task 2: Centralize target-loss cleanup and pull exception handling** - `06b023d` (`feat`)
3. **Task 3: Remove Phase 02-owned attack fallback flat-state access** - `f3b1487` (`feat`)

## Files Created/Modified

- `src/scripts/boop/boop_safety.lua` - Clears canonical automation intent before flee movement and uses owned state for flee bookkeeping.
- `src/scripts/boop/boop_events.lua` - Centralizes target-loss warnings and attack cleanup while preserving pull exception behavior.
- `src/scripts/boop/boop_attacks.lua` - Removes Phase 02-owned flat-state fallback reads from attack planning helpers.
- `tools/check_release_gates.py` - Tightens `boop_attacks.lua` flat-state drift allowance to zero.
- `mfile` - Synchronized package version for task commits.
- `src/scripts/boop/boop_init.lua` - Synchronized `boop.version` for task commits.
- `CODEX.md` - Synchronized current package version documentation.
- `.planning/phases/02-state-ownership-repair-and-safety-baseline/02-04-SUMMARY.md` - Execution summary and coverage metadata.

## Decisions Made

- Kept `src/scripts/boop/boop_runtime.lua` untouched because Plan 02-03 already owns `clearAutomationIntent` and `clearAttackIntent`.
- Used `clearAttackIntent("target_lost")` for target disappearance rather than broad cleanup so walk/gold state is not unnecessarily reset.
- Treated same-event retargeting as safe only after `shouldHold("target")` confirms the room/target state is not blocked.
- Applied the repository versioning rule before every commit, despite the plan's stale output note saying the orchestrator owned version synchronization.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing Critical] Applied mandatory version synchronization for executor-owned commits**
- **Found during:** Every task commit
- **Issue:** The plan output block said not to edit version fields, but `AGENTS.md` and `CODEX.md` require version fields to be bumped and synchronized before every commit.
- **Fix:** Bumped and synchronized `mfile.version`, `mfile.title`, `boop.version`, and `CODEX.md` current version for each task commit.
- **Files modified:** `mfile`, `src/scripts/boop/boop_init.lua`, `CODEX.md`
- **Verification:** `python3 tools/check_release_gates.py --check versions` before each commit; full `python3 tools/check_release_gates.py` before each task commit.
- **Committed in:** `8f2459a`, `06b023d`, `f3b1487`

**Total deviations:** 1 auto-fixed (Rule 2)
**Impact on plan:** The implementation scope stayed aligned with Plan 02-04; the deviation only reconciled the plan text with hard repository commit policy.

## Issues Encountered

- Host Busted commands failed before executing specs with `boop package is not loaded`. Focused Lua syntax checks and release gates passed, but these host Busted runs are recorded as unknown rather than passed.
- The exact wave-level command failed at the `muddle` wrapper because `/usr/local/bin/muddle` invokes Docker with `-it`: `cannot attach stdin to a TTY-enabled container because stdin is not a terminal`.
- An equivalent non-TTY Docker Muddler fallback built `boop Hunter.mpackage` successfully and `/tmp/Mudlet.AppImage` launched and exited cleanly, but Mudlet output reported `Busted not available - double-check that it's installed properly.`, so the in-Mudlet specs did not execute.

## Verification

- `luac -p src/scripts/boop/boop_safety.lua tests/boop_safety_spec.lua` - passed.
- `luac -p src/scripts/boop/boop_events.lua src/scripts/boop/boop_targets.lua tests/boop_event_transitions_spec.lua tests/boop_pull_spec.lua` - passed.
- `luac -p src/scripts/boop/boop_attacks.lua tests/boop_attacks_spec.lua tests/boop_runtime_spec.lua` - passed.
- `luac -p src/scripts/boop/boop_safety.lua src/scripts/boop/boop_events.lua src/scripts/boop/boop_targets.lua src/scripts/boop/boop_attacks.lua tests/boop_safety_spec.lua tests/boop_event_transitions_spec.lua tests/boop_pull_spec.lua tests/boop_attacks_spec.lua tests/boop_runtime_spec.lua` - passed.
- `python3 tools/check_release_gates.py --check state-drift` - passed after every task.
- `python3 tools/check_release_gates.py` - passed after implementation.
- `TESTS_DIRECTORY="$PWD/tests" busted ...` focused commands - failed before specs with `boop package is not loaded`.
- Exact full command `muddle && AUTORUN_BUSTED_TESTS=true TESTS_DIRECTORY="$PWD/tests" QUIT_MUDLET_AFTER_TESTS=true PRETEST_PACKAGE="$PWD/build/boop Hunter.mpackage" /tmp/Mudlet.AppImage --profile "GithubTests" --mirror` - failed at the Docker TTY wrapper before Mudlet execution.
- Non-TTY fallback Muddler plus Mudlet command - exited 0, built the package, and launched Mudlet, but Mudlet reported Busted unavailable so specs did not run.

## Known Stubs

None introduced by this plan. Stub scanning surfaced existing empty-string configuration defaults and normal nil/empty guards, not new UI or behavior stubs.

## Threat Flags

None. The plan modified existing safety, target-loss, and attack-planning surfaces already covered by the plan threat register; it did not add new network endpoints, auth paths, file access patterns, or schema boundaries.

## TDD Gate Compliance

This was an execute plan with `tdd="true"` tasks and pre-existing tests from earlier Phase 02 planning. Plan 02-04 produced GREEN implementation commits only; no RED `test(...)` commits were added in this plan because the contract tests already existed.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

Phase 02 state ownership is tighter for the highest-risk SAFE-01 and SAFE-03 paths. Remaining runtime confidence depends on a Mudlet environment with Busted available, because local host and AppImage verification did not execute the focused specs.

## Self-Check: PASSED

- Summary file exists at `.planning/phases/02-state-ownership-repair-and-safety-baseline/02-04-SUMMARY.md`.
- Task commits exist in git history: `8f2459a`, `06b023d`, `f3b1487`.
- Expected source, tooling, and version synchronization files exist.

---
*Phase: 02-state-ownership-repair-and-safety-baseline*
*Completed: 2026-07-11*
