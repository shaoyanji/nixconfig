# YouTube/media download and management shell
{pkgs ? import <nixpkgs> {}}:
let
  builder = pkgs.callPackage ./builder.nix {};
  common = pkgs.callPackage ./common-packages.nix {};
  hooks = pkgs.callPackage ./shell-hooks.nix {};
in
builder.mkDevShell {
  name = "yt";
  packages = with pkgs; [
    common.greeting
    common.core
    common.ui
    common.productivity
    common.media
    pkgs.htop
  ];
  greeting = "Hello, Nix!";
  extraHooks = [hooks.full hooks.greeting];
}
