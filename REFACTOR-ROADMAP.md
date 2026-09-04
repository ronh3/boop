# REFACTOR-ROADMAP.md

An incremental path from the architecture in `ARCHITECTURE.md` to the one in `TARGET-ARCHITECTURE.md`.

Twelve phases plus one optional follow-up. Each is **conceptually isolated, independently testable, and independently revertible**. Phases may touch overlapping files; commits within a phase are **atomic by architectural invariant**, not by module.

Every phase ends with a green full Mudlet Busted run and **no unapproved observable behaviour change**. Intentional behaviour changes are the candidate fixes in §2, each individually approved, isolated, and tested.

---

## 1. Sequencing rationale

1. **Measure first** (Phase 1) — nothing is optimized before it can be observed.
2. **Remove proven waste** (Phase 2) — the two findings that need no structural change.
3. **Extract the combat loop** (Phase 3) — close the three reciprocal pairs caused by Runtime's decision/execution code while leaving Runtime's target lifecycle in place.
4. **Composition, presentation, and persistence seams** (Phase 4) — twelve more pairs, and the composition root.
5. **Draw the remaining boundaries** (Phases 5-7) — room authority, egress, canonical accessors.
6. **Extract feature subsystems** (Phase 8) — **the graph becomes acyclic here**; Phase 9 adds the combatlog seam.
7. **Presentation and data hygiene** (Phases 10-13) — safely deferrable past 1.0.

### Suggested stopping points

- **Phases 1-4** deliver measurement, proven waste removal, the composition root, and fifteen of the original twenty-three reciprocal pairs closed. Phase 3 also adds one approved temporary pair, so stopping after Phase 4 leaves nine pairs and a residual SCC.
- **Phase 8 is the architecture stopping point.** It is where the supported direct-reference graph becomes acyclic and cycle enforcement becomes unconditional. Everything structural is in place.
- **Phases 9-13** are cohesion and data hygiene, safely deferrable past 1.0.

---

## 2. Candidate behaviour fixes

Discovered during the audit. Each is a deliberate, approved change, isolated into its own commit with its own test.

| # | Finding | Status | Lands in |
|---|---|---|---|
| F1 | `boop_init.lua:118` divides `getEpoch()` by 1000, but every `nowSeconds()` treats it as seconds. The `requestCoreSupports` throttle therefore never engages, sending extra `Core.Supports.Add` on rapid reconnects. | **Approved** | Phase 2c |
| F2 | `boop_ui.lua:72`'s `currentClass()` is state-first, defaults to `"unknown"`, and does not lowercase, unlike the runtime and stats implementations. Latent today because `profileReadiness` lowercases internally. | **Approved** | Phase 7 |
| F3 | `boop.onVitals` has no `enabled` guard, so a disabled boop still builds two contexts per prompt. **The guard goes immediately before `boop.tick()`**, so rage observation and the spec parse still update canonical state while disabled. | **Approved** | Phase 2c |
| F4 | `markUnnamableMaulUsed` runs only on the direct dispatch path, never the queued one. | **Investigate only — no behaviour change.** Trigger-driven `boop.rage.onHoundMaulUsed`/`onHyenaMaulUsed` may already cover the queued path, making the util call redundant rather than the queued path broken. Findings recorded in `.planning/codebase/CONCERNS.md`; any change is a separate proposal. | Phase 6 (investigation only) |
| F5 | `boop_events.lua:3146` returns `nil` where every other exit from `schedulePrequeue` returns `false`. | **Approved** | Phase 3 |
| F6 | `init <-> ui` cycle: `boop.bootstrap()` calls `boop.ui.status("ready")` at `boop_init.lua:207-208`. Moving that line into `boop_bootstrap.lua`, which already loads after `boop_ui`, removes the edge. | **Approved** | Phase 4a |

---

## 3. Phases

### Phase 1 — Measurement and architecture guardrails

**Invariant established:** we can measure before optimizing, and boundary erosion fails CI.

