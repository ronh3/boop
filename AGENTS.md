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
| `independent_review`, `independent_review_target_sha` | Claude only, citing its append-only review entry and exact reviewed/correction SHA. `independent_review_target_sha` is the exact full SHA most recently independently reviewed and is the authoritative merge-coverage anchor. The Phase 00.1 initialization is a one-time human-authorized Codex transcription; after it, only Claude may advance it. |
| `human_arbitration` | Human only, citing the dated arbitration entry in the review artifact |
| `live_mudlet_validation` | Human only, citing the phase UAT decision/result |
| `phase_closure` | Human only, citing the exact accepted SHA and closure decision in UAT |
| `merge_authorization` | Human explicitly authorizes an exact full SHA outside the commit tree; Codex mechanically records it as the required annotated approval tag. The tag, not a later STATE or UAT entry, is final authorization evidence. |

Other actors must not advance, reset, or clear another writer's gate. Codex may
initialize a new phase's gates as pending; it may not infer human or Claude
approval. Protected gate decisions must include attribution and evidence, not
just a bare `complete` value. Structural/milestone changes require human scope
authority. This is a role contract; Git author names do not authenticate a human.

On a human-authorized active-phase transition, the prior phase's
`independent_review` and `independent_review_target_sha` do not carry forward.
The new phase begins with `independent_review: pending` and
`independent_review_target_sha: null`, together with the required pending human,
live, closure, and merge gates. This reset is phase activation, not a Claude
review-completion transition. Within the same active phase, review-anchor
changes remain Claude-owned and the anchor may not be cleared to null.

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
- Human arbitration, live applicability and required live results, and phase
  closure remain recorded in UAT (and referenced by STATE). After every mutation,
  review/correction, arbitration, required live validation, closure decision, and
  exact-SHA CI result is complete, the human explicitly authorizes the final
  immutable full phase HEAD **outside** the commit tree. Codex then mechanically
  creates an annotated tag named
  `phase-<phase>-approved-<12-char-commit-sha>` that targets that exact commit.
  Its message records human authorization, date, phase, and the full authorized
  SHA. The Phase 00 `phase-00-approved` tag is a historical exception: never
  rename, move, or delete it.
- Approval tags are immutable evidence once pushed: never force-move, replace,
  or delete one during normal workflow. Before authorization or merge, run
  `python3 tools/check_merge_authorization.py --phase <phase>`: it checks the
  reviewed closure tail and that the newest valid annotated approval tag binds
  its name, phase, full annotation SHA, peeled commit, local/remote tag object,
  and local/remote phase head. The approval-tag GitHub Actions workflow must
  also succeed before `main` may be fast-forwarded. Git identity does **not**
  authenticate human intent; this check records and binds the human
  role-contract event mechanically, but does not prove it cryptographically.
  Server-side signed tags and protected tag rules are optional future
  defense-in-depth, not a present acceptance gate. Only the peeled commit
  targeted by the newest valid approval tag may fast-forward `main`; do not
  create an unreviewed merge or squash commit. Immediately before the
  fast-forward, verify local phase HEAD, origin phase HEAD, the human-authorized
  full SHA, and the peeled approval-tag commit are identical. If the branch
  changes after authorization, repeat the affected gates and obtain a new
  explicit authorization and new tag; older tags remain historical evidence and
  cannot authorize the changed branch. After the fast-forward, verify
  `main == origin/main ==` the authorized tagged commit.
  Before exact-SHA authorization, the candidate must be covered by the latest
  Claude-owned `independent_review_target_sha`. A candidate may follow that SHA
  only through the mechanically permitted closure tail. Any later mutation to
  source, tests, workflow implementation, authority documents, architecture,
  active context, ROADMAP, package/version metadata, or another non-permitted
  path invalidates review coverage and requires a Claude review or re-review.
  No in-tree bookkeeping commit follows authorization, because it would create a
  new SHA and invalidate the authorization.
- Record reviewed/correction SHAs in the review artifact; human arbitration,
  live, and closure decisions in UAT; and CI run ID, attempt, URL, event, branch,
  and head SHA in VERIFICATION. STATE may show an external authorization as
  pending/required before the tag exists, but cannot substitute for the tag. A
  branch name or green CI result alone is not phase acceptance.

## Agent Handoff Mailboxes

`.planning/CODEX-NEXT.md` and `.planning/CLAUDE-NEXT.md` are reusable execution
handoffs, not authority or evidence artifacts. Their precedence is strictly:

