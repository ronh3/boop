---
status: testing
phase: 03-queue-interrupt-gold-and-autowalk-regression-coverage
source:
  - 03-VERIFICATION.md
started: 2026-07-26T21:45:34Z
updated: 2026-07-31T22:23:42-07:00
---

# Phase 03 UAT: Queue, Interrupt, Gold, and Autowalk Regression Coverage

## Current Test

number: 2
name: Simplified runtime and stale-target recovery
expected: |
  With boop 0.1.459 installed, lifecycle, room, target, and walker status are
  computed directly. Only interrupt, pull, and gold operations may hold
  automation. Movement, accepted room evidence, or a global-blacklist edit
  clears an ineligible target without stopping the walker.
awaiting: exact-SHA CI, package installation, then user response

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
  With boop 0.1.459 installed, manual targeting remains an intentional
  automatic-walk status and is reported as `manual_targeting`, not
  `room_clear`. Lifecycle, room readiness, target eligibility, and walker state
  are computed directly; only interrupt, pull, and gold appear as active
  operations. Movement, accepted room evidence, and blacklist edits clear stale
  target intent without stopping the walker.

  Easy check:
  1. Install 0.1.459, reconnect or reload, then run `boop status`. Confirm it
     prints `version: 0.1.459`. In `boop debug`, `ACTIVE OPERATIONS` should be
     empty unless an interrupt, pull, or gold action is actually in progress.
  2. Run `boop on`, `boop targeting auto`, and `boop walk start`. Engage a
     wanted denizen without issuing `ql`, `ih`, `boop status`, or another
     refresh after entering the room. Combat must begin from the natural GMCP
     sequence. Stop combat if necessary, then leave the room. `boop status`
     must not retain that old target as `engaged_target`; the walker must remain
     active and proceed when the destination room is clear.
  3. In a safe room, target a denizen and add that exact name to the global
     blacklist. The target id/name and queued attack intent must clear
     immediately, even in manual mode, while the walker state remains intact.
  4. Run `boop trace show 100`. Normal room and target transitions may report
     computed `room_partial`, `room_clear`, or `ready` status, but must not
     produce room, target, GMCP, or walker operation enter/exit records.
  5. For any delayed room, inspect `gmcp item list response` trace entries.
     `waits=inv` means the room contents arrived first but were held for the
     inventory barrier; `waits=room` means the requested room snapshot itself
     had not arrived. After `status=accepted`, the next natural tick should log
     `room application claimed: source=tick` and queue the attack without
     another `room_partial` hold.
result: [pending]
reported: |
  Take a look at the log trace from output.md. Am still seeing delay between
  entering a room, and when boop identifies a mob and starts attacking. Seems
  to require a prompt or two to come in before it starts.
severity: major
observed: "Version 0.1.458 trace shows Inv then Room completing fence 481 at 22:18:07 with status=accepted and waits=none. A following natural tick still reports room_partial because acceptedSourceAuthority is unset until the zero-delay application callback. The callback runs only after another mob action/prompt, then applies the room and queues Staffcast in the same second."
prior_reported: "Version 0.1.449 required ql or another GMCP refresh before natural-room combat began."
prior_observed: "A valid pirate Add arrived while room evidence was partial, then the copied List replaced it; 0.1.450 resolved that separate delta-reconciliation defect."
previous_result: issue
previous_reported: |
  Check output.md. Thierry, the ferryman is not a target I wanted killed. I stopped combat, moved out, and added him to the global blacklist. However, boop is now stuck, thinking it's on engaged_target for the blocker.
previous_severity: major
previous_observed: "output.md shows targeting mode whitelist, walk active, zero room denizens, current target 152345 / Thierry, the ferryman, and engaged_target still owning combat and target after movement and the global-blacklist edit."
earlier_result: issue
earlier_reported: |
  1. Pass.
  2. Appears not to pass.
     See output.md. The walker does not appear to ever actually start moving rooms/start. Version is 441.
earlier_severity: major
earlier_observed: "Step 1 passed with the exact inactive-stop message. After walk start, output.md shows the active walker held by walk_room_unsettled, followed by room_partial; it never reaches the expected manual_targeting hold or emits movement. Switching to automatic targeting instead exposes engaged_target for stale target 6832 while room denizens remain zero."
oldest_reported: "boop walk stop doesn't return any sort of message when running in step 1. After doing boop walk start, no movement is done. blocker shown is room_clear -- room clear. This is after seeing the same issue, and completely restarting mudlet."
oldest_severity: major
oldest_result: "Before Plans 03-11/03-12, List-before-Info followed by same-room Info created a new partial generation and stalled the walker."

### 3. Wrong-room gold and pack transfer

