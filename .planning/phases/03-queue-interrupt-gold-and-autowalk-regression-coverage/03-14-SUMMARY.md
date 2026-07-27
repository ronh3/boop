---
phase: 03-queue-interrupt-gold-and-autowalk-regression-coverage
plan: "14"
subsystem: runtime-safety
tags: [lua, mudlet, lifecycle, gmcp, response-fence, busted]
requires:
  - phase: 03-queue-interrupt-gold-and-autowalk-regression-coverage
    plan: "13"
    provides: canonical room-response and exact-owner gold authorization
provides:
  - Always-active prompt-only lifecycle evidence isolated from disabled hunting automation
  - Order-independent exact-owner IRE recovery from current support and prompt evidence
  - Eight-second room-response warning that warns once and remains fail closed
affects: [03-phase-verification, lifecycle-live-uat, autowalk-live-uat]
tech-stack:
  added: []
  patterns:
    - Lifecycle evidence observers remain available while the hunting-owned trigger folder is disabled.
    - Current IRE support reconciles through one canonical gmcp:ire owner without requesting support on evidence-only paths.
    - Room-response timeout warnings never authorize work or clear room:observation.
key-files:
  created:
    - tests/boop_lifecycle_spec.lua
    - src/triggers/boop_lifecycle/triggers.json
    - .planning/phases/03-queue-interrupt-gold-and-autowalk-regression-coverage/03-14-SUMMARY.md
  modified:
    - src/scripts/boop/boop_init.lua
    - src/scripts/boop/boop_events.lua
    - src/triggers/triggers.json
    - src/triggers/boop/Core/triggers.json
    - src/triggers/boop_lifecycle/Prompt.lua
    - tests/boop_event_transitions_spec.lua
    - mfile
    - CODEX.md
key-decisions:
  - "Keep the prompt-only lifecycle observer enabled independently from hunting automation; all combat, gag, target, gold, and walk triggers stay under boop."
  - "Reuse the exact gmcp:ire owner and reconcile current IRE at explicit lifecycle and event boundaries without support requests on evidence-only paths."
  - "Warn on incomplete room-response fences at 8.0 seconds while retaining room:observation fail closed."
patterns-established:
  - "Disabled evidence-only path: observe IRE and prompt lifecycle facts, then return before runtime step/apply or any automation side effect."
  - "Lifecycle trigger ownership: boop lifecycle contains exactly one prompt observer; boop retains all hunting automation."
requirements-completed: [SAFE-02, SAFE-04, WALK-01, WALK-02, WALK-03]
coverage:
  - id: D1
    description: Disabled hunting leaves only prompt and IRE lifecycle evidence observable, with zero combat, target, gold, queue, gag, or walker automation effects.
    requirement: SAFE-02
    verification:
      - kind: unit
        ref: "tests/boop_lifecycle_spec.lua#boop lifecycle recovery gap-03-3 keeps only lifecycle evidence active while disabled"
        status: pass
      - kind: unit
        ref: "tests/boop_lifecycle_spec.lua#boop lifecycle recovery gap-03-3 prompt evidence has zero disabled automation"
        status: pass
    human_judgment: false
  - id: D2
    description: IRE-event-to-prompt and prompt-to-IRE-event both release only gmcp:ire, without Char.Status or enable, while unrelated owners survive.
    requirement: SAFE-04
    verification:
      - kind: unit
        ref: "tests/boop_lifecycle_spec.lua#boop lifecycle recovery gap-03-3 releases gmcp ire in either evidence order"
        status: pass
      - kind: integration
        ref: "Focused persistence/safety/event/walk/gold/lifecycle host Busted aggregate: 109 successes"
        status: pass
    human_judgment: false
  - id: D3
    description: A room response accepted at 4.5 seconds is quiet; an incomplete fence warns once at 8.0 seconds and retains room:observation.
    requirement: WALK-01
    verification:
      - kind: unit
        ref: "tests/boop_lifecycle_spec.lua#boop lifecycle recovery gap-03-3 room warning honors measured latency and remains fail closed"
        status: pass
    human_judgment: false
  - id: D4
    description: Existing gold and movement regressions remain green across lifecycle reconciliation and the calibrated room-response warning.
    requirement: WALK-02
    verification:
      - kind: integration
        ref: "tests/boop_gold_spec.lua and tests/boop_walk_spec.lua in the 109-test aggregate"
        status: pass
    human_judgment: false
  - id: D5
    description: Walker emission remains blocked by canonical room evidence and exact owners; warning expiry itself cannot authorize movement.
    requirement: WALK-03
    verification:
      - kind: integration
        ref: "tests/boop_event_transitions_spec.lua and tests/boop_walk_spec.lua in the 109-test aggregate"
        status: pass
    human_judgment: false
  - id: D6
    description: Version 0.1.427 passes syntax, release gates, manifest checks, host regression tests, and package construction.
    verification:
      - kind: other
        ref: "luac -p, python3 tools/check_release_gates.py, git diff --check, and Muddler 1.1.0"
        status: pass
      - kind: integration
        ref: "Real Mudlet focused/full suite"
        status: unknown
    human_judgment: true
    rationale: "Local real-Mudlet execution is unavailable because /tmp/Mudlet.AppImage is absent; host Busted is diagnostic only and is not a substitute."
