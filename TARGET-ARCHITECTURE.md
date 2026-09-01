# TARGET-ARCHITECTURE.md

The intended shape of boop. `ARCHITECTURE.md` describes what exists; this file describes what the refactor is aiming at and why each boundary is drawn where it is. `REFACTOR-ROADMAP.md` sequences the work; `ARCHITECTURE-RULES.md` is the short form for day-to-day use.

This is **not a rewrite**. Every module below is formed by moving existing functions with their logic intact. No algorithm is redesigned.

---

## 1. What problem this solves

`ARCHITECTURE.md` §3 records the measured state. Of the 20 script modules, `boop_bootstrap` is the composition root with zero incoming edges; the other **19 form a single strongly-connected component**, containing **nineteen directly reciprocal pairs** (`A ↔ B`) and a large number of longer directed cycles.

Three modules concentrate the problem:

- **`boop_runtime`** holds the combat loop (`context`, `step`, `applyEffects`, `tickStep`), so the state module calls outward into `attacks`, `targets`, `safety`, and `walk` — each of which calls back.
- **`boop_util`** holds the command dispatcher (`executeAction`), so the string-helpers module calls into `runtime`, `gag`, and `rage`.
- **`boop_events`** owns 42 top-level `boop.<function>` symbols — `tick`, `canAct`, `getWieldedItem`, `clearGoldQueueIntent`, `requestRoomItemsOnce` and the rest — which six other modules call directly. This alone accounts for six reciprocal pairs.

Closing them is staged across four phases: Phase 3 closes five, Phase 4 nine, Phase 5 one, and **Phase 8 the final four**. The last group depends on the cohesive gold, inventory, and interrupt extraction, because that is what gives the remaining `boop_events` top-level functions an owner. **Phase 8 is therefore the point at which the graph becomes acyclic** — not Phase 4.

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

**The module dependency graph is a DAG.** Every edge is classified, and `tools/check_release_gates.py --check architecture` enforces both the classification and acyclicity.

| Class | Meaning | Guardrail behaviour |
|---|---|---|
| **allowed** | A sanctioned direction. | Any number of calls. Adding calls along it never requires an edit. |
| **legacy** | An edge that exists today and is scheduled for removal or a decision. | May shrink, never grow. A phase deletes it or promotes it to allowed. |
| **forbidden** | Never permissible. | Fails immediately. |

Forbidden edges:

- `runtime` -> any decision, orchestration, or presentation module
- `db` -> `stats`
- `stats` -> `ui`
- `util` -> any boop module except `theme`
- `send(` outside `boop.wire`

**Any cycle fails, regardless of edge classification.**

### Enforcement schedule

Cycle enforcement tightens in two stages, because the graph is not acyclic until Phase 8 completes.

**Through Phase 7**, every currently reciprocal edge is registered as `legacy`, and the guardrail enforces monotonic improvement:

- existing legacy edges may only **disappear**, never grow back;
- **no new legacy edge** may appear;
- **no module may newly join a cyclic SCC**;
- **SCC size may only decrease**;
- new unapproved edges and forbidden edges always fail.

**On Phase 8 acceptance**, the graph must contain **no non-trivial SCC** and the legacy list must be **empty**. From that point, any cycle is an unconditional hard CI failure.

### The composition root

`boop_bootstrap` has zero incoming edges and is the **composition root**: nothing references it, and it performs the wiring that would otherwise force lower modules to know about higher ones. Graph analysis excludes it from cycle reporting by construction — a module with no in-edges cannot be in a cycle — rather than by special-casing.

Phase 4 moves the package's composition into it: the ready notification, **both** registry-attachment sites, and the initialization sequence currently performed by `boop.state.init()`. This is the sanctioned place for one-way wiring; when a lower module appears to need a higher one, the wiring belongs here rather than as an edge.

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
| `boop.runtime` | | `boop_runtime` (residual) | **The state API namespace**: `ensureState`, canonical accessors (`currentRoomId`, `currentClass`, `currentSpec`), snapshot builders. **`boop.state` stays a pure data tree — no service functions attached to it** | the `boop.state.*` tree | **State ownership.** Calls no decision module; this is what breaks four cycles |
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
| `boop.attacks` | | `boop_attacks` | Profile registry, standard and rage selection, command modifiers. **Loses `execute`** | `attacks.registry`, `state.combat.temporaryAttackPreferences` | Becomes purely a decision module |
| `boop.rage` | | `boop_rage` | Readiness, global cooldown, Triumph credit, gain sampling, affliction ingestion | `state.rage` | Lifecycle ownership |
| `boop.safety` | | `boop_safety` | Flee policy and execution. **No longer sends directly** | `state.combat.fleeing` | **Reusable policy** |
| `boop.inventory` | * | `boop_events` | Wielded-hand tracking, inventory snapshots | `state.inventory` | **State ownership**, with a real consumer — `attacks` Depthswalker weapon designation currently reaches a bare global `boop.getWieldedItem` |
| `boop.combatlog` | * | `boop_gag` (parse half) | Parses attack, damage, crit, balance, proc, and kill lines into structured events and publishes them | `state.gag.pending*` (parse state) | **Dependency seam** — removes `gag -> stats` and gives combat-line telemetry a source that is not the display filter |
| `boop.stats` | | `boop_stats` (model half) | Scopes, accumulators, mob XP, coalesced persistence flush. Consumes `combatlog` and `Char.Status` | `boop.stats.*` | State ownership |

