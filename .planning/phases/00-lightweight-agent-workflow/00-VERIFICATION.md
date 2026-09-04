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


## Final corrective pass — Codex, 2026-09-04

Starting SHA: `5b4417be62e31800e4f348d14a1948ce95f46112`. Its completed
CI identity was independently fetched for this boundary: [33925663133](https://github.com/ronh3/boop/actions/runs/33925663133),
attempt 1, `main.yml`, `push`, `phase/00-lightweight-agent-workflow`, exact
head SHA `5b4417be62e31800e4f348d14a1948ce95f46112`, conclusion `success`.
This historical result does not certify the following correction.

N-01/N-02/N-03 correction scope: trusted origin/main ancestry for the phase
baseline; append-preserving UAT/VERIFICATION history; ignored Python bytecode.
The correction containing this entry synchronizes version `0.1.496.5`.

Local automated results:

- `python3 tools/check_release_gates.py`: all six gates pass (versions,
  version-bump, workflow, manifests, state-drift, architecture).
- `python3 tests/test_workflow_gates.py`: **30 tests pass**, including 11 new
  adversarial tests for legitimate/invalid baselines, absent authoritative main,
  retained HEAD ancestry, concealed version/review violations, UAT and verification
  rewriting/deletion/restoration, synthetic decision replacement, dated appends,
  and empty-artifact deletion. Existing five fake-CI tests also pass.
- `python3 tests/test_architecture_guard.py`: **25 tests pass**; unchanged
  25 modules / 141 edges, sole composition root `boop_bootstrap`.
- `bash -n tools/wait_for_exact_ci.sh` and `git diff --check`: pass.
- `git check-ignore tools/__pycache__/*.pyc`: both generated guard caches
  are ignored; `git status --short --untracked-files=all` has only intended edits.

No local full-Mudlet substitute is claimed. The correction SHA, staged release
gate, fresh-checkout cleanliness and completed CI/build/Busted evidence will be
appended at the next evidence boundary, followed by a new final-tip CI gate
reported in handoff under A-5. Earlier entries and placeholders above stay
unchanged under A-2; all future verification evidence is appended with attribution
and date. Neither automated verification nor policy arbitration closes Phase 00.


## Completed final correction boundary — Codex, 2026-09-04

Correction SHA: `887a4ff64292ed784dd8f48d4c3c03f8bd20f632`
(`fix(workflow): protect baseline and phase evidence history`).

- Exact-SHA CI: [33926389525](https://github.com/ronh3/boop/actions/runs/33926389525),
  attempt **1**, workflow `main.yml`, event `push`, branch
  `phase/00-lightweight-agent-workflow`, exact head SHA
  `887a4ff64292ed784dd8f48d4c3c03f8bd20f632`, conclusion **success**.
- Staged-path classification: package-affecting; all four checkpoints advance
  from `0.1.496.4` to `0.1.496.5`. Staged and pre-push release gates: all six pass.
- Local and CI suites: **30 workflow tests pass; 25 architecture tests pass**.
  The live CI checkout also supplies origin/main successfully for the new guard.
- Muddler build and upload succeed at version `0.1.496.5`; package artifact ID
  `9957019192`. No generated artifacts are tracked or edited.
- Real-Mudlet Busted execution and the subsequent failure-marker check pass.
  The captured test-step log contains **1006 leading `+` success progress
  markers**, with no leading failure/error markers. It does **not** contain a
  final success/failure/error/pending totals line, so this record does not
  invent that summary or borrow totals from an earlier run. This logging limit
  is supplied for Claude re-review; CI itself concludes success.
- N-03 fresh-checkout reproduction: a temporary full-history `git clone
  --no-local` of this exact correction starts clean with no Python caches.
  Running `python3 tools/check_release_gates.py` passes all six checks, creates
  two ignored `tools/__pycache__/*.pyc` files, and leaves
  `git status --porcelain --untracked-files=all` empty, without cache cleanup.
  The actual source checkout also stays clean after its pre-push Python gate,
  phase push and exact-SHA CI gate.
- The exact-CI script rechecks local HEAD, branch, clean worktree and the exact
  remote phase ref after watching. All checks pass with caches retained.
- A-1 through A-7 are present verbatim in the dated human-policy appendix.
  All three pre-existing review/UAT/verification artifacts are unchanged byte
  prefixes; STATE is byte-identical to starting SHA `5b4417be…`.
- CI used the cached Mudlet runtime; download and PR-comment steps were skipped.
  Existing dependency deprecation annotations did not fail the run.

This independently needed evidence boundary records the known correction SHA,
completed CI identity, and fresh-checkout results. It changes only `.planning/`
and preserves version `0.1.496.5`. Its new final HEAD needs its own push and
exact-SHA gate; that final run identity will be reported in handoff without a
further bookkeeping commit, under A-5. No finding is closed by Codex.
