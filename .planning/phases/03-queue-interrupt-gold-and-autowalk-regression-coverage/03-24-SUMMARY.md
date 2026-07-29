---
phase: 03-queue-interrupt-gold-and-autowalk-regression-coverage
plan: 24
subsystem: diag-gold-queue-integration
tags: [lua, mudlet, native-queue, diag, gold, ownership, timeout]

requires:
  - phase: 03-23
    provides: exact generation-owned gold displacement, replay, and explicit-evidence timeout contract
provides:
  - valid two-command diag native queue replacement
  - exact transfer of sent pickup or pack ownership before destructive queue clearing
  - one ordinary replay tick for either prompt/result or timeout terminal ownership
  - real-diag regression matrix for stale and fresh gold timer orderings
affects: [phase-03-uat, diag, gold, release-verification]

tech-stack:
  added: []
  patterns:
    - destructive diag queue replacement transfers exact gold dispatch ownership before its first native clear
    - only a successful first-terminal diag timeout may invoke the ordinary replay tick

key-files:
  created: []
  modified:
    - tests/boop_diag_spec.lua
    - tests/boop_diag_timeout_spec.lua
    - tests/boop_gold_retry_spec.lua
    - src/scripts/boop/boop_ui.lua
    - mfile
    - src/scripts/boop/boop_init.lua
    - CODEX.md

key-decisions:
  - "Transfer the exact sent gold dispatch after the diag blocker exists and immediately before clearqueue all."
  - "Give only result-then-prompt diag timeouts the new exact-success replay tick, preserving existing prompt-only interrupt timeout behavior."
  - "Keep Plan 03-23 gold replay, fresh-timeout, explicit-evidence, and target-loss production contracts unchanged."

patterns-established:
  - "Real diag integration tests apply every send to the deterministic native queue model."
  - "Terminal race matrices assert owner, generation, phase, replay count, warning count, and exact invalidation."

requirements-completed: [SAFE-02, SAFE-04, WALK-02]

coverage:
  - id: G03-8-D1
    description: "Diag emits clearqueue all followed by queue addclearfull freestand diagnose with no invalid native queue command."
    requirement: SAFE-02
    verification:
      - kind: integration
        ref: "tests/boop_diag_spec.lua#requires a real zero-argument result trigger before diagnose can complete on prompt"
        status: pass
      - kind: integration
        ref: "tests/boop_diag_timeout_spec.lua#retains a terminal tombstone and releases only the timed-out owner"
        status: pass
    human_judgment: false
  - id: G03-8-D2
    description: "Real diag transfers pickup and pack dispatches before native replacement and replays each exactly once through either terminal winner."
    requirement: SAFE-04
    verification:
      - kind: integration
        ref: "tests/boop_gold_retry_spec.lua#real diag collision matrix"
        status: pass
    human_judgment: false
  - id: G03-8-D3
    description: "Fresh replay timeout remains nonterminal and visible without duplicate sends, then movement or disable releases the exact owner once."
    requirement: SAFE-04
    verification:
      - kind: integration
        ref: "tests/boop_gold_retry_spec.lua#real diag fresh-timeout and invalidation matrix"
        status: pass
    human_judgment: false
  - id: G03-8-D4
    description: "Explicit replayed pickup evidence advances to one freestand pack command and explicit put evidence leaves no gold or interrupt operation."
    requirement: WALK-02
    verification:
      - kind: integration
        ref: "tests/boop_gold_retry_spec.lua#real diag replay advances pickup through explicit get and put evidence"
        status: pass
    human_judgment: false

duration: 5m
completed: 2026-07-29
status: complete
---

# Phase 03 Plan 24: Real Diag Gold Recovery Summary

**Real diag now transfers active gold dispatch ownership before valid global native queue replacement, then replays pickup or packing exactly once through the first terminal owner while fresh replay timeouts remain fail-closed.**

## Performance

- **Duration:** 5m
- **Started:** 2026-07-29T07:10:35Z
- **Completed:** 2026-07-29T07:15:25Z
- **Tasks:** 1
- **Files modified:** 7

## Accomplishments

