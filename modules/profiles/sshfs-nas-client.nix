{
  config,
  lib,
  pkgs,
  ...
}: let
  user = import ../global/user.nix;
  sshKey = "/home/${user.name}/.ssh/id_ed25519";
  sshKnownHosts = "/home/${user.name}/.ssh/known_hosts";
  nasHost = "192.168.3.25";
  nasRemotePath = "/Volumes/data";
  mountPoint = "/Volumes/data";

  sshfsOptions = [
    "allow_other"
    "default_permissions"
    "IdentityFile=${sshKey}"
    "UserKnownHostsFile=${sshKnownHosts}"
    "StrictHostKeyChecking=accept-new"
    "reconnect"
    "ServerAliveInterval=15"
    "ServerAliveCountMax=3"
    "_netdev"
    "nofail"
    "noauto"
    "x-systemd.automount"
    "x-systemd.idle-timeout=300"
    "x-systemd.device-timeout=5s"
    "x-systemd.mount-timeout=10s"
  ];
in
  lib.mkIf (config.networking.hostName != "frieren") {
    # Allow non-root users and systemd mount units to use allow_other
    programs.fuse.userAllowOther = true;

    environment.systemPackages = with pkgs; [
      sshfs-fuse
      fuse3
      (writeShellScriptBin "nas-recover" ''
        echo "Recovering ${mountPoint} SSHFS automount..."
        sudo ${pkgs.systemd}/bin/systemctl reset-failed Volumes-data.mount Volumes-data.automount 2>/dev/null || true
        sudo ${pkgs.systemd}/bin/systemctl restart Volumes-data.automount
        if ls ${mountPoint} >/dev/null 2>&1; then
          echo "Successfully mounted ${mountPoint} via SSHFS!"
        else
          echo "Automount restarted, but NAS (${nasHost}) could not be reached right now."
        fi
      '')
    ];

    # Provide mount.fuse.sshfs in /bin for util-linux mount helper lookup
    system.activationScripts.mount-sshfs = {
      text = ''
        mkdir -p /bin
        ln -sfn ${pkgs.sshfs-fuse}/bin/mount.fuse.sshfs /bin/mount.fuse.sshfs
        ln -sfn ${pkgs.sshfs-fuse}/bin/mount.sshfs /bin/mount.sshfs
      '';
    };

    # Host entry for frieren
    networking.hosts.${nasHost} = ["frieren"];

    fileSystems.${mountPoint} = {
      device = "${user.name}@${nasHost}:${nasRemotePath}";
      fsType = "fuse.sshfs";
      options = sshfsOptions;
    };

    # Prevent automount lockout when accessed before network is ready
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
  }