### Orchestration

| Module | New | From | Responsibility | Owned state | Justification |
|---|---|---|---|---|---|
| `boop.combat` | * | `boop_runtime` (`context`/`step`/`applyEffects`/`tickStep`/`promptStep`) + `boop_events` (prequeue, standard retry) + `boop_attacks.execute` | The combat loop: build context, evaluate gates once, choose target, build plan, dispatch, schedule prequeue | `state.combat`, `state.queue` (coordination) | **Lifecycle ownership**, and the module whose existence makes the graph acyclic |
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

| Subtree | Semantic owner | Everyone else |
|---|---|---|
| `combat.hunting`, `.attacking`, `.limiters` | `boop.combat` | read |
| `combat.fleeing` | `boop.safety` | read |
| `combat.class`, `.spec` | `boop.events` (adapter, via a runtime ingestion API) | read |
| `combat.blockersByOwner`, `.operationLock` | `boop.locks` | read; mutate only through the lock API |
| `combat.pullState` | `boop.interrupt` | read |
| `combat.temporaryAttackPreferences` | `boop.attacks` | read |
| `targeting.currentTargetId`, `.targetName`, `.targetShield`, `.denizens`, `.gameTargetSync` | `boop.targets` | read |
| `targeting.roomObservation`, `.movementIntent` | `boop.room` | read; mutate only through the observation API |
| `targeting.incomingWhitelistShares` | `boop.share` | read |
| `queue.standard*` | `boop.standard` | read |
| `queue.outbound*` | `boop.wire` | read |
| `queue.prequeue*`, `.balanceReadyAt`, `.equilibriumReadyAt`, `.alias*` | `boop.combat` | read |
| `gold.*` | `boop.gold` | read |
| `diag.*` | `boop.interrupt` | read |
| `walk.*` | `boop.walk` | read |
| `inventory.*` | `boop.inventory` | read |
| `rage.*` | `boop.rage` | read |
| `gag.pending*` | `boop.combatlog` | read |
| `lifecycle.*` | `boop.runtime` (ingestion API called by adapters) | read |
| `trace.*` | `boop.trace` | — |
| `ui.*` | `boop.ui` | — |
| `ih.*` | `boop.ih` | — |

Ownership is non-overlapping at subtree granularity. Where a domain splits across owners — `combat` and `queue` do — the split is by named subtree, and the table above is the authority.

### Where the acting code lives

| Concern | Lives on |
|---|---|
| The data | `boop.state.<domain>.*` |
| Hydration, schema version, integrity repair | `boop.runtime.ensureState()` |
| Canonical accessors | `boop.runtime.currentRoomId()`, `currentClass()`, `currentSpec()` |
| Snapshots | `boop.runtime.*Snapshot()`, `boop.room.*Snapshot()`, `boop.locks.*Snapshot()` |
| Ingestion APIs for adapter-supplied evidence | the semantic owner of the target subtree |

Phase 4 retires `boop_state.lua` and adds a test asserting no function value is reachable under `boop.state`.

The externally supported subset is the S1 state-field allowlist in `ARCHITECTURE.md` §5 — 15 entries covering 18 fields across eight domains. The five domains not named there (`trace`, `ui`, `inventory`, `ih`, `gag`) are internal in their entirety, which is what makes the room-authority, standard-lifecycle, and inventory extractions legal without a compatibility note.

## 7. Cross-cutting rules

- **Adapters normalize and hand off; they do not freely mutate.** An external adapter (`boop.events`, trigger entry points, the walker adapter) converts raw input into normalized values and then calls the **ingestion API of the subtree's semantic owner**. It may write only state it owns itself. Writing another subsystem's invariant-bearing state directly — generations, locks, dispatch identity, observation fences — is forbidden even when the value looks obviously correct, because the owner is where the legality of a transition is decided.
- Engines read canonical state. No `gmcp.*` access in decision code. `charstats` is parsed once per Vitals event and handed to the owners of `state.rage.amount` and `state.combat.spec`.
- Decisions produce data; execution consumes it.
- One gate evaluator, `boop.combat.evaluateGates(intent)`, shared by tick, prequeue, and prequeue-refresh.
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