**Work**
- New `src/scripts/boop/boop_perf.lua`, manifest position after `boop_util`. Probes and storage per `PERFORMANCE.md` §6.
- `boop.perf.on` reset in `boop_bootstrap.lua`.
- New alias `src/aliases/boop/Diagnostics/Boop_Perf.lua` for `boop perf on|off|show|reset`.
- `tools/check_release_gates.py` gains `--check architecture`, a **convention-based guard** for Boop's direct, statically visible architectural subset. It builds the graph from direct namespaced APIs, known direct top-level APIs, and direct shared-data references resolved to their semantic owners. It deliberately does not claim to analyze arbitrary valid Lua.
- Production rejects architecture-obscuring indirection: aliased or parenthesized/bracket-computed `boop` roots, cross-module function captures, aliased/`_G` `send` and `sendGMCP`, compatibility-forwarder captures, and hidden owned-data mutation through aliases or `rawset`. Fourteen existing path-and-symbol patterns remain narrow documented legacy exceptions; Runtime's exact line-scoped schema-hydration `rawset` is a separate permanent exception. The only sanctioned string dependency is the existing Mudlet event-registration helper's literal `"boop.<symbol>"` callback, which resolves normally and fails closed when unknown.
- **Direct data-resolution semantics** (declared in `ARCHITECTURE.md` §4, not inferred):
  1. longest matching declared prefix wins — `boop.state.targeting.roomObservation` resolves to current owner `boop.runtime` even though `boop.state.targeting` resolves to `boop.targets`;
  2. reads **and** writes both create an edge on the semantic owner;
  3. a visible write by a non-owner is additionally a **mutation violation**; hidden mutation syntax is prohibited rather than followed through data flow;
  4. **fail closed** — a direct Boop reference resolving to neither a known executable, declared owner, nor the shared kernel is a hard error; `boop.state` schema custody is exact-root only and never supplies fallback ownership for a new first-level domain;
  5. defensive initialization (`boop.X = boop.X or {}`) creates no edge and transfers no ownership;
  6. **exported locals are executable, not data** — `boop.ui.printHeader = uiPrintHeader` where the right-hand side is a local function. Without this rule 15 `boop.ui` members are misclassified.
- The check rejects the authoritative hard-forbidden direct directions, duplicate direct exports, new direct outbound sender locations, and new direct internal uses of `boop.tick` or `boop.executeAction`. Attack-profile files are analyzed as `boop.attacks`; only the two exact `boop.attacks.register` definitions are exempted from duplicate-export failure.
- **Staged cycle policy, in force through Phase 7.** The guard reports direct edges, reciprocal pairs, and SCCs as review evidence but does not maintain an occurrence tombstone ledger or formal SCC-history state machine. Unconditional cycle failure begins at Phase 8 acceptance.
- `boop_bootstrap` is the composition root and has zero incoming edges, so it cannot be in a cycle. Graph analysis reports on the other modules by construction rather than by special-casing.
- The historical `96384bc` facts remain documented reference data: 20 modules, 108 edges, 98 executable, 39 owned-data, 29 overlapping, 23 reciprocal pairs, and one SCC of 19. The current Phase-1 tree is 21 modules and 117 edges after exactly nine explicit Perf dependencies.

**Tests** — `tests/boop_perf_spec.lua` covers disabled real probes and both clocks, exception-safe tokens, nesting overflow, normal/reversed/missing/multiple Vitals/Prompt correlation through the real production entry points, incomplete-epoch discard, unrelated/deferred ticks, parse-boundary and deep-copy counters, stale reserved DB rows, bootstrap reset, command routing, and trace independence. `tests/test_architecture_guard.py` covers allowed direct references, prohibited indirection, fail-closed unknown namespaces, ownership writes, exact attack-profile handling, duplicate exports, forbidden edges, outbound/forwarder baselines, and the current graph report.

**Acceptance** — suite green · `boop perf show` renders with zero samples while disabled · the convention guard passes today's graph and fails on prohibited indirection, forbidden direct edges, unresolved direct namespaces, duplicate exports, new sender sites, or new compatibility-forwarder sites · `README.md` and the in-game diagnostics help topic document `boop perf` · no config-dashboard row added.

---

### Phase 2 — Hot-path waste and stats persistence

**Invariant established:** the identified avoidable hot-path work below is removed, and no synchronous DB write occurs at combat frequency.

**2a — runtime waste**
- `ensureState()` fast path: a cheap schema-version sentinel plus top-level domain integrity validation (13 `type()` checks) on normal calls, with **full defaults hydration and the `operationModelVersion` migration only on validation failure**. Deleting a domain at runtime must still repair it.
- Non-copying `roomReadinessSnapshot` for the readiness path; the full `roomObservationSnapshot` is retained for diagnostic callers.
- Drop the idle `deepCopy(state.gold.operation)`.
- Short-circuit `operationHolds` when `blockersByOwner` is empty.
- Single `charstats` parse per Vitals event into `state.rage.amount` and `state.combat.spec` (M3).

