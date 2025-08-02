# let
#   nixpkgs = fetchTarball "https://github.com/NixOS/nixpkgs/tarball/nixos-unstable";
#   pkgs = import nixpkgs { config = {}; overlays = []; };
# in
{ pkgs ? import <nixpkgs> {} }:
  pkgs.mkShell
# pkgs.mkShellNoCC
{
  nativeBuildInputs = with pkgs; [
  ];
  packages = with pkgs; [
    jekyll
    bundler
  ];
   shellHook = /*bash*/ ''

   '';
}
