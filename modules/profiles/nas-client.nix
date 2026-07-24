{ config
, lib
, pkgs
, ...
}:
let
  nasAutomountOptions = [
    "x-systemd.automount"
    "x-systemd.after=network-online.target"
    "noauto"
    "x-systemd.idle-timeout=60"
    "x-systemd.device-timeout=15s"
    "x-systemd.mount-timeout=15s"
  ];
in
# Skip NAS mount on both NAS hosts (the NAS doesn't mount itself).
lib.mkIf (config.networking.hostName != "thinsandy" && config.networking.hostName != "frieren") {
  environment.systemPackages = [ pkgs.nfs-utils ];

  fileSystems."/Volumes/data" = {
    device = "192.168.3.25:/data";
    fsType = "nfs";
    options = nasAutomountOptions;
  };
}
