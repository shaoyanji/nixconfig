{ lib, hostInventory }:
let
  selectByKind = kind: lib.filterAttrs (_: host: host.kind == kind) hostInventory;
  project = kind: fn: lib.mapAttrs fn (selectByKind kind);
in
  { inherit selectByKind project; }
