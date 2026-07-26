---
phase: 03-queue-interrupt-gold-and-autowalk-regression-coverage
plan: "02"
subsystem: runtime-safety
tags: [lua, mudlet, interrupts, fifo, tombstones, regression-tests]
requires:
  - phase: 03-queue-interrupt-gold-and-autowalk-regression-coverage
    plan: "01"
    provides: exact-owner blocker registry, deterministic snapshots, and independent owned-domain defaults
provides:
  - Generation-owned interrupt dispatch with one exact blocker owner, timer, and active operation
  - First-terminal-wins completion for prompt, diagnose result-plus-prompt, and timeout paths
  - Zero-argument diagnose FIFO correlation with retained timeout tombstones
affects: [03-03, 03-08, 03-09]
tech-stack:
  added: []
  patterns:
    - Interrupt generation and exact owner are lifecycle identity; timer cancellation is cleanup only.
    - Diagnose result and prompt evidence consume only the ordered FIFO head.
    - Timeout tombstones absorb stale zero-argument output before newer evidence can advance.
key-files:
  created:
    - .planning/phases/03-queue-interrupt-gold-and-autowalk-regression-coverage/03-02-SUMMARY.md
  modified:
    - src/scripts/boop/boop_ui.lua
    - src/scripts/boop/boop_runtime.lua
    - src/scripts/boop/boop_events.lua
    - tests/boop_interrupt_spec.lua
    - tests/boop_diag_spec.lua
    - tests/boop_diag_timeout_spec.lua
    - mfile
    - src/scripts/boop/boop_init.lua
    - CODEX.md
key-decisions:
  - "Represent the active interrupt as one state.diag.operation record keyed by a monotonic generation and exact interrupt:<generation> blocker owner."
  - "Keep diagnose output correlation independent from the active operation: zero-argument result and prompt paths inspect only evidenceQueue[1]."
  - "Retain a timed-out diagnose record as a terminal tombstone until its late result plus prompt marks and drains that exact FIFO head."
  - "Keep state.diag hold, awaitPrompt, timeoutTimer, and label as derived compatibility display fields; terminal ownership belongs to completeInterrupt."
patterns-established:
  - "Interrupt terminal path: compare generation, mark terminal, preserve timeout evidence when needed, clear exact owner, then emit one terminal result."
  - "Diagnose evidence: enqueue before dispatch, mark FIFO head on result, consume FIFO head on prompt, never scan or infer from the current operation."
requirements-completed: [SAFE-02]
coverage:
  - id: D1
    description: Prompt-mode interrupts send and schedule once, reject same or different repeats, and terminate once in either prompt/timeout order.
    requirement: SAFE-02
    verification:
      - kind: unit
        ref: "tests/boop_interrupt_spec.lua (host Busted focused run: 9/9 plan specs passed)"
        status: pass
      - kind: other
        ref: "lua -e prompt interrupt generation/repeat/terminal diagnostic"
        status: pass
      - kind: integration
        ref: "tests/boop_interrupt_spec.lua in real Mudlet/Busted"
        status: unknown
    human_judgment: true
    rationale: "The deterministic host checks pass, but authoritative prompt/timer behavior remains assigned to the exact-final-HEAD Mudlet CI run."
  - id: D2
    description: Diagnose result and prompt evidence use the unchanged zero-argument trigger boundary and FIFO-head-only correlation.
    requirement: SAFE-02
    verification:
      - kind: unit
        ref: "tests/boop_diag_spec.lua and tests/boop_diag_timeout_spec.lua (focused host Busted)"
        status: pass
      - kind: other
        ref: "DIAG_REAL_TRIGGER_COMPLETION_PASS and DIAG_FIFO_TOMBSTONE_DIAGNOSTIC_PASS"
        status: pass
      - kind: integration
        ref: "focused diagnose specs in real Mudlet/Busted"
        status: unknown
    human_judgment: true
    rationale: "The real trigger scripts were executed directly and the focused specs pass, but Mudlet's runtime remains CI-authoritative."
  - id: D3
    description: Diagnose timeout releases only its exact owner and retains a tombstone that absorbs stale output without mutating a newer generation.
    requirement: SAFE-02
    verification:
      - kind: unit
        ref: "tests/boop_diag_timeout_spec.lua#absorbs N's late zero-argument result and prompt without mutating diagnose N+1"
        status: pass
      - kind: other
        ref: "lua -e N timeout -> N+1 -> stale result -> prompt diagnostic"
        status: pass
      - kind: integration
        ref: "tests/boop_diag_timeout_spec.lua in real Mudlet/Busted"
        status: unknown
    human_judgment: true
    rationale: "Exact side-effect counts pass in deterministic execution; final Mudlet confirmation is deferred to the parent-owned terminal CI gate."
  - id: D4
    description: Fresh resets deep-copy diagnose generation, operation, and evidence queue defaults independently.
    requirement: SAFE-02
    verification:
      - kind: unit
        ref: "tests/boop_diag_spec.lua#materializes independent generation, operation, and evidence defaults on reset"
        status: pass
      - kind: other
        ref: "DIAG_DEFAULT_ISOLATION_PASS"
        status: pass
    human_judgment: false
