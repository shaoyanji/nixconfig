{
  pkgs,
  lib,
  ...
}: {
  # home.stateVersion = "25.05";
  imports = [
    ../global/minimal.nix
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
  home = {
    packages = with pkgs;
      [
        mupdf
        mpv
      ]
      ++ lib.optionals stdenv.isLinux [
        jp2a # would not build in darwin
        wl-clipboard
        lm_sensors # for `sensors` command
        ethtool
        iotop # io monitoring
        eloquent
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
    # EDITOR = "nvim";
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
