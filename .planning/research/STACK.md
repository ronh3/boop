# Technology Stack: boop Hunter Pre-1.0 Hardening

**Project:** boop Hunter
**Domain:** Brownfield standalone Mudlet package for Achaea hunting/bashing
**Research dimension:** Stack, runtime, testing, packaging, external-doc assumptions
**Researched:** 2026-07-09
**Overall confidence:** HIGH for repo-observed stack, MEDIUM for external API currency

## Executive Recommendation

Keep the existing stack. boop is already correctly shaped as a Mudlet Lua 5.1 package built by Muddler, tested with Busted inside a real Mudlet profile, driven by Achaea/Iron Realms GMCP plus text-trigger fallbacks, and persisted through Mudlet DB. Pre-1.0 work should harden this stack, not replace it.

The 1.0 stack decision is: **Mudlet Lua 5.1-compatible package + Muddler + Mudlet DB + Achaea GMCP + Busted-in-Mudlet CI + optional demonnicAutoWalker integration**. Add gates around version sync, manifest parity, command-fragment validation, and high-risk game-text regressions. Do not introduce a new runtime framework, external curing/hunting dependency, or alternate package builder before 1.0.

## Recommended Stack

### Core Runtime

| Technology | Version / Floor | Purpose | Recommendation | Confidence |
|------------|-----------------|---------|----------------|------------|
| Mudlet | CI currently pins 4.20.1; current public line is newer | Package runtime, triggers, aliases, event engine, timers, rich output, local DB | Keep 4.20.1 as the CI floor for pre-1.0 unless a specific live regression requires testing newer Mudlet. Do not require newer-than-CI APIs without raising and documenting the minimum Mudlet version. | HIGH repo / MEDIUM web |
| Lua | Mudlet Lua 5.1 | All package logic and tests | Keep all code Lua 5.1-compatible. Avoid Lua 5.2+ and LuaJIT-only features. | HIGH |
| Achaea/Iron Realms GMCP | Current Nexus docs + Achaea historical spec | Room, target, vitals/status, skills, IRE modules | Continue using GMCP as the primary state source, with explicit nil guards and text-trigger fallbacks for Achaea combat lines. | MEDIUM |
| Mudlet DB | Mudlet built-in DB API | Persist config, lists, tags, stats, mob XP | Keep DB-backed state. Add migrations defensively; avoid file-based ad hoc persistence. | HIGH |

### Build And Packaging

| Technology | Version / Pin | Purpose | Recommendation | Confidence |
|------------|---------------|---------|----------------|------------|
| Muddler | Existing local `muddle`; CI uses `demonnic/build-with-muddler@main` | Build `.mpackage` from `mfile` and `src/` manifests | Keep Muddler. Add/keep checks that `mfile`, manifests, package output, and version fields agree. Consider pinning the action or logging exact Muddler version for release reproducibility. | HIGH repo / MEDIUM web |
| `mfile` | Research-time version observed: `0.1.321` | Package metadata, title, version, token replacement | Treat `mfile.version`, `mfile.title`, and `boop.version` as a release gate. Version sync should fail CI, not rely only on human review. | HIGH |
| Source manifests | `src/**/{scripts,aliases,triggers}.json` | Mudlet object layout and load order | Keep `src/scripts/boop/scripts.json` hand-ordered. Sort only display-order manifests with `tools/sort_manifests.sh`. Add manifest/file parity tests. | HIGH |
| Built artifacts | `build/` | Generated output | Do not edit or review as source. Build from `src/` and `mfile` only. | HIGH |

### Testing And CI

| Technology | Version / Pin | Purpose | Recommendation | Confidence |
|------------|---------------|---------|----------------|------------|
| Busted | LuaRocks install; supports Lua >= 5.1 | Spec framework | Keep Busted as the only Lua test framework before 1.0. Use pure-Lua style only where it still runs inside Mudlet. | HIGH repo / MEDIUM web |
| Real Mudlet test run | Current CI imports `build/boop Hunter.mpackage` into `GithubTests` profile | Runtime validation of Mudlet globals, package load, DB, rich output, GMCP stubs | Keep as the primary automated gate. Extend it for state ownership, gags, autowalk boundaries, command validation, and version/manifest checks. | HIGH |
| GitHub Actions | Ubuntu runner | Build, package, test, artifact upload | Keep current pipeline shape. Add explicit gates before artifact upload: version sync, JSON parse, manifest parity, forbidden built-artifact edits, and high-risk regression specs. | HIGH |
| Live Mudlet validation | Manual/operator checklist | Achaea server behavior, GMCP timing, prompt/gag text, queues, walker | Required for changes touching GMCP negotiation, gag regexes, prompt timing, queue commands, autowalk, gold, diag, flee, and party/walker events. CI cannot fully replace this. | HIGH |

