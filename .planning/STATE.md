---
state_version: 2
milestone: v1.0
milestone_name: Pre-1.0 Hardening
active_phase: "00"
active_phase_name: lightweight-agent-workflow
active_branch: phase/00-lightweight-agent-workflow
active_specification: .planning/phases/00-lightweight-agent-workflow/00-CONTEXT.md
status: corrections_awaiting_rereview
independent_review: "narrow_rereview_complete_no_open_findings — Claude, 2026-09-04; final narrow re-review of 80e38aa655672f102745d4c0dbdbf5ad5d0b492c against correction 887a4ff64292ed784dd8f48d4c3c03f8bd20f632 recorded in 00-ADVERSARIAL-REVIEW.md; N-01, N-02, N-03 verified fixed, M-06 and M-08 upgraded from partially fixed to verified fixed, no new findings; supersedes the 57d98dc re-review gate value; not an acceptance and not phase closure"
human_arbitration: pending
live_mudlet_validation: pending_human_determination
phase_closure: pending_human_authorization
merge_authorization: pending_human_authorization
main_baseline: a345a34ea0da2eed6f5bfe1c5e586488749a3e22
last_updated: "2026-09-04"
---

# Project State

## Project Reference

See: `.planning/PROJECT.md`.

**Core value:** boop must make Achaea hunting safer, clearer, and less noisy without taking control away from the operator.
**Current focus:** Phase 00 — lightweight multi-agent workflow adoption

## Current Position

Branch: `phase/00-lightweight-agent-workflow`
Specification: `.planning/phases/00-lightweight-agent-workflow/00-CONTEXT.md`
Main baseline: see canonical `main_baseline` in frontmatter.
Status: Corrective pass; awaiting Claude re-review and human arbitration.

State writers follow `AGENTS.md`:

- Codex: factual `status`, active phase/name/branch/specification, branch-start
  `main_baseline`, and `last_updated`, within authorized scope.
- Claude: `independent_review`, citing its dated review entry and exact SHA.
- Human: `human_arbitration`, `live_mudlet_validation`, `phase_closure`, and
  `merge_authorization`, with attributed evidence in the review/UAT artifacts.
- No actor may advance, reset, or clear another writer's gate. Codex may
  initialize new gates as pending, never infer approval or close a finding.

Claude's initial findings are recorded in `00-ADVERSARIAL-REVIEW.md` at commit
`9b47f6409a3ba6e75ff575baafe3020d03a7622a`, reviewing
`44fb844fe2aadf9d71fd7aa95736f3f336e3af72`. The frontmatter review gate is left
for Claude to update; this factual pointer does not advance it. All Codex
proposed dispositions await Claude re-review / human arbitration.

## Session Continuity

Current work is Phase 00 corrections on the named active branch. Resume with
`00-ADVERSARIAL-REVIEW.md`, `00-VERIFICATION.md`, and `00-UAT.md`. Do not resume
historical Phase 03 plans or begin refactor Phase 6. Phase 00 is not complete.

## Historical Planning Record

The detailed metrics and accumulated decisions below predate the lightweight
workflow. They remain durable project provenance, but legacy tooling names and
status values and execution instructions in that history cannot control any
current or future phase. Old phase numbers here refer to the hardening roadmap,
unless explicitly qualified as refactor phases.

## Performance Metrics

**Velocity:**

- Total plans completed: 47
- Average duration: 14 min
- Total execution time: 8.6 hours

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 01 | 7 | 156m | 22 min |
| 02 | 7 | ~70m | ~10 min |
| 03 | 33/38 | ~387m | ~12 min |

**Recent Trend:**

- Last 5 completed plans: Phase 03 P31 (14m), P32 (22m), P33 (8m), P34 (live checkpoint), P39 (interrupt hierarchy)
- Trend: Plan 03-39 closes automated G-03-27 implementation; Plan 03-40 is its focused live-verification checkpoint

