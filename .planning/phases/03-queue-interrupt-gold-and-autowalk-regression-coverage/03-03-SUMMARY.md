---
phase: 03-queue-interrupt-gold-and-autowalk-regression-coverage
plan: "03"
subsystem: runtime-safety
tags: [lua, mudlet, pull, generations, blockers, regression-tests]
requires:
  - phase: 03-queue-interrupt-gold-and-autowalk-regression-coverage
    plan: "01"
    provides: exact owner-keyed blockers, deterministic snapshots, and shared room observation
  - phase: 03-queue-interrupt-gold-and-autowalk-regression-coverage
    plan: "02"
    provides: generation-owned first-terminal lifecycle pattern and stale callback rejection
provides:
  - Generation-owned pull records with exact blocker and timer ownership
  - First-terminal-wins completion across return, origin timeout, and timeout-away recovery
  - Pull lifecycle regression coverage proving saved enabled configuration remains unchanged
affects: [03-04, 03-08, 03-09]
tech-stack:
  added: []
  patterns:
    - Pull generation is captured by every asynchronous callback and compared before mutation.
    - Timeout away from origin changes the exact owner's reason but does not release the hold.
    - Pull lifecycle state never mutates or persists the operator's enabled configuration.
key-files:
  created:
    - .planning/phases/03-queue-interrupt-gold-and-autowalk-regression-coverage/03-03-SUMMARY.md
  modified:
    - src/scripts/boop/boop_runtime.lua
    - src/scripts/boop/boop_ui.lua
    - src/scripts/boop/boop_events.lua
    - tests/boop_runtime_spec.lua
    - tests/boop_pull_spec.lua
    - tests/boop_event_transitions_spec.lua
    - mfile
    - src/scripts/boop/boop_init.lua
    - CODEX.md
key-decisions:
  - "Represent each pull as one exact record keyed by monotonic pullGeneration and pull:<generation> blocker ownership."
  - "Route every terminal outcome through completePull, which compares generation, marks terminal, cancels its timer, and clears only its exact owner."
  - "Treat timeout while away as recovery state pull_timeout_away; retain the hold until a later matching return completes the generation."
  - "Keep enabled configuration entirely outside pull lifecycle control, with zero setEnabled or saveConfig calls."
patterns-established:
  - "Pull terminal path: compare generation, mark terminal, cancel exact timer, clear exact owner, then remove the active record and emit one result."
  - "Pull timeout recovery: transition outbound or away to timed_out_away under the same owner, then wait for matching Room.Info return."
requirements-completed: [SAFE-02]
coverage:
  - id: D1
    description: Pull dispatch allocates one exact generation record, owner, timer, and unchanged command without mutating enabled configuration.
    requirement: SAFE-02
    verification:
      - kind: unit
        ref: "tests/boop_pull_spec.lua#allocates one exact owner, record, timer, and unchanged command"
        status: pass
      - kind: integration
        ref: "tests/boop_pull_spec.lua in real Mudlet/Busted"
        status: unknown
    human_judgment: true
    rationale: "Exact deterministic side-effect counts pass locally, while final Mudlet timer and room-event behavior remains assigned to the parent-owned exact-HEAD CI gate."
  - id: D2
    description: Return and timeout callbacks are generation-checked and first-terminal-wins, including stale N callbacks after pull N+1 starts.
    requirement: SAFE-02
    verification:
      - kind: unit
        ref: "tests/boop_pull_spec.lua (return/timeout order, stale generation, duplicate room, and duplicate timeout cases)"
        status: pass
      - kind: unit
        ref: "tests/boop_event_transitions_spec.lua (target removal while exact pull owner is active)"
        status: pass
      - kind: integration
        ref: "focused pull and room-event specs in real Mudlet/Busted"
        status: unknown
    human_judgment: true
    rationale: "Generation and side-effect assertions are deterministic, but authoritative Mudlet callback delivery remains pending exact-final-HEAD CI."
  - id: D3
    description: Timeout away from origin changes the exact blocker to pull_timeout_away and preserves all automation holds until matching return.
    requirement: SAFE-02
    verification:
      - kind: unit
        ref: "tests/boop_pull_spec.lua#keeps the exact owner held after timeout away until matching return"
        status: pass
      - kind: other
        ref: "focused three-spec host Busted run: 48 successes, 0 failures, 0 errors"
        status: pass
      - kind: integration
        ref: "live pull timeout-away and return check"
        status: unknown
    human_judgment: true
    rationale: "Recovery ownership is fully asserted in tests; live movement confirmation remains intentionally routed to $gsd-verify-work 03."
  - id: D4
    description: Fresh runtime resets independently restore pullGeneration zero and pullState false.
    requirement: SAFE-02
    verification:
      - kind: unit
        ref: "tests/boop_runtime_spec.lua (pull generation and record reset assertions)"
        status: pass
      - kind: other
        ref: "luac syntax and release-gate verification"
        status: pass
    human_judgment: false
