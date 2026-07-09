# Domain Pitfalls

**Domain:** Mudlet/Achaea hunting package release hardening  
**Project:** boop Hunter  
**Researched:** 2026-07-09  
**Overall confidence:** HIGH for local codebase risks; MEDIUM for external Mudlet/Muddler/GMCP constraints verified through web sources.

## Phase Mapping Used

| Phase | Focus |
|-------|-------|
| Phase 1 | Runtime GMCP state ownership, pull/flee room transitions, and safety baseline |
| Phase 2 | Compact combat summaries, gag fixtures, and scroll reduction without hiding signal |
| Phase 3 | Queue, interrupt, gold, and autowalk integration hardening |
| Phase 4 | Command-fragment validation and party-share trust hardening |
| Phase 5 | CI, manifest parity, version sync, and release packaging gates |

## Critical Pitfalls

### Pitfall 1: Split GMCP Room State Breaks Pull, Flee, and Walk

**Confidence:** HIGH  
**What goes wrong:** GMCP room transitions update or read the wrong state domain. Current source still has `boop.onRoomInfo()` writing flat keys such as `boop.state.room`, `lastRoom`, `lastRoomDir`, and `pullState`, while current runtime defaults and command handlers use `boop.state.targeting.*` and `boop.state.combat.pullState`. `boop.walk.blockedReason()` also checks flat blocker fields instead of `boop.state.diag`, `boop.state.combat`, `boop.state.gold`, and `boop.state.targeting`.

**Why it happens:** The package is mid-hardening after a state-domain refactor. GMCP event handlers, UI command handlers, safety, and walker code were not all moved to the same canonical state paths.

**Consequences:** Pull may never observe the "away" or "returned to origin" transition. `bflee`/auto-flee may lose the return direction. Autowalk may advance while a target, gold pickup, diagnose hold, or flee is still active. Stats and trace can disagree with dashboard state.

**Warning signs:** `pull` times out even after returning to origin; `boop trace show` logs room changes but `boop status` or dashboards show stale room/target state; `bflee` reports no flee direction after a recent move; `boop walk status` says ready while a target/gold/diag/flee state is visibly active.

**Prevention strategy:** Make `boop.state.targeting.room/lastRoom/lastRoomDir/movedRooms` and `boop.state.combat.pullState` the only room/pull state. Update `boop.walk` to read `boop.state.walk.*` for walker flags and cross-domain blockers from their owning domains. Add regression tests that fail if `boop.onRoomInfo()` creates or relies on flat room/pull keys.

**Roadmap phase mapping:** Phase 1 must land before changing gag timing or autowalk behavior. Phase 3 should not start walker changes until this state ownership path is fixed.

### Pitfall 2: Compact Gagging Hides Real Combat Signal

**Confidence:** HIGH  
**What goes wrong:** New gag summaries delete or merge the wrong lines, or summarize too aggressively. Attack, damage, crit, slain, XP, balance, and mob damage lines are correlated through pending state and short timers; unseen Achaea line variants can leave summaries incomplete or hide important warnings.

**Why it happens:** Mudlet gagging operates on the active output buffer line, and timer callbacks do not block later script execution. boop has broad gag coverage across many class folders, so small changes to pending/flush behavior can affect unrelated classes.

**Consequences:** Operators lose health-loss, failure, shield, rage, or "something unusual happened" signal while the UI looks quieter. Stats attribution can drift when damage or kill lines are folded into the wrong summary. The worst failure mode is "clean output" that is less safe than spam.

**Warning signs:** Unpaired `Damage dealt`, `Health lost`, balance, warning, or failure lines disappear; kill summaries appear before attack summaries; battlerage and standard damage from different targets are merged; players report less scroll but worse situational awareness.

**Prevention strategy:** Treat every new live line shape as a replay fixture in `tests/boop_gag_spec.lua` before changing timers or merge logic. Default unknown lines to visible. Keep kill, health-loss, flee, queue failure, gold failure, shield/no-shield, and diagnose/failure signals out of blanket gag paths. Validate with live combat logs, not only handcrafted single-line tests.

