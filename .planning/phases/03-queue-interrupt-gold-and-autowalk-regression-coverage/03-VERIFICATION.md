---
phase: 03-queue-interrupt-gold-and-autowalk-regression-coverage
verified: 2026-07-28T08:18:10Z
status: human_needed
score: 5/5 must-haves verified
plan_truths_audited: 98/98
behavior_unverified: 0
overrides_applied: 0
re_verification:
  previous_status: human_needed
  previous_score: 5/5
  gaps_closed:
    - "The implementation side of UAT G-03-5 is closed: a settled non-gold List followed by a gold Item.Add now creates one bounded room-only response fence, and only the matching fenced List can authorize the same operation."
    - "The implementation side of UAT G-03-4 is closed: manual targeting is a canonical walk hold with visible status/action guidance, while inactive, owned, attached, and silent stop semantics remain distinct."
    - "The implementation side of UAT G-03-6 is closed: trace live is session-only, collection-dependent, exact-once, non-recursive, reload-resetting, buffer-preserving, and packaged through the exact alias/help route."
  gaps_remaining: []
  regressions: []
deferred:
  - truth: "In-game pull help precisely distinguishes timeout-at-origin release from timeout-away hold-until-return behavior."
    addressed_in: "Phase 6"
    evidence: "Phase 6 success criterion 3 requires README, command help, UIDESIGN guidance, and dashboard copy to match every changed command surface or operator workflow."
human_verification:
  - test: "After all planning mutations are committed, push the immutable final HEAD and run tools/wait_for_exact_ci.sh with its full SHA."
    expected: "main.yml succeeds with an exactly matching headSha and the complete packaged real-Mudlet Busted run reports zero failures and zero errors, including the Psion and Dragon pull-profile cases."
    why_human: "The corrected candidate still needs an immutable exact-SHA GitHub run; the local Mudlet 4.20.1 rerun passed all 686 packaged cases, but local execution cannot satisfy the origin/headSha authority gate."
  - test: "Rerun the settled non-gold List then gold Item.Add flow, once normally and once while moving before the revalidation response."
    expected: "Item.Add causes one room-only revalidation and no get by itself; only the matching current-room fenced List permits one get, its confirmation permits one put, wrong-room/stale/duplicate responses do nothing, unrelated holds suppress all attack/loot/walk output, and the operation releases without a permanent jam."
    why_human: "Host tests exercise the transition, but only live Mudlet/Achaea can establish actual GMCP List/Add ordering, command confirmations, and room movement timing."
  - test: "Rerun manual-targeting walk hold and stop ownership in the existing Phase 3 UAT."
    expected: "An inactive non-silent stop prints 'walk stop: no active boop walk'; manual targeting reports manual_targeting with action 'boop targeting auto' and emits no move; returning to auto permits one safe move; owned stop emits one walker stop while attached/detached and silent paths remain non-destructive and quiet."
    why_human: "The host harness proves state transitions, but real status rendering and demonnicAutoWalker event ownership require the installed package and external walker."
  - test: "Exercise the packaged boop trace live on|off alias with collection off/on, show/clear, one known trace-producing event, and a package reload."
    expected: "Live mode never enables collection, collection-off produces no live output, collection-on produces exactly one non-recursive live line per collected entry, show/clear/100-entry trimming remain intact, reload preserves the buffer and persisted collection setting but resets live to off, and help/status describe the split."
    why_human: "The built XML contains the exact route, but alias matching, package reload behavior, and Mudlet output are only authoritative in a real installed profile."
---

# Phase 3: Queue, Interrupt, Gold, and Autowalk Regression Coverage Verification Report

**Phase Goal:** Timing-sensitive command paths cannot attack, loot, or walk while another safety hold or room-state blocker owns the next action.
**Verified:** 2026-07-28T08:18:10Z
**Status:** human_needed
**Re-verification:** Yes — complete goal re-verification after Plans 03-16 through 03-19
**Verified HEAD:** `f60b7af156abc30b4642ca418e725805ad8c9493`
**Branch:** `codex/pre-1.0-hardening-pass`
**Package version:** `0.1.441`

## Goal Achievement

The current implementation satisfies all five Phase 3 roadmap truths in code and focused behavioral tests. Plans 03-16 through 03-19 close the implementation defects diagnosed by UAT G-03-4, G-03-5, and G-03-6 without weakening the earlier exact-owner safety model.

