---
phase: 03-queue-interrupt-gold-and-autowalk-regression-coverage
verified: 2026-07-27T07:34:23Z
status: gaps_found
score: 4/5 must-haves verified
behavior_unverified: 0
overrides_applied: 0
re_verification:
  previous_status: human_needed
  previous_score: 5/5
  gaps_closed:
    - "G-03-3 implementation: disabled IRE/prompt evidence now releases only gmcp:ire in either order, lifecycle prompt observation is isolated from hunting automation, and the room-response warning is 8.0 seconds and fail closed."
  gaps_remaining:
    - "Two tracked diagnose-timeout regressions still assume prompt runtime processing while hunting is disabled and fail after the intentional disabled lifecycle return."
    - "Three tracked pull lifecycle regressions identify pull timers by their 8.0-second delay and now collide with the 8.0-second room-response warning timer."
  regressions:
    - "tests/boop_diag_timeout_spec.lua: two exact named tests fail."
    - "tests/boop_pull_spec.lua: three exact owner/timer lifecycle tests fail because pullTimerCount() counts response-fence timers."
gaps:
  - truth: "Diagnose timeout and tombstone regression coverage remains executable after disabled lifecycle observation is separated from automation."
    status: failed
    reason: "Two exact named tests fail because boop.onPrompt() now correctly returns before runtime processing when boop.config.enabled is false, but the timeout fixtures did not establish the enabled precondition required by the runtime diagnose flow."
    artifacts:
      - path: "tests/boop_diag_timeout_spec.lua"
        issue: "The cases at lines 116 and 186 leave enabled=false, then expect onPrompt() to consume diagnose evidence; assertions fail at lines 164 and 198."
      - path: "src/scripts/boop/boop_events.lua"
        issue: "The intentional disabled return at lines 1764-1765 exposes the stale fixture assumption; the implementation behavior is covered by the passing lifecycle test."
    missing:
      - "Make runtime diagnose-timeout cases establish enabled=true before expecting prompt runtime processing."
      - "Retain or add a separate disabled-path assertion proving prompt evidence remains automation-inert and fail closed."
      - "Rerun the two exact diagnose-timeout cases and the authoritative real-Mudlet suite."
  - truth: "Pull lifecycle regression coverage distinguishes the operation-owned timeout from room-response warning timers."
    status: failed
    reason: "ROOM_RESPONSE_FENCE_WARNING_SECONDS now equals diagTimeoutSeconds (8.0). pullTimerCount() classifies timers only by delay, so room transitions inflate the count and three exact pull lifecycle tests fail."
    artifacts:
      - path: "tests/boop_pull_spec.lua"
        issue: "pullTimerCount() at lines 53-60 counts every timer whose delay is 8.0; exact failures occur at lines 280, 390, and 553."
      - path: "src/scripts/boop/boop_events.lua"
        issue: "The valid 8.0-second room-response timer at lines 48 and 327 now collides with the test helper's delay-based identity heuristic."
    missing:
      - "Identify and count pull timers by state.combat.pullState.timeoutTimer or captured operation-owned timer IDs, never by delay."
      - "Keep response-fence timers in the fixture and assert that stale pull callbacks remain zero-effect while those unrelated timers coexist."
      - "Rerun the three exact pull lifecycle cases and the authoritative real-Mudlet suite."
---

# Phase 3: Queue, Interrupt, Gold, and Autowalk Regression Coverage Verification Report

**Phase Goal:** Timing-sensitive command paths cannot attack, loot, or walk while another safety hold or room-state blocker owns the next action.
**Verified:** 2026-07-27T07:34:23Z
**Status:** gaps_found
**Re-verification:** Yes — after gap Plan 03-14
**Verified HEAD:** `e0aade29d06325137c9437be2c4f11a967619a9a`
**Branch:** `codex/pre-1.0-hardening-pass`
**Package version:** `0.1.427`

## Goal Achievement

Plan 03-14's implementation goal is present, wired, and passes its four exact named behavioral tests. G-03-3 is therefore closed at the automated implementation level.

The phase cannot pass verification yet. Plan 03-14's 109-case aggregate omitted two timing-sensitive suites affected by its changes. Independent exact-name execution found two failing diagnose-timeout tests and three failing pull lifecycle tests. These are tracked repository specs included in the real-Mudlet CI test directory, not the deliberately discarded 41-spec host run. Roadmap success criterion 5—working regression coverage for timing-sensitive ownership—therefore fails.

Live Achaea/Mudlet validation is also still pending. The existing `03-UAT.md` remains `partial`; this report does not mark any live test passed.

### Observable Truths

