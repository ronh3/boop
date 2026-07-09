# Technology Stack

**Analysis Date:** 2026-07-09

## Languages

**Primary:**
- Lua 5.1-compatible - Active Mudlet package logic in `src/scripts/boop/*.lua`, command aliases in `src/aliases/boop/**/*.lua`, trigger handlers in `src/triggers/boop/**/*.lua`, and tests in `tests/*_spec.lua`. CI installs Lua `5.1.5` in `.github/workflows/main.yml`.

**Secondary:**
- JSON - Muddler package metadata and object manifests in `mfile`, `src/scripts/scripts.json`, `src/scripts/boop/scripts.json`, `src/aliases/aliases.json`, `src/aliases/boop/**/*.json`, `src/triggers/triggers.json`, and `src/triggers/boop/**/*.json`.
- Shell - Manifest maintenance and CI shell steps in `tools/sort_manifests.sh` and `.github/workflows/main.yml`.
- YAML - GitHub Actions workflow in `.github/workflows/main.yml`.
- Markdown - User and developer documentation in `README.md`, `DESIGN.md`, `UIDESIGN.md`, `CODEX.md`, `tests/README.md`, `testcmds.md`, and `testmenus.md`.
- Lua/JSON reference packages - Historical/source-reference packages live under `Basher/`, `Bashing/`, and `Foxhunt/`; the active package source of truth remains `src/` per `CODEX.md`.

## Runtime

**Environment:**
- Mudlet package runtime - Active package code uses Mudlet globals such as `send`, `sendGMCP`, `db`, `tempTimer`, `registerAnonymousEventHandler`, `installPackage`, `cecho`, and `cechoLink` in `src/scripts/boop/boop_init.lua`, `src/scripts/boop/boop_events.lua`, `src/scripts/boop/boop_db.lua`, `src/scripts/boop/boop_walk.lua`, `src/scripts/boop/boop_util.lua`, and `src/scripts/boop/boop_ui.lua`.
- Mudlet AppImage `4.20.1` is used for CI behavior tests via `MUDLET_RELEASE_ASSET` in `.github/workflows/main.yml`.
- Achaea/IRE GMCP runtime - The package requests `IRE.Target 1`, `IRE.Display 3`, and `Char.Skills 1` support in `src/scripts/boop/boop_init.lua` and consumes GMCP data in `src/scripts/boop/boop_events.lua`, `src/scripts/boop/boop_runtime.lua`, `src/scripts/boop/boop_targets.lua`, `src/scripts/boop/boop_attacks.lua`, and `src/scripts/boop/boop_skills.lua`.

**Package Manager:**
- Application runtime: no standalone language package manager is detected for active source; no `package.json`, `requirements.txt`, `pyproject.toml`, `go.mod`, `Cargo.toml`, or Lua rockspec exists at the repository root.
- CI test dependencies: LuaRocks installs `mediator_lua` and `busted` in `.github/workflows/main.yml`.
- Build packaging: Muddler is invoked locally as `muddle` per `CODEX.md` and through `demonnic/build-with-muddler@main` in `.github/workflows/main.yml`.
- Lockfile: missing for LuaRocks and GitHub Action dependencies; no lockfile is detected in the repository root.

## Frameworks

**Core:**
- Mudlet package APIs - Runtime API surface for event handlers, triggers, aliases, timers, local DB, package install, rich output, and command sending in `src/scripts/boop/boop_init.lua`, `src/scripts/boop/boop_events.lua`, `src/scripts/boop/boop_db.lua`, `src/scripts/boop/boop_walk.lua`, and `src/scripts/boop/boop_util.lua`.
- Muddler - Mudlet package builder driven by `mfile`, `src/scripts/scripts.json`, `src/scripts/boop/scripts.json`, `src/aliases/aliases.json`, `src/aliases/boop/**/*.json`, `src/triggers/triggers.json`, and `src/triggers/boop/**/*.json`.
- Achaea GMCP/IRE modules - Targeting, room inventory, character vitals/status, skills, and rage readiness use `gmcp.Char.Items.*`, `gmcp.Room.Info`, `gmcp.Char.Status`, `gmcp.Char.Vitals`, `gmcp.Char.Skills.*`, `gmcp.IRE.Target.*`, and `gmcp.IRE.Display.ButtonActions` in `src/scripts/boop/boop_events.lua`, `src/scripts/boop/boop_runtime.lua`, `src/scripts/boop/boop_targets.lua`, `src/scripts/boop/boop_attacks.lua`, and `src/scripts/boop/boop_skills.lua`.

**Testing:**
- Busted - Lua spec runner installed in `.github/workflows/main.yml`; specs are in `tests/*_spec.lua` with shared setup in `tests/support/boop_test_helper.lua`.
- Real Mudlet test harness - CI clones `demonnic/test-in-mudlet`, installs a `GithubTests` Mudlet profile, imports `build/boop Hunter.mpackage`, and runs Busted inside Mudlet through `.github/workflows/main.yml`.

