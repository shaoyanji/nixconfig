# Vaultwarden — offloaded from frieren 2026-11-02 (docs/service-offload.md).
#
# 4.2 MB and 36 MiB resident: this is not about resources, it is about a password
# manager not depending on a laptop. 8222 and 3012 are opened on `tailscale0` alone;
# the only client is frieren's `vault.frieren.lan` vhost.
#
# DOMAIN is unchanged on purpose. It is the origin WebAuthn registers against, so a
# new name would silently invalidate every passkey already enrolled.
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
