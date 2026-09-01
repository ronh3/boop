# ARCHITECTURE-RULES.md

Rules for anyone — human or agent — changing boop. Short by design. The reasoning lives in `ARCHITECTURE.md`, `TARGET-ARCHITECTURE.md`, and `PERFORMANCE.md`.

---

## Dependencies

1. **The module dependency graph must become a DAG, and must never regress toward one that isn't.** `python3 tools/check_release_gates.py --check architecture` enforces this from a graph built with **both** namespaced and top-level `boop.*` attribution.
   - **Through Phase 7**, the graph is not yet acyclic. Staged policy: existing legacy edges may only disappear, no new legacy edge may appear, no module may newly join a cyclic SCC, and SCC size may only decrease.
   - **From Phase 8 acceptance**, the legacy list is empty and any cycle is a permanent hard failure. There is no exemption for a "deliberate" binding — if two modules need each other, one of them is wrong, or a shared seam is missing.
2. **Edges are classified allowed / legacy / forbidden.** Adding calls along an allowed edge is free. A new unapproved edge fails. A legacy edge may shrink, never grow.
3. **These edges are forbidden outright:**
   - `runtime` -> any decision, orchestration, or presentation module
   - `db` -> `stats`
   - `stats` -> `ui`
   - `gag` -> `ui`
   - `registry` -> any other module
   - `util` -> any boop module except `theme`
   - `send(` outside `boop.wire`
4. **Adapters normalize and hand off; they do not freely mutate.** An external adapter converts raw input into normalized values and calls the **ingestion API of the target subtree's semantic owner**. It may write only state it owns. Never write another subsystem's invariant-bearing state directly — generations, locks, dispatch identity, observation fences — even when the value looks obviously right. No `gmcp.*` access in decision code.
5. **`boop_bootstrap.lua` is the composition root.** It is the one place that wires modules together after they are all loaded — the ready notification, registry attachment, and anything of the same shape. Nothing may reference it. When a lower module seems to need a higher one, move the wiring here instead of adding the edge.
6. **Shared presentation primitives live in `boop.render`, not `boop.ui`.** Anything that renders — screens, gag summaries, stats reports — depends on `boop.render`. Only screens and dashboards depend on `boop.ui`.
7. **Registries declare and accept; they never call.** `boop.registry` holds data and a registration API. Handlers register themselves into it. A registry that calls into a handler module is a cycle waiting to happen.

## Ownership

9. **One authoritative owner per concept.** Before writing a helper, check whether a canonical one exists — `currentRoomId`, `currentClass`, `currentSpec`, `copySourceAuthority`, `deepCopy`, `nowSeconds`. Do not reimplement one locally.
10. **`boop.state` is a data tree.** No function is reachable under it. Service functions go on `boop.runtime` or another API namespace.
11. **Schema custody and semantic ownership are different.** `boop.runtime` alone owns the tree's *shape* — domains, defaults, hydration, migration. Each subtree has exactly one *semantic* owner that decides which transitions are legal and is the only module permitted to mutate it. See `TARGET-ARCHITECTURE.md` §6 for the table.
12. **`mmp` is referenced only in `boop_walk.lua`**, as a mapper fallback and not as game state.
13. **Stats and trace observe; they never control.** No telemetry function may return a value that changes a combat decision.
14. **Persistence exchanges plain tables.** `boop.db` never reaches into another module's internals.

## Compatibility

15. **Know which tier you are changing.** `ARCHITECTURE.md` §5 defines them:
    - **S1** — alias syntax and semantics, config keys, the DB schema, `boop.version`, `demonwalker.*` integration, and the S1 state-field allowlist. Breaking any of these needs a documented note.
    - **S2** — symbols referenced from `src/aliases/` and `src/triggers/`. Change freely; migrate those files in the same commit.
    - **S3** — every other top-level `boop.*` function. Move, rename, or delete freely.
16. **Output formats are not automatically S1.** Wording, colour, spacing, and presentation may change. Only formats explicitly designated stable or machine-consumed carry a commitment.
17. **New S1 state requires deliberate promotion**, recorded in `ARCHITECTURE.md` in the same commit. State not on the allowlist is internal, including whole domains.
18. **Add a compatibility forwarder only for a real need.** Today that means `boop.tick` and `boop.executeAction`.

## Change discipline

19. **No unapproved observable behaviour change.** A behaviour fix discovered while refactoring is proposed separately, isolated into its own commit, tested, and approved before it lands.
20. **A new module needs a stated justification** from: state ownership, lifecycle ownership, dependency seam, transport boundary, reusable policy, or strong cohesion. **Reducing a line count is not a justification.**
21. **Load order is a dependency decision.** `src/scripts/boop/scripts.json` is hand-ordered and excluded from `tools/sort_manifests.sh`. Documented initialization, composition, and registration work at load time is allowed and expected — namespace setup, function definitions, the profile-registration guard, and composition-root wiring. What is forbidden is *undocumented* behaviourally significant load-time work. See `ARCHITECTURE.md` §1.
22. **Triggers go at the narrowest correct ownership scope.** A class-specific pattern belongs in that class's local manifest; a pattern that is genuinely class-agnostic belongs at the shared scope (`General`, `Combat`, `Mobs`, `Core`). Do not force a shared pattern into a class folder, and never flatten class folders back into a parent.
23. **Run `python3 tools/check_release_gates.py` before every commit and again before every push.** Classify the commit by its staged paths: anything outside `.planning/` is package-affecting and must bump all four version checkpoints together.

## Performance

24. **Measure before optimizing.** Enable `boop perf`, collect, and compare against the budget in `PERFORMANCE.md` §4.
25. **No synchronous DB write on a combat-frequency path.** Coalesce, and flush on the observable boundaries.
26. **A large file is not a performance bug.** Mudlet compiles scripts once at load. File size is a maintainability signal only.
27. **Do not target anything in the "likely negligible" list** in `PERFORMANCE.md` §3 *for performance work* without a measurement that contradicts it. This is not a freeze: those items may still be changed freely for correctness, clarity, or an architectural boundary — just not on the argument that it will make them faster.
28. **The per-prompt performance figure is `prompt_total`**, a single measured span. Never derive it by summing nested probes.
