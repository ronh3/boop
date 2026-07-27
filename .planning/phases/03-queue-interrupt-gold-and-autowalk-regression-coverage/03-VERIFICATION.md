---
phase: 03-queue-interrupt-gold-and-autowalk-regression-coverage
verified: 2026-07-27T12:21:27Z
status: human_needed
score: 5/5 must-haves verified
behavior_unverified: 0
overrides_applied: 0
re_verification:
  previous_status: gaps_found
  previous_score: 4/5
  gaps_closed:
    - "Diagnose timeout/tombstone fixtures now establish enabled runtime prompt processing while the separate disabled lifecycle contract remains automation-inert."
    - "Pull lifecycle assertions now identify the operation-owned timeout by state.combat.pullState.timeoutTimer while equal-delay room-response timers coexist."
  gaps_remaining: []
  regressions: []
deferred:
  - truth: "In-game pull help precisely distinguishes timeout-at-origin release from timeout-away hold-until-return behavior."
    addressed_in: "Phase 6"
    evidence: "Phase 6 success criterion 3 requires README, command help, UIDESIGN guidance, and dashboard copy to match every changed command surface or operator workflow."
human_verification:
  - test: "Push the immutable final committed HEAD and run tools/wait_for_exact_ci.sh against that exact SHA."
    expected: "main.yml succeeds with a matching headSha and the complete packaged real-Mudlet Busted run reports zero failures and zero errors, including the Psion and Dragon pull-profile cases."
    why_human: "Current HEAD is not on origin, /tmp/Mudlet.AppImage is unavailable, and the host bootstrap loads only the Occultist profile."
  - test: "In real Mudlet while boop is disabled, exercise IRE-event then prompt, prompt then IRE-event, and enable-before-prompt recovery with an unrelated blocker installed."
    expected: "Only gmcp:ire clears after both evidence items; the unrelated owner survives, enable-before-prompt remains held until the prompt, and disabled callbacks emit no attack, target, gold, queue, gag, or walker side effects."
    why_human: "Host tests cannot prove installed trigger-folder state and live Mudlet GMCP/prompt event sequencing."
  - test: "Rerun the live room-settlement/cross-owner walk flow from 03-UAT.md, including same-room ql, stop/restart, a diag during transition, ordinary latency, and one forced incomplete room response."
    expected: "No attack, get/put, or demonwalker.move occurs while any owner remains; each settled room emits at most one move; sub-8-second responses stay quiet; an incomplete 8-second fence warns once and remains fail closed."
    why_human: "This depends on live GMCP response ordering, timer latency, and the external demonnicAutoWalker integration."
  - test: "Rerun the live wrong-room gold and pack-transfer flow from 03-UAT.md."
    expected: "Same-room ql preserves one pickup, movement before confirmation produces no stale get/retry, confirmed pickup permits exactly one inventory-owned put after movement, and no combat command contains get or put."
    why_human: "Live inventory/room GMCP and Achaea command confirmations cannot be reproduced authoritatively by the host stubs."
---

# Phase 3: Queue, Interrupt, Gold, and Autowalk Regression Coverage Verification Report

**Phase Goal:** Timing-sensitive command paths cannot attack, loot, or walk while another safety hold or room-state blocker owns the next action.
**Verified:** 2026-07-27T12:21:27Z
**Status:** human_needed
**Re-verification:** Yes — after Plan 03-15 gap closure
**Verified HEAD:** `2a82dbdb52239c71b06122bf84252a1502936516`
**Branch:** `codex/pre-1.0-hardening-pass`
**Package version:** `0.1.429`

## Goal Achievement

The Phase 03 implementation goal is present, substantive, wired, and exercised by focused behavioral tests. The two automated gaps from the previous report are closed at current HEAD:

- `tests/boop_diag_timeout_spec.lua` now enables automation in both prompt-consuming timeout/tombstone cases; the isolated file passes 3/3.
- `tests/boop_pull_spec.lua` resolves pull timeout identity from `state.combat.pullState.timeoutTimer`; all three previously failing lifecycle cases pass independently while unrelated 8.0-second response-fence timers remain in the fixture.
- `tests/boop_lifecycle_spec.lua` restores replaced package tables after every case; the lifecycle-to-menu canary passes 17/17 without reset or teardown errors.

The phase is not fully verified yet. The complete packaged real-Mudlet suite has not run at the immutable final SHA, and the existing live UAT history remains partial. Those are external/runtime authority checks, not observable automated implementation failures, so the status is `human_needed`, not `gaps_found`.

