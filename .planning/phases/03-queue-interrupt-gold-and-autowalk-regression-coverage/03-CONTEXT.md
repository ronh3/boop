# Phase 03: Queue, Interrupt, Gold, and Autowalk Regression Coverage - Context

**Gathered:** 2026-07-25T22:51:37Z
**Status:** Ready for planning

<domain>
## Phase Boundary

Phase 03 hardens boop Hunter's timing-sensitive queue, interrupt, gold, and
autowalk paths. It must ensure that each pending action owns an explicit hold,
releases only from trustworthy evidence, and cannot attack, loot, or move after
its room or ownership boundary becomes stale.

This phase covers regression tests and the narrow behavior repairs those tests
expose. It does not absorb route selection from `demonnicAutoWalker`, add broad
new hunting commands, validate arbitrary command fragments, or expand compact
combat summaries. Those remain assigned to later roadmap phases.

</domain>

<decisions>
## Implementation Decisions

### Overlapping Holds
- **D-01:** Use per-system all-clear semantics. Each subsystem remains held until every blocker affecting that subsystem has cleared.
- **D-02:** Release boundaries are subsystem-specific. Clearing one subsystem must not release unrelated held work.
- **D-03:** Normal status shows the highest-priority blocker plus an additional-blocker count; trace and debug list every active blocker.
- **D-04:** Choose the primary blocker through a fixed safety priority so critical safety and missing-state blockers outrank workflow blockers.

### Interrupt Release Timing
- **D-05:** Each interrupt waits for operation-specific completion evidence, such as its success signal, required prompt, confirmed room transition, or defined timeout fallback.
- **D-06:** Timeout recovery cancels only the interrupt's owned intent, releases only its hold, emits warning and trace output, and preserves every unrelated blocker.
- **D-07:** Repeating an interrupt while it is pending is idempotent. Do not resend or restart it; report that the original request is still awaiting completion.
- **D-08:** The first terminal signal wins when timeout and success or prompt callbacks race. Release exactly once and make every later callback a no-op.

### Gold Room Ownership
- **D-09:** Gold detection, pickup, and pickup retries belong to the exact originating room ID. A room change invalidates that room-bound intent.
- **D-10:** After confirmed pickup, packing becomes inventory-owned and may complete or retry across room changes.
- **D-11:** Duplicate gold signals in the same room coalesce into one pickup lifecycle without sending or queueing another `get sovereigns`.
- **D-12:** If the room ID is missing or unsettled, defer pickup and require a stable room ID plus current room-item evidence that the gold is still present.
- **D-12A:** Initial, retried, and replayed gold pickup uses `queue add full get sovereigns`; packing remains an independent `freestand` put command.

### Autowalk Movement Safety
- **D-13:** Emit `demonwalker.move` only from a complete all-clear snapshot: the room is settled, no valid target remains, all walk-affecting blockers are clear, no loot, interrupt, pull, or flee work is pending, and no move is already queued.
- **D-14:** A settled room requires `Room.Info` and the complete room-items list for the same room. Prompts may support settlement but cannot replace missing room data.
- **D-15:** Missing settlement evidence triggers one capped room-refresh recovery while movement remains held. If evidence still does not arrive, emit warning and trace output without moving.
- **D-16:** Each settled room may produce at most one movement request. Re-arm only after a confirmed new room ID and a new arrival or settlement cycle; duplicate same-room callbacks are ignored.

### Manual Move Semantics
- **D-17:** `boop walk move` is a safe one-step request and obeys the same settlement and all-clear gate as automatic movement.
- **D-18:** A blocked manual move shows the primary reason, confirms no move was queued, and leaves movement state unchanged; full blocker detail remains in trace and debug.
- **D-19:** Repeating `boop walk move` while a move is pending is idempotent and does not alter ownership, timers, or the queued request.
- **D-20:** A successful manual move keeps walk mode active. Normal automatic evaluation resumes after the next arrival and settlement cycle.

### Walker Stop Ownership
- **D-21:** `boop walk stop` is ownership-aware. Stop the underlying run when boop started it; when boop only attached, detach boop and leave the external run under its original owner's control.
- **D-22:** Stop immediately invalidates boop's queued move before stopping or detaching. Late timers and callbacks from the stopped generation are no-ops.
- **D-23:** Restarting creates a fresh movement generation. Do not reuse prior room, settlement, blocker, or queued-move observations; require current-room GMCP before advancing.
- **D-24:** Stop confirmation states the ownership outcome: distinguish a stopped boop-owned walk from boop detaching while the external walker remains running.

