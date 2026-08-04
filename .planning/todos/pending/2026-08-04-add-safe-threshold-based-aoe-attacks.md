---
created: 2026-08-04T20:32:08.249Z
title: Add safe threshold-based AOE attacks
area: general
files:
  - src/scripts/boop/boop_targets.lua:940
  - src/scripts/boop/boop_targets.lua:1049
  - src/scripts/boop/boop_attacks.lua:1768
  - src/scripts/boop/boop_attacks.lua:1800
  - src/scripts/boop/boop_ui.lua:684
  - src/scripts/boop/boop_ui_registry.lua:806
---

## Problem

Boop always selects a single-target standard attack even when a room contains enough valid hunting targets to justify an area attack. The operator wants an opt-in mode that uses a configured AOE command at a configurable target-count threshold, then falls back to the normal preferred attack when the threshold or safety conditions are not met.

Counting valid targets alone is unsafe. Many AOE commands can affect every denizen in the room, so a blacklisted, non-whitelisted, called-target-ineligible, or otherwise protected denizen must prevent automatic AOE rather than merely being omitted from the count. Mounts and non-denizen items must continue to use the existing GMCP attribute filtering.

## Solution

Implement after Phase 3 lifecycle repair and within or after Phase 4 command validation.

- Add opt-in controls provisionally shaped as `boop aoe on|off`, `boop aoe threshold <n>`, `boop aoe attack <command>`, `boop aoe clear`, and `boop aoe status`. Persist enablement, threshold, and per-class/spec command only after the command-fragment trust contract is defined; default to OFF and a threshold of 3.
- Expose one targeting API that returns the current eligible denizens under the active manual/whitelist/blacklist/auto and leader-call policy. Select AOE only when the eligible count reaches the threshold and every denizen the command could affect is eligible; otherwise trace the reason and use the ordinary single-target standard.
- Do not use AOE while room evidence is partial, target policy is unresolved, an interrupt/standard generation is pending, or shield handling requires the configured single-target shield action. Preserve current attack ownership, target substitution, modifiers, queueing, assist transformation, and blocker checks.
- Show mode, threshold, command/fallback, eligible count, and safety reason in status/help. Add targeting-mode, blacklist, whitelist, mount/non-denizen, partial-room, shield, direct/queued, reconnect, and fallback tests plus live UAT with one protected denizen present.

