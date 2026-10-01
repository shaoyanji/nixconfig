# Thin wrapper around nixpkgs.lib.nixosSystem.
#
# Centralised so defaults can be added for all NixOS hosts in one place.
# nixos-configurations.nix passes { inputs, self } here; hosts that do not
# set their own specialArgs in flake/host-inventory.nix get the default.
#
# Used by flake/nixos-configurations.nix via mkNixosHost.
{ nixpkgs
, inputs
, self
, ...
}: { system
   , modules
   , specialArgs ? { inherit inputs self; }
   , ...
   }:
nixpkgs.lib.nixosSystem {
  inherit system modules specialArgs;
}
