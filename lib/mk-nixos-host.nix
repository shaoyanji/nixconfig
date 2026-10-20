# Thin wrapper around nixpkgs.lib.nixosSystem.
#
# Centralised so defaults can be added for all NixOS hosts in one place.
# nixos-configurations.nix passes { inputs, self } here; hosts that do not
# set their own specialArgs in flake/host-inventory.nix get the default.
#
# Used by flake/nixos-configurations.nix via mkNixosHost.
{
  nixpkgs,
  inputs,
  self,
  ...
}: {
  system,
  modules,
  # The inventory key. `networking.hostName` was declared in 20 host files and
  # every one of them repeated its own directory name, so the registry already
  # knew the answer. mkDefault (1000) is weaker than a plain definition, so a
  # host that genuinely needs a different hostname still wins without a conflict.
  hostName ? null,
  specialArgs ? {inherit inputs self;},
  ...
}:
nixpkgs.lib.nixosSystem {
  inherit system specialArgs;
  modules =
    nixpkgs.lib.optional (hostName != null) (
      {lib, ...}: {
        networking.hostName = lib.mkDefault hostName;
      }
    )
    ++ modules;
}
