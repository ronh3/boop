---
status: complete
phase: 03-queue-interrupt-gold-and-autowalk-regression-coverage
source:
  - 03-VERIFICATION.md
started: 2026-07-26T21:45:34Z
updated: 2026-07-28T21:11:40-07:00
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
  With boop 0.1.441 installed, manual targeting remains an intentional
  automatic-walk hold and is reported as `manual_targeting`, not `room_clear`.
  Room settlement accepts the live GMCP ordering, same-room refreshes preserve
  the accepted room, and stop/restart cannot reuse stale evidence. No automatic
  attack, loot command, or walker move occurs while another safety owner
  remains; exactly one next action resumes after automatic targeting is
  selected and all owners release.

  Easy check:
  1. Run `boop on`, `boop trace clear`, and `boop trace on`. With no
     boop walk active, run `boop walk stop`; it must print exactly
     `walk stop: no active boop walk`.
  2. Run `boop targeting manual`, then start a normal route with
     `boop walk start`. Run `boop status`: it must show
     `manual_targeting -- manual targeting is active`, give
     `boop targeting auto` as the next action, and emit no walker movement or
     movement reservation while manual targeting remains selected.
  3. Run `boop targeting auto`. Only after automatic targeting is selected and
     every other blocker is clear should exactly one eligible walker movement
     occur for the settled room.
  4. Let the walker cross several rooms. In one room, run `ql` to force a
     same-room refresh; stop and restart the boop-owned walker once and retain
     its distinct `walk stopped -- boop-owned demonwalker run ended` feedback.
     The already-passed attached-run check remains non-destructive and must
     continue to report
     `walk detached -- external demonwalker run remains active`.
  5. During one room transition, run `diag`. No attack, get/put, or walker move
     may occur until `diag` and every other visible blocker clear; then exactly
     one next action should resume.
  6. Run `boop trace show 100`. There must be no `room_partial` hold that
     persists until an unrelated later GMCP event, no ordinary sub-8-second
     room warning, and at most one walker move per settled room.
result: issue
reported: |
  1. Pass.
  2. Appears not to pass.
     See output.md. The walker does not appear to ever actually start moving rooms/start. Version is 441.
severity: major
observed: "Step 1 passed with the exact inactive-stop message. After walk start, output.md shows the active walker held by walk_room_unsettled, followed by room_partial; it never reaches the expected manual_targeting hold or emits movement. Switching to automatic targeting instead exposes engaged_target for stale target 6832 while room denizens remain zero."
previous_reported: "boop walk stop doesn't return any sort of message when running in step 1. After doing boop walk start, no movement is done. blocker shown is room_clear -- room clear. This is after seeing the same issue, and completely restarting mudlet."
previous_severity: major
previous_result: "Before Plans 03-11/03-12, List-before-Info followed by same-room Info created a new partial generation and stalled the walker."

### 3. Wrong-room gold and pack transfer

expected: |
  With boop 0.1.441 installed, a gold Item.Add in an already settled room
  requests one current-room revalidation but cannot authorize pickup by itself.
  Only the matching fenced room List may queue one get. Confirmed pickup may
  queue one put, while stale, duplicate, wrong-room, and movement-invalidated
  responses do nothing. Completing or cancelling gold must release its owner so
  hunting and walking cannot remain permanently jammed.

  Easy check:
  1. Stop the walker, then run `boop on`, `boop trace clear`,
     `boop trace on`, `boop trace live on`, `boop autogold on`, and configure
     a valid `boop pack <container>`.
  2. Kill one mob and stay in the room. The live trace should show one
     room-only revalidation after the gold Add, followed by exactly one get
     only after the matching room List. Pickup confirmation should permit
     exactly one put without requiring exit and re-entry.
  3. Repeat, but move immediately after the gold drop and before pickup.
     Wait five seconds. No old-room get, retry, put, attack, or walker move may
     be emitted from the invalidated response.
  4. Repeat once more while `diag` owns an unrelated hold. Gold may revalidate,
     but no get, put, attack, or walker move may occur until every owner clears.
     After the final owner clears, exactly one eligible action may resume and
     hunting must not remain jammed.
  5. Run `boop trace show 100`. Confirm no standard/rage attack command
     contains get or put, no gold generation dispatches twice, and stale room
     responses have no side effects.