duration: 11m
completed: 2026-07-27
status: complete
---

# Phase 03 Plan 14: Disabled Lifecycle Recovery Summary

**A prompt-only lifecycle boundary now reconciles the canonical `gmcp:ire` owner in either evidence order while disabled automation stays inert and incomplete room evidence remains blocked through an 8-second warning.**

## Performance

- **Duration:** 11m
- **Started:** 2026-07-27T07:10:46Z
- **Completed:** 2026-07-27T07:21:23Z
- **Tasks:** 3
- **Files modified:** 10

## Accomplishments

- Added four exact lifecycle regressions covering trigger ownership, both IRE/prompt evidence orders, unrelated-owner preservation, enable-before-prompt behavior, disabled zero-effect guarantees, and calibrated room-response timing.
- Relocated the sole prompt dispatcher into an always-active `boop lifecycle` folder while retaining all combat, gagging, targeting, gold, queue, and walker triggers under the hunting-owned `boop` folder.
- Added public IRE reconciliation and Display event observers so current support can complete the existing `gmcp:ire` owner without Char.Status, enable, a duplicate blocker model, or an evidence-path support request.
- Made prompt and IRE event paths evidence-only while disabled, preserving idempotency and unrelated owners before returning ahead of runtime or automation effects.
- Calibrated the room-response warning from 4.0 to 8.0 seconds; it warns exactly once while leaving canonical `room:observation` fail closed.
- Preserved deferred hyena output and prefix/custom attack scope without adding commands or help surface.

## Task Commits

Each implementation task was committed atomically:

1. **Task 1: Add RED lifecycle recovery regressions** - `8b84c94` (test, version `0.1.426`)
2. **Task 2: Isolate lifecycle recovery observers and calibrate room warning** - `e42fc7c` (feat, version `0.1.427`)
3. **Task 3: Verify and record Plan 03-14 completion** - planning-only metadata commit containing this summary and tracking updates

## Files Created/Modified

- `tests/boop_lifecycle_spec.lua` - Defines the four exact disabled-lifecycle, evidence-order, zero-effect, and room-warning contracts.
- `tests/boop_event_transitions_spec.lua` - Aligns enabled target-event fixtures with the new preceding IRE evidence observation and exact-owner release order.
- `src/scripts/boop/boop_init.lua` - Separates always-active lifecycle trigger synchronization from hunting automation and reconciles current IRE support on enable.
- `src/scripts/boop/boop_events.lua` - Adds public IRE reconciliation/event observation, disabled evidence-only returns, Display event registration, and the 8.0-second room warning.
- `src/triggers/triggers.json` - Registers active `boop lifecycle` beside inactive hunting-owned `boop`.
- `src/triggers/boop/Core/triggers.json` - Removes the old Core prompt object.
- `src/triggers/boop_lifecycle/Prompt.lua` - Relocates the single prompt dispatcher without changing its call surface.
- `src/triggers/boop_lifecycle/triggers.json` - Declares the prompt-only lifecycle trigger folder.
- `mfile`, `src/scripts/boop/boop_init.lua`, `CODEX.md` - Synchronize package version checkpoints through RED `0.1.426` and final GREEN `0.1.427`.

