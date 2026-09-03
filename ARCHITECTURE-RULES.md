# ARCHITECTURE-RULES.md

Rules for anyone — human or agent — changing boop. Short by design. The reasoning lives in `ARCHITECTURE.md`, `TARGET-ARCHITECTURE.md`, and `PERFORMANCE.md`.

---

## Dependencies

1. **The target module graph is a DAG.** `python3 tools/check_release_gates.py --check architecture` builds the current graph from Boop's supported direct-reference subset. Through Phase 7, reciprocal pairs and SCCs are reported for review. **From Phase 8 acceptance, any non-trivial SCC is a permanent hard failure.**
2. **Cross-module architecture must be direct and statically visible.** Use forms such as `boop.targets.choose()` and `boop.state.targeting.currentTargetId`. Do not alias `boop`, capture another module's function, parenthesize the root to evade matching, use `boop[dynamic]`, alias `send`/`sendGMCP` or compatibility forwarders, or mutate owned data through aliases/`rawset`. The one sanctioned string form is a literal `"boop.<symbol>"` passed through `boop.events.register()`'s existing local Mudlet event-registration helper; unknown callback symbols fail closed. The guard implements this repository convention, not general Lua or string analysis. Fourteen path-and-symbol legacy indirections may not widen; Runtime's exact line-scoped schema-custody `rawset` is recorded separately as permanent.
3. **These edges are forbidden outright:**
   - `runtime` -> any decision, orchestration, or presentation module
   - `attacks` -> `combat` (decision never depends on orchestration)
   - `db` -> `stats`
   - `stats` -> `ui`
   - `gag` -> `ui`
   - `registry` -> any other module
   - `util` -> any boop module except `theme`
   - before Phase 6, any new or expanded direct `send()`/`sendGMCP()` site outside the reviewed baseline; from Phase 6 onward, either call outside `boop.wire`
   - Phase 3's concrete Runtime invariant is zero references to Attacks, Safety, Walk, Gag, or Combat. The surviving target-lifecycle references are deferred to Phase 5.
4. **Adapters normalize and hand off; they do not freely mutate.** An external adapter converts raw input into normalized values and calls the **ingestion API of the target subtree's semantic owner**. It may write only state it owns. Never write another subsystem's invariant-bearing state directly — generations, locks, dispatch identity, observation fences — even when the value looks obviously right. No `gmcp.*` access in decision code.
5. **`boop_bootstrap.lua` is the composition root.** It is the one place that wires modules together after they are all loaded — the ready notification, registry attachment, and anything of the same shape. Nothing may reference it. When a lower module seems to need a higher one, move the wiring here instead of adding the edge.
6. **Shared presentation primitives live in `boop.render`, not `boop.ui`.** Anything that renders — screens, gag summaries, stats reports — depends on `boop.render`. Only screens and dashboards depend on `boop.ui`.
7. **Registries declare and accept; they never call.** `boop.registry` holds data and a registration API. Handlers register themselves into it. A registry that calls into a handler module is a cycle waiting to happen.

## Ownership

8. **One authoritative owner per concept.** Before writing a helper, check whether a canonical one exists — `currentRoomId`, `currentClass`, `currentSpec`, `copySourceAuthority`, `deepCopy`, `nowSeconds`. Do not reimplement one locally.
9. **`boop.state` is a data tree.** No function is reachable under it. Service functions go on `boop.runtime` or another API namespace.
10. **Schema custody and semantic ownership are different.** `boop.runtime` alone owns the tree's *shape* — domains, defaults, hydration, migration. Each subtree has exactly one *semantic* owner that decides which transitions are legal and is the only module permitted to mutate it. See `TARGET-ARCHITECTURE.md` §6 for the table.
11. **Physical initialization does not establish ownership.** `boop.X = boop.X or {}` is defensive bootstrap, not a claim. Never infer a data owner from where a table is first assigned — a first-assignment rule was measured and invents six fictional reciprocal pairs.
12. **Shared-data ownership is explicit and versioned.** Declared in `ARCHITECTURE.md` §4 and nowhere else. Executable ownership may be inferred from definitions and exports; data ownership may not.
13. **Direct data references resolve by longest declared prefix**, and **both reads and writes create a dependency edge** on the semantic owner. A read of another module's representation is real coupling.
14. **A direct write by a non-owner is a mutation violation.** Use the owner's ingestion API. Hidden mutation through a local alias, `rawset`, or a dynamically computed ownership path is unsupported architectural indirection, not a form the guard attempts to follow. The sole `rawset` exception is Runtime's exact `boop_runtime.lua:283` schema-hydration site; it is line-scoped and permanent schema custody.
15. **Unresolvable direct Boop references fail closed.** Anything that resolves to neither a known executable, declared owner, nor the shared kernel is a hard error, never a dropped edge.
16. **The shared kernel is a closed list** — `boop.config`, `boop.version`. No module owns them and they create no edges. They remain governed by their write-ownership rules. `boop.defaults` is not kernel: it is owned by `boop.init`, so reads create normal dependency edges and only init may write it. Adding to the kernel requires editing `ARCHITECTURE.md`.
17. **Every first-level `boop.state.<domain>` has an explicit semantic owner.** Runtime owns the exact `boop.state` root for schema custody; that root is never fallback ownership for an undeclared child domain. New domains fail closed until the ownership table is updated.
18. **`mmp` is referenced only in `boop_walk.lua`**, as a mapper fallback and not as game state.
19. **Stats and trace observe; they never control.** No telemetry function may return a value that changes a combat decision.
20. **Persistence exchanges plain tables.** `boop.db` never reaches into another module's internals.
    - `boop.runtime.context()` permanently remains Runtime's canonical composite projection. Combat consumes it, Attacks retains its bare-call fallback to it, and no `boop.combat.context()` copy or forwarder is permitted.

