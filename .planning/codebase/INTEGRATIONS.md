# External Integrations

**Analysis Date:** 2026-07-09

## APIs & External Services

**Game Runtime APIs:**
- Achaea GMCP / IRE modules - Targeting, room inventory, character state, skill gating, and rage readiness.
  - SDK/Client: Mudlet `sendGMCP` and `gmcp` globals in `src/scripts/boop/boop_init.lua`, `src/scripts/boop/boop_events.lua`, `src/scripts/boop/boop_runtime.lua`, `src/scripts/boop/boop_targets.lua`, `src/scripts/boop/boop_attacks.lua`, and `src/scripts/boop/boop_skills.lua`.
  - Auth: Not applicable; game session GMCP channel is provided by Mudlet/Achaea.
- Achaea command channel - Sends target, attack, queue, party, assist, loot, flee, diagnose, and interrupt commands.
  - SDK/Client: Mudlet `send()` in `src/scripts/boop/boop_targets.lua`, `src/scripts/boop/boop_util.lua`, `src/scripts/boop/boop_events.lua`, `src/scripts/boop/boop_rage.lua`, and `src/scripts/boop/boop_ui.lua`.
  - Auth: Not applicable; uses the connected Mudlet game session.

**Mudlet Runtime Services:**
- Mudlet package/event APIs - Registers anonymous event handlers, manages trigger folders, timers, rich links, output, package installation, and local DB.
  - SDK/Client: Mudlet globals in `src/scripts/boop/boop_init.lua`, `src/scripts/boop/boop_events.lua`, `src/scripts/boop/boop_db.lua`, `src/scripts/boop/boop_walk.lua`, `src/scripts/boop/boop_util.lua`, and `src/scripts/boop/boop_ui.lua`.
  - Auth: Not applicable.
- Mudlet package installer - Installs the optional `demonnicAutoWalker` package from GitHub releases.
  - SDK/Client: `installPackage()` and `boop.walk.packageUrl` in `src/scripts/boop/boop_walk.lua`.
  - Auth: Not detected.

**Optional Runtime Package:**
- `demonnicAutoWalker` - External walking package that owns path selection while boop decides when a room is clear.
  - SDK/Client: Global `demonwalker` table and Mudlet events `demonwalker.arrived`, `demonwalker.finished`, and `demonwalker.move` in `src/scripts/boop/boop_walk.lua` and `src/scripts/boop/boop_events.lua`.
  - Auth: Not applicable.

**Local Data Import:**
- Foxhunt Mudlet DB - Imports whitelist and blacklist data from the local `hunting` database.
  - SDK/Client: Mudlet DB client in `src/scripts/boop/boop_ui.lua`; source schema includes `hunting.whitelist`, `hunting.blacklist`, and `hunting.hconfig`.
  - Auth: Not applicable; reads local Mudlet profile database files.

**CI/Build Services:**
- GitHub Actions - Builds package, installs test dependencies, runs Mudlet tests, uploads artifacts, and comments on pull requests.
  - SDK/Client: Workflow actions and shell steps in `.github/workflows/main.yml`.
  - Auth: GitHub-provided `GITHUB_TOKEN` in `.github/workflows/main.yml`.
- GitHub Releases API - Downloads a Mudlet AppImage tarball from the repository release asset named by `MUDLET_RELEASE_TAG` and `MUDLET_RELEASE_ASSET`.
  - SDK/Client: `curl` against `https://api.github.com/repos/${GITHUB_REPOSITORY}/releases/tags/${MUDLET_RELEASE_TAG}` in `.github/workflows/main.yml`.
  - Auth: GitHub-provided `GITHUB_TOKEN` in `.github/workflows/main.yml`.
- External GitHub actions and repositories - CI uses `demonnic/build-with-muddler@main`, `leafo/gh-actions-lua@v8.0.0`, `leafo/gh-actions-luarocks@v4.0.0`, `GabrielBB/xvfb-action@v1.6`, `peter-evans/create-or-update-comment@v4`, and clones `https://github.com/demonnic/test-in-mudlet.git`.
  - SDK/Client: GitHub Actions runner in `.github/workflows/main.yml`.
  - Auth: Public actions/repos plus GitHub runner credentials.
