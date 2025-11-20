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
        mpv
        ani-cli
      ]
      ++ lib.optionals stdenv.isLinux [
        thunderbird-bin
        imv
        freetube
        markdownlint-cli
        qalculate-qt
        yank
        gnuplot
        jp2a # would not build in darwin
        lm_sensors # for `sensors` command
        ethtool
        iotop # io monitoring
        go
        gcc
        wasmtime
        tinygo
        scc
      ]
      ++ lib.optionals stdenv.hostPlatform.isx86_64 [
        # anki-bin
        # markdown-anki-decks
        hyprpicker
        cliphist
        wl-clipboard
        simplex-chat-desktop
      ]
      ++ lib.optionals stdenv.isDarwin [
        libation
        ytfzf
        iina # ani-cli dependency
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
