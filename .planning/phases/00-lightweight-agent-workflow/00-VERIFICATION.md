# Phase 00 — Automated verification

Writer: Codex. Automated evidence only; awaiting Claude re-review and human
arbitration. Live applicability and acceptance remain in `00-UAT.md`.

## Scope and boundaries

- Original implementation reviewed by Claude:
  `44fb844fe2aadf9d71fd7aa95736f3f336e3af72`.
- Original review commit: `9b47f6409a3ba6e75ff575baafe3020d03a7622a`.
- Corrective implementation: the package-affecting commit introducing this
  document; exact SHA will be appended after commit.
- Package checkpoints: synchronized at `0.1.496.4`.
- Product-source diff: only `boop.version`; gameplay remains unchanged.

## Local automated checks (2026-09-04)

- `python3 tools/check_release_gates.py`: versions, per-commit/staged version
  bumps, workflow/review preservation, manifests, state drift, and architecture.
- `python3 tests/test_workflow_gates.py`: 19 tests pass. Temporary Git histories
  cover omitted/decreasing/unsynchronized version bumps, numeric comparison,
  staged versus unstaged snapshots, renames/deletions, missing ancestry, prior
  violations hidden by later repairs, review rewrite/deletion, branch restrictions,
  and retired configuration. A fake CI service exercises push selection,
  failure handling, rechecked identity, clean-tree and exact remote-ref checks.
- `bash -n tools/wait_for_exact_ci.sh` and `git diff --check`: pass.
- `python3 tests/test_architecture_guard.py`: 25 tests pass; current architecture
  stays at 25 modules / 141 edges with `boop_bootstrap` as sole composition root.
- Final staged release gate: results appended at the correction evidence boundary.
- Full automated Lua/Busted suite and Muddler build: use GitHub Actions;
  `/tmp/Mudlet.AppImage` is unavailable locally. No host substitute is claimed.

## Durable CI identities

| Boundary | Workflow/event/branch | Exact head SHA | Run / attempt | Result |
|---|---|---|---|---|
| Original implementation; independently re-fetched 2026-09-04 | `main.yml` / `push` / `phase/00-lightweight-agent-workflow` | `44fb844fe2aadf9d71fd7aa95736f3f336e3af72` | [33915198772](https://github.com/ronh3/boop/actions/runs/33915198772) / 1 | success |

Each identity certifies only its named SHA. A following evidence commit needs
its own pushed exact-SHA gate. Report the final run ID/attempt/URL/head SHA in
the handoff without another self-referential bookkeeping commit; the next
independently needed review/evidence boundary can preserve that identity here.
Raw logs/artifacts remain in Actions. Infrastructure failures can use
`gh run rerun RUN_ID --failed` without changing HEAD, followed by the gate.

## Limits

These checks cannot authenticate human or reviewer identities, protect remote
main against a privileged bypass, or infer gate approval from Git author names.
The local staged-branch check is not a server-side branch protection rule. CI
checks full phase history but does not retrospectively certify the inherited
pre-workflow baseline. Role/acceptance decisions require the attributed evidence
specified in AGENTS. The exact push run is the terminal automated gate; PR runs
are additional branch-head evidence, not synthetic-merge acceptance.

## Correction boundary evidence — 2026-09-04

- Correction SHA: `7f8a35b27f10654b09d039cb62d3a50f0154ad1a`.
- CI run: [33924081942](https://github.com/ronh3/boop/actions/runs/33924081942),
  attempt 1; workflow `main.yml`; event `push`; branch
  `phase/00-lightweight-agent-workflow`; head SHA `7f8a35b27f10654b09d039cb62d3a50f0154ad1a`.
- Exact-SHA gate: passed with clean worktree, unchanged HEAD, and the exact
  remote phase ref rechecked after watching.
- Release gates: all six pass (versions, version-bump, workflow, manifests,
  state-drift, architecture).
- Architecture analyzer: 25 tests pass locally and in CI.
- Workflow enforcement: 19 tests pass locally and in CI.
- Full real-Mudlet Busted: **1006 successes / 0 failures / 0 errors / 0 pending**.
- Muddler build and artifact upload: success at synchronized version 0.1.496.4.
- Shell syntax and whitespace checks: pass.
- Original Claude review remains an unchanged byte prefix; retired GSD config
  is a byte-identical rename. Existing protected STATE gates are unchanged.
- Final baseline diff inspection: no gameplay/command/module-boundary changes;
  only the version assignment changes under src. No tracked build files changed.
- CI used its cached Mudlet runtime; the download path and PR-only comment step
  were not exercised. Existing dependency deprecation annotations remain; they
  did not fail CI and are outside this workflow correction scope.

This evidence entry creates a new planning-only commit and does not certify that
new commit. Push and gate that final HEAD, report its run identity, and stop.
The final evidence-only commit preserves 0.1.496.4; it grants no acceptance.

## Files changed by the corrective implementation

- Authority/startup and policy: `AGENTS.md`, `CLAUDE.md`, `CODEX.md`, `README.md`,
  `DESIGN.md`, `REFACTOR-ROADMAP.md`.
- Current planning: `.planning/STATE.md`, `.planning/ROADMAP.md`,
  `.planning/codebase/STRUCTURE.md`, and this phase’s `00-CONTEXT.md`,
  `00-ADVERSARIAL-REVIEW.md`, `00-VERIFICATION.md`, `00-UAT.md`.
- Retired configuration: `.planning/config.json` renamed without content change
  to `.planning/legacy-gsd-config.json.provenance`.
- Mechanical checks: `tools/workflow_guard.py`, `tools/check_release_gates.py`,
  `tools/wait_for_exact_ci.sh`, `tests/test_workflow_gates.py`,
  `.github/workflows/main.yml`.
- Synchronized package metadata: `mfile`, `src/scripts/boop/boop_init.lua`,
  and the CODEX checkpoint listed above.
- Local-only cleanup: removed the obsolete sed allow-list entry from ignored
  `.claude/settings.local.json`; it is not a tracked or published change.
