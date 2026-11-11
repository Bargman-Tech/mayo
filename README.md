# Mayo

The shared library for the Bargman-Tech fleet — the **mayo library**: the home
of the **Mayo** and **Ketchup** layers (and the `bargman-tech` flake schema
contract). Consumed by both the parent flake and the child machine flake as a
flake input; neither repository vendors this code.

**Visibility: public** (the original intention) · **AGPL-3.0-or-later**

## The two layers (demarkation ruling 2026-11-11)

| Layer | Domain | Layout |
|---|---|---|
| **Ketchup** | **Topology + host management**: pure JSON→attrset generators, validation, serialization, registry/hosts/known-hosts construction. No machine data, no secrets. | `lib/ketchup/` |
| **Mayo** | **System configuration helpers + other library assets**: reusable NixOS modules, generic helpers, golden tooling. | `lib/mayo/` |

Secret-Sauce (proprietary machine configs, real topology data, secrets) never
lives here — it stays in the parent and the owning machine repos.

**Split-readiness:** `lib/ketchup/` and `lib/mayo/` never import each other.
Consumers glue the layers together. The eventual separation of Ketchup and Mayo
into their own repositories is therefore a directory move plus import-root
updates.

## Contents

| Path | What |
|---|---|
| `lib/ketchup/topology_library.nix` | **Ketchup API** (C1 clean API) — `ketchup.generators.*` (nine), `mktopology`, `registry`, `mkHostsEntries`, `mkKnownHosts`, `validate` |
| `lib/ketchup/mktopology.nix`, `mkRegistry.nix` | topology engine (orchestrator + cross-machine registry) |
| `lib/ketchup/mkHostsEntries.nix`, `mkKnownHosts.nix` | host management (`/etc/hosts` entries, known-hosts construction, `coordToIp`/`deriveTopo`) |
| `lib/ketchup/gen*.nix` | nine pure generators: firewall, dns, nginx, backup, wireguard, network, forwarding, tailscale, monitoring |
| `lib/ketchup/validate.nix`, `utils.nix` | topology validation helpers |
| `lib/mayo/mayo_library.nix` | **Mayo API** (C1 clean API) — catalogue of the layer's members |
| `lib/mayo/rclone-target.nix` | rclone-target NixOS options module (what `genBackup` writes into) |
| `lib/mayo/golden/serialize-config.nix` | the one true config serializer (dump-config, golden checks) |
| `lib/mayo/golden/coverage.nix` | golden coverage audit (data-injected) |
| `lib/mayo/golden/apps.nix` | `mkDumpConfigApp` / `mkValidateGoldensApp` builders |
| `lib/mayo/golden/compare-configs.sh` | revision comparison script (embeds its own serializer copy by design — must work from any revision) |

## Consumption pattern

Mayo deliberately has **no flake inputs**: each consumer supplies its own `lib`
(so every repo keeps pinning its own nixpkgs) and the repo-relative seams
(`topologyDir`, `pubKeyDir`, `repoRoot`).

```nix
ketchup = import "${mayo.lib}/ketchup/topology_library.nix" {
  inherit lib;
  topologyDir = ./topology;
  pubKeyDir = ./secrets/public_keys/wireguard;
};
topologyConfigs = ketchup.mktopology { };            # seams pre-bound
hostsText = ketchup.mkHostsEntries topology;

mayoLib = import "${mayo.lib}/mayo/mayo_library.nix";
# modules list: mayoLib.rcloneTarget
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
