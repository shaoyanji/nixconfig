# Fleet Modular Control Knob Registry

> **Generated — do not edit.** Built from `modules.toml` by `lib/docs.nix`
> (`nix build .#docs`). Refresh the checked-in copy with `task docs:sync`.

Declarative control knobs for optional profiles, services, and system roles across the fleet.

Knobs are declared in `modules.toml` and consumed by `modules.toml`-driven
tooling; this page is generated so it cannot lag the registry.

## Profile knobs

| knob | option | module | default | hosts |
| --- | --- | --- | --- | --- |
| AI Agent Tooling | profiles.ai.enable | `modules/user/ai/default.nix` | off | eisen, poseidon, fern, stark, scratch, guckloch |
| Base Desktop Environment | profiles.desktop.enable | `modules/profiles/base-desktop-environment.nix` | off | frieren, poseidon, eisen, fern, scratch |
| Base Node Baseline | profiles.base-node.enable | `modules/profiles/base-node.nix` | on | frieren, poseidon, eisen, fern, stark, kellerbench, deckstation, ares, delphi, applevalley, scratch, minyx |
| Hermes Agent Gateway | profiles.hermes.enable | `modules/profiles/hermes.nix` | off | frieren |
| Impermanence Root Rollback | environment.persistence.enable | `modules/profiles/impermanence.nix` | off | ares, garnixMachine |
| Laptop Power Management | profiles.laptop.enable | `modules/profiles/laptop.nix` | off | frieren, poseidon, fern, applevalley |
| MicroVM Virtualization Host | microvm.host.enable | `modules/profiles/microvm-host.nix` | off | — |
| NAS Client Mounts | profiles.nas-client.enable | `modules/profiles/nas-client.nix` | off | eisen, poseidon, fern, kellerbench, deckstation, ares |
| nixbuild.net Remote Builder | profiles.nixbuild-client.enable | `modules/profiles/nixbuild-client.nix` | off | frieren |
| NVIDIA Proprietary Drivers | hardware.nvidia.modesetting.enable | `modules/profiles/nvidia.nix` | off | stark, kellerbench |
| Server Hardening | profiles.server-hardening.enable | `modules/profiles/server-hardening.nix` | off | frieren, delphi |
| SSHFS NAS Client Mounts | profiles.sshfs-nas-client.enable | `modules/profiles/sshfs-nas-client.nix` | off | — |
| Steam Gaming & Gamescope | programs.steam.enable | `modules/profiles/steam.nix` | off | eisen, kellerbench, deckstation, ares |
| SteamOS Big Picture Kiosk | steamos.kiosk.enable | `modules/profiles/steamos.nix` | off | ares |
| Sunshine GameStream | services.sunshine.enable | `modules/profiles/sunshine.nix` | off | eisen, kellerbench, deckstation |


## Service knobs

| knob | option | module | default | hosts |
| --- | --- | --- | --- | --- |
| Aria2 RPC Download Daemon | services.aria2-daemon.enable | `modules/services/aria2-daemon.nix` | off | frieren |
| Harmonia LAN Binary Cache | services.harmonia.enable | `modules/services/harmonia.nix` | off | frieren |
| Home Assistant & Mosquitto | services.home-assistant.enable | `modules/services/home-assistant.nix` | off | frieren |
| iVentoy Network PXE | services.iventoy.enable | `modules/services/iventoy.nix` | off | frieren |
| Kiwix Offline Wikipedia | services.kiwix-serve.enable | `modules/services/kiwix.nix` | off | frieren |
| Fleet Pastebin | services.paste.enable | `modules/services/paste.nix` | off | frieren |


## Role knobs

| knob | option | module | default | hosts |
| --- | --- | --- | --- | --- |
| Heim Full Workstation Role | roles.heim.enable | `modules/roles/heim.nix` | off | poseidon, fern |
| Minimal Server Role | roles.minimal.enable | `modules/roles/minimal.nix` | off | delphi, garnixMachine, minyx, kali, alarm |

