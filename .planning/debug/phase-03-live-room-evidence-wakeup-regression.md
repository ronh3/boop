---
status: diagnosed
trigger: "Diagnose G-03-7 in /var/home/ron/mudletCode/boop. Goal: find_root_cause_only. Do not edit source, tests, UAT, versions, or commits."
created: 2026-07-28T21:13:08-07:00
updated: 2026-07-28T21:23:00-07:00
---

## Current Focus

reasoning_checkpoint:
  hypothesis: The live stall is caused by a response fence that treats the requested `Char.Items.Inv`→`Char.Items.Room` send order as a guaranteed response order and uses persistent `Room.Info` as the identity of a room-ID-less List. A room List received before its Inv response is discarded, while a List received after Inv but before a moved Room.Info can be accepted into the old generation. The next generation therefore remains `itemsSeen=false` until another List arrives. Independently, accepting old-generation evidence invokes targeting/combat synchronously, and the following moved Room.Info neither generation-guards nor revokes the commands already sent.
  confirming_evidence:
    - `boop_runtime.lua:358-464` advances only `await_inv`→`await_room`, returns `awaiting_inv` without retaining an early room payload, and accepts a post-Inv List solely against the fence plus persistent current Room.Info.
    - The direct probe reproduces both failures: room-before-Inv leaves the fence stranded until a second room List, and post-Inv List-before-Info settles generation 1 before generation 2 starts empty.
    - `output.md:1751-1805` proves accepted generation-45 evidence emits target/attack intent before generation 46; the emitted commands execute while generation 46 is blocked and fail in the new room.
  falsification_test: The hypothesis would be false if a single room-before-Inv response pair settled its current generation, if a post-Inv pre-Info List could be identified/reconciled without old-generation application, or if moved Room.Info revoked generation-45 target/attack emission. The runtime probe and live trace show the opposite in all three cases.
  fix_rationale: Per-fence response latches make response completion order-independent, explicit generation/room reconciliation prevents room-ID-less evidence crossing a moved Info boundary, and generation-owned deferred dispatch with a final room-generation check closes the command race rather than merely hiding its symptom.
  blind_spots: The live trace does not log Inv transitions or non-accepted List statuses, so the exact dropped destination response cannot be read directly from `output.md`; it is established by the deterministic production-runtime probe plus the observed later-List wakeup. A final implementation would still require live Mudlet verification.
next_action: Return the diagnosis only; do not implement, edit tests, bump versions, or commit.

## Symptoms

expected: Starting a live boop walk from the current room settles its requested room evidence, then reports `manual_targeting` while manual mode is active and can advance after automatic targeting is selected. More generally, entering a room must settle current Room.Info + Char.Items evidence without requiring unrelated `boop status`, `ql`, `ih`, or later GMCP activity before targeting/combat/walk can proceed.
actual: Phase 03 UAT Test 2 failed. `boop walk start` was held by `walk_room_unsettled`, then `room_partial`, with no movement. Test 3 independently shows Room.Info entering a fresh generation with `items:false`; combat does not dispatch until a later `ql`/`ih`/status-adjacent event supplies a room List. In `output.md` lines 26-34 a room List count=0 is processed immediately before Room.Info moves 4231->4232, then generation 35 starts `items=false` and times out until `ql` at lines 65-70. Similar sequences recur.
errors: No Lua exception reported; observable blockers are `walk_room_unsettled`, `room_partial`, and repeated current room observations with `items:false`.
reproduction: In live Mudlet version 0.1.441, enter a room where `Char.Items.List` for the destination arrives before `Room.Info`, then start/continue combat or `boop walk start` without issuing `ql`, `ih`, `boop status`, or waiting for unrelated GMCP activity.
started: Observed during Phase 03 UAT Tests 2 and 3 on package version 0.1.441.

## Eliminated

- hypothesis: The walker evaluates `walk_room_unsettled` or `manual_targeting` in the wrong order.
  evidence: `boop_walk.lua:239-254` evaluates manual targeting before room settlement, and the shared room observation remains `itemsSeen=false`; combat and gold stall independently in the same generations.
  timestamp: 2026-07-28T21:20:00-07:00
- hypothesis: The response timeout is too short and causes the missing evidence.
  evidence: `boop_runtime.lua:335-355` and `boop_events.lua:300-315` only warn on timeout; they do not remove or retry the fence. The generation settles immediately when a later `ql`/`ih`-induced room List arrives.
  timestamp: 2026-07-28T21:20:00-07:00
