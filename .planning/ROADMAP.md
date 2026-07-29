# Roadmap: boop Hunter

## v1.0: Pre-1.0 Hardening

## Overview

boop Hunter's pre-1.0 roadmap hardens the existing Mudlet hunting package in risk order: make release metadata and manifest drift visible first, repair owned runtime state and safety behavior, cover timing-heavy queue/gold/walk paths, lock down command trust boundaries, expand compact-summary fixtures, then close with docs and live release verification. This milestone preserves current behavior and release confidence rather than expanding the feature surface.

Parallelization note: Phase 4 can be planned after Phase 2 without waiting for Phase 3 if file ownership is split cleanly. Phase 5 fixture collection can begin once Phase 1 exists, but gag behavior changes should wait until Phase 2 safety signal is stable. Phase 6 closes after all prior behavior phases.

## Phases

**Phase Numbering:**

- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [x] **Phase 1: Release Gates and State Contracts** - CI and tests catch metadata, manifest, and high-risk state drift before later hardening. (completed 2026-07-10)
- [x] **Phase 2: State Ownership Repair and Safety Baseline** - Runtime state, GMCP degradation, flee, and stale-target behavior use canonical owned domains. (completed 2026-07-11)
- [ ] **Phase 3: Queue, Interrupt, Gold, and Autowalk Regression Coverage** - Timing-sensitive holds, loot, and walker movement are covered and fail closed.
- [ ] **Phase 4: Command Validation and Trust Boundaries** - User-controlled command fragments and whitelist-share apply flows are validated before they can become game commands.
- [ ] **Phase 5: Compact Summary Fixture Expansion and Focused Gag Fixes** - Live-log fixtures drive narrow gag fixes that preserve combat signal.
- [ ] **Phase 6: Docs, Help, and Live Release Verification** - Operator-facing surfaces and docs match behavior, and the 1.0 candidate has recorded build, test, and live checks.

## Phase Details

### Phase 1: Release Gates and State Contracts

**Goal**: Maintainers can trust CI and focused tests to catch release metadata, package membership, and high-risk state-contract drift before behavior changes land.
**Depends on**: Nothing (first phase)
**Requirements**: REL-01, REL-02, REL-04
**Success Criteria** (what must be TRUE):

  1. Maintainer can see CI fail when `mfile.version`, `mfile.title`, `boop.version`, or the `CODEX.md` checkpoint disagree.
  2. Maintainer can see CI fail when source JSON is invalid or script, alias, or trigger manifests do not match source files.
  3. Maintainer can run focused regression tests that fail when high-risk runtime paths bypass owned state contracts before behavior changes land.

**Plans**: 7/7 plans executed

- [x] 01-01-PLAN.md
- [x] 01-02-PLAN.md
- [x] 01-03-PLAN.md
- [x] 01-04-PLAN.md
- [x] 01-05-PLAN.md
- [x] 01-06-PLAN.md
- [x] 01-07-PLAN.md

### Phase 2: State Ownership Repair and Safety Baseline

**Goal**: boop's runtime, safety, trace, status, and dashboard behavior agree on canonical owned state and fail closed when game state is incomplete.
**Depends on**: Phase 1
**Requirements**: STATE-01, STATE-02, STATE-03, SAFE-01, SAFE-03
**Success Criteria** (what must be TRUE):

  1. Hunting state for room, target, pull, walk, gold, diag, flee, queue, inventory, trace, rage, IH, and gag is read and written through owned domains instead of removed flat keys.
  2. User sees visible blockers or warnings when GMCP reconnect, missing `gmcp.IRE`, partial room or target updates, or hidden game state make automation unsafe.
  3. Runtime trace, status, and dashboard surfaces report the same canonical values for targeting, movement, pull, gold, diag, flee, queue, and gag debugging.
  4. Auto-flee cancels or blocks queue, prequeue, walk, gold, and attack intent before escape movement is sent.
  5. When the current target disappears from GMCP room items, queued attack state clears and boop retargets only from valid room targets.