**Roadmap phase mapping:** Phase 2. Do not broaden gag coverage until fixture coverage for the target classes and mob attack lines exists.

### Pitfall 3: Queue, Prequeue, Interrupt, Gold, and Pull Timers Race Each Other

**Confidence:** HIGH  
**What goes wrong:** Timed queue work resumes attacks too early or too late. `diag`, `matic`, `catarin`, `fly`, `ts`, `leap`, prequeue, gold pickup, and pull all use queue commands and timers. A stale `BOOP_ATTACK`, pending gold prefix, or interrupt hold can overlap with room changes and target changes.

**Why it happens:** Mudlet timers schedule future callbacks without blocking subsequent Lua execution. boop queues standard actions through a cached alias, prepends gold pickup to queued attacks, and separately uses prompt/timeout paths to release holds.

**Consequences:** An attack fires while the operator expected `diag`/`fly`/`leap`/pull safety. Gold commands run after leaving the room. Prequeued attacks hit stale target IDs. Pull resumes or remains paused incorrectly. Queue clearing may remove an operator command or preserve an unsafe old alias.

**Warning signs:** Manual interrupt is followed immediately by an attack; trace shows `prequeue sent standard` during a diag hold; `setalias BOOP_ATTACK` still references a previous target; gold `get`/`put` retries fire in the wrong room; pull timeout is the normal completion path rather than an exception.

**Prevention strategy:** Centralize queue state transitions and make interrupts cancel prequeue, mark alias dirty, and block combat until the exact prompt or timeout condition is satisfied. Add tests for interleavings: interrupt during gold pending, room change during prequeue, target removal after alias set, pull timeout away vs origin, and gold success/failure followed by walker advance.

**Roadmap phase mapping:** Phase 3, with Phase 1 state fixes as a prerequisite.

### Pitfall 4: Autowalk Advances on a False "Room Clear"

**Confidence:** HIGH  
**What goes wrong:** boop raises `demonwalker.move` when the room is not actually safe to leave, or never raises it after the room clears. Current `tests/boop_walk_spec.lua` is disabled, and `boop_walk.lua` still checks several stale flat blocker names.

**Why it happens:** demonnicAutoWalker is event-driven: consumers listen for `demonwalker.arrived`, do their room work, then raise `demonwalker.move`. boop must bridge that contract to GMCP room/item updates, target selection, gold handling, diag/flee state, and leader target calls.

**Consequences:** The character can walk away mid-combat, mid-loot, during flee recovery, or during a manual interrupt. The opposite failure is a stalled walk that looks idle even though the room is clear.

**Warning signs:** `boop walk status` shows ready while `boop.state.targeting.currentTargetId` is set; walker advances before `gmcp.Char.Items.List` arrives; repeated `move already queued`; rooms stall after successful gold pickup; leader-call mode walks while waiting for a party target.

**Prevention strategy:** Put walker runtime flags under `boop.state.walk.*`; make blocker checks read canonical domains; add active tests for `demonwalker.arrived`, `demonwalker.finished`, `demonwalker.move`, room-settled fallback, target-present, diag, flee, gold pending, and leader-call blockers. Keep demonnicAutoWalker external; do not absorb route planning into boop.

**Roadmap phase mapping:** Phase 3. This should be a focused integration phase, not a general walker rewrite.

### Pitfall 5: Safety Behavior Fails Open or Uses a Bad Escape Path

**Confidence:** HIGH  
**What goes wrong:** Auto-flee disables boop but sends no useful escape command, sends the wrong direction, or leaves a queued attack behind. Gagging or compact summaries can also hide the warnings that explain why safety paused or failed.

**Why it happens:** Flee direction depends on accurate room transition state. Runtime safety runs before combat planning, but queued aliases, prequeue timers, gold handling, and walker state are separate side-effect paths.

