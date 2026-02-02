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
    # ../dev.nix
    # ../helix.nix
    # ../scripts
  ];
  home = {
    packages = with pkgs;
      [
        mupdf
        opencode
      ]
      ++ lib.optionals stdenv.isLinux [
        ani-cli
        audacity
        mpv
        ytfzf
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
        goose-cli
        qrrs
        cook-cli
        surge-cli
        supabase-cli
        turso-cli
        cloudflare-cli
        bootdev-cli
        wash-cli
        rendercv
        libation
      ]
      ++ lib.optionals stdenv.isDarwin [
        iina # ani-cli dependency
        wget
        cocoapods
        m-cli # useful macOS CLI commands
        # libation
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
