{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.tailnetForwardProxy;

  runner = pkgs.writeShellScript "tailnet-forward-proxy" ''
        set -eu
        ip=""
        for _ in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30; do
          ip="$(${pkgs.tailscale}/bin/tailscale ip -4 2>/dev/null | head -n 1 || true)"
          case "$ip" in
            100.*) break ;;
            *) ip=""; sleep 1 ;;
          esac
        done
        if [ -z "$ip" ]; then
          echo "tailnet-forward-proxy: no tailnet IPv4 address" >&2
          exit 1
        fi
        conf="$RUNTIME_DIRECTORY/tinyproxy.conf"
    {
      printf 'Port ${toString cfg.port}\n'
      printf 'Listen %s\n' "$ip"
      printf 'Timeout ${toString cfg.timeoutSeconds}\n'
      printf 'LogLevel Error\n'
      printf 'MaxClients ${toString cfg.maxClients}\n'
      printf 'DisableViaHeader Yes\n'
      printf 'Allow 100.64.0.0/10\n'
      printf 'ConnectPort 443\n'
    } >"$conf"
    exec ${pkgs.tinyproxy}/bin/tinyproxy -d -c "$conf"
  '';
in {
  options.services.tailnetForwardProxy = {
    enable = lib.mkEnableOption "a forward proxy bound to the tailnet address";

    port = lib.mkOption {
      type = lib.types.port;
      default = 8471;
      description = "Port tinyproxy binds on the host's tailnet IPv4 address.";
    };

    timeoutSeconds = lib.mkOption {
      type = lib.types.ints.positive;
      default = 60;
      description = "Idle connection timeout passed to tinyproxy.";
    };

    maxClients = lib.mkOption {
      type = lib.types.ints.positive;
      default = 16;
      description = "Maximum simultaneous proxy clients.";
    };

    memoryMax = lib.mkOption {
      type = lib.types.str;
      default = "64M";
      description = "systemd MemoryMax for the proxy.";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.tailnet-forward-proxy = {
      description = "Tailnet-bound forward proxy";
      wantedBy = ["multi-user.target"];
      wants = ["network-online.target" "tailscaled.service"];
      after = ["network-online.target" "tailscaled.service"];
      unitConfig.X-Fleet-Role = "daemon";
      serviceConfig = {
        Type = "simple";
        DynamicUser = true;
        RuntimeDirectory = "tailnet-forward-proxy";
        ExecStart = runner;
        Restart = "always";
        RestartSec = 3;
        TimeoutStopSec = 10;
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        NoNewPrivileges = true;
        RestrictAddressFamilies = ["AF_INET" "AF_INET6" "AF_UNIX"];
        MemoryMax = cfg.memoryMax;
      };
    };
  };
}
