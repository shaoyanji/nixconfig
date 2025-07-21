{pkgs, ...}: {
  imports = [
    ./hyprland.nix
  ];
  xdg.configFile = {
    "hypr/animations.conf".source = ../dotfiles/.config/hypr/animations.conf;
    "hypr/monitors.conf".source = ../dotfiles/.config/hypr/monitors.conf;
    "hypr/userprefs.conf".source = ../dotfiles/.config/hypr/userprefs.conf;
    "hypr/windowrules.conf".source = ../dotfiles/.config/hypr/windowrules.conf;
    "hypr/themes/colors.conf".source = ../dotfiles/.config/hypr/themes/colors.conf;
    "hypr/themes/common.conf".source = ../dotfiles/.config/hypr/themes/common.conf;
    "hypr/themes/theme.conf".source = ../dotfiles/.config/hypr/themes/theme.conf;
  };
}