| # | Roadmap truth | Status | Evidence |
|---|---|---|---|
| 1 | `diag`, queued interrupts, `pull`, and manual holds prevent automatic attacks until their exact release condition is satisfied. | ✓ VERIFIED | Exact owner logic is wired through `shouldHold`, `completeInterrupt`, and generation-owned pull state. `boop_interrupt_spec.lua` passed 3/3, `boop_diag_spec.lua` passed 3/3, six exact pull owner/generation cases passed, and prequeue/tick suites passed 13/13 and 30/30. |
| 2 | Gold pickup, pack/stash, retry, warning, and stale-pending behavior cannot send in the wrong room or bypass active safety holds. | ✓ VERIFIED | The 109-case aggregate passed; isolated gold retry passed 9/9 and tick passed 30/30. Canonical copied room evidence and exact operation room/generation/item checks remain wired in `boop_events.lua`. |
| 3 | `boop walk` start, stop, move, and status reflect settlement/blocker state and emit only when safe. | ✓ VERIFIED | Isolated `boop_walk_spec.lua` passed 39/39; the phase aggregate also passed. Final reservation emission still rechecks run generation, room generation, reservation identity, package availability, and aggregate all-clear. |
| 4 | `demonnicAutoWalker` remains optional with explicit install/status behavior and no silent update. | ✓ VERIFIED | Manifest/source inspection found no install/update path outside explicit install; the isolated walker suite includes and passed `never installs or updates from status, start, or move`. |
| 5 | Regression coverage catches unsafe movement, attacks during holds, wrong-room loot, target-removal queue drift, stale callbacks/retries, and permanent walk stalls. | ✗ FAILED | Core gold/walk/target suites pass, but five exact tracked timing tests fail after 03-14: two diagnose-timeout cases and three pull timer/owner cases. The plan aggregate did not include either affected spec. |

**Score:** 4/5 roadmap truths verified (0 present-but-behavior-unverified)

### Plan 03-14 Must-Haves

| # | Plan 03-14 truth | Status | Evidence |
|---|---|---|---|
| 1 | Disabled hunting leaves only lifecycle prompt/IRE evidence active; hunting triggers remain disabled. | ✓ VERIFIED | `src/triggers/triggers.json` has active `boop lifecycle` and inactive `boop`; the lifecycle child manifest contains exactly one `Prompt`; the exact lifecycle-boundary test passed. |
| 2 | IRE→prompt and prompt→IRE release only `gmcp:ire`, without Char.Status/enable, while unrelated owners survive. | ✓ VERIFIED | `reconcileIreSupport` records only exact-owner IRE evidence; `notePromptObserved` requires both declared evidence bits. The exact ordering test passed 1/1. |
| 3 | Disabled reconnect clears stale `gmcp_ire_missing` before enable when both evidence items arrive; enable-before-prompt remains held. | ✓ VERIFIED | Both disabled orderings and enable-before-prompt are asserted in the passing exact ordering test. |
| 4 | Disabled lifecycle callbacks cause no runtime step/apply, gag, target/gold/walk mutation, send, support request, or automation event. | ✓ VERIFIED | `onPrompt` returns at `boop_events.lua:1764` before runtime processing; Target Set/Info return at lines 1507/1533 after evidence-only reconciliation. The exact zero-side-effect test passed 1/1. |
| 5 | A 4.5-second accepted response is quiet; an incomplete 8.0-second response warns once and retains `room:observation`. | ✓ VERIFIED | Named constant and timer wiring are present; `timeoutRoomResponseFence` is one-shot and does not clear the owner. The exact room-warning test passed 1/1. |

### Gap Closure Mapping

| Gap | Automated status | Evidence | Live status |
|---|---|---|---|
| G-03-1 | ✓ CLOSED | Serialized Inv→Room response fences, same-room preservation, stale drain behavior, and walker settlement remain covered by the passing event/walk aggregate. | UAT Test 1 rerun pending. |
| G-03-2 | ✓ CLOSED | Canonical gold evidence, actual-change cancellation, success-owned packing, and wrong-room rejection remain covered by passing gold/event tests. | UAT Test 2 rerun pending. |
| G-03-3 | ✓ CLOSED in code/tests | All four exact `boop lifecycle recovery gap-03-3 ...` tests passed at HEAD. | Live disabled reconnect, room latency, and original blocked UAT rerun pending. |

## Required Artifacts

The artifact helper reported **70/71 existing** declarations and **41/41 key links**. The sole non-existing path is intentional: Plan 03-14 declares `src/triggers/boop/Core/Prompt.lua` as the removed legacy dispatcher. Manual semantic verification confirms its absence is the required state, so all 71 artifact declarations conform to their stated intent.