- hypothesis: Generation 46 incorrectly bypasses its `room_partial` blocker and dispatches combat.
  evidence: `output.md:1764,1795,1799,1803` repeatedly shows generation-46 ticks held. The commands acknowledged/executed at lines 1796-1805 were emitted synchronously from the generation-45 settlement at lines 1751-1755.
  timestamp: 2026-07-28T21:22:00-07:00
## Evidence

- timestamp: 2026-07-28T21:14:00-07:00
  checked: Phase 03 UAT and synchronized version checkpoints
  found: UAT Test 2 records `walk_room_unsettled` followed by `room_partial` and no movement; Test 3 independently records delayed combat until a later room List. `mfile`, `boop_init.lua`, and `CODEX.md` all identify version 0.1.441.
  implication: the symptom is cross-consumer room-settlement failure in the exact reported package, not a version mismatch or walker-only presentation bug.
- timestamp: 2026-07-28T21:15:00-07:00
  checked: output.md room chronology
  found: At output.md:26-27, a room List count=0 exits `room_partial`; only afterward, output.md:29-33 enters generation 35 with room=4232 and items=false as Room.Info moves 4231->4232. The generation times out at output.md:65-66 and settles only when `ql` produces another List at output.md:68-70.
  implication: the destination's naturally arriving List was consumed before the destination Room.Info generation existed; no automatic event subsequently wakes that generation.
- timestamp: 2026-07-28T21:15:00-07:00
  checked: repeated output.md transitions
  found: The same pattern recurs across generations 36-46: each moved Room.Info enters items=false and settlement occurs only on a later List, often seconds later. The failure affects combat/gold/target/walk through the shared `room:observation` blocker.
  implication: this is a deterministic live ordering mismatch in shared room evidence, not an intermittent walker API failure.
- timestamp: 2026-07-28T21:16:00-07:00
  checked: src/scripts/boop/boop_runtime.lua response-fence implementation
  found: `observeRoomItemsList` authorizes an `await_room` queue head when the fence generation/room equal the current observation and `currentRoomId()` equals that observation. Before Room.Info changes, all three values still identify the old room; the List payload itself carries no room ID. Accepted heads are immediately removed and `itemsSeen=true`.
  implication: an Inv barrier cannot distinguish an old-room response from a destination List delivered before destination Room.Info; the fence can authenticate serialization but not room identity.
- timestamp: 2026-07-28T21:16:00-07:00
  checked: src/scripts/boop/boop_events.lua onRoomItemsList/onRoomInfo ordering
  found: `onRoomItemsList` applies every `accepted` transition immediately to room targets, room blocker, gold, walk settlement, and tick. `onRoomInfo` is the only moved-room boundary that starts the destination observation; it runs later in the failing live order, invalidates only fences still queued, enters `room_partial`, and opens one capped replacement request.
  implication: once the pre-Info destination List has been popped as old-room evidence, no state remains that can reconcile it with the following Room.Info.
- timestamp: 2026-07-28T21:16:00-07:00
  checked: existing response-fence tests in tests/boop_event_transitions_spec.lua and tests/boop_walk_spec.lua
  found: Tests reject a room List only when it precedes the inventory barrier, and stale-epoch tests call `onRoomInfo` before delivering delayed old responses. They do not exercise an old/current fence already in `await_room` followed by a destination room List and only then destination Room.Info.
  implication: the tests model either Room.Info-first invalidation or room-before-Inv rejection, not the observed post-Inv List-before-Info sequence that satisfies the fence under the wrong epoch.
- timestamp: 2026-07-28T21:17:00-07:00
  checked: read-only direct runtime probe against boop_runtime.lua
  found: With room 4231 and fence 1 already `await_room`, a destination-shaped room List returned `accepted` for room 4231/generation 1, populated acceptedItems, and emptied the queue. Delivering Room.Info 4232 then produced generation 2 with itemsSeen=false and no accepted items.
  implication: the exact state corruption is deterministic in the production runtime without walker, gold, UI, or timing dependencies.
- timestamp: 2026-07-28T21:17:00-07:00
  checked: prior resolved G-03-1 diagnosis
  found: The earlier diagnosis explicitly required list-first evidence to remain unbound until a matching Info and warned that persistent GMCP Room.Info cannot authenticate a room-ID-less List. Plan 03-11 replaced that with an Inv→Room serialization fence and explicitly prohibited unbound candidates.
  implication: the implemented fix narrowed stale-response handling but did not satisfy the original live unordered-pair requirement; the regression is a design gap in the chosen fence, not accidental drift in walker code.
