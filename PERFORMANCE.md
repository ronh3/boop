# PERFORMANCE.md

The hot-path model, a performance budget, and the instrumentation needed to replace the budget's guesses with measurements.

> **No measurements have been taken.** Every finding below is static analysis, and every threshold in §4 is a starting hypothesis. The classifications describe confidence in the *shape* of a cost, not an observed timing. Phase 1 of `REFACTOR-ROADMAP.md` exists to fix that before anything is optimized.

Source verified against commit `96384bc` (package version `0.1.490`).

---

## 1. The hot-path model

Work in boop divides by how often it runs.

| Cadence | What runs | Bounded by |
|---|---|---|
| **Per line of game output** | 885 Mudlet trigger patterns; on a match, one of three generic handlers | game output rate x pattern count |
| **Per prompt** | `boop.onPrompt` -> `promptStep` -> often `boop.tick`; separately `gmcp.Char.Vitals` -> `boop.onVitals` -> `boop.tick` | prompt rate (assumed 2-4/sec in combat) |
| **Per room change** | `Room.Info` + `Char.Items.List` fence and application; denizen list rebuild | movement rate |
| **Per retarget** | `targets.setTarget`, three `incrementCounter` calls, each flushing stats to SQLite | kill rate |
| **Per kill** | `recordKill`, mob XP observation, gold and experience deltas | kill rate |
| **Per balance recovery** | `onBalanceUsed` -> `schedulePrequeue` -> timer -> `prequeueStandard` | balance rate |

The per-line tier is the only one whose cost is unbounded in the codebase's own growth: it scales with the number of supported classes.

---

## 2. Per-prompt work as written

`boop.onVitals()` has no `enabled` guard and calls `boop.tick()` unconditionally. `boop.onPrompt()` guards on `enabled`, builds a context for `promptStep`, then calls `boop.tick()` again if `promptStep` returns `runTick`.

Assuming `gmcp.Char.Vitals` fires alongside each prompt — **an assumption Phase 1 must confirm** — each prompt performs two full tick decisions. `boop.canAct()`'s 0.4 s limiter suppresses the second *dispatch*, but not the decision work behind it. That is waste, not a correctness bug.

### `boop.runtime.context()`

Tracing the call chain, `context()` invokes `boop.runtime.ensureState()` **nine times**:

| Path | Call |
|---|---|
| `context()` itself (`boop_runtime.lua:3736`) | 1 |
| `readinessSnapshot` -> `lifecycleSnapshot` -> `lifecycleState` | 2 |
| `readinessSnapshot` -> `roomObservationSnapshot` -> `roomObservationState` | 3 |
| `readinessSnapshot` -> `currentRoomSourceAuthority` -> `roomObservationState` | 4 |
| ... -> `validateRoomSourceAuthority` -> `roomObservationState` | 5 |
| `standardPending` -> `activeStandard` -> `standardQueueState` | 6 |
| `standardSnapshot` -> `standardQueueState` | 7 |
| `operationLockSnapshot` -> `currentOperationLock` | 8 |
| ... -> `sortedOperationRecords` -> `sortedBlockerRecords` | 9 |

Each `ensureState()` iterates 13 domains against roughly 119 default keys, checking `current[key] == nil` — approximately 1,100 hash lookups per `context()`, multiplied by two to four contexts per prompt.

Additionally, per context:

- `roomObservationSnapshot()` deep-copies `acceptedItems`, `fenceQueue`, `lastCompletedFence`, and `activeApplication` — the last of which itself holds a deep copy of the room item list. This scales with room population. `readinessSnapshot()` then reads four scalar fields from the result and discards the rest.
- `deepCopy(state.gold.operation)` runs even when gold is idle.
- `standardSnapshot()` deep-copies the standard operation.
- `gmcp.Char.Vitals.charstats` is scanned with a per-entry `string.match` to extract Rage.
- Roughly twelve nested sub-tables are allocated.

`tickStep` then calls `boop.runtime.operationHolds()` five times consecutively (`target`, `combat`, `queue`, `gold`, `walk`) and four more times in the gold branch. Each call runs `sortedOperationRecords()` -> `sortedBlockerRecords()`, which invokes `ensureState()`, allocates a fresh record table per blocker, and calls `table.sort` — even when `blockersByOwner` is empty, which is the normal hunting case. `prequeueStandard` pays four, `schedulePrequeue` three, `refreshPrequeuedStandard` four.