**Plans**: 7/7 plans executed

Plans:

- [x] 02-01-PLAN.md — Wave 0 runtime, flee, and walk safety test contracts
- [x] 02-02-PLAN.md — Wave 0 GMCP, target-loss, pull, trace, and UI test contracts
- [x] 02-03-PLAN.md — Canonical owned blocker model and GMCP recovery holds
- [x] 02-04-PLAN.md — Flee cleanup, target-loss cleanup, pull exception, and attack ownership repair
- [x] 02-05-PLAN.md — Walk ownership migration and state-drift gate tightening
- [x] 02-06-PLAN.md — Canonical status, dashboard, trace, and focused docs/help sync
- [x] 02-07-PLAN.md — Final automated gates and compact blocker/status human checkpoint

**UI hint**: yes

### Phase 3: Queue, Interrupt, Gold, and Autowalk Regression Coverage

**Goal**: Timing-sensitive command paths cannot attack, loot, or walk while another safety hold or room-state blocker owns the next action.
**Depends on**: Phase 2
**Requirements**: SAFE-02, SAFE-04, WALK-01, WALK-02, WALK-03
**Success Criteria** (what must be TRUE):

  1. `diag`, queued interrupts, `pull`, and manual holds prevent automatic attacks until their prompt, room, or timeout release condition is satisfied.
  2. Gold pickup, pack/stash, retry, warning, and stale-pending behavior cannot send commands in the wrong room or bypass active safety holds.
  3. `boop walk` start, stop, move, and status behavior reflects room-settled state, blocker reasons, and external `demonwalker.move` emission only when the room is safe to leave.
  4. `demonnicAutoWalker` remains optional, with explicit install/status feedback and no silent auto-update behavior.
  5. Regression coverage catches unsafe movement, attacks during holds, wrong-room loot commands, target-removal queue drift, and permanent walk stalls.

**Plans**: 23/24 plans executed

Plans:

- [x] 03-20-PLAN.md
- [x] 03-21-PLAN.md
- [x] 03-22-PLAN.md
- [x] 03-23-PLAN.md
- [ ] 03-24-PLAN.md

- [x] 03-16-PLAN.md
- [x] 03-17-PLAN.md
- [x] 03-18-PLAN.md
- [x] 03-19-PLAN.md

- [x] 03-11-PLAN.md
- [x] 03-12-PLAN.md
- [x] 03-13-PLAN.md

**Wave 15** *(blocked on Wave 14 completion; ready for gap execution)*

- [x] 03-15-PLAN.md — Diagnose/pull contract repair and real-Mudlet suite isolation

**Wave 14** *(blocked on Wave 13 completion; ready for gap execution)*

- [x] 03-14-PLAN.md — Disabled-safe lifecycle evidence and calibrated room-response warning

**Wave 1**

- [x] 03-01-PLAN.md — Canonical owner-keyed blockers and shared room-observation foundation

**Wave 2** *(blocked on Wave 1 completion)*

- [x] 03-02-PLAN.md — Generation-owned queued interrupts and first-terminal callback safety

**Wave 3** *(blocked on Wave 2 completion)*

- [x] 03-03-PLAN.md — Generation-owned pull lifecycle without persisted enable mutation

**Wave 4** *(blocked on Wave 3 completion)*

- [x] 03-04-PLAN.md — Staged gold core, runtime ownership, and focused gold specs

**Wave 5** *(blocked on Wave 4 completion)*

- [x] 03-05-PLAN.md — Gold room/event/tick integration and cross-owner resumption

**Wave 6** *(blocked on Wave 5 completion)*

- [x] 03-06-PLAN.md — Walker core, shared all-clear evaluator, and guarded emitter

**Wave 7** *(blocked on Wave 6 completion)*

- [x] 03-07-PLAN.md — Walker stop/arrival/event integration and ownership outcomes

**Wave 8** *(blocked on Wave 7 completion)*

- [x] 03-08-PLAN.md — Multi-owner UI/help and aggregate attack/prequeue coverage

