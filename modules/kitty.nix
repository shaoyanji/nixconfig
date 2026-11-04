# kitty: font, theme and window settings shared by the desktops.
_: {
  programs.kitty = {
    enable = true;
    themeFile = "tokyo_night_storm";
    shellIntegration.enableBashIntegration = true;
    settings = {
      background_opacity = 0.6;
      scrollback_lines = 10000;
      enable_audio_bell = false;
      update_check_interval = 0;
      hide_window_decorations = "yes";
    };
    font = {
      name = "JetBrainsMono NFM";
      size = 14;
    };
  };
}
