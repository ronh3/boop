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


---

## Codex proposed dispositions and corrections — 2026-09-04

Author: Codex, implementation/correction role. These are proposals only. None of
Claude’s original findings, severities, text, table cells, or review status above
has been changed. All 23 findings remain awaiting Claude re-review; partial
agreement and policy choices also await Human + ChatGPT/Neon arbitration.

Correction boundary: the package-affecting commit containing this appendix. Its
full SHA is not self-embedded; a subsequent planning-only evidence entry will
name the correction SHA and its CI run. Local verification is recorded in
00-VERIFICATION.md. Phase 00 remains incomplete; main is not a correction target.

Proposed totals: 15 ACCEPT, 8 PARTIALLY ACCEPT, 0 REJECT. No final disposition or
factual closure is asserted by those labels.

### Codex proposal for B-01

- **Proposed disposition:** ACCEPT.
- **Reasoning/evidence:** AGENTS previously prohibited accepting only disputed findings, leaving the predicate unowned. The corrected contract prohibits Codex from finally accepting, resolving, or closing any finding; ACCEPT/PARTIALLY ACCEPT/REJECT are explicitly proposals. Claude must name the correction SHA for factual closure; the human arbitrates.
- **Files changed:** AGENTS.md; .planning/STATE.md; 00-CONTEXT.md; CLAUDE.md.
- **Tests/checks:** Manual authority cross-check; workflow gate protects the recorded review prefix. No check claims to authenticate the actor.
- **Correction SHA:** pending commit; see the subsequent correction-evidence entry.
- **Status:** awaiting Claude re-review / human arbitration; not closed.

### Codex proposal for B-02

- **Proposed disposition:** ACCEPT.
- **Reasoning/evidence:** STATE originally protected only live validation and phase closure. AGENTS and STATE now name a writer and evidence home for every gate, including exact-SHA merge authorization. Codex owns factual coordination only. The existing independent_review: pending value is deliberately untouched; the prose points to Claude’s actual review without writing its gate.
- **Files changed:** AGENTS.md; .planning/STATE.md; 00-UAT.md; CLAUDE.md.
- **Tests/checks:** Manual comparison of frontmatter before/after confirms no existing protected gate was advanced. Role identity remains a workflow constraint, not a Git-author test.
- **Correction SHA:** pending commit; see the subsequent correction-evidence entry.
- **Status:** awaiting Claude re-review / human arbitration; not closed.

### Codex proposal for B-03

- **Proposed disposition:** ACCEPT.
- **Reasoning/evidence:** The old merge permission named a phase, the direct-commit ban covered only active phase work, and CODEX push defaults were unconditional. The corrected rules ban every direct main commit, require the active phase branch for quick/hotfix/docs/planning work, and limit standing push defaults to that branch. Human authorization names an exact full SHA; branch-tip changes invalidate it. Fast-forwarding only that SHA avoids producing an unreviewed merge/squash tree.
- **Files changed:** AGENTS.md; CODEX.md; .planning/STATE.md; 00-CONTEXT.md; 00-UAT.md; tools/workflow_guard.py; tests/test_workflow_gates.py.
- **Tests/checks:** Staged active-phase branch passes; main, detached HEAD, and a different phase branch fail. Exact-CI tests require the expected SHA on the exact remote branch. These are not remote protection settings.
- **Correction SHA:** pending commit; see the subsequent correction-evidence entry.
- **Status:** awaiting Claude re-review / human arbitration; not closed.

### Codex proposal for H-01

- **Proposed disposition:** ACCEPT.
- **Reasoning/evidence:** The baseline diff contains a real src/scripts/boop/boop_init.lua change, even though it is only boop.version. AC5 now states the exact version-only product-source exception and acknowledges the operator-visible version string. No gameplay exception is introduced.
- **Files changed:** 00-CONTEXT.md; 00-VERIFICATION.md; 00-UAT.md.
- **Tests/checks:** Final baseline src diff inspection and four-checkpoint release gate; no runtime behavior test added for the string edit.
- **Correction SHA:** pending commit; see the subsequent correction-evidence entry.
- **Status:** awaiting Claude re-review / human arbitration; not closed.

### Codex proposal for H-02

- **Proposed disposition:** PARTIALLY ACCEPT.
- **Reasoning/evidence:** The operational filename and git.branching_strategy=none / gsd branch template contradict the active contract. Preserve the complete file by renaming it to .planning/legacy-gsd-config.json.provenance and prohibit loading it. However, the cited ship template literally says Product owner approval pending, so it does not itself fabricate approval. Historical provenance need not be deleted.
- **Files changed:** Rename .planning/config.json to .planning/legacy-gsd-config.json.provenance; AGENTS.md; tools/workflow_guard.py; tests/test_workflow_gates.py.
- **Tests/checks:** Byte equality against the original Git blob; workflow gate rejects a restored live .planning/config.json. Test covers that failure.
- **Correction SHA:** pending commit; see the subsequent correction-evidence entry.
- **Status:** awaiting Claude re-review / human arbitration; not closed.

### Codex proposal for H-03

- **Proposed disposition:** ACCEPT.
- **Reasoning/evidence:** README contained the exact operational upstream GSD / terminal authority sentence while CODEX had already corrected it. README now describes blocking automated evidence and links to the common authority contract and evidence-recording policy; startup begins with AGENTS.
- **Files changed:** README.md; AGENTS.md; CODEX.md.
- **Tests/checks:** Search operational startup docs for stale GSD execution and terminal acceptance claims; manually compare CI wording.
- **Correction SHA:** pending commit; see the subsequent correction-evidence entry.
- **Status:** awaiting Claude re-review / human arbitration; not closed.

### Codex proposal for H-04

- **Proposed disposition:** ACCEPT.
- **Reasoning/evidence:** No tracked CLAUDE.md existed. The new root CLAUDE.md imports @AGENTS.md and gives an explicit startup path through STATE and the active context. It also states that tool permissions cannot grant implementation or acceptance authority. The stale configuration pointer survives only in the retired provenance file. Claude Code’s documented project-memory path supports a root CLAUDE.md and @ imports: https://code.claude.com/docs/en/memory .
- **Files changed:** CLAUDE.md; AGENTS.md; retired config rename.
- **Tests/checks:** Inspect the tracked startup pointer and actual AGENTS/STATE/context paths. No claim of running a fresh Claude session.
- **Correction SHA:** pending commit; see the subsequent correction-evidence entry.
- **Status:** awaiting Claude re-review / human arbitration; not closed.

### Codex proposal for H-05

- **Proposed disposition:** PARTIALLY ACCEPT.
- **Reasoning/evidence:** The initial-only source prohibition was too narrow and now applies to every reviewer pass, including implementation docs and tests. But the suggested ban on every STATE gate conflicts with B-02’s Claude-owned independent_review field. Claude may append review evidence and update only that field. It can establish factual closure on re-review of a named correction SHA, never by implementing the correction; human arbitration/closure remain separate.
- **Files changed:** AGENTS.md; CLAUDE.md; .planning/STATE.md; 00-CONTEXT.md.
- **Tests/checks:** Manual writer-table and reviewer-permissions consistency check. All findings here remain proposals.
- **Correction SHA:** pending commit; see the subsequent correction-evidence entry.
- **Status:** awaiting Claude re-review / human arbitration; not closed.

### Codex proposal for H-06

