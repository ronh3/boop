---
phase: 01
slug: release-gates-and-state-contracts
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-07-09
---

# Phase 01 - Validation Strategy

Per-phase validation contract for feedback sampling during execution.

## Test Infrastructure

| Property | Value |
|----------|-------|
| Framework | Busted 2.3.0 locally; CI installs Busted and runs inside Mudlet |
| Config file | none detected; CI controls the Mudlet runner through environment variables |
| Quick run command | `python3 tools/check_release_gates.py` after Wave 0 creates it |
| Full suite command | Build the package, then run the existing Mudlet AppImage Busted command with `AUTORUN_BUSTED_TESTS=true TESTS_DIRECTORY=$PWD/tests QUIT_MUDLET_AFTER_TESTS=true PRETEST_PACKAGE=$PWD/build/boop Hunter.mpackage` |
| Estimated runtime | static gate: under 10 seconds; full Mudlet suite: CI/runtime dependent |

## Sampling Rate

- After every task commit: run `python3 tools/check_release_gates.py` once the checker exists.
- After every plan wave: run the static release gates plus the existing package build and Mudlet/Busted suite when the local runner is available.
- Before `$gsd-verify-work`: static release gates, package build, and current Busted suite must be green, or missing local Mudlet runner evidence must be documented.
- Max feedback latency: static checks should remain under 10 seconds locally.

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 01-01-01 | 01 | 1 | REL-01 | T-01-version | version metadata mismatch exits non-zero before build | static gate | `python3 tools/check_release_gates.py --check versions` | no, Wave 0 creates it | pending |
| 01-01-02 | 01 | 1 | REL-02 | T-01-manifest | invalid JSON or manifest/file parity drift exits non-zero before build | static gate | `python3 tools/check_release_gates.py --check manifests` | no, Wave 0 creates it | pending |
| 01-02-01 | 02 | 2 | REL-04 | T-01-state-drift | new high-risk flat-state drift exits non-zero while known drift is reviewed explicitly | static gate plus Busted | `python3 tools/check_release_gates.py --check state-drift` and selected Busted spec | partial; existing runtime specs cover domain initialization | pending |

## Wave 0 Requirements

- [ ] `tools/check_release_gates.py` - implements REL-01, REL-02, and static state-drift allowlist checks.
- [ ] `.github/workflows/main.yml` - calls the local static gate immediately after checkout and before Muddler.
- [ ] `src/aliases/boop/Targeting/Boop_IH.lua` - either register, delete, or intentionally exclude before manifest parity blocks CI.
- [ ] `src/triggers/boop/Shield/Weaponmastery_Two_Handed/triggers.json` or the corresponding Lua filenames - align the two Two-Handed manifest entries with actual files.
- [ ] `tests/boop_state_contract_spec.lua` or extensions to `tests/boop_runtime_spec.lua` - adds green REL-04 owned-domain and known-drift contract coverage.

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Full in-Mudlet Busted execution | REL-04 | Requires Mudlet AppImage/profile availability; local `/tmp/Mudlet.AppImage` may be absent | Use the existing CI command or GitHub Actions run and record the package import plus Busted result before phase verification |

## Validation Sign-Off

- [ ] All tasks have automated verify commands or Wave 0 dependencies.
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify.
- [ ] Wave 0 covers all missing static gate/test references.
- [ ] No watch-mode flags in verification commands.
- [ ] Static feedback latency remains under 10 seconds.
- [ ] `nyquist_compliant: true` set in frontmatter after Wave 0 and task verification coverage are real.

**Approval:** pending
