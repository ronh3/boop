# boop

Standalone Mudlet package for Achaea auto hunting.

## Status
- Functional core: targeting, attacks, rage readiness, safety, DB-backed lists.
- Class profiles: Occultist and Magi configured; other classes stubbed. Dragon standards share `incant`/`tailsmash`.
- IH integration: `ih` output is re-rendered with clickable whitelist/blacklist buttons for denizens.
- Skill gating uses GMCP `Char.Skills.*` info for standard/rage abilities.
- Targeting uses denizen IDs (IRE.Target.Set by id), not names.

## Commands
- `boop` (status + main help dashboard)
- `bh` (toggle on/off)
- `boop on` / `boop off`
- `boop help` / `boop help <number|topic|home>` (examples: `boop help 2`, `boop help whitelist`)
- `boop status` (current settings/status dashboard)
- `boop config` / `boop config <number|section|section number|back|home>` (menu-style config flow)
- `boop autogold` / `boop autogold on` / `boop autogold off`
- `boop pack` / `boop pack <container>` / `boop pack off` / `boop pack test` (auto-stash container for sovereigns)
- `boop import foxhunt [merge|overwrite|dryrun]` (imports Foxhunt DB whitelist/blacklist into boop)
- `boop prequeue` / `boop prequeue on` / `boop prequeue off`
- `boop lead` / `boop lead <seconds>` (prequeue lead timing)
- `boop get [key]` / `boop set <key> <value>`
- `boop trace` / `boop trace on|off|show [n]|clear`
- `boop targeting <manual|whitelist|blacklist|auto>`
- `boop ragemode <simple|dam|big|small|aff|cond|buff|pool|none>` (default: `simple`)
- `diag` (queue-clear + diagnose; temporarily pauses boop attacks until diagnose result + prompt)
- `boop ih` (also overrides `ih`)
- `boop whitelist` / `boop whitelist add <name>` / `boop whitelist remove <name>` (display is clickable: up/down/remove)
- `boop whitelist browse [tag]` (browse whitelist areas; optional tag filter)
- `boop whitelist tags <area>` / `boop whitelist tag list`
- `boop whitelist tag add <area> | <tag[,tag2,...]>`
- `boop whitelist tag remove <area> | <tag[,tag2,...]>`
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
- Whitelist areas can have multiple tags (for example `continent-a`, `newbie`, `high-end`) for browse/filter workflows.
- Whitelist tags are normalized to lowercase and `-` separators, so `Mid Level` becomes `mid-level`.
- `boop ih` shows items too; only denizens get whitelist/blacklist buttons.
- Auto gold pickup grabs newly dropped room items whose names contain `gold sovereign`.
- In queueing mode, auto gold pickup is prepended to the next standard attack as `get sovereigns/<attack>`.
- If no standard attack follows quickly, boop falls back to `queue add freestand get sovereigns` (also used in non-queueing mode to avoid balance-lock misses).
- If `boop pack <container>` is set, boop follows pickup with `put sovereigns in <container>`.
- Gold get/put has trigger-based success/failure tracking with limited retries and warning output when retries are exhausted.
- For `Two Handed` spec with `Focus` known in `Weaponmastery`, boop prepends `battlefury focus speed/` to standard damage attacks (never shieldbreakers).
- For `Unnamable` with `Maul` known in `Dominion`, boop prepends `maul &tar/` to standard attacks while ready, then waits for the cooldown-ready line before prepending again.
- `diag` clears queue, queues `diagnose`, and pauses attacks until `You are: ...` or `You are in perfect health.` and the following prompt (with timeout fallback via `diagTimeoutSeconds`).
- Prequeue is separately configurable from queueing (`boop prequeue`); when enabled, it queues standard attacks before recovery using `boop lead` seconds (default `1.00`).
- Warrior classes (Infernal/Paladin/Runewarden) use `gmcp.Char.Vitals` `Spec` to select standard attacks.
- In queueing mode, boop caches the last `BOOP_ATTACK` alias payload and skips redundant `setalias` sends when unchanged.
- Trace buffer records recent boop decisions/commands for post-mortem debugging (`boop trace show`).
- Foxhunt import reads Mudlet DB `hunting` lists directly; `merge` is default, `overwrite` clears boop lists first, `dryrun` reports counts only.

## Starting A Session
- See `CODEX.md` (Session Startup).

## Build
- Use Muddler from repo root (see `CODEX.md` for exact guidance).
