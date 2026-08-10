---
status: complete
quick_id: 260810-ikl
package_commit: 906212f
---

# Quick Task 260810-ikl Summary

Changed `ragePoolThreshold` from a reach-before-spend gate to a post-spend reserve. Ordinary battlerage actions now receive the same cost-aware finalization treatment as `pullRageReserve`: an action is held with `pool_hold` when paying its rage cost would leave less than the configured pool.

Preserved the existing exceptions for rage shieldbreaks and Triumph free rage. Updated the command help, README, design contract, and synchronized package version to `0.1.481`.

## Verification

- Focused reserve-boundary regression: 1 success, 0 failures.
- Lua syntax check: passed.
- Muddler package build: passed.
- `python3 tools/check_release_gates.py`: versions, manifests, and state-drift passed.
- Full Mudlet Busted suite delegated to the required exact-HEAD GitHub Actions gate after the final push.