expected: |
  With boop 0.1.459 installed, a gold Item.Add in an already settled room
  requests one current-room revalidation but cannot authorize pickup by itself.
  Only the matching fenced room List may queue one
  `queue add full get sovereigns`. Confirmed pickup may queue one freestand put,
  while stale, duplicate, wrong-room, and movement-invalidated responses do
  nothing. A diag collision must issue `clearqueue all` before its diagnose
  command, preserve the displaced gold operation, and authorize exactly one
  replay after the exact interrupt owner releases.

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
     Native output must show `clearqueue all` before
     `queue addclearfull freestand diagnose`, with no unknown-queue error. After
     the exact diag owner clears, exactly one eligible gold command may replay
     and hunting must not remain jammed. The trace should show
     `diag result observed: source=gmcp` followed by `diag prompt consumed`;
     running `diag` again must complete normally instead of timing out one
     generation behind.
  5. Run `boop trace show 100`. Confirm no standard/rage attack command
     contains get or put, no gold generation dispatches twice, and stale room
     responses have no side effects. A fresh replay timeout may remain held for
     explicit evidence, but it must not duplicate the command; movement must
     invalidate pickup and disabling boop must invalidate packing.
  6. When Achaea prints any sovereign line ending with `flying into your hands
     before they can reach the ground.`, confirm boop
     sends one `queue add freestand put sovereigns in <container>` and no
     `get sovereigns`. The trace should show `gold direct pickup` followed by
     the normal pack success or bounded failure handling.
result: [pending]
previous_result: issue
previous_reported: "Check output.md. Behavior does not seem quite right. Boop did not start attacking until another command (boop status, ql, etc.) were checked. Gold pickup seems wonky at best, pickup seeming to not occur after death when doing a diag prior, etc. Think the gold timeout may be too short?"
previous_severity: major
previous_observed: "Normal gold generations 1, 2, 4, and 6 complete one get-confirm-put sequence. Room settlement repeatedly remains room_partial until a later ql/ih/status-adjacent event supplies the missing room List, corroborating G-03-7. In the failing diag sequence, gold generation 5 queues get sovereigns, diag then globally clears/replaces the shared native queue set, no pickup confirmation arrives, and the fixed four-second gold timer terminates the operation while the sovereigns remain in room 4249; a later room refresh creates generation 6 and finally picks them up."
earlier_reported: "Check output.md. Does not appear to be working whatsoever. Actual hunting is also broken, it seems. It will sometimes attack the first mob in the room, but then gets jammed up."
earlier_severity: blocker
earlier_blocker: "Gold was recognized in GMCP, but the reconnect snapshot showed boop enabled=false and gmcp_ire_missing was waiting for prompt evidence."
earlier_result: "Before Plans 03-11/03-13, pickup required exit/re-entry and a same-room Room.Info cancelled the queued get before packing."

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
  including Psion and Dragon pull-profile cases, reports no failures or errors
  while building synchronized package 0.1.459.
result: [pending]
source: automated
previous_result: pass
previous_evidence: "GitHub Actions run 30342898415 passed for exact source/package SHA 95cfbb96b4428032570b3e6019ae61f0ed619b29."
earlier_evidence: "GitHub Actions run 30265771025 passed for pre-gap SHA 07d73e8b38823277a8132cbcded2ea9f88e92f08."

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
passed: 3
issues: 1
pending: 2
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
  truth: "Starting a live boop walk from the current room settles its requested room evidence, then reports manual_targeting while manual mode is active and can advance after automatic targeting is selected; moved-room boundaries never permit stale prior-room target or attack dispatch."
  status: resolved
  reason: "User reported that inactive stop passed, but the walker never began moving. output.md shows walk_room_unsettled progressing to room_partial instead of the expected manual_targeting hold, then engaged_target after automatic targeting was selected."
  severity: major
  test: 2
  root_cause: "The room-response fence assumes requested Inv-then-Room response order. A Room List arriving first is discarded, so the generation waits for a later List; a post-Inv, pre-Info room-ID-less List can instead be authenticated against persistent old Room.Info and applied to the prior generation. Accepted settlement synchronously emits generationless target and attack commands, which the following moved Room.Info cannot revoke."
  artifacts:
    - path: "src/scripts/boop/boop_runtime.lua"
      issue: "The response fence has a one-way await_inv-to-await_room phase, discards early Room payloads, and authenticates room-ID-less Lists against persistent Room.Info."
    - path: "src/scripts/boop/boop_events.lua"
      issue: "Accepted Lists immediately mutate target/gold/walk state and tick; moved Room.Info starts a new generation but cannot revoke already-emitted prior-generation commands."
    - path: "src/scripts/boop/boop_targets.lua"
      issue: "Target selection immediately sends settarget without carrying the accepted room generation."
    - path: "src/scripts/boop/boop_attacks.lua"
      issue: "Attack selection reaches external command dispatch without final room-generation validation."
    - path: "src/scripts/boop/boop_util.lua"
      issue: "Standard queue emission sends setalias and BOOP_ATTACK immediately with no generation owner."
    - path: "tests/boop_event_transitions_spec.lua"
      issue: "Out-of-order tests supply a second Room response after rejecting Room-before-Inv and never cover post-Inv List-before-moved-Info cross-binding."
    - path: "tests/boop_walk_spec.lua"
      issue: "Walk tests use ordered response pairs and omit the live manual-to-auto wake-up plus stale prior-room dispatch sequence."
  missing:
    - "Latch copied Inv and Room responses independently per fence so exactly one response of each type settles in either order."
    - "Keep pre-Info room-ID-less evidence untrusted across movement boundaries and reconcile or invalidate it without binding it to persistent old Room.Info."
    - "Make accepted-room application and target/gold/walk/combat emission generation-owned with a final room/generation check immediately before external effects."
    - "Invalidate stale pending applicators and local intent on moved Room.Info without globally clearing unrelated shared-queue work."
    - "Add exact regressions for both response orders, manual-to-auto walk advancement, post-Inv List-before-Info isolation, and the 4255-to-4249 stale target/attack chronology."
  debug_session: ".planning/debug/phase-03-live-room-evidence-wakeup-regression.md"
  resolved_by:
    - "03-20-PLAN.md"
    - "03-21-PLAN.md"
    - "03-22-PLAN.md"
    - "03-22 post-plan target-loss hotfix, commit 457aafc"
  verification: "03-VERIFICATION.md verifies both response orders, exact room authority, manual-to-auto wake-up, stale dispatch rejection, and target-loss release at package 0.1.447; live Mudlet confirmation remains pending."

