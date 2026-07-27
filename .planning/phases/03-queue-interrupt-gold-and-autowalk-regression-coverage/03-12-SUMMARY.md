---
phase: 03-queue-interrupt-gold-and-autowalk-regression-coverage
plan: "12"
subsystem: runtime-safety
tags: [lua, mudlet, autowalk, gmcp, response-fence, generations, busted]
requires:
  - phase: 03-queue-interrupt-gold-and-autowalk-regression-coverage
    plan: "11"
    provides: serialized Inv-to-Room response fences, invalidated FIFO draining, and complete same-room observation preservation
provides:
  - Tokenless demonwalker.arrived adapter with no generation or correlation authority
  - Fresh-start walker epochs whose only settlement path is the current serialized room-response fence
  - Same-room reservation continuity and stop/restart stale-response draining with one guarded move
affects: [03-13-gold-same-room-closure, 03-phase-verification, autowalk-live-uat]
tech-stack:
  added: []
  patterns:
    - External arrival notifications may request evidence but never create, identify, settle, or rearm an epoch.
    - Walker settlement and emission use canonical accepted observation identity rather than persistent merged GMCP tables.
    - Restart invalidates old response records in place so they drain before the new fence can bind.
key-files:
  created:
    - .planning/phases/03-queue-interrupt-gold-and-autowalk-regression-coverage/03-12-SUMMARY.md
  modified:
    - src/scripts/boop/boop_walk.lua
    - src/scripts/boop/boop_events.lua
    - tests/boop_walk_spec.lua
    - tests/boop_event_transitions_spec.lua
    - mfile
    - src/scripts/boop/boop_init.lua
    - CODEX.md
key-decisions:
  - "Discard every demonwalker.arrived argument at the adapter boundary; event names and synthetic numbers cannot become production authority."
  - "Open the fresh-start response fence directly from walk.start and let active incomplete arrival call only the capped Plan 03-11 opener."
  - "Preserve complete same-room reservations and evaluate settlement/emission against the canonical accepted observation room and generation."
patterns-established:
  - "Tokenless notification boundary: zero forwarded arguments, no lifecycle mutation, and at most one capped evidence request."
  - "Walker epoch boundary: fresh start or actual Room.Info change owns resets; accepted current-fence room evidence owns settlement."
requirements-completed: [WALK-01, WALK-02, WALK-03]
coverage:
  - id: D1
    description: Real tokenless and synthetic-argument arrival calls cannot create evidence, reset lifecycle state, settle, reserve, or move; incomplete arrival can only request the already-capped current fence.
    requirement: WALK-01
    verification:
      - kind: unit
        ref: "tests/boop_event_transitions_spec.lua#arrival-tokenless-fence requests no authorizing evidence"
        status: pass
      - kind: integration
        ref: "arrival-tokenless-fence host Busted filter: 3 successes"
        status: pass
    human_judgment: false
  - id: D2
    description: Complete same-room reservations survive repeated arrival and Room.Info, while stop/restart drains old responses and callbacks before one new guarded move.
    requirement: WALK-02
    verification:
      - kind: unit
        ref: "tests/boop_walk_spec.lua#arrival-tokenless-fence same-room and restart cases"
        status: pass
      - kind: integration
        ref: "Focused walker/event host Busted aggregate: 84 successes"
        status: pass
    human_judgment: false
  - id: D3
    description: Optional walker installation behavior remains unchanged and the 0.1.420 package builds with the tokenless arrival lifecycle.
    requirement: WALK-03
    verification:
      - kind: other
        ref: "python3 tools/check_release_gates.py and muddle"
        status: pass
      - kind: integration
        ref: "Real Mudlet focused/full suite"
        status: unknown
    human_judgment: true
    rationale: "The local /tmp/Mudlet.AppImage was unavailable; the parent retains final immutable-HEAD CI and live-Mudlet authority."
duration: 7m
completed: 2026-07-26
status: complete
---

# Phase 03 Plan 12: Tokenless Walker Arrival Authority Summary

**Real `demonwalker.arrived` is now a tokenless, non-authorizing evidence hint: only current fenced room responses can settle a fresh epoch and release one guarded move.**

## Performance

- **Duration:** 7m
- **Started:** 2026-07-27T02:33:48Z
- **Completed:** 2026-07-27T02:41:00Z
- **Tasks:** 2
- **Files modified:** 7

## Accomplishments

- Added three exact RED regressions through the real arrival adapter for zero argument authority, complete same-room reservation preservation, and stop/restart FIFO response draining.
- Removed the arrival fallback that reset settlement, canceled emitters, and created an independent timer; active incomplete arrival now calls only the capped room-response-fence opener.
- Made public walk start create an explicit evidence-empty `fresh_start` epoch and request exactly `Char.Items.Inv` then `Char.Items.Room`.
- Preserved reservation and emission one-shot behavior across repeated arrival, duplicate same-room Info/List callbacks, stale timers, and invalidated old response pairs.
- Switched walker settlement and deferred-emission room checks from persistent merged GMCP to the canonical accepted observation identity.

## Task Commits

Each task was committed atomically:

