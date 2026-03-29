{
  config,
  lib,
  pkgs,
  ...
}: let
  nasAutomountOptions = [
    "x-systemd.automount"
    "x-systemd.after=network-online.target"
    "noauto"
    "x-systemd.idle-timeout=60"
    "x-systemd.device-timeout=15s"
    "x-systemd.mount-timeout=15s"
  ];
in
  lib.mkIf (config.networking.hostName != "thinsandy") {
    environment.systemPackages = [pkgs.nfs-utils];

    fileSystems."/Volumes/data" = {
      device = "thinsandy.fritz.box:/data";
      fsType = "nfs";
      options = nasAutomountOptions;
    };
  }
