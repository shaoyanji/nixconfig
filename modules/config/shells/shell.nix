# General purpose shell with common utilities
{pkgs ? import <nixpkgs> {}}:
let
  common = pkgs.callPackage ./common-packages.nix {};
  hooks = pkgs.callPackage ./shell-hooks.nix {};
in
pkgs.mkShell {
  packages = with pkgs; [
    common.greeting
    common.core
    common.ai
    common.ui
    common.productivity
    common.editors
    pkgs.fastfetch
    pkgs.speedtest-cli
  ];

  GREETING = "Hello, Nix!";
  shellHook = ''
    ${hooks.full}
    ${hooks.greeting}
  '';
}
