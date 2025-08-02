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
    (python310.withPackages (ps: with ps; [
      flask
      fuzzywuzzy
      markdown2
      python-dotenv
    ]))
  ];
   shellHook = /*bash*/ ''

   '';
}
