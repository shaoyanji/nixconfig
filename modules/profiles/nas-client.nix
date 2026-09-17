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
# Skip NAS mount on the NAS host itself (the NAS doesn't mount itself).
  # (thinsandy, the previous NAS, was decommissioned — frieren is the NAS.)
lib.mkIf (config.networking.hostName != "frieren") {
  environment.systemPackages = [ pkgs.nfs-utils ];

  fileSystems."/Volumes/data" = {
    device = "192.168.3.25:/data";
    fsType = "nfs";
    options = nasAutomountOptions;
  };
}