**Consequences:** The operator believes boop has gone safe while an old queued attack, walker move, or stale alias still executes. At low HP, a missing `lastRoomDir` can turn auto-flee into "boop disabled, no movement".

**Warning signs:** `[WARN] No flee direction set.` after movement; low HP disables boop but no `wake/wake/apply mending to legs/stand/<dir>` is sent; `queue addclearfull freestand BOOP_ATTACK` appears after a flee; compact output hides flee or queue warnings.

**Prevention strategy:** Treat flee as a fail-closed transition: cancel prequeue, dirty the queue alias, clear gold intent, stop IH/gag pending state, stop/hold walker, and send escape only when the canonical last-room direction is known. Add tests for flee while prequeue/gold/walk/diag are active and live validation for `bflee` after real GMCP room moves.

**Roadmap phase mapping:** Phase 1 for room-direction correctness; Phase 3 for queue/walker interactions.

## Moderate Pitfalls

### Pitfall 1: GMCP Availability and Ordering Are Assumed Too Strongly

**Confidence:** MEDIUM-HIGH  
**What goes wrong:** boop assumes GMCP modules, fields, or ordering are present when they are temporarily missing after reconnect, package load, server compression quirks, or game-side changes.

**Prevention strategy:** Reannounce GMCP support on reconnect, keep nil guards, and distinguish "unknown" from "empty". Do not attack or walk based only on a room number without fresh `Char.Items.List` or equivalent room-settled evidence. Keep trace lines for GMCP room/item/target/skill events.

**Warning signs:** `gmcp.IRE` is absent after reconnect; denizens stay empty until manual `look`/`ih`; class/spec/rage unknown after login; skill gating falls back despite known skills; target ID and room item list disagree.

**Roadmap phase mapping:** Phase 1 and live validation at the end of every runtime-touching phase.

### Pitfall 2: User-Controlled Command Fragments Become Game Commands

**Confidence:** HIGH  
**What goes wrong:** Operator-entered values such as `goldPack`, `assistLeader`, `leap` direction, game separator, pull mob names, or future config strings are concatenated into `send()` commands. Pull rejects newlines and the configured separator in the mob name, but validation is not centralized across all command fragments.

**Prevention strategy:** Add one shared command-fragment validator before values are persisted or sent. Validate container IDs/names, leader names, directions, separators, and any string that can cross into `send()`, `setalias`, `queue`, `pt`, or rich link callbacks. Reject newlines, carriage returns, active command separators, slash separators where relevant, and empty/ambiguous directions.

**Warning signs:** A `boop pack` value produces multiple commands; assist mode prefixes an unexpected command chain; `boop separator` accepts text that makes pull parsing ambiguous; tests only cover pull mob injection and not pack/leader/direction/separator injection.

**Roadmap phase mapping:** Phase 4, but add validators before any new command-surface expansion.

### Pitfall 3: Party Whitelist Share Trust Is Too Permissive

**Confidence:** HIGH  
**What goes wrong:** When no assist leader is configured, incoming whitelist-share packets from any non-self party speaker are trusted into pending state. The operator must still apply them, but `overwrite` can replace an area's whitelist. Incoming packet state also lacks TTL/count caps.

**Prevention strategy:** Require an explicit trusted sender for whitelist shares, or at least warn loudly when accepting a share without a configured leader. Cap packet count, entry count, token lifetime, and total pending share memory. Show sender, area, count, and mode risk before apply; make `merge` the safest path and keep `overwrite` visibly destructive.

**Warning signs:** `boop whitelist receive` shows a pending share from an unexpected party member; pending shares survive long after the party context changed; malformed packet streams accumulate in `incomingWhitelistShares`.

**Roadmap phase mapping:** Phase 4. This can follow command-fragment validation because both are trust-boundary work.

### Pitfall 4: CI Passes While Release Metadata or Manifest Contents Are Wrong

**Confidence:** HIGH  
**What goes wrong:** Source tests pass but the built `.mpackage` has missing aliases/triggers/scripts, wrong load order, or mismatched version fields. Current CI reads `mfile` package/version, but local policy also requires `mfile.title` and `boop.version` to match. Manifest parity is not broadly enforced.