duration: 15m
completed: 2026-07-26
status: complete
---

# Phase 03 Plan 03: Generation-Owned Pull Lifecycle Summary

**Pull now owns one generation-scoped hold from dispatch through return or timeout recovery, rejects stale callbacks, and never rewrites the operator's saved enabled setting.**

## Performance

- **Duration:** 15m
- **Started:** 2026-07-26T13:33:05Z
- **Completed:** 2026-07-26T13:47:07Z
- **Tasks:** 2
- **Files modified:** 9

## Accomplishments

- Added exact pull regression contracts for record shape, owner identity, command and timer counts, both terminal orders, duplicate events, stale callbacks, unrelated owners, and enabled-config immutability.
- Replaced saved enabled toggles and broad timeout cleanup with a monotonic pull generation, exact `pull:<generation>` owner, captured timer callbacks, and one first-terminal completion API.
- Preserved the safety hold after timeout away from origin by transitioning the same owner to `pull_timeout_away`, then releasing only after a matching room return.
- Kept target-removal behavior compatible with an active pull without replacing its exact owner or releasing unrelated automation state.

## Task Commits

Each task was committed atomically:

1. **Task 1: Pin pull ownership, config immutability, and callback ordering** - `6f878db` (test)
2. **Task 2: Implement generation-owned pull and exact room release** - `3e9fc10` (feat)

**Plan metadata:** committed separately with this summary and state closeout.

## Files Created/Modified

- `.planning/phases/03-queue-interrupt-gold-and-autowalk-regression-coverage/03-03-SUMMARY.md` - Records implementation, evidence, deviations, and the downstream pull contract.
- `src/scripts/boop/boop_runtime.lua` - Adds the canonical `pullGeneration` default beside the inactive pull record.
- `src/scripts/boop/boop_ui.lua` - Owns pull allocation, captured timeout handling, exact blocker transitions, and first-terminal completion.
- `src/scripts/boop/boop_events.lua` - Applies generation-checked departure and return transitions while preserving target-removal intent during pull.
- `tests/boop_runtime_spec.lua` - Covers pull defaults and keeps inherited generation-owned interrupt fixtures exact.
- `tests/boop_pull_spec.lua` - Covers dispatch, return, timeout-away recovery, stale generations, duplicate callbacks, owner isolation, and config immutability.
- `tests/boop_event_transitions_spec.lua` - Pins target-removal behavior against the exact active pull record and owner.
- `mfile` - Advances package title/version through the required Task 1 and Task 2 patch increments.
- `src/scripts/boop/boop_init.lua` - Keeps `boop.version` synchronized at `0.1.401`.
- `CODEX.md` - Keeps the package-version checkpoint synchronized at `0.1.401`.

## Decisions Made

- `state.combat.pullState` is either `false` or one exact record containing only `active`, `generation`, `blockerOwner`, `phase`, `terminal`, `originRoom`, `direction`, `returnDirection`, `command`, and `timeoutTimer`.
- `completePull(generation, reason, opts)` is the sole terminal owner-release path; wrong generations and already-terminal records are no-ops.
- A timeout at origin completes immediately, while a timeout away keeps the exact owner active under `pull_timeout_away` until a matching room return completes it as `returned_after_timeout`.
- Pull dispatch and completion do not call `setEnabled`, do not call `saveConfig`, and do not store a restoration snapshot.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Isolated pull timer assertions from skill-probe timers**
- **Found during:** Task 2 focused pull verification
- **Issue:** The deterministic pull fixture learned `Harry` but left two unrelated Occultist skill probes unresolved, so their lookup timers polluted the exact one-pull-timer assertion.
- **Fix:** Marked `chaosgate` and `fluctuate` explicitly unlearned in the fixture so the test captures only lifecycle effects under test.
- **Files modified:** `tests/boop_pull_spec.lua`
- **Verification:** Focused pull spec completed with 13 successes, 0 failures, and 0 errors.
- **Committed in:** `3e9fc10`