- **Proposed disposition:** PARTIALLY ACCEPT.
- **Reasoning/evidence:** The two numbered product roadmaps and the missing bootstrap entry made the active sequence ambiguous. The milestone roadmap now indexes Phase 00 as active and incomplete and explicitly distinguishes Hardening Phase N from Refactor Phase N. REFACTOR-ROADMAP carries its namespace and points to STATE/context for activation; CODEX qualifies landed Refactor Phase 5. Existing hardening completion history is not rewritten. The recommendation to label Phase 00 completed-scope is not followed because this pass cannot establish completion.
- **Files changed:** .planning/ROADMAP.md; REFACTOR-ROADMAP.md; AGENTS.md; CODEX.md; .planning/STATE.md; 00-CONTEXT.md.
- **Tests/checks:** Manual phase namespace/branch/context check; no Phase 6 implementation or acceptance-status updates.
- **Correction SHA:** pending commit; see the subsequent correction-evidence entry.
- **Status:** awaiting Claude re-review / human arbitration; not closed.

### Codex proposal for M-01

- **Proposed disposition:** ACCEPT.
- **Reasoning/evidence:** The bottom Session Continuity block names the old 03-33 checkpoint. It is preserved but retitled Historical Session Continuity; the new current handoff points only to Phase 00 correction/review/verification/UAT artifacts.
- **Files changed:** .planning/STATE.md.
- **Tests/checks:** Inspect current and historical handoff headings and their references.
- **Correction SHA:** pending commit; see the subsequent correction-evidence entry.
- **Status:** awaiting Claude re-review / human arbitration; not closed.

### Codex proposal for M-02

- **Proposed disposition:** ACCEPT.
- **Reasoning/evidence:** The old Phase 03 Final authority statement is retained as provenance but explicitly marked superseded by AGENTS and automated-evidence-only. The general historical disclaimer now bars old execution instructions from controlling future phases as well as Phase 00. STATE’s old decisions do not replace PROJECT Key Decisions.
- **Files changed:** .planning/STATE.md; AGENTS.md.
- **Tests/checks:** Search the retained authority statement and verify the adjacent explicit supersession; do not purge historical plans.
- **Correction SHA:** pending commit; see the subsequent correction-evidence entry.
- **Status:** awaiting Claude re-review / human arbitration; not closed.

### Codex proposal for M-03

- **Proposed disposition:** PARTIALLY ACCEPT.
- **Reasoning/evidence:** The record-versus-no-commit policy needed a durable home and an explicit non-self-referential sequence. VERIFICATION now records run ID, attempt, URL, event, branch, SHA and outcome for completed boundaries. After an evidence commit, gate its new final SHA and report that identity; the next independently needed boundary may persist it. Contrary to the transient-only premise, Claude’s original review already records run 33915198772. It has also been independently fetched and entered in VERIFICATION. An earlier result never certifies the later evidence commit.
- **Files changed:** AGENTS.md; CODEX.md; README.md; 00-VERIFICATION.md; tools/wait_for_exact_ci.sh.
- **Tests/checks:** GitHub API re-fetch of run 33915198772 confirms push, branch, full head SHA, success, attempt 1. Final boundary run identities will be reported after their own gates.
- **Correction SHA:** pending commit; see the subsequent correction-evidence entry.
- **Status:** awaiting Claude re-review / human arbitration; not closed.

### Codex proposal for M-04

- **Proposed disposition:** ACCEPT.
- **Reasoning/evidence:** Phase 00 had no VERIFICATION or UAT artifact. Both now exist in the designated phase directory. VERIFICATION distinguishes automated evidence and limits; UAT supplies pending human-only applicability, live results, closure, and exact-SHA authorization fields. No human decision is manufactured to fill the scaffold.
- **Files changed:** 00-VERIFICATION.md; 00-UAT.md.
- **Tests/checks:** Inspect artifact existence, pending decisions, and links to the AGENTS writer contract.
- **Correction SHA:** pending commit; see the subsequent correction-evidence entry.
- **Status:** awaiting Claude re-review / human arbitration; not closed.

### Codex proposal for M-05

- **Proposed disposition:** ACCEPT.
- **Reasoning/evidence:** The prior Phase-4 example implied that fourth components meant reviewed corrective rebuilds, while Phase 00 used them before review. CODEX now states that process-only phases and subsequent package-affecting commits may use numeric fourth-component build increments, which imply no review/test/acceptance status. This correction synchronizes 0.1.496.4. DESIGN also contained a conflicting every-commit/merge bump rule; it now delegates to staged-path classification and all four checkpoints.
- **Files changed:** CODEX.md; DESIGN.md; mfile; src/scripts/boop/boop_init.lua; AGENTS.md; 00-VERIFICATION.md.
- **Tests/checks:** Version agreement and per-commit monotonicity gates; tests for three/four components, numeric ordering, decrease/equivalent trailing zero, malformed and mismatched values.
- **Correction SHA:** pending commit; see the subsequent correction-evidence entry.
- **Status:** awaiting Claude re-review / human arbitration; not closed.

### Codex proposal for M-06

- **Proposed disposition:** ACCEPT.
- **Reasoning/evidence:** check_versions previously checked agreement only. The new default version-bump gate checks each commit after the phase baseline against every parent, and the staged snapshot against HEAD. A single merge-base-to-HEAD comparison as recommended would miss an omitted bump after an earlier valid bump; the per-commit check closes that case. CI fetches full history and checks actual PR head commits, avoiding synthetic merge metadata. The historical pre-workflow baseline is not retroactively checked.
- **Files changed:** tools/workflow_guard.py; tools/check_release_gates.py; tests/test_workflow_gates.py; .github/workflows/main.yml; AGENTS.md.
- **Tests/checks:** Temporary histories demonstrate omitted bumps, later bumps hiding an earlier failure, decreases, partial staging, renames/deletions, missing history, and checkpoint disagreement. CI runs this gate plus the focused tests.
- **Correction SHA:** pending commit; see the subsequent correction-evidence entry.
- **Status:** awaiting Claude re-review / human arbitration; not closed.

### Codex proposal for M-07

- **Proposed disposition:** ACCEPT.
- **Reasoning/evidence:** Live applicability was constrained only in Phase 00. AGENTS now makes the human its decider in every phase and defines pending_human_determination as an unsatisfied gate. The human records rationale, date, SHA and decision/results in UAT; neither implementation nor reviewer agents may mark required/not-applicable/passed.
- **Files changed:** AGENTS.md; .planning/STATE.md; 00-CONTEXT.md; 00-UAT.md; CLAUDE.md.
- **Tests/checks:** Cross-document authority check. The technical observation that only the version string changes is evidence, not a live applicability decision.
- **Correction SHA:** pending commit; see the subsequent correction-evidence entry.
- **Status:** awaiting Claude re-review / human arbitration; not closed.

### Codex proposal for M-08

- **Proposed disposition:** ACCEPT.
- **Reasoning/evidence:** The generalized contract is now append-only for recorded findings and prior entries, preserving IDs, severity and text. New proposals, correction evidence, re-review and arbitration entries are attributed separately. A Git-backed workflow check rejects rewriting/deleting existing adversarial-review files across committed history and the index. This appendix leaves Claude’s entire original artifact untouched.
- **Files changed:** AGENTS.md; tools/workflow_guard.py; tools/check_release_gates.py; tests/test_workflow_gates.py; appended 00-ADVERSARIAL-REVIEW.md.
- **Tests/checks:** Tests cover append success, severity/text rewrite, deletion, and a later restoration hiding an earlier rewrite. Compare the original review blob as an unchanged byte prefix.
- **Correction SHA:** pending commit; see the subsequent correction-evidence entry.
- **Status:** awaiting Claude re-review / human arbitration; not closed.

### Codex proposal for L-01

