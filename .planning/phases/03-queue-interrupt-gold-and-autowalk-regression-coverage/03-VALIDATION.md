---
phase: 03
slug: queue-interrupt-gold-and-autowalk-regression-coverage
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-07-25
---

# Phase 03 - Validation Strategy

> Per-phase validation contract for timing-sensitive command ownership and movement safety.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Busted/luassert inside Mudlet 4.20.1 with Lua 5.1-compatible execution |
| **Config file** | `.github/workflows/main.yml`; test setup lives in `tests/support/boop_test_helper.lua` |
| **Quick run command** | `python3 tools/check_release_gates.py` plus the smallest affected Mudlet spec when a local AppImage is available |
| **Full suite command** | `muddle && AUTORUN_BUSTED_TESTS=true TESTS_DIRECTORY="$PWD/tests" QUIT_MUDLET_AFTER_TESTS=true PRETEST_PACKAGE="$PWD/build/boop Hunter.mpackage" /tmp/Mudlet.AppImage --profile "GithubTests" --mirror` |
| **Estimated runtime** | Static gates under 10 seconds; focused/full Mudlet runtime depends on AppImage startup and is authoritative in GitHub Actions when unavailable locally |

The static release gate is fast feedback only. It does not substitute for behavioral
execution inside Mudlet's Lua 5.1-compatible runtime.

---

## Sampling Rate

- **After every task commit:** Run `python3 tools/check_release_gates.py` and the smallest affected Mudlet Busted spec when the AppImage is available. A task commit touching tests, docs, source, or any path outside `.planning/` is package-affecting and must monotonically synchronize all four version checkpoints under AGENTS.md.
- **After every plan wave:** Run the full Mudlet/Busted suite; use the configured GitHub Actions job when local Mudlet is unavailable. Any run completed before the repository terminal exact-HEAD extension is sampling evidence only.
- **During standard GSD closeout:** SUMMARY/STATE/ROADMAP/REQUIREMENTS/verification/phase-completion commits are planning-only and version-exempt when every staged path is under `.planning/`.
- **After upstream GSD and all repository mutations:** The parent pushes immutable final HEAD, then runs `tools/wait_for_exact_ci.sh "$FINAL_SHA"` as the mandatory repository-level AGENTS.md/CODEX.md extension.
- **Before `$gsd-verify-work`:** Release gates, package build, available local real-Mudlet execution, and the repository terminal exact-final-SHA CI extension must be green. CI evidence is reported without a follow-up repository commit; any later mutation requires the parent to push the new final HEAD and rerun the script.
- **Max feedback latency:** One task between static checks; no timing-safety task may be followed by another without its focused assertions being added.

---

## Commit Classification and Terminal CI Authority

