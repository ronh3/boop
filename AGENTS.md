# AGENTS.md

Repository-local authority, workflow, and safety rules for every human or agent
working on Boop.

## Roles And Authority

- **Human + ChatGPT/Neon** own requirements, architecture, scope, arbitration,
  and acceptance decisions. Only the human may authorize phase closure or a
  merge to `main`.
- **Codex** is the primary implementation agent. Codex may change source,
  tests, documentation, and Git state when instructed, but may not declare a
  phase live-accepted or complete.
- **Claude** is the independent adversarial reviewer. In every review pass,
  Claude must not edit implementation source, tests, or implementation docs.
  Claude may only append to the designated adversarial-review artifact and
  update its own `independent_review` gate in `STATE.md` with that evidence.
- **Mudlet** is the final authority for live runtime behavior. Host tests and
  CI support a decision; they do not substitute for required live Mudlet
  validation.

The authority order is:

```text
requirements / active specification
  -> architecture
  -> implementation
  -> automated verification
  -> independent adversarial review
  -> corrections
  -> human arbitration
  -> human determination of live applicability and required Mudlet validation
  -> phase closure
```

A later stage may validate or challenge an earlier one, but it may not silently
redefine it. Ambiguities and conflicts return to the human for arbitration.

## Durable Artifacts

Use the existing authoritative artifact for each purpose. Do not create a
parallel ADR, status file, review log, or specification when one of these fits.

| Purpose | Authoritative artifact |
|---|---|
| Milestone requirements | `.planning/REQUIREMENTS.md` |
| Active phase specification and fixed scope | `.planning/phases/<NN>-<slug>/<NN>-CONTEXT.md` |
| Milestone sequencing and phase namespace index | `.planning/ROADMAP.md` |
| Refactor sequence and historical refactor phase numbers | `REFACTOR-ROADMAP.md`; activated only by the current phase context |
| Current phase, branch, gate, and handoff state | `.planning/STATE.md` |
| Current architecture and ownership | `ARCHITECTURE.md` |
| Mandatory architecture invariants | `ARCHITECTURE-RULES.md` |
| Approved target architecture | `TARGET-ARCHITECTURE.md` |
| Durable product/scope decisions | `.planning/PROJECT.md` `Key Decisions` |
| Automated verification | the phase's `<NN>-VERIFICATION.md`, tests, release gates, and exact-SHA CI |
| Independent findings and disposition | the phase's single `<NN>-ADVERSARIAL-REVIEW.md` |
| Human-directed live acceptance | the phase's `<NN>-UAT.md` |

`<NN>-PLAN.md` and `<NN>-SUMMARY.md` files are execution records subordinate to
the requirements, active context, and architecture. Existing `.planning`
history and legacy tooling metadata are provenance only; no orchestration
framework has authority over this workflow. The retired configuration is kept
byte-for-byte at `.planning/legacy-gsd-config.json.provenance`; it must not be
loaded as configuration or restored to `.planning/config.json`. Historical
plans, validation instructions, research, and codebase maps cannot activate
legacy commands or override this contract in any phase.

The adversarial-review artifact is append-only after a review is recorded. No
actor may rewrite or delete an existing finding's ID, severity, text, or prior
entries. Append dated, attributed proposals, corrections, re-reviews, and human
arbitration as separate entries. Claude owns initial findings. Codex may propose
ACCEPT, PARTIALLY ACCEPT, or REJECT and supply evidence, but may not mark any
finding finally accepted, resolved, or closed. Claude may establish factual
closure only by a recorded re-review of a named correction SHA; the human may
arbitrate a finding explicitly. Neither action alone closes a phase.

Phase `*-UAT.md` and `*-VERIFICATION.md` artifacts are append-only from
creation. Preserve all existing content, including pending scaffolds, as an
unchanged prefix. Human decisions and new or corrected evidence must be appended
as dated, attributed entries; never rewrite, remove, or replace prior entries or
placeholders. The workflow guard checks all three artifact types across phase
history, every merge parent, and the staged snapshot. Prefix preservation cannot
authenticate the author of a new entry; the role contract still applies.

## State Writers And Live Authority

`STATE.md` frontmatter is the canonical current coordination record. Its
`main_baseline` is the immutable branch-start SHA for the active phase; prose
and context reference it rather than maintain another live copy. Historical
review and verification SHAs remain immutable evidence for their own boundaries.
The history guards require this baseline to be an ancestor of both phase HEAD
and `refs/remotes/origin/main`. That remote-tracking main ref and its full history
must be available (fetch origin before verification); local `main` is not a
fallback authority. A commit reachable only from the phase cannot set the
coverage boundary, and callers cannot override the declared baseline.

| Fields | Authorized writer and evidence |
|---|---|
| `status`, `active_phase`, `active_phase_name`, `active_branch`, `active_specification`, `main_baseline`, `last_updated` | Codex may record factual coordination within human-authorized scope; no status value grants acceptance |
| `independent_review` | Claude only, citing its append-only review entry and exact reviewed/correction SHA |
| `human_arbitration` | Human only, citing the dated arbitration entry in the review artifact |
| `live_mudlet_validation` | Human only, citing the phase UAT decision/result |
| `phase_closure` | Human only, citing the exact accepted SHA and closure decision in UAT |
| `merge_authorization` | Human only, naming the exact full SHA and dated authorization in UAT |

