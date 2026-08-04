---
created: 2026-07-19T05:06:47.586Z
updated: 2026-08-04T20:32:08.249Z
title: Add temporary prefixes and custom attacks
area: general
files:
  - src/scripts/boop/boop_attacks.lua:173
  - src/scripts/boop/boop_attacks.lua:228
  - src/scripts/boop/boop_attacks.lua:1373
  - src/scripts/boop/boop_ui.lua:2908
  - src/aliases/boop/Core/aliases.json:117
  - src/aliases/boop/Core/Boop_Prefer.lua:1
  - src/scripts/boop/boop_ui_registry.lua:806
---

## Problem

boop has no operator-defined equivalent of its hard-coded assist and class-specific attack prefixes. An operator cannot temporarily prepend a command to generated hunting attacks and then clear it without changing profile source.

`boop prefer temp` also only selects damage or shield commands already registered in the active class/spec profile. The intended feature is an arbitrary temporary command, not merely a temporary selection from the registry, so a situational attack missing from boop's profile still cannot be used through the preference workflow.

Both capabilities would place user-controlled command fragments into direct and queued game-command paths. They therefore need explicit scope, lifecycle, separator handling, target substitution, and validation rather than raw string concatenation.

## Solution

Implement after Phase 4 command trust boundaries are established.

- Add a visible, session-local temporary prefix control with status and clear operations. During planning, decide whether the prefix applies to standard attacks only or standard plus rage, and whether it lasts until cleared or supports a one-shot mode.
- Define deterministic ordering with gold pickup, assist, class modifiers, target substitution, direct sends, and the `BOOP_ATTACK` queue alias.
- Add an explicit session-only custom form, provisionally `boop prefer temp <dam|shield> custom <command>`, rather than overloading registered-option resolution. Require deliberate `&tar` substitution when the command needs a target, preserve the saved/profile fallback, display custom state in `boop prefer` and status, support `boop prefer temp clear [dam|shield]`, and reset custom values on reconnect/package reload.
- Apply the same normal attack modifier, assist transformation, fixed-alias, and direct/queued lifecycle boundaries as registered standards. A custom shield command is selected only in the normal shield branch; a custom damage command does not silently become a shield bypass.
- Reject newlines, native queue commands, and unsafe separator payloads until Phase 4 defines the accepted command-fragment grammar. Add parser, direct/queued, assist, shield, clear, reconnect/reload, help, README, and status coverage before shipping.
