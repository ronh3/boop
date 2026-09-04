# Phase 1 Adversarial Second-Pass Review

Date: 2026-09-01
Scope: Current uncommitted corrected Phase 1 diff
Baseline: Git object `96384bc`
Disposition: **Rework Phase 1; do not commit the reviewed diff as-is.**

## Executive verdict

The historical and current architecture graph numbers reproduce exactly, but the mechanisms intended to preserve those properties do not provide a durable, fail-closed CI guardrail. Valid Lua can evade dependency, ownership, mutation, outbound-call, and compatibility-forwarder analysis. The SCC and legacy ratchets are not independently monotonic. Performance instrumentation also retains two production defects: disabled `combatlog.line` is not branch-only, and `prompt_total` can correlate callbacks across disable/re-enable collection epochs.

No Phase 2 or later feature implementation was found. The diff does contain unrelated mechanical cleanup that should be reverted or separated.

## Independently verified graph

| Metric | Historical `96384bc` | Current Phase 1 |
|---|---:|---:|
| Modules | 20 | 21 |
| Unique dependency directions | 108 | 117 |
| Executable/API directions | 98 | 107 |
| Owned-data directions | 39 | 44 |
| Executable/data overlap | 29 | 34 |
| Directly reciprocal pairs | 23 | 23 |
| Non-trivial SCCs | One of size 19 | One of size 19 |
| Composition root | `boop_bootstrap` | `boop_bootstrap` |
| Reported unresolved references | 0 | 0 |
| Reported duplicate exports | 0 | 0 |

The current graph is exactly the historical 108 directions plus these nine approved Perf directions:

- `boop_attacks -> boop_perf`
- `boop_bootstrap -> boop_perf`
- `boop_db -> boop_perf`
- `boop_events -> boop_perf`
- `boop_gag -> boop_perf`
- `boop_runtime -> boop_perf`
- `boop_skills -> boop_perf`
- `boop_targets -> boop_perf`
- `boop_util -> boop_perf`

No historical direction was removed. These counts are exact under the current analyzer/reference model; they do not establish that the model detects all valid Lua.

## Blocker

### 1. Valid Lua silently evades dependency and ownership analysis

Locations:

- `tools/architecture_guard.py:273` — `lex_lua`
- `tools/architecture_guard.py:304` — `_boop_path`
- `tools/architecture_guard.py:386` — defensive initialization handling
- `tools/architecture_guard.py:498` — `analyze_units`
- `tools/architecture_guard.py:539` — attack duplicate suppression

Proven valid-Lua misses include:

- `1+boop.targets.choose()` — the unspaced form is swallowed by numeric lexing. The spaced `1 + boop...` form is detected.
- `(boop).targets.choose()`
- `local b=boop; b.targets.choose()`
- `boop.rogue = boop.rogue or {}` — produces no unresolved reference.
- `boop.state["targeting"]...` — resolves only to `boop_runtime`, losing the longest-prefix `boop_targets` owner.
- Unknown colon calls can become ordinary data dependencies rather than unresolved executable references.
- Executable exports underneath owned-data or shared-kernel namespaces are accepted.
- A third `boop.attacks.register` definition is suppressed when the two expected aggregate definitions are present.

All adversarial samples parse successfully with `luac`. Consequently, reported zero unresolved references and duplicate exports can be a fail-open result.

Smallest correction: parse complete Lua prefix expressions and lvalues, including parentheses, colon calls and static brackets. Fix numeric lexing, track root aliases or reject them, reject executable exports overlapping owned-data/kernel namespaces, and restrict the attack-profile exception to the two exact approved files and definitions. A real Lua AST is preferable to additional token heuristics.

### 2. Mutation governance misses common writes and real production sites

Location: `tools/architecture_guard.py:596`, write recognition inside `analyze_units`.

A write is recognized only when `=` immediately follows a dotted path. These forms create a dependency edge but no mutation violation:

```lua
boop.state.targeting.denizens[1] = {}
local s = boop.state.targeting; s.currentTargetId = "x"
table.insert(boop.state.targeting.denizens, {})
rawset(boop.state.targeting, "currentTargetId", "x")
boop.state.targeting.currentTargetId, other = "x", 1
```