## Decisions Made

- The lifecycle folder is permanently available but deliberately prompt-only. Hunting automation remains governed by the existing `boop` trigger folder.
- `gmcp:ire` remains the sole recovery owner. Connection, Char.Status, enable, prompt, and actual IRE events reconcile that owner rather than introducing parallel lifecycle state.
- Prompt and IRE callbacks may record evidence while disabled, but return before target updates, prompt gagging, runtime steps, attacks, gold, queue work, or walker movement.
- The measured room-response warning threshold is 8.0 seconds. A warning is diagnostic only and cannot clear or bypass `room:observation`.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Corrected Busted global GMCP replacement**

- **Found during:** Task 2 focused GREEN verification
- **Issue:** Assigning a replacement GMCP table through the Busted environment did not update `_G.gmcp`, so the implementation could not observe the test's current IRE support.
- **Fix:** Updated the lifecycle fixture to replace the actual global and restore it through the existing test cleanup path.
- **Files modified:** `tests/boop_lifecycle_spec.lua`
- **Verification:** All four exact lifecycle tests and the 109-test aggregate pass.
- **Committed in:** `e42fc7c`

**2. [Rule 3 - Blocking] Aligned legacy target-event fixtures with enabled behavior and IRE-first observation**

- **Found during:** Task 2 regression-suite verification
- **Issue:** Four legacy target-event tests exercised automation while `boop.config.enabled` was false and expected target behavior to precede the new canonical IRE event observation.
- **Fix:** Made their enabled precondition explicit and updated call-order expectations to include `gmcp:ire` evidence before target handling and prompt release.
- **Files modified:** `tests/boop_event_transitions_spec.lua`
- **Verification:** Event transitions and the complete 109-test aggregate pass with zero failures or errors.
- **Committed in:** `e42fc7c`

**3. [Rule 1 - Bug] Preserved automation shutdown when a host trigger API is partially unavailable**

- **Found during:** Task 2 safety regression verification
- **Issue:** The first lifecycle-folder synchronization implementation returned early when `enableTrigger` was unavailable, preventing an available `disableTrigger` from shutting down hunting automation.
- **Fix:** Lifecycle and automation trigger calls now execute independently and the function reports combined success without skipping a safe shutdown path.
- **Files modified:** `src/scripts/boop/boop_init.lua`, `tests/boop_lifecycle_spec.lua`
- **Verification:** Safety regressions and the complete 109-test aggregate pass.
- **Committed in:** `e42fc7c`

**4. [Rule 1 - Bug] Corrected inconsistent generic state-handler closeout**

- **Found during:** Task 3 planning/state closeout
- **Issue:** The generic handlers counted all 28 plans but advanced Phase 03 to Plan 2, marked three phases complete and 50% progress before live verification, and labeled new decisions as `Phase ?`.
- **Fix:** Recorded Plan 14 of 14 at 100% plan completion, retained only two completed phases, marked Phase 03 ready for verification with live UAT pending, refreshed metrics, and labeled decisions as Phase 03.
- **Files modified:** `.planning/STATE.md`
- **Verification:** STATE and ROADMAP agree on 14/14 executed plans while Phase 03 remains in progress pending live UAT.
- **Committed in:** Plan metadata closeout commit

---

**Total deviations:** 4 auto-fixed (2 Rule 1 bugs, 2 Rule 3 blocking fixtures)
**Impact on plan:** The fixes preserve the plan's exact lifecycle boundary and compatibility contract while keeping planning state honest about pending live verification; no command, help, combat, hyena, prefix, or custom-attack scope was added.

## Issues Encountered

- The first Muddler attempt used non-TTY execution and its container wrapper rejected stdin attachment. Re-running Muddler with a PTY completed successfully at version `0.1.427`.
- Local real-Mudlet execution is unavailable: `/tmp/Mudlet.AppImage` was not found. Host Busted is diagnostic only and is not a substitute, so live UAT remains pending.

## Verification

