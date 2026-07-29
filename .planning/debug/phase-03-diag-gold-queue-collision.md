---
status: diagnosed
trigger: "Diagnose G-03-8 in /var/home/ron/mudletCode/boop. Goal: find_root_cause_only. Do not edit source, tests, UAT, versions, or commits."
created: 2026-07-28T21:12:56-07:00
updated: 2026-07-28T22:07:30-07:00
---

## Current Focus

hypothesis: CONFIRMED — a real diag started after gold dispatch globally replaces the server queue without transitioning the owned gold stage back to unsent/displaced; its still-live timer suppresses release-time replay and later terminates the generation without game evidence
test: live trace ordering, authoritative Achaea queue semantics, complete dispatch/timeout/runtime release path, trigger coverage, and focused test ordering all agree
expecting: confirmed observations are recorded below; no remaining competing hypothesis explains the exact command, error, owner, timer, and room-refresh sequence
next_action: return the root-cause-only report; make no production or test changes

## Symptoms

expected: A queue-clearing interrupt cannot silently discard an owned pending gold command. Gold remains held while the interrupt owns the queue, then exactly one eligible get-confirm-put sequence resumes or terminates from explicit evidence without requiring a room refresh.
actual: On boop 0.1.441, gold generation 5 transitions from deferred_room to pickup_pending and queues `get sovereigns`; `diag` then starts and sends its queue-clearing interrupt; no gold pickup/removal/success follows; four seconds later `pending_timeout` clears generation 5 while sovereigns remain in room 4249; a later room refresh/movement creates generation 6, which succeeds.
errors: The game reports `Unknown queue specified` immediately after the diag queue commands.
reproduction: In a room containing sovereigns, let gold generation 5 dispatch `queue add freestand get sovereigns`, then invoke `diag`, whose current implementation sends `queue clear` followed by `queue addclearfull freestand diagnose`; observe no get result and eventual gold timeout until a later room refresh creates a new generation.
started: Phase 03 UAT Test 3 on package version 0.1.441; normal gold generations 1, 2, 4, and 6 succeed, isolating the failure to the live diag/gold overlap.

## Eliminated

- hypothesis: The four-second timeout is the primary cause and merely needs to be lengthened.
  evidence: `QUEUE ADDCLEARFULL` has already removed the only get command. While `operation.timeoutTimer` remains truthy, `boop_runtime.lua:1336-1354` and `boop_events.lua:1056-1070` prohibit redispatch; any longer positive timeout only delays the same no-evidence termination.
  timestamp: 2026-07-28T21:15:35-07:00

- hypothesis: The `Unknown queue specified` response means `queue addclearfull freestand diagnose` was rejected, leaving the gold get intact.
  evidence: Achaea's QUEUEING help defines `Freestand` as valid, `QUEUE ADDCLEARFULL <queue> <command>` as removing all queued commands then inserting the new command, and `QUEUE CLEAR <queue>` as requiring a queue argument. In both live diag runs (`output.md:1312-1331`, `1636-1651`) the error is followed by successful diagnose output.
  timestamp: 2026-07-28T21:15:05-07:00

- hypothesis: Diag fails to release its own owner, so the interrupt hold itself causes the gold timeout.
  evidence: The retained trace at `output.md:1874-1881` records `interrupt:2` exiting and terminating on `diagnose_result_prompt` at 18:35:46, two seconds before generation 5 times out at 18:35:48.
  timestamp: 2026-07-28T21:14:53-07:00
## Evidence

- timestamp: 2026-07-28T21:13:37-07:00
  checked: `.planning/debug/knowledge-base.md`
  found: No debug knowledge base exists.
  implication: There is no known-pattern candidate to privilege; diagnosis must come from current source and live evidence.

- timestamp: 2026-07-28T21:13:37-07:00
  checked: `.planning/phases/03-queue-interrupt-gold-and-autowalk-regression-coverage/03-UAT.md:92-127`
  found: Test 3 records normal generations 1, 2, 4, and 6 completing, but generation 5 loses progress only when diag overlaps; the later generation 6 requires a refreshed room observation.
  implication: Generic gold parsing, pickup, and packing work; the differentiating condition is shared-queue mutation during the active pickup generation.

- timestamp: 2026-07-28T21:13:37-07:00
  checked: `src/scripts/boop/boop_ui.lua:1404-1406` and `src/scripts/boop/boop_events.lua:760`
  found: Gold queues `get sovereigns` on `freestand`; diag sends two separate commands, bare `queue clear` and then `queue addclearfull freestand diagnose`.
  implication: The server-visible error and destructive replacement may come from different commands; exact output ordering must be resolved before attributing causality.

- timestamp: 2026-07-28T21:14:06-07:00
  checked: `output.md:1598-1668`
  found: Generation 5 becomes `pickup_pending`, emits one `gold queue: get sovereigns` at line 1632, then diag generation 2 starts at lines 1636-1640. `Unknown queue specified` appears at line 1641, but diagnose executes and produces its result at lines 1648-1651. No gold removal/get-success occurs before the gold timeout at lines 1665-1668.
  implication: Diag's second queue command executes despite the visible queue error; the get is gone while boop still believes generation 5 is pickup-pending.

