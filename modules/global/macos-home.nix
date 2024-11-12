{ pkgs, lib,  ... }:

{
  home.stateVersion = "24.11";
  imports = [ 
    #./home.nix
    # ./hyprland.nix
    #./lf
    ./env.nix 
    #./shell
    ./sops.nix
    #./nixvim 
    #./wezterm 
    #    ./kitty
    # ./browser/firefox.nix
    # ./nvim
  ];


  # The home.packages option allows you to install Nix packages into your
  # environment.
  home.packages = with pkgs; [
    #cmus
    glow
    entr
    gum
    go-task
    mc
    hyperfine
    tgpt
    ]  ++ lib.optionals stdenv.isDarwin [
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