### Observable Truths

| # | Roadmap truth | Status | Evidence |
|---|---|---|---|
| 1 | `diag`, queued interrupts, `pull`, and manual holds prevent automatic attacks until their prompt, room, or timeout release condition is satisfied. | ✓ VERIFIED | Exact-owner operations are wired through `setBlocker`, `shouldHold`, `completeInterrupt`, and generation-owned pull state. Verifier-run lifecycle/diag/diag-timeout/interrupt/prequeue/tick checks passed 102/102 in isolated host processes; the three exact pull lifecycle cases also passed independently. |
| 2 | Gold pickup, pack/stash, retry, warning, and stale-pending behavior cannot send commands in the wrong room or bypass active safety holds. | ✓ VERIFIED | Gold dispatch checks the exact operation owner, canonical copied room observation, room ID/generation, item identity, and unrelated combat/queue/gold/walk owners before sending. Verifier-run gold and retry specs passed 8/8 and 9/9; event-transition and tick specs passed 46/46 and 30/30. |
| 3 | `boop walk` start, stop, move, and status reflect room settlement/blockers and emit `demonwalker.move` only when safe. | ✓ VERIFIED | Start creates a fresh room epoch and exact walk owner; normal/manual movement shares `evaluateAllClear`; the reserved emitter rechecks run, room generation, reservation ID, package availability, settlement, and every unrelated hold. Verifier-run walk spec passed 39/39. |
| 4 | `demonnicAutoWalker` remains optional with explicit install/status feedback and no silent auto-update. | ✓ VERIFIED | Production search finds `installPackage` only inside `boop.walk.install`; `demonwalker.move` and `.stop` each have one guarded emitter. The walk test `never installs or updates from status, start, or move` is part of the passing 39-case spec. |
| 5 | Regression coverage catches unsafe movement, attacks during holds, wrong-room loot, target-removal queue drift, and permanent walk stalls. | ✓ VERIFIED | Named tests cover both blocker clear orders, captured prequeue callbacks, response-fence ordering, stale room/gold callbacks, target-removal queue drift, timeout-under-owner liveness, and one guarded walk move. All relevant verifier-run host specs passed. |

**Score:** 5/5 roadmap truths verified (0 present-but-behavior-unverified)

### Plan Must-Have Audit

| Scope | Status | Evidence |
|---|---|---|
| Plans 03-01 through 03-13 implementation/test must-haves | ✓ VERIFIED | Owner registry, interrupt/pull operations, staged gold, response-fenced room evidence, walker reservation/emission, UI snapshots, and cross-lifecycle regressions exist in production/test code and pass focused host checks. |
| Plan 03-14 disabled-safe lifecycle and 8-second warning must-haves | ✓ VERIFIED automated | Active prompt-only lifecycle folder, disabled early returns, exact `gmcp:ire` evidence, and warning-only room timeout are wired. Four lifecycle tests pass. Live ordering/latency remains below under Human Verification. |
| Plan 03-15 fixture isolation and diagnose/pull contract must-haves | ✓ VERIFIED | Exact package-table restoration, explicit enabled diagnose preconditions, operation timer identity, and bounded host processes are present and pass. |
| Plan 03-15 complete packaged real-Mudlet suite must-have | ? UNCERTAIN — HUMAN REQUIRED | CI wiring exists, but current HEAD is ahead of origin and no matching successful `main.yml` run exists. The local AppImage is absent. |
| Plan 03-15 UAT blocking boundary | ✓ VERIFIED | Live UAT remains correctly blocked pending exact-SHA CI; this report does not overwrite or mark the existing UAT passed. |
| Plans 03-08/03-09 exact help coherence | ↪ DEFERRED TO PHASE 6 | `boop_ui_registry.lua:778` retains an ambiguous legacy pull-timeout sentence. Phase 6 explicitly owns command-help/documentation coherence. It does not weaken runtime safety. |

### Deferred Items

| # | Item | Addressed In | Evidence |
|---|---|---|---|
| 1 | Clarify pull help so timeout-at-origin release and timeout-away hold-until-return are stated exactly. | Phase 6 | Phase 6 success criterion 3 requires command help and docs to match changed behavior. |

## Required Artifacts

The artifact helper reported 74/75 declarations present. The one reported absence is intentional: Plan 03-14 requires the legacy `src/triggers/boop/Core/Prompt.lua` dispatcher to be removed. Manual semantic review therefore resolves the artifact contract as 75/75.

