# Flask Python development shell
{pkgs ? import <nixpkgs> {}}:
let
  builder = pkgs.callPackage ./builder.nix {};
  common = pkgs.callPackage ./common-packages.nix {};
in
builder.mkPackageShell {
  name = "flaskpy";
  package = common.python-flask;
  greeting = "Hello, Flask!";
}
