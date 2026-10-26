# Remote paste bin: pastes land on frieren over SSH, served read-only by
_: let
  user = import ../global/user.nix;
in {
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
    # The bare root has no index file, so nginx answered it with a bare 403 —
    # which read as "the paste bin is broken". Answer the exact root with a
    # usage hint instead; actual pastes are /<name> and keep being served above.
    # The hint is a file the server sends verbatim: no escaped-newline body in
    # the config, and the wording can be edited without touching nginx syntax.
    # `alias` to a FILE inside an exact location whose URI ends in `/` runs the
    # index module and asks for "<file>index.html", which nginx answers with a
    # 500 (measured 2026-10-26: paste.frieren.lan was the one dead card on the
    # portal). Rewrite internally to a non-directory URI so the alias target is
    # served verbatim; the browser URL stays `/`.
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
