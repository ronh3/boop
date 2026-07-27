---
status: diagnosed
phase: 03-queue-interrupt-gold-and-autowalk-regression-coverage
source:
  - 03-VERIFICATION.md
started: 2026-07-26T21:45:34Z
updated: 2026-07-27T01:12:23Z
---

# Phase 03 UAT: Queue, Interrupt, Gold, and Autowalk Regression Coverage

## Current Test

[testing complete]

## Tests

### 1. Cross-owner attack, loot, and walk release

expected: |
  In a safe Achaea test area with autogold and demonnicAutoWalker enabled, exercising `diag`, one queued interrupt, and `pull` while a real target or gold lifecycle is active sends no automatic attack, loot command, or walker move until every relevant owner releases. Exactly one next action resumes after aggregate all-clear.
result: issue
reported: "Walk appears not to receive complete room state. The live trace shows gmcp.Char.Items.List arriving before gmcp.Room.Info; Room.Info then starts a new items:false generation even when moved=no, and the walker remains held until another room list arrives."
severity: major

### 2. Wrong-room gold and pack transfer

expected: |
  Gold evidence created in room A cannot cause a room-A get or retry after moving to room B. A confirmed inventory-owned put may finish after movement, and no loot command is chained with an attack.

  Easy check:
  1. Stop the walker, then run `boop trace clear`, `boop trace on`, `boop autogold on`, and configure a valid `boop pack <container>`.
  2. In room A beside an exit, kill a mob and move manually to room B as soon as the first `get sovereigns` is queued. Wait at least five seconds, then run `boop trace show 40`.
  3. The initial get may have been sent in room A, but there must be no get or retry sent after the room change; the old room-owned gold operation should end with `reason=room_changed`.
  4. Repeat, but let pickup succeed first. Move after `gold_pack_pending` or the put is queued; the inventory-owned put may finish after movement, and no standard/rage command may contain get or put.
result: issue
reported: "The get gold command was never sent after killing the mob. After exiting and re-entering the room, it was picked up. The gold was never put in the pack."
severity: major

### 3. Optional walker and stop ownership

expected: |
  Without demonnicAutoWalker, walk status, start, and move never install or update the package, while explicit install provides visible feedback. With the package present, stopping a boop-owned run emits one external stop, while detaching from an already-running external walk does not stop that run.

  Easy check:
  1. Simulate an unavailable package without uninstalling it: `lua _boopWalkerTest = demonwalker; demonwalker = nil`, then run `boop walk status`, `boop walk start`, and `boop walk move`. Each must report unavailable/blocked without opening an installer.
  2. Restore it with `lua demonwalker = _boopWalkerTest; _boopWalkerTest = nil`. Running `boop walk install` now should visibly report that the package is already available.
  3. Owned run: ensure no walk is active, run `boop walk start`, then `boop walk stop`. It should say the boop-owned run ended, and `lua echo(tostring(demonwalker.enabled))` should print `false`.
  4. Attached run: run `lua demonwalker:init()`, `boop walk start`, then `boop walk stop`. It should say detached, and `lua echo(tostring(demonwalker.enabled))` should still print `true`; clean up with `lua raiseEvent("demonwalker.stop")`.
result: pass

## Summary

total: 3
passed: 1
issues: 2
pending: 0
skipped: 0
blocked: 0

## Gaps

- gap_id: G-03-1
  truth: "Room settlement accepts either live GMCP arrival order, preserves complete evidence across same-room Room.Info refreshes, and releases hunting and walker ownership exactly once when the current room is complete."
  status: failed
  reason: "User reported a live walker stall. Trace evidence shows Char.Items.List before Room.Info, followed by a new items:false observation for moved=no; only a later duplicate room list clears room_partial."
  severity: major
  test: 1
  root_cause: "Phase 03 models settlement as an ordered Room.Info -> Char.Items.List pair. boop.onRoomInfo starts a fresh itemsSeen=false observation before determining whether the room changed, so same-room refreshes discard valid evidence and may stall or double-advance the walker. Because List has no room ID, the current stamp path can also authenticate stale old-room items against the persistent new Room.Info table."
  artifacts:
    - path: "src/scripts/boop/boop_events.lua"
      issue: "onRoomInfo unconditionally starts a new observation and invalidates room-owned gold before determining whether the room ID actually changed."
    - path: "src/scripts/boop/boop_runtime.lua"
      issue: "The observation API cannot retain pending item-list evidence for reconciliation with a following Room.Info event."
    - path: "src/scripts/boop/boop_walk.lua"
      issue: "demonwalker.arrived is treated only as a refresh fallback instead of a validated transition hint for reconciling unordered room evidence."
  missing:
    - "Treat Room.Info and Char.Items.List as an unordered event pair while retaining fail-closed room identity checks."
    - "Preserve settled item evidence and room-owned gold on same-room Room.Info updates; invalidate them only on an actual room ID change."
    - "Use validated demonwalker.arrived/current-room identity as a transition hint, never as standalone room evidence."
    - "Keep ambiguous list-first evidence unbound until safely reconciled, and reject stale old-room lists without replacing denizens or releasing owners."
    - "Add regressions for list-before-info, info-before-list, same-room refresh, stale prior-room lists, delayed refresh, and initial/non-movement walker arrival."
  debug_session: ".planning/debug/phase-03-room-evidence-ordering.md"

- gap_id: G-03-2
  truth: "Room-owned pickup is cancelled only by an actual room change; confirmed pickup transfers to inventory-owned packing, which may complete after movement, and loot is never chained with an attack."
  status: failed
  reason: "User reported that no get was sent after the kill; after exit and re-entry the get was finally queued, but no put followed. Trace shows the same-room Room.Info cancelled pickup generation 9 as room_changed immediately after the get was queued, so the subsequent item removal could not transfer the operation to packing."
  severity: major
  test: 2
  root_cause: "Two linked defects occur at separate transitions: the Info-first-only observation model cannot retain and reconcile List-before-Info evidence, delaying pickup; then boop.onRoomInfo terminates DEFERRED_ROOM and PICKUP_PENDING before comparing the incoming room ID with targeting.room, so same-room Info destroys the live pickup before success can transfer it to inventory-owned packing."
  artifacts:
    - path: "src/scripts/boop/boop_events.lua"
      issue: "onRoomInfo calls completeGoldOperation(..., room_changed) for room-owned stages even when traceRoomInfo later reports moved=no."
    - path: "src/scripts/boop/boop_runtime.lua"
      issue: "List-before-info evidence cannot be reconciled into the current room observation, leaving gold deferred until another list or timeout."
  missing:
    - "Cancel room-owned gold only after confirming the room ID actually changed."
    - "Reconcile list-before-info evidence so a current-room gold add/list can advance pickup without requiring exit and re-entry."
    - "Add a regression for list -> get queued -> same-room Room.Info -> get success/item removal -> inventory-owned put."
  debug_session: ".planning/debug/phase-03-gold-same-room-cancellation.md"
