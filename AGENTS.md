# AGENTS.md

Repository-local instructions for Codex and future agent sessions.

## Session Startup
- Read `README.md` and `DESIGN.md` to understand current scope and user-facing behavior.
- Read `UIDESIGN.md` when doing UI or UX work.
- Read `CODEX.md` for repo-specific workflow guidance.
- Check version fields before making changes.

## Versioning Rule
- On every commit and every push, keep all boop version fields synchronized.
- Update `mfile.version`.
- Update `mfile.title` to `boop Hunter <version>`.
- Update `src/scripts/boop/boop_init.lua` `boop.version`.
- Never leave those fields mismatched.
- Before committing or pushing, verify the current version with a quick search/read of those files.

## Workflow
- Work only under `src/` for package content; never edit built artifacts.
- Keep user-facing docs and command help in sync with command-surface changes.
- Prefer polish, consistency, operator clarity, and stability over feature expansion.
