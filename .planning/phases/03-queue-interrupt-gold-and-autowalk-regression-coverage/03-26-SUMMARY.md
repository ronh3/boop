---
phase: 03-queue-interrupt-gold-and-autowalk-regression-coverage
plan: 26
subsystem: gold-pack-recovery
tags: [lua, mudlet, gold, quarantine, inventory-authority, prompt-grace]

requires:
  - phase: 03-25
    provides: monotonic outbound sequence and exact queue-dispatch provenance
  - phase: 03-24
    provides: one-replay displaced gold ownership and stale-callback contracts
provides:
  - exact nonblocking quarantine for exhausted inventory-owned pack replays
  - ready/result prompt window with generation-guarded bounded grace
  - causally newer complete inventory authority and late-old-activity invalidation
  - consume-before-dispatch safe opportunity for one fresh inventory-owned put
affects: [phase-03-uat, plan-03-29, plan-03-30, gold, queueing, walking]

tech-stack:
  added: []
  patterns:
    - release exact operation ownership before retaining diagnostic-only provenance
    - separate complete inventory evidence from room-fence wield projection
    - consume eligibility before creating a fresh operation generation

key-files:
  created: []
  modified:
    - src/scripts/boop/boop_runtime.lua
    - src/scripts/boop/boop_events.lua
    - src/scripts/boop/boop_ui_registry.lua
    - tests/boop_gold_retry_spec.lua
    - tests/boop_ui_registry_spec.lua
    - README.md
    - mfile
    - src/scripts/boop/boop_init.lua
    - CODEX.md

key-decisions:
  - "Retain exhausted pack provenance in gold.packQuarantine, never in gold.operation, compatibility pending fields, blockers, or walk ownership."
  - "Treat raw old put results as diagnostic-only until a qualifying inventory snapshot exists; activity after qualification invalidates that snapshot."
  - "Allow a later put only from an explicit safe gold opportunity after consuming eligibility and rechecking configuration, inventory, standard lifecycle, and every aggregate subsystem gate."

patterns-established:
  - "Quarantine chronology: first ready prompt opens, the following prompt closes, one exact grace callback expires, and only a later complete inventory generation may qualify."
  - "Inventory authority: accepted inventory responses update wield projection; complete duplicate lists may advance quarantine evidence without reviving drained room-response epochs."
  - "Non-overlap: prompt, timer, inventory, status, movement, and raw result observations never dispatch by themselves."

requirements-completed: [SAFE-02, SAFE-04, WALK-02, WALK-03]

coverage:
  - id: G03-23-D1
    description: "A real diag-displaced pack replay times out once, warns once, releases its exact owner, and preserves unrelated owners in a nonblocking quarantine."
    requirement: WALK-02
    verification:
      - kind: integration
        ref: "tests/boop_gold_retry_spec.lua#real diag releases replay-timed-out pack"
        status: pass
      - kind: integration
        ref: "tests/boop_gold_retry_spec.lua#releases a replay-timed-out pack into one non-owning quarantine"
        status: pass
    human_judgment: false
  - id: G03-23-D2
    description: "Not-ready prompts cannot mature quarantine; ready/result prompts, bounded grace, and a causally newer complete inventory list are all required."
    requirement: SAFE-04
    verification:
      - kind: integration
        ref: "tests/boop_gold_retry_spec.lua#keeps prolonged not-ready prompts nonblocking and immature"
        status: pass
      - kind: integration
        ref: "tests/boop_gold_retry_spec.lua#qualifies only post-window post-grace inventory evidence without sending"
        status: pass
    human_judgment: false
  - id: G03-23-D3
    description: "Raw overlap evidence is diagnostic-only, while late old activity invalidates qualifying inventory and requires a newer complete List."
    requirement: SAFE-02
    verification:
      - kind: integration
        ref: "tests/boop_gold_retry_spec.lua#treats raw old results during overlap as diagnostic-only"
        status: pass
      - kind: integration
        ref: "tests/boop_gold_retry_spec.lua#invalidates qualified inventory after late old pack activity"
        status: pass
    human_judgment: false
  - id: G03-23-D4
    description: "One explicit safe opportunity consumes eligibility before one fresh put and remains held by enabled, autogold, pack, standard, combat, queue, gold, and walk gates."
    requirement: WALK-03
    verification:
      - kind: integration
        ref: "tests/boop_gold_retry_spec.lua#consumes eligible packing only after every runtime gate releases"
        status: pass
      - kind: integration
        ref: "tests/boop_gold_retry_spec.lua#cancels quarantine grace on disable and ignores stale callbacks"
        status: pass
      - kind: integration
        ref: "tests/boop_gold_retry_spec.lua#cancels quarantine grace on reconnect and ignores stale callbacks"
        status: pass
    human_judgment: false

