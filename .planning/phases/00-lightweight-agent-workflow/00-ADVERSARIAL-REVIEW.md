# Phase 00 Adversarial Review — Lightweight Multi-Agent Workflow

**Reviewed SHA:** `44fb844fe2aadf9d71fd7aa95736f3f336e3af72`
**Branch:** `phase/00-lightweight-agent-workflow`
**Main baseline:** `a345a34ea0da2eed6f5bfe1c5e586488749a3e22`
**Reviewer:** Claude (independent adversarial reviewer, `AGENTS.md:14-16`)
**Review date:** 2026-09-04
**Disposition:** Findings recorded only. Claude records no dispositions, no
resolutions, and no phase closure. Phase 00 is **not** declared complete.

## Review scope

Complete `main..44fb844` diff (10 files, +251/-52), plus the full current text of
`AGENTS.md`, `CODEX.md`, `README.md`, `.planning/STATE.md`, `.planning/PROJECT.md`,
`.planning/REQUIREMENTS.md`, `.planning/ROADMAP.md`, `.planning/config.json`,
`.planning/codebase/STRUCTURE.md`,
`.planning/phases/00-lightweight-agent-workflow/00-CONTEXT.md`,
`.github/workflows/main.yml`, `tools/wait_for_exact_ci.sh`, and
`tools/check_release_gates.py`. Reviewed against the Phase 00 intent: human +
ChatGPT/Neon own scope and acceptance; Codex implements but cannot declare live
acceptance or completion; Claude reviews adversarially; Mudlet is final for live
runtime behavior; `main` stays the accepted baseline; active work lives on pushed
phase branches; existing planning/review/UAT artifacts are reused; GSD artifacts
are provenance only.

Green CI was explicitly not treated as evidence that the workflow design is correct.

## Independently reproduced facts

| Check | Result |
|---|---|
| `git rev-parse origin/phase/00-lightweight-agent-workflow` | `44fb844f…` — remote matches the reviewed SHA |
| `git merge-base main HEAD` | `a345a34e…` — equals `origin/main`; branch was created from current `origin/main` as `AGENTS.md:73-75` requires |
| Commits under review | `90ab936` (docs: establish lightweight multi-agent workflow), `44fb844` (ci: verify pushed phase branches) |
| Version chain | `0.1.496.1` → `0.1.496.2` (`90ab936`) → `0.1.496.3` (`44fb844`); all four checkpoints synchronized at each step |
| `python3 tools/check_release_gates.py` at reviewed SHA | `[OK] versions`, `[OK] manifests`, `[OK] state-drift`, `[OK] architecture` |
| Exact-SHA CI | GitHub Actions `main.yml` run `33915198772`, event `push`, headBranch `phase/00-lightweight-agent-workflow`, headSha `44fb844f…`, conclusion `success` |

CI genuinely runs on pushed phase branches and the exact-SHA gate is satisfiable for
this commit. That is automated evidence only (`AGENTS.md:128-132`) and is not treated
below as validation of the workflow contract.

**Totals: 3 blocker · 6 high · 8 medium · 6 low.**

---

## Blockers

### B-01 — Codex can accept its own adversarial-review findings

- **Severity:** Blocker
- **Location:** `AGENTS.md:62-67` (specifically `:64-66`)
- **Violated invariant:** Codex is the implementation agent and may not declare its
  own work accepted; acceptance authority belongs to Claude (as to fact) and the
  human (as to arbitration). Phase 00 requirement: "Codex cannot declare live
  acceptance or phase completion" (`00-CONTEXT.md:20-22`).
- **Problem:** The rule reads "Codex may record proposed dispositions and correction
  evidence but may not mark **disputed** findings accepted or the phase closed." The
  qualifier is a negation with an unowned predicate: it grants, by implication, that
  Codex *may* mark **undisputed** findings accepted — and nothing in the repository
  says who decides whether a finding is disputed. The only party editing the artifact
  at that moment is Codex.
- **Failure scenario:** Claude records M-06 (unenforced version rule). Codex reads it,
  agrees with it, declares it undisputed, writes "Accepted — no change required; the
  rule is documented in AGENTS.md" into the artifact, and closes it. No human ever
  sees the finding. Repeat across an entire review and the adversarial gate becomes
  a formality that the implementer self-clears. The phase-closure prohibition still
  holds, so nothing trips — the finding history simply arrives at the human
  pre-cleared.
- **Smallest correction:** Change `AGENTS.md:64-66` to: "Codex may record proposed
  dispositions and correction evidence only. Codex may not mark any finding accepted,
  resolved, or closed. A finding is closed by Claude on re-review (as to fact) or by
  the human (as to arbitration)."

### B-02 — Two of the four STATE.md gate fields are unowned and Codex-writable

- **Severity:** Blocker
- **Location:** `.planning/STATE.md:9-13` (frontmatter gates) and `:34-37`
  (protective prose)
- **Violated invariant:** `AGENTS.md:48` makes `STATE.md` authoritative for "current
  phase, branch, gate, and handoff state". Gate state must not be settable by the
  party the gate constrains.