**2. [Rule 3 - Blocking] Migrated inherited runtime fixtures to generation-owned operation state**
- **Found during:** Task 2 focused runtime and event verification
- **Issue:** Two inherited runtime fixtures still seeded the pre-Plan-03-02 diagnose boolean and allowed unrelated skill-probe timers, preventing exact aggregate verification.
- **Fix:** Seeded the canonical diagnose operation and exact interrupt blocker, and explicitly marked the unrelated Occultist skill probes unlearned.
- **Files modified:** `tests/boop_runtime_spec.lua`
- **Verification:** Focused runtime and event specs completed with 35 successes, 0 failures, and 0 errors.
- **Committed in:** `3e9fc10`

**3. [Rule 1 - Bug] Corrected inconsistent GSD closeout metadata**
- **Found during:** State and roadmap closeout
- **Issue:** The state handlers advanced the plan correctly but emitted an incorrect frontmatter percentage, a stale body progress bar and activity description, phase-less decision labels, and malformed roadmap status spacing.
- **Fix:** Reconciled `STATE.md` to 17/23 plans and 74%, labeled Plan 03-03 decisions as Phase 03, refreshed the activity text, and restored the roadmap row format.
- **Files modified:** `.planning/STATE.md`, `.planning/ROADMAP.md`
- **Verification:** State reads Plan 4 of 9 with 17/23 plans and 74%; roadmap reads 3/9 with `In Progress` status.
- **Committed in:** Plan metadata closeout commit

---

**Total deviations:** 3 auto-fixed (Rule 1: 1, Rule 3: 2)
**Impact on plan:** The changes repaired deterministic test setup and planning metadata required to verify and close the plan; package behavior and feature scope were unchanged.

## Issues Encountered

- `/tmp/Mudlet.AppImage` is unavailable, so the real-Mudlet focused and full Busted runs could not execute locally. The focused host harness passes all 48 plan-relevant specs; authoritative Mudlet execution remains assigned to the parent-owned exact-final-HEAD CI gate.
- A supplemental broad host run reached 498 successes but also reported 65 environment errors because the host harness lacks Mudlet's `db` API, plus one unrelated pre-existing gold expectation failure. Those results are not treated as product failures or as substitutes for the real-Mudlet suite.

## Verification

- `luac -p src/scripts/boop/boop_runtime.lua src/scripts/boop/boop_ui.lua src/scripts/boop/boop_events.lua tests/boop_runtime_spec.lua tests/boop_pull_spec.lua tests/boop_event_transitions_spec.lua` - pass
- Focused host Busted run for the three plan specs with package preload - 48 successes, 0 failures, 0 errors
- `tests/boop_pull_spec.lua` focused run - 13 successes, 0 failures, 0 errors
- `tests/boop_runtime_spec.lua` plus `tests/boop_event_transitions_spec.lua` focused run - 35 successes, 0 failures, 0 errors
- `muddle` - pass; built package metadata at `0.1.401`
- `python3 tools/check_release_gates.py` - pass for versions, manifests, and state drift before each task commit and during plan-wide verification
- Static acceptance scans - pass for exact generation identifiers, terminal reasons, timeout-away code, owner syntax, and absence of pull-path persisted enable mutation
- Real Mudlet/Busted focused execution - pending parent exact-final-HEAD CI because the local AppImage is unavailable

## Known Stubs

None. Added empty capture tables, empty room guards, `false` inactive records, and `nil` timer fields are intentional lifecycle or test-fixture state; no placeholder data flows to the operator.

## User Setup Required

None - no external service configuration is required.

## Next Phase Readiness

- Plan 03-04 can build staged gold ownership on the exact blocker registry without pull timeout races releasing unrelated systems.
- Plans 03-08 and 03-09 can rely on generation-scoped pull ownership, config immutability, and the complete return/timeout/stale-callback matrix.
- Live pull return and timeout-away checks remain intentionally assigned to `$gsd-verify-work 03`.
- The parent must still push the immutable final Phase 03 HEAD and run `tools/wait_for_exact_ci.sh` after all Phase 03 mutations; this executor intentionally did not push or claim terminal CI authority.

## Self-Check: PASSED

- The summary and every listed runtime, event, UI, test, metadata, and version file exist.
- Task commits `6f878db` and `3e9fc10` are present in repository history.
- Coverage metadata classifies cleanly with four deliverables and no errors.
- Final syntax, Muddler, and release gates pass with all package version fields synchronized at `0.1.401`.

---
*Phase: 03-queue-interrupt-gold-and-autowalk-regression-coverage*
*Completed: 2026-07-26*
