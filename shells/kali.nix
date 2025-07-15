# let
#   nixpkgs = fetchTarball "https://github.com/NixOS/nixpkgs/tarball/nixos-unstable";
#   pkgs = import nixpkgs { config = {}; overlays = []; };
# in
{pkgs ? import <nixpkgs> {}}:
pkgs.mkShell
# pkgs.mkShellNoCC
{
  packages = with pkgs; [
    helix
    cowsay
    lolcat
    # aitools
    aichat
    tgpt
    mods
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
    # eval "$(task --completion bash)"
    eval "$(${pkgs.direnv}/bin/direnv hook bash)"
    eval "$(starship init bash)"
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
    alias cat='${pkgs.bat}/bin/bat'
    alias grep='${pkgs.ripgrep}/bin/rg'

    echo $GREETING | cowsay | lolcat

  '';
}