The phase is not yet fully authoritative in the shipped environment. The corrected candidate has not passed the immutable exact-SHA GitHub gate, and the three corrected live flows have not been rerun against package 0.1.441. The ordered verifier decision tree therefore yields `human_needed`, not `passed` and not `gaps_found`.

After verification, the first exact-SHA run exposed a test-environment mismatch in the package-reload trace case: GitHub exports `TESTS_DIRECTORY`, while the host-focused test used `BOOP_REPO_ROOT`. Version 0.1.441 makes the test derive the same repository root from either variable. A local Mudlet 4.20.1 packaged rerun completed 686/686 cases without a Busted failure marker; the corrected final GitHub run remains pending.

### Observable Truths

| # | Roadmap truth | Status | Evidence |
|---|---|---|---|
| 1 | `diag`, queued interrupts, `pull`, and manual holds prevent automatic attacks until their exact release condition is satisfied. | ✓ VERIFIED | `boop_runtime.lua` maintains exact owner keys and aggregate hold checks; interrupt, pull, diagnostic, lifecycle, prequeue, tick, walk, and UI behavioral specs pass. Manual targeting resolves to canonical `manual_targeting`, blocks reservation/emission, and points to `boop targeting auto`. |
| 2 | Gold pickup, pack/stash, retry, warning, and stale-pending behavior cannot act in the wrong room or bypass active safety holds. | ✓ VERIFIED | Item.Add can request, but cannot supply, canonical room authority. One room-only response fence binds the exact operation/room/generation/item; only its accepted copied List can promote the same operation. Movement, stale generations, mismatches, duplicates, and unrelated owners suppress get/put/attack/walk. Gold, retry, event-transition, tick, and runtime tests pass. |
| 3 | `boop walk` start, stop, move, and status reflect settlement/blockers and emit `demonwalker.move` only when safe. | ✓ VERIFIED | Start creates a fresh room epoch; one shared evaluator covers manual/automatic paths; the final emitter rechecks run, room, reservation, package, settlement, and every unrelated owner. Inactive stop is visible, owned stop invalidates before one external stop, attached detach is non-destructive, and silent stop stays silent. Walk/UI/event tests pass. |
| 4 | `demonnicAutoWalker` remains optional with explicit install/status feedback and no silent auto-update. | ✓ VERIFIED | Production search finds one `installPackage` call, only in the explicit install path; no updater exists. `demonwalker.move` and `.stop` each have one guarded emitter. The 41-case walk spec includes no-install/no-update checks. |
| 5 | Regression coverage catches unsafe movement, attacks during holds, wrong-room loot, target-removal drift, and permanent walk stalls. | ✓ VERIFIED | Tests enumerate both owner-clear orders, exact self-owner exclusion, stale callbacks, target removal under aggregate blockers, room-fence invalidation, the settled-List/Add gold regression, exact get-confirm-put, timeout/release liveness, manual walk holds, stop ownership, and trace reload/exact-once behavior. |

**Score:** 5/5 roadmap truths verified (0 present-but-behavior-unverified)

### Plan Must-Have Audit

All 98 `must_haves.truths` assertions from Plans 03-01 through 03-19 were checked against current source and tests. This table records every plan rather than relying on SUMMARY claims.

