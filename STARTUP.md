# STARTUP.md

Quick session checklist for `boop`.

## Start
1. Connect with GMCP enabled. `boop` bootstraps on load and is **off** by default.
2. Choose targeting mode (default is `whitelist`):
   - `boop targeting auto` to hit any denizen, or
   - stay on `whitelist` and add targets via `boop ih` / `ih`.
3. Run `boop ih` (or `ih`) in the area and click `[+whitelist]` or `[+blacklist]` as needed.
4. Start hunting with `boop on` (or toggle with `boop`).

## Troubleshooting
- `boop status` for quick status.
- `boop debug` when not attacking (check eq/bal, target count, class, and rage).

## Persistence
Session data (whitelist/blacklist/config) is stored in the Mudlet DB, so reconnects keep your settings.
