---
created: 2026-07-19T05:06:47.586Z
title: Add temporary prefixes and custom attacks
area: general
files:
  - src/scripts/boop/boop_util.lua:185
  - src/scripts/boop/boop_attacks.lua:173
  - src/scripts/boop/boop_attacks.lua:1118
  - src/scripts/boop/boop_ui.lua:2355
  - src/aliases/boop/Core/aliases.json:117
  - .planning/ROADMAP.md:93
---

## Problem

boop has no operator-defined equivalent of its hard-coded assist and class-specific attack prefixes. An operator cannot temporarily prepend a command to generated hunting attacks and then clear it without changing profile source.

`boop prefer` also only selects damage or shield commands already registered in the active class/spec profile. It rejects an operator-provided command, so a valid situational attack missing from boop's profile cannot be selected through the normal preference workflow.

Both capabilities would place user-controlled command fragments into direct and queued game-command paths. They therefore need explicit scope, lifecycle, separator handling, target substitution, and validation rather than raw string concatenation.

## Solution

Implement after Phase 4 command trust boundaries are established.

- Add a visible, session-local temporary prefix control with status and clear operations. During planning, decide whether the prefix applies to standard attacks only or standard plus rage, and whether it lasts until cleared or supports a one-shot mode.
- Define deterministic ordering with gold pickup, assist, class modifiers, target substitution, direct sends, and the `BOOP_ATTACK` queue alias.
- Extend attack preferences with a validated custom damage or shield command scoped to the active class/spec. Preserve a clear fallback to the profile default and display the active custom command in `boop prefer` status.
- Support boop's target placeholder deliberately, reject unsafe separators or queue fragments, and add direct/queued/reload regression coverage before exposing persistence.
