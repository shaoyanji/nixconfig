# Infrastructure monitoring + backups for frieren.
#
# smartd + scrutiny: SMART health polling and web dashboard for the
#   NAS's disks. frieren is a laptop running 24/7 — temperature and
#   reallocation trends are the early-warning system. Alerts land in
#   the journal (smartd) and the scrutiny UI; wire them into HA or
#   uptime-kuma notifications later. Port 8124 because the module
#   default 8080 collides with pihole-web.
# restic: nightly backup of the stateful services to /srv/backup
#   (data pool). The repository password is generated on-device on
#   first run (root-only file) — swap for an sops-managed file and/or
#   a remote repository when off-site backups land. PostgreSQL data
#   dirs are deliberately EXCLUDED: hot-copying a live data directory
#   is not a consistent backup — add services.postgresql.backup
#   (pg_dump) alongside before trusting DB restore points.
{ pkgs, ... }: {
  # --- SMART monitoring ---
  services.smartd = {
    enable = true;
    autodetect = true;
    notifications.mail.enable = false; # no MTA configured; see header
  };

  services.scrutiny = {
    enable = true;
    collector.enable = true; # weekly metric collector (default timer)
    settings.web.listen.port = 8124;
  };
  networking.firewall.allowedTCPPorts = [ 8124 ];

  # --- Vaultwarden (Bitwarden Compatible Password & TOTP Vault) ---
  services.vaultwarden = {
    enable = true;
    config = {
      ROCKET_ADDRESS = "127.0.0.1";
      ROCKET_PORT = 8222;
      DOMAIN = "http://vault.frieren.lan";
      SIGNUPS_ALLOWED = true;
    };
    backupDir = "/srv/backup/vaultwarden";
  };

  # --- PostgreSQL daily pg_dump for Immich & Paperless ---
  systemd.tmpfiles.rules = [
    "d /srv/backup 0700 root root -"
    "d /srv/backup/postgresql 0700 postgres postgres -"
    "d /srv/backup/vaultwarden 0700 vaultwarden vaultwarden -"
  ];

  services.postgresqlBackup = {
    enable = true;
    databases = [ "immich" ];
    location = "/srv/backup/postgresql";
    startAt = "*-*-* 03:00:00"; # 30 min before 03:30 restic snapshot
  };

  # --- restic local backups ---
  services.restic.backups.frieren-local = {
    initialize = true;
    repository = "/srv/backup/restic";
    passwordFile = "/root/.restic-password";
    paths = [
      "/srv/private/home-assistant"
      "/srv/private/plex"
      "/srv/private/zigbee2mqtt"
      "/var/lib/immich"
      "/var/lib/paperless"
      "/var/lib/uptime-kuma"
      "/var/lib/vaultwarden"
      "/srv/backup/postgresql"
      "/srv/backup/vaultwarden"
    ];
    # NOTE: /var/lib/postgresql intentionally excluded — see header.
    timerConfig = {
      OnCalendar = "*-*-* 03:30:00"; # before the 04:00 autoUpgrade
      Persistent = true;
      RandomizedDelaySec = "10min";
    };
    pruneOpts = [
      "--keep-daily 7"
      "--keep-weekly 5"
      "--keep-monthly 12"
    ];
  };

  # Guarantee the restic password file exists before restic-backups runs
  # (preStart runs after module initialization, which leads to ordering failures).
  systemd.services.restic-ensure-password = {
    description = "Ensure restic repository password file exists";
    wantedBy = [ "multi-user.target" ];
    before = [ "restic-backups-frieren-local.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = pkgs.writeShellScript "restic-ensure-password" ''
        if [ ! -s /root/.restic-password ]; then
          head -c 32 /dev/urandom | base64 > /root/.restic-password
          chmod 0600 /root/.restic-password
        fi
      '';
    };
  };

  systemd.services.restic-backups-frieren-local.unitConfig = {
    Wants = [ "restic-ensure-password.service" ];
    After = [ "restic-ensure-password.service" ];
  };

  # 24/7 Remote Operator Gateway: Antigravity remote-control daemon
  systemd.user.services.antigravity-cli-daemon = {
    description = "antigravity remote-control daemon";
    after = [ "network.target" ];
    unitConfig = {
      StartLimitIntervalSec = 0;
    };
    serviceConfig = {
      Type = "simple";
      Environment = [
        "SSH_CLIENT=127.0.0.1 1 1"
        "SSH_CONNECTION=127.0.0.1 1 127.0.0.1 22"
        "HOME=/home/devji"
        "USER=devji"
        "PATH=/home/devji/.nix-profile/bin:/etc/profiles/per-user/devji/bin:/run/current-system/sw/bin"
        "SHELL=/run/current-system/sw/bin/bash"
      ];
      ExecStart = "${pkgs.antigravity-cli}/bin/agy remote-control serve";
      Restart = "on-failure";
      RestartSec = "10s";
      RestartPreventExitStatus = 3;
      TimeoutStopSec = "30s";
      StandardOutput = "journal";
      StandardError = "journal";
    };
    wantedBy = [ "default.target" ];
  };
}