- Olivine-Labs `mediator_lua` archive - CI installs a generated rockspec pointing at `https://github.com/Olivine-Labs/mediator_lua/archive/refs/tags/v1.1.2-0.tar.gz`.
  - SDK/Client: LuaRocks in `.github/workflows/main.yml`.
  - Auth: Not detected.

## Data Storage

**Databases:**
- Mudlet DB `boop` - Stores package config, whitelist, blacklist, whitelist tags, lifetime/session stats, and mob XP observations.
  - Connection: Local Mudlet profile DB; no env var is used.
  - Client: Mudlet `db:create`, `db:get_database`, `db:fetch`, `db:add`, `db:update`, and `db:delete` in `src/scripts/boop/boop_db.lua`.
  - Tables: `config`, `whitelist`, `blacklist`, `whitelist_tags`, `mob_xp`, `mob_xp_v2`, and `stats` in `src/scripts/boop/boop_db.lua`.
- Mudlet DB `hunting` - Optional Foxhunt import source.
  - Connection: Local Mudlet profile file `Database_hunting.db`; path is resolved with `getMudletHomeDir()` in `src/scripts/boop/boop_ui.lua`.
  - Client: Mudlet `db:get_database`, `db:create`, and `db:fetch` in `src/scripts/boop/boop_ui.lua`.

**File Storage:**
- Local Mudlet profile database files - Runtime persistence uses Mudlet DB files for `boop` and optional `hunting` databases through `src/scripts/boop/boop_db.lua` and `src/scripts/boop/boop_ui.lua`.
- Build artifacts - CI packages and uploads `build/tmp/`, and tests import `build/boop Hunter.mpackage` in `.github/workflows/main.yml`.
- CI logs - Failing Mudlet logs are uploaded from `/tmp/mudlet.raw.log` in `.github/workflows/main.yml`.
- Reference assets - Historical package assets include `Basher/src/resources/legacy logo.jpg` and `Bashing/src/resources/License.md`; active package source remains under `src/`.

**Caching:**
- Runtime cache: In-memory trace buffer stores up to 100 lines in `src/scripts/boop/boop_util.lua`; rage samples and timers are in `src/scripts/boop/boop_rage.lua`.
- CI cache: Mudlet AppImage is cached at `/tmp/Mudlet.AppImage` with `actions/cache@v4` in `.github/workflows/main.yml`.
- External cache service: Not detected for production runtime.

## Authentication & Identity

**Auth Provider:**
- Custom/game-session identity - Runtime identity comes from the connected Achaea/Mudlet session, including GMCP character fields and party-chat speaker names.
  - Implementation: `gmcp.Char.Status.name`, `gmcp.Char.Name.name`, assist leader names, and party speaker matching in `src/scripts/boop/boop_targets.lua`, `src/scripts/boop/boop_runtime.lua`, and `src/scripts/boop/boop_ui.lua`.
- CI identity - GitHub Actions uses the repository-scoped `github.token`.
  - Implementation: `GITHUB_TOKEN: ${{ github.token }}` in `.github/workflows/main.yml`.
- Web application auth: Not detected in `src/`, `tests/`, or `.github/workflows/main.yml`.

## Monitoring & Observability

**Error Tracking:**
- External error tracking service: Not detected.
- Runtime warnings/errors are emitted through `boop.util.warn()` and `boop.util.err()` in `src/scripts/boop/boop_util.lua`, with call sites across `src/scripts/boop/boop_db.lua`, `src/scripts/boop/boop_walk.lua`, `src/scripts/boop/boop_ui.lua`, and `src/scripts/boop/boop_events.lua`.

**Logs:**
- Mudlet output - Operator feedback uses `cecho`/`echo` in `src/scripts/boop/boop_util.lua` and rich UI output in `src/scripts/boop/boop_ui.lua`.
- Runtime trace - Optional `boop trace` stores recent decisions, GMCP room/item events, combat planning, queueing, walker state, and import outcomes in memory via `src/scripts/boop/boop_util.lua`, `src/scripts/boop/boop_events.lua`, `src/scripts/boop/boop_targets.lua`, `src/scripts/boop/boop_rage.lua`, and `src/scripts/boop/boop_ui.lua`.
- CI logs - Mudlet output is captured at `/tmp/mudlet.raw.log`, filtered by an inline Python script, and uploaded on failure in `.github/workflows/main.yml`.

## CI/CD & Deployment

