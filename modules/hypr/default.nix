{pkgs, ...}: {
  imports = [
    ./hyprland.nix
  ];
  xdg.configFile = {
    "hypr/animations.conf".source=./animations.conf;
    "hypr/monitors.conf".source=./monitors.conf;
    "hypr/userprefs.conf".source=./userprefs.conf;
    "hypr/windowrules.conf".source=./windowrules.conf;
    "hypr/themes/colors.conf".source=./themes/colors.conf;
    "hypr/themes/common.conf".source=./themes/common.conf;
    "hypr/themes/theme.conf".source=./themes/theme.conf;
  };
}
