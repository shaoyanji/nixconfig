{
  lib,
  inputs,
  hostInventory,
}:
lib.mapAttrs (_: host:
  inputs.nix-darwin.lib.darwinSystem {
    inherit (host) system modules;
    specialArgs = host.specialArgs or {};
  })
(lib.filterAttrs (_: host: host.kind == "darwin") hostInventory)
