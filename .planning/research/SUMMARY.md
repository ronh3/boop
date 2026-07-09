# Project Research Summary

**Project:** boop Hunter
**Domain:** Brownfield standalone Mudlet package for Achaea hunting/bashing
**Researched:** 2026-07-09
**Confidence:** HIGH for local repo conclusions; MEDIUM for external Mudlet/Achaea API currency

## Executive Summary

boop Hunter is already a mature Achaea hunting helper, not a greenfield build. Experts should harden it as a Mudlet Lua 5.1 package with thin aliases/triggers, GMCP-driven state, Mudlet DB persistence, Muddler packaging, Busted-in-real-Mudlet CI, and optional demonnicAutoWalker integration. The current stack and architecture are correct for 1.0; the release risk is inconsistency at boundaries, not missing broad capability.

The recommended approach is a pre-1.0 hardening roadmap: add release gates, lock owned state-domain contracts, repair state drift, then cover autowalk, command-fragment validation, compact gag summaries, and docs/help coherence. Feature work should mostly stabilize existing behavior users already rely on: targeting, attacks, rage, safety, gold, party support, dashboards, stats, and compact combat summaries.

The main risks are safety-critical timing bugs and quiet failures: split GMCP room state can break pull/flee/walk, gagging can hide real combat signal, timers can race queue/gold/interrupt behavior, and CI can pass while manifests or version metadata are wrong. Mitigate with focused Busted-in-Mudlet specs, live combat-log fixtures, strict version/manifest gates, shared command validation before persistence, and live Mudlet validation for GMCP, prompt, gag, queue, walker, and game-text behavior.

## Key Findings

### Stack

Keep the existing stack. boop should remain a self-contained Mudlet Lua 5.1-compatible package built with Muddler, persisted through Mudlet DB, driven by Achaea/Iron Realms GMCP plus text-trigger fallbacks, and tested with Busted inside a real Mudlet profile. Do not introduce a new runtime framework, external hunting/curing dependency, alternate builder, or internal walker before 1.0.

**Core technologies:**

- Mudlet Lua 5.1 - runtime for aliases, triggers, event handlers, timers, DB, and rich output; keep Lua 5.1-compatible code.
- Muddler - source-to-package builder using `mfile` and `src/**` manifests; keep generated artifacts out of source edits.
- Mudlet DB - persistent config, hunting lists, tags, and stats; avoid ad hoc file persistence.
- Achaea/IRE GMCP - primary source for room, target, vitals, skills, inventory, and IRE modules; keep nil guards and text fallbacks.
- Busted inside real Mudlet CI - primary automated release gate; extend it for state ownership, autowalk, gags, command validation, manifests, and version sync.
- demonnicAutoWalker - optional external walking package; boop should decide when a room is safe to leave, while the walker owns pathing.

**Critical version/build requirements:**

- Keep `mfile.version`, `mfile.title`, and `src/scripts/boop/boop_init.lua` `boop.version` synchronized.
- Keep `src/scripts/boop/scripts.json` manually ordered; do not auto-sort it.
- Add CI gates for JSON validity, manifest/file parity, version synchronization, and packaged import behavior.
- Keep Mudlet 4.20.1 as the current CI floor unless a live regression forces a documented minimum-version bump.

### Features

boop is past MVP feature discovery. The mature table-stakes feature set is already present: GMCP room/target state, denizen-ID targeting, DB-backed whitelist/blacklist/tags, class attack profiles, battlerage modes, shield handling, safety interrupts, gold/pack behavior, party coordination, stats, dashboards, help, trace, and compact gag summaries.

**Must harden for 1.0:**

