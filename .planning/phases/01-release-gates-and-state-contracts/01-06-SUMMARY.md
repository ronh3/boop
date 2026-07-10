---
phase: 01-release-gates-and-state-contracts
plan: "06"
subsystem: output-ui
tags: [ih, stats, ui-registry, menu-wiring, mudlet]

requires:
  - phase: 01-release-gates-and-state-contracts
    provides: 01-UAT.md#G-01-8E
  - phase: 01-release-gates-and-state-contracts
    provides: 01-UAT.md#G-01-8F
provides:
  - Valid IH object rows expose whitelist and blacklist actions
  - Plain whitelist output assertion covers mob XP summaries after share hints
  - Shared UI/config registries reattach after reset or reload
  - Section-local numeric config dispatch
  - Current menu wiring expectations for home, party, combat, and debug screens
affects: [phase-01, ih, stats, ui, tests]

tech-stack:
  added: []
  patterns:
    - UI/config registry access calls a shared reattach hook before using public tables.
    - Section-local numeric config commands are applied before numeric tokens are considered navigation.
    - Menu wiring specs assert meaningful handlers and command seeds instead of stale counts.

key-files:
  created:
    - .planning/phases/01-release-gates-and-state-contracts/01-06-SUMMARY.md
  modified:
    - src/scripts/boop/boop_ih.lua
    - src/scripts/boop/boop_ui.lua
    - src/scripts/boop/boop_ui_registry.lua
    - tests/support/boop_test_helper.lua
    - tests/boop_stats_spec.lua
    - tests/boop_menu_wiring_spec.lua
    - README.md
    - mfile
    - src/scripts/boop/boop_init.lua
    - CODEX.md

key-decisions:
  - "Treat valid IH object rows as actionable for whitelist/blacklist capture, even before GMCP has identified the row as a denizen."
  - "Keep global blacklist suppression for IH action labels."
  - "Keep the existing plain whitelist share hint and update the mob XP spec to search the full output."
  - "Use CI or a future Lua 5.1-compatible local runner as the authoritative full Mudlet/Busted gate."

patterns-established:
  - "Registry fallback metatables are idempotent and update fallback values without wrapping themselves repeatedly."
  - "helper.reset() repairs public UI/config registries after clearing test state."

requirements-completed: [REL-04]

coverage:
  - id: D1
    description: "Valid IH object rows preserve operator list actions in plain fallback output."
    requirement: REL-04
    verification:
      - kind: static
        ref: "luac syntax check for boop_ih.lua and boop_ih_spec.lua"
        status: pass
      - kind: inspection
        ref: "boop.ih.handleLine treats validated object ids as actionable while printLine still suppresses global blacklist labels"
        status: pass
    human_judgment: false
  - id: D2
    description: "Plain whitelist output continues to surface mob XP summaries."
    requirement: REL-04
    verification:
      - kind: inspection
        ref: "displayWhitelist still appends boop.stats.formatMobXp; spec now searches all plain lines after the share hint"
        status: pass
    human_judgment: false
  - id: D3
    description: "UI registries survive helper reset and stale reload tables."
    requirement: REL-04
    verification:
      - kind: static
        ref: "luac syntax check for boop_ui.lua, boop_ui_registry.lua, helper, and UI specs"
        status: pass
      - kind: inspection
        ref: "config accessors and config dispatch call attachUiConfigRegistries before resolving sections/actions"
        status: pass
    human_judgment: false
  - id: D4
    description: "Release gates and package build remain green after output/UI gap closure."
    requirement: REL-04
    verification:
      - kind: other
        ref: "python3 tools/check_release_gates.py"
        status: pass
      - kind: other
        ref: "muddle with PTY"
        status: pass
    human_judgment: false
  - id: D5
    description: "Full Mudlet/Busted confirmation remains pending on CI or a corrected Lua 5.1 local runner."
    requirement: REL-04
    verification:
      - kind: other
        ref: "local AppImage/Busted remains blocked by LuaRocks runtime mismatch; demonnic/test-in-mudlet uses Lua 5.1.5 before installing Busted"
        status: blocked
    human_judgment: true

duration: 31 min
completed: 2026-07-10
status: complete
---

# Phase 01 Plan 06: Output And UI Registry Gap Summary

**IH action output and UI registry/config dispatch gaps are implemented, with local gates and package build passing.**

## Accomplishments

- Made valid IH object rows actionable in plain output, preserving whitelist/blacklist labels even before GMCP denizen recognition.
- Kept global blacklist suppression for IH action labels.
- Kept plain whitelist output behavior intact and updated the mob XP spec to verify the entry across all emitted lines.
- Made UI/config registry access reattach shared registries before config, mode, preset, help, screen, and action lookups.
- Made registry fallback metatables idempotent so repeated repair does not stack wrapper functions.
- Repaired helper reset ordering so test resets leave UI/config registries available.
- Fixed config dispatch so bare numeric commands inside a section apply the current section option before being interpreted as section navigation.
- Reconciled menu wiring specs with current home, party, combat, and debug controls.
- Updated README IH behavior notes.
- Synchronized package version fields to `0.1.342`.

## Checks Run

- Lua syntax check for IH, targets, UI, registry, helper, and focused specs - pass
- Version release gate - pass
- Full release gate script - pass
- Muddler package build - pass when run with a PTY
- Full local Mudlet/Busted - still pending on CI or a Lua 5.1-compatible local Busted tree

## Issues Encountered

- `muddle` failed without a PTY because the local wrapper tried to attach stdin to a TTY-enabled Docker container. Rerunning with a PTY passed.
- The Demonnic test-in-Mudlet action confirms the right full-suite path: install Lua 5.1.5, install Busted there, then run specs inside Mudlet under Xvfb. The local Homebrew LuaRocks tree is still not a reliable authority for this run.

## Next

Continue with Plan 01-07 for the remaining gag summary state-machine failures.

## Quality Check

Plan 01-06 implementation and artifact checks passed locally, with full Mudlet/Busted deferred to CI or a corrected local Lua 5.1 runner.
