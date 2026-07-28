# CODEX.md

Guidance for Codex when working in this repository.

## Project Overview
- Standalone Mudlet package for Achaea auto hunting.
- Package metadata lives in `mfile` (package/name/version); keep it current.
- Packaged source of truth is under `src/` (scripts/aliases/triggers).
- Target namespace: `boop`.
- Rage readiness prefers GMCP `IRE.Display` when available.

## Build System (Muddler)
- Work only in `src/` JSON + Lua files; never edit built artifacts.
- `mfile` version drives `@VERSION@`/`@PKGNAME@` replacements in code.
- Each object folder needs a manifest JSON: `scripts.json`, `aliases.json`, `triggers.json`, etc.
- Names in JSON map to Lua filenames (spaces → underscores).
- Build locally with `muddle` (or Docker wrapper) from repo root; output typically under `build/tmp/` unless `outputFile` changes.

## Current Source Layout
- `src/scripts/` — core Lua scripts; manifest at `src/scripts/scripts.json`.
- `src/scripts/boop/attacks/` — class attack tables (one file per class).
- `src/aliases/` — alias scripts; manifests can be nested (e.g., `src/aliases/aliases.json` and subfolders).
- `src/triggers/` — trigger scripts; manifest at `src/triggers/triggers.json`.

## JSON Tips (Muddler)
- Always double-escape backslashes in regex patterns: `"^\\d+$"`.
- `isFolder` `"yes"` entries create nesting; leaf entries set `script` to the Lua file stem.
- Trigger pattern types: `substring`, `regex`, `startOfLine`, `exactMatch`, `lua`, `prompt`, `color/colour`, `spacer`.

## CI & Versioning
- CI reads `mfile` for `package` and `version`, builds with Muddler, and uploads `build/tmp/` as `<package>-<version>`.
- Classify commits by staged paths. A commit is planning-only only when every staged path is under `.planning/`; planning-only commits do not bump the package version.
- Any commit that includes a path outside `.planning/` is package-affecting: bump the boop version monotonically and synchronize all four checkpoints.
- Sync rule: every version bump must update all four checkpoints together with the exact same version value:
  - `mfile.version`
  - `mfile.title` as `boop Hunter <version>`
  - `src/scripts/boop/boop_init.lua` `boop.version`
  - this file's `Current synchronized package version` checkpoint
- Never commit or push with those version fields mismatched.
- Run the local release gate before pushing:
  - `python3 tools/check_release_gates.py`
  - `python3 tools/check_release_gates.py --check versions`
  - `python3 tools/check_release_gates.py --check manifests`
  - `python3 tools/check_release_gates.py --check state-drift`
- Full local Mudlet Busted path, when `/tmp/Mudlet.AppImage` is available:
  `muddle && AUTORUN_BUSTED_TESTS=true TESTS_DIRECTORY="$PWD/tests" QUIT_MUDLET_AFTER_TESTS=true PRETEST_PACKAGE="$PWD/build/boop Hunter.mpackage" /tmp/Mudlet.AppImage --profile "GithubTests" --mirror`
- If `/tmp/Mudlet.AppImage` is not available locally, use the GitHub Actions Mudlet run as the authoritative full-suite fallback.
- Do not treat the host's default LuaRocks/Busted tree as authoritative unless it is a Lua 5.1-compatible tree built for Mudlet-style execution; this repo's CI intentionally mirrors `demonnic/test-in-mudlet` with Lua 5.1.5, Busted, the `GithubTests` profile, and Xvfb.
- After a GSD workflow finishes every source, documentation, SUMMARY, STATE, ROADMAP, REQUIREMENTS, and phase-completion commit, push immutable final HEAD and run `tools/wait_for_exact_ci.sh`. The script's exact-`headSha` success is the blocking terminal authority; any later repository mutation requires it to run again.

## Workflow Reminders
- Keep structure shallow and logical.
- Prefer the Mudlet DB for data; use small Lua tables only for config.
- Use `cecho` tags for colored output; avoid mixing `decho`-style tags.
- Make aliases responsive with confirmation output when they do not already emit results.
- When adding new scripts, update the right manifest JSON and name files accordingly.
- Keep `mfile` version, title, and description current; tokens replace on build.
- Inspect staged paths and run `python3 tools/check_release_gates.py` before every commit and again before every push.
- Explain the reasoning behind code changes in responses. Do not make non-trivial changes without verifying with the user first.
- Commit and push changes unless the user asks otherwise.
- Keep `README.md` in sync when commands or features change.
- Maintain the config UI look/feel (config theme + sectioned layout) for new menus.
- When the user says there was a failure/error, inspect `output.md` by default before asking for more detail.