- GMCP-driven room, target, denizen, vitals, skills, and IRE module state.
- Targeting by denizen id with conservative targeting modes and priority controls.
- Owned runtime state for room, pull, walk, gold, diag, flee, queue, targeting, inventory, trace, rage, IH, and gag domains.
- Safety behavior: auto-flee, interrupt holds, pull recovery, queue cancellation, and stale target cleanup.
- Loot timing: gold pickup, pack/stash, retries, warnings, and interaction with queue/walk.
- Compact combat summaries that preserve damage, target, crit, kill, XP/gold, warning, and unusual-line signal.
- Autowalk blocker and room-settled regression coverage.
- Release gates for version sync, manifest parity, and package build/import confidence.
- Shared validation for user-controlled command fragments before persistence or dispatch.
- Workflow coherence across `boop`, `boop control`, `boop config`, `boop party`, `boop stats`, `boop help`, docs, and in-game feedback tags.

**Differentiators to keep but not expand before 1.0:**

- Party roster, combo inference, target/affliction calls, and whitelist sharing.
- Advanced battlerage modes and conditional profile logic.
- Stats depth across session, login, trip, lifetime, areas, mobs, targets, abilities, crits, and rage.
- Configurable gag scopes/colors and compact on/off/status feedback.

**Defer or treat as non-goals:**

- Broad class/profile expansion unless fixing a shipped profile bug.
- New rage modes, miniwindows, trace export, stats export/caching, data-driven trigger generation, and combat-log replay importer beyond focused fixtures.
- Route/pathfinding ownership, absorbing demonnicAutoWalker, or silent auto-install/update behavior.
- Large bundled static area databases.
- PvP combat automation, arbitrary remote-command party automation, unattended AFK hunting, timeout avoidance, or any feature optimized for unattended gold/XP gain.
- Broad architecture rewrites or a parallel menu system.

### Architecture

Keep the current manifest-loaded global `boop` namespace with thin Mudlet adapters, owned runtime state domains, domain modules, and a runtime coordinator that plans effects before applying Mudlet side effects. This shape matches Mudlet's event-driven Lua 5.1 runtime and allows risky behavior to be tested through domain functions instead of scattered alias/trigger scripts.

**Major components:**

1. Package manifests - `mfile` and `src/**/{scripts,aliases,triggers}.json` define package membership and load order.
2. Bootstrap/events - initialize `boop`, DB/state, trigger sync, GMCP support, and event handlers.
3. Runtime state/coordinator - canonical volatile domains plus `context`, `step`, and `applyEffects`.
4. Targeting - denizen lists, current target, shield state, DB-backed lists, party calls, and whitelist sharing.
5. Combat planner/executor - class profiles, skill gates, standard/rage decisions, queue/direct send effects.
6. Safety/interruption - flee, diag, queued interrupts, pull lifecycle, and fail-closed behavior.
7. Gag summarizer - pending attack/kill/mob summaries, prompt flush, colors, stats hooks, and fixture-driven text handling.
8. Walker adapter - optional demonnicAutoWalker boundary and room-clear/blocker decisions.
9. Persistence/UI/tests - Mudlet DB helpers, dashboards/help/config registries, and Busted-in-Mudlet CI.

**Patterns to follow:**

- Plan from runtime context and apply effects through domain APIs.
- Store volatile state only under owned domains such as `state.targeting`, `state.combat`, `state.walk`, `state.gold`, `state.diag`, and `state.gag`.
- Keep aliases/triggers thin and delegate to domain code.
- Add live-line replay fixtures before gag timer, delete-line, merge, or trigger-breadth changes.
- Validate command fragments before saving them, not only at final `send()`.

### Critical Pitfalls

