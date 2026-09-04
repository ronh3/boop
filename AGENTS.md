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
- **Claude** is the independent adversarial reviewer. Claude's initial review
  must not modify implementation source. Claude may add or update the phase's
  designated adversarial-review artifact.
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
  -> live Mudlet validation
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
| Milestone sequencing | `.planning/ROADMAP.md` |
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
framework has authority over this workflow.

The adversarial-review artifact identifies the exact reviewed commit, preserves
finding IDs and severity, and records each disposition and correction commit.
Claude owns the initial findings. Codex may record proposed dispositions and
correction evidence but may not mark disputed findings accepted or the phase
closed. Human arbitration is recorded explicitly instead of overwriting the
review history.

## Phase And Git Workflow

- `main` is the latest completed, independently reviewed, human-authorized, and
  live-validated phase.
- Active work occurs on `phase/<number>-<short-description>`, created from the
  current `origin/main`. The matching context file and `.planning/STATE.md`
  must name that branch.
- Push phase branches to `origin` at meaningful specification,
  implementation, review, and correction boundaries so every agent reviews the
  same commit.
- Commit coherent boundaries, not every trivial edit. Review-artifact-only and
  correction commits should remain distinguishable from the implementation
  commit they assess.
- Never rebase or force-push a published phase branch without explicit human
  approval. Incorporate concurrent remote work with the safest non-rewriting
  method and escalate genuine conflicts.
- Codex must not merge a phase to `main` until the human explicitly authorizes
  it after review, arbitration, and required live Mudlet validation.
- Record the reviewed SHA, correction SHA, live result, and closure authority
  in the existing phase artifacts. A branch name or green CI result alone is
  not phase acceptance.

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
  `python3 tools/check_release_gates.py`.

## Verification And Terminal CI

- Automated verification must match the risk and acceptance criteria in the
  active specification. Behavior changes need focused tests plus the relevant
  regression suite.
- After all repository mutations for a boundary are complete, Codex pushes the
  immutable final HEAD and runs `tools/wait_for_exact_ci.sh`.
- The exact-SHA CI gate is blocking automated evidence. CI evidence is reported
  but not committed; any later repository mutation invalidates it and requires
  another run.
- Successful automated verification does not authorize live acceptance, phase
  closure, or merge to `main`.

## Repository Discipline

- Work only under `src/` for package content; never edit built artifacts.
- Keep user-facing docs and command help in sync with command-surface changes.
- Prefer polish, consistency, operator clarity, and stability over feature
  expansion.