- Replaced rejected bare `queue clear` with exact `clearqueue all`, retaining `queue addclearfull freestand diagnose` as the second ordered command.
- Wired real diag to transfer the current sent pickup or pack dispatch to its exact `interrupt:<generation>` owner before either destructive native command.
- Made a winning diag timeout perform one ordinary tick; prompt/result and timeout losers remain no-ops through the existing first-terminal and tombstone contracts.
- Added eight real diag collision permutations covering pickup/pack, prompt-result/timeout winners, and both old gold-timeout orderings.
- Proved fresh replay timeouts retain exact state without duplicate sends, then release pickup once on movement or packing once through real disable.
- Synchronized package version `0.1.447`.

## Task Commits

1. **Task 1: Integrate diag with exact gold displacement and completion, then bump the synchronized package version** - `5069e94` (fix)

## Files Created/Modified

- `tests/boop_diag_spec.lua` - Applies real diag sends to the native queue model and proves exact command order, global replacement, validation, FIFO ownership, and prompt/result completion.
- `tests/boop_diag_timeout_spec.lua` - Proves a winning exact timeout performs one tick and late result/prompt signals preserve first-terminal ownership.
- `tests/boop_gold_retry_spec.lua` - Adds the real diag pickup/pack terminal-order matrix, fresh-timeout holds, exact invalidation, and explicit get-to-put completion.
- `src/scripts/boop/boop_ui.lua` - Transfers gold displacement ownership, sends valid native syntax, and gates the timeout replay tick on exact completion.
- `mfile` - Synchronizes package title and version at `0.1.447`.
- `src/scripts/boop/boop_init.lua` - Synchronizes runtime package version at `0.1.447`.
- `CODEX.md` - Updates the synchronized package-version checkpoint.

## Decisions Made

- Gold displacement is attempted only after the interrupt blocker is authoritative and immediately before `clearqueue all`; unrelated Lua queue, walker, target, and attack ownership is untouched.
- The new timeout-side tick is limited to `result_then_prompt` diag operations. Existing prompt-only queued interrupt timeout semantics remain unchanged.
- `boop_events.lua` was not modified. Plan 03-23's dispatch identity, one-replay, nonterminal fresh-timeout, movement/disable invalidation, and post-Plan-22 target-loss recovery contracts remain the production authority.

## Automated Evidence

- Test-first RED:
  - `tests/boop_diag_spec.lua`: 2 successes / 1 failure for rejected bare queue syntax.
  - `tests/boop_diag_timeout_spec.lua`: 1 success / 2 failures for the missing timeout-owned tick.
  - `tests/boop_gold_retry_spec.lua`: 18 successes / 8 failures because real diag had not transferred pickup or pack displacement ownership.
- Final focused and adjacent Busted:
  - `tests/boop_diag_spec.lua`: 3 successes.
  - `tests/boop_diag_timeout_spec.lua`: 3 successes.
  - `tests/boop_gold_retry_spec.lua`: 26 successes.
  - `tests/boop_interrupt_spec.lua`: 3 successes.
  - `tests/boop_event_transitions_spec.lua`: 55 successes, preserving target-loss recovery.
  - `tests/boop_gold_spec.lua`: 9 successes.
  - Total: 99 successes, 0 failures, 0 errors.
- `luac -p` passed for every modified Lua source and spec.
- `git diff --check` passed.
- `python3 tools/check_release_gates.py` passed versions, manifests, and state-drift immediately before commit.
- Direct `muddle` built `boop Hunter 0.1.447` successfully.

## Deviations from Plan

None - plan executed exactly as written.

## Known Stubs

None. The stub scan found only pre-existing operator diagnostics that report unavailable optional runtime facilities; no placeholder or unwired data path was introduced.

## Issues Encountered

None.

## User Setup Required

None.

## Next Phase Readiness

- G-03-8 has complete deterministic coverage and is ready for the plan's live Mudlet evidence pass.
- The parent session still owns complete packaged Mudlet/AppImage verification and the immutable-final-HEAD push/exact-SHA CI gate. No push was performed, as requested.

## Self-Check: PASSED

- All seven planned task files and this summary exist.
- Task commit `5069e94` exists and contains no tracked-file deletions.
- Focused Busted, adjacent target-loss/interrupt/gold suites, Lua syntax, diff hygiene, release gates, and direct `muddle` verification passed.
