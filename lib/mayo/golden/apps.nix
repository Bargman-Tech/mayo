# lib/mayo/golden/apps.nix
# Golden app builders (Mayo layer — golden tooling ruling 2026-11-11).
#
# Generic: the apps run from the consuming repository's root and work against
# `./.` and the goldens directory passed in. The serializer is resolved from
# this library (./serialize-config.nix), not from the consumer's tree.
#
# Usage:
#   apps = import mayo.golden.apps { inherit lib pkgs; };
#   # flake apps:
#     dump-config = { type = "app"; program = lib.getExe (apps.mkDumpConfigApp { }); };
#     validate-goldens = { type = "app"; program = lib.getExe (apps.mkValidateGoldensApp { goldenDir = "${self}/goldens"; }); };
{ lib, pkgs }:

{
  # Full config serialization for comparing between revisions
  mkDumpConfigApp = { name ? "dump-config" }: pkgs.writeShellApplication {
    inherit name;
    runtimeInputs = [ pkgs.jq ];
    text = ''
      if [ -z "$1" ]; then
        echo "Usage: nix run .#${name} <machine-name>"
        echo "Example: nix run .#${name} cortex-alpha > /tmp/config.json"
        echo ""
        echo "To compare between revisions:"
        echo "  git checkout old-rev && nix run .#${name} cortex-alpha > /tmp/old.json"
        echo "  git checkout new-rev && nix run .#${name} cortex-alpha > /tmp/new.json"
        echo "  diff /tmp/old.json /tmp/new.json"
        exit 1
      fi
      MACHINE="$1"
      nix eval --json --impure \
        --expr '
          let
            flake = builtins.getFlake (builtins.toString ./.);
            lib = (import <nixpkgs> {}).lib;
            serializer = import ${./serialize-config.nix} { inherit lib; };
            config = (flake.nixosConfigurations."'"$MACHINE"'" or flake.dormantConfigurations."'"$MACHINE"'").config;
          in
          serializer.serializeConfig config
        ' | jq -S .
    '';
  };

  # Validate machine config against golden files
  # NOTE: Golden tests validate that config hasn't changed from prior state.
  # This is regression testing — completely separate from topology generation.
  # Topology generates config; goldens validate config. Related but unrelated.
  mkValidateGoldensApp = { name ? "validate-goldens", goldenDir }: pkgs.writeShellApplication {
    inherit name;
    runtimeInputs = [ pkgs.jq ];
    text = ''
      MACHINE="''${1:-cortex-alpha}"
      echo "Validating $MACHINE against golden..."
      nix run .#dump-config -- "$MACHINE" | jq -S . > /tmp/current-config.json

      if diff -u "${goldenDir}/$MACHINE.json" /tmp/current-config.json; then
        echo "✓ $MACHINE matches golden"
      else
        echo "✗ $MACHINE differs from golden!"
        echo "If intentional, update with:"
        echo "  nix run .#dump-config -- $MACHINE > goldens/$MACHINE.json"
        exit 1
      fi
    '';
  };
}
