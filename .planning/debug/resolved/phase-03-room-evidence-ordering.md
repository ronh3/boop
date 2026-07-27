---
status: resolved
trigger: "Diagnose Phase 03 UAT gap G-03-1 only. Goal: find_root_cause_only."
created: 2026-07-26T00:00:00-07:00
updated: 2026-07-26T20:12:00-07:00
---

## Current Focus

hypothesis: CONFIRMED — an ordered-pair room state machine treats event arrival order as room identity and treats every Room.Info as movement; this discards valid evidence, rearms release, and cannot safely reconcile a room-ID-less List.
test: Completed through source tracing, history, focused specs, and deterministic host harnesses.
expecting: Confirmed.
next_action: Post-fix live UAT is tracked in Phase 03 Test 1.

## Symptoms

expected: Room settlement accepts either live GMCP arrival order, preserves complete evidence across same-room Room.Info refreshes, and releases hunting and walker ownership exactly once when the current room is complete.
actual: Live trace showed gmcp.Char.Items.List before gmcp.Room.Info; Room.Info started a new items:false generation even when moved=no; walker remained held until another list arrived. Repeated live examples showed list -> same-room Info -> room_partial -> later duplicate list clears.
errors: No Lua error reported; incorrect room settlement and ownership-release state transitions.
reproduction: Test 1 in Phase 03 UAT.
started: Discovered during live Phase 03 UAT.

## Eliminated

- hypothesis: The walker fails to clear its own exact owner after complete current-generation evidence.
  evidence: Focused event/walk specs pass, and the direct harness shows walk:12 clears immediately on each complete matching List; the owner is reintroduced only because same-room Info creates a new room generation.
  timestamp: 2026-07-26T00:25:00-07:00

## Evidence

- timestamp: 2026-07-26T00:01:00-07:00
  checked: .planning/debug/knowledge-base.md
  found: No project debug knowledge base exists.
  implication: There is no known-pattern candidate to test first; investigation must proceed from current code and UAT evidence.

- timestamp: 2026-07-26T00:10:00-07:00
  checked: src/scripts/boop/boop_runtime.lua room-observation API
  found: startRoomObservation always increments generation and resets itemsSeen=false; stampRoomItemsObservation rejects a list unless an infoSeen observation already exists and its roomId matches the persistent gmcp.Room.Info.num.
  implication: The runtime models only Info-then-List. It has no unbound/pending list evidence that can survive until a following Room.Info identifies the room.

- timestamp: 2026-07-26T00:10:00-07:00
  checked: src/scripts/boop/boop_events.lua onRoomItemsList and onRoomInfo
  found: A list handler returns as room_partial when stamping fails. Conversely, every Room.Info first starts a new items:false generation, cancels room-owned gold, and enters room_partial; only afterward does it compare previous and current room IDs, set movedRooms, and call walk.onRoomChange unconditionally.
  implication: Valid list evidence is necessarily lost on every following Info, including moved=no refreshes, and unrelated room-owned state is invalidated before movement is known.

- timestamp: 2026-07-26T00:10:00-07:00
  checked: src/scripts/boop/boop_walk.lua settlement and arrival flow
  found: Walker settlement is generation-equality gated. onRoomSettled clears the exact walk owner and calls maybeAdvance only when the walk.roomGeneration equals the complete observation; onArrived/onRoomChange both arm a fallback but cannot reconcile evidence from the prior generation.
  implication: The walker correctly stays fail-closed after Room.Info resets the observation; the stall is downstream evidence of the observation lifecycle defect, not an independent failure to clear the walker owner.

- timestamp: 2026-07-26T00:10:00-07:00
  checked: common bug pattern map
  found: Symptoms match Async/Timing plus State Management invalid-transition/dual-source categories.
  implication: Competing hypotheses are event-order mismatch, unconditional same-room invalidation, or walker release duplication; specs and a focused reproduction must distinguish them.

- timestamp: 2026-07-26T00:20:00-07:00
  checked: tests/boop_event_transitions_spec.lua and tests/boop_walk_spec.lua
  found: Tests explicitly require a fresh generation for every Room.Info, require List only after that generation, invalidate a room-owned stage on same-room Room.Info, and model walker owner transition with Room.Info before List. There is no List-before-Info or same-room evidence-preservation case.
  implication: The regression suite does not merely omit the live order; several assertions pin the faulty ordered-event contract and must be replaced or narrowed to actual room changes.

- timestamp: 2026-07-26T00:20:00-07:00
  checked: git history for room observation and walker event wiring
  found: Commit b84c205 introduced the Info-starts-generation/later-List-only model by design. Commit d0a8e3c later made every Room.Info call walk.onRoomChange so the walker generation follows each reset, including moved=no.
  implication: Root cause is a cross-module state-machine design error introduced in Phase 03, not an intermittent external walker defect.

- timestamp: 2026-07-26T00:20:00-07:00
  checked: persistent Mudlet GMCP shape and event payload use in source/tests
  found: The room List payload contains location/items but no room ID, while stampRoomItemsObservation reads the independently persistent gmcp.Room.Info.num.
  implication: A fix cannot authorize a carried List merely because the merged GMCP table currently names a room; list-first evidence must remain unbound until reconciled by a validated room/arrival transition, and ambiguous stale evidence must fail closed.

