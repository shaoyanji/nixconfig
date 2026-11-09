# appflow-board — the job pipeline as a page over the archive's read routes.
# Why it has no snapshot and why the proxy allowlist is exact:
# `docs/appflow-board.md`.
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
