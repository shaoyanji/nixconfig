# General purpose shell with common utilities
{pkgs ? import <nixpkgs> {}}:
let
  builder = pkgs.callPackage ./builder.nix {};
  common = pkgs.callPackage ./common-packages.nix {};
  hooks = pkgs.callPackage ./shell-hooks.nix {};
in
builder.mkDevShell {
  name = "general";
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
  greeting = "Hello, Nix!";
  extraHooks = [hooks.full hooks.greeting];
}
