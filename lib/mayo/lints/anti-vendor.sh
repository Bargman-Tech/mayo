#!/usr/bin/env bash
# Mayo structure lint: anti-vendoring (LDR-001 D-10).
#
# Library files owned by mayo must never reappear inside a consumer repo's
# lib/ tree. Re-vendoring is the failure mode this whole architecture
# eliminated; the lint keeps it eliminated.
#
# usage: anti-vendor.sh <repo-root>
#   <repo-root>  the consuming repository
set -euo pipefail

root="${1:?usage: anti-vendor.sh <repo-root>}"
lib_dir="$root/lib"

if [ ! -d "$lib_dir" ]; then
  echo "anti-vendor: no lib/ directory — nothing vendored"
  exit 0
fi

forbidden=(
  # legacy parent-level names
  serialize-config.nix golden_coverage.nix topology_library.nix rclone-target.nix
  # ketchup layer
  mktopology.nix mkRegistry.nix mkHostsEntries.nix mkKnownHosts.nix
  validate.nix utils.nix
  genFirewall.nix genDns.nix genNginx.nix genBackup.nix genWireguard.nix
  genNetwork.nix genForwarding.nix genTailscale.nix genMonitoring.nix
  # mayo layer golden tooling
  coverage.nix apps.nix
)

violations=0
while IFS= read -r -d '' f; do
  base="$(basename "$f")"
  for name in "${forbidden[@]}"; do
    if [ "$base" = "$name" ]; then
      echo "anti-vendor: vendored mayo-owned file: $f" >&2
      violations=1
    fi
  done
done < <(find "$lib_dir" -type f \( -name '*.nix' -o -name '*.sh' \) -not -path '*/.git/*' -print0)

if [ "$violations" -ne 0 ]; then
  exit 1
fi
echo "anti-vendor: no mayo-owned files vendored under lib/"