| Artifact | Expected | Status | Details |
|---|---|---|---|
| `tests/boop_lifecycle_spec.lua` | Four focused G-03-3 regressions | ✓ VERIFIED | 591 substantive lines; exactly four `gap-03-3` cases; all four pass individually. |
| `src/triggers/triggers.json` | Separate lifecycle and hunting folders | ✓ VERIFIED | `boop lifecycle` is active; `boop` is inactive by default. |
| `src/triggers/boop_lifecycle/triggers.json` | Prompt-only lifecycle manifest | ✓ VERIFIED | Exactly one active non-folder child, `Prompt`, using `return isPrompt()`. |
| `src/triggers/boop_lifecycle/Prompt.lua` | Thin lifecycle dispatcher | ✓ VERIFIED | Calls only `boop.onPrompt()`. |
| `src/triggers/boop/Core/Prompt.lua` | Legacy duplicate removed | ✓ VERIFIED (ABSENT AS REQUIRED) | File is absent; no other prompt Lua file exists under `src/triggers/boop`. |
| `src/triggers/boop/Core/triggers.json` | No duplicate Core prompt entry | ✓ VERIFIED | Contains only hunting-owned Core triggers; no `Prompt` entry. |
| `src/scripts/boop/boop_init.lua` | Independent folder synchronization and enable-boundary IRE reconciliation | ✓ VERIFIED | Always attempts lifecycle enable, then independently enables/disables hunting automation; enabled path reconciles IRE before automation synchronization. |
| `src/scripts/boop/boop_events.lua` | Canonical IRE observation, disabled early returns, event registration, 8-second warning | ✓ VERIFIED | Substantive and wired at connection, Char.Status, enable, Display/Target events, prompt, and response-fence timeout boundaries. |
| `tests/boop_diag_timeout_spec.lua` | Diagnose timeout/tombstone regression coverage | ✗ REGRESSION | Two exact tests fail because fixtures retain disabled state while expecting runtime prompt consumption. |
| `tests/boop_pull_spec.lua` | Pull owner/timer/race regression coverage | ✗ REGRESSION | Three exact lifecycle tests fail because delay-based timer classification collides with the new 8.0-second room warning. |

## Key Link Verification

| From | To | Via | Status | Details |
|---|---|---|---|---|
| Top-level trigger manifest | Lifecycle child manifest | `boop lifecycle` folder registration | ✓ WIRED | Muddler discovered and packaged the lifecycle Prompt. |
| Lifecycle Prompt | `boop.onPrompt` | Thin dispatcher | ✓ WIRED | Exactly one prompt script exists. |
| Display/Target events | `boop.onIreSupportObserved` | Anonymous event registrations | ✓ WIRED | ButtonActions, FixedFont, Ohmap, Target.Set, and Target.Info are registered once to the intended handlers. |
| Connection/Char.Status/enable/prompt/events | Canonical `gmcp:ire` owner | `reconcileIreSupport` → `noteGmcpObserved` / `notePromptObserved` | ✓ WIRED | No second lifecycle owner or direct clear path was found. |
| Disabled lifecycle callbacks | Safety boundary | Early returns before runtime/target automation | ✓ WIRED | Exact side-effect counters remain zero in the passing lifecycle test. |
| Response fence timer | Warning-only timeout | `timeoutRoomResponseFence` | ✓ WIRED | Warning is one-shot; `room:observation` remains active. |
| Plan 03-14 aggregate | Diagnose/pull regression specs | Test selection | ✗ NOT WIRED | The 109-case command omitted `boop_diag_timeout_spec.lua` and `boop_pull_spec.lua`, so both fixture regressions escaped GREEN verification. |

## Data-Flow Trace (Level 4)

| Artifact | Data | Source | Produces authoritative data | Status |
|---|---|---|---|---|
| `boop_events.lua` | IRE evidence | Current `gmcp.IRE.Target`/`Display` at explicit lifecycle/event boundaries | Yes; only `gmcp:ire` receives IRE evidence | ✓ FLOWING |
| `boop_runtime.lua` | Prompt/GMCP evidence bits | `notePromptObserved` and exact-owner `noteGmcpObserved` | Yes; auto-clear requires every declared evidence bit | ✓ FLOWING |
| `boop_init.lua` | Trigger-folder enabled state | Persisted `boop.config.enabled` | Yes; lifecycle remains active while hunting automation follows enabled state | ✓ FLOWING |
| `boop_events.lua` / `boop_runtime.lua` | Room warning state | Current response-fence ID, generation, room, and timer ID | Yes; accepted evidence cancels; matching incomplete timer warns once | ✓ FLOWING |
| `tests/boop_pull_spec.lua` | Pull timer identity | Timer delay comparison | No; 8.0-second room and pull timers are indistinguishable | ✗ HOLLOW TEST HEURISTIC |

