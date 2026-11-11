# SPDX-License-Identifier: AGPL-3.0-or-later
{
  description = "Mayo — shared configuration surface (topology engine, known-hosts, rclone target) for the Bargman-Tech fleet. Mayo-split Step 3: consumed by github.com/DarthPJB/NixOS-Configuration (parent) and gitlab.com/mecha-team-zero/gaming-host-1 (child).";

  # Deliberately no inputs: mayo is a library of Nix functions, and every
  # consumer supplies its own `lib` so each repo keeps pinning its own nixpkgs
  # and the function bodies stay byte-identical to their pre-move versions:
  #
  #   registry = import "${mayo}/lib/topology/mkRegistry.nix" {
  #     inherit lib; topologyDir = ./topology;
  #   };
  #   mktopology = (import "${mayo}/lib/topology/mktopology.nix" { inherit lib; }).mktopology;
  #   knownHosts = (import "${mayo}/lib/mkKnownHosts.nix" { inherit lib; }).mkKnownHosts { ... };
  #
  # The `lib` output is a path convenience (mayo.lib == ${mayo}/lib).
  outputs = { self }: {
    lib = ./lib;
  };
}
