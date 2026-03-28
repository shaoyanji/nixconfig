{
  lib,
  inputs,
  hostInventory,
  nixpkgs,
}:
lib.mapAttrs (_: host:
  inputs.home-manager.lib.homeManagerConfiguration {
    extraSpecialArgs = host.extraSpecialArgs or {};
    pkgs = nixpkgs.legacyPackages.${host.system};
    inherit (host) modules;
  })
(lib.filterAttrs (_: host: host.kind == "home") hostInventory)
