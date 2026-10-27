# Replit-style development shell
{pkgs}: let
  builder = pkgs.callPackage ./builder.nix {};
  common = pkgs.callPackage ./common-packages.nix {};
in
  builder.mkMinimalShell [common.replit common.editors]