**2b — stats persistence (P1)**
- Replace `persistLifetime()`'s immediate `boop.db.saveStats()` with a dirty flag plus a **5-second coalesced flush** on a timer that exists only while dirty.
- **Immediate flush on:** boop disable (`onEnabledChanged(false)`), disconnect (`sysConnectionEvent`), flee and shutdown paths, any stats rendering (`boop.stats.show*`), controlled reload or teardown, and any operation where exact persisted state must be observed (`boop stats reset`, config export/import, `boop get`/`boop set` of lifetime values).

**2c — approved fixes** — F3 (guard immediately before `boop.tick()`) and F1. Separate commits, each with its own test.

**Tests protecting it** — `boop_state_contract_spec`, `boop_runtime_spec`, `boop_tick_spec`, `boop_prequeue_spec`, `boop_event_transitions_spec`, `boop_stats_spec`, `boop_persistence_spec`, `boop_db_spec`, `boop_rage_ingestion_spec`.

**New tests** — `ensureState` repairs a domain deleted at runtime · the migration still runs when the sentinel is stale · `readinessSnapshot` returns identical values for seeded room observations · `context().rage.amount` matches the pre-change parse · rage observation and spec still update while boop is disabled · lifetime totals are exact after each immediate-flush trigger · a dirty flush fires after the interval with no explicit save · `saveStats` calls per simulated retarget drop from 3 to 0 · the support throttle engages within `minInterval`.

**Acceptance** — every existing spec passes unchanged · measurable drop in `context` total time and in `db.saveStats` calls per minute under an identical seeded workload · no change to any command boop sends.

**Out of scope** — changing tick dispatch order or coalescing ticks.

---

### Phase 3 — Break the runtime/decision cycles

**Invariant established:** `boop.runtime` no longer owns combat decision/execution and contains zero references to Attacks, Safety, Walk, or Gag. Runtime permanently retains the canonical composite `context()` projection and its current target/Standard lifecycle responsibilities. Combat has one home and one gate evaluator. **This is the centrepiece of the roadmap.**

**3a** — move `step`, `applyEffects`, `tickStep`, and `promptStep` from `boop_runtime.lua`; `boop.attacks.execute`; and Events' `canAct`/`canUseRage` implementations into new `boop_combat.lua`. `boop.runtime.context()` does **not** move: Runtime builds canonical context and Combat consumes it. Detailed Standard terminalization, grace, evidence, candidate correlation, retry/recovery, and lifecycle hooks also remain in Runtime/current ownership until the later Standard phase.

**3b** — collapse the three duplicated gate sequences into one `boop.combat.evaluateGates(intent)` returning `{allowed, code, label}`, consumed by tick, prequeue, and prequeue-refresh. Removes the duplicated `planContext` rebuild at `boop_runtime.lua:4012-4036`. Folds F5.

`boop.tick` remains an Events-owned room/orchestration facade through Phase 7. It first claims and may apply pending room work, preserving the existing recursive/re-entrant behavior, and then delegates the combat decision portion to `boop.combat.tick`. Prequeue scheduling, dispatch timing, target synchronization, and refresh entry points likewise remain in Events while consuming Combat's gate evaluator.

Moving `applyEffects` intact creates an approved temporary `events ↔ combat` seam. Combat calls the Events-owned `boop.maybeFlushPendingGold` and `boop.flushPendingGold`; Events calls Combat. Phase 8 Gold extraction and facade retirement remove the pair. No callback, dependency injection, or forwarding indirection is introduced to hide it.

**Tests protecting it** — `boop_tick_spec`, `boop_prequeue_spec` (1,255 lines — the primary contract), `boop_runtime_spec`, `boop_planner_spec`, `boop_shields_spec`, `boop_interrupt_spec`, `boop_diag_spec`, `boop_event_transitions_spec`.

**New tests** — a table-driven spec with independent expected tick/prequeue verdicts across diag hold, Gold pending/operation, operation lock, shielded target, no target, flee threshold, Standard pending, readiness failure, and unavailable planning; explicit tests for legitimate refresh differences; room-before-Combat delegation; canonical Runtime context and bare Attacks fallback; limiter timings; F5; and a guardrail assertion that `boop_runtime.lua` references none of `boop.attacks`, `boop.safety`, `boop.walk`, or `boop.gag`.

