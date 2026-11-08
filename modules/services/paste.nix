# Remote paste bin: pastes land on frieren over SSH, served read-only by
{user, ...}: {
  # Paste storage + 30-day expiry (tmpfiles 'e' cleans files older than age).
  systemd.tmpfiles.rules = [
    "d /var/lib/paste 0755 ${user.name} users -"
    "e /var/lib/paste - - - 30d"
  ];

  services.nginx.virtualHosts."paste.frieren.lan" = {
    serverAliases = [
      "paste.lan"
      "paste.frieren.local"
      "paste.local"
    ];
    listen = [
      {
        addr = "0.0.0.0";
        port = 80;
      }
    ];
    locations."/" = {
      root = "/var/lib/paste";
      extraConfig = ''
        # No directory listings: /var/ has no index file, and an open
        # autoindex would enumerate every paste (names are the only gate).
        autoindex off;
        default_type text/plain;
      '';
    };
    # The bare root has no index, so it answered 403. Serve a hint file instead
    # (a file, so the wording needs no nginx escaping), but not via `alias` at
    # `/`: a location whose URI ends in `/` runs the index module and asks for
    # `<file>index.html`, which is a 500. Rewrite to a non-directory URI.
    locations."= /" = {
      extraConfig = ''
        rewrite ^ /_notice.txt last;
      '';
    };
    locations."= /_notice.txt" = {
      alias = ./paste-notice.txt;
      extraConfig = ''
        default_type text/plain;
        add_header Cache-Control "no-store";
      '';
    };
  };
}
