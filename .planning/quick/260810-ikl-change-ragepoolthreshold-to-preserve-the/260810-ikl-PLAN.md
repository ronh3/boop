---
quick_id: 260810-ikl
status: complete
description: Change ragePoolThreshold to preserve the configured rage after ordinary battlerage spending, matching pullRageReserve semantics
---

# Quick Task 260810-ikl Plan

## Task 1: Enforce the rage-pool reserve

- Update ordinary rage decision finalization so an ability is held when its post-spend rage would fall below `ragePoolThreshold`.
- Preserve the existing shieldbreak and Triumph free-rage exceptions.
- Add regression coverage at below-threshold, exactly-threshold, insufficient-post-spend, and sufficient-post-spend rage levels.

## Task 2: Synchronize the shipped contract

- Update command help and project documentation from reach-before-spend wording to reserve wording.
- Bump all synchronized package version checkpoints.
- Run focused tests and repository release gates, then commit and push atomically.
