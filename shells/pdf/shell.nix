# let
#   nixpkgs = fetchTarball "https://github.com/NixOS/nixpkgs/tarball/nixos-unstable";
#   pkgs = import nixpkgs { config = {}; overlays = []; };
# in
{ pkgs ? import <nixpkgs> {} }:
  pkgs.mkShell
# pkgs.mkShellNoCC 
{
  
  packages = with pkgs; [
    cowsay
    lolcat
 # aitools
    #ollama
    #aichat
    tgpt
    #mods
  # pdf workflow
     pandoc
     texlive.combined.scheme-small
     pdfcpu
     poppler_utils
     wkhtmltopdf
  ];
  GREETING = "Hello, Nix!";
   shellHook = ''
   echo $GREETING | cowsay | lolcat
   '';
}
