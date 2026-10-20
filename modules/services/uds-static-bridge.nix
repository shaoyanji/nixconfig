# Declarative Zero-TCP Static Documentation Bridge via UNIX Domain Sockets (EXP-024).
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.udsStaticBridge;
  # Same site, same evaluated inputs as the HTTP vhost: the compiled registry and
  # this host's own name, so the served bytes cannot disagree with nginx's copy.
  akiDocs = import ../../lib/aki-site.nix {
    inherit pkgs;
    inventory = config.fleet.inventory;
    host = config.networking.hostName;
  };

  # Same cache policy the HTTP vhost uses (modules/config/nginx-static-cache.nix):
  # one store path, one set of cache directives.
  staticCache = import ../config/nginx-static-cache.nix;
in {
  options.services.udsStaticBridge = {
    enable = lib.mkEnableOption "declarative zero-TCP static documentation bridge via UNIX domain sockets";

    socketDir = lib.mkOption {
      type = lib.types.str;
      default = "/run/uds-docs";
      description = "Runtime directory where the UNIX domain socket is placed.";
    };

    socketPath = lib.mkOption {
      type = lib.types.str;
      default = "/run/uds-docs/docs.sock";
      description = "Filesystem path for the UNIX domain socket listener.";
    };

    root = lib.mkOption {
      type = lib.types.path;
      default = akiDocs;
      description = "Static site directory to serve over the UNIX domain socket.";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.tmpfiles.rules = [
      "d ${cfg.socketDir} 0775 nginx users -"
    ];

    services.nginx = {
      enable = true;
      virtualHosts."uds-docs" = {
        listen = [
          {
            addr = "unix:${cfg.socketPath}";
            extraParameters = ["backlog=1024"];
          }
        ];
        locations."/" = {
          inherit (cfg) root;
          extraConfig =
            staticCache.html
            + ''
              # Zero-TCP IPC headers (bridge-specific, so kept next to the link)
              add_header X-Bridge-Transport "UNIX-Domain-Socket" always;
              add_header X-Bridge-Security "POSIX-DAC-Isolated" always;
            '';
        };

        # Content-hashed immutable static assets (Gap B).
        #
        # Eight explicit hex classes instead of the `{8}` quantifier: a brace in
        # a location key is emitted by the config generator split across lines
        # (`location ~* \.[a-f0-9] { / 8 / }`), nginx then reports
        # `unexpected "}"`, and this unit's vhost takes the whole server down
        # with it. Same match, one line. See the twin fix in
        # hosts/frieren/reverse-proxy.nix.
        locations."~* \\.[0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]\\.(?:css|js)$" = {
          inherit (cfg) root;
          extraConfig = staticCache.hashed;
        };

        # Live mainframe telemetry (Gap A)
        locations."= /data/live.json" = {
          alias = "${cfg.socketDir}/live.json";
          extraConfig = ''
            default_type application/json;
            add_header Cache-Control "no-cache, no-store, must-revalidate" always;
          '';
        };
      };
    };

    # Zero-overhead local mainframe telemetry emitter (Gap A)
    systemd.services.uds-docs-telemetry = {
      description = "Zero-overhead local mainframe telemetry emitter for UDS docs";
      path = with pkgs; [coreutils gnugrep gawk jq systemd];
      serviceConfig = {
        Type = "oneshot";
        User = "nginx";
        Group = "users";
      };
      script = ''
        UPTIME=$(uptime -p 2>/dev/null || echo "up")
        LOAD=$(cut -d' ' -f1-3 /proc/loadavg 2>/dev/null || echo "0.0")
        MEM_TOTAL=$(awk '/MemTotal/ {print int($2/1024)}' /proc/meminfo 2>/dev/null || echo "0")
        MEM_AVAIL=$(awk '/MemAvailable/ {print int($2/1024)}' /proc/meminfo 2>/dev/null || echo "0")
        MEM_USED=$((MEM_TOTAL - MEM_AVAIL))
        CURRENT_GEN=$(readlink -f /nix/var/nix/profiles/system | grep -oE '[0-9]+$' || echo "unknown")

        cat <<EOF > ${cfg.socketDir}/live.json.tmp
        {
          "hostname": "${config.networking.hostName}",
          "generation": "$CURRENT_GEN",
          "uptime": "$UPTIME",
          "load": "$LOAD",
          "memory": {
            "used_mb": $MEM_USED,
            "total_mb": $MEM_TOTAL
          },
          "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
        }
        EOF
        mv -f ${cfg.socketDir}/live.json.tmp ${cfg.socketDir}/live.json
      '';
    };

    systemd.timers.uds-docs-telemetry = {
      description = "Periodic update timer for UDS docs live telemetry";
      wantedBy = ["timers.target"];
      timerConfig = {
        OnBootSec = "30s";
        OnUnitActiveSec = "2m";
      };
    };
  };
}
