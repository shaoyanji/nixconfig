# Yarn/Node.js development shell
{pkgs ? import <nixpkgs> {}}:
let
  builder = pkgs.callPackage ./builder.nix {};
  common = pkgs.callPackage ./common-packages.nix {};
  hooks = pkgs.callPackage ./shell-hooks.nix {};
in
builder.mkDevShell {
  name = "yarn";
  packages = with pkgs; [common.greeting common.yarn];
  greeting = "Hello, Nix!";
  extraHooks = [hooks.basic hooks.greeting];
}
