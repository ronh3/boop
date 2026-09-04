# Phase 00: Lightweight Multi-Agent Workflow - Context

**Branch:** `phase/00-lightweight-agent-workflow`
**Main baseline:** `a345a34ea0da2eed6f5bfe1c5e586488749a3e22`
**Status:** Implementation ready for independent review after the branch is pushed

## Phase Boundary

Establish the minimum durable repository contract for a lightweight Boop
workflow shared by the human, ChatGPT/Neon, Codex, Claude, and Mudlet. Reuse the
repository's existing requirements, architecture, phase-context, verification,
review, UAT, and state artifacts rather than introducing another documentation
tree or an orchestration framework.

This is a repository-process bootstrap phase. It does not change product
behavior, begin the product roadmap's Phase 6, or alter architecture ownership.

## Requirements

- Define each role and its authority, including that Codex cannot declare live
  acceptance or phase completion and that Claude's initial review is
  source-read-only.
- Establish the required authority order from specification through human and
  live Mudlet acceptance to phase closure.
- Name the existing authoritative artifact for active scope, architectural and
  project decisions, current state, automated verification, independent review
  and disposition, and live validation.
- Require active work on pushed `phase/<number>-<short-description>` branches.
- Keep `main` limited to completed, reviewed, human-authorized, live-validated
  phases.
- Preserve meaningful implementation, review, and correction commit
  boundaries without requiring a commit for every edit.
- Require explicit human authorization before merging a phase to `main`.
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
5. No product source, command behavior, module boundary, or build artifact is
   changed.
6. Repository release gates pass, the branch is pushed, and exact-SHA CI is
   recorded as automated evidence only.
7. Review, human arbitration, live-applicability/validation, phase closure, and
   merge to `main` remain pending human-controlled stages.

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
- **Initial review:** Pending Claude review of an exact pushed commit.
- **Human arbitration:** Pending.
- **Live Mudlet applicability or validation:** Pending human decision; Codex
  may not mark it not-applicable or passed.
- **Phase closure and merge to `main`:** Pending explicit human authorization.
