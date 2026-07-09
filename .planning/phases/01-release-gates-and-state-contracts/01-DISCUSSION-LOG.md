# Phase 1: Release Gates and State Contracts - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-07-09
**Phase:** 1-Release Gates and State Contracts
**Areas discussed:** Gate Strictness

---

## Gate Strictness

| Option | Description | Selected |
|--------|-------------|----------|
| All deterministic gates block | Version sync, JSON validity, manifest parity, and state-contract regressions fail CI. | ✓ |
| Only package-breaking gates block | Version sync, JSON validity, and manifest parity fail CI; state-contract tests can be added but not required yet. | |
| Version sync first | Only version sync fails CI in Phase 1; other gates are warnings or later work. | |
| Other | User-defined blocking policy. | |

**User's choice:** All deterministic gates block CI.
**Notes:** The user selected the strictest deterministic gate posture for Phase 1.

---

## Known Existing Defects Policy

| Option | Description | Selected |
|--------|-------------|----------|
| Block only after a passing baseline | Phase 1 adds gates that pass on current code, then Phase 2 tightens/fixes behavior. | ✓ |
| Allow failing tests now | Phase 1 may add red tests for known defects, making CI fail until Phase 2 fixes them. | |
| Quarantine known failures | Add pending/skipped tests documenting known defects, then unskip in Phase 2. | |
| Other | User-defined policy. | |

**User's choice:** Block only after a passing baseline.
**Notes:** Phase 1 should not leave CI red for defects intentionally assigned to later phases.

---

## Gate Placement

| Option | Description | Selected |
|--------|-------------|----------|
| CI plus local scripts | Add CI steps and reusable local test/scripts so maintainers can run the same checks before committing. | ✓ |
| CI only | Keep Phase 1 focused on GitHub Actions enforcement; local use is optional/manual. | |
| Busted only where possible | Prefer Lua specs inside Mudlet; use shell/CI checks only where Busted cannot inspect. | |
| Other | User-defined split. | |

**User's choice:** CI plus local scripts.
**Notes:** Checks should be reusable locally and called by CI.

---

## CI Dependency Risk Boundary

| Option | Description | Selected |
|--------|-------------|----------|
| Minimal risk cleanup | Scope only what supports deterministic gates; no broad pinning pass yet. | ✓ |
| Pin major moving parts now | Pin Muddler/test-in-Mudlet/actions where practical as part of Phase 1. | |
| Defer dependency pinning | Do not touch CI dependencies in Phase 1 unless needed for the new gates. | |
| Other | User-defined boundary. | |

**User's choice:** Minimal risk cleanup.
**Notes:** Broad dependency pinning is out of scope unless necessary or low-risk for the new deterministic gates.

---

## the agent's Discretion

- Planner may choose exact check implementation details, provided the gates are deterministic, pass on current code, and are runnable locally.
- Planner may defer known behavior defects to later phases rather than creating a red CI baseline in Phase 1.

## Deferred Ideas

None.