duration: 19m
completed: 2026-08-04
status: complete
---

# Phase 03 Plan 26: Bounded Gold Pack Quarantine Summary

**Exhausted interrupt-displaced pack replays now release every owned subsystem into an exact nonblocking quarantine, then permit at most one later put only after prompt/grace closure, newer inventory proof, and a fresh safe opportunity.**

## Performance

- **Duration:** 19m
- **Started:** 2026-08-04T10:04:05Z
- **Completed:** 2026-08-04T10:22:42Z
- **Tasks:** 1
- **Files modified:** 9

## Accomplishments

- Replaced the replay-timed-out inventory-pack indefinite hold with one exact warning, terminal release, and a provenance-rich quarantine that owns no blocker, gold operation, compatibility pending state, or walker reservation.
- Added a nonblocking chronology that opens at the first authoritative freestand-ready prompt, closes at the following prompt, expires one generation-guarded grace, and accepts only a causally newer complete inventory List.
- Made no-sovereigns inventory resolve silently, sovereigns-present inventory record eligibility without dispatch, and late old put invocation/result evidence invalidate the qualifying snapshot.
- Added a consume-before-dispatch safe opportunity that rechecks enabled/autogold/pack settings, current inventory, active gold and standard lifecycles, plus all combat/queue/gold/walk blockers before creating one fresh pack generation.
- Preserved pickup replay behavior, unrelated-owner isolation, room-response-fence wield semantics, reconnect/disable cancellation, and stale timer no-ops.
- Updated only gold recovery README/help text and synchronized package version `0.1.470`.

## Task Commits

1. **Task 1: Implement, document, verify, and package bounded gold quarantine** - `b8ff548` (feat)

## Files Created/Modified

- `src/scripts/boop/boop_runtime.lua` - Owns exact pack-quarantine identity, prompt/grace chronology, inventory generations, late-activity invalidation, resolution, and consume-before-dispatch state.
- `src/scripts/boop/boop_events.lua` - Creates quarantine before exact release, observes prompts/outbound/inventory evidence, protects new pickup paths from overlap, and emits one later gated put.
- `src/scripts/boop/boop_ui_registry.lua` - Explains bounded release, nonautomatic prompts, newer inventory proof, and the later safe opportunity in gold help.
- `tests/boop_gold_retry_spec.lua` - Covers real diag orderings, exact release, prolonged not-ready state, grace chronology, no-gold resolution, raw/late old activity, all gates, one put, disable/reconnect, and unchanged pickup behavior.
- `tests/boop_ui_registry_spec.lua` - Locks the bounded gold-recovery help contract.
- `README.md` - Documents the operator-facing nonblocking quarantine and safe later put contract.
- `mfile` - Synchronizes package title and version at `0.1.470`.
- `src/scripts/boop/boop_init.lua` - Synchronizes runtime package version at `0.1.470`.
- `CODEX.md` - Updates the synchronized package-version checkpoint.

## Decisions Made

- Quarantine is diagnostic/evidence state, not another operation: it retains old owner, generation, dispatch/provenance, native put, pack, outbound sequence, release inventory generation, prompt window, grace token/timer, qualifying inventory, and terminal disposition without owning any subsystem.
- Raw old success/failure before qualification is traced without mutating quarantine. The same evidence after qualification invalidates inventory authority and advances the minimum required complete inventory generation.
- Inventory lists keep two concerns separate: current accepted responses continue to own wield projection, while a complete duplicate inventory List can provide newer quarantine evidence without allowing invalidated room epochs to change wield state.
- Prompts and inventory never auto-create a gold generation. Only a later direct/confirmed gold opportunity can consume eligibility, and consumption occurs before the fresh operation or wire send.