## Behavioral Spot-Checks

| Behavior | Command/check | Result | Status |
|---|---|---|---|
| Four exact G-03-3 lifecycle behaviors | Four separate Busted `--name` invocations | 4 successes, 0 failures/errors | ✓ PASS |
| Plan 03-14 focused GREEN | Persistence + safety + event transitions + walk + gold + lifecycle | 109 successes, 0 failures/errors | ✓ PASS |
| Prior-phase isolated gate | Safety, state contract, and walk in separate processes | 4 + 3 + 39 = 46 successes | ✓ PASS |
| Interrupt ownership | Isolated `boop_interrupt_spec.lua` | 3 successes | ✓ PASS |
| Normal diagnose ownership | Isolated `boop_diag_spec.lua` | 3 successes | ✓ PASS |
| Queue/prequeue ownership | Isolated `boop_prequeue_spec.lua` | 13 successes | ✓ PASS |
| Gold retry and runtime tick | Isolated gold retry and tick specs | 9 + 30 successes | ✓ PASS |
| Runtime and trace ownership | Isolated runtime and trace specs | 14 + 5 successes | ✓ PASS |
| Pull generation/owner core | Six exact named pull tests | 6 successes | ✓ PASS |
| Diagnose stale-output/tombstone cases | Two exact named tests | 0/2 pass; assertions fail at lines 164 and 198 | ✗ FAIL |
| Pull return/timeout timer-count cases | Three exact named tests | 0/3 pass; observed counts 3/2/7 instead of 1/1/3 | ✗ FAIL |
| Psion/Dragon pull host checks | Two exact named host tests | Diagnostic-only failures because the host helper loads only the Occultist profile | ℹ EXCLUDED FROM BLOCKER COUNT |
| Lua syntax | `luac -p` over all `src/` and `tests/` Lua files | Exit 0 | ✓ PASS |
| Release gates | `python3 tools/check_release_gates.py` | versions, manifests, state-drift all `[OK]` | ✓ PASS |
| Package construction | `muddle` | Muddler 1.1.0 built `boop Hunter 0.1.427` | ✓ PASS |

The deliberately invalid attempt to run all 41 host specs in one shared Lua process was not repeated and is not counted.

## Probe Execution

Step 7c: **SKIPPED**. No Phase 03 PLAN/SUMMARY declares a probe, and no `scripts/**/tests/probe-*.sh` file exists.

## Requirements Coverage

| Requirement | Source plans | Status | Evidence |
|---|---|---|---|
| SAFE-02 | 03-01, 03-02, 03-03, 03-08, 03-09, 03-14 | ⚠ PARTIAL / BLOCKED | Exact-owner implementation and core diag/interrupt/pull tests pass, but two diagnose-timeout and three pull lifecycle regression tests are not green after 03-14. |
| SAFE-04 | 03-01, 03-04, 03-05, 03-08 through 03-11, 03-13, 03-14 | ✓ SATISFIED | Canonical response-fenced gold, exact room/generation/item checks, retries, owner holds, and independent get/put behavior pass focused tests. |
| WALK-01 | 03-01, 03-06, 03-07, 03-09, 03-11, 03-12, 03-14 | ✓ SATISFIED | Start/stop/move/status, settlement, tokenless arrival, and warning behavior are implemented and covered by passing walk/event/lifecycle tests. |
| WALK-02 | 03-01, 03-06 through 03-14 | ✓ SATISFIED | Walker emission remains gated by canonical room evidence and aggregate exact owners; isolated walk passed 39/39. |
| WALK-03 | 03-06 through 03-09, 03-11, 03-12, 03-14 | ✓ SATISFIED | Optional package behavior and no implicit install/update remain implemented and tested. |

Every requirement ID declared in all 14 PLAN frontmatters exists in `.planning/REQUIREMENTS.md`, maps to Phase 3, and is accounted for above. No Phase 03 requirement is orphaned.

## Commit and Version Verification

| Commit | Claimed purpose | Actual path/content evidence | Status |
|---|---|---|---|
| `8b84c94` | RED lifecycle contract | Adds `tests/boop_lifecycle_spec.lua` and synchronizes version 0.1.426 without production behavior changes | ✓ VERIFIED |
| `e42fc7c` | GREEN lifecycle implementation | Adds lifecycle manifest/Prompt, removes Core Prompt, changes init/events/tests, and synchronizes 0.1.427 | ✓ VERIFIED |
| `e0aade2` | Planning closeout | Changes only `.planning/ROADMAP.md`, `.planning/STATE.md`, and `03-14-SUMMARY.md` | ✓ VERIFIED |