| Artifact | Expected | Status | Details |
|---|---|---|---|
| `src/scripts/boop/boop_runtime.lua` | Exact-owner blockers, room response fences, interrupt terminal, aggregate tick gates | ✓ VERIFIED | Substantive implementation; owner set/clear/exclusion is wired into runtime effects. |
| `src/scripts/boop/boop_events.lua` | Room/GMCP adapters, staged gold, prompt lifecycle boundary | ✓ VERIFIED | Accepts only current fenced room snapshots, gates gold, handles pull return, and exits before automation while disabled. |
| `src/scripts/boop/boop_ui.lua` | Interrupt and pull operation creation | ✓ VERIFIED | Creates exact generation owners/timers, rejects repeats, and leaves saved enabled intent unchanged. |
| `src/scripts/boop/boop_walk.lua` | Shared movement gate and guarded external emitter | ✓ VERIFIED | Start/stop/detach/arrival/settlement/reservation behavior is substantive and wired to `demonwalker` events. |
| `src/scripts/boop/boop_util.lua` | Combat dispatch without chained gold | ✓ VERIFIED | `executeAction` sends only the supplied combat action; gold uses its separate freestand queue path. |
| `src/triggers/boop_lifecycle/triggers.json` and `Prompt.lua` | Always-available prompt evidence only | ✓ VERIFIED | Top-level lifecycle folder is active and has exactly one prompt child calling `boop.onPrompt()`. |
| `src/triggers/boop/Core/Prompt.lua` | Legacy prompt dispatcher removed | ✓ VERIFIED — ABSENT AS REQUIRED | File does not exist; no duplicate Core prompt entry remains. |
| `tests/boop_lifecycle_spec.lua` | Disabled lifecycle and fixture-isolation regressions | ✓ VERIFIED | 610 substantive lines; restores exact package-table references; 4/4 pass. |
| `tests/boop_diag_timeout_spec.lua` | Timeout/tombstone contracts with correct runtime preconditions | ✓ VERIFIED | Prompt-consuming cases explicitly set `boop.config.enabled = true`; 3/3 pass. |
| `tests/boop_pull_spec.lua` | Operation-owned timer and stale callback contracts | ✓ VERIFIED | Uses `pullState.timeoutTimer`; all three actionable cases pass independently. |
| Gold, walk, runtime, event, prequeue, tick specs | Phase-wide behavioral coverage | ✓ VERIFIED | Verifier-run focused files pass with zero failures/errors. |
| `.github/workflows/main.yml` and `tools/wait_for_exact_ci.sh` | Complete packaged Mudlet suite and exact-SHA authority | ✓ WIRED / ? NOT EXECUTED | CI imports the built package and runs the complete tests directory; exact-SHA script validates origin, `headSha`, success, and immutable worktree. No current final-SHA result exists. |

## Key Link Verification

The key-link helper reported 44/46. Both reported failures are pattern-escaping false negatives and pass manual inspection, yielding 46/46 semantic links:

- `tests/boop_diag_timeout_spec.lua` sets `boop.config.enabled = true` before both prompt-consuming cases, and `boop.onPrompt()` retains the disabled early return.
- `tests/boop_pull_spec.lua` reads `boop.state.combat.pullState.timeoutTimer` in `pullTimer()` and invokes the captured callback while separately counting unrelated timers.

| From | To | Via | Status | Details |
|---|---|---|---|---|
| Owner registry | Tick, prequeue, gold, walk | `shouldHold(system, exceptOwner)` | ✓ WIRED | Exact self-owner exclusion never suppresses unrelated owners. |
| Room.Info and item Lists | Runtime observation | serialized Inv→Room fence | ✓ WIRED | Only copied accepted current-epoch room items reach consumers. |
| Accepted room observation | Targets, gold, walker | one adapter application path | ✓ WIRED | Pre-barrier, stale, duplicate, and mismatched Lists do not authorize downstream effects. |
| Interrupt command | Runtime terminal | generation + `interrupt:<generation>` | ✓ WIRED | Prompt/result/timeout terminal clears only the exact owner. |
| Pull command and Room.Info | Pull terminal | generation, phase, origin room, exact timer | ✓ WIRED | Timeout-away keeps the owner; matching return completes once. |
| Gold operation | Queue command | exact room/generation/item plus aggregate holds | ✓ WIRED | Get-confirm-put is independent from combat dispatch. |
| Walker reservation | External walker | final reservation/all-clear recheck | ✓ WIRED | One `demonwalker.move` emitter exists. |
| Lifecycle prompt/IRE events | `gmcp:ire` owner | evidence-only disabled observers | ✓ WIRED | Disabled callbacks reconcile lifecycle evidence and return before runtime automation. |
| GitHub Actions | Complete tests directory | packaged real-Mudlet profile | ✓ WIRED / ? NOT RUN AT FINAL SHA | Authority exists but is pending execution. |

