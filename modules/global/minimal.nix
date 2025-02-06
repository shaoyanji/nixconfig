{
  pkgs,
  lib,
  ...
}: {
  #  home.stateVersion = "24.11";
  imports = [
    ../lf
    ../env.nix
    #../shell
    ../sops.nix
    ../helix.nix
    ../shell/tmux.nix
    ../shell/bash.nix
    ../shell/nushell.nix
  ];
  home = {
    packages =
      [
        pkgs.gum
        pkgs.go-task
        pkgs.mailsy
      ]
      ++ lib.optionals pkgs.stdenv.isLinux [
        pkgs.wl-clipboard
      ];
    file = {};

    sessionVariables = {
      GUM_CHOOSE_SELECTED_FOREGROUND = 50;
      GUM_CHOOSE_CURSOR_FOREGROUND = 50;
      GUM_CHOOSE_HEADER_FOREGROUND = 30;
    };
  };
}
