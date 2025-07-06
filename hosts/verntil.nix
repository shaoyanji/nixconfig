{
  config,
  pkgs,
  ...
}:
## Please read the home-configuration.nix manpage for a list of all available options.
{
  home.username = "jisifu";
  home.homeDirectory = "/home/jisifu";
  home.stateVersion = "22.05";
  imports = [
    ../modules/lf
    ../modules/shell
    ../modules/helix.nix
  ];
  home.packages = with pkgs; [
    nix-index
    helix
    tgpt
    go-task
    yq
    cmark
    dprint
    marksman
    age
    pop
    glow
    charm-freeze
    viu
    qrencode
    duf
    slides
    graphviz
    graph-easy
    nix-output-monitor
    ripgrep
    fd
    bat
    eza
    gum
    mailsy
    sqlite
    lynx
    alejandra
  ];
  programs = {
    direnv = {
      enable = true;
      nix-direnv.enable = true;
    };
    zoxide = {
      enable = true;
      options = [
        "--cmd cd"
      ];
    };
    fzf.enable = true;
  };

  home.sessionVariables = {
    GUM_CHOOSE_SELECTED_FOREGROUND = 50;
    GUM_CHOOSE_CURSOR_FOREGROUND = 50;
    GUM_CHOOSE_HEADER_FOREGROUND = 30;
  }; # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;
}
