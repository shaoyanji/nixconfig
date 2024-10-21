{ config, pkgs, ... }:
let 
  myAliases = { 
      l="eza -lahF --color=auto --icons --sort=size --group-directories-first";
      lss="eza -hF --color=auto --icons --sort=size --group-directories-first";
      la="eza -ahF --color=auto --icons --sort=size --group-directories-first";
      ls="eza -lhF --color=auto --icons --sort=Name --group-directories-first";
      lst="eza -lahFT --color=auto --icons --sort=size --group-directories-first";
      lt="eza -aT --icons --group-directories-first --color=auto --sort=size";
    #cat="bat";
  };
in
{
  programs.zsh = {
    enable = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
    enableCompletion = true;
    shellAliases = myAliases;
    oh-my-zsh = {
      enable = true;
      plugins = [
        "git"
        #"kubectl"
        #"docker"
        #"helm"
        "aliases"
        "alias-finder"
        "colored-man-pages"
        "vi-mode"
      ];
    };
  };
  #  imports = [ ./shells/fish ];
  programs.bash = {
    enable = true;
    shellAliases = myAliases;
    bashrcExtra = ''
    	source $HOME/.bash_aliases
	eval "$(fzf --bash)"
	eval "$(zoxide init bash)"
        eval "$(starship init bash)"
    '';
  };
  programs.starship = {
    enable = true;
    # Configuration written to ~/.config/starship.toml
    settings = {
      # add_newline = false;
       character = {
         success_symbol = "[➜](bold green)";
         error_symbol = "[➜](bold red)";
       };
      # package.disabled = true;
    };
  };
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };
  programs.zoxide = {
    enable = true;
    options = [
      "--cmd cd"
        ];
  };
  programs.fzf.enable = true;

  home.packages = with pkgs;
    [
      thefuck
      jq
      ripgrep
      fd
      zsh-forgit
      zsh-fzf-history-search
      zsh-fzf-tab
      bat
      eza
      starship
      tgpt
    ];

  home.file = {
    #    ".zshrc".source = ./.zshrc;
    ".tmux.conf".source = ./.tmux.conf;

    # # You can also set the file content immediately.

     ".bash_aliases".text = ''
      0file() { curl -F"file=@$1" https://envs.sh ; }
      0pb() { curl -F"file=@-;" https://envs.sh ; }
      0url() { curl -F"url=$1" https://envs.sh ; }
      0short() { curl -F"shorten=$1" https://envs.sh ; }
    '';
    # ".gradle/gradle.properties".text = ''
    #   org.gradle.console=verbose
    #   org.gradle.daemon.idletimeout=3600000
    # '';
  };

 home.sessionVariables = {
  };
}
