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
  };
in {
  imports = [
    #./nushell.nix # nushell not cached for darwin
    ./zsh.nix
    ./bash.nix
    ./tmux.nix
  ];
  programs = {
    zsh = {
      shellAliases = myAliases;
    };
    bash = {
      shellAliases = myAliases;
    };
    starship = {
      enable = true;
      # Configuration written to ~/.config/starship.toml
      # settings = {
      #   add_newline = false;
      #   command_timeout = 1300;
      #   scan_timeout = 50;
      #   format =
      #     /*
      #     bash
      #     */
      #     "$all$nix_shell$nodejs$lua$golang$rust$php$git_branch$git_commit$git_state$git_status\n$username$hostname$directory";
      #   character = {
      #     success_symbol = "[➜](bold green)";
      #     error_symbol = "[➜](bold red)";
      #   };
      #   # package.disabled = true;
      # };
    };
    direnv = {
      enable = true;
      nix-direnv.enable = true;
    };
    zoxide = {
      enable = true;
      options = [
        # "--cmd cd"
      ];
    };
    fzf.enable = true;
    fzf.enableBashIntegration = true;
  };
  home.packages = with pkgs; [
    # thefuck
    jq
    htmlq
    ripgrep
    fd
    zsh-forgit
    zsh-fzf-history-search
    #zsh-fzf-tab
    bat
    eza
  ];
  xdg.configFile = {
    "starship.toml".source = ../config/starship.toml;
  };
  home.file = {
  };

  home.sessionVariables = {
  };
}
