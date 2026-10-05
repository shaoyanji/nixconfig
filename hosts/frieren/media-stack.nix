{ pkgs
, lib
, ...
}:
let
  user = import ../../modules/global/user.nix;
in
{
  # --- Immich ---
  # Machine learning re-enabled (2026-09-29): smart search + facial
  # recognition. The onnxruntime build in nixpkgs does not ship the
  # OpenVINO execution provider, so ML jobs run on CPU — acceptable for
  # a personal library; the UHD 620 keeps serving Jellyfin/Plex
  # transcodes. Models download from HuggingFace on first job into
  # MACHINE_LEARNING_CACHE_FOLDER (/var/cache/immich, module default).
  users.users.immich.extraGroups = [ "video" "render" ];
  services.immich = {
    host = "0.0.0.0";
    enable = true;
    port = 2283;
    accelerationDevices = null;
    openFirewall = true;
    machine-learning.enable = true;
  };

  # /var/lib/immich lives on the data pool — the module's shared
  # serviceConfig sets PrivateMounts=true which masks it, so all three
  # services get the override (ML reads the library for embeddings/
  # facial recognition just like server/microservices).
  systemd.services.immich-server.unitConfig.RequiresMountsFor = "/var/lib/immich";
  systemd.services.immich-microservices.unitConfig.RequiresMountsFor = "/var/lib/immich";
  systemd.services.immich-machine-learning.unitConfig.RequiresMountsFor = "/var/lib/immich";
  systemd.services.immich-server.serviceConfig.PrivateMounts = lib.mkForce false;
  systemd.services.immich-microservices.serviceConfig.PrivateMounts = lib.mkForce false;
  systemd.services.immich-machine-learning.serviceConfig.PrivateMounts = lib.mkForce false;

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
    dataDir = "/srv/private/jellyfin";
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
    dataDir = "/srv/private/plex";
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
    configDir = "/srv/private/home-assistant";
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
      "mqtt"
    ];
    extraPackages = ps: [
      ps.androidtvremote2
    ];
    config = {
      default_config = { };
      command_line = [
        {
          sensor = {
            name = "frieren Battery Level";
            command = "cat /sys/class/power_supply/BAT0/capacity";
            unit_of_measurement = "%";
            device_class = "battery";
          };
        }
        {
          sensor = {
            name = "frieren Battery Status";
            command = "cat /sys/class/power_supply/BAT0/status";
            icon = "mdi:battery-charging";
          };
        }
        {
          binary_sensor = {
            name = "frieren AC Connected";
            command = "cat /sys/class/power_supply/ADP0/online";
            payload_on = "1";
            payload_off = "0";
            device_class = "power";
          };
        }
      ];
    };
  };
}
