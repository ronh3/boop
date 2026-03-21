# boop

Standalone Mudlet package for Achaea auto hunting.

## Status
- Functional core: targeting, attacks, rage readiness, safety, DB-backed lists.
- Class profiles: broad Foxhunt-derived profile coverage is included for the shipped classes.
- IH integration: `ih` output is re-rendered with clickable whitelist/blacklist buttons for denizens.
- Skill gating uses GMCP `Char.Skills.*` info for standard/rage abilities.
- Targeting uses denizen IDs (`settarget <id>`), not names.

## Commands
- `boop` (home dashboard)
- `boop control` (live control dashboard)
- `bh` (toggle on/off)
- `boop on` / `boop off`
- `boop help` / `boop help <number|topic|home>` (examples: `boop help 2`, `boop help targeting`)
- `boop status` (status summary)
- `boop config` / `boop config <number|section|section number|back|home>` (menu-style config flow)
- `boop preset <solo|party|leader|leader-call>` (apply recommended baseline settings)
- `boop party` (party dashboard)
- `boop mode solo|assist|leader|leader-call` (`leader` auto-calls your targets; `leader-call` follows another leader)
- `boop assist <leader>` / `boop assist on|off|clear`
- `boop targetcall on|off`
- `boop affcalls on|off`
- `boop walk [status|start|stop|move]`
- `boop walk install` (installs the required `demonnicAutoWalker` Mudlet package)
- `boop roster` / `boop roster <class...>` / `boop roster clear` (save party class roster; your own class is auto-included)
- `boop combos` / `boop combos <class...>` / `boop combos list` (party combo inference from rage afflictions + conditional needs)
- `boop prefer` / `boop prefer <dam|shield> <option>` / `boop prefer clear <dam|shield>` (bias standard attack choice within a profile)
- `boop weapon` / `boop weapon <role> <item-id>` / `boop weapon clear <role>` (save class-scoped weapon designations such as `scythe` or `dagger`; prefer raw GMCP item ids)
- `boop theme <name|auto|list>` (`list` includes boop themes plus the built-in ADB city/class themes)
- `boop autogold` / `boop autogold on` / `boop autogold off`
- `boop pack` / `boop pack <container>` / `boop pack off` / `boop pack test` (auto-stash container for sovereigns)
- `boop import foxhunt [merge|overwrite|dryrun]` (imports Foxhunt DB whitelist/blacklist into boop)
- `boop prequeue` / `boop prequeue on` / `boop prequeue off`
- `boop lead` / `boop lead <seconds>` (prequeue lead timing)
- `boop get [key]` / `boop set <key> <value>`
- `boop trace` / `boop trace on|off|show [n]|clear`
- `boop gag` / `boop gag on|off|own|others|all|<scope> on|off`
- `boop targeting <manual|whitelist|blacklist|auto>`
- `boop ragemode <simple|big|small|aff|tempo|combo|hybrid|none>` (default: `simple`)
- `diag` (queue-clear + diagnose; temporarily pauses boop attacks until diagnose result + prompt)
- `matic` (queues `ldeck draw matic` on the attack queue; temporarily pauses boop attacks until the next prompt or timeout)
- `catarin` (queues `ldeck draw catarin` on the attack queue; temporarily pauses boop attacks until the next prompt or timeout)
- `boop whitelist` / `boop whitelist add <name>` / `boop whitelist remove <name>` (display is clickable: up/down/remove)
- `boop whitelist browse [tag]` (browse whitelist areas; optional tag filter)
- `boop whitelist tags <area>` / `boop whitelist tag list`
- `boop whitelist tag add <area> | <tag[,tag2,...]>`
- `boop whitelist tag remove <area> | <tag[,tag2,...]>`
- `boop blacklist` / `boop blacklist add <name>` / `boop blacklist remove <name>` (display is clickable: up/down/remove)
- `boop blacklist global` / `boop blacklist global add <name>` / `boop blacklist global remove <name>` (all-area blacklist manager)
- `boop aff` / `boop aff add <a/b>` / `boop aff remove <a/b>` / `boop aff clear`
- `boop debug` / `boop debug attacks` / `boop debug skills` / `boop debug skills dump`
- `boop trip start` / `boop trip stop`
- `boop stats [session|login|trip|lifetime|lasttrip|areas|mobs|targets|abilities|crits|rage|records|compare|reset]`
- `bflee`