| Plan | Truths | Status | Current-code evidence |
|---|---:|---|---|
| 03-01 | 5 | ✓ VERIFIED | Runtime owner registry, immutable blocker snapshots, aggregate gates, and exact-owner clear/exclusion tests. |
| 03-02 | 5 | ✓ VERIFIED | FIFO interrupt operation, generation owner, one terminal path, repeat rejection, and timeout tombstones. |
| 03-03 | 4 | ✓ VERIFIED | Pull generation/origin/timer ownership, return completion, timeout-away retention, and stale callback suppression. |
| 03-04 | 5 | ✓ VERIFIED | Separate gold operation state, independent queue commands, exact pickup confirmation, and inventory-owned packing. |
| 03-05 | 5 | ✓ VERIFIED | Room observation epoch/fence, copied accepted Lists, serialized requests, stale/mismatched response rejection. |
| 03-06 | 5 | ✓ VERIFIED | Optional walker detection/install/status, fresh run generation, settlement owner, and no silent update. |
| 03-07 | 5 | ✓ VERIFIED | Shared all-clear evaluator, captured reservation identity, one guarded move emitter, stale emitter cancellation. |
| 03-08 | 6 | ✓ VERIFIED | Canonical status precedence and blocker snapshots for queue, gold, walk, diagnostics, and room state. |
| 03-09 | 9 | ✓ VERIFIED | Cross-owner attack/gold/walk suppression in both clear orders and one eligible effect after final release. |
| 03-10 | 5 | ✓ VERIFIED | Target removal/retarget cannot bypass queue or runtime owners; captured prequeue callbacks revalidate. |
| 03-11 | 5 | ✓ VERIFIED | Same-room refresh preserves accepted evidence while actual movement invalidates room-owned work. |
| 03-12 | 5 | ✓ VERIFIED | Tokenless walker arrival, current reservation only, stop/restart generation safety, and owned/attached distinction. |
| 03-13 | 6 | ✓ VERIFIED | Gold retry/warning paths remain bounded, exact-owner, room-safe, and fail closed without permanent normal-path stalls. |
| 03-14 | 5 | ✓ VERIFIED | Active lifecycle prompt folder, disabled evidence-only callbacks, exact `gmcp:ire` release, and warning-only 8-second fence timeout. Legacy Core prompt is absent as required. |
| 03-15 | 6 | ✓ VERIFIED automated | Fixture table restoration, enabled diagnostic preconditions, exact pull timer identity, bounded isolated tests, and final-SHA CI wiring. Execution of final-SHA CI remains a human item. |
| 03-16 | 4 | ✓ VERIFIED | Settled non-gold List + gold Add creates one room-only fence; Add is noncanonical; matching List promotes the same operation; stale/wrong-room/duplicate paths suppress all effects and normal completion releases. |
| 03-17 | 4 | ✓ VERIFIED | Manual targeting is a walk hold/status reason; inactive stop is visible; silent, owned, and attached semantics remain safe; UI status does not fall through to room-clear. |
| 03-18 | 5 | ✓ VERIFIED | Live trace defaults/reloads off, is runtime-only, never enables collection, emits exact-once only while collecting, and preserves buffer/show/clear/trim behavior. |
| 03-19 | 4 | ✓ VERIFIED automated | Exact alias regex/body/help route is present in source and built XML; release gates, syntax, and local package build pass. Exact-SHA CI and live alias execution remain human items. |

### Deferred Item

| Item | Addressed In | Evidence |
|---|---|---|
| Clarify pull help so timeout-at-origin release and timeout-away hold-until-return are stated exactly. | Phase 6 | Phase 6 success criterion 3 owns final README/help/UIDESIGN/operator-workflow coherence. This wording issue does not change runtime ownership. |

## Required Artifacts

The plan helper and manual review resolve 92/92 semantic artifact declarations across Plans 03-01 through 03-19. Helper false negatives were inspected rather than accepted: the legacy Core prompt is intentionally absent, escaped-pattern misses in Plan 03-15 are present in source, and Plans 03-16 through 03-19 use string-form artifact declarations that require manual verification.

| Artifact | Expected | Status | Details |
|---|---|---|---|
| `src/scripts/boop/boop_runtime.lua` | Exact-owner blockers, room epochs/fences, interrupt terminal, aggregate tick gates | ✓ VERIFIED | Substantive and wired. `roomOnly` fences bind current settled room/generation and accept one current response; owner snapshots and exact exclusions feed all effect gates. |
| `src/scripts/boop/boop_events.lua` | GMCP adapters, staged gold, room revalidation, pull/lifecycle boundaries | ✓ VERIFIED | Add requests bounded revalidation but never populates accepted authority; matching List promotes; movement/stale evidence drains safely; confirmed get alone permits put. |
| `src/scripts/boop/boop_walk.lua` | Shared movement gate, canonical reasons, safe stop/detach, guarded external emitter | ✓ VERIFIED | Manual mode, package loss, room settlement, owner aggregation, run/reservation identity, and owned/attached semantics are all wired. |
| `src/scripts/boop/boop_ui.lua` | Operation creation, canonical status, visible inactive stop, trace command routing | ✓ VERIFIED | Exact generation owners/timers and the `manual_targeting`/trace status surfaces are substantive and tested. |
| `src/scripts/boop/boop_util.lua` | Independent combat dispatch and collection-gated trace output | ✓ VERIFIED | Combat actions never chain loot; trace appends only when collection is enabled and emits one direct, non-recursive live line. |
| `src/scripts/boop/boop_bootstrap.lua` and `scripts.json` | Early reload reset before bootstrap guard, preserving trace buffer | ✓ VERIFIED | Runtime loads before bootstrap; bootstrap sets only `state.trace.live = false` before its early-return guard. |
| `src/scripts/boop/boop_ui_registry.lua` | Exact trace help/status contract | ✓ VERIFIED | Help distinguishes persisted collection from session-only live output and exposes `boop trace live on|off`. |
| Trace live alias manifest and body | One enabled leaf alias with exact regex and two-argument route | ✓ VERIFIED | Source and generated `boop Hunter.xml` contain `^(?i)boop\\s+trace\\s+live\\s+(on|off)$` and `boop.ui.traceCommand("live", matches[2] or "")`. |
| `src/triggers/boop_lifecycle/triggers.json` and `Prompt.lua` | Always-available prompt evidence only | ✓ VERIFIED | Top-level lifecycle folder is active with exactly one prompt child calling `boop.onPrompt()`. |
| `src/triggers/boop/Core/Prompt.lua` | Legacy duplicate prompt removed | ✓ VERIFIED — ABSENT AS REQUIRED | No old Core prompt file or duplicate dispatcher exists. |
| Phase-focused test files | Executable behavioral regressions for every stateful contract | ✓ VERIFIED | 17 focused files produced 254 successes with zero failures/errors. |
| `.github/workflows/main.yml` and `tools/wait_for_exact_ci.sh` | Packaged full-suite authority and immutable SHA gate | ✓ WIRED / ? CORRECTED RUN PENDING | CI imports the package and runs the complete test directory; the gate checks origin presence, exact `headSha`, success, and worktree immutability. |