- TDD RED: each exact lifecycle test failed independently with one intentional marker, zero errors, and no unrelated failures: three `GAP_03_3_LIFECYCLE_BOUNDARY_BROKEN` cases and one `GAP_03_3_ROOM_WARNING_WINDOW_BROKEN` case.
- Focused GREEN: 4 successes, 0 failures, 0 errors, 0 pending.
- Plan-level persistence/safety/event/walk/gold/lifecycle aggregate: 109 successes, 0 failures, 0 errors, 0 pending.
- Lua syntax: the host helper, init, events, lifecycle prompt dispatcher, and lifecycle spec pass `luac -p`.
- Trigger boundary: `boop lifecycle` is active and contains exactly one prompt observer; the old Core prompt is absent and no duplicate prompt dispatch remains.
- Release gates: versions, manifests, and state drift pass at synchronized version `0.1.427`.
- Muddler: version 1.1.0 built `build/boop Hunter.mpackage` successfully at `0.1.427`; ignored generated output was not staged or committed.
- Diff hygiene: `git diff --check` passes.
- Local real-Mudlet: unavailable because `/tmp/Mudlet.AppImage` is absent; live UAT is not marked passed.
- Parent-owned exact-final-HEAD GitHub Actions gate: intentionally not run or claimed.

## Known Stubs

- The lifecycle and event-transition specs use Busted stubs, captured timer callbacks, synthetic GMCP tables, and empty fixture values as intentional deterministic test infrastructure.
- Existing empty-string defaults in `boop_init.lua` are valid unset configuration values; this plan introduced no runtime or operator-facing stub.

## User Setup Required

None - no dependencies, commands, help surface, or external configuration changed.

## Live UAT handoff

Use package 0.1.427 built from the final execution commit. Keep `boop trace on` during all steps and paste back `boop status`, the owner snapshot line, and `boop trace show 100` for each scenario.

1. Disabled IRE event then prompt, without Char.Status or enable:
   - Preconditions: confirm `type(gmcp.IRE) == "table"` and `type(gmcp.IRE.Display) == "table"`, then run `boop off`, `boop trace clear`, and `boop trace on`.
   - Run `lua _boopUatIre=gmcp.IRE; gmcp.IRE=nil; boop.onConnectionEvent(); boop.runtime.setBlocker("uat:unrelated", "interrupt_pending", "UAT unrelated", {combat=true}, {}, {source="uat"}); gmcp.IRE=_boopUatIre; raiseEvent("gmcp.IRE.Display.FixedFont"); local s=boop.runtime.state(); local b=s.combat.blockersByOwner["gmcp:ire"]; echo(string.format("enabled=%s owner=%s gmcpSeen=%s promptSeen=%s unrelated=%s\n", tostring(boop.config.enabled), tostring(b and b.code or "none"), tostring(b and b.gmcpSeen or false), tostring(b and b.promptSeen or false), tostring(s.combat.blockersByOwner["uat:unrelated"]~=nil)))`.
   - Without calling `boop.onCharStatus()`, `boop on`, or any enable synchronization, expect that same command to print `enabled=false`, `owner=gmcp_ire_missing`, `gmcpSeen=true`, `promptSeen=false`, and `unrelated=true`.
   - Run `lua boop.onPrompt()`, then repeat the snapshot. Expect `owner=none` and `unrelated=true`. `boop trace show 100` must contain no attack, target update, `get`, `put`, queue execution, prompt gag, or `demonwalker.move` from the disabled evidence inputs.

2. Disabled prompt then IRE event, without Char.Status or enable:
   - Run `lua gmcp.IRE=nil; boop.onConnectionEvent(); boop.onPrompt(); local s=boop.runtime.state(); local b=s.combat.blockersByOwner["gmcp:ire"]; echo(string.format("enabled=%s owner=%s gmcpSeen=%s promptSeen=%s unrelated=%s\n", tostring(boop.config.enabled), tostring(b and b.code or "none"), tostring(b and b.gmcpSeen or false), tostring(b and b.promptSeen or false), tostring(s.combat.blockersByOwner["uat:unrelated"]~=nil)))`. Expect `enabled=false`, `owner=gmcp_ire_missing`, `gmcpSeen=false`, `promptSeen=true`, and `unrelated=true`.
   - Run `lua gmcp.IRE=_boopUatIre; raiseEvent("gmcp.IRE.Display.Ohmap")`, then repeat the snapshot. Expect `owner=none` and `unrelated=true`.
   - Repeat `lua boop.onPrompt(); raiseEvent("gmcp.IRE.Display.Ohmap")`; the owner must remain absent and `uat:unrelated` must survive. Clean up with `lua boop.runtime.clearBlocker("uat:unrelated", "UAT cleanup"); _boopUatIre=nil`.

