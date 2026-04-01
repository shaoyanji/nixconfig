# Raspberry Pi/embedded development shell with extensive tooling
{pkgs ? import <nixpkgs> {}}:
let
  common = pkgs.callPackage ./common-packages.nix {};
  hooks = pkgs.callPackage ./shell-hooks.nix {};
in
pkgs.mkShell {
  packages = with pkgs; [
    common.greeting
    common.terminal-extras
  ];

  GREETING = "Hello, Nix!";
  shellHook = ''
    ${hooks.greeting}
  '';
}
