{
  pkgs,
  lib,
  inputs,
  ...
}: {
  # home.stateVersion = "25.05";
  imports = [
    inputs.kickstart-nixvim.homeManagerModules.default
    # ../global/minimal.nix
    # ../lf
    # ../env.nix
    ../shell
    # ../sops.nix
    # ../nixvim
    ../wezterm
    ../kitty
    # ../dev.nix
    # ../helix.nix
    # ../scripts
  ];
  programs.nixvim.enable = true;
  home = {
    packages = with pkgs;
      [
        mupdf
        mpv
        # viu
        # qrencode
        # duf
        # go-task
        # nixd
        # devenv
        #cmus
        #yt-dlp
        # sqlite
        ## nix formatting
        #nixfmt-rfc-style
        #alejandra
        #nixpkgs-fmt
        ## utilities
        # htop
        # mailsy
        # pop
        # glow
        # charm-freeze
        # entr
        # gum
        # go-task
        # yq-go
        # just
        # mc
        # hyperfine
        ## archives
        # zip
        # xz
        # unzip
        # p7zip

        # networking tools
        # mtr # A network diagnostic tool
        # iperf3
        # dnsutils # `dig` + `nslookup`
        # ldns # replacement of `dig`, it provide the command `drill`
        # aria2 # A lightweight multi-protocol & multi-source command-line download utility
        # socat # replacement of openbsd-netcat
        # nmap # A utility for network discovery and security auditing
        # ipcalc # it is a calculator for the IPv4/v6 addresses

        # misc
        # file
        # which
        # tree
        # gnused
        # gnutar
        # gawk
        # zstd
        # gnupg

        ## nix related
        ## it provides the command `nom` works just like `nix`
        ## with more details log output
        # nix-output-monitor

        ## productivity
        # hugo # static site generator

        # btop # replacement of htop/nmon
        # iftop # network monitoring

        ## base tools
        # alacritty
        # niv # nix package manager
        ## dev tools
        # xcbuild #for temporary build of homebrew
        # coreutils
        ## miscellaneous
        # pandoc
        # texlive.combined.scheme-small
        # wkhtmltopdf # unstable
        ## languages
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
        ## large language model tools
        # aichat
        # mods
        # tgpt
        # ollama
        # database
        # duckdb
        # pocketbase
        # haskelkPackages.postgrest
        # postgres
        ## applications
        # spotube # too many updates (better managed through homebrew)
        # niv
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

        # diff-so-fancy
        # entr
        # exiftool
        # fdupes
        # most
        # procs
        # # rip
        # rsync
        # sd
        # tre
        # bandwhich
        # glances
        # gping
        # #dua-cli
        # speedtest-cli
        # #dog
        # buku
        # ddgr
        # khal
        # mutt
        # newsboat
        # rclone
        # #taskwarrior3
        # tuir
        # httpie
        # lazygit
        # #ngrok
        # asciinema
        # navi
        # #transfer
        # #surge #x86
        # epr
        # #meetup-cli
        # lynx
        # #obs
        # #hget
        # translate-shell
        # mc
        # #gitmoji-cli
        # #gitmoji-changelog
        # #sparkly-cli
        # #lowcharts
        # # Adds the 'hello' command to your environment. It prints a friendly
        # # "Hello, world!" when run.
        # pkgs.hello

        #(pkgs.nerdfonts.override { fonts = [ "JetBrainsMono" ]; })
        #(pkgs.nerd-fonts.jetbrains-mono)

        # (pkgs.writeShellScriptBin "my-hello" ''
        #   echo "Hello, ${config.home.username}!"
        # '')
      ]
      ++ lib.optionals stdenv.isLinux [
        jp2a # would not build in darwin
        # keybase
        wl-clipboard
        lm_sensors # for `sensors` command
        ethtool
        iotop # io monitoring
        ##   system call monitoring
        # strace # system call monitoring
        # ltrace # library call monitoring
        # lsof # list open files
        # ##   system tools
        # sysstat
        # pciutils # lspci
        # usbutils # lsusb
      ]
      ++ lib.optionals stdenv.isDarwin [
        libation
      ];
    file = {
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

    # sessionVariables = {
    #   #    EDITOR = "nvim";
    #   GUM_CHOOSE_SELECTED_FOREGROUND = 50;
    #   GUM_CHOOSE_CURSOR_FOREGROUND = 50;
    #   GUM_CHOOSE_HEADER_FOREGROUND = 30;
    # };
  };

  # nixpkgs.config.allowUnfree = true;
  # nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [
  #   "obsidian"
  # ];

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;
}