`tickStep` also rebuilds a near-complete second copy of the context (`boop_runtime.lua:4012-4036`) whenever the chosen target differs from `context.target.id`, linear-scanning `denizens` to resolve the name — that is, on essentially every retarget.

---

## 3. Findings

### Probable optimization opportunity

Clear waste with a behaviour-preserving fix. Measure to size it, then fix.

**P1 — `boop.db.saveStats()` on the combat path.** The function performs 13 `db:fetch` queries plus up to 13 `db:update` writes. It is called from `persistLifetime()` inside `addGold`, `addExperience`, `incrementCounter` (every counter except `roomMoves`), and `recordKill`. Because `boop.stats.onTargetSet` calls `incrementCounter` three times — `retargets`, `abandoned`, `targets` — **a single retarget triggers 39 synchronous indexed SELECTs plus writes**, on the most frequent event in bashing.

The `stats` sheet declares `_unique = { "name" }`, so each lookup is indexed rather than a scan. Even so, this is the only place in boop that performs synchronous I/O at combat frequency, and it is the most likely cause of any observed client hitching. Addressed in Phase 2.

**P2 — Room-item deep copies in `readinessSnapshot()`.** Copy work that scales with room population, performed on every context build and discarded immediately.

**P3 — Duplicate ticks per prompt.** Full decision work runs twice; the second result is discarded by the `canAct` limiter. Measured in Phase 1; the fix is deferred — see §5.

**P4 — `ensureState()` re-validating 13 domains on every call.** After bootstrap, nothing is ever missing.

### Worth measuring

Plausibly significant; cannot be settled by reading the code.

**M1 — 885 regex patterns across 512 triggers, all enabled together.** Gag 277 triggers / 503 patterns, Shield 116 / 214, Rage 102 / 126. For any given character roughly 95% of the pattern set is class-irrelevant, yet every pattern is evaluated against every line of game output. This runs in Mudlet's C++ engine and is invisible to Lua profiling. It is the largest *unbounded* cost in the system: it grows with every class boop supports. Deferred — see §5.

**M2 — timer churn from `canAct` and `canUseRage`.** Each creates a `tempTimer` per successful call (0.4 s and 0.6 s respectively). At combat cadence that is a steady trickle of Mudlet timer objects. Both are also query-shaped names with mutating side effects, which is a clarity problem independent of cost.

**M3 — `charstats` scanned three times per Vitals event** — once by `boop.attacks.getRage()` called from `onVitals`, once by the Spec extraction loop in `onVitals`, and once inside `context()`. Individually cheap. Worth doing regardless, because parsing once into `state.rage.amount` and `state.combat.spec` is also the correct architecture.

### Likely negligible — already fast enough

Documented so that a future session does not spend effort here.

| Item | Why it is fine |
|---|---|
| `boop.targets.choose()` | Bounded by room denizen count (typically under 20) times whitelist length, using simple string comparisons |
| `updateRoomItems`, `addRoomItem`, `removeRoomItem` | Linear over room contents, and only on room GMCP events |
| `boop.gag.onPrompt()` | Two config checks and an optional flush |
| `boop.attacks.plan()`, `selectRage()` | Table walks over a single class profile of tens of entries; no allocation storms |
| `boop.trace.log()` | Early-returns on `traceEnabled`; the 100-entry `table.remove(buf, 1)` trim only runs while tracing is on |
| `boop.executeAction()` | A split, a few string operations, and `send()` |
| **Module file size** | Mudlet compiles scripts once at load. A 5,546-line `boop_ui.lua` is a maintainability concern and never a runtime one. |

### Architectural risk if boop grows

- Trigger count is linear in supported classes with no sharding mechanism.
- `boop_events` absorbs every new asynchronous flow, so each feature widens the module that owns the tick.
- Stats detail tables (`areas`, `abilities`, `targetStats`, rage breakdowns) are unbounded per scope over a long session.
- `context()` is a single wide struct handed to every consumer; each new field is paid for by every caller on every tick.

---

## 4. Performance budget