Missed current production writes include:

- `src/scripts/boop/boop_attacks.lua:1491`
- `src/scripts/boop/boop_db.lua:333-359`
- `src/scripts/boop/boop_db.lua:482-493`
- `src/scripts/boop/boop_ui.lua:3458`
- `src/scripts/boop/boop_ui.lua:3469`

Dynamic kernel writes such as `boop.config[key]` in `boop_db.lua` and `boop_ui.lua` are also absent from kernel-write accounting. The reported mutation and kernel-write ceilings are therefore incomplete.

Smallest correction: use AST-based lvalue and alias tracking, including indexed and multiple assignment plus known mutators such as `rawset` and `table.insert`. Rebuild and review mutation/kernel baselines afterward.

### 3. Outbound-call and compatibility-forwarder guards are bypassable

Locations:

- `tools/architecture_guard.py:924-933` — `CallSite.key`
- `tools/architecture_guard.py:936-1021` — `_scan_calls`
- `tools/architecture_guard.py:1051-1059` — `production_call_sites`

The scanner detects `send "x"` and `send [[x]]`, and ignores an unrelated local shadow. It misses:

- `(send)("x")`
- `_G.send("x")`
- aliases and captures of global `send`
- `(boop).tick()`
- `boop["tick"]()`
- root aliases of `boop.tick` and `boop.executeAction`
- protected or higher-order invocation

Two misses exist in the current production diff:

- `src/scripts/boop/boop_util.lua:377` passes global `send` into `boop.perf.measure`. There are 16 direct `send` syntaxes across eight files, but an additional executable higher-order send path. Eight direct `sendGMCP` calls are confirmed.
- `src/scripts/boop/boop_attacks.lua:2041-2046` invokes `boop.executeAction` through `pcall`. The guard reports six direct calls, while production has seven actual internal invocations. Seventeen direct `boop.tick` calls were confirmed.

Site identity contains only symbol, path and containing function. Moving a call within the same function passes; anonymous callbacks collapse together. The call scan walks only `*.lua`, while module discovery skips every script folder except `attacks`, so comprehensive alias, trigger and future-folder coverage is not established.

Smallest correction: resolve protected globals and forwarders when captured or passed as values, use stable lexical/statement site identities, and recursively govern every executable manifest folder/body. In production, put the sole raw `send(...)` inside one helper and measure that helper.

### 4. SCC shrink followed by regrowth passes

Locations:

- `tools/architecture_guard.py:854-871` — `validate_scc_checkpoint`
- `tests/test_architecture_guard.py:249-274` — current SCC test

With an old checkpoint containing `{a,b,c}`, a graph shrinking to `{a,b}` passes without changing the checkpoint. Regrowing to `{a,b,c}` against that unchanged checkpoint also passes. The test supplies the already-shrunken checkpoint and therefore does not exercise repository behavior.

Smallest correction: require the persisted checkpoint to equal the normalized current SCC partition. A split must atomically update the checkpoint, and that update must be checked as a refinement of the previously accepted Git version.

## High

### 1. Historical immutability and ceilings are self-authenticating

Locations:

- `tools/architecture_guard.py:729-777` — baseline loading and validation
- `tools/architecture_guard.py:780-851` — edge/site classification and ratchets
- `tools/architecture_guard.py:1101-1151` — historical metadata validation
- `tools/architecture_baseline.json`

One editable JSON file supplies historical edges and summaries, immutable/active/retired legacy state, SCC checkpoint, exact sites, and every occurrence ceiling. A new edge can be added to both “immutable” and active state, while code growth can be paired with a raised ceiling. Deleting both a ceiling and its tombstone erases site history. Historical topology is checked, but the 98/39/29 executable/data/overlap breakdown is trusted summary data rather than independently reconstructed.

Current data is internally consistent: 50 active legacy edges, zero retired, and 58 allowed. Allowed edges are not pointlessly ceiling-limited, and listed hard-forbidden edges win over allowed/legacy policy. Those properties are not durably anchored.