- gap_id: G-03-8
  truth: "A queue-clearing interrupt cannot silently discard an owned pending gold command: gold remains held while the interrupt owns the queue, then exactly one eligible get-confirm-put sequence resumes or terminates from explicit evidence without requiring a room refresh."
  status: resolved
  reason: "User reported that combat often waited for another command and gold pickup failed after diag. output.md shows gold generation 5 queue get sovereigns, diag globally clear/replace the shared native queue set, no pickup response, and pending_timeout four seconds later while the gold remained in the room."
  severity: major
  test: 3
  root_cause: "Gold and diag share Achaea's native queue system without shared command-entry ownership. Diag sends invalid bare queue clear, then globally destructive addclearfull, which removes the queued gold get regardless of its queue type; boop keeps pickup_pending and its live timeout because no displaced-command transition exists. Diag release cannot replay while that timer is active, and the four-second callback later terminates the generation without game evidence."
  artifacts:
    - path: "src/scripts/boop/boop_ui.lua"
      issue: "Real diag emits an invalid bare queue clear and a destructive addclearfull without coordinating an already-dispatched gold command."
    - path: "src/scripts/boop/boop_events.lua"
      issue: "Gold tracks phase and timeout but not displacement of its native queue entry; elapsed timeout terminates instead of replaying after the interrupt."
    - path: "src/scripts/boop/boop_runtime.lua"
      issue: "Interrupt release ticks normally, but the surviving gold timeout token suppresses flush_gold and exact-once redispatch."
    - path: "src/triggers/boop/Gold/triggers.json"
      issue: "Explicit get/put failures are covered, but native queue replacement has no evidence or recovery transition."
    - path: "tests/boop_diag_spec.lua"
      issue: "Append-only send mocks assert command text but do not model invalid bare clear or destructive addclearfull semantics."
    - path: "tests/boop_gold_spec.lua"
      issue: "Aggregate-owner coverage places the interrupt before gold dispatch rather than replacing a get already queued."
    - path: "tests/boop_gold_retry_spec.lua"
      issue: "Timeout coverage omits the live release-before-timeout ordering after destructive queue replacement."
  missing:
    - "Replace the invalid bare `queue clear` command with the valid global clear `clearqueue all`, preserving the following diagnose queue command."
    - "Use `queue add full get sovereigns` for initial pickup, retries, and displacement replay; keep packing independent on `freestand`."
    - "Before destructive queue replacement, preserve the gold owner, mark any sent pickup or pack command displaced/unsent, and cancel its stale pending timer."
    - "On exact interrupt completion, revalidate the current gold stage and dispatch exactly one generation-guarded get or put without requiring new room evidence."
    - "Terminate only from explicit success, failure, movement, disable, flee, or item evidence; a queue-replaced command cannot be silently abandoned by elapsed time."
    - "Add a native queue model and regressions for real diag after pickup and pack dispatch, both interrupt-release/timeout orderings, exact-once replay, and complete get-confirm-put termination."
  debug_session: ".planning/debug/phase-03-diag-gold-queue-collision.md"
  resolved_by:
    - "03-23-PLAN.md"
    - "03-24-PLAN.md"
  verification: "03-VERIFICATION.md verifies stage-specific native queues, exact displacement ownership, one replay, nonterminal replay timeout, explicit invalidation, and real diag command ordering at package 0.1.447; live Mudlet/native-queue confirmation remains pending."