- timestamp: 2026-07-28T21:14:06-07:00
  checked: `output.md:1808-1829`
  found: A later current-room item list creates generation 6, which emits exactly one get, receives item removal and explicit pickup success, emits one put, and terminates on explicit put success.
  implication: The room's gold and the normal get-confirm-put machinery remained valid; only generation 5's queued command/ownership coordination failed.

- timestamp: 2026-07-28T21:14:06-07:00
  checked: `.planning/STATE.md:100-123`
  found: Phase decisions intentionally made get/put independent `freestand` commands and aggregate authorization the release mechanism; reevaluation after owner release applies only when the gold stage remains unsent and has no active timeout.
  implication: The current design coordinates blockers before dispatch but does not yet establish ownership of a dispatched shared-queue entry against a later destructive interrupt.

- timestamp: 2026-07-28T21:14:53-07:00
  checked: Achaea `HELP QUEUEING` (`https://www.achaea.com/game-help?what=queueing`)
  found: `QUEUE CLEAR` requires a queue argument; `Freestand` is a valid queue type; `QUEUE ADDCLEARFULL` removes all queued commands and inserts its new command at the beginning.
  implication: `queue clear` is the source of `Unknown queue specified`; `queue addclearfull freestand diagnose` is the accepted command that removes `queue add freestand get sovereigns`.

- timestamp: 2026-07-28T21:14:53-07:00
  checked: `src/scripts/boop/boop_events.lua:606-650,692-779,1056-1108` and `src/scripts/boop/boop_runtime.lua:1325-1354`
  found: Gold authorization checks unrelated blockers only at dispatch. Once sent, the operation remains `pickup_pending` with a truthy timeout token; both runtime tick and gold flush refuse another send while that token exists. There is no displaced/removed queue-entry state.
  implication: Clearing the interrupt owner correctly cannot recover the get: boop still treats the removed server command as in flight.

- timestamp: 2026-07-28T21:14:53-07:00
  checked: `src/scripts/boop/boop_events.lua:692-715`
  found: When the four-second callback fires it first consumes the timeout token; if dispatch is then authorized, it logs stale state and calls `completeGoldOperation(..., "pending_timeout")` without revalidation, retry, or redispatch.
  implication: Because diag had already released, generation 5 is silently terminated from elapsed time rather than explicit get failure/removal/success evidence.

- timestamp: 2026-07-28T21:15:35-07:00
  checked: `tests/boop_gold_spec.lua:278-343`, `tests/boop_event_transitions_spec.lua:1344-1377`, and `tests/boop_gold_retry_spec.lua:273-371`
  found: Aggregate-owner tests put the interrupt owner in place before initial gold dispatch, or fire the gold timeout while a synthetic interrupt owner is still active. They therefore test unsent-stage release/requeue, not a real diag arriving after get dispatch and replacing the server queue; the real interrupt release case uses non-clearing `matic`.
  implication: The live ordering and shared-queue destructive effect are outside existing coverage.

- timestamp: 2026-07-28T21:15:41-07:00
  checked: `tests/boop_diag_spec.lua:70-75,137-184`, `tests/boop_diag_timeout_spec.lua:42-53,90-114`, and `tests/boop_event_transitions_spec.lua:48-50`
  found: Test `send` stubs only append command strings. Diag tests assert both bare `queue clear` and `queue addclearfull freestand diagnose` were emitted but do not simulate server queue contents, `ADDCLEARFULL` replacement, or the queue error.
  implication: Tests can pass while blessing the invalid clear command and never observe loss of the previously queued gold get.

- timestamp: 2026-07-28T21:16:40-07:00
  checked: `src/triggers/boop/Gold/triggers.json:18-34` and `src/triggers/boop/Gold/Gold_Command_Failure.lua:1`
  found: Gold retries are driven by explicit get/put failure lines such as not seeing/carrying the item. `Unknown queue specified` is not a gold failure trigger, and there is no trigger for a command displaced by `ADDCLEARFULL`.
  implication: The queue error cannot repair or explicitly terminate generation 5; with no get command left, no pickup success/removal/failure evidence can arrive.

- timestamp: 2026-07-28T22:07:30-07:00
  checked: User correction and Achaea `HELP QUEUEING` (`https://www.achaea.com/game-help?what=queueing`)
  found: `CLEARQUEUE ALL` is the valid command for clearing every queue; `QUEUE CLEAR <queue>` is only the queue-specific synonym for `CLEARQUEUE <queue>`.
  implication: Preserve diag's explicit global-clear step by replacing bare `queue clear` with `clearqueue all`; do not simply omit that step.

## Resolution