result: issue
reported: "Check output.md. Behavior does not seem quite right. Boop did not start attacking until another command (boop status, ql, etc.) were checked. Gold pickup seems wonky at best, pickup seeming to not occur after death when doing a diag prior, etc. Think the gold timeout may be too short?"
severity: major
observed: "Normal gold generations 1, 2, 4, and 6 complete one get-confirm-put sequence. Room settlement repeatedly remains room_partial until a later ql/ih/status-adjacent event supplies the missing room List, corroborating G-03-7. In the failing diag sequence, gold generation 5 queues get sovereigns, diag then clears/replaces the shared freestand queue, no pickup confirmation arrives, and the fixed four-second gold timer terminates the operation while the sovereigns remain in room 4249; a later room refresh creates generation 6 and finally picks them up."
previous_reported: "Check output.md. Does not appear to be working whatsoever. Actual hunting is also broken, it seems. It will sometimes attack the first mob in the room, but then gets jammed up."
previous_severity: blocker
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
evidence: "GitHub Actions run 30342898415 passed for exact source/package SHA 95cfbb96b4428032570b3e6019ae61f0ed619b29."
previous_evidence: "GitHub Actions run 30265771025 passed for pre-gap SHA 07d73e8b38823277a8132cbcded2ea9f88e92f08."

### 6. Live trace correlation

expected: |
  With boop 0.1.441 installed, `boop trace live on|off` controls a
  session-only stream independently from persisted trace collection. Live mode
  is off after package load, never enables collection, prints each accepted
  timestamped entry exactly once without tracing itself, and resets off on
  package reload while retaining the buffer and persisted collection setting.

  Easy check:
  1. Run `boop trace off`, `boop trace clear`, then
     `boop trace live on`. It should report that live is on while collection
     remains off. Run `ql`; no live trace line and no buffered entry should
     appear.
  2. Run `boop trace on`, then `ql`. Each collected event should print once as
     `trace live: HH:MM:SS | ...`; none of those output lines may create
     another trace entry.
  3. Run `boop trace show 100`, then `boop trace clear`. Show must not add
     entries; clear must empty the buffer without turning live off.
  4. Reload/reinstall boop in the same Mudlet session. Run `boop trace`.
     Collection should retain its saved on/off setting, live must be off, and
     the pre-reload buffer must still be present unless it was cleared in
     step 3.
  5. Run `boop help diagnostics` and confirm collection and live streaming are
     described as separate controls.
result: pass
observed: "Collection-off isolation, exact-once live streaming, show/clear buffer behavior, package-reload reset, persisted collection state, and diagnostics help all appeared to pass."
previous_reported: "Could we introduce a debug mode that will essentially show the trace log events/actions in real time? I feel that might be handy here, to help correlate what's on the screen with boop's logs."
previous_severity: minor

## Summary

total: 6
passed: 4
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
  status: resolved
  reason: "User reported: boop walk stop produced no message; boop walk start produced no movement while the blocker displayed room_clear -- room clear, including after a complete Mudlet restart."
  severity: major
  test: 2
  root_cause: "Two independent defects combine in the UAT workflow. Movement is held because the persisted live configuration is targetingMode=manual, and boop.walk.evaluateAllClear explicitly rejects that state as manual_targeting; the dashboard omits this evaluator condition and instead reports room_clear, concealing the real hold. Separately, boop.walk.stop returns false immediately when inactive and emits no feedback, while the UI dispatcher ignores the return value."
  artifacts:
    - path: "src/scripts/boop/boop_walk.lua"
      issue: "The manual-targeting safety gate is correct, but inactive stop returns false without operator feedback."
    - path: "src/scripts/boop/boop_ui.lua"
      issue: "The shared dashboard does not consume the walk evaluator reason and the walk command dispatcher ignores an inactive-stop false return."
    - path: "tests/boop_walk_spec.lua"
      issue: "Coverage asserts the manual-targeting hold and active stop cases but omits dashboard parity and inactive-stop feedback."
  missing:
    - "Preserve the manual-targeting safety gate while surfacing manual_targeting as the actual walk/dashboard reason."
    - "Give boop walk stop explicit feedback when no boop walk is active."
    - "Cover inactive, owned, and attached stop feedback plus a settled walk in persisted manual mode."
    - "Make automatic targeting an explicit live-UAT precondition before movement is expected."
  debug_session: ".planning/debug/phase-03-live-walk-no-start-feedback.md"
  resolved_by:
    - "03-17-PLAN.md"
  verification: "Focused walk/UI host execution passes 85/85 at 0.1.433; post-fix live UAT Test 2 remains pending at package 0.1.434."