1. **Split GMCP room state breaks pull, flee, and walk** - make `state.targeting.room/lastRoom/lastRoomDir/movedRooms` and `state.combat.pullState` canonical; add no-flat-state regression tests.
2. **Compact gagging hides real combat signal** - fixture every live line shape before changing gag timing or merge logic; keep warnings and unknown lines visible or traceable.
3. **Queue, prequeue, interrupt, gold, and pull timers race each other** - centralize hold/cancel/alias-dirty transitions and test interleavings around room changes, target removal, gold, and prompts.
4. **Autowalk advances on a false room-clear state** - repair canonical blockers, enable walk contract tests, and only raise `demonwalker.move` after room-settled and safety checks pass.
5. **Safety fails open or uses a bad escape path** - flee should cancel queue/prequeue/walk/gold intent, require a canonical last-room direction, and keep warnings visible.
6. **User-controlled command fragments become game commands** - centralize validation for separators, directions, pack/container values, leader names, pull targets, queue payloads, party text, and future command settings.
7. **CI passes while release artifact metadata is wrong** - add version sync, manifest parity, pinned/reproducible build checks, and packaged import validation.

## Implications for Roadmap

Suggested phase structure should optimize for dependency order and release risk, not novelty.

### Phase 1: Release Gates and State Contracts

**Rationale:** Low-behavior-risk gates and tests should land before later hardening so package omissions, version drift, and state regressions are caught immediately.

**Delivers:** Version sync check, JSON parse check, manifest/file parity check, required load-order anchors, and state-domain contract tests for room, pull, walk, inventory, gold, diag, flee, queue, target, and gag domains.

**Addresses:** Release confidence, runtime state ownership, CI/version gates.

**Avoids:** Green CI with a broken package, hidden flat-state drift, and version/artifact mismatch.

**Research flag:** Standard patterns; no extra research phase needed unless CI tooling choices change.

### Phase 2: State Ownership Repair and Safety Baseline

**Rationale:** Autowalk, pull, flee, gold, and diag behavior depend on a single canonical state model. Fixing symptoms before state ownership is stable will create churn.

**Delivers:** Migration of remaining flat room/pull/walk/inventory/flee paths to owned domains; fail-closed safety behavior; reconnect/nil-GMCP degradation; trace updates for support.

**Addresses:** Runtime state consistency, pull/flee room transitions, stale target cleanup, GMCP degradation.

**Avoids:** Pull timeouts after returning, missing flee direction, stale queue aliases, and dashboards disagreeing with runtime state.

**Research flag:** Needs light phase research only for live GMCP edge cases such as reconnect and hidden/fogged state behavior.

### Phase 3: Queue, Interrupt, Gold, and Autowalk Regression Coverage

**Rationale:** These domains compete for command timing and room movement. They should be tested together after state ownership is repaired.

**Delivers:** Active `boop_walk_spec` coverage; blocker reasons for target/gold/diag/flee/leader-call/room-settled states; tests for interrupt during gold, room change during prequeue, target removal after alias set, pull timeout, and walker advance after gold resolution.

**Addresses:** Autowalk regression coverage, queue/interrupt/gold hardening, optional walker integration.

**Avoids:** Walking away mid-combat or mid-loot, attacks firing during manual holds, gold commands in the wrong room, and permanent walk stalls.

**Research flag:** Needs `$gsd-plan-phase --research-phase` if changing demonnicAutoWalker event/API assumptions or install/pinning behavior; otherwise local tests and live validation are enough.

### Phase 4: Command Validation and Trust Boundaries

**Rationale:** Persisted operator input can become game commands later through send, queue, pull, pack, party, or rich links. This should be fixed before adding command-surface breadth.

**Delivers:** Shared validator surface; validation for separators, directions, pack/container, leader/sender names, pull mob names, queue fragments, and party whitelist-share packet caps/TTL/trusted sender review.

**Addresses:** Command-fragment validation, whitelist-share trust hardening, external install clarity.

**Avoids:** Multi-command injection through persisted config, arbitrary remote-command automation, unsafe party share apply flows, and silent latest-package supply-chain drift.

**Research flag:** Needs focused research if defining a stricter public trust model for party shares or pinning third-party install URLs.

### Phase 5: Compact Summary Fixture Expansion and Focused Gag Fixes

**Rationale:** Spam reduction is a high-value user goal, but gag behavior is timing-sensitive and can hide safety signal. Fixture evidence must come before timer/merge changes.

