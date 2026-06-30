{
  pkgs,
  lib,
  ...
}: {
  imports = [
    ./hardware-configuration.nix
    ../../modules/profiles/firewall-baseline.nix
  ];

  networking.hostName = "demo";

  # No sops, no secrets — use plain password for demo/travel box
  users.users.user = {
    isNormalUser = true;
    description = "demo user";
    extraGroups = ["networkmanager" "wheel"];
    # mkpasswd -m sha-512 "demo" is the default password for this travel image
    hashedPassword = "$6$demo$demo";
    openssh.authorizedKeys.keys = [];
  };

  # Lightweight display manager for niri autologin
  services.displayManager = {
    autoLogin = {
      enable = true;
      user = "user";
    };
  };

  programs.niri.enable = true;

  # Minimal session env
  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1";
  };

  environment.systemPackages = with pkgs; [
    # Tools for netbook travels
    networkmanagerapplet
    bluez
    bluez-tools
  ];

  # Minimal portal setup (GTK only — no KDE deps)
  xdg.portal = {
    enable = true;
    extraPortals = with pkgs; [
      xdg-desktop-portal-gtk
    ];
    config.common = {
      default = [ "gtk" ];
      "org.freedesktop.impl.portal.FileChooser" = [ "gtk" ];
    };
  };

  # Fonts — minimal
  fonts = {
    enableDefaultPackages = true;
    fontconfig.defaultFonts = {
      serif = ["Noto Serif"];
      sansSerif = ["Noto Sans"];
      monospace = ["JetBrainsMono Nerd Font"];
    };
    packages = with pkgs; [
      nerd-fonts.jetbrains-mono
    ];
  };

  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  hardware.bluetooth.enable = true;

  # zram for RAM-sensitive netbook
  zramSwap.enable = true;

  # Key repeat & caps as ctrl (via keyd)
  services.keyd = {
    enable = true;
    keyboards = {
      default = {
        ids = ["*"];
        settings = {
          main = {
            capslock = "escape";
          };
        };
      };
    };
  };

  # Tailscale for mesh connectivity
  services.tailscale.enable = true;

  # Wireless/network
  networking.networkmanager.enable = true;

  # Basics
  time.timeZone = "Europe/Berlin";
  i18n.defaultLocale = "en_US.UTF-8";
  console = {
    font = "Lat2-Terminus16";
    keyMap = "us";
  };

  security.sudo.wheelNeedsPassword = false;

  system.stateVersion = "25.05";
}
