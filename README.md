# boop

Standalone Mudlet package for Achaea auto hunting.

## Status
- Functional core: targeting, attacks, rage readiness, safety, DB-backed lists.
- Class profiles: Occultist and Magi configured; other classes stubbed. Dragon standards share `incant`/`tailsmash`.
- IH integration: `ih` output is re-rendered with clickable whitelist/blacklist buttons for denizens.
- Skill gating uses GMCP `Char.Skills.*` info for standard/rage abilities.
- Targeting uses denizen IDs (IRE.Target.Set by id), not names.

## Commands
- `bh` (toggle on/off)
- `boop on` / `boop off`
- `boop help` / `boop help <topic>` (examples: `boop help whitelist`, `boop help players`, `boop help queueing`)
- `boop status`
- `boop config` (interactive clickable config dashboard)
- `boop players` / `boop players add <name>` / `boop players remove <name>` (ignored-player whitelist)
- `boop autogold` / `boop autogold on` / `boop autogold off`
- `boop targeting <manual|whitelist|blacklist|auto>`
- `boop ragemode <simple|dam|big|small|aff|cond|buff|pool|none>` (default: `simple`)
- `boop ih` (also overrides `ih`)
- `boop whitelist` / `boop whitelist add <name>` / `boop whitelist remove <name>` (display is clickable: up/down/remove)
- `boop blacklist` / `boop blacklist add <name>` / `boop blacklist remove <name>` (display is clickable: up/down/remove)
- `boop aff` / `boop aff add <a/b>` / `boop aff remove <a/b>` / `boop aff clear`
- `boop debug` / `boop debug attacks` / `boop debug skills` / `boop debug skills dump`
- `boop trip start` / `boop trip stop`
- `boop flee`

## Notes
- Standard attacks and rage actions are independent and can fire together.
- `boop ragemode big` pools rage until a `Big Damage` rage attack is usable; it only uses `Small Damage` while big is on cooldown.
- Denizens come from `gmcp.Char.Items.List` with attrib `m` and exclude `x`/`d`.
- Denizen name matching for whitelist/blacklist is case-insensitive and normalizes straight/curly apostrophes.
- `boop ih` shows items too; only denizens get whitelist/blacklist buttons.
- Auto gold pickup grabs newly dropped room items whose names contain `gold sovereign`.
- In queueing mode, auto gold pickup is prepended to the next standard attack as `get sovereigns/<attack>`.
- If no standard attack follows quickly, boop falls back to `queue add freestand get sovereigns`.
- For `Two Handed` spec with `Focus` known in `Weaponmastery`, boop prepends `battlefury focus speed/` to standard damage attacks (never shieldbreakers).
- For `Unnamable` with `Maul` known in `Dominion`, boop prepends `maul &tar/` to standard attacks while ready, then waits for the cooldown-ready line before prepending again.
- With `ignoreOtherPlayers` off, non-whitelisted players in room pause hunting; manage the whitelist with `boop players`.
- Standard attacks prequeue ~1s before balance/eq recovers using `Balance used:`/`Equilibrium used:` timing lines.
- Warrior classes (Infernal/Paladin/Runewarden) use `gmcp.Char.Vitals` `Spec` to select standard attacks.
- In queueing mode, boop caches the last `BOOP_ATTACK` alias payload and skips redundant `setalias` sends when unchanged.

## Starting A Session
- See `CODEX.md` (Session Startup).

## Build
- Use Muddler from repo root (see `CODEX.md` for exact guidance).
