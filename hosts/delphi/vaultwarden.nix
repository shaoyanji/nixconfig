# Vaultwarden on delphi, offloaded from frieren 2026-11-02. DOMAIN is unchanged
# because it is the origin passkeys were enrolled against; 8222/3012 are tailnet-only.
# docs/service-offload.md.
{...}: {
  services.vaultwarden = {
    enable = true;
    # Local, sqlite-consistent dumps; the offload bridge ships them to
    # /srv/backup/offload/vaultwarden-backup on frieren, whose restic snapshot is
    # the copy that survives this host.
    backupDir = "/var/backup/vaultwarden";
    config = {
      ROCKET_ADDRESS = "0.0.0.0";
      ROCKET_PORT = 8222;
      # Declared, not defaulted: frieren's proxy names the websocket port.
      WEBSOCKET_PORT = 3012;
      DOMAIN = "http://vault.frieren.lan";
      SIGNUPS_ALLOWED = true;
    };
  };

  systemd.tmpfiles.rules = [
    "d /var/backup/vaultwarden 0700 vaultwarden vaultwarden -"
  ];
}
