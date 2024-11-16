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
    #aichat
    tgpt
    #mods
# ui
    gum
    pop
    charm-freeze
# utilities
    zoxide
    fzf
    bat
    ripgrep
    eza
    lf
    starship
    direnv
    go-task
    yq-go
    nushell
# external
    git
# workflow/languages
    # python
    # rust
    # go
    # luajit
    # pandoc
# misc
    # texlive-scheme-small
    # ghostscript
    fastfetch
    speedtest-cli
    btop
    htop
# entertainment
    # yt-dlp
    # cmus
    # spotube
# secrets management
    sops
    bitwarden-cli
    # gpg
    # age
    # pass
# editor
    # neovim
    # helix
    # kakoune
    # vis
    # emacs
    # vscode
  ];

  GREETING = "Hello, Nix!";
   shellHook = ''
   eval "$(zoxide init bash)"
   eval "$(fzf --bash)"
   eval "$(task --completion bash)"
   eval "$(direnv hook bash)"
   eval "$(starship init bash)"
   0file() { curl -F"file=@$1" https://envs.sh ; }
   0pb() { curl -F"file=@-;" https://envs.sh ; }
   0url() { curl -F"url=$1" https://envs.sh ; }
   0short() { curl -F"shorten=$1" https://envs.sh ; }
   alias l='eza -lahF --color=auto --icons --sort=size --group-directories-first'
   alias lss='eza -hF --color=auto --icons --sort=size --group-directories-first'
   alias la='eza -ahF --color=auto --icons --sort=size --group-directories-first'
   alias ls='eza -lhF --color=auto --icons --sort=Name --group-directories-first'
   alias lst='eza -lahFT --color=auto --icons --sort=size --group-directories-first'
   alias lt='eza -aT --icons --group-directories-first --color=auto --sort=size'
   alias cat='bat'
   alias grep='rg'

   echo $GREETING | cowsay | lolcat

   # secrets management
   BW_SESSION="oB8LrP9CMoqGmlPPe89YhS8fghHQh+G/qmx1if2Qnr+aS+GuJRhTkFz+UFMc86ccPZ2L9nFJjP5FWF86XkeAGg=="
   curl -s https://raw.githubusercontent.com/shaoyanji/nixconfig/refs/heads/main/modules/global/secrets/secrets.yaml -o .temp.yaml

   # pop settings
   export RESEND_API_KEY=$(sops -d --extract '["RESEND"]["API"]["KEY"]' .temp.yaml)
   # export POP_SMTP_HOST=smtp.gmail.com
   # export POP_SMTP_PORT=587
   # export POP_SMTP_USERNAME=$(sops -d --extract '["POP"]["SMTP"]["USERNAME"]' .temp.yaml)
   # export POP_SMTP_PASSWORD=$(sops -d --extract '["POP"]["SMTP"]["PASSWORD"]' .temp.yaml)
   rm .temp.yaml
  '';
}
