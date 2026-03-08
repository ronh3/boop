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
- Versioning: bump `mfile.version` on every change we commit/merge (even docs/config-only); keep it monotonically increasing.
- Title policy: update `mfile.title` manually on each version bump to `boop Hunter <version>` (for example `boop Hunter 0.1.35`).

## Workflow Reminders
- Keep structure shallow and logical.
- Prefer the Mudlet DB for data; use small Lua tables only for config.
- Use `cecho` tags for colored output; avoid mixing `decho`-style tags.
- Make aliases responsive with confirmation output when they do not already emit results.
- When adding new scripts, update the right manifest JSON and name files accordingly.
- Keep `mfile` version, title, and description current; tokens replace on build.
- Explain the reasoning behind code changes in responses. Do not make non-trivial changes without verifying with the user first.
- Commit and push changes unless the user asks otherwise.
- Keep `README.md` in sync when commands or features change.
- Maintain the config UI look/feel (config theme + sectioned layout) for new menus.

## User Preferences / Project Memory
- Treat `CODEX.md` as the continuity file for new sessions; keep it current when preferences or workflow conventions change.
- Push non-trivial changes after committing them. If a version was bumped, the expectation is to push unless the user says not to.
- Keep `mfile.title` updated manually to `boop Hunter <version>`.
- Avoid surfacing legacy/old command behavior in user-facing help or docs unless the user explicitly asks for backwards-compat details.
- `boop` by itself should show status only. `boop help` should show help only.
- `bh` and `boop on/off` should use the compact boop aesthetic summary, not the full dashboard.
- Preserve the newer, streamlined boop UI direction: fewer broader help/config sections rather than many tiny topics.
- Prefer runtime-safe refactors over aggressive cleanup.

## Current UI / UX Conventions
- Keep boop output in the established styled format using `cecho` color tags and sectioned headers where appropriate.
- Help and config should share the same overall visual language.
- Status is the place for current settings; help is the place for reference/documentation.
- New user-facing command output should acknowledge success/failure clearly and should not silently fail.

## Current Structure Notes
- Trigger folders are now nested by class/category where practical.
- `src/triggers/boop/Gag/` is organized into class folders, each with its own `triggers.json`.
- `src/triggers/boop/Shield/` is organized into class folders, each with its own `triggers.json`.
- `src/triggers/boop/Rage/Afflictions/` is organized into class folders, each with its own `triggers.json`.
- When adding triggers in those areas, update the class-local manifest rather than flattening files back into the parent folder.
- `tools/sort_manifests.sh` is safe to run for manifests, except for known load-order-sensitive files already excluded by the script.

## Session Startup (New Agent Checklist)
- Read `README.md` and `DESIGN.md` to understand current scope and user-facing behavior.
- Open `mfile` to confirm current version and title; bump `version` and manually sync `title` on every commit.
- Work only under `src/` for package content; never edit built artifacts.
- Use the existing `boop` namespace and follow the current file/manifest layout.
- For gameplay behavior questions, prefer the existing reference implementations (Basher/Bashing/Foxhunt) and our current code as the source of truth unless instructed otherwise.
- If implementing new commands or flows, update `README.md` and ensure aliases/triggers are registered in the proper manifest JSON.
