# Yarn/Node.js development shell
{pkgs ? import <nixpkgs> {}}:
let
  common = pkgs.callPackage ./common-packages.nix {};
  hooks = pkgs.callPackage ./shell-hooks.nix {};
in
pkgs.mkShell {
  packages = with pkgs; [
    common.greeting
    common.yarn
  ];

  GREETING = "Hello, Nix!";
  shellHook = ''
    ${hooks.basic}
    ${hooks.greeting}
  '';
}
