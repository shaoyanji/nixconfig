{
  config,
  pkgs,
  lib,
  ...
}:
let
  user = import ../../modules/global/user.nix;
in
{
  # --- Immich ---
  users.users.immich.extraGroups = ["video" "render"];
  services.immich = {
    host = "0.0.0.0";
    enable = true;
    port = 2283;
    accelerationDevices = null;
    openFirewall = true;
    machine-learning.enable = false;
  };

  # --- *arr stack ---
  services.sonarr = {
    enable = true;
    openFirewall = true;
  };

  services.readarr = {
    enable = true;
    openFirewall = true;
  };

  services.lidarr = {
    enable = true;
    openFirewall = true;
  };

  services.prowlarr = {
    enable = true;
    openFirewall = true;
  };

  services.radarr = {
    enable = true;
    openFirewall = true;
  };

  # --- Jellyfin ---
  systemd.services.jellyfin.environment.LIBVA_DRIVER_NAME = "iHD";

  services.jellyfin = {
    enable = true;
    openFirewall = true;
  };

  environment.systemPackages = with pkgs; [
    jellyfin
    jellyfin-web
    jellyfin-ffmpeg
  ];

  # --- Plex ---
  services.plex = {
    enable = true;
    openFirewall = true;
    user = user.name;
  };

  # --- Anki sync ---
  services.anki-sync-server = {
    enable = true;
    address = "0.0.0.0";
    openFirewall = true;
    users = [
      {
        username = "bob";
        password = "password";
      }
    ];
  };

  # --- Home Assistant ---
  services.home-assistant = {
    enable = true;
    extraComponents = [
      "rest"
      "command_line"
      "todoist"
      "jellyfin"
      "plex"
      "fritzbox"
      "github"
      "immich"
      "met"
      "ipp"
      # "icloud"
      # "notion"
      # "twitter"
      # "telegram"
      # "ollama"
      # "foscam"
      # "philips_js"
      # "ecovacs"
      # "onvif"
      # "generic"
      # "tailscale"
      # "pi_hole"
      # "radio_browser"
    ];
    config = {
      default_config = {};
    };
  };
}
