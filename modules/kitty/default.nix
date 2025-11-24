{...}: {
  programs.kitty = {
    enable = true;
    themeFile = "tokyo_night_storm";
    shellIntegration.enableBashIntegration = true;
    settings = {
      background_opacity = 0.6;
      scrollback_lines = 10000;
      enable_audio_bell = false;
      update_check_interval = 0;
    };
    font = {
      name = "JetBrainsMono Nerd Font";
      size = 14;
    };
  };
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
  #

  # xdg.configFile = {
  #   "kitty/kitty.conf".source = builtins.fetchurl {
  #     url = "https://gist.githubusercontent.com/shaoyanji/9b62e91a017add8d6e397e2f7acf9c8b/raw/9550bd4c5177498331fc75e85091a4c35fe02a1d/kitty.conf";
  #     sha256 = "1bcng872z0fcpny3hljpqds8nvqrzq79br3q5486rq13gik42iq7";
  #   };
  #   "kitty/current-theme.conf".source = builtins.fetchurl {
  #     url = "https://gist.githubusercontent.com/shaoyanji/17d95dbb9f9b7453c4595caaf0f0ac81/raw/d26e4b763c5d258b7e8f0a1a29f77fc5f8750726/current-theme.conf";
  #     sha256 = "0x6jv0ry2lynd9py6blsif3pplgbmmf45f7sysxdqqw3093mfa6r";
  #   };
  # };
}