1. **Task 1: Add RED tokenless-arrival and fenced-restart regressions** - `1dcdfcc` (test, version `0.1.419`)
2. **Task 2: Make tokenless arrival non-authorizing without rearming movement** - `961ceb0` (fix, version `0.1.420`)

**Plan metadata:** committed separately with this summary and sequential state closeout.

## Files Created/Modified

- `tests/boop_event_transitions_spec.lua` - Covers real adapter argument discard, fresh fenced start, pre-barrier/inventory zero effects, one accepted settlement, and exact event counts.
- `tests/boop_walk_spec.lua` - Covers complete same-room reservation preservation, same-room restart, stale response draining, stale timer callbacks, capped timeout warning, and one move.
- `src/scripts/boop/boop_events.lua` - Discards every `demonwalker.arrived` argument and invokes zero-argument walker arrival.
- `src/scripts/boop/boop_walk.lua` - Removes arrival rearming, opens fresh-start fences, synchronizes only actual room boundaries, and uses canonical observation identity for settlement/emission.
- `mfile`, `src/scripts/boop/boop_init.lua`, `CODEX.md` - Synchronize package version checkpoints through RED `0.1.419` and final GREEN `0.1.420`.

## Decisions Made

- Arrival is a notification without identity. Both Mudlet's event-name string and arbitrary numeric arguments are discarded before entering walker state.
- The response fence is opened by `walk.start`; later active/incomplete arrivals may only retry the capped opener, which is a no-op once the current epoch already has a pair.
- Room movement or explicit fresh start may clear reservation state. Complete same-room arrival and Room.Info are preservation paths.
- The accepted observation's room and generation are the walker proof. Persistent `gmcp.Room.Info` and `gmcp.Char.Items.List` remain transport state, not settlement authority.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Corrected inconsistent generic state-handler closeout**

- **Found during:** Sequential planning/state closeout
- **Issue:** `state.update-progress` reported 96% but wrote 33% to STATE frontmatter, while generic handlers retained stale Plan 03-11 status/activity prose and labeled new decisions as `Phase ?`.
- **Fix:** Corrected STATE to Plan 13 of 13, 26/27 completed plans, 96% progress, current Plan 03-12 activity/readiness prose, Phase 03 decision labels, and updated Phase 03 metrics.
- **Files modified:** `.planning/STATE.md`
- **Verification:** STATE frontmatter/body, ROADMAP 12/13 count, summary count, and session stop point agree.
- **Committed in:** Plan metadata closeout commit

---

**Total deviations:** 1 auto-fixed (1 Rule 1 bug)
**Impact on plan:** Planning metadata now reflects the authoritative on-disk summaries and does not affect package behavior or versioning.

## Issues Encountered

- The first Muddler invocation used non-TTY execution and its container wrapper refused stdin attachment. Re-running the same build with a PTY succeeded at version `0.1.420`.
- `/tmp/Mudlet.AppImage` is absent, so the canonical local real-Mudlet suite was unavailable. Host Busted remains focused diagnostic evidence only; no real-Mudlet or exact-final-HEAD CI claim is made.

## Verification

- TDD RED: the exact `arrival-tokenless-fence` filter produced 3 intentional `ARRIVAL_TOKENLESS_FENCE_BROKEN` failures, 0 errors, and no unmarked failures.
- Named GREEN: 3 successes, 0 failures, 0 errors, 0 pending.
- Focused walker/event aggregate: 84 successes, 0 failures, 0 errors, 0 pending.
- Lua syntax: walker, runtime, events, both focused specs, and init pass `luac -p`.
- Release gates: versions, manifests, and state drift pass at synchronized version `0.1.420`.
- Muddler: package build completed successfully as `build/boop Hunter.mpackage` at `0.1.420`; generated output was not staged or committed.
- Local real-Mudlet: unavailable because `/tmp/Mudlet.AppImage` is absent.
- Parent-owned exact-final-HEAD GitHub Actions gate: intentionally not run or claimed.

## Known Stubs

- The focused specs use Busted stubs, captured timer callbacks, synthetic GMCP tables, and fixed fixture IDs as intentional deterministic test infrastructure. No stub or placeholder was introduced into package runtime or operator-facing behavior.

## User Setup Required

None - `demonnicAutoWalker` remains optional, with its existing explicit install/status behavior unchanged.

## Next Phase Readiness

- Plan 03-13 can close the remaining gold same-room evidence path against copied accepted items without a walker arrival shortcut.
- The parent retains sole authority to push immutable final HEAD and run `tools/wait_for_exact_ci.sh` after all remaining plan and tracking mutations finish.

## Self-Check: PASSED

- The summary and all seven implementation, test, and synchronized-version files exist.
- Task commits `1dcdfcc` and `961ceb0` are present in RED → GREEN order.
- The three exact named regressions and all 84 focused walker/event checks pass.
- Lua syntax, release gates, Muddler, diff checks, and generated-artifact staging checks pass at version `0.1.420`.

---
*Phase: 03-queue-interrupt-gold-and-autowalk-regression-coverage*
*Completed: 2026-07-26*
