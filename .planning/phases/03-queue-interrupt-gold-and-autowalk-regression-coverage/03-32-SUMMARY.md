---
phase: 03-queue-interrupt-gold-and-autowalk-regression-coverage
plan: 32
subsystem: queue-gold-room-observation
tags: [mudlet, lua, gmcp, gold, queueing, room-authority, tdd]

# Dependency graph
requires:
  - phase: 03-31
    provides: same-observation standard candidate authority and synchronized package 0.1.474
  - phase: 03-26
    provides: pack quarantine and consume-before-dispatch recovery
provides:
  - exact empty-string GMCP item refreshes with one IRE/MCCP transport flush per request
  - transport-only whitespace exclusion before outbound command causality
  - full-queue pickup deadlines anchored to the first authoritative execution opportunity
  - integrated request-to-get-to-confirmed-pickup-to-put regression coverage
  - synchronized package 0.1.475
affects: [03-33, G-03-23, live-uat, exact-sha-ci]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - frame every autonomous item refresh through one exact request-and-flush helper
    - arm full-pickup result deadlines once at a full-ready prompt rather than at enqueue time
    - keep room-fence, generation, owner, dispatch, and quarantine identities authoritative end to end

key-files:
  created:
    - .planning/phases/03-queue-interrupt-gold-and-autowalk-regression-coverage/03-32-SUMMARY.md
  modified:
    - src/scripts/boop/boop_events.lua
    - tests/boop_gold_retry_spec.lua
    - tests/boop_event_transitions_spec.lua
    - tests/boop_walk_spec.lua
    - tests/boop_gold_spec.lua
    - tests/boop_lifecycle_spec.lua
    - tests/boop_pull_spec.lua
    - tests/boop_tick_spec.lua
    - mfile
    - src/scripts/boop/boop_init.lua
    - CODEX.md

key-decisions:
  - "Emit Char.Items.Inv/Room with the documented empty-string body and immediately follow each request with one whitespace transport flush."
  - "Reject trimmed-empty transport sends before every outbound, Rage, gold, and movement attribution path while preserving all real command contamination."
  - "Treat the first full-ready prompt as the pickup execution opportunity; initial, retry, and displacement-replayed pickups share this rule while packing retains independent freestand timing."
  - "Reuse the existing room fence, gold owner/generation, and pack quarantine instead of adding another coordinator or public API."

patterns-established:
  - "Protocol-versus-command separation: required Mudlet transport flushes are observable in protocol tests but invisible to command causality."
  - "Execution-window timing: a full-queue command owns state at enqueue but owns a result deadline only after it can execute."

requirements-completed: [SAFE-04, WALK-02, WALK-03]

coverage:
  - id: D1
    description: "Every autonomous Inv/Room refresh carries the exact empty-string body and one immediate transport flush without advancing outbound command sequence."
    requirement: SAFE-04
    verification:
      - kind: integration
        ref: "tests/boop_gold_retry_spec.lua#protocol chronology"
        status: pass
    human_judgment: false
  - id: D2
    description: "Only the active current-room/current-generation fence accepts reversed Inv/Room responses; stale and duplicate responses have zero settlement or dispatch effect."
    requirement: WALK-02
    verification:
      - kind: integration
        ref: "tests/boop_gold_retry_spec.lua#integrated request/get/put chronology"
        status: pass
    human_judgment: false
  - id: D3
    description: "Full-queue pickup timeouts begin once at the first full-ready prompt for initial, retry, and replay dispatches, never while balances are unavailable."
    requirement: SAFE-04
    verification:
      - kind: integration
        ref: "tests/boop_gold_retry_spec.lua#execution-aware pickup timing"
        status: pass
    human_judgment: false
  - id: D4
    description: "One exact pickup consumes eligible quarantine once, sends one independent freestand put, and one put terminal releases the operation without disturbing unrelated owners."
    requirement: WALK-03
    verification:
      - kind: integration
        ref: "tests/boop_gold_retry_spec.lua#get-confirm-put adapter chronology"
        status: pass
    human_judgment: false

# Metrics
duration: 22m
completed: 2026-08-04
status: complete
---

# Phase 03 Plan 32: Autonomous GMCP Refresh and Full-Queue Gold Completion Summary

**Autonomous item refreshes now use exact framed-and-flushed GMCP requests, while full-queue gold pickups wait for a real execution opportunity before starting their bounded get-confirm-put deadline.**

## Performance