## Notes
- Standard attacks and rage actions are independent and can fire together.
- `boop ragemode big` pools rage until a `Big Damage` rage attack is usable; it only uses `Small Damage` while big is on cooldown.
- Denizens come from `gmcp.Char.Items.List` with attrib `m` and exclude `x`/`d`.
- Denizen name matching for whitelist/blacklist is case-insensitive and normalizes straight/curly apostrophes.
- Whitelist areas can have multiple tags (for example `continent-a`, `newbie`, `high-end`) for browse/filter workflows.
- Whitelist tags are normalized to lowercase and `-` separators, so `Mid Level` becomes `mid-level`.
- `ih` shows items too; only denizens get whitelist/blacklist buttons.
- Denizens on the global blacklist do not show `ih` whitelist/blacklist action labels.
- `boop walk` integrates with `demonnicAutoWalker`; if it is missing, use `boop walk install`.
- Auto gold pickup grabs newly dropped room items whose names contain `gold sovereign`.
- In queueing mode, auto gold pickup is prepended to the next queued standard attack as `get sovereigns/<attack>`.
- If no standard attack follows quickly, boop falls back to the game-side balance queue for `get sovereigns` so off-balance kills still loot cleanly.
- Non-queueing mode uses the same balance-queue fallback path.
- If `boop pack <container>` is set, boop follows pickup with `put sovereigns in <container>`.
- Gold get/put has trigger-based success/failure tracking with limited retries and warning output when retries are exhausted.
- For `Two Handed` spec with `Focus` known in `Weaponmastery`, boop prepends `battlefury focus speed/` to standard damage attacks (never shieldbreakers).
- For `Unnamable` with `Maul` known in `Dominion`, boop prepends `maul &tar/` to standard attacks while ready, then waits for the cooldown-ready line before prepending again.
- `diag` clears queue, queues `diagnose`, and pauses attacks until `You are: ...` or `You are in perfect health.` and the following prompt (with timeout fallback via `diagTimeoutSeconds`).
- `matic` queues `ldeck draw matic` on the same queue boop uses for standard attacks and pauses attacks until the next prompt (with the same timeout fallback via `diagTimeoutSeconds`).
- `catarin` queues `ldeck draw catarin` on the same queue boop uses for standard attacks and pauses attacks until the next prompt (with the same timeout fallback via `diagTimeoutSeconds`).
- Prequeue is separately configurable from queueing (`boop prequeue`); when enabled, it queues standard attacks before recovery using `boop lead` seconds (default `1.00`).
- Warrior classes (Infernal/Paladin/Runewarden) use `gmcp.Char.Vitals` `Spec` to select standard attacks.
- In queueing mode, boop caches the last `BOOP_ATTACK` alias payload and skips redundant `setalias` sends when unchanged.
- `boop weapon` stores class-scoped wield targets that profiles can consume when they need a specific weapon role; prefer raw GMCP item ids because wield tracking matches exact ids most reliably.
- `boop theme list` exposes boop's built-in themes plus the built-in ADB city/class palette names, so themes like `ashtan`, `depthswalker`, and `targossas` work directly in boop.
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
- `boop ragemode combo` is conditional-first, can pool for a roster-enabled party aff primer (or self-primer when profile data supports it), then holds reserve rage and spends only overflow.
- `boop ragemode hybrid` uses the same conditional/priming logic, but falls back to normal damage when reserve logic would otherwise hold.
- `boop ragemode tempo` is aff-first, but can spend on damage when rolling rage gain predicts quick recovery (10s window).
- Tune tempo behavior with `boop set tempoRageWindowSeconds <seconds>` and `boop set tempoSqueezeEtaSeconds <seconds>`.
- `boop stats login` shows current-login totals across boop on/off toggles; unlike `lifetime`, it is not persisted between logins.
- `boop help` and `boop config` are streamlined into fewer top-level sections for faster navigation.
- `boop targeting` and `boop ragemode` now show current value + usage when called without arguments, and clear errors for invalid values.
- Targeting now supports `retargetOnPriority` (default `on`); set it `off` to keep your current target instead of swapping when higher-priority mobs enter.
- Command feedback now uses consistent tags for quick scanning: `[OK]`, `[INFO]`, `[WARN]`, `[ERR]`.
- Conditional needs default to `any` (one affliction present) unless a profile explicitly sets `needsMode = "all"`.
- Battlerage afflictions are auto-tracked from class/general combat lines (gain + wear-off), and updates are scoped to your current target context for conditional rage checks.
- Shield state is now cleared from a broad set of class/general break and "no shield" combat lines, reducing repeated/wasted shieldbreak attempts when the shield is already down.
- Rage affliction tracker now emits party callouts for target aff changes using target id format (for example `pt 12345: amnesia`, `pt 12345: amnesia down`) and local boop echo confirmations.

## Maintenance
- `tools/sort_manifests.sh` sorts display-order manifests for aliases, triggers, and attack scripts.
- `src/scripts/boop/scripts.json` is intentionally not auto-sorted because script load order is runtime-sensitive.

## Starting A Session
- See `CODEX.md` (Session Startup).

## Build
- Use Muddler from repo root (see `CODEX.md` for exact guidance).