**These are hypotheses.** They are derived from a model, not from measurement, and Phase 1 replaces them with observed values.

Mudlet's UI and Lua share one thread, so per-prompt work is time the client cannot spend rendering. At an assumed 2-4 prompts per second, holding boop under roughly 5% of wall time means 12-25 ms of Lua work per second.

| Measure | Target | Warn | Investigate |
|---|---|---|---|
| `prompt_total` — boop Lua per prompt | < 3 ms | **8 ms** | 20 ms |
| `tick` duration | < 1 ms | **3 ms** | 10 ms |
| `context` build | < 0.3 ms | 1 ms | 3 ms |
| `targets.choose` | < 0.1 ms | 0.5 ms | 2 ms |
| `attacks.plan` + `selectRage` | < 0.3 ms | 1 ms | 3 ms |
| Any single GMCP handler | < 1 ms | 3 ms | 10 ms |
| `db.saveStats` single call | < 1 ms | 5 ms | 15 ms |
| `db.saveStats` calls per minute while hunting | < 10 | 60 | 200 |
| `ticks_per_prompt` | 1.0 | 1.5 | 2.0 |

The two bolded thresholds are the explicit trigger conditions for reopening tick coalescing (§5, deferred item B).

---

## 5. Deferred optimizations

Both are real, both are measurement-gated, and neither belongs in the pre-1.0 roadmap.

### A. Class-scoped trigger enabling

**The opportunity.** Enabling only the active class's Gag, Shield, and Rage trigger folders would take roughly 843 of 885 patterns out of per-line evaluation for a default-configuration character.

**Why it is deferred.** The risks are structural, not incidental:

- **Manifest name collision.** `Gag/Monk`, `Shield/Monk`, and `Rage/Afflictions/Monk` all carry the manifest name `Monk`. Mudlet's `enableTrigger`/`disableTrigger` operate by name across every match, so per-category control is impossible without renaming roughly 100 manifests. Scoping is all-or-nothing per class name.
- **The class-to-folder map is not one-to-one.** `Dragon_All_Dragons` is shared across six colours; `Weaponmastery_Two_Handed`, `Sword_and_Shield`, and `Dual_Blunt` are spec-scoped and span Runewarden, Sentinel, Paladin, and Infernal; `Necromancy` exists only under Shield; and `General`, `Combat`, and `Mobs` are class-agnostic and must stay enabled. A hand-maintained mapping table is required, and a wrong entry means a silently undetected shieldbreak — a hard-to-diagnose combat failure.
- **A behavioural constraint.** `gagOthersAttacks` (default `false`) requires every class's patterns to be live. Scoping is only safe while it is off, so any scheme must re-enable everything when a user turns it on.
- **Telemetry is unaffected either way.** `boop.stats.onAttackLine` early-returns on `not selfActor` (`boop_stats.lua:1043-1046`), so other players' attack lines feed display only.
- **The re-sync hook already exists.** `boop.onCharStatus` detects class changes and already calls `boop.skills.requestAll()`.

**Measurement method.** Lua cannot see this cost. Run an A/B at a fixed line rate with the `boop` trigger folder enabled versus disabled, and record observed client responsiveness. Record the observation here rather than estimating from pattern counts.

**Reopens when** the A/B shows a material difference *and* the mapping risk is explicitly accepted.

### B. Vitals/prompt tick coalescing

**The opportunity.** Collapsing the Vitals-driven tick and the prompt-driven tick into one removes roughly half the per-prompt decision work.

**Why it is deferred.** The duplication wastes work but causes no incorrect behaviour, because the `canAct` limiter already prevents a duplicate dispatch. Coalescing changes *when* a decision is made relative to the prompt, and `attackLeadSeconds` and the balance/equilibrium handling are finely tuned. That is not a risk worth taking immediately before a release for a saving that may be immaterial.

**Reopens when** measured `prompt_total` exceeds 8 ms, or `tick` duration exceeds 3 ms.

Phase 1 instruments `ticks_per_prompt` and `tick` specifically so this decision can be made from data.

---

## 6. Instrumentation: `boop.perf`

### Disabled-cost contract

A disabled inline probe costs **one plain boolean field read and a branch**. `boop.perf.on` is a field on a table, never a function call:

