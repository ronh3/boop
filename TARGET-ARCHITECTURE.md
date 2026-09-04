# TARGET-ARCHITECTURE.md

The intended shape of boop. `ARCHITECTURE.md` describes what exists; this file describes what the refactor is aiming at and why each boundary is drawn where it is. `REFACTOR-ROADMAP.md` sequences the work; `ARCHITECTURE-RULES.md` is the short form for day-to-day use.

This is **not a rewrite**. Every module below is formed by moving existing functions with their logic intact. No algorithm is redesigned.

---

## 1. What problem this solves

The committed `0.1.493` baseline recorded in `ARCHITECTURE.md` §3 has 21 script modules, 118 unique dependency edges, twenty-three directly reciprocal pairs (`A ↔ B`), and a 19-module strongly-connected component. Phase 3 adds Combat to that component intentionally; SCC shrinkage is not a pre-Phase-8 invariant.

Three modules concentrate the problem:

- **`boop_runtime`** held combat decision/execution (`step`, `applyEffects`, `tickStep`) beside its permanent composite `context` projection, so the state module called outward into `attacks`, `safety`, and `walk` — each of which called back. Runtime still has target-lifecycle responsibilities until Phase 5.
- **`boop_util`** held the command dispatcher through Phase 3. Phase 4 moved it to `boop.wire`, leaving string/output helpers and the Trace code scheduled for Phase 7.
- **`boop_events`** owns 42 top-level `boop.<function>` symbols — `tick`, `canAct`, `getWieldedItem`, `clearGoldQueueIntent`, `requestRoomItemsOnce` and the rest — which six other modules call directly. This alone accounts for six reciprocal pairs.

A fourth source is not a module but a missing rule: **shared data**. Four pairs exist only because one module reads or writes another's state or lists — `db ↔ init`, `db ↔ targets`, `stats ↔ targets`, `targets ↔ util`. They are invisible to an executable-only graph, which is why data references are part of the dependency model (§3) and why ownership is declared explicitly rather than inferred from assignment order.

Closing them is staged across four phases. Phase 3 closed three existing pairs and added the temporary `events ↔ combat` migration seam, for 23 → 21. Phase 4 closed twelve more and left the measured tree at nine reciprocal pairs. Phase 5 closes `events ↔ walk` and the deferred `runtime ↔ targets`, and **Phase 8 closes the remaining six original pairs plus `events ↔ combat`**. The last group depends on cohesive Gold, Inventory, and Interrupt extraction and retirement of the Events combat facade. **Phase 8 remains the point at which the graph becomes acyclic** — not Phase 4.

The target is a directed acyclic graph with one owner per concept.

---

## 2. Design principles

1. **Adapters normalize; engines read canonical state.** GMCP handlers write into `boop.state`; decision code never reaches into `gmcp.*`.
2. **Decisions produce data; execution consumes it.** `boop.attacks.plan()` already returns an unexecuted plan — extend that so prequeue and tick share one plan producer.
3. **One authoritative owner per concept.** One `currentRoomId`, one `deepCopy`, one gate evaluator, one egress point.
4. **`boop.state` is a data tree.** Service functions live on API namespaces such as `boop.runtime`, never attached to the externally readable state table.
5. **Observation never controls.** Stats and trace observe; no telemetry function may return a value that changes a combat decision.
6. **Persistence is a port.** `boop.db` exchanges plain tables; it never reaches into another module's internals.
7. **A module earns its existence.** Six admissible justifications: state ownership, lifecycle ownership, dependency seam, transport boundary, reusable policy, strong cohesion. Reducing a line count is not one of them.

---

## 3. Dependency model

### The binding invariant

**The target module dependency graph is a DAG.** `tools/check_release_gates.py --check architecture` enforces Boop's direct-reference coding convention and builds the supported graph from it. Before Phase 8, the existing cycles are reported as migration evidence. At Phase 8 acceptance, acyclicity becomes a hard gate.