## Automated Evidence

- Test-first RED: 32 successes and seven named missing-quarantine/help assertion failures, with zero setup or syntax errors.
- Final focused Busted: 37 successes, 0 failures, 0 errors across gold retry and UI registry specs.
- Room-fence compatibility regression: 68 successes, 0 failures, 0 errors in `boop_event_transitions_spec.lua`.
- Complete host regression pass: all 41 specs passed in isolated processes, totaling 646 successes with 0 failures and 0 errors.
- `luac -p` passed for every plan-listed Lua source and focused spec.
- `git diff --check` and staged diff hygiene passed.
- `python3 tools/check_release_gates.py` passed versions, manifests, and state-drift immediately before commit.
- PTY-backed `muddle` built `boop Hunter 0.1.470` successfully after the final amended source state.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Preserved room-response-fence wield projection while observing quarantine inventory**

- **Found during:** Final isolated host regression pass
- **Issue:** The first inventory-evidence integration reused every raw inventory payload for wield projection, allowing drained old-fence responses to overwrite current wield state.
- **Fix:** Kept wield rebuilding restricted to current accepted inventory responses, while routing only accepted or complete duplicate lists into quarantine inventory generations. Invalidated/drained epochs remain inert.
- **Files modified:** `src/scripts/boop/boop_events.lua`
- **Verification:** `boop_event_transitions_spec.lua` passed 68/68; all 41 isolated specs passed 646/646; focused tests remained 37/37.
- **Commit:** `b8ff548` (amended into the single package commit)

**2. [Rule 1 - Workflow State Bug] Reconciled SDK-derived phase metadata**

- **Found during:** Final state update
- **Issue:** The SDK advanced the correct Plan 26 counter and ROADMAP row, but left STATE progress text at 89%, frontmatter percent at 33%, the Plan 25 activity description, and new decisions labeled `Phase ?`.
- **Fix:** Reconciled STATE against the authoritative 26 summaries and ROADMAP: Plan 26 of 30, 40/44 plans (91%), current activity/metrics, and Phase 03 decision labels.
- **Files modified:** `.planning/STATE.md`
- **Verification:** STATE and ROADMAP both report Plan 03-26 complete with 26/30 Phase 03 plans and 40/44 milestone plans.
- **Commit:** Plan metadata commit

---

**Total deviations:** 2 auto-fixed bugs (1 implementation, 1 workflow metadata)
**Impact on plan:** The fixes preserve the existing room-fence contract, keep quarantine evidence causal, and align planning state with authoritative on-disk completion artifacts.

## Known Stubs

None. The scan found only established runtime defaults and test-fixture empty values; every new quarantine field has a live producer and consumer, and no placeholder prevents the plan goal.

## Issues Encountered

- The first `muddle` attempt could not access the sandboxed Docker socket. Re-running the same gate with approved Docker access and a PTY completed successfully.
- A monolithic host `busted tests` experiment reproduced the repository's shared database-fixture contamination. Running each of the 41 specs in its own process produced the authoritative 646-success host regression pass.

## User Setup Required

None.

## Next Phase Readiness

- G-03-23 is deterministically covered for Plans 03-29 and 03-30 to rerun and validate live owner/generation/native-put/inventory evidence.
- Pickup replay and existing queue/room-fence contracts remain green, so later phase work can use the quarantine snapshot without adding another coordinator.
- The parent session still owns the immutable-final-HEAD push and exact-SHA CI gate. No push was performed.

## Self-Check: PASSED

- All nine planned implementation/version files and this summary exist.
- Task commit `b8ff548` exists and contains no tracked-file deletions.
- Focused tests, room-fence compatibility, all isolated host specs, Lua syntax, diff hygiene, release gates, and the final `muddle` package build passed.
