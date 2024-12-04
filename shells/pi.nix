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
#   aichat
#   tgpt
#   mods
# ui
#   gum
#   just
#   pop
# utilities
#    fd
#    zoxide
#    fzf
#    bat
#    ripgrep
#    eza
#    lf
# starship
#    direnv
#   go-task
#   yq-go
#   nushell
#    git
#   charm-freeze
#   pandoc
# secrets management
    #age
    #sops
#    bitwarden-cli
# editor
#    neovim
# extras
#   hugo
#    yt-dlp
# programming languages
#    tinygo
#    go
#    gcc
#    python3
#    nim
#    luajit
#    rustc
#    cargo
    #tcc
  ];
  GREETING = "Hello, Nix!";
   shellHook = ''
  #BW_SESSION="oB8LrP9CMoqGmlPPe89YhS8fghHQh+G/qmx1if2Qnr+aS+GuJRhTkFz+UFMc86ccPZ2L9nFJjP5FWF86XkeAGg=="
  echo $GREETING | cowsay | lolcat
  alias load-taskfile='sops -d ./modules/global/secrets/Taskfile.yaml >./Taskfile.yml'
  nu
  '';
}
