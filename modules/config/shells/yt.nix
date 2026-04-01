# YouTube/media download and management shell
{pkgs ? import <nixpkgs> {}}:
let
  common = pkgs.callPackage ./common-packages.nix {};
  hooks = pkgs.callPackage ./shell-hooks.nix {};
in
pkgs.mkShell {
  packages = with pkgs; [
    common.greeting
    common.core
    common.ui
    common.productivity
    common.media
    pkgs.htop
  ];

  GREETING = "Hello, Nix!";
  shellHook = ''
    ${hooks.full}
    ${hooks.greeting}
  '';
}