```lua
local function rawSendCommand(command)
  send(command, false)
end

if boop.perf.on then
  boop.perf.measure("wire.send", nil, rawSendCommand, command)
else
  rawSendCommand(command)
end
```

Most function-envelope probes are installed only by `boop perf on` and restored to the exact original function by `boop perf off`, so their disabled path has no wrapper overhead at all. When disabled there is **no clock call of any kind**, no table allocation, no string formatting, no counter update, and no logging. Probe names are string literals interned at load.

### State and lifetime

`boop.perf` is **module-owned and session-local**. It is not a `boop.state` domain, so the state-contract guardrail is untouched, and it is not a `boop.defaults` key, so `saveConfig` cannot persist it. `boop_bootstrap.lua` resets `boop.perf.on` to `false` on every package load, alongside the existing `state.trace.live` reset. Disabling Perf or running `boop perf reset` discards any incomplete leading/trailing correlation epoch; stale partial callbacks can never be committed after re-enable or reset.

### Two clocks, chosen per probe

This distinction matters. `os.clock()` measures **CPU** time and would under-report a blocking SQLite write to near zero — exactly the case of greatest concern.

| Probe class | Clock | Rationale |
|---|---|---|
| Outer probes, where wall-clock blocking matters: `prompt_total`, `tick`, `gmcp.*`, `db.*`, `wire.send`, `applyEffects` | **`getEpoch()`** | Measures elapsed latency including blocking I/O |
| Inner CPU-only decision probes: `context`, `targets.choose`, `attacks.plan`, `attacks.selectRage`, `attacks.applyModifiers` | **`os.clock()`** (optional) | Finer resolution where nothing blocks |

**Resolution caveat.** `getEpoch()` offers roughly millisecond resolution, so a single sub-millisecond sample reads as 0 or 1 ms. Averaging many samples reduces — but does not remove — that quantization error: `totalSeconds / count` is more trustworthy than any individual sample, yet it remains resolution-limited, and a mean well below 1 ms should be read as an order-of-magnitude indication rather than a precise figure. Where a precise sub-millisecond number matters, use the `os.clock()` inner probes or raise the sample count until the quantization noise is small relative to the difference being measured. **Counts and totals are the most reliable evidence**; `max` and the bucketed percentiles are outlier detection, not precise per-call figures.

### Storage

Fixed records and depth slots are allocated once on enable. Per probe: `count`, `totalSeconds`, `maxSeconds`, `lastSeconds`, and a fixed eight-bucket log-spaced histogram (`<0.05`, `<0.1`, `<0.25`, `<0.5`, `<1`, `<2.5`, `<10`, `>=10` ms) for approximate p50/p95/p99. Source tags are a small fixed counter map, not free-form strings. Enabled exception-safe wrappers use transient argument/result packing for `xpcall`; the disabled path allocates nothing.

Each active span receives an opaque numeric token. Exit validates that token against the exact top depth, so a rejected depth-overflow enter cannot pop a different span. Enabled wrappers always unwind the token, preserve nil and multiple return values, and rethrow the original error object.

### Prompt correlation and the per-prompt total

Probes nest — `tick` contains `context`, which contains nothing else instrumented; `applyEffects` contains `wire.send`. **Summing probe totals therefore double-counts** and must never be used to derive the per-prompt figure.

Instead, `boop.perf` maintains an explicit **prompt epoch** from separately measured synchronous callback segments:

- The real `boop.onVitals()` envelope is measured as `gmcp.Char.Vitals`; the real `boop.onPrompt()` envelope is measured as `prompt.callback`. The prompt entry increments monotonic `promptSeq`.
- `prompt_total` is the sum of the relevant completed callback-envelope durations, not their wall-clock start/end interval. Waiting or network idle time between Vitals and Prompt is therefore excluded. Nested `tick`, `context`, and other probes are already inside those envelopes and are never added again.
- Ordering mode is learned from the first observed callback sequence. If Vitals precedes the first Prompt, **leading mode** accumulates one or more Vitals segments and commits them with the next Prompt. A Prompt with no pending Vitals commits a prompt-only epoch, which explicitly handles missing Vitals.
- If Prompt is observed first, **trailing mode** opens that Prompt epoch. Following Vitals segments attach to it, and the next Prompt commits the prior epoch and opens another. The newest trailing-order Prompt remains visibly pending until the next Prompt; no timer or idle-time span is introduced merely to close it.
- Multiple Vitals callbacks in either order are accumulated into the appropriate single epoch. Timer-deferred work, room/target/walk/char-status ticks, and any other work outside the active Vitals or Prompt callback are excluded.
- `completedPromptEpochs` counts only committed epochs. `correlatedTicks` counts only ticks executed synchronously inside their Vitals/Prompt callbacks. `ticks_per_prompt` is `correlatedTicks / completedPromptEpochs`, so unrelated or deferred ticks cannot distort it.

