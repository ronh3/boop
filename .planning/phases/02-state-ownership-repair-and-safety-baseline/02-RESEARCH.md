# Phase 02: State Ownership Repair and Safety Baseline - Research

**Researched:** 2026-07-10
**Domain:** Mudlet Lua runtime state ownership, GMCP degradation, and automation safety holds
**Confidence:** HIGH for codebase mapping; MEDIUM for external GMCP documentation details

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
### State ownership scope

- **D-01:** Treat remaining flat `boop.state.*` access in Phase 02-owned paths as a defect, not compatibility. No new reads/writes should be added to legacy flat keys for room, target, pull, walk, gold, diag, flee, queue, inventory, trace, rage, IH, or gag.
- **D-02:** Expand the state-drift gate instead of relying only on manual review. The gate should fail if migrated Phase 02 files reintroduce flat access for the owned domains.
- **D-03:** If a file is touched for state ownership in Phase 02, prefer finishing that file's relevant ownership migration in the same phase rather than leaving a mixed flat/owned pattern in hot paths. If a file is too broad, explicitly keep unrelated domains out of scope before the plan lands.
- **D-04:** Test helpers and fixtures should migrate with runtime code. Do not preserve old flat setup patterns in tests just to reduce test churn.
- **D-05:** Prioritize safety-critical runtime flows first: room, target, flee, pull, queue, and gold before dashboard/trace polish.
- **D-06:** Allow cleanup only when it directly reduces state risk, makes ownership easier to verify, or removes obsolete flat compatibility from the Phase 02 domain. Avoid broad aesthetic refactors.
- **D-07:** Old flat-state tests should be rewritten to owned-domain setup/assertions instead of deleted when they still represent valid behavior.
- **D-08:** Remove obsolete flat keys from initialization/default/reset surfaces for Phase 02 domains once owned replacements are in place.

### Safety baseline

- **D-09:** When GMCP/game state is incomplete, boop should fail closed by holding attacks, walking advancement, queue/prequeue execution, and gold automation.
- **D-10:** The operator-facing warning should be concise: one visible blocker line, with details available in status/trace.
- **D-11:** Holds should clear automatically only when both a prompt cycle and the relevant GMCP state have been observed.
- **D-12:** Room changes should trigger fresh blocker evaluation and may clear old room/target blockers only when the new state is trustworthy.
- **D-13:** Phase 02 core safety coverage includes missing/partial room, current target, target removal, flee state, and GMCP IRE support. Other exotic malformed GMCP cases can be deferred unless they fall out naturally from shared validation.
- **D-14:** Warnings should be rate-limited so repeated bad GMCP events do not spam the live hunt log.
- **D-15:** Runtime safety holds must not silently change saved operator configuration such as `boop.config.enabled`.
- **D-16:** Blockers should block automation, not manual operator commands. Manual commands may still report why automation is held.
- **D-17:** Store structured blocker reason codes and affected systems in owned state so tests, status, and trace can assert the same source of truth.

### Auto-flee cleanup

- **D-18:** Auto-flee must cancel combat intent before escape movement: queued standard/rage attacks, prequeue state, target-call intent, and pending attack plans.
- **D-19:** Auto-flee must cancel walking and gold intent before escape movement.
- **D-20:** Auto-flee should not automatically re-enable hunting after fleeing. Operator must explicitly turn boop back on when safe.
- **D-21:** When the current target disappears, clear the current target and all attack intent tied to it, then retarget only if a valid target is present in the current room.
- **D-22:** Active pull/room transitions are the narrow exception to immediate target-loss cleanup. If the target disappears during an active pull transition, preserve only the state needed to complete or safely hold that pull lifecycle.
- **D-23:** When pull recovery ends, apply normal target-loss cleanup if the target is still absent.
- **D-24:** Target loss should produce a single concise warning line, not repeated spam across room item deltas.
- **D-25:** Auto-flee cleanup should produce a single concise summary line; detailed cleared fields belong in trace/status.
- **D-26:** Tests must assert cleanup happens before the flee movement command is sent.
- **D-27:** Target-loss retargeting may happen in the same tick only when current room target data is valid.

### Status, trace, dashboard

- **D-28:** Status/dashboard should show a compact blocker summary: code, short reason, affected systems, and what state is still awaited.
- **D-29:** Trace should capture blocker enter/exit, target-loss cleanup, flee cleanup, pull holds, GMCP recovery, and retarget decisions by default when tracing is enabled.
- **D-30:** Status/trace should show normalized owned-state values, not raw GMCP dumps.
- **D-31:** Live hunting output should remain minimal; status/trace/dashboard carry the richer detail.
- **D-32:** Update command help/docs for any new blocker/status fields if the operator-facing command surface changes.
- **D-33:** Status should display stable blocker codes plus human labels, e.g. `target_lost -- target left room`.
- **D-34:** Add/keep a focused UAT checkpoint for compact blocker/status readability instead of treating screenshots as enough.

### Pull and GMCP recovery boundaries

- **D-35:** Pull owns its lifecycle state and active-pull target-loss exception.
- **D-36:** Pull timeout while away should keep boop paused/held; only consider resume after return-to-origin and trustworthy state.
- **D-37:** Structured pull blockers should be present only while pull is active or resolving. Do not leave stale pull blockers after pull lifecycle is over.
- **D-38:** Pull command validation remains Phase 04 unless state lifecycle changes expose an immediate safety bypass.
- **D-39:** If `gmcp.IRE`, `gmcp.IRE.Target`, or `gmcp.IRE.Display` are missing after reconnect/status events, boop should retry GMCP supports immediately and hard-hold target-dependent automation.
- **D-40:** GMCP recovery should use immediate retry first, then short throttle/backoff so it is responsive without spamming.
- **D-41:** One concise operator warning is enough for GMCP recovery; status/trace can show retry details.
- **D-42:** Synthetic tests are enough in Phase 02; full live reconnect validation belongs in Phase 06.

### Autowalk boundary

- **D-43:** Phase 02 should migrate walk blocker reads and prevent unsafe walk advancement. Full walker start/stop/move behavior is Phase 03.
- **D-44:** Walk blockers should cover target, flee, GMCP, and pull now. Gold/diag timing depth waits can stay Phase 03 unless already touched by owned-state migration.
- **D-45:** Add focused blocker tests in the cleanest harness available; do not broaden into full walker route/arrival behavior yet.
- **D-46:** Do not change demonnicAutoWalker install/status behavior unless a blocker reason needs to report external walker unavailability.

### the agent's Discretion
- Choose whether blocker helpers live in `boop.safety`, `boop.runtime`, or a small state helper module, as long as ownership is clear and tests verify canonical output.
- Choose exact stable reason-code names, but keep them short, documented, and asserted in tests.
- Decide whether to update dashboard rendering in the same plan wave as status/trace or after runtime safety tests pass.
- Use small module/function extractions only where they reduce repeated ownership checks or make cleanup ordering testable.

