---
status: complete
phase: 03-queue-interrupt-gold-and-autowalk-regression-coverage
source:
  - 03-VERIFICATION.md
started: 2026-07-26T21:45:34Z
updated: 2026-07-28T06:34:29Z
---

# Phase 03 UAT: Queue, Interrupt, Gold, and Autowalk Regression Coverage

## Current Test

[testing complete]

## Tests

### 1. Disabled lifecycle recovery

expected: |
  With boop 0.1.429 installed, the prompt-only lifecycle observer remains active
  while hunting is off. IRE and prompt evidence may arrive in either order; only
  `gmcp:ire` clears after both are present, unrelated blockers survive, and
  enabling before the prompt remains held until that prompt arrives.

  Easy check:
  1. In an empty safe room, run `boop off`, `boop trace clear`, and
     `boop trace on`. Cleanly close and reopen Mudlet. After the first prompt,
     run `boop status` and `boop trace show 100`. `gmcp_ire_missing` must be
     gone, and there must be no attack, target, gold, queue, gag, or walker
     action while boop was disabled.
  2. Test prompt-first with:
     `lua boop.runtime.setBlocker("uat:unrelated","uat_hold","UAT unrelated hold",{combat=true},{timeout=true},{source="uat"}); _boopUatIre=gmcp.IRE; gmcp.IRE=nil; boop.runtime.clearBlocker("gmcp:ire","uat reset"); boop.onConnectionEvent(); boop.onPrompt(); gmcp.IRE=_boopUatIre; boop.onIreSupportObserved("uat prompt first")`
     Then run `boop status`. `gmcp_ire_missing` must be absent while the
     `uat:unrelated` hold remains.
  3. Test enable-before-prompt with:
     `lua gmcp.IRE=nil; boop.runtime.clearBlocker("gmcp:ire","uat reset"); boop.onConnectionEvent(); gmcp.IRE=_boopUatIre; boop.config.enabled=true; boop.triggers.syncEnabled()`
     Run `boop status`: it should still show `gmcp_ire_missing` waiting for the
     prompt. Run `ql`, wait for its prompt, then run `boop status` again. The
     GMCP blocker must be gone while `uat:unrelated` remains.
  4. Clean up with `boop off`, then:
     `lua boop.runtime.clearBlocker("uat:unrelated","uat cleanup"); gmcp.IRE=_boopUatIre; _boopUatIre=nil`
result: pass
observed: "Clean reconnect, prompt-first, and enable-before-prompt checks passed; the unrelated owner remained as uat_hold -- UAT unrelated hold."

### 2. Cross-owner attack, loot, and walk release

expected: |
  With boop 0.1.429 installed, room settlement accepts the live GMCP ordering, same-room refreshes preserve the accepted room, and stop/restart cannot reuse stale evidence. No automatic attack, loot command, or walker move occurs while another safety owner remains; exactly one next action resumes after all owners release.

  Easy check:
  1. Run `boop on`, `boop trace clear`, `boop trace on`, and `boop walk stop`, then start a normal route with `boop walk start`.
  2. Let the walker cross several rooms. In one room, run `ql` to force a same-room refresh; stop and restart the walker once.
  3. During one room transition, run `diag`. No attack, get/put, or walker move may occur until `diag` and every other visible blocker clear; then exactly one next action should resume.
  4. Run `boop trace show 100`. There must be no `room_partial` hold that persists until an unrelated later GMCP event, no ordinary sub-8-second room warning, and at most one walker move per settled room.
result: issue
reported: "boop walk stop doesn't return any sort of message when running in step 1. After doing boop walk start, no movement is done. blocker shown is room_clear -- room clear. This is after seeing the same issue, and completely restarting mudlet."
severity: major
previous_result: "Before Plans 03-11/03-12, List-before-Info followed by same-room Info created a new partial generation and stalled the walker."

### 3. Wrong-room gold and pack transfer

