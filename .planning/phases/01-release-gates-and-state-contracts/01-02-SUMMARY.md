---
phase: 01-release-gates-and-state-contracts
plan: "02"
subsystem: ci
tags: [github-actions, release-gates, documentation, muddler]

requires:
  - phase: 01-release-gates-and-state-contracts
    provides: tools/check_release_gates.py
provides:
  - Blocking GitHub Actions Release gates step
  - Maintainer documentation for local static gates and full Mudlet Busted run
affects: [phase-01, release, ci]

tech-stack:
  added: []
  patterns:
    - GitHub Actions calls repo-local release gate before package metadata and Muddler

key-files:
  created: []
  modified:
    - .github/workflows/main.yml
    - CODEX.md
    - mfile
    - src/scripts/boop/boop_init.lua

key-decisions:
  - "Run release gates immediately after checkout and before Muddler or metadata-derived artifact naming."
  - "Document CI-equivalent local commands in CODEX instead of changing operator-facing README docs."

patterns-established:
  - "CI invokes the same local release gate maintainers run before push."

requirements-completed: [REL-01, REL-02]

coverage:
  - id: D1
    description: "GitHub Actions blocks on the local release gate before package metadata and Muddler build steps."
    requirement: REL-01
    verification:
      - kind: other
        ref: "python3 tools/check_release_gates.py"
        status: pass
      - kind: other
        ref: "workflow order assertion for Release gates before Read package metadata and Muddle"
        status: pass
    human_judgment: false
  - id: D2
    description: "CODEX documents local focused release-gate commands and the full Mudlet Busted path."
    requirement: REL-02
    verification:
      - kind: other
        ref: "rg CODEX.md for --check versions, --check manifests, --check state-drift, /tmp/Mudlet.AppImage"
        status: pass
    human_judgment: false

duration: 12 min
completed: 2026-07-09
status: complete
---

# Phase 01 Plan 02: CI Release Gate Summary

**GitHub Actions now runs the local release gate before package metadata, Muddler, and Mudlet test work, with matching local commands documented for maintainers.**

## Performance

- **Duration:** 12 min
- **Started:** 2026-07-09T21:20:00Z
- **Completed:** 2026-07-09T21:32:00Z
- **Tasks:** 3
- **Files modified:** 4

## Accomplishments

- Added a blocking `Release gates` workflow step immediately after checkout.
- Documented `python3 tools/check_release_gates.py` and all focused `--check` modes in `CODEX.md`.
- Documented the local full Mudlet Busted command and the CI fallback when `/tmp/Mudlet.AppImage` is unavailable.

## Task Commits

1. **Tasks 1-3: CI release gate, local docs, version sync** - `2698f60` (ci)

**Plan metadata:** pending in this commit.

## Files Created/Modified

- `.github/workflows/main.yml` - Adds blocking `Release gates` step.
- `CODEX.md` - Adds local release-gate and Mudlet Busted commands.
- `mfile` - Version synchronized for the implementation commit.
- `src/scripts/boop/boop_init.lua` - Version synchronized for the implementation commit.

## Decisions Made

- Kept the CI dependency-risk cleanup narrow by adding only the local Python gate invocation.
- Kept README unchanged because Plan 02 does not alter the operator command surface.

## Deviations from Plan

### Auto-fixed Issues

None.

---

**Total deviations:** 0 auto-fixed.
**Impact on plan:** The implementation matches the planned CI and documentation scope.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

Ready for Plan 03 to add focused Busted coverage for owned runtime state contracts.

---
*Phase: 01-release-gates-and-state-contracts*
*Completed: 2026-07-09*
