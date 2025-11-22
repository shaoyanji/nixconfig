{
  pkgs,
  lib,
  ...
}: {
  # home.stateVersion = "25.05";
  imports = [
    ../global/minimal.nix
    ../shell
    # ../lf
    # ../env.nix
    # ../sops.nix
    # ../nixvim
    ../wezterm
    ../kitty
    # ../dev.nix
    # ../helix.nix
    # ../scripts
  ];
  # programs.thunderbird.enable = true; # requires caching
  # programs.anki.enable = true;
  home = {
    packages = with pkgs;
      [
        mupdf
        ani-cli
      ]
      ++ lib.optionals stdenv.isLinux [
        mpv
        imv
        # yank
        gnuplot
        jp2a # would not build in darwin
        lm_sensors # for `sensors` command
        ethtool
        iotop # io monitoring
      ]
      ++ lib.optionals stdenv.hostPlatform.isx86_64 [
        # anki-bin
        # markdown-anki-decks
        qalculate-qt
        thunderbird-bin
        hyprpicker
        cliphist
        wl-clipboard
        simplex-chat-desktop
        go
        gcc
        wasmtime
        tinygo
        scc
        goose-cli
        uv
        qrrs
        cook-cli
        surge-cli
        supabase-cli
        turso-cli
        cloudflare-cli
        bootdev-cli
        wash-cli
        rendercv
      ]
      ++ lib.optionals stdenv.isDarwin [
        # libation
        ytfzf
        iina # ani-cli dependency
        wget
        cocoapods
        m-cli # useful macOS CLI commands
        # wezterm
        # darwin.xcode_16_1
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

    sessionVariables = {
    };
  };

  # nixpkgs.config.allowUnfree = true;
  # nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [
  #   "obsidian"
  # ];

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;
}