Smallest correction: derive historical edges and original ceilings from immutable Git history, store executable/data/site identity separately, and compare later migration state with the previously accepted commit using append-only tombstones and non-increasing ceilings.

### 2. Disabled `combatlog.line` is not branch-only

Location: `src/scripts/boop/boop_gag.lua:1465-1516`.

The former inline attack parser was extracted into `parseAttackLine`, which is invoked before the Perf decision. Disabled mode therefore adds a helper call and six-value return plumbing on every combat line. It adds no clock, counter, formatting or logging, but it violates the explicit contract that disabled Perf adds only a boolean read and branch.

Smallest correction: preserve the exact inline uninstrumented path when disabled and enter the measured helper only on the enabled branch.

### 3. `prompt_total` can correlate callbacks across collection epochs

Locations:

- `src/scripts/boop/boop_perf.lua:121-131` — `resetCorrelation`
- `src/scripts/boop/boop_perf.lua:276-326` — `_completeCallback`
- `src/scripts/boop/boop_perf.lua:397-419` — `setEnabled`

Reproduced through real production entry points:

1. Enable Perf and call `boop.onVitals()`.
2. Disable and re-enable Perf.
3. Call `boop.onPrompt()`.

The pre-disable Vitals callback and post-enable Prompt callback are committed as one epoch. Idle time is not numerically summed, but the measurement crosses collection intervals and is semantically stale.

During uninterrupted collection, the core model works: it sums separately timed synchronous callback segments, excludes idle and deferred work, avoids nested-probe summation, handles normal and reversed order plus missing/multiple Vitals, and ignores unrelated ticks. The off/on defect means the metric is not correct in all supported collection lifecycles.

Smallest correction: discard incomplete prompt correlation state on disable while retaining completed bounded records.

### 4. Hard-forbidden coverage is incomplete

Locations:

- `tools/architecture_guard.py:697-710` — `is_hard_forbidden`
- `tools/architecture_guard.py:800-815` — edge classification

`runtime -> targets` remains forbidden even if placed in the allowed set, so ordering works for listed edges. However, `runtime -> rage` and `runtime -> ih` can be allowed despite their decision/orchestration roles. `boop_util -> boop_perf` also bypasses the documented “util only depends on theme” rule through the approved-Perf exception.

Smallest correction: define module roles centrally and enforce forbidden role transitions, including future modules. Remove or explicitly document the narrow util/Perf exception.

## Medium

### 1. Stale live Perf configuration survives reload

Location: `src/scripts/boop/boop_db.lua:254-290`, `boop.db.loadConfig`.

Persisted `perf` and `perf.*` rows are rejected or deleted correctly, and save rejects them. Existing reserved keys already present in live `boop.config`, however, are not purged before defaults or the no-database-handle return.

Smallest correction: remove exact `perf` and `perf.*` keys from the live table before any early return. Test seeded live values as well as DB rows.

### 2. Legacy promotion promised by the target design is unrepresentable

Locations:

- `tools/architecture_guard.py:792-812`
- `TARGET-ARCHITECTURE.md:50`

A legacy edge must be active or retired, and retired is rejected before allowed. It therefore cannot remain present and be deliberately promoted to allowed as documented.

Smallest correction: add a disjoint `promoted_legacy_edges` state or remove the promotion promise.

### 3. Tests reuse implementation data and omit demonstrated evasions

Locations:

- `tests/test_architecture_guard.py:85-206`
- `tests/test_architecture_guard.py:249-366`
- `tests/boop_perf_spec.lua:304-323`

Missing coverage includes unspaced numeric syntax, parentheses, aliases, static brackets, indexed/mutator writes, stale SCC checkpoints, same-function site movement, higher-order forwarders, a third attack definition, off/on prompt correlation, seeded live config, and an actual captured deferred timer callback. Historical expected edges are imported from the implementation’s JSON rather than independently reconstructed. The normal `ticks_per_prompt` test derives its oracle from the same counters and does not assert the expected exact result.

Smallest correction: add adversarial independent fixtures and keep the historical oracle outside the implementation data being validated.

### 4. The authoritative documents do not agree

Examples:

