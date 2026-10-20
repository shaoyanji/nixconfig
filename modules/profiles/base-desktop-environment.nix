{
  pkgs,
  lib,
  ...
}: let
  user = import ../global/user.nix;
in {
  imports = [
    ./desktop-client.nix
    ../nixos/lxc
    ./boot.nix
  ];

  services = {
    displayManager = {
      autoLogin = {
        enable = true;
        user = user.name;
      };
    };
  };

  # OS keyring for secret-service clients (agy/Antigravity CLI auth tokens,
  # plus any other libsecret users). Without it agy fails at every launch:
  # "failed to retrieve token: secret keyring is locked" + DBUS warnings.
  services.gnome.gnome-keyring.enable = true;
  # File-manager plumbing Nautilus assumes but NixOS does not enable. Without
  # gvfs, `trash://` and network locations fail; without tumbler no thumbnail
  # is ever rendered (which also makes the image/video handlers look broken);
  # without udisks2 removable media never appears, and upower is what draws a
  # battery at all. All four are inert on a host that never opens a file manager.
  services.gvfs.enable = true;
  services.udisks2.enable = true;
  services.tumbler.enable = true;
  services.upower.enable = true;

  security.pam.services = {
    login.enableGnomeKeyring = true;
    greetd.enableGnomeKeyring = true; # no-op on hosts not using greetd
    sddm.enableGnomeKeyring = true; # no-op on hosts not using sddm
  };

  hardware.graphics = {
    enable = lib.mkDefault true;
    enable32Bit = lib.mkDefault pkgs.stdenv.hostPlatform.isx86_64;
  };

  programs.niri.enable = true;

  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1";
    QT_QPA_PLATFORM = "wayland";
    QT_QPA_PLATFORMTHEME = "kde";
    XDG_MENU_PREFIX = "plasma-";
  };

  environment.systemPackages = with pkgs; [
    # Audio & Desktop file management
    alsa-utils
    nautilus
    ffmpegthumbnailer
    # fn-key helpers: niri binds spawn these on XF86 media/brightness keys
    brightnessctl
    playerctl
  ];

  # GTK portal only. The KDE portal was here for its file chooser, but it pulls
  # the whole KDE/Qt portal stack — and through libksysguard, qtwebengine
  # (measured 2026-10-17: 466 MiB on frieren, more with the rest of KDE).
  # Nautilus is the file manager on this profile, so the GTK chooser is the
  # intended one; the KDE portal never had to be installed to keep Qt apps
  # themed (that is QT_QPA_PLATFORMTHEME, still set above).
  xdg.portal = {
    enable = true;
    extraPortals = with pkgs; [
      xdg-desktop-portal-gtk
    ];
    config.common = {
      default = ["gtk"];
      "org.freedesktop.impl.portal.FileChooser" = ["gtk"];
    };
    config.niri = lib.mkForce {
      default = ["gtk"];
      "org.freedesktop.impl.portal.FileChooser" = ["gtk"];
    };
  };

  programs.appimage = {
    enable = true;
    binfmt = true;
  };

  fonts = {
    enableDefaultPackages = true;
    enableGhostscriptFonts = false;
    fontconfig.defaultFonts = {
      serif = ["Noto Serif"];
      sansSerif = ["Noto Sans"];
      monospace = ["JetBrainsMono Nerd Font Mono" "JetBrainsMono NFM"];
    };
    packages = with pkgs; [
      nerd-fonts.jetbrains-mono
    ];
  };
}
