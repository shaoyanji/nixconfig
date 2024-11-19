{ pkgs, lib,  ... }:

{
  home.stateVersion = "24.11";
  imports = [ 
    # ./hyprland.nix
    ./lf
    ./env.nix 
    ./shell
    ./sops.nix
    ./nixvim 
    ./wezterm 
    ./kitty
    # ./browser/firefox.nix # issue with M1
    # ./nvim
  ];
  # The home.packages option allows you to install Nix packages into your
  # environment.
  home.packages = with pkgs; [
    nixd
    devenv
    cmus
    yt-dlp
# nix formatting
    #nixfmt-rfc-style
    #alejandra
    #nixpkgs-fmt
# utilities
    htop
    mailsy
    # charm-freeze
    # pop
    glow
    # entr
    gum
    go-task
    yq-go
    # just
    # mc
    hyperfine
# archives
    zip
        #    xz
    unzip
    p7zip

# networking tools
    mtr # A network diagnostic tool
    iperf3
    dnsutils  # `dig` + `nslookup`
    ldns # replacement of `dig`, it provide the command `drill`
    aria2 # A lightweight multi-protocol & multi-source command-line download utility
    socat # replacement of openbsd-netcat
    nmap # A utility for network discovery and security auditing
    ipcalc  # it is a calculator for the IPv4/v6 addresses

# misc
    cowsay
    file
    which
    tree
    gnused
    gnutar
    gawk
    zstd
    gnupg

# nix related
#
# it provides the command `nom` works just like `nix`
# with more details log output
    nix-output-monitor

# productivity
    hugo # static site generator

    btop  # replacement of htop/nmon
    iotop # io monitoring
    iftop # network monitoring

# base tools 
    # alacritty
    # niv # nix package manager
# dev tools
    # xcbuild #for temporary build of homebrew
    # coreutils
# miscellaneous
    # pandoc
    # texlive.combined.scheme-small
    # wkhtmltopdf # unstable
# languages
    # python3
    # nodejs
    # go
    # rustup
    # nim
    # gcc
    # clang
    # ruby
    # lua
    # luajit
    # moonscript
    # perl
    # php
    # quarto
    # ghostscript
# large language model tools
    # aichat
    # mods
    tgpt
    # ollama
# database
    # duckdb
    # pocketbase
    # haskelkPackages.postgrest
    # postgres
# applications
    # spotube # too many updates (better managed through homebrew)
    # niv
    # m-cli
    # browsh
    # neovim
    # python3
    # htop
    # gcc
    # coreutils
    # eza
    # fd
    # ripgrep
    # bat
    # fzf
    # zoxide
    # thefuck
    # go
    # docker
    # pocketbase
    # haskellPackages.postgrest
    # zed-editor

    # # Adds the 'hello' command to your environment. It prints a friendly
    # # "Hello, world!" when run.
    # pkgs.hello

    (pkgs.nerdfonts.override { fonts = [ "JetBrainsMono" ]; })

    # (pkgs.writeShellScriptBin "my-hello" ''
    #   echo "Hello, ${config.home.username}!"
    # '')
   ]  ++ lib.optionals stdenv.isDarwin [
    # obsidian
    cocoapods
    m-cli # useful macOS CLI commands
    wezterm
  ];
  home.file = {
    # # Building this configuration will create a copy of 'dotfiles/screenrc' in
    # # the Nix store. Activating the configuration will then make '~/.screenrc' a
    # # symlink to the Nix store copy.
    # ".screenrc".source = dotfiles/screenrc;
   # # You can also set the file content immediately.
    # ".gradle/gradle.properties".text = ''
    #   org.gradle.console=verbose
    #   org.gradle.daemon.idletimeout=3600000
    # '';
  };

    home.sessionVariables = {
  #    EDITOR = "nvim";
   };
    programs.home-manager.enable = true;
}
