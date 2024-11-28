# let
#   nixpkgs = fetchTarball "https://github.com/NixOS/nixpkgs/tarball/nixos-unstable";
#   pkgs = import nixpkgs { config = {}; overlays = []; };
# in
{ pkgs ? import <nixpkgs> {} }:
#  pkgs.mkShell
 pkgs.mkShellNoCC 
{
  packages = with pkgs; [
    cowsay
    lolcat
# aitools
    #aichat
#   tgpt
    #mods
# ui
#   gum
#   just
#   pop
# utilities
    #zoxide
    #fzf
    bat
    ripgrep
    eza
    lf
   # starship
    direnv
#   go-task
#   yq-go
#   nushell
    git
#   charm-freeze
    # pandoc
# secrets management
    #age
    #sops
#   bitwarden-cli
# editor
#    neovim
# extras
#   hugo
# programming languages
    tinygo
    go
    #python3
    #nim 
    #luajit
  ];
  GREETING = "Hello, Nix!";
   shellHook = ''
   0file() { curl -F"file=@$1" https://envs.sh ; }
   0pb() { curl -F"file=@-;" https://envs.sh ; }
   0url() { curl -F"url=$1" https://envs.sh ; }
   0short() { curl -F"shorten=$1" https://envs.sh ; }
#   BW_SESSION="oB8LrP9CMoqGmlPPe89YhS8fghHQh+G/qmx1if2Qnr+aS+GuJRhTkFz+UFMc86ccPZ2L9nFJjP5FWF86XkeAGg=="
   alias l='eza -lahF --color=auto --icons --sort=size --group-directories-first'
   alias lss='eza -hF --color=auto --icons --sort=size --group-directories-first'
   alias la='eza -ahF --color=auto --icons --sort=size --group-directories-first'
   alias ls='eza -lhF --color=auto --icons --sort=Name --group-directories-first'
   alias lst='eza -lahFT --color=auto --icons --sort=size --group-directories-first'
   alias lt='eza -aT --icons --group-directories-first --color=auto --sort=size'
   alias cat='bat'
   alias grep='rg'
 
#   EDITOR=nvim
   echo $GREETING | cowsay | lolcat
   eval "$(direnv hook bash)"
   eval "$(starship init bash)"
   eval "$(atuin init bash)"
   alias load-taskfile='sops -d ./modules/global/secrets/Taskfile.yaml>./Taskfile.yml'
   export PATH="$HOME/aarch64bin:$PATH:$HOME/.local/bin:$HOME/go/bin"

  '';
}