**Acceptance** — identical command output across the suite · measured graph moves from 21 to 22 modules and from 23 to **21 reciprocal pairs**: `runtime ↔ attacks`, `runtime ↔ safety`, and `runtime ↔ walk` close, while temporary `events ↔ combat` is added · `runtime ↔ targets` remains for Phase 5 · `events ↔ targets` remains for Phase 8 · the SCC is expected and permitted to grow from 19 to 20 because Combat joins the staged cyclic component · no SCC-monotonicity criterion applies before the Phase-8 DAG milestone · edge counts come only from measured guard output.

---

### Phase 4 — Composition root, presentation seam, and persistence port

**Status: implemented in `0.1.495` and review-corrected in `0.1.495.1`.** The measured Phase-4 tree has 23 modules, 127 unique dependency directions (119 executable/API, 41 owned-data, 33 overlapping), nine reciprocal pairs, and a residual SCC of size 20. All twelve named pair closures below are absent. Reviewed forbidden edges fell from fourteen to two, reviewed mutation edges from fourteen to eight, and legacy indirection exceptions from fourteen to four.

**Invariant established:** package composition happens in one place; presentation primitives are shared without a dependency on `boop.ui`; persistence exchanges plain tables; and **no function is reachable under `boop.state`**.

This phase closes **twelve** of the original twenty-three reciprocal pairs. It does **not** produce a DAG — Phase 3 leaves 21 current pairs, and nine survive after this phase until the remaining boundary work, including the approved temporary pair, completes at Phase 8.

**4a — composition root (`init ↔ ui`, `events ↔ init`).** F6 approved. Move the `boop.ui.status("ready")` notification out of `boop_init.lua:207-208`, and relocate the wiring body of `boop.bootstrap()` — the ordered `init` calls into db, state, afflictions, rage, ih, triggers, skills, stats, and `boop.events.register()` — into `boop_bootstrap.lua`, the composition root. `boop_init.lua` keeps `boop.defaults`, the trigger-folder helpers, and the GMCP support announcement. **Observable package-load behaviour is preserved**: first boot runs the same sequence in the same order and emits the same ready message at the same point; an already-bootstrapped package reload performs only the composition root's generation-sensitive IRE reconciler and UI/Registry refresh after the existing reload flush/resets.

Also in 4a: **`boop_init` writes `boop.skills.desiredGroups`**, another module's owned data — a mutation violation. Replace the direct write with a `boop.skills.setDesiredGroups()` ingestion API.

**4b — retire `boop_state.lua`.** The file defines `boop.state.init()`, a service function under the data-only state tree, and performs a **second** registry attachment.

- **`boop.state.init()` is deleted.** Its two responsibilities separate: hydration becomes a direct `boop.runtime.ensureState()` call from the composition root, and registry attachment becomes composition-root wiring.
- **Both legacy registry-attachment sites are removed** — the call at the tail of `boop_ui_registry.lua` and the one inside `boop.state.init()`. `boop.registry.attachUiConfigRegistries()` is invoked only from `boop_bootstrap.lua`: once on first boot and once to refresh generation-sensitive bindings on a mid-session package reload.
- **`boop_init.lua:164`'s `boop.state.init()` call** is replaced by the composition root's `boop.runtime.ensureState()`.
- **`tests/support/boop_test_helper.lua:168`** migrates from `boop.state.init()` to the same real initialization path the package uses, so the helper and production share one entry point.
- `boop_state.lua` is removed from `src/scripts/boop/scripts.json`.

**4c — registry independence (`ui ↔ ui_registry`).**

- `boop_ui_registry.lua` declares **data** — config schema, modes, presets, help topics, screen routes — plus a **registration API** (`boop.registry.defineConfigSetter(key, handler)` and equivalents). It references no other module.
- `boop.ui` **registers its handlers into** the registry rather than the registry naming them. This inverts the 48 `boop.ui.*` references currently living inside registry setter closures.

**4d — presentation seam (`gag ↔ ui`, `stats ↔ ui`).** Extract `boop_render.lua`:

- `printHeader`, `printSection`, `printRow`, `printFooter`, `computeLabelWidth`, and the sectioned-layout helpers move from `boop_ui.lua` to `boop.render`. A justified seam, not a size split: it is consumed by `ui`, `gag`, and later `stats.report`, and it is what lets the latter two render without depending on `ui`.
- That closes 46 of 47 `stats -> ui` references and 10 of 22 `gag -> ui` references.
- The remaining 12 `gag -> ui` references (`_setScreen`, `consumeConfigReturnScreen`, `config`) come from the gag **colour-picker screens**, which are config screens that happen to be about gag. They move to the UI layer; `boop.gag` keeps palette resolution and line rendering.
- The last `stats -> ui` reference was a dashboard click handler calling `boop.ui.setEnabled(true)`. It now seeds the public `boop on` command without executing it, preserving the operator workflow without a Stats-to-UI dependency.