**Build/Dev:**
- GitHub Actions - Build, package, run tests, upload artifacts, and comment on pull requests from `.github/workflows/main.yml`.
- `jq` - Reads `mfile` metadata in `.github/workflows/main.yml` and sorts JSON manifests in `tools/sort_manifests.sh`.
- `curl`, `tar`, `perl`, `python`, and `xvfb` - CI support tools for fetching the Mudlet AppImage, preparing the test profile, filtering logs, and running Mudlet headlessly in `.github/workflows/main.yml`.

## Key Dependencies

**Critical:**
- Mudlet - Required runtime for every active package file under `src/`; persistence depends on Mudlet DB APIs in `src/scripts/boop/boop_db.lua`.
- Achaea GMCP/IRE - Required for target IDs, room denizens, skill gating, rage readiness, character state, and room movement in `src/scripts/boop/boop_init.lua`, `src/scripts/boop/boop_events.lua`, `src/scripts/boop/boop_targets.lua`, `src/scripts/boop/boop_attacks.lua`, and `src/scripts/boop/boop_skills.lua`.
- Muddler - Required to produce the installable Mudlet package from `mfile` and `src/**` manifests; CI uses `demonnic/build-with-muddler@main` in `.github/workflows/main.yml`.
- Mudlet DB - Required for persisted config, whitelist/blacklist lists, whitelist tags, stats, and mob XP observations in `src/scripts/boop/boop_db.lua`; Foxhunt import reads another local Mudlet DB in `src/scripts/boop/boop_ui.lua`.
- `demonnicAutoWalker` - Optional runtime package used by `boop walk`; integration and installer URL are in `src/scripts/boop/boop_walk.lua`.

**Infrastructure:**
- `actions/checkout@v4`, `actions/cache@v4`, `actions/upload-artifact@v4` - Repository checkout, Mudlet AppImage caching, and artifact/log upload in `.github/workflows/main.yml`.
- `leafo/gh-actions-lua@v8.0.0` and `leafo/gh-actions-luarocks@v4.0.0` - Lua and LuaRocks setup in `.github/workflows/main.yml`.
- `GabrielBB/xvfb-action@v1.6` - Headless Mudlet test execution in `.github/workflows/main.yml`.
- `peter-evans/create-or-update-comment@v4` - Pull request build-preview comment in `.github/workflows/main.yml`.
- `mediator_lua` `1.1.2-0` - CI installs this rock from an Olivine-Labs GitHub tarball in `.github/workflows/main.yml`.
- `busted` - CI installs this Lua test framework through LuaRocks in `.github/workflows/main.yml`.

## Configuration

**Environment:**
- Package metadata is configured in `mfile`; active fields are `package: "boop Hunter"`, `title: "boop Hunter 0.1.318"`, `version: "0.1.318"`, and `outputFile: true`.
- Runtime defaults live in `src/scripts/boop/boop_init.lua` under `boop.defaults`; persisted user changes are loaded and saved through `src/scripts/boop/boop_db.lua`.
- Version fields are synchronized between `mfile` and `src/scripts/boop/boop_init.lua` (`boop.version = "0.1.318"`); the sync rule is documented in `AGENTS.md` and `CODEX.md`.
- No `.env*` files are detected in the repository root; runtime configuration is Mudlet DB-backed rather than environment-variable-backed.
- Test execution expects `TESTS_DIRECTORY`, `AUTORUN_BUSTED_TESTS`, `QUIT_MUDLET_AFTER_TESTS`, and `PRETEST_PACKAGE` in `.github/workflows/main.yml`; `tests/support/boop_test_helper.lua` requires `TESTS_DIRECTORY`.

**Build:**
- Build metadata: `mfile`.
- Source manifests: `src/scripts/scripts.json`, `src/scripts/boop/scripts.json`, `src/scripts/boop/attacks/scripts.json`, `src/aliases/aliases.json`, `src/aliases/boop/**/*.json`, `src/triggers/triggers.json`, and `src/triggers/boop/**/*.json`.
- CI workflow: `.github/workflows/main.yml`.
- Manifest sorting helper: `tools/sort_manifests.sh`; it intentionally skips `src/scripts/boop/scripts.json` because load order is runtime-sensitive.

## Platform Requirements

**Development:**
- Mudlet with package APIs for local runtime validation; active package files are under `src/` per `CODEX.md`.
- Muddler CLI (`muddle`) for local builds from the repository root as documented in `CODEX.md`.
- `jq` for `tools/sort_manifests.sh`; shell utilities are used by `.github/workflows/main.yml`.
- GitHub Actions runner uses Ubuntu, Lua `5.1.5`, LuaRocks, Mudlet AppImage `4.20.1`, `libfuse2`, `libopengl0`, `libegl1`, and xvfb in `.github/workflows/main.yml`.

**Production:**
- Deployment target is an installable Mudlet `.mpackage` generated from `src/` and `mfile`; CI imports `build/boop Hunter.mpackage` for tests and uploads `build/tmp/` as the versioned artifact in `.github/workflows/main.yml`.
- Runtime target is a Mudlet profile connected to Achaea with GMCP enabled; target support negotiation is performed in `src/scripts/boop/boop_init.lua`.
- Built artifacts under `build/` are generated output and are not active source per `CODEX.md`.

---

*Stack analysis: 2026-07-09*