expected: |
  With boop 0.1.429 installed, current-room gold queues one get without requiring exit/re-entry. Same-room Room.Info preserves pickup, actual movement cancels room-owned acquisition, and confirmed pickup permits exactly one inventory-owned put even if movement follows. No loot command is chained with an attack.

  Easy check:
  1. Stop the walker, then run `boop on`, `boop trace clear`, `boop trace on`, `boop autogold on`, and configure a valid `boop pack <container>`.
  2. Kill one mob and stay in the room. Immediately after the get is queued, run `ql`. The get must not be cancelled by the same-room refresh, and the gold must be put in the configured pack without leaving and re-entering.
  3. Repeat and move to the next room before pickup confirms. Wait five seconds; no old-room get or retry may be sent in the new room.
  4. Repeat once more, but move only after pickup confirms or `gold_pack_pending` appears. Exactly one put may finish after movement. Run `boop trace show 100` and confirm no standard/rage attack command contains get or put.
result: issue
reported: "Check output.md. Does not appear to be working whatsoever. Actual hunting is also broken, it seems. It will sometimes attack the first mob in the room, but then gets jammed up."
severity: blocker
previous_blocker: "Gold was recognized in GMCP, but the reconnect snapshot showed boop enabled=false and gmcp_ire_missing was waiting for prompt evidence."
previous_result: "Before Plans 03-11/03-13, pickup required exit/re-entry and a same-room Room.Info cancelled the queued get before packing."

### 4. Optional walker and stop ownership

expected: |
  Without demonnicAutoWalker, walk status, start, and move never install or update the package, while explicit install provides visible feedback. With the package present, stopping a boop-owned run emits one external stop, while detaching from an already-running external walk does not stop that run.

  Easy check:
  1. Simulate an unavailable package without uninstalling it: `lua _boopWalkerTest = demonwalker; demonwalker = nil`, then run `boop walk status`, `boop walk start`, and `boop walk move`. Each must report unavailable/blocked without opening an installer.
  2. Restore it with `lua demonwalker = _boopWalkerTest; _boopWalkerTest = nil`. Running `boop walk install` now should visibly report that the package is already available.
  3. Owned run: ensure no walk is active, run `boop walk start`, then `boop walk stop`. It should say the boop-owned run ended, and `lua echo(tostring(demonwalker.enabled))` should print `false`.
  4. Attached run: run `lua demonwalker:init()`, `boop walk start`, then `boop walk stop`. It should say detached, and `lua echo(tostring(demonwalker.enabled))` should still print `true`; clean up with `lua raiseEvent("demonwalker.stop")`.
result: pass

### 5. Exact-final-SHA packaged Mudlet CI

expected: |
  The immutable final commit is present on origin and `main.yml` succeeds for
  that exact `headSha`. The complete packaged real-Mudlet Busted suite,
  including Psion and Dragon pull-profile cases, reports no failures or errors.
result: pass
source: automated
evidence: "GitHub Actions run 30265771025 passed for 07d73e8b38823277a8132cbcded2ea9f88e92f08."

## Summary

total: 5
passed: 3
issues: 2
pending: 0
skipped: 0
blocked: 0

## Gaps

- gap_id: G-03-1
  truth: "Room settlement accepts either live GMCP arrival order, preserves complete evidence across same-room Room.Info refreshes, and releases hunting and walker ownership exactly once when the current room is complete."
  status: resolved
  reason: "User reported a live walker stall. Trace evidence shows Char.Items.List before Room.Info, followed by a new items:false observation for moved=no; only a later duplicate room list clears room_partial."
  severity: major
  test: 2
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
  debug_session: ".planning/debug/resolved/phase-03-room-evidence-ordering.md"
  resolved_by:
    - "03-11-PLAN.md"
    - "03-12-PLAN.md"
  verification: "03-VERIFICATION.md reports the implementation gap closed at 0.1.425; post-fix live UAT Test 1 remains pending."