**4e — dispatcher relocation (`runtime ↔ util`, `rage ↔ util`, `gag ↔ util`, `targets ↔ util`).** Create `boop_wire.lua` and move the action dispatcher, Rage dispatcher, `prependAssist`, `markUnnamableMaulUsed`, `normalizeDispatchOptions`, and `dispatchAuthorityCurrent` into it. The command separator is now `boop.wire.separator`; list persistence has no separator field.

**G3, mandatory:** `boop.wire` must take `targetId` as a **parameter** from its caller rather than reading `boop.state.targeting.currentTargetId` (`boop_util.lua:346`). Without this the pair simply re-forms as `wire ↔ targets` in Phase 6 once targets routes `settarget` through wire. This is already implied by the transport-boundary definition; it is called out because it is easy to carry across unchanged. `boop.executeAction` is retained as an external forwarder; internal callers move to `boop.wire.*` in this phase, since this is the extraction that creates the owner. Phase 6 completes the Wire invariant.

**4f — persistence ports (`db ↔ stats`, `db ↔ targets`).** Two applications of the same pattern:

- `boop.db.loadStats()` returns a table for the caller to apply rather than writing `boop.stats.lifetime.*` and `boop.stats.mobXp` directly; `boop.db.saveStats(table)` takes one. Removes all 37 `db -> stats` references without requiring the stats/report split, which stays in Phase 10.
- **G2:** `boop.db.loadLists()` likewise returns a table rather than writing `boop.lists` directly. Same inversion, same fix; it was missed originally because `boop.lists` ownership was undeclared.

**Tests protecting it** — `boop_ui_spec`, `boop_ui_registry_spec`, `boop_menu_wiring_spec`, `boop_gag_spec`, `boop_stats_spec`, `boop_persistence_spec`, `boop_db_spec`, `boop_lifecycle_spec`, `boop_assist_spec`, `boop_prequeue_spec`, `boop_tick_spec`, and the whole suite via the migrated test helper.

**New tests** — first package boot produces the same sequence and ready output while mid-session reload refreshes generation-sensitive composition without repeating startup · registry data is complete with no `boop.ui` edge from the registry · every screen renders identically through `boop.render` · gag colour screens behave identically from their new home · the Stats dashboard enable row seeds `boop on` without executing it · `boop.db.loadStats()` returns a table and mutates no `boop.stats` field · **no function value is reachable under `boop.state`** · the test helper's initialization path matches production's.

**Acceptance achieved** — identical observable behaviour including package-load output · twelve reciprocal pairs closed (`init ↔ ui`, `events ↔ init`, `db ↔ init`, `ui ↔ ui_registry`, `gag ↔ ui`, `stats ↔ ui`, `runtime ↔ util`, `rage ↔ util`, `gag ↔ util`, `targets ↔ util`, `db ↔ stats`, `db ↔ targets`) · zero mutation violations remaining in `boop_init` · `boop_state.lua` no longer exists · measured SCC evidence reported without a monotonicity gate · **the graph is not yet acyclic; staged enforcement continues**.

---

### Phase 5 — Room authority and admission control

**Implementation candidate (`0.1.496`)** — Room and Locks are extracted for review; `runtime ↔ targets` and `events ↔ walk` are mechanically closed. The packaged Mudlet 4.20.1 suite is green; acceptance remains pending review.

**Invariant established:** room-generation authority and operation admission are each owned by one module with one set of invariants, and `boop.state` is a pure data tree behind the `boop.runtime` API.

**Work** — extract `boop_room.lua` (observation, response fences, applications, movement intent, `validateRoomSourceAuthority`, `currentRoomSourceAuthority`) and `boop_locks.lua` (blockers, operation locks, priority, `operationHolds`/`shouldHold`, interrupt admission tiers) from `boop_runtime.lua`.

**Tests** — `boop_runtime_spec`, `boop_state_contract_spec`, `boop_event_transitions_spec`, `boop_walk_spec`, `boop_gold_spec`, `boop_interrupt_spec`, `boop_trace_spec`.

**New tests** — room-authority validation and lock admission each exercised without loading the combat loop · **no function value is reachable under `boop.state`**.

