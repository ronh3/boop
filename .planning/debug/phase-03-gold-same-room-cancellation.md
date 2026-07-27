---
status: diagnosed
trigger: "Diagnose Phase 03 UAT gap G-03-2 only. Goal: find_root_cause_only."
created: 2026-07-26T18:14:25-07:00
updated: 2026-07-26T18:20:17-07:00
---

## Current Focus

hypothesis: confirmed — two linked invalid transitions independently explain the delayed pickup and the lost packing transfer
test: complete
expecting: complete
next_action: return root-cause-only diagnosis; do not modify source or tests

## Symptoms

expected: Room-owned pickup is cancelled only by an actual room change; confirmed pickup transfers to inventory-owned packing, which may complete after movement, and loot is never chained with an attack.
actual: No get was sent after kill. After exit and re-entry, list evidence queued get for gold generation 9, then a same-room Room.Info (moved=no) immediately terminated generation 9 as room_changed. The gold item was removed but no live pickup remained to transfer to pack_pending, so no put was sent.
errors: No explicit runtime error; the operation was incorrectly terminated with reason room_changed.
reproduction: Test 2 in Phase 03 UAT.
started: Discovered during live UAT.

## Eliminated

- hypothesis: transferGoldToPacking or inventory-owned movement handling caused the missing put
  evidence: When a live PICKUP_PENDING operation reaches onGoldGetSuccess, transferGoldToPacking clears room identity, enters PACK_PENDING, and queues put; existing specs also preserve this stage across actual movement. The live path never reached this function because onRoomInfo had already cleared the operation.
  timestamp: 2026-07-26T18:20:17-07:00
- hypothesis: room-item removal is an alternate pickup confirmation path that malfunctioned
  evidence: The only pickup confirmation path is the explicit "You pick up ... Sovereign..." trigger calling onGoldGetSuccess. Room item removal only logs pending removal and does not own phase transfer; after premature terminal completion, both callbacks correctly find no live pickup.
  timestamp: 2026-07-26T18:20:17-07:00
- hypothesis: loot/attack command chaining contributed to the failure
  evidence: Gold dispatch uses independent `queue add freestand` commands, while combat execution receives only the supplied action; focused specs assert no sovereign command appears in attack aliases.
  timestamp: 2026-07-26T18:20:17-07:00
## Evidence

- timestamp: 2026-07-26T18:14:58-07:00
  checked: README.md gold behavior contract
  found: The repository documents complete Room.Info plus room item list as settlement evidence, get-confirm-put as separate gold stages, and an explicit ban on chaining loot with attacks.
  implication: The reported expected behavior is an existing product invariant, not a new requirement.
- timestamp: 2026-07-26T18:14:58-07:00
  checked: package version checkpoints
  found: mfile title, boop_init.lua, and CODEX.md all identify version 0.1.416; no package-affecting change is authorized.
  implication: This diagnosis remains planning-only and must not trigger version work.
- timestamp: 2026-07-26T18:15:17-07:00
  checked: DESIGN.md current gold and lifecycle design
  found: Gold is explicitly a get-confirm-put pipeline; confirmed inventory ownership starts packing, and interrupt, pull, gold, and walk lifecycles use generation-owned operations so superseded callbacks cannot mutate current state.
  implication: Diagnosis must distinguish room-evidence invalidation of pickup from any later inventory-owned packing transition rather than treating gold as one room-bound operation.
- timestamp: 2026-07-26T18:15:42-07:00
  checked: Phase 03 UAT Test 2 and gap G-03-2
  found: Live trace attribution says generation 9 reached queued pickup only after exit/re-entry, then a same-room Room.Info terminated it as room_changed before item removal; the UAT separately identifies list-before-info inability to advance the original deferred pickup.
  implication: The report itself contains two temporal failure points that must be tested separately rather than collapsed by shared symptoms.
- timestamp: 2026-07-26T18:15:42-07:00
  checked: STATE.md Phase 03 decisions
  found: The implemented decision intentionally treated every Room.Info as invalidation evidence for DEFERRED_ROOM and PICKUP_PENDING, while separately requiring Room.Info plus a later complete room-item list for settlement.
  implication: The candidate mechanism is a deliberate state-machine rule that conflicts with the stronger actual-room-change ownership invariant under unordered GMCP arrival.
- timestamp: 2026-07-26T18:16:56-07:00
  checked: boop.onRoomInfo ordering in boop_events.lua
  found: onRoomInfo calls startRoomObservation(info.num), then terminally completes DEFERRED_ROOM/PICKUP_PENDING as room_changed, and only afterward compares targeting.room with info.num to set movedRooms; traceRoomInfo therefore can report moved=no after the operation was already destroyed.
  implication: Same-room cancellation is directly confirmed and does not depend on timeout, command output, or packing logic.
- timestamp: 2026-07-26T18:16:56-07:00
  checked: completeGoldOperation, onGoldGetSuccess, and transferGoldToPacking
  found: Completion marks the operation terminal and replaces state.gold.operation with false; onGoldGetSuccess accepts only a live PICKUP_PENDING operation. When live, transferGoldToPacking correctly clears room identity, changes to PACK_PENDING, and queues put under inventory ownership.
  implication: Item removal or a later get-success line cannot pack after premature cancellation, while the packing transfer mechanism itself preserves movement independence.