The budget's "total boop Lua per prompt" row means `prompt_total`, and nothing else. Nested probes explain *where* that total goes; they never construct it.

### Probe naming across the refactor

Probes are named for the **concern**, not the current file, so the same name survives extraction and before/after comparisons stay valid across phases:

| Probe | Today | After |
|---|---|---|
| `tick` | `boop.tick` in `boop_events` | `boop.combat.tick` |
| `context` | `boop.runtime.context` | unchanged |
| `prequeue.*` | `boop_events` | `boop.combat` |
| `wire.send` | `boop.executeAction` in `boop_util` | `boop.wire` (Phase 4e) |
| `combatlog.line` | the parse half of `boop.gag.onAttackLine` | `boop.combatlog` (Phase 9) |
| `db.*` | `boop.db` | unchanged |
| `gmcp.<Package>` | `boop_events` handlers | unchanged |

A probe whose owner has not been extracted yet is placed at the current equivalent call site. Moving it with the code is part of that phase's work, and the probe name does not change.

### Probe set

| Probe | Question it answers |
|---|---|
| `prompt_total` | **the budget's per-prompt figure** — correlated synchronous Vitals + Prompt callback segments |
| `prompt.callback` | Synchronous work in the real Prompt callback before deferred timers run |
| `tick`, tagged `vitals`/`prompt`/`target`/`room`/`walk`/`charstatus` | invocation count, duration, and **source attribution** |
| `ticks_per_prompt` | Is the duplicate-tick hypothesis real? Gates deferred item B |
| `context` | Cost of the wide context build |
| `targets.choose`, `attacks.plan`, `attacks.selectRage`, `attacks.applyModifiers` | Decision cost breakdown |
| `prequeue.schedule`, `prequeue.standard`, `prequeue.refresh` | Prequeue cost and frequency |
| `gmcp.<Package>` | Per-handler duration and rate |
| `db.saveStats`, `db.saveConfig`, `db.recordMobXpObservation` | Synchronous I/O on the combat path; before/after evidence for P1 |
| `combatlog.line` | Attack-line capture parsing, duplicate/correlation checks, and razeslash intent resolution; ends before stats publication, gag decisions, rendering, and trace formatting |
| `applyEffects`, `wire.send` | Dispatch cost |
| counters: `ticks_suppressed_by_limiter`, `contexts_built`, `deepcopy_items`, `stats_flushes` | Coalescible waste; `deepcopy_items` counts accepted items plus item-bearing pending/completed fences and the active application traversed by the snapshot |

### Command surface

`boop perf on`, `boop perf off`, `boop perf show`, `boop perf reset` — rendered in the established `cecho` sectioned style.

Documented in `README.md` and in the in-game **diagnostics** help topic beside `boop trace`. Deliberately **not** on the config dashboard: it is a diagnostic, not a setting, and the config surface is kept focused.

Perf and trace are independent. Perf never appends to the trace buffer, and trace never updates perf counters.

---

## 7. How to use this document

1. **Measure before changing anything.** Enable `boop perf`, hunt normally for a few minutes, and record `boop perf show`.
2. **Compare against §4**, and replace the hypothesised thresholds in that table with observed values, noting the date and the conditions.
3. **Fix only what the measurement justifies.** P1 and P2 are near-certain wins and are scheduled. P3 and M1 are explicitly gated on evidence.
4. **Re-measure after each change**, using the same seeded workload, and record the delta.
5. **Do not optimize anything in the "likely negligible" list** without measurement contradicting it.

The point of the budget is to make it possible to conclude that boop is fast enough — which, for most of the code, is the expected answer.
