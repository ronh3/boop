---
phase: 01-release-gates-and-state-contracts
status: diagnosed
started: 2026-07-09T21:12:56Z
updated: 2026-07-10T03:06:06Z
source:
  - 01-01-SUMMARY.md
  - 01-02-SUMMARY.md
  - 01-03-SUMMARY.md
counts:
  total: 8
  passed: 7
  issues: 1
  pending: 0
  skipped: 0
  blocked: 0
---

# Phase 01 UAT: Release Gates and State Contracts

## Current Status

Phase 01 implementation coverage is green for local static checks and summary-derived acceptance criteria. Full Mudlet/Busted execution is now available through `/tmp/Mudlet.AppImage`, but final sign-off is blocked by failing full-suite results. The latest focused repair removed the early attack-profile import failure, reducing the suite from `154 successes / 112 failures / 6 errors` to `464 successes / 45 failures / 3 errors`. The remaining failure clusters have been split into diagnosed gaps below for gap-only execution.

## Tests

1. **Local release gate CLI validates synchronized versions, JSON/manifests, and reviewed state drift.**
   - Requirement: REL-01
   - Source: `01-01-SUMMARY.md` coverage D1
   - Result: pass
   - Evidence: `python3 tools/check_release_gates.py`; `python3 tools/check_release_gates.py --check versions`

2. **Manifest parity baseline is clean after removing duplicate IH alias source and fixing Two Handed trigger names.**
   - Requirement: REL-02
   - Source: `01-01-SUMMARY.md` coverage D2
   - Result: pass
   - Evidence: `python3 tools/check_release_gates.py --check manifests`; `test ! -e src/aliases/boop/Targeting/Boop_IH.lua && test -f src/aliases/boop/Targeting/IH.lua`

3. **Known flat-state access is explicitly baselined and fails when new access is introduced.**
   - Requirement: REL-04
   - Source: `01-01-SUMMARY.md` coverage D3
   - Result: pass
   - Evidence: `python3 tools/check_release_gates.py --check state-drift`; temporary probe failure was confirmed during implementation and restored to green

4. **GitHub Actions blocks on the local release gate before package metadata and Muddler build steps.**
   - Requirement: REL-01
   - Source: `01-02-SUMMARY.md` coverage D1
   - Result: pass
   - Evidence: `python3 tools/check_release_gates.py`; workflow order assertion for `Release gates` before `Read package metadata` and `Muddle`

5. **CODEX documents local focused release-gate commands and the full Mudlet Busted path.**
   - Requirement: REL-02
   - Source: `01-02-SUMMARY.md` coverage D2
   - Result: pass
   - Evidence: `rg CODEX.md` for `--check versions`, `--check manifests`, `--check state-drift`, and `/tmp/Mudlet.AppImage`

6. **Owned runtime domains and defaults are covered by a focused Busted spec.**
   - Requirement: REL-04
   - Source: `01-03-SUMMARY.md` coverage D1
   - Result: pass
   - Evidence: `test -f tests/boop_state_contract_spec.lua`; `luac -p tests/boop_state_contract_spec.lua`; `python3 tools/check_release_gates.py --check state-drift`

7. **Runtime context mapping reads seeded owned-domain values for target, queue, gold, diag, inventory, and rage.**
   - Requirement: REL-04
   - Source: `01-03-SUMMARY.md` coverage D2
   - Result: pass
   - Evidence: `rg tests/boop_state_contract_spec.lua` for `boop.runtime.context()` and seeded owned-domain assertions

8. **Full Mudlet/Busted execution must pass with Mudlet 4.20.1 before Phase 01 sign-off.**
   - Requirement: REL-04
   - Source: `01-03-SUMMARY.md` coverage D3
   - Result: issue
   - Evidence: `/tmp/Mudlet.AppImage` extracted from `Mudlet-4.20.1-linux-x64.AppImage.tar`; containerized CI-style Mudlet run saved at `/tmp/boop-mudlet-0.1.338.raw.log`
   - Current result: `464 successes / 45 failures / 3 errors / 0 pending`
   - Remaining failure clusters: gag summaries, pull command behavior, UI/menu callback counts, IH capture, stats whitelist output, and two attack-selection edge cases

## Gaps