- Standard GSD SUMMARY, STATE, ROADMAP, REQUIREMENTS, verification, and phase-completion commits are planning-only only when every staged path is under `.planning/`; those commits do not bump the package version.
- Plan task commits that touch tests, docs, source, version metadata, or any other path outside `.planning/` are package-affecting and must monotonically synchronize `mfile.version`, `mfile.title`, `src/scripts/boop/boop_init.lua` `boop.version`, and the CODEX checkpoint.
- Upstream `$gsd-execute-phase 03` completes its ordinary execution and tracking flow without a custom post-summary parser hook. After that flow and every other repository mutation finish, the parent captures `FINAL_SHA`, pushes immutable final HEAD, and runs `tools/wait_for_exact_ci.sh "$FINAL_SHA"`.
- The script requires a clean matching HEAD, authenticated `gh`, the exact SHA on `origin`, an exact-`headSha` `main.yml` run, a successful conclusion, and unchanged local state through completion.
- CI evidence is reported and remains uncommitted. Missing push/authentication/exact run/success blocks repository completion/readiness, and any later repository mutation invalidates prior evidence and requires a rerun for the new final HEAD.

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 03-W0-01 | 03-01 foundation; 03-08 rendering | 1, 8 | SAFE-02 | T-03-stale-owner | Multiple owner-keyed blockers aggregate per subsystem; clearing one owner preserves unrelated attack/loot/movement holds and deterministic primary/all-owner output. | unit/integration | Focused Mudlet run for `tests/boop_runtime_spec.lua`, `tests/boop_trace_spec.lua`, and `tests/boop_ui_spec.lua` | Existing files; Phase 03 cases assigned to Plans 03-01 and 03-08 | pending |
| 03-W0-02 | 03-02 interrupts; 03-03 pull; 03-08 aggregate/manual holds | 2, 3, 8 | SAFE-02 | T-03-stale-callback | Interrupt and pull generations are idempotent, first-terminal-wins, release only owned holds, and never permit attack/prequeue during another hold. Diagnose output uses the real zero-argument trigger boundary and a FIFO whose timed-out head remains a tombstone: N timeout → N+1 starts → old result → prompt can mark/drain only N and leaves N+1 owner, timer, `resultSeen`, terminal state, sends, ticks, and output unchanged. Existing operator-disabled and manual-targeting states each produce exact zero attack/prequeue side effects until their existing explicit release action. | unit/integration | Focused Mudlet run for `tests/boop_interrupt_spec.lua`, `tests/boop_diag_spec.lua`, `tests/boop_diag_timeout_spec.lua`, `tests/boop_pull_spec.lua`, `tests/boop_prequeue_spec.lua`, and `tests/boop_tick_spec.lua` | Existing files; cases assigned to Plans 03-02, 03-03, and 03-08; existing diagnose trigger scripts are read-only zero-argument boundaries | pending |
| 03-W0-03 | 03-04 gold core; 03-05 event/tick integration | 4, 5 | SAFE-04 | T-03-wrong-room | Pickup is room-owned, packing becomes inventory-owned only after confirmation, duplicates coalesce, and stale retry/timeout callbacks cannot send in another room. Gold excludes only its own owner; current GMCP/room, pull, and interrupt owners defer unchanged-stage resumption until their real release paths and all other relevant owners clear. Real auto-flee instead cancels gold, invalidates timers/retries, emits no `flush_gold`/get/put, and keeps hunting disabled until explicit operator re-enable. | unit/integration | Focused Mudlet run for `tests/boop_gold_spec.lua`, `tests/boop_gold_retry_spec.lua`, `tests/boop_event_transitions_spec.lua`, and `tests/boop_tick_spec.lua` | Existing files; core assigned to 03-04 and integration to 03-05 | pending |
| 03-W0-04 | 03-06 walker core; 03-07 stop/event integration | 6, 7 | WALK-01, WALK-02 | T-03-unsafe-move | Automatic/manual requests share the normal evaluator; one monotonic reservation ID is captured per room cycle; only the exact run/room/reservation may use the reserved evaluator; duplicate/stale callbacks emit zero. Real lifecycle entry points set/update/clear `walk:<generation>` without self-blocking its matching emitter. | unit/integration | Focused Mudlet run for `tests/boop_walk_spec.lua` and `tests/boop_event_transitions_spec.lua` | Existing files; core assigned to 03-06 and integration to 03-07 | pending |
| 03-W0-05 | 03-06 package core; 03-07 ownership stop | 6, 7 | WALK-03 | T-03-external-boundary | Start/attach and stop/detach respect ownership; package loss invalidates the current reservation and updates the active owner to `walker_unavailable`; stop/finish invalidate before exact-owner clear; installation is explicit; no status or runtime path silently installs or updates. | boundary unit | Focused Mudlet run for `tests/boop_walk_spec.lua` | Existing file; cases assigned to Plans 03-06 and 03-07 | pending |
| 03-W0-06 | 03-08 aggregate effects; 03-09 matrix/docs/final | 8, 9 | SAFE-02, SAFE-04, WALK-01, WALK-02, WALK-03 | T-03-cross-lifecycle | Explicit callback orderings preserve ownership across interrupt, pull, gold, room observation, target removal, and walker interleavings; UI/trace obtains each walker code from real lifecycle entry points. Task 3 supplies local static/build/real-Mudlet evidence; after upstream GSD and all mutations finish, the parent supplies repository terminal authority through `tools/wait_for_exact_ci.sh`. | integration | Full Mudlet/Busted suite plus `python3 tools/check_release_gates.py`; after final immutable HEAD is pushed, `tools/wait_for_exact_ci.sh "$FINAL_SHA"` | Existing harness; integration assigned to Plans 03-08 and 03-09, terminal authority to the parent repository extension | pending |

*Status: pending, green, red, flaky*

---

## Required Ordering Matrix

Each row requires an explicit test that captures callbacks and invokes both terminal
orderings. Assertions must include exact `send()`/`raiseEvent()` counts and retained
owner state, not only final booleans.

