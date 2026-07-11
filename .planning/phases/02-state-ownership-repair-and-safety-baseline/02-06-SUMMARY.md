---
phase: 02-state-ownership-repair-and-safety-baseline
plan: 06
subsystem: ui
tags: [lua, mudlet, status, dashboard, blockers, docs]
requires:
  - phase: 02-state-ownership-repair-and-safety-baseline
    provides: canonical runtime blocker snapshot and owned walk/blocker state from plans 02-03 through 02-05
provides:
  - Canonical blocker rendering across status, dashboard, control/config, party, and debug surfaces
  - Operator help/docs aligned to stable blocker code-plus-label, systems, and waits-for output
  - Recorded local verification limits for host Busted and Mudlet Busted availability
affects: [phase-02, phase-03, phase-06, status-ui, operator-docs]
tech-stack:
  added: []
  patterns:
    - Runtime blocker snapshot is the UI source of truth for blocker code, label, affected systems, and waits-for fragments.
    - Help/docs only describe blocker fields visible to operators.
key-files:
  created:
    - .planning/phases/02-state-ownership-repair-and-safety-baseline/02-06-SUMMARY.md
  modified:
    - src/scripts/boop/boop_ui.lua
    - src/scripts/boop/boop_ui_registry.lua
    - README.md
    - UIDESIGN.md
    - mfile
    - src/scripts/boop/boop_init.lua
    - CODEX.md
key-decisions:
  - "Use boop.runtime.blockerSnapshot() as the status/dashboard/debug blocker source of truth, with legacy checks only as inactive-blocker fallbacks."
  - "Keep trace source unchanged because prior Phase 02 contracts already emit normalized blocker enter/exit, cleanup, GMCP recovery, pull, and retarget messages."
  - "Document Busted/Mudlet availability limitations instead of treating environment failures as passing tests."
patterns-established:
  - "Canonical blocker text is rendered as code -- label, with compact systems: and waits: fragments when present."
  - "Status-visible docs stay scoped to real command-surface output and avoid claiming full live reconnect or walker-route coverage."
requirements-completed: [STATE-02, STATE-03]
coverage:
  - id: D1
    description: Status, dashboard, control/config, party, and debug surfaces render the runtime blocker snapshot with stable code-plus-label output.
    requirement: STATE-03
    verification:
      - kind: other
        ref: "luac -p src/scripts/boop/boop_ui.lua tests/boop_ui_spec.lua"
        status: pass
      - kind: other
        ref: "python3 tools/check_release_gates.py --check state-drift"
        status: pass
      - kind: unit
        ref: "TESTS_DIRECTORY=$PWD/tests busted tests/boop_ui_spec.lua"
        status: unknown
    human_judgment: true
    rationale: "Host Busted failed before executing specs because the boop package was not loaded; verifier should review the recorded environment limitation."
  - id: D2
    description: Help, README, and UIDESIGN describe the changed status/debug blocker fields without overstating Phase 02 validation.
    requirement: STATE-03
    verification:
      - kind: other
        ref: "luac -p src/scripts/boop/boop_ui.lua src/scripts/boop/boop_ui_registry.lua tests/boop_trace_spec.lua tests/boop_ui_spec.lua"
        status: pass
      - kind: other
        ref: "rg -n 'full live reconnect|full walker route coverage' README.md UIDESIGN.md src/scripts/boop/boop_ui_registry.lua"
        status: pass
    human_judgment: false
  - id: D3
    description: Built package loads under the Mudlet AppImage verification path, with full Mudlet Busted blocked by local profile dependency availability.
    requirement: STATE-02
    verification:
      - kind: other
        ref: "muddle"
        status: pass
      - kind: e2e
        ref: "AUTORUN_BUSTED_TESTS=true TESTS_DIRECTORY=$PWD/tests QUIT_MUDLET_AFTER_TESTS=true PRETEST_PACKAGE=$PWD/build/boop Hunter.mpackage /tmp/Mudlet.AppImage --profile GithubTests --mirror"
        status: unknown
    human_judgment: true
    rationale: "Mudlet loaded and auto-ran the test hook but reported 'Busted not available', so full Mudlet Busted execution remains a Phase 02/02-07 environment concern."
duration: 8m
completed: 2026-07-11
status: complete
---

# Phase 02 Plan 06: Canonical Status Dashboard Summary

**Runtime blocker snapshots now drive compact status, dashboard, debug, and focused operator docs with stable code-plus-label wording.**

## Performance

- **Duration:** 8m
- **Started:** 2026-07-11T01:21:54Z
- **Completed:** 2026-07-11T01:30:01Z
- **Tasks:** 2
- **Files modified:** 7

## Accomplishments

- Replaced UI-side blocker inference with a formatter that reads `boop.runtime.blockerSnapshot()` and renders `code -- label`, `systems:`, and `waits:` fragments consistently.
- Updated status, home, control/config, party, and debug output so the same seeded blocker presents the same canonical code and label across operator surfaces.
- Synced command help, README, and UIDESIGN guidance for the changed blocker/status fields without claiming full live reconnect validation or full walker route coverage.

## Task Commits

Each task was committed atomically:

1. **Task 1: Replace ad hoc UI blockers with the runtime snapshot** - `9ac1dd3` (feat)
2. **Task 2: Ensure trace and help/docs match the changed status surface** - `2344839` (docs)

## Files Created/Modified

