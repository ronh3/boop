# boop Hunter

## What This Is

boop Hunter is an existing standalone Mudlet package for Achaea hunting and bashing. It automates target selection, standard attacks, battlerage use, basic safety, loot handling, party coordination, stats, and operator-facing dashboards while staying independent of large external curing or hunting frameworks.

The project is no longer a greenfield build. The current work is pre-1.0 release hardening: preserve current behavior, improve reliability and operator clarity, fix live regressions, and reduce Achaea combat scroll through compact summaries instead of simply hiding useful information.

## Core Value

boop must make Achaea hunting safer, clearer, and less noisy without taking control away from the operator.

## Requirements

### Validated

- Existing targeting modes select denizens from GMCP room item data and use target IDs for `settarget`.
- Existing whitelist, blacklist, global blacklist, whitelist tags, and priority ordering are persisted through Mudlet DB.
- Existing class attack profiles choose standard and rage actions with skill gating, shield handling, openers, preferences, and battlerage modes.
- Existing runtime coordinator, prompt handling, GMCP handlers, and trigger adapters drive hunting ticks from room, target, vitals, prompt, and combat text events.
- Existing safety support includes auto-flee threshold handling, interrupt holds, `diag`, queue interruption commands, and pull flow recovery.
- Existing loot support includes gold pickup, optional pack/stash behavior, retry tracking, and warnings on failed pickup or stash attempts.
- Existing party support includes solo, assist, leader, and leader-call modes; target calls; affliction calls; roster and combo inference; and whitelist sharing.
- Existing UI surfaces include `boop`, `boop control`, `boop config`, `boop party`, `boop stats`, and workflow-first `boop help`.
- Existing gag support condenses self, other-player, and mob combat lines into readable summaries and feeds stats hooks.
- Existing stats support tracks session, login, trip, lifetime, area, mob, target, ability, crit, and rage metrics.
- Existing test coverage runs Busted inside a real Mudlet profile in CI and covers core domains, UI, DB, targeting, attacks, rage, gags, stats, and regressions.

### Active

- [ ] Stabilize pre-1.0 runtime state ownership so room, pull, walk, gold, diag, flee, and targeting paths use the owned state domains consistently.
- [ ] Improve compact combat summaries so high-volume Achaea output is condensed into clear, information-rich lines without hiding important warnings, failures, or unusual events.
- [ ] Harden gag line coverage with focused regression fixtures from live combat logs before changing timing or merge behavior.
- [ ] Strengthen release confidence with CI gates for version synchronization, manifest parity, and high-risk behavior paths.
- [ ] Fill the autowalk regression gap around blockers, room-settled behavior, external walker events, and gold/diag/flee interactions.
- [ ] Keep operator workflows coherent across home, control, config, party, stats, help, and gag/color surfaces.
- [ ] Add shared validation for user-controlled command fragments before persisted values can be sent as game commands.
- [ ] Maintain user-facing docs, command help, and dashboard entry points in sync with every command-surface change.

### Out of Scope

- Full rewrite or architecture churn for its own sake - the package is already mostly built and in release-hardening mode.
- PvP combat automation - boop is an Achaea hunting/bashing system, not an advanced combat automation suite.
- Absorbing `demonnicAutoWalker` into boop - boop should integrate with the external walker rather than become the walker.
- Dependence on SVO, Wundersys, or other large external automation frameworks - boop should remain self-contained apart from explicit optional integrations.
- Large static area databases without validation - list data should remain DB-backed and operator-maintained/imported.
- Broad feature expansion before 1.0 - new capabilities should wait unless they close a real usage, safety, or clarity gap.

## Context

- Source of truth for package content is under `src/`; built artifacts are generated and should not be edited.
- Package metadata lives in `mfile`, and runtime version is declared in `src/scripts/boop/boop_init.lua`.
- Current repository workflow is documented in `AGENTS.md` and `CODEX.md`; both require synchronized version fields on every commit and push.
- Product behavior and command surface are documented in `README.md`, `DESIGN.md`, and `UIDESIGN.md`.
- GSD codebase mapping exists under `.planning/codebase/` and should be read before planning hardening work.
- The package runs in Mudlet against Achaea, relies heavily on GMCP and IRE modules, and uses Mudlet DB for persistent config and hunting data.
- CI builds the Muddler package and runs Busted specs inside a real Mudlet AppImage profile.
- The highest-value known concerns are state-domain drift, autowalk coverage gaps, gag summarization fragility, manifest parity risk, and missing automated version-sync enforcement.

## Constraints

- **Runtime:** Mudlet Lua 5.1-compatible code and Achaea GMCP behavior constrain implementation choices.
- **Build:** Muddler manifest load order is runtime-sensitive, especially `src/scripts/boop/scripts.json`.
- **Source boundary:** Work only under `src/` for package content; never edit generated package artifacts.
- **Versioning:** Every commit and push must keep `mfile.version`, `mfile.title`, `src/scripts/boop/boop_init.lua` `boop.version`, and the `CODEX.md` checkpoint synchronized.
- **Operator UX:** Preserve the current streamlined UI direction: dashboard-first, workflow-first help, aligned rows, clear `[OK]`, `[INFO]`, `[WARN]`, and `[ERR]` feedback.
- **Spam reduction:** Prefer compact summaries and configurable signal over blanket gagging that hides important game state.
- **Dependencies:** Keep `demonnicAutoWalker` as an optional external integration.
- **Testing:** Risky behavior changes need focused Busted coverage, and live Mudlet validation remains required for GMCP, prompt, gag, queue, walker, and game-text behavior.

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Treat the current project as brownfield pre-1.0 hardening | The system is already mostly built and needs reliability, clarity, and release confidence more than broad new scope. | - Pending |
| Reduce scroll through compact summaries first | Operators still need useful hunting signal; summaries preserve information better than aggressive hiding. | - Pending |
| Keep boop self-contained | Existing design explicitly avoids relying on SVO, Wundersys, or large external systems. | - Pending |
| Keep `demonnicAutoWalker` external | Walking is a separate domain and current boop behavior is integration-focused. | - Pending |
| Use GSD `.planning/` artifacts for structured future work | Existing `AGENTS.md`, `CODEX.md`, `README.md`, and `UIDESIGN.md` help Codex, but GSD adds durable requirements, roadmap, state, and phase artifacts. | - Pending |

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `$gsd-transition`):
1. Requirements invalidated? Move to Out of Scope with reason.
2. Requirements validated? Move to Validated with phase reference.
3. New requirements emerged? Add to Active.
4. Decisions to log? Add to Key Decisions.
5. "What This Is" still accurate? Update if drifted.

**After each milestone** (via `$gsd-complete-milestone`):
1. Full review of all sections.
2. Core Value check - still the right priority?
3. Audit Out of Scope - reasons still valid?
4. Update Context with current state.

---
*Last updated: 2026-07-09 after initialization*