- **Duration:** 22 min
- **Started:** 2026-08-04T21:47:10Z
- **Completed:** 2026-08-04T22:08:44Z
- **Tasks:** 1
- **Files modified:** 11 package/test files plus planning closeout artifacts

## Accomplishments

- Added a private request helper that sends exact `Char.Items.Inv ""` and `Char.Items.Room ""` bodies and immediately follows each with Mudlet's required `send(" ")` IRE/MCCP flush.
- Classified trimmed-empty sends before outbound-ledger, Rage, gold old-put, and movement observation, so transport flushes cannot contaminate command ownership while real manual and differently owned commands still do.
- Added explicit pickup execution state so initial, retry, and displacement-replayed `queue add full get sovereigns` operations arm one generation/dispatch-owned result timeout only at the first authoritative full-ready prompt.
- Proved the real handler chronology from stale/current Inv/Room fences through one full get, exact pickup adapter, consume-before-dispatch quarantine handoff, one freestand put, and one terminal release.
- Synchronized `mfile.title`, `mfile.version`, `boop.version`, and the CODEX checkpoint at package 0.1.475 and built the package successfully.

## Task Commits

Each task was committed atomically:

1. **Task 1: Repair autonomous GMCP refresh and prove full-queue get-confirm-put completion** - `80bda87` (fix)

**Plan metadata:** This summary and required tracking metadata are committed separately as the planning-only closeout.

## TDD Evidence

- **RED:** The new integrated regression produced 30 successes and 3 expected failures: transport whitespace advanced outbound causality, the room refresh lacked the required framed/flushed request, and pickup operations lacked execution-window state.
- **GREEN:** `tests/boop_gold_retry_spec.lua` passed 34/34, and the required combined gold/event/walk suite passed 149/149 after the production repair and compatibility fixture updates.
- The plan required one green package commit, so RED test work and the minimal implementation were committed together in `80bda87` after the complete gate passed.

## Files Created/Modified

- `src/scripts/boop/boop_events.lua` - Adds exact GMCP request flushing, transport-only send classification, and execution-aware full-pickup timeout ownership.
- `tests/boop_gold_retry_spec.lua` - Adds protocol order, active-fence, queue-readiness, retry/replay, adapter, quarantine, stale-timer, and one-get/one-put regressions.
- `tests/boop_event_transitions_spec.lua` - Keeps cross-lifecycle request and pickup-timer assertions exact under the new protocol contract.
- `tests/boop_walk_spec.lua` - Updates walker refresh expectations for explicit request bodies and transport flushing.
- `tests/boop_gold_spec.lua` - Updates gold fence request expectations and filters transport-only sends from command captures.
- `tests/boop_lifecycle_spec.lua` - Keeps lifecycle command capture focused on non-whitespace commands.
- `tests/boop_pull_spec.lua` - Keeps pull command capture focused on non-whitespace commands.
- `tests/boop_tick_spec.lua` - Opens the authoritative pickup execution window before timeout assertions and ignores transport-only sends.
- `mfile` - Sets package title and version to 0.1.475.
- `src/scripts/boop/boop_init.lua` - Sets runtime `boop.version` to 0.1.475.
- `CODEX.md` - Advances the synchronized package-version checkpoint to 0.1.475.
- `.planning/phases/03-queue-interrupt-gold-and-autowalk-regression-coverage/03-32-SUMMARY.md` - Records implementation, verification, deviations, and handoff evidence.

## Decisions Made

- A request is valid only when both Mudlet transport functions are available; each exact GMCP call and its flush are emitted as one helper-owned pair.
- Empty or whitespace-only sends are transport, not player/system commands. They return before every command-causality observer; no non-empty command receives this exemption.
- A pickup operation records queue ownership immediately but starts its result deadline only on the first full-ready prompt. Duplicate or not-ready prompts cannot restart, expire, or retry it.
- Packing remains independently timed from its freestand dispatch, and the existing exact room fence, generation, dispatch, blocker, and quarantine identities remain unchanged.
- No public API, trigger text, trigger manifest, command help, walker install behavior, package dependency, or generated artifact changed.

## Verification

