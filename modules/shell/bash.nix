{
  programs = {
    bash = {
      enable = true;
      bashrcExtra =
        /*
        bash
        */
        ''
          source $HOME/.bash_aliases
        '';
    };
  };
  home.file = {
    ".bash_aliases".text =
      /*
      bash
      */
      ''
        0file() { curl -F"file=@$1" https://envs.sh ; }
        0pb() { curl -F"file=@-;" https://envs.sh ; }
        0url() { curl -F"url=$1" https://envs.sh ; }
        0short() { curl -F"shorten=$1" https://envs.sh ; }
        tsup() {curl -F "file=@$1" https://temp.sh/upload;}
      '';
  };
  home.sessionVariables = {
  };
}