Supported edges come from direct namespaced executable references, direct known top-level executable references, and **direct shared-data references resolved to their declared semantic owner**. Data reads and writes both create edges. The single graph exception is the **shared kernel** (`boop.config`, `boop.version`); `boop.defaults` remains ordinary owned data belonging to `boop.init`.

This is a repository subset, not a claim about arbitrary valid Lua. Cross-module references must remain statically visible. Aliasing `boop`, parenthesized or bracket-computed roots, captured cross-module functions, aliased/`_G` outbound calls, compatibility-forwarder captures, and hidden owned-data mutation are rejected as unsupported architectural indirection. The sole sanctioned string dependency is a literal `"boop.<symbol>"` passed through `boop.events.register()`'s existing local helper to Mudlet's string-callback event API; it resolves to the symbol's normal owner and unknown symbols fail closed. The guard does not implement general alias, string, or data-flow analysis beyond that exact mechanism.

Forbidden edges:

- `runtime` -> any decision, orchestration, or presentation module
- `attacks` -> `combat` (decision never depends on orchestration)
- `db` -> `stats`
- `db` -> `targets`
- `stats` -> `ui`
- `gag` -> `ui`
- `registry` -> any other module
- `util` -> any boop module except `theme`
- `render` -> any boop module except `theme` and low-level `util`
- `wire` -> `targets`; target identity is caller-supplied
- `send(` outside `boop.wire`

### Enforcement schedule

**Through Phase 7**, the guard reports current direct edges, reciprocal pairs, and SCC membership for review and rejects the hard forbidden directions above. The historical 96384bc facts remain documented reference data; the tool does not maintain occurrence tombstones or a formal SCC-history ratchet.

**On Phase 8 acceptance**, the supported graph must contain **no non-trivial SCC**. From that point, any direct-reference cycle is an unconditional hard CI failure, with the source convention preventing hidden cross-module dependencies from being an accepted escape hatch.

### The composition root

`boop_bootstrap` has zero incoming edges and is the **composition root**: nothing references it, and it performs the wiring that would otherwise force lower modules to know about higher ones. Graph analysis excludes it from cycle reporting by construction — a module with no in-edges cannot be in a cycle — rather than by special-casing.

Phase 4 moved the package's composition into it: the ready notification, the single surviving Registry attachment site with generation-sensitive reload refresh, trigger/Events callback wiring, and the ordered initialization sequence formerly in Init/State. This is the sanctioned place for one-way wiring; when a lower module appears to need a higher one, the wiring belongs here rather than as an edge.

### Tiers

Descriptive, not enforced — a review aid. The DAG and the edge classification are what bind.

```
T0  util, theme, render                          (leaves: util depends only on theme)
T1  trace, perf, db, skills, afflictions, registry
T2  runtime, room, locks                          (state API, room authority, admission)
T3  wire, standard                                (egress, queued-standard lifecycle)
T4  targets, lists, share, attacks, rage, safety,
    inventory, combatlog, stats                   (domain)
T5  combat, gold, interrupt, walk, ih             (orchestration)
T6  events                                        (GMCP/system adapter — calls down; nothing calls it)
T7  ui, commands, stats.report, gag               (presentation and command routing)
```

---

## 4. Modules

New modules are marked *. Provenance lets each move be traced to its source.

### Foundation

| Module | New | From | Responsibility | Owned state | Justification |
|---|---|---|---|---|---|
| `boop.util` | | `boop_util` | Strings and operator output. Its only remaining dependency is `boop.theme` | — | Becomes a leaf once trace and the dispatcher leave |
| `boop.theme` | | `boop_theme` | Colour tag sets | — | Cohesion |
| `boop.render` | * | `boop_ui` | Shared presentation primitives: `printHeader`, `printSection`, `printRow`, `printFooter`, `computeLabelWidth`, and the sectioned-layout helpers | — | **Dependency seam** — consumed by `ui`, `gag`, and `stats.report`; extracting it is what lets gag and stats render without depending on `ui` |
| `boop.trace` | * | `boop_util` | Rolling decision/command buffer, live streaming | `state.trace` | **Dependency seam** — eleven modules consume it, and its dependence on `state`/`config` is one of two reasons `boop.util` is not a leaf |
| `boop.perf` | * | new | Session-local hot-path instrumentation | `boop.perf` (module-owned, not in the state tree) | **Cohesion**, under a strict disabled-cost contract |
| `boop.db` | | `boop_db` | Persistence I/O over seven sheets; exchanges plain tables | `boop.db.handle` | **Transport boundary** (storage) |
| `boop.skills` | | `boop_skills` | GMCP skill inventory and gating lookups | `boop.skills` caches | State ownership |
| `boop.afflictions` | | `boop_afflictions` | Target affliction tracking | — | Cohesion |
| `boop.registry` | | `boop_ui_registry` | Config schema, UI modes, presets, help topics, screen routes, and a **registration API** that handlers call into. Declares data and accepts registrations; **references no other module** | — | **Reusable policy** |