- timestamp: 2026-07-26T00:25:00-07:00
  checked: focused host Busted tests for tests/boop_event_transitions_spec.lua and tests/boop_walk_spec.lua
  found: All 78 existing cases pass.
  implication: The implementation matches its tests; the UAT failure is an untested/incorrect contract assumption rather than accidental drift from the suite.

- timestamp: 2026-07-26T00:25:00-07:00
  checked: read-only List -> same-room Room.Info -> duplicate List harness
  found: The first List left generation 7 complete with room and walk owners clear. Same-room Info reported moved=false but replaced it with generation 8/itemsSeen=false and restored both owners. A duplicate List then completed generation 8 and cleared both owners.
  implication: The exact live state flow is reproduced deterministically and directly confirms the hypothesis.

- timestamp: 2026-07-26T00:32:00-07:00
  checked: read-only emitted List -> same-room Room.Info -> duplicate List harness
  found: The first completion emitted one demonwalker.move at reservation 1; same-room Info created generation 8, and the duplicate List created reservation 2 and emitted a second demonwalker.move.
  implication: Unconditional same-room regeneration violates the exactly-once requirement in both directions: it can stall when the first reservation is canceled or double-advance when it already emitted.

- timestamp: 2026-07-26T00:32:00-07:00
  checked: read-only changed Room.Info -> stale prior-room List harness
  found: After Room.Info changed from room 1 to room 2, a room-ID-less List containing old-room denizen old-42 set generation 8 itemsSeen=true, replaced current denizens, and cleared room:observation.
  implication: Persistent gmcp.Room.Info cannot authenticate the List payload. Any fix that simply carries or stamps whichever List is available would preserve a stale-list authorization hole.

- timestamp: 2026-07-26T00:32:00-07:00
  checked: demonnicAutoWalker upstream event contract and boop event adapter
  found: The walker documents arrived as a notification after reaching a room, including rooms selected because configured search targets matched; the live event supplies no room identity to boop, and boop normalizes the Mudlet event-name argument to nil.
  implication: demonwalker.arrived may open/annotate a pending transition window, but initial/non-movement arrival must not reset evidence and the event can never settle or identify a room by itself.

## Resolution

root_cause: >-
  Phase 03 modeled room settlement as a strict Room.Info -> Char.Items.List sequence. startRoomObservation always creates a new generation with itemsSeen=false, and onRoomInfo invokes it before comparing the incoming room ID with targeting.room. The handler therefore invalidates complete evidence and room-owned gold even when movedRooms is false, then routes every Info through walk.onRoomChange. Conversely, a List has no room ID and stampRoomItemsObservation authenticates it only by reading the separate persistent gmcp.Room.Info table, so List-first evidence is either attached to an old generation or cannot be safely identified. The walker correctly follows the replacement generation and stays fail closed until another List; if its first reservation already emitted, the same-room reset can instead create a second reservation and move.
fix: >-
  Replace the ordered-event API with one room-observation epoch that latches Room.Info and a copied complete List independently. Advance the epoch only for an actual room-ID change or an explicit fresh-start boundary, never for a same-room Info refresh. Compare room IDs before invalidating room-owned state: same-room Info must preserve generation, complete list/denizens, DEFERRED_ROOM/PICKUP_PENDING gold, walker reservation, and settled owners; actual changes invalidate those once. Because List has no room ID and Mudlet gmcp tables persist/merge, keep list-first data as an unbound copied candidate and do not update targets, authorize gold/walk, or clear owners until a matching Info binds it within a validated transition epoch. An outstanding walker reservation/arrival may annotate that epoch, but demonwalker.arrived alone must never identify, reset, or settle a room; initial/non-movement arrivals are no-ops for room identity. Ambiguous or stale candidates are discarded and trigger the existing one-shot refresh. Notify room/walk consumers only on the incomplete-to-complete edge so exact-owner clear, hunting reevaluation, reservation, and move remain one-shot.
verification: >-
  Diagnose-only. Existing focused event/walk specs passed 78/78. Read-only harnesses reproduced generation 7 complete -> same-room generation 8 partial -> duplicate List complete; demonstrated two walker moves when the first reservation emitted before the same-room refresh; and demonstrated that a stale old-room List after changed Room.Info currently settles the new generation and installs old-room denizens.
files_changed: []

required_regressions:
  - Info -> List and List -> Info each complete one observation epoch and produce one room-owner clear, one hunting reevaluation, and at most one walker reservation/move.
  - A complete same-room Room.Info refresh preserves generation, items, denizens, room-owned gold, settled state, and an existing emitted/pending walker reservation without a refresh, owner re-entry, second tick, or second move.
  - An actual room-ID change invalidates prior evidence, room-owned gold, and stale walker callbacks exactly once.
  - A prior-room List received before or after changed-room Info cannot settle, replace denizens, dispatch gold, or release walking unless it is safely bound to the validated current transition; ambiguous evidence stays room_partial and requests at most one refresh.
  - Pending list-first evidence is copied at receipt and consumed once; later mutation of the persistent gmcp table, duplicate Lists, delayed refreshes, prompts, timers, and stale callbacks cannot alter or settle another epoch.
  - Expected walker arrival supports both GMCP orders, while initial/start, event-name-only, repeated, and same-room/search-target demonwalker.arrived events provide no standalone room identity or settlement.
  - Fresh walk restart still requires fresh Info plus complete List even when the room number is unchanged.
