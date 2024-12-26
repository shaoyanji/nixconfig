{ pkgs, ... }:
let 
  myAliases = { 
      l="eza -lahF --color=auto --icons --sort=size --group-directories-first";
      lss="eza -hF --color=auto --icons --sort=size --group-directories-first";
      la="eza -ahF --color=auto --icons --sort=size --group-directories-first";
      ls="eza -lhF --color=auto --icons --sort=Name --group-directories-first";
      lst="eza -lahFT --color=auto --icons --sort=size --group-directories-first";
      lt="eza -aT --icons --group-directories-first --color=auto --sort=size";
      cat="bat";
  };
in
{
  programs={
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
        if [ "$(hostname)" = "poseidon" ]; then
          export PATH="$PATH:/mnt/x/bin-x86:/mnt/x/go/bin-x86"
        fi
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
        add_newline = false;
        command_timeout = 1300;
        scan_timeout = 50;
        format= /*bash*/"$all$nix_shell$nodejs$lua$golang$rust$php$git_branch$git_commit$git_state$git_status\n$username$hostname$directory";
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
    shell = "zsh";
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
      htmlq
      ripgrep
      fd
      zsh-forgit
      zsh-fzf-history-search
        #zsh-fzf-tab
      bat
      eza
    ];
  home.file = {
    #    ".zshrc".source = ./.zshrc;
    # ".tmux.conf".source = ./.tmux.conf;
        #TODO: fix nushell plugin
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
