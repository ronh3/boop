# Phase 00 — Human live applicability and acceptance record

Status: pending human determination. This scaffold records no acceptance.
Writer for decisions and results: human, under `AGENTS.md`.

## Technical evidence supplied by Codex (2026-09-04)

The only package-source diff against the inherited main baseline is the
`boop.version` string; metadata/title/checkpoint advance with it. Workflow docs,
CI selection/permissions, and host Git checks do not change gameplay execution.
No tracked build artifact, command behavior, or module boundary changes.
A live gameplay regression test therefore appears technically unnecessary for
this diff; checking the displayed version after import remains a possible human
choice. This observation does not determine live applicability. Automated
Mudlet Busted results belong in VERIFICATION and cannot fill this gate.

## Human decision — pending

- Applicable exact full SHA: pending
- Human name/date and decision evidence: pending
- Live validation required or not applicable: pending
- Rationale and required checks, if any: pending
- Live results and unresolved regressions: pending

## Human closure and merge authorization — pending

- Review/correction SHA and arbitration entry: pending
- Accepted exact full SHA and closure authority/date: pending
- Authorized exact full SHA for fast-forward to main and authority/date: pending

Only the human may fill these decisions and update the corresponding STATE
gates. Any later phase-tip change invalidates merge authorization. Phase 00 is
not complete; no merge is authorized by this artifact.


## Append-only recording instructions — Codex, 2026-09-04

Under the human-approved A-2 policy recorded in `00-ADVERSARIAL-REVIEW.md`,
all existing text above, including pending placeholders, remains unchanged.
The earlier instruction to “fill these decisions” is to be carried out by
appending dated, attributed entries below, not by editing those fields.

For each future human entry, record the human name and date, applicable full
SHA, decision and rationale, required checks and results where applicable, and
references to review/arbitration evidence. Closure and merge authorization each
require their own explicit human decision and exact full SHA. Corrections to
earlier records must identify the prior entry and append the correction.
The human updates the corresponding STATE gates with that evidence.

This is a recording instruction only. Codex makes no live-applicability,
validation, closure, or merge decision; all those gates remain pending.


## Human Phase 00 closure decisions — 2026-09-04

Authority: explicit human decisions supplied for mechanical recording in the
Phase 00 closure-bookkeeping instruction. Codex records these decisions without
reinterpretation or additional authority.

### Human arbitration

Human arbitration for Phase 00 is **complete**. A-1 through A-7 are approved
exactly as recorded in the dated **Human + ChatGPT/Neon arbitration —
2026-09-04** entry in `00-ADVERSARIAL-REVIEW.md`.

### Live Mudlet applicability

- Decision: `not_applicable`.
- Applicable reviewed SHA:
  `f244be0eec92057e35e730c5c32db9b2acdc3312`.
- Rationale: Phase 00 changes repository workflow, CI/tooling, documentation,
  planning artifacts, and synchronized version metadata. It does not change
  gameplay behavior, command behavior, combat logic, module ownership behavior,
  or Mudlet runtime functionality.
- Automated real-Mudlet/Busted evidence remains verification evidence and is
  not being substituted for a required live gameplay gate. The human has
  determined that no live gameplay gate is required for this process-only
  phase.

### Phase closure

- Decision: Phase 00 is **approved for closure**.
- Accepted independently reviewed SHA:
  `f244be0eec92057e35e730c5c32db9b2acdc3312`.
- The commit containing this entry is closure bookkeeping only and does not
  alter the reviewed implementation or workflow behavior.

### Phase 00 exact-SHA merge-authorization exception

The merge is not authorized or performed by this entry. For Phase 00 only, the
human approved this external exact-SHA authorization mechanism to avoid a
self-referential commit loop:

1. This commit records arbitration, live applicability, and closure.
2. After this commit is pushed and passes exact-SHA CI, its resulting full SHA
   becomes the merge candidate.
3. The human must then explicitly authorize that exact SHA.
4. That authorization is recorded outside the commit tree using an annotated
   Git tag named `phase-00-approved`.
5. The annotated tag must target exactly the authorized closure-bookkeeping SHA
   and record the human authorization and date in its message.
6. Only the commit targeted by that tag may fast-forward `main`.
7. No later branch mutation may be included without repeating the required
   gates and obtaining new authorization.

Merge authorization remains pending. No annotated approval tag has been created
by this decision entry, and no merge has occurred.
