# let
#   nixpkgs = fetchTarball "https://github.com/NixOS/nixpkgs/tarball/nixos-unstable";
#   pkgs = import nixpkgs { config = {}; overlays = []; };
# in
{pkgs ? import <nixpkgs> {}}:
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
    # nushell
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
    # mpv
    # yt-dlp
    # cmus
    # spotube
    # secrets management
    sops
    # bitwarden-cli
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
    eval "$(${pkgs.zoxide}/bin/zoxide init bash)"
    eval "$(${pkgs.fzf}/bin/fzf --bash)"
    eval "$(${pkgs.go-task}/bin/task --completion bash)"
    eval "$(${pkgs.direnv}/bin/direnv hook bash)"
    eval "$(${pkgs.starship}/bin/starship init bash)"
    0file() { curl -F"file=@$1" https://envs.sh ; }
    0pb() { curl -F"file=@-;" https://envs.sh ; }
    0url() { curl -F"url=$1" https://envs.sh ; }
    0short() { curl -F"shorten=$1" https://envs.sh ; }
    alias l='${pkgs.eza}/bin/eza -lahF --color=auto --icons --sort=size --group-directories-first'
    alias lss='${pkgs.eza}/bin/eza -hF --color=auto --icons --sort=size --group-directories-first'
    alias la='${pkgs.eza}/bin/eza -ahF --color=auto --icons --sort=size --group-directories-first'
    alias ls='${pkgs.eza}/bin/eza -lhF --color=auto --icons --sort=Name --group-directories-first'
    alias lst='${pkgs.eza}/bin/eza -lahFT --color=auto --icons --sort=size --group-directories-first'
    alias lt='${pkgs.eza}/bin/eza -aT --icons --group-directories-first --color=auto --sort=size'
    alias cat='${pkgs.bat}/bin/bat -p'
    alias grep='${pkgs.ripgrep}/bin/rg'

    echo $GREETING | cowsay | lolcat

    # secrets management
    # BW_SESSION="oB8LrP9CMoqGmlPPe89YhS8fghHQh+G/qmx1if2Qnr+aS+GuJRhTkFz+UFMc86ccPZ2L9nFJjP5FWF86XkeAGg=="
    # curl -s https://raw.githubusercontent.com/shaoyanji/nixconfig/refs/heads/main/modules/global/secrets/secrets.yaml -o .temp.yaml

    # pop settings
    # export RESEND_API_KEY=$(sops -d --extract '["RESEND"]["API"]["KEY"]' .temp.yaml)
    # export POP_SMTP_HOST=smtp.gmail.com
    # export POP_SMTP_PORT=587
    # export POP_SMTP_USERNAME=$(sops -d --extract '["POP"]["SMTP"]["USERNAME"]' .temp.yaml)
    # export POP_SMTP_PASSWORD=$(sops -d --extract '["POP"]["SMTP"]["PASSWORD"]' .temp.yaml)
    # rm .temp.yaml
  '';
}
