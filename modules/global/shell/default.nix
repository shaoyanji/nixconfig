{ pkgs, ... }:
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
  programs={
    nushell={
      enable=true;
      extraConfig = /*nu*/ ''
        let carapace_completer = {|spans|
        carapace $spans.0 nushell $spans | from json
        }
        $env.config = {
         show_banner: false,
         history: {
          max_size: 100_000 # Session has to be reloaded for this to take effect
          sync_on_enter: true # Enable to share history between multiple sessions, else you have to close the session to write history to file
          file_format: "sqlite" # "sqlite" or "plaintext"
          isolation: false # only available with sqlite file_format. true enables history isolation, false disables it. true will allow the history to be isolated to the current session using up/down arrows. false will allow the history to be shared across all sessions.
         }
         completions: {
         case_sensitive: false # case-sensitive completions
         quick: true    # set to false to prevent auto-selecting completions
         partial: true    # set to false to prevent partial filling of the prompt
         algorithm: "fuzzy"    # prefix or fuzzy
         external: {
         # set to false to prevent nushell looking into $env.PATH to find more suggestions
             enable: true 
         # set to lower can improve completion performance at the cost of omitting some options
             max_results: 100 
             completer: $carapace_completer # check 'carapace_completer' 
           }
         }



        } 
        $env.PATH = ($env.PATH | 
        split row (char esep) |
        prepend /home/devji/.apps |
        append /usr/bin/env
        )
        '';
    };
    carapace.enable = true;
    carapace.enableNushellIntegration = true;
    zsh = {
      enable = true;
      autosuggestion.enable = true;
      syntaxHighlighting.enable = true;
      enableCompletion = true;
      shellAliases = myAliases;
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
      };
    };
    #  imports = [ ./shells/fish ];
    bash = {
      enable = true;
      shellAliases = myAliases;
      bashrcExtra = /*bash*/ ''
        if [ "$(hostname)" = "lunarfall" ]; then
          source "$HOME/.nix-profile/etc/profile.d/hm-session-vars.sh"
        fi
        source $HOME/.bash_aliases
        eval "$(fzf --bash)"
        eval "$(zoxide init bash)"
        eval "$(starship init bash)"

      '';
    };
    starship = {
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
    direnv = {
      enable = true;
      nix-direnv.enable = true;
    };
    zoxide = {
      enable = true;
      options = [
        "--cmd cd"
          ];
    };
    fzf.enable = true;
  };
  programs.tmux = {
    enable = true;
    terminal = "xterm-256color";
    shell = "${pkgs.zsh}/bin/zsh";
      #shortcut = "a";
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
    extraConfig = /*tmux*/ ''
      set -g mouse on
      bind h select-pane -L
      bind j select-pane -D
      bind k select-pane -U
      bind l select-pane -R
      bind | split-window -h -c "#{pane_current_path}"
      bind - split-window -v -c "#{pane_current_path}"
      bind c new-window -c "#{pane_current_path}"
      set -g @catppuccin_flavours "mocha"
      set -g @continuum-restore "on"
      set -g @continuum-boot "on"
      set -g @resurrect-strategy-nvim "session"
      set -g @resurrect-capture-pane-contents "on"
    '';
  };
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
    ];

  home.file = {
    #    ".zshrc".source = ./.zshrc;
    # ".tmux.conf".source = ./.tmux.conf;

    # # You can also set the file content immediately.

     ".bash_aliases".text = /*bash*/''
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
