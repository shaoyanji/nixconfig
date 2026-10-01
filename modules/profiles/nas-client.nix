{ config
, lib
, pkgs
, ...
}:
let
  nasAutomountOptions = [
    "x-systemd.automount"
    "_netdev"
    "nofail"
    "noauto"
    "x-systemd.idle-timeout=60"
    "x-systemd.device-timeout=10s"
    "x-systemd.mount-timeout=15s"
  ];
in
# Skip NAS mount on the NAS host itself (the NAS doesn't mount itself).
  # (thinsandy, the previous NAS, was decommissioned — frieren is the NAS.)
lib.mkIf (config.networking.hostName != "frieren") {
  environment.systemPackages = [
    pkgs.nfs-utils
    (pkgs.writeShellScriptBin "nas-recover" ''
      echo "Recovering /Volumes/data NAS automount..."
      sudo ${pkgs.systemd}/bin/systemctl reset-failed Volumes-data.mount Volumes-data.automount 2>/dev/null || true
      sudo ${pkgs.systemd}/bin/systemctl restart Volumes-data.automount
      if ls /Volumes/data >/dev/null 2>&1; then
        echo "Successfully mounted /Volumes/data!"
      else
        echo "Automount unit restarted, but NAS server (192.168.3.25) could not be reached right now."
      fi
    '')
  ];

  fileSystems."/Volumes/data" = {
    device = "192.168.3.25:/data";
    fsType = "nfs";
    options = nasAutomountOptions;
  };

  # Prevent automount lockout when accessed before network is ready (e.g. at boot by HM symlink checks)
  systemd.units = {
    "Volumes-data.automount.d/50-recovery.conf" = {
      text = ''
        [Unit]
        StartLimitIntervalSec=0
      '';
    };
    "Volumes-data.mount.d/50-recovery.conf" = {
      text = ''
        [Unit]
        StartLimitIntervalSec=0
      '';
    };
  };

  # Automatically recover/reset failed mount states once network comes online
  systemd.services.nas-mount-recovery = {
    description = "Recover NAS mount after network comes online";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = false;
      ExecStart = pkgs.writeShellScript "nas-mount-recovery" ''
        ${pkgs.systemd}/bin/systemctl reset-failed Volumes-data.mount Volumes-data.automount 2>/dev/null || true
        ${pkgs.systemd}/bin/systemctl restart Volumes-data.automount 2>/dev/null || true
      '';
    };
  };
}