- gap_id: G-03-9
  truth: "Target loss cannot deadlock automatic hunting: authoritative current-room evidence or a valid arriving denizen releases only the stale target-loss owner, after which one current target and attack may resume."
  status: resolved
  reason: "Live package 0.1.444 remained permanently held by target_lost -- target left room. output.md showed prompts, accepted room lists, multiple room changes, and a valid Dyissan archer Items.Add while every tick, queue, walk, and gold action remained blocked."
  severity: blocker
  test: 2
  root_cause: "The target:loss owner required target GMCP plus prompt evidence, but the owner itself blocked automatic retargeting and therefore prevented the settarget command that would produce target GMCP. Accepted fenced room snapshots and valid denizen additions were not counted as recovery GMCP, leaving a circular wait."
  artifacts:
    - path: "src/scripts/boop/boop_events.lua"
      issue: "Accepted room application and valid room-item additions updated denizens without satisfying target:loss recovery evidence."
    - path: "tests/boop_event_transitions_spec.lua"
      issue: "Target-loss coverage handled direct Target.Set/Target.Info and same-room replacement, but omitted no-replacement loss followed by moved-room settlement or a later valid denizen Add."
  resolution:
    - "Keep target:loss held while the destination room remains room_partial."
    - "Treat an accepted fenced current-room snapshot as target-loss GMCP evidence, allowing the existing prompt-plus-GMCP contract to release exactly that owner."
    - "Treat a room Items.Add as recovery evidence only after the item passes denizen validation and is present in the tracked denizen set."
    - "Retain unrelated owners and prove exactly one fresh settarget and attack with no stale prior-target dispatch."
  resolved_by:
    - "03-22 post-plan live-UAT hotfix, commit 457aafc"
  verification: "Host event transitions pass 55/55 and adjacent runtime/tick/walk/target suites pass 97/97 at package 0.1.445; live Mudlet confirmation remains pending."

- gap_id: G-03-10
  truth: "Movement, accepted current-room evidence, and a new global-blacklist rule reconcile active target ownership so an absent or newly forbidden denizen cannot keep combat, targeting, or walking held by engaged_target."
  status: resolved
  reason: "User reported: Check output.md. Thierry, the ferryman is not a target I wanted killed. I stopped combat, moved out, and added him to the global blacklist. However, boop is now stuck, thinking it's on engaged_target for the blocker."
  severity: major
  test: 2
  root_cause: "The owner-keyed blocker model represented synchronous lifecycle, room, target, and walker conditions as records that required later release evidence. Movement cleared attack commands but retained currentTargetId, accepted empty room contents did not reconcile it, global-blacklist edits did not invalidate it, and status treated any non-empty target id as engaged. The stale identity therefore survived the room and list state that already proved it invalid."
  artifacts:
    - path: "src/scripts/boop/boop_runtime.lua"
      issue: "Production holds now read only interrupt, pull, and gold operation locks; lifecycle and room readiness are computed snapshots, and reload migration purges old pseudo-owner records."
    - path: "src/scripts/boop/boop_events.lua"
      issue: "Movement clears stale target and queue intent while preserving walker ownership; accepted room applications and valid denizen additions wake current-state evaluation."
    - path: "src/scripts/boop/boop_targets.lua"
      issue: "Accepted room contents and blacklist edits reconcile target eligibility, with the global blacklist overriding every targeting mode and target call."
    - path: "src/scripts/boop/boop_walk.lua"
      issue: "Walker gates are computed from lifecycle, room authority, target eligibility, and real active operations instead of walker-owned blockers."
    - path: "src/scripts/boop/boop_ui.lua"
      issue: "Status reports computed state and active operations, validates engaged-target eligibility, and includes the installed package version."
    - path: "tests/"
      issue: "Runtime, event, target, lifecycle, walk, UI, queue, gold, trace, interrupt, and pull regressions cover operation-only holds and stale-target recovery."
  resolution:
    - "Restrict production operation locks to interrupt, pull, and gold owner namespaces; retain legacy blocker APIs only as non-authoritative compatibility surfaces."
    - "Compute lifecycle and room readiness directly from canonical state, and evaluate target and walker eligibility directly at each decision."
    - "Clear stale target and queued attack intent on movement, accepted room contents, and blacklist edits without stopping an active walker."
    - "Preserve target and queue intent only during a live pull, then reconcile them when the pull returns or terminates."
    - "Expose computed Status plus Active Operations in operator surfaces and use operation enter/exit terminology in trace."
    - "Show the installed version in compact and full `boop status` output."
  resolved_by:
    - "0.1.448 runtime simplification hardening"
  verification: "Focused host suites pass for runtime, lifecycle, event transitions, targeting, walking, UI, trace, pull preservation, queueing, and gold behavior; packaged Mudlet CI and live UAT remain pending."

