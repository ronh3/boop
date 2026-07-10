# Phase 02: State Ownership Repair and Safety Baseline - Context

**Gathered:** 2026-07-10T22:32:51Z
**Status:** Ready for planning

<domain>
## Phase Boundary

Phase 02 repairs boop Hunter's safety-critical runtime state ownership and unsafe-state behavior. It should move room, target, flee, pull, queue, gold, GMCP recovery, and walk-blocker decisions onto canonical owned state domains, then make automation fail closed when the state needed for safe hunting is incomplete.

This phase is not a broad rewrite and does not own full autowalk behavior coverage, command-fragment validation, final release/live validation, or compact-gag fixture expansion. Those remain assigned to later roadmap phases. Phase 02 may split or reshape code where it directly reduces state-ownership risk.

</domain>

<decisions>
## Implementation Decisions

### State Migration Strictness
- **D-01:** Remaining flat `boop.state.*` access in Phase 02-owned paths is a defect, not compatibility behavior.
- **D-02:** Expand the state-drift gate so migrated files fail CI if flat `boop.state.*` access returns.
- **D-03:** If Phase 02 touches a file for state ownership, remove all flat-state access in that file or explicitly keep the untouched domain out of Phase 02 scope before the plan lands.
- **D-04:** Migrate test helpers and fixtures for Phase 02 behavior so tests seed and assert owned domains only.
- **D-05:** Prioritize safety-critical runtime flows first: room, target, flee, pull, queue, and gold before dashboard or trace polish.
- **D-06:** Broad internal cleanup is allowed only when it directly reduces state-ownership risk. Useful module-boundary cleanup is acceptable; unrelated refactors are not.
- **D-07:** Rewrite tests that assert old flat-state behavior to owned-domain behavior.
- **D-08:** Remove obsolete flat keys from initialization, defaults, and helper reset paths when they belong to Phase 02-owned domains.

### Unsafe-State Blockers
- **D-09:** When GMCP or game state is incomplete, boop should hard-hold automation: attacks, walking, queue execution, and gold actions stop until the missing state is trustworthy.
- **D-10:** Hard-hold output should be concise by default: one compact `[WARN]` blocker line, with details available through status and trace.
- **D-11:** Missing-state holds clear only after both a prompt and the relevant GMCP state arrive.
- **D-12:** Room changes start a fresh blocker evaluation and may clear old blocker reasons when the new room state is trustworthy.
- **D-13:** Explicit missing-state coverage in Phase 02 is core safety only: missing or partial room, current target, target removal, flee state, and GMCP IRE support.
- **D-14:** Rate-limit repeated blocker warnings. Show the first warning and suppress repeats until the reason changes or the operator asks for status.
- **D-15:** Missing-state hard holds are temporary runtime holds and must not change saved `boop.config.enabled`.
- **D-16:** Phase 02 hard holds block automation only. Do not broadly block manual operator commands.
- **D-17:** Store structured blocker reason codes and affected systems in owned state so tests, status, and trace can inspect them.

### Flee And Target Loss Policy
- **D-18:** Auto-flee cancels all combat intent before movement is sent: queued standard/rage attacks, prequeue, target-call intent, and pending attack plans.
- **D-19:** Auto-flee also cancels walking and gold intent: stop walk advancement and clear pending gold actions before movement is sent.
- **D-20:** Flee does not automatically re-enable hunting. The operator must explicitly turn boop back on.
- **D-21:** When the current target disappears from GMCP room items, clear current target and all attack intent, then retarget only from valid room targets.
- **D-22:** Active pull/room transitions are a narrow target-loss exception: preserve target state while pull lifecycle owns temporary away/return behavior.
- **D-23:** When pull recovery ends by return or timeout, apply normal target-loss cleanup if the target is still not present.
- **D-24:** Target-loss cleanup prints one concise `[WARN]` line per loss event.
- **D-25:** Auto-flee cleanup prints a single summary line; details belong in trace/status.
- **D-26:** Tests should assert cleanup happens before the flee command is sent.
- **D-27:** Target-loss retargeting may happen in the same tick when GMCP room items are current and valid targets exist.

