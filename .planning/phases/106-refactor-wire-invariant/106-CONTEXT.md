# Workflow Phase 106: Refactor Phase 6 — Complete the Wire Invariant

**Branch:** `phase/106-refactor-wire-invariant`
**Main baseline:** See `.planning/STATE.md` frontmatter `main_baseline`.
**Status:** Human-authorized phase bootstrap; source implementation not yet authorized.

## Identity And Namespace

This context activates **REFACTOR-ROADMAP Refactor Phase 6 — Complete the Wire
invariant**. It does not activate or consume Hardening Phase 6 (Docs, Help, and
Live Release Verification) in `.planning/ROADMAP.md`.

The workflow identifier `106` exists only to prevent branch, context, evidence,
and approval-tag namespace collisions between the repository's separate
hardening and refactor Phase 6 sequences. References to Phase 106 in workflow
artifacts therefore mean Refactor Phase 6.

## Fixed Scope

### Primary invariant

`boop.wire` is the only production caller of `send()` and `sendGMCP()`. There is
no second sanctioned production sender.

### Current measured boundary

Implementation must use the current inventory in `ARCHITECTURE.md` §6 as truth,
not blindly copy the older line-number inventory in `REFACTOR-ROADMAP.md`.

- There are 16 production `send()` calls across nine files.
- One is already the raw Wire dispatcher call, so 15 non-Wire `send()` calls
  require migration.
- The inventory includes `src/aliases/boop/Targeting/IH.lua`.
- The room-item request `send(" ")` site now lives in `boop_room.lua` after
  Refactor Phase 5.
- Eight `sendGMCP()` calls remain across `boop_init.lua`, `boop_skills.lua`, and
  `boop_room.lua`.

Line numbers are evidence snapshots, not durable scope. Before implementation,
re-measure all executable Lua under `src/`, including aliases and triggers.

### Required transport design

Wire must expose distinct, concern-appropriate APIs for:

- owned combat dispatch;
- unowned utility commands;
- queue control;
- channel text; and
- protocol requests.

Unrelated commands must not be forced through the Standard dispatch lifecycle
merely to centralize egress. Exact ownership and lifecycle semantics stay with
the concern that already owns them; Wire is the audited transport boundary.

### Required structural work

The implementation phase must:

1. Add or complete Wire outbound registration and observation machinery.
2. Migrate every remaining production `send()` caller through Wire.
3. Migrate every production `sendGMCP()` caller through Wire.
4. Preserve `boop.executeAction` as the justified external compatibility
   forwarder while moving internal transport through Wire.
5. Keep target identity caller-supplied; Wire must not depend on Targets or read
   targeting state to discover the target.
6. Extract `boop_standard.lua` from Runtime for queued-Standard lifecycle
   ownership: dispatch generations, baseline, candidate buffering and
   disposition, grace, retry and recovery, terminals, and mutation barrier.
7. Update the script manifest and load order as required by the new Standard
   module, preserving documented load-time behavior.
8. Narrow architectural `send()` and `sendGMCP()` guardrails so only
   `boop_wire.lua` may call the Mudlet primitives directly.

The proposed `boop.standard` module is justified by lifecycle ownership and
strong cohesion. Wire remains a transport boundary, not a replacement owner for
Standard state transitions.

### F4 investigation boundary

Investigate `markUnnamableMaulUsed` for direct versus queued dispatch. Determine
whether the trigger-driven `boop.rage.onHoundMaulUsed` and
`boop.rage.onHyenaMaulUsed` paths already cover queued dispatch, and record the
factual result in phase evidence.

This phase does **not** authorize an F4 behavior change. If the queued path is
factually uncovered, propose a separate change for Human + ChatGPT/Neon
approval; do not implement it under this context.

## Compatibility And Behavior Contract

This is a behavior-preserving refactor. It must:

- preserve S1 alias syntax and semantics;
- preserve exact command text and ordering;
- preserve queue timing and queue-control semantics;
- preserve `settarget` synchronization behavior;
- preserve the complete queued-Standard lifecycle behavior;
- preserve GMCP payloads and request sequencing;
- preserve IH alias ordering, with `boop.ih.start()` before outbound `ih`; and
- introduce no unapproved observable behavior change.

Wire APIs may make ownership explicit, but they may not coalesce, reorder,
retime, validate differently, or reinterpret existing outbound traffic.

## Acceptance Criteria

1. Covered regression cases observe byte-identical outbound game commands and
   protocol payloads in the same order and at the same lifecycle boundaries.
2. Production source contains exactly one primitive `send(` call, in
   `boop_wire.lua`.
3. Production source contains exactly one primitive `sendGMCP(` call, in
   `boop_wire.lua`.
4. The architecture guard enforces both single-egress invariants and rejects
   evasion through aliases or indirect primitive capture under the repository's
   supported static-reference convention.
5. `boop_standard.lua` owns the queued-Standard lifecycle named in this context,
   and Runtime no longer owns that lifecycle implementation.
6. Wire has no dependency on Targets; target identity remains caller-supplied.
7. S1 alias semantics, command bytes/order, queue behavior, target sync, GMCP
   payloads/sequencing, and IH ordering are unchanged.
8. The full relevant regression suite, architecture guard tests, manifest
   checks, and release gates are green.
9. Measured dependency, reciprocal-pair, and SCC evidence is recorded. There is
   no SCC-monotonicity requirement before Refactor Phase 8.
10. The F4 investigation result is recorded without an unapproved behavior fix.

## Required Verification Emphasis

At minimum, implementation verification must include:

- `boop_prequeue_spec`
- `boop_assist_spec`
- `boop_tick_spec`
- `boop_interrupt_spec`
- `boop_pull_spec`
- `boop_gold_spec`
- `boop_safety_spec`
- `boop_target_call_spec`
- `boop_whitelist_share_spec`
- `boop_rage_ingestion_spec`
- `boop_event_transitions_spec`
- `boop_trace_spec`
- architecture-guard tests
- manifest and release gates

Focused tests must compare exact outbound command strings, protocol payloads,
ordering, queue-control classification, ownership registration, and relevant
Standard lifecycle terminals. The full real-Mudlet Busted suite and Muddler
build remain automated evidence; live applicability and any required Mudlet
validation remain a human decision in `106-UAT.md`.

## Out Of Scope

- Refactor Phase 7 canonical accessor and util-leaf work.
- Refactor Phase 8 Gold, Interrupt, and Inventory subsystem extraction.
- Hardening Phase 6.
- Command-validation redesign.
- Mnemosyne or Nemesine work.
- Unrelated UI, gameplay, performance, or feature changes.
- Any F4 behavioral fix.

## Planning And Commit Boundaries

An implementation plan may decompose work into independently reviewable
boundaries such as Wire API/observation machinery, primitive-call migrations,
Standard lifecycle extraction, and guard/test closure. Any decomposition is
subordinate to this fixed scope and behavior contract.

Every package-affecting commit must monotonically bump all synchronized version
fields under `AGENTS.md`. Planning-only commits remain under `.planning/` and
preserve the package version. Independent review, human arbitration, live
applicability, phase closure, and exact-SHA merge authorization remain separate
gates; this context grants none of them.
