# Determinate Nix across the NixOS fleet — fleet-wide since 2026-10-19.
#
# ONE module, imported by every NixOS chain (`globalModulesNixos`,
# `globalModulesContainers`, `globalModulesDemo`), so the fleet runs one Nix
# binary. Two Nix versions in a fleet that pushes its own store paths makes
# every cache warm and every `nix copy` a guess about who can read what.
#
# Proven on eisen first (generation 26.11.20261016.f20cd90, 2026-10-19): the
# trial switched, the daemon came up as `determinate-nixd`, and the Qwen
# endpoint answered 200. This file is that module promoted, with the trial-only
# commentary replaced by what the fleet now depends on.
#
# What DN changes at runtime (read from modules/nixos.nix in the pinned input):
#   - `nix.package` -> determinate's own `nix` at the normal priority (100);
#     `modules/global/global.nix` sets the fleet default with `lib.mkDefault`,
#     because a *plain* fleet definition is a definition CONFLICT, not a pick.
#   - `nix-daemon.service` ExecStart -> `determinate-nixd … daemon`, plus a
#     socket at /nix/var/determinate/determinate-nixd.socket.
#   - `/etc/nix/nix.conf` becomes a target for `nix/nix.custom.conf`; every
#     `nix.settings` entry (fleet substituters, trusted keys, experimental
#     features) still lands, just in the included file.
#   - the `nix` CLI is added to `environment.systemPackages`.
#
# Rollback is the generation, not a migration — the store format is unchanged:
#   nixos-rebuild --rollback switch    (or boot the previous generation)
#
# Not imported by: the microVMs (`testvm`, `frieren-canary`) and
# `garnixMachine`, which build their own module lists and are not fleet hosts.
{
  inputs,
  lib,
  ...
}: {
  imports = [inputs.determinate.nixosModules.default];

  determinate.enable = true;

  # DN repoints the `nixpkgs` registry entry at FlakeHub weekly nixpkgs
  # (`mkOverride 750`, `exact = true`), which would silently change what
  # `<nixpkgs>` means on every host. Keep it on this flake's own pin: the pin is
  # the rollback unit, so it must not be able to drift under a rebuild.
  nix.registry.nixpkgs.to = lib.mkForce {
    type = "github";
    owner = "NixOS";
    repo = "nixpkgs";
    rev = inputs.nixpkgs.rev;
  };

  # DN's binaries are NOT on cache.nixos.org: without its own substituter the
  # first switch compiles 54 derivations (boost 1.89, wasmtime 48, libgit2,
  # boehm-gc, Python envs) because DN's packages come from its own nixpkgs fork.
  # With it the same closure is a 0-build fetch (measured on eisen: 54 builds +
  # 848 MiB -> 0 builds). The key is the public FlakeHub Cache key that signs
  # install.determinate.systems, and it is mirrored into the flake's nixConfig so
  # CI and the builder can substitute DN too.
  #
  # Bootstrap order: this setting only takes effect AFTER activation, so a
  # switch that *adds* DN must pass it on the command line (or pre-fetch with
  # `nix copy --from https://install.determinate.systems`) — see
  # `.agents/deploy/README.md`.
  nix.settings = {
    substituters = ["https://install.determinate.systems"];
    trusted-public-keys = ["cache.flakehub.com-3:hJuILl5sVK4iKm86JzgdXW12Y2Hwd5G07qKtHTOcDCM="];
    # Pre-trusted like the rest of the fleet caches, so a flake-level
    # extra-substituter never triggers the interactive y/N prompt.
    trusted-substituters = ["https://install.determinate.systems"];
  };
}
