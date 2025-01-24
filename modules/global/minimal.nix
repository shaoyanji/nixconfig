{
  pkgs,
  lib,
  ...
}: {
  home.stateVersion = "24.11";
  imports = [
    ../lf
    ../env.nix
    ../shell
    ../sops.nix
    ../helix.nix
  ];
  home = {
    packages = with pkgs;
      [
        gum
        go-task
        mailsy
      ]
      ++ lib.optionals stdenv.isLinux [
        wl-clipboard
      ];
    file = {};

    sessionVariables = {
      GUM_CHOOSE_SELECTED_FOREGROUND = 50;
      GUM_CHOOSE_CURSOR_FOREGROUND = 50;
      GUM_CHOOSE_HEADER_FOREGROUND = 30;
    };
  };

  nixpkgs.config.allowUnfree = true;

  programs.home-manager.enable = true;
}
