---
gsd_state_version: 1.0
milestone: v1.0
milestone_name: Pre-1.0 Hardening
current_phase: 03
current_phase_name: Queue, Interrupt, Gold, and Autowalk Regression Coverage
status: executing
stopped_at: Completed 03-07-PLAN.md
last_updated: "2026-07-26T15:01:09.902Z"
last_activity: 2026-07-26
last_activity_desc: Completed Phase 03 Plan 07
progress:
  total_phases: 6
  completed_phases: 2
  total_plans: 23
  completed_plans: 21
  percent: 91
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-07-09)

**Core value:** boop must make Achaea hunting safer, clearer, and less noisy without taking control away from the operator.
**Current focus:** Phase 03 — Queue, Interrupt, Gold, and Autowalk Regression Coverage

## Current Position

Phase: 03 (Queue, Interrupt, Gold, and Autowalk Regression Coverage) — EXECUTING
Plan: 8 of 9
Status: Ready to execute
Last activity: 2026-07-26 — Completed Phase 03 Plan 07

Progress: [█████████░] 91%

## Performance Metrics

**Velocity:**

- Total plans completed: 21
- Average duration: 16 min
- Total execution time: 5.5 hours

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 01 | 7 | 156m | 22 min |
| 02 | 7 | ~70m | ~10 min |
| 03 | 7 | 102m | ~15 min |

**Recent Trend:**

- Last 5 plans: Phase 03 P03 (15m), Phase 03 P04 (16m), Phase 03 P05 (14m), Phase 03 P06 (16m), Phase 03 P07 (14m)
- Trend: Phase 03 timing-sensitive ownership plans are holding near a 15-minute average

*Updated after each plan completion*
| Phase 02 P02 | 7 min | 2 tasks | 7 files |
| Phase 02 P03 | 18 min | 2 tasks | 7 files |
| Phase 02-state-ownership-repair-and-safety-baseline P04 | 6m27s | 3 tasks | 7 files |
| Phase 02-state-ownership-repair-and-safety-baseline P05 | 5m | 2 tasks | 5 files |
| Phase 02-state-ownership-repair-and-safety-baseline P06 | 8m | 2 tasks | 7 files |
| Phase 02 P07 | 20m | 2 tasks | 6 files |
| Phase 03 P01 | 17m | 3 tasks | 12 files |
| Phase 03 P02 | 10m | 2 tasks | 9 files |
| Phase 03 P03 | 15m | 2 tasks | 9 files |
| Phase 03 P04 | 16m | 2 tasks | 9 files |
| Phase 03 P05 | 14m | 2 tasks | 8 files |
| Phase 03 P06 | 16m | 2 tasks | 8 files |
| Phase 03 P07 | 14m | 2 tasks | 8 files |

## Accumulated Context

### Decisions

Decisions are logged in PROJECT.md Key Decisions table.
Recent decisions affecting current work:

- [Milestone]: Treat this as brownfield pre-1.0 hardening, not a greenfield MVP.
- [Roadmap]: Use the research-backed six-phase order, with REL-03 assigned to final live release verification.
- [Scope]: Do not edit package source, version fields, or generated build artifacts during roadmap creation.
- [Phase 02]: Plan 02-01 kept production runtime behavior unchanged and added RED contract tests for downstream Phase 02 implementation.
- [Phase 02]: Plan 02-01 used owned-domain helper setup for blocker and automation-intent fixtures instead of flat state compatibility keys.
- [Phase 02]: Plan 02-02 kept production behavior unchanged and added Wave 0 contracts for GMCP recovery, target-loss cleanup, pull holds, trace, and canonical blocker UI rendering.
- [Phase 02]: Plan 02-03 stores the cross-automation blocker under owned combat state and routes runtime/events through blockerSnapshot/shouldHold.
- [Phase 02]: Plan 02-03 treats Plans 02-01 and 02-02 as RED contract commits and ships GREEN implementation commits.
- [Phase 02]: Plan 02-03 patched pull_timeout_away at the pull timeout source because events do not own that transition.
- [Phase 02]: Plan 02-04 uses the Plan 02-03 runtime cleanup helper as the source of truth; this plan did not modify boop_runtime.lua.
- [Phase 02]: Plan 02-04 clears target-loss attack intent with clearAttackIntent rather than broad automation cleanup.
- [Phase 02]: Plan 02-04 enforces attack fallback migration by reducing boop_attacks.lua flat-state drift allowance to zero.
- [Phase 02]: Plan 02-05 keeps demonnicAutoWalker install/status behavior unchanged while migrating walk blocker state ownership.
- [Phase 02]: Plan 02-06 uses boop.runtime.blockerSnapshot() as the canonical UI/status/debug source, with legacy checks only as inactive-blocker fallbacks.
- [Phase 02]: Plan 02-06 kept trace source unchanged because prior Phase 02 contracts already emit normalized blocker enter/exit, cleanup, GMCP recovery, pull, and retarget messages.
- [Phase 02]: Plan 02-06 documented host Busted and Mudlet Busted availability limitations rather than treating environment failures as passing tests.
- [Phase 02]: GitHub Actions run 29143523210 passed the real Mudlet/Busted package suite on commit 312ff01, closing the prior local Busted availability gap.
- [Phase 02]: User live-confirmed compact blocker/trace readability after installing the rebuilt package.
- [Phase 03 planning]: Commits whose staged paths are all under `.planning/` preserve the package version; any commit touching another path bumps all four version checkpoints.
- [Phase 03 planning]: Final authority is the tracked repository extension `tools/wait_for_exact_ci.sh` against immutable final HEAD after all GSD mutations.
- [Phase 03 planning]: Diagnose output uses a zero-argument FIFO/tombstone evidence queue so late output cannot release a newer interrupt generation.
- [Phase 03]: Plan 03-01 makes blockersByOwner authoritative and keeps combat.blocker only as a derived primary compatibility snapshot.
- [Phase 03]: Plan 03-01 permits blocker mutation and self-exclusion only by exact owner key, never by blocker code, family, or subsystem.
- [Phase 03]: Plan 03-01 requires Room.Info plus a later complete current-cycle room item list, with one capped Char.Items.Room refresh per generation.
- [Phase 03]: Represent each active interrupt as one generation-keyed operation with an exact interrupt:<generation> blocker owner.
- [Phase 03]: Keep diagnose evidence independent from the active operation; zero-argument result and prompt handlers inspect only FIFO head.
- [Phase 03]: Retain timed-out diagnose evidence as a tombstone until late result and prompt evidence drains that exact FIFO record.
- [Phase 03]: Route all interrupt terminal effects through completeInterrupt after marking the matching generation terminal.
- [Phase 03]: Represent each pull as one exact record keyed by monotonic pullGeneration and pull:<generation> blocker ownership.
- [Phase 03]: Route every terminal outcome through completePull, which compares generation, marks terminal, cancels its timer, and clears only its exact owner.
- [Phase 03]: Treat timeout while away as recovery state pull_timeout_away; retain the hold until a later matching return completes the generation.
- [Phase 03]: Keep enabled configuration entirely outside pull lifecycle control, with zero setEnabled or saveConfig calls.
- [Phase 03]: Use one monotonic gold generation and gold:<generation> blocker owner as canonical authority; legacy pending fields remain derived compatibility views.
- [Phase 03]: Keep DEFERRED_ROOM and PICKUP_PENDING tied to current room evidence, then clear room identity before inventory-owned PACK_PENDING.
- [Phase 03]: Dispatch get and put as independent freestand queue commands; combat execution emits only its supplied action.
- [Phase 03]: Give real auto-flee precedence only inside the active-gold branch, preserving established broad blocker ordering for non-gold ticks.
- [Phase 03]: Treat every current Room.Info observation as invalidation evidence for DEFERRED_ROOM and PICKUP_PENDING while preserving PACK_PENDING.
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

### Pending Todos

- [Add temporary prefixes and custom attacks](./todos/pending/2026-07-19-add-temporary-prefixes-and-custom-attacks.md) after Phase 4 command trust boundaries.
- [Verify Infernal hyena maul summary](./todos/pending/2026-07-24-verify-infernal-hyena-maul-summary.md) during Phase 5 fixture expansion after capturing a successful ungagged live sequence.

### Blockers/Concerns

- Remaining milestone concerns now move to Phase 03+ scope: autowalk coverage gaps, gold/interrupt timing coverage, command trust boundaries, gag fixture fragility, and final release verification.

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

Last session: 2026-07-26T15:01:09.896Z
Stopped at: Completed 03-07-PLAN.md
Resume file: None
