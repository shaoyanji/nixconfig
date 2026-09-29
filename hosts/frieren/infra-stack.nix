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
_: {
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

  # --- restic local backups ---
  systemd.tmpfiles.rules = [
    "d /srv/backup 0700 root root -"
  ];

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

  # The restic unit fails without the password file; generate it once
  # on first run (root-only) instead of shipping a secret in this
  # commit — frieren self-upgrades and must not reference a sops
  # secret that is not in modules/secrets.yaml yet.
  systemd.services.restic-backups-frieren-local.preStart = ''
    if [ ! -s /root/.restic-password ]; then
      head -c 32 /dev/urandom | base64 > /root/.restic-password
      chmod 0600 /root/.restic-password
    fi
  '';
}