### Agent Discretion
- Choose stable reason codes, blocker priorities within the user-selected safety ordering, and compact output wording consistent with existing status and trace surfaces.
- Choose bounded timeout values and the least noisy room-refresh mechanism. Recovery must remain capped and fail closed.
- Choose the external walker adapter calls needed to stop a boop-owned run after confirming the installed `demonnicAutoWalker` API.
- Choose test organization and helper extraction, provided timing, stale callback, room ownership, and command-order assertions remain explicit.
- If the external walker becomes unavailable mid-run, fail closed, invalidate boop-owned movement intent, and report the condition without attempting silent installation or update.

### Interrupt Admission And Preemption (Supplemental 2026-08-11)
- **D-25:** Keep blocker display priority and interrupt admission priority separate. `BLOCKER_PRIORITY` decides which active blocker is shown first; it does not authorize one operation to cancel another.
- **D-26:** Use four interrupt admission tiers: absolute safety, emergency, diagnostic, and utility. Existing commands classify as: auto-flee at absolute safety; `leap` and `fly` at emergency; `diag` at diagnostic; and `matic`, `catarin`, and `ts` at utility. Future `tumble` and class-heal commands must register as emergency without adding command-specific arbitration branches.
- **D-27:** Absolute safety may supersede any active operation. An emergency may atomically supersede a diagnostic or utility operation. A diagnostic may supersede a utility operation. Lower-priority work may never replace higher-priority work.
- **D-28:** Same-tier operations do not replace one another. Repeating the same pending command is idempotent; a different same-tier request is rejected with the active owner and reason. This prevents duplicate movement or heal commands after the first may already have started executing.
- **D-29:** Attacks, Rage, gold, target replacement, and walking are automation, not interrupt tiers. They remain held behind every active interrupt and may never preempt it. Emergency admission may displace their queued intent when required to make the emergency command authoritative.
- **D-30:** Supersession is one atomic lifecycle transition: install the incoming generation and blocker, terminalize the old generation with `superseded_by:<name>`, cancel its timer, tombstone its late evidence, and replace the native queue before any tick, retry, walker move, gold action, or automatic diagnose can run.
- **D-31:** Late result, prompt, timeout, denial, and room callbacks from a superseded generation are no-ops. They cannot complete, clear, or otherwise mutate the incoming operation.
- **D-32:** A superseded automatic diagnose retains the venom-confusion threshold and may be retried only after the emergency terminal. No diagnose retry may run in the transition window or displace the emergency.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Project And Requirements
- `.planning/PROJECT.md` - Brownfield pre-1.0 hardening goal, operator-control principle, constraints, and out-of-scope boundaries.
- `.planning/REQUIREMENTS.md` - Phase 03 requirements `SAFE-02`, `SAFE-04`, `WALK-01`, `WALK-02`, and `WALK-03`.
- `.planning/ROADMAP.md` - Phase 03 goal, success criteria, dependencies, and boundaries with Phases 04 through 06.
- `.planning/STATE.md` - Current milestone position and accumulated Phase 02 decisions.
- `.planning/phases/02-state-ownership-repair-and-safety-baseline/02-CONTEXT.md` - Canonical blocker, fail-closed, owned-state, and autowalk scope decisions inherited by Phase 03.

### Product Behavior
- `DESIGN.md` - Current gold, interrupt, pull, queue, shield, and external-walker behavior.
- `README.md` - Operator-facing `boop walk`, auto-gold, pack, interrupt, trace, and status behavior.

### Codebase Intel
- `.planning/codebase/ARCHITECTURE.md` - Runtime coordinator, owned state domains, GMCP event flow, gold lifecycle, and walker integration boundaries.
- `.planning/codebase/CONVENTIONS.md` - Owned-domain state rules, Lua compatibility, public API patterns, and side-effect conventions.
- `.planning/codebase/CONCERNS.md` - Known timing, autowalk, external integration, and regression-coverage risks.
- `.planning/codebase/INTEGRATIONS.md` - Achaea command channel, Mudlet events, and `demonnicAutoWalker` integration contract.
- `.planning/codebase/TESTING.md` - Mudlet Busted harness, timer/event stubbing patterns, and walk-test coverage gap.