## Key Link Verification

Manual semantic review resolves 58/58 key links across all 19 plans. Earlier helper misses were pattern-escaping false negatives; the 12 links added by Plans 03-16 through 03-19 were inspected directly.

| From | To | Via | Status | Details |
|---|---|---|---|---|
| Owner registry | Tick, prequeue, gold, walk | `shouldHold(system, exceptOwner)` | ✓ WIRED | Exact self-owner exclusion never suppresses unrelated owners; sorted aggregate snapshots feed status and gates. |
| Room.Info and item Lists | Runtime observation | ordinary Inv→Room or bounded room-only response fence | ✓ WIRED | Only copied accepted current-room/current-generation Lists become authority. |
| Gold Item.Add | Exact gold operation | one `room_revalidation` fence | ✓ WIRED | Add can initiate one request but cannot authorize get; the matching fence/List promotes the original operation without generation drift. |
| Accepted room observation | Gold dispatch | room/generation/item/fence plus aggregate owner checks | ✓ WIRED | One get is followed only by confirmed get→one put; duplicates and stale responses are inert. |
| Interrupt/pull/diagnostic operations | Runtime terminal | exact owner and generation | ✓ WIRED | Prompt/result/return/timeout clears only the owning operation; stale callbacks cannot clear replacements. |
| Target removal/retarget | Attack and prequeue | final aggregate hold revalidation | ✓ WIRED | Retargeting cannot attack or queue while any unrelated owner remains. |
| Walk evaluator | Reservation and external walker | final run/room/reservation/all-clear recheck | ✓ WIRED | Manual targeting prevents reservation; one guarded move emitter exists. |
| Stop command | External walker | owned/attached state captured before invalidation | ✓ WIRED | Owned runs stop once; attached/detached runs never destructively stop external ownership. |
| Trace collection | Buffer/live output | collection gate before append and direct info output | ✓ WIRED | Collection off means no append/output; live does not recurse through trace. |
| Bootstrap | Trace runtime state | reset before early-return guard | ✓ WIRED | Reload turns live off without replacing or clearing the buffer. |
| Alias manifest/body | UI trace handler and help registry | exact regex plus `traceCommand("live", ...)` | ✓ WIRED | Source route survives into the generated package XML. |
| GitHub Actions | Complete packaged test directory | exact-SHA wait gate | ✓ WIRED / ? CORRECTED RUN PENDING | The first finalization run exposed the trace test's host-only root variable; 0.1.441 accepts the existing packaged-CI `TESTS_DIRECTORY` contract. |

## Data-Flow Trace (Level 4)

| Artifact | Data | Source | Produces authoritative data | Status |
|---|---|---|---|---|
| Runtime owner registry | Active safety holds | Exact operation/lifecycle set and clear calls | Yes; immutable sorted snapshots and exact-owner exclusion | ✓ FLOWING |
| Room observation | Accepted room items | Room.Info epoch plus serialized response fence | Yes; current matching List is deep-copied, stale/mismatched evidence is rejected | ✓ FLOWING |
| Gold operation | Deferred→pickup→pack state | Exact Add request, accepted fenced List, get confirmation, inventory transfer | Yes; Add is not authority and room-owned state is discarded before inventory-owned put | ✓ FLOWING |
| Walk reservation | Safe external move | Settled room, targeting mode, target/denizen state, runtime owners, gold/pull/flee state | Yes; captured run/room/reservation reaches one final guarded emitter | ✓ FLOWING |
| Trace buffer/live stream | Collected diagnostic entries | Persisted collection flag plus session-only live flag | Yes; one append and at most one direct output per collected entry | ✓ FLOWING |
| Packaged alias | User command to trace state | Generated XML regex/body to `boop.ui.traceCommand` | Yes in local package build | ✓ FLOWING locally / live execution pending |

