---
status: testing
phase: 03-queue-interrupt-gold-and-autowalk-regression-coverage
source:
  - 03-VERIFICATION.md
started: 2026-07-26T21:45:34Z
updated: 2026-07-26T21:45:34Z
---

# Phase 03 UAT: Queue, Interrupt, Gold, and Autowalk Regression Coverage

## Current Test

number: 1
name: Cross-owner attack, loot, and walk release
expected: |
  No automatic standard or rage attack, get or put command, or walker movement occurs while any relevant owner remains. Once the exact owner and all other relevant owners clear, exactly one next action resumes.
awaiting: user response

## Tests

### 1. Cross-owner attack, loot, and walk release

expected: |
  In a safe Achaea test area with autogold and demonnicAutoWalker enabled, exercising `diag`, one queued interrupt, and `pull` while a real target or gold lifecycle is active sends no automatic attack, loot command, or walker move until every relevant owner releases. Exactly one next action resumes after aggregate all-clear.
result: pending

### 2. Wrong-room gold and pack transfer

expected: |
  Gold evidence created in room A cannot cause a room-A get or retry after moving to room B. A confirmed inventory-owned put may finish after movement, and no loot command is chained with an attack.
result: pending

### 3. Optional walker and stop ownership

expected: |
  Without demonnicAutoWalker, walk status, start, and move never install or update the package, while explicit install provides visible feedback. With the package present, stopping a boop-owned run emits one external stop, while detaching from an already-running external walk does not stop that run.
result: pending

## Summary

total: 3
passed: 0
issues: 0
pending: 3
skipped: 0
blocked: 0

## Gaps