## User Preferences / Project Memory
- Treat `CODEX.md` as the continuity file for new sessions; keep it current when preferences or workflow conventions change.
- Push non-trivial changes after committing them. If a version was bumped, the expectation is to push unless the user says not to.
- Keep all four boop version checkpoints synchronized. Planning-only commits may preserve the current version; package-affecting commits must bump it.
- Avoid surfacing legacy/old command behavior in user-facing help or docs unless the user explicitly asks for backwards-compat details.
- `boop` by itself should open the home dashboard. `boop help` should show help only.
- `bh` and `boop on/off` should use the compact boop aesthetic summary, not the full dashboard.
- Preserve the newer, streamlined boop UI direction: workflow-first help, fewer broader config sections, and direct paths from common goals to commands.
- Prefer runtime-safe refactors over aggressive cleanup.
- The user is aiming for a 1.0 release; prefer polish, clarity, and release-readiness work over broad feature expansion unless a real usage gap is identified.
- Future party/dashboard follow-up: add reporting for the current area's whitelist on `boop party`.
- If the command surface changes, update aliases, help text, `boop stats help` when relevant, `README.md`, and `UIDESIGN.md` together so the shipped contract stays consistent.

## Current UI / UX Conventions
- Keep boop output in the established styled format using `cecho` color tags and sectioned headers where appropriate.
- Help and config should share the same overall visual language.
- Status is the place for current settings; help is the place for reference/documentation.
- Help should start from user goals and first steps before listing reference commands; normal workflows should get normal topics rather than being hidden in diagnostics.
- New user-facing command output should acknowledge success/failure clearly and should not silently fail.
- `boop control`, `boop config`, `boop party`, and `boop stats` are now primary surfaces and should be treated as the canonical operator workflow.
- Footer breadcrumb/help commands should remain clickable in rich Mudlet rendering.

## Current Structure Notes
- Trigger folders are now nested by class/category where practical.
- `src/triggers/boop/Gag/` is organized into class folders, each with its own `triggers.json`.
- `src/triggers/boop/Shield/` is organized into class folders, each with its own `triggers.json`.
- `src/triggers/boop/Rage/Afflictions/` is organized into class folders, each with its own `triggers.json`.
- When adding triggers in those areas, update the class-local manifest rather than flattening files back into the parent folder.
- `tools/sort_manifests.sh` is safe to run for manifests, except for known load-order-sensitive files already excluded by the script.
- Mudlet CI now runs real in-Mudlet `busted` specs; prefer extending that suite when fixing real regressions.

## Session Startup (New Agent Checklist)
- Read `README.md` and `DESIGN.md` to understand current scope and user-facing behavior.
- Read `UIDESIGN.md` as well when doing UI or UX work; it is now lagging less and should be kept in sync.
- Open `mfile`, `src/scripts/boop/boop_init.lua`, and this checkpoint to confirm synchronized versions. Bump all four only for package-affecting commits; preserve them for planning-only commits.
- Work only under `src/` for package content; never edit built artifacts.
- Use the existing `boop` namespace and follow the current file/manifest layout.
- For gameplay behavior questions, prefer the existing reference implementations (Basher/Bashing/Foxhunt) and our current code as the source of truth unless instructed otherwise.
- If implementing new commands or flows, update `README.md` and ensure aliases/triggers are registered in the proper manifest JSON.
- For party/leader/walker behavior, assume `demonnicAutoWalker` remains an external dependency and boop should integrate with it rather than absorb it.

## Session Checkpoint
- Branch to continue from: `codex/pre-1.0-hardening-pass`
- The branch tip moves with normal hardening commits; rely on git history rather than this file for the exact latest hash.
- Current synchronized package version: `0.1.434`
- The purposeful pre-1.0 hardening work that is currently in this branch:
  - runtime/state ownership and coordinator path
  - combat planner split from execution
  - UI/config/help registries
  - UI registry migration follow-up fixes, including `boop pack test` behavior and misleading help numbering on non-action rows
  - workflow-first in-game help, including dedicated loot/import, targeting, combat, party, and stats topics
  - GMCP support re-announcement on reconnect / missing-`gmcp.IRE` fallback
  - compatibility cleanup: the legacy flat `boop.state.<key>` bridge has been removed
- Intentionally not in this branch:
  - the local Muddler/dev auto-update helper (`boop dev`) was rolled back on purpose and should stay out unless explicitly requested again
- Important compatibility note for any future session:
  - internal code now uses owned state domains directly: `boop.state.combat`, `targeting`, `gold`, `queue`, `diag`, `trace`, `rage`, `inventory`, `ih`, `gag`
  - any personal/debug Mudlet scripts that still read old flat keys like `boop.state.currentTargetId`, `boop.state.goldGetPending`, or `boop.state.diagHold` will now break and must be updated
- Current project status:
  - the major refactor is considered landed
  - the package is in release-hardening mode, not broad-architecture mode
  - next work should be driven by live Mudlet regressions and release polish, not new structural churn
- Best next-session validation focus after restart:
  - `boop`, `boop control`, `boop config`, `boop party`, `boop help`, `boop stats help`
  - targeting/retarget flow
  - gold pickup + pack flow
  - `diag` and one queued interrupt (`matic`/`fly`/etc.)
  - reconnect/package reload and confirm `gmcp.IRE` returns without manual `sendGMCP`
