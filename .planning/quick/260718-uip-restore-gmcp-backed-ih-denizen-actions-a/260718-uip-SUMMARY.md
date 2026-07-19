---
quick_id: 260718-uip
status: complete
completed: 2026-07-19
implementation_commit: a984495
---

# Quick Task 260718-uip Summary

Restored GMCP-backed classification for `ih` whitelist/blacklist actions.

## Changes

- Added an ID-first denizen lookup with normalized-name fallback against boop's filtered room denizen state.
- Kept every valid `ih` object row visible while limiting list controls to targetable GMCP denizens.
- Added regression cases for a normal `m` denizen, an ordinary item, and the observed `mx` phantom donkey mount.
- Corrected the README behavior note and synchronized package metadata.

## Verification

- Focused IH Busted suite: 8 successes, 0 failures.
- Full host Busted suite: 538 successes, 0 failures.
- Release gates: versions, manifests, and state-drift passed.
- Muddler 1.1.0 package build completed successfully.

## Result

Ordinary items and `mx` mounts render in `ih` without whitelist/blacklist controls. Valid `m` denizens retain those controls.
