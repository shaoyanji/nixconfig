{ pkgs, ... }:
{
  programs.tmux = {
    enable = true;
    terminal = "xterm-256color";
    #shell = "zsh";
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
    ];
  home.file = {
  };

 home.sessionVariables = {
  };
}