root_cause: |
  Gold and diag share the native Achaea queue without shared command-entry ownership.
  Generation 5 first sends `queue add freestand get sovereigns` and arms its four-second
  pending timer (`boop_events.lua:56-58,754-779`). Real diag then sends invalid bare
  `queue clear` followed by valid `queue addclearfull freestand diagnose`
  (`boop_ui.lua:1403-1406`). Achaea rejects the first command as `Unknown queue
  specified`; the second globally removes every queued command, including gold's get,
  and inserts diagnose.

  The Lua gold owner remains `pickup_pending`, because no state transition records that
  its server queue entry was displaced. Diag correctly releases `interrupt:2` on result
  plus prompt, but the gold timeout token is still live. Runtime tick therefore emits no
  `flush_gold` (`boop_runtime.lua:1336-1354`), and both gold flush/dispatch reject replay
  while the token exists (`boop_events.lua:754-779,1056-1108`). At four seconds the
  callback consumes the token, sees all other owners clear, and calls
  `completeGoldOperation(..., "pending_timeout")` without retry, revalidation, or game
  evidence (`boop_events.lua:692-715`). No later room event exists to create another
  generation, so only the eventual refresh creates generation 6.

  The four-second duration is not the primary cause. Lengthening it only lengthens the
  period during which replay is suppressed before the same terminal path. It is a
  secondary symptom/terminalizer that turns the queue-ownership collision into silent
  abandonment. The existing behavior is also timing-dependent: if the timer fires
  while an interrupt owner still holds queue/gold authorization, it consumes the token
  without terminating and a later tick can replay; if diag releases first, as live UAT
  did, the timer terminates the operation.
fix: |
  Suggested direction only: coordinate destructive queue mutation with the active gold
  operation. Before `ADDCLEARFULL`, mark an already-dispatched pickup/pack command as
  explicitly displaced/unsent and cancel or consume its pending timer while preserving
  the gold owner. On the interrupt's exact terminal transition, reauthorize current
  evidence and dispatch exactly one current-stage get/put, or terminate only from an
  explicit invalidation/failure signal. Replace invalid bare `queue clear` with
  `clearqueue all`, and preserve the following `queue addclearfull freestand diagnose`
  command. Initial, retried, and replayed pickup should use the operator-selected
  `queue add full get sovereigns`; packing remains on `freestand`.
verification: |
  Root-cause-only diagnosis. Confirmed from package 0.1.441 live trace
  (`output.md:1598-1668,1808-1829,1874-1881`), source control flow, official Achaea
  QUEUEING semantics, trigger inventory, and focused test/static probes. No production,
  test, UAT, version, or commit changes were made.
files_changed:
  - `.planning/debug/phase-03-diag-gold-queue-collision.md`

## Files Involved

- `src/scripts/boop/boop_ui.lua:1333-1423` — `queueInterrupt` emits the invalid bare clear and the accepted global `ADDCLEARFULL` without coordinating an already-dispatched gold command.
- `src/scripts/boop/boop_events.lua:56-58,606-650,692-779,1056-1198` — gold tracks phase/timer ownership but not whether its native queue entry was displaced; timeout completes rather than replaying or waiting for explicit evidence.
- `src/scripts/boop/boop_runtime.lua:1325-1354,1440-1493` — diag release runs a normal tick, but the active gold timeout suppresses `flush_gold`.
- `src/triggers/boop/Gold/triggers.json:18-34` — explicit get/put failures are covered; queue replacement/error is not.
- `tests/boop_gold_spec.lua:278-343` — tests blocker-before-dispatch, not interrupt-after-dispatch.
- `tests/boop_gold_retry_spec.lua:273-371` — tests timeout while a synthetic owner is still active, not the live release-before-timeout ordering after a destructive queue replacement.
- `tests/boop_event_transitions_spec.lua:1344-1377` — the real interrupt release test starts non-clearing `matic` before gold, so the gold stage is still unsent.
- `tests/boop_diag_spec.lua:70-75,137-184` and `tests/boop_diag_timeout_spec.lua:42-53,90-114` — append-only send stubs assert command text but do not model Achaea queue semantics or server errors.

## Missing Regression Coverage

- Start a settled gold pickup first; assert one native get and one live timeout, then invoke real `boop.ui.diag()` and model `ADDCLEARFULL` removing that get.
- Complete diag result plus prompt before the gold timeout, matching `output.md`; assert the gold owner survives and exactly one current-stage get is replayed without a new room List/Info event.
- Continue through item removal/get success and assert exactly one put and one explicit terminal transition.
- Cover the converse timeout-while-interrupt-active ordering so correctness does not depend on which timer/owner releases first.
- Repeat the collision for inventory-owned `pack_pending`.
- Make the queue model reject bare `QUEUE CLEAR`, accept `CLEARQUEUE ALL`, and apply global `ADDCLEARFULL` semantics so tests prove the corrected two-command diag sequence.

## Suggested Fix Direction

Introduce an explicit native-queue displacement transition at the gold/interrupt boundary:
preserve `gold:<generation>`, convert the current sent stage to replayable unsent state,
cancel its stale pending timer, issue valid `clearqueue all`, perform the interrupt's
following global replacement, and let the
exact interrupt terminal path schedule one generation-guarded normal tick. That tick
must revalidate the unchanged room-owned pickup (or inventory-owned pack), issue one
`full` pickup command or `freestand` pack command, and re-arm one timer. Explicit
movement, item failure/removal, success, disable,
or flee evidence may still terminate through existing generation guards; elapsed time
alone must not silently discard queue-replaced gold.