## Compatibility

21. **Know which tier you are changing.** `ARCHITECTURE.md` §5 defines them:
    - **S1** — alias syntax and semantics, config keys, the DB schema, `boop.version`, `demonwalker.*` integration, and the S1 state-field allowlist. Breaking any of these needs a documented note.
    - **S2** — symbols referenced from `src/aliases/` and `src/triggers/`. Change freely; migrate those files in the same commit.
    - **S3** — every other top-level `boop.*` function. Move, rename, or delete freely.
22. **Output formats are not automatically S1.** Wording, colour, spacing, and presentation may change. Only formats explicitly designated stable or machine-consumed carry a commitment.
23. **New S1 state requires deliberate promotion**, recorded in `ARCHITECTURE.md` in the same commit. State not on the allowlist is internal, including whole domains.
24. **Add a compatibility forwarder only for a real need.** Today that means `boop.tick` and `boop.executeAction`.
    - Through Phase 7, `boop.tick` is an Events-owned room-aware facade, not a direct Combat forwarder. It performs pending-room application work before delegating the combat portion.
    - The Phase-3 `events ↔ combat` pair is an approved, visible migration seam: Combat calls only the Events-owned Gold symbols `boop.maybeFlushPendingGold` and `boop.flushPendingGold`; Events invokes Combat. Phase 8 removes the pair. Do not hide it behind callbacks, dynamic lookup, or dependency injection.

## Change discipline

25. **No unapproved observable behaviour change.** A behaviour fix discovered while refactoring is proposed separately, isolated into its own commit, tested, and approved before it lands.
26. **A new module needs a stated justification** from: state ownership, lifecycle ownership, dependency seam, transport boundary, reusable policy, or strong cohesion. **Reducing a line count is not a justification.**
27. **Load order is a dependency decision.** `src/scripts/boop/scripts.json` is hand-ordered and excluded from `tools/sort_manifests.sh`. Documented initialization, composition, and registration work at load time is allowed and expected — namespace/schema/function definition, profile registration, registry attachment, `boop.perf.register(...)` probe registration, and composition-root startup. Any new behaviorally significant load-time class or site must be explicitly documented and reviewed. See `ARCHITECTURE.md` §1.
28. **Triggers go at the narrowest correct ownership scope.** A class-specific pattern belongs in that class's local manifest; a pattern that is genuinely class-agnostic belongs at the shared scope (`General`, `Combat`, `Mobs`, `Core`). Do not force a shared pattern into a class folder, and never flatten class folders back into a parent.
29. **Run `python3 tools/check_release_gates.py` before every commit and again before every push.** Classify the commit by its staged paths: anything outside `.planning/` is package-affecting and must bump all four version checkpoints together.

## Performance

30. **Measure before optimizing.** Enable `boop perf`, collect, and compare against the budget in `PERFORMANCE.md` §4.
31. **No synchronous DB write on a combat-frequency path.** Coalesce, and flush on the observable boundaries.
32. **A large file is not a performance bug.** Mudlet compiles scripts once at load. File size is a maintainability signal only.
33. **Do not target anything in the "likely negligible" list** in `PERFORMANCE.md` §3 *for performance work* without a measurement that contradicts it. This is not a freeze: those items may still be changed freely for correctness, clarity, or an architectural boundary — just not on the argument that it will make them faster.
34. **The per-prompt performance figure is `prompt_total`**, a single measured span. Never derive it by summing nested probes.
