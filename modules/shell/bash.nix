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

          # Ensure NixOS setuid wrapper path (/run/wrappers/bin) is present in PATH
          # so sudo / su work seamlessly in non-login subshells and automated agent environments.
          if [ -d /run/wrappers/bin ] && [[ ":$PATH:" != *":/run/wrappers/bin:"* ]]; then
            export PATH="/run/wrappers/bin:$PATH"
          fi

          # Load in-memory decrypted secrets if available (shared with Nushell)
          if [ -z "''${GEMINI_API_KEY:-}" ]; then
            _sec_cache="''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/nushell-secrets.json"
            if [ -f "$_sec_cache" ] && command -v jq >/dev/null 2>&1; then
              eval "$(jq -r 'to_entries | .[] | "export " + .key + "=" + (.value | @sh)' "$_sec_cache" 2>/dev/null)"
            fi
          fi

          # Ensure zoxide is initialized with --cmd cd
          if command -v zoxide >/dev/null 2>&1; then
            eval "$(zoxide init bash --cmd cd)"
          fi

          if [ -f "$HOME/.bash_aliases" ]; then
            source "$HOME/.bash_aliases"
          fi
        '';
    };
    zoxide = {
      enable = true;
      enableBashIntegration = true;
      options = ["--cmd cd"];
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
