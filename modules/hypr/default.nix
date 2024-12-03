{pkgs, ...}: {
  home.packages = with pkgs; [
  ];
  home.file={
    ".config/hypr/animations.conf".source=./animations.conf;
    ".config/hypr/monitors.conf".source=./monitors.conf;
    ".config/hypr/userprefs.conf".source=./userprefs.conf;
    ".config/hypr/windowrules.conf".source=./windowrules.conf;
    ".config/hypr/themes/colors.conf".source=./themes/colors.conf;
    ".config/hypr/themes/common.conf".source=./themes/common.conf;
    ".config/hypr/themes/theme.conf".source=./themes/theme.conf;
  };
}
