{ config, pkgs, ... }:

{
  programs.kitty = {
    enable = true;
    settings = {
      startup_session = "Default";
      font_family = "JetBrainsMono NF";
      font_size = 12;
      scrollback_lines = 10000;
      tab_bar_margin_width = 1;
      tab_bar_style = "powerline";
      tab_bar_min_tabs = 2;
      tab_bar_max_tabs = 10;
      mouse_map = "default";
      cursor_shape = "block";
      cursor_blink_interval = 0.5;
      cursor_stop_blinking_after = 0.5;
      enable_audio_bell = false;
      include = "~/.config/kitty/theme.conf";
    };
  };
  home.file.".config/kitty/theme.conf".source = ./current-theme.conf;
}