### Optional Runtime Integration

| Technology | Role | Recommendation | What Not To Do | Confidence |
|------------|------|----------------|----------------|------------|
| demonnicAutoWalker | External walking package; boop decides when a room is clear, walker decides where to go | Keep optional. Integrate through `demonwalker` API/events and clear install/status feedback. | Do not absorb walker logic into boop before 1.0. Do not make boop unusable when walker is absent. | HIGH repo / MEDIUM web |
| SVO/Wundersys/large hunting systems | Out-of-scope external frameworks | Keep out of runtime dependencies. | Do not introduce framework-specific queue/state integrations before 1.0. | HIGH |

## Runtime Assumptions

### Mudlet And Lua

- Mudlet scripting uses Lua 5.1. Code should avoid `goto`, `_ENV`, `table.pack`, native bitwise operators, integer-subtype assumptions, and Lua 5.3+ pattern/library behavior.
- Treat Mudlet globals as runtime services, not always-present module imports. Keep guards around `send`, `sendGMCP`, `gmcp`, `db`, `tempTimer`, `killTimer`, `registerAnonymousEventHandler`, `cecho`, `cechoLink`, `installPackage`, and trigger enable/disable APIs.
- Prefer direct Lua functions and Mudlet APIs over `expandAlias`-style command indirection for internal behavior.
- `tempTimer` is asynchronous. Tests should capture callbacks where possible rather than sleeping.
- Event handlers must remain idempotent across reload/reconnect. Duplicate handlers and stale timer IDs are a release risk.

### Achaea GMCP

- Continue negotiating support for `IRE.Target 1`, `IRE.Display 3`, and `Char.Skills 1`; keep reconnect and missing-`gmcp.IRE` re-announcement coverage.
- Use `Char.Items.*` as the primary source for room denizens and inventory/wield tracking. Preserve the current denizen rule: room item `attrib` includes `m` and excludes non-target flags such as `x`/`d`.
- Use `IRE.Target.Set` / `IRE.Target.Info` for current target identity and HP percent when available. Keep targeting ID-based (`settarget <id>`), not name-based.
- Use `Char.Skills.Get` for skill gating. Treat skill/status/vitals values as stringly typed and partial-update-prone.
- Treat `gmcp.IRE.Display.ButtonActions` as useful but not sufficient by itself. Current Nexus GMCP docs document `IRE.Display` sparsely compared with boop's observed usage, so rage readiness needs fallbacks and live validation.
- If GMCP requests fail after reconnect/package reload, investigate Mudlet's documented IRE `sendGMCP` quirk before papering over missing support with broad text fallbacks.

### Achaea Command Channel

- Outbound command construction is part of the stack, not just business logic. Any user-controlled command fragment that can reach `send()` needs validation before persistence or dispatch.
- Highest-risk fragments for pre-1.0: command separator, pull direction/mob fragment, pack/container, weapon/item IDs, assist leader/party call text, queue payloads, and any future custom command setting.
- Prefer raw GMCP item IDs for exact inventory/wield actions. Do not normalize IDs as human-readable labels.

## Testing Recommendations

### Keep This Test Shape

1. Build with Muddler from `mfile` and `src/`.
2. Import the generated `.mpackage` into a real Mudlet profile.
3. Run Busted specs inside Mudlet with `TESTS_DIRECTORY`, `AUTORUN_BUSTED_TESTS`, `QUIT_MUDLET_AFTER_TESTS`, and `PRETEST_PACKAGE`.
4. Stub Mudlet side effects only at boundaries: `send`, `sendGMCP`, timers, rich output, package install, and DB save hooks.
5. Exercise production domains directly: targets, runtime/coordinator, combat planner, attacks, rage, skills, gold, diag, safety, stats, UI registries, gags, and walker boundary.

### Add Or Strengthen These Gates Before 1.0

| Gate | Why | Suggested Check |
|------|-----|-----------------|
| Version synchronization | Required by repo workflow; release artifacts are versioned from `mfile` | CI script compares `mfile.version`, `mfile.title`, `boop.version`, and CODEX checkpoint if kept current |
| Manifest parity | Muddler silently depends on JSON manifests matching files | Script walks manifest entries and verifies referenced Lua/JSON files exist; flags orphaned package files |
| JSON validity | Manifest syntax breaks packaging | `jq` parse all `*.json` under `src/` plus `mfile` |
| Load-order protection | `src/scripts/boop/scripts.json` is runtime-sensitive | Test asserts known critical order, or at minimum excludes it from auto-sort and documents order groups |
| Command-fragment validation | User-controlled config can become game commands | Unit specs for accepted/rejected separators, directions, item IDs, names, and queue fragments |
| Autowalk regression | External walker boundary is event/timer-heavy | Specs for missing walker, install path, start/stop/move, arrived/finished events, blockers, room-settled gating, gold/diag/flee interactions |
| Gag fixture coverage | Achaea combat text changes are easy to break | Fixture-driven tests from live logs for self, other-player, mob, kill, crit, shield, rage, pet/follow-through, and unusual warning lines |
| GMCP reconnect | Current checkpoint calls this out | Specs for `sysConnectionEvent`, missing `gmcp.IRE`, support re-announcement, and safe nil handling |