### Status And Trace Surface
- **D-28:** `boop status` and the main dashboard should show a compact blocker summary: current blocker code/reason, affected systems, and whether resume waits on prompt, GMCP, or manual action.
- **D-29:** Trace captures state transitions by default: blocker enter/exit, target-loss cleanup, flee cleanup, pull holds, GMCP recovery, and retarget decisions. Targeted per-tick details are only for explicit trace/debug mode.
- **D-30:** Status and trace should show normalized owned-state values by default: the state boop actually uses for decisions, not raw GMCP dumps.
- **D-31:** Live hunting output stays minimal: one line on transitions and no repeated output while held.
- **D-32:** Update command help/docs for new blocker/status fields where relevant.
- **D-33:** Status should display both stable reason code and short human label, for example `target_lost -- target left room`.
- **D-34:** Phase 02 UAT should include one focused checkpoint for compact blocker/status behavior; detailed reason-code coverage belongs in automated tests.

### Pull Lifecycle Boundaries
- **D-35:** Pull owns movement lifecycle plus a narrow active-pull target-loss exception. Normal target cleanup resumes when pull ends.
- **D-36:** If pull timeout fires while the character is away from the origin room, keep boop paused/held; only consider resume after return-to-origin and trustworthy state.
- **D-37:** Use structured pull blocker reasons only when pull is actively holding automation.
- **D-38:** Do not change pull command validation in Phase 02 unless a lifecycle fix reveals an immediate bypass. Command validation remains Phase 04 scope.

### GMCP Recovery Policy
- **D-39:** When `gmcp.IRE`, `gmcp.IRE.Target`, or `gmcp.IRE.Display` is missing after reconnect/status events, retry supports immediately and hard-hold target-dependent automation until required IRE modules are present.
- **D-40:** Force one immediate recovery retry, then use short throttle/backoff while state remains missing.
- **D-41:** Show one concise warning when entering GMCP recovery; carry details in status/trace.
- **D-42:** Add focused synthetic GMCP recovery tests in Phase 02. Full live reconnect validation remains Phase 06.

### Autowalk Scope Boundary
- **D-43:** Phase 02 migrates walk blocker reads and prevents unsafe advancement now; full walker start/stop/move behavior suite remains Phase 03.
- **D-44:** Walk blockers cover target, flee, GMCP, and pull now. Gold/diag timing depth waits for Phase 03 unless already touched by owned-state migration.
- **D-45:** Add focused blocker tests wherever the existing harness is cleanest; avoid broader walker start/stop/move scenarios in Phase 02.
- **D-46:** Do not change `demonnicAutoWalker` install/status behavior unless required to expose a Phase 02 blocker reason.

### Agent Discretion
- Choose the cleanest test file or harness for Phase 02 blocker tests. File location matters less than keeping scope on owned-state and safety behavior.
- Choose exact reason-code names, but keep them stable, documented, and suitable for tests and pasted diagnostics.
- Choose small module extractions only when they directly lower state-migration risk.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Project And Roadmap
- `.planning/PROJECT.md` - Brownfield pre-1.0 hardening goal, core value, active requirements, and out-of-scope boundaries.
- `.planning/REQUIREMENTS.md` - Phase 02 requirements `STATE-01`, `STATE-02`, `STATE-03`, `SAFE-01`, and `SAFE-03`.
- `.planning/ROADMAP.md` - Phase 02 goal, dependencies, success criteria, and later-phase boundaries.
- `.planning/STATE.md` - Current milestone position and Phase 02 focus.
- `.planning/phases/01-release-gates-and-state-contracts/01-CONTEXT.md` - Phase 01 decisions, especially strict local/CI gates and deferral of behavior repairs to later phases.

