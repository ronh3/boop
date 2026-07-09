---
phase: 01-release-gates-and-state-contracts
status: partial
started: 2026-07-09T21:12:56Z
updated: 2026-07-09T21:12:56Z
source:
  - 01-01-SUMMARY.md
  - 01-02-SUMMARY.md
  - 01-03-SUMMARY.md
counts:
  total: 8
  passed: 7
  issues: 0
  pending: 0
  skipped: 0
  blocked: 1
---

# Phase 01 UAT: Release Gates and State Contracts

## Current Status

Phase 01 implementation coverage is green for all local static checks and summary-derived acceptance criteria. Final sign-off is blocked on full Mudlet/Busted execution evidence because this environment does not have `/tmp/Mudlet.AppImage`, and no GitHub Actions run was found for `codex/pre-1.0-hardening-pass`.

## Tests

1. **Local release gate CLI validates synchronized versions, JSON/manifests, and reviewed state drift.**
   - Requirement: REL-01
   - Source: `01-01-SUMMARY.md` coverage D1
   - Result: pass
   - Evidence: `python3 tools/check_release_gates.py`; `python3 tools/check_release_gates.py --check versions`

2. **Manifest parity baseline is clean after removing duplicate IH alias source and fixing Two Handed trigger names.**
   - Requirement: REL-02
   - Source: `01-01-SUMMARY.md` coverage D2
   - Result: pass
   - Evidence: `python3 tools/check_release_gates.py --check manifests`; `test ! -e src/aliases/boop/Targeting/Boop_IH.lua && test -f src/aliases/boop/Targeting/IH.lua`

3. **Known flat-state access is explicitly baselined and fails when new access is introduced.**
   - Requirement: REL-04
   - Source: `01-01-SUMMARY.md` coverage D3
   - Result: pass
   - Evidence: `python3 tools/check_release_gates.py --check state-drift`; temporary probe failure was confirmed during implementation and restored to green

4. **GitHub Actions blocks on the local release gate before package metadata and Muddler build steps.**
   - Requirement: REL-01
   - Source: `01-02-SUMMARY.md` coverage D1
   - Result: pass
   - Evidence: `python3 tools/check_release_gates.py`; workflow order assertion for `Release gates` before `Read package metadata` and `Muddle`

5. **CODEX documents local focused release-gate commands and the full Mudlet Busted path.**
   - Requirement: REL-02
   - Source: `01-02-SUMMARY.md` coverage D2
   - Result: pass
   - Evidence: `rg CODEX.md` for `--check versions`, `--check manifests`, `--check state-drift`, and `/tmp/Mudlet.AppImage`

6. **Owned runtime domains and defaults are covered by a focused Busted spec.**
   - Requirement: REL-04
   - Source: `01-03-SUMMARY.md` coverage D1
   - Result: pass
   - Evidence: `test -f tests/boop_state_contract_spec.lua`; `luac -p tests/boop_state_contract_spec.lua`; `python3 tools/check_release_gates.py --check state-drift`

7. **Runtime context mapping reads seeded owned-domain values for target, queue, gold, diag, inventory, and rage.**
   - Requirement: REL-04
   - Source: `01-03-SUMMARY.md` coverage D2
   - Result: pass
   - Evidence: `rg tests/boop_state_contract_spec.lua` for `boop.runtime.context()` and seeded owned-domain assertions

8. **Full Mudlet/Busted execution must be verified in CI because the local AppImage is unavailable.**
   - Requirement: REL-04
   - Source: `01-03-SUMMARY.md` coverage D3
   - Result: blocked
   - Blocked by: release-build
   - Evidence needed: GitHub Actions full Mudlet/Busted run, or an equivalent local run with `/tmp/Mudlet.AppImage`
   - Current evidence: `/tmp/Mudlet.AppImage` is missing locally, and `gh run list --branch codex/pre-1.0-hardening-pass --limit 10` returned no matching workflow run

## Gaps

No acceptance issue has been found. Verification is waiting for full Mudlet/Busted runtime evidence before Phase 01 can be signed off.
