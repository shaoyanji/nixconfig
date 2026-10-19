# Determinate Nix on eisen — trial only, 2026-10-19.
#
# Why this file exists on exactly one host: DN ships a NixOS module that swaps
# the system Nix for its own CLI + `determinate-nixd`, which then runs
# `nix-daemon.service` and owns `/etc/nix/nix.conf` (our `nix.settings` land in
# `nix.custom.conf` instead). That is fine to measure on a workstation and wrong
# to roll out to 25 hosts whose rollback unit is the flake pin, so nothing else
# imports it.
#
# What it changes at runtime (verified in the module source):
#   - `nix.package` -> `inputs.nix.packages.<system>.default` at mkOverride 750;
#     `modules/global/global.nix` now sets the fleet default as mkDefault so this
#     wins. Without that, DN's config would apply but the upstream binary would
#     stay — the half-migrated state this file exists to avoid.
#   - `nix-daemon.service` ExecStart -> `determinate-nixd daemon`, plus a socket
#     at /nix/var/determinate/determinate-nixd.socket.
#   - `/etc/nix/nix.conf` becomes a target for `nix/nix.custom.conf`.
#
# Rollback: `nixos-rebuild --rollback switch` (or boot the previous generation).
# The store format does not change, so no migration is needed either way.
#
# The registry override below is deliberate: the module repoints `nixpkgs` at
# FlakeHub weekly nixpkgs (mkOverride 750), which would silently change what
# `<nixpkgs>` means on this host. Keep it on the flake's own pin instead.
{
  inputs,
  lib,
  ...
}: {
  imports = [inputs.determinate.nixosModules.default];

  determinate.enable = true;

  nix.registry.nixpkgs.to = lib.mkForce {
    type = "github";
    owner = "NixOS";
    repo = "nixpkgs";
    rev = inputs.nixpkgs.rev;
  };
}