- gap_id: G-03-11
  truth: "A current-generation Char.Items.Add or Remove received while the requested room snapshot is pending remains authoritative when that snapshot is applied, so hunting starts from the natural GMCP sequence without ql or another refresh."
  status: resolved
  reason: "Version 0.1.449 receives a valid pirate Items.Add while the room response fence is incomplete, then applies a requested room List that omits the pirate and reports tick: no target. A later refreshed List includes the pirate and combat starts immediately."
  severity: major
  test: 2
  root_cause: "boop.onRoomItemsAdd updates the live denizen table, but applyRoomApplication later calls updateRoomItems with the copied List and replaces the entire table. The response fence retains Inv and Room snapshots but does not retain newer Add/Remove deltas that arrive between the room boundary and deferred snapshot application."
  artifacts:
    - path: "src/scripts/boop/boop_runtime.lua"
      issue: "Response fences and pending room applications have no generation-bound room-item delta journal."
    - path: "src/scripts/boop/boop_events.lua"
      issue: "Room Add/Remove events mutate live consumers without attaching the event to an incomplete fence or unclaimed application."
    - path: "src/scripts/boop/boop_targets.lua"
      issue: "Accepted snapshot application replaces denizens, erasing any newer valid Add that was already observed."
    - path: "tests/boop_event_transitions_spec.lua"
      issue: "Existing tests cover settled Add wake-up and response order, but not Add/Remove interleaving with a pending room snapshot."
  missing:
    - "Journal copied room Add/Remove events only on the matching current room generation while a response fence or room application is pending."
    - "Replay those deltas in event order over the copied room List before accepted items, denizens, gold, walk, and tick consume it."
    - "Discard the journal at movement boundaries and reject stale-generation deltas."
    - "Add regressions proving a newer Add survives a stale snapshot, a newer Remove is not resurrected, and no second room List is required."
  resolution:
    - "Attach copied Add/Remove deltas to the exact valid response fence, room ID, and observation generation."
    - "Replay the ordered deltas over the copied room snapshot before creating its deferred room application, and apply later deltas directly to an unclaimed application."
    - "Keep existing snapshot attributes when duplicate IDs occur, preserving mx/d target exclusions while filling only missing fields."
    - "Trace Add/Remove attributes, reconciled denizen counts, and every recorded pending delta for live correlation."
  resolved_by:
    - "0.1.450 room snapshot/delta reconciliation"
  verification: "G-03-11 event regressions cover Add before List, Remove before List, Add after List before application, restrictive duplicate attributes, and one-room-request liveness. Event transitions pass 62/62; adjacent gold/walk and target/tick/runtime/trace suites pass; the packaged real-Mudlet suite completed without a Busted failure or error marker."

- gap_id: G-03-12
  truth: "When the current target shields or a normal attack rebounds, a staged standard shieldbreak remains selected until it executes and explicit combat evidence clears the shield."
  status: resolved
  reason: "Live version 0.1.450 rebuilt BOOP_ATTACK from Infernal dsl to raze after both the shield-gain and rebound lines, then replaced it with dsl before equilibrium recovered."
  severity: major
  test: 2
  root_cause: "prequeueStandard and refreshPrequeuedStandard call onShieldbreakAttempt immediately after staging BOOP_ATTACK. The following Balance/Equilibrium used event resets prequeuedStandard and schedules another prequeue; because the shield is already marked attempted even though raze has not executed, standard selection falls through to normal damage and overwrites the queued alias."
  artifacts:
    - path: "src/scripts/boop/boop_events.lua"
      issue: "Future queued shieldbreaks are marked attempted at alias staging/rebuild time instead of after execution evidence."
    - path: "src/scripts/boop/boop_attacks.lua"
      issue: "The attempted guard correctly suppresses repeat direct attempts, but receives a false-positive attempt from prequeue staging."
    - path: "tests/boop_prequeue_spec.lua"
      issue: "Existing shield refresh coverage expects premature attempted state and omits the shield-gain, rebound, balance-use, replacement-prequeue chronology."
  missing:
    - "Do not mark a shieldbreak attempted merely because a future BOOP_ATTACK alias was queued or rebuilt."
    - "Keep direct standard and rage dispatch attempt tracking intact."
    - "Prove the live Infernal dsl-to-raze chronology cannot downgrade back to dsl before shield-down evidence."
  resolution:
    - "Prequeue staging and shield-triggered alias rebuilds retain unattempted shield state until combat output proves execution."
    - "Normal queued standard dispatch also avoids premature attempt state, while direct standard and direct rage dispatch retain the existing retry guard."
    - "The exact Infernal hyena-maul/dsl, shield, rebound, balance-use, replacement-prequeue sequence remains hyena-maul/raze."
  resolved_by:
    - "0.1.451 queued shieldbreak execution semantics"
  verification: "Prequeue/planner/shield focused regressions pass 21/21, adjacent event/tick/runtime regressions pass 100/100, Lua 5.1 syntax and release gates pass, Muddler builds 0.1.451, and the packaged real-Mudlet suite completes without a new Busted failure/error marker."