duration: 10m
completed: 2026-07-26
status: complete
---

# Phase 03 Plan 02: Generation-Owned Interrupt and Diagnose FIFO Summary

**Generation-owned interrupts now reject repeats, release only their exact hold once, and correlate zero-argument diagnose output through FIFO timeout tombstones that cannot advance a newer operation.**

## Performance

- **Duration:** 10m
- **Started:** 2026-07-26T13:18:21Z
- **Completed:** 2026-07-26T13:28:29Z
- **Tasks:** 2
- **Files modified:** 9

## Accomplishments

- Added exact regression contracts for all prompt-mode interrupt commands, same/different repeats, both prompt/timeout terminal orders, unrelated-owner retention, and zero server queue removal.
- Added normal and stale diagnose ordering coverage through the unchanged detail/perfect zero-argument trigger scripts, including FIFO head blocking and independent reset defaults.
- Replaced shared interrupt booleans with a monotonic operation generation, exact `interrupt:<generation>` blocker owner, stable timer capture, and one first-terminal API.
- Added diagnose evidence enqueueing, FIFO-head-only result marking, prompt consumption, and retained timeout tombstones so stale output cannot mutate or release N+1.

## Task Commits

Each task was committed atomically:

1. **Task 1: Add repeat and terminal-order interrupt contracts** - `4adccda` (test)
2. **Task 2: Implement the generation-owned interrupt lane** - `10405c0` (feat)

**Plan metadata:** committed separately with this summary and state closeout.

## Files Created/Modified

- `.planning/phases/03-queue-interrupt-gold-and-autowalk-regression-coverage/03-02-SUMMARY.md` - Records the implementation, evidence, deviations, and downstream contract.
- `src/scripts/boop/boop_ui.lua` - Allocates interrupt generations, exact owners, operation records, diagnose evidence, timers, and idempotent dispatch.
- `src/scripts/boop/boop_runtime.lua` - Owns interrupt defaults, first-terminal completion, FIFO result marking, tombstone prompt consumption, and exact-owner release.
- `src/scripts/boop/boop_events.lua` - Delegates the zero-argument diagnose trigger boundary to FIFO-head result marking.
- `tests/boop_interrupt_spec.lua` - Covers all prompt-mode commands, repeats, both terminal orders, exact sends/timers, and unrelated owners.
- `tests/boop_diag_spec.lua` - Covers default isolation, prompt-before-result, real zero-argument completion, duplicates, and FIFO head blocking.
- `tests/boop_diag_timeout_spec.lua` - Covers timeout tombstones, exact-owner release, stale N evidence absorption, and late no-ops.
- `mfile` - Advances package title/version through the required Task 1 and Task 2 patch increments.
- `src/scripts/boop/boop_init.lua` - Keeps `boop.version` synchronized at `0.1.399`.
- `CODEX.md` - Keeps the package-version checkpoint synchronized at `0.1.399`.

## Decisions Made

