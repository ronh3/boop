# boop

Standalone Mudlet package for Achaea auto hunting.

## Status
- Functional core: targeting, attacks, rage readiness, safety, DB-backed lists.
- Class profiles: Occultist and Magi configured; other classes stubbed. Dragon standards share `incant`/`tailsmash`.
- IH integration: `ih` output is re-rendered with clickable whitelist/blacklist buttons for denizens.
- Skill gating uses GMCP `Char.Skills.*` info for standard/rage abilities.
- Targeting uses denizen IDs (IRE.Target.Set by id), not names.

## Commands
- `boop` (toggle on/off)
- `boop on` / `boop off`
- `boop status`
- `boop targeting <manual|whitelist|blacklist|auto>`
- `boop ih` (also overrides `ih`)
- `boop whitelist` / `boop whitelist add <name>` / `boop whitelist remove <name>`
- `boop blacklist` / `boop blacklist add <name>` / `boop blacklist remove <name>`
- `boop aff` / `boop aff add <a/b>` / `boop aff remove <a/b>` / `boop aff clear`
- `boop debug` / `boop debug attacks` / `boop debug skills` / `boop debug skills dump`
- `boop trip start` / `boop trip stop`
- `boop flee`

## Notes
- Standard attacks and rage actions are independent and can fire together.
- Denizens come from `gmcp.Char.Items.List` with attrib `m` and exclude `x`/`d`.
- `boop ih` shows items too; only denizens get whitelist/blacklist buttons.

## Starting A Session
1. Connect with GMCP enabled. `boop` bootstraps on load and is **off** by default.
2. Choose targeting mode (default is `whitelist`):
   - `boop targeting auto` to hit any denizen, or
   - stay on `whitelist` and add targets via `boop ih` / `ih`.
3. Run `boop ih` (or `ih`) in the area and click `[+whitelist]` or `[+blacklist]` as needed.
4. Start hunting with `boop on` (or toggle with `boop`).
5. Use `boop status` or `boop debug` if nothing is attacking (check eq/bal, target count, class, and rage).

Session data (whitelist/blacklist/config) is persisted in the Mudlet DB, so reconnects keep your settings.

## Build
- Use Muddler from repo root (see `CODEX.md` for exact guidance).