*Updated after each plan completion*
| Phase 02-state-ownership-repair-and-safety-baseline P06 | 8m | 2 tasks | 7 files |
| Phase 02 P07 | 20m | 2 tasks | 6 files |
| Phase 03 P01 | 17m | 3 tasks | 12 files |
| Phase 03 P02 | 10m | 2 tasks | 9 files |
| Phase 03 P03 | 15m | 2 tasks | 9 files |
| Phase 03 P04 | 16m | 2 tasks | 9 files |
| Phase 03 P05 | 14m | 2 tasks | 8 files |
| Phase 03 P06 | 16m | 2 tasks | 8 files |
| Phase 03 P07 | 14m | 2 tasks | 8 files |
| Phase 03 P08 | 12m | 3 tasks | 10 files |
| Phase 03 P09 | 10m | 3 tasks | 9 files |
| Phase 03 P10 | 7m | 2 tasks | 8 files |
| Phase 03 P11 | 17m | 2 tasks | 10 files |
| Phase 03 P12 | 7m | 2 tasks | 7 files |
| Phase 03 P13 | 11m | 2 tasks | 7 files |
| Phase 03 P14 | 11m | 3 tasks | 10 files |
| Phase 03 P15 | 3m | 3 tasks | 7 files |
| Phase 03 P16 | 6m | 2 tasks | 7 files |
| Phase 03 P17 | 4m | 3 tasks | 9 files |
| Phase 03 P18 | 7m | 3 tasks | 8 files |
| Phase 03 P19 | 7m | 3 tasks | 9 files |
| Phase 03 P20 | 9m35s | 1 tasks | 6 files |
| Phase 03 P21 | 14m32s | 1 tasks | 9 files |
| Phase 03 P22 | 8m | 1 tasks | 5 files |
| Phase 03 P23 | 31m | 1 tasks | 11 files |
| Phase 03 P24 | 5m | 1 tasks | 7 files |
| Phase 03 P25 | 19m | 1 tasks | 10 files |
| Phase 03 P26 | 19m | 1 tasks | 9 files |
| Phase 03 P27 | 9m | 1 tasks | 8 files |
| Phase 03 P28 | 14m | 1 tasks | 10 files |
| Phase 03 P29 | 12m | 1 tasks | 8 files |
| Phase 03 P30 | 0m | 3 tasks | 2 files |
| Phase 03 P31 | 14m | 1 tasks | 5 files |
| Phase 03 P32 | 22m | 1 tasks | 11 files |
| Phase 03 P33 | 8m | 1 tasks | 6 files |
| Phase 03 P34 | live | 3 tasks | 2 files |
| Phase 03 P39 | 20m | 3 tasks | 14 files |

## Accumulated Context

### Decisions

Recent decisions affecting current work:

- [Milestone]: Treat this as brownfield pre-1.0 hardening, not a greenfield MVP.
- [Roadmap]: Use the research-backed six-phase order, with REL-03 assigned to final live release verification.
- [Scope]: Do not edit package source, version fields, or generated build artifacts during roadmap creation.
- [Phase 02]: Established canonical owned blockers, runtime cleanup, target-loss repair, walker ownership, and canonical status/trace rendering with RED→GREEN contract coverage.
- [Phase 02]: Kept pull timeout ownership at its source, preserved external walker install behavior, and reduced flat-state drift allowance to zero.
- [Phase 02]: GitHub Actions run 29143523210 and user live validation confirmed the real Mudlet suite and compact blocker/trace readability.
- [Phase 03 planning]: Commits whose staged paths are all under `.planning/` preserve the package version; any commit touching another path bumps all four version checkpoints.
- [Phase 03 planning; superseded by AGENTS.md — CI is automated evidence only]: Final authority is the tracked repository extension `tools/wait_for_exact_ci.sh` against immutable final HEAD after all GSD mutations.
- [Phase 03]: Diagnose completion prefers Char.Afflictions.List with visible result-line fallback; a new explicit diagnose supersedes unresolved evidence from a timed-out dispatch so stale FIFO state cannot poison later generations.
- [Phase 03]: A corpse line that sends sovereigns directly into inventory bypasses room pickup and starts the existing inventory-owned pack operation without issuing get.
- [Phase 03]: Plan 03-01 makes blockersByOwner authoritative and keeps combat.blocker only as a derived primary compatibility snapshot.
- [Phase 03]: Plan 03-01 permits blocker mutation and self-exclusion only by exact owner key, never by blocker code, family, or subsystem.
- [Phase 03]: Plan 03-01 requires Room.Info plus a later complete current-cycle room item list, with one capped Char.Items.Room refresh per generation.
- [Phase 03]: Interrupts use exact generation owners and one completeInterrupt terminal boundary; diagnose evidence is bounded to the current explicit dispatch.
- [Phase 03]: Pulls use monotonic generation owners and one completePull boundary; timeout-away retains its hold without mutating enabled configuration.
- [Phase 03]: Use one monotonic gold generation and gold:<generation> blocker owner as canonical authority; legacy pending fields remain derived compatibility views.
- [Phase 03]: Keep DEFERRED_ROOM and PICKUP_PENDING tied to current room evidence, then clear room identity before inventory-owned PACK_PENDING.
- [Phase 03]: Dispatch gold get on the full queue and put on the freestand queue as independent commands; combat execution emits only its supplied action.
- [Phase 03]: Give real auto-flee precedence only inside the active-gold branch, preserving established broad blocker ordering for non-gold ticks.
- [Phase 03]: Advance deferred room evidence without sending, then let one normal tick emit flush_gold and call flushPendingGold once.
- [Phase 03]: Replace direct gold-terminal walker advancement with a generation-guarded zero-delay tick.
- [Phase 03]: Use shared current-room observation as the only walker settlement authority; capped timers may warn but never stamp settlement.
- [Phase 03]: Keep moveQueued blocking in normal evaluation and permit only the exact run/room/reservation emitter to exclude walk:<generation>.
- [Phase 03]: Preserve monotonic walker reservation IDs across generation invalidation while canceling refresh and emitter callback authority.
- [Phase 03]: Keep demonnicAutoWalker package mutation explicit; status, start, move, and package-loss paths never install or update.
- [Phase 03]: Invalidate the current walker generation and exact reservation before owner cleanup, operator output, or an owned external stop event.
- [Phase 03]: Detach attached runs locally without changing demonwalker.enabled or raising demonwalker.stop.
- [Phase 03]: Require a new shared Room.Info plus complete room-item observation after every restart, even when the room number is unchanged.
- [Phase 03]: Normalize nonnumeric Mudlet event-name arguments to absent generation tokens while preserving numeric stale-callback guards.
- [Phase 03]: Use the canonical primary blocker snapshot and its additionalCount for normal surfaces; reserve the complete sorted snapshot for full diagnostics.
- [Phase 03]: Keep ownership and timing guidance inside the existing interrupts, loot, and party help topics without adding commands, aliases, topics, owners, or APIs.
- [Phase 03]: Preserve aggregate authorization as the release mechanism: clearing one owner never bypasses another owner or the existing disabled/manual automation intent.
- [Phase 03]: Keep the final cross-lifecycle matrix in the existing event-transition integration spec without adding APIs or test frameworks.
- [Phase 03]: Reevaluate once after room settlement only when the current gold stage remains unsent and has no active timeout.
- [Phase 03]: Reserve terminal repository authority for the parent immutable-final-HEAD CI gate after every mutation.
- [Phase 03]: Consume only the exact matching fired gold timeout token and synchronize derived pending state before evaluating unrelated owners.
- [Phase 03]: Keep timeout recovery on the existing normal tick/flush and guarded walker paths without adding owner-release hooks or walker special cases.
- [Phase 03]: Use only serialized Inv-to-Room response order plus unchanged room generation as production List authority.
- [Phase 03]: Keep invalidated room-response fences in FIFO order as zero-effect drains ahead of newer epochs.
- [Phase 03]: Preserve complete same-room observations and invalidate room-owned state only on actual movement or explicit fresh start.
- [Phase 03]: Discard every demonwalker.arrived argument; tokenless arrival can only request the current capped response fence.
- [Phase 03]: Open a fresh-start fence from walk.start and preserve complete same-room reservations across arrival and Room.Info.
- [Phase 03]: Use canonical accepted observation identity, not persistent GMCP tables, for walker settlement and emission.
- [Phase 03]: Use copied current-fence room observations for gold authorization; populated canonical targeting-room mismatches reject without any persistent-GMCP fallback.
- [Phase 03]: Require exact operation room, room generation, and gold item identity before initial or retry gold sends.
- [Phase 03]: Preserve same-room acquisition, cancel only on actual movement, and transfer to roomless packing only after confirmed pickup.
- [Phase 03 planning]: Keep a prompt-only lifecycle trigger active while hunting automation is disabled; every combat, gag, targeting, gold, queue, and walker trigger remains under the independently toggled automation folder.
- [Phase 03 planning]: Reconcile canonical `gmcp:ire` evidence from post-connection IRE Target/Display events and the prompt boundary so IRE and prompt may arrive in either order without `Char.Status` or enable.
- [Phase 03]: Keep the prompt-only lifecycle observer enabled independently from hunting automation; all combat, gag, target, gold, and walk triggers stay under boop.
- [Phase 03]: Reuse the exact gmcp:ire owner and reconcile current IRE at explicit lifecycle and event boundaries without support requests on evidence-only paths.
- [Phase 03]: Warn on incomplete room-response fences at 8.0 seconds while retaining room:observation fail closed.
- [Phase 03]: Plan 03-15 kept exact owner and timer identity canonical, preserved host-versus-real-Mudlet authority boundaries, and left exact-SHA CI and live UAT to the parent.
- [Phase 03]: Plan 03-16 keeps settled Item.Add non-canonical and spends one exact-operation Char.Items.Room revalidation allowance.
- [Phase 03]: Plan 03-16 starts room-only fences at await_room while preserving ordinary Inv-to-Room observation fences and aggregate owner gates.
- [Phase 03]: Manual targeting remains a hard automatic-walk hold; status projects code, label, and recovery action from the shared movement evaluator.
- [Phase 03]: Inactive non-silent stop is acknowledged at the walk lifecycle boundary while silent calls and owned-stop versus attached-detach semantics remain unchanged.
- [Phase 03]: Live walk UAT must prove the manual hold, then select automatic targeting before movement is expected.
- [Phase 03]: Live trace mode remains runtime-only and cannot persist or independently enable collection.
- [Phase 03]: Top-level package bootstrap resets only trace.live before guarded bootstrap, preserving the trace table and buffer.
- [Phase 03]: Accepted trace appends stream once through direct non-tracing INFO feedback after trimming.
- [Phase 03]: Plan 03-19 packages live tracing through a dedicated anchored alias so persisted collection routing and capture indexes remain unchanged.
- [Phase 03]: Plan 03-19 documents persisted collection, session-only live streaming, show, and clear as independent controls with live reset off by default.
- [Phase 03]: The parent retains immutable-final-HEAD push, exact-SHA CI, and live Phase 03 UAT authority after all repository mutations.
- [Phase 03]: Room Inv and Room responses are independent copied latches that settle exactly once in either order.
- [Phase 03]: Accepted room evidence retains a zero-delay fallback record with captured applicationId, roomId, and observationGeneration; the next natural tick may claim that exact current record first through the same validator.
- [Phase 03]: Moved Room.Info invalidates stale room applications and local attack intent without queue-wide cleanup.
- [Phase 03]: Deferred room-owned callbacks retain their copied application, room, and generation authority without destination fallback.
- [Phase 03]: Every automatic target, alias, queue, standard, and rage boundary revalidates exact room authority before send or success-dependent state.
- [Phase 03]: Stale combat rejection remains local and preserves intentional non-room command families plus unrelated shared queue ownership.
- [Phase 03]: Wake active walks only on a true manual-to-nonmanual targeting transition.
- [Phase 03]: Delegate targeting wakeups to boop.walk.maybeAdvance so snapshot, owner, and reservation gates remain authoritative.
- [Phase 03]: Pickup dispatch uses the full queue while packing remains an independent freestand command.
- [Phase 03]: Destructive native queue replacement invalidates only the exact sent dispatch timer while preserving gold owner, generation, phase, evidence, and retry authority.
- [Phase 03]: A fresh displacement-replay timeout waits nonterminally for explicit evidence instead of completing with pending_timeout or replaying automatically.
- [Phase 03]: Transfer the exact sent gold dispatch after the diag blocker exists and immediately before clearqueue all.
- [Phase 03]: Give only result-then-prompt diag timeouts the new exact-success replay tick, preserving existing prompt-only interrupt timeout behavior.
- [Phase 03]: Keep Plan 03-23 gold replay, fresh-timeout, explicit-evidence, and target-loss production contracts unchanged.
- [Phase 03]: Make the exact standard record authoritative while retaining prequeuedStandard as its compatibility projection.
- [Phase 03]: Activate destructive mutation serialization only after an observed queued ADDCLEARFULL baseline; direct standard plus rage remains compatible and is attributed through the outbound ledger.
- [Phase 03]: Quarantine proven departure without clearing native work, but send one traced clearqueue all for present or unknown forbidden-target revocation.
- [Phase 03]: Retain exhausted pack provenance only in nonblocking gold.packQuarantine, outside all operation and compatibility ownership.
- [Phase 03]: Invalidate qualifying inventory on late old put activity and require another causally newer complete List.
- [Phase 03]: Consume quarantine eligibility before one fresh put and recheck configuration, inventory, standard lifecycle, and all aggregate subsystem gates.
- [Phase 03]: Use interrupt:<generation> as the leap outbound owner so denial attribution and completeInterrupt release share one exact identity.
- [Phase 03]: Open the leap denial window only on the observed owned ADDCLEARFULL wire; later unowned outbound traffic leaves the operation for bounded timeout.
- [Phase 03]: Preserve clearqueue all plus ADDCLEARFULL leap policy and schedule one ordinary zero-delay tick after command_failed completion.
- [Phase 03]: Use the shared outbound ledger as the sole source of exact Rage wire order and final-owned-wire causality; never register the unsplit logical Rage action.
- [Phase 03]: Keep global Battlerage cooldown independent from per-ability readiness and reopen it only on exact Available-list recovery or reconnect.
- [Phase 03]: Bound Triumph with a replaceable generation timer and first-terminal clearing on matching use, expiry, causal insufficient-rage output, timeout, or reconnect.
- [Phase 03]: Hold Rage only behind nonterminal queued standard generations so established direct standard-plus-Rage execution remains intact.
- [Phase 03]: Plan 03-29: Leave completeInterrupt and scripts.json unchanged because focused seam counts proved terminal producer, retained acceptance, and live rendering were already exact.
- [Phase 03]: Plan 03-29: Collapse only unchanged target-removal, room_partial, and no-target fingerprints at live admission while retaining every accepted record and prioritizing lifecycle terminals.
- [Phase 03]: Plan 03-29: Defer six starting-HEAD boop_tick_spec expectation failures rather than weaken exact queued-standard ownership or edit an unrelated suite.
- [Phase 03]: Plan 03-31 keeps dispatch authority application-exact and permits newer application ids only during result reconciliation in the same current room observation.
- [Phase 03]: Plan 03-31 keeps manual and differently owned post-baseline outbound traffic ambiguous across same-room evidence refreshes and traces the exact rejection reason.
- [Phase 03]: Plan 03-32 emits each autonomous item refresh with the documented empty-string body and one immediate whitespace transport flush.
- [Phase 03]: Plan 03-32 excludes only trimmed-empty transport sends before command causality; every real manual or differently owned command remains observable.
- [Phase 03]: Plan 03-32 starts full-pickup result timing once at the first full-ready execution opportunity for initial, retry, and replay dispatches; packing timing remains independent.
- [Phase 03]: Plan 03-32 reuses exact room-fence, gold generation/dispatch, and pack-quarantine authority without adding a coordinator or public API.
- [Phase 03]: Treat the alternate no-abilities sentence as global cooldown recovery only; preserve all per-ability readiness and neighboring Rage lifecycle state.
- [Phase 03]: Keep Rage_Command_Outcome.lua unchanged and route one exact anchored manifest alternative into boop.rage.onCommandOutcome.
- [Phase 03]: Reject punctuation, prefix, suffix, and similar-prose near matches at both trigger and parser boundaries.
- [Phase 03]: Keep interrupt admission tiers independent from blocker display priority: flee is absolute, leap/fly are emergency, diagnose is diagnostic, and matic/catarin/touch-shield are utility.
- [Phase 03]: A repeated emergency of the same kind is an explicit retry that atomically replaces the prior generation; different same-tier and lower-tier requests preserve the active owner.

