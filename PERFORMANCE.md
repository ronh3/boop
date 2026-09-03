# PERFORMANCE.md

The hot-path model, a performance budget, and the instrumentation needed to replace the budget's guesses with measurements.

> Phase 1 has produced a live Achaea hunting baseline. The thresholds in §4 remain the original starting hypotheses; Phase 2 does not rewrite them from synthetic tests. Static-analysis passages below are retained as the before-state for the approved optimizations and are labelled accordingly.

Source verified against commit `96384bc` (package version `0.1.490`).

### Phase-1 live baseline

| Measure | Samples/calls | Mean | Max | Other evidence |
|---|---:|---:|---:|---|
| `prompt_total` | 2,243 | 2.077 ms | 45 ms | below the 8 ms tick-coalescing reopen threshold |
| `tick` | 4,629 | 1.016 ms | 59 ms | Vitals 2,243; prompt 2,151; duplicate work confirmed but deferred |
| `context` | 9,870 | 0.301 ms | 3.998 ms | 1,859,872 copied room items across the run |
| `db.saveStats` | 335 | 19.015 ms | 51 ms | 6,370 ms cumulative; median, p95, and p99 buckets all >=10 ms |

The inexpensive decision probes remained small (`targets.choose` 0.057 ms, `attacks.plan` 0.092 ms, `attacks.selectRage` 0.048 ms, `attacks.applyModifiers` 0.016 ms). Phase 2 therefore targets persistence and discarded context work, not decision algorithms or duplicate-tick ordering.

### Phase-2 live validation

An approximately eight-minute Achaea hunting run on package version `0.1.493` produced the following post-change evidence:

| Measure | Samples/calls | Mean | Phase-1 mean/evidence |
|---|---:|---:|---|
| `prompt_total` | 1,392 | 0.607 ms | 2.077 ms |
| `tick` | 2,769 | 0.213 ms | 1.016 ms |
| `context` | 6,026 | 0.064 ms | 0.301 ms |
| `db.saveStats` | 43 over 1,392 prompts | variable by individual SQLite write | 335 calls over 2,243 prompts |
| `Items.Remove` | live run | 0.110 ms | 8.420 ms |
| `Room.Info` | live run | 0.625 ms | 9.071 ms |
| `Char.Status` | live run | 0.017 ms | 4.752 ms |
| `applyEffects` | live run | 0.039 ms | 0.366 ms |

The run recorded 43 `stats_flushes` and 99,337 `deepcopy_items` over 6,026 contexts, compared with 1,859,872 copied items over 9,870 contexts in the Phase-1 baseline. Persistence coalescing is therefore validated by the dramatic reduction in save frequency; variable latency for an individual SQLite write remains expected.

Duplicate work remains observable — 1,390 Vitals ticks, 1,379 prompt ticks, and 1,392 `prompt_total` samples — but the work is now cheap. Tick coalescing remains deferred exactly as described in §5.

Beginning with `0.1.494`, the `tick` probe measures `boop.combat.tick`, not the complete Events-owned `boop.tick` facade. Pending room-application work and facade-level rejected ticks are excluded, so Phase-2/`0.1.493` and Phase-3/`0.1.494` tick sample counts and means are not strictly directly comparable.

---

## 1. The hot-path model

Work in boop divides by how often it runs.

| Cadence | What runs | Bounded by |
|---|---|---|
| **Per line of game output** | 885 Mudlet trigger patterns; on a match, one of three generic handlers | game output rate x pattern count |
| **Per prompt** | `boop.onPrompt` -> `promptStep` -> often `boop.tick`; separately `gmcp.Char.Vitals` -> `boop.onVitals` -> `boop.tick` | prompt rate (assumed 2-4/sec in combat) |
| **Per room change** | `Room.Info` + `Char.Items.List` fence and application; denizen list rebuild | movement rate |
| **Per retarget** | `targets.setTarget`, three `incrementCounter` calls, each marking one shared pending stats flush dirty | kill rate; at most one coalesced save per 5-second window |
| **Per kill** | `recordKill`, mob XP observation, gold and experience deltas | kill rate |
| **Per balance recovery** | `onBalanceUsed` -> `schedulePrequeue` -> timer -> `prequeueStandard` | balance rate |

The per-line tier is the only one whose cost is unbounded in the codebase's own growth: it scales with the number of supported classes.

---

## 2. Per-prompt work at the Phase-1 baseline

Before Phase 2, `boop.onVitals()` had no `enabled` guard and called `boop.tick()` unconditionally. Phase 2 retains Vitals observation while disabled but now returns before the tick. `boop.onPrompt()` still guards on `enabled`, builds a context for `promptStep`, then calls `boop.tick()` again if `promptStep` returns `runTick`.

Phase-1 source counts confirmed that `gmcp.Char.Vitals` usually fires alongside each prompt, producing roughly two full tick decisions per prompt. `boop.combat.canAct()`'s 0.4 s limiter suppresses the second *dispatch*, but not the decision work behind it. The measured means remain below the reopen threshold, so tick coalescing is still deferred.