### Codebase Intel
- `.planning/codebase/ARCHITECTURE.md` - Runtime state domains, event flow, domain module boundaries, and integration points.
- `.planning/codebase/CONCERNS.md` - Known runtime state ownership drift, autowalk blocker drift, and state-domain migration coverage gaps.
- `.planning/codebase/TESTING.md` - Busted/Mudlet test patterns, helper reset behavior, stubs, and where focused state/blocker tests can live.

### Repo Workflow
- `AGENTS.md` - Repository-local startup, versioning, and workflow rules.
- `CODEX.md` - Codex workflow guidance, synchronized version checkpoint, local release gates, and Mudlet/Busted path.
- `tools/check_release_gates.py` - Existing release gate that Phase 02 should extend for migrated-file flat-state enforcement.
- `.github/workflows/main.yml` - CI path that runs release gates, Muddler, and Mudlet Busted.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `src/scripts/boop/boop_runtime.lua` - Defines `DOMAIN_DEFAULTS`, `boop.runtime.ensureState()`, `boop.runtime.context()`, and runtime effects. Phase 02 should extend owned blocker state here.
- `src/scripts/boop/boop_state.lua` - State initialization seam that should stop creating obsolete flat keys for Phase 02-owned domains.
- `src/scripts/boop/boop_events.lua` - GMCP room/target/status/prompt handlers and current state-transition behavior.
- `src/scripts/boop/boop_safety.lua` - Flee threshold parsing and flee command behavior.
- `src/scripts/boop/boop_walk.lua` - External walker integration and blocker reads.
- `src/scripts/boop/boop_ui.lua` and `src/scripts/boop/boop_ui_registry.lua` - Status/dashboard/help surfaces and command routing.
- `tests/support/boop_test_helper.lua` - Shared test reset/fixture surface that must seed owned domains, not obsolete flat state.
- `tests/boop_event_transitions_spec.lua`, `tests/boop_pull_spec.lua`, `tests/boop_safety_spec.lua`, `tests/boop_runtime_spec.lua`, and existing runtime/UI specs - Likely homes for focused Phase 02 behavior tests.

### Established Patterns
- Package code shares the global `boop` namespace and does not use Lua `require`.
- Runtime decisions are best represented as context/effects before Mudlet side effects.
- Mudlet side effects are testable with Busted stubs for `send`, `tempTimer`, `killTimer`, `sendGMCP`, and output helpers.
- User-facing output should use compact `[OK]`, `[INFO]`, `[WARN]`, and `[ERR]` style through existing boop utilities/theme.
- CI already runs `python3 tools/check_release_gates.py`, Muddler, and Busted inside a real Mudlet profile.

### Integration Points
- Extend `tools/check_release_gates.py --check state-drift` as files migrate to owned domains.
- Add structured blocker state under owned runtime domains and surface it through status/dashboard/trace.
- Wire missing GMCP/IRE support recovery through existing `boop.requestCoreSupports()` behavior without introducing repeated GMCP spam.
- Keep pull lifecycle state separate from targeting except for the narrow active-pull target-loss exception.
- Keep autowalk changes to owned blocker reads and unsafe advancement prevention; leave full walker behavior coverage to Phase 03.

</code_context>

<specifics>
## Specific Ideas

- Reason-code examples: `missing_room`, `target_lost`, `waiting_prompt`, `gmcp_ire_missing`, `pull_away`, `pull_timeout_away`, and `waiting_return`.
- Status output should pair code and label, for example `target_lost -- target left room`.
- One focused UAT checkpoint should verify that compact blocker/status output explains why automation is held.
- Flee tests should prove cleanup happens before the flee command is sent.

</specifics>

<deferred>
## Deferred Ideas

- Full walker start/stop/move behavior and external walker event coverage remain Phase 03 scope.
- Command-fragment validation, including broader pull input hardening, remains Phase 04 scope unless a lifecycle repair exposes an immediate bypass.
- Full live reconnect validation remains Phase 06 scope.
- README-wide release documentation can stay Phase 06 unless Phase 02 changes an operator workflow that must be documented immediately.

</deferred>

---

*Phase: 02-State Ownership Repair and Safety Baseline*
*Context gathered: 2026-07-10T22:32:51Z*
