{pkgs, ...}: {
  # programs.alacritty.enable = true; # Super+T in the default setting (terminal)
  programs.fuzzel.enable = true; # Super+D in the default setting (app launcher)
  # programs.fuzzel.settings = {
  #   main = {
  #     terminal = "${pkgs.kitty}/bin/kitty";
  #     layer = "overlay";
  #   };
  #   colors.background = "ffffffff";
  # };
  # programs.firefox.enable = true;
  programs.swaylock.enable = true; # Super+Alt+L in the default setting (screen locker)
  services.mako.enable = true; # notification daemon
  services.swayidle.enable = true; # idle management daemon
  services.polkit-gnome.enable = true; # polkit
  home.packages = with pkgs; [
    xwayland-satellite # xwayland support
    swaybg # wallpaper
    # firefox-bin
  ];
  # xdg.configFile."niri/config.kdl".source = builtins.fetchurl {
  #   url = "https://raw.githubusercontent.com/YaLTeR/niri/refs/heads/main/resources/default-config.kdl";
  #   sha256 = "sha256:05bbav6xc8rx1fki49iv6y7grncp22afal6an31jjkqw2scq6bsd";
  # };
}
