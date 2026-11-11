#!/usr/bin/env bash
# Mayo structure lint: layer boundary.
#
# The Ketchup and Mayo layers must never reference each other. Split-readiness
# (demarkation ruling 2026-11-11): separating the layers into their own
# repositories must remain a directory move plus import-root updates.
#
# usage: layer-boundary.sh <mayo-lib-root>
#   <mayo-lib-root>  the mayo lib/ directory (contains ketchup/ and mayo/)
set -euo pipefail

root="${1:?usage: layer-boundary.sh <mayo-lib-root>}"
k_dir="$root/ketchup"
m_dir="$root/mayo"

[ -d "$k_dir" ] || { echo "layer-boundary: missing $k_dir" >&2; exit 1; }
[ -d "$m_dir" ] || { echo "layer-boundary: missing $m_dir" >&2; exit 1; }

violations=0

scan() {
  local dir="$1" label="$2" regex="$3" f hits
  while IFS= read -r -d '' f; do
    hits="$(sed 's/#.*$//' "$f" | grep -nE "$regex" || true)"
    if [ -n "$hits" ]; then
      printf 'layer-boundary: %s references the %s layer:\n%s\n' "$f" "$label" "$hits" >&2
      violations=1
    fi
  # lints/ is excluded: boundary tooling necessarily names both layers.
  done < <(find "$dir" -type f \( -name '*.nix' -o -name '*.sh' \) -not -path '*/lints/*' -print0)
}

scan "$k_dir" "mayo" '(\.\./|\./)?mayo/'
scan "$m_dir" "ketchup" '(\.\./|\./)?ketchup/'

if [ "$violations" -ne 0 ]; then
  exit 1
fi
echo "layer-boundary: ketchup/ and mayo/ are import-clean"