- A request is pending only while `state.diag.operation` is the current nonterminal operation; same and different repeats report the active name without touching sends, timers, owners, or prequeue state.
- `completeInterrupt(generation, reason)` is the only terminal owner-release path. It marks terminal before timer cleanup, owner clear, derived-field reset, output, and trace.
- Diagnose result handlers never derive identity from the current operation. They mark only the oldest evidence record and mirror `operation.resultSeen` only after an exact generation and mode comparison.
- A prompt cannot scan past missing result evidence. A result-seen timeout tombstone is drained without tick, warning, OK/info, trace, send, timer, owner, or active-operation mutation.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Re-ran Muddler with the required PTY**
- **Found during:** Plan-wide package verification
- **Issue:** The repository's container-backed `muddle` wrapper rejected the initial non-interactive invocation because its container requires a TTY.
- **Fix:** Re-ran the same build through a PTY without changing source or build configuration.
- **Files modified:** None
- **Verification:** Muddler completed successfully and produced the `boop Hunter 0.1.399` package.
- **Committed in:** N/A (verification environment only)

**2. [Rule 1 - Bug] Corrected inconsistent GSD closeout metadata**
- **Found during:** State and roadmap closeout
- **Issue:** The state handlers advanced the plan correctly but emitted a stale body progress bar, an incorrect frontmatter percentage, phase-less decision labels, and malformed roadmap status spacing.
- **Fix:** Reconciled `STATE.md` to 16/23 plans and 70%, labeled Plan 03-02 decisions as Phase 03, refreshed the last-activity text, and restored the roadmap row format.
- **Files modified:** `.planning/STATE.md`, `.planning/ROADMAP.md`
- **Committed in:** Plan metadata closeout commit

---

**Total deviations:** 2 auto-fixed (Rule 1: 1, Rule 3: 1)
**Impact on plan:** The deviations adapted the build invocation and repaired planning metadata; implementation scope and package contents were unchanged.

## Issues Encountered

- `/tmp/Mudlet.AppImage` is unavailable, so the real-Mudlet focused Busted run could not execute locally. The 9 focused specs pass in the host Busted harness and direct Lua diagnostics, while authoritative Mudlet execution remains assigned to the parent-owned exact-final-HEAD GitHub Actions gate.

## Verification

- `luac -p src/scripts/boop/boop_ui.lua src/scripts/boop/boop_runtime.lua src/scripts/boop/boop_events.lua tests/boop_interrupt_spec.lua tests/boop_diag_spec.lua tests/boop_diag_timeout_spec.lua` - pass
- Focused host Busted run for the three plan specs with a minimal package preload - 9 successes, 0 failures, 0 errors
- Direct prompt interrupt generation/repeat/terminal diagnostic - pass
- Direct normal diagnose completion through `Diag_Result_Perfect.lua` - pass
- Direct N timeout → N+1 → stale result → prompt FIFO tombstone diagnostic - pass
- Direct diagnose default/reset isolation diagnostic - pass
- `muddle` - pass; built package metadata at `0.1.399`
- `python3 tools/check_release_gates.py` - pass for versions, manifests, and state drift before each task commit and during plan-wide verification
- Real Mudlet/Busted focused execution - pending parent exact-final-HEAD CI because the local AppImage is unavailable

## Known Stubs

None. Added empty tables, `false` flags, empty strings, and `nil` timer fields are intentional owned-state defaults or deterministic test-capture initializers; no placeholder data flows to the operator.

## User Setup Required

None - no external service configuration is required.

## Next Phase Readiness

- Plan 03-03 can apply the same generation/first-terminal pattern to pull ownership without changing interrupt APIs.
- Plans 03-08 and 03-09 can rely on exact interrupt owners and the complete repeat/race matrix when validating cross-lifecycle holds and final Mudlet behavior.
- The parent must still push the immutable final Phase 03 HEAD and run `tools/wait_for_exact_ci.sh` after all Phase 03 mutations; this executor intentionally did not push or claim terminal CI authority.

## Self-Check: PASSED

- The summary and every listed runtime, event, UI, test, metadata, and version file exist.
- Task commits `4adccda` and `10405c0` are present in repository history.
- Coverage metadata classifies cleanly with all four dimensions represented and no errors.
- Final release gates pass with all package version fields synchronized at `0.1.399`.

---
*Phase: 03-queue-interrupt-gold-and-autowalk-regression-coverage*
*Completed: 2026-07-26*