**Prevention strategy:** Add CI checks for `mfile.version`, `mfile.title`, and `src/scripts/boop/boop_init.lua` `boop.version`. Add manifest parity tests that every Lua file under `src/scripts`, `src/aliases`, and `src/triggers` is reachable from the appropriate JSON manifest and every manifest script entry resolves to a file. Keep `src/scripts/boop/scripts.json` load-order reviewed and never auto-sort it.

**Warning signs:** Runtime `boop version` differs from artifact name; a new trigger file exists but is absent after package import; Muddler build succeeds but a command/trigger is missing in Mudlet; tests import source helpers but not the packaged file path.

**Roadmap phase mapping:** Phase 5. Do this before tagging or calling the branch release-ready.

### Pitfall 5: CI Supply Chain Drift Changes Build/Test Behavior

**Confidence:** HIGH  
**What goes wrong:** The workflow uses broad `write-all` permissions, `demonnic/build-with-muddler@main`, a depth-1 clone of `demonnic/test-in-mudlet`, runtime LuaRocks installs, and action versions that can change independently of boop.

**Prevention strategy:** Reduce GitHub Actions permissions to the minimum needed. Pin third-party actions and cloned test assets to immutable SHAs or known release tags. Record the supported Mudlet AppImage version and checksum. Keep artifact upload/comment permissions scoped to PR comment needs.

**Warning signs:** CI fails or passes differently without source changes; Mudlet profile behavior changes after `test-in-mudlet` updates; package output changes after a Muddler action update; PR workflows have write privileges unrelated to artifact/comment tasks.

**Roadmap phase mapping:** Phase 5, ideally before release candidates are cut.

## Minor Pitfalls

### Pitfall 1: Over-Trusting Busted Coverage for Live Achaea Text

**Confidence:** HIGH  
**What goes wrong:** The suite runs inside real Mudlet, which is strong, but most combat text inputs are still curated fixtures. Achaea line variants, prompt timing, mapper events, and party chat shapes can differ during live hunting.

**Prevention strategy:** Keep adding replay-style fixtures from real combat logs and require a short live validation checklist for GMCP room/items, gag summaries, queue interrupts, gold, pull, flee, and walker behavior after each risky phase.

**Warning signs:** CI is green but live hunting leaves visible spam, hides a warning, or fails only after reconnect/package reload.

**Roadmap phase mapping:** Every phase, with the heaviest burden on Phases 2 and 3.

### Pitfall 2: Trace Buffer Is Too Short for Long Reproduction Sessions

**Confidence:** HIGH  
**What goes wrong:** `boop.trace.log()` keeps only the last 100 entries. Long hunting sessions can evict the event that caused a later bad target, queue, or walk decision.

**Prevention strategy:** For hardening, add a configurable trace limit or export command before relying on operator trace logs as primary live evidence. Keep trace compact but include room/item/queue/walker/safety decisions.

**Warning signs:** `boop trace show` starts after the failure cascade rather than before it; users must reproduce immediately instead of filing one long trace.

**Roadmap phase mapping:** Phase 1 or Phase 3 as a small support task.

### Pitfall 3: Mudlet DB Changes Lack an Explicit Migration Ledger

**Confidence:** HIGH  
**What goes wrong:** Older local profiles can have missing or partial sheets. The DB code has guard paths, but new persistent fields or changed row meanings can silently degrade if schema expectations are implicit.

**Prevention strategy:** Avoid schema churn before 1.0 unless it closes a release risk. If schema changes are unavoidable, add schema-version metadata, migration tests, and clear warnings that tell the operator what was repaired.

**Warning signs:** Config/list/stat changes work in fresh CI profiles but fail or warn in an old live profile; import/clear paths depend on optional sheets without migration evidence.

**Roadmap phase mapping:** Phase 5 if release packaging touches persistence; otherwise defer until post-1.0.