- timestamp: 2026-07-26T18:16:56-07:00
  checked: boop.runtime room observation API
  found: Every startRoomObservation call increments generation and resets itemsSeen=false; stampRoomItemsObservation can attach a list only to an observation whose existing roomId matches the currently visible gmcp.Room.Info.
  implication: The API has no pending-list reconciliation path for list-before-info arrival, a separate transition boundary from gold cancellation.
- timestamp: 2026-07-26T18:17:51-07:00
  checked: boop_gold_spec.lua
  found: Tests cover successful get-to-pack transfer, pack survival after an actual move, cancellation before success on an actual move, and attack commands without loot chaining; none inserts a same-room Room.Info between queued get and get success.
  implication: Existing unit coverage validates the desired adjacent invariants but misses the live ordering that destroys pickup.
- timestamp: 2026-07-26T18:17:51-07:00
  checked: boop_event_transitions_spec.lua same-room invalidation test
  found: The test named "invalidates a current room-owned stage on Room.Info" explicitly sends Room.Info num=1 while already in room 1 and asserts state.gold.operation becomes false.
  implication: The suite codifies the defective event-based cancellation rule, so green tests cannot protect the actual-room-change requirement.
- timestamp: 2026-07-26T18:17:51-07:00
  checked: room evidence transition specs
  found: Tests require only List after Room.Info and assert every Room.Info starts a fresh itemsSeen=false generation; there is no list-before-info reconciliation or same-room evidence preservation case.
  implication: The delayed pickup and same-room cancellation are linked by event ordering but occur at distinct state-machine transitions and require separate regressions.
- timestamp: 2026-07-26T18:18:36-07:00
  checked: git blame for onRoomInfo and room observation API
  found: startRoomObservation/reset behavior originated in Phase 03 commit b84c205a, while unconditional gold termination in onRoomInfo originated later in Phase 03 commit c5d30c99.
  implication: The two mechanisms are linked defects introduced by separate changes, not one indivisible defect.
- timestamp: 2026-07-26T18:18:36-07:00
  checked: focused host Busted execution
  found: Standalone Busted could not load the Mudlet package and the filtered run selected zero tests.
  implication: Host execution is inconclusive and cannot be counted as verification; diagnosis rests on live UAT evidence, direct control-flow inspection, and deterministic spec assertions.
- timestamp: 2026-07-26T18:20:17-07:00
  checked: Phase 03 introducing diffs
  found: Commit b84c205a introduced the Info-first room observation model. Commit c5d30c99 later moved room-owned gold completion from inside the actual-room-ID-change branch to before that comparison, while the phase pattern still stated that duplicate same-room signals coalesce.
  implication: The live failure is a Phase 03 state-machine regression with two separately introduced, linked defects.
- timestamp: 2026-07-26T18:20:17-07:00
  checked: exact success and removal trigger boundaries
  found: Gold Get Success invokes onGoldGetSuccess from the pickup text line; onRoomItemsRemove does not transfer ownership. Both require the canonical operation to remain live for packing to begin.
  implication: Once same-room Room.Info terminally clears state.gold.operation, neither subsequent evidence can produce a put.
- timestamp: 2026-07-26T18:20:17-07:00
  checked: source and test worktree integrity
  found: No source, tests, UAT, STATE, ROADMAP, or other existing file was modified; only this permitted diagnosis file was created.
  implication: Investigation remained root-cause-only.
## Resolution

root_cause: "Two linked defects occur at different transition boundaries. First, `startRoomObservation` models only Info->List: every Room.Info creates a new generation with `itemsSeen=false`, while a List arriving first cannot be retained/reconciled, so the original gold operation remains deferred or waits for duplicate evidence. Second, `boop.onRoomInfo` calls `startRoomObservation` and terminally completes every DEFERRED_ROOM/PICKUP_PENDING operation with `room_changed` before comparing incoming `info.num` with `targeting.room`; therefore a same-room refresh (`moved=no`) destroys the queued pickup. `completeGoldOperation` clears `state.gold.operation`, so later get-success/removal evidence cannot call `transferGoldToPacking`, and no put is queued. Inventory-owned PACK_PENDING and attack/loot separation are not defective."
fix: "Compute normalized actual movement before room-owned invalidation; preserve the current observation and live DEFERRED_ROOM/PICKUP_PENDING operation on same-room Room.Info, and cancel them only when the room ID truly changes. Extend the shared room-observation API to retain an unbound complete List and reconcile it with the following validated Room.Info/transition hint, failing closed on ambiguous stale prior-room evidence. Preserve transferGoldToPacking's clearing of room identity and its PACK_PENDING survival across actual movement. Regressions: List->same-room Info and Info->List each advance one get; List->get queued->same-room Info->get success/removal->one put; actual room change cancels deferred/pickup and makes late success/retry no-ops; PACK_PENDING survives actual movement and completes; stale old-room lists and duplicate signals send nothing extra; combat commands never contain get/put."
verification: "Root cause confirmed by live UAT ordering, complete control-flow inspection, existing assertions that encode same-room invalidation, and introducing diffs b84c205a/c5d30c99. No fix was applied or verified in diagnose-only mode."
files_changed: []