### `boop.runtime.context()`

At the Phase-1 baseline, tracing the call chain showed that `context()` invoked `boop.runtime.ensureState()` **nine times**:

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

Before Phase 2, each call iterated 13 domains against roughly 119 default keys, checking `current[key] == nil` — approximately 1,100 hash lookups per `context()`. Phase 2 keeps the call topology but healthy calls now validate only the schema/migration sentinels and the 13 top-level domain table types. Full hydration still runs when a sentinel is stale or a domain is damaged.

Additionally, the Phase-1 baseline paid these per-context costs:

- `roomObservationSnapshot()` deep-copies `acceptedItems`, `fenceQueue`, `lastCompletedFence`, and `activeApplication` — the last of which itself holds a deep copy of the room item list. This scales with room population. `readinessSnapshot()` then reads four scalar fields from the result and discards the rest.
- `deepCopy(state.gold.operation)` runs even when gold is idle.
- `standardSnapshot()` deep-copies the standard operation.
- `gmcp.Char.Vitals.charstats` is scanned with a per-entry `string.match` to extract Rage.
- Roughly twelve nested sub-tables are allocated.

Phase 2 replaces the readiness caller's full room snapshot with scalar-only readiness data, skips the gold-operation copy when idle, and reads canonical Rage state populated once by the Vitals handler. The full diagnostic room snapshot and active-operation copy semantics remain intact.

`tickStep` then calls `boop.runtime.operationHolds()` five times consecutively (`target`, `combat`, `queue`, `gold`, `walk`) and four more times in the gold branch. At the Phase-1 baseline, each call allocated normalized records and sorted even when `blockersByOwner` was empty. Phase 2 returns immediately for the normal empty map; non-empty priority and normalization behavior is unchanged.

`tickStep` also rebuilds a near-complete second copy of the context (`boop_runtime.lua:4012-4036`) whenever the chosen target differs from `context.target.id`, linear-scanning `denizens` to resolve the name — that is, on essentially every retarget.

---

## 3. Findings

### Probable optimization opportunity

Clear waste with a behaviour-preserving fix. Measure to size it, then fix.

**P1 — `boop.db.saveStats()` on the combat path (addressed in Phase 2).** At the live baseline the function performed 13 `db:fetch` queries plus up to 13 `db:update` writes per call and averaged 19.015 ms. `persistLifetime()` now marks one coalesced persistence state dirty; repeated mutations share a single 5-second timer, with immediate flushes at exact observation and lifecycle boundaries.

The `stats` sheet declares `_unique = { "name" }`, so each lookup is indexed rather than a scan. Even so, this is the only place in boop that performs synchronous I/O at combat frequency, and it is the most likely cause of any observed client hitching. Addressed in Phase 2.

**P2 — Room-item deep copies in `readinessSnapshot()` (addressed in Phase 2).** The readiness path is now scalar-only; the full copied observation API remains available to diagnostic callers.

**P3 — Duplicate ticks per prompt.** Full decision work runs twice; the second result is discarded by the `canAct` limiter. Measured in Phase 1; the fix is deferred — see §5.

**P4 — `ensureState()` re-validating every nested default on every call (addressed in Phase 2).** Healthy calls now use sentinel plus top-level integrity checks while damaged domains and stale migrations still self-repair.

### Worth measuring

Plausibly significant; cannot be settled by reading the code.

**M1 — 885 regex patterns across 512 triggers, all enabled together.** Gag 277 triggers / 503 patterns, Shield 116 / 214, Rage 102 / 126. For any given character roughly 95% of the pattern set is class-irrelevant, yet every pattern is evaluated against every line of game output. This runs in Mudlet's C++ engine and is invisible to Lua profiling. It is the largest *unbounded* cost in the system: it grows with every class boop supports. Deferred — see §5.

**M2 — timer churn from `boop.combat.canAct` and `boop.combat.canUseRage`.** Each creates a `tempTimer` per successful call (0.4 s and 0.6 s respectively). At combat cadence that is a steady trickle of Mudlet timer objects. Both are also query-shaped names with mutating side effects, which is a clarity problem independent of cost.

**M3 — `charstats` scanned three times per Vitals event (addressed in Phase 2).** The Vitals event now scans once and writes `state.rage.amount` and `state.combat.spec`; attacks and context consume those canonical values.

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

**These thresholds remain hypotheses.** Phase-1 and Phase-2 live measurements are compared against them above; Phase 2 leaves the thresholds unchanged because the post-change run validates the approved optimizations without crossing the tick-coalescing reopen thresholds.

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
| `prequeue.*` | `boop_events` | unchanged through Phase 7; the shared gate work runs in `boop.combat` beneath the same probe |
| `applyEffects` | `boop.runtime` | `boop.combat` |
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
