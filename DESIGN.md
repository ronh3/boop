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
- Start every Mudlet profile session in whitelist targeting mode; targeting-mode changes are session-local so a previously broad mode cannot carry into a new login.
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
- `whitelist_tags` with `area`, `pos`, `tag`.
- `blacklist` with `area`, `pos`, `name`, `ignore`.
- `stats` for lifetime totals.

## Targeting Modes
- `manual` (no auto retarget; the global blacklist still overrides it)
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
- Targeting uses GMCP `Char.Items.*` data and sends `settarget <id>` as the only outbound targeting command. Selection compares boop's local target with `IRE.Target.Info` so a stale gameside target is resynchronized even when boop's local ID has not changed.
- Denizen filtering: attrib includes `m` and excludes `x` and `d`.
- `boop ih` re-renders Info-Here lines and adds clickable whitelist/blacklist buttons for denizens.
- `boop`, `boop control`, `boop config`, `boop party`, and `boop stats` are now distinct operator surfaces rather than one large menu tree.
- `boop config` renders a clickable configuration hub with subsection dashboards for combat, targeting, loot, and diagnostics, plus direct routes back to party, roster, theme, control, stats, and mode surfaces.
- `boop help` is now a workflow-first help surface, not a flat command index: common goals lead to topic pages with first steps, common commands, advanced commands, and notes. Loot/gold/import has its own normal workflow topic rather than being buried under diagnostics.
- `boop config` and `boop help` use a shared sectioned row layout (`HEADER > section`, divider, aligned `[ value ]` action buttons).
- `boop whitelist` and `boop blacklist` render clickable list managers (`up`/`down`/`remove`).
- `boop whitelist browse [tag]` browses area-level whitelist entries with optional tag filter.
- `boop whitelist share [area]` emits structured party-chat packets for one area's ordered whitelist; incoming shares stay pending until explicitly applied as `merge`, `merge-reorder`, `overwrite`, or `reject`.
- Whitelist areas support multi-tag metadata via `boop whitelist tag add/remove`, with `boop whitelist tag list` summary and per-area `boop whitelist tags <area>`.
- Gold is normally a get-confirm-put pipeline: pickup is queued independently from attacks, and confirmed inventory ownership starts inventory-owned packing through `put sovereigns in <container>`.
- Achaea sovereign lines ending with `flying into your hands before they can reach the ground.` bypass room pickup and enter the same inventory-owned packing stage without issuing `get sovereigns`.
- `boop pack <container>` configures the optional container consumed by the inventory-owned packing stage.
- `boop import foxhunt [merge|overwrite|dryrun]` imports area list data from Foxhunt's `hunting` DB into boop lists.
- Gold get/put tracking listens for success/failure lines, including Achaea's `pick up`, `scoop up`, and direct-to-hands pickup confirmations, and performs bounded retries before warning.
- Gold queue state is now guarded by a short stale-pending timeout; if get/put success/failure triggers are missed, boop warns, clears stale pending state, and resumes.
- `boop prequeue` and `boop lead` make prequeue behavior explicit and independent from `useQueueing`.
- A queued standard always dispatches the fixed alias through `queue addclearfull freestand BOOP_ATTACK`, making it a whole balance/equilibrium queue replacement. Its exact owner/generation remains pending from the observed ADDCLEARFULL baseline through the prompt after matching success/denial evidence; candidate-free readiness opens one generation-owned grace and recovery budget.
- Nonterminal queued-standard authority serializes target selection, alias mutation, subsequent standard work, Rage, and direct dispatch. Direct standard-plus-Rage remains compatible when no queued generation owns the barrier.
- Target departure and movement quarantine the old fixed alias without native queue mutation; only old result or grace terminal evidence releases it for replacement. Explicit blacklist/forbidden-target revocation sends one traced `clearqueue all` even when current-room presence is unknown, because preserving that alias could execute prohibited work.
- If a standard attack is already prequeued and the current target gains shield before it fires, boop rebuilds `BOOP_ATTACK` immediately to the current shieldbreak standard when appropriate. Staging or rebuilding that queued alias does not count as executing the shieldbreak, so a rebound cannot downgrade the next prequeue back to normal damage before shield-down evidence arrives.
- Shield mode is session-only and applies uniformly to every class/spec profile: `break` lets tracked shields select standard or rage shield responses, while `bypass` retains shield state and keeps normal standard/rage selection. Bypass changes planning only and does not grant shield penetration. Reload and reconnect reset the mode to `break`; the legacy `breakShields` boolean remains only as a command/config compatibility surface.
- Magi Staffcast damage can land while a target's magical shield remains active, so Staffcast output is not shield-down evidence.
- Runtime safety uses owner-keyed operation locks only for asynchronous interrupt, pull, and gold work, so each operation releases only itself.
- Lifecycle, room readiness, target eligibility, attack-profile readiness, and walker state are computed from canonical state. A missing or unusable attack profile is reported without creating an operation lock, and computed state never depends on a later callback releasing a pseudo-owner.
- Movement, accepted room contents, and blacklist edits reconcile stale target intent without stopping an active walker. An active pull preserves its target and queued intent until return or termination.
- `diag` sends `clearqueue all`, replaces the full balance/equilibrium queue with `diagnose`, and temporarily blocks attacks until a `Char.Afflictions.List` snapshot plus prompt; visible diagnose result lines remain fallback evidence.
- `diag` includes a timeout fallback, and unresolved evidence from a timed-out dispatch is bounded to that dispatch instead of consuming every later diagnose result.
- Two `You are confused as to the effects of the venom.` observations force the same diagnose interrupt. Successful diagnose completion resets the capped counter; timeout leaves it armed for a later retry.
- `leap <direction>` explicitly clears every server queue before queueing the leap and holds combat/queue dispatch until changed `Room.Info` confirms movement. The exact observed owned leap wire opens a room/generation-bound denial window: the hindered-legs line immediately terminalizes that leap as `command_failed`, while contaminated, stale, or otherwise ambiguous denial remains diagnostic and retains the timeout fallback.
- `pull <mobname> <direction>` uses an operation lock without changing saved enabled configuration, sends the configured separator-delimited move/ready-damage-rage/leap-back chain, and releases after origin-room confirmation or a timeout while already at origin; timeout away retains the hold until return.
- Interrupt, pull, and gold operations plus room and walk transitions are generation-owned; callbacks from superseded generations cannot mutate current state.
- An exhausted interrupt-displaced pack replay releases every operation/blocker/walk owner into a nonblocking provenance quarantine. Ready/result prompt closure, one bounded grace, and a causally newer complete inventory generation may qualify it, but only a later explicit safe gold opportunity can consume eligibility and issue at most one fresh put after all standard/combat/queue/gold/walk gates are rechecked.
- `boop get/set` provides scriptable config access, and `boop trace` exposes a rolling decision/command buffer.
- `boop trace` now includes compact GMCP room/info/item/gold-related room events for debugging movement and loot timing.
- Fenced `Char.Items.List` responses are traced before settlement with response location, transition status, observed halves, and the still-awaited half, allowing room-entry latency to be attributed without weakening room authority.
- Exact abbreviated or full outbound direction commands arm a short-lived movement intent against either settled origin evidence or its exact in-flight response fence. A changed post-fence duplicate room list that arrives before moved `Room.Info` can become a combat-only provisional hint after the destination is confirmed; authoritative post-move evidence remains mandatory for gold and walker settlement, and unchanged, orphan-first, expired, overlapping, or unconfirmed lists stay fail closed.
- A completed room application retains its generation-owned zero-delay fallback, but a normal tick may claim the exact pending application first. Both paths use the same application, room, and observation-generation validator; moved `Room.Info` still invalidates the application before any stale consumer can run.
- Trace collection and live streaming are independent: persisted `traceEnabled` remains the sole gate before entries are appended, while runtime-only `boop.state.trace.live` resets to `false` on package/session initialization and is never saved.
- When collection and live streaming are both enabled, every accepted entry is timestamped, appended, and trimmed to the 100-entry bound. Operation enter/exit and exact interrupt success/failure/timeout terminals are then emitted live exactly once per accepted producer event through non-tracing output, before prompt gag summaries flush.
- Retained trace remains forensic and count-preserving. Live admission alone collapses an unchanged expected target-removal, `room_partial`, or no-target fingerprint after its first rendering; changed routine state, lifecycle terminals, denial, timeout, and authority failures remain live.
- Live state does not alter retained-buffer behavior: `boop trace show [n]` continues to read collected entries, and `boop trace clear` empties the buffer without changing whether live streaming is enabled.
- `boop gag mobs` condenses known mob attack flavor lines plus following `Health lost` lines into `Mob: Damage -> You (#### damagetype)` summaries with their own configurable gag palette.
- Two-handed standards prepend `battlefury focus speed/` when `Focus` is known (Weaponmastery), excluding shieldbreaker paths.
- Unnamable standards prepend `hound maul &tar/` and Infernal standards prepend `hyena maul &tar/` when the class-specific `Maul` skill is known and ready. Queued intent does not consume readiness before Achaea confirms use or rejection through the existing trigger lines.
- Dragon profiles include `blast &tar` as a standard damage option exposed through `boop prefer`; rage and pull-rage dragon actions are not blast-prefixed.
- Infernal profiles include `quash &tar/arc` as the `quarc` standard damage option exposed through `boop prefer`.
- The Magi profile keeps Horripilation as its default staffcast and exposes Scintilla and Dissolution as standard damage preferences; Dissolution availability follows the Artificing `Staff` ability.
- Saved standard preferences remain class/spec scoped. A session-only preference layer can override damage or shield selection without writing to config storage; clearing it reveals the saved value, and reload/reconnect clears all temporary overrides.
- Standard attacks and rage actions are independent; standard builds rage and there is no mode toggle.
- `ragePoolThreshold` is a persisted 0-100 post-spend reserve for ordinary rage actions. It composes with existing rage modes and pull reserve, while rage shieldbreaks and Triumph free-rage actions bypass the reserve.
- A complete uncontaminated final Rage wire gives generic cooldown/insufficient-rage output exact causal authority. Cooldown closes a global Battlerage gate independently from per-ability timers; only exact Available-list recovery or reconnect reset reopens it, and ambiguous output is diagnostic-only.
- Triumph's free-rage line creates one replaceable generation-owned credit consumed by hybrid rage selection. It ignores current rage amount but still respects cooldown and conditional state, and matching use, expiry, causal insufficient-rage output, timeout, movement, replacement, or reconnect terminalizes it exactly once.
- Skill gating issues `Char.Skills.Get` requests per skill (group-aware).
- `boop preset solo|party|leader|leader-call` applies recommended baseline config bundles; `leader-call` requires an assist leader to already be configured.
- Party-size is intentionally session-local and defaults to `1` on load; it is used by stats/mob XP telemetry and is not persisted.
- External autowalking is integrated through `demonnicAutoWalker` as a separate package; installation is explicit and runtime paths never install or update it.
- Movement settlement is shared room observation: boop requires current `Room.Info` plus a complete current room item list, while prompts and timers cannot mark a room settled.
- Walker shutdown follows owned stop / attached detach: stop ends a boop-owned run but only detaches boop from an externally owned run.

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
- The next major phase is release hardening and 1.0 polish, not broad new feature development.