- **Proposed disposition:** PARTIALLY ACCEPT.
- **Reasoning/evidence:** A prospective workflow rule cannot certify old main history. AGENTS now applies the requirements to additions from Phase 00 forward and describes the inherited baseline without retroactively claiming independent review or live acceptance. The recommendation to call the old baseline accepted is not used: this pass has no evidence or authority to manufacture that acceptance.
- **Files changed:** AGENTS.md; 00-CONTEXT.md; 00-VERIFICATION.md.
- **Tests/checks:** Verify local and remote main remain the starting SHA; inspect prospective wording.
- **Correction SHA:** pending commit; see the subsequent correction-evidence entry.
- **Status:** awaiting Claude re-review / human arbitration; not closed.

### Codex proposal for L-02

- **Proposed disposition:** ACCEPT.
- **Reasoning/evidence:** The active baseline had three live copies. STATE frontmatter now owns the immutable phase-start SHA, and the current-position prose plus active context reference that field. Review/verification SHAs remain immutable boundary evidence; they must not be rewritten when a future phase starts.
- **Files changed:** AGENTS.md; .planning/STATE.md; 00-CONTEXT.md; tools/workflow_guard.py.
- **Tests/checks:** The history gate reads and validates the full canonical baseline SHA and fails when ancestry is missing. Manual check of the two references.
- **Correction SHA:** pending commit; see the subsequent correction-evidence entry.
- **Status:** awaiting Claude re-review / human arbitration; not closed.

### Codex proposal for L-03

- **Proposed disposition:** PARTIALLY ACCEPT.
- **Reasoning/evidence:** Run selection now filters by push event and exact branch as well as SHA, rechecks all three after watching, and confirms the exact remote branch still points to HEAD. The no-rerun premise is incorrect: gh run rerun retains the original event SHA/ref, so workflow_dispatch is unnecessary and would not be selected by this push-only gate. GitHub documents reruns within 30 days, up to 50 attempts: https://docs.github.com/en/actions/how-tos/manage-workflow-runs/re-run-workflows-and-jobs . CODEX documents rerunning infrastructure failures without a new commit.
- **Files changed:** tools/wait_for_exact_ci.sh; tests/test_workflow_gates.py; CODEX.md; 00-VERIFICATION.md.
- **Tests/checks:** Fake-service tests assert branch/event filters, reject failed push and changed post-watch identities, reject dirty worktree and SHA available only on another remote ref. Live exact-SHA gate still required.
- **Correction SHA:** pending commit; see the subsequent correction-evidence entry.
- **Status:** awaiting Claude re-review / human arbitration; not closed.

### Codex proposal for L-04

- **Proposed disposition:** PARTIALLY ACCEPT.
- **Reasoning/evidence:** write-all is excessive. The workflow now grants contents: read and pull-requests: write for its existing PR comment step; artifact upload uses the Actions artifact service and does not require the proposed actions: write grant. No new permission or comment action is added. Action documentation: https://github.com/actions/upload-artifact and https://github.com/peter-evans/create-or-update-comment .
- **Files changed:** .github/workflows/main.yml.
- **Tests/checks:** Inspect every token consumer; the pushed correction run will exercise checkout, cached/downloaded test runtime, build and artifact upload under reduced permissions. The existing PR-only comment step is not exercised by a push run.
- **Correction SHA:** pending commit; see the subsequent correction-evidence entry.
- **Status:** awaiting Claude re-review / human arbitration; not closed.

### Codex proposal for L-05

- **Proposed disposition:** ACCEPT.
- **Reasoning/evidence:** The two STRUCTURE descriptions still looked like live GSD generation guidance. They now explicitly label the maps historical output of superseded tooling with no orchestration authority. Other historical research/plan mentions remain provenance under AGENTS.
- **Files changed:** .planning/codebase/STRUCTURE.md; AGENTS.md.
- **Tests/checks:** Search operational docs for GSD instructions and inspect preserved historical references.
- **Correction SHA:** pending commit; see the subsequent correction-evidence entry.
- **Status:** awaiting Claude re-review / human arbitration; not closed.

### Codex proposal for L-06

- **Proposed disposition:** PARTIALLY ACCEPT.
- **Reasoning/evidence:** The one-off sed allow-list entry exists locally and was removed. git ls-files .claude returns no tracked files, and git check-ignore identifies the user’s global ignore rule for **/.claude/settings.local.json. Thus this is local permission residue, not shipped workflow code or an instruction to execute sed. Remaining permissions are untouched. CLAUDE’s tracked startup contract says permissions cannot grant authority, and staged snapshot checks reject unsynchronized version edits.
- **Files changed:** Local ignored .claude/settings.local.json only; CLAUDE.md provides the durable permission/authority distinction.
- **Tests/checks:** Parse local JSON and confirm the stale sed entry is absent. The ignored file is intentionally not force-added; version mismatch tests cover the underlying enforceable invariant.
- **Correction SHA:** pending commit; see the subsequent correction-evidence entry.
- **Status:** awaiting Claude re-review / human arbitration; not closed.

### Arbitration and re-review requests

Human + ChatGPT/Neon arbitration is requested on the qualified premises and
remedies in H-02, H-05, H-06, M-03, L-01, L-03, L-04, and L-06. In particular,
confirm the single Claude-owned review gate, pending Phase 00 namespace entry,
exact-SHA fast-forward authorization, CI identifier handoff sequence, and the
process-only fourth-component version convention. The latter two are explicit
contract corrections proposed under M-03/M-05, not claims of human acceptance.

Claude re-review of the named correction commit is needed for factual closure
of every finding, including inspection of the new Git checks and CI selection.
No agent-side test establishes role identity or human consent. The human still
owns Phase 00 live applicability and every closure/merge decision in UAT.


### Codex correction evidence — 2026-09-04