### Repository Workflow
- `AGENTS.md` - Repository-local source, versioning, and documentation rules.
- `CODEX.md` - Release gates, build/test path, and synchronized package-version requirements.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `src/scripts/boop/boop_runtime.lua` - Owns domain defaults, blocker APIs, automation cleanup, runtime context, and tick coordination.
- `src/scripts/boop/boop_events.lua` - Owns interrupt transitions, GMCP room/item handling, gold detection, queue intent, retry timers, stale-state cleanup, and prompt entry points.
- `src/scripts/boop/boop_walk.lua` - Existing optional walker adapter with `active`, `owned`, `roomSettled`, `moveQueued`, arrival timers, blocker checks, and `demonwalker.move` emission.
- `src/scripts/boop/boop_targets.lua` - Supplies current target and valid-room-target decisions used by the walk all-clear gate.
- `src/scripts/boop/boop_ui.lua` and `src/scripts/boop/boop_ui_registry.lua` - Route interrupt and walk commands and provide compact status/help output.
- `tests/support/boop_test_helper.lua` - Shared owned-state and GMCP fixture setup.
- `tests/boop_interrupt_spec.lua`, `tests/boop_gold_spec.lua`, `tests/boop_gold_retry_spec.lua`, `tests/boop_walk_spec.lua`, `tests/boop_event_transitions_spec.lua`, `tests/boop_prequeue_spec.lua`, and `tests/boop_tick_spec.lua` - Existing focused homes for Phase 03 contracts.

### Established Patterns
- Safety state lives in owned domains and cross-system holds flow through `boop.runtime.shouldHold()` and `boop.runtime.blockerSnapshot()`.
- Deferred Mudlet effects use `tempTimer`; tests capture callbacks and invoke them explicitly to verify stale-generation and race behavior.
- Gold pickup uses Achaea's `full` queue, packing uses `freestand`, and both maintain separate get, put, retry, pack, and stale-timeout state.
- Normal output is compact and transition-oriented; complete state belongs in `boop trace` and debug surfaces.
- `demonnicAutoWalker` owns route choice, while boop owns only room-safety decisions and movement-event emission.
- CI builds with Muddler and runs Busted inside a real Mudlet profile.

### Integration Points
- Extend the canonical blocker model to support multiple simultaneous blockers and per-system release without reintroducing flat state.
- Bind interrupt and gold callbacks to operation or room generations so late callbacks cannot release or retry newer work.
- Replace timer-only room settlement with same-room `Room.Info` plus complete room-item evidence and a capped recovery path.
- Keep `demonwalker.move` behind one all-clear emission path used by both automatic and manual movement.
- Add an ownership-aware stop adapter while preserving explicit missing-package status/install behavior and avoiding silent updates.

</code_context>

<specifics>
## Specific Ideas

- Normal blocker output should resemble `primary_code -- short label | +N more`; trace/debug should list all blockers and affected systems.
- Gold lifecycle has two ownership stages: room-bound acquisition, then inventory-bound packing after confirmed pickup.
- Missing room settlement gets one refresh attempt, not an unbounded timer or command loop.
- Movement is generation-based: one request per settled room, and stop/restart invalidates all callbacks from the prior generation.
- `boop walk move` is not an escape hatch. It follows the same safety gate and keeps the active walk mode unchanged.
- Stop output must say whether boop stopped its own walker run or detached from an independently owned run.

</specifics>

<deferred>
## Deferred Ideas

- Verify the successful Infernal hyena maul compact summary during Phase 05 fixture expansion.

### Reviewed Todos (not folded)
- **Add temporary prefixes and custom attacks** - New command capability belongs after Phase 04 establishes command validation and trust boundaries.
- **Verify Infernal hyena maul summary** - Compact gag fixture work belongs in Phase 05, not Phase 03 timing and movement hardening.

</deferred>

---

*Phase: 03-Queue, Interrupt, Gold, and Autowalk Regression Coverage*
*Context gathered: 2026-07-25T22:51:37Z*
