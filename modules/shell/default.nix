{pkgs, ...}: let
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
  # The shell, in one file. `shell/base.nix` was a second name for the same
  # concept — bash + tmux — and every consumer that wanted only that half
  # imported a file whose whole body was two imports.
  imports = [
    ./starship.nix
    ./nushell.nix
    ./atuin.nix
    # ./zsh.nix
  ];
  programs = {
    # zsh = {
    #   shellAliases = myAliases;
    # };
    bash = {
      enable = true;
      shellAliases = myAliases;
      bashrcExtra = ''
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

        if [ -f "$HOME/.bash_aliases" ]; then
          source "$HOME/.bash_aliases"
        fi
      '';
    };

    tmux = {
      enable = true;
      tmuxinator.enable = true;
      shell = "${pkgs.nushell}/bin/nu";
      historyLimit = 100000;
      baseIndex = 1;
      plugins = with pkgs.tmuxPlugins; [
        yank
        resurrect
        continuum
        tmux-fzf
        vim-tmux-navigator
        fzf-tmux-url
        catppuccin
        better-mouse-mode
      ];
      keyMode = "vi";
      mouse = true;

      extraConfig = ''
        bind h select-pane -L
        bind j select-pane -D
        bind k select-pane -U
        bind l select-pane -R
        bind | split-window -h -c "#{pane_current_path}"
        bind - split-window -v -c "#{pane_current_path}"
        bind c new-window -c "#{pane_current_path}"
        set -g extended-keys on
        set -g extended-keys-format csi-u
        set -g @catppuccin_flavours "mocha"
        set -g @continuum-restore "on"
        set -g @continuum-boot "on"
        set -g @resurrect-strategy-nvim "session"
        set -g @resurrect-capture-pane-contents "on"
      '';
    };

    direnv = {
      enable = true;
      nix-direnv.enable = true;
      enableNushellIntegration = true;
      enableBashIntegration = true;
      enableGitIntegration = true;
      stdlib = ''
        # Cap nix print-dev-env at 10s so slow/un-cached builds fall back to the existing devshell
        _nix() {
          local cmd=("''${_nix_direnv_nix:-nix}" --no-warn-dirty --extra-experimental-features "nix-command flakes" "$@")
          if [[ "''${1:-}" == "print-dev-env" ]]; then
            if ! timeout 10s "''${cmd[@]}"; then
              echo "nix-direnv: devShell build exceeded 10s timeout (falling back to prior cached shell)" >&2
              return 1
            fi
          else
            "''${cmd[@]}"
          fi
        }
      '';
    };

    zoxide = {
      enable = true;
      enableBashIntegration = true;
      enableNushellIntegration = true;
      options = [
        "--cmd cd"
      ];
    };

    fzf.enable = true;
    fzf.enableBashIntegration = true;
    # Nushell integration disabled: HM's nushell-fzf-integration.nu uses
    # deprecated `str downcase` (nu 0.114) and spams a warning at every
    # shell start. Re-enable once home-manager ships the fixed script.
    fzf.enableNushellIntegration = false;
    fzf.tmux.enableShellIntegration = true;
    ripgrep.enable = true;
    jq.enable = true;
    fd = {
      enable = true;
      hidden = true;
    };
    bat = {
      enable = true;
      config = {
        style = "plain";
      };
    };
    eza = {
      enable = true;
      enableBashIntegration = true;
      enableNushellIntegration = true;
      icons = "auto";
      git = true;
      extraOptions = [
        "--group-directories-first"
      ];
    };
  };

  home.file.".bash_aliases".text = ''
    0file() { curl -F"file=@$1" https://envs.sh ; }
    0pb() { curl -F"file=@-;" https://envs.sh ; }
    0url() { curl -F"url=$1" https://envs.sh ; }
    0short() { curl -F"shorten=$1" https://envs.sh ; }
    tsup() { curl -F "file=@$1" https://temp.sh/upload; }
    log2() { local n=0; for ((i=$1-1; i>0; i>>=1)); do ((n+=1)); done; echo $n; }
  '';
}