**Delivers:** Replay fixtures from live logs for own attack plus battlerage, mob damage plus health loss, kill/XP ordering, crit tiers, shield/no-shield, warning/failure passthrough, pet/follow-through lines, and unusual parse cases; narrow summary fixes after fixtures pass.

**Addresses:** Compact combat summaries, spam reduction, stats attribution, warning passthrough.

**Avoids:** Blanket gagging, clean-looking but unsafe output, hidden failures, wrong target merges, and kill summaries before attack summaries.

**Research flag:** Needs phase research only to collect and classify live combat logs for missing classes/line shapes. Official docs are not enough for combat prose.

### Phase 6: Docs, Help, and Live Release Verification

**Rationale:** End with operator coherence and release validation once behavior is stable. Documentation should reflect behavior changes, not drive broad churn.

**Delivers:** README/help/UIDESIGN updates only for changed command surfaces, compact toggle/status output checks, Muddler build, Busted-in-Mudlet run, and live checklist for GMCP reconnect, room/target, gold/pack, diag, one queued interrupt, walk, and gag output.

**Addresses:** Docs/help coherence, operator clarity, final release confidence.

**Avoids:** User-facing docs drifting from shipped command behavior and release candidates that pass CI but fail live Mudlet timing.

**Research flag:** Standard patterns; live validation required, but no broad research phase needed.

### Phase Ordering Rationale

- Release gates and state contracts come first because they reduce risk for every later edit.
- State ownership precedes autowalk because walker correctness depends on canonical room, target, gold, diag, flee, and walk domains.
- Queue/interrupt/gold/autowalk belong together because their failures are timing and command-channel interleavings.
- Command validation is isolated as a trust-boundary phase so it can be enforced consistently before any future command expansion.
- Gag summary work is intentionally later than core safety state because compact output must never hide safety failures.
- Docs/help and live release verification should close the milestone after behavior stabilizes.

### Research Flags

Phases likely needing deeper research during planning:

- **Phase 2:** live GMCP reconnect, missing `gmcp.IRE`, and game states with intentionally hidden names/targets.
- **Phase 3:** demonnicAutoWalker event/API assumptions if adapter behavior or install pinning changes.
- **Phase 4:** party whitelist-share trust model and any third-party package pinning/checksum policy.
- **Phase 5:** live combat-log collection and classification for gag fixtures.

Phases with standard patterns where research can usually be skipped:

- **Phase 1:** version sync, JSON checks, manifest parity, and state contract tests are repo-local.
- **Phase 6:** docs/help coherence and release checklist execution are standard local validation work.

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | Repo-observed stack is clear: Mudlet Lua 5.1, Muddler, Mudlet DB, GMCP, Busted-in-Mudlet CI, optional demonnicAutoWalker. External API freshness is MEDIUM. |
| Features | HIGH | Based on README, DESIGN, PROJECT, codebase maps, tests, and current milestone priorities. External ecosystem comparisons are MEDIUM. |
| Architecture | HIGH | Current architecture and state drift are documented by local maps and source reads; Mudlet/GMCP runtime constraints are MEDIUM externally. |
| Pitfalls | HIGH | Major risks are evidenced by local code/test gaps and repeated across stack, feature, architecture, and pitfalls research. |

**Overall confidence:** HIGH for roadmap direction; MEDIUM for exact live Achaea text and current external API behavior.

### Gaps to Address

- **Live combat prose:** Official docs do not cover Achaea combat output. Use real logs and replay fixtures before gag changes.
- **GMCP edge cases:** Reconnect, missing modules, partial updates, and hidden/fogged state need live validation.
- **demonnicAutoWalker contract:** Local adapter tests should verify current events and install/status behavior before changing walker assumptions.
- **Command validation policy:** Define conservative accepted forms for separators, directions, pack/container, leader names, pull targets, and party-share packets.
- **CI reproducibility:** Decide whether to pin Muddler/test-in-Mudlet actions and external assets before release candidates.
- **Whitelist-share trust:** Decide whether trusted sender means configured assist leader, explicit allowlist, or both.