### State and authority

| Module | New | From | Responsibility | Owned state | Justification |
|---|---|---|---|---|---|
| `boop.runtime` | | `boop_runtime` (residual) | **The state API namespace**: `ensureState`, the permanent canonical composite `context()` projection, canonical accessors (`currentRoomId`, `currentClass`, `currentSpec`), and other snapshot builders. **`boop.state` stays a pure data tree — no service functions attached to it** | the `boop.state.*` tree | **State ownership.** Combat, Attacks, and UI consume Runtime context; Runtime never depends on Combat |
| `boop.room` | * | `boop_runtime` | Room observation, response fences, applications, movement intent, source-authority validation | `state.targeting.roomObservation`, `movementIntent` | **Dependency seam** — every dispatch path asks "is this decision still valid for the room I am in?" — plus one coherent generation invariant |
| `boop.locks` | * | `boop_runtime` | Operation locks, blockers, priority ordering, `operationHolds`/`shouldHold`, interrupt admission tiers | `state.combat.blockersByOwner` | **Reusable policy** — admission control consumed by gold, interrupt, walk, and combat |

### Transport

| Module | New | From | Responsibility | Owned state | Justification |
|---|---|---|---|---|---|
| `boop.wire` | * | `boop_util` + `boop_runtime` + every current sender | **The only production caller of `send()` and `sendGMCP()`.** Outbound registration and observation, dispatch-authority checks, alias binding, direct/queued split, assist prefix | `state.queue.outbound*` | **Transport boundary** |
| `boop.standard` | * | `boop_runtime` | Queued-standard lifecycle: dispatch generations, baseline, candidate buffering and disposition, grace, retry, terminals, mutation barrier | `state.queue.standard*` | **Lifecycle ownership + strong cohesion** — the most intricate invariant in the package |

`boop.wire` exposes distinct entry points for distinct concerns, so migrating a party-channel callout does not force it through the standard-dispatch lifecycle:

| Entry point | Used for |
|---|---|
| owned combat dispatch | standard and rage actions that participate in the dispatch lifecycle |
| unowned utility command | pack test, `look in`, one-off operator commands |
| queue control | `clearqueue all`, queue mutation |
| channel text | `pt` target callouts, affliction callouts, share packets |
| protocol request | `sendGMCP` payloads and the request flush |

### Decision

