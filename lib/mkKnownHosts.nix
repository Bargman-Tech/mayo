# lib/mkKnownHosts.nix
# Fleet known-host construction — moved verbatim from the parent flake
# (mayo-split Step 3, ruling (c): mkKnownHosts unified now).
#
# One implementation; each consumer fills in its own inputs:
#
#   machines  every hostname to consider
#   pubKeyOf  hostname -> public key or null
#             (parent: secrix config -> secrets/ file fallback;
#              child: identity/public_keys/host_keys/ files)
#   topo      deriveTopo of a registry hosts attrset (or any { name = entry; })
#   hostNamesOf  defaults to hostNamesFromTopo topo
#
# Machines whose key resolves to null are dropped — so each side's output is
# byte-identical to its pre-move behaviour: the parent sees the same machine set
# as before, and the child still only emits entries for the hosts that carry a
# key in identity/. Golden parity proves it.
{ lib }:
rec {
  # Helper: derive IP from coordinate (subnet + peer_id)
  coordToIp = coord:
    let
      parts = lib.splitString "/" coord.subnet;
      ip = builtins.head parts;
      octets = lib.splitString "." ip;
      prefix = lib.concatStringsSep "." (lib.init octets);
    in
    "${prefix}.${toString coord.peer_id}";

  # Backward-compatible topo attrset derived from a registry hosts attrset.
  # Verbatim from the parent flake: wireguard IP + lan interface map, with
  # WG / Tailscale / MAC-alias coordinates filtered out of the lan view.
  deriveTopo = hosts:
    lib.mapAttrs
      (_name: host:
        let
          coords = host.coordinate or [ ];
          wgCoords = builtins.filter (c: c.plane_name == "wg") coords;
          wgCoord = if wgCoords != [ ] then builtins.head wgCoords else null;
          # Filter to only include standard network interfaces (skip MAC-based aliases)
          otherCoords = builtins.filter
            (c:
              c.plane_name != "wg" && c.plane_name != "tailscale-platonic"
              && !lib.hasPrefix "mac:" c.interface
            )
            coords;
          lan = lib.listToAttrs (map
            (c: {
              name = coordToIp c;
              value = c.interface;
            })
            otherCoords);
        in
        (if wgCoord != null then { wireguard = coordToIp wgCoord; } else { })
        // (if lan != { } then { inherit lan; } else { })
      )
      hosts;

  # hostNames for a machine: name + domain + every IP route it has
  # (verbatim getHostNames from the parent flake).
  hostNamesFromTopo = topo: name:
    let
      entry = topo.${name} or null;
      names = [ name "${name}.johnbargman.net" ];
    in
    if entry != null then
      lib.unique
        (names
          ++ lib.optionals (entry ? wireguard) [ entry.wireguard ]
          ++ lib.optionals (entry ? lan) (builtins.attrNames entry.lan)
          ++ lib.optionals (entry ? uplink) (builtins.attrNames entry.uplink)
        )
    else
      names;

  # Build the known-hosts attrset: only machines with a resolvable key,
  # keyed by hostname -> { hostNames; publicKey; }.
  mkKnownHosts =
    { machines
    , pubKeyOf # hostname -> string | null
    , topo ? { }
    , hostNamesOf ? hostNamesFromTopo topo
    }:
    let
      entries = builtins.listToAttrs (map
        (name:
          let
            pubKey = pubKeyOf name;
          in
          lib.nameValuePair name (
            if pubKey != null then {
              hostNames = hostNamesOf name;
              publicKey = pubKey;
            } else null
          )
        )
        machines);
    in
    lib.filterAttrs (_name: value: value != null) entries;
}
