# Thin wrapper around nixpkgs.lib.nixosSystem.
#
# Currently a passthrough, but centralised here so defaults (extra modules,
# specialArgs, etc.) can be added for all NixOS hosts in one place.
#
# Used by flake/nixos-configurations.nix via mkNixosHost.
{nixpkgs}: {
  system,
  modules,
  specialArgs ? {},
  ...
}:
  nixpkgs.lib.nixosSystem {
    inherit system modules specialArgs;
  }
