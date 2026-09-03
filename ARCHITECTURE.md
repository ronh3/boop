# ARCHITECTURE.md

How boop works today. Present tense, descriptive — this file records what the code *is*, not what it should become. For the intended shape see `TARGET-ARCHITECTURE.md`; for the rules that protect it see `ARCHITECTURE-RULES.md`.

**Source verified against the Phase-3 `0.1.494` working tree.** Current graph counts are measured by `tools/architecture_guard.py`; historical `96384bc` and Phase-1/2 counts remain below only as migration reference points.

---

## 1. Package and build model

boop is a standalone Mudlet package for Achaea, built with [Muddler](https://github.com/demonnic/muddler) from `src/`.

| Area | Path | Size |
|---|---|---|
| Scripts | `src/scripts/boop/` | 22 modules + 35 attack profiles, 30,651 lines |
| Aliases | `src/aliases/boop/` | 83 files, 131 lines — thin dispatchers |
| Triggers | `src/triggers/boop/`, `src/triggers/boop_lifecycle/` | 513 files, 3,247 lines |
| Tests | `tests/` | 43 Busted specs, 24,268 lines, run inside a real Mudlet in CI |

There is no `require()`. Modules are namespace tables on a single global, each file opening with `boop.<ns> = boop.<ns> or {}`. This is the correct idiom for Muddler packages and is deliberate — see §10.

`mfile` drives `@VERSION@`/`@PKGNAME@` token replacement. Four version checkpoints must stay synchronized: `mfile.version`, `mfile.title`, `boop.version` in `boop_init.lua`, and the checkpoint in `CODEX.md`.

### Load order

`src/scripts/boop/scripts.json` is deliberately unsorted and excluded from `tools/sort_manifests.sh`:

```
init → util → perf → theme → skills → db → runtime → state → afflictions → rage → ih
→ targets → gag → attacks → attacks/* → safety → stats → walk → combat
→ ui_registry → ui → events → bootstrap
```

**As the current function bodies are written**, definitions are order-independent: every cross-module reference resolves at call time through the `boop` global, and all guarded call sites use the `if boop.x and boop.x.y then` idiom. This is a property of the code as it stands, not a guarantee of the language — a function body that read another module's table at definition time, or a file that captured a `boop.*` value into an upvalue at load, would reintroduce order sensitivity.

Approved load-time work falls into these current classes:

- **Namespace, schema, and function/export definition**, including defensive `boop.<namespace> = boop.<namespace> or {}` initialization.
- **Attack-profile registration.** `attacks/attack_profile_bootstrap.lua` defines `boop.attacks.register` as a queueing stub *if and only if* `boop_attacks.lua` has not already defined the real one; profile files register at load time and `boop.attacks.flushPendingProfiles()` later drains the queue.
- **Registry attachment.** `boop_ui_registry.lua` calls `boop.registry.attachUiConfigRegistries()` at its tail, installing the config/UI registry tables and their metatable fallbacks.
- **Performance probe registration.** Instrumented modules call `boop.perf.register(...)` after defining the wrapped functions. `boop_perf.lua` initializes session-local probe storage and safely unwraps a prior source-load generation before accepting those registrations.
- **Composition-root startup.** `boop_bootstrap.lua` runs last, resets session-local runtime flags, and calls `boop.bootstrap()`.

Any new behaviorally significant class or site of load-time work must be explicitly documented here and reviewed. Undocumented load-time behavior is a defect.

---

## 2. Subsystems

The left column is the file; the right column is what it *actually* owns, which in several cases is more than its name suggests.

| Module | Lines | Actually owns |
|---|---|---|
| `boop_runtime` | 3937 | **Six distinct subsystems** remain: state schema and sentinel-guarded `ensureState`; the permanent canonical composite `context()` projection; room observation, response fences, applications, movement intent, and source authority; operation locks and blockers; queued-standard dispatch lifecycle/outbound expectations; interrupt terminals and diag evidence; pack quarantine. It no longer owns combat decision/execution. |
| `boop_combat` | 867 | Tick/prompt decision orchestration (`tickStep`, `promptStep`, `step`), the shared `evaluateGates(intent)`, target-adjusted planning, effect application, action execution, and the 0.4/0.6-second dispatch limiters. It consumes `boop.runtime.context()` and does not define a context projection. |
| `boop_events` | 3440 | GMCP and system event handlers, including the single Vitals `charstats` adapter into canonical Rage/Spec state, **plus** the entire Gold pipeline (~1250 lines), wielded-inventory tracking, Standard retry/recovery, the prequeue engine, the room-aware `boop.tick` facade, and `boop.onPrompt`. |
| `boop_ui` | 5546 | Dashboards, help, and config screens; config mutation; **the pull/interrupt state machine** (`queueInterrupt`, `diag`, `matic`, `catarin`, `fly`, `leap`, `touchShield`, `pullCommand`, `completePull`, `armPullTimeout`); alias-facing command parsers; five sites of raw `db:` access. |
| `boop_stats` | 3070 | The scope model and accumulators also own the 5-second dirty/coalesced lifetime-persistence schedule and exact-boundary flushes; **the remaining ~1,500 lines are rendering and `boop stats` command routing**, with a few late model functions interleaved among them. |
| `boop_attacks` | 1941 | Decision-only profile registry, `plan`/`applyModifiers`/`choose`, standard and Rage selection, and skill gating. Its bare `choose()` fallback still obtains the canonical projection from `boop.runtime.context()`. |
| `boop_targets` | 2037 | Denizen inventory, selection, game-target sync — **plus** whitelist/blacklist/tag data, the party whitelist-share packet protocol, and list rendering. |
| `boop_gag` | 1816 | Line condensation and palette — **plus the combat-line parser, which is the sole ingestion point for combat-line telemetry into `boop.stats`**. |
| `boop_ui_registry` | 1355 | Config schema and setters; UI modes, presets, help topics, screens; the metatable fallback bridge. |
| `boop_rage` | 885 | Rage readiness, global Battlerage cooldown, Triumph free-rage credit, canonical current amount, gain sampling, affliction-trigger ingestion, party callouts. |
| `boop_walk` | 812 | `demonnicAutoWalker` adapter, all-clear evaluation, reserved-move emission, blocker reporting. |
| `boop_db` | 648 | Mudlet DB schema, config/list/stats/mob-XP load and save. |
| `boop_util` | 500 | String and operator-output helpers — **plus `boop.trace.*` and `boop.executeAction`/`boop.executeRageAction`**, the command dispatcher. |
| `boop_theme` | 357 | Colour tag sets. |
| `boop_init` | 210 | Namespace bootstrap, `boop.defaults`, trigger folder enable/disable, GMCP support announcement, `boop.bootstrap`. |
| `boop_skills` | 184 | GMCP-driven skill inventory and gating lookups. |
| `boop_ih` | 143 | Info-Here capture and clickable list management. |
| `boop_afflictions` | 95 | Target affliction tracking (manual). |
| `boop_safety` | 77 | Flee threshold parsing and flee execution. |
| `boop_state` | 16 | A thin shim: attaches UI registries, then delegates to `boop.runtime.ensureState()`. |
| `boop_bootstrap` | 11 | Flushes pending stats before controlled source reload, performs session-local resets, then calls `boop.bootstrap()`. |

---

## 3. Dependency reality

### Graph shape

Boop deliberately uses a **convention-based, statically analyzable architectural subset**. The guard tokenizes enough Lua to recognize direct references while keeping comments and strings opaque. It is not a general Lua parser or data-flow analyzer. The graph is built from three kinds of supported direct reference:

- **namespaced executable** — `boop.<namespace>.<member>`, attributed to the module that defines the namespace's first member;
- **top-level executable** — `boop.<function>`, attributed to the module that defines it;
- **shared data** — a read or write of a declared data namespace or subtree, attributed to its **explicitly declared semantic owner** (§4).

All three are required, and each was added because omitting it hid real coupling. A namespace-only graph misses reciprocal pairs created by top-level Events facades; `boop_events` currently owns 42 top-level functions. Adding data references surfaces additional pairs. Counts throughout this document are **occurrences**, not lines containing a reference.

The coding convention is part of the protection. Cross-module code uses direct forms such as `boop.targets.choose()` and `boop.state.targeting.currentTargetId`. Architecture-obscuring forms are rejected: `local b = boop`, `(boop).targets`, `boop["targets"]`, function captures such as `local f = boop.tick`, aliases or `_G` access for `send`/`sendGMCP`, and owned-data mutation through aliases or `rawset`. The guard does not try to recover the hidden dependency semantically. Fourteen current path-and-symbol legacy exceptions cover seven computed owned-data writes, pre-existing `boop_events` state aliases, four `boop_stats` rendering captures, and the protected `pcall(boop.executeAction, ...)` site now owned by Combat; they are not permission for new indirection. Separately, the exact `rawset(state, domain, current)` in `boop_runtime.lua:283` is a permanent line-scoped schema-custody exception, not architectural debt.

One narrow string form is architectural by necessity: inside `boop.events.register()`, its existing local `add(event, fn)` helper passes literal `"boop.<symbol>"` callbacks to Mudlet's `registerAnonymousEventHandler`. The guard resolves only that handler-registration shape to the symbol's normal owner and fails closed if the literal names an unknown Boop symbol. Other strings remain opaque and do not create dependencies.

Two direct-reference rules matter enough to state here:

- **Exported locals are executable, not data.** `boop.ui.printHeader = uiPrintHeader`, where `uiPrintHeader` is a local function, is a function export. Without this rule 15 members of `boop.ui` are misclassified as data (`boop_ui.lua:101`, `:1124`, `:1132`, `:1133`, `:1157`).
- **A namespace belongs to whichever module defines its first member**, so `boop.trace` counts as `boop_util` and `boop.triggers` as `boop_init`.

The package contains **20 script modules** and **108 unique dependency edges**: 98 executable/API directions and 39 semantically owned-data directions, with 29 directions present in both sets. This corrects the earlier 109 count after the final shared-kernel reconciliation made `boop.defaults` ordinary data owned by `boop.init`. `boop_bootstrap` has **zero incoming edges** — nothing references it — so it cannot participate in any cycle. It is the **composition root**, and graph analysis excludes it by construction rather than by special-casing.

The remaining **19 modules form a single strongly-connected component**. Every one of them can reach every other by some directed path.

The Phase-1 working tree is tracked separately from that historical reference. It contains **21 modules** after adding `boop_perf` and **117 unique directions**: the frozen 108 plus exactly nine reviewed telemetry edges into Perf. Of those current directions, 107 are executable/API and 44 are owned-data, with 34 directions in both sets. It retains the same 23 reciprocal pairs, the same 19-member SCC, `boop_bootstrap` as the sole composition root, and zero unresolved direct references or duplicate direct exports.

The Phase-2 working tree contains the same **21 modules** and **118 unique directions**: 108 executable/API and 46 owned-data, with 36 directions in both sets. The one new direction is the explicit controlled-reload call `boop_bootstrap -> boop_stats`; canonical Rage ownership makes the existing `boop_attacks -> boop_rage` direction owned-data as well, and the persistence availability check makes the existing `boop_stats -> boop_db` direction owned-data as well as executable. The graph still has 23 reciprocal pairs, the same 19-member SCC, and the same sole composition root. No target-architecture boundary changed.

The Phase-3 `0.1.494` working tree contains **22 modules** and **126 unique directions**: 115 executable/API and 48 owned-data, with 37 directions in both sets. It has **21 reciprocal pairs** and one non-trivial SCC of size **20**; the SCC growth is expected because Combat joins the existing staged component. `boop_bootstrap` remains the sole composition root, with zero unresolved direct references and zero duplicate exports. Phase 3 closes `runtime ↔ attacks`, `runtime ↔ safety`, and `runtime ↔ walk`, removes Runtime's one-way Gag edge, and adds the approved temporary `events ↔ combat` pair.

Terminology used below:

- **Directly reciprocal pair (`A ↔ B`)** — both `A → B` and `B → A` exist. There are currently **twenty-one**.
- **Directed cycle** — any closed path of arbitrary length. The SCC implies a very large number; they are not enumerated.
- **SCC** — the maximal set of mutually reachable modules. There is one non-trivial SCC, currently of size 20.

### The twenty-one directly reciprocal pairs

Pairs marked **(data)** exist only because of a shared-data reference and are invisible to an executable-only graph.

| Pair | Reverse edge caused by | Closed by |
|---|---|---|
| `runtime ↔ targets` | Runtime retains six target-lifecycle references in responsibilities such as `beginConnectionLifecycle` and `clearAttackIntent`; Targets calls Runtime state/authority APIs | Phase 5 |
| `events ↔ targets` | `boop_targets` calls the Events-owned `boop.tick` and `boop.refreshPrequeuedStandard` facades | Phase 8 |
| `events ↔ combat` | Events calls `boop.combat.evaluateGates`, `tick`, and `prompt`; Combat calls the Events-owned `boop.maybeFlushPendingGold` and `boop.flushPendingGold` | Phase 8 Gold extraction/facade retirement |
| `init ↔ ui` | init→ui 2: `boop.bootstrap()` calls `ui.status("ready")` (`boop_init.lua:207–208`). ui→init: `boop.triggers.syncEnabled()` (`boop_ui.lua:1266–1267`) plus the top-level `boop.getShieldMode` | Phase 4a |
| `events ↔ init` | events calls the top-level `boop.requestCoreSupports` and `boop.resetShieldMode`; init calls the top-level `boop.reconcileIreSupport` and `boop.events.register` from `boop.bootstrap()` | Phase 4a |
| **`db ↔ init` (data)** | db→init: reads `boop.defaults` to cast persisted config values. init→db: `boop.db.init()` from `boop.bootstrap()` | Phase 4a |
| `ui ↔ ui_registry` | registry→ui 48 — config-setter closures invoking `boop.ui.*Command`/`set*` at call time; ui→registry 20 | Phase 4c |
| `stats ↔ ui` | stats→ui 47 — 46 rendering primitives plus one dashboard click handler calling `ui.setEnabled`; ui→stats 9 | Phase 4d |
| `gag ↔ ui` | gag→ui 22 — 10 rendering primitives plus 12 screen and navigation calls from the gag colour screens; ui→gag 29 | Phase 4d |
| `runtime ↔ util` | util→runtime 16 from `executeAction`; runtime→util 14 for string helpers and `boop.trace` | Phase 4e |
| `rage ↔ util` | `boop_util.markUnnamableMaulUsed` calls `rage.setReady` (`boop_util.lua:208`) | Phase 4e |
| `gag ↔ util` | `executeAction` calls `gag.noteStandardIntent`; gag→util 108, mostly `boop.util` and `boop.trace` | Phase 4e |
| **`targets ↔ util` (data)** | util→targets: `executeAction` reads `boop.state.targeting.currentTargetId` (`boop_util.lua:346`). targets→util: `boop.util`, `boop.trace` | Phase 4e |
| `db ↔ stats` | db→stats 37 (`loadStats` writes `boop.stats.lifetime` directly); stats→db 8 | Phase 4f |
| **`db ↔ targets` (data)** | db→targets: `loadLists()` writes `boop.lists` directly. targets→db: `boop.db.saveList` | Phase 4f |
| `events ↔ walk` | `boop_walk` calls the top-level `boop.requestRoomItemsOnce` | Phase 5 |
| `attacks ↔ events` | `boop_attacks` calls the top-level `boop.getWieldedItem` inventory adapter | Phase 8 |
| `events ↔ runtime` | `boop_runtime` calls the top-level `boop.tick`, `boop.retryStandardDispatch`, `boop.onStandardLifecycleTerminal`, and `boop.tryVenomConfusionDiag` | Phase 8 |
| `events ↔ safety` | `boop_safety` calls the top-level `boop.clearGoldQueueIntent` | Phase 8 |
| `events ↔ ui` | `boop_ui` calls the top-level `boop.tick`, `boop.schedulePrequeue`, `boop.refreshPrequeuedStandard`, `boop.clearGoldQueueIntent`, and `boop.displaceGoldQueueIntent` | Phase 8 |
| **`stats ↔ targets` (data)** | stats→targets: one read of `state.targeting.currentTargetId` (`boop_stats.lua:1501`). targets→stats: `onTargetSet` push (`:484`) plus two `formatMobXp` calls in list rendering (`:1597`, `:1643`) | Phase 8 |

From the 0.1.493 baseline, Phase 3 closes three pairs and adds temporary `events ↔ combat`, yielding 21. Phase 4 closes twelve original pairs, Phase 5 closes `events ↔ walk` and `runtime ↔ targets`, and **Phase 8 closes the remaining six original pairs plus the temporary pair** — at which point the graph is acyclic. See `REFACTOR-ROADMAP.md`.

`boop_events` references `boop.runtime.*` **181 times**. The two files are one tangled subsystem separated by history rather than by design.

**Removed one-way edge:** Runtime no longer references Gag; `gag.onPrompt` effect application moved to Combat.

### Top-level symbol ownership

The guard currently resolves 51 top-level `boop.<function>` symbols. `boop_events` owns 42; the moved limiters are now namespaced under `boop.combat` and are not top-level compatibility shims.

| Owner | Count | Cross-module examples |
|---|---|---|
| `boop_events` | 42 | `tick`, `onPrompt`, `schedulePrequeue`, `prequeueStandard`, `refreshPrequeuedStandard`, `getWieldedItem`, Gold facades, `requestRoomItemsOnce`, `reconcileIreSupport`, `tryVenomConfusionDiag`, `retryStandardDispatch`, `onStandardLifecycleTerminal` |
| `boop_init` | 3 | `getShieldMode`, `resetShieldMode`, `requestCoreSupports` |
| `boop_skills` | 3 | `onSkillsGroups`, `onSkillsList`, `onSkillsInfo` |
| `boop_util` | 2 | `executeAction`, `executeRageAction` |

`boop.tick` and `boop.executeAction` are retained as external forwarders (see §5). Every other top-level symbol moves to its owning module as that module is extracted, and internal callers move with it.

### `boop_state.lua`

`boop_state.lua` (16 lines) defines `boop.state.init()`, which performs a **second** registry attachment — the first being at the tail of `boop_ui_registry.lua` — and then delegates to `boop.runtime.ensureState()`. It is called from `boop.bootstrap()` (`boop_init.lua:164`) and from `tests/support/boop_test_helper.lua:168`.

This is a direct contradiction of the data-only intent for `boop.state`: a service function lives under the state tree. Phase 4 retires the file entirely.

### Inversions

Beyond the cycles:

- **`db → stats`** — `boop.db.loadStats()` writes `boop.stats.lifetime.*` and `boop.stats.mobXp` directly rather than returning data for the caller to apply.
- **`gag → stats`** — combat-line telemetry is ingested by the display-filter module. `boop.gag.onAttackLine` calls `boop.stats.onAttackLine` *before* consulting any gag config, so telemetry survives with gags off; the coupling is subtle and undocumented rather than broken.
- **`ui → db`** — beyond 22 `boop.db.*` references, `boop_ui.lua` calls `db:` directly at `:3217` (`db:fetch`), `:3375`/`:3378` (`db:fetch`), and `:3376`/`:3379` (`db:delete`), bypassing the persistence module.
- **`util → state/config`** — `boop.trace.log` reads `boop.config.traceEnabled` and `boop.state.trace.*`, which together with the dispatcher is why `boop_util.lua` is not a leaf.

`boop_util.lua`'s outgoing edges separate cleanly into three groups: the string/output helpers depend only on `boop.theme`; `boop.trace.*` depends on `boop.state.trace` and `boop.config.traceEnabled`; and `executeAction`/`executeRageAction` depend on `boop.runtime` (8 distinct functions), `boop.gag.noteStandardIntent`, `boop.rage.setReady`, `boop.state.queue`/`targeting`, `boop.config`, and `boop.lists.separator`.

---

## 4. State ownership

### Canonical state

`boop.state` holds thirteen owned domains, defined by `DOMAIN_DEFAULTS` in `boop_runtime.lua` and hydrated by `boop.runtime.ensureState()`:

```
combat  lifecycle  targeting  gold  queue  walk  diag
trace   ui         rage       inventory  ih   gag
```

Two mechanisms protect this: `tests/boop_state_contract_spec.lua` asserts the domains exist with expected defaults and that `boop.runtime.context()` maps from them, and `tools/check_release_gates.py --check state-drift` fails on new flat-state access outside the owned domains.

The legacy flat `boop.state.<key>` bridge was removed on this branch. `CODEX.md` records that personal Mudlet scripts reading old flat keys broke as a result.

### State outside the canonical tree

| Location | Contents |
|---|---|
| `boop.config` | All persisted settings, loaded from the `config` sheet over `boop.defaults` |
| `boop.lists` | `whitelist`, `blacklist`, `globalBlacklist`, `whitelistTags`, `separator` |
| `boop.stats` | `lifetime`, `session`, `login`, `trip`, `mobXp`, `lastGold`, `lastXp`, `activeTarget`, `pendingAttack` |
| `boop.attacks.registry` | Class → profile table, plus `pendingRegistry` |
| `boop.skills` | Known-skill and group caches |
| `boop.gmcp` | `lastSupportAnnounceAt` |
| `boop.handlers` | Registered anonymous event-handler ids |

Stats state outside the canonical tree is the largest ownership gap: it is mutated by `boop_db`, `boop_gag`, `boop_targets`, `boop_safety`, `boop_attacks`, and `boop_events`.

### Shared-data ownership

**Physical table initialization does not establish architectural ownership.** `boop.lists = boop.lists or {}` in `boop_init.lua` is defensive bootstrap, not a claim. Executable ownership is *inferred* from Lua definitions and exports; **shared-data ownership is explicit, semantic, and versioned** — declared in this section and nowhere else.

This distinction is load-bearing, not stylistic. A first-assignment rule was measured against this tree and invents six reciprocal pairs — including `runtime ↔ state` and `init ↔ util`, artifacts of where a table happened to be initialized — while losing two genuine pairs by misattribution. It measures assignment history, not architecture.

**Resolution rules.** For supported direct references, the longest matching declared prefix wins. Reads and writes both create a dependency edge on the semantic owner. A visible write by a non-owner is additionally a **mutation violation**, reported separately from the graph. Defensive initialization creates no edge and transfers no ownership. **A direct reference resolving to neither a declared owner nor the shared kernel is a hard error.** Indirect mutation is prohibited by convention instead of being followed through arbitrary Lua data flow.

#### Shared kernel — no module owner, no edges

| Namespace | Why |
|---|---|
| `boop.config` | Six modules write it, fifteen read it. No module has a defensible claim; forcing one manufactures 1–5 fictional pairs (measured: init +5, registry +3, db +1). Structurally it is already three-way — **schema** owned by `boop.registry`, **persistence** by `boop.db`, **values** written by whichever module owns that setting's semantics. |
| `boop.version` | Written once by `boop_init`, read by `boop_ui`. S1. |

This list is **closed and versioned**. Adding to it requires editing this section — the reviewable act that keeps the exemption from becoming a blind spot. Kernel namespaces are exempt from the *graph*, not from *governance*: a module may write only config keys whose semantics it owns, through the registry's setter path.

#### Pure data namespaces

| Namespace | Defensive init in | Actual writers | Semantic owner |
|---|---|---|---|
| `boop.defaults` | — | init | **`boop.init`** — DB reads create `db → init`; writes are restricted to init |
| `boop.lists` | `boop_targets` (8), `boop_init` (6) | db 8, ui 6, targets 3 | **`boop.targets`** — not `boop_init` |
| `boop.lists.separator` | `boop_init` | init | **command/dispatch** — used only by `executeAction` and gag razeslash parsing; zero targeting use |
| `boop.handlers` | `boop_init` | events 2 | `boop.events` |
| `boop.gmcp` | `boop_init` | init | `boop.init` — not cross-module |
| `boop.bootstrapped` | — | init | `boop.init` — not cross-module |

#### Data subtrees under executable namespaces

| Subtree | Cross-module access | Semantic owner |
|---|---|---|
| `boop.attacks.registry`, `.pendingRegistry` | `boop_ui` reads (3 sites) | `boop.attacks` |
| `boop.skills.known`, `.pending`, `.skillToGroup`, `.lastInfo`, `.lastList` | `boop_ui` reads | `boop.skills` |
| `boop.skills.desiredGroups` | **written by `boop_init`** | `boop.skills` — **mutation violation today**; needs an ingestion API |
| `boop.stats.lifetime`, `.mobXp` | `boop_db` reads and writes | `boop.stats` |
| `boop.stats.trip` | `boop_ui` reads | `boop.stats` |
| `boop.db.handle` | `boop_ui` reads (5 raw `db:` sites) | `boop.db` |
| `boop.registry.config`, `.ui` | `boop_ui` reads | `boop.registry` |
| `boop.ui.modes`, `.presets`, `.helpTopics`, `.screens` | `boop_ui_registry` | `boop.registry`, aliased onto `boop.ui` by `attachUiConfigRegistries` |

#### `boop.state` — schema custody versus semantic ownership

`boop.runtime` owns the tree's **shape**: domain list, defaults, hydration, schema sentinel, integrity repair, migration. It does **not** own the meaning of any field. The root `boop.state` declaration below is exact schema custody, not fallback ownership for its children: every first-level `boop.state.<domain>` must have an explicit semantic-owner declaration or the guard fails closed. Each subtree has one semantic owner that decides which transitions are legal and is the only module permitted to mutate it. Ownership is declared at whatever prefix depth makes it non-overlapping.

| Prefix | Semantic owner | Writers today |
|---|---|---|
| `boop.state` *(schema only)* | `boop.runtime` | — |
| `boop.state.combat` | `boop.runtime` (broad residual declaration during staged schema/lifecycle migration) | runtime owns blockers/schema/reset paths; Combat writes `attacking` and `limiters`; attacks, events, safety, rage, ui, and stats retain narrower current responsibilities |
| `boop.state.combat.openerUsedByClass`, `.temporaryAttackPreferences` | `boop.attacks` | attacks |
| `boop.state.lifecycle` | `boop.runtime` | events 1 |
| `boop.state.targeting` | `boop.targets` | targets 27, runtime 14, events 6, rage 1 |
| `boop.state.targeting.roomObservation` | `boop.runtime` | runtime |
| `boop.state.targeting.movementIntent` | `boop.runtime` | runtime |
| `boop.state.gold` | `boop.events` | events 33, runtime 14 |
| `boop.state.queue` | `boop.runtime` | events 18, ui 11, runtime 7, util 3, attacks |
| `boop.state.walk` | `boop.walk` | runtime 12 — **runtime writes walk's subtree** |
| `boop.state.diag` | `boop.runtime` | runtime 9, ui 7, events 1 |
| `boop.state.trace` | `boop.util` | util 6, ui 1, bootstrap 1 |
| `boop.state.ui` | `boop.ui` | — |
| `boop.state.rage` | `boop.rage` | rage 3 |
| `boop.state.inventory` | `boop.events` | events 11 |
| `boop.state.ih` | `boop.ih` | ih 10 |
| `boop.state.gag` | `boop.gag` | gag 54 |

The multi-writer domains — `combat` (5 modules), `queue` (5), `targeting` (4), `diag` (3) — are the ownership drift the roadmap corrects. `TARGET-ARCHITECTURE.md` §6 records where each subtree's ownership moves.

---

## 5. Supported API surface

**432 top-level, globally-addressable `boop.*` functions** are defined across `src/`. Being globally addressable is not the same as being public: the S1/S2/S3 classification below, not reachability, determines what carries a compatibility commitment.

Aliases reference 80 distinct `boop.*` symbols and triggers reference 44 — and both are files this repository owns and changes in the same commit.

### S1 — Supported external contract

Breaking any of these requires a documented note.

- **Alias syntax and semantics.** What a user types (`boop`, `boop control`, `boop config`, `boop help`, `boop party`, `boop stats …`, `bh`, `diag`, `matic`, `catarin`, `fly`, `leap <dir>`, `pull <mob> <dir>`, `boop whitelist …`, `boop blacklist …`, …) and what each command *does*. **The contract is the command surface, not the Lua router behind it.**
- **Output formats only where explicitly designated stable or machine-consumed.** Cosmetic wording, colour, spacing, ordering, and general presentation are **not** S1 and may change freely. No output format is formally designated stable today; the gag summary line (`Mob: Damage -> You (#### damagetype)`) is the most plausible candidate for designation, since users may capture it with their own triggers.
- **Persisted config keys and the Mudlet DB schema** — seven sheets: `config`, `whitelist`, `blacklist`, `whitelist_tags`, `mob_xp`, `mob_xp_v2`, `stats`.
- **`boop.version`.**
- **`demonwalker.*` event integration** and `boop walk` semantics.
- **The state-field allowlist below**, and — implied by it — the parent domains those fields live in.

#### S1 state-field allowlist

This list *is* the external state contract. Everything under `boop.state` not listed here is internal and may be added, renamed, restructured, or removed, **including entire domains not named below**. Only the parent domains of allowlisted fields are guaranteed to exist.

**New state becomes S1 only by deliberate promotion, recorded in this file in the same commit.**

| Field | Meaning |
|---|---|
| `combat.hunting` | boop is actively hunting |
| `combat.attacking` | the last tick dispatched an action |
| `combat.fleeing` | a flee is in progress |
| `combat.class`, `combat.spec` | current class and spec |
| `targeting.currentTargetId` | current target id |
| `targeting.targetName` | current target name |
| `targeting.targetShield` | target shield state |
| `targeting.denizens` | eligible denizens in the current room |
| `targeting.room`, `targeting.lastRoomDir` | current room and last movement direction |
| `queue.prequeuedStandard` | a standard attack is staged |
| `gold.getPending`, `gold.putPending` | the gold pipeline is mid-flight |
| `diag.hold` | combat is held by an interrupt |
| `walk.active` | the walker is running |
| `lifecycle.ready` | GMCP/IRE lifecycle is ready |
| `rage.ready` | per-ability rage readiness map |

**15 allowlist entries covering 18 fields** (four entries name two fields each). Guaranteed parent domains, by implication: `combat`, `targeting`, `queue`, `gold`, `diag`, `walk`, `lifecycle`, `rage`. The remaining five domains — `trace`, `ui`, `inventory`, `ih`, `gag` — are internal in their entirety.

Explicitly **not** S1, even inside guaranteed domains: `roomObservation`, `movementIntent`, `gameTargetSync`, `blockersByOwner`, `operationLock`, `standardOperation`, `outbound*`, `packQuarantine`, `evidenceQueue`, `limiters`, and every internal generation, timer, and sentinel field.

### S2 — Package-internal wiring

The `boop.*` symbols referenced from `src/aliases/` and `src/triggers/`, plus the alias-facing command routers. Freely changeable; the alias and trigger files migrate in the same commit. Dominated by:

| Symbol | Trigger files |
|---|---|
| `boop.gag.onAttackLine` | 263 |
| `boop.targets.onShieldDownTrigger` | 116 |
| `boop.rage.onAfflictionTrigger` | 92 |

### S3 — Internal

Every remaining top-level `boop.*` function, reachable only from other scripts and from `tests/`. Freely movable, renamable, removable.

**Forwarders** are justified only for `boop.tick` and `boop.executeAction` — the two globals a user's personal automation would plausibly call directly.

---

## 6. Outbound egress

**Sixteen production `send()` call sites across eight files.** There is no single egress point today. The count covers every executable Lua file under `src/`, including aliases.

| Site | Command | Concern |
|---|---|---|
| `src/aliases/boop/Targeting/IH.lua:2` | `ih` | direct targeting alias |
| `boop_util.lua:376` | `sendOwned` inside `executeAction` | the dispatcher itself |
| `boop_events.lua:135` | gold queue command | gold |
| `boop_events.lua:487` | `send(" ")` | GMCP request flush |
| `boop_targets.lua:541` | `settarget <id>` | target sync |
| `boop_targets.lua:563` | `pt Target: <id>.` | target callout |
| `boop_targets.lua:930`, `:937`, `:939` | `pt <share packets>` | party-share transport |
| `boop_safety.lua:66` | `clearqueue all` | flee |
| `boop_rage.lua:844` | affliction callout | rage callout |
| `boop_runtime.lua:2642` | `clearqueue all` | standard revoke |
| `boop_ui.lua:1586` | `queue add freestand look in <pack>` | pack test |
| `boop_ui.lua:1746` | `clearqueue all` | leap |
| `boop_ui.lua:1757` | queued interrupt command | interrupt |
| `boop_ui.lua:2206` | pull chain | pull |

A further textual match at `boop_targets.lua:925` is an error-message string (`"Cannot share whitelist: send() is unavailable."`), not a call.

`sendGMCP()` is a separate protocol path: **eight literal calls across three files** — `boop_init.lua:140–143` (four core-supports announcements), `boop_skills.lua:42`, `:51`, `:68` (three skill queries), and `boop_events.lua:486` (one room-item request).

---

## 7. Event flows

### Entry points

- **Twenty anonymous event handlers** registered by `boop.events.register()`: `gmcp.Char.Afflictions.List`, `gmcp.Char.Items.{List,Add,Remove,Update}`, `gmcp.Room.Info`, `gmcp.IRE.Display.{ButtonActions,FixedFont,Ohmap}`, `gmcp.IRE.Target.{Set,Info}`, `gmcp.Char.Status`, `gmcp.Char.Vitals`, `gmcp.Char.Skills.{Groups,List,Info}`, `sysDataSendRequest`, `sysConnectionEvent`, `demonwalker.arrived`, `demonwalker.finished`.
- **One always-on prompt trigger** — `src/triggers/boop_lifecycle/Prompt.lua`, a native Mudlet `prompt` pattern calling `boop.onPrompt()`. Its folder is the only trigger folder active when boop is disabled.
- **512 gameplay triggers** in the `boop` folder, enabled and disabled wholesale by `boop.triggers.setEnabled()`.

### Combat and action flow

```
gmcp.Char.Vitals ─→ boop.onVitals()  ─┐
                                       ├─→ boop.tick(authority, opts)
prompt trigger ──→ boop.onPrompt() ───┘        │
                        │                       ├─ claim/apply pending room work [Events]
                        ├─ rage.onPrompt()      └─ combat.tick()
                        ├─ reconcileGoldPickup       ├─ runtime.context()       [build]
                        ├─ reconcileStandard         ├─ combat.evaluateGates() [decide]
                        └─ combat.prompt()           ├─ targets.choose()
                             └─ gag_prompt           ├─ attacks.choose()
                                                     └─ combat.applyEffects() [execute]
                                                          └─ combat.execute()
                                                               └─ boop.executeAction() → send()
```

`boop.onVitals()` parses `gmcp.Char.Vitals.charstats` once into canonical `state.rage.amount` and `state.combat.spec`, even while Boop is disabled. It then returns before combat decision work when disabled; otherwise it follows the unchanged Vitals tick path. `boop.onPrompt()` guards on `enabled`, reconciles Gold and Standard lifecycle in their current owners, delegates prompt decision/effects to Combat, then ticks again if `promptStep` returns `runTick`. `boop.combat.canAct()`'s 0.4 s limiter still suppresses a duplicate *dispatch* but not duplicate enabled decision work; tick coalescing remains deferred.

`boop.tick` is intentionally **not** a direct forwarder in Phase 3. Events first checks and may claim a pending room application, preserving current recursive/re-entrant Room/Targeting/Gold/Walk behavior; only then does it call `boop.combat.tick`. Runtime permanently owns `boop.runtime.context()`, which Combat consumes. The same projection remains available directly to UI and to bare `boop.attacks.choose()`; no Combat context copy exists.

`applyEffects` moved intact. Its two Gold calls — `boop.maybeFlushPendingGold` during gate evaluation and `boop.flushPendingGold` during effect application — are the exact Combat → Events half of the approved temporary `events ↔ combat` pair. Phase 8 Gold extraction removes them and retires the Events facade.

### Prequeue flow

`boop.onBalanceUsed(kind, seconds)` — driven by the balance/equilibrium trigger — records `balanceReadyAt`/`equilibriumReadyAt`, then `boop.schedulePrequeue()` sets a `tempTimer` for `readyAt − attackLeadSeconds`. On fire, the Events-owned `boop.prequeueStandard()` consumes `boop.combat.evaluateGates({kind="prequeue"})`, preserves target synchronization ordering, obtains its plan from Combat's shared target-adjusted planning path, then calls `boop.executeAction(action, forceQueue=true)`. `boop.refreshPrequeuedStandard()` uses the explicit `refresh` intent, which intentionally omits ordinary prequeue's flee check and adds current-target/shieldbreak requirements. It rebuilds the alias if the target gains a shield before the queued standard fires.

### Target lifecycle

`gmcp.Char.Items.List/Add/Remove` feed the room-observation fence and application model in `boop_runtime`, which on acceptance calls `boop.targets.updateRoomItems()` to rebuild `state.targeting.denizens`. Denizen filtering requires `attrib` to contain `m` and to exclude `x` and `d`.

Selection is `boop.targets.choose()`: mode → area → sorted denizens → called-target check → optional current-target keep → priority scan. Modes are `manual`, `whitelist`, `blacklist`, `auto`; the global blacklist overrides all of them.

Synchronization sends `settarget <id>` as the only outbound targeting command. It is generation-owned and single-flight: either a matching `IRE.Target.Set` or `IRE.Target.Info` acknowledges it via `boop.targets.observeGameTarget()`, one timed retry is allowed, repeated requests coalesce, and delayed stale target info cannot roll back an acknowledged target.

### Rage decision

Inside `boop.attacks.plan()`: `selectRage(profile, rage, classKey, standardShieldbreak)` dispatches on mode — `combo`, `tempo`, `aff`, `small`, `big`, `none` — resolving conditional primers and party primers, applying the `ragePoolThreshold` post-spend reserve and the pull reserve, consuming any Triumph free-rage credit, and respecting the global Battlerage cooldown gate in `boop.rage.isGlobalCooldownOpen()`. Rage shieldbreaks and Triumph free-rage actions bypass the pool reserve.

### Telemetry flow

Telemetry reaches `boop.stats` by two independent paths:

1. **Combat lines** — gag triggers → `boop.gag.on*Line` → `boop.stats.on*`. The stats call happens **before** the gag-config early return, so telemetry survives with gags disabled, but only while the `boop` trigger folder is enabled. `boop.stats.onAttackLine` early-returns on `not selfActor` (`boop_stats.lua:1043–1046`), so other players' attack lines feed display only. `boop_gag` is the sole ingestion point for this path.
2. **Character status** — `gmcp.Char.Status` → `boop.stats.onCharStatus()` computes gold and experience deltas, independently of gag and of the trigger folder's enabled state.

Vitals `charstats` have a separate canonical-state path: `boop.onVitals()` performs the only production scan, sends Rage through `boop.rage.onRageObserved()`, and writes Spec to `state.combat.spec`. Planning and context callers read those owned values rather than rescanning GMCP.

### Persistence flow

`boop.db.init()` creates seven sheets and calls `loadConfig`, `loadLists`, `loadStats`. Thereafter: `saveConfig` runs per setting change; `saveList`/`saveWhitelistTags` per list edit; `recordMobXpObservation` per observed mob XP; and lifetime-stat mutations mark `boop.stats.persistence` dirty.

Only one 5-second timer is owned while dirty. Its callback performs one `saveStats`; mutations during or after a flush remain dirty and own one retry. Disable, disconnect, flee, controlled source reload, every stats-rendering entry point, and stats reset flush immediately. An immediate flush invalidates/cancels its timer token so a late callback cannot save a newer generation redundantly. DB failure or unavailability leaves the state dirty. The DB schema and `saveStats` probe remain unchanged; see `PERFORMANCE.md`.

Session-local config keys — `partySize`, `breakShields`, `targetingMode` — are reset to defaults on load and actively deleted from the config sheet.

### UI and config flow

Aliases call `boop.ui.*` functions. Config schema, setters, UI modes, presets, help topics, and screen routes live in `boop_ui_registry.lua` and are attached onto `boop.config` and `boop.ui` by `boop.registry.attachUiConfigRegistries()` with metatable fallbacks. Screens render through shared primitives (`_printHeader`, `_printSection`, `_printFooter`) that `boop_gag` also uses for its colour screens.

---

## 8. Trigger placement and ownership

471 of 513 trigger scripts are a single line calling one of three generic handlers with a spec table. They are a **pattern registry expressed as Mudlet trigger objects**, not code.

| Category | Triggers | Patterns |
|---|---|---|
| `Gag/` | 277 | 503 |
| `Shield/` | 116 | 214 |
| `Rage/` | 102 | 126 |
| `Core/` | 5 | 18 |
| `Gold/` | 5 | 16 |
| `Diag/` | 5 | 5 |
| `IH/` | 2 | 2 |
| `boop_lifecycle/` | 1 | 1 |
| **Total** | **513** | **885** |

All 885 patterns are active simultaneously whenever hunting is enabled.

**Architectural rationale, not a measured result:** moving this pattern data into Lua tables matched by a smaller number of dispatching triggers is expected to be a poor trade, because Mudlet's trigger matching runs in the client's C++ engine while a Lua-side matcher would evaluate several hundred patterns per line in interpreted code. This expectation has not been measured, and `PERFORMANCE.md` records the experiment that would settle it.

Two placement observations:

- **`Gag/<Class>/` misnames its ownership.** Those 277 triggers are the combat-line *ingestion* point and feed `boop.stats` before any gag config is consulted. The folder name describes one consumer, not the concern.
- **Three folder groups sit on a different axis than class**: `Dragon_All_Dragons` (shared across six colours), `Weaponmastery_Two_Handed` / `Sword_and_Shield` / `Dual_Blunt` (spec-scoped, spanning Runewarden, Sentinel, Paladin, and Infernal), and `Necromancy` (Shield only). Additionally, `Gag/Monk`, `Shield/Monk`, and `Rage/Afflictions/Monk` all carry the manifest name `Monk`, and Mudlet's `enableTrigger`/`disableTrigger` operate by name across every match.

---

## 9. External integrations

| Integration | Surface |
|---|---|
| **Mudlet GMCP** | `gmcp.Char.{Vitals,Status,Items.*,Skills.*,Afflictions.List}`, `gmcp.Room.Info`, `gmcp.IRE.{Target.*,Display.*}`. Support announced via `Core.Supports.Add`. |
| **Mudlet DB** | `db:create`, `db:fetch`, `db:add`, `db:update`, `db:delete` over seven sheets. |
| **`demonnicAutoWalker`** | Events `demonwalker.arrived`, `demonwalker.finished`, `demonwalker.move`. Installation is explicit and operator-initiated; runtime paths never install or update it. |
| **`mmp`** | `mmp.currentroom` as a room-id fallback inside `boop_walk.lua` only. |
| **`agnosticdb`** | Optional colour list for the gag palette picker. |
| **Foxhunt** | One-way import of area list data from Foxhunt's `hunting` DB via `boop import foxhunt`. |

---

## 10. Deliberately unusual — do not "fix"

Each of these looks like a smell and is not.

- **A single `boop` global namespace.** Correct for a Mudlet package; there is no module loader to hide behind.
- **No `require()`.** Muddler assembles scripts into a package; ordering is the manifest's job.
- **A hand-ordered `scripts.json`.** Excluded from `tools/sort_manifests.sh` on purpose. Adding a script is a dependency decision.
- **The `boop.attacks.register` guard in `attack_profile_bootstrap.lua`.** Deliberate load-order tolerance that also enables standalone profile testing.
- **Six dragon profiles sharing an identical `standard` block.** Kept duplicated so each profile file stays self-contained and readable: the profile file is where a maintainer looks when fixing a class, and a shared table would move part of a class's definition somewhere else. This is a maintainability judgement, not a claim that no safe deduplication exists.
- **Large files.** Mudlet compiles scripts once at load. A 5,546-line `boop_ui.lua` is a maintainability concern and never a runtime one.

### Supported but not preferred

- **`black_dragon.lua` list-wraps its shield entry** (`shield = { {cmd = ...} }`) where the other five dragons use a bare entry (`shield = { cmd = ... }`). `standardCommand()` accepts both shapes, so this is fully supported and not a correctness bug — but it is an inconsistency, and normalizing it is a sanctioned change.

---

## 11. Divergence from other documentation

| Source | Claim | Reality |
|---|---|---|
| `DESIGN.md` "Proposed Architecture" | Lists `boop.core` and `boop.config` as modules | Neither exists. `boop.config` is a settings table; the coordinator is `boop_runtime` plus `boop_events`. |
| `DESIGN.md` Attack Flow step 6 | "Send via native Mudlet queue or direct send" | Understates it. A queued standard is a whole balance/equilibrium queue replacement through a fixed `BOOP_ATTACK` alias, with generation ownership, quarantine, and grace/recovery budgets. |
| `.planning/codebase/CONCERNS.md` | Three "Known Bugs": room handling writes flat `boop.state.room`; pull completion reads `boop.state.pullState`; walk blockers read flat flags | **All three are fixed.** `onRoomInfo` writes `targeting.*`; `boop.walk.blockedReason()` delegates to `evaluateAllClear`; the flat-state bridge was removed. |
| `.planning/codebase/CONCERNS.md` | "`tests/boop_walk_spec.lua` contains only a disabled placeholder" | Stale — it is 1,570 lines. |
| `.planning/codebase/CONCERNS.md` | Performance bottlenecks section | Omits the two largest findings: `saveStats` call frequency and per-context room-item deep copies. |
| `.planning/codebase/ARCHITECTURE.md` | Diagram shows `boop_events` as a thin GMCP layer | It is also the gold subsystem, the inventory tracker, the prequeue engine, and the tick entry point. |

Both `.planning/codebase/` files have been refreshed alongside this document.