### What Not To Add Before 1.0

- Do not replace Busted with another Lua test framework.
- Do not move primary tests to pure host Lua only; Mudlet APIs and package import behavior are the point of the release gate.
- Do not add coverage tooling unless it is cheap and does not destabilize the Mudlet run. Behavior coverage matters more than a percentage target here.
- Do not add broad snapshot tests for whole dashboards. Prefer targeted text fragments and routing/link callback assertions.
- Do not mock the domain being tested. Mock the Mudlet boundary; run boop code.

## Packaging Recommendations

### Keep Muddler As The Builder

Muddler matches the repository structure and project constraints: `mfile` at root, source under `src/`, JSON manifests for Mudlet objects, Lua files read by convention, and generated `.mpackage` output. Replacing it before 1.0 would add release risk without improving the known hardening problems.

Recommended release build path:

```bash
muddle
```

Recommended package-source constraints:

- Keep package content under `src/`.
- Keep generated files under `build/` out of manual edits.
- Keep `src/scripts/boop/scripts.json` manually ordered.
- Run `tools/sort_manifests.sh` only for manifests it intentionally handles.
- Ensure any new alias/trigger/script updates its nearest manifest.
- Keep `mfile.outputFile` behavior consistent with CI artifact expectations.

### Improve Reproducibility

The current CI is workable for development, but pre-1.0 release confidence benefits from tighter pins:

- Prefer versioned GitHub Actions where available.
- If keeping `demonnic/build-with-muddler@main`, log the resolved action SHA and Muddler version in CI output.
- Keep the Mudlet AppImage explicit. CI currently uses `Mudlet-4.20.1-linux-x64.AppImage.tar`; that is acceptable as a floor even though newer Mudlet versions exist.
- Keep uploaded artifact name derived from `mfile.package` and `mfile.version`.

## External Documentation Assumptions

| Topic | Source Of Truth | How To Use It | Confidence |
|-------|-----------------|---------------|------------|
| Mudlet Lua version and APIs | Mudlet wiki/manual | Use for Lua 5.1, `sendGMCP`, timers, event handlers, DB, package manager, UI functions | MEDIUM |
| Achaea/Iron Realms GMCP | Current Nexus GMCP docs, cross-checked with Achaea GMCP PDF | Nexus is current; Achaea PDF is historical detail for module semantics | MEDIUM |
| Muddler | demonnic/muddler repo and wiki raw docs | Use for `mfile`, `src/` layout, manifest conventions, token replacement, local `muddle` build | MEDIUM |
| Busted | LunarModules Busted docs | Use for Lua 5.1-compatible spec framework assumptions | MEDIUM |
| Real Mudlet CI | demonnic/test-in-mudlet docs plus existing boop workflow | Keep the concept, but boop's custom workflow is the local source of truth | MEDIUM |
| Achaea live combat text | Live logs and boop fixtures | Official docs are insufficient; validate from real game output | HIGH for local fixtures once captured |
| demonnicAutoWalker | demonnicAutoWalker README and live package behavior | Use documented events/API; verify installed-version behavior live | MEDIUM |

## Alternatives Considered

| Category | Recommended | Alternative | Why Not |
|----------|-------------|-------------|---------|
| Runtime | Mudlet Lua 5.1 | Lua 5.4/LuaJIT-specific runtime | Mudlet scripting target is Lua 5.1; newer features would break users or tests |
| Build | Muddler | Hand-authored Mudlet XML/package artifacts | Error-prone, unreadable, bypasses existing source/manifests |
| Build | Muddler | New custom Node/Python builder | Adds a release-critical tool with no user-facing payoff before 1.0 |
| Tests | Busted inside Mudlet | Pure host Lua only | Misses Mudlet package import, globals, DB, event/timer, and rich UI behavior |
| Tests | Existing Busted | LuaUnit/Plenary/custom harness | Fragmentation without solving current risk areas |
| Persistence | Mudlet DB | JSON files or global serialized Lua files | DB is already established and matches Mudlet persistence patterns |
| Walking | Optional demonnicAutoWalker integration | Build internal walker | Out of scope; existing design keeps walking as a separate domain |
| Hunting ecosystem | Self-contained boop | SVO/Wundersys/large external framework dependency | Violates product scope and complicates support/compatibility |
| Distribution | `.mpackage` artifact | Mudlet package repository / `mpkg` as required install path | `mpkg` may be useful later, but direct `.mpackage` release is simpler for 1.0 |

