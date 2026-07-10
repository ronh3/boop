---
phase: 01-release-gates-and-state-contracts
plan: "04"
subsystem: attacks
tags: [runtime-context, target-hp, rage, mudlet]

requires:
  - phase: 01-release-gates-and-state-contracts
    provides: 01-UAT.md#G-01-8A
provides:
  - Current-target HP validation in runtime attack context
  - Explicit known-skill fixture for the Harry fallback
affects: [phase-01, attacks, runtime-state, tests]

tech-stack:
  added: []
  patterns:
    - Runtime context carries source-specific ids for game data that can lag the active target.

key-files:
  created: []
  modified:
    - src/scripts/boop/boop_runtime.lua
    - src/scripts/boop/boop_attacks.lua
    - tests/boop_attacks_spec.lua
    - mfile
    - src/scripts/boop/boop_init.lua
    - CODEX.md

key-decisions:
  - "Keep target.id as the active target and add target.infoId for the GMCP Target.Info source row."
  - "Blank context target.hpperc when GMCP Target.Info does not belong to the active target."
  - "Keep rage selection strict about known skills; the Harry fallback fixture now seeds Harry explicitly."

patterns-established:
  - "Planning-context HP is known only when the data source id matches the current target id."

requirements-completed: [REL-04]

coverage:
  - id: D1
    description: "Attack selection no longer treats stale GMCP Target.Info hpperc as known current-target HP."
    requirement: REL-04
    verification:
      - kind: static
        ref: "luac -p src/scripts/boop/boop_runtime.lua src/scripts/boop/boop_attacks.lua tests/boop_attacks_spec.lua"
        status: pass
      - kind: inspection
        ref: "runtime context exposes target.infoId and blanks target.hpperc when infoId differs from target.id"
        status: pass
    human_judgment: false
  - id: D2
    description: "Shieldbreak-disabled rage fallback remains strict about known abilities and now has an explicit Harry fixture."
    requirement: REL-04
    verification:
      - kind: inspection
        ref: "tests/boop_attacks_spec.lua seeds Harry in the Occultist fixture"
        status: pass
    human_judgment: false
  - id: D3
    description: "Release gates and package build remain green after the attack context fix."
    requirement: REL-04
    verification:
      - kind: other
        ref: "python3 tools/check_release_gates.py"
        status: pass
      - kind: other
        ref: "muddle"
        status: pass
    human_judgment: false
  - id: D4
    description: "Full Mudlet/Busted local replay was attempted but blocked by local profile/LuaRocks incompatibility."
    requirement: REL-04
    verification:
      - kind: other
        ref: "/tmp/boop-mudlet-0.1.340.raw.log"
        status: blocked
    human_judgment: true
    rationale: "The AppImage reaches the throwaway GSDTests profile and Busted initialization, then fails on the native LuaRocks system module because the installed rock tree targets the wrong Lua runtime for Mudlet. demonnic/test-in-mudlet installs Lua 5.1.5 before Busted; CI remains the authoritative full-suite gate until a Lua 5.1-compatible local Busted tree is installed."

duration: 31 min
completed: 2026-07-10
status: complete
---

# Phase 01 Plan 04: Attack Context Gap Summary

**Attack planning now treats target HP as current only when GMCP Target.Info belongs to the active target.**

## Accomplishments

- Added `target.infoId` to `boop.runtime.context()` so flattened attack context preserves the GMCP source target id.
- Blanked `target.hpperc` in runtime context when GMCP Target.Info is stale for the current target.
- Tightened `boop.attacks.getTargetHpPercKnown()` so planning context with missing or mismatched `infoId` does not unlock full-HP openers.
- Updated the Occultist attack spec fixture to seed Harry explicitly, preserving strict known-skill rage selection.
- Synchronized package version fields to `0.1.340`.

## Checks Run

- luac syntax check for runtime, attacks, and attack spec - pass
- release gate script - pass
- Muddler package build - pass
- Full local Mudlet/Busted - blocked by local test-harness LuaRocks/runtime mismatch; log saved as boop-mudlet-0.1.340.raw.log under tmp

## Issues Encountered

- The local AppImage/profile path currently cannot run Busted reliably. The clean throwaway `GSDTests` profile reaches Busted initialization, but the installed LuaRocks tree loads a native `system` module incompatible with Mudlet's embedded Lua runtime. The supported `demonnic/test-in-mudlet` action uses Lua 5.1.5 for its Busted tree; the local Homebrew tree used here was Lua 5.5.

## Next

Continue with Plan 01-05 for room transition, pull lifecycle, and missing-IRE GMCP retry gaps.

## Quality Check

Plan 01-04 implementation and artifact checks passed, with the full Mudlet/Busted environment limitation recorded above for CI or local Lua 5.1 follow-up.
