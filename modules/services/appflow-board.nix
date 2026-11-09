# appflow-board — the job pipeline as a page, read straight from the archive.
#
# There is no snapshot job and no second copy: the vhost proxies five read-only
# endpoints of the mail hub's NpgsqlRest (`services.emailArchive`, loopback 8080)
# and serves one static page that calls them. The pipeline is the database's, the
# page is a viewer, and a writer that lands a row is visible at the next refresh.
#
# The allowlist is the point. `/api/application-update` and `/api/application-upsert`
# are published by the plugin too, so proxying `/api/` would put writes on the
# tailnet from a page that only reads. Four exact locations cannot reach them.
#
# Tailnet exposure is the portal mount, not a firewall row: `docs/media-relay.md`
# and `.agents/deploy/hosts/delphi.md` carry the same rule for the sibling mount.
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.appflowBoard;

  page = pkgs.runCommand "appflow-board-ui" {} ''
    mkdir -p $out
    install -m 0644 ${../../lib/appflow-board/index.html} $out/index.html
  '';

  # One exact location per read, so the proxied surface is this list and not the
  # plugin's route table.
  proxyTo = name: ''
    proxy_pass ${cfg.upstream}/api/${name};
    proxy_set_header Host 127.0.0.1;
    proxy_http_version 1.1;
    add_header Cache-Control "no-store" always;
  '';
in {
  options.services.appflowBoard = {
    enable = lib.mkEnableOption "the read-only job pipeline board (delphi)";

    port = lib.mkOption {
      type = lib.types.port;
      # 8094 is the media library, 8080 the archive API, 8461 its tailnet front.
      default = 8462;
      description = "Loopback port for the board. Nothing opens it in the firewall; the tailnet front is a portal mount.";
    };

    upstream = lib.mkOption {
      type = lib.types.str;
      default = "http://127.0.0.1:8080";
      description = "The archive API the board reads. Four read-only routes are proxied; nothing else is reachable through this vhost.";
    };
  };

  config = lib.mkIf cfg.enable {
    services.nginx = {
      enable = true;
      virtualHosts."appflow-board" = {
        listen = [
          {
            addr = "127.0.0.1";
            port = cfg.port;
          }
        ];
        root = page;
        locations = {
          # The same two-location shape the media library needed: `/` is answered
          # by the index module rewriting to `/index.html`, and the alias works
          # only where the URI does not end in `/`.
          "= /" = {
            root = page;
          };
          "= /index.html" = {
            alias = "${page}/index.html";
            extraConfig = ''
              add_header Cache-Control "no-store";
            '';
          };
          "= /api/applications" = {
            extraConfig = proxyTo "applications";
          };
          "= /api/application-pipeline" = {
            extraConfig = proxyTo "application-pipeline";
          };
          "= /api/application-get" = {
            extraConfig = proxyTo "application-get";
          };
          "= /api/applications-discovered" = {
            extraConfig = proxyTo "applications-discovered";
          };
          "= /api/application-mail" = {
            extraConfig = proxyTo "application-mail";
          };
        };
      };
    };
  };
}