### Deferred Ideas (OUT OF SCOPE)
- Full autowalk start/stop/move behavior and deep route edge cases are Phase 03.
- Command-fragment validation and chain-send hardening are Phase 04.
- Live GMCP reconnect validation and broader release UX/docs are Phase 06.
- README-wide release documentation refresh is Phase 06 unless Phase 02 changes operator-visible commands enough to require a targeted help/docs update.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| STATE-01 | Room, target, pull, walk, gold, diag, flee, queue, inventory, trace, rage, IH, and gag state is read and written through owned domains. | Runtime domains already exist for `combat`, `targeting`, `gold`, `queue`, `walk`, `diag`, `trace`, `ui`, `rage`, `inventory`, `ih`, and `gag`; `boop_walk.lua` and selected no-context fallbacks in `boop_attacks.lua` remain the main Phase 02 ownership risks. [VERIFIED: codebase grep src/scripts/boop/boop_runtime.lua:19] [VERIFIED: codebase grep src/scripts/boop/boop_walk.lua:6] [VERIFIED: codebase grep src/scripts/boop/boop_attacks.lua:25] |
| STATE-02 | GMCP reconnect, missing `gmcp.IRE`, partial room-target updates, and unsafe hidden state degrade with visible blockers and warnings. | Existing reconnect/status handlers retry GMCP supports, but they do not yet create structured owned blockers, rate-limited warnings, prompt-plus-GMCP clearing, or backoff state. [VERIFIED: codebase grep src/scripts/boop/boop_events.lua:514] [VERIFIED: codebase grep src/scripts/boop/boop_events.lua:764] |
| STATE-03 | Runtime trace, status, and dashboard report canonical owned-state values for targeting, movement, pull, gold, diag, flee, queue, and gag debugging. | Status/dashboard currently derive blocker text from ad hoc UI logic, while trace is effect-driven; the planner should route both through one owned blocker snapshot so trace/status/dashboard assert the same values. [VERIFIED: codebase grep src/scripts/boop/boop_ui.lua:329] [VERIFIED: codebase grep src/scripts/boop/boop_runtime.lua:366] |
| SAFE-01 | Auto-flee cancels or blocks queue, prequeue, walk, gold, and attack intent before escape movement. | `boop.safety.flee()` already disables hunting and clears some domains, but it sends escape movement without a single tested cleanup step for queue/prequeue/walk/attack intent ordering. [VERIFIED: codebase grep src/scripts/boop/boop_safety.lua:23] [VERIFIED: codebase grep tests/boop_safety_spec.lua:58] |
| SAFE-03 | Current target disappearance clears queued attack state and retargets only valid room targets. | `onRoomItemsRemove()` clears current target and some target fields, then retargets/ticks; it does not yet centralize attack-intent cleanup, pull exceptions, structured warning, or same-tick valid-room gating. [VERIFIED: codebase grep src/scripts/boop/boop_events.lua:561] [VERIFIED: codebase grep tests/boop_event_transitions_spec.lua:42] |
</phase_requirements>

## Summary

Phase 02 is a state-ownership repair and fail-closed safety phase, not a feature expansion phase. The existing owned-domain model is already in place in `boop.runtime.ensureState()` and `boop.runtime.context()`, and Phase 01 moved several high-value paths to owned domains; the remaining planning risk is mixed ownership in hot automation paths, especially walk blockers and no-context attack fallbacks. [VERIFIED: codebase grep src/scripts/boop/boop_runtime.lua:124] [VERIFIED: codebase grep src/scripts/boop/boop_runtime.lua:177] [VERIFIED: codebase grep tools/check_release_gates.py:76]

The planner should treat structured runtime blockers as the central design object for this phase. GMCP recovery, target loss, pull holds, flee cleanup, walk advancement, gold automation, queue/prequeue, status, dashboard, and trace should all read the same owned blocker state, with concise live warnings and richer status/trace detail. [VERIFIED: codebase grep src/scripts/boop/boop_ui.lua:329] [VERIFIED: codebase grep src/scripts/boop/boop_runtime.lua:253] [VERIFIED: codebase grep src/scripts/boop/boop_events.lua:764]

The implementation should stay inside Phase 02 boundaries: migrate walk blocker reads and unsafe advancement only, keep full walker route behavior for Phase 03, keep command-fragment validation for Phase 04, and use synthetic GMCP reconnect tests rather than live reconnect validation. [VERIFIED: codebase grep .planning/ROADMAP.md:23] [VERIFIED: codebase grep .planning/ROADMAP.md:38] [VERIFIED: codebase grep .planning/ROADMAP.md:45]

**Primary recommendation:** Add a small canonical blocker/cleanup API over owned state, migrate Phase 02 hot paths to it, expand the state-drift gate for touched files, and test cleanup-before-command ordering before any status/dashboard polish. [VERIFIED: codebase grep .planning/phases/02-state-ownership-repair-and-safety-baseline/02-CONTEXT.md:13]

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|--------------|----------------|-----------|
| Owned runtime domains | Mudlet package runtime | Tests/release gate | `boop.runtime.ensureState()` owns domain defaults and `tools/check_release_gates.py` enforces remaining flat-state allowances. [VERIFIED: codebase grep src/scripts/boop/boop_runtime.lua:19] [VERIFIED: codebase grep tools/check_release_gates.py:76] |
| GMCP recovery and incomplete game-state holds | Event/runtime layer | UI trace/status | GMCP events enter through `boop.events`, but automation hold decisions need runtime-owned blocker state consumed by tick/effects/UI. [VERIFIED: codebase grep src/scripts/boop/boop_events.lua:480] [VERIFIED: codebase grep src/scripts/boop/boop_runtime.lua:253] |
| Target disappearance and valid retargeting | Event/targeting layer | Combat queue/runtime | Room item removal is detected in `boop.events`, target identity lives in `state.targeting`, and queued attack effects are emitted by runtime combat planning. [VERIFIED: codebase grep src/scripts/boop/boop_events.lua:561] [VERIFIED: codebase grep src/scripts/boop/boop_runtime.lua:293] |
| Auto-flee cleanup | Safety layer | Runtime effects/walk/gold/queue | `boop.safety.flee()` sends escape movement today, so cleanup must happen there or in a helper it calls before any `send` side effect. [VERIFIED: codebase grep src/scripts/boop/boop_safety.lua:23] |
| Walk unsafe advancement prevention | Walk layer | Runtime blocker API | `boop.walk` currently evaluates blockers before advancing; Phase 02 should migrate those reads without changing full walker behavior. [VERIFIED: codebase grep src/scripts/boop/boop_walk.lua:70] |
| Status/dashboard/trace consistency | UI and trace effects | Runtime blocker snapshot | `boop.ui.currentBlocker()` currently recomputes blocker text separately from trace; both should use the owned blocker snapshot. [VERIFIED: codebase grep src/scripts/boop/boop_ui.lua:329] [VERIFIED: codebase grep src/scripts/boop/boop_runtime.lua:366] |
| Pull target-loss exception | UI pull lifecycle | Event/targeting cleanup | Pull lifecycle state is stored under `state.combat.pullState`; target-loss cleanup must preserve only active pull resolution state and then apply normal cleanup when pull ends. [VERIFIED: codebase grep src/scripts/boop/boop_ui.lua:1267] [VERIFIED: codebase grep src/scripts/boop/boop_events.lua:637] |

## Project Constraints (from AGENTS.md)

- Read `README.md` and `DESIGN.md` before drawing implementation conclusions; both were inspected for command surface, architecture, and phase boundaries. [VERIFIED: codebase grep AGENTS.md:5] [VERIFIED: local command]
- Read `UIDESIGN.md` for UI or UX work; this phase touches status/dashboard/trace presentation, so UI guidance was inspected. [VERIFIED: codebase grep AGENTS.md:7] [VERIFIED: local command]
- Read `CODEX.md` for repository workflow guidance; it confirms package source lives under `src/`, built artifacts are not source, and release gates include `versions`, `manifests`, and `state-drift`. [VERIFIED: codebase grep AGENTS.md:8] [VERIFIED: codebase grep CODEX.md:19]
- On commits and pushes, keep `mfile.version`, `mfile.title`, and `src/scripts/boop/boop_init.lua` `boop.version` synchronized; this research task must not commit or push, per user instruction. [VERIFIED: codebase grep AGENTS.md:11] [VERIFIED: user request]
- Work only under `src/` for package content and never edit built artifacts; this task writes only the planning artifact. [VERIFIED: codebase grep AGENTS.md:20] [VERIFIED: user request]
- Keep user-facing docs and command help in sync with command-surface changes; Phase 02 only needs targeted help/docs updates if blocker/status command output changes. [VERIFIED: codebase grep AGENTS.md:22] [VERIFIED: codebase grep .planning/phases/02-state-ownership-repair-and-safety-baseline/02-CONTEXT.md:72]
- Prefer polish, consistency, operator clarity, and stability over feature expansion; this aligns with Phase 02 boundaries against full walker behavior and live reconnect validation. [VERIFIED: codebase grep AGENTS.md:23] [VERIFIED: codebase grep .planning/ROADMAP.md:24]

## Standard Stack

### Core

