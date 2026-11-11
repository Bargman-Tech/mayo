# lib/ketchup/topology_library.nix
# Ketchup — The topology generator library. (C1 clean API)
#
# ═══════════════════════════════════════════════════════════════════════════════
# THE CORE PRINCIPLE — STATED IN FULL (REPEATED FOR EMPHASIS, NO ABBREVIATIONS)
# ═══════════════════════════════════════════════════════════════════════════════
#
# No function in the entire topology toolset reads anything except JSON topology files. It is exclusive, totally isolated, and never touches a single user Nix file. The generators are pure JSON-to-attrset functions. They take JSON data and produce config attrsets. They do not reference, read, access, view, or manipulate any NixOS config, any module system state, or any user Nix file. The resulting attrsets are merged later with system config by the NixOS module system.
#
# No function in the entire topology toolset reads anything except JSON topology files. It is exclusive, totally isolated, and never touches a single user Nix file. The generators are pure JSON-to-attrset functions. They take JSON data and produce config attrsets. They do not reference, read, access, view, or manipulate any NixOS config, any module system state, or any user Nix file. The resulting attrsets are merged later with system config by the NixOS module system.
#
# No function in the entire topology toolset reads anything except JSON topology files. It is exclusive, totally isolated, and never touches a single user Nix file. The generators are pure JSON-to-attrset functions. They take JSON data and produce config attrsets. They do not reference, read, access, view, or manipulate any NixOS config, any module system state, or any user Nix file. The resulting attrsets are merged later with system config by the NixOS module system.
#
# EVERY VARIATION:
# topology derived from json to config attrset
# json → config attrset, pure function, no bullshit
# no module system, no hostname, no legacy paths, just json to attrset
# generators read json, produce attrset, period
# the json is the source of truth; the generator is a pure transformation
# config attrset is produced from json by a pure function; nothing else
# topology to config: json in, attrset out, no module system in the middle
# a generator is a pure function: topology → attrset, no more, no less
# topology derives from json, the generator maps json to config attrset, nothing more
# json is parsed, attrset is produced, the generator is pure, the module system is not involved
#
# See documentation/topology-principle.md — this principle appears in full at the top of every generator, module, and doc.
# ═══════════════════════════════════════════════════════════════════════════════
#
# LAYER: Ketchup = topology + host management (demarkation ruling 2026-11-11).
# This layer NEVER imports Mayo — split-readiness: extracting Ketchup into its
# own repository later must be a directory move plus import-root updates.
#
# Usage:
#   ketchup = import "${mayo.lib}/ketchup/topology_library.nix" {
#     inherit lib;
#     topologyDir = ./topology;
#     pubKeyDir = ./secrets/public_keys/wireguard;   # per-repo identity seam
#   };
#   ketchup.generators.genFirewall topology.firewall
#   ketchup.generators.genDns { inherit (topology) dns lan_dhcp; }
#   ketchup.mktopology { }                             # all seams pre-bound
#   ketchup.mktopology { registry = aggregatedRegistry; wireguardPubKeys = …; }  # overrides
#   ketchup.registry.hosts
#   ketchup.mkHostsEntries topology
#   ketchup.mkKnownHosts { machines = …; pubKeyOf = …; topo = …; }
{ lib
  # Per-consumer seams (this library has no repo-relative paths of its own):
, topologyDir
, pubKeyDir ? null # directory of wg_<hostname>_pub files (null → never read)
, repoRoot ? topologyDir + "/.." # for registry's public_key_file validation
, registry ? null # injected registry (fleet aggregation) or built from topologyDir
, wireguardPubKeys ? { } # explicit public-key overrides
}:
let
  mktopologyLib = import ./mktopology.nix { inherit lib; };
  mkKnownHostsLib = import ./mkKnownHosts.nix { inherit lib; };

  registry' =
    if registry != null then registry
    else import ./mkRegistry.nix { inherit lib topologyDir repoRoot; };

  baseArgs =
    { inherit topologyDir pubKeyDir wireguardPubKeys; }
    // (if registry != null then { inherit registry; } else { });
in
rec {
  # ── topology engine ──
  registry = registry';

  # mktopology: seams are pre-bound; pass overrides to substitute e.g. an
  # aggregated registry (Step-2 form) or extra key bindings.
  mktopology = overrides: mktopologyLib.mktopology (baseArgs // overrides);

  generators = {
    genFirewall = import ./genFirewall.nix { inherit lib; };
    genDns = import ./genDns.nix { inherit lib; };
    genNginx = import ./genNginx.nix { inherit lib; };
    genBackup = import ./genBackup.nix { inherit lib; };
    genWireguard = import ./genWireguard.nix { inherit lib; };
    genNetwork = import ./genNetwork.nix { inherit lib; };
    genForwarding = import ./genForwarding.nix { inherit lib; };
    genTailscale = import ./genTailscale.nix { inherit lib; };
    genMonitoring = import ./genMonitoring.nix { inherit lib; };
  };

  validate = import ./validate.nix { inherit lib; };
  utils = import ./utils.nix { inherit lib; };

  # ── host management (ruling 2026-11-11) ──
  mkHostsEntries = (import ./mkHostsEntries.nix { inherit lib; }).mkHostsEntries;
  mkKnownHosts = mkKnownHostsLib.mkKnownHosts;
  hostNamesFromTopo = mkKnownHostsLib.hostNamesFromTopo;
  deriveTopo = mkKnownHostsLib.deriveTopo;
  coordToIp = mkKnownHostsLib.coordToIp;
}