- `env BOOP_REPO_ROOT="$PWD" TESTS_DIRECTORY="$PWD/tests" busted --helper=tests/support/boop_host_busted_helper.lua tests/boop_gold_retry_spec.lua tests/boop_event_transitions_spec.lua tests/boop_walk_spec.lua` - 149 successes, 0 failures, 0 errors.
- `tests/boop_gold_retry_spec.lua` alone - 34 successes, 0 failures, 0 errors.
- Compatibility suites for gold, lifecycle, pull, and timeout-under-owner behavior - 40 successes, 0 failures, 0 errors across the directly affected cases.
- `luac -p` across both modified source files and all seven modified Lua specs - passed.
- `python3 -m json.tool src/triggers/boop/Gold/triggers.json` - passed; the verification-only manifest remained unchanged.
- `git diff --check` - passed.
- `python3 tools/check_release_gates.py` - versions, manifests, and state-drift passed both before and after staging.
- `muddle` - Muddler 1.1.0 built `build/boop Hunter.mpackage` for version 0.1.475 successfully; generated outputs remained ignored and unmodified in git.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Updated legacy protocol and timing fixtures outside the five-file task list**
- **Found during:** Task 1 GREEN verification
- **Issue:** The required `send(" ")` transport became observable to existing command-capture stubs, explicit empty-string request bodies changed exact request assertions, and enqueue-time pickup timer fixtures now needed the authoritative ready prompt. Leaving those fixtures unchanged blocked the plan's required event/walk suite and broader directly affected regressions.
- **Fix:** Filtered only trimmed-empty transport from command arrays, made request expectations exact, and opened the pickup execution window before assertions that intentionally exercise its result timer.
- **Files modified:** `tests/boop_event_transitions_spec.lua`, `tests/boop_walk_spec.lua`, `tests/boop_gold_spec.lua`, `tests/boop_lifecycle_spec.lua`, `tests/boop_pull_spec.lua`, `tests/boop_tick_spec.lua`
- **Commit:** `80bda87`

**2. [Rule 1 - Bug] Corrected the integrated regression's removed-owner expectation**
- **Found during:** Task 1 GREEN verification
- **Issue:** The new test initially expected a removed exact blocker lookup to return boolean `false`, while the established helper correctly returns `nil` for an absent owner.
- **Fix:** Asserted absence with `assert.is_nil` without changing runtime behavior.
- **Files modified:** `tests/boop_gold_retry_spec.lua`
- **Commit:** `80bda87`

**3. [Rule 1 - Bug] Repaired SDK progress and phase labels during closeout**
- **Found during:** Plan closeout tracking update
- **Issue:** `state.update-progress` returned the correct 46/52 and 88% values but wrote 33% to STATE frontmatter, retained stale Plan 03-31 activity/velocity prose, and `state.add-decision` emitted `Phase ?` labels.
- **Fix:** Restored disk-derived 88% progress, Plan 03-32 activity and metrics, Plan 03-33 next position, and normalized all four decision labels to Phase 03. The ROADMAP SDK result was also spacing-normalized without changing its 32/38 count.
- **Files modified:** `.planning/STATE.md`, `.planning/ROADMAP.md`
- **Commit:** Planning-only closeout commit

---

**Total deviations:** 3 auto-fixed (1 blocking fixture update, 2 bugs)
**Impact on plan:** Additional package files only preserve existing regression semantics under the required protocol/timing change, and planning metadata was corrected to disk-derived completion state; no package behavior or scope beyond G-03-23 was added.

## Known Stubs

None. The added empty values are intentional protocol bodies, lifecycle state defaults, or isolated test fixtures; all production paths are wired to real handlers and runtime state.

## Issues Encountered

- The sandbox cannot access the Docker daemon, and Muddler requires a TTY. The same repository build was rerun through the approved host TTY and completed successfully.
- The repository's known all-specs-in-one-process host-helper limitation and six pre-existing aggregate-owner `boop_tick_spec.lua` expectations remain documented in the phase deferred ledger; starting HEAD reproduced them, and no unrelated behavior was weakened.

## Authentication Gates

None.

## User Setup Required

None - no external service configuration or package installation is required.

## Next Phase Readiness

- Plan 03-33 can proceed from package 0.1.475 with G-03-23 covered by deterministic request, fence, execution-window, and get-confirm-put regressions.
- Live Test 9 remains required before Phase 03 can pass; this plan does not claim installed-Mudlet or live-Achaea verification.
- Push and exact-final-HEAD CI remain deferred to the parent after all remaining Phase 03 repository mutations.

## Self-Check: PASSED

- All 11 package/test files and this summary exist.
- Task commit `80bda87` exists in repository history.

---
*Phase: 03-queue-interrupt-gold-and-autowalk-regression-coverage*
*Completed: 2026-08-04*