## Installation And Developer Commands

```bash
# Build package from repo root
muddle

# Sort safe manifests only; intentionally skips load-order-sensitive scripts manifest
tools/sort_manifests.sh

# CI-equivalent local Mudlet run shape, after building and preparing a test profile
AUTORUN_BUSTED_TESTS="true" \
TESTS_DIRECTORY="$PWD/tests" \
QUIT_MUDLET_AFTER_TESTS="true" \
PRETEST_PACKAGE="$PWD/build/boop Hunter.mpackage" \
/tmp/Mudlet.AppImage --profile "GithubTests" --mirror
```

No `npm install`, Python package install, or application-level LuaRocks runtime dependency should be introduced for boop itself before 1.0. LuaRocks dependencies belong to CI/test setup only.

## Phase Implications

1. **Release gates first** - Add version sync, JSON parse, manifest parity, and package metadata checks before deeper behavior churn.
2. **State ownership and command validation next** - These touch outbound commands and runtime safety; test them through Busted-in-Mudlet with boundary stubs.
3. **Autowalk and GMCP hardening after that** - Requires event/timer coverage and live validation against Mudlet/Achaea timing.
4. **Gag/spam reduction last within hardening** - Needs fixture-backed tests from real logs because official docs do not cover combat prose.
5. **Docs/help coherence throughout** - Any command-surface change must update README/help/UI surfaces in the same phase.

## Research Flags

- **IRE.Display.ButtonActions:** boop uses it, but current Nexus docs document `IRE.Display` sparsely. Keep fallbacks and live validation.
- **Mudlet current vs CI floor:** Current public Mudlet releases are newer than 4.20.1. Keep 4.20.1 as a compatibility floor unless a bug forces a bump, then document the bump explicitly.
- **Action pinning:** `demonnic/build-with-muddler@main` is convenient but less reproducible. Release branches should either pin it or record the resolved SHA/version.
- **Achaea text fixtures:** Official GMCP docs do not validate gag/combat summaries. Live log fixtures are the only reliable source.
- **Command separator semantics:** The game-side separator is user-controlled and potentially dangerous if validation is loose. Treat this as a stack/security gate, not only a UX setting.

## Sources

- Local repo: `.planning/PROJECT.md`, `.planning/codebase/STACK.md`, `.planning/codebase/TESTING.md`, `.planning/codebase/INTEGRATIONS.md`, `README.md`, `DESIGN.md`, `CODEX.md`, `.github/workflows/main.yml`, `mfile`, `src/scripts/boop/boop_init.lua`.
- Mudlet Advanced Lua, Lua version: https://wiki.mudlet.org/w/Manual:Advanced_Lua
- Mudlet Networking Functions, `sendGMCP`: https://wiki.mudlet.org/w/Manual:Networking_Functions
- Mudlet Event Engine: https://wiki.mudlet.org/w/Manual:Event_Engine
- Mudlet Object Functions, `tempTimer`: https://wiki.mudlet.org/w/Manual:Mudlet_Object_Functions
- Mudlet Database Functions: https://wiki.mudlet.org/w/Manual:Database_Functions
- Mudlet Package Manager / package APIs: https://wiki.mudlet.org/w/Manual:Package_Manager
- Mudlet current release/download line: https://www.mudlet.org/download/
- Iron Realms Nexus GMCP docs: https://nexus.ironrealms.com/GMCP
- Achaea GMCP specification PDF: https://www.achaea.com/local/Achaea_GMCP_Spec_20140311.pdf
- demonnic/muddler: https://github.com/demonnic/muddler
- Muddler raw wiki usage docs: https://raw.githubusercontent.com/wiki/demonnic/muddler/Usage.md
- Muddler raw wiki scripts docs: https://raw.githubusercontent.com/wiki/demonnic/muddler/Scripts.md
- Muddler raw wiki triggers docs: https://raw.githubusercontent.com/wiki/demonnic/muddler/Triggers.md
- Muddler raw wiki aliases docs: https://raw.githubusercontent.com/wiki/demonnic/muddler/Aliases.md
- build-with-muddler action docs: https://raw.githubusercontent.com/demonnic/build-with-muddler/main/README.md
- test-in-mudlet action docs: https://raw.githubusercontent.com/demonnic/test-in-mudlet/main/README.md
- Busted docs: https://lunarmodules.github.io/busted/
- demonnicAutoWalker README: https://raw.githubusercontent.com/demonnic/demonnicAutoWalker/master/README.md
