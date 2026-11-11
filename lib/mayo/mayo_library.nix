# lib/mayo/mayo_library.nix
# Mayo — system configuration helpers and other library assets. (C1 clean API)
#
# LAYER: Mayo = system configuration helpers + other library assets
# (demarkation ruling 2026-11-11). This layer NEVER imports Ketchup —
# split-readiness: extracting Mayo into its own repository later must be a
# directory move plus import-root updates. Golden tooling therefore takes its
# topology/registry data injected rather than building it.
#
# This file is a catalogue of the layer's members: entries are file paths (or
# paths to shell scripts), imported by consumers with their own arguments:
#
#   mayo = import "${mayo.lib}/mayo/mayo_library.nix";
#   # modules list:
#     mayo.rcloneTarget
#   # golden tooling:
#     serializer = import mayo.golden.serializeConfig { inherit lib; };
#     coverage   = import mayo.golden.coverage { goldenDir = ./goldens; topologyMachines = …; machineNames = …; };
#     apps       = import mayo.golden.apps { inherit lib pkgs; };
#     scripts/compare-configs.sh ← mayo.golden.compareConfigs (copied or executed by path)
{
  # ── reusable NixOS modules (system configuration helpers) ──
  rcloneTarget = ./rclone-target.nix;

  # ── golden tooling (library surface — ruling 2026-11-11) ──
  golden = {
    # Config serializer (the one true serializer; used by dump-config and
    # checks.network-config-*): { lib }: { serializeConfig = config → attrset; }
    serializeConfig = ./golden/serialize-config.nix;

    # Coverage audit: { goldenDir, topologyMachines, machineNames }:
    #   { isComplete; missing; coveragePercent; coveredCount; totalMachines; }
    coverage = ./golden/coverage.nix;

    # App builders: { lib, pkgs }: { mkDumpConfigApp; mkValidateGoldensApp; }
    apps = ./golden/apps.nix;

    # Revision comparison script. Embeds its own serializer copy by design —
    # it must work from any revision, including ones without this library.
    compareConfigs = ./golden/compare-configs.sh;
  };
}
