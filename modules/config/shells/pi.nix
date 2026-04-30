# Raspberry Pi/embedded development shell with extensive tooling
{pkgs ? import <nixpkgs> {}}:
let
  builder = pkgs.callPackage ./builder.nix {};
  common = pkgs.callPackage ./common-packages.nix {};
in
builder.mkMinimalShell [common.terminal-extras]
