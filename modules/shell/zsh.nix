{
  programs = {
    zsh = {
      enable = true;
      autosuggestion.enable = true;
      syntaxHighlighting.enable = true;
      enableCompletion = true;
      oh-my-zsh = {
        enable = true;
        plugins = [
          "git"
          "direnv"
          #"kubectl"
          #"docker"
          #"helm"
          "aliases"
          "alias-finder"
          "colored-man-pages"
          "vi-mode"
        ];
        initExtra = ''
          source ~/.bash_aliases
        '';
      };
    };
  };

  home.sessionVariables = {
  };
}
