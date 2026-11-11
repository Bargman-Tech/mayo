#!/usr/bin/env bash
# Mayo structure lint: API freeze.
#
# Consumers must reach the library only through the two layer APIs
# (lib/ketchup/topology_library.nix and lib/mayo/mayo_library.nix). Raw
# references to any other library path bypass the freeze and break the
# split-readiness guarantee.
#
#   Bare `${mayo.lib}` (no path suffix) is a directory reference and allowed —
#   the freeze guards FILE access, which is what bypasses the API surface.
#
# usage: api-freeze.sh <repo-root>
#   <repo-root>  the consuming repository (scanned for *.nix)
set -euo pipefail

root="${1:?usage: api-freeze.sh <repo-root>}"

allowed=$'\n/ketchup/topology_library.nix\n/mayo/mayo_library.nix'
violations=0

while IFS= read -r -d '' f; do
  hits="$(sed 's/#.*$//' "$f" | grep -nE 'mayo\.lib\}' || true)"
  [ -z "$hits" ] && continue
  while IFS= read -r hit; do
    line_no="${hit%%:*}"
    while IFS= read -r ref; do
      [ -z "$ref" ] && continue
      path="${ref#mayo.lib\}}"
      if ! printf '%s\n' "$allowed" | grep -qx "$path"; then
        printf 'api-freeze: %s:%s bypasses the layer APIs: mayo.lib}%s\n' \
          "$f" "$line_no" "$path" >&2
        violations=1
      fi
    done < <(printf '%s\n' "$hit" | grep -oE 'mayo\.lib\}[^"'"'"'[:space:];,]*' || true)
  done <<<"$hits"
done < <(find "$root" -type f -name '*.nix' -not -path '*/.git/*' -print0)

if [ "$violations" -ne 0 ]; then
  exit 1
fi
echo "api-freeze: all mayo references go through the layer APIs"
