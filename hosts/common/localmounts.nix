{
  config,
  pkgs,
  ...
}: let
  burgernas = "100.72.61.23";
  burgernas_nfs = "192.168.178.4";
  #    fritznas = "192.168.178.1";
  automount_opts = "x-systemd.automount,x-systemd.after=network-online.target,noauto,x-systemd.idle-timeout=60,x-systemd.device-timeout=10s,x-systemd.mount-timeout=10s";
  reg_opts = "rw,noserverino,uid=1000,gid=1";
  tailscale_opts = "x-systemd.requires=tailscaled.service";
  cred_wolf = "credentials=${config.sops.secrets."server/localwd/credentials".path}";
  cred_fritz = "credentials=${config.sops.secrets."server/keyrepo/credentials".path}";
in {
  systemd.timers."burgernas-unmount" = {
    wantedBy = ["timers.target"];
    timerConfig = {
      OnCalendar = "22:59:00";
      Unit = "burgernas-unmount.service";
    };
  };

  systemd.services."burgernas-unmount" = {
    script = ''
      set -eu
      ${pkgs.coreutils}/bin/umount /mnt/{v,w,x,z}
    '';
    serviceConfig = {
      Type = "oneshot";
      User = "root";
    };
  };
  environment.systemPackages = [pkgs.cifs-utils];
  fileSystems."/Volumes/peachcable" = {
    device = "${burgernas_nfs}:/volume1/peachcable";
    fsType = "nfs";
    options = ["${automount_opts}"];
  };

  #  fileSystems."/mnt/y" = {
  #    device = "//${fritznas}/fritz.nas/External-USB3-0-01/";
  #    fsType = "cifs";
  #    options =
  #    ["${automount_opts},${reg_opts},${cred_fritz}"];
  #  };
  #fileSystems."/mnt/z" = {
  #  device = "//${burgernas}/usbshare2";
  #  fsType = "cifs";
  #  options = ["${automount_opts},${reg_opts},${cred_wolf},${tailscale_opts}"];
  #};
  #fileSystems."/mnt/x" = {
  #  device = "//${burgernas}/Shared Library";
  #  fsType = "cifs";
  #  options = ["${automount_opts},${reg_opts},${cred_wolf},${tailscale_opts}"];
  #};
  #fileSystems."/mnt/v" = {
  #  device = "//${burgernas}/usbshare1";
  #  fsType = "cifs";
  #  options = ["${automount_opts},${reg_opts},${cred_wolf},${tailscale_opts}"];
  #};
}