- gap_id: G-03-13
  truth: "A successful live gold pickup confirmation terminates the pickup operation immediately, allowing the current target or walker to resume without waiting for the stale-pending timeout."
  status: resolved
  reason: "Live output repeatedly showed `You scoop up <amount> gold sovereigns.`, followed by no `gold get success` transition and a four-second `pending_timeout` before combat resumed."
  severity: major
  test: 3
  root_cause: "The Gold Get Success trigger recognized only Achaea's `You pick up ... sovereigns.` wording. The live `You scoop up ... gold sovereigns.` wording never called boop.onGoldGetSuccess, so the room-item removal remained intentionally ambiguous and the gold operation held combat, queue, and walk until timeout."
  artifacts:
    - path: "src/triggers/boop/Gold/triggers.json"
      issue: "Pickup success omitted the live `scoop up` wording."
    - path: "tests/boop_gold_spec.lua"
      issue: "Gold behavior tests called boop.onGoldGetSuccess directly and did not assert the packaged trigger wording."
  resolution:
    - "Recognize both observed `pick up` and `scoop up` sovereign confirmation lines as pickup success."
    - "Keep room-item removal alone nonterminal because it does not prove inventory ownership."
    - "Regress the packaged trigger manifest so either observed confirmation reaches the existing get-confirm-put transition."
  resolved_by:
    - "0.1.452 live gold pickup confirmation coverage"
  verification: "Gold core passes 10/10, gold retry passes 26/26, event transitions pass 62/62, and tick/runtime passes 38/38. Lua syntax, JSON parsing, release gates, Muddler 0.1.452 build, and packaged trigger inspection pass; local Mudlet is unavailable, so exact-SHA real-Mudlet CI remains pending."

- gap_id: G-03-14
  truth: "A diagnose result completes the current interrupt after its following prompt, and one missed or timed-out result cannot consume every later diagnose result."
  status: resolved
  reason: "Live 0.1.452 trace shows diagnose generations 51 and 52 both reaching the eight-second timeout even though diagnose was visibly run; the trace had no result-evidence event to distinguish a missed text trigger from stale FIFO consumption."
  severity: major
  test: 3
  root_cause: "Diagnose completion depended only on two rendered text prefixes. Every timeout also retained an unresolved FIFO tombstone indefinitely. When a prior result was genuinely absent or its text trigger was missed, the next valid result was assigned to that tombstone, leaving the current generation one result behind and repeating the timeout cycle."
  artifacts:
    - path: "src/scripts/boop/boop_runtime.lua"
      issue: "A new diagnose appended behind every unresolved timeout tombstone, allowing stale evidence to poison all later generations."
    - path: "src/scripts/boop/boop_events.lua"
      issue: "The documented diagnose-time Char.Afflictions.List event was not registered as completion evidence."
    - path: "src/scripts/boop/boop_init.lua"
      issue: "Boop did not explicitly announce Char.Afflictions GMCP support."
    - path: "src/triggers/boop/Diag/triggers.json"
      issue: "Rendered-line matching was the only result signal and could be missed or preempted by another package's output handling."
  resolution:
    - "Announce Char.Afflictions 1 and treat its List event as primary current-dispatch result evidence."
    - "Retain both visible diagnose result triggers as fallback evidence."
    - "Keep at most one dispatch's evidence when a new explicit diagnose starts, so an unresolved timed-out record cannot create permanent generation lag."
    - "Trace result source, evidence generation, active generation, prompt consumption, and stale-evidence supersession."
  resolved_by:
    - "0.1.453 diagnose GMCP evidence and bounded timeout recovery"
  verification: "Focused host diagnose, timeout, lifecycle-registration, and event-transition suites pass 74/74; release gates, package build, and exact-SHA Mudlet CI passed for package 0.1.453."

- gap_id: G-03-15
  truth: "When Achaea sends sovereigns directly into inventory using any line with the stable direct-to-hands suffix, boop skips room pickup and puts them into the configured gold container."
  status: resolved
  reason: "The first live direct-to-hands line exposed missing inventory-delivery handling; subsequent evidence showed that Achaea uses multiple sovereign prefixes with the same stable ending."
  severity: major
  test: 3
  root_cause: "Direct inventory delivery is neither a room-gold drop nor the result of a boop-owned get operation. The initial fix added the missing transition but bound its trigger and handler to one exact corpse sentence instead of the stable sovereign-and-suffix contract."
  artifacts:
    - path: "src/triggers/boop/Gold/triggers.json"
      issue: "The original trigger recognized only one direct-to-hands corpse-gold wording."
    - path: "src/scripts/boop/boop_events.lua"
      issue: "The direct inventory-delivery handler originally required the exact `golden sovereigns spill from the corpse` phrase."
    - path: "tests/boop_gold_spec.lua"
      issue: "Gold regressions initially omitted direct inventory delivery, then covered only one exact wording rather than prefix variants and false-positive rejection."
  resolution:
    - "Recognize sovereign lines ending with the stable direct-to-hands suffix while rejecting unrelated items."
    - "Create or advance one normal inventory-owned pack operation and dispatch `queue add freestand put sovereigns in <container>`."
    - "Never issue `get sovereigns` for this line; retain the existing pack success, failure, retry, timeout, and operation cleanup."
  resolved_by:
    - "0.1.455 direct-to-inventory corpse-gold packing and help-contract alignment"
    - "0.1.456 generalized sovereign-prefix recognition with exact-suffix and false-positive guards"
  verification: "Focused host gold core passes 13/13, gold retry passes 26/26, event transitions pass 62/62, and the aligned UI help contract passes 46/46. Lua syntax, JSON validation, release gates, Muddler build, packaged trigger inspection, and direct regex samples pass; package 0.1.456 exact-SHA Mudlet CI remains pending."

