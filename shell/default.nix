{ config, pkgs, ... }:
let 
  myAliases = { 
      l="exa -lahF --color=auto --icons --sort=size --group-directories-first";
      lss="exa -hF --color=auto --icons --sort=size --group-directories-first";
      la="exa -ahF --color=auto --icons --sort=size --group-directories-first";
      ls="exa -lhF --color=auto --icons --sort=Name --group-directories-first";
      lst="exa -lahFT --color=auto --icons --sort=size --group-directories-first";
      lt="exa -aT --icons --group-directories-first --color=auto --sort=size";
      cat="bat";

  };
in
{
  
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
  home.packages = with pkgs;
  [
      fzf
      zoxide
      bat
      eza
      starship

      tgpt
    
  ];

  home.file = {
    # ".p10k.zsh".source = ./.p10k.zsh;
    ".zshrc".source = ./.zshrc;
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