- timestamp: 2026-07-28T21:18:00-07:00
  checked: direct runtime replacement-fence continuation
  found: After Room.Info creates generation 2, its replacement fence reaches `await_room` on the inventory response while `itemsSeen` remains false; a later room List is accepted and completes generation 2.
  implication: once the generation misses/drops its first room response, any unrelated later room List (`ql`, `ih`, or equivalent GMCP-producing activity) acts as the wakeup because timeout only warns and the fence remains queued.
- timestamp: 2026-07-28T21:18:00-07:00
  checked: repository host suites
  found: `boop_event_transitions_spec.lua` passes 48/48 and `boop_walk_spec.lua` passes 41/41 against version 0.1.441.
  implication: production matches the tested ordered-fence contract; the live failure is missing regression coverage, not a currently failing covered case.
- timestamp: 2026-07-28T21:19:00-07:00
  checked: output.md:1751-1805
  found: The delayed List settles room 4255/generation 45 at lines 1751-1755 and immediately emits target/standard queue intent for denizen 44026. Room.Info then moves to 4249/generation 46 and enters `room_partial` at lines 1759-1764, yet the prior settarget and BOOP_ATTACK commands execute at lines 1796-1804 and fail with `You cannot see that being here.`
  implication: room observation blocks new generation-46 decisions, but it does not revoke commands already emitted from generation 45; this is a prior-room dispatch race coupled to the late settlement edge.
- timestamp: 2026-07-28T21:21:00-07:00
  checked: response-order liveness probe using the production `boop_runtime.lua`
  found: With a fresh fence in `await_inv`, one room List returned `awaiting_inv` and its payload was not stored; the following Inv response changed the fence to `await_room` but left `itemsSeen=false`. Only a second room List completed the generation. In the complementary post-Inv case, the first room List was accepted into generation 1/room 4231, then Room.Info 4232 started generation 2 with `itemsSeen=false` and an empty accepted list.
  implication: the fence has safety only for its assumed order, not liveness for the unordered live response pair, and it cannot reconcile a room-ID-less List across the subsequent Info boundary.
- timestamp: 2026-07-28T21:22:00-07:00
  checked: targeting and combat dispatch path
  found: `boop_events.lua:1255-1292` immediately updates targets/gold/walk and calls `boop.tick()` for an accepted List; `boop_targets.lua:218-224` immediately sends `settarget`; `boop_attacks.lua:1607-1645` calls `executeAction`; and `boop_util.lua:202-224` immediately sends `setalias BOOP_ATTACK ...` plus `queue addclearfull freestand BOOP_ATTACK`. None carries the room observation generation.
  implication: there is no revalidation point between evidence acceptance and externally visible command dispatch.
- timestamp: 2026-07-28T21:22:00-07:00
  checked: moved-room invalidation and attack-intent cleanup
  found: `boop_events.lua:1455-1514` starts the new observation and blocker, but its moved-room cleanup clears only target-call and shield state. `boop_runtime.lua:1090-1124` can clear local pending attack/alias metadata but does not cancel commands already sent to the server, and `onRoomInfo` does not call it here.
  implication: generation 46 can correctly block new decisions while generation-45 `settarget`/`BOOP_ATTACK` still executes. This is a separate dispatch-lifetime defect exposed by the same late evidence boundary, not another failure of the generation-46 blocker.
- timestamp: 2026-07-28T21:22:00-07:00
  checked: missing regression coverage
  found: `boop_event_transitions_spec.lua:647-797` sends Room-before-Inv, expects it to be rejected, then supplies a second Room after Inv; `:799-925` moves Room.Info before delayed old responses; and `:927-1063` explicitly expects the one-response out-of-order case to time out. `boop_walk_spec.lua:1022-1172` feeds ordered old and new Inv→Room pairs. No test covers accepted List→immediate moved Info before target/attack execution.
  implication: existing coverage proves stale-response safety under an ordered-response contract but deliberately omits (and in one case codifies against) live response-order liveness and prior-generation command revocation.
- timestamp: 2026-07-28T21:23:00-07:00
  checked: identity limits of the live chronology
  found: Because `Char.Items.List` has no room ID, `output.md` alone cannot prove whether every pre-Info List is a destination response or a delayed response for the old/current room. The room-4255 payload identifies denizen 44026 in room 4255 and is therefore prior-room evidence relative to the following move to 4249.
  implication: the root cause does not depend on assigning every pre-Info List to the destination: either identity is unsafe under the current fence. Destination evidence can be discarded before Inv, while valid prior-room evidence can settle and dispatch after movement has begun but before Room.Info establishes the new epoch.

## Resolution

