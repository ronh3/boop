---
gsd_state_version: 1.0
milestone: v1.0
milestone_name: Pre-1.0 Hardening
current_phase: 03
current_phase_name: queue-interrupt-gold-and-autowalk-regression-coverage
status: verifying
stopped_at: Completed 03-24-PLAN.md
last_updated: "2026-07-29T07:16:38.327Z"
last_activity: 2026-07-29
last_activity_desc: Phase 03 execution started
progress:
  total_phases: 6
  completed_phases: 3
  total_plans: 38
  completed_plans: 38
  percent: 100
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-07-09)

**Core value:** boop must make Achaea hunting safer, clearer, and less noisy without taking control away from the operator.
**Current focus:** Phase 03 — queue-interrupt-gold-and-autowalk-regression-coverage

## Current Position

Phase: 03 (queue-interrupt-gold-and-autowalk-regression-coverage) — EXECUTING
Plan: 24 of 24
Status: Phase complete — ready for verification
Last activity: 2026-07-29 — Phase 03 execution started

Progress: [██████████] 100%

## Performance Metrics

**Velocity:**

- Total plans completed: 34
- Average duration: 14 min
- Total execution time: 7.1 hours

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 01 | 7 | 156m | 22 min |
| 02 | 7 | ~70m | ~10 min |
| 03 | 19/19 | 204m | 11 min |

**Recent Trend:**

- Last 5 plans: Phase 03 P15 (3m), Phase 03 P16 (6m), Phase 03 P17 (4m), Phase 03 P18 (7m), Phase 03 P19 (7m)
- Trend: Plan 03-19 packaged live-trace controls and operator contracts; parent verification, final metadata, terminal CI, and live UAT remain

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
- [Phase 03 planning]: Final authority is the tracked repository extension `tools/wait_for_exact_ci.sh` against immutable final HEAD after all GSD mutations.
- [Phase 03 planning]: Diagnose output uses a zero-argument FIFO/tombstone evidence queue so late output cannot release a newer interrupt generation.
- [Phase 03]: Plan 03-01 makes blockersByOwner authoritative and keeps combat.blocker only as a derived primary compatibility snapshot.
- [Phase 03]: Plan 03-01 permits blocker mutation and self-exclusion only by exact owner key, never by blocker code, family, or subsystem.
- [Phase 03]: Plan 03-01 requires Room.Info plus a later complete current-cycle room item list, with one capped Char.Items.Room refresh per generation.
- [Phase 03]: Interrupts use exact generation owners, FIFO/tombstone diagnose evidence, and one completeInterrupt terminal boundary.
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
- [Phase 03]: Accepted room evidence applies only through a zero-delay record with captured applicationId, roomId, and observationGeneration.
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

### Pending Todos

- [Add temporary prefixes and custom attacks](./todos/pending/2026-07-19-add-temporary-prefixes-and-custom-attacks.md) after Phase 4 command trust boundaries.
- [Verify Infernal hyena maul summary](./todos/pending/2026-07-24-verify-infernal-hyena-maul-summary.md) during Phase 5 fixture expansion after capturing a successful ungagged live sequence.

### Blockers/Concerns

- Plan 03-16 closed G-03-5 with one exact-operation room-only revalidation while preserving copied List authority and aggregate blockers.
- Plan 03-17 closed G-03-4 while preserving manual-targeting movement safety and owned-stop versus attached-detach semantics.
- Plan 03-19 closed packaged alias and operator-documentation wiring for G-03-6; all nineteen Phase 03 plans are executed.
- Local real-Mudlet execution remains unavailable; the focused host helper cannot authoritatively run the entire unrelated profile/DB/rich-output test tree.
- Parent exact-final-HEAD CI and live Achaea UAT remain blocking external gates before Phase 03 can be marked complete.

### Quick Tasks Completed

| # | Description | Date | Commit | Directory |
|---|-------------|------|--------|-----------|
| 260718-uip | Restore GMCP-backed IH denizen actions and hide whitelist/blacklist controls for non-denizen items | 2026-07-19 | a984495 | [260718-uip-restore-gmcp-backed-ih-denizen-actions-a](./quick/260718-uip-restore-gmcp-backed-ih-denizen-actions-a/) |

## Deferred Items

Items acknowledged and carried forward from previous milestone close:

| Category | Item | Status | Deferred At |
|----------|------|--------|-------------|
| *(none)* | | | |

## Session Continuity

Last session: 2026-07-29T07:16:17.566Z
Stopped at: Completed 03-24-PLAN.md
Resume file: None