| Lifecycle | Ordering A | Ordering B | Required invariant |
|-----------|------------|------------|--------------------|
| Interrupt | prompt/success then timeout | timeout then prompt/success | One terminal result and release; unrelated blockers remain; late callback is a no-op. |
| Interrupt repeat | same request twice while pending | different interrupt while one owns the lane | No resend or timer restart; the original owner remains. |
| Diagnose evidence FIFO | N result line through an existing zero-argument trigger, then prompt | N timeout, N+1 starts, old N result line through an existing zero-argument trigger, then prompt | Normal N completes once and drains its record. In the stale order, N remains as a terminal tombstone until its late result/prompt marks and drains only the FIFO head; N+1 generation, operation `resultSeen`, owner, timer, terminal state, send/tick/output counts, and unresolved evidence record remain unchanged. Missing or duplicate output never scans past or relabels the FIFO head. |
| Pull | valid return then timeout | timeout away then return | Only the current pull owner releases; stale callbacks cannot clear a later pull; saved enabled config is unchanged. |
| Manual attack hold | `boop off`/disabled, then tick and captured prequeue callback | manual targeting, then tick and captured prequeue callback | Both states produce zero attack sends and zero prequeue scheduling/execution. Resumption occurs only after existing `boop on` or an existing non-manual targeting-mode action, with one fresh evaluation and no new hold command. |
| Gold | room change before pickup success | pickup success before room change | The first cancels room-owned acquisition; the second preserves inventory-owned packing. |
| Gold evidence | text/Add before complete room list | complete room list plus duplicate signals | No early command; exactly one pickup after current evidence. |
| Gold timeout | old timeout after a new generation | retry after room change | No current-state mutation and no wrong-room command. |
| Gold owner authorization | gold owner is the only owner, or one current GMCP/room, pull, or interrupt owner is also active and reaches its real release path | real auto-flee fires during initial get, put, or retry | The exact gold owner never self-deadlocks. Non-flee owners block with zero send/retry consumption and resume one unchanged current stage through one tick/`flush_gold` only after every relevant owner clears. Real auto-flee destructively cancels the gold operation, invalidates its timers/retries, schedules zero `flush_gold`, emits zero get/put, and leaves hunting disabled until the existing explicit operator re-enable path. |
| Walk reservation | wrong/stale run, room generation, or reservation ID callback | matching reservation callback invoked twice | Wrong/stale callbacks emit zero and mutate no current state; the matching callback bypasses only its own `walk_move_pending` owner, emits once, and the duplicate emits zero. |
| Walk | stop then queued callback | stop, restart, then old callback | No event or state mutation from the old generation; callbacks are invalidated before exact walker-owner clear. |
| Walk settlement | prompt/timer without item list | current `Room.Info` plus complete room list | The first remains `walk_room_unsettled` and refreshes once; the second clears exactly `walk:<generation>` only when no move is reserved, then may evaluate all-clear once. |
| Walk duplicate | repeated arrival/list/manual callbacks | new room then new settlement cycle | At most one reservation/event in the first room cycle; the second increments and captures a fresh reservation ID, and reservation creation updates the same owner to `walk_move_pending`. |
| External loss | package disappears before emit | attached external run receives boop stop | Loss invalidates the queued reservation, sets the same owner to `walker_unavailable`, and emits no movement/install/update; detach invalidates first, clears the exact owner, and sends no external stop. |

---

## Wave 0 Requirements

- [ ] Extend `tests/support/boop_test_helper.lua` with deterministic generations, owner-keyed blocker seeding, room-observation cycles, captured timer queues, and walker/install stubs.
- [ ] Add multi-blocker, per-system all-clear, and deterministic-primary cases to `tests/boop_runtime_spec.lua`, `tests/boop_trace_spec.lua`, and `tests/boop_ui_spec.lua`.
- [ ] Add interrupt and pull repeat, race-order, stale-callback, unrelated-blocker, no-persisted-enable-mutation, and no-attack/prequeue cases. Diagnose coverage must use the unchanged detail/perfect trigger scripts and zero-argument `boop.onDiagReadyLine()`, prove independent `state.diag.evidenceQueue` reset/deep copy, normal FIFO completion, and N timeout → N+1 → old result → prompt tombstone absorption without N+1 mutation.
- [ ] Add exact SAFE-02 disabled/manual-targeting cases: zero attack/prequeue effects while held, then one fresh evaluation only after existing `boop on` or non-manual targeting release.
- [ ] Replace chained gold-command expectations with staged room/inventory ownership, duplicate detection, room-change, stale retry/timeout, exact-owner self-exclusion, destructive real auto-flee cancellation with zero resumption/get/put and explicit operator re-enable, plus current GMCP/room, pull, and interrupt holds with one unchanged-stage runtime-tick resumption only after every relevant owner clears.
- [ ] Expand `tests/boop_walk_spec.lua` to cover exact `DOMAIN_DEFAULTS.walk` reset/deep-copy fields (including `reservationId`), start/attach, real owner set/update/clear transitions, normal versus reserved evaluation, exact reservation IDs, stop/detach, status, explicit install outcomes, manual movement, settlement recovery, one-move-per-room, stale generations, duplicate callbacks, package loss, and event emission.
- [ ] Add event-order integration cases while retaining target-removal queue-drift coverage in `tests/boop_event_transitions_spec.lua`.
- [ ] Update `tests/README.md` after the coverage exists.

