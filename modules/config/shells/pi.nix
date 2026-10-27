# Raspberry Pi/embedded development shell with extensive tooling
{pkgs}: let
  builder = pkgs.callPackage ./builder.nix {};
  common = pkgs.callPackage ./common-packages.nix {};
in
  builder.mkMinimalShell [common.terminal-extras]
