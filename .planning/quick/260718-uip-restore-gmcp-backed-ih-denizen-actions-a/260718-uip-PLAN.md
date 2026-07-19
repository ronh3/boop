---
quick_id: 260718-uip
status: planned
description: Restore GMCP-backed IH denizen actions and hide whitelist/blacklist controls for non-denizen items
---

# Quick Task 260718-uip Plan

Restore `ih` list actions only for room entries present in boop's GMCP-filtered denizen set.

1. Add an ID-first denizen row lookup with normalized-name fallback and use it from `boop.ih.handleLine()`.
2. Add focused coverage for a valid `m` denizen, an ordinary item, and the observed `mx` mount payload.
3. Correct the README behavior note, synchronize version `0.1.380`, and run focused/full release gates.
