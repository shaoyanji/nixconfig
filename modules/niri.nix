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
  home.file."Pictures/Wallpapers/yqKnYa.jpg".source = builtins.fetchurl {
    url = "https://envs.net/~jisifu/pics/yqKnYa.jpg";
    sha256 = "sha256:0i5dc7680cx2g32manwy8smfiwg2g6h6kfrhpxlm2icxza3jdscs";
  };
  # xdg.configFile."niri/config.kdl".source = builtins.fetchurl {
  #   url = "https://raw.githubusercontent.com/YaLTeR/niri/refs/heads/main/resources/default-config.kdl";
  #   sha256 = "sha256:05bbav6xc8rx1fki49iv6y7grncp22afal6an31jjkqw2scq6bsd";
  # };
  xdg.configFile."niri/config.kdl".source = builtins.fetchurl {
    url = "https://gist.githubusercontent.com/shaoyanji/f675c27adaaac753b35af9141568b78b/raw/c545b19c872e0fc4051f0ead3c20928ce793b246/config.kdl";
    sha256 = "sha256:0f2r9zr7xam1816ppm36cpzddgxbxm0b2l02vlpxl9vhargaq5ss";
  };
}