- gap_id: G-03-16
  truth: "A Magi can retain Horripilation as the default standard attack or explicitly prefer Scintilla or Dissolution through the normal attack preference surface."
  status: resolved
  reason: "The Magi profile exposed only Horripilation even though Scintilla and Dissolution are valid elemental staff damage attacks."
  severity: minor
  test: 2
  root_cause: "The Magi `standard.dam` profile was a single attack entry rather than an ordered preference list."
  artifacts:
    - path: "src/scripts/boop/attacks/magi.lua"
      issue: "Scintilla and Dissolution were absent from standard damage selection."
    - path: "tests/boop_attacks_spec.lua"
      issue: "No contract covered Magi preference labels, commands, or Artificing skill gates."
  resolution:
    - "Preserve Horripilation as the first/default Magi damage option."
    - "Add `staffcast scintilla at &tar`, gated by Artificing Scintilla."
    - "Add `staffcast dissolution at &tar`, labeled Dissolution and gated by the Artificing Staff ability."
  resolved_by:
    - "0.1.457 Magi staffcast preference expansion"
  verification: "Focused host Magi attack-profile contracts pass 4/4; adjacent attack and packaged Mudlet verification remain pending."

- gap_id: G-03-17
  truth: "Once both current room-response halves are accepted, the next natural tick can claim that exact pending room application without waiting behind its zero-delay fallback, while moved-room invalidation remains fail closed."
  status: resolved
  reason: "Live 0.1.458 trace showed status=accepted and waits=none, followed by tick held: room_partial; the room application and first attack occurred only after another mob action and prompt allowed the zero-delay callback to run."
  severity: major
  test: 2
  root_cause: "The response fence marked itemsSeen immediately but withheld acceptedSourceAuthority, denizen application, and tick until a zero-delay timer callback. A natural Vitals/prompt tick arriving before that callback therefore remained room_partial even though the complete copied room evidence was already pending."
  artifacts:
    - path: "src/scripts/boop/boop_events.lua"
      issue: "boop.tick did not recognize or claim a complete, valid pending room application before evaluating room readiness."
    - path: "tests/boop_event_transitions_spec.lua"
      issue: "Room-application tests covered timer completion and moved-room invalidation but omitted a normal tick between fence acceptance and timer execution."
  resolution:
    - "Before a no-authority normal tick evaluates readiness, claim only the exact current valid pending application through the existing application/room/generation validator."
    - "Cancel the claimed application's fallback timer and run the unchanged authority-stamped target, gold, walker, and combat consumers exactly once."
    - "Retain the zero-delay callback when no natural tick intervenes, and preserve zero stale effects when moved Room.Info invalidates the application first."
    - "Trace whether the application was claimed by `source=tick` or `source=timer` for live chronology."
  resolved_by:
    - "0.1.459 exact-authority natural-tick room application wake"
  verification: "The named G-03-17 regression and the existing moved-room invalidation chronology pass in the 63-case event-transition suite; adjacent trace, tick/runtime, gold, walk, prequeue, and target suites pass. Exact-SHA Mudlet CI and live 0.1.459 confirmation remain pending."

- gap_id: G-03-18
  truth: "Magi Staffcast damage does not clear a target's tracked magical shield because Staffcast can land while that shield remains active."
  status: resolved
  reason: "Live 0.1.459 output showed a target gain a magical shield, Scintilla land for damage, boop clear shield state from the generic Staffcast trigger, and the actual shield fade later."
  severity: major
  test: 2
  root_cause: "The generated Magi Staffcast success trigger was incorrectly included in the shield-down trigger family, treating damage that bypasses shield as proof that shield was removed."
  artifacts:
    - path: "src/triggers/boop/Shield/Magi/triggers.json"
      issue: "All successful Staffcast variants were registered as shield-down evidence."
    - path: "src/triggers/boop/Shield/Magi/Magi_General_Staffcast.lua"
      issue: "The trigger unconditionally called onShieldDownTrigger for ordinary Staffcast damage."
    - path: "tests/boop_shields_spec.lua"
      issue: "Shield tests did not constrain the packaged Magi evidence boundary."
  resolution:
    - "Remove ordinary Magi Staffcast damage from the shield-down trigger manifest."
    - "Retain explicit Magi Erode and Disintegrate shield-down evidence."
    - "Regress both manifest and script absence so generated package wiring cannot silently restore the false signal."
  resolved_by:
    - "0.1.460 Magi Staffcast shield-evidence correction"
  verification: "Focused shield/prequeue regressions pass 18/18 and focused Magi profile checks pass 4/4. Lua syntax, release gates, and the 0.1.460 package build pass; built XML retains the Staffcast gag trigger with no Staffcast shield-down handler. Exact-SHA Mudlet CI and live confirmation remain pending."