**Wave 9** *(blocked on Wave 8 completion)*

- [x] 03-09-PLAN.md — Cross-lifecycle matrix, docs, and exact-HEAD authoritative validation

**Wave 10** *(blocked on Wave 9 completion)*

- [x] 03-10-PLAN.md — Gold timeout authority recovery and permanent walk-stall regression closure

### Phase 4: Command Validation and Trust Boundaries

**Goal**: Operator-entered and party-provided command fragments are reviewed and constrained before persistence, queueing, or game-command dispatch.
**Depends on**: Phase 2
**Requirements**: CMD-01, CMD-02, CMD-03
**Success Criteria** (what must be TRUE):

  1. Unsafe separators, directions, pack/container values, assist leader names, pull target names, queue payload fragments, and party text are rejected before they are persisted or sent.
  2. User sees clear accepted or rejected feedback when command inputs do not match conservative forms.
  3. Whitelist-share receive flow shows sender, area, entry count, mode risk, TTL/cap state, and trusted-sender status before destructive apply modes are accepted.

**Plans**: TBD

### Phase 5: Compact Summary Fixture Expansion and Focused Gag Fixes

**Goal**: Compact combat summaries reduce scroll while preserving damage, target, kill, warning, failure, unusual-event, and stats signal.
**Depends on**: Phase 1 and Phase 2
**Requirements**: GAG-01, GAG-02, GAG-03, GAG-04
**Success Criteria** (what must be TRUE):

  1. Maintainer can replay fixtures covering own attacks, battlerage, mob attacks plus health loss, kill/XP ordering, crit tiers, shield/no-shield lines, pets/follow-through, and unusual parse cases.
  2. User sees compact summaries that preserve target, damage, crit, kill, XP/gold, warning, failed-command, and unusual-event signal.
  3. Unknown or safety-relevant lines remain visible or produce traceable compact diagnostics instead of being silently hidden.
  4. Summary ordering is stable: attack summaries flush before kill summaries, stale summaries do not cross target changes, and stats hooks receive the same meaning as visible output.

**Plans**: TBD

### Phase 6: Docs, Help, and Live Release Verification

**Goal**: The 1.0 candidate is coherent for operators and backed by recorded package build, automated Mudlet tests, and live validation evidence.
**Depends on**: Phase 3, Phase 4, and Phase 5
**Requirements**: REL-03, UX-01, UX-02, UX-03, LIVE-01, LIVE-02
**Success Criteria** (what must be TRUE):

  1. User can reach common workflows through coherent `boop`, `boop control`, `boop config`, `boop party`, `boop stats`, and `boop help` entry points.
  2. `bh`, `boop on`, `boop off`, status, gag, and blocker outputs show compact state summaries with consistent `[OK]`, `[INFO]`, `[WARN]`, and `[ERR]` feedback.
  3. README, command help, UIDESIGN guidance, and dashboard copy match every changed command surface or operator workflow.
  4. Maintainer can produce a 1.0 candidate only after Muddler build output, Busted execution inside a real Mudlet profile, and required live Mudlet checks are recorded.
  5. Unresolved live regressions are recorded as GSD follow-up work before release approval.

**Plans**: TBD
**UI hint**: yes

## Progress

**Execution Order:**
Phases normally execute in numeric order. Phase 4 may be planned after Phase 2 in parallel with Phase 3 if implementation ownership is split safely. Phase 6 executes after all behavior phases complete.

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Release Gates and State Contracts | 7/7 | Complete    | 2026-07-10 |
| 2. State Ownership Repair and Safety Baseline | 7/7 | Complete    | 2026-07-11 |
| 3. Queue, Interrupt, Gold, and Autowalk Regression Coverage | 23/24 | In Progress|  |
| 4. Command Validation and Trust Boundaries | 0/TBD | Not started | - |
| 5. Compact Summary Fixture Expansion and Focused Gag Fixes | 0/TBD | Not started | - |
| 6. Docs, Help, and Live Release Verification | 0/TBD | Not started | - |