### Pending Todos

- [Add temporary prefixes and custom attacks](./todos/pending/2026-07-19-add-temporary-prefixes-and-custom-attacks.md) after Phase 4 command trust boundaries.
- [Add safe threshold-based AOE attacks](./todos/pending/2026-08-04-add-safe-threshold-based-aoe-attacks.md) after Phase 3 repair and Phase 4 command validation.
- [Add class heal interrupt](./todos/pending/2026-08-04-add-class-heal-interrupt.md) after Phase 3 lifecycle repair and exact live result-line capture.
- [Verify Infernal hyena maul summary](./todos/pending/2026-07-24-verify-infernal-hyena-maul-summary.md) during Phase 5 fixture expansion after capturing a successful ungagged live sequence.

### Blockers/Concerns

- Plan 03-16 closed G-03-5 with one exact-operation room-only revalidation while preserving copied List authority and aggregate blockers.
- Plan 03-17 closed G-03-4 while preserving manual-targeting movement safety and owned-stop versus attached-detach semantics.
- Plan 03-29 implemented G-03-26 terminal trace visibility, retained forensics, and live-only routine deduplication in package 0.1.473; live verification remains in Plan 03-37.
- Six aggregate-owner cases in `boop_tick_spec.lua` retain pre-existing expectations that conflict with Plan 03-25 exact queued-standard ownership; starting HEAD reproduces them and the phase deferred ledger records follow-up.
- Local real-Mudlet execution remains unavailable; the focused host helper cannot authoritatively run the entire unrelated profile/DB/rich-output test tree.
- Parent exact-final-HEAD CI and live Achaea UAT remain blocking external gates before Phase 03 can be marked complete.

### Quick Tasks Completed

| # | Description | Date | Commit | Directory |
|---|-------------|------|--------|-----------|
| 260718-uip | Restore GMCP-backed IH denizen actions and hide whitelist/blacklist controls for non-denizen items | 2026-07-19 | a984495 | [260718-uip-restore-gmcp-backed-ih-denizen-actions-a](./quick/260718-uip-restore-gmcp-backed-ih-denizen-actions-a/) |
| 260810-ikl | Preserve configured rage after ordinary battlerage spending | 2026-08-10 | 906212f | [260810-ikl-change-ragepoolthreshold-to-preserve-the](./quick/260810-ikl-change-ragepoolthreshold-to-preserve-the/) |

## Deferred Items

Items acknowledged and carried forward from previous milestone close:

| Category | Item | Status | Deferred At |
|----------|------|--------|-------------|
| *(none)* | | | |

## Historical Session Continuity

Last session: 2026-08-04T22:24:56.710Z
Stopped at: Completed 03-33-PLAN.md
Resume file: None