- gap_id: G-03-19
  truth: "The operator can switch every class/spec between normal shield responses and ordinary attack planning for the current session, with the safe shieldbreak policy restored on reload or reconnect."
  status: resolved
  reason: "A temporary game mode lets otherwise ordinary attacks pass shields, but the behavior is not Magi-specific and must never become a persistent assumption in normal play."
  severity: minor
  test: 2
  root_cause: "The planner's existing `breakShields` gate was already class-agnostic, but it was exposed only as a persisted advanced boolean and could leave a nonstandard bypass policy active across normal sessions."
  artifacts:
    - path: "src/scripts/boop/boop_ui.lua"
      issue: "There was no explicit session shield-mode command, enum control, or immediate two-way rebuild of a staged class attack."
    - path: "src/scripts/boop/boop_db.lua"
      issue: "The legacy `breakShields` value persisted across package loads and connections."
    - path: "src/scripts/boop/boop_events.lua"
      issue: "Prequeue refresh accepted only shieldbreak plans, so changing back to an ordinary class attack could not rebuild the staged alias."
    - path: "tests/boop_shields_spec.lua"
      issue: "No contract covered mode commands, package wiring, retained shield evidence, or safe session resets."
  resolution:
    - "Add `boop shieldmode break|bypass|toggle` and an enum-style combat control that operate on the shared planner gate for every class and spec."
    - "Keep tracked shield evidence in both modes; `break` selects profile shield responses and `bypass` selects the profile's ordinary standard and rage actions."
    - "Make the mode session-only, remove stale persisted values, and reset to `break` on package reload and reconnect."
    - "Rebuild an existing prequeued class attack in either direction without weakening ordinary shield-gain refreshes."
  resolved_by:
    - "0.1.461 class-agnostic session shield mode"
  verification: "Focused shield, prequeue, attack, persistence, UI, registry, lifecycle, event-transition, tick, runtime, and planner host regressions pass 194/194. Lua syntax and JSON validation pass; release gates, package build, and exact-SHA real-Mudlet CI remain pending."

- gap_id: G-03-20
  truth: "A changed room item list that arrives immediately before moved Room.Info can wake destination combat without authorizing gold or walker settlement."
  status: resolved
  reason: "Live trace showed the destination denizen list arrive as a post-completion duplicate for the origin generation immediately before Room.Info changed rooms; boop then waited for a second authoritative list while the destination mob attacked first."
  severity: major
  test: 2
  root_cause: "Char.Items.List has no room identifier, so the response fence correctly rejected the early list but had no outbound movement correlation with which to retain it as a bounded combat hint."
  artifacts:
    - path: "src/scripts/boop/boop_events.lua"
      issue: "Outbound movement was not observed, and every non-authoritative list was discarded before Room.Info could confirm the destination."
    - path: "src/scripts/boop/boop_runtime.lua"
      issue: "Room readiness had no separate, fail-closed combat-only path for short-lived movement-correlated evidence."
    - path: "tests/boop_event_transitions_spec.lua"
      issue: "No chronology covered direction send -> changed duplicate list -> moved Room.Info -> provisional attack while room_partial."
  resolution:
    - "Observe exact outbound directions through Mudlet's sysDataSendRequest event without replacing typed commands or keybindings."
    - "Arm against settled origin evidence or its exact active response fence, then retain only a changed duplicate after that fence completes and consume it only when moved Room.Info confirms a different room within the bounded intent window."
    - "Use the retained list for synchronous target selection and combat only; keep room readiness partial and continue requiring the normal post-move fenced list for gold and walker settlement."
    - "Reject unsupported commands, overlapping movement sends, unchanged lists, orphan-first lists, expired candidates, failed movement, and movement from an unsettled origin."
  resolved_by:
    - "0.1.462 movement-correlated provisional combat wake"
    - "0.1.463 full-name movement direction aliases"
  verification: "The focused event-transition suite passes 66/66, including all 22 supported direction commands, combat-only destination wake-up, no provisional gold/walker authority, and expiry rejection. Eleven adjacent lifecycle, runtime, tick, trace, gold, walk, target, prequeue, state-contract, and safety host suites pass 173/173; the 0.1.463 Muddler package and release gates pass. Exact-SHA Mudlet CI remains pending."