**Hosting:**
- Runtime hosting: Not applicable; the product is a local Mudlet package generated from `mfile` and `src/`.
- Repository/CI: GitHub Actions in `.github/workflows/main.yml`.
- Artifact distribution: CI uploads `build/tmp/` as `${package}-${version}` using `actions/upload-artifact@v4` in `.github/workflows/main.yml`.

**CI Pipeline:**
- Build pipeline: `.github/workflows/main.yml` runs on pushes and pull requests targeting `main`, reads `mfile`, builds with `demonnic/build-with-muddler@main`, installs Lua/LuaRocks dependencies, downloads/caches Mudlet, installs `demonnic/test-in-mudlet`, runs Busted specs inside Mudlet, uploads logs/artifacts, and posts a PR preview comment.
- Local build path: `muddle` from the repository root as documented in `CODEX.md`.

## Environment Configuration

**Required env vars:**
- Runtime package: None detected; runtime config is persisted in Mudlet DB through `src/scripts/boop/boop_db.lua`.
- CI: `MUDLET_RELEASE_TAG`, `MUDLET_RELEASE_ASSET`, `GITHUB_TOKEN`, `AUTORUN_BUSTED_TESTS`, `TESTS_DIRECTORY`, `QUIT_MUDLET_AFTER_TESTS`, and `PRETEST_PACKAGE` in `.github/workflows/main.yml`.
- Tests: `TESTS_DIRECTORY` is required by `tests/support/boop_test_helper.lua`.

**Secrets location:**
- No `.env*` files are detected in the repository root.
- CI uses GitHub-provided `GITHUB_TOKEN` in `.github/workflows/main.yml`; no repository secret values are present in source files reviewed for this map.
- Runtime stores settings and lists in local Mudlet profile DB files through `src/scripts/boop/boop_db.lua`; do not treat these local profile DB files as committed source.

## Webhooks & Callbacks

**Incoming:**
- Mudlet GMCP event callbacks - Registered through `registerAnonymousEventHandler` in `src/scripts/boop/boop_events.lua` for `gmcp.Char.Items.*`, `gmcp.Room.Info`, `gmcp.IRE.Target.*`, `gmcp.Char.Status`, `gmcp.Char.Vitals`, `gmcp.Char.Skills.*`, and `sysConnectionEvent`.
- External walker callbacks - `demonwalker.arrived` and `demonwalker.finished` are registered in `src/scripts/boop/boop_events.lua`.
- Party chat callbacks - Trigger patterns in `src/triggers/boop/Core/triggers.json` feed target calls and whitelist packets into `src/triggers/boop/Core/Party_Target_Call.lua`, `src/triggers/boop/Core/Party_Whitelist_Share.lua`, and `src/scripts/boop/boop_targets.lua`.
- Text trigger callbacks - Gold, diagnosis, prompt, balance, gag, shield, and rage-affliction trigger folders are declared under `src/triggers/boop/**/*.json` and call handlers in `src/scripts/boop/boop_events.lua`, `src/scripts/boop/boop_rage.lua`, `src/scripts/boop/boop_gag.lua`, and `src/scripts/boop/boop_targets.lua`.
- HTTP webhooks: Not detected.

**Outgoing:**
- GMCP support/skill requests - `Core.Supports.Add`, `Char.Skills.Get`, and group/skill-specific requests are sent from `src/scripts/boop/boop_init.lua` and `src/scripts/boop/boop_skills.lua`.
- Achaea commands - `settarget`, standard attacks, rage attacks, `queue addclearfull freestand`, `setalias BOOP_ATTACK`, `queue add freestand get sovereigns`, party `pt` messages, assist-prefixed commands, flee, diagnose, and interrupts are sent from `src/scripts/boop/boop_targets.lua`, `src/scripts/boop/boop_util.lua`, `src/scripts/boop/boop_events.lua`, `src/scripts/boop/boop_rage.lua`, and `src/scripts/boop/boop_ui.lua`.
- Walker events - `demonwalker.move` is raised from `src/scripts/boop/boop_walk.lua`.
- Optional package install - `installPackage()` downloads `demonnicAutoWalker.mpackage` from GitHub releases in `src/scripts/boop/boop_walk.lua`.
- CI network calls - `.github/workflows/main.yml` downloads a Mudlet release asset through the GitHub API, fetches `mediator_lua` through LuaRocks, clones `demonnic/test-in-mudlet`, uploads artifacts, and posts PR comments.

---

*Integration audit: 2026-07-09*