**Acceptance** — identical behaviour · `boop.runtime` depends only on its allowed state/authority foundations · **`events ↔ walk` closes**, since `boop.requestRoomItemsOnce` moves to `boop.room` and `boop_walk` migrates with it · **`runtime ↔ targets` closes here**, when `beginConnectionLifecycle`, `clearAttackIntent`, and the remaining target-lifecycle seams migrate to their approved owners · forbidden-edge list extended. SCC size is measured and reported, not ratcheted before Phase 8.

---

### Phase 6 — Complete the Wire invariant

**Invariant established:** `boop.wire` is the **only** production caller of `send()` **and `sendGMCP()`**. No second sanctioned sender.

**Work** — `boop_wire.lua` already exists from Phase 4d with the dispatcher in it. Add the outbound registration and observation machinery, then migrate **every one of the fourteen remaining `send()` sites**:

| Site | Command |
|---|---|
| `boop_events.lua:135` | gold queue command |
| `boop_events.lua:487` | GMCP request flush |
| `boop_targets.lua:541` | `settarget <id>` |
| `boop_targets.lua:563` | `pt Target: <id>.` |
| `boop_targets.lua:930`, `:937`, `:939` | party-share packets |
| `boop_safety.lua:66` | flee `clearqueue all` |
| `boop_rage.lua:844` | affliction callout |
| `boop_runtime.lua:2642` | standard-revoke `clearqueue all` |
| `boop_ui.lua:1586` | pack test |
| `boop_ui.lua:1746` | leap `clearqueue all` |
| `boop_ui.lua:1757` | queued interrupt command |
| `boop_ui.lua:2206` | pull chain |

Wire exposes distinct entry points per `TARGET-ARCHITECTURE.md` §4 — owned combat dispatch, unowned utility command, queue control, channel text, protocol request — so migration does not force unrelated commands through the standard-dispatch lifecycle.

Also route the **eight `sendGMCP()` sites** through Wire — `boop_init.lua:140-143`, `boop_skills.lua:42`, `:51`, `:68`, and `boop_events.lua:486` — so protocol requests and game commands share one audited egress point. And extract `boop_standard.lua` (dispatch generations, baseline, candidate disposition, grace, retry, terminals, mutation barrier).

**Narrow the `send(` and `sendGMCP(` guardrails to `boop_wire.lua` alone.**

Carries the **F4 investigation** (no behaviour change): determine whether the trigger-driven maul-readiness handlers already cover the queued path, and record the finding.

**Tests** — `boop_prequeue_spec`, `boop_assist_spec`, `boop_tick_spec`, `boop_interrupt_spec`, `boop_pull_spec`, `boop_gold_spec`, `boop_safety_spec`, `boop_target_call_spec`, `boop_whitelist_share_spec`, `boop_rage_ingestion_spec`, `boop_event_transitions_spec`, `boop_trace_spec`.

**Acceptance** — byte-identical wire output for every spec · exactly one `send(` and one `sendGMCP(` in production source · measured SCC evidence reported without a monotonicity gate. (The `util` reciprocal pairs were closed in Phase 4 when the dispatcher moved; this phase completes the egress invariant.)

---

### Phase 7 — Canonical accessors and the util leaf

**Invariant established:** one implementation per shared concept, and `boop.util` depends only on `boop.theme`. **Timing-neutral by construction** — nothing in this phase changes when any code runs.

**Work**
- Extract `boop_trace.lua` from `boop_util.lua`.
- Publish `boop.runtime.currentRoomId()` (normalized GMCP), `currentClass()`, and `currentSpec()` — **on the API namespace, not on `boop.state`**.
- Single `copySourceAuthority`, `deepCopy`, `nowSeconds`.
- Migrate call sites in `targets`, `rage`, `ui`, `walk`, `events`, `attacks`, `stats`.
- Adopt F2.
- **`mmp.currentroom` stays in `boop_walk.lua`**, commented as a mapper fallback rather than game state.

**Tests** — `boop_event_transitions_spec` (4,050 lines), `boop_walk_spec`, `boop_lifecycle_spec`, `boop_rage_ingestion_spec`, `boop_ui_spec`, `boop_trace_spec`.

**New tests** — `currentRoomId()` agrees across modules for GMCP-only, state-only, and disagreeing-state cases · the `mmp` fallback still applies when `Room.Info` is absent.

**Acceptance** — no change to sent commands · exactly one definition per accessor · `boop_walk.lua` is the only file referencing `mmp` · `boop_util.lua` is a graph leaf apart from `boop.theme`.