- id: G-01-8A
  truth: "Attack selection must use current-target HP and readiness data without trusting stale GMCP target info."
  status: failed
  reason: "Full Mudlet/Busted: boop_attacks_spec.lua @ 26 and @ 48 fail; opener is selected for mismatched target HP and shieldbreak-disabled rage fallback returns empty instead of harry."
  severity: major
  test: 8
  root_cause: "boop.runtime.context() combines the canonical current target id with gmcp.IRE.Target.Info.hpperc, so stale target-info HP can look current. The shieldbreak-disabled fallback also needs a targeted decision on whether rage readiness should be seeded in tests or relaxed in code."
  artifacts:
    - path: "src/scripts/boop/boop_runtime.lua"
      issue: "target.hpperc is copied from gmcp target info without preserving the target-info id used to validate it"
    - path: "src/scripts/boop/boop_attacks.lua"
      issue: "known-HP and simple rage selection consume the flattened runtime target context"
    - path: "tests/boop_attacks_spec.lua"
      issue: "captures both stale target HP and shieldbreak-disabled fallback expectations"
    - path: "/tmp/boop-mudlet-0.1.338.raw.log"
      issue: "full-suite evidence for the two attack-selection failures"
  missing:
    - "Preserve or validate GMCP target-info id before treating hpperc as known for the current target."
    - "Make the shieldbreak-disabled fallback expectation explicit by either seeding Harry readiness or adjusting readiness rules intentionally."
  debug_session: ".planning/debug/phase-01-full-mudlet-busted.md"

- id: G-01-8B
  truth: "Room transitions and pull lifecycle must read and write owned state domains."
  status: failed
  reason: "Full Mudlet/Busted: boop_event_transitions_spec.lua @ 125 and boop_pull_spec.lua @ 46, @ 62, @ 88, @ 108, @ 124, @ 141, and @ 153 fail."
  severity: major
  test: 8
  root_cause: "boop.onRoomInfo() still treats boop.state as a flat table for room, lastRoom, lastRoomDir, fleeing, and pullState, while current state lives under boop.state.targeting and boop.state.combat. Pull command setup writes boop.state.combat.pullState, but room transitions inspect boop.state.pullState, so phase changes and resume/timeout cleanup do not line up."
  artifacts:
    - path: "src/scripts/boop/boop_events.lua"
      issue: "onRoomInfo uses legacy flat fields instead of targeting/combat domains"
    - path: "src/scripts/boop/boop_ui.lua"
      issue: "pull command lifecycle depends on owned combat.pullState and currentRoomId"
    - path: "tests/boop_event_transitions_spec.lua"
      issue: "room transition and gold-clear regression coverage"
    - path: "tests/boop_pull_spec.lua"
      issue: "pull command separator, timeout, room return, and input-safety coverage"
    - path: "/tmp/boop-mudlet-0.1.338.raw.log"
      issue: "full-suite evidence for event and pull failures"
  missing:
    - "Rewrite onRoomInfo around boop.state.targeting and boop.state.combat domains."
    - "Ensure pull phase changes, timeout cleanup, and boop resume decisions share the same owned pull state."
    - "Keep separator and mob-name safety feedback covered while fixing the lifecycle."
  debug_session: ".planning/debug/phase-01-full-mudlet-busted.md"

- id: G-01-8C
  truth: "GMCP support negotiation must retry when Char.Status arrives before IRE GMCP is active."
  status: failed
  reason: "Full Mudlet/Busted: boop_event_transitions_spec.lua @ 188 fails because Core.Supports.Add for IRE.Target is not sent."
  severity: major
  test: 8
  root_cause: "boop.onCharStatus() routes through boop.requestCoreSupports({ requestSkills = true, minInterval = 2 }); if a prior announce timestamp exists, the missing-IRE recovery path can be throttled even though GMCP support is incomplete."
  artifacts:
    - path: "src/scripts/boop/boop_events.lua"
      issue: "onCharStatus missing-IRE support retry is min-interval throttled"
    - path: "src/scripts/boop/boop_init.lua"
      issue: "requestCoreSupports owns announce throttling"
    - path: "tests/boop_event_transitions_spec.lua"
      issue: "GMCP missing-IRE retry coverage"
    - path: "/tmp/boop-mudlet-0.1.338.raw.log"
      issue: "full-suite evidence for support retry failure"
  missing:
    - "Force or otherwise bypass throttling when gmcp.IRE, gmcp.IRE.Target, or gmcp.IRE.Display is absent."
    - "Keep normal connection-ready throttling intact for non-recovery calls."
  debug_session: ".planning/debug/phase-01-full-mudlet-busted.md"

