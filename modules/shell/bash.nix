{
  programs = {
    bash = {
      enable = true;
      bashrcExtra =
        /*
        bash
        */
        ''
          # Autodetect Wayland and X11 display socket if unset (e.g. SSH / tmux sessions)
          if [ -z "''${WAYLAND_DISPLAY:-}" ] && [ -n "''${XDG_RUNTIME_DIR:-}" ]; then
            for sock in "$XDG_RUNTIME_DIR"/wayland-*; do
              if [ -S "$sock" ]; then
                export WAYLAND_DISPLAY="''${sock##*/}"
                break
              fi
            done
          fi
          if [ -z "''${DISPLAY:-}" ] && [ -S "/tmp/.X11-unix/X0" ]; then
            export DISPLAY=":0"
          fi

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
        tsup() { curl -F "file=@$1" https://temp.sh/upload; }
        log2() { local n=0; for ((i=$1-1; i>0; i>>=1)); do ((n+=1)); done; echo $n; }
      '';
  };
  home.sessionVariables = {};
}