| Library / Runtime | Version | Purpose | Why Standard |
|-------------------|---------|---------|--------------|
| Mudlet | 4.20.1 local AppImage; CI workflow also targets Mudlet 4.20.1 | Runtime host for GMCP, aliases, triggers, timers, and package execution | Existing tests and release flow run the package under Mudlet, and full behavior depends on Mudlet's event and GMCP APIs. [VERIFIED: local command `/tmp/Mudlet.AppImage --version`] [VERIFIED: codebase grep .github/workflows/main.yml] |
| Lua | 5.1-compatible code style; CI installs Lua 5.1.5 | Package language and Busted runtime language | Mudlet package code targets Lua 5.1-era compatibility, and CI pins Lua 5.1.5 before installing test dependencies. [VERIFIED: codebase grep .github/workflows/main.yml] |
| Muddler | command present at `/usr/local/bin/muddle`; version command unavailable in non-TTY shell | Builds `src/` package content into `build/boop Hunter.mpackage` | Existing build instructions and CI use `muddle`; do not edit `build/` directly. [VERIFIED: local command `command -v muddle`] [VERIFIED: codebase grep CODEX.md:19] |
| Busted | 2.3.0 host command; run inside Mudlet for canonical tests | Lua test framework | Existing specs use Busted assertions and are launched through Mudlet profile automation. [VERIFIED: local command `busted --version`] [VERIFIED: codebase grep tests/support/boop_test_helper.lua:1] |
| Python | 3.14.6 local | Release gate runner | `tools/check_release_gates.py` implements version, manifest, and state-drift checks. [VERIFIED: local command `python3 --version`] [VERIFIED: codebase grep tools/check_release_gates.py:1] |

### Supporting