- gap_id: G-03-5
  truth: "A live gold drop advances from current-room evidence to get and pack without indefinitely blocking retargeted hunting."
  status: resolved
  reason: "User reported that gold handling did not appear to work and normal hunting attacked inconsistently before jamming. output.md shows gold:3 entering gold_deferred_room at 23:31:57 after a current-room gold add, retargeting the next denizen, then holding the combat queue for more than 40 seconds until later manual room refresh/movement."
  severity: blocker
  test: 3
  root_cause: "A settled current-room Item.Add updates targeting and detects gold but never patches or revalidates roomObservation.acceptedItems. Gold authorization requires that exact item in acceptedItems, while the preceding complete non-gold list leaves itemsSeen and refreshAttempted set so another response fence is refused. The gold generation therefore remains DEFERRED_ROOM and its exact owner holds combat, queue, and walk indefinitely despite successful retargeting."
  artifacts:
    - path: "src/scripts/boop/boop_events.lua"
      issue: "onRoomItemsAdd starts gold handling without applying a canonical current-epoch room mutation, while canonicalGoldEvidence requires the item in acceptedItems."
    - path: "src/scripts/boop/boop_runtime.lua"
      issue: "A settled observation cannot open the bounded revalidation needed by the deferred operation, and active gold exclusively occupies tick progression."
    - path: "tests/boop_gold_spec.lua"
      issue: "Coverage omits the live complete non-gold List followed by an incremental same-room gold Add."
  missing:
    - "Define one canonical, exact-current-epoch settled Item.Add/Remove mutation or bounded revalidation path."
    - "Reevaluate the same gold generation after the accepted mutation or response without weakening wrong-room and stale-fence rejection."
    - "Cover the live settled-list-to-add order, movement/stale boundaries, retargeting under aggregate owners, and exactly one get-confirm-put sequence."
  debug_session: ".planning/debug/phase-03-gold-deferred-hunting-stall.md"
  resolved_by:
    - "03-16-PLAN.md"
  verification: "03-VERIFICATION.md verifies the bounded settled-Add revalidation and exact get-confirm-put contracts at 0.1.441; post-fix live UAT Test 3 remains pending."

- gap_id: G-03-6
  truth: "An operator can stream newly recorded trace events in real time for the current session without changing normal output, persistence, or trace-buffer behavior."
  status: resolved
  reason: "Live UAT required repeatedly capturing boop trace show output after the fact, making it difficult to correlate Achaea output with the exact blocker and action transitions that occurred on screen."
  severity: minor
  test: 6
  root_cause: "The trace subsystem only appends timestamped entries to its bounded buffer and exposes retrospective show/clear commands. It has no session runtime flag or non-recursive output path for echoing a newly appended entry at collection time."
  artifacts:
    - path: "src/scripts/boop/boop_util.lua"
      issue: "boop.trace.log buffers entries but has no optional live-output branch."
    - path: "src/scripts/boop/boop_runtime.lua"
      issue: "Trace runtime state contains only the buffer and has no session-only live flag."
    - path: "src/scripts/boop/boop_ui.lua"
      issue: "boop trace supports on, off, show, and clear but no live stream command or status."
    - path: "src/scripts/boop/boop_ui_registry.lua"
      issue: "Diagnostics help and controls do not describe or expose live trace streaming."
    - path: "tests/boop_trace_spec.lua"
      issue: "Trace tests cover buffered evidence but not default-off live output, one-print-per-entry behavior, or recursion prevention."
  missing:
    - "Add session-only boop trace live on|off control with visible status and no config persistence."
    - "Echo each newly appended trace entry exactly once in the existing timestamped trace format while live mode is enabled."
    - "Keep trace collection independently controllable and prevent live output from feeding back into boop.trace.log."
    - "Update diagnostics help and regression coverage for default-off, enable, disable, reload reset, and buffer parity."
  resolved_by:
    - "03-18-PLAN.md"
    - "03-19-PLAN.md"
  verification: "03-VERIFICATION.md verifies session-only state, package-reload reset, exact-once non-recursive output, and packaged alias/help wiring at 0.1.441; post-fix live UAT Test 6 remains pending."

- gap_id: G-03-7
  truth: "Starting a live boop walk from the current room settles its requested room evidence, then reports manual_targeting while manual mode is active and can advance after automatic targeting is selected."
  status: failed
  reason: "User reported that inactive stop passed, but the walker never began moving. output.md shows walk_room_unsettled progressing to room_partial instead of the expected manual_targeting hold, then engaged_target after automatic targeting was selected."
  severity: major
  test: 2
  artifacts: []
  missing: []

- gap_id: G-03-8
  truth: "A queue-clearing interrupt cannot silently discard an owned pending gold command: gold remains held while the interrupt owns the queue, then exactly one eligible get-confirm-put sequence resumes or terminates from explicit evidence without requiring a room refresh."
  status: failed
  reason: "User reported that combat often waited for another command and gold pickup failed after diag. output.md shows gold generation 5 queue get sovereigns, diag clear/replace the shared freestand queue, no pickup response, and pending_timeout four seconds later while the gold remained in the room."
  severity: major
  test: 3
  artifacts: []
  missing: []

## Deferred Follow-Ups

- test: 2
  idea: "Add the installed boop version to boop status."
  deferred_at: 2026-07-28