3. Enable before the next prompt remains fail closed:
   - Run `boop off`, then `lua _boopUatIre=gmcp.IRE; gmcp.IRE=nil; boop.onConnectionEvent(); gmcp.IRE=_boopUatIre; raiseEvent("gmcp.IRE.Display.ButtonActions")`, followed by `boop on` before invoking another prompt.
   - Run the owner snapshot. Expect `enabled=true`, `owner=gmcp_ire_missing`, `gmcpSeen=true`, and `promptSeen=false`.
   - Cause one prompt with operator command `ql`, then repeat the snapshot. Expect `owner=none`. A second prompt remains idempotent. Clean up with `lua _boopUatIre=nil`.

4. Ordinary room latency:
   - Run `boop trace clear`, `boop trace on`, and a normal `boop walk start`, then traverse at least five room transitions.
   - For every `Char.Items.Room` response arriving within 8.0 seconds, `boop trace show 100` must contain no `room response fence timeout`; each settled room may produce at most one `demonwalker.move`.

5. Forced incomplete room evidence:
   - Run `boop walk stop`, then `lua _boopUatRoomItems=boop.onRoomItemsList; boop.onRoomItemsList=function() return false end`, followed by `boop trace clear`, `boop trace on`, and `boop walk start`.
   - Wait 9 seconds without restoring the handler. Expect exactly one `[WARN] room_partial -- room response fence incomplete`, one `room response fence timeout` trace, an active `room_partial`/`room:observation` blocker in `boop status`, and no `demonwalker.move`, attack, `get`, or `put` during the suppression window.
   - Restore immediately with `lua boop.onRoomItemsList=_boopUatRoomItems; _boopUatRoomItems=nil`, then run `boop walk stop` and `boop walk start`. Confirm fresh complete evidence settles normally; do not leave the UAT override installed.

6. Original blocked UAT rerun:
   - During a live room transition, run `diag`, then run `lua local s=boop.runtime.state(); local op=s.diag.operation; echo(string.format("interruptOwner=%s roomOwner=%s\n", tostring(type(op)=="table" and op.blockerOwner or "none"), tostring(s.combat.blockersByOwner["room:observation"] and "room:observation" or "none")))`. Expect `interruptOwner=interrupt:<generation>` and `roomOwner=room:observation`. Confirm no attack, gold transfer, queue action, or walker move occurs until that exact generation-owned interrupt owner and `room:observation` are both clear, then exactly one next eligible action occurs.
   - With `boop on`, automatic gold on, and a configured pack, kill one mobile and send a same-room `ql`. Confirm exactly one eligible `queue add freestand get sovereigns` and one matching `queue add freestand put sovereigns in <pack>`, with no stale `gmcp_ire_missing` owner.

7. Final handoff:
   - Run `boop status`, the owner snapshot, and `boop trace show 100`; paste back all three outputs.
   - The executor does not push. After all repository mutations are complete, the parent session pushes immutable final HEAD and runs `tools/wait_for_exact_ci.sh`; success is valid only for a `main.yml` run whose `headSha` exactly matches that final HEAD.

## Next Phase Readiness

- All 14 Phase 03 plans now have implementation and automated regression evidence.
- Phase 03 live UAT remains pending. The handoff above must be run in real Mudlet before the phase can claim live verification.
- The parent retains sole authority to push immutable final HEAD and run `tools/wait_for_exact_ci.sh` after this planning/state closeout.

## Self-Check: PASSED

- The summary, all implementation/test files, and the prompt-only lifecycle manifest exist; the legacy Core prompt path is absent.
- Task commits `8b84c94` and `e42fc7c` are present in RED → GREEN order.
- The Live UAT handoff matches Plan 03-14 verbatim.
- The 109-test aggregate, Lua syntax, release gates, Muddler build, and diff hygiene checks pass at synchronized version `0.1.427`.

---
*Phase: 03-queue-interrupt-gold-and-autowalk-regression-coverage*
*Completed: 2026-07-27*