- **Problem:** The frontmatter carries four gates — `independent_review`,
  `human_arbitration`, `live_mudlet_validation`, `phase_closure`. The prose at
  `:34-37` protects only the last two: "Codex may record branch and gate progress but
  may not set live Mudlet validation or phase closure to complete."
  `independent_review` and `human_arbitration` are named nowhere and are, by the
  general grant at `AGENTS.md:11-13` ("Codex may change … documentation, and Git state
  when instructed"), Codex-writable.
- **Failure scenario:** A future Codex session, tidying state after a correction
  round, writes `independent_review: complete` and `human_arbitration: complete`.
  The second of those is a fabricated record of a human decision that never occurred.
  Every downstream session — including a fresh Claude session performing session
  startup per `AGENTS.md:93-95` — reads STATE.md as the gate authority and concludes
  the phase needs only live validation. The two rules that *were* written survive
  intact and catch nothing, because the forged gates are upstream of them.
- **Smallest correction:** In `.planning/STATE.md:34-37`, replace the two-gate list
  with an explicit writer per gate: Codex may write `status`, `active_branch`,
  `active_phase`, `active_specification`, and `main_baseline` only; `independent_review`
  is written by Claude; `human_arbitration`, `live_mudlet_validation`, and
  `phase_closure` are written by the human only. Mirror the same sentence into
  `AGENTS.md` so it is not phase-scoped.

### B-03 — Three-part hole that puts unaccepted work on `main`

- **Severity:** Blocker
- **Location:** `AGENTS.md:85-89`; `CODEX.md:59`; `CODEX.md:68`
- **Violated invariant:** `AGENTS.md:71-72` — "`main` is the latest completed,
  independently reviewed, human-authorized, and live-validated phase";
  `00-CONTEXT.md:29-33` — "Keep `main` limited to completed, reviewed,
  human-authorized, live-validated phases."
- **Problem:** Three independent gaps compose:
  1. **Authorization binds no SHA.** `AGENTS.md:85-87` says Codex must not merge "a
     phase" until the human authorizes it "after review, arbitration, and required
     live Mudlet validation". The unit of authorization is the phase, not a commit.
     `AGENTS.md:88-89` asks that the reviewed and correction SHAs be *recorded*, but
     never requires that the merged tree equal them.
  2. **The direct-commit ban is scoped to phase work.** `CODEX.md:59` says "do not
     commit active phase work directly to `main`." Anything not classified as active
     phase work — a quick task, a hotfix, a docs touch-up — is left free to land on
     `main`. The repository already has this precedent institutionalized:
     `.planning/STATE.md:232-237` records two completed quick tasks with their
     commits, and `.planning/quick/` holds their PLAN/SUMMARY pairs. Nothing in
     `AGENTS.md` covers quick tasks at all.
  3. **Push is the standing default.** `CODEX.md:68` — "Commit and push changes
     unless the user asks otherwise" — and `CODEX.md:75` — "Push non-trivial changes
     after committing them" — are unconditional and apply on whatever branch is
     checked out, including `main`.
- **Failure scenario A (stale merge):** Claude reviews `44fb844`. Codex pushes three
  correction commits. The human, reading a review artifact that names `44fb844`,
  authorizes "merge Phase 00". Codex merges the branch tip, which now includes a
  fourth commit pushed after the last review boundary. Unreviewed content lands on
  `main` and every rule was followed.
- **Failure scenario B (quick task):** A new session is asked for a one-line gag fix.
  It is not "active phase work", so `CODEX.md:59` does not apply; `CODEX.md:68`
  applies and pushes. `main` now holds source that was never independently reviewed,
  arbitrated, or live-validated, and `AGENTS.md:71-72` is silently false.
- **Smallest correction:** (a) In `AGENTS.md:85-87`, require that human merge
  authorization name an exact SHA and that only that SHA may be merged; a later push
  voids the authorization. (b) Change `CODEX.md:59` to "do not commit *any* work
  directly to `main`" and add a phase-branch requirement for quick tasks in
  `AGENTS.md`. (c) Scope `CODEX.md:68` to "commit and push to the active phase
  branch".

---

## High

### H-01 — Acceptance Criterion 5 is falsified by the branch it certifies

- **Severity:** High
- **Location:** `00-CONTEXT.md:46-47` vs. the reviewed diff
  (`src/scripts/boop/boop_init.lua`, `mfile`)
- **Violated invariant:** An acceptance criterion must be true of the commit offered
  for acceptance.
- **Problem:** AC5 states "No product source, command behavior, module boundary, or
  build artifact is changed." The reviewed diff changes
  `src/scripts/boop/boop_init.lua` — product source under `src/` — moving
  `boop.version` from `0.1.496.1` to `0.1.496.3`, and changes `mfile` version and
  title. `boop.version` is operator-visible at runtime. The same file's D-00-06
  (`00-CONTEXT.md:68-70`) explicitly acknowledges the version bump, so the document
  contradicts itself two sections apart.
- **Failure scenario:** The human reads AC5 and skips source review for a
  "process-only" phase. The precedent is then reusable: any future process phase can
  assert "no product source changed" while carrying edits to `src/`, and the
  criterion no longer distinguishes a version bump from a behavior change.
- **Smallest correction:** Rewrite AC5 as "No command behavior, module boundary, or
  build artifact is changed. The only product-source change is the synchronized
  version bump required by D-00-06."

### H-02 — `.planning/config.json` is live-looking GSD orchestration authority

- **Severity:** High
- **Location:** `.planning/config.json` (whole file, untouched by this phase)
- **Violated invariant:** `00-CONTEXT.md:34` — "Do not introduce GSD or any other
  orchestration framework"; D-00-05 (`00-CONTEXT.md:65-67`) — GSD metadata is
  historical provenance only; `AGENTS.md:57-60` — "legacy tooling metadata are
  provenance only".
- **Problem:** The file survives untouched and is machine-readable, is named
  `config.json`, sits directly beside the four documents `AGENTS.md` names
  authoritative, and is not mentioned anywhere in `AGENTS.md` — not in the Durable
  Artifacts table, not as provenance. Its contents actively contradict the new
  contract:
  - `git.phase_branch_template: "gsd/phase-{phase}-{slug}"` contradicts
    `AGENTS.md:73` (`phase/<number>-<short-description>`) and the actual branch name.
  - `git.branching_strategy: "none"` contradicts the mandatory-phase-branch rule.
  - `mode: "yolo"` and `workflow.human_verify_mode: "end-of-phase"` contradict the
    per-boundary human authority model.
  - `workflow.code_review: true` / `code_review_depth: "standard"` describe an
    automated review step that could be read as substituting for Claude.
  - `ship.pr_body_sections` describes an automated PR/ship path with a
    "Stakeholder Review & Approval" template that fabricates approval text.
  - `claude_md_path: "./.claude/CLAUDE.md"` points at a file that does not exist
    (see H-04).
- **Failure scenario:** A fresh session doing startup finds `.planning/config.json`,
  reasonably treats structured config as more authoritative than prose, and creates
  `gsd/phase-06-…` instead of `phase/06-…`. `.planning/STATE.md` then names a branch
  that does not exist, `AGENTS.md:74-75` ("The matching context file and
  `.planning/STATE.md` must name that branch") is violated, and — because
  `.github/workflows/main.yml:5` filters on `main` and `phase/**` — **no CI runs at
  all**, so the exact-SHA gate can never be satisfied for that phase.
- **Smallest correction:** Delete `.planning/config.json`, or rename it to
  `.planning/legacy-gsd-config.json.provenance` and add a row to the `AGENTS.md`
  Durable Artifacts section marking it explicitly non-authoritative. Deleting is
  smaller and removes the ambiguity entirely.

### H-03 — `README.md` asserts a conflicting authority model and active GSD execution

- **Severity:** High
- **Location:** `README.md:177`
- **Violated invariant:** `AGENTS.md:128-132` — CI is blocking *automated evidence*
  and does not authorize acceptance; D-00-05 — no GSD orchestration authority.
- **Problem:** The line reads: "Repository **terminal CI authority** runs only after
  upstream **GSD** execution and every repository mutation finish: the parent pushes
  immutable final HEAD, then runs `tools/wait_for_exact_ci.sh` …". This survives
  unedited while `AGENTS.md` deliberately renamed its own section from "Terminal CI
  Gate" to "Verification And Terminal CI" and demoted CI below live Mudlet validation
  and human closure. `CODEX.md:55` was corrected in this very phase; the identical
  README claim was not. Critically, `AGENTS.md:96` instructs every session to read
  `README.md` at startup — so this text is in-context for every agent, and it sits in
  a user-facing behavior bullet list rather than under any historical disclaimer.
- **Failure scenario:** A new session performs startup, reads `README.md:177`, and
  concludes that a successful `wait_for_exact_ci.sh` is terminal authority. It reports
  the phase as done on green CI, skipping independent review, arbitration, and live
  Mudlet validation — the exact failure mode Phase 00 exists to prevent. It also
  learns that a "GSD execution" stage is a live part of the workflow.
- **Smallest correction:** Rewrite `README.md:177` to: "Repository CI is blocking
  automated evidence only: after every repository mutation, push immutable final HEAD
  and run `tools/wait_for_exact_ci.sh`. CI evidence is not committed, any later
  mutation requires a rerun, and CI never authorizes acceptance or closure — see
  `AGENTS.md`."

### H-04 — `AGENTS.md` is not loaded into Claude sessions; no `CLAUDE.md` exists

- **Severity:** High
- **Location:** repository root and `.claude/` (absence); `00-CONTEXT.md:38` (AC1)
- **Violated invariant:** AC1 — "`AGENTS.md` is the concise authority and lifecycle
  contract for **every agent**."
- **Problem:** `find . -name CLAUDE.md` returns nothing: there is no root `CLAUDE.md`
  and no `.claude/CLAUDE.md` (which `.planning/config.json` nonetheless points at).
  `.claude/` contains only `settings.local.json`. `AGENTS.md` is a Codex-side
  convention; a Claude session does not automatically load it. The contract that
  defines Claude's role, its source-read-only constraint, the designated review
  artifact, and the prohibition on self-approval is therefore absent from the context
  of the agent it constrains, unless a human pastes it in — which is exactly how this
  review was initiated.
- **Failure scenario:** A future Claude session is asked "review the phase branch".
  Without `AGENTS.md` in context it does not know it must not edit implementation
  source, does not know the artifact path or naming convention, and does not know it
  may not resolve findings. It fixes what it finds, writes a summary into a new file
  of its own naming, and the "independent adversarial review" stage produces no
  durable artifact and no independence.
- **Smallest correction:** Add a root `CLAUDE.md` containing a pointer: "This
  repository's authority, workflow, and safety contract is `AGENTS.md`. Read it in
  full before any action, then `.planning/STATE.md` and the active phase context it
  names." Correct or remove `claude_md_path` in `.planning/config.json` (see H-02).

### H-05 — "initial review" leaves Claude free to edit source and close its own findings

- **Severity:** High
- **Location:** `AGENTS.md:14-16`
- **Violated invariant:** Reviewer independence — the reviewer must not become an
  implementer of the code it certifies.
- **Problem:** "Claude's **initial** review must not modify implementation source."
  The qualifier scopes the constraint to one pass and, by implication, releases every
  subsequent pass. There is no second sentence bounding later passes. Separately,
  `AGENTS.md:15-16` grants Claude the right to "add or update the phase's designated
  adversarial-review artifact" with no restriction on *what* it may write there —
  including marking its own findings resolved. `AGENTS.md:64` says only "Claude owns
  the initial findings"; ownership of resolution is unassigned. Note the asymmetry:
  Codex's authority is constrained by an explicit (if flawed, see B-01) prohibition;
  Claude's is constrained by an adjective.
- **Failure scenario:** Claude records five findings. Codex corrects three. Claude
  re-reviews, decides the remaining two are trivial, edits `AGENTS.md` itself to fix
  them, and writes "resolved by reviewer" into the artifact. The independent reviewer
  has now authored part of the implementation and certified it, and the human sees a
  clean artifact with no open findings.
- **Smallest correction:** Replace `AGENTS.md:14-16` with: "**Claude** is the
  independent adversarial reviewer. Claude never modifies implementation source,
  tests, or state gates in any pass. Claude may only add to the phase's designated
  adversarial-review artifact, and may close a finding only by recording a verified
  re-review of a named correction SHA — never by implementing the correction."

### H-06 — Three live "Phase N" namespaces; Phase 00 exists in none of the sequencing authorities

- **Severity:** High
- **Location:** `.planning/ROADMAP.md:20-25` and `:269-272`;
  `REFACTOR-ROADMAP.md:46-350`; `.planning/STATE.md:5-6`; `CODEX.md:39-44` and `:120`
- **Violated invariant:** `AGENTS.md:47` names `.planning/ROADMAP.md` the authority
  for milestone sequencing; `AGENTS.md:93-95` requires a session to stop and report if
  `STATE.md` and the phase context disagree with Git state.
- **Problem:** "Phase N" resolves to three different things and none of them is
  Phase 00:
  - `.planning/ROADMAP.md:20-25` — Phases 1–6, with **Phase 3, 4, 5, and 6 still
    unchecked** and the summary table at `:269-272` showing only Phases 1–2 complete.
  - `REFACTOR-ROADMAP.md` — a *separate root-level* roadmap with Phases 1–13, whose
    Phase 4 and Phase 5 are the ones actually landed on `main` (`ad77cdc` "complete
    phase 4 composition and ownership seams", `1cfc72c` "complete phase 5 room and
    lock ownership"). This document is not in the `AGENTS.md` Durable Artifacts table
    at all.
  - `.planning/STATE.md:5-6` — `active_phase: "00"`, which appears in neither roadmap.

  `CODEX.md:120` ("landed through Phase 5") and `CODEX.md:39-44` ("the Phase-4 base
  increments the third component to `0.1.495`") both reference the REFACTOR-ROADMAP
  numbering without naming it, while sitting in a file whose sibling authority is the
  `.planning` roadmap.
- **Failure scenario:** A new session performs startup. `STATE.md` says Phase 00.
  `ROADMAP.md`, the declared sequencing authority, says Phase 3 is the next open phase
  and Phases 4–5 are not started — while Git history says Phases 4 and 5 are complete.
  The session either stops and reports a mismatch it cannot resolve
  (`AGENTS.md:93-95`), or picks one and begins the wrong work. `CODEX.md:120`'s
  "through Phase 5" reinforces the wrong reading.
- **Smallest correction:** Add Phase 00 to `.planning/ROADMAP.md` as a completed-scope
  process phase, add `REFACTOR-ROADMAP.md` to the `AGENTS.md` Durable Artifacts table
  with its scope stated, and qualify each ambiguous reference with its document
  (e.g. `CODEX.md:120` → "REFACTOR-ROADMAP Phase 5").

---

## Medium

### M-01 — Stale handoff block inside the state authority still points at Phase 03

- **Severity:** Medium
- **Location:** `.planning/STATE.md:247-252`
- **Violated invariant:** `AGENTS.md:48` — `STATE.md` is authoritative for "current
  phase, branch, gate, and **handoff state**".
- **Problem:** The `Session Continuity` block was not touched by this phase and still
  reads "Last session: 2026-08-04T22:24:56.710Z / Stopped at: Completed 03-33-PLAN.md
  / Resume file: None". It contradicts the frontmatter (Phase 00), the body (`:29-32`),
  *and* the metrics section immediately above it, which records work through Plan
  03-39. The `Historical Planning Record` disclaimer at `:39-43` scopes itself to "the
  detailed metrics and accumulated decisions below" — handoff state is neither, and
  handoff state is precisely what `AGENTS.md` makes this file authoritative for.
- **Failure scenario:** A session scrolls to the end of `STATE.md` looking for where
  to resume — the section literally titled "Session Continuity" — and resumes Phase 03
  at plan 34, on the Phase 00 branch.
- **Smallest correction:** Update `.planning/STATE.md:247-252` to the current
  boundary, or move the block under the `Historical Planning Record` heading and
  retitle it `Historical Session Continuity`.

### M-02 — Retained decision names `wait_for_exact_ci.sh` "final authority"

- **Severity:** Medium
- **Location:** `.planning/STATE.md:118`
- **Violated invariant:** `AGENTS.md:21-33` authority order and `:128-132`.
- **Problem:** "[Phase 03 planning]: **Final authority** is the tracked repository
  extension `tools/wait_for_exact_ci.sh` against immutable final HEAD after all GSD
  mutations." This is the strongest surviving statement of the superseded model, it
  uses the word "final", it names GSD, and it sits in an `### Decisions` list that
  `AGENTS.md:52` treats as a home for durable decisions. The `:39-43` disclaimer says
  such decisions "do not control the current phase" but does not contradict this one
  specifically, and a reader scanning for authority statements will find this line's
  wording far more definite than the disclaimer's.
- **Failure scenario:** An agent resolving an authority question greps for
  "authority", finds this line, and treats a green exact-SHA run as terminal — the
  same outcome as H-03, reached through a second document.
- **Smallest correction:** Prefix the entry with "(Superseded by `AGENTS.md` authority
  order; CI is automated evidence only.)".

### M-03 — Exact-SHA CI evidence is required to be recorded and forbidden to be committed

- **Severity:** Medium
- **Location:** `AGENTS.md:128-130` vs `00-CONTEXT.md:48-49` (AC6)
- **Violated invariant:** Evidence supporting acceptance must remain verifiable after
  the session that produced it ends.
- **Problem:** AC6 requires that "exact-SHA CI is **recorded** as automated evidence
  only", while `AGENTS.md:129-130` states "CI evidence is reported but **not
  committed**". Reported to whom, and where it persists, is unspecified. In practice
  the only record of run `33915198772` succeeding on `44fb844` is transient session
  output. `AGENTS.md:88-89` requires recording the reviewed SHA, correction SHA, live
  result, and closure authority — CI run identity is conspicuously absent from that
  list.
- **Failure scenario:** Weeks later the human asks whether the reviewed SHA ever
  passed CI. Nothing in the repository answers. Because GitHub Actions logs expire and
  `main.yml` has no `workflow_dispatch` (see L-03), the run cannot be reconstructed
  without a new commit — which by definition is a different SHA.
- **Smallest correction:** Add the CI run id and headSha to the phase's
  `<NN>-VERIFICATION.md` and to the `AGENTS.md:88-89` recording list. Recording a run
  *identifier* is not committing the evidence blob, so the two rules stop conflicting.

### M-04 — Phase 00 has no `00-VERIFICATION.md` or `00-UAT.md`

- **Severity:** Medium
- **Location:** `00-CONTEXT.md:40-42` (AC3); `AGENTS.md:53` and `:55`
- **Violated invariant:** AC3 — the existing `VERIFICATION`, `ADVERSARIAL-REVIEW`, and
  `UAT` artifacts "are reused with unambiguous ownership".
- **Problem:** `.planning/phases/00-lightweight-agent-workflow/` contains exactly one
  file, `00-CONTEXT.md`. `AGENTS.md:53` makes `<NN>-VERIFICATION.md` an authority for
  automated verification and `:55` makes `<NN>-UAT.md` the authority for
  human-directed live acceptance. Neither exists, so AC3 asserts reuse of artifacts
  that were never created, AC6's "recorded" has no home (M-03), and the
  live-validation gate at `.planning/STATE.md:12` has nowhere to land its result.
- **Failure scenario:** The human authorizes closure. The repository holds no record
  of what was verified or what live checks were performed, so the very first phase
  closed under the new workflow sets the precedent that VERIFICATION and UAT are
  optional.
- **Smallest correction:** Create `00-VERIFICATION.md` (release-gate results, CI run
  identity) and `00-UAT.md` (even if its recorded content is a human determination
  that live validation is not applicable — see M-07), or amend AC3 to state which
  artifacts this phase deliberately omits and why.

### M-05 — The version used contradicts `CODEX.md`'s own corrective-build convention

- **Severity:** Medium
- **Location:** `CODEX.md:39-44`; `mfile`; `src/scripts/boop/boop_init.lua`
- **Violated invariant:** The convention stated in the same file the phase edited.
- **Problem:** `CODEX.md:39-43` defines: the fourth component is for "**reviewed and
  tested corrective rebuilds** of that phase", and "the next phase increments the
  third component again". Phase 00 is a new phase, so by that rule it should have gone
  to `0.1.497`. Instead it took `0.1.496.2` and `0.1.496.3` — fourth-component
  increments, the slot reserved for reviewed corrective rebuilds, applied to a phase
  that had not been reviewed or tested at all. It also consumed two of them before any
  review boundary existed. Separately, `CODEX.md:40` anchors the convention to "the
  Phase-4 base" without naming which roadmap's Phase 4 (see H-06).
- **Failure scenario:** Corrections to this review's findings need version numbers.
  The convention now offers `0.1.496.4` for "reviewed corrective rebuild" — but `.2`
  and `.3` already burned that meaning, so the version string no longer distinguishes
  original implementation from post-review correction, which is the one thing the
  fourth component was introduced to encode.
- **Smallest correction:** Either move Phase 00 to `0.1.497` on the next
  package-affecting commit, or amend `CODEX.md:39-44` to state that process-only
  phases take fourth-component increments and that the fourth component no longer
  implies review status.

### M-06 — The versioning rule is prose-only; CI enforces neither classification nor monotonicity

- **Severity:** Medium
- **Location:** `tools/check_release_gates.py:126-176` (`check_versions`);
  `AGENTS.md:106-119`
- **Violated invariant:** `AGENTS.md:108-117` — every package-affecting commit "must
  **monotonically** bump all Boop version fields together"; REL-01.
- **Problem:** `check_versions` reads `mfile.version`, then asserts that `mfile.title`,
  `boop.version`, and the `CODEX.md` checkpoint match it. That is a four-way
  *agreement* check only. It has no access to the diff, so it cannot tell a
  planning-only commit from a package-affecting one; and it never compares against any
  previous version, so it cannot detect a missing bump or a decrease. The
  classification rule that Phase 00 spent two documents restating is enforced by
  nothing.
- **Failure scenario:** Codex edits `src/scripts/boop/boop_gag.lua` and forgets to
  bump. All four fields still agree, `[OK] versions`, CI is green, and the exact-SHA
  gate passes. Two source revisions now ship under one version string — precisely the
  drift REL-01 exists to prevent. A version that moves *backwards* passes identically.
- **Smallest correction:** Add a `--check version-bump` mode that compares
  `mfile.version` against `git merge-base origin/main HEAD`'s value and fails when any
  path outside `.planning/` changed without a strictly greater version. Wire it into
  the `Release gates` step of `.github/workflows/main.yml`.

### M-07 — Live-Mudlet applicability is phase-scoped, undefined, and contradicts the authority order

- **Severity:** Medium
- **Location:** `00-CONTEXT.md:78-79`; `AGENTS.md:21-33` and `:17-19`;
  `.planning/STATE.md:12`
- **Violated invariant:** "Mudlet remains final authority for **applicable** live
  runtime behavior" — applicability must have a defined decider and a recorded result.
- **Problem:** Three inconsistent treatments coexist. `AGENTS.md:21-33` places "live
  Mudlet validation" unconditionally in the authority chain before phase closure, with
  no applicability concept. `AGENTS.md:17-19` refers to "**required** live Mudlet
  validation" without saying who determines that it is required.
  `.planning/STATE.md:12` invents a fourth value, `pending_human_determination`, which
  no rule defines. The only rule that actually constrains anyone —
  `00-CONTEXT.md:78-79`, "Codex may not mark it not-applicable or passed" — lives in
  Phase 00's context file and therefore does not carry to Phase 01 or any later phase.
- **Failure scenario:** Phase 06 is documentation-only. Codex writes
  `live_mudlet_validation: not_applicable` in `STATE.md`. `AGENTS.md` contains no rule
  against it, the Phase 00 context does not apply, and the mandatory live gate is
  self-cleared by the implementer for every future non-runtime phase — with STATE.md
  gates already unowned per B-02.
- **Smallest correction:** Move the sentence from `00-CONTEXT.md:78-79` into
  `AGENTS.md`, generalized: "Whether live Mudlet validation is required for a phase is
  a human determination recorded in the phase's `<NN>-UAT.md`. Codex and Claude may
  neither mark it required, not-applicable, nor passed."

### M-08 — Review-artifact edit rights, severity integrity, and re-review are unspecified

- **Severity:** Medium
- **Location:** `AGENTS.md:62-67`; `00-CONTEXT.md:60-62` (D-00-03)
- **Violated invariant:** D-00-03 — "one **append-preserving** adversarial review
  artifact per phase. Findings, proposed dispositions, correction evidence, and human
  arbitration remain **distinguishable** inside it."
- **Problem:** The append-preserving property is stated only in Phase 00's context
  file and never reaches `AGENTS.md`, so it does not generalize. What
  `AGENTS.md:62-64` does say is passive — the artifact "preserves finding IDs and
  severity" — naming no actor and prohibiting no one from rewriting a finding's text
  or lowering its severity. And nothing anywhere states who closes a finding after a
  correction lands, or whether a re-review of the correction SHA is required before
  closure.
- **Failure scenario:** Codex lands a partial correction for a Blocker and rewrites
  the finding as Medium with "narrowed after correction" — no rule is broken. Combined
  with B-01 (Codex may accept undisputed findings), the entire severity ladder is
  editable by the implementer, and the human's arbitration view is of a document that
  no longer says what the reviewer wrote.
- **Smallest correction:** Add to `AGENTS.md:62-67`: "The artifact is append-only. No
  actor may edit or delete a recorded finding's ID, severity, or text; changes are
  recorded as new dated entries beneath the finding. A finding closes only on a
  recorded Claude re-review naming the correction SHA, or on recorded human
  arbitration."

---

## Low

### L-01 — The `main` invariant is asserted as already true, and is not

- **Severity:** Low
- **Location:** `AGENTS.md:71-72`
- **Problem:** "`main` is the latest completed, independently reviewed,
  human-authorized, and live-validated phase." At the reviewed SHA, `main` is
  `a345a34`, whose recent history (`1cfc72c` "complete phase 5", `ad77cdc` "complete
  phase 4", `30871b5`, `f39cf22`, `0eef7c4`) is an unreviewed refactor stream that
  predates this workflow. No bootstrap exception is recorded.
- **Failure scenario:** An agent treats the sentence as a verified fact about the
  current baseline and skips scrutiny of pre-existing `main` content, or treats the
  demonstrably false statement as evidence that `AGENTS.md` describes aspiration
  rather than rules.
- **Smallest correction:** Add "From Phase 00 forward," to the start of the sentence,
  and note that `a345a34` is the accepted pre-workflow baseline.

### L-02 — `main_baseline` is duplicated in three places with no owner

- **Severity:** Low
- **Location:** `.planning/STATE.md:14`, `.planning/STATE.md:31`, `00-CONTEXT.md:4`
- **Problem:** `a345a34` appears three times. No rule names which copy is
  authoritative or requires the others to be updated together.
- **Failure scenario:** Phase 00 merges and Phase 01 starts. One copy is updated,
  another is not, and the `AGENTS.md:93-95` startup consistency check fires on a
  discrepancy that is purely bookkeeping — or worse, does not fire because the agent
  read the stale copy.
- **Smallest correction:** Make `.planning/STATE.md` frontmatter the single owner and
  have `00-CONTEXT.md:4` reference it rather than restate the SHA.

### L-03 — The exact-CI gate is run-selection-ambiguous and cannot be re-run

- **Severity:** Low
- **Location:** `tools/wait_for_exact_ci.sh:33-49`; `.github/workflows/main.yml:3-7`
- **Problem:** The `--jq` filter takes `first` of up to 20 runs matching the headSha,
  with no filter on `event` or `headBranch`. Once a phase branch has an open PR to
  `main`, a `push` run and a `pull_request` run exist for the same headSha, and which
  one the gate evaluates depends on list ordering. Separately, `main.yml` declares no
  `workflow_dispatch`, so a run that fails for infrastructure reasons (the Mudlet
  AppImage download, the 20-minute runner timeout) cannot be re-gated for that SHA
  without creating a new commit — which changes the SHA the review named.
- **Failure scenario:** A green PR run masks a red push run, or a flaky infrastructure
  failure forces a new commit that silently invalidates the reviewed SHA.
- **Smallest correction:** Add `select(.event == "push")` to the `--jq` filter, and add
  `workflow_dispatch:` to `main.yml`.

### L-04 — `permissions: write-all` now runs on every `phase/**` push

- **Severity:** Low
- **Location:** `.github/workflows/main.yml:5` and `:11`
- **Problem:** Widening the push trigger from `main` to `main, "phase/**"` — the
  substance of commit `44fb844` — also widens where a job declaring
  `permissions: write-all` executes with `github.token`. The job's actual needs are
  read access to the repository plus release-asset download and artifact upload.
- **Failure scenario:** Any future compromise or mistake in a workflow step now has a
  write-scoped token available on a much larger set of branches than before.
- **Smallest correction:** Replace `write-all` with the specific scopes used
  (`contents: read`, `actions: write` for artifacts, `pull-requests: write` for the PR
  comment step).

### L-05 — `.planning/codebase/` still self-describes as GSD output

- **Severity:** Low
- **Location:** `.planning/codebase/STRUCTURE.md:32` and `:243`
- **Problem:** "Generated codebase maps for **GSD workflows**" and "Generated
  architecture/structure/quality/stack maps for **GSD planning**".
  `.planning/PROJECT.md` was corrected in this phase to drop the "GSD" prefix from its
  reference to this same directory; the directory's own description was not.
- **Failure scenario:** Minor — an agent infers a live generation step it should run
  or keep in sync.
- **Smallest correction:** Drop "GSD" from both lines, or add "(historical; generated
  by superseded tooling)".

### L-06 — Stale hardcoded version-bump permission in `.claude/settings.local.json`

- **Severity:** Low
- **Location:** `.claude/settings.local.json`
- **Problem:** The allow-list pins a literal `sed -i` command bumping the `CODEX.md`
  checkpoint from `0.1.491` to `0.1.492` — a one-off from a long-past session,
  preserved as if it were a workflow step, and now misleading given the
  four-checkpoint synchronization rule.
- **Failure scenario:** Cosmetic; it suggests single-field checkpoint edits are a
  sanctioned pattern, which `AGENTS.md:108-117` forbids.
- **Smallest correction:** Remove that entry.

---

## Investigated and concluded NOT defects

- **CI does support pushed phase branches.** `phase/**` matches
  `phase/00-lightweight-agent-workflow`, and run `33915198772` (event `push`,
  headBranch `phase/00-lightweight-agent-workflow`) completed `success` on exactly
  `44fb844f…`. The exact-SHA review model is mechanically achievable on this branch.
- **`tools/wait_for_exact_ci.sh` is sound on its core guarantees.** It rejects short
  SHAs, requires `HEAD == expected`, requires a clean worktree with untracked files
  included, requires the SHA to exist on `origin`, re-verifies `headSha` after
  watching, and re-checks HEAD and worktree cleanliness afterwards. The immutability
  claim holds; only run *selection* is loose (L-03).
- **Branch provenance is correct.** `git merge-base main HEAD` is `a345a34`, equal to
  `origin/main`, satisfying `AGENTS.md:73-75`.
- **Version fields are internally consistent and monotonic across this branch.**
  `0.1.496.1 → .2 → .3`, with `mfile.version`, `mfile.title`,
  `src/scripts/boop/boop_init.lua`, and the `CODEX.md` checkpoint synchronized at each
  commit. The *convention* is violated (M-05) and the *rule* is unenforced (M-06), but
  the values themselves are correct.
- **Both implementation commits correctly self-classified.** Each touched paths
  outside `.planning/` and each bumped. The path-prefix classification rule was
  applied faithfully.
- **Release gates pass at the reviewed SHA**, including the architecture guard
  (25 modules, 141 edges, single composition root `boop_bootstrap`).
- **Commit boundaries are appropriate.** `90ab936` (contract) and `44fb844` (CI
  enablement) are coherent and separable, per `AGENTS.md:77-81`.
- **No orchestration framework was introduced.** The GSD problem here is entirely
  residual (H-02, H-03, M-02, L-05), not additive.
- **The `phase/**` glob is not over-broad in a harmful way** relative to
  `AGENTS.md:73`'s `phase/<number>-<short-description>`; a wider CI filter than the
  naming rule is the safe direction.
- **No product behavior, command surface, module boundary, or build artifact
  changed.** The only `src/` change is the version string — which is H-01's
  documentation problem, not a behavior regression.

---

## Disposition

Claude records findings only. Per `AGENTS.md:62-67`, Codex may record proposed
dispositions and correction evidence below; disputed findings and all closure decisions
belong to human arbitration. B-01, B-02, H-05, and M-08 concern who may fill this table
in — until they are resolved, dispositions recorded here should be treated as proposals
regardless of how they are labelled.

| ID | Severity | Proposed disposition | Correction SHA | Arbitration | Closed by |
|---|---|---|---|---|---|
| B-01 | Blocker | | | | |
| B-02 | Blocker | | | | |
| B-03 | Blocker | | | | |
| H-01 | High | | | | |
| H-02 | High | | | | |
| H-03 | High | | | | |
| H-04 | High | | | | |
| H-05 | High | | | | |
| H-06 | High | | | | |
| M-01 | Medium | | | | |
| M-02 | Medium | | | | |
| M-03 | Medium | | | | |
| M-04 | Medium | | | | |
| M-05 | Medium | | | | |
| M-06 | Medium | | | | |
| M-07 | Medium | | | | |
| M-08 | Medium | | | | |
| L-01 | Low | | | | |
| L-02 | Low | | | | |
| L-03 | Low | | | | |
| L-04 | Low | | | | |
| L-05 | Low | | | | |
| L-06 | Low | | | | |

## Review status

- **Reviewed SHA:** `44fb844fe2aadf9d71fd7aa95736f3f336e3af72`
- **Findings:** 3 blocker, 6 high, 8 medium, 6 low
- **Independent review:** initial pass complete; no re-review performed
- **Human arbitration:** pending
- **Live Mudlet applicability or validation:** pending human determination
- **Phase closure and merge to `main`:** pending explicit human authorization
- **Phase 00 is not complete.**

This review commit mutates the repository and therefore invalidates the exact-SHA CI
evidence recorded above for `44fb844`; per `AGENTS.md:126-130` the gate must be run
again against the new HEAD by Codex.
