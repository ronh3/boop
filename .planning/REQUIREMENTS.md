# Requirements: boop Hunter

**Defined:** 2026-07-09
**Core Value:** boop must make Achaea hunting safer, clearer, and less noisy without taking control away from the operator.

## v1 Requirements

Requirements for the pre-1.0 hardening milestone. Each maps to roadmap phases.

### Release Gates

- [ ] **REL-01**: CI fails when `mfile.version`, `mfile.title`, `src/scripts/boop/boop_init.lua` `boop.version`, or the `CODEX.md` session checkpoint disagree.
- [ ] **REL-02**: CI validates source JSON and Muddler manifest/file parity for scripts, aliases, and triggers without auto-sorting runtime-sensitive manifests.
- [ ] **REL-03**: Release verification includes Muddler build output and Busted execution inside a real Mudlet profile before a 1.0 candidate is considered ready.
- [ ] **REL-04**: High-risk runtime paths have focused regression tests before behavior changes land.

### Runtime State

- [ ] **STATE-01**: Room, target, pull, walk, gold, diag, flee, queue, inventory, trace, rage, IH, and gag state are read and written through owned state domains rather than removed flat keys.
- [ ] **STATE-02**: GMCP reconnect, missing `gmcp.IRE`, partial room/target updates, and intentionally hidden game state degrade with visible blockers or warnings instead of unsafe guessing.
- [ ] **STATE-03**: Runtime trace, status, and dashboard surfaces report canonical owned-state values when debugging targeting, movement, pull, gold, diag, flee, queue, and gag behavior.

### Safety And Timing

- [ ] **SAFE-01**: Auto-flee cancels or blocks queue, prequeue, walk, gold, and attack intent before sending escape movement.
- [ ] **SAFE-02**: `diag`, queued interrupts, `pull`, and manual hold flows prevent automatic attacks until their prompt, room, or timeout release conditions are satisfied.
- [ ] **SAFE-03**: Stale target cleanup clears queued attacks and retargets safely when the current target disappears from GMCP room items.
- [ ] **SAFE-04**: Gold pickup, pack/stash, retry, warning, and stale-pending behavior cannot send commands in the wrong room or bypass active safety holds.

### Autowalk Integration

- [ ] **WALK-01**: `boop walk` tests cover start, stop, move, room-settled behavior, blocker reasons, and external `demonwalker.move` event emission.
- [ ] **WALK-02**: Walker advancement is blocked while target, gold, diag, flee, pull, leader-call, or room-settling state says the room is not safe to leave.
- [ ] **WALK-03**: `demonnicAutoWalker` remains an optional external integration with explicit install/status feedback and no silent auto-update behavior.

### Command Trust

- [ ] **CMD-01**: Shared validation rejects unsafe user-controlled command fragments before they are persisted or sent.
- [ ] **CMD-02**: Separators, directions, pack/container values, assist leader names, pull target names, queue payload fragments, and party text use conservative accepted forms.
- [ ] **CMD-03**: Whitelist-share apply flow displays sender, area, entry count, mode risk, TTL/cap state, and trusted-sender status before destructive apply modes are accepted.

### Compact Summaries

- [ ] **GAG-01**: Live-log replay fixtures cover own attacks, battlerage, mob attacks plus health loss, kill/XP ordering, crit tiers, shield/no-shield lines, pets/follow-through, and unusual parse cases before gag timing or merge logic changes.
- [ ] **GAG-02**: Compact summaries preserve target, damage, crit, kill, XP/gold, warning, failed-command, and unusual-event signal.
- [ ] **GAG-03**: Unknown or safety-relevant lines remain visible or produce traceable compact diagnostics rather than being silently hidden.
- [ ] **GAG-04**: Summary ordering is stable: attack summaries flush before kill summaries, stale summaries do not cross target changes, and stats hooks receive the same meaning as visible output.

### Operator Experience

- [ ] **UX-01**: `boop`, `boop control`, `boop config`, `boop party`, `boop stats`, and `boop help` remain coherent entry points with direct routes for common workflows.
- [ ] **UX-02**: `bh`, `boop on`, `boop off`, status, gag, and blocker outputs use compact state summaries with consistent `[OK]`, `[INFO]`, `[WARN]`, and `[ERR]` feedback.
- [ ] **UX-03**: README, command help, UIDESIGN guidance, and dashboard copy are updated with every command-surface or operator-workflow change.

