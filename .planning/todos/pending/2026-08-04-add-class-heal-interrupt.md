---
created: 2026-08-04T20:32:08.249Z
title: Add class heal interrupt
area: general
files:
  - src/scripts/boop/boop_ui.lua:1595
  - src/scripts/boop/boop_runtime.lua:2977
  - src/scripts/boop/boop_events.lua:2820
  - src/scripts/boop/boop_state.lua:1
  - src/aliases/boop/Combat/aliases.json:61
  - src/scripts/boop/boop_ui_registry.lua:861
  - tests/boop_interrupt_spec.lua:1
---

## Problem

The operator wants a short `ch` interrupt that pauses boop attacks, replaces conflicting native attack work through the existing serialized interrupt lifecycle, and invokes the current class's active heal. Boop does not currently expose this command or maintain reusable authoritative self-posture state for Depthswalker's prone-sensitive command choice.

Initial class commands:

- Magi: `cast bloodboil`
- Dragon and all color-dragon forms: `dragonheal`
- Infernal: `fitness`
- Blademaster: `alleviate`
- Depthswalker: `chrono accelerate` while prone; `chrono accelerate boost` only while standing is known

The exact success, denial, cooldown, unavailable-skill, and no-effect lines still need live capture. Current standard-denial parsing recognizes `You must be standing first.` and recovery parsing recognizes `You stand up.`, but it does not persist posture for later command selection.

## Solution

Implement after Phase 3's standard/interrupt lifecycle gaps are repaired, then complete it when the operator supplies exact server lines.

- Add a class-heal registry and a `ch` alias that resolves the current normalized class/form, rejects unsupported classes visibly, and starts one exact interrupt owner/generation. Clear or replace the native attack queue once, hold automatic combat/queue work, send exactly one class-heal command, and resume only from guarded result-plus-prompt evidence or bounded timeout.
- Add a small self-posture domain with known-standing, known-prone, and unknown states. Feed it from trustworthy GMCP evidence when available and exact posture denial/recovery lines; reset it on reconnect. For Depthswalker, choose boosted accelerate only when standing is known and use plain accelerate when prone or unknown.
- Do not infer success from the first unrelated prompt while a queued heal may still be waiting. Add exact result adapters as live lines are captured, preserve stale-generation no-ops, and trace selected class, command, posture source, owner/generation, terminal reason, and timeout.
- Update alias manifests, help, status/diagnostics, README, and interrupt tests. Cover every initial class, Dragon aliases/forms, unsupported class, prone/standing/unknown Depthswalker selection, concurrent interrupt rejection, native queue replacement, success, denial, timeout, reconnect, and stale callbacks.

