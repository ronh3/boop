---
phase: 02
slug: state-ownership-repair-and-safety-baseline
status: complete
nyquist_compliant: true
wave_0_complete: true
created: 2026-07-10
updated: 2026-07-11T06:54:08Z
---

# Phase 02 - Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Busted 2.3.0, executed canonically inside Mudlet 4.20.1 |
| **Config file** | none; Mudlet bootstrap uses `tests/support/boop_test_helper.lua` |
| **Quick run command** | `python3 tools/check_release_gates.py --check state-drift` |
| **Full suite command** | `muddle && AUTORUN_BUSTED_TESTS=true TESTS_DIRECTORY="$PWD/tests" QUIT_MUDLET_AFTER_TESTS=true PRETEST_PACKAGE="$PWD/build/boop Hunter.mpackage" /tmp/Mudlet.AppImage --profile "GithubTests" --mirror` |
| **Estimated runtime** | ~10s quick gate; full Mudlet suite runtime varies by local display startup |

---

## Sampling Rate

- **After every task commit:** Run `python3 tools/check_release_gates.py --check state-drift` plus the smallest affected Mudlet Busted spec when available.
- **After every plan wave:** Run the full Mudlet suite command.
- **Before `$gsd-verify-work`:** `python3 tools/check_release_gates.py --check versions --check manifests --check state-drift` and the full Mudlet suite must be green.
- **Max feedback latency:** 1 task between automated checks; no unverified safety-state task may be followed by another safety-state task.

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 02-W0-01 | Wave 0 | 0 | STATE-01 | T-02-01 | Phase 02 tests and helpers seed/assert owned domains, not flat `boop.state.*` compatibility keys. | static/unit | `python3 tools/check_release_gates.py --check state-drift` | yes | green |
| 02-W0-02 | Wave 0 | 0 | STATE-02 | T-02-02 | Missing or partial GMCP state creates owned blockers and holds attacks, walk, queue/prequeue, and gold. | integration | full Mudlet suite with expanded `tests/boop_event_transitions_spec.lua` | yes | green |
| 02-W0-03 | Wave 0 | 0 | STATE-03 | T-02-03 | Trace, status, and dashboard read the same canonical owned blocker/status values. | integration/UI text | full Mudlet suite with expanded `tests/boop_trace_spec.lua` and `tests/boop_ui_spec.lua` | yes | green |
| 02-W0-04 | Wave 0 | 0 | SAFE-01 | T-02-04 | Auto-flee clears queue, prequeue, walk, gold, attack, and rage intent before any escape command is sent. | unit/integration | full Mudlet suite with expanded `tests/boop_safety_spec.lua` | yes | green |
| 02-W0-05 | Wave 0 | 0 | SAFE-03 | T-02-05 | Target disappearance clears stale attack intent and retargets only from valid current-room target data, preserving only active pull recovery state. | integration | full Mudlet suite with expanded `tests/boop_event_transitions_spec.lua` and `tests/boop_pull_spec.lua` | yes | green |

*Status: pending, green, red, flaky*

---

## Wave 0 Requirements

- [x] `tests/boop_walk_spec.lua` - focused tests for owned blocker reads and unsafe walk advancement holds without full route behavior.
- [x] `tests/boop_safety_spec.lua` - cleanup-before-flee-send assertions for queue, prequeue, walk, gold, standard/rage attack intent, and target-call intent.
- [x] `tests/boop_event_transitions_spec.lua` - GMCP blocker/backoff tests and target-loss cleanup/valid-retarget/pull-exception tests.
- [x] `tests/boop_trace_spec.lua` - canonical blocker enter/exit, target-loss cleanup, flee cleanup, pull hold, GMCP recovery, and retarget trace assertions.
- [x] `tests/boop_ui_spec.lua` - compact blocker/status/dashboard assertions for stable codes, labels, affected systems, and awaited state.
- [x] `tools/check_release_gates.py` - tightened state-drift allowlist after each migrated Phase 02 file.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Compact blocker/status readability | STATE-03 | User-facing readability still benefits from operator review even with string assertions. | In Mudlet, trigger a synthetic blocker or use status/trace test output; confirm one concise live warning and richer `boop status`/trace detail. |
| Live reconnect recovery | STATE-02 | Full live reconnect validation is deferred to Phase 06 by Phase 02 context. | Do not block Phase 02 on this; record any manual reconnect observations as follow-up evidence for Phase 06. |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies.
- [x] Sampling continuity: no 3 consecutive tasks without automated verify.
- [x] Wave 0 covers all missing references from `02-RESEARCH.md`.
- [x] No watch-mode flags.
- [x] Feedback latency stayed within the sampling rate above.
- [x] `nyquist_compliant: true` set in frontmatter after Wave 0 coverage is implemented and verified.

**Approval:** passed, backed by GitHub Actions run `29143523210` and user live Mudlet confirmation.
