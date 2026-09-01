# AGENTS.md

Repository-local instructions for Codex and future agent sessions.

## Session Startup
- Read `README.md` and `DESIGN.md` to understand current scope and user-facing behavior.
- Read `ARCHITECTURE.md` for how boop actually works today, and `ARCHITECTURE-RULES.md` before changing module boundaries.
- Read `UIDESIGN.md` when doing UI or UX work.
- Read `CODEX.md` for repo-specific workflow guidance.
- Check version fields before making changes.

## Versioning Rule
- Classify a commit from its staged paths before committing.
- A planning-only commit has every staged path under `.planning/`. Planning-only commits do not bump the package version.
- Any commit with a staged path outside `.planning/` is package-affecting and must monotonically bump all boop version fields together:
  - `mfile.version`
  - `mfile.title` to `boop Hunter <version>`
  - `src/scripts/boop/boop_init.lua` `boop.version`
  - the `CODEX.md` current synchronized package-version checkpoint
- Never leave those fields mismatched.
- Before committing or pushing, inspect staged paths and run `python3 tools/check_release_gates.py`.

## Terminal CI Gate
- GSD may create planning-only SUMMARY, STATE, ROADMAP, REQUIREMENTS, and phase-completion commits without a package version bump.
- After a GSD workflow finishes all repository mutations, the parent Codex session must push the immutable final HEAD and run `tools/wait_for_exact_ci.sh`.
- This gate is blocking. It requires a successful `main.yml` run whose `headSha` exactly matches final HEAD.
- CI evidence is reported to the user and is not committed. Any later repository mutation invalidates the evidence and requires the gate to run again.

## Workflow
- Work only under `src/` for package content; never edit built artifacts.
- Keep user-facing docs and command help in sync with command-surface changes.
- Prefer polish, consistency, operator clarity, and stability over feature expansion.