## Sources

### Primary Local Sources

- `.planning/research/STACK.md` - stack, runtime, build, test, packaging, and release gate recommendations.
- `.planning/research/FEATURES.md` - table stakes, active hardening features, differentiators, deferred work, and anti-features.
- `.planning/research/ARCHITECTURE.md` - component boundaries, data flow, state ownership, integration points, and build order.
- `.planning/research/PITFALLS.md` - critical/moderate/minor pitfalls and phase-specific warnings.
- `.planning/PROJECT.md` - current milestone, validated requirements, active requirements, constraints, and out-of-scope boundaries.
- `README.md`, `DESIGN.md`, `CODEX.md` - shipped command surface, product intent, repo workflow, and current hardening context.

### External Sources Cited By Research

- Mudlet Advanced Lua: https://wiki.mudlet.org/w/Manual:Advanced_Lua
- Mudlet Networking Functions / `sendGMCP`: https://wiki.mudlet.org/w/Manual:Networking_Functions
- Mudlet Event Engine: https://wiki.mudlet.org/w/Manual:Event_Engine
- Mudlet Object Functions / `tempTimer`: https://wiki.mudlet.org/w/Manual:Mudlet_Object_Functions
- Mudlet Database Functions: https://wiki.mudlet.org/w/Manual:Database_Functions
- Mudlet Package Manager: https://wiki.mudlet.org/w/Manual:Package_Manager
- Mudlet Supported Protocols: https://wiki.mudlet.org/w/Manual%3ASupported_Protocols
- Mudlet Trigger Engine: https://wiki.mudlet.org/w/Manual:Trigger_Engine
- Mudlet scripting/gagging behavior: https://wiki.mudlet.org/w/manual%3Ascripting
- Mudlet `send()` behavior: https://wiki.mudlet.org/w/Manual%3ABasic_Essentials
- Mudlet current release/download line: https://www.mudlet.org/download/
- Iron Realms Nexus GMCP docs: https://nexus.ironrealms.com/GMCP
- Achaea GMCP specification PDF: https://www.achaea.com/local/Achaea_GMCP_Spec_20140311.pdf
- Achaea automation help 15.8: https://www.achaea.com/game-help/?what=triggers-automation-and-auto-auto-rat-auto-fish-etc
- Achaea Hunting wiki: https://wiki.achaea.com/Hunting
- Achaea fog/meta update: https://www.achaea.com/2026/06/05/some-meta-adjustments
- demonnic/muddler: https://github.com/demonnic/muddler
- Muddler usage docs: https://raw.githubusercontent.com/wiki/demonnic/muddler/Usage.md
- Muddler scripts docs: https://raw.githubusercontent.com/wiki/demonnic/muddler/Scripts.md
- Muddler aliases docs: https://raw.githubusercontent.com/wiki/demonnic/muddler/Aliases.md
- Muddler triggers docs: https://raw.githubusercontent.com/wiki/demonnic/muddler/Triggers.md
- Muddler CI docs: https://raw.githubusercontent.com/wiki/demonnic/muddler/CI.md
- build-with-muddler action docs: https://raw.githubusercontent.com/demonnic/build-with-muddler/main/README.md
- test-in-mudlet docs: https://github.com/demonnic/test-in-mudlet
- test-in-mudlet action docs: https://raw.githubusercontent.com/demonnic/test-in-mudlet/main/README.md
- Busted docs: https://lunarmodules.github.io/busted/
- demonnicAutoWalker docs: https://github.com/demonnic/demonnicAutoWalker
- demonnicAutoWalker README: https://raw.githubusercontent.com/demonnic/demonnicAutoWalker/master/README.md
- AchaeaBashingScript/Bashing comparator: https://github.com/AchaeaBashingScript/Bashing

---
*Research completed: 2026-07-09*
*Ready for roadmap: yes*