| Module | New | From | Responsibility | Owned state | Justification |
|---|---|---|---|---|---|
| `boop.targets` | | `boop_targets` | Denizen inventory, selection, game-target sync | `state.targeting` | State ownership |
| `boop.lists` | * | `boop_targets` | Whitelist/blacklist/tag data, ordering, membership queries | `boop.lists.*` | **State ownership** — a user-edited, persisted lifecycle distinct from per-tick selection |
| `boop.share` | * | `boop_targets` | Party whitelist-share packet encode/decode, sender trust, pending application | `state.targeting.incomingWhitelistShares` | **Transport boundary** (party chat) |
| `boop.attacks` | | `boop_attacks` | Profile registry, standard and rage selection, command modifiers. **Loses `execute`** | `attacks.registry`, `state.combat.openerUsedByClass`, `state.combat.temporaryAttackPreferences` | Becomes purely a decision module |
| `boop.rage` | | `boop_rage` | Readiness, global cooldown, Triumph credit, gain sampling, affliction ingestion | `state.rage` | Lifecycle ownership |
| `boop.safety` | | `boop_safety` | Flee policy and execution. **No longer sends directly** | `state.combat.fleeing` | **Reusable policy** |
| `boop.inventory` | * | `boop_events` | Wielded-hand tracking, inventory snapshots | `state.inventory` | **State ownership**, with a real consumer — `attacks` Depthswalker weapon designation currently reaches a bare global `boop.getWieldedItem` |
| `boop.combatlog` | * | `boop_gag` (parse half) | Parses attack, damage, crit, balance, proc, and kill lines into structured events and publishes them | `state.gag.pending*` (parse state) | **Dependency seam** — removes `gag -> stats` and gives combat-line telemetry a source that is not the display filter |
| `boop.stats` | | `boop_stats` (model half) | Scopes, accumulators, mob XP, coalesced persistence flush. Consumes `combatlog` and `Char.Status` | `boop.stats.*` | State ownership |

### Orchestration

| Module | New | From | Responsibility | Owned state | Justification |
|---|---|---|---|---|---|
| `boop.combat` | * | `boop_runtime` (`step`/`applyEffects`/`tickStep`/`promptStep`) + `boop_events` (`canAct`/`canUseRage`) + `boop_attacks.execute` | The combat loop: consume Runtime context, evaluate gates, choose target, build a target-adjusted plan, and dispatch. Through Phase 7, Events keeps the room-aware `boop.tick` and prequeue facades. | `state.combat` execution coordination; `state.queue` prequeue coordination after the Phase-8 facade retirement | **Lifecycle ownership.** It depends on Attacks; Attacks never depends on it |
| `boop.gold` | * | `boop_events` + pack quarantine from `boop_runtime` | Pickup and pack pipeline, retries, quarantine | `state.gold` | State + lifecycle ownership |
| `boop.interrupt` | * | `boop_ui` + interrupt terminals and diag evidence from `boop_runtime` | `diag`/`matic`/`catarin`/`fly`/`leap`/`pull` admission, generations, timeouts, terminals | `state.diag`, `state.combat.pullState` | State + lifecycle ownership |
| `boop.walk` | | `boop_walk` | External walker adapter. **Owns the `mmp.currentroom` fallback** | `state.walk` | **Transport boundary** (external package) |
| `boop.ih` | | `boop_ih` | Info-Here capture | `state.ih` | Cohesion |

### Adapter and presentation

| Module | New | From | Responsibility | Owned state | Justification |
|---|---|---|---|---|---|
| `boop.events` | | `boop_events` (residual) | GMCP and system adapter only | — | **Transport boundary** |
| `boop.ui` | | `boop_ui` | Screens and dashboards, including the gag colour screens. Rendering primitives move out to `boop.render` | `state.ui` | Cohesion |
| `boop.commands` | * | `boop_ui` | Alias-facing parsing and routing; config setters. **S2 implementation of the S1 command surface** | — | Cohesion — puts the command contract in one testable place |
| `boop.stats.report` | * | `boop_stats` (render half) | All `show*` rendering and `boop stats` routing | — | **Cohesion**, and it breaks the `stats <-> ui` cycle |
| `boop.gag` | | `boop_gag` (render half) | Line condensation and palette resolution. Consumes `combatlog`; renders through `boop.render`. **The colour-picker screens move to the UI layer** — they are config screens that happen to be about gag | `state.gag` (render state) | Cohesion after the parse split |

---

## 5. The combatlog publication contract

Deliberately **not** a generic event bus, subscriber registry, or dependency-injection container. Introducing one for two consumers would add indirection without adding capability.

`boop_combatlog.lua` defines a **fixed, ordered, one-way dispatch list** — a literal sequence of named calls in source order, guarded with the established `if boop.x and boop.x.y then` idiom:

1. **Telemetry first** — `boop.stats.observe*`. This preserves today's ordering, in which stats is notified before any gag configuration is consulted, so telemetry survives with gags off.
2. **Rendering second** — `boop.gag.render*`.

Rules:

