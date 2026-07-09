# Phase 1: Release Gates and State Contracts - Context

**Gathered:** 2026-07-09
**Status:** Ready for planning

<domain>
## Phase Boundary

This phase delivers deterministic release and regression gates for the existing boop Hunter codebase. It should make CI and local preflight checks catch version drift, malformed package metadata/manifests, manifest/file mismatch, and high-risk state-contract regressions before later behavior hardening begins.

This phase does not fix the known room, pull, flee, gold, autowalk, or gag behavior defects. Those behavior repairs belong to later roadmap phases. Phase 1 may add tests and checks that prove current safe contracts, but its committed gate set must pass on the current codebase when the phase completes.

</domain>

<decisions>
## Implementation Decisions

### Gate Strictness
- **D-01:** All deterministic gates added in Phase 1 should block CI when they fail.
- **D-02:** Deterministic gates include version synchronization, JSON validity, manifest parity, and state-contract regression checks.
- **D-03:** Phase 1 gates must establish a passing baseline on the current codebase. Known defects that require behavior changes should be documented and left for the appropriate later phase, not introduced as permanently failing CI in Phase 1.
- **D-04:** The same checks should be reusable locally, not only embedded in GitHub Actions. Prefer local scripts or test commands that CI calls directly.
- **D-05:** Phase 1 should keep CI dependency-risk cleanup minimal. Broad pinning of Muddler, test-in-Mudlet, actions, or LuaRocks dependencies is out of scope unless it is directly necessary for the new deterministic gates or is a low-risk supporting cleanup.

### the agent's Discretion
- The planner may choose the exact script names, test file names, and CI step placement, provided the checks are deterministic, pass on the current codebase, and can be run locally.
- The planner may decide whether a specific gate is best implemented as shell, Lua/Busted, or a small helper script, based on the existing test/build patterns.
- The planner may leave known behavior defects as documented follow-up evidence for later phases when making a Phase 1 gate pass would otherwise require behavior fixes.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Project Scope
- `.planning/PROJECT.md` — Defines the brownfield pre-1.0 hardening goal, core value, active requirements, and out-of-scope boundaries.
- `.planning/REQUIREMENTS.md` — Defines Phase 1 requirements `REL-01`, `REL-02`, and `REL-04`.
- `.planning/ROADMAP.md` — Defines Phase 1 goal, dependencies, success criteria, and phase ordering.
- `.planning/STATE.md` — Current project state and Phase 1 focus.

### Research And Codebase Intel
- `.planning/research/SUMMARY.md` — Research-backed roadmap implications; Phase 1 is release gates and state contracts.
- `.planning/codebase/STACK.md` — Current build/runtime/tooling stack and existing CI dependencies.
- `.planning/codebase/TESTING.md` — Existing Busted-in-Mudlet test patterns and local/CI test structure.
- `.planning/codebase/ARCHITECTURE.md` — Runtime state domains, package manifests, and load-order-sensitive architecture.
- `.planning/codebase/INTEGRATIONS.md` — CI, Muddler, Mudlet, GMCP, and external dependency integration points.
- `.planning/codebase/CONCERNS.md` — Known version-sync, manifest-parity, state-domain, and CI dependency risks that Phase 1 should address or intentionally defer.

### Repo Workflow
- `AGENTS.md` — Repository-local startup, versioning, and workflow rules.
- `CODEX.md` — Detailed Codex workflow guidance, current package version checkpoint, and release-hardening context.
- `.github/workflows/main.yml` — Existing GitHub Actions build/test pipeline that Phase 1 gates should integrate with.
- `tools/sort_manifests.sh` — Existing manifest maintenance helper; note that `src/scripts/boop/scripts.json` is intentionally load-order sensitive.
- `tests/README.md` — Existing test inventory and guidance for extending the suite.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `.github/workflows/main.yml`: Existing CI already reads `mfile`, builds with Muddler, imports the package into Mudlet, runs Busted, uploads artifacts/logs, and comments on PRs.
- `tests/support/boop_test_helper.lua`: Shared reset/fixture surface for Busted specs inside Mudlet.
- `tests/*_spec.lua`: Existing behavior and contract spec patterns for runtime, UI, DB, targeting, attacks, rage, gags, stats, and regressions.
- `tools/sort_manifests.sh`: Existing JSON manifest helper that can inform or complement a manifest-parity check.

### Established Patterns
- Tests use Busted assertions and helper-seeded Mudlet/GMCP state.
- Mudlet side effects are mocked with Busted stubs for unit-style specs.
- Package content lives under `src/`; generated artifacts are not edited.
- `src/scripts/boop/scripts.json` is intentionally not auto-sorted because load order is runtime-sensitive.
- Version fields must remain synchronized across `mfile.version`, `mfile.title`, `src/scripts/boop/boop_init.lua` `boop.version`, and the `CODEX.md` checkpoint on every commit and push.

### Integration Points
- Add local checks in a reusable script or test command, then call that same command from `.github/workflows/main.yml`.
- Manifest parity should inspect `src/scripts/`, `src/aliases/`, and `src/triggers/` manifests without changing their ordering.
- State-contract tests should target current owned-domain invariants without requiring Phase 2 behavior fixes.

</code_context>

<specifics>
## Specific Ideas

- Treat deterministic gate failures as blockers, not warnings.
- Keep Phase 1 green on current code by separating current-contract checks from known future behavior fixes.
- Prefer checks that a maintainer can run locally before pushing.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within Phase 1 scope.

</deferred>

---

*Phase: 1-Release Gates and State Contracts*
*Context gathered: 2026-07-09*
