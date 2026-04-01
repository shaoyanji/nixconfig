# Replit-style development shell
{pkgs ? import <nixpkgs> {}}:
let
  common = pkgs.callPackage ./common-packages.nix {};
  hooks = pkgs.callPackage ./shell-hooks.nix {};
in
pkgs.mkShell {
  packages = with pkgs; [
    common.greeting
    common.replit
    common.editors
  ];

  GREETING = "Hello, Nix!";
  shellHook = ''
    ${hooks.greeting}
  '';
}
