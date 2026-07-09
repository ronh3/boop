# Feature Landscape

**Project:** boop Hunter  
**Domain:** Standalone Mudlet package for Achaea hunting/bashing  
**Researched:** 2026-07-09  
**Scope:** Features dimension only, focused on pre-1.0 hardening and combat-scroll reduction  
**Overall confidence:** HIGH for local product state, MEDIUM for external Mudlet/Achaea ecosystem facts

## Executive Take

boop is already past the MVP feature-discovery stage. The expected feature set for a mature Achaea/Mudlet hunting helper is present: GMCP-driven room and target state, DB-backed hunting lists, class attack profiles, battlerage decisions, safety interrupts, loot handling, party coordination, stats, and operator dashboards. The 1.0 work should not add a new major domain. It should make those existing domains predictable under live GMCP, prompt, gag, queue, gold, flee, and walker timing.

For this milestone, "feature work" should mostly mean hardening behavior users already rely on. The highest-value user-facing feature is compact combat summaries that reduce scroll while preserving signal: damage, target, crits, kills, XP/gold, warnings, missed parse cases, and unusual events. The highest-value release feature is confidence: state ownership, regression fixtures, manifest/version gates, and clear diagnostics when Mudlet/Achaea data is missing or delayed.

External research reinforces the current architecture. Current IRE GMCP documentation covers `Char.Items`, `Char.Skills`, `Char.Vitals`, `Room`, `IRE.Display`, and `IRE.Target`, which are exactly the surfaces boop uses. Mudlet's GMCP documentation expects event-driven handlers and `sendGMCP` requests for modules that need explicit requests. Achaea's own automation help creates an important product boundary: boop should remain an attended hunting assistant with explicit operator controls, not a feature set optimized for unattended gold/XP automation.

## Source Basis