---

### Phase 8 — Feature subsystem extraction — **the acyclic milestone**

**Invariant established:** each stateful feature machine owns its own state domain in its own module, **and the module dependency graph contains no non-trivial SCC**.

This phase closes the last seven reciprocal pairs: six surviving baseline pairs plus the temporary Phase-3 `events ↔ combat` seam. They depend on cohesive Gold, Inventory, and Interrupt extraction and retirement of the Events combat/prequeue facades; the stats/targets data pair is pulled forward so the milestone actually holds:

| Pair | Closed by moving |
|---|---|
| `attacks ↔ events` | `boop.getWieldedItem` → `boop.inventory` |
| `events ↔ safety` | `boop.clearGoldQueueIntent` → `boop.gold` |
| `events ↔ ui` | `boop.clearGoldQueueIntent`, `boop.displaceGoldQueueIntent` → `boop.gold` |
| `events ↔ runtime` | `boop.tryVenomConfusionDiag` → `boop.interrupt` |
| `events ↔ targets` | retire the Events-owned `boop.tick`/prequeue facades and migrate their target-facing callers to final owners |
| `events ↔ combat` | `boop.maybeFlushPendingGold` and `boop.flushPendingGold` → `boop.gold`; retire the Events Combat facade |
| `stats ↔ targets` | **G1**, two parts — see below |

**G1** is a data pair, pulled forward from Phases 10 and 12 so that Phase 8 genuinely produces a DAG:

- delete the single `boop.state.targeting` read at `boop_stats.lua:1501`, passing the target id in instead. Already required by "stats observes, never controls";
- move the two `boop.stats.formatMobXp` calls at `boop_targets.lua:1597` and `:1643` out of list rendering into the report layer.

Internal callers migrate **with** each extraction, not before it — no caller is moved twice.

**Work** — three independent commits: `boop_gold.lua` (pipeline from `boop_events` plus pack quarantine from `boop_runtime`); `boop_interrupt.lua` (from `boop_ui` plus interrupt terminals and diag evidence from `boop_runtime`); `boop_inventory.lua` (from `boop_events`).

**Tests** — `boop_gold_spec`, `boop_gold_retry_spec` (1,799 lines), `boop_interrupt_spec`, `boop_pull_spec`, `boop_diag_spec`, `boop_diag_timeout_spec`, `boop_wield_spec`, `boop_trace_spec`.

**Acceptance** — trace output byte-identical for the gold flows the trace spec asserts · no timer creation or lock mutation remains in any `boop_ui*` file · `boop_events.lua` contains only `on*` handlers · **the supported graph contains no non-trivial SCC and `--check architecture` switches to unconditional cycle failure** · no internal caller of `boop.tick` or `boop.executeAction` remains.

**New tests** — a guardrail test asserting the supported direct-reference graph has no non-trivial SCC.

**Risk** — the interrupt extraction is the highest-behavioural-risk move in the roadmap. Land it alone, with a live session pass over `diag`, `matic`, `fly`, `leap`, and one `pull` round trip.

---

### Phase 9 — Combat event ingestion seam

**Invariant established:** combat-line telemetry has a source that is not the display filter.

**Behaviour seam only. No trigger-folder renaming in this phase.**

**Work** — extract `boop_combatlog.lua`, the parse half of `boop_gag.lua` (actor and target resolution, duplicate suppression, damage/crit/balance correlation, kill lines), publishing through the fixed ordered dispatch defined in `TARGET-ARCHITECTURE.md` §5: telemetry first, rendering second. `boop.gag` and `boop.stats` become consumers. Trigger files keep calling their current entry points, forwarded to `boop.combatlog`.

**Tests** — `boop_gag_spec` (841 lines), `boop_stats_spec`, `boop_trace_spec`.

**New tests** — telemetry is recorded with all gag options off · gag rendering is unchanged with telemetry disabled · dispatch order is telemetry-before-rendering · no `gag -> stats` edge in the graph.

**Acceptance** — identical gag output and identical stats accumulation for every replay case in the suite.

---

### Phase 9b — Trigger ownership rename *(optional, atomic follow-up)*

**Invariant established:** trigger folder names match the concern that owns them.

**Work** — rename the `src/triggers/boop/Gag/` scope to reflect combat-event ingestion, updating the class-local manifests. Pure renaming; no Lua behaviour change.

**Tests** — `python3 tools/check_release_gates.py --check manifests`, plus the full suite, since trigger membership is what breaks if a manifest is wrong.

