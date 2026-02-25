# DESIGN.md

Design plan for the `boop` self-contained Achaea autohunter/basher.

## Purpose
Build a reliable, self-contained hunting system for Achaea with sane defaults, clear configuration, and minimal dependencies.

## Scope
- Automatic target selection and attack execution for bashing.
- Configurable targeting and attack strategies.
- Tracking gains and safety automation (flee, pause, shield handling).
- Lightweight interactive UI and command surface for configuration and status.
- Info-Here capture with click-to-add/remove for whitelist/blacklist.

## Non-Goals
- Depend on external systems (SVO, Wundersys, other frameworks).
- Ship large, static area databases without validation.
- Implement advanced combat automation beyond bashing.

## Core Requirements
- Self-contained Mudlet package that runs without external systems.
- Use GMCP and IRE.Target when available.
- Use Mudlet DB for persistent config and lists.
- Provide clear configuration commands and feedback.

## What We’ll Vulture
- From Bashing
  - Auto-flee logic based on estimated damage and thresholds.
  - Trip/session/lifetime gains tracking.
  - Simple priority list UX (auto-add on kill, click-to-remove).
- From Foxhunt
  - DB-backed whitelist/blacklist with priority order per area.
  - Info-Here capture with click-to-add/remove.
  - Structured GMCP event handlers for room/target/status state.
  - Class attack definitions as data tables.

## What We’ll Discard
- External queue system integrations (SVO/Wundersys).
- Massive static area lists without maintenance.
- Personal or character-specific hardcoding.

## Proposed Architecture
- `boop.core`
  - Event handlers for GMCP room/target/status updates.
  - State and limiter management.
- `boop.config`
  - DB-backed settings with defaults and migration.
- `boop.skills`
  - GMCP-driven skill inventory for gating abilities.
- `boop.afflictions`
  - Target affliction tracking (stubbed; manual overrides; ingestion deferred).
- `boop.targets`
  - Target selection logic and list management.
  - Whitelist/blacklist and priority handling.
- `boop.attacks`
  - Attack strategems per class.
  - Queueing abstraction using native Mudlet queue commands.
- `boop.rage`
  - Rage readiness fallback (timers + text triggers).
- `boop.safety`
  - Auto-flee thresholds and pause-on-affliction logic.
- `boop.stats`
  - Session/trip/lifetime gains and timers.
- `boop.ui`
  - Config display and click UI helpers.
- `boop.ih`
  - Info-Here capture and clickable list management.

## Data Model (Mudlet DB)
- `config` key/value settings.
- `whitelist` with `area`, `pos`, `name`, `ignore`.
- `blacklist` with `area`, `pos`, `name`, `ignore`.
- `stats` for lifetime totals.

## Targeting Modes
- `manual` (no auto retarget)
- `whitelist` (only allow targets in per-area whitelist)
- `blacklist` (allow all except per-area blacklist and global blacklist)
- `auto` (any valid denizen)

## Attack Flow (High-Level)
1. Update room/denizen state from GMCP.
2. Choose target based on mode and priority.
3. Ensure IRE.Target is set (by denizen ID).
4. Build standard action and rage action from class strategem.
5. Gate rage by IRE.Display readiness when available (fallback: rage amount only).
6. Send via native Mudlet queue or direct send (standard + rage can fire together).
7. Apply safety checks and flee if needed.

## Implementation Notes (Current)
- Targeting uses GMCP `Char.Items.*` data and sends `IRE.Target.Set` with denizen ID.
- Denizen filtering: attrib includes `m` and excludes `x` and `d`.
- `boop ih` re-renders Info-Here lines and adds clickable whitelist/blacklist buttons for denizens.
- `boop config` renders a clickable configuration dashboard for common toggles/modes.
- `boop` shows status plus the main help dashboard for quick command discovery.
- `boop config` and `boop help` use a shared sectioned row layout (`HEADER > section`, divider, aligned `[ value ]` action buttons).
- `boop whitelist` and `boop blacklist` render clickable list managers (`up`/`down`/`remove`).
- `boop autogold` toggles automatic pickup of newly dropped gold sovereigns; in queueing mode it prepends `get sovereigns/` to the next standard attack, with a short fallback timer to queue `get sovereigns` if no attack follows (and non-queueing mode uses queued `get sovereigns` to avoid balance-lock misses).
- `boop pack <container>` sets an optional auto-stash container (`put sovereigns in <container>`) used after auto gold pickup.
- `boop import foxhunt [merge|overwrite|dryrun]` imports area list data from Foxhunt's `hunting` DB into boop lists.
- Gold get/put tracking now listens for success/failure lines and performs bounded retries before warning.
- `boop prequeue` and `boop lead` make prequeue behavior explicit and independent from `useQueueing`.
- `diag` clears queue, queues `diagnose`, and temporarily blocks attacks until a diagnose result line plus prompt.
- `diag` includes a timeout fallback to release attack hold if diagnose result lines are missed.
- `boop get/set` provides scriptable config access, and `boop trace` exposes a rolling decision/command buffer.
- Two-handed standards prepend `battlefury focus speed/` when `Focus` is known (Weaponmastery), excluding shieldbreaker paths.
- Unnamable standards prepend `maul &tar/` when `Maul` is known (Dominion) and ready, with readiness tracked through the existing ability-ready trigger lines.
- Standard attacks and rage actions are independent; standard builds rage and there is no mode toggle.
- Skill gating issues `Char.Skills.Get` requests per skill (group-aware).

## Versioning Policy
- Bump `mfile.version` on every commit/merge.
- Manually sync `mfile.title` to `boop Hunter <version>` on each version bump.

## Concrete Plan
1. Inventory and extract reference behaviors from Bashing and Foxhunt into notes.
2. Draft `boop` module layout and initial namespaces in `src/scripts/`.
3. Implement DB schema + config defaults.
4. Implement GMCP event handlers and room/target state.
5. Implement target selection modes and list management.
6. Implement attack strategems for a small starter set of classes.
7. Implement safety system (auto-flee + pause-on-afflictions).
8. Implement stats tracking and trip/session timers.
9. Implement minimal UI commands and Info-Here click management.
10. Package and test in Mudlet with a controlled checklist.

## Decisions
- First supported class: Occultist.
- Command prefix: `boop`.
- Default auto-flee threshold: 30% HP.
- Rage readiness: prefer IRE.Display (GMCP); fallback to internal ready flags + timers and text triggers.
- Affliction tracking: manual only for now; ingestion deferred.
- Standard and rage actions are separate timers and can be used in tandem.
- Targeting uses ID (not name).

## Open Questions
- None yet (add here as they come up).