Correction commit C-00: `7f8a35b27f10654b09d039cb62d3a50f0154ad1a`
(`fix(workflow): correct Phase 00 authority and enforcement gaps`).
Exact-SHA CI: [33924081942](https://github.com/ronh3/boop/actions/runs/33924081942),
attempt 1, `main.yml`, `push`, `phase/00-lightweight-agent-workflow`, exact
head SHA `7f8a35b27f10654b09d039cb62d3a50f0154ad1a`: success.
Mudlet Busted: 1006 successes / 0 failures / 0 errors / 0 pending. Release gates,
25 architecture tests, 19 workflow tests, Muddler build and artifact upload pass.
See 00-VERIFICATION.md for evidence scope and limitations.

This table supplies the now-known correction SHA for each earlier proposal; it
does not replace or modify any finding or proposal. C-00 always means the full
SHA above. Every status remains awaiting Claude re-review / human arbitration.

| Finding | Correction SHA reference | Status |
|---|---|---|
| B-01 | C-00 | awaiting re-review / arbitration |
| B-02 | C-00 | awaiting re-review / arbitration |
| B-03 | C-00 | awaiting re-review / arbitration |
| H-01 | C-00 | awaiting re-review / arbitration |
| H-02 | C-00 | awaiting re-review / arbitration |
| H-03 | C-00 | awaiting re-review / arbitration |
| H-04 | C-00 | awaiting re-review / arbitration |
| H-05 | C-00 | awaiting re-review / arbitration |
| H-06 | C-00 | awaiting re-review / arbitration |
| M-01 | C-00 | awaiting re-review / arbitration |
| M-02 | C-00 | awaiting re-review / arbitration |
| M-03 | C-00 | awaiting re-review / arbitration |
| M-04 | C-00 | awaiting re-review / arbitration |
| M-05 | C-00 | awaiting re-review / arbitration |
| M-06 | C-00 | awaiting re-review / arbitration |
| M-07 | C-00 | awaiting re-review / arbitration |
| M-08 | C-00 | awaiting re-review / arbitration |
| L-01 | C-00 | awaiting re-review / arbitration |
| L-02 | C-00 | awaiting re-review / arbitration |
| L-03 | C-00 | awaiting re-review / arbitration |
| L-04 | C-00 | awaiting re-review / arbitration |
| L-05 | C-00 | awaiting re-review / arbitration |
| L-06 | C-00 (tracked guard); ignored local setting removed outside Git | awaiting re-review / arbitration |

The following evidence commit changes only `.planning/` and preserves package
version 0.1.496.4. Its new exact-SHA CI result is required separately and will
be reported in the final handoff. No finding is finally accepted/resolved/closed
by Codex; Phase 00 remains incomplete, and no merge is authorized.


---

## Claude re-review of the corrected tree — 2026-09-04

**Reviewed final SHA:** `57d98dc51cc7dbd52e77634aa7356b2102888a41`
**Substantive correction SHA:** `7f8a35b27f10654b09d039cb62d3a50f0154ad1a`
**Original implementation reviewed:** `44fb844fe2aadf9d71fd7aa95736f3f336e3af72`
**Original review commit:** `9b47f6409a3ba6e75ff575baafe3020d03a7622a`
**Branch:** `phase/00-lightweight-agent-workflow`
**Reviewer:** Claude (independent adversarial reviewer, `AGENTS.md` Roles And
Authority)
**Disposition:** Factual re-review only. This entry records verification results
against named SHAs. It does not arbitrate policy, determine live applicability,
authorize a merge, or close Phase 00. Codex's proposed dispositions were not
accepted on the basis that Codex agreed with a finding; each was re-derived from
the final tree.

### Scope and method

Reviewed the **final tree at `57d98dc`**, verifying each original finding against
the correction introduced at `7f8a35b`. Inspected `9b47f640..7f8a35b` (21 files,
+902/-71) and `7f8a35b..57d98dc` (2 files, +91/-0, planning-only), the full
current text of `AGENTS.md`, `CLAUDE.md`, `CODEX.md`, `README.md`, `DESIGN.md`,
`.planning/STATE.md`, `.planning/ROADMAP.md`, `REFACTOR-ROADMAP.md`,
`.planning/codebase/STRUCTURE.md`, `00-CONTEXT.md`, `00-VERIFICATION.md`,
`00-UAT.md`, `.github/workflows/main.yml`, `tools/workflow_guard.py`,
`tools/check_release_gates.py`, `tools/wait_for_exact_ci.sh`, and
`tests/test_workflow_gates.py`.

Prose claims were not accepted as enforcement. Every mechanical claim was
re-derived by executing the guards against constructed violations in a scratch
clone of `57d98dc`, discarded afterwards. Green CI was again not treated as
evidence that the workflow design is correct.

### Independently reproduced facts

| Check | Result |
|---|---|
| Local `HEAD` and `origin/phase/00-lightweight-agent-workflow` | both `57d98dc5…`; worktree clean |
| Branch provenance | `git merge-base main HEAD` = `a345a34e…` = `origin/main`; unchanged |
| `python3 tools/check_release_gates.py` at `57d98dc` | `[OK]` versions, version-bump, workflow, manifests, state-drift, architecture |
| `python3 tests/test_workflow_gates.py` | 19 tests pass |
| `python3 tests/test_architecture_guard.py` | 25 tests pass (25 modules / 141 edges, root `boop_bootstrap`) |
| Version chain | `0.1.496.3` → `0.1.496.4` at `7f8a35b`; preserved at `57d98dc` (planning-only) |
| Exact-SHA CI for `7f8a35b` | run `33924081942`, attempt 1, event `push`, branch `phase/00-lightweight-agent-workflow`, headSha exact, conclusion `success` — re-fetched independently; matches `00-VERIFICATION.md` |
| Exact-SHA CI for `57d98dc` | run `33924331245`, attempt 1, event `push`, branch `phase/00-lightweight-agent-workflow`, headSha exact, conclusion `success` — not yet recorded in `00-VERIFICATION.md`; recorded here as re-review evidence |
| Original review byte-preservation | `9b47f640` blob (40 853 bytes) is an **exact byte prefix** of the `57d98dc` blob (65 642 bytes) |
| Retired GSD config | `sha256` of `9b47f640:.planning/config.json` equals `sha256` of `57d98dc:.planning/legacy-gsd-config.json.provenance` (`5c5acc83…`); no `.planning/config.json` in the final tree |
| Protected STATE gates | between `9b47f640` and `57d98dc` the only frontmatter changes are `status` (Codex-owned) and a newly initialized `merge_authorization: pending_human_authorization`; `independent_review`, `human_arbitration`, `live_mudlet_validation`, and `phase_closure` are unadvanced |

Codex advanced no gate it does not own, and fabricated no human decision.

### Adversarial probes executed against the new guards

| # | Construction | Result |
|---|---|---|
| 1 | Commit touching `src/` with no version bump | `[FAIL] version-bump` — correctly rejected |
| 2 | Commit decreasing version with all four checkpoints synchronized | `[FAIL] version-bump` — correctly rejected |
| 3 | In-place severity downgrade of recorded findings | `[FAIL] workflow` — correctly rejected |
| 4 | Deletion of the review artifact | `[FAIL] workflow` — correctly rejected |
| 5 | Review rewrite hidden by a later restoring commit | `[FAIL] workflow` on **both** commits — correctly rejected |
| 6 | Restoring `.planning/config.json` | `[FAIL] workflow` — correctly rejected |
| 7 | Staged work on `main`, and on a detached HEAD | `[FAIL] workflow` — correctly rejected |
| 8 | Same work **already committed** on `main`, then gates run | all six `[OK]` — **not** detected (see arbitration item A-1) |
| 9 | No staged changes on `main` (the CI situation) | `[OK] workflow` — branch rule is inert in CI (A-1) |
| 10 | Advance `main_baseline` past a violating commit | all six `[OK]` — **new finding N-01** |
| 11 | Fabricated human decisions written into `00-UAT.md` | all six `[OK]` — **new finding N-02** |
| 12 | `independent_review`/`human_arbitration` forged to `complete` | all six `[OK]` — disclosed identity limit (A-1) |

Probes 1–7 confirm the new guards enforce what they claim. Probes 8–12 bound
what they do **not** cover.

### Result for every original finding

Classification is of the **corrected final tree at `57d98dc`**. "Contract-level"
means the invariant is carried by prose that no mechanical check enforces;
"mechanical" means a guard rejects the violation.

#### Blockers

**B-01 — Codex can accept its own findings — VERIFIED FIXED (contract-level).**
The `disputed` qualifier is gone. `AGENTS.md` now reads: Codex "may propose
ACCEPT, PARTIALLY ACCEPT, or REJECT and supply evidence, but may not mark any
finding finally accepted, resolved, or closed", with factual closure reserved to
a Claude re-review naming a correction SHA and arbitration reserved to the human,
and "Neither action alone closes a phase." The unowned predicate that created the
implication is removed rather than reassigned. Behaviour matches: Codex's own
appendix labels all 23 entries proposals and leaves every status "awaiting Claude
re-review / human arbitration". No finding was pre-cleared.

**B-02 — Unowned STATE gates — VERIFIED FIXED (contract-level).**
`AGENTS.md` gained a `State Writers And Live Authority` table naming an
authorized writer and required evidence for every field, including the two
previously unnamed gates and a newly added `merge_authorization`. Codex is
limited to factual coordination fields, and "no status value grants acceptance".
`STATE.md` prose mirrors it. Verified above that no protected gate was advanced.
Enforcement is prose only — probe 12 forges both gates with all gates green — but
this is the disclosed and genuinely infeasible case: `AGENTS.md` states outright
that "Git author names do not authenticate a human", and `00-VERIFICATION.md`
repeats it under Limits. Recorded as arbitration item A-1, not as an open defect.

**B-03 — Three-part hole putting unaccepted work on `main` — VERIFIED FIXED
(contract-level, with an advisory mechanical check).**
All three sub-gaps are closed:
1. Authorization now binds a commit: "Human merge authorization must name the
   exact full commit SHA … Only that SHA may land on `main` by fast-forward; do
   not create an unreviewed merge/squash commit. A later branch-tip change
   invalidates authorization", plus a pre-merge requirement to verify the
   authorized SHA equals local and remote phase HEAD and passed exact-SHA CI, and
   a re-gate requirement when `main` cannot fast-forward.
2. The ban is now unqualified in both documents: `AGENTS.md` "No work may be
   committed directly to `main`, including quick fixes, hotfixes, docs, or
   planning. Those tasks use an authorized phase branch … they are not
   exceptions"; `CODEX.md` "do not commit any work directly to `main`".
3. The standing push default is scoped: `CODEX.md` "Commit and push changes only
   to the active phase branch … This default never authorizes a push or merge to
   `main`", and "A version bump does not authorize pushing `main`."

`check_staged_branch` adds real mechanical support: probe 7 rejects staged work
on `main` and on a detached HEAD. Its limits are material and are disclosed
rather than overstated — probe 8 shows an already-committed direct `main` change
passes all gates, and probe 9 shows the check is inert in CI because CI has
nothing staged. It is a voluntary pre-commit check, not branch protection. See
A-1.

#### High

**H-01 — AC5 falsified by its own branch — VERIFIED FIXED.**
AC5 now reads "No command behavior, module boundary, or tracked build artifact is
changed. The only product-source change is the synchronized version bump required
by D-00-06 (including the operator-visible version string)." The self-
contradiction with D-00-06 is resolved, and the final baseline diff confirms the
sole `src/` change is `boop.version`.

**H-02 — `.planning/config.json` as live-looking authority — VERIFIED FIXED.**
Renamed to `.planning/legacy-gsd-config.json.provenance`, verified byte-identical
by `sha256`. `AGENTS.md` states it "must not be loaded as configuration or
restored to `.planning/config.json`", and probe 6 confirms the workflow guard
rejects a restored `.planning/config.json` — a prose rule with a mechanical
backstop. The `gsd/phase-{phase}-{slug}` template, `branching_strategy: "none"`,
`mode: "yolo"`, and the dangling `claude_md_path` survive only inside the retired
provenance blob, which no longer reads as configuration.
One sub-claim of the original finding is **superseded**: I asserted the ship
template "fabricates approval text". Re-read at `57d98dc`, the section is
`"Stakeholder Review & Approval"` with template `"- Product owner approval
pending for {phase_name}."` — it records a pending state and fabricates nothing.
Codex's correction of that premise is accepted; it does not affect the finding's
disposition, which rested on the file's operational appearance.

**H-03 — `README.md` asserted conflicting authority and live GSD execution —
VERIFIED FIXED.** The line now reads "Repository CI is blocking automated
evidence only… CI never authorizes acceptance, closure, or merge", and points to
`AGENTS.md`. `README.md` "Starting A Session" additionally now routes through
`AGENTS.md` and `STATE.md` first rather than `CODEX.md` alone. No "GSD execution"
stage remains in any startup or authority document; the single surviving `GSD`
token across `AGENTS.md`, `CODEX.md`, `CLAUDE.md`, `README.md`, `DESIGN.md`,
`STATE.md`, `ROADMAP.md`, and `STRUCTURE.md` is the explicitly superseded
historical decision line addressed by M-02.

**H-04 — `AGENTS.md` not loaded into Claude sessions — VERIFIED FIXED.**
A tracked root `CLAUDE.md` now exists, importing `@AGENTS.md` and directing the
reader to `.planning/STATE.md` and the active phase context, restating the
source-read-only constraint, the designated artifact, the single Claude-owned
gate, and that "Tool permissions do not grant workflow authority." Verified
operationally rather than by inspection alone: in this session the contract
loaded automatically from `CLAUDE.md`/`AGENTS.md` without being pasted, which is
the failure mode the finding described. Residual, inherent and not a defect: this
mechanism is specific to agents that load `CLAUDE.md`.

**H-05 — "initial review" left Claude free to implement and self-close —
VERIFIED FIXED.** `AGENTS.md` now reads "In every review pass, Claude must not
edit implementation source, tests, or implementation docs. Claude may only append
to the designated adversarial-review artifact and update its own
`independent_review` gate in `STATE.md`", and closure is bounded to "a recorded
re-review of a named correction SHA" — never by implementing the correction. The
adjective that scoped the constraint to one pass is gone, and `CLAUDE.md` repeats
the constraint where a Claude session will actually read it.
Codex's PARTIALLY ACCEPT deviates from my proposed text, which said Claude must
not write state gates at all. The deviation is **correct**: my H-05 remedy and
B-02's remedy were in direct conflict, since B-02 requires `independent_review`
to have a non-Codex owner. Reserving exactly one gate to Claude, with no
authority over the other five, is the coherent resolution. Recorded as
arbitration item A-3 for human confirmation as policy, not as an open defect.

**H-06 — Three live "Phase N" namespaces — VERIFIED FIXED.**
`.planning/ROADMAP.md` now opens with an `Active workflow and phase namespaces`
section indexing Phase 00 as active and incomplete, defines "Hardening Phase N"
and "Refactor Phase N" as distinct namespaces, and states explicitly that
"Refactor Phases 4–5 in Git history do not close Hardening Phases 4–5 here" —
which is precisely the contradiction a startup session would otherwise hit.
`REFACTOR-ROADMAP.md` gained a namespace header stating it does not authorize
starting work, and is now a row in the `AGENTS.md` Durable Artifacts table
("activated only by the current phase context"). `CODEX.md` qualifies the
ambiguous reference as "landed through `REFACTOR-ROADMAP.md` Phase 5".
Codex declined the part of my proposed remedy that would label Phase 00
"completed-scope"; that refusal is correct, since Phase 00 is not complete, and
my wording was loose. Whether Phase 00 should occupy a slot in the hardening
checkbox sequence is a sequencing question for the human (A-4).

#### Medium

**M-01 — Stale Phase 03 handoff inside the state authority — VERIFIED FIXED.**
The block is retitled `Historical Session Continuity` and retained as provenance;
a new current `Session Continuity` section names Phase 00 corrections and the
review/verification/UAT artifacts, and states "Do not resume historical Phase 03
plans or begin refactor Phase 6."

**M-02 — Retained decision naming `wait_for_exact_ci.sh` "final authority" —
VERIFIED FIXED.** The entry is preserved as provenance but prefixed
"[Phase 03 planning; superseded by AGENTS.md — CI is automated evidence only]",
and the historical disclaimer now bars old execution instructions from
controlling "any current or future phase" rather than only Phase 00.

**M-03 — CI evidence required to be recorded and forbidden to be committed —
VERIFIED FIXED.** `AGENTS.md` resolves the contradiction by distinguishing run
*identifiers* from raw evidence: "Commit completed run identifiers and summaries
in `<NN>-VERIFICATION.md` … keep raw CI logs/artifacts in GitHub Actions", and
the recording list now names "CI run ID, attempt, URL, event, branch, and head
SHA in VERIFICATION". `00-VERIFICATION.md` carries a durable identity table.
Independently re-fetched: run `33915198772` and run `33924081942` both match
their recorded rows exactly.
One premise of the original finding is **superseded**: I wrote that the only
record of run `33915198772` was transient session output. It was in fact already
recorded in my own review artifact. Codex's correction is accepted.
The self-reference is handled honestly rather than hidden: an identifier "always
describes its named SHA, never a later evidence commit", so the evidence commit's
own run is reported in handoff. That leaves `57d98dc`'s run `33924331245`
uncommitted at this SHA; it is recorded in this entry instead. The sequence is
sound but inherently recursive — see A-5.

**M-04 — No `00-VERIFICATION.md` or `00-UAT.md` — VERIFIED FIXED.**
Both exist. `00-VERIFICATION.md` separates automated evidence from an explicit
`Limits` section that concedes the checks "cannot authenticate human or reviewer
identities, protect remote main against a privileged bypass, or infer gate
approval from Git author names", and that the staged-branch check "is not a
server-side branch protection rule". `00-UAT.md` is a pending-only scaffold; no
human decision is manufactured in it. The candour of the Limits section is worth
noting — it states the residual risks accurately rather than claiming coverage.

**M-05 — Version used contradicted `CODEX.md`'s own convention — VERIFIED
FIXED.** The convention is rewritten so that fourth components "identify builds
and never imply review, test, acceptance, or closure status", with process-only
phases permitted to use them. The contradiction is removed by correcting the
convention rather than by renumbering, and `DESIGN.md`'s conflicting
"bump on every commit/merge" rule now delegates to staged-path classification.
This is a deliberate contract change and Codex flagged it for confirmation (A-6).

**M-06 — Version rule prose-only; nothing enforced classification or
monotonicity — PARTIALLY FIXED.** The enforcement genuinely exists and works.
`tools/workflow_guard.py` adds `check_version_history`, wired as the default
`version-bump` gate and run in CI, with `fetch-depth: 0` and a checkout of the
real PR head rather than GitHub's synthetic merge commit. It checks every commit
since the phase baseline against its parent (and every parent of a merge) plus
the staged snapshot against HEAD, so a later valid bump cannot mask an earlier
omission. Probe 1 rejects an omitted bump; probe 2 rejects a decrease; the
four-checkpoint agreement check is preserved inside `version_at`.
Classified PARTIALLY FIXED because the guarantee is conditional: probe 10 shows
the whole check can be silently switched off by advancing `main_baseline`, a
field the constrained party owns. See **N-01**.

**M-07 — Live-Mudlet applicability undefined and phase-scoped — VERIFIED
FIXED.** The rule moved from `00-CONTEXT.md` into `AGENTS.md`, generalized to
"For every phase", assigns the determination to the human with date, rationale
and applicable SHA recorded in `<NN>-UAT.md`, defines the previously undefined
`pending_human_determination` as "an unsatisfied gate", and states that Codex and
Claude "may supply technical evidence but may not make that determination or mark
live testing passed". The authority order line was also amended to "human
determination of live applicability and required Mudlet validation". Consistent
in practice: `00-UAT.md` supplies technical evidence that a live test "appears
technically unnecessary" while explicitly stating "This observation does not
determine live applicability."

**M-08 — Review-artifact edit rights, severity integrity, re-review unspecified —
PARTIALLY FIXED.** The rule generalized into `AGENTS.md` ("append-only after a
review is recorded. No actor may rewrite or delete an existing finding's ID,
severity, text, or prior entries") and, unusually for this class of rule, is
mechanically enforced: probes 3, 4 and 5 confirm `check_review_transition`
rejects in-place severity downgrades, deletion, and a rewrite hidden behind a
later restoring commit, checking every commit and every merge parent. Closure
authority is now assigned explicitly.
Classified PARTIALLY FIXED for the same reason as M-06: probe 10 shows advancing
`main_baseline` silently disables this guard too, and in that probe every
`Blocker` severity in this artifact was downgraded to `Low` with all six gates
reporting `[OK]`. See **N-01**.

#### Low

**L-01 — `main` invariant asserted as already true — VERIFIED FIXED.**
Now scoped prospectively: "From Phase 00 forward, additions to `main` require
independent review, human arbitration/authorization, and the human-recorded live
applicability decision … The pre-workflow baseline named in the Phase 00 state is
inherited history, not retroactively certified by this rule." Codex declined my
suggestion to call the baseline "accepted"; that refusal is correct, since no
such acceptance occurred, and the resulting wording is more accurate than my
proposed remedy.

**L-02 — `main_baseline` duplicated with no owner — VERIFIED FIXED.**
`STATE.md` frontmatter is now the single owner; `00-CONTEXT.md` and the STATE
prose reference it instead of restating the SHA, and `AGENTS.md` records that
historical review/verification SHAs remain immutable boundary evidence. Note the
interaction: consolidating the baseline into one writable field is also what made
**N-01** reachable. The consolidation is right; the gate must stop trusting it.

**L-03 — Run-selection ambiguity and no re-gate path — VERIFIED FIXED.**
`tools/wait_for_exact_ci.sh` now derives the branch, validates it against
`main|phase/<n>-<slug>`, filters discovery by `--commit`, `--branch` and
`--event push`, and after watching re-verifies `headSha`, `event`, `headBranch`,
local HEAD, current branch, worktree cleanliness, and that the exact remote ref
still points at the SHA; it reports run id and attempt. The PR-versus-push
ambiguity is closed at both selection and verification.
My second premise is **superseded**: I claimed an infrastructure failure could
not be re-gated without a new commit. Codex is factually right that
`gh run rerun` creates a new attempt against the original run's event and SHA, so
`workflow_dispatch` is unnecessary — and would in any case now be excluded by the
`event == push` filter. `CODEX.md` documents the rerun path. The corrected
behaviour is better than my proposed remedy.

**L-04 — `permissions: write-all` on every `phase/**` push — VERIFIED FIXED.**
Replaced with `contents: read` and `pull-requests: write`. I checked each token
consumer in the final workflow: the release-asset download uses `github.token`
against this repository's own release (`contents: read` suffices);
`actions/upload-artifact@v4` uses the Actions artifact service and needs no
scope; `peter-evans/create-or-update-comment@v4` is gated on
`github.event_name == 'pull_request'` and needs `pull-requests: write`. The grant
now matches actual use.
Two residuals, neither a defect. (a) Job-level permissions mean push runs also
carry `pull-requests: write` although only the PR-gated step uses it; the
smallest further hardening would be to move that step into its own job so the
build job keeps `contents: read` alone. (b) `00-VERIFICATION.md` correctly
discloses that the correction run hit the Mudlet runtime cache, so the
release-download path was not exercised under the reduced grant.

**L-05 — `.planning/codebase/` self-described as GSD output — VERIFIED FIXED.**
Both lines now read "Historical … from superseded tooling", one adding "no
orchestration authority".

**L-06 — Stale hardcoded version-bump permission — VERIFIED FIXED (locally, not
verifiable from Git).** The stale `0.1.491`→`0.1.492` `sed` entry is absent from
`.claude/settings.local.json`. Confirmed that the file is untracked
(`git ls-files .claude` is empty) and ignored by the user's global ignore rule,
so this correction is not durable repository state and cannot be re-verified by a
future reviewer from the tree. Codex's PARTIALLY ACCEPT framing is accurate. The
durable part of the remedy is `CLAUDE.md`'s statement that tool permissions do
not grant workflow authority.

### New findings introduced or left open by the corrective pass

These are new IDs in the `N-` namespace so they cannot be confused with the
original 23. Provenance is stated for each.

#### N-01 — The version-bump and review-preservation gates can be silently disabled by advancing `main_baseline`

- **Severity:** High
- **Introduced by:** the corrective pass (`7f8a35b`); the guard is new code
- **Location:** `tools/workflow_guard.py:61-68` (`phase_baseline`), consumed by
  `transitions` (`:71-73`), `check_version_history` (`:76-87`), and
  `check_workflow` (`:118-130`)
- **Violated invariant:** the guarantees the corrective pass created for M-06
  ("every package-affecting commit increases the numeric version") and M-08 ("no
  actor may rewrite or delete an existing finding's ID, severity, text, or prior
  entries"). A gate's coverage window must not be settable by the party the gate
  constrains.
- **Problem:** `phase_baseline` reads `main_baseline` from the **working-tree**
  `.planning/STATE.md` and validates only that it is *an ancestor of HEAD*
  (`git merge-base --is-ancestor base HEAD`). Every commit on the phase branch
  satisfies that. `main_baseline` is, per the `AGENTS.md` writer table, a
  Codex-writable coordination field, and moving it is a planning-only edit that
  preserves the version and therefore passes every other gate. Nothing anywhere
  ties the declared baseline to `origin/main`: it is referenced only in
  `workflow_guard.py` and the tests, and `check_state_drift` does not inspect it.
- **Failure scenario (reproduced, probes 10 and 4):** Commit a change to
  `src/scripts/boop/boop_init.lua` with no version bump — `[FAIL] version-bump`.
  Then commit a one-line planning-only edit setting `main_baseline` to that
  commit's SHA. All six gates now report `[OK]` with the unbumped
  package-affecting change still in the tree. The same edit hides review
  tampering: after an in-place rewrite downgrading every `Blocker` in this
  artifact to `Low`, advancing `main_baseline` past it returns `[OK] workflow`,
  and the tampered severities stand. CI reproduces this, because CI runs the same
  script and derives the baseline from the same checked-out file.
- **Why it matters here:** these two guards are the only mechanically enforced
  invariants the corrective pass added. Reducing them to self-declared scope
  returns M-06 and M-08 to prose while CI continues to report green.
- **Smallest correction:** in `phase_baseline`, additionally require that the
  declared baseline be reachable from `main` — e.g. assert
  `git merge-base --is-ancestor <base> origin/main` (falling back to `main`)
  alongside the existing HEAD-ancestry assertion, and fail closed when the ref is
  unavailable. Verified feasible against the current tree: `a345a34e…` is an
  ancestor of `origin/main`, so the legitimate baseline passes, while a
  branch-only commit like the one in probe 10 does not. CI already uses
  `fetch-depth: 0`, so the ref is present. A focused test alongside the existing
  19 would pin it.

#### N-02 — `<NN>-UAT.md` carries the highest-authority decisions with no tamper guard

- **Severity:** Medium
- **Introduced by:** the corrective pass; `00-UAT.md` was created at `7f8a35b`
  under M-04, and `AGENTS.md` simultaneously made UAT the evidence home for the
  human-only live, closure, and merge-authorization gates
- **Location:** `tools/workflow_guard.py:90-104` (`check_review_transition`),
  which matches only `.planning/phases/**/*-ADVERSARIAL-REVIEW.md`;
  `.planning/phases/00-lightweight-agent-workflow/00-UAT.md`
- **Violated invariant:** `AGENTS.md` State Writers table — `phase_closure` and
  `merge_authorization` are "Human only, citing … in UAT", and merge
  authorization must name an exact full SHA. The record those gates cite must be
  at least as tamper-evident as the review findings.
- **Problem:** the corrective pass built an append-only guard and applied it to
  the review artifact only. `00-UAT.md`, which now holds live applicability,
  phase closure, and the exact-SHA merge authorization, is unguarded — as are
  `<NN>-VERIFICATION.md` and the `STATE.md` gates themselves. This is an
  asymmetry within the new code, not an inherent limit: unlike role
  authentication, extending the existing prefix check is straightforward.
- **Failure scenario (reproduced, probe 11):** rewrite `00-UAT.md`'s pending
  fields to read `Live validation required or not applicable: not_applicable` and
  `Authorized exact full SHA for fast-forward to main …: <sha> / Human /
  2026-09-04`, and commit. All six gates report `[OK]`. A later session, or the
  human returning after an interval, reads UAT as the authority `AGENTS.md`
  designates for merge authorization and finds a decision that was never made.
  The review artifact is protected against exactly this forgery; the record that
  actually authorizes a merge is not.
- **Smallest correction:** extend `check_review_transition`'s path predicate to
  cover `-UAT.md` (and, if the human wants evidence integrity too,
  `-VERIFICATION.md`) under `.planning/phases/`, keeping the same
  unchanged-byte-prefix rule so both remain append-only. Note the consequence
  worth the human's decision: a strict prefix rule makes the pending-scaffold
  fields in `00-UAT.md` un-editable in place, so the human's decisions would have
  to be recorded as appended dated entries — which is how `AGENTS.md` already
  requires review dispositions to be recorded. Because that changes how the human
  writes their own record, the remedy is offered for arbitration (A-2) rather
  than as a purely factual defect.

#### N-03 — Running the mandated local gate dirties the worktree the CI gate requires to be clean

- **Severity:** Low
- **Provenance:** **not** introduced by the corrective pass. `check_release_gates.py`
  already imported `architecture_guard` at `44fb844`, so this predates `7f8a35b`
  and is not a regression. It is recorded here because the corrective pass added a
  second imported module (`workflow_guard`) and increased how often the gate is
  mandated, and because the original review did not identify it.
- **Location:** `.gitignore` (absence of a `__pycache__` entry);
  `tools/wait_for_exact_ci.sh:19`
- **Violated invariant:** the mandated sequence in `AGENTS.md` — run
  `python3 tools/check_release_gates.py` before committing and pushing, then run
  `tools/wait_for_exact_ci.sh` — must be executable as written.
- **Problem:** `AGENTS.md` and `CODEX.md` require the release gate to be run
  before every commit and again before every push. Importing `tools/architecture_guard`
  and `tools/workflow_guard` causes CPython to write
  `tools/__pycache__/*.pyc`. `.gitignore` covers `/Basher`, `/Bashing`, `/build`,
  `/Foxhunt`, `.output`, `output.md`, and `UIEXAMPLE.md` — not `__pycache__`. The
  exact-CI gate then fails at `git status --porcelain --untracked-files=all`
  with "worktree is not clean".
- **Failure scenario (observed in this review):** running the mandated gate in a
  clean checkout of `57d98dc` left `tools/__pycache__/architecture_guard.cpython-314.pyc`
  and `workflow_guard.cpython-314.pyc` untracked. Following the documented order
  literally, the next step blocks; the tempting recoveries are to delete the
  files each time or, worse, to commit them — which would make an otherwise
  planning-only commit package-affecting and trip the new `version-bump` gate.
- **Smallest correction:** add `__pycache__/` to `.gitignore`. (Alternatively set
  `PYTHONDONTWRITEBYTECODE=1` in the documented invocation, but the ignore entry
  is smaller and durable.)

### Items requiring human arbitration

These are policy or scope decisions, not factual re-review outcomes. None is
resolved by this entry.

- **A-1 — Enforcement ceiling.** Gate-writer ownership (B-02), the direct-`main`
  ban (B-03), and gate/decision integrity are prose-only, and probes 8, 9 and 12
  bound what Git-side checks can do: an already-committed direct `main` change
  passes all gates, the branch rule is inert in CI, and both protected gates can
  be forged to `complete`. `AGENTS.md` and `00-VERIFICATION.md` disclose this
  accurately. The remaining decision is the human's: whether to add server-side
  GitHub branch protection on `main` (required status checks, no direct pushes,
  and optionally CODEOWNERS review) so that the contract's most important rule
  has an enforcement point outside the repository. Recommended, but outside what
  any repository file can implement.
- **A-2 — N-02 remedy shape.** Whether to extend the append-only guard to
  `<NN>-UAT.md` (and `<NN>-VERIFICATION.md`), accepting that the human's own
  decisions would then be recorded as appended dated entries rather than edited
  in place.
- **A-3 — Claude's single writable gate.** Codex's H-05 resolution gives Claude
  `independent_review` and nothing else, resolving a genuine conflict between my
  H-05 and B-02 remedies. Confirm as policy.
- **A-4 — Phase 00's place in the hardening sequence.** The namespace ambiguity
  is fixed, but whether Phase 00 occupies a numbered slot in
  `.planning/ROADMAP.md`'s checkbox sequence, and how the next phase is selected,
  is human scope authority.
- **A-5 — CI identifier recursion.** The "report the final HEAD's run in handoff,
  persist at the next boundary" sequence is sound and honest, but means the
  reviewed tip's own run is never committed at that tip. `57d98dc`'s run
  `33924331245` is recorded in this entry. Confirm the policy is acceptable.
- **A-6 — Version convention change (M-05).** Redefining fourth components as
  build identifiers carrying no review or acceptance meaning is a deliberate
  contract change Codex flagged for confirmation.
- **A-7 — L-06 durability.** The corrected file is untracked and globally
  ignored, so that correction is not verifiable from the repository by any future
  reviewer.

### Re-review status

- **Reviewed final SHA:** `57d98dc51cc7dbd52e77634aa7356b2102888a41`
- **Substantive correction SHA:** `7f8a35b27f10654b09d039cb62d3a50f0154ad1a`
- **Original findings:** 21 VERIFIED FIXED, 2 PARTIALLY FIXED (M-06, M-08, both
  conditional on N-01), 0 STILL PRESENT, 0 SUPERSEDED / NOT A DEFECT at the
  finding level. Three individual sub-premises — the H-02 approval-template
  claim, the M-03 transient-evidence claim, and the L-03 no-rerun claim — are
  superseded by evidence; Codex was right on all three and the corrected
  behaviour is better than my proposed remedy in L-03.
- **New findings:** 3 — N-01 (High), N-02 (Medium), N-03 (Low, pre-existing and
  explicitly not a regression).
- **Codex conduct check:** the original review is preserved as an exact byte
  prefix, the retired config is a byte-identical rename, no protected gate was
  advanced, no human decision was fabricated, and every disposition is labelled a
  proposal. No finding was self-closed.
- **Independent review:** re-review complete against the named SHAs, with N-01
  and N-02 open.
- **Human arbitration:** pending (A-1 … A-7).
- **Live Mudlet applicability or validation:** pending human determination.
- **Phase closure and merge to `main`:** pending explicit human authorization.
- **Phase 00 is not complete.** Nothing in this entry accepts, closes, or
  authorizes anything.

This re-review commit mutates the repository and therefore invalidates the
exact-SHA CI evidence for `57d98dc` recorded above; per `AGENTS.md` the gate must
be run again by Codex against the new final HEAD.


---

## Human + ChatGPT/Neon arbitration — 2026-09-04

Authority: explicit human instructions supplied through ChatGPT/Neon for this
final corrective pass, starting at `5b4417be62e31800e4f348d14a1948ce95f46112`.
Recorded by Codex at the human’s express direction. The approved policy text
below is reproduced verbatim. This records policy arbitration evidence only;
the human-owned STATE gate is untouched. It grants no phase closure or merge.

A-1 — Enforcement ceiling
Accept the documented limitation that repository-local Git checks cannot
authenticate human-vs-agent identity or reliably block an already-committed
direct-main change. Do NOT make GitHub branch protection/rulesets a Phase 00
blocker. Server-side protection may be added separately later.

A-2 — UAT/evidence integrity
ACCEPT. Extend append-preserving protection to phase UAT and VERIFICATION
artifacts. Human decisions and later evidence must be appended as dated entries,
not written by rewriting historical entries or placeholder text.

A-3 — Claude gate ownership
CONFIRM. Claude's only STATE gate is independent_review.

A-4 — Phase 00 namespace
CONFIRM. Phase 00 is a special workflow/bootstrap phase. It does not consume,
renumber, or automatically advance either the product-hardening or refactor
phase sequences. The human explicitly selects the next phase after Phase 00.

A-5 — CI identifier recursion
ACCEPT the current model: a CI identifier describes its named immutable SHA.
The current final-tip CI run may be reported in the handoff and durably recorded
at a later independently necessary repository boundary. Do not create infinite
evidence-only commits.

A-6 — version fourth component
CONFIRM. Fourth components are build identifiers only. They imply no review,
test, acceptance, or closure status.

A-7 — local Claude settings durability
ACCEPT as a local-only limitation. Do not attempt to track
.claude/settings.local.json. CLAUDE.md / AGENTS.md remain the durable authority.


## Codex final corrective pass evidence — 2026-09-04

Role: Codex, implementation/correction evidence only. Starting reviewed HEAD:
`5b4417be62e31800e4f348d14a1948ce95f46112`. Correction SHA: the commit
containing this appendix; its full SHA and completed CI identity will be appended
at the following evidence boundary. These are correction proposals awaiting
Claude re-review, not final finding dispositions or factual closure.

- **N-01 — proposed ACCEPT:** `phase_baseline` now requires the declared full
  SHA to be an ancestor of both HEAD and `refs/remotes/origin/main`. Missing
  authoritative main/history fails closed. Local main cannot substitute, and
  the unused caller-supplied baseline override is removed from both guards.
  Tests reject phase-only baselines in working-tree, staged, and committed
  states, including attempts to hide an unbumped package commit or rewritten
  review; legitimate main ancestry passes and HEAD ancestry remains required.
  This addresses the baseline bypass underlying M-06 and M-08; Claude must
  establish factual verification against the named correction SHA.
- **N-02 — proposed ACCEPT:** the unchanged-prefix guard now covers UAT and
  VERIFICATION from creation, across committed transitions, every merge parent,
  and the index. It also rejects deletion of an initially empty artifact. Tests
  cover changed/deleted history, replacement of an existing synthetic human
  decision, later restoration hiding tampering, and allowed dated appends.
  AGENTS documents this model; the UAT scaffold is retained byte-for-byte with
  appended recording instructions. New-entry authorship remains the accepted
  A-1 enforcement limit; tests make no claim to authenticate a human.
- **N-03 — proposed ACCEPT:** `.gitignore` now ignores `__pycache__/` and
  `*.pyc`. Running the required Python gates creates ignored caches with no
  untracked cache output. A fresh-checkout cleanliness check and the real
  release-gate → push → exact-SHA-CI sequence will be recorded after commit.

Local checks: all six release gates, 30 workflow tests (including 11 new tests),
25 architecture tests, shell syntax and whitespace checks pass. Package version
checkpoints advance together to `0.1.496.5`; only the version assignment changes
under `src/`. Full Muddler/real-Mudlet automated verification uses CI because
`/tmp/Mudlet.AppImage` is unavailable locally. See `00-VERIFICATION.md`.

All preceding Claude/Codex review text and both prior evidence artifacts remain
unchanged byte prefixes. STATE is entirely untouched, including Claude’s review
gate and every human-owned gate. Human/Neon must perform or explicitly authorize
the separate `human_arbitration` STATE write referencing the arbitration above.
Live applicability, phase closure and exact-SHA merge authorization still require
human action; no gameplay change, phase transition, closure or merge is made.
