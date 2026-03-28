{
  lib,
  mkNixosHost,
  hostInventory,
}:
lib.mapAttrs (_: host: mkNixosHost {
  inherit (host) system modules;
  specialArgs = host.specialArgs or {};
})
(lib.filterAttrs (_: host: host.kind == "nixos") hostInventory)
