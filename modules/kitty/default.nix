{ config, pkgs, ... }:

{
  #  programs.kitty = {
  #    enable = true;
  #    settings = {
  #      font_family = "JetBrainsMono";
  #      font_size = 12;
  #      background_opacity = 0.9;
  #      scrollback_lines = 10000;
  #      tab_bar_margin_width = 1;
  #      tab_bar_style = "powerline";
  #      tab_bar_min_tabs = 2;
  #      cursor_shape = "block";
  #      cursor_blink_interval = 0.5;
  #      cursor_stop_blinking_after = 0.5;
  #      enable_audio_bell = false;
  #      include = "~/.config/kitty/theme.conf";
  #    };
  #  };
  home.file.".config/kitty/kitty.conf".source = ./kitty.conf;
  home.file.".config/kitty/current-theme.conf".source = ./current-theme.conf;
}
