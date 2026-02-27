#!/usr/bin/env sh
set -eu

ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"

sort_manifest() {
  file="$1"
  tmp="${file}.tmp"
  jq 'sort_by((.name // "")|ascii_downcase)' "$file" > "$tmp"
  mv "$tmp" "$file"
  echo "sorted: $file"
}

# Safe to sort for display order.
sort_manifest "$ROOT/src/aliases/boop/aliases.json"
sort_manifest "$ROOT/src/triggers/boop/triggers.json"
sort_manifest "$ROOT/src/scripts/boop/attacks/scripts.json"

# Intentionally not sorted:
#   src/scripts/boop/scripts.json
# It is load-order sensitive (boop_init/boop_bootstrap/attack registry dependencies).
echo "skipped: $ROOT/src/scripts/boop/scripts.json (load-order sensitive)"