- No consumer may return a value that changes parsing.
- No consumer may mutate another consumer's state.
- Order is source order and is part of the contract.
- Adding a consumer means editing that list — a deliberate, reviewable act.

---

## 6. State model

`boop.state` is a **data tree**. No function is reachable under it.

### Two distinct kinds of ownership

Conflating these is what let `boop.state.init()` exist and let six modules mutate the stats tree.

**Schema custody — `boop.runtime`, exactly one module.** Owns the shape of the tree: the domain list, defaults, hydration, the schema-version sentinel, integrity repair, and migration. It decides what fields exist and that they are present and well-typed. It does **not** decide what they mean.

**Semantic ownership — one module per field or subtree.** Owns the meaning and the invariants: which transitions are legal, what evidence justifies a write, and which generation a value belongs to. The semantic owner is the only module permitted to mutate that subtree; everyone else reads, or calls an ingestion API.

Current owners are recorded in `ARCHITECTURE.md` §4; this table is the target, with the phase that moves each one.

| Subtree | Target semantic owner | Moves in | Everyone else |
|---|---|---|---|
| `combat.hunting`, `.attacking`, `.limiters` | `boop.combat` | P3 | read |
| `combat.fleeing` | `boop.safety` | P3 | read |
| `combat.class`, `.spec` | `boop.events` (adapter, via a runtime ingestion API) | P2a | read |
| `combat.blockersByOwner`, `.operationLock` | `boop.locks` | P5 | read; mutate only through the lock API |
| `combat.pullState` | `boop.interrupt` | P8 | read |
| `combat.openerUsedByClass`, `.temporaryAttackPreferences` | `boop.attacks` | already | read |
| `targeting.currentTargetId`, `.targetName`, `.targetShield`, `.denizens`, `.gameTargetSync` | `boop.targets` | already | read |
| `targeting.roomObservation`, `.movementIntent` | `boop.room` | P5 | read; mutate only through the observation API |
| `targeting.incomingWhitelistShares` | `boop.share` | P12 | read |
| `queue.standard*` | `boop.standard` | P6 | read |
| `queue.outbound*` | `boop.wire` | P4e | read |
| `queue.prequeue*`, `.balanceReadyAt`, `.equilibriumReadyAt`, `.alias*` | `boop.combat` | P8 facade retirement | read |
| `gold.*` | `boop.gold` | P8 | read |
| `diag.*` | `boop.interrupt` | P8 | read |
| `walk.*` | `boop.walk` | already (runtime writes today) | read |
| `inventory.*` | `boop.inventory` | P8 | read |
| `rage.*` | `boop.rage` | already | read |
| `gag.pending*` | `boop.combatlog` | P9 | read |
| `lifecycle.*` | `boop.runtime` (ingestion API called by adapters) | already | read |
| `trace.*` | `boop.trace` | P7 | — |
| `ui.*` | `boop.ui` | already | — |
| `ih.*` | `boop.ih` | already | — |

Ownership is non-overlapping at subtree granularity. Where a domain splits across owners — `combat` and `queue` do — the split is by named subtree, and the table above is the authority.

Data outside `boop.state` follows the same model:

| Namespace | Current owner | Target owner | Moves in |
|---|---|---|---|
| `boop.lists` | `boop.targets` | `boop.lists` module | P12 |
| `boop.wire.separator` | `boop.wire` (moved from the former list-shaped command setting) | unchanged | P4e complete |
| `boop.handlers` | `boop.events` | unchanged | — |
| `boop.attacks.registry`, `.pendingRegistry` | `boop.attacks` | unchanged | — |
| `boop.skills.*` | `boop.skills` | unchanged; `desiredGroups` gains an ingestion API | P4a |
| `boop.stats.*` | `boop.stats` | unchanged; `db` exchanges plain tables | P4f |
| `boop.db.handle` | `boop.db` | unchanged; UI raw access removed | P11 |
| `boop.registry.*`, `boop.ui.{modes,presets,helpTopics,screens}` | `boop.registry` | unchanged; registration inverted | P4c |
| `boop.config`, `boop.version` | **shared kernel — no owner** | unchanged | — |
| `boop.defaults` | `boop.init` | unchanged | — |