| Tool / API | Version | Purpose | When to Use |
|------------|---------|---------|-------------|
| Mudlet `sendGMCP()` | Mudlet API | Requests GMCP modules such as `Core.Supports.Add` and skill data | Use existing `boop.requestCoreSupports()` path for reconnect and missing-IRE recovery rather than a new transport. [CITED: https://wiki.mudlet.org/w/Manual%3ANetworking_Functions] [VERIFIED: codebase grep src/scripts/boop/boop_events.lua:764] |
| Mudlet event handlers | Mudlet API | Receives GMCP and system events through registered handlers | Use existing `registerAnonymousEventHandler()` setup in `boop.events.register()`. [CITED: https://wiki.mudlet.org/w/Manual%3AEvent_Engine] [VERIFIED: codebase grep src/scripts/boop/boop_events.lua:480] |
| IRE GMCP Core.Supports | IRE GMCP protocol | Re-negotiates supported GMCP modules after reconnect or missing data | `Core.Supports.Set` replaces and `Core.Supports.Add` appends or overrides module support declarations, so immediate retry plus throttled repeats should call the existing support-request helper. [CITED: https://nexus.ironrealms.com/GMCP] [VERIFIED: codebase grep src/scripts/boop/boop_init.lua] |
| `tools/check_release_gates.py` state-drift gate | local script | Static guard against reintroduced flat state access | Expand its baseline as files migrate so Phase 02 cannot regress silently. [VERIFIED: codebase grep tools/check_release_gates.py:76] |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Existing owned state domains | New persistent DB-backed blocker state | Reject for Phase 02 because blockers are volatile runtime safety state and current DB stores config/lists/stats, not `boop.state`. [VERIFIED: codebase grep src/scripts/boop/boop_db.lua:80] |
| Existing Mudlet GMCP event path | Custom GMCP polling loop | Reject because Mudlet already raises GMCP events and `sendGMCP()` handles module requests. [CITED: https://wiki.mudlet.org/w/Manual%3ASupported_Protocols] |
| Existing walk module blocker checks | Full demonnicAutoWalker behavior rewrite | Reject because Phase 02 boundary is blocker reads and unsafe advancement only; route behavior belongs to Phase 03. [VERIFIED: codebase grep .planning/phases/02-state-ownership-repair-and-safety-baseline/02-CONTEXT.md:102] |
| Existing Busted/Mudlet harness | New test framework | Reject because existing specs, helpers, and CI already validate Mudlet package behavior. [VERIFIED: codebase grep .github/workflows/main.yml] [VERIFIED: codebase grep tests/support/boop_test_helper.lua:93] |

**Installation:** No new external packages are recommended for Phase 02. [VERIFIED: codebase grep package context; no package manager manifests found for Phase 02 install]

**Version verification:** Local probes confirmed Mudlet 4.20.1, Busted 2.3.0, Python 3.14.6, LuaRocks 3.13.0, and `jq` 1.8.1; `muddle` is present but its version command failed in this non-TTY environment. [VERIFIED: local command]

## Package Legitimacy Audit

Phase 02 should not install new external packages. [VERIFIED: codebase grep .planning/ROADMAP.md:23] The package legitimacy gate is therefore not applicable, and there are no npm/PyPI/crates packages to approve, remove, or flag. [VERIFIED: local command]

| Package | Registry | Age | Downloads | Source Repo | Verdict | Disposition |
|---------|----------|-----|-----------|-------------|---------|-------------|
| None | — | — | — | — | — | No install recommended. [VERIFIED: local command] |

**Packages removed due to [SLOP] verdict:** none. [VERIFIED: local command]
**Packages flagged as suspicious [SUS]:** none. [VERIFIED: local command]

## Architecture Patterns

### System Architecture Diagram

```text
Mudlet GMCP / prompt / aliases
        |
        v
boop.events.register()
        |
        +--> Room/target updates --> state.targeting + state.gold + pull lifecycle
        |                              |
        |                              v
        |                         target-loss cleanup
        |                         /        \
        |                  active pull      no active pull
        |                   hold/resolve    clear target + attack intent
        |
        +--> Reconnect/status --> requestCoreSupports() --> GMCP recovery blocker/backoff
        |
        v
boop.runtime.context() --> blocker snapshot from owned state
        |
        v
boop.runtime.tickStep()
        |
        +--> held automation: trace/status/dashboard warning only
        |
        +--> safe automation: gold, walk advance, target choice, combat plan
        |
        v
boop.runtime.applyEffects() --> send/queue/flee/trace side effects
```

This flow matches existing event registration, runtime context, tick, and effect boundaries; the new Phase 02 work should insert blocker and cleanup helpers into those boundaries rather than creating a parallel state path. [VERIFIED: codebase grep src/scripts/boop/boop_events.lua:480] [VERIFIED: codebase grep src/scripts/boop/boop_runtime.lua:177] [VERIFIED: codebase grep src/scripts/boop/boop_runtime.lua:253] [VERIFIED: codebase grep src/scripts/boop/boop_runtime.lua:366]

### Recommended Project Structure

```text
src/scripts/boop/
├── boop_runtime.lua      # owned domain defaults, context snapshots, tick/effect routing
├── boop_safety.lua       # flee decision and cleanup-before-movement helper
├── boop_events.lua       # GMCP room/target/reconnect ingestion and target-loss transitions
├── boop_walk.lua         # Phase 02 owned blocker reads; no full walker rewrite
├── boop_targets.lua      # target selection and applyTarget canonical writes
├── boop_attacks.lua      # remove no-context flat fallbacks in Phase 02-owned paths
├── boop_ui.lua           # status/dashboard/help surfaces reading canonical blocker snapshot
└── boop_trace.lua        # trace entries fed by runtime/effect/blocker events
tools/
└── check_release_gates.py # expand state-drift baseline for migrated files
tests/
├── boop_event_transitions_spec.lua # GMCP recovery and target-loss behavior
├── boop_safety_spec.lua            # flee cleanup-before-send behavior
├── boop_walk_spec.lua              # blocker reads and unsafe advancement
├── boop_trace_spec.lua             # canonical trace values
└── boop_ui_spec.lua                # status/dashboard canonical values
```

This structure uses existing files and test conventions; no new package content outside `src/` is needed. [VERIFIED: codebase grep CODEX.md:19] [VERIFIED: codebase grep tests]

### Pattern 1: Owned State Domains Only

**What:** Read and write runtime hunting state through `boop.state.<domain>.<field>` after `boop.runtime.ensureState()` has initialized domains. [VERIFIED: codebase grep src/scripts/boop/boop_runtime.lua:124]

**When to use:** Every Phase 02 path touching room, target, pull, walk, gold, diag, flee, queue, inventory, trace, rage, IH, or gag. [VERIFIED: codebase grep .planning/REQUIREMENTS.md]

**Example:**

```lua
-- Source pattern: src/scripts/boop/boop_runtime.lua domain defaults and context mapping.
local state = boop.runtime.ensureState()
local target = state.targeting
local walk = state.walk

if target.currentTargetId and not state.combat.fleeing then
  walk.blockedByTarget = true
end
```

The concrete names in this snippet are planner guidance; the factual source is the existing owned-domain initialization and context mapping. [VERIFIED: codebase grep src/scripts/boop/boop_runtime.lua:19] [VERIFIED: codebase grep src/scripts/boop/boop_runtime.lua:177]

### Pattern 2: Structured Blocker Snapshot

**What:** Store a normalized blocker record in owned runtime state with stable `code`, short `label`, `affected` systems, `waitsFor` state, warning throttle metadata, and optional trace details. [VERIFIED: codebase grep .planning/phases/02-state-ownership-repair-and-safety-baseline/02-CONTEXT.md:44]

**When to use:** GMCP missing/partial state, target loss, active pull holds, flee state, and unsafe hidden state that should stop automation but not manual operator commands. [VERIFIED: codebase grep .planning/phases/02-state-ownership-repair-and-safety-baseline/02-CONTEXT.md:29]

**Example:**

```lua
-- Recommended shape over existing owned state, not a new dependency.
state.combat.blocker = {
  code = "gmcp_missing_ire",
  label = "GMCP IRE data missing",
  affected = { attacks = true, walk = true, queue = true, gold = true },
  waitsFor = { prompt = true, gmcpIRE = true },
  details = "retrying Core.Supports",
}
```

The `combat` domain already owns flee, pull, attacking, and hunting state, so it is the lowest-churn owner for cross-automation blockers unless implementation reveals a cleaner local helper. [VERIFIED: codebase grep src/scripts/boop/boop_runtime.lua:20]

### Pattern 3: Cleanup Before Side Effects

**What:** Clear unsafe intent first, record one summary warning/trace entry, then send movement or attack side effects. [VERIFIED: codebase grep .planning/phases/02-state-ownership-repair-and-safety-baseline/02-CONTEXT.md:52]

**When to use:** Auto-flee and target disappearance. [VERIFIED: codebase grep src/scripts/boop/boop_safety.lua:23] [VERIFIED: codebase grep src/scripts/boop/boop_events.lua:561]

**Example:**

```lua
-- Recommended testable helper shape.
local cleared = boop.safety.clearAutomationIntent("flee")
boop.trace.record("flee_cleanup", cleared)
boop.executeAction(escapeCommand)
```

Tests should assert the cleanup helper runs before the first `send("wake")` or movement command in the flee chain. [VERIFIED: codebase grep tests/boop_safety_spec.lua:58] [VERIFIED: codebase grep .planning/phases/02-state-ownership-repair-and-safety-baseline/02-CONTEXT.md:58]

### Pattern 4: Pull Exception Is Narrow and Temporary

**What:** If a target disappears during an active pull transition, preserve only pull lifecycle state needed to return or hold safely; when pull resolves, run normal target-loss cleanup if the target is still absent. [VERIFIED: codebase grep .planning/phases/02-state-ownership-repair-and-safety-baseline/02-CONTEXT.md:54]

**When to use:** `state.combat.pullState.active == true` during room item removal, room transition, or pull timeout. [VERIFIED: codebase grep src/scripts/boop/boop_ui.lua:1416] [VERIFIED: codebase grep src/scripts/boop/boop_events.lua:637]

**Example:**

```lua
-- Recommended branch point around onRoomItemsRemove().
if boop.pull and boop.pull.isResolvingTargetLoss(state.combat.pullState) then
  boop.runtime.setBlocker("pull_resolving", { affected = { attacks = true, walk = true } })
else
  boop.targets.clearLostTargetIntent("target_lost")
end
```

The exact helper location is discretionary, but the pull-state source and target-loss event source are already established. [VERIFIED: codebase grep src/scripts/boop/boop_ui.lua:1267] [VERIFIED: codebase grep src/scripts/boop/boop_events.lua:561]

### Pattern 5: GMCP Recovery Uses Existing Support Request Path

**What:** On reconnect or missing `gmcp.IRE`/`Target`/`Display`, request GMCP supports immediately, enter a blocker, and then retry with short throttled/backoff timing until prompt plus relevant GMCP state arrives. [VERIFIED: codebase grep src/scripts/boop/boop_events.lua:764] [VERIFIED: codebase grep .planning/phases/02-state-ownership-repair-and-safety-baseline/02-CONTEXT.md:89]

**When to use:** `sysConnectionEvent`, `gmcp.Char.Status`, and other status-like events where target-dependent automation would otherwise proceed with stale or incomplete state. [VERIFIED: codebase grep src/scripts/boop/boop_events.lua:480] [VERIFIED: codebase grep src/scripts/boop/boop_events.lua:514]

**Example:**

```lua
-- Recommended helper shape, using existing support-request behavior.
if not (gmcp and gmcp.IRE and gmcp.IRE.Target and gmcp.IRE.Display) then
  boop.runtime.setBlocker("gmcp_missing_ire", { waitsFor = { prompt = true, gmcpIRE = true } })
  boop.requestCoreSupports({ requestSkills = true, minInterval = 0, force = true })
end
```

Mudlet exposes `sendGMCP()` for GMCP requests, and IRE documents `Core.Supports.Add` as a way to append or override module support declarations. [CITED: https://wiki.mudlet.org/w/Manual%3ANetworking_Functions] [CITED: https://nexus.ironrealms.com/GMCP]

### Anti-Patterns to Avoid

- **Mixed flat/owned reads in touched files:** This hides state drift and makes tests pass against stale keys; migrate the whole Phase 02-owned surface in a touched file or document why the unrelated domain stays out of scope. [VERIFIED: codebase grep .planning/phases/02-state-ownership-repair-and-safety-baseline/02-CONTEXT.md:15]
- **UI-only blocker strings:** `boop.ui.currentBlocker()` currently recomputes ad hoc status text; Phase 02 needs an owned blocker source shared by runtime, trace, status, and dashboard. [VERIFIED: codebase grep src/scripts/boop/boop_ui.lua:329]
- **Flee movement before cleanup:** `boop.safety.flee()` sends an escape chain; Phase 02 tests must prove intent cleanup happens before that side effect. [VERIFIED: codebase grep src/scripts/boop/boop_safety.lua:49] [VERIFIED: codebase grep .planning/phases/02-state-ownership-repair-and-safety-baseline/02-CONTEXT.md:58]
- **Treating GMCP support retry as recovery by itself:** Current code retries supports, but fail-closed behavior also needs blocker state, warning throttling, and clearing rules. [VERIFIED: codebase grep src/scripts/boop/boop_events.lua:764]
- **Pull timeout clearing away-state too early:** Current pull timeout can clear pull state while away; Phase 02 requires a held/paused state until return-to-origin and trustworthy state. [VERIFIED: codebase grep src/scripts/boop/boop_ui.lua:1281] [VERIFIED: codebase grep .planning/phases/02-state-ownership-repair-and-safety-baseline/02-CONTEXT.md:82]

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| GMCP transport and reconnect polling | New custom network or polling loop | Mudlet GMCP events plus existing `boop.requestCoreSupports()` | Mudlet already populates the `gmcp` table and exposes GMCP send/request APIs; existing boop handlers are wired to those events. [CITED: https://wiki.mudlet.org/w/Manual%3ASupported_Protocols] [VERIFIED: codebase grep src/scripts/boop/boop_events.lua:480] |
| Runtime state model | Parallel compatibility map or flat aliases | `boop.runtime.ensureState()` owned domains | The current state contract and release gate already define canonical domains. [VERIFIED: codebase grep src/scripts/boop/boop_runtime.lua:19] [VERIFIED: codebase grep tests/boop_state_contract_spec.lua:1] |
| Static drift detection | Manual review checklist only | Expand `tools/check_release_gates.py --check state-drift` | The script already inventories known flat accesses and can fail on new or changed drift. [VERIFIED: codebase grep tools/check_release_gates.py:76] |
| Full walker behavior | New route engine or demonnicAutoWalker integration rewrite | Existing `boop.walk` blocker checks only | Phase 02 is explicitly limited to blocker reads and unsafe advancement, with full walker behavior deferred. [VERIFIED: codebase grep .planning/phases/02-state-ownership-repair-and-safety-baseline/02-CONTEXT.md:102] |
| Trace/status/dashboard data formatting | Separate formatting logic per surface | Shared owned blocker snapshot plus existing UI/trace renderers | Consistency requirement is across surfaces, so separate logic would recreate drift. [VERIFIED: codebase grep .planning/REQUIREMENTS.md] |
| Target selection rules | New target list implementation | Existing `boop.targets` and owned `state.targeting.denizens` | Current target selection already uses owned denizen lists; Phase 02 should fix stale-current cleanup around it. [VERIFIED: codebase grep src/scripts/boop/boop_targets.lua:177] |

**Key insight:** Phase 02 fails if it creates another source of truth. The repair should centralize blocker and cleanup state in owned domains, then make runtime, UI, trace, and tests read the same canonical values. [VERIFIED: codebase grep .planning/REQUIREMENTS.md]

## Runtime State Inventory

| Category | Items Found | Action Required |
|----------|-------------|-----------------|
| Stored data | Mudlet DB code persists config, party lists, mob XP, and stats; no volatile `boop.state` persistence was found in `boop_db.lua`. [VERIFIED: codebase grep src/scripts/boop/boop_db.lua:80] | No data migration for runtime state ownership. If command help/config keys change, update docs/help and DB defaults only through source. [VERIFIED: codebase grep AGENTS.md:22] |
| Live service config | GMCP support negotiation is live session state; `boop.events` already retries supports on connection/status events. [VERIFIED: codebase grep src/scripts/boop/boop_events.lua:514] `demonnicAutoWalker` is an external live dependency for walking, but Phase 02 must not change install/status behavior unless reporting a blocker reason. [VERIFIED: codebase grep DESIGN.md] [VERIFIED: codebase grep .planning/phases/02-state-ownership-repair-and-safety-baseline/02-CONTEXT.md:105] | Add blocker/backoff state in boop runtime; do not migrate external walker state or routes. [VERIFIED: codebase grep .planning/ROADMAP.md:38] |
| OS-registered state | No systemd, launchd, scheduled task, or OS registration references were found in the repository scan. [VERIFIED: local command `rg -n "systemd|launchd|Task Scheduler|pm2|cron|crontab" .`] | None. [VERIFIED: local command] |
| Secrets/env vars | No `.env` runtime secrets were found; CI/test environment variables are limited to Mudlet/Busted automation such as `TESTS_DIRECTORY`, `AUTORUN_BUSTED_TESTS`, `QUIT_MUDLET_AFTER_TESTS`, and release asset variables. [VERIFIED: local command `rg -n "TESTS_DIRECTORY|AUTORUN_BUSTED_TESTS|QUIT_MUDLET_AFTER_TESTS|MUDLET_RELEASE_TAG|GITHUB_TOKEN" .`] | No secret or env var migration. Keep test commands using existing variables. [VERIFIED: codebase grep .github/workflows/main.yml] |
| Build artifacts | `build/` contains generated package output and filtered/temp files. [VERIFIED: local command `ls build`] | Do not edit build artifacts. Source changes in implementation should be rebuilt with `muddle` and verified by release gates. [VERIFIED: codebase grep CODEX.md:19] |

**Nothing found in OS-registered state:** None, verified by repository search for common service registration terms. [VERIFIED: local command]

## Current State Ownership Findings

| Surface | Current Ownership State | Planning Implication |
|---------|-------------------------|----------------------|
| Runtime defaults/context | Owned domains exist and context maps target, denizens, queue, gold, diag, assist, inventory, and rage into canonical snapshots. [VERIFIED: codebase grep src/scripts/boop/boop_runtime.lua:19] [VERIFIED: codebase grep src/scripts/boop/boop_runtime.lua:177] | Use this as the source of truth; avoid adding flat aliases. [VERIFIED: codebase grep .planning/phases/02-state-ownership-repair-and-safety-baseline/02-CONTEXT.md:13] |
| State init/reset | `boop.state.init()` delegates to `boop.runtime.ensureState()`. [VERIFIED: codebase grep src/scripts/boop/boop_state.lua:8] | Add new blocker fields to runtime defaults, not separate flat reset logic. [VERIFIED: codebase grep src/scripts/boop/boop_runtime.lua:124] |
| Walk | `boop_walk.lua` still treats `boop.state` as the walk state table and reads/writes flat walk, diag, flee, gold, and target fields. [VERIFIED: codebase grep src/scripts/boop/boop_walk.lua:6] [VERIFIED: codebase grep src/scripts/boop/boop_walk.lua:70] | Highest-priority ownership migration file; update state-drift allowlist after migration. [VERIFIED: codebase grep tools/check_release_gates.py:104] |
| Attacks | Planning helpers prefer context/owned state but still fall back to flat `spec`, `currentTargetId`, `targetShield`, wielded items, and `lastOpenerTraceKey` in no-context paths. [VERIFIED: codebase grep src/scripts/boop/boop_attacks.lua:39] [VERIFIED: codebase grep src/scripts/boop/boop_attacks.lua:1202] | Remove or isolate only Phase 02-owned fallbacks touched by cleanup/target-loss work; do not broaden into attack-system refactor. [VERIFIED: codebase grep .planning/phases/02-state-ownership-repair-and-safety-baseline/02-CONTEXT.md:16] |
| Events room/pull | Room info handling now writes `state.targeting.room`, movement, flee, and pull lifecycle through owned domains. [VERIFIED: codebase grep src/scripts/boop/boop_events.lua:637] | Treat older planning/codebase docs that mention room/pull flat drift as stale; verify against source before planning edits. [VERIFIED: codebase grep src/scripts/boop/boop_events.lua:637] |
| Target removal | Current target removal clears current target, prequeue flag, alias dirty, shield/affs, and retargets/ticks. [VERIFIED: codebase grep src/scripts/boop/boop_events.lua:561] | Add all-attack-intent cleanup, valid-room retarget gating, pull exception, and structured warning. [VERIFIED: codebase grep .planning/phases/02-state-ownership-repair-and-safety-baseline/02-CONTEXT.md:53] |
| Safety flee | Flee clears some state and sends escape movement, but does not centralize queue/prequeue/walk/gold/attack cleanup before sends. [VERIFIED: codebase grep src/scripts/boop/boop_safety.lua:23] | Implement a cleanup-before-command helper and assert order in tests. [VERIFIED: codebase grep .planning/phases/02-state-ownership-repair-and-safety-baseline/02-CONTEXT.md:58] |
| UI blockers | Status/dashboard blocker text is currently computed in `boop.ui.currentBlocker()`. [VERIFIED: codebase grep src/scripts/boop/boop_ui.lua:329] | Replace ad hoc blocker text with owned blocker snapshot while preserving concise live output. [VERIFIED: codebase grep .planning/phases/02-state-ownership-repair-and-safety-baseline/02-CONTEXT.md:66] |

## Common Pitfalls

### Pitfall 1: Passing Tests Through Flat Test Setup

**What goes wrong:** Tests seed `boop.state.currentTargetId` or other flat fields and mask runtime drift. [VERIFIED: codebase grep .planning/phases/02-state-ownership-repair-and-safety-baseline/02-CONTEXT.md:14]

**Why it happens:** Helpers historically reset a shared global state table, and some old tests predate owned domains. [VERIFIED: codebase grep tests/support/boop_test_helper.lua:93]

**How to avoid:** Update helper setup and assertions to owned domains such as `state.targeting.currentTargetId`, `state.queue.prequeuedStandard`, `state.gold.autoGrabPending`, and `state.walk.active`. [VERIFIED: codebase grep src/scripts/boop/boop_runtime.lua:20]

**Warning signs:** New test fixtures write direct flat keys that are also listed in `KNOWN_FLAT_STATE_ACCESS`. [VERIFIED: codebase grep tools/check_release_gates.py:76]

### Pitfall 2: Letting GMCP Retry Continue Automation

**What goes wrong:** Missing `gmcp.IRE` triggers `requestCoreSupports()` but target-dependent automation still proceeds using stale state. [VERIFIED: codebase grep src/scripts/boop/boop_events.lua:764]

**Why it happens:** Current code requests support modules but does not store a runtime blocker. [VERIFIED: codebase grep src/scripts/boop/boop_events.lua:764]

**How to avoid:** Add blocker state at the same time as the retry and make tick/walk/gold/queue/attack planning consult it. [VERIFIED: codebase grep src/scripts/boop/boop_runtime.lua:253]

**Warning signs:** Tests assert `Core.Supports.Add` was sent but do not assert automation is held. [VERIFIED: codebase grep tests/boop_event_transitions_spec.lua:179]

### Pitfall 3: Clearing Pull State Too Early

**What goes wrong:** Pull timeout while away can clear pull state, leaving boop disabled without a structured pull blocker or clear recovery path. [VERIFIED: codebase grep src/scripts/boop/boop_ui.lua:1281]

**Why it happens:** Current timeout code treats timeout cleanup and lifecycle resolution as the same operation. [VERIFIED: codebase grep src/scripts/boop/boop_ui.lua:1281]

**How to avoid:** Keep a resolving pull blocker while away and only clear it after return-to-origin plus trustworthy state. [VERIFIED: codebase grep .planning/phases/02-state-ownership-repair-and-safety-baseline/02-CONTEXT.md:82]

**Warning signs:** A test expects `state.combat.pullState` to be nil after away timeout. [VERIFIED: codebase grep tests/boop_pull_spec.lua]

### Pitfall 4: Retargeting From Partial Room Data

**What goes wrong:** Target-loss cleanup retargets immediately from incomplete room item state, potentially queuing attacks against stale or absent targets. [VERIFIED: codebase grep src/scripts/boop/boop_events.lua:561]

**Why it happens:** Room item remove events are deltas, and GMCP partial updates can leave ambiguous local state unless merged or validated. [CITED: https://wiki.mudlet.org/w/Manual%3AMiscellaneous_Functions]

**How to avoid:** Retarget same tick only when current room target data is valid; otherwise enter a `target_lost` or `room_partial` blocker and wait for prompt plus relevant GMCP state. [VERIFIED: codebase grep .planning/phases/02-state-ownership-repair-and-safety-baseline/02-CONTEXT.md:31]

**Warning signs:** Tests only check a new alias was queued, not whether the room target list was trustworthy. [VERIFIED: codebase grep tests/boop_event_transitions_spec.lua:42]

### Pitfall 5: Splitting Status, Dashboard, and Trace Sources

**What goes wrong:** Status says one blocker, dashboard shows another, and trace records raw GMCP or stale flat values. [VERIFIED: codebase grep src/scripts/boop/boop_ui.lua:329] [VERIFIED: codebase grep src/scripts/boop/boop_runtime.lua:366]

**Why it happens:** UI currently computes blocker strings locally while trace is effect-driven. [VERIFIED: codebase grep src/scripts/boop/boop_ui.lua:329]

**How to avoid:** Render all three from the same owned blocker snapshot and normalized target/movement/gold/queue/gag values. [VERIFIED: codebase grep .planning/REQUIREMENTS.md]

**Warning signs:** A blocker code appears in status but not in trace tests. [VERIFIED: codebase grep tests/boop_trace_spec.lua] [VERIFIED: codebase grep tests/boop_ui_spec.lua]

## Code Examples

Verified patterns from current source and recommended Phase 02 adaptations:

### Existing Owned Domain Initialization

```lua
-- Source: src/scripts/boop/boop_runtime.lua domain defaults.
local DOMAIN_DEFAULTS = {
  combat = { hunting = false, attacking = false, fleeing = false, pullState = nil },
  targeting = { currentTargetId = nil, currentTargetName = nil, denizens = {} },
  gold = { autoGrabPending = false, getPending = false, putPending = false },
  queue = { prequeueEnabled = false, prequeuedStandard = false },
}
```

This excerpt is shortened; the actual file also defines walk, diag, trace, ui, rage, inventory, ih, and gag domains. [VERIFIED: codebase grep src/scripts/boop/boop_runtime.lua:19]

### Existing Runtime Decision Boundary

```lua
-- Source: src/scripts/boop/boop_runtime.lua tickStep pattern.
local context = boop.runtime.context()
local decision = boop.runtime.tickStep(context)
boop.runtime.applyEffects(decision.effects)
```

The planner should place blocker checks before gold, target choice, walk advancement, and combat plan effects in this boundary. [VERIFIED: codebase grep src/scripts/boop/boop_runtime.lua:253] [VERIFIED: codebase grep src/scripts/boop/boop_runtime.lua:366]

### Recommended Flee Cleanup Test Shape

```lua
-- Recommended test shape for tests/boop_safety_spec.lua.
state.queue.prequeuedStandard = true
state.walk.active = true
state.gold.autoGrabPending = true

boop.safety.flee()

assert.is_false(state.queue.prequeuedStandard)
assert.is_false(state.walk.active)
assert.is_false(state.gold.autoGrabPending)
assert.are.equal("wake", sent_commands[1])
```

The factual requirement is cleanup before movement; exact assertion helpers should follow the existing `boop_safety_spec.lua` send-capture style. [VERIFIED: codebase grep tests/boop_safety_spec.lua:58] [VERIFIED: codebase grep .planning/phases/02-state-ownership-repair-and-safety-baseline/02-CONTEXT.md:58]

### Recommended State-Drift Gate Update

```python
# Source pattern: tools/check_release_gates.py KNOWN_FLAT_STATE_ACCESS.
KNOWN_FLAT_STATE_ACCESS = {
    "src/scripts/boop/boop_walk.lua": {},
}
```

The planner should only remove allowances for files actually migrated in Phase 02, then run `python3 tools/check_release_gates.py --check state-drift`. [VERIFIED: codebase grep tools/check_release_gates.py:76] [VERIFIED: local command]

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Flat `boop.state.*` runtime keys | Owned domains under `boop.state.combat`, `targeting`, `gold`, `queue`, `walk`, `diag`, `trace`, `ui`, `rage`, `inventory`, `ih`, and `gag` | Present before Phase 02; enforced by current state contract tests | Phase 02 should delete remaining flat access in owned paths rather than bridge it. [VERIFIED: codebase grep tests/boop_state_contract_spec.lua:1] |
| Ad hoc blocker text in UI | Structured blocker reason codes in owned state | Required by Phase 02 decisions | Enables status/dashboard/trace consistency and stable tests. [VERIFIED: codebase grep .planning/phases/02-state-ownership-repair-and-safety-baseline/02-CONTEXT.md:44] |
| Reconnect support retry only | Support retry plus hard-held automation and retry throttling/backoff | Required by Phase 02 decisions | Prevents attacks/walk/gold/queue from proceeding with incomplete GMCP. [VERIFIED: codebase grep .planning/phases/02-state-ownership-repair-and-safety-baseline/02-CONTEXT.md:89] |
| Target removal clears only target/prequeue subset | Target removal clears target plus all attack intent, then retargets only valid current-room targets | Required by Phase 02 decisions | Prevents stale queued attacks and unsafe retargeting. [VERIFIED: codebase grep src/scripts/boop/boop_events.lua:561] [VERIFIED: codebase grep .planning/phases/02-state-ownership-repair-and-safety-baseline/02-CONTEXT.md:53] |

**Deprecated/outdated:**
- Flat state compatibility in Phase 02-owned files is deprecated by user decision and should not be preserved as compatibility. [VERIFIED: codebase grep .planning/phases/02-state-ownership-repair-and-safety-baseline/02-CONTEXT.md:13]
- Local UI-only blocker strings are outdated for Phase 02 because blockers must be asserted by tests, status, dashboard, and trace from the same source. [VERIFIED: codebase grep .planning/REQUIREMENTS.md]
- Away pull timeout that clears pull state is outdated for Phase 02 because away timeout must remain held/paused until return-to-origin and trustworthy state. [VERIFIED: codebase grep .planning/phases/02-state-ownership-repair-and-safety-baseline/02-CONTEXT.md:82]

## Assumptions Log

No `[ASSUMED]` claims are used as planning facts in this research. All implementation-relevant factual claims are tied to local codebase inspection, local commands, user-provided context, or official Mudlet/IRE documentation. [VERIFIED: local command]

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| — | None | — | — |

## Open Questions (RESOLVED)

1. **Exact blocker field location (RESOLVED)**
   - What we know: The blocker must be owned runtime state and cross automation systems. [VERIFIED: codebase grep .planning/phases/02-state-ownership-repair-and-safety-baseline/02-CONTEXT.md:44]
   - What's unclear: The context does not lock whether the field is `state.combat.blocker`, a new `state.safety` domain, or helper-owned data under another existing domain. [VERIFIED: codebase grep .planning/phases/02-state-ownership-repair-and-safety-baseline/02-CONTEXT.md:112]
   - Recommendation: Use `state.combat.blocker` unless implementation finds a cleaner minimal helper, because `combat` already owns flee, attacking, hunting, and pull state. [VERIFIED: codebase grep src/scripts/boop/boop_runtime.lua:20]
   - Resolution: Phase 02 plans adopt `state.combat.blocker` as the canonical owned blocker home, surfaced through `boop.runtime.blockerSnapshot()`, `boop.runtime.setBlocker(...)`, `boop.runtime.clearBlocker(...)`, and `boop.runtime.shouldHold(system)`. [RESOLVED: .planning/phases/02-state-ownership-repair-and-safety-baseline/02-01-PLAN.md] [RESOLVED: .planning/phases/02-state-ownership-repair-and-safety-baseline/02-03-PLAN.md]

2. **Which attack fallbacks to migrate in Phase 02 (RESOLVED)**
   - What we know: `boop_attacks.lua` still has no-context flat fallbacks for target/spec/shield/wielded state and one trace key. [VERIFIED: codebase grep src/scripts/boop/boop_attacks.lua:39] [VERIFIED: codebase grep src/scripts/boop/boop_attacks.lua:1202]
   - What's unclear: The phase should not become a broad attack-system refactor. [VERIFIED: codebase grep .planning/phases/02-state-ownership-repair-and-safety-baseline/02-CONTEXT.md:17]
   - Recommendation: Migrate only fallbacks directly touched by target-loss cleanup, queue clearing, or trace consistency; defer unrelated attack planning cleanup if not needed for safety. [VERIFIED: codebase grep .planning/phases/02-state-ownership-repair-and-safety-baseline/02-CONTEXT.md:18]
   - Resolution: Phase 02 migrates class/spec, current target id, target shield, rage readiness, wielded item, and opener trace fallback reads in `src/scripts/boop/boop_attacks.lua` only where they are Phase 02-owned or touched by target-loss cleanup, queue clearing, or trace consistency. Genuinely untouched non-Phase-02 fallback entries may remain only when source inspection proves they are outside the task. [RESOLVED: .planning/phases/02-state-ownership-repair-and-safety-baseline/02-04-PLAN.md]

3. **Whether status output changes require README updates now (RESOLVED)**
   - What we know: Project rules require docs/help sync with command-surface changes, and Phase 02 requires targeted help/docs updates if blocker/status fields change. [VERIFIED: codebase grep AGENTS.md:22] [VERIFIED: codebase grep .planning/phases/02-state-ownership-repair-and-safety-baseline/02-CONTEXT.md:72]
   - What's unclear: The exact rendered text is not locked. [VERIFIED: codebase grep .planning/phases/02-state-ownership-repair-and-safety-baseline/02-CONTEXT.md:112]
   - Recommendation: Plan a small help/status docs check after UI tests, not a README-wide release refresh. [VERIFIED: codebase grep .planning/phases/02-state-ownership-repair-and-safety-baseline/02-CONTEXT.md:119]
   - Resolution: Phase 02 includes a focused help/docs sync only if `boop status`, trace, debug, dashboard, or help text changes. The planned scope is `src/scripts/boop/boop_ui_registry.lua`, `README.md`, and `UIDESIGN.md` as needed; README-wide release documentation remains Phase 06 scope. [RESOLVED: .planning/phases/02-state-ownership-repair-and-safety-baseline/02-06-PLAN.md]

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|-------------|-----------|---------|----------|
| Mudlet AppImage | Full Busted-in-Mudlet validation | Yes | 4.20.1 | CI Mudlet workflow if local full run fails for display issues. [VERIFIED: local command `/tmp/Mudlet.AppImage --version`] |
| Muddler | Package build before Mudlet tests | Yes | Unknown; command present but version command failed in non-TTY shell | Use CI build path or invoke `muddle` directly during implementation verification. [VERIFIED: local command `command -v muddle`] |
| Busted | Lua test framework | Yes | 2.3.0 host | Canonical behavior still runs through Mudlet profile. [VERIFIED: local command `busted --version`] |
| LuaRocks | CI dependency install pattern | Yes | 3.13.0 | Existing CI installs `busted` and `lua-cjson` through LuaRocks. [VERIFIED: local command `luarocks --version`] [VERIFIED: codebase grep .github/workflows/main.yml] |
| Python | Release gate script | Yes | 3.14.6 | None needed. [VERIFIED: local command `python3 --version`] |
| jq | Manifest helper/release checks | Yes | 1.8.1 | Python JSON parsing if needed. [VERIFIED: local command `jq --version`] |
| xvfb-run | Headless GUI test support | Yes | command present | CI environment already provisions display support. [VERIFIED: local command `command -v xvfb-run`] |

**Missing dependencies with no fallback:** none found for planning. [VERIFIED: local command]

**Missing dependencies with fallback:** Muddler version is unknown in this non-TTY shell, but the command is present and CI/local build instructions use direct `muddle` invocation. [VERIFIED: local command] [VERIFIED: codebase grep CODEX.md:21]

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | Busted 2.3.0, executed canonically inside Mudlet 4.20.1. [VERIFIED: local command] |
| Config file | No standalone `.busted` config found; Mudlet test bootstrap uses `tests/support/boop_test_helper.lua`. [VERIFIED: local command `rg --files -g ".busted" -g "busted*.lua"`] [VERIFIED: codebase grep tests/support/boop_test_helper.lua:93] |
| Quick run command | `python3 tools/check_release_gates.py --check state-drift` [VERIFIED: local command] |
| Full suite command | `muddle && AUTORUN_BUSTED_TESTS=true TESTS_DIRECTORY="$PWD/tests" QUIT_MUDLET_AFTER_TESTS=true PRETEST_PACKAGE="$PWD/build/boop Hunter.mpackage" /tmp/Mudlet.AppImage --profile "GithubTests" --mirror` [VERIFIED: codebase grep CODEX.md:21] |

### Phase Requirements -> Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|--------------|
| STATE-01 | Owned domains replace flat state in Phase 02 paths. | static + unit | `python3 tools/check_release_gates.py --check state-drift` and Mudlet Busted for `tests/boop_state_contract_spec.lua` | Yes. [VERIFIED: codebase grep tools/check_release_gates.py:76] [VERIFIED: codebase grep tests/boop_state_contract_spec.lua:1] |
| STATE-02 | GMCP missing/reconnect/partial data creates visible blockers and holds automation. | integration | Full Mudlet suite with expanded `tests/boop_event_transitions_spec.lua` | Existing file; Wave 0 expansion needed. [VERIFIED: codebase grep tests/boop_event_transitions_spec.lua:179] |
| STATE-03 | Trace/status/dashboard report the same canonical owned values. | integration/UI text | Full Mudlet suite with expanded `tests/boop_trace_spec.lua` and `tests/boop_ui_spec.lua` | Existing files; Wave 0 expansion needed. [VERIFIED: codebase grep tests/boop_trace_spec.lua] [VERIFIED: codebase grep tests/boop_ui_spec.lua] |
| SAFE-01 | Flee cleanup clears queue/prequeue/walk/gold/attack intent before escape movement. | unit/integration | Full Mudlet suite with expanded `tests/boop_safety_spec.lua` | Existing file; Wave 0 expansion needed. [VERIFIED: codebase grep tests/boop_safety_spec.lua:58] |
| SAFE-03 | Target disappearance clears attack intent and retargets only valid current-room targets, with pull exception. | integration | Full Mudlet suite with expanded `tests/boop_event_transitions_spec.lua` and `tests/boop_pull_spec.lua` | Existing files; Wave 0 expansion needed. [VERIFIED: codebase grep tests/boop_event_transitions_spec.lua:42] [VERIFIED: codebase grep tests/boop_pull_spec.lua] |

### Sampling Rate

- **Per task commit:** `python3 tools/check_release_gates.py --check state-drift` plus the smallest affected Mudlet Busted spec when available. [VERIFIED: codebase grep tools/check_release_gates.py:76]
- **Per wave merge:** Full Mudlet Busted suite command from `CODEX.md`. [VERIFIED: codebase grep CODEX.md:21]
- **Phase gate:** `python3 tools/check_release_gates.py --check versions --check manifests --check state-drift` and full Mudlet Busted suite green before `$gsd-verify-work`. [VERIFIED: codebase grep CODEX.md:28]

### Wave 0 Gaps

- [ ] `tests/boop_walk_spec.lua` currently exists as an empty placeholder; add focused tests for owned blocker reads and unsafe advancement holds without full walker route behavior. [VERIFIED: codebase grep tests/boop_walk_spec.lua] [VERIFIED: codebase grep .planning/phases/02-state-ownership-repair-and-safety-baseline/02-CONTEXT.md:103]
- [ ] `tests/boop_safety_spec.lua` needs cleanup-before-flee-send assertions for queue, prequeue, walk, gold, and attack/rage intent. [VERIFIED: codebase grep tests/boop_safety_spec.lua:58]
- [ ] `tests/boop_event_transitions_spec.lua` needs GMCP blocker/backoff tests and target-loss cleanup/valid-retarget/pull-exception tests. [VERIFIED: codebase grep tests/boop_event_transitions_spec.lua:179]
- [ ] `tests/boop_trace_spec.lua` and `tests/boop_ui_spec.lua` need canonical blocker/status/dashboard assertions once the blocker snapshot exists. [VERIFIED: codebase grep tests/boop_trace_spec.lua] [VERIFIED: codebase grep tests/boop_ui_spec.lua]
- [ ] `tools/check_release_gates.py` state-drift allowlist must be tightened after each migrated file. [VERIFIED: codebase grep tools/check_release_gates.py:76]

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|------------------|
| V2 Authentication | No | No user auth surface exists in Phase 02 package runtime. [VERIFIED: codebase grep README.md] |
| V3 Session Management | No | No web/session management surface exists in Phase 02 package runtime. [VERIFIED: codebase grep README.md] |
| V4 Access Control | No | Operator commands are local Mudlet aliases; Phase 02 does not add roles or remote authorization. [VERIFIED: codebase grep README.md] |
| V5 Input Validation | Yes | Validate GMCP completeness and owned room/target state before automation; command-fragment validation remains Phase 04 unless an immediate bypass is exposed. [VERIFIED: codebase grep .planning/phases/02-state-ownership-repair-and-safety-baseline/02-CONTEXT.md:29] [VERIFIED: codebase grep .planning/ROADMAP.md:45] |
| V6 Cryptography | No | Phase 02 does not introduce cryptography or secret handling. [VERIFIED: codebase grep .planning/ROADMAP.md:23] |

### Known Threat Patterns for Mudlet Automation

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Acting on stale or incomplete GMCP room/target state | Tampering / Safety impact | Fail closed with owned blocker state until prompt plus relevant GMCP state arrives. [VERIFIED: codebase grep .planning/phases/02-state-ownership-repair-and-safety-baseline/02-CONTEXT.md:29] |
| Stale queued attack after target disappears | Tampering / Safety impact | Clear current target and all attack intent, then retarget only valid current-room targets. [VERIFIED: codebase grep .planning/phases/02-state-ownership-repair-and-safety-baseline/02-CONTEXT.md:53] |
| Flee movement while other automation intent remains active | Safety impact | Cleanup queue/prequeue/walk/gold/attack intent before escape movement and require explicit operator re-enable. [VERIFIED: codebase grep .planning/phases/02-state-ownership-repair-and-safety-baseline/02-CONTEXT.md:48] |
| Warning spam during repeated bad GMCP events | Denial of service / operator overload | Rate-limit live warnings and move detail to status/trace. [VERIFIED: codebase grep .planning/phases/02-state-ownership-repair-and-safety-baseline/02-CONTEXT.md:35] |
| Command fragment injection | Tampering | Keep broad validation for Phase 04; do not expand Phase 02 except where cleanup reveals a direct safety bypass. [VERIFIED: codebase grep .planning/ROADMAP.md:45] |

## Sources

### Primary (HIGH confidence)

- `src/scripts/boop/boop_runtime.lua` - owned domain defaults, context mapping, tick/effect architecture. [VERIFIED: codebase grep]
- `src/scripts/boop/boop_events.lua` - GMCP handlers, room/target updates, reconnect retry, target removal, pull room transitions. [VERIFIED: codebase grep]
- `src/scripts/boop/boop_safety.lua` - auto-flee side effects and current cleanup gaps. [VERIFIED: codebase grep]
- `src/scripts/boop/boop_walk.lua` - remaining flat walk/blocker state usage. [VERIFIED: codebase grep]
- `src/scripts/boop/boop_ui.lua` - status/dashboard blocker rendering and pull lifecycle. [VERIFIED: codebase grep]
- `src/scripts/boop/boop_attacks.lua` - no-context flat fallbacks and attack-planning state. [VERIFIED: codebase grep]
- `tests/boop_*_spec.lua` and `tests/support/boop_test_helper.lua` - current Busted coverage and helper patterns. [VERIFIED: codebase grep]
- `tools/check_release_gates.py` - state-drift gate and current allowlist. [VERIFIED: codebase grep]
- `.planning/phases/02-state-ownership-repair-and-safety-baseline/02-CONTEXT.md`, `.planning/REQUIREMENTS.md`, `.planning/ROADMAP.md`, `.planning/STATE.md` - locked decisions, requirement mapping, and phase boundaries. [VERIFIED: codebase grep]
- `AGENTS.md`, `CODEX.md`, `README.md`, `DESIGN.md`, `UIDESIGN.md` - repository workflow, package architecture, command surface, and UI conventions. [VERIFIED: codebase grep]

### Secondary (MEDIUM confidence)

- Mudlet Supported Protocols manual - GMCP event/table behavior and module enabling concepts. [CITED: https://wiki.mudlet.org/w/Manual%3ASupported_Protocols]
- Mudlet Networking Functions manual - `sendGMCP()` behavior and examples. [CITED: https://wiki.mudlet.org/w/Manual%3ANetworking_Functions]
- Mudlet Event Engine manual - `registerAnonymousEventHandler()` and event dispatch model. [CITED: https://wiki.mudlet.org/w/Manual%3AEvent_Engine]
- Mudlet Miscellaneous Functions manual - partial GMCP/MSDP table merge support via `setMergeTables()`. [CITED: https://wiki.mudlet.org/w/Manual%3AMiscellaneous_Functions]
- IRE Nexus GMCP documentation - `Core.Supports.Set`/`Add`, `Char.Skills.Get`, and character data packet conventions. [CITED: https://nexus.ironrealms.com/GMCP]

### Tertiary (LOW confidence)

- None used for implementation facts. [VERIFIED: local command]

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - verified from local commands, CI/workflow files, and repo workflow documentation. [VERIFIED: local command] [VERIFIED: codebase grep]
- Architecture: HIGH - verified from source files and tests in the repository. [VERIFIED: codebase grep]
- GMCP protocol details: MEDIUM - verified from official Mudlet and IRE documentation, but live reconnect behavior is intentionally deferred to Phase 06. [CITED: https://wiki.mudlet.org/w/Manual%3ASupported_Protocols] [CITED: https://nexus.ironrealms.com/GMCP]
- Pitfalls: HIGH for codebase-specific pitfalls and MEDIUM where tied to external GMCP partial-update behavior. [VERIFIED: codebase grep] [CITED: https://wiki.mudlet.org/w/Manual%3AMiscellaneous_Functions]

**Research date:** 2026-07-10
**Valid until:** 2026-08-09 for codebase architecture; re-check Mudlet/IRE docs if GMCP support semantics are changed before implementation. [VERIFIED: local command]

## RESEARCH COMPLETE

Research is complete for planning Phase 02. The planner should create tasks around owned blocker state, walk ownership migration, cleanup-before-command safety behavior, target-loss retarget gating, trace/status/dashboard consistency, and state-drift gate tightening. [VERIFIED: codebase grep .planning/REQUIREMENTS.md]
