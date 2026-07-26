# Phase 03: Queue, Interrupt, Gold, and Autowalk Regression Coverage - Research

**Researched:** 2026-07-25
**Domain:** Mudlet Lua timing safety, owned queue/loot lifecycles, GMCP room evidence, and optional autowalker integration
**Confidence:** MEDIUM

<user_constraints>
## User Constraints (from CONTEXT.md)

The following phase boundary, decisions, discretion, and deferred work are copied verbatim from `03-CONTEXT.md`.

### Phase Boundary

Phase 03 hardens boop Hunter's timing-sensitive queue, interrupt, gold, and
autowalk paths. It must ensure that each pending action owns an explicit hold,
releases only from trustworthy evidence, and cannot attack, loot, or move after
its room or ownership boundary becomes stale.

This phase covers regression tests and the narrow behavior repairs those tests
expose. It does not absorb route selection from `demonnicAutoWalker`, add broad
new hunting commands, validate arbitrary command fragments, or expand compact
combat summaries. Those remain assigned to later roadmap phases.

### Locked Decisions

#### Overlapping Holds
- **D-01:** Use per-system all-clear semantics. Each subsystem remains held until every blocker affecting that subsystem has cleared.
- **D-02:** Release boundaries are subsystem-specific. Clearing one subsystem must not release unrelated held work.
- **D-03:** Normal status shows the highest-priority blocker plus an additional-blocker count; trace and debug list every active blocker.
- **D-04:** Choose the primary blocker through a fixed safety priority so critical safety and missing-state blockers outrank workflow blockers.

#### Interrupt Release Timing
- **D-05:** Each interrupt waits for operation-specific completion evidence, such as its success signal, required prompt, confirmed room transition, or defined timeout fallback.
- **D-06:** Timeout recovery cancels only the interrupt's owned intent, releases only its hold, emits warning and trace output, and preserves every unrelated blocker.
- **D-07:** Repeating an interrupt while it is pending is idempotent. Do not resend or restart it; report that the original request is still awaiting completion.
- **D-08:** The first terminal signal wins when timeout and success or prompt callbacks race. Release exactly once and make every later callback a no-op.

#### Gold Room Ownership
- **D-09:** Gold detection, pickup, and pickup retries belong to the exact originating room ID. A room change invalidates that room-bound intent.
- **D-10:** After confirmed pickup, packing becomes inventory-owned and may complete or retry across room changes.
- **D-11:** Duplicate gold signals in the same room coalesce into one pickup lifecycle without sending or queueing another `get sovereigns`.
- **D-12:** If the room ID is missing or unsettled, defer pickup and require a stable room ID plus current room-item evidence that the gold is still present.

#### Autowalk Movement Safety
- **D-13:** Emit `demonwalker.move` only from a complete all-clear snapshot: the room is settled, no valid target remains, all walk-affecting blockers are clear, no loot, interrupt, pull, or flee work is pending, and no move is already queued.
- **D-14:** A settled room requires `Room.Info` and the complete room-items list for the same room. Prompts may support settlement but cannot replace missing room data.
- **D-15:** Missing settlement evidence triggers one capped room-refresh recovery while movement remains held. If evidence still does not arrive, emit warning and trace output without moving.
- **D-16:** Each settled room may produce at most one movement request. Re-arm only after a confirmed new room ID and a new arrival or settlement cycle; duplicate same-room callbacks are ignored.

#### Manual Move Semantics
- **D-17:** `boop walk move` is a safe one-step request and obeys the same settlement and all-clear gate as automatic movement.
- **D-18:** A blocked manual move shows the primary reason, confirms no move was queued, and leaves movement state unchanged; full blocker detail remains in trace and debug.
- **D-19:** Repeating `boop walk move` while a move is pending is idempotent and does not alter ownership, timers, or the queued request.
- **D-20:** A successful manual move keeps walk mode active. Normal automatic evaluation resumes after the next arrival and settlement cycle.

#### Walker Stop Ownership
- **D-21:** `boop walk stop` is ownership-aware. Stop the underlying run when boop started it; when boop only attached, detach boop and leave the external run under its original owner's control.
- **D-22:** Stop immediately invalidates boop's queued move before stopping or detaching. Late timers and callbacks from the stopped generation are no-ops.
- **D-23:** Restarting creates a fresh movement generation. Do not reuse prior room, settlement, blocker, or queued-move observations; require current-room GMCP before advancing.
- **D-24:** Stop confirmation states the ownership outcome: distinguish a stopped boop-owned walk from boop detaching while the external walker remains running.

### the agent's Discretion
- Choose stable reason codes, blocker priorities within the user-selected safety ordering, and compact output wording consistent with existing status and trace surfaces.
- Choose bounded timeout values and the least noisy room-refresh mechanism. Recovery must remain capped and fail closed.
- Choose the external walker adapter calls needed to stop a boop-owned run after confirming the installed `demonnicAutoWalker` API.
- Choose test organization and helper extraction, provided timing, stale callback, room ownership, and command-order assertions remain explicit.
- If the external walker becomes unavailable mid-run, fail closed, invalidate boop-owned movement intent, and report the condition without attempting silent installation or update.

### Deferred Ideas (OUT OF SCOPE)

- Verify the successful Infernal hyena maul compact summary during Phase 05 fixture expansion.

