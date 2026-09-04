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
