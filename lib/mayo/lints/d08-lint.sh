#!/usr/bin/env bash
# Mayo structure lint: D-08 staging doctrine (machine repos).
#
# A machine flake is the staging source of truth: secret declarations are
# bindings only (name, attachment, owner/mode) whose files are ABSENT. No
# ciphertext, no decryption, no repo-root escapes. Production actualisation
# happens parent-side via extendModules overrides.
#
# usage: d08-lint.sh <repo-root>
#   <repo-root>  the machine repository (e.g. gaming-host-1)
set -euo pipefail

root="${1:?usage: d08-lint.sh <repo-root>}"
violations=0

# 1. No ciphertext material anywhere in the repository.
while IFS= read -r -d '' f; do
  echo "d08-lint: ciphertext present: $f" >&2
  violations=1
done < <(find "$root" -type f -name '*.age' -not -path '*/.git/*' -print0)

# 2. No decryption invocations.
while IFS= read -r hit; do
  echo "d08-lint: decryption invocation: $hit" >&2
  violations=1
done < <(grep -rIn --exclude-dir=.git -e 'age -d' -e 'age --decrypt' "$root" || true)

# 3. The secrets/ tree must be fileless — bindings resolve to absent files.
if [ -d "$root/secrets" ]; then
  while IFS= read -r -d '' f; do
    echo "d08-lint: secrets file present in staging repo: $f" >&2
    violations=1
  done < <(find "$root/secrets" -type f -not -path '*/.git/*' -print0)
fi

# 4. No path escapes beyond the repository root.
while IFS= read -r hit; do
  echo "d08-lint: path escapes the repo root: $hit" >&2
  violations=1
done < <(grep -rIn --exclude-dir=.git --include='*.nix' '\.\./\.\./\.\.' "$root" || true)

if [ "$violations" -ne 0 ]; then
  exit 1
fi
echo "d08-lint: staging doctrine holds (no ciphertext, no decryption, no escapes)"