No new test framework or dependency is required.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Live interrupt and pull release | SAFE-02 | Real Achaea output, prompts, and room transitions complement deterministic callback tests. | Run one interrupt through success/prompt, one pull through return, and one pull timeout while away; confirm attacks remain held and only the owned hold releases. |
| Live gold pickup then packing | SAFE-04 | Live GMCP item timing and queue acknowledgement can differ from synthetic event ordering. | Observe one room pickup and post-pickup pack, then leave during a second room-owned pickup; confirm no wrong-room retry and inventory-owned packing may finish after movement. |
| Owned stop versus attached detach | WALK-01, WALK-03 | Requires a live `demonnicAutoWalker` run and operator-visible route state. | Start one walk through boop and stop it, then attach boop to an externally started run and stop boop; confirm the first raises external stop while the second only detaches. |
| One safe move after settlement | WALK-01, WALK-02 | Confirms the external package receives the event in a live Mudlet profile. | In a clear room, wait for matching room info/items evidence and request one move; confirm exactly one advancement and no movement while any listed blocker is active. |

---

## Validation Sign-Off

- [ ] All plan tasks have automated verification or an explicit Wave 0 dependency.
- [ ] Sampling continuity: no three consecutive tasks without automated verification.
- [ ] Wave 0 covers every missing test reference.
- [ ] Both terminal orderings in the race matrix are asserted.
- [ ] Diagnose tests execute the real zero-argument trigger boundary; no result helper accepts a generation. Normal result→prompt drains/completes N, while N timeout → N+1 → old result → prompt marks/drains only N's FIFO tombstone and leaves every N+1 state/side-effect count unchanged.
- [ ] SAFE-02 disabled/manual-targeting holds and explicit existing release actions have exact zero-send/prequeue and one-resumption assertions.
- [ ] Gold self-owner exclusion and non-flee GMCP/room/pull/interrupt block/resume behavior cover initial get, put, and retries; real auto-flee separately proves destructive cancellation, timer/retry invalidation, zero `flush_gold`/get/put, and explicit operator re-enable.
- [ ] Walker tests prove monotonic reservation capture, exact run/room/reservation matching, normal `move_pending`, exact-owner-only reserved exclusion, real owner lifecycle transitions, one matching event, and zero wrong/stale/duplicate events.
- [ ] UI/trace tests produce `walk_room_unsettled`, `walk_move_pending`, and `walker_unavailable` through real walker lifecycle entry points.
- [ ] No watch-mode flags.
- [ ] Static gates and authoritative Mudlet behavior checks are reported separately.
- [ ] Package-affecting plan task commits synchronize all four version checkpoints; standard GSD SUMMARY/STATE/ROADMAP/REQUIREMENTS/verification/phase-completion commits preserve the version when every staged path is under `.planning/`.
- [ ] Task 3 reports static/build/local real-Mudlet results without final authority; no custom post-summary marker or parser hook is required.
- [ ] After upstream GSD execution and every repository mutation finish, the parent captures and pushes immutable `FINAL_SHA`, then `tools/wait_for_exact_ci.sh "$FINAL_SHA"` proves an exact-`headSha` successful `main.yml` run.
- [ ] CI evidence is not committed. Missing push/authentication/exact run/success blocks repository completion/UAT readiness, and any later verifier, UAT artifact, state update, version bump, documentation change, or other mutation forces a rerun for the new final HEAD.
- [ ] `nyquist_compliant: true` is set only after Wave 0 and task coverage are implemented and green.

**Approval:** pending