- gap_id: G-03-2
  truth: "Room-owned pickup is cancelled only by an actual room change; confirmed pickup transfers to inventory-owned packing, which may complete after movement, and loot is never chained with an attack."
  status: resolved
  reason: "User reported that no get was sent after the kill; after exit and re-entry the get was finally queued, but no put followed. Trace shows the same-room Room.Info cancelled pickup generation 9 as room_changed immediately after the get was queued, so the subsequent item removal could not transfer the operation to packing."
  severity: major
  test: 3
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
  debug_session: ".planning/debug/resolved/phase-03-gold-same-room-cancellation.md"
  resolved_by:
    - "03-11-PLAN.md"
    - "03-13-PLAN.md"
  verification: "03-VERIFICATION.md reports the implementation gap closed at 0.1.425; post-fix live UAT Test 2 remains pending."

- gap_id: G-03-3
  truth: "A live walk settles from current room evidence and advances once after all blockers clear; valid gmcp.IRE data releases the recovery blocker without requiring Char.Status to repeat."
  status: resolved
  reason: "User reported Test 1 did not pass. Trace evidence shows every settled room remains held by gmcp_ire_missing and response-fence warnings recur before live room lists arrive. A focused reconnect snapshot then proved the owner had gmcpSeen=true and observed ire=true but promptSeen=false while boop enabled=false."
  severity: major
  test: 1
  root_cause: "The GMCP recovery owner requires both GMCP and prompt evidence, but boop.triggers.syncEnabled disables the entire boop trigger folder whenever hunting is off. The only boop.onPrompt boundary lives inside that folder, so a connection-time owner can observe valid IRE while disabled but can never observe the prompt needed to clear. Starting walk or enabling automation can therefore inherit a stale highest-priority owner and deadlock before any command produces a new prompt."
  artifacts:
    - path: "src/scripts/boop/boop_init.lua"
      issue: "boop.triggers.setEnabled toggles the whole boop trigger folder from config.enabled, including lifecycle evidence needed while hunting is disabled."
    - path: "src/triggers/boop/Core/Prompt.lua"
      issue: "The sole prompt observer calls boop.onPrompt from inside the folder disabled by boop off."
    - path: "src/scripts/boop/boop_events.lua"
      issue: "gmcp:ire declares both gmcp and prompt waits, but has no enable-boundary recovery for prompt evidence missed while its trigger was disabled."
    - path: "src/scripts/boop/boop_events.lua"
      issue: "The fixed 0.35-second room-response warning fires before normal live room-list responses in every sampled room, obscuring whether a response is actually lost."
  missing:
    - "Keep the minimal prompt/lifecycle evidence boundary active while hunting is off, without re-enabling combat, gag, or automation triggers."
    - "Reconcile current IRE evidence at connection and enable boundaries so GMCP and prompt may arrive in either order without leaving a stale owner."
    - "Cover disabled reconnect -> IRE observed -> prompt observed -> enable, plus enable-before-next-prompt, with exact owner release and zero automation while disabled."
    - "Calibrate or redefine the room-response timeout so ordinary live response latency is not reported as an incomplete fence while genuine missing responses remain fail closed."
  resolved_by:
    - "03-14-PLAN.md"
  resolved_at: 2026-07-27
  verification: "03-VERIFICATION.md reports all automated lifecycle contracts green at 0.1.429; live UAT Test 1 remains pending."

- gap_id: G-03-4
  truth: "Starting a live boop walk from a settled room emits movement, and stopping it gives visible operator feedback."
  status: failed
  reason: "User reported: boop walk stop produced no message; boop walk start produced no movement while the blocker displayed room_clear -- room clear, including after a complete Mudlet restart."
  severity: major
  test: 2
  artifacts: []
  missing: []

- gap_id: G-03-5
  truth: "A live gold drop advances from current-room evidence to get and pack without indefinitely blocking retargeted hunting."
  status: failed
  reason: "User reported that gold handling did not appear to work and normal hunting attacked inconsistently before jamming. output.md shows gold:3 entering gold_deferred_room at 23:31:57 after a current-room gold add, retargeting the next denizen, then holding the combat queue for more than 40 seconds until later manual room refresh/movement."
  severity: blocker
  test: 3
  artifacts: []
  missing: []