### Where the acting code lives

| Concern | Lives on |
|---|---|
| The data | `boop.state.<domain>.*` |
| Hydration, schema version, integrity repair | `boop.runtime.ensureState()` |
| Canonical accessors | `boop.runtime.currentRoomId()`, `currentClass()`, `currentSpec()` |
| Snapshots | `boop.runtime.context()`, `boop.runtime.*Snapshot()`, `boop.room.*Snapshot()`, `boop.locks.*Snapshot()` |
| Ingestion APIs for adapter-supplied evidence | the semantic owner of the target subtree |

Phase 4 retires `boop_state.lua` and adds a test asserting no function value is reachable under `boop.state`.

The externally supported subset is the S1 state-field allowlist in `ARCHITECTURE.md` §5 — 15 entries covering 18 fields across eight domains. The five domains not named there (`trace`, `ui`, `inventory`, `ih`, `gag`) are internal in their entirety, which is what makes the room-authority, standard-lifecycle, and inventory extractions legal without a compatibility note.

## 7. Cross-cutting rules

- **Adapters normalize and hand off; they do not freely mutate.** An external adapter (`boop.events`, trigger entry points, the walker adapter) converts raw input into normalized values and then calls the **ingestion API of the subtree's semantic owner**. It may write only state it owns itself. Writing another subsystem's invariant-bearing state directly — generations, locks, dispatch identity, observation fences — is forbidden even when the value looks obviously correct, because the owner is where the legality of a transition is decided.
- Engines read canonical state. No `gmcp.*` access in decision code. `charstats` is parsed once per Vitals event and handed to the owners of `state.rage.amount` and `state.combat.spec`.
- Decisions produce data; execution consumes it.
- One gate evaluator, `boop.combat.evaluateGates(intent)`, shared by tick, prequeue, and prequeue-refresh.
- **Runtime builds canonical context; Combat consumes it.** `boop.runtime.context()` remains the permanent composite projection used by Combat, the bare `boop.attacks.choose()` fallback, and UI. There is no `boop.combat.context()` compatibility copy.
- Through Phase 7, `boop.tick` remains an Events-owned facade: it claims and applies pending room work before delegating only the combat decision portion to `boop.combat.tick`. Phase 8 retires that facade after Room, Gold, and related ownership is available.
- Through Phase 7, `boop.combat` calls exactly the Events-owned Gold orchestration symbols `boop.maybeFlushPendingGold` and `boop.flushPendingGold`, while Events calls Combat. This approved temporary `events ↔ combat` seam is removed by Phase 8 Gold extraction; it must not be disguised with callbacks or indirection.
- **`send()` only from `boop.wire`. No second sanctioned sender**, including `boop.safety`.
- **`sendGMCP()` is part of the Wire invariant**, alongside `send()`. Both are outbound egress and both route through `boop.wire` as of Phase 6. The eight current call sites are listed in `ARCHITECTURE.md` §6. If a Mudlet constraint later argues for an exception, it must be documented here with the specific constraint.
- `boop.state` is data; service functions live on `boop.runtime`.
- Stats observes and never controls.
- Persistence exchanges plain tables. No synchronous DB write on a combat-frequency path.
- One implementation per shared concept. `mmp` is referenced only in `boop_walk`.

---

## 8. Non-goals

- **No `require()`.** Muddler ordering plus `boop.<ns> = boop.<ns> or {}` is the module system, and it works. Load-time side effects stay limited to documented registration mechanisms.
- **No event bus, message broker, or DI container.** The combatlog contract in §5 is a fixed call list precisely to avoid one.
- **No algorithm redesign.** Rage selection, room authority, the standard lifecycle, and the gag correlation logic move intact. Behavioural change is out of scope except where a candidate fix is separately approved.
- **No splitting for size.** A large file is a maintainability signal, not a runtime one, and never on its own a reason to add a module.
- **No compatibility shims beyond real need.** Only `boop.tick` and `boop.executeAction` get forwarders.