- `src/scripts/boop/boop_ui.lua` - Added canonical blocker detail formatting and rendered blocker details across status/dashboard/debug surfaces.
- `src/scripts/boop/boop_ui_registry.lua` - Updated help text for visible blocker/status/debug output.
- `README.md` - Documented stable blocker `code -- label`, affected systems, and waits-for status fragments.
- `UIDESIGN.md` - Added design guidance for compact canonical blocker/status output.
- `mfile` - Synchronized package version bumps required by repo policy.
- `src/scripts/boop/boop_init.lua` - Synchronized `boop.version` required by repo policy.
- `CODEX.md` - Synchronized current package-version checkpoint required by repo policy.

## Decisions Made

- `boop.runtime.blockerSnapshot()` is the authoritative UI source for active blocker state; local disabled/diag/gold/leader/walk checks are fallbacks only when no canonical active blocker exists.
- Trace production code did not need modification in this plan because prior Phase 02 work already normalized blocker enter/exit, cleanup, GMCP recovery, pull, and retarget trace messages.
- Busted and Mudlet Busted limitations were recorded as environment limitations, not hidden or reported as passing tests.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Required repo workflow] Applied mandatory version synchronization and task commits**
- **Found during:** Task 1, Task 2, and metadata closeout
- **Issue:** The plan output block delegated commits/version sync to the orchestrator, but this sequential executor run and repo policy required the executor to commit atomically and keep all version fields synchronized before every commit.
- **Fix:** Bumped and synchronized `mfile.version`, `mfile.title`, `src/scripts/boop/boop_init.lua` `boop.version`, and `CODEX.md` before each task commit.
- **Files modified:** `mfile`, `src/scripts/boop/boop_init.lua`, `CODEX.md`
- **Verification:** `python3 tools/check_release_gates.py --check versions` before each commit, plus full release gates where practical.
- **Committed in:** `9ac1dd3`, `2344839`

**2. [Rule 3 - Verification environment] Used pseudo-terminal execution for Muddler/Mudlet verification**
- **Found during:** Plan-level verification
- **Issue:** The local command harness failed non-TTY Muddler execution with `cannot attach stdin to a TTY-enabled container because stdin is not a terminal`.
- **Fix:** Reran `muddle` and the Mudlet AppImage command with a pseudo-terminal so project verification could proceed to the actual Mudlet test hook.
- **Files modified:** None
- **Verification:** `muddle` completed successfully; Mudlet loaded the profile and reported the remaining `Busted not available` limitation.
- **Committed in:** Not applicable

---

**Total deviations:** 2 auto-fixed (Rule 2: 1, Rule 3: 1)
**Impact on plan:** Repo workflow and verification harness adjustments only; no feature-scope expansion.

## Issues Encountered

- `TESTS_DIRECTORY="$PWD/tests" busted tests/boop_ui_spec.lua` failed before running specs with `tests/support/boop_test_helper.lua:94: boop package is not loaded`.
- `TESTS_DIRECTORY="$PWD/tests" busted tests/boop_trace_spec.lua` failed before running specs with the same package-load error.
- The Mudlet AppImage command loaded the built package path and started the autorun hook, but reported `Busted not available - double-check that it's installed properly.`

## Verification

- `luac -p src/scripts/boop/boop_ui.lua tests/boop_ui_spec.lua` - pass
- `luac -p src/scripts/boop/boop_ui.lua src/scripts/boop/boop_ui_registry.lua tests/boop_trace_spec.lua tests/boop_ui_spec.lua` - pass
- `python3 tools/check_release_gates.py --check state-drift` - pass
- `python3 tools/check_release_gates.py` - pass
- `python3 tools/check_release_gates.py --check versions` - pass before each task commit
- `muddle` - pass, built `build/boop Hunter.mpackage` for version `0.1.371`
- Host Busted UI/trace specs - attempted, blocked before specs because the boop package was not loaded
- Mudlet AppImage suite - attempted, profile loaded and test hook ran, blocked because Busted was not available in the profile

## Known Stubs

None introduced. Stub-pattern scanning found ordinary Lua nil/empty guards, existing defensive `debug skills dump` availability messages, and a UIDESIGN instruction about avoiding placeholder-looking help syntax; none are new unwired UI placeholders.

## Threat Flags

None. This plan changed local operator rendering and documentation only; it introduced no new network endpoints, authentication paths, file-access trust boundary, or schema changes.

## User Setup Required

None for the code changes. Full Mudlet Busted verification still requires a Mudlet profile with Busted available; Plan 02-07 owns the final automated gates and compact blocker/status human checkpoint.

## Next Phase Readiness

Plan 02-07 can use these canonical status/debug surfaces for final automated gates and human verification. Remaining risk is validation-environment availability, not an uncommitted code path in this plan.

## Self-Check: PASSED

- Summary file exists at `.planning/phases/02-state-ownership-repair-and-safety-baseline/02-06-SUMMARY.md`.
- Task commits exist: `9ac1dd3`, `2344839`.
- Key files exist: `src/scripts/boop/boop_ui.lua`, `src/scripts/boop/boop_ui_registry.lua`, `README.md`, `UIDESIGN.md`, `mfile`, `src/scripts/boop/boop_init.lua`, `CODEX.md`.
- Version synchronization check passed with `python3 tools/check_release_gates.py --check versions`.

---
*Phase: 02-state-ownership-repair-and-safety-baseline*
*Completed: 2026-07-11*
