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

## Workflow Reminders
- Keep structure shallow and logical.
- Prefer the Mudlet DB for data; use small Lua tables only for config.
- Use `cecho` tags for colored output; avoid mixing `decho`-style tags.
- Make aliases responsive with confirmation output when they do not already emit results.
- When adding new scripts, update the right manifest JSON and name files accordingly.
- Keep `mfile` version and description current; tokens replace on build.
- Explain the reasoning behind code changes in responses. Do not make non-trivial changes without verifying with the user first.
- Commit and push changes unless the user asks otherwise.
- Keep `README.md` in sync when commands or features change.
- Maintain the config UI look/feel (config theme + sectioned layout) for new menus.

## Session Startup (New Agent Checklist)
- Read `README.md` and `DESIGN.md` to understand current scope and user-facing behavior.
- Open `mfile` to confirm current version; bump it on every commit.
- Work only under `src/` for package content; never edit built artifacts.
- Use the existing `boop` namespace and follow the current file/manifest layout.
- For gameplay behavior questions, prefer the existing reference implementations (Basher/Bashing/Foxhunt) and our current code as the source of truth unless instructed otherwise.
- If implementing new commands or flows, update `README.md` and ensure aliases/triggers are registered in the proper manifest JSON.