- id: G-01-8D
  truth: "Gag summaries must reduce scroll while preserving attack, proc, crit, balance, prompt, kill, and XP signal."
  status: failed
  reason: "Full Mudlet/Busted: 24 boop_gag_spec.lua cases fail across own attacks, procs, DSL merging, companion mauls, standalone battlerage, alternate wording, and kill/XP compaction."
  severity: major
  test: 8
  root_cause: "The gag summary pipeline is failing across the pending-attack/pending-kill merge surface rather than one isolated assertion. The failing cases all exercise boop.gag pending state, timer flush, source grouping, prompt flush, or kill-summary ordering in src/scripts/boop/boop_gag.lua."
  artifacts:
    - path: "src/scripts/boop/boop_gag.lua"
      issue: "pending summary state machine does not satisfy existing compact-summary fixtures"
    - path: "tests/boop_gag_spec.lua"
      issue: "focused coverage for attack/proc/crit/balance/prompt/kill summary behavior"
    - path: "/tmp/boop-mudlet-0.1.338.raw.log"
      issue: "full-suite evidence for the gag failure cluster"
  missing:
    - "Replay boop_gag_spec.lua in small groups and repair the pending summary pipeline with stable ordering."
    - "Preserve unknown/safety-relevant lines while compacting only known summaries."
  debug_session: ".planning/debug/phase-01-full-mudlet-busted.md"

- id: G-01-8E
  truth: "Plain output for IH and whitelist stats must preserve operator actions and mob XP signal."
  status: failed
  reason: "Full Mudlet/Busted: boop_ih_spec.lua @ 121 and boop_stats_spec.lua @ 856 fail."
  severity: major
  test: 8
  root_cause: "boop.ih.handleLine() only adds whitelist/blacklist labels when the IH row name is already recognized as a known denizen, while the test expects valid IH object rows to expose actions. The whitelist stats failure needs targeted replay of displayWhitelist after mob XP samples are recorded."
  artifacts:
    - path: "src/scripts/boop/boop_ih.lua"
      issue: "plain IH fallback suppresses list actions for valid object rows that are not pre-known denizens"
    - path: "src/scripts/boop/boop_targets.lua"
      issue: "plain whitelist output is expected to append boop.stats.formatMobXp summaries"
    - path: "tests/boop_ih_spec.lua"
      issue: "IH object-row action coverage"
    - path: "tests/boop_stats_spec.lua"
      issue: "plain whitelist mob XP summary coverage"
    - path: "/tmp/boop-mudlet-0.1.338.raw.log"
      issue: "full-suite evidence for IH and stats output failures"
  missing:
    - "Decide and implement the intended IH action policy for valid object rows in plain mode."
    - "Ensure mob XP summaries are recorded and rendered in plain whitelist output."
  debug_session: ".planning/debug/phase-01-full-mudlet-busted.md"

- id: G-01-8F
  truth: "UI registries, menu wiring, and config callbacks must remain coherent after package reload and helper reset."
  status: failed
  reason: "Full Mudlet/Busted: boop_menu_wiring_spec.lua @ 118, @ 184, @ 261, @ 333; boop_ui_registry_spec.lua @ 43; boop_ui_spec.lua @ 203, @ 220, @ 268, @ 298, and @ 310 fail."
  severity: major
  test: 8
  root_cause: "Several failures are stale callback-count expectations after new controls were added, but config action failures also show registry attachment/reset drift. helper.reset() clears boop.ui tables after state init attaches registries, and production config paths need to reattach or fall back consistently before dispatching callbacks."
  artifacts:
    - path: "src/scripts/boop/boop_ui_registry.lua"
      issue: "shared config registries must reattach cleanly after stale table replacement"
    - path: "src/scripts/boop/boop_ui.lua"
      issue: "config routes and return-screen refresh depend on attached registries"
    - path: "tests/support/boop_test_helper.lua"
      issue: "reset ordering can clear UI registry tables after state init"
    - path: "tests/boop_menu_wiring_spec.lua"
      issue: "callback counts and seed expectations need reconciliation with current UI"
    - path: "tests/boop_ui_registry_spec.lua"
      issue: "reload registry attachment coverage"
    - path: "tests/boop_ui_spec.lua"
      issue: "config numeric dispatch and return-screen behavior coverage"
    - path: "/tmp/boop-mudlet-0.1.338.raw.log"
      issue: "full-suite evidence for UI/menu failures"
  missing:
    - "Reattach shared UI/config registries after reset/reload and before config dispatch."
    - "Update stale menu wiring counts only where the current UI intentionally added or removed controls."
    - "Keep config section actions scoped to their current section and restore the correct section after seeded commands."
  debug_session: ".planning/debug/phase-01-full-mudlet-busted.md"