| Source | Confidence | Used For |
|--------|------------|----------|
| `.planning/PROJECT.md` | HIGH | Current milestone priorities, validated behavior, active hardening items, out-of-scope boundaries. |
| `README.md` | HIGH | Shipped command surface and user-visible feature behavior. |
| `DESIGN.md` | HIGH | Product intent, architecture intent, non-goals, GMCP/data-model assumptions. |
| `UIDESIGN.md` | HIGH | Expected operator UI behavior and release-phase UX guidance. |
| `.planning/codebase/*.md` | HIGH | Actual implementation structure, concerns, tests, integrations, and gaps. |
| `tests/README.md` | HIGH | Existing automated coverage and missing regression areas. |
| [IRE Nexus GMCP docs](https://nexus.ironrealms.com/GMCP) | MEDIUM | Current GMCP module surface: `Char.Items`, `Char.Skills`, `Char.Vitals`, `Room`, `IRE.Display`, `IRE.Target`, support negotiation. |
| [Mudlet Supported Protocols](https://wiki.mudlet.org/w/Manual%3ASupported_Protocols) | MEDIUM | GMCP event handling and `sendGMCP` usage expectations. |
| [Mudlet Event Engine](https://wiki.mudlet.org/w/Manual%3AEvent_Engine) | MEDIUM | Event-handler registration pattern for protocol and custom events. |
| [Mudlet Package Manager](https://wiki.mudlet.org/w/Manual%3APackage_Manager) and [Muddler](https://github.com/demonnic/muddler) | MEDIUM | Package/build expectations for source-controlled Mudlet package releases. |
| [Achaea Help 15.8](https://www.achaea.com/game-help/?what=triggers-automation-and-auto-auto-rat-auto-fish-etc) | MEDIUM | Automation boundary and anti-feature guidance. |
| [Achaea Hunting wiki](https://wiki.achaea.com/Hunting) | MEDIUM | Domain framing: hunting/bashing is for denizen XP and gold. |
| [Achaea fog update](https://www.achaea.com/2026/06/05/some-meta-adjustments) | MEDIUM | Current reminder that GMCP/name visibility can be intentionally unavailable in some game states. |
| [AchaeaBashingScript/Bashing](https://github.com/AchaeaBashingScript/Bashing) | MEDIUM | Ecosystem comparator for target ordering, battlerage strategies, shield handling, and GMCP/Mudlet expectations. |

## Table Stakes

Features users reasonably expect from an existing Achaea/Mudlet hunting helper. Missing or unreliable behavior here makes the product feel incomplete.

| Feature | Why Expected | Complexity | Dependencies | 1.0 Judgment |
|---------|--------------|------------|--------------|--------------|
| GMCP-driven room, target, and denizen state | A hunting helper must know current room, denizens, target id, target HP, vitals, class/spec, skills, and movement transitions without relying only on fragile text parsing. | High | `gmcp.Char.Items.*`, `gmcp.Room.Info`, `gmcp.IRE.Target.*`, `gmcp.Char.Vitals`, event handlers, owned runtime state domains. | Keep and harden. This is foundational. |
| Targeting by denizen id | Achaea rooms can contain repeated denizen names; id targeting avoids name ambiguity and slow manual targeting. | Medium | GMCP room items, `settarget <id>`, current-target state, target removal handling. | Keep as the only auto-targeting path. |
| Persistent whitelist, blacklist, global blacklist, tags, and priority order | Hunting area setup is operator knowledge. Users expect lists to survive reloads and preserve safe target order. | Medium | Mudlet DB, `boop.targets`, IH capture, list UI, import path. | Keep. Do not replace with static bundled area data. |
| Manual, whitelist, blacklist, and auto targeting modes | Operators need different safety levels depending on area familiarity. | Medium | Target lists, denizen filters, current target state, UI/config registry. | Keep. Default should remain conservative. |
| Retarget-on-priority control | Priority swaps are useful but can surprise operators in mixed rooms. The toggle is expected at this maturity. | Medium | Target priority ordering, current target tracking, room item updates. | Keep and test. |
| Class/spec standard attack profiles | A hunting package is not useful unless it knows class-appropriate bashing attacks and can adapt to spec/forms. | High | `gmcp.Char.Status`, `gmcp.Char.Vitals` spec fields, attack profile registry, planner tests. | Keep. Avoid profile churn before hardening. |
| Skill-gated attacks | Users should not have to hand-edit profiles for unlearned abilities. | Medium | `Char.Skills.Get`, skill cache, profile `skill`/`group` fields, fallback actions. | Keep and regression-test. |
| Standard and battlerage actions as separate decisions | Achaea hunting commonly uses standard attacks and rage actions together; boop already models them independently. | High | Attack planner, rage readiness, target id, queue/direct send helpers. | Keep. Do not collapse into one opaque "rotation." |
| Battlerage modes | Users expect at least simple damage, shieldbreak, pooling, conditional/affliction, and off/manual modes. | High | Rage amount/readiness, `IRE.Display` when present, text fallback, profile rage contracts, affliction tracker. | Keep existing modes. Do not add more before 1.0 unless fixing a real gap. |
| Shield detection and shieldbreak behavior | Denizen shielding wastes attacks unless the package reacts. Existing ecosystem comparators also treat shield handling as core. | High | Shield seen/down triggers, target state, `breakShields`, standard/rage profile metadata. | Keep and harden with live line variants. |
| Openers and target lifecycle cleanup | One-time per-target openers and stale target cleanup prevent repeated or misdirected attacks. | Medium | Target id lifecycle, `IRE.Target.Info`, room item removal, opener history. | Keep and test around party kills and retargets. |
| Safety: auto-flee threshold | A bashing helper must fail closed when health drops. | Medium | `Char.Vitals.hp/maxhp`, flee direction, config, send chain, disable-on-flee behavior. | Keep. Prioritize correctness over convenience. |
| Safety: interrupt holds | Operators need immediate manual actions such as `diag`, `touch shield`, `fly`, `leap`, card draws, and pull flow without boop fighting them. | High | Prompt trigger, timers, queue clearing, combat hold state, command parser. | Keep and harden. |
| Pull flow recovery | Pull is risky because it chains movement, rage, and return. Users expect boop to pause and resume only when the origin room is confirmed. | High | GMCP room info, rage availability, separator validation, timeout fallback, combat state. | Keep, but do not broaden before command validation and state tests. |
| Loot: automatic gold pickup with bounded retry | Hunting produces gold; users expect pickup without infinite retries or hidden failures. | Medium | Room item GMCP, gold triggers, freestand queue fallback, retry counters, warning output. | Keep and harden. |
| Loot: optional pack/stash behavior | Auto-stashing is a practical hunting feature, but must be explicit and warn on failure. | Medium | Gold pickup state, pack target config, command validation, success/failure triggers. | Keep with validation. |
| Compact combat summaries | The selected user priority is scroll/spam reduction. Users need condensed attacks, damage, crits, kills, XP, mob damage, and party noise without losing situational signal. | High | Gag triggers, pending gag state/timers, prompt flush, stats hooks, live combat log fixtures. | Active 1.0 feature. |
| Configurable gag scopes and colors | Users need separate control over own attacks, others, and mobs; blanket gagging is too coarse. | Medium | Gag config, color registry, dashboard/debug surfaces. | Keep. Polish only where it improves clarity. |
| Operator dashboards | A public package needs a discoverable home, control, config, party, stats, and help surface. | Medium | UI registry, `cecho`/links, command routing, README/UIDESIGN sync. | Keep and unify. |
| Workflow-first help | Users need goal-based first steps, not only a command dump. | Medium | Help registry, command parser, docs/tests. | Keep. Update with every command-surface change. |
| Consistent feedback tags | `[OK]`, `[INFO]`, `[WARN]`, and `[ERR]` scanning is table stakes for live hunting reliability. | Low | `boop.util`, UI emitters, gag/status paths. | Keep. Apply when touching output. |
| Stats: session, login, trip, lifetime, area, mob, target, ability, crit, rage | Mature hunters expect performance and profitability feedback. | High | Gag/kill/XP/gold hooks, Mudlet DB, stats scopes, render limits. | Keep. Optimize later if render cost appears. |
| Party assist and leader-call modes | Achaea hunting often happens in groups; assisting and following a leader target call are expected. | Medium | Party triggers, assist leader config, target id calls, attack prefixing. | Keep. Avoid arbitrary remote-command execution. |
| Party roster and combo inference | This is useful enough to retain, but it is near the boundary between table-stakes party support and differentiator. | Medium | Rage profile metadata, roster config, affliction tracker, UI. | Keep current behavior; defer expansion. |
| Trace and diagnostics | Live GMCP/text bugs are hard to reproduce. A bounded trace buffer and diagnostics are required for support. | Medium | Trace state, event hooks, UI/debug commands, output discipline. | Keep and make compact. |
| Release/build integrity | For a standalone Mudlet package, manifests, version fields, and in-Mudlet tests are part of the delivered feature contract. | Medium | Muddler, `mfile`, script/alias/trigger manifests, CI, Busted-in-Mudlet. | Must harden before 1.0. |

## Pre-1.0 Active Hardening Features

These should be treated as active roadmap candidates for the 1.0 hardening milestone. They are not broad feature expansion; they make existing behavior reliable enough to ship.

| Feature | User Value | Complexity | Dependencies | Acceptance Shape |
|---------|------------|------------|--------------|------------------|
| Owned runtime state completion | Prevents room, pull, walk, gold, diag, flee, and target paths from drifting into contradictory flat/nested state. | High | `boop.runtime.ensureState`, event handlers, walk/gold/diag/flee modules, tests. | No live code reads removed flat state keys; transition tests assert domain writes. |
| Compact summary replay fixtures | Reduces combat scroll without hiding important damage, crit, kill, XP, shield, or warning information. | High | Live combat logs, `boop_gag_spec.lua`, gag timers, trigger manifests. | Every new live line shape gets a replay-style regression before timer/merge changes. |
| Warning passthrough for gag mode | Prevents scroll reduction from hiding failed gold pickup, missed stash, queue/flee warnings, unusual combat lines, or parse gaps. | Medium | Gag filters, `boop.util.warn/err`, trace, tests. | Warnings and unmatched unusual lines remain visible or produce compact diagnostics. |
| Attack-summary ordering guarantees | Operators should see attack summaries before kill summaries and not get stale summaries after target changes. | Medium | Pending attack/kill state, prompt flush, room/target transitions. | Tests cover attack + rage + kill + XP ordering and target disappearance. |
| Autowalk blocker regression suite | Existing `boop walk` should not advance while gold, diag, flee, target, leader-call, or room-settling state is active. | High | `boop_walk.lua`, external walker event adapter, runtime effects, disabled walk spec. | `tests/boop_walk_spec.lua` covers start/stop, blockers, room-settled fallback, and `demonwalker.move`. |
| Gold/diag/flee/walk interaction checks | These features all compete for command timing. Failures here are high-risk in live hunting. | High | Runtime state, event timers, gold pending state, diag hold, flee disable, walker advance. | Focused specs prove one domain cannot silently bypass another domain's hold. |
| Shared command-fragment validation | Prevents persisted operator inputs from producing unintended game command chains. | Medium | UI setters, pack target, assist leader, directions, separator, pull command, tests. | Central validator rejects separators/newlines/unsafe fragments before save/send. |
| Version synchronization gate | Prevents package artifact and runtime `boop.version` from diverging. | Low | `mfile`, `boop_init.lua`, CI shell/Lua check. | CI fails unless `mfile.version`, `mfile.title`, and `boop.version` match. |
| Manifest parity validation | Prevents scripts/triggers/aliases from being present in source but missing from the built package. | Medium | Muddler manifests, `tools/sort_manifests.sh`, tests. | Test checks every manifest entry resolves and every expected source object is reachable. |
| GMCP reconnect/support verification | Ensures `IRE.Target`, `IRE.Display`, and `Char.Skills` support survives reconnect/reload. | Medium | `sendGMCP`, support requests, connection events, skill cache, tests/manual Mudlet check. | Reconnect path re-announces needed support and degrades clearly if `gmcp.IRE` is absent. |
| GMCP-unavailable degradation | Recent Achaea changes show some states can intentionally hide GMCP/name data. boop should pause or warn, not guess dangerously. | Medium | Room/target state, fog/no-data detection, UI blockers, trace. | Missing room/target data blocks unsafe automation and explains the blocker compactly. |
| Dashboard coherence pass | Users should not need to remember which surface owns a workflow. | Medium | `boop`, `control`, `config`, `party`, `stats`, `help`, `UIDESIGN.md`, tests. | Common workflows have direct dashboard paths and consistent compact footers. |
| Compact on/off/status summaries | The user selected compact summaries; toggles should not dump full dashboards unless explicitly requested. | Low | `bh`, `boop on/off`, status helpers, UI tests. | Toggle commands emit short state summaries with blockers/next action. |
| Whitelist-share trust hardening | Party whitelist packets can replace local ordering. The review/apply step exists, but sender trust and packet limits need tightening. | Medium | Party triggers, pending share state, assist leader/self checks, UI preview. | Explicit trusted sender, packet cap/TTL, sender/area/count shown before apply. |
| External walker install hardening | Current install follows latest release URL. Pre-1.0 should avoid making supply-chain risk worse. | Medium | `boop.walk.packageUrl`, docs, install command, optional checksum/pinned release. | Installer displays exact URL/version and is documented; auto-update behavior is not added. |

## Differentiators and Deferred Work

These are valuable after 1.0, but they should not displace hardening unless they close a live safety or clarity gap.

| Feature | Value Proposition | Complexity | Dependencies | Defer Until |
|---------|-------------------|------------|--------------|-------------|
| Broader class/profile expansion | More classes and forms make boop useful to more players. | High | Stable profile contract, skill/rage matrix tests, live line fixtures. | After 1.0 profile contracts are stable. |
| Data-driven trigger/pattern generation | Reduces maintenance burden for large gag/shield/rage trigger sets. | High | Manifest parity tests, existing trigger layout, generated fixture review. | After current trigger behavior is locked down. |
| Live combat-log replay importer | Converts real hunts into repeatable gag/rage/shield/stats regressions. | Medium | Log format conventions, gag/rage/shield handlers, test helper fixtures. | After initial manual replay fixtures prove shape. |
| Advanced compact-summary tuning | Per-class summary layouts, collapse thresholds, and richer rare-event annotation could improve scanning. | Medium | Gag state, colors, UI config, live feedback. | After baseline summary correctness is reliable. |
| Current-area party whitelist report | Useful party dashboard follow-up noted in project memory. | Low | Current room area, whitelist DB, `boop party` dashboard. | Post-1.0 polish unless trivial during dashboard pass. |
| Deeper party combo optimizer | Helps groups coordinate conditional rage and affliction setups. | High | Rage profile metadata, party roster, target aff tracking, callouts. | After solo/assist hardening and anti-remote-command boundaries are explicit. |
| Safer whitelist sharing with tags | Sharing area tags would improve group setup portability. | Medium | Whitelist tags DB, packet protocol, trust/cap/TTL hardening. | After trust model is fixed. |
| Stats render caching and export | Helps long-running sessions and post-hunt analysis. | Medium | Stats scopes, DB schema, render invalidation. | When render cost or export demand appears. |
| Trace export | Makes support/debugging easier than copying a short in-memory buffer. | Medium | Trace buffer, Mudlet file APIs, privacy review. | After trace content is stable and bounded. |
| Optional miniwindow mirror | Could improve UX for mouse-heavy users, but inline must remain canonical. | High | UI registry, Mudlet window APIs, UIDESIGN parity. | After 1.0 inline surfaces settle. |
| Pinned external walker integration contract | Makes `demonnicAutoWalker` integration more predictable across releases. | Medium | Known walker release, event contract tests, installer docs. | After walk regression suite exists. |
| Package update/check command | Helps distribution, but can add network and supply-chain complexity. | Medium | Release process, version sync gate, user consent. | After 1.0 release packaging is stable. |

## Anti-Features

Features to explicitly avoid before 1.0. Several should remain out of scope permanently unless the product direction changes.

| Anti-Feature | Why Avoid | Complexity | Dependencies/Risk | What to Do Instead |
|--------------|-----------|------------|-------------------|--------------------|
| Unattended AFK auto-hunting | Achaea's automation help warns against automation used to gain gold/XP while unattended. Building toward "walk away and farm" is a product and account-risk boundary. | High | Walker, target/attack, gold, safety, timeout behavior. | Keep explicit operator controls, visible blockers, and attended-use assumptions. |
| Timeout avoidance or keepalive automation for farming | This directly conflicts with the spirit of Achaea's automation restrictions. | Medium | GMCP keepalive, timers, route loops. | Do not build it. |
| Fully autonomous route-and-kill loops as a 1.0 goal | Combining walker, auto target, auto attack, auto gold, and no operator checkpoints increases unattended-use risk and hardens the wrong behavior. | High | `boop walk`, targeting, combat, loot. | Keep walker as optional attended integration with blockers and manual start/stop. |
| PvP combat automation | boop is a hunting/bashing package, not a PvP offense system. PvP automation adds a different risk, scope, and maintenance class. | High | Player target detection, affliction locks, combat priorities. | Keep PvP out of scope. |
| Arbitrary remote-command party automation | Achaea help specifically distinguishes permitted targeting from triggered actions ordered by someone else. | High | Party chat triggers, command senders, assist mode. | Only support narrow bashing target-call/assist flows with trusted leader checks. |
| Absorbing `demonnicAutoWalker` | Pathfinding/walking is a separate domain and already has an external package. Reimplementing it would delay 1.0 and expand support burden. | High | Mapping, route state, exits, movement recovery. | Keep a small adapter and contract tests. |
| Requiring SVO, Wundersys, or another major framework | The product promise is standalone. Large dependencies would make setup and support worse. | Medium | External queue/curing APIs. | Continue using Mudlet/Achaea primitives and optional explicit integrations only. |
| Large bundled static area databases | Area data gets stale and can encode unsafe assumptions. | High | Data maintenance, import/migration, user trust. | Keep DB-backed operator-maintained/imported lists. |
| Blanket gagging that hides game state | Spam reduction must not hide warnings, failed commands, death-risk signals, or parse misses. | Medium | Gag triggers, output filtering. | Use compact summaries plus visible warnings and trace diagnostics. |
| Broad architecture rewrite before 1.0 | The product is already built; rewrite churn would create regressions without user-facing value. | High | All modules and tests. | Make scoped hardening changes within existing domains. |
| New menu system parallel to current dashboards | UIDESIGN calls for coherent inline-first workflow surfaces. A parallel system increases support burden. | Medium | UI registry, help, docs, tests. | Extend existing home/control/config/party/stats/help surfaces. |
| Persisting unsafe command fragments | Pack names, leaders, separators, directions, and pull targets can become command chains if not validated. | Medium | UI setters, send paths, DB. | Add shared validation before persisting or sending. |
| Auto-installing or auto-updating latest external packages silently | Latest URLs can change independently and are supply-chain sensitive. | Medium | `installPackage`, GitHub releases. | Require explicit install, show URL/version, prefer pinned known release. |
| Adding trigger coverage without manifest/tests | Missing manifest entries silently break packaged behavior. | Medium | Muddler manifests, large trigger tree. | Add manifest parity tests and replay fixtures first. |
| Adding more rage modes for novelty | Existing modes are already broad. More modes increase support and bug surface. | Medium | Rage planner, profiles, help/docs. | Tune existing modes based on live evidence. |
| Expanding stats into heavy analytics before render bounds | Stats are useful, but unbounded detail can create memory/render cost in long sessions. | Medium | Stats tables, DB, UI rendering. | Keep current summaries; optimize/cap before expanding. |

## Feature Dependencies

```text
GMCP support negotiation
  -> GMCP event ingestion
  -> owned runtime state domains
  -> target selection
  -> attack and rage planning
  -> command sending / queueing
  -> gag summaries and stats attribution

Mudlet DB
  -> config defaults and persistence
  -> whitelist/blacklist/tags
  -> stats/lifetime data
  -> dashboards and workflow help

Text trigger coverage
  -> shield state
  -> rage readiness and afflictions
  -> compact attack/kill/mob summaries
  -> stats hooks

Safety state
  -> diag and interrupt holds
  -> gold pending state
  -> flee disable path
  -> pull return recovery
  -> walk blocker decisions

Release gates
  -> manifest parity
  -> version synchronization
  -> Muddler build
  -> in-Mudlet Busted suite
  -> 1.0 package confidence
```

## MVP / 1.0 Recommendation

Prioritize:

1. **Compact summary hardening**
   - Expand replay fixtures from live combat logs.
   - Preserve damage, crit, target, kill, XP, gold, and warning signal.
   - Keep unmatched/unusual output visible or traceable.

2. **State and safety hardening**
   - Finish owned state-domain consistency.
   - Test gold, diag, flee, pull, target, and walk interactions.
   - Treat missing GMCP or unsettled room state as a blocker, not an invitation to guess.

3. **Release confidence gates**
   - Add version-sync CI.
   - Add manifest parity validation.
   - Keep docs/help/dashboard output synchronized with command behavior.

4. **Command-fragment validation**
   - Centralize validation for separators, pack targets, leader names, directions, and future command fragments.
   - Reject unsafe values before persistence.

Defer:

- More class/profile breadth unless a current shipped profile is wrong.
- New rage modes.
- Miniwindows.
- Route/pathfinding ownership.
- Large area databases.
- Any feature that makes unattended gold/XP automation easier.

## Roadmap Implications

The features roadmap should be ordered by behavioral risk, not novelty.

| Phase Candidate | Rationale | Includes | Avoids |
|-----------------|-----------|----------|--------|
| Compact Summaries Hardening | Directly matches user priority and reduces live hunting scroll. | Gag replay fixtures, warning passthrough, attack/kill ordering, compact toggle output. | Blanket gagging and cosmetic-only color work. |
| Runtime State and Safety | Prevents dangerous timing bugs in existing hunting workflows. | Owned state cleanup, GMCP degradation, gold/diag/flee/pull/walk tests. | Rewrites and new movement features. |
| Release Gates | Makes 1.0 package output trustworthy. | Version sync, manifest parity, build/test enforcement, docs/help sync. | Manual-only release checklist. |
| Command Validation and Trust | Closes unsafe command-fragment and party-share edges. | Shared validators, whitelist share sender/cap/TTL review, external install clarity. | Arbitrary command chaining and broad party automation. |
| Post-1.0 Differentiators | Adds product depth after stable release. | Profile breadth, richer stats, trace export, party enhancements, optional miniwindow. | Pre-1.0 scope creep. |

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Implemented feature inventory | HIGH | Based on local README, DESIGN, UIDESIGN, codebase maps, and test inventory. |
| Pre-1.0 hardening priorities | HIGH | Directly supported by `.planning/PROJECT.md`, `.planning/codebase/CONCERNS.md`, and `CODEX.md`. |
| Mudlet/GMCP capability assumptions | MEDIUM | Verified against current official IRE/Mudlet docs via websearch; exact live Achaea behavior still needs Mudlet validation. |
| Achaea automation boundary | MEDIUM | Based on official help file; product decisions should stay conservative. |
| Ecosystem comparator expectations | MEDIUM | Public Achaea bashing scripts confirm target ordering, shield handling, rage modes, and GMCP/Mudlet requirements, but they are not authoritative for boop. |

## Open Questions for Later Phases

- Which exact live combat logs should seed the compact-summary replay suite?
- Should `boop walk install` pin a known `demonnicAutoWalker` release before 1.0, or only display the current latest-release URL more clearly?
- Should whitelist-share trust require `assistLeader`, an explicit allowlist, or both?
- What is the minimum supported Mudlet version for public 1.0, given CI currently uses a Mudlet 4.20.x AppImage?
- How should boop surface GMCP-hidden states such as Achaea fog: warning only, automatic pause, or both?