```text
requirements / active specification
  -> architecture
  -> workflow / role authority
  -> STATE
  -> review / evidence constraints
  -> handoff instruction
```

A handoff may narrow or execute already-authorized work, but never override
AGENTS, requirements, active context, architecture, role boundaries, human-only
gates, Claude-only review ownership, or version/release gates. Only Human +
ChatGPT/Neon under human direction may assign a new handoff. Codex and Claude
must not rewrite their own handoff to grant scope. Updating a handoff does not
execute it; the human remains the trigger. Mailboxes are deliberately mutable;
their history is ordinary Git history, not append-only evidence.

At its completion boundary, the executing agent is required and permitted to
change only its own mailbox `status: ready` to `status: consumed`. It must not
change any other frontmatter value or any body byte during retirement. A
consumed mailbox may become `ready` only as a fresh Human + ChatGPT/Neon
assignment: its new review target must be a full, resolving HEAD-ancestor SHA,
must differ from both the consumed handoff target and the current
`independent_review_target_sha`, and the resulting handoff must pass all normal
ready-handoff checks. That fresh assignment may replace assignment fields and
body; a consumed-to-consumed mutation and a status-only replay are forbidden.
Only Human + ChatGPT/Neon under human direction may assign or reassign a ready
handoff; the repository checks structurally contain, but cannot authenticate,
that role contract.

Both files use this stable format:

```yaml
---
handoff_version: 1
status: idle | ready | consumed
agent: codex | claude
mode: active_phase | phase_bootstrap | null when idle
branch: <branch or null when idle>
task_base_sha: <full SHA or null when idle>
review_target_sha: <full SHA or null>
assigned_by: Human + ChatGPT/Neon
---
```

Their body contains `# Objective`, `# Required Inputs`, `# Task`,
`# Constraints`, `# Verification`, and `# Completion Boundary`. An `idle`
handoff has no executable task and its `mode`, `branch`, `task_base_sha`, and
`review_target_sha` are all null. A `consumed` handoff preserves its assignment
provenance but authorizes no execution. `task_base_sha` is the known pre-delivery
repository boundary; it never claims to be the SHA of the handoff-delivery
commit itself.

When told to run a ready handoff, the named agent's first executable action is
`python3 tools/check_handoff_execution.py --agent <codex|claude> --fetch` and it
must stop if that helper fails. The helper fetches origin/tags, verifies branch
and remote parity, SHA resolution/ancestry, and the pre-execution range. Codex still
performs normal startup reads; it cannot use a handoff to work on main, close a
phase, merge, arbitrate, decide live applicability, or self-accept Claude
findings. Claude still reads `CLAUDE.md` and normal authorities first and may
only perform its reviewer role; a handoff can name review/correction SHAs,
finding IDs, questions, evidence, and a stop boundary, never permission to edit
implementation or human-owned gates.

The release `workflow` gate parses both mailboxes with their exact known schema.
It requires ready/consumed task bases to resolve to HEAD ancestors, requires a
Claude review target, allows Claude only `active_phase`, and requires a ready
active-phase handoff's branch to match STATE. It cannot authenticate the human
assigner or execute a handoff.

For Claude review completion, a changed `independent_review_target_sha` must be
part of one constrained review-completion transition: the new full SHA resolves
and is an ancestor of the review commit; only STATE, the current append-only
adversarial-review artifact, and CLAUDE-NEXT may change; only Claude-owned
review fields may change in STATE; and the matching ready Claude handoff must be
retired unchanged except for `ready -> consumed`, with its `review_target_sha`
equal to the new anchor. A ready Claude handoff whose target already equals the
current anchor is a rejected replay. These checks structurally contain the role
contract; they do not cryptographically authenticate Claude.

`phase_bootstrap` is Codex-only. It permits a human-authorized new branch from
the named exact `origin/main` `task_base_sha` to carry its delivery handoff while
STATE still describes the completed prior phase. The handoff must name the new
branch, authorized phase identifier/name, exact base, and bootstrap scope. Codex
first proves the branch fork point equals that base and later commits are only
the expected handoff-delivery planning change, then creates or updates the new
context and STATE before any normal work. This exception never supplies missing
human authority for a structural phase transition. The staged workflow gate
permits that one delivery boundary only when the staged change is exactly
`.planning/CODEX-NEXT.md`, HEAD still equals `origin/main`, and `task_base_sha`
equals that same commit; after it commits, ordinary branch/state invariants
resume until the first bootstrap execution commit updates CONTEXT and STATE.

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