Other actors must not advance, reset, or clear another writer's gate. Codex may
initialize a new phase's gates as pending; it may not infer human or Claude
approval. Protected gate decisions must include attribution and evidence, not
just a bare `complete` value. Structural/milestone changes require human scope
authority. This is a role contract; Git author names do not authenticate a human.

For every phase, whether live Mudlet validation is required is a human decision
recorded in `<NN>-UAT.md` with date, rationale, and applicable SHA. The human
records `required`, `not_applicable`, or a validation result there and updates
the corresponding state gate. Codex and Claude may supply technical evidence
but may not make that determination or mark live testing passed. Until then,
`pending_human_determination` is an unsatisfied gate. Required live tests must
pass in Mudlet before human closure; automated Mudlet Busted is separate evidence.

## Phase And Git Workflow

- From Phase 00 forward, additions to `main` require independent review, human
  arbitration/authorization, and the human-recorded live applicability decision
  plus any required Mudlet validation. The pre-workflow baseline named in the
  Phase 00 state is inherited history, not retroactively certified by this rule.
- Active work occurs on `phase/<number>-<short-description>`, created from the
  current `origin/main`. The matching context file and `.planning/STATE.md`
  must name that branch. No work may be committed directly to `main`, including
  quick fixes, hotfixes, docs, or planning. Those tasks use an authorized phase
  branch and the same review/acceptance gates; they are not exceptions.
- Push phase branches to `origin` at meaningful specification,
  implementation, review, and correction boundaries so every agent reviews the
  same commit.
- Commit coherent boundaries, not every trivial edit. Review-artifact-only and
  correction commits should remain distinguishable from the implementation
  commit they assess.
- Never rebase or force-push a published phase branch without explicit human
  approval. Incorporate concurrent remote work with the safest non-rewriting
  method and escalate genuine conflicts.
- Human merge authorization must name the exact full commit SHA after review,
  arbitration, and the live gate. Only that SHA may land on `main` by fast-forward;
  do not create an unreviewed merge/squash commit. A later branch-tip change
  invalidates authorization. Immediately before merging, verify the authorized
  SHA equals local and remote phase HEAD and passed exact-SHA CI. If main cannot
  fast-forward, integrate on the phase branch, then repeat the affected gates
  and obtain new exact-SHA authorization.
- Record reviewed/correction SHAs in the review artifact, human live/closure
  and merge decisions in UAT, and CI run ID, attempt, URL, event, branch, and
  head SHA in VERIFICATION. STATE references those authorities; a branch name
  or green CI result alone is not phase acceptance.

## Session Startup

- Read `.planning/STATE.md`, then the active phase context it names, before
  changing anything. If they disagree with the checked-out branch or Git
  state, stop and report the mismatch.
- Read `README.md` and `DESIGN.md` to understand current scope and user-facing
  behavior.
- Read `ARCHITECTURE.md` for how Boop works today, and
  `ARCHITECTURE-RULES.md` before changing module boundaries.
- Read `UIDESIGN.md` when doing UI or UX work.
- Read `CODEX.md` for repository build, testing, version, and continuity
  guidance.
- Check Git status, upstream divergence, and all version fields before making
  changes.

## Versioning Rule

- Classify a commit from its staged paths before committing.
- A planning-only commit has every staged path under `.planning/`.
  Planning-only commits do not bump the package version.
- Any commit with a staged path outside `.planning/` is package-affecting and
  must monotonically bump all Boop version fields together:
  - `mfile.version`
  - `mfile.title` to `boop Hunter <version>`
  - `src/scripts/boop/boop_init.lua` `boop.version`
  - the `CODEX.md` current synchronized package-version checkpoint
- Never leave those fields mismatched.
- Before committing or pushing, inspect staged paths and run
  `python3 tools/check_release_gates.py`. The `version-bump` gate checks every
  commit since the phase baseline against its parent and checks the staged
  snapshot against HEAD. CI must fetch full history. Planning-only commits
  preserve versions; every package-affecting commit increases the numeric
  version. Fast-forwarding an already checked commit creates no new commit.

## Verification And Terminal CI

- Automated verification must match the risk and acceptance criteria in the
  active specification. Behavior changes need focused tests plus the relevant
  regression suite.
- After all repository mutations for a boundary are complete, Codex pushes the
  immutable final HEAD and runs `tools/wait_for_exact_ci.sh`.
- The exact-SHA CI gate is blocking automated evidence. Commit completed run
  identifiers and summaries in `<NN>-VERIFICATION.md` at the next evidence or
  review boundary; keep raw CI logs/artifacts in GitHub Actions. An identifier
  always describes its named SHA, never a later evidence commit. After that
  commit, push and gate the new final HEAD and report its run identity in the
  handoff without another bookkeeping commit. The next independently needed
  boundary can preserve that identity. Every later mutation requires a new
  final gate; a successful earlier run remains historical evidence only.
- Successful automated verification does not authorize live acceptance, phase
  closure, or merge to `main`.

## Repository Discipline

- Work only under `src/` for package content; never edit built artifacts.
- Keep user-facing docs and command help in sync with command-surface changes.
- Prefer polish, consistency, operator clarity, and stability over feature
  expansion.