#### Reviewed Todos (not folded)
- **Add temporary prefixes and custom attacks** - New command capability belongs after Phase 04 establishes command validation and trust boundaries.
- **Verify Infernal hyena maul summary** - Compact gag fixture work belongs in Phase 05, not Phase 03 timing and movement hardening.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| SAFE-02 | `diag`, queued interrupts, `pull`, and manual hold flows prevent automatic attacks until their prompt, room, timeout, or existing operator release conditions are satisfied. | Replace the single interrupt boolean/timer with an owned operation record and generation; make pull an explicit runtime blocker rather than a persisted `enabled` toggle; treat existing `boop off`/disabled state and manual-targeting mode as the manual holds; exercise zero attack/prequeue side effects plus explicit `boop on` and non-manual-targeting release transitions. [VERIFIED: codebase inspection `.planning/REQUIREMENTS.md:26`, `src/scripts/boop/boop_ui.lua:1248`, `src/scripts/boop/boop_ui.lua:1606`] |
| SAFE-04 | Gold pickup, pack/stash, retry, warning, and stale-pending behavior cannot send commands in the wrong room or bypass active safety holds. | Introduce a room-bound acquisition phase and a post-success inventory-bound packing phase; gate every initial send, retry, and timeout callback by generation, room, room evidence, and blocker all-clear. [VERIFIED: codebase inspection `.planning/REQUIREMENTS.md:28`, `src/scripts/boop/boop_events.lua:415`, `src/scripts/boop/boop_events.lua:462`, `src/scripts/boop/boop_events.lua:908`] |
| WALK-01 | `boop walk` tests cover start, stop, move, room-settled behavior, blocker reasons, and external `demonwalker.move` event emission. | Expand the current blocker-only walk spec into lifecycle, ownership, settlement, stale-callback, event, status, install, and failure tests using captured Mudlet callbacks. [VERIFIED: codebase inspection `.planning/REQUIREMENTS.md:32`, `tests/boop_walk_spec.lua:3`] |
| WALK-02 | Walker advancement is blocked while target, gold, diag, flee, pull, leader-call, or room-settling state says the room is not safe to leave. | Route automatic and manual movement through one side-effect-free all-clear evaluation and one generation-guarded emission function. [VERIFIED: codebase inspection `.planning/REQUIREMENTS.md:33`, `src/scripts/boop/boop_walk.lua:131`] |
| WALK-03 | `demonnicAutoWalker` remains an optional external integration with explicit install/status feedback and no silent auto-update behavior. | Keep route ownership external; test missing/available/install-failure/status states, explicit install only, ownership-aware stop, and fail-closed disappearance without any update call. [VERIFIED: codebase inspection `.planning/REQUIREMENTS.md:34`, `src/scripts/boop/boop_walk.lua:189`] [CITED: https://github.com/demonnic/demonnicAutoWalker] |
</phase_requirements>

## Summary

Phase 03 is not primarily a coverage-only phase: the tests will expose four structural timing defects that need narrow repairs. The runtime currently stores one `combat.blocker`; `setBlocker()` overwrites it, `clearBlocker()` clears it wholesale, and `shouldHold()` consults only that one object. That model cannot implement per-system all-clear or preserve an unrelated blocker after one operation completes. [VERIFIED: codebase inspection `src/scripts/boop/boop_runtime.lua:34`, `src/scripts/boop/boop_runtime.lua:281`, `src/scripts/boop/boop_runtime.lua:330`, `src/scripts/boop/boop_runtime.lua:370`, `src/scripts/boop/boop_runtime.lua:388`]

Interrupt, pull, gold, and walk timers also have no operation generation. A killed timer can already have fired, and Mudlet explicitly reports `killTimer()` failure when a timer no longer exists, so timer cancellation alone cannot prove that a callback still owns current state. [VERIFIED: codebase inspection `src/scripts/boop/boop_ui.lua:1261`, `src/scripts/boop/boop_ui.lua:1412`, `src/scripts/boop/boop_events.lua:443`, `src/scripts/boop/boop_walk.lua:345`] [CITED: https://wiki.mudlet.org/w/Manual%3ALua_Functions#killTimer]

Gold is presently marked as pickup- and pack-pending before either command succeeds, and both commands can be queued back-to-back or embedded ahead of an attack. A room transition then clears both phases. The safe design must instead queue only acquisition, wait for confirmed pickup, then create an inventory-owned packing phase that survives room changes; automatic combat must remain held until the gold lifecycle reaches a terminal state. [VERIFIED: codebase inspection `src/scripts/boop/boop_events.lua:462`, `src/scripts/boop/boop_events.lua:473`, `src/scripts/boop/boop_events.lua:937`, `src/scripts/boop/boop_util.lua:198`]

Walk settlement currently becomes true from a 0.2-second timer without a complete item list, and manual move forces `roomSettled = true` before evaluating blockers. The move callback only checks `active`, so a stop/restart can allow an old callback to emit in a fresh run. Replace those paths with shared room-observation evidence and a walk generation/room-cycle token. [VERIFIED: codebase inspection `src/scripts/boop/boop_walk.lua:90`, `src/scripts/boop/boop_walk.lua:335`, `src/scripts/boop/boop_walk.lua:357`]

**Primary recommendation:** Plan four ordered implementation seams—owner-keyed blockers, generation-owned interrupt/pull operations, shared room evidence with two-stage gold ownership, and a single generation-guarded walker emission path—then validate their cross-products with explicit callback ordering tests. [VERIFIED: phase decisions `03-CONTEXT.md` D-01 through D-24]

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Blocker ownership and per-system all-clear | Client runtime coordinator | UI/status | Runtime dispatch owns whether automation may act; UI renders the computed primary blocker and count. [VERIFIED: codebase inspection `src/scripts/boop/boop_runtime.lua:388`, `src/scripts/boop/boop_ui.lua:385`] |
| Interrupt and pull lifecycle | Client operation state | Achaea command/prompt/room boundary | boop owns operation generation and release; Achaea supplies prompt, output, room, and timeout evidence. [VERIFIED: codebase inspection `src/scripts/boop/boop_ui.lua:1248`, `src/scripts/boop/boop_events.lua:688`, `src/scripts/boop/boop_events.lua:908`] |
| Room observation and settlement | Client GMCP event adapter | Achaea GMCP service | `Room.Info` supplies the room ID and `Char.Items.List` supplies a complete location list; the latter has no room-ID field, so boop must bind events to its current room cycle. [VERIFIED: codebase inspection `src/scripts/boop/boop_events.lua:742`, `src/scripts/boop/boop_events.lua:908`] [CITED: https://nexus.ironrealms.com/GMCP] |
| Gold acquisition and packing | Client gold domain | Achaea command/GMCP/text boundary | Acquisition is room-owned; only confirmed acquisition transfers ownership to inventory packing. [VERIFIED: phase decisions `03-CONTEXT.md` D-09 through D-12] |
| Walk all-clear and one-move-per-room | Client walker adapter | External `demonnicAutoWalker` | boop owns safety and event emission; the external package owns route choice and movement. [VERIFIED: codebase inspection `src/scripts/boop/boop_walk.lua:335`] [CITED: https://github.com/demonnic/demonnicAutoWalker] |
| Regression harness | Mudlet/Busted test tier | GitHub Actions | Tests stub Mudlet boundaries and run inside a real Mudlet profile in CI. [VERIFIED: codebase inspection `tests/boop_interrupt_spec.lua:24`, `.github/workflows/main.yml:109`, `.github/workflows/main.yml:213`] |

## Project Constraints (from AGENTS.md)

- Read `README.md`, `DESIGN.md`, and `CODEX.md`; read `UIDESIGN.md` when UI/UX work is involved. All were inspected because blocker/status wording is part of this phase. [VERIFIED: codebase inspection `AGENTS.md`, `UIDESIGN.md`]
- On every future commit or push, synchronize `mfile.version`, `mfile.title` as `boop Hunter <version>`, and `src/scripts/boop/boop_init.lua` `boop.version`; the current three values are `0.1.393`. [VERIFIED: codebase inspection `AGENTS.md`, `mfile:3`, `mfile:5`, `src/scripts/boop/boop_init.lua:3`]
- Package-content edits belong under `src/`; built artifacts must not be edited. [VERIFIED: codebase inspection `AGENTS.md`, `CODEX.md:12`]
- User-facing documentation and help must stay synchronized with command-surface or behavior wording changes. [VERIFIED: codebase inspection `AGENTS.md`, `CODEX.md:58`, `CODEX.md:73`]
- Blocker wording must stay stable as `code -- label`; status/dashboard/config/party/debug should read the canonical snapshot, keep systems/waits compact, and retain deterministic plain-text output for tests. [VERIFIED: codebase inspection `UIDESIGN.md`]
- Prefer polish, operator clarity, consistency, and stability over feature expansion. [VERIFIED: codebase inspection `AGENTS.md`, `CODEX.md:70`]
- For this research request, write only under `.planning`, do not edit package code or built artifacts, and do not commit or push. [VERIFIED: user instruction]

## Current Implementation Findings

### Blocker Aggregation

- `DOMAIN_DEFAULTS.combat` contains one `blocker` record rather than an owner-keyed collection. [VERIFIED: codebase inspection `src/scripts/boop/boop_runtime.lua:19`]
- `setBlocker()` mutates that one record, so a second blocker replaces the first. [VERIFIED: codebase inspection `src/scripts/boop/boop_runtime.lua:330`]
- `clearBlocker()` accepts a reason-like value but clears the entire record without checking operation ownership. [VERIFIED: codebase inspection `src/scripts/boop/boop_runtime.lua:370`]
- Generic prompt-plus-GMCP observation can clear whichever single blocker happens to be stored, rather than only the blocker that requested that evidence. [VERIFIED: codebase inspection `src/scripts/boop/boop_runtime.lua:397`, `src/scripts/boop/boop_runtime.lua:411`, `src/scripts/boop/boop_runtime.lua:423`]
- UI status first renders the canonical blocker, then falls back through ad hoc diag, flee, gold, leader, walk, target, and room states; this cannot show a deterministic primary plus count until all active holds are collected through one snapshot API. [VERIFIED: codebase inspection `src/scripts/boop/boop_ui.lua:385`]

### Interrupt and Pull Ordering

- `queueInterrupt()` overwrites the active diag label and timer on every call, resends the command, and has no operation ID; it therefore fails the repeat-idempotency and stale-callback contracts. [VERIFIED: codebase inspection `src/scripts/boop/boop_ui.lua:1248`]
- Prompt completion clears the entire diag hold and timer with no generation comparison. [VERIFIED: codebase inspection `src/scripts/boop/boop_runtime.lua:809`, `src/scripts/boop/boop_runtime.lua:870`]
- `diag` has distinct line-then-prompt evidence, while the other current queued interrupts use prompt evidence; pull uses outbound/return room transitions and a timeout. Preserve those existing operator-facing completion contracts while adding ownership. [VERIFIED: codebase inspection `src/scripts/boop/boop_ui.lua:1289`, `src/scripts/boop/boop_events.lua:688`, `README.md:99`]
- Pull currently calls `setEnabled(false)` and later `setEnabled(true)`. `setEnabled()` persists the enabled setting, so a temporary pull lifecycle mutates saved operator configuration rather than only owning a runtime hold. [VERIFIED: codebase inspection `src/scripts/boop/boop_ui.lua:1043`, `src/scripts/boop/boop_ui.lua:1606`]
- Repeat pull is already no-send/idempotent at the command boundary, but its timeout callback identifies only “some active pull,” so a stale callback can act on a newer pull. [VERIFIED: codebase inspection `src/scripts/boop/boop_ui.lua:1412`, `src/scripts/boop/boop_ui.lua:1582`]
- Achaea offers `QUEUE REMOVE <index>` but no stable queue-entry handle; `ADDCLEARFULL` clears all queues and inserts at the beginning. Do not add index-based timeout removal because the index can later identify unrelated operator work. [CITED: https://www.achaea.com/game-help?what=queueing]

### Gold Ownership

- `markGoldQueueIntent()` marks both get and put pending before pickup succeeds, and `queueGoldCommands()` immediately queues both. [VERIFIED: codebase inspection `src/scripts/boop/boop_events.lua:462`, `src/scripts/boop/boop_events.lua:473`]
- Queueing mode can place `get sovereigns`, `put sovereigns`, and the next attack in one `BOOP_ATTACK` payload. That ordering cannot prove pickup before pack and cannot keep combat held while loot owns the next action. [VERIFIED: codebase inspection `src/scripts/boop/boop_util.lua:198`]
- Gold lifecycle state has no origin room, generation, phase, or terminal marker. [VERIFIED: codebase inspection `src/scripts/boop/boop_runtime.lua:69`]
- Room change calls `clearGoldQueueIntent()`, which clears both acquisition and packing even after pickup success would have made packing inventory-owned. [VERIFIED: codebase inspection `src/scripts/boop/boop_events.lua:415`, `src/scripts/boop/boop_events.lua:937`]
- A room-item remove event clears both pending phases before a later success trigger can transfer to packing; the safe behavior is to keep the current acquisition generation pending until success, explicit failure, room invalidation, or timeout decides it. [VERIFIED: codebase inspection `src/scripts/boop/boop_events.lua:791`, `src/scripts/boop/boop_events.lua:639`]
- Initial pickup, get retry, put retry, and stale timeout paths recheck pending booleans but do not recheck operation generation or room ownership. [VERIFIED: codebase inspection `src/scripts/boop/boop_events.lua:443`, `src/scripts/boop/boop_events.lua:597`, `src/scripts/boop/boop_events.lua:616`]

### Walk Lifecycle

- `blockedReason()` already covers external availability, active state, boop enabled, manual targeting, settlement, queued move, leader call, runtime blocker, pull, diag, flee, loot, selected target, and valid room target. Reuse that behavioral inventory, but compute it from one immutable evaluation snapshot. [VERIFIED: codebase inspection `src/scripts/boop/boop_walk.lua:131`]
- Arrival fallback marks the room settled after 0.2 seconds even when no room-item list arrived, which conflicts with the locked same-room evidence requirement. [VERIFIED: codebase inspection `src/scripts/boop/boop_walk.lua:90`]
- `onRoomItemsList()` marks walk settled after any complete room list while walk is unblocked, but it does not bind that list to a room-observation generation. [VERIFIED: codebase inspection `src/scripts/boop/boop_events.lua:742`]
- The manual move path writes `roomSettled = true` before calling the gate, so it is currently an escape hatch around missing settlement. [VERIFIED: codebase inspection `src/scripts/boop/boop_walk.lua:357`]
- The deferred move callback checks only `active`; stopping and restarting before an old callback runs can let that callback emit in the new run. [VERIFIED: codebase inspection `src/scripts/boop/boop_walk.lua:335`]
- `stop()` only resets boop flags and never invokes the external stop API. The upstream package documents `raiseEvent("demonwalker.stop")` as its public stop operation. [VERIFIED: codebase inspection `src/scripts/boop/boop_walk.lua:291`] [CITED: https://github.com/demonnic/demonnicAutoWalker]
- The upstream package exposes `demonwalker.enabled`, registers `demonwalker.move` and `demonwalker.stop`, and raises `demonwalker.finished`; the current boop availability/attachment checks use real upstream state. [CITED: https://github.com/demonnic/demonnicAutoWalker]
- `install()` catches thrown errors but ignores a false or nil-plus-error return from `installPackage()`. Mudlet 4.20 returns true on success and nil plus an error on failure, so tests must cover return-value failure as well as thrown failure. [VERIFIED: codebase inspection `src/scripts/boop/boop_walk.lua:189`] [CITED: https://wiki.mudlet.org/w/Manual%3AMiscellaneous_Functions#installPackage]

## Standard Stack

### Core

| Library / Runtime | Version | Purpose | Why Standard |
|-------------------|---------|---------|--------------|
| Mudlet | 4.20.1 in CI | Executes the package, GMCP events, timers, package install, command sends, and custom events | Keep the repository-pinned runtime; do not introduce a second scheduler or event layer. [VERIFIED: codebase inspection `.github/workflows/main.yml:15`] |
| Lua | 5.1 compatibility in CI | Package implementation language | The authoritative CI profile intentionally uses Lua 5.1.5; new code must avoid host-Lua-only features. [VERIFIED: codebase inspection `CODEX.md:46`] |
| Muddler | Existing project CLI/action | Builds `src/` into the Mudlet package consumed by tests | Preserve the established source/manifests/build path. [VERIFIED: codebase inspection `CODEX.md:12`, `.github/workflows/main.yml:32`] |
| Busted + luassert | 2.3.0 on the host; CI resolves Busted through LuaRocks | Behavior specs, stubs, spies, and assertions | Existing specs already capture timer callbacks and stub Mudlet globals; extend that pattern. [VERIFIED: environment probe] [VERIFIED: codebase inspection `tests/boop_interrupt_spec.lua:24`, `.github/workflows/main.yml:74`] [CITED: https://lunarmodules.github.io/busted/] |

### Supporting APIs

| API / Integration | Version | Purpose | When to Use |
|-------------------|---------|---------|-------------|
| Mudlet `tempTimer` / `killTimer` | Mudlet 4.20.1 | Bounded fallback scheduling and best-effort timer cancellation | Use with generation and terminal checks; never treat timer cancellation as ownership proof. [CITED: https://wiki.mudlet.org/w/Manual%3ALua_Functions#tempTimer] |
| Mudlet `raiseEvent` / anonymous handlers | Mudlet 4.20.1 | External walker event integration | Emit only from the one guarded walk effect; retain registered arrival/finished handlers. [CITED: https://wiki.mudlet.org/w/Manual%3ALua_Functions#raiseEvent] [CITED: https://wiki.mudlet.org/w/Manual%3AMiscellaneous_Functions#registerAnonymousEventHandler] |
| IRE GMCP `Room.Info`, `Char.Items.Room`, `Char.Items.List` | Current IRE protocol docs | Room identity, one capped refresh, and complete room-item evidence | Use `sendGMCP([[Char.Items.Room]])` once when a room cycle lacks item-list evidence. [CITED: https://nexus.ironrealms.com/GMCP] |
| `demonnicAutoWalker` | Existing external package; inspected upstream commit `44c78f1` dated 2024-04-11 | Route selection and physical autowalk | Keep optional and external; boop owns only start/attach/stop safety and move-event timing. [CITED: https://github.com/demonnic/demonnicAutoWalker] |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Owner-keyed blocker registry | Keep one blocker and add special-case booleans | Reject: it cannot preserve overlapping per-system holds or render all active blockers. [VERIFIED: phase decisions `03-CONTEXT.md` D-01 through D-04] |
| Operation generations | Depend on `killTimer()` | Reject: Mudlet returns false after a timer has fired, and callbacks need an independent current-owner check. [CITED: https://wiki.mudlet.org/w/Manual%3ALua_Functions#killTimer] |
| Shared room-observation record | Let walk and gold maintain separate settlement booleans | Reject: duplicate room truth would recreate ordering disagreements between loot and movement. [VERIFIED: codebase inspection `src/scripts/boop/boop_events.lua:742`, `src/scripts/boop/boop_walk.lua:90`] |
| Explicit external adapter | Absorb route planning into boop | Reject: route selection is explicitly out of scope and belongs to `demonnicAutoWalker`. [VERIFIED: phase boundary `03-CONTEXT.md`] |

**Installation:** No new development dependency or package-manager install is required. Preserve the existing, explicit operator action `boop walk install`; do not call it during tests or startup. [VERIFIED: codebase inspection `src/scripts/boop/boop_walk.lua:189`, `README.md:27`]

## Package Legitimacy Audit

No npm, PyPI, crates.io, LuaRocks, or other new implementation package is recommended, so the package-legitimacy seam is not applicable to this phase. [VERIFIED: research recommendation]

| Package | Registry | Age / Activity | Downloads | Source Repo | Verdict | Disposition |
|---------|----------|----------------|-----------|-------------|---------|-------------|
| `demonnicAutoWalker` | GitHub Releases / Mudlet package | Existing upstream; inspected latest cloned commit dated 2024-04-11 | Not used as a legitimacy signal | `github.com/demonnic/demonnicAutoWalker` | Existing official integration; non-registry gate | Approved only as the already-selected optional runtime integration; never install or update silently. [CITED: https://github.com/demonnic/demonnicAutoWalker] |

**Packages removed due to SLOP verdict:** none. No candidate package was introduced. [VERIFIED: research scope]

**Packages flagged as suspicious:** none. [VERIFIED: research scope]

## Architecture Patterns

### System Architecture Diagram

```text
Achaea output / Mudlet events
  text lines | prompt | Room.Info | Char.Items.List | demonwalker.arrived/finished
                                  |
                                  v
                    boop_events.lua adapters
                                  |
                  +---------------+----------------+
                  |                                |
                  v                                v
       shared room observation            owned operation records
       room ID + generation                interrupt / pull / gold / walk
       info seen + items seen              generation + phase + terminal
                  |                                |
                  +---------------+----------------+
                                  |
                                  v
                   owner-keyed blocker registry
                   any blocker affects subsystem?
                                  |
                        +---------+---------+
                        | yes               | no
                        v                   v
                hold + status/trace    immutable all-clear snapshot
                                            |
                         +------------------+------------------+
                         |                  |                  |
                         v                  v                  v
                   combat/queue        gold phase effect   walk effect
                   send / alias        queue get OR put    tempTimer(0)
                                                               |
                                               generation + room recheck
                                                               |
                                                               v
                                                raiseEvent("demonwalker.move")
                                                               |
                                                               v
                                                demonnicAutoWalker boundary
```

The diagram separates observed facts, operation ownership, authorization, and side effects. No callback should mutate or emit based only on a timer ID or a stale boolean. [VERIFIED: phase decisions `03-CONTEXT.md` D-01 through D-24]

### Recommended Project Structure

```text
src/scripts/boop/
├── boop_runtime.lua       # blocker registry, primary priority, room/operation snapshots
├── boop_events.lua        # GMCP sequencing, gold lifecycle, prompt/room transitions
├── boop_walk.lua          # external adapter, walk generation, single move emitter
├── boop_ui.lua            # interrupt/pull commands and compact status wording
├── boop_util.lua          # remove gold/attack command chaining
└── boop_ui_registry.lua   # help wording only if behavior text changes
tests/
├── support/boop_test_helper.lua
├── boop_runtime_spec.lua
├── boop_interrupt_spec.lua
├── boop_diag_spec.lua
├── boop_diag_timeout_spec.lua
├── boop_pull_spec.lua
├── boop_gold_spec.lua
├── boop_gold_retry_spec.lua
├── boop_walk_spec.lua
├── boop_event_transitions_spec.lua
├── boop_prequeue_spec.lua
└── boop_tick_spec.lua
```

Use existing files rather than adding a new framework or domain module. The high-conflict implementation files are `boop_runtime.lua`, `boop_events.lua`, `boop_walk.lua`, and `boop_ui.lua`; plans that edit the same file should be sequential rather than parallel. [VERIFIED: codebase inspection]

### Pattern 1: Owner-Keyed Blockers with Per-System Aggregation

**What:** Store blockers by stable owner, not by whichever blocker was most recently observed. `boop.runtime.shouldHold(system, exceptOwner)` returns true if any active blocker other than the optional exact owner key affects that system; omitting `exceptOwner` preserves the aggregate all-owner check. The exclusion is never by blocker code, code family, or subsystem. Status sorts all blockers by a fixed priority and exposes the first plus `count - 1`. [VERIFIED: phase decisions `03-CONTEXT.md` D-01 through D-04]

**Recommended owner forms:** `gmcp:ire`, `room:observation`, `interrupt:<generation>`, `pull:<generation>`, `gold:<generation>`, and `walk:<generation>`. These are recommended stable ownership keys, not current APIs. [VERIFIED: phase decisions `03-CONTEXT.md`]

**Recommended priority groups:** missing/partial GMCP and room state first; flee and away-from-origin recovery second; active pull third; interrupts fourth; gold acquisition/packing fifth; walk settlement/queued-move workflow last. Within a group, sort by stable code then owner so output does not depend on Lua table iteration. [VERIFIED: phase decision `03-CONTEXT.md` D-04]

### Pattern 2: Generation-Owned Operation with First-Terminal-Wins

**What:** Each asynchronous lifecycle has a monotonically increasing generation, phase, terminal flag, blocker owner, and timer IDs. Every callback captures the generation and delegates to one terminal function that returns false if the current record differs or already terminated. [VERIFIED: phase decisions `03-CONTEXT.md` D-05 through D-08, D-22 through D-23]

**When to use:** Interrupt timeout/prompt/success, pull timeout/room return, gold timeout/retry/success, settlement refresh, and queued walk emission. [VERIFIED: codebase inspection `src/scripts/boop/boop_ui.lua:1269`, `src/scripts/boop/boop_ui.lua:1412`, `src/scripts/boop/boop_events.lua:446`, `src/scripts/boop/boop_walk.lua:345`]

### Pattern 3: Shared Room Observation

**What:** Add one room-observation record under the existing room-owning `state.targeting` domain. Expose the exact contract as `boop.runtime.startRoomObservation(roomId)`, `boop.runtime.stampRoomItemsObservation()`, and `boop.runtime.roomObservationSnapshot()`, with the existing event boundary `boop.requestRoomItemsOnce(reason)`. A `Room.Info` transition starts or invalidates a generation and resets item evidence; only a complete `Char.Items.List` with `location == "room"` observed afterward stamps item evidence for that current generation. [VERIFIED: codebase inspection `src/scripts/boop/boop_runtime.lua:53`, `src/scripts/boop/boop_events.lua:742`, `src/scripts/boop/boop_events.lua:908`]

**Why there:** `state.targeting` already owns the current room and room denizens, while walk and gold are consumers. Putting shared room truth in `state.walk` or `state.gold` would invert ownership. [VERIFIED: codebase inspection `src/scripts/boop/boop_runtime.lua:53`]

**Protocol limitation:** `Char.Items.List` includes `location` and `items` but no room ID. Perfect payload-level correlation is unavailable; boop must invalidate the old observation on room transition and accept only a complete room list observed after the current `Room.Info` cycle began. [CITED: https://nexus.ironrealms.com/GMCP]

**Recovery:** Convert the existing arrival fallback from “assume settled” into “request `Char.Items.Room` once.” Keep movement held; if the post-refresh bounded check still lacks a complete list, warn and trace without moving. [VERIFIED: phase decisions `03-CONTEXT.md` D-14 through D-15] [CITED: https://nexus.ironrealms.com/GMCP]

### Pattern 4: Two-Stage Gold Ownership

**What:** Model gold as:

```text
provisional detection
  -> room evidence ready?
       no  -> deferred_room (no command; one shared room refresh)
       yes -> pickup_pending(roomId, roomGeneration, goldItemId?)
                  |
        +---------+----------+
        | room changed       | get confirmed
        v                    v
      canceled       pack_pending_inventory
                              |
                    success/failure/timeout
                              |
                           terminal
```

Queue only `get sovereigns` during `pickup_pending`. Queue `put sovereigns in <pack>` only after confirmed pickup transfers ownership to inventory. Do not prepend pickup/pack to an attack alias. [VERIFIED: phase decisions `03-CONTEXT.md` D-09 through D-12]

### Pattern 5: One Walk Evaluator and One Emitter

**What:** Both automatic advancement and `boop walk move` call the same pure evaluator. Only a successful result may reserve `moveIssuedForRoomGeneration`, mark `moveQueued`, and schedule the emitter. The emitter rechecks active generation, room generation, reservation, package availability, and all-clear before raising the event. [VERIFIED: phase decisions `03-CONTEXT.md` D-13 through D-20]

**Stop behavior:** Invalidate the boop generation and queued reservation first. If `owned == true`, raise `demonwalker.stop`; if attached, reset only boop state. Then report the distinct outcome. [VERIFIED: phase decisions `03-CONTEXT.md` D-21 through D-24] [CITED: https://github.com/demonnic/demonnicAutoWalker]

### Component Responsibilities

| Component | Keep | Change |
|-----------|------|--------|
| `boop_runtime.lua` | Domain initialization, coordinator step/effects, context creation | Replace one blocker with owner-keyed collection; expose sorted/all/primary snapshots; make automatic gates use aggregate holds; include room/operation generation details in context. [VERIFIED: codebase inspection `src/scripts/boop/boop_runtime.lua`] |
| `boop_events.lua` | GMCP registration, room/item handlers, prompt entry, existing gold success/failure triggers | Stamp room observations, cap refresh, stage gold ownership, generation-guard retries/timeouts, and clear only owning blockers. [VERIFIED: codebase inspection `src/scripts/boop/boop_events.lua`] |
| `boop_walk.lua` | Optional package boundary, start/attach concept, blocker inventory, custom-event integration | Delete timer-based settlement, add generation/room reservation, unify manual/automatic gate, recheck before emit, implement ownership-aware stop, and harden install return handling. [VERIFIED: codebase inspection `src/scripts/boop/boop_walk.lua`] |
| `boop_ui.lua` | Existing command routes and compact output helpers | Create idempotent interrupt records, make pull runtime-held without persisted enabled toggles, and render primary plus count. [VERIFIED: codebase inspection `src/scripts/boop/boop_ui.lua`] |
| `boop_util.lua` | Attack alias caching and queue dispatch | Remove gold/pack chaining from `BOOP_ATTACK`; do not send attack while gold blocker owns combat/queue. [VERIFIED: codebase inspection `src/scripts/boop/boop_util.lua:198`] |
| Tests/helper | Existing reset, GMCP fixture, Busted stubs | Add multi-callback capture, owner/generation seeders, room-cycle helpers, and external walker/install stubs. [VERIFIED: codebase inspection `tests/support/boop_test_helper.lua`, `tests/boop_interrupt_spec.lua:24`] |

### Anti-Patterns to Avoid

- **One “current blocker”:** A later blocker silently erases an earlier hold. Use owner-keyed aggregation. [VERIFIED: codebase inspection `src/scripts/boop/boop_runtime.lua:330`]
- **Clear by reason or code family:** Release by exact owner/generation; code labels are presentation, not identity. [VERIFIED: phase decision `03-CONTEXT.md` D-02]
- **Timer ID as ownership:** Cancel timers for hygiene, but callback generation/terminal checks enforce correctness. [CITED: https://wiki.mudlet.org/w/Manual%3ALua_Functions#killTimer]
- **Prompt means settled:** Prompt can support an operation but cannot substitute for current `Room.Info` plus complete room items. [VERIFIED: phase decision `03-CONTEXT.md` D-14]
- **Manual move writes safety state:** Manual move is a request, not evidence; it must never set settlement true. [VERIFIED: phase decision `03-CONTEXT.md` D-17]
- **Gold packed before confirmed get:** It conflates room and inventory ownership and fails under room-change ordering. [VERIFIED: phase decisions `03-CONTEXT.md` D-09 through D-10]
- **Mutable queue-index cancellation:** Achaea queue indices are not stable ownership handles. [CITED: https://www.achaea.com/game-help?what=queueing]
- **Silent optional-package recovery:** Missing external walker state must stop movement and report; never install or update automatically. [VERIFIED: phase decision `03-CONTEXT.md` Agent Discretion]

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Route selection/pathfinding | A boop route planner | Existing `demonnicAutoWalker` | The external package owns room selection and mapper movement; the phase owns safety only. [CITED: https://github.com/demonnic/demonnicAutoWalker] |
| Room-item refresh | Repeated `look` commands or an unbounded polling loop | One `sendGMCP([[Char.Items.Room]])` request per room cycle | IRE documents this request and its complete `Char.Items.List` response. [CITED: https://nexus.ironrealms.com/GMCP] |
| Timer/mock framework | Custom scheduler or assertion library | Existing Busted/luassert stubs plus captured callbacks | The repository already uses this pattern and official Busted stubs preserve call history. [VERIFIED: codebase inspection `tests/boop_interrupt_spec.lua:24`] [CITED: https://lunarmodules.github.io/busted/] |
| External walker update system | Background release checks or startup updates | Explicit existing install/status path; upstream `dwalk update` remains operator-owned | WALK-03 forbids silent update behavior. [VERIFIED: requirement `WALK-03`] [CITED: https://github.com/demonnic/demonnicAutoWalker] |
| Selective Achaea queue identity | Guessing that index 1 is still boop's command | Local operation ownership and safe next-dispatch replacement; no index mutation | Official queue help exposes mutable indices, not stable IDs. [CITED: https://www.achaea.com/game-help?what=queueing] |

**Key insight:** Safety comes from proving that a callback still owns the current operation and room cycle immediately before a side effect, not from adding more cleanup calls after stale work has already escaped. [VERIFIED: phase decisions `03-CONTEXT.md` D-01 through D-24]

## Common Pitfalls

### Pitfall 1: Clearing the Wrong Overlapping Hold

**What goes wrong:** A prompt or GMCP event releases a workflow while a missing-room, flee, or pull-away blocker still affects the same subsystem. [VERIFIED: codebase inspection `src/scripts/boop/boop_runtime.lua:397`]

**Why it happens:** The current runtime stores only one blocker and generic observation flags. [VERIFIED: codebase inspection `src/scripts/boop/boop_runtime.lua:34`]

**How to avoid:** Clear exact owners and recompute all-clear per subsystem after every transition. [VERIFIED: phase decisions `03-CONTEXT.md` D-01 through D-04]

**Warning signs:** A test clears one blocker and `shouldHold("combat")` becomes false despite another combat blocker still being present. [VERIFIED: phase decision `03-CONTEXT.md` D-01]

### Pitfall 2: Success/Timeout Double Release

**What goes wrong:** Timeout clears a newer operation or both timeout and success emit resume output and trigger an attack. [VERIFIED: codebase inspection `src/scripts/boop/boop_ui.lua:1269`, `src/scripts/boop/boop_ui.lua:1412`]

**Why it happens:** Timer callbacks test broad booleans rather than the captured operation generation. [VERIFIED: codebase inspection `src/scripts/boop/boop_ui.lua:1271`, `src/scripts/boop/boop_ui.lua:1413`]

**How to avoid:** One terminal function performs compare-and-complete; invoke callbacks in both orders in tests. [VERIFIED: phase decision `03-CONTEXT.md` D-08]

**Warning signs:** Two `[OK]`/`[WARN]` terminal messages, two ticks, or a stale callback that clears a newer label. [VERIFIED: phase decisions `03-CONTEXT.md` D-06 through D-08]

### Pitfall 3: Treating Pull as Saved Configuration

**What goes wrong:** A temporary pull persists boop disabled, produces stats/config side effects, or re-enables an operator-disabled session. [VERIFIED: codebase inspection `src/scripts/boop/boop_ui.lua:1043`, `src/scripts/boop/boop_ui.lua:1606`]

**Why it happens:** Pull uses `setEnabled()` as a hold mechanism. [VERIFIED: codebase inspection `src/scripts/boop/boop_ui.lua:1615`]

**How to avoid:** Keep `config.enabled` unchanged; own a pull blocker and generation instead. [VERIFIED: inherited decision `.planning/phases/02-state-ownership-repair-and-safety-baseline/02-CONTEXT.md` D-15] [VERIFIED: phase decision `03-CONTEXT.md` D-01]

**Warning signs:** `boop.db.saveConfig("enabled", ...)` appears in a pull test or pull completion calls `setEnabled(true)`. [VERIFIED: codebase inspection `src/scripts/boop/boop_ui.lua:1070`, `src/scripts/boop/boop_events.lua:988`]

### Pitfall 4: Misattributing a Room Item List

**What goes wrong:** A delayed list from the prior transition settles the current room and allows wrong-room pickup or movement. [VERIFIED: phase decisions `03-CONTEXT.md` D-09, D-14]

**Why it happens:** `Char.Items.List` has no room ID. [CITED: https://nexus.ironrealms.com/GMCP]

**How to avoid:** Reset observation on every new `Room.Info`, accept complete room lists only in the current cycle, invalidate all old generations, and use one explicit refresh when evidence is missing. [VERIFIED: phase decisions `03-CONTEXT.md` D-12 through D-15]

**Warning signs:** `roomSettled` becomes true from a timer, prompt, or list that occurred before the current room generation began. [VERIFIED: codebase inspection `src/scripts/boop/boop_walk.lua:90`]

### Pitfall 5: Clearing Inventory-Owned Packing on Room Change

**What goes wrong:** Pickup succeeds, the character moves, and room transition erases a valid pack retry or queues a wrong-room get retry. [VERIFIED: codebase inspection `src/scripts/boop/boop_events.lua:937`]

**Why it happens:** One clear function resets both acquisition and packing. [VERIFIED: codebase inspection `src/scripts/boop/boop_events.lua:415`]

**How to avoid:** Room transition cancels only provisional/acquisition phases; inventory packing remains generation-owned until terminal. [VERIFIED: phase decisions `03-CONTEXT.md` D-09 through D-10]

**Warning signs:** A room-change test expects `putPending == false` immediately after confirmed get. [VERIFIED: phase decision `03-CONTEXT.md` D-10]

### Pitfall 6: Stop/Restart Callback Leakage

**What goes wrong:** A timer scheduled by run N emits `demonwalker.move` after run N+1 starts. [VERIFIED: codebase inspection `src/scripts/boop/boop_walk.lua:345`]

**Why it happens:** The callback checks only `active`. [VERIFIED: codebase inspection `src/scripts/boop/boop_walk.lua:346`]

**How to avoid:** Stop increments/invalidate generation before any external event; emitter compares captured run and room generations. [VERIFIED: phase decisions `03-CONTEXT.md` D-22 through D-23]

**Warning signs:** Invoking a captured callback after stop/restart raises one event or changes `moveQueued`. [VERIFIED: phase decision `03-CONTEXT.md` D-22]

### Pitfall 7: Incorrect Install Success

**What goes wrong:** Status says installation was requested successfully when `installPackage()` returned a failure tuple without throwing. [VERIFIED: codebase inspection `src/scripts/boop/boop_walk.lua:207`]

**Why it happens:** `pcall()` success is confused with installation success. [CITED: https://wiki.mudlet.org/w/Manual%3AMiscellaneous_Functions#installPackage]

**How to avoid:** Distinguish thrown errors, false/nil-plus-error returns, and success; keep install explicitly user-triggered. [CITED: https://wiki.mudlet.org/w/Manual%3AMiscellaneous_Functions#installPackage]

**Warning signs:** A stub returning `nil, "failure"` still causes `[OK] install requested`. [VERIFIED: codebase inspection `src/scripts/boop/boop_walk.lua:216`]

## Code Examples

These are implementation sketches derived from locked decisions and official APIs; they are not current repository code.

### First-Terminal-Wins Operation

```lua
-- Sources:
-- 03-CONTEXT.md D-06 through D-08
-- https://wiki.mudlet.org/w/Manual:Lua_Functions#killTimer
local function finishInterrupt(generation, terminalReason)
  local op = boop.runtime.state().diag.operation
  if type(op) ~= "table"
      or op.generation ~= generation
      or op.terminal then
    return false
  end

  op.terminal = true
  if op.timeoutTimer and killTimer then
    killTimer(op.timeoutTimer)
  end
  op.timeoutTimer = nil
  boop.runtime.clearBlocker(op.blockerOwner, terminalReason)
  boop.runtime.state().diag.operation = nil
  return true
end
```

### Aggregate Hold Check

```lua
-- Source: 03-CONTEXT.md D-01 through D-04
function boop.runtime.shouldHold(system, exceptOwner)
  local key = normalizeKey(system)
  for owner, blocker in pairs(boop.runtime.state().combat.blockersByOwner or {}) do
    if owner ~= exceptOwner
        and blocker.systems
        and blocker.systems[key] == true then
      return true
    end
  end
  return false
end
```

### Capped Room Refresh

```lua
-- Sources:
-- 03-CONTEXT.md D-14 through D-15
-- https://nexus.ironrealms.com/GMCP
local function requestRoomItemsOnce(observation, reason)
  if observation.itemsSeen or observation.refreshAttempted then
    return false
  end
  observation.refreshAttempted = true
  observation.refreshReason = reason
  if sendGMCP then
    sendGMCP([[Char.Items.Room]])
  end
  return true
end
```

### Generation-Guarded Walker Emission

```lua
-- Sources:
-- 03-CONTEXT.md D-13 through D-23
-- https://github.com/demonnic/demonnicAutoWalker
tempTimer(0, function()
  local live = boop.runtime.state().walk
  if not live.active
      or live.generation ~= runGeneration
      or live.moveIssuedForRoomGeneration ~= roomGeneration
      or not boop.walk.isAvailable() then
    return
  end

  local ok = boop.walk.evaluateAllClear(runGeneration, roomGeneration)
  if not ok then
    return
  end
  raiseEvent("demonwalker.move")
end)
```

### Ownership-Aware Stop

```lua
-- Sources:
-- 03-CONTEXT.md D-21 through D-24
-- https://github.com/demonnic/demonnicAutoWalker
local wasOwned = walk.owned == true
boop.walk.invalidateCurrentGeneration("operator stop")
if wasOwned and raiseEvent then
  raiseEvent("demonwalker.stop")
  boop.util.ok("walk stopped; boop-owned demonwalker run ended")
else
  boop.util.ok("walk detached; external demonwalker run left active")
end
```

### Busted Race Test

```lua
-- Sources:
-- Existing repository pattern: tests/boop_interrupt_spec.lua
-- https://lunarmodules.github.io/busted/
boop.ui.matic()
local oldTimeout = scheduled[1]
boop.onPrompt()
oldTimeout()

assert.is_nil(boop.state.diag.operation)
assert.stub(warn_stub).was_not_called()
assert.are.equal(1, terminal_message_count())
```

## State of the Art

| Old / Current Approach | Required Approach | When Changed | Impact |
|------------------------|-------------------|--------------|--------|
| One mutable blocker | Owner-keyed blocker set with deterministic priority and per-system aggregate | Phase 03 locked decision | Makes overlapping safety holds independently releasable. [VERIFIED: phase decisions `03-CONTEXT.md` D-01 through D-04] |
| Timer cancellation plus broad boolean | Generation plus terminal compare; timer kill is cleanup only | Phase 03 locked decision | Prevents stale callbacks from releasing or emitting newer work. [VERIFIED: phase decision `03-CONTEXT.md` D-08] |
| `get` + `put` + attack chained before confirmation | Room-owned get, then inventory-owned put, then combat reevaluation | Phase 03 locked decision | Preserves room correctness and command ordering. [VERIFIED: phase decisions `03-CONTEXT.md` D-09 through D-12] |
| 0.2-second settlement assumption | Same-cycle `Room.Info` plus complete room list, one refresh, fail closed | Phase 03 locked decision | Prevents movement from outrunning GMCP evidence. [VERIFIED: phase decisions `03-CONTEXT.md` D-14 through D-16] |
| Stop only resets boop flags | Invalidate generation, stop owned external run or detach from attached run | Phase 03 locked decision | Prevents stale movement and respects external ownership. [VERIFIED: phase decisions `03-CONTEXT.md` D-21 through D-24] |

**Deprecated/outdated within this phase:**

- Direct automatic gates on `state.diag.hold` are outdated once interrupts own blockers; retain detail fields only if needed for display compatibility. [VERIFIED: codebase inspection `src/scripts/boop/boop_runtime.lua:723`, `src/scripts/boop/boop_events.lua:1159`]
- `armArrivalFallback()` setting `roomSettled = true` is incompatible with D-14. [VERIFIED: codebase inspection `src/scripts/boop/boop_walk.lua:90`]
- Gold-prefix construction in `boop.executeAction()` is incompatible with staged ownership. [VERIFIED: codebase inspection `src/scripts/boop/boop_util.lua:198`]
- Pull's temporary use of persisted `config.enabled` is incompatible with explicit runtime-hold ownership. [VERIFIED: codebase inspection `src/scripts/boop/boop_ui.lua:1606`]

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| — | None. Recommendations are derived from locked phase decisions, current source/tests, or cited official documentation. | — | — |

## Open Questions (RESOLVED)

1. **Timeout ownership and server-side queued work — resolved**
   - Resolution: D-06 timeout cancellation owns only boop's local interrupt operation, local intent, timer, and exact blocker owner. It sends no mutable-index removal and no queue-wide or queue-type removal because Achaea exposes no stable queue-entry handle. The next boop interrupt dispatch retains the existing `ADDCLEARFULL` replacement semantics. Tests must assert zero server-queue mutation at timeout and prove every unrelated blocker and queued operator action is preserved. [VERIFIED: phase decision `03-CONTEXT.md` D-06] [VERIFIED: codebase inspection `src/scripts/boop/boop_util.lua:239`] [CITED: https://www.achaea.com/game-help?what=queueing]

2. **Room-list correlation strength — resolved**
   - Resolution: Ordered observation is the strongest protocol correlation available. Every `Room.Info` transition calls `boop.runtime.startRoomObservation(roomId)` to start or invalidate a generation. Only a complete room `Char.Items.List` observed afterward may call `boop.runtime.stampRoomItemsObservation()` for that generation. `boop.requestRoomItemsOnce(reason)` performs one refresh request; prompts and timers never settle a room. Consumers read only `boop.runtime.roomObservationSnapshot()`. [VERIFIED: phase decisions `03-CONTEXT.md` D-14 through D-15] [CITED: https://nexus.ironrealms.com/GMCP]

3. **SAFE-02 manual-hold meaning — resolved**
   - Resolution: Manual holds are the existing operator-controlled `boop off`/disabled state and manual-targeting state. Tests must prove exact zero attack sends and zero prequeue scheduling/execution while either state is active, then prove resumption only after the existing `boop on` action or an existing transition from manual targeting to a non-manual targeting mode. Phase 03 adds no `boop hold` command or equivalent new command surface. [VERIFIED: codebase inspection `.planning/REQUIREMENTS.md:26`, `src/scripts/boop/boop_ui.lua:394`, `src/scripts/boop/boop_walk.lua:142`] [VERIFIED: phase boundary `03-CONTEXT.md`]

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|-------------|-----------|---------|----------|
| `muddle` | Package build before Mudlet tests | ✓ | CLI present at `/usr/local/bin/muddle`; no version text returned | Existing GitHub Muddler action. [VERIFIED: environment probe] |
| Python | Release gates | ✓ | 3.14.6 | None needed. [VERIFIED: environment probe] |
| Host Lua | Non-authoritative diagnostics only | ✓ | 5.5.0 | Do not use as behavioral authority; CI uses Lua 5.1.5. [VERIFIED: environment probe] [VERIFIED: codebase inspection `CODEX.md:46`] |
| Host Busted | Non-authoritative diagnostics only | ✓ | 2.3.0 | Use real-Mudlet CI/profile execution. [VERIFIED: environment probe] [VERIFIED: codebase inspection `CODEX.md:46`] |
| `/tmp/Mudlet.AppImage` | Local authoritative Busted run | ✗ | — | GitHub Actions is the documented authoritative fallback. [VERIFIED: environment probe] [VERIFIED: codebase inspection `CODEX.md:43`] |
| `demonnicAutoWalker` runtime global | Walk integration | Not applicable in workspace | Optional Mudlet package | Stub `demonwalker`, `raiseEvent`, and `installPackage` in tests; live validation remains optional-package aware. [VERIFIED: codebase inspection `tests/boop_walk_spec.lua:44`] |

**Missing dependencies with no fallback:** none for planning or code authoring. [VERIFIED: environment audit]

**Missing dependencies with fallback:** the local Mudlet AppImage is absent; use GitHub Actions for the authoritative full suite unless it is supplied locally. [VERIFIED: environment probe] [VERIFIED: codebase inspection `CODEX.md:45`]

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | Busted/luassert inside Mudlet 4.20.1 with Lua 5.1-compatible execution. [VERIFIED: codebase inspection `.github/workflows/main.yml:15`, `CODEX.md:46`] |
| Config file | `.github/workflows/main.yml`; CI clones the `demonnic/test-in-mudlet` `GithubTests` profile. [VERIFIED: codebase inspection `.github/workflows/main.yml:109`] [CITED: https://github.com/demonnic/test-in-mudlet] |
| Static quick run | `python3 tools/check_release_gates.py` — fast, but not a behavioral substitute. [VERIFIED: codebase inspection `CODEX.md:38`] |
| Focused behavior run | `muddle && AUTORUN_BUSTED_TESTS=true TESTS_DIRECTORY="$PWD/tests/boop_walk_spec.lua" QUIT_MUDLET_AFTER_TESTS=true PRETEST_PACKAGE="$PWD/build/boop Hunter.mpackage" /tmp/Mudlet.AppImage --profile "GithubTests" --mirror` — the profile accepts a file path, but the AppImage is currently missing locally. [CITED: https://github.com/demonnic/test-in-mudlet] [VERIFIED: environment probe] |
| Full suite command | `muddle && AUTORUN_BUSTED_TESTS=true TESTS_DIRECTORY="$PWD/tests" QUIT_MUDLET_AFTER_TESTS=true PRETEST_PACKAGE="$PWD/build/boop Hunter.mpackage" /tmp/Mudlet.AppImage --profile "GithubTests" --mirror` [VERIFIED: codebase inspection `CODEX.md:43`] |
| Authoritative fallback | GitHub Actions full Mudlet Busted job; the runner has a 20-minute timeout. [VERIFIED: codebase inspection `.github/workflows/main.yml:123`, `.github/workflows/main.yml:213`] |

The repository does not currently provide an authoritative sub-30-second behavioral command on this host because `/tmp/Mudlet.AppImage` is absent and host Lua 5.5/Busted must not be treated as equivalent to Mudlet Lua 5.1. The planner should preserve this distinction rather than marking the Python release gate as behavior coverage. [VERIFIED: environment probe] [VERIFIED: codebase inspection `CODEX.md:45`]

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| SAFE-02 | Multiple holds aggregate; interrupt/pull repeat is no-send; prompt/room/timeout releases only owner; success-timeout races terminate once; no attack/prequeue escapes. | Unit + integration | Focused Mudlet runs for `tests/boop_runtime_spec.lua`, `tests/boop_interrupt_spec.lua`, `tests/boop_diag_spec.lua`, `tests/boop_diag_timeout_spec.lua`, `tests/boop_pull_spec.lua`, `tests/boop_prequeue_spec.lua`, and `tests/boop_tick_spec.lua`, followed by full suite. | ✅ Existing files; ❌ Wave 0 cases missing. [VERIFIED: codebase inspection] |
| SAFE-04 | Gold is room-owned before get, inventory-owned after confirmation, duplicates coalesce, retries/timeouts are generation-safe, holds suppress sends, and attacks are not chained into loot. | Unit + integration | Focused Mudlet runs for `tests/boop_gold_spec.lua`, `tests/boop_gold_retry_spec.lua`, `tests/boop_event_transitions_spec.lua`, `tests/boop_prequeue_spec.lua`, and `tests/boop_tick_spec.lua`, followed by full suite. | ✅ Existing files; ❌ Wave 0 ownership/race cases missing. [VERIFIED: codebase inspection] |
| WALK-01 | Start owned vs attach, status, explicit install outcomes, stop/detach, manual move, room settle, event emission, and stale callbacks. | Unit + integration | Focused Mudlet run for `tests/boop_walk_spec.lua`, then full suite. | ✅ Existing file; ❌ lifecycle coverage missing. [VERIFIED: codebase inspection `tests/boop_walk_spec.lua:3`] |
| WALK-02 | Target, valid denizen, gold, diag, flee, pull, leader call, missing/partial room, incomplete items, runtime blocker, and queued move all hold automatic and manual movement. | Table-driven unit + event integration | Focused Mudlet runs for `tests/boop_walk_spec.lua` and `tests/boop_event_transitions_spec.lua`, then full suite. | ✅ Existing files; ❌ same-room/cross-blocker cases missing. [VERIFIED: codebase inspection] |
| WALK-03 | Missing package never silently installs; explicit install handles throw/return failure/success; mid-run disappearance fails closed; stop uses upstream event only for boop-owned runs; no update call. | Boundary unit | Focused Mudlet run for `tests/boop_walk_spec.lua`, then full suite. | ✅ Existing file; ❌ install/status/ownership cases missing. [VERIFIED: codebase inspection] |

### Required Ordering Matrix

Each row should become at least one explicit test where captured callbacks are invoked in the stated order. [VERIFIED: phase decisions `03-CONTEXT.md`]

| Lifecycle | Ordering A | Ordering B | Required invariant |
|-----------|------------|------------|--------------------|
| Interrupt | prompt/success then timeout | timeout then prompt/success | One terminal output, one release, unrelated blockers remain, late callback no-op. [VERIFIED: decision D-08] |
| Interrupt repeat | same command twice before terminal | different interrupt while one owns lane | No resend, no timer restart, original owner remains. [VERIFIED: decision D-07] |
| Pull | return room then timeout | timeout away then return | Pull owner releases only at valid boundary; stale timeout cannot clear later pull; saved enabled config unchanged. [VERIFIED: decisions D-06 through D-08] |
| Gold | room change before get success | get success before room change | First cancels room-owned acquisition; second preserves inventory-owned pack. [VERIFIED: decisions D-09 through D-10] |
| Gold evidence | text/Add before complete List | complete List with duplicate signals | No early command; exactly one get once evidence is current. [VERIFIED: decisions D-11 through D-12] |
| Gold timeout | old timeout after new gold generation | retry after room change | No current-state clear and no wrong-room send. [VERIFIED: decision D-09] |
| Walk | stop then queued callback | stop, restart, old callback | No event from old generation. [VERIFIED: decisions D-22 through D-23] |
| Walk settlement | prompt/timer without items | Room.Info + current complete List | First holds and refreshes once; second may evaluate all-clear once. [VERIFIED: decisions D-14 through D-16] |
| Walk duplicate | repeated arrived/List/manual move in same room | new Room.Info then settlement | At most one event in first cycle; one new reservation in second. [VERIFIED: decisions D-16, D-19] |
| External loss | package present at scheduling, absent at callback | attached run stopped from boop | Fail closed/no move/no install; detach without external stop. [VERIFIED: Agent Discretion, decisions D-21 through D-22] |

### Test Assertions That Must Be Explicit

- Assert exact `send()` and `raiseEvent()` call counts, not only final booleans. [VERIFIED: existing test pattern `tests/boop_interrupt_spec.lua:47`, `tests/boop_walk_spec.lua:22`]
- Assert no command was queued on blocked paths and that ownership, generation, timer IDs, and room observations remained unchanged. [VERIFIED: phase decisions D-07, D-18, D-19]
- Assert blocker lists and affected systems after one owner clears; normal status must show primary plus `+N more`, while trace/debug exposes all owners. [VERIFIED: phase decisions D-01 through D-04]
- Assert command order: get only, success, put only, pack terminal, then combat/walk reevaluation. [VERIFIED: phase decisions D-09 through D-13]
- Assert no `installPackage()` from status/start/move/mid-run failure and no update-related call anywhere. [VERIFIED: requirement WALK-03]
- Assert `raiseEvent("demonwalker.stop")` only for boop-owned stop and `raiseEvent("demonwalker.move")` only after the emitter's final recheck. [CITED: https://github.com/demonnic/demonnicAutoWalker]
- Preserve the existing target-removal queue-drift regression while adding walk/gold interleavings. [VERIFIED: codebase inspection `tests/boop_event_transitions_spec.lua:243`, `.planning/ROADMAP.md:91`]

### Sampling Rate

- **Per task:** Run `python3 tools/check_release_gates.py`; when the AppImage is available, run each changed focused spec by setting `TESTS_DIRECTORY` to that file. [VERIFIED: codebase inspection `CODEX.md:38`] [CITED: https://github.com/demonnic/test-in-mudlet]
- **Per wave merge:** Run the full Mudlet suite; if local Mudlet remains unavailable, push only during implementation when authorized and use the configured GitHub Actions job. [VERIFIED: codebase inspection `CODEX.md:43`]
- **Phase gate:** Full Mudlet/Busted suite green, release gates green, and focused live Mudlet validation for one interrupt, pull return/away timeout, gold pickup/pack, owned walk stop, attached walk detach, and one safe move. [VERIFIED: codebase inspection `CODEX.md:43`, `.planning/ROADMAP.md:77`]

### Wave 0 Gaps

- [ ] Extend `tests/support/boop_test_helper.lua` with owner-keyed blocker seeding, room-observation cycles, deterministic generation values, captured timer queues, and external walker/install stubs. [VERIFIED: codebase inspection `tests/support/boop_test_helper.lua:225`]
- [ ] Add multi-blocker and deterministic-primary cases to `tests/boop_runtime_spec.lua`. [VERIFIED: codebase inspection `tests/boop_runtime_spec.lua:104`]
- [ ] Add interrupt repeat, different-request-while-pending, timeout/success ordering, unrelated blocker preservation, and no-attack/prequeue cases. [VERIFIED: codebase inspection `tests/boop_interrupt_spec.lua`, `tests/boop_diag_spec.lua`, `tests/boop_diag_timeout_spec.lua`]
- [ ] Add pull generation, no-persisted-enable mutation, overlapping hold, timeout/return ordering, and stale callback cases to `tests/boop_pull_spec.lua`. [VERIFIED: codebase inspection `tests/boop_pull_spec.lua`]
- [ ] Replace chained-command expectations with staged room/inventory ownership, duplicate detection, room change, stale retry/timeout, and hold cases in gold specs. [VERIFIED: codebase inspection `tests/boop_gold_spec.lua:165`, `tests/boop_gold_retry_spec.lua:82`]
- [ ] Expand `tests/boop_walk_spec.lua` beyond blocker reasons to start/attach/stop/detach/status/install/manual/settlement/one-per-room/generation/event coverage. [VERIFIED: codebase inspection `tests/boop_walk_spec.lua:69`]
- [ ] Add event-order integration cases to `tests/boop_event_transitions_spec.lua` and retain target-removal queue-drift coverage. [VERIFIED: codebase inspection `tests/boop_event_transitions_spec.lua:243`, `tests/boop_event_transitions_spec.lua:410`]
- [ ] Update `tests/README.md` to list the completed walk/gold/ordering coverage. [VERIFIED: codebase inspection `tests/README.md`]

No new test framework or config file is needed. [VERIFIED: codebase inspection]

## Security Domain

Security enforcement is enabled at ASVS Level 1, so the phase must preserve fail-closed validation at event and command-effect boundaries even though boop is a local Mudlet package rather than a web service. [VERIFIED: codebase inspection `.planning/config.json`]

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | No | No identity/authentication surface is introduced in Phase 03. [VERIFIED: phase boundary `03-CONTEXT.md`] |
| V3 Session Management | No | Mudlet profile/session behavior is not an authentication session mechanism in scope here. [VERIFIED: phase boundary `03-CONTEXT.md`] |
| V4 Access Control | No | No role or authorization model is introduced. [VERIFIED: phase boundary `03-CONTEXT.md`] |
| V5 Input Validation | Yes | Validate GMCP table shape, non-empty stable room ID, complete room item list, exact operation generation, phase, terminal state, and external API availability before side effects. [VERIFIED: phase decisions `03-CONTEXT.md` D-05 through D-23] |
| V6 Cryptography | No | No cryptographic operation or secret handling is introduced. [VERIFIED: phase boundary `03-CONTEXT.md`] |

### Known Threat Patterns for Mudlet Timing/Integration

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Stale timer or event acts as the current operation | Spoofing / Tampering | Captured generation, exact owner, terminal compare, and final side-effect recheck. [VERIFIED: phase decisions D-08, D-22, D-23] |
| Missing/partial GMCP causes wrong-room command | Tampering | Fail closed; require current room cycle and complete list; one capped refresh. [VERIFIED: phase decisions D-09, D-12, D-14, D-15] |
| External walker disappears or changes mid-run | Tampering / Denial of Service | Recheck API at emission, invalidate movement, warn/trace, and never auto-install/update. [VERIFIED: Agent Discretion] |
| Mutable queue index removes operator work | Tampering | Do not infer queue-item ownership from an index; keep timeout cleanup local. [CITED: https://www.achaea.com/game-help?what=queueing] |
| User-controlled command fragment injection | Tampering | Preserve current narrow guards; do not broaden validation here because Phase 04 owns the trust boundary. [VERIFIED: phase boundary and deferred work `03-CONTEXT.md`] |

## Planning Decomposition

1. **Foundation:** Add owner-keyed blocker APIs, deterministic priority/all snapshots, room-observation defaults/helpers, and helper/test foundations. This must land before any lifecycle relies on independent clearing. [VERIFIED: phase decisions D-01 through D-04]
2. **Interrupt and pull:** Move all release paths to generation-owned terminal functions, reject repeats without resend, stop persisting pull pause through `config.enabled`, and add attack/prequeue race coverage. [VERIFIED: phase decisions D-05 through D-08]
3. **Gold:** Stage room-owned pickup and inventory-owned pack, remove gold chaining from attack aliases, gate retries/timeouts by room/generation, and test room/list/event orderings. [VERIFIED: phase decisions D-09 through D-12]
4. **Walk:** Replace timer settlement, add one refresh, unify manual/automatic gate, reserve one move per room generation, recheck at emit, and implement ownership-aware stop/missing-package failure. [VERIFIED: phase decisions D-13 through D-24]
5. **Integration/polish:** Update compact status/trace/help/docs, run cross-product tests and release gates, then perform authoritative Mudlet CI/live validation. [VERIFIED: project constraints `AGENTS.md`, `CODEX.md`]

Do not parallelize steps that edit `boop_runtime.lua`, `boop_events.lua`, or shared helper state; gold and walk both depend on the same room-observation contract and should share one settled-room implementation. [VERIFIED: codebase inspection]

## Sources

### Primary (HIGH confidence)

- Repository source and tests at the current working tree, especially `boop_runtime.lua`, `boop_events.lua`, `boop_walk.lua`, `boop_ui.lua`, `boop_util.lua`, and the Phase 03-focused specs. [VERIFIED: codebase inspection]
- `.planning/phases/03-queue-interrupt-gold-and-autowalk-regression-coverage/03-CONTEXT.md` — locked phase decisions and scope. [VERIFIED: codebase inspection]
- `.planning/REQUIREMENTS.md`, `.planning/ROADMAP.md`, `.planning/STATE.md` — requirement text, success criteria, and current phase state. [VERIFIED: codebase inspection]
- `AGENTS.md`, `README.md`, `DESIGN.md`, `CODEX.md` — repository workflow and current operator-facing contract. [VERIFIED: codebase inspection]
- `.github/workflows/main.yml` and `tools/check_release_gates.py` — authoritative CI/test and static-gate setup. [VERIFIED: codebase inspection]

### Secondary (MEDIUM confidence)

- https://nexus.ironrealms.com/GMCP — official `Room.Info`, `Char.Items.Room`, and `Char.Items.List` protocol documentation. [CITED: https://nexus.ironrealms.com/GMCP]
- https://wiki.mudlet.org/w/Manual%3ALua_Functions — official timer and custom-event API semantics. [CITED: https://wiki.mudlet.org/w/Manual%3ALua_Functions]
- https://wiki.mudlet.org/w/Manual%3AMiscellaneous_Functions — official `installPackage()` and anonymous-handler semantics. [CITED: https://wiki.mudlet.org/w/Manual%3AMiscellaneous_Functions]
- https://github.com/demonnic/demonnicAutoWalker — official upstream README/source for init, enabled, move, stop, arrived, finished, and explicit update behavior. [CITED: https://github.com/demonnic/demonnicAutoWalker]
- https://github.com/demonnic/test-in-mudlet — official test profile; its runner accepts either a directory or one file. [CITED: https://github.com/demonnic/test-in-mudlet]
- https://lunarmodules.github.io/busted/ — official Busted stubs/spies/call assertions. [CITED: https://lunarmodules.github.io/busted/]
- https://www.achaea.com/game-help?what=queueing — official Achaea queue commands and `ADDCLEARFULL`/index semantics. [CITED: https://www.achaea.com/game-help?what=queueing]

### Tertiary (LOW confidence)

- None. [VERIFIED: research log]

## Metadata

**Confidence breakdown:**

- Standard stack: HIGH — directly verified from the repository, host probes, and official project docs; no new package is proposed. [VERIFIED: codebase and environment inspection]
- Architecture: HIGH — driven by locked decisions and concrete current-state defects. [VERIFIED: `03-CONTEXT.md` and codebase inspection]
- External walker/GMCP details: MEDIUM — verified from official upstream/web documentation through the research seam, whose classified confidence is MEDIUM. [CITED: https://github.com/demonnic/demonnicAutoWalker] [CITED: https://nexus.ironrealms.com/GMCP]
- Pitfalls: HIGH — each is reproduced by source shape or an explicit locked race/ownership contract. [VERIFIED: codebase inspection and `03-CONTEXT.md`]
- Validation architecture: HIGH for file/test mapping; MEDIUM for local execution availability because the Mudlet AppImage is absent. [VERIFIED: codebase and environment inspection]

**Research date:** 2026-07-25
**Valid until:** 2026-08-24