### Live Validation

- [ ] **LIVE-01**: Final 1.0 validation includes live Mudlet checks for GMCP reconnect, room/target state, retargeting, gold plus pack, `diag`, one queued interrupt, pull, walk, and gag summaries.
- [ ] **LIVE-02**: Live validation records unresolved regressions as GSD follow-up work before release approval.

## v2 Requirements

Deferred to future release. Tracked but not in the current roadmap.

### Feature Depth

- **V2-FEAT-01**: Add broader class/profile coverage after profile contracts and replay fixtures are stable.
- **V2-FEAT-02**: Add richer party combo optimization after command-trust boundaries are explicit.
- **V2-FEAT-03**: Add current-area whitelist reporting to `boop party` after 1.0 release hardening.
- **V2-FEAT-04**: Add trace export after trace contents and privacy bounds are stable.
- **V2-FEAT-05**: Add stats export or render caching when real long-session cost or export demand is observed.

### Tooling

- **V2-TOOL-01**: Consider a live combat-log replay importer after manual replay fixtures prove the format.
- **V2-TOOL-02**: Consider data-driven trigger generation after manifest parity and fixture review are reliable.
- **V2-TOOL-03**: Consider pinned external walker release policy after the walker contract suite exists.

### UI

- **V2-UI-01**: Consider an optional miniwindow mirror only after inline dashboards settle and remain canonical.

## Out of Scope

Explicitly excluded. Documented to prevent scope creep.

| Feature | Reason |
|---------|--------|
| Full rewrite or broad architecture churn | The product is already mostly built; pre-1.0 value comes from hardening existing behavior. |
| PvP combat automation | boop is a hunting/bashing package, not a PvP offense system. |
| Unattended AFK hunting or timeout avoidance | Conflicts with the attended operator-control boundary and Achaea automation risk. |
| Absorbing route/pathfinding ownership | `demonnicAutoWalker` remains the optional external walker; boop owns safety/blocker decisions only. |
| SVO, Wundersys, or other large framework dependency | The package promise is self-contained behavior with explicit optional integrations. |
| Large bundled static area databases | Area data should remain operator-maintained/imported and DB-backed. |
| Blanket gagging | Spam reduction must preserve warnings, failures, unusual events, and safety signal. |
| Arbitrary remote-command party automation | Party flows remain narrow, explicit, and trusted; no general remote command execution. |
| New rage modes for novelty | Existing modes are broad enough; tune them only from live evidence. |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| REL-01 | Phase 1 | Pending |
| REL-02 | Phase 1 | Pending |
| REL-03 | Phase 6 | Pending |
| REL-04 | Phase 1 | Pending |
| STATE-01 | Phase 2 | Pending |
| STATE-02 | Phase 2 | Pending |
| STATE-03 | Phase 2 | Pending |
| SAFE-01 | Phase 2 | Pending |
| SAFE-02 | Phase 3 | Pending |
| SAFE-03 | Phase 2 | Pending |
| SAFE-04 | Phase 3 | Pending |
| WALK-01 | Phase 3 | Pending |
| WALK-02 | Phase 3 | Pending |
| WALK-03 | Phase 3 | Pending |
| CMD-01 | Phase 4 | Pending |
| CMD-02 | Phase 4 | Pending |
| CMD-03 | Phase 4 | Pending |
| GAG-01 | Phase 5 | Pending |
| GAG-02 | Phase 5 | Pending |
| GAG-03 | Phase 5 | Pending |
| GAG-04 | Phase 5 | Pending |
| UX-01 | Phase 6 | Pending |
| UX-02 | Phase 6 | Pending |
| UX-03 | Phase 6 | Pending |
| LIVE-01 | Phase 6 | Pending |
| LIVE-02 | Phase 6 | Pending |

**Coverage:**
- v1 requirements: 26 total
- Mapped to phases: 26
- Unmapped: 0

---
*Requirements defined: 2026-07-09*
*Last updated: 2026-07-09 after roadmap creation*
