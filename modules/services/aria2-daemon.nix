# aria2-daemon — network RPC download service with AriaNg web UI.
#
# Runs aria2c as a systemd service with RPC enabled, stores downloads
# on the NAS data volume, and exposes the RPC endpoint + AriaNg web UI
# through nginx.
#
# The RPC secret is loaded from an EnvironmentFile at runtime — never
# stored in the Nix store or command line.
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.aria2-daemon;
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
      description = "EnvironmentFile containing RPC_SECRET=...";
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

    nginx.domain = lib.mkOption {
      type = lib.types.str;
      default = "aria.local";
      description = "Domain for the AriaNg web UI";
    };
  };

  config = lib.mkIf cfg.enable {
    users.users.${cfg.user} = {
      isSystemUser = true;
      group = cfg.user;
      home = cfg.downloadDir;
      createHome = true;
    };

    users.groups.${cfg.user} = {};

    systemd.tmpfiles.rules = [
      "d ${cfg.downloadDir} 0755 ${cfg.user} ${cfg.user} -"
      "f ${cfg.sessionFile} 0644 ${cfg.user} ${cfg.user}"
    ];

    systemd.services.aria2-daemon = {
      description = "aria2 RPC download daemon";
      after = ["network.target"];
      wantedBy = ["multi-user.target"];

      serviceConfig = {
        Type = "exec";
        User = cfg.user;
        Group = cfg.user;
        Restart = "on-failure";
        RestartSec = 10;
        StateDirectory = "aria2";
        StateDirectoryMode = "0755";
        ProtectHome = true;
        ProtectSystem = "strict";
        ReadWritePaths = [cfg.downloadDir (dirOf cfg.sessionFile)];
        PrivateTmp = true;
        NoNewPrivileges = true;

        # Inject RPC secret from file at runtime, never on the command line.
        EnvironmentFile = lib.mkIf (cfg.rpcSecretFile != null) cfg.rpcSecretFile;
        ExecStart = let
          flags = lib.cli.toGNUCommandLineShell {} {
            enable-rpc = true;
            "rpc-listen-port" = cfg.rpcPort;
            "rpc-listen-all" = false;
            "rpc-allow-origin-all" = true;
            "listen-port" = cfg.btListenPort;
            "dht-listen-port" = cfg.btListenPort;
            enable-dht = true;
            enable-dht6 = true;
            enable-peer-exchange = true;
            "peer-id-prefix" = "-TR2770-";
            "peer-agent" = "Transmission/2.77";
            "user-agent" = "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:56.0) Gecko/20100101 Firefox/56.0";
            continue = true;
            "max-concurrent-downloads" = 10;
            "max-connection-per-server" = 16;
            "min-split-size" = "10M";
            split = 5;
            "disk-cache" = "32M";
            "file-allocation" = "falloc";
            "save-session-interval" = 60;
            "input-file" = cfg.sessionFile;
            "save-session" = cfg.sessionFile;
            dir = cfg.downloadDir;
            "seed-ratio" = 0;
            "bt-hash-check-seed" = true;
            "bt-seed-unverified" = true;
            "max-upload-limit" = "50K";
            disable-ipv6 = true;
          };
          secretFlag = lib.optionalString (cfg.rpcSecretFile != null) '' --rpc-secret="$RPC_SECRET"'';
        in "${pkgs.bash}/bin/bash -c 'exec ${pkgs.aria2}/bin/aria2c ${flags}${secretFlag}'";
    };

    services.nginx = lib.mkIf cfg.nginx.enable {
      enable = true;
      virtualHosts.${cfg.nginx.domain} = {
        locations."/" = {
          root = pkgs.ariang;
          index = "index.html";
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
