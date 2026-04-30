# Jekyll static site development shell
{pkgs ? import <nixpkgs> {}}:
let
  builder = pkgs.callPackage ./builder.nix {};
  common = pkgs.callPackage ./common-packages.nix {};
in
builder.mkPackageShell {
  name = "jekyll";
  package = common.jekyll;
  greeting = "Hello, Jekyll!";
}