## Data-Flow Trace (Level 4)

| Artifact | Data | Source | Produces authoritative data | Status |
|---|---|---|---|---|
| `boop_runtime.lua` | Active safety owners | Exact lifecycle set/clear operations | Yes; immutable sorted snapshots and exact-owner exclusion | ✓ FLOWING |
| `boop_events.lua` | Current room items | Room.Info epoch plus serialized Inv→Room response fence | Yes; deep-copied accepted items only | ✓ FLOWING |
| Gold operation | Pickup/pack stage | Accepted room snapshot, command confirmation, inventory transfer | Yes; room-owned get becomes roomless inventory-owned put only after success | ✓ FLOWING |
| `boop_walk.lua` | Move reservation | Current settled room, target/denizen state, gold/diag/pull/flee state, blocker snapshot | Yes; captured run/room/reservation reaches one guarded emitter | ✓ FLOWING |
| Lifecycle observer | IRE/prompt evidence | Installed GMCP events and prompt-only lifecycle trigger | Yes in code/host tests; installed live ordering still needs UAT | ⚠ LIVE CHECK PENDING |

## Behavioral Spot-Checks

| Behavior | Command/check | Result | Status |
|---|---|---|---|
| Affected Plan 03-15 suites | Seven isolated `busted --helper=tests/support/boop_host_busted_helper.lua <spec>` processes | 102 successes, 0 failures, 0 errors | ✓ PASS |
| Lifecycle shared-state restoration | Lifecycle + menu wiring in one deliberate process | 17 successes, 0 failures, 0 errors | ✓ PASS |
| Three prior pull timer regressions | Three independent exact-name Busted invocations | 1 success each; 0 failures/errors | ✓ PASS |
| Runtime/gold/retry/walk contracts | Four isolated focused specs | 14 + 8 + 9 + 39 successes; 0 failures/errors | ✓ PASS |
| Prior-phase safety/state/walk canary | Safety + state-contract + walk specs | 4 + 3 + 39 successes; 0 failures/errors | ✓ PASS |
| Complete host pull diagnostic | Full `tests/boop_pull_spec.lua` under Occultist-only helper | 11 successes, exactly 2 Psion/Dragon profile exclusions, 0 errors | ℹ DIAGNOSTIC ONLY |
| Lua syntax | `luac -p` over 24 phase-relevant Lua files | Exit 0 | ✓ PASS |
| Release gates | `python3 tools/check_release_gates.py` | versions, manifests, state-drift all `[OK]` | ✓ PASS |
| Diff/worktree pre-write check | `git diff --check`; `git status --short` | Clean before this report replacement | ✓ PASS |
| Muddler package construction | Parent-provided current-HEAD evidence | Muddler 1.1.0 built package 0.1.429 | ✓ PASS — PARENT EVIDENCE |
| Complete local real-Mudlet suite | `/tmp/Mudlet.AppImage` availability check | AppImage absent | ? SKIP |
| Exact-final-SHA `main.yml` | Local HEAD/origin comparison | HEAD `2a82dbd`; origin branch `150b3e3`; no final-SHA gate | ? HUMAN REQUIRED |

## Probe Execution

No Phase 03 plan/summary declares a probe, and no conventional `scripts/*/tests/probe-*.sh` files were discovered.

| Probe | Command | Result | Status |
|---|---|---|---|
| None | Discovery only | No probes declared or found | SKIPPED |

## Requirements Coverage

Every requirement ID declared across all 15 PLAN frontmatter blocks is present in `.planning/REQUIREMENTS.md`. Their union exactly matches the five requirements mapped to Phase 03; no orphaned Phase 03 requirement exists.

