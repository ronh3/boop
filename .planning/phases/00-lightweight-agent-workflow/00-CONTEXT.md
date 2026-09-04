# Phase 00: Lightweight Multi-Agent Workflow - Context

**Branch:** `phase/00-lightweight-agent-workflow`
**Main baseline:** See `.planning/STATE.md` frontmatter `main_baseline`.
**Status:** Corrections awaiting Claude re-review and human arbitration; not complete.

## Phase Boundary

Establish the minimum durable repository contract for a lightweight Boop
workflow shared by the human, ChatGPT/Neon, Codex, Claude, and Mudlet. Reuse the
repository's existing requirements, architecture, phase-context, verification,
review, UAT, and state artifacts rather than introducing another documentation
tree or an orchestration framework.

This is a repository-process bootstrap phase. It does not change product
behavior, begin the `REFACTOR-ROADMAP.md` Phase 6, or alter architecture ownership.

## Requirements

- Define each role and its authority, including that Codex cannot declare live
  acceptance or phase completion and that Claude's reviewer role is
  source-read-only in every pass.
- Establish the required authority order from specification through human and
  live Mudlet acceptance to phase closure.
- Name the existing authoritative artifact for active scope, architectural and
  project decisions, current state, automated verification, independent review
  and disposition, and live validation.
- Require active work on pushed `phase/<number>-<short-description>` branches.
- From this bootstrap forward, additions to `main` require review, human
  authorization, and human-determined live applicability/required validation.
- Preserve meaningful implementation, review, and correction commit
  boundaries without requiring a commit for every edit.
- Require explicit human authorization naming the exact SHA before a
  fast-forward to `main`; any later branch-tip change invalidates authorization.
- Prohibit all direct commits to `main`, including quick fixes and hotfixes.
- Do not introduce GSD or any other orchestration framework.

## Acceptance Criteria

1. `AGENTS.md` is the concise authority and lifecycle contract for every agent.
2. `.planning/STATE.md` identifies the active branch and this specification.
3. Existing `REQUIREMENTS.md`, architecture documents, `STATE.md`, per-phase
   `CONTEXT`, `VERIFICATION`, `ADVERSARIAL-REVIEW`, and `UAT` artifacts are
   reused with unambiguous ownership.
4. Claude can record initial findings in
   `.planning/phases/00-lightweight-agent-workflow/00-ADVERSARIAL-REVIEW.md`
   without editing implementation source.
5. No command behavior, module boundary, or tracked build artifact is changed.
   The only product-source change is the synchronized version bump required
   by D-00-06 (including the operator-visible version string).
6. Repository release gates pass, the branch is pushed, and exact-SHA CI is
   recorded as automated evidence only.
7. Claude owns independent review; the human owns arbitration, live
   applicability/validation, closure, and exact-SHA merge authorization.
   Corrections do not grant acceptance or complete this phase.

## Decisions

- **D-00-01:** Reuse per-phase `CONTEXT.md` as the active specification; do not
  add a parallel `ACTIVE.md` or specification registry.
- **D-00-02:** Reuse `ARCHITECTURE.md`, `ARCHITECTURE-RULES.md`,
  `TARGET-ARCHITECTURE.md`, and `.planning/PROJECT.md`; do not add an ADR
  directory unless a future decision cannot fit an existing authority.
- **D-00-03:** Use one append-preserving adversarial review artifact per phase.
  Findings, proposed dispositions, correction evidence, and human arbitration
  remain distinguishable inside it.
- **D-00-04:** Reuse `VERIFICATION.md` for automated evidence and `UAT.md` for
  human-directed live Mudlet evidence; neither is replaced by CI status.
- **D-00-05:** Treat existing GSD-named metadata as historical provenance only.
  The repository workflow is the plain-file contract in `AGENTS.md` and does
  not invoke an orchestration framework.
- **D-00-06:** Because this phase changes repository files outside
  `.planning/`, it follows the existing package-affecting version rule even
  though it changes no runtime behavior.

## Review And Closure

- **Designated review artifact:**
  `.planning/phases/00-lightweight-agent-workflow/00-ADVERSARIAL-REVIEW.md`
- **Initial review:** Claude reviewed `44fb844fe2aadf9d71fd7aa95736f3f336e3af72`;
  original findings are preserved in the designated artifact. Corrections await
  re-review and human arbitration; Codex proposals are not final dispositions.
- **Human arbitration:** Pending.
- **Live Mudlet applicability or validation:** Pending human decision; Codex
  may not mark it not-applicable or passed.
- **Phase closure and merge to `main`:** Pending explicit human authorization.


## Human-authorized final corrective scope — 2026-09-04

The human approved A-1 through A-7 verbatim in the dated Human + ChatGPT/Neon
arbitration entry in `00-ADVERSARIAL-REVIEW.md`. This pass addresses N-01
(trusted main-history baseline), N-02 (append-preserving UAT and verification
records), and N-03 (ignored Python caches), with focused tests and exact-SHA CI.
Phase 00 is a special workflow/bootstrap phase: it does not consume, renumber,
or automatically advance either the hardening or refactor sequence. The human
explicitly selects the next phase. Claude re-review and human-owned STATE gate
actions remain separate; this corrective scope does not close Phase 00.