- `ARCHITECTURE.md:15,28-40` still says 20 modules and its early load-order description omits Perf, while a later section reports 21.
- `ARCHITECTURE-RULES.md:65`, `README.md:143`, and `UIDESIGN.md:148` describe `prompt_total` as a single/direct outer span, conflicting with the correlated-segment model in `PERFORMANCE.md:213-219,241`.
- `TARGET-ARCHITECTURE.md:53-59` omits registry and `gag -> ui` hard rules and promises unsupported legacy promotion.
- `REFACTOR-ROADMAP.md:65,373` assigns Wire/F4 work to Phase 5, while the detailed plan places it in Phase 6.
- The “util only depends on theme” rule conflicts with the approved `boop_util -> boop_perf` direction.

Smallest correction: choose one prompt contract and synchronize every document; reconcile module count/load order, hard-policy list, the Perf exception, promotion semantics, and phase numbering.

## Low

### 1. Span token encoding has a long-run collision boundary

Location: `src/scripts/boop/boop_perf.lua:187-208`.

Span identity is encoded as `record.id * 1e9 + token`. At the boundary, decoding can select the following record and strand nesting depth.

Smallest correction: use a structured token or a bounded, non-overlapping record/token identity.

### 2. The diff contains unrelated mechanical cleanup

Examples:

- `src/scripts/boop/boop_attacks.lua:1803-1898` — return-via-local rewrites.
- `src/scripts/boop/boop_events.lua:2295-2410` — broad room-handler formatting changes.
- `src/scripts/boop/boop_events.lua:2730-2746` — walk callback return rewrites.
- Similar formatting/return rewrites occur in `boop_runtime.lua` and `boop_targets.lua`.

These changes are not Phase 1 instrumentation and slightly enlarge semantic and review risk. Revert them or separate them from Phase 1.

## Performance properties that did verify

- Enabled spans are exception-safe.
- Multiple return values survive protected spans.
- Nesting overflow does not pop an earlier valid span under ordinary token ranges.
- Production record and histogram storage are bounded.
- Normal, reversed, missing, and multiple-Vitals prompt correlation works during uninterrupted collection.
- Idle/network time, deferred work, nested probes, and unrelated tick sources are excluded from completed prompt epochs.
- `combatlog.line` ends before telemetry consumers, rendering, and trace work.
- Intended item-bearing snapshot structures contribute to `deepcopy_items`.
- Wrapper restoration, alias/manifest wiring, bootstrap reset, and trace independence work.

These successes do not resolve the disabled combat-line or off/on prompt defects.

## Scope verdict

No Phase 2 or later implementation was found:

- no `ensureState` optimization;
- no stats persistence coalescing;
- no `onVitals` enabled guard;
- no `Core.Supports` unit fix;
- no combat ownership movement;
- no Wire, Room, Gold, or other ownership extraction;
- no tick coalescing.

Unrelated mechanical cleanup was found, as described above.

## Explicit answers

- Is the architecture analyzer trustworthy as a long-term CI guardrail? **No.**
- Is the owned-data/shared-kernel model implemented consistently and fail-closed? **No.**
- Does `prompt_total` measure the intended metric? **Not fully. It is correct during uninterrupted collection but incorrect across off/on epochs.**
- Are migration/SCC/legacy ratchets actually monotonic? **No.**
- Are outbound-call and compatibility-forwarder guards robust? **No.**
- Was any Phase 2 or later implementation found? **No.**
- Do the implementation and authoritative architecture documents agree? **No.**
- Recommendation: **Rework Phase 1 and repeat adversarial review before committing.**

## Read-only validation performed

- Historical graph reconstructed from Git object `96384bc` in memory.
- Current graph independently analyzed.
- `tests/test_architecture_guard.py`: 18 tests passed.
- `tools/check_release_gates.py`: passed, including version, manifest, state-drift, and architecture checks.
- `tests/boop_perf_spec.lua`: 15 passed, 1 pending because the DB case requires real Mudlet.
- Changed and new Lua files passed `luac -p`.
- `git diff --check` passed.

Passing checks are evidence of the current canonical paths, not proof against the adversarial cases above.

This review made no source changes and did not commit or push.
