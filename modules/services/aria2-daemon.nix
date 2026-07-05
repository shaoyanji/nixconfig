# aria2-daemon — network RPC download service with AriaNg web UI.
#
# Delegates the daemon lifecycle to the native nixpkgs `services.aria2`
# module and adds the nginx vhost for AriaNg + RPC reverse proxy.
#
# The RPC secret is loaded via systemd LoadCredential at runtime — never
# stored in the Nix store or command line.
#
# AriaNg is pulled as a pre-built release zip via fetchzip instead of
# building from source via npm (which is fragile and breaks frequently).
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.aria2-daemon;

  # Pre-built AriaNg static files — avoids npm build failures from nixpkgs.
  ariang = (import ../../lib/fetches-extra.nix {inherit pkgs;}).fetch "ariang";
in {
  options.services.aria2-daemon = {
    enable = lib.mkEnableOption "aria2 RPC download daemon";

    user = lib.mkOption {
      type = lib.types.str;
      default = "aria2";
      description = "System user for aria2 daemon";
    };

    downloadDir = lib.mkOption {
      type = lib.types.str;
      default = "/srv/data/downloads";
      description = "Where downloads are saved";
    };

    sessionFile = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/aria2/aria2.session";
      description = "Session file for resuming downloads";
    };

    rpcHost = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = "RPC listen host (expose via nginx)";
    };

    rpcPort = lib.mkOption {
      type = lib.types.port;
      default = 6800;
      description = "RPC listen port";
    };

    rpcSecretFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "Path to a file containing the RPC secret (loaded via systemd LoadCredential)";
    };

    btListenPort = lib.mkOption {
      type = lib.types.port;
      default = 51413;
      description = "BitTorrent DHT/listen port";
    };

    nginx.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Expose AriaNg + RPC proxy via nginx";
    };

    nginx.listenPort = lib.mkOption {
      type = lib.types.port;
      default = 8080;
      description = "Port for AriaNg web UI";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.rpcSecretFile != null;
        message = "services.aria2-daemon requires rpcSecretFile to be set (the native services.aria2 module mandates a secret file)";
      }
    ];

    # Delegate daemon lifecycle to the native nixpkgs module.
    services.aria2 = {
      enable = true;
      rpcSecretFile = cfg.rpcSecretFile;
      openPorts = false; # We manage firewall separately via networking.firewall.
      settings = {
        dir = cfg.downloadDir;
        "save-session" = cfg.sessionFile;
        "rpc-listen-port" = cfg.rpcPort;
        "listen-port" = [
          {
            from = cfg.btListenPort;
            to = cfg.btListenPort;
          }
        ];

        # Feature flags matching the original custom service.
        "enable-dht" = true;
        "enable-dht6" = true;
        "enable-peer-exchange" = true;
        "dht-listen-port" = cfg.btListenPort;

        # Peer/client impersonation.
        "peer-id-prefix" = "-TR2770-";
        "peer-agent" = "Transmission/2.77";
        "user-agent" = "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:56.0) Gecko/20100101 Firefox/56.0";

        # Download/performance tuning.
        continue = true;
        "max-concurrent-downloads" = 10;
        "max-connection-per-server" = 16;
        "min-split-size" = "10M";
        split = 5;
        "disk-cache" = "32M";
        "file-allocation" = "falloc";
        "save-session-interval" = 60;

        # Seeding behavior.
        "seed-ratio" = 0;
        "bt-hash-check-seed" = true;
        "bt-seed-unverified" = true;
        "max-upload-limit" = "50K";

        # RPC binding — localhost only, nginx reverse-proxies.
        "rpc-listen-all" = false;
        "rpc-allow-origin-all" = true;

        disable-ipv6 = true;
      };
    };

    # Nginx vhost: serves AriaNg static UI and reverse-proxies /jsonrpc.
    services.nginx = lib.mkIf cfg.nginx.enable {
      enable = true;
      virtualHosts.aria = {
        listen = [
          {
            addr = "0.0.0.0";
            port = cfg.nginx.listenPort;
          }
        ];
        serverName = "_";
        root = ariang;
        locations."/" = {
          tryFiles = "$uri $uri/ /index.html";
        };
        locations."/jsonrpc" = {
          proxyPass = "http://${cfg.rpcHost}:${builtins.toString cfg.rpcPort}/jsonrpc";
          proxyWebsockets = true;
          extraConfig = ''
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header Host $host;
          '';
        };
      };
    };
  };
}
