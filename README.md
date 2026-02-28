# boop

Standalone Mudlet package for Achaea auto hunting.

## Status
- Functional core: targeting, attacks, rage readiness, safety, DB-backed lists.
- Class profiles: broad Foxhunt-derived profile coverage is included; some standards are intentionally simplified and marked for later refinement.
- IH integration: `ih` output is re-rendered with clickable whitelist/blacklist buttons for denizens.
- Skill gating uses GMCP `Char.Skills.*` info for standard/rage abilities.
- Targeting uses denizen IDs (IRE.Target.Set by id), not names.

## Commands
- `boop` (current settings/status dashboard)
- `bh` (toggle on/off)
- `boop on` / `boop off`
- `boop help` / `boop help <number|topic|home>` (examples: `boop help 2`, `boop help whitelist`)
- `boop status` (current settings/status dashboard)
- `boop config` / `boop config <number|section|section number|back|home>` (menu-style config flow)
- `boop party` / `boop party <class...>` / `boop party clear` (save party class roster; your own class is auto-included)
- `boop combos` / `boop combos <class...>` / `boop combos list` (party combo inference from rage afflictions + conditional needs)
- `boop autogold` / `boop autogold on` / `boop autogold off`
- `boop pack` / `boop pack <container>` / `boop pack off` / `boop pack test` (auto-stash container for sovereigns)
- `boop import foxhunt [merge|overwrite|dryrun]` (imports Foxhunt DB whitelist/blacklist into boop)
- `boop prequeue` / `boop prequeue on` / `boop prequeue off`
- `boop lead` / `boop lead <seconds>` (prequeue lead timing)
- `boop get [key]` / `boop set <key> <value>`
- `boop trace` / `boop trace on|off|show [n]|clear`
- `boop gag` / `boop gag on|off|own|others|all|<scope> on|off`
- `boop targeting <manual|whitelist|blacklist|auto>`
- `boop ragemode <simple|dam|big|small|aff|cond|combo|buff|pool|none>` (default: `simple`)
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
- Attack-line gagging can be toggled separately for your own attacks and other players' attacks, replacing matched lines with `Who: What -> Victim`.
- Weaponmastery standard attack lines (Two Handed + Sword and Shield) are included in gag replacement coverage.
- Self-attack gag mode now compacts Weaponmastery speed/damage/balance lines into one attack summary and condenses slain + experience into a single kill summary.
- When both summaries are pending, boop now emits the attack summary before the kill summary.
- Critical hit tiers are folded into the self attack summary as `- 2xCRIT/4xCRIT/8xCRIT/16xCRIT/32xCRIT`.
- Unnamable battlerage `Shriek` line is included in gag replacement coverage.
- Unnamable battlerage `Sunder` line is included in gag replacement coverage and shield-down tracking.
- Unnamable battlerage `Destroy` line is included in gag replacement coverage.
- Unnamable/Infernal pet maul command lines (`hound maul`/`hyena maul`) are included in gag replacement coverage so their damage/crit can fold into a compact summary.
- Common chaos hound follow-through flavor lines are also suppressed when a matching maul summary is pending.
- If your current target disappears from room items (for example a party kill), boop now clears queued stale attack state in queueing mode and immediately retargets/ticks.
- Standard profiles can define `openerAt100`; it fires once per target id when target HP is explicitly known as 100% (currently used by Occultist: `attend &tar`).
- With `boop trace on`, opener decisions are logged with deduped reasons (for example selected, hp unknown, hp not full, already used).
- Foxhunt import reads Mudlet DB `hunting` lists directly; `merge` is default, `overwrite` clears boop lists first, `dryrun` reports counts only.
- `boop combos` infers synergy from class rage profiles, including per-class affliction providers and conditional readiness.
- `boop combos` with no args automatically uses `boop party` roster plus your current class.
- `boop party` also highlights which party conditionals your class can help enable from your rage afflictions.
- `boop ragemode combo` fires your conditional rage attack when needs are up and otherwise holds required rage, only spending overflow on damage.
- Conditional needs default to `any` (one affliction present) unless a profile explicitly sets `needsMode = "all"`.
- Battlerage afflictions are auto-tracked from class/general combat lines (gain + wear-off), and updates are scoped to your current target context for conditional rage checks.
- Shield state is now cleared from a broad set of class/general break and "no shield" combat lines, reducing repeated/wasted shieldbreak attempts when the shield is already down.

## Maintenance
- `tools/sort_manifests.sh` sorts display-order manifests for aliases, triggers, and attack scripts.
- `src/scripts/boop/scripts.json` is intentionally not auto-sorted because script load order is runtime-sensitive.

## Starting A Session
- See `CODEX.md` (Session Startup).

## Build
- Use Muddler from repo root (see `CODEX.md` for exact guidance).
