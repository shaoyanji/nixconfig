# Flask Python development shell
{pkgs ? import <nixpkgs> {}}:
let
  common = pkgs.callPackage ./common-packages.nix {};
  hooks = pkgs.callPackage ./shell-hooks.nix {};
in
pkgs.mkShell {
  packages = with pkgs; [
    common.greeting
    common.python-flask
  ];

  GREETING = "Hello, Nix!";
  shellHook = ''
    ${hooks.greeting}
  '';
}
