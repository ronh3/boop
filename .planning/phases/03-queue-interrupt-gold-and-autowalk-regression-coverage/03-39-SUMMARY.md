---
phase: 03-queue-interrupt-gold-and-autowalk-regression-coverage
plan: 39
subsystem: interrupt-admission-hierarchy
tags: [mudlet, interrupts, safety, supersession, generation-ownership]

requires:
  - phase: 03-27
    provides: generation-owned leap denial and exact interrupt terminal handling
  - phase: 03-29
    provides: exact live interrupt terminal trace visibility
provides:
  - runtime-owned interrupt admission tiers independent from blocker display order
  - atomic higher-priority and repeated-emergency supersession
  - stale timer, causal-window, blocker, and diagnose-evidence quarantine
affects: [03-40, SAFE-02, SAFE-04, WALK-02, class-heal-interrupt]

tech-stack:
  added: []
  patterns:
    - install incoming generation ownership before releasing the superseded owner
    - declare command tiers at the caller and evaluate policy in runtime

key-files:
  created:
    - .planning/phases/03-queue-interrupt-gold-and-autowalk-regression-coverage/03-39-SUMMARY.md
  modified:
    - src/scripts/boop/boop_runtime.lua
    - src/scripts/boop/boop_ui.lua
    - src/scripts/boop/boop_safety.lua
    - tests/boop_interrupt_spec.lua
    - tests/boop_safety_spec.lua
    - README.md
    - DESIGN.md

key-decisions:
  - "Interrupt admission priority is independent from BLOCKER_PRIORITY, which remains display-only."
  - "The operator's newer requirement supersedes the plan's duplicate-idempotence rule for emergency commands: repeated leap/fly requests replace their own active generation and receive a fresh timeout."
  - "Different same-tier commands and lower-tier requests remain rejected without changing the active operation."
  - "Auto-flee disables automation, terminalizes any interrupt, clears the native queue, and then sends flee actions."

requirements-completed: [SAFE-02, SAFE-04, WALK-02]

coverage:
  - id: G-03-27-AUTOMATED
    description: "Interrupt tiers, atomic supersession, repeated leap recovery, and stale-generation isolation"
    requirement: SAFE-04
    verification:
      - kind: automated
        ref: tests/boop_interrupt_spec.lua
        status: pass
      - kind: automated
        ref: tests/boop_safety_spec.lua
        status: pass
    human_judgment: false

completed: 2026-08-26
status: complete
---

# Phase 03 Plan 39: Interrupt Admission Hierarchy Summary

**Package 0.1.484 gives room-exit and safety commands explicit authority to replace stuck lower-priority interrupts without waiting for their timers.**

## Accomplishments

- Added pure runtime admission for utility, diagnostic, emergency, and absolute tiers.
- Made leap and fly supersede diagnose or utility work, and diagnose supersede utility work.
- Made a repeated leap/fly an explicit retry with a fresh generation and timeout.
- Installed incoming ownership before terminalizing the old generation as `superseded_by:<name>`.
- Quarantined old timers, leap causality, blockers, and diagnose evidence so late callbacks cannot release the new operation.
- Made auto-flee terminalize active interrupts and clear their native queue before sending flee commands.

## Assumption Delta

The original plan required identical requests to remain idempotent. Live operator feedback showed that this preserved a failed leap until timeout and prevented an immediate retry. The shipped rule therefore permits same-kind emergency replacement while retaining rejection for different same-tier and lower-priority requests; duplicate diagnose and utility requests remain idempotent/rejected.

## Verification

- 224 focused and adjacent host tests passed across interrupt, diagnose, safety, runtime, room-event, walk, gold, and tick suites.
- Lua syntax, release gates, Muddler build, and exact-SHA Mudlet CI remain part of the package closeout.
- Live authority remains pending in Plan 03-40.

## Next Step

Install package 0.1.484 and execute Plan 03-40: queue diagnose, immediately issue a valid leap, confirm the leap replaces diagnose without a timeout wait, then repeat leap before settlement and confirm the old timer is inert.

---
*Phase: 03-queue-interrupt-gold-and-autowalk-regression-coverage*
*Completed: 2026-08-26*