**Acceptance** — built package contents identical apart from names · manifest check green.

Skippable without affecting any later phase.

---

### Phase 10 — Stats decomposition

**Invariant established:** stats observes and never controls; persistence exchanges plain tables.

**Work** — `boop_stats.lua` becomes model and collection only; new `boop_stats_report.lua` takes all `show*` rendering and `boop stats` routing; `boop.db.loadStats()` returns a table the caller applies and `saveStats(table)` takes one.

The persistence *frequency* fix landed in Phase 2b and the plain-table port in Phase 4f; this phase completes the model/presentation split.

**Tests** — `boop_stats_spec` (900 lines), `boop_persistence_spec`, `boop_db_spec`, `boop_menu_wiring_spec`, `boop_ui_spec`.

**New tests** — `boop_db` contains no `boop.stats.` reference · `boop_stats` makes no `boop.ui.*` call.

**Acceptance** — identical `boop stats` output · `boop_stats` makes no `boop.ui` or `boop.render` call from model code. (Both reciprocal pairs were closed in Phase 4; this phase completes the ownership split.)

---

### Phase 11 — Command routing and UI

**Invariant established:** the S1 command surface has one identifiable, testable implementation.

**Work** — extract `boop_commands.lua` (alias-facing `*Command` parsers, routers, and config setters) from `boop_ui.lua`, leaving screens. Rendering primitives already left in Phase 4d. Handler registration follows the Phase 4c inversion: `boop.commands` registers into `boop.registry`. Replace the five raw `db:` calls in `boop_ui.lua` with `boop.db` calls.

`boop.commands.*` is **S2**; the S1 contract remains alias syntax and semantics.

**Tests** — `boop_ui_spec` (1,304 lines), `boop_ui_registry_spec`, `boop_menu_wiring_spec`.

**New tests** — every alias entry point resolves to a `boop.commands.*` function · a contract test enumerating the S1 alias list with its expected semantics.

**Acceptance** — identical screen output for every spec · no raw `db:` call outside `boop_db.lua`.

---

### Phase 12 — Targeting decomposition

**Invariant established:** list data, share transport, and per-tick selection are separately owned.

**Work** — extract `boop_lists.lua` (whitelist, blacklist, tags: data, ordering, membership, persistence calls) and `boop_share.lua` (party packet encode/decode, sender trust, pending application) from `boop_targets.lua`. List rendering follows the Phase 11 command/UI boundary.

**Tests** — `boop_targets_spec`, `boop_whitelist_share_spec`, `boop_target_call_spec`, `boop_ui_spec`, `boop_persistence_spec`.

**Acceptance** — identical list rendering and share protocol output · `boop.targets` no longer references `boop.db`.

---

### Phase 13 — Elemental profile aliases

**Invariant established:** identical class data has one definition.

**Work** — add `boop.attacks.registerAlias(newClass, existingClass)` resolved lazily at `flushPendingProfiles()`. Each `*_elemental_lady.lua` becomes a one-line alias to its `_lord` counterpart. Normalize `black_dragon.lua`'s shield shape.

**Dragon standard blocks stay duplicated by decision** — see `ARCHITECTURE.md` §10.

**Tests** — `boop_profile_matrix_spec`, `boop_profiles_spec`, `boop_rage_contract_spec`, `boop_openers_contract_spec`, `boop_attack_profile_load_order_spec`.

**New tests** — an alias resolves after `flushPendingProfiles()` regardless of file load order · `registerAlias` to an unknown class fails loudly rather than registering an empty profile.

**Acceptance** — every profile spec passes unchanged · zero change to any generated command · each profile file still `dofile`s standalone, as the matrix spec requires.

---

## 4. Deferred, with reopening evidence

| Deferred | Reopens when |
|---|---|
| Vitals/prompt tick coalescing | measured `prompt_total` > 8 ms or `tick` > 3 ms (`PERFORMANCE.md` §5B) |
| Class-scoped trigger enabling | the A/B shows a material difference **and** the mapping risk is accepted (`PERFORMANCE.md` §5A) |
| F4 maul-marking change | the Phase 5 investigation shows the queued path is genuinely uncovered |
| Dragon standard-block dedup | a change must be applied to all six dragon files more than once |
| Stats state moving into `boop.state` | a bug is traced to stats state living outside the canonical tree |
| Further `boop_ui` screen splitting | Phase 10 leaves screens genuinely incohesive rather than merely large |
