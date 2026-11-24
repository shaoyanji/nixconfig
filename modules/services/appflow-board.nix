# appflow-board — the job pipeline as a page over the archive's routes.
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

  # One exact location per route, so the proxied surface is this list and not the
  # plugin's route table.
  proxyTo = name: ''
    proxy_pass ${cfg.upstream}/api/${name};
    proxy_set_header Host 127.0.0.1;
    proxy_http_version 1.1;
    add_header Cache-Control "no-store" always;
  '';

  # The write routes need one credential: `$appflow_write_ok` comes from the map
  # the sops template renders, and `return` inside `if` is the one `if` nginx
  # guarantees — the key itself never enters the store.
  writeGuard = ''
    if ($appflow_write_ok = 0) { return 403; }
  '';
in {
  options.services.appflowBoard = {
    enable = lib.mkEnableOption "the job pipeline board (delphi) — five reads plus the two write routes";

    port = lib.mkOption {
      type = lib.types.port;
      # 8094 is the media library, 8080 the archive API, 8461 its tailnet front.
      default = 8462;
      description = "Loopback port for the board. Nothing opens it in the firewall; the tailnet front is a portal mount.";
    };

    upstream = lib.mkOption {
      type = lib.types.str;
      default = "http://127.0.0.1:8080";
      description = "The archive API the board fronts. Five GET reads plus the two POST write routes are proxied; nothing else is reachable through this vhost.";
    };
  };

  config = lib.mkIf cfg.enable {
    # One shared bearer per the auth decision (AGENTS.nix
    # devin-lane-appflow-write-auth): the secret lives only under /run/secrets,
    # and the rendered map turns `Authorization: Bearer <key>` into a flag the
    # two write locations test. Reads stay open — the flag gates nothing else.
    sops.secrets."appflow-board-bearer" = {
      sopsFile = ../../modules/secrets.yaml;
      owner = "nginx";
      group = "nginx";
      mode = "0400";
      restartUnits = ["nginx.service"];
    };
    sops.templates."appflow-board-write-auth.conf" = {
      owner = "nginx";
      group = "nginx";
      mode = "0440";
      content = ''
        map $http_authorization $appflow_write_ok {
          default 0;
          "Bearer ${config.sops.placeholder."appflow-board-bearer"}" 1;
        }
      '';
    };

    services.nginx = {
      appendHttpConfig = ''
        include ${config.sops.templates."appflow-board-write-auth.conf".path};
      '';
      enable = true;
      virtualHosts."appflow-board" = {
        listen = [
          {
            addr = "127.0.0.1";
            inherit (cfg) port;
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
          # The two write routes: update status/stage/next_action by id, or
          # insert/update a full record. Bearer-gated, then POST through to the
          # same upstream — the vhost is a proxy, the SQL files own the write
          # contract.
          "= /api/application-update" = {
            extraConfig = writeGuard + proxyTo "application-update";
          };
          "= /api/application-upsert" = {
            extraConfig = writeGuard + proxyTo "application-upsert";
          };
        };
      };
    };
  };
}
