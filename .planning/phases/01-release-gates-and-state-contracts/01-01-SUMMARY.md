---
phase: 01-release-gates-and-state-contracts
plan: "01"
subsystem: release-gates
tags: [ci, muddler, manifests, versioning, state-contracts]

requires: []
provides:
  - Local release gate CLI for version, manifest, and state-drift checks
  - Clean manifest parity baseline for current package source
  - Reviewed flat-state drift baseline for high-risk runtime paths
affects: [phase-01, phase-02, release, ci]

tech-stack:
  added: []
  patterns:
    - Python stdlib release gate called locally and by CI
    - Explicit flat-state drift baseline before behavior repair phases

key-files:
  created:
    - tools/check_release_gates.py
  modified:
    - src/triggers/boop/Shield/Weaponmastery_Two_Handed/triggers.json
    - mfile
    - src/scripts/boop/boop_init.lua
    - CODEX.md
  deleted:
    - src/aliases/boop/Targeting/Boop_IH.lua

key-decisions:
  - "Use Python stdlib only for deterministic release gates."
  - "Repair current manifest drift instead of broad allowlisting orphan Lua files."
  - "Baseline known flat-state access by symbol counts so future drift requires review."

patterns-established:
  - "Release gates run through tools/check_release_gates.py with focused --check modes."
  - "Manifest parity uses Muddler name-to-file resolution without sorting manifests."

requirements-completed: [REL-01, REL-02, REL-04]

coverage:
  - id: D1
    description: "Local release gate CLI validates synchronized versions, JSON/manifests, and reviewed state drift."
    requirement: REL-01
    verification:
      - kind: other
        ref: "python3 tools/check_release_gates.py"
        status: pass
      - kind: other
        ref: "python3 tools/check_release_gates.py --check versions"
        status: pass
    human_judgment: false
  - id: D2
    description: "Manifest parity baseline is clean after removing duplicate IH alias source and fixing Two Handed trigger names."
    requirement: REL-02
    verification:
      - kind: other
        ref: "python3 tools/check_release_gates.py --check manifests"
        status: pass
      - kind: other
        ref: "test ! -e src/aliases/boop/Targeting/Boop_IH.lua && test -f src/aliases/boop/Targeting/IH.lua"
        status: pass
    human_judgment: false
  - id: D3
    description: "Known flat-state access is explicitly baselined and fails when new access is introduced."
    requirement: REL-04
    verification:
      - kind: other
        ref: "python3 tools/check_release_gates.py --check state-drift"
        status: pass
      - kind: other
        ref: "temporary boop.state.currentTargetId probe caused --check state-drift to fail, then recovery passed"
        status: pass
    human_judgment: false

duration: 22 min
completed: 2026-07-09
status: complete
---

# Phase 01 Plan 01: Release Gate Baseline Summary

**Python stdlib release gates now block version drift, manifest/file drift, and unreviewed flat-state drift against a passing current baseline.**

## Performance

- **Duration:** 22 min
- **Started:** 2026-07-09T20:57:00Z
- **Completed:** 2026-07-09T21:19:00Z
- **Tasks:** 3
- **Files modified:** 6

## Accomplishments

- Added `tools/check_release_gates.py` with `--check versions`, `--check manifests`, and `--check state-drift`.
- Repaired current manifest parity by deleting orphan `Boop_IH.lua` and renaming Two Handed trigger manifest entries to match existing Lua files.
- Added an explicit reviewed flat-state baseline for `boop_events.lua`, `boop_walk.lua`, and `boop_attacks.lua`.

## Task Commits

1. **Tasks 1-3: release gate checker, manifest baseline repair, version sync** - `d725564` (feat)

**Plan metadata:** pending in this commit.

## Files Created/Modified

- `tools/check_release_gates.py` - Local release gate CLI.
- `src/triggers/boop/Shield/Weaponmastery_Two_Handed/triggers.json` - Manifest names now map to existing Lua files.
- `src/aliases/boop/Targeting/Boop_IH.lua` - Removed duplicate orphan alias adapter.
- `mfile` - Version synchronized for the implementation commit.
- `src/scripts/boop/boop_init.lua` - Version synchronized for the implementation commit.
- `CODEX.md` - Version checkpoint synchronized for the implementation commit.

## Decisions Made

- Used Python stdlib rather than adding package dependencies.
- Kept manifest order unchanged and fixed the current baseline instead of adding broad orphan exclusions.
- Used symbol-count state-drift baselines to catch both new flat-state access and intentional cleanup that needs baseline review.

## Deviations from Plan

### Auto-fixed Issues

None.

---

**Total deviations:** 0 auto-fixed.
**Impact on plan:** The implementation content matches the plan. The planned tasks were committed together so the repository's synchronized-version rule could be satisfied cleanly for the production change.

## Issues Encountered

None. Negative checks confirmed the version gate and state-drift gate fail on intentional temporary drift, then pass after restoration.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

Ready for Plan 02 to wire `python3 tools/check_release_gates.py` into GitHub Actions and document the local command surface.

---
*Phase: 01-release-gates-and-state-contracts*
*Completed: 2026-07-09*
