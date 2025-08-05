{pkgs, ...}: {
  imports = [
    ./hyprland.nix
  ];
  xdg.configFile = {
    "hypr/animations.conf".source = ../config/hypr/animations.conf;
    # "hypr/monitors.conf".source = ../config/hypr/monitors.conf;
    # "hypr/userprefs.conf".source = ../config/hypr/userprefs.conf;
    "hypr/windowrules.conf".source = ../config/hypr/windowrules.conf;
    # "hypr/themes/colors.conf".source = ../config/hypr/themes/colors.conf;
    "hypr/themes/common.conf".source = ../config/hypr/themes/common.conf;
    "hypr/themes/theme.conf".source = ../config/hypr/themes/theme.conf;
  };
}
