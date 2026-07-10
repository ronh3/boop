---
status: complete
phase: 01-release-gates-and-state-contracts
source:
  - 01-01-SUMMARY.md
  - 01-02-SUMMARY.md
  - 01-03-SUMMARY.md
  - 01-04-SUMMARY.md
  - 01-05-SUMMARY.md
  - 01-06-SUMMARY.md
  - 01-07-SUMMARY.md
started: 2026-07-09T21:12:56Z
updated: 2026-07-10T21:27:50Z
counts:
  total: 8
  passed: 8
  issues: 0
  pending: 0
  skipped: 0
  blocked: 0
---

# Phase 01 UAT: Release Gates and State Contracts

## Current Test

[testing complete]

## Tests

### 1. Local Release Gate CLI
expected: |
  Maintainers can run one local command that validates synchronized versions, JSON/manifests, and reviewed state drift before package build or push.
result: pass
evidence:
  - `python3 tools/check_release_gates.py`
  - `python3 tools/check_release_gates.py --check versions`

### 2. Clean Manifest Parity Baseline
expected: |
  Source JSON and Muddler manifest/file parity are clean, including removal of the duplicate IH alias source and repaired Two Handed trigger names.
result: pass
evidence:
  - `python3 tools/check_release_gates.py --check manifests`
  - `test ! -e src/aliases/boop/Targeting/Boop_IH.lua && test -f src/aliases/boop/Targeting/IH.lua`

### 3. Reviewed State-Drift Baseline
expected: |
  Known flat-state access is explicitly baselined and the gate fails when new high-risk flat-state access is introduced.
result: pass
evidence:
  - `python3 tools/check_release_gates.py --check state-drift`
  - Temporary drift probe failure was confirmed during Plan 01 and then restored to green.

### 4. CI Release Gate Ordering
expected: |
  GitHub Actions runs the local release gate immediately after checkout and before package metadata, Muddler, Mudlet setup, and Busted work.
result: pass
evidence:
  - Current successful GitHub Actions run `29074509231`
  - Job `86303032834` step 3 `Release gates` completed successfully before Muddler and Mudlet Busted steps.

### 5. Maintainer Gate Documentation
expected: |
  CODEX documents focused local release-gate commands and the full Mudlet Busted path so maintainers can reproduce failures.
result: pass
evidence:
  - `rg CODEX.md` for `--check versions`, `--check manifests`, `--check state-drift`, and `/tmp/Mudlet.AppImage`

### 6. Owned Runtime State Contract Coverage
expected: |
  Owned runtime domains and defaults are covered by a focused Busted spec, and runtime context mapping reads seeded owned-domain values.
result: pass
evidence:
  - `tests/boop_state_contract_spec.lua`
  - `luac -p tests/boop_state_contract_spec.lua`
  - `python3 tools/check_release_gates.py --check state-drift`

### 7. Gap Closure Regression Coverage
expected: |
  The previously diagnosed full-suite failure clusters for attack context, pull/event state, GMCP support retry, IH/stats output, UI registries, menu wiring, and gag summaries are closed by executed gap plans.
result: pass
evidence:
  - `01-04-SUMMARY.md` closes `G-01-8A`
  - `01-05-SUMMARY.md` closes `G-01-8B` and `G-01-8C`
  - `01-06-SUMMARY.md` closes `G-01-8E` and `G-01-8F`
  - `01-07-SUMMARY.md` closes `G-01-8D`

### 8. Authoritative Full Mudlet/Busted Confirmation
expected: |
  Full Mudlet/Busted execution passes inside the supported CI Mudlet profile before Phase 01 sign-off.
result: pass
evidence:
  - GitHub Actions run `29074509231` completed successfully at commit `c0b257dba361d13e63ff10328cc891745949bf1f`.
  - Job `86303032834` completed `Run Busted tests in Mudlet` and `Check Busted result` successfully.
  - CI artifact `boop Hunter-0.1.349` uploaded successfully after the full in-Mudlet test gate.

## Summary

total: 8
passed: 8
issues: 0
pending: 0
skipped: 0
blocked: 0

## Gaps

- gap_id: G-01-8A
  truth: "Attack selection must use current-target HP and readiness data without trusting stale GMCP target info."
  status: resolved
  resolved_by: 01-04-PLAN.md
  resolved_at: 2026-07-10
  evidence: "01-04-SUMMARY.md and successful CI run 29074509231"

- gap_id: G-01-8B
  truth: "Room transitions and pull lifecycle must read and write owned state domains."
  status: resolved
  resolved_by: 01-05-PLAN.md
  resolved_at: 2026-07-10
  evidence: "01-05-SUMMARY.md and successful CI run 29074509231"

- gap_id: G-01-8C
  truth: "GMCP support negotiation must retry when Char.Status arrives before IRE GMCP is active."
  status: resolved
  resolved_by: 01-05-PLAN.md
  resolved_at: 2026-07-10
  evidence: "01-05-SUMMARY.md and successful CI run 29074509231"

- gap_id: G-01-8D
  truth: "Gag summaries must reduce scroll while preserving attack, proc, crit, balance, prompt, kill, and XP signal."
  status: resolved
  resolved_by: 01-07-PLAN.md
  resolved_at: 2026-07-10
  evidence: "01-07-SUMMARY.md and successful CI run 29074509231"

- gap_id: G-01-8E
  truth: "Plain output for IH and whitelist stats must preserve operator actions and mob XP signal."
  status: resolved
  resolved_by: 01-06-PLAN.md
  resolved_at: 2026-07-10
  evidence: "01-06-SUMMARY.md and successful CI run 29074509231"

- gap_id: G-01-8F
  truth: "UI registries, menu wiring, and config callbacks must remain coherent after package reload and helper reset."
  status: resolved
  resolved_by: 01-06-PLAN.md
  resolved_at: 2026-07-10
  evidence: "01-06-SUMMARY.md and successful CI run 29074509231"