## Phase-Specific Warnings

| Phase Topic | Likely Pitfall | Mitigation |
|-------------|----------------|------------|
| Runtime GMCP state | Room, pull, flee, and stats split between flat and owned domains | Convert handlers to canonical domains and add no-flat-state regression tests |
| Compact summaries | Gagging hides warnings or merges unrelated damage | Fixture from live logs first; default unknown lines visible |
| Queue/interruption | Prequeue or stale aliases fire during holds | Centralize hold/cancel/alias-dirty behavior and test interleavings |
| Autowalk | `demonwalker.move` raised before room is actually clear | Implement walker contract tests and canonical blockers |
| Safety | Auto-flee disables boop but sends no escape or leaves queued attack | Fail closed: cancel queue/prequeue/walk, require canonical flee direction |
| Command validation | Persisted values become unintended game command chains | Shared validator for every value crossing into `send()` or queue aliases |
| Party sharing | Untrusted or unbounded whitelist packets reach pending/apply state | Require leader/trusted sender, TTL, packet caps, and explicit destructive-mode UX |
| CI hardening | Green build does not prove release artifact parity | Version sync, manifest parity, pinned dependencies, packaged import tests |
| Release packaging | Load order or missing manifest entry breaks package import | Keep `scripts.json` order intentional and test manifest/file reachability |

## Sources

### Local Evidence

- `.planning/PROJECT.md`
- `.planning/config.json`
- `.planning/codebase/CONCERNS.md`
- `.planning/codebase/TESTING.md`
- `.planning/codebase/INTEGRATIONS.md`
- `.planning/codebase/ARCHITECTURE.md`
- `README.md`
- `DESIGN.md`
- `CODEX.md`
- `src/scripts/boop/boop_events.lua`
- `src/scripts/boop/boop_runtime.lua`
- `src/scripts/boop/boop_walk.lua`
- `src/scripts/boop/boop_ui.lua`
- `src/scripts/boop/boop_util.lua`
- `src/scripts/boop/boop_safety.lua`
- `src/scripts/boop/boop_gag.lua`
- `src/scripts/boop/boop_targets.lua`
- `.github/workflows/main.yml`
- `tests/README.md`
- `tests/boop_pull_spec.lua`
- `tests/boop_gag_spec.lua`
- `tests/boop_interrupt_spec.lua`
- `tests/boop_walk_spec.lua`
- `tests/boop_whitelist_share_spec.lua`

### External Evidence

- Mudlet GMCP and supported protocols: https://wiki.mudlet.org/w/Manual%3ASupported_Protocols
- Mudlet `sendGMCP`: https://wiki.mudlet.org/w/Manual%3ANetworking_Functions
- Mudlet event handlers: https://wiki.mudlet.org/w/Manual%3AMiscellaneous_Functions
- Mudlet scripting and gagging behavior: https://wiki.mudlet.org/w/manual%3Ascripting
- Mudlet `send()` behavior: https://wiki.mudlet.org/w/Manual%3ABasic_Essentials
- Achaea GMCP specification PDF: https://www.achaea.com/local/Achaea_GMCP_Spec_20140311.pdf
- Iron Realms Nexus GMCP docs: https://nexus.ironrealms.com/GMCP
- Muddler usage and mfile docs: https://raw.githubusercontent.com/wiki/demonnic/muddler/Usage.md
- Muddler scripts manifest docs: https://raw.githubusercontent.com/wiki/demonnic/muddler/Scripts.md
- Muddler aliases manifest docs: https://raw.githubusercontent.com/wiki/demonnic/muddler/Aliases.md
- Muddler triggers manifest docs: https://raw.githubusercontent.com/wiki/demonnic/muddler/Triggers.md
- Muddler CI docs: https://raw.githubusercontent.com/wiki/demonnic/muddler/CI.md
- test-in-mudlet docs: https://github.com/demonnic/test-in-mudlet
- demonnicAutoWalker docs: https://github.com/demonnic/demonnicAutoWalker