## Behavioral Spot-Checks

| Behavior | Command/check | Result | Status |
|---|---|---|---|
| Phase-focused host behavior | Isolated Busted runs for runtime, interrupt, diag, diag-timeout, gold, gold-retry, event-transition, prequeue, tick, walk, UI, trace, lifecycle, state-contract, safety, UI-registry, and persistence specs | 254 successes, 0 failures, 0 errors | ✓ PASS |
| Settled List→Add gold regression | Named gold/event transition cases | One bounded room-only request; Add/Inv cannot authorize; matching List keeps exact operation; exact one get-confirm-put; movement/stale/duplicate paths inert | ✓ PASS |
| Manual targeting and walk ownership | Named walk/UI cases | 41/41 walk and 44/44 UI successes include manual hold/status/action, inactive feedback, and silent/owned/attached semantics | ✓ PASS |
| Live trace contract | `tests/boop_trace_spec.lua` | 13/13 successes cover fresh/reset off, non-persistence, collection dependency, exact-once/non-recursion, buffer preservation, show/clear/trim/status | ✓ PASS |
| Aggregate exact-owner regression | Runtime/prequeue/tick/event/walk suites | Both clear orders and stale-owner callbacks retain unrelated holds; no early attack/get/put/move | ✓ PASS |
| Full host pull diagnostic | `tests/boop_pull_spec.lua` under Occultist-only helper | 11 successes, exactly 2 Psion/Dragon profile exclusions, 0 errors | ℹ DIAGNOSTIC ONLY |
| Lua syntax | `find src -name '*.lua' ... luac -p` | Exit 0 | ✓ PASS |
| Release gates | `python3 tools/check_release_gates.py` | `[OK] versions`, `[OK] manifests`, `[OK] state-drift`; synchronized 0.1.441 | ✓ PASS |
| Muddler package build | `muddle` | Muddler 1.1.0 built `build/boop Hunter.mpackage` version 0.1.441 successfully | ✓ PASS |
| Generated package route | `unzip -p ... 'boop Hunter.xml'` inspection | Exact trace-live alias regex/body/help and lifecycle prompt are present | ✓ PASS |
| Local packaged Mudlet suite | Mudlet 4.20.1 with `BOOP_REPO_ROOT` absent and CI's `TESTS_DIRECTORY` present | 686 successes, 0 failure markers; Mudlet segfaulted only during local application teardown after closing the completed suite | ✓ TESTS PASS / ℹ LOCAL TEARDOWN |
| Exact-final-SHA `main.yml` | Corrected candidate | Prior run `30342244363` exposed the root-variable mismatch; the 0.1.441 exact-SHA rerun is pending | ? HUMAN REQUIRED |

## Probe Execution

No Phase 3 plan or summary declares a probe, and no conventional `scripts/*/tests/probe-*.sh` file exists.

| Probe | Command | Result | Status |
|---|---|---|---|
| None | Discovery only | No probes declared or found | SKIPPED |

## Requirements Coverage

Every requirement ID declared by Plans 03-01 through 03-19 exists in `.planning/REQUIREMENTS.md`. Their union exactly matches the five requirements assigned to Phase 3; there are no orphaned Phase 3 requirements.

| Requirement | Description | Status | Evidence |
|---|---|---|---|
| SAFE-02 | Interrupt, pull, diagnostic, and manual holds prevent attacks until exact release. | ✓ SATISFIED | Exact operation owners, aggregate combat/prequeue gates, manual walk hold, session trace isolation, and passing interrupt/pull/diag/lifecycle/runtime/prequeue/tick/UI tests. |
| SAFE-04 | Gold never acts in the wrong room or bypasses another hold. | ✓ SATISFIED | Noncanonical Add, one response-fenced room revalidation, exact current List authority, wrong-room/stale suppression, independent get-confirm-put, and passing gold/retry/event/tick tests. |
| WALK-01 | Walk coverage includes start, stop, move, settlement, canonical reasons, and external events. | ✓ SATISFIED | 41 passing walk cases plus UI/event integration cover start/stop/restart, settlement, `manual_targeting`, status actions, and one safe external move. |
| WALK-02 | Walk advancement remains blocked by target, gold, diagnostic, flee, pull, leader, and room state. | ✓ SATISFIED | Shared evaluator and final reservation recheck include aggregate runtime owners; gold revalidation/movement cases prove no walk leak and later release. |
| WALK-03 | External walker remains optional with explicit install/status and no silent update. | ✓ SATISFIED | Single explicit install call, no updater, package-loss/status tests, and preserved owned/attached stop semantics. |

## Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|---|---:|---|---|---|
| `src/scripts/boop/boop_ui_registry.lua` | 778 | Legacy pull-timeout help is less precise than timeout-away ownership behavior | ⚠ Warning — deferred | Runtime safety is correct; Phase 6 owns final help/doc coherence. |
| Phase-relevant source/tests | — | `TBD`, `FIXME`, `XXX`, TODO/HACK/PLACEHOLDER, empty user-visible implementation, or orphaned artifact | None | No blocker debt marker, substantive stub, hollow data path, or orphaned production artifact was found. |

## Human Verification Required

Use these as the concise rerun checklist in the existing `03-UAT.md`; do not create another UAT artifact.

### 1. Immutable final-SHA packaged CI

**Test:** After all planning/UAT mutations are committed, push the immutable final HEAD and run:

```bash
FINAL_SHA="$(git rev-parse HEAD)"
tools/wait_for_exact_ci.sh "$FINAL_SHA"
```

**Expected:** `main.yml` succeeds for exactly `FINAL_SHA`, and the complete packaged real-Mudlet suite reports zero failures/errors, including Psion and Dragon pull-profile cases.

### 2. Corrected settled-List→gold-Add flow

**Test:** In a settled room whose accepted List has no gold, receive a gold Item.Add. Observe one normal successful revalidation, then repeat while moving before the response; include an unrelated safety owner.

**Expected:** Add sends no get and causes one room-only revalidation. Only the matching current-room fenced List authorizes one get; get confirmation authorizes one put. Wrong-room, stale-generation, stale-fence, duplicate, and movement-before-response paths emit no get/put/attack/move. Releasing the final owner or completing/cancelling the operation leaves combat and walk able to continue.

### 3. Corrected manual-targeting/stop flow

**Test:** With no boop walk active, run `boop walk stop`; then start walking, switch to manual targeting in an empty settled room, inspect status, return to auto, and exercise owned versus attached stop/detach.

**Expected:** Inactive stop visibly prints `walk stop: no active boop walk`. Manual mode reports `manual_targeting` with `boop targeting auto`, reserves/emits no move, and auto permits one safe move. Owned stop emits one external stop after invalidation; attached/detached and silent paths remain non-destructive/quiet.

### 4. Corrected packaged live-trace flow

**Test:** Through the packaged aliases, exercise `boop trace live on|off` with collection off and on, generate one known trace event, use show/clear, then reload the package.

**Expected:** Live never enables collection; collection-off emits/appends nothing. Collection-on emits exactly one non-recursive live line per appended entry. Show, clear, and 100-entry trimming remain correct. Reload preserves the buffer and persisted collection setting but resets live off. Help/status distinguish persisted collection from session-only live output.

## Adversarial Disconfirmation

- Host tests are not treated as packaged Mudlet authority. The local build proves XML/package inclusion, not live alias, GMCP, prompt, timer, or external-walker execution.
- The full host pull file is not falsely reported green: its two Psion/Dragon cases cannot run under the Occultist-only helper and remain part of exact-SHA packaged CI authority.
- SUMMARY completion claims were not used as evidence. Production state transitions, source wiring, generated XML, focused tests, version gates, and build output were inspected or executed independently.
- The corrected candidate is not yet committed and pushed. No previous CI result can satisfy its immutable exact-SHA gate.

## Gaps Summary

No automated implementation gap or regression remains at current HEAD. All five roadmap truths, all 98 plan truths, 92 semantic artifacts, 58 semantic key links, and all five Phase 3 requirement IDs are accounted for.

Human authority remains for the immutable final-SHA packaged suite and the three corrected live flows. Record those results in the existing `03-UAT.md`, then rerun Phase 3 verification; do not infer a pass from plan completion or the local host suite.

---

_Verified: 2026-07-28T08:18:10Z_
_Verifier: Codex (gsd-verifier)_