| Requirement | Source Plans | Description | Status | Evidence |
|---|---|---|---|---|
| SAFE-02 | 03-01, 02, 03, 08, 09, 14, 15 | Interrupt, pull, diag, and manual holds prevent attacks until exact release. | ✓ SATISFIED | Exact-owner runtime plus passing interrupt/diag/pull/prequeue/tick/lifecycle tests. |
| SAFE-04 | 03-01, 04, 05, 08, 09, 10, 11, 13, 14 | Gold cannot act in the wrong room or bypass safety holds. | ✓ SATISFIED | Canonical room evidence, staged gold ownership, passing gold/retry/event/tick tests. |
| WALK-01 | 03-01, 06, 07, 08, 09, 11, 12, 14 | Walk tests cover start/stop/move/settlement/reasons/external emission. | ✓ SATISFIED | Passing 39-case walk spec plus event-transition integration. |
| WALK-02 | 03-01, 06, 07, 08, 09, 10, 11, 12, 13, 14 | Walker advancement remains blocked by unsafe room/runtime state. | ✓ SATISFIED | Shared all-clear and reserved-emitter recheck; timeout-under-owner liveness passes. |
| WALK-03 | 03-06, 07, 08, 09, 12, 14 | External walker remains optional and explicit. | ✓ SATISFIED | Single explicit install path, no update path, passing package-loss/install/status tests. |

## Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|---|---|---|---|---|
| `src/scripts/boop/boop_ui_registry.lua` | 778 | Legacy pull-timeout help is less precise than current timeout-away ownership behavior | ⚠ Warning — deferred | Operator wording should distinguish timeout-at-origin release from timeout-away hold-until-return. Phase 6 owns final help/doc coherence. Runtime behavior is unaffected. |
| Phase-modified source/tests | — | `TBD`, `FIXME`, `XXX`, placeholder, or empty user-visible implementation | None | No blocker debt markers or substantive stubs found. |

## Human Verification Required

### 1. Exact-final-SHA packaged real-Mudlet CI

**Test:** After this verification and all remaining planning mutations are committed, push the immutable final HEAD and run `tools/wait_for_exact_ci.sh "$FINAL_SHA"`.

**Expected:** A successful `main.yml` run whose `headSha` exactly equals `FINAL_SHA`; the complete packaged Busted directory reports zero failures and zero errors, including Psion and Dragon pull cases.

**Why human:** Current HEAD has not been pushed, the local AppImage is absent, and host execution cannot load every class profile.

### 2. Disabled lifecycle recovery

**Test:** In real Mudlet with `boop off`, exercise IRE→prompt and prompt→IRE orderings with an unrelated blocker, then test enabling before the next prompt.

**Expected:** `gmcp:ire` clears only after both evidence items, the unrelated owner survives, enable-before-prompt remains held, and disabled evidence produces no automation side effect.

**Why human:** Installed trigger activation and live GMCP/prompt ordering are not authoritative in the host harness.

### 3. Live room settlement and cross-owner walk

**Test:** Rerun UAT Test 1, including same-room `ql`, stop/restart, a `diag` during transition, ordinary response latency, and one forced incomplete response.

**Expected:** No attack, loot, queue, or movement side effect while any owner remains; exactly one eligible next action after all owners clear; at most one move per settled room; one fail-closed warning only after an incomplete 8-second fence.

**Why human:** Requires live Achaea GMCP timing and the real external walker.

### 4. Live wrong-room gold and pack transfer

**Test:** Rerun UAT Test 2 with one same-room refresh, movement before pickup confirmation, and movement after confirmed pickup.

**Expected:** Same-room refresh preserves exactly one get; wrong-room stale work sends nothing; confirmed pickup permits exactly one inventory-owned put after movement; no attack command contains loot.

**Why human:** Requires live room/inventory GMCP and actual command confirmation lines.

The optional-walker ownership UAT already passed and does not need to be repeated unless the package/runtime changed.

## Adversarial Disconfirmation

- **Partially verified boundary:** Packaged real-Mudlet execution is wired but not run at final SHA; host success is not treated as equivalent.
- **Potentially misleading test signal:** The complete host pull file exits nonzero for exactly two profile cases because the helper loads only Occultist. Only the three isolated timer-identity cases count as host GREEN; Psion/Dragon remain CI-only.
- **Uncovered host error path:** Live trigger-folder activation, GMCP event ordering/latency, and external walker behavior cannot be proven by local stubs and are explicitly routed to human verification.

## Gaps Summary

No automated implementation gaps remain at current HEAD. The previous diagnose-timeout and pull timer-identity gaps are closed, and the roadmap goal is supported by passing focused behavior tests.

Phase completion still requires the exact-final-SHA packaged real-Mudlet CI gate followed by the live lifecycle, room/walk, and gold reruns above. Existing `03-UAT.md` history remains unchanged: its optional-walker test passed, while the previously failed/blocked flows still need post-fix reruns.

---

_Verified: 2026-07-27T12:21:27Z_
_Verifier: Codex (gsd-verifier)_
