---
created: 2026-07-24T16:50:35.770Z
title: Verify Infernal hyena maul summary
area: general
files:
  - src/triggers/boop/Gag/Unnamable/triggers.json:87
  - src/triggers/boop/Gag/Unnamable/Unnamable_Hyena_Maul.lua:1
  - src/scripts/boop/boop_gag.lua:1444
  - src/scripts/boop/boop_gag.lua:1634
  - src/scripts/boop/boop_gag.lua:1760
  - tests/boop_gag_spec.lua:321
  - output.md:49
---

## Problem

With own-attack gagging enabled, boop intentionally removes the raw Infernal
hyena command and companion flavor lines and should emit a compact
`You: Hyena Maul -> target` summary after damage or prompt processing. The
operator reports not seeing either the raw attack or its compact replacement.

The available trace only proves that boop queued `hyena maul` and then received
the cooldown rejection (`hyena maul not ready`). It contains no successful
`hyena maul used` or `gag: self | ability=Hyena Maul` event, so changing the
trigger from this evidence would be speculative.

## Solution

Address during Phase 5 compact-summary fixture expansion.

- Disable own-attack gagging temporarily and capture the complete successful
  Infernal hyena command, companion flavor, critical, damage, standard attack,
  balance, and prompt sequence.
- Compare the live wording with the current command and flavor trigger patterns.
- Add the captured sequence as a regression fixture before making any narrow
  trigger or summary-lifecycle correction.
- Verify that gagging removes only the raw noise, emits a visible Hyena Maul
  compact summary with target/damage/critical signal, and records a trace event.
- Keep cooldown rejection and readiness lines visible or traceable so a failed
  maul cannot be mistaken for a successfully gagged attack.
