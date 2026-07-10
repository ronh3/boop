---
phase: 01-release-gates-and-state-contracts
plan: "05"
subsystem: events
tags: [runtime-state, gmcp, pull, room-transitions]

requires:
  - phase: 01-release-gates-and-state-contracts
    provides: 01-UAT.md#G-01-8B
  - phase: 01-release-gates-and-state-contracts
    provides: 01-UAT.md#G-01-8C
provides:
  - Owned-domain room transition handling
  - Pull lifecycle handling through combat.pullState
  - Forced missing-IRE GMCP support recovery
affects: [phase-01, events, pull, runtime-state, tests]

tech-stack:
  added: []
  patterns:
    - Event handlers call ensureState before touching owned runtime domains.
    - Static state-drift baseline keeps repaired files under a zero-flat-access guard.

key-files:
  created: []
  modified:
    - src/scripts/boop/boop_events.lua
    - tools/check_release_gates.py
    - mfile
    - src/scripts/boop/boop_init.lua
    - CODEX.md

key-decisions:
  - "Use boop.state.targeting for room, lastRoom, lastRoomDir, and movedRooms in onRoomInfo()."
  - "Use boop.state.combat for fleeing and pullState in onRoomInfo()."
  - "Force Core.Supports.Add recovery when Char.Status arrives without IRE GMCP active."
  - "Keep boop_events.lua in the state-drift baseline with zero allowed flat-state access."

patterns-established:
  - "When a baseline cleanup removes all flat access from a watched file, leave the file in KNOWN_FLAT_STATE_ACCESS as an empty map."

requirements-completed: [REL-04]

coverage:
  - id: D1
    description: "Room transitions read/write targeting-owned room state and clear room-sensitive state."
    requirement: REL-04
    verification:
      - kind: static
        ref: "luac syntax check for boop_events.lua and related pull specs"
        status: pass
      - kind: other
        ref: "python3 tools/check_release_gates.py --check state-drift"
        status: pass
    human_judgment: false
  - id: D2
    description: "Pull lifecycle now shares combat.pullState between pull command and room transitions."
    requirement: REL-04
    verification:
      - kind: inspection
        ref: "onRoomInfo uses combat.pullState and targeting.room"
        status: pass
    human_judgment: false
  - id: D3
    description: "Missing-IRE Char.Status recovery is not throttled by a recent routine support announce."
    requirement: REL-04
    verification:
      - kind: inspection
        ref: "onCharStatus calls requestCoreSupports with force=true and minInterval=0 when IRE support is missing"
        status: pass
    human_judgment: false
  - id: D4
    description: "Release gates and package build remain green after state-drift baseline cleanup."
    requirement: REL-04
    verification:
      - kind: other
        ref: "python3 tools/check_release_gates.py"
        status: pass
      - kind: other
        ref: "muddle"
        status: pass
    human_judgment: false
  - id: D5
    description: "Full Mudlet/Busted local replay remains pending on a Lua 5.1-compatible local Busted tree or CI evidence."
    requirement: REL-04
    verification:
      - kind: other
        ref: "local AppImage profile reaches Busted initialization but the Homebrew Lua 5.5 rock tree is incompatible"
        status: blocked
    human_judgment: true

duration: 18 min
completed: 2026-07-10
status: complete
---

# Phase 01 Plan 05: Event And Pull State Gap Summary

**Room transitions, pull lifecycle handling, and missing-IRE support recovery now use canonical owned state.**

## Accomplishments

- Reworked `boop.onRoomInfo()` to use `boop.state.targeting.room`, `lastRoom`, `lastRoomDir`, and `movedRooms`.
- Moved room-transition flee handling to `boop.state.combat.fleeing`.
- Moved pull transition handling to `boop.state.combat.pullState`, matching `boop.ui.pullCommand()`.
- Forced GMCP support recovery from `boop.onCharStatus()` when `gmcp.IRE`, `gmcp.IRE.Target`, or `gmcp.IRE.Display` is missing.
- Updated the state-drift baseline so `boop_events.lua` now permits zero flat-state accesses while still being scanned.
- Synchronized package version fields to `0.1.341`.

## Checks Run

- Lua syntax check for event, UI, init, event-transition spec, and pull spec files - pass
- Python compile check for the release gate script - pass
- Release gate script, including state-drift - pass
- Muddler package build - pass
- Full local Mudlet/Busted - still pending on a Lua 5.1-compatible local Busted tree or CI run

## Issues Encountered

- The state-drift gate correctly failed after the flat-state cleanup until the reviewed baseline was updated. The final baseline keeps `boop_events.lua` watched with no allowed flat accesses.
- Local full Mudlet/Busted remains a tooling issue, not a package build issue. The supported `demonnic/test-in-mudlet` action uses a Lua 5.1.5 Busted tree; the local Homebrew LuaRocks tree used during this run was Lua 5.5.

## Next

Continue with Plan 01-06 for IH plain output, whitelist stats output, and UI registry/menu wiring gaps.

## Quality Check

Plan 01-05 implementation and artifact checks passed, with full Mudlet/Busted deferred to CI or a corrected local Lua 5.1 runner.
