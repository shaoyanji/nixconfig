# Remote paste bin: pastes land on frieren over SSH, served read-only by
# nginx at http://paste.frieren.lan (LAN + Tailscale only — no auth, so treat
# pastes as LAN-visible; 8-char random names + 30-day tmpfiles expiry).
#
# Server component on frieren. The client CLI `pb` is installed fleet-wide via
# modules/scripts/pb.nix.
#
# DNS: covered by the dnsmasq wildcard (address=/frieren.lan/192.168.3.25);
# firewall: port 80 already open via reverse-proxy.nix.
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
    locations."= /" = {
      alias = ./paste-notice.txt;
      extraConfig = ''
        default_type text/plain;
        add_header Cache-Control "no-store";
      '';
    };
  };
}
