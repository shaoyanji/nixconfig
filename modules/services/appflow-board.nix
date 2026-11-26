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

  # One exact location per route, so the proxied surface is these two lists and
  # not the plugin's route table: reads plus, gated, the two writes — update
  # status/stage/next_action by id, or insert/update a full record.
  readRoutes = ["applications" "application-pipeline" "application-get" "applications-discovered" "application-mail"];
  writeRoutes = ["application-update" "application-upsert"];

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

  # The proxy boilerplate is the same for every route; only the guard differs.
  mkApiLocation = guard: name:
    lib.nameValuePair "= /api/${name}" {extraConfig = guard + proxyTo name;};
in {
  options.services.appflowBoard = {
    enable = lib.mkEnableOption "the job pipeline board (delphi) — five reads plus the two write routes";

    port = lib.mkOption {
      type = lib.types.port;
      # 8080 is the archive API; it is loopback-only, so this board is its only
      # tailnet surface (the appflow portal mount on 8463).
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
    # Every proxied name must be an endpoint the plugin actually publishes:
    # `/api/applications` 404'd on the live vhost while the file sat in this
    # repo — the deployed npgsqlrest was built from a tree that lacked it. A
    # route without a .sql file fails the host eval now, not a request later.
    assertions =
      map (name: {
        assertion = builtins.pathExists (../plugins/appflow/sql + "/${name}.sql");
        message = "appflow-board proxies /api/${name} but modules/plugins/appflow/sql/${name}.sql does not exist";
      }) (readRoutes
        ++ writeRoutes);

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
        locations =
          # The static-UI pair is the same shape the media library serves
          # (modules/config/nginx-static-ui.nix); the board adds a no-store on
          # the page itself plus its proxied routes.
          lib.recursiveUpdate (import ../config/nginx-static-ui.nix page) {
            "= /index.html".extraConfig = ''
              add_header Cache-Control "no-store";
            '';
          }
          // builtins.listToAttrs (map (mkApiLocation "") readRoutes)
          // builtins.listToAttrs (map (mkApiLocation writeGuard) writeRoutes);
      };
    };
  };
}
