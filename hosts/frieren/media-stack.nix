{
  pkgs,
  lib,
  ...
}: let
  user = import ../../modules/global/user.nix;

  # DLNA is a first-party Jellyfin plugin (moved out of core in 10.9). nixpkgs
  # offers neither a `services.jellyfin.plugins` option nor a plugin package, so
  # the ABI-matched release is fetched and dropped into the persistent plugins
  # dir by the activation script below. Bump `version` + `hash` together when the
  # running Jellyfin's targetAbi advances; source of truth:
  # https://repo.jellyfin.org/files/plugin/manifest.json
  jellyfin-plugin-dlna =
    pkgs.runCommand "jellyfin-plugin-dlna-14.0.0.0" {
      nativeBuildInputs = [pkgs.unzip];
    } ''
      mkdir -p $out/DLNA_14.0.0.0
      unzip -q ${
        pkgs.fetchurl {
          url = "https://repo.jellyfin.org/files/plugin/dlna/dlna_14.0.0.0.zip";
          hash = "sha256-kf4oheol9tnvtcV+i47lWucJfSYZCKWv0U/z9er1chU=";
        }
      } -d $out/DLNA_14.0.0.0
    '';
in {
  # --- Immich ---
  # Machine learning re-enabled (2026-09-29): smart search + facial
  # recognition. The onnxruntime build in nixpkgs does not ship the
  # OpenVINO execution provider, so ML jobs run on CPU — acceptable for
  # a personal library; the UHD 620 keeps serving Jellyfin/Plex
  # transcodes. Models download from HuggingFace on first job into
  # MACHINE_LEARNING_CACHE_FOLDER (/var/cache/immich, module default).
  users.users.immich.extraGroups = ["video" "render"];
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

  # QuickSync needs the iGPU render node. nixpkgs' jellyfin user carries no
  # video/render groups, so transcoding only worked because udev happens to
  # expose /dev/dri/renderD128 as 0666 here. Declare the groups instead of
  # relying on that: headless and desktop both import this file.
  users.users.jellyfin.extraGroups = ["video" "render"];

  services.jellyfin = {
    enable = true;
    openFirewall = true;
    dataDir = "/srv/private/jellyfin";
  };

  # Jellyfin reads plugins only at startup and loads them from the persistent
  # data pool (/srv/private is a btrfs subvolume), so the plugin survives
  # rebuilds and the service is restarted whenever the pinned plugin changes.
  systemd.tmpfiles.rules = [
    "d /srv/private/jellyfin/plugins 0755 jellyfin jellyfin -"
    "d /srv/data/audiobooks 0755 ${user.name} users -"
    "d /srv/data/audiobooks/Books 0755 ${user.name} users -"
    "d /srv/data/audiobooks/.inprogress 0755 ${user.name} users -"
    "d /home/${user.name}/.local/share/Libation 0700 ${user.name} users -"
  ];

  # --- Libation (Audible audiobook manager & scheduled sync) ---
  systemd.services.libation-sync = {
    description = "Libation Audible Audiobook Sync & Liberate";
    after = ["network-online.target"];
    wants = ["network-online.target"];
    serviceConfig = {
      Type = "oneshot";
      User = user.name;
      Group = "users";
      WorkingDirectory = "/srv/data/audiobooks";
      ExecStart = pkgs.writeShellScript "libation-sync-run" ''
        set -eu
        if [ ! -s "/home/${user.name}/.local/share/Libation/Settings.json" ]; then
          echo "Libation settings not found. Skipping sync."
          exit 0
        fi
        if ${pkgs.libation}/bin/libationcli list-accounts 2>&1 | grep -q "No accounts configured"; then
          echo "No Audible accounts configured in Libation. Skipping sync."
          exit 0
        fi
        echo "Starting Libation scan..."
        ${pkgs.libation}/bin/libationcli scan || true
        echo "Starting Libation liberation..."
        ${pkgs.libation}/bin/libationcli liberate || true
      '';
    };
  };

  systemd.timers.libation-sync = {
    description = "Daily Libation Audible Audiobook Sync";
    wantedBy = ["timers.target"];
    timerConfig = {
      OnCalendar = "daily";
      Persistent = true;
      RandomizedDelaySec = "1800";
    };
  };

  system.activationScripts.jellyfin-dlna = {
    text = ''
      plugins=/srv/private/jellyfin/plugins
      if [ -d /srv/private/jellyfin ]; then
        mkdir -p "$plugins"
        rm -rf "$plugins"/DLNA_*
        cp -r ${jellyfin-plugin-dlna}/DLNA_14.0.0.0 "$plugins"/DLNA_14.0.0.0
        chown -R jellyfin:jellyfin "$plugins"/DLNA_14.0.0.0
        chmod -R u=rwX,go=rX "$plugins"/DLNA_14.0.0.0
      fi
    '';
  };

  systemd.services.jellyfin.restartTriggers = [jellyfin-plugin-dlna];

  environment.systemPackages = with pkgs; [
    jellyfin
    jellyfin-web
    jellyfin-ffmpeg
    libation
  ];

  # --- Plex ---
  services.plex = {
    enable = true;
    openFirewall = true;
    user = user.name;
    dataDir = "/srv/private/plex";
  };

  # --- Audiobookshelf (self-hosted audiobook & podcast server) ---
  services.audiobookshelf = {
    enable = true;
    port = 13378;
    host = "0.0.0.0";
    openFirewall = true;
  };
  users.users.audiobookshelf.extraGroups = ["users"];

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
}