root_cause: >-
  G-03-7 is a response-order/identity defect in the shared room-observation fence. `requestRoomItemsForFence` sends `Char.Items.Inv` and `Char.Items.Room`, but `observeRoomItemsList` requires responses in that same order. A room response received while the fence is `await_inv` is returned as `awaiting_inv` and discarded; after the Inv response, the fence waits indefinitely for a second room List because timeout only warns. Conversely, after Inv, a room-ID-less List arriving before a moved Room.Info is authorized by the still-persistent old room/generation and is applied immediately; the following Info starts a new generation with `itemsSeen=false`. This explains why unrelated later `ql`/`ih`/GMCP List activity wakes combat/walk. The 4255→4249 failure is a coupled, separate prior-room dispatch race: generation-45 settlement synchronously sends `settarget` and server-queued `BOOP_ATTACK`; moved Room.Info correctly blocks generation 46 but does not generation-own, defer, or revoke the commands already emitted, so they execute in room 4249.
fix: >-
  Diagnose-only. Smallest correct direction: replace the one-way phase with per-fence Inv/Room latches that retain either response order and finalize exactly once after both halves are present, while keeping fail-closed generation/room validation and explicitly reconciling or invalidating any room-ID-less pre-Info candidate at the moved Info boundary. Then make target/gold/walk/tick application and target/attack command emission generation-owned and deferred to a final room-generation revalidation point; movement must cancel stale pending applicators/intent without globally clearing unrelated shared queue work.
verification: >-
  Confirmed by `output.md` chronology, source-path trace, and a read-only production-runtime probe for both post-Inv List-before-Info and Room-before-Inv. Existing focused suites still pass (`boop_event_transitions_spec.lua` 48/48; `boop_walk_spec.lua` 41/41), demonstrating the gap is absent from current coverage.
files_changed: []

## Files Involved

- `src/scripts/boop/boop_runtime.lua:222-253,281-323,335-464,1090-1124` — observation epochs, strict ordered fence, warning-only timeout, and local-only attack cleanup.
- `src/scripts/boop/boop_events.lua:318-343,1255-1292,1407-1552` — one-shot request, synchronous accepted-List side effects, and moved-room invalidation that does not revoke prior combat dispatch.
- `src/scripts/boop/boop_targets.lua:149-161,218-224` — accepted items replace denizens and target selection immediately sends `settarget`.
- `src/scripts/boop/boop_attacks.lua:1607-1645` and `src/scripts/boop/boop_util.lua:202-224` — generationless immediate standard/rage/alias/server-queue dispatch.
- `src/scripts/boop/boop_walk.lua:239-254,563-637,714-783` — consumer of shared settlement; its manual-mode and generation checks are not the root cause.
- `tests/boop_event_transitions_spec.lua:647-1063` and `tests/boop_walk_spec.lua:1022-1172` — ordered/stale safety coverage that omits live unordered-pair liveness and stale-dispatch cancellation.
- `output.md:26-70,1751-1805` — live ordering, later-List wakeup, and prior-room command execution evidence.

## Missing Regression Coverage

- A fresh current-room walk under both response orders, Inv→Room and Room→Inv, with exactly one response of each type: it must settle to `manual_targeting`; selecting automatic targeting must reserve/emit exactly one move without `ql`, `ih`, or status activity.
- Post-Inv List-before-moved-Info followed by the destination's own unordered response pair: old evidence must never cross-bind, and the destination must settle without a second List.
- Room-before-Inv with no duplicate room response: the copied room payload must remain latched and settle when Inv arrives, with exactly one target/gold/walk/tick application.
- The exact 4255→4249 ordering: generation 45 List accepted, then generation 46 Room.Info before deferred dispatch. Assert zero generation-45 `settarget`, `BOOP_ATTACK`, rage, gold, or walk emissions after the boundary and that generation 46 stays blocked until its own evidence settles.
- Stale-dispatch cancellation must preserve unrelated gold/diagnostic/shared `freestand` queue ownership and must not double-tick, double-reserve, or double-send when both response halves arrive.

## Suggested Fix Direction

1. Store copied Inv and Room payloads as independent latches on a fence; accept either arrival order and complete once, only while the fence's observation generation and room still match.
2. Treat a pre-Info room List as untrusted because List has no room ID. Reconcile it only through an explicit bounded transition rule; otherwise invalidate it at moved Room.Info and open a fresh order-independent fence. Never infer destination identity from persistent old `gmcp.Room.Info`.
3. Separate evidence settlement from external command emission. Queue a generation-owned applicator/decision and re-check observation generation, room ID, and blocker state immediately before target/gold/walk/combat sends. A moved Info must invalidate that pending work and clear stale local intent; avoid an unsafe global server queue clear.
4. Preserve the existing walker policy: once current-room evidence is settled, manual mode should report `manual_targeting`, and switching to auto should advance exactly once.
