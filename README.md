# Mayo

The **Mayo** library — the shared configuration surface (topology engine,
known-hosts construction, rclone target) plus the `bargman-tech` flake schema
for the Bargman-Tech fleet.

**Visibility: public** (the original intention).

## Consumers

| Repo | Role |
|---|---|
| `github.com/DarthPJB/NixOS-Configuration` | parent flake — consumes `mayo` as an input, aggregates child schema exports |
| `gitlab.com/mecha-team-zero/gaming-host-1` | child machine flake — consumes `mayo` as an input, vendors no library files |

- **Working document:** `opencode/plans/mayo-split-PLAN.md` (in the parent repo)
- **Status:** Step 3 of the mayo split complete (**GATE C**, 2026-11-10) —
  populated and consumed by both flakes; neither repository vendors these files
  (LDR-001 D-10). Step 3b (a wrapped API over this engine) is pending.

## Contents

| Path | What |
|---|---|
| `lib/topology/mktopology.nix` | topology → NixOS config attrsets (flake-level orchestrator) |
| `lib/topology/mkRegistry.nix` | cross-machine topology registry + 10 validators |
| `lib/topology/gen*.nix` | nine pure generators: firewall, dns, nginx, backup, wireguard, network, forwarding, tailscale, monitoring |
| `lib/topology/mkHostsEntries.nix` | `/etc/hosts` generation |
| `lib/topology/validate.nix`, `lib/topology/utils.nix` | validation helpers |
| `lib/mkKnownHosts.nix` | unified known-hosts construction (`machines` / `pubKeyOf` / `topo`) |
| `lib/rclone-target.nix` | the NixOS options module `genBackup` writes into |

## Consumption pattern

Mayo deliberately has **no flake inputs**: each consumer supplies its own `lib`
(so every repo keeps pinning its own nixpkgs) and the repo-relative seams
(`topologyDir`, `repoRoot`, `pubKeyDir`), which keeps the function bodies
byte-identical across repositories.

```nix
registry = import "${mayo.lib}/topology/mkRegistry.nix" {
  inherit lib;
  topologyDir = ./topology;
};
mktopology = (import "${mayo.lib}/topology/mktopology.nix" { inherit lib; }).mktopology;
knownHosts = (import "${mayo.lib}/mkKnownHosts.nix" { inherit lib; }).mkKnownHosts {
  machines = ...; pubKeyOf = ...; topo = ...;
};
```

## License

SPDX-License-Identifier: **AGPL-3.0-or-later**

Copyright (c) 2026 Bargman-Tech. All files in this repository are licensed
under the GNU Affero General Public License, version 3 or (at your option) any
later version — see [`LICENSE`](./LICENSE) for the full text.

Repositories that import this library unmodified keep their own licensing;
any **modified** version of this code must be distributed under
AGPL-3.0-or-later, and offering it as a network service triggers the AGPL's
source-availability requirement.
