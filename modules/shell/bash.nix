{
  programs={
    bash = {
      enable = true;
      bashrcExtra = /*bash*/ ''
        source $HOME/.bash_aliases
        eval "$(fzf --bash)"
        eval "$(zoxide init bash)"
        eval "$(starship init bash)"
      '';
    };
  };
  home.file = {
     ".bash_aliases".text = /*bash*/''
      0file() { curl -F"file=@$1" https://envs.sh ; }
      0pb() { curl -F"file=@-;" https://envs.sh ; }
      0url() { curl -F"url=$1" https://envs.sh ; }
      0short() { curl -F"shorten=$1" https://envs.sh ; }
    '';
  };
 home.sessionVariables = {
  };
}
