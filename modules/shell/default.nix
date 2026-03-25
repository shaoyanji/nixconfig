{
  pkgs,
  lib,
  ...
}: let
  myAliases = {
    l = "${pkgs.eza}/bin/eza -lahF --color=auto --icons --sort=size --group-directories-first";
    lss = "${pkgs.eza}/bin/eza -hF --color=auto --icons --sort=size --group-directories-first";
    la = "${pkgs.eza}/bin/eza -ahF --color=auto --icons --sort=size --group-directories-first";
    ls = "${pkgs.eza}/bin/eza -lhF --color=auto --icons --sort=Name --group-directories-first";
    lst = "${pkgs.eza}/bin/eza -lahFT --color=auto --icons --sort=size --group-directories-first";
    lt = "${pkgs.eza}/bin/eza -aT --icons --group-directories-first --color=auto --sort=size";
    cat = "${pkgs.bat}/bin/bat -p";
    grep = "${pkgs.ripgrep}/bin/rg";
    tb = "nc termbin.com 9999";
    ll = "ls -alF";
  };
in {
  imports = [
    ./base.nix
    ./starship.nix
    ./nushell.nix
    # ./zsh.nix
  ];
  programs = {
    # zsh = {
    #   shellAliases = myAliases;
    # };
    bash = {
      shellAliases = myAliases;
    };
    direnv = {
      enable = true;
      nix-direnv.enable = true;
      enableNushellIntegration = true;
      enableBashIntegration = true;
    };
    zoxide = {
      enable = true;
      enableBashIntegration = true;
      enableNushellIntegration = true;
      options = [
        # "--cmd cd"
      ];
    };
    fzf.enable = true;
    fzf.enableBashIntegration = true;
    fzf.tmux.enableShellIntegration = true;
    ripgrep.enable = true;
  };
  home.packages = with pkgs; [
    zoxide
    direnv
    fzf
    jq
    ripgrep
    fd
    bat
    eza
  ];
}