Current version fields are synchronized at `0.1.427`: `mfile.version`, `mfile.title`, `boop.version`, and the `CODEX.md` checkpoint. No build output or `.mpackage` is tracked.

## Anti-Patterns Found

| File/scope | Pattern | Severity | Impact |
|---|---|---|---|
| Phase 03 declared source/tests/docs | `TBD`, `FIXME`, `XXX` | None | No unresolved debt-marker blocker found. |
| Phase 03 declared source/tests/docs | `TODO`, `HACK`, `PLACEHOLDER`, not-implemented wording | None material | Two “placeholder” matches are documentation/test terminology, not stubs. |
| `tests/boop_diag_timeout_spec.lua` | Fixture no longer matches explicit enabled/disabled lifecycle semantics | 🛑 BLOCKER | Two tracked regression tests fail. |
| `tests/boop_pull_spec.lua` | Delay used as timer identity | 🛑 BLOCKER | Three tracked regression tests fail after both timers became 8.0 seconds. |

## Human Verification Required After Automated Gaps Close

### 1. Disabled IRE evidence in both orders

**Test:** Run the Plan 03-14 live handoff scenarios for IRE event→prompt and prompt→IRE event while `boop off`, without Char.Status or enable; repeat duplicate inputs and preserve a seeded unrelated owner.

**Expected:** `gmcp:ire` remains until both `gmcpSeen` and `promptSeen` are true, then only that owner clears. The unrelated owner survives, and trace shows no attack, target update, get/put, queue execution, gag, or walker move.

**Why human:** Real Achaea GMCP event ordering and Mudlet prompt delivery are outside the host harness.

### 2. Enable-before-prompt recovery

**Test:** Observe current IRE while disabled, run `boop on` before the next prompt, inspect the owner, then cause one prompt with `ql`.

**Expected:** Enable leaves `gmcp:ire` held with `gmcpSeen=true` and `promptSeen=false`; the next prompt clears it once and a duplicate prompt is idempotent.

**Why human:** This crosses live trigger-folder activation, merged GMCP state, and prompt timing.

### 3. Ordinary and forced-missing room response timing

**Test:** Walk through at least five normal transitions, then use the reversible `boop.onRoomItemsList` suppression from the Plan 03-14 handoff for nine seconds and restore it immediately.

**Expected:** Normal responses inside 8.0 seconds do not warn and emit at most one move per settled room. Forced missing evidence warns/traces once, retains `room:observation`, and emits no move, attack, get, or put.

**Why human:** Real server response latency and external demonwalker behavior require Mudlet/Achaea.

### 4. Existing UAT Tests 1 and 2

**Test:** Rerun `03-UAT.md` Test 1 (cross-owner room/walk release with diag/interrupt/pull) and Test 2 (same-room gold, wrong-room cancellation, and inventory-owned packing).

**Expected:** No action occurs until every exact owner clears; then exactly one eligible action resumes. Gold sends one get and one matching put, same-room Info preserves pickup, actual movement cancels only room-owned acquisition, and no combat command contains get/put.

**Why human:** These are the live flows that exposed G-03-1, G-03-2, and G-03-3.

## External Authority Boundaries

- `/tmp/Mudlet.AppImage` is absent. Host Busted remains diagnostic and is not a substitute for real Mudlet.
- Parent exact-final-HEAD GitHub Actions CI has not run and is not claimed. The tracked CI includes all 41 specs, including the five exact cases currently failing locally.
- Live Achaea UAT has not run after 03-14 and is not claimed.
- The optional walker ownership UAT previously passed, but Tests 1 and 2 plus the new G-03-3 handoff remain unresolved.
- Phase 6 owns final recorded package/release evidence, but it does not explicitly defer or waive these Phase 03 regression failures.

## Gaps Summary

G-03-3's code path is implemented and its four focused tests pass, but Phase 03's regression contract is not complete. Plan 03-14 changed disabled prompt semantics and made the room warning equal the pull timeout without running the affected diagnose-timeout and pull specs. Five deterministic tracked tests now fail. Fix those test contracts and rerun verification; after automated gaps close, status should return to `human_needed` until the four live rerun groups above pass.

---

_Verified: 2026-07-27T07:34:23Z_
_Verifier: Codex (gsd-verifier)_
