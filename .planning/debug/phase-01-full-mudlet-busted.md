---
phase: 01-release-gates-and-state-contracts
source: 01-UAT.md
created: 2026-07-10T03:06:06Z
status: diagnosed
mode: inline
---

# Phase 01 Full Mudlet/Busted Diagnosis

GSD normally diagnoses UAT gaps with `gsd-debugger` subagents. The multi-agent tool is available in this runtime, but it requires explicit user authorization for sub-agents. This diagnosis was performed inline from the full Mudlet/Busted log and the owning source/tests.

## Evidence

- Latest log: `/tmp/boop-mudlet-0.1.338.raw.log`
- Suite result: `464 successes / 45 failures / 3 errors / 0 pending`
- Prior import-order failure was removed by commit `5ae5bb2`.
- Compile/import signal after that repair: `compile-error-count 0`, `boop-nil-count 0`.

## Gap Diagnosis

| Gap | Failure Cluster | Root Cause | Fix Direction |
|-----|-----------------|------------|---------------|
| G-01-8A | `boop_attacks_spec.lua` @ 26, @ 48 | Runtime target context flattens current target id and GMCP target-info HP, allowing stale HP to be treated as known. The shieldbreak-disabled fallback also needs explicit readiness intent for Harry. | Preserve target-info id or blank stale hpperc in `boop.runtime.context()`, then clarify rage readiness/test seeding for the Harry fallback. |
| G-01-8B | room transition and pull tests | `boop.onRoomInfo()` still uses legacy flat `boop.state` fields while current state lives under `targeting` and `combat`. Pull writes `combat.pullState` but room transitions inspect `pullState` on the wrong table. | Rewrite room transition handling around `boop.state.targeting` and `boop.state.combat`; keep pull timeout/return cleanup on one owned state path. |
| G-01-8C | GMCP support retry | Missing-IRE recovery calls `boop.requestCoreSupports()` with `minInterval = 2`, so a recent announce can suppress recovery even when GMCP support is incomplete. | Force or bypass throttling for missing `gmcp.IRE`, `gmcp.IRE.Target`, or `gmcp.IRE.Display` recovery paths. |
| G-01-8D | 24 gag summary cases | The failures span pending attack, proc, crit, balance, prompt, companion, standalone battlerage, and kill/XP ordering. This is a summary state-machine failure surface, not one stale assertion. | Replay `tests/boop_gag_spec.lua` in smaller groups and repair `boop_gag.lua` pending summary behavior without hiding unknown/safety-relevant lines. |
| G-01-8E | IH valid row and whitelist XP plain output | IH plain fallback only exposes list actions when the name is already recognized as a denizen; stats output needs targeted replay to confirm mob XP samples reach `displayWhitelist`. | Treat valid IH object rows according to the intended operator action policy and ensure `formatMobXp` appears in plain whitelist output. |
| G-01-8F | menu counts, UI registry reload, config callbacks | Some count failures are stale expectations after added controls, but registry/callback failures indicate reset/reload drift. `helper.reset()` clears `boop.ui` tables after registry attachment, and config dispatch needs robust reattachment/fallback. | Reattach shared registries after reset/reload and update menu wiring counts only where current UI intentionally changed. |

## Recommended Gap Plans

- `01-04-PLAN.md`: attack context and rage fallback.
- `01-05-PLAN.md`: owned room transition, GMCP retry, and pull lifecycle.
- `01-06-PLAN.md`: IH/stats plain output plus UI registry/menu wiring.
- `01-07-PLAN.md`: gag summary state machine.

## Commands Used For Diagnosis

- `rg -n "Failure ->|successes /" /tmp/boop-mudlet-0.1.338.raw.log`
- `sed -n '2876,3395p' /tmp/boop-mudlet-0.1.338.raw.log`
- Source inspection across `src/scripts/boop/boop_runtime.lua`, `boop_attacks.lua`, `boop_events.lua`, `boop_ui.lua`, `boop_ui_registry.lua`, `boop_ih.lua`, `boop_targets.lua`, and `boop_gag.lua`
- Test inspection across `tests/boop_attacks_spec.lua`, `boop_event_transitions_spec.lua`, `boop_pull_spec.lua`, `boop_ih_spec.lua`, `boop_stats_spec.lua`, `boop_menu_wiring_spec.lua`, `boop_ui_registry_spec.lua`, `boop_ui_spec.lua`, and `boop_gag_spec.lua`
