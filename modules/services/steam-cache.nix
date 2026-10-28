# steam-cache — LAN Steam content cache (Valve's own lancache hook).
#
# Split in two on purpose: the :80 front lives in frieren's always-on nginx and
# falls back to Valve, while the cache process owns the removable flash tier.
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.steamCache;

  backendConf = pkgs.writeText "steam-cache-nginx.conf" ''
    user nginx;
    worker_processes 2;
    error_log stderr warn;
    events { worker_connections 1024; }
    http {
      # /dev/stdout is not openable in this unit's namespace (measured: open()
      # failed 6: No such device or address), so access lines go to the journal.
      access_log syslog:server=unix:/dev/log,facility=local0,tag=steamcache;
      proxy_cache_path ${cfg.cacheDir} levels=1:2 keys_zone=steam:100m
        max_size=${cfg.maxSize} inactive=${cfg.inactive} use_temp_path=off;
      server {
        listen 127.0.0.1:${toString cfg.port};
        resolver ${cfg.resolver} valid=60s ipv6=off;
        location = /__health {
          return 200 "ok\n";
        }
        location / {
          proxy_pass http://$host$request_uri;
          proxy_set_header Host $host;
          proxy_http_version 1.1;
          proxy_cache steam;
          proxy_cache_key "$host$request_uri";
          proxy_cache_lock on;
          proxy_cache_valid 200 206 1d;
          proxy_cache_use_stale error timeout updating http_500 http_502 http_503 http_504;
          proxy_ignore_headers X-Accel-Expires Set-Cookie Vary Expires;
          add_header X-Steam-Cache $upstream_cache_status always;
        }
      }
    }
  '';
in {
  options.services.steamCache = {
    enable = lib.mkEnableOption "the LAN Steam content cache";

    port = lib.mkOption {
      type = lib.types.port;
      default = 8081;
      description = "Loopback port the cache backend listens on.";
    };

    cacheDir = lib.mkOption {
      type = lib.types.str;
      default = "/mnt/flash-cache/steam-cache";
      description = ''
        Cache root. Must live on the flash tier, not `/srv/data`: the spindle
        serves Jellyfin and the restic push, and 8 concurrent readers get
        236 MB/s here against 67 MB/s there.
      '';
    };

    requireMount = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = "/mnt/flash-cache";
      description = ''
        Mount point that must be mounted before the cache starts (null = no
        check). Without it, an unplugged stick leaves the cache writing into an
        empty directory on the root filesystem.
      '';
    };

    maxSize = lib.mkOption {
      type = lib.types.str;
      default = "70g";
      description = "Upper bound for the cache on disk.";
    };

    inactive = lib.mkOption {
      type = lib.types.str;
      default = "30d";
      description = "Evict an object after this long without a request.";
    };

    resolver = lib.mkOption {
      type = lib.types.str;
      default = "1.1.1.1";
      description = ''
        Resolver used to reach the real Valve CDN. Never the fleet resolver: it
        answers these hostnames with our own address, which would loop.
      '';
    };

    vhostName = lib.mkOption {
      type = lib.types.str;
      default = "steam-cache";
      description = "Attribute name of the front virtual host.";
    };

    serverName = lib.mkOption {
      type = lib.types.str;
      default = "~^.+[.]steamcontent[.]com$ steamcdn-a.akamaihd.net";
      description = ''
        Hosts Steam requests while caching: every `*.steamcontent.com` name the
        client is handed, plus the client installer CDN.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.steam-cache = {
      description = "LAN Steam content cache (nginx, flash tier)";
      after = ["network-online.target"];
      wants = ["network-online.target"];
      wantedBy = ["multi-user.target"];
      unitConfig.ConditionPathIsMountPoint = cfg.requireMount;
      serviceConfig = {
        Type = "simple";
        # Two entries, not one shell line: systemd word-splits ExecStartPre and
        # would hand `&&` to mkdir as a path (measured: `mkdir: cannot create
        # directory '.../bin/chown'`). Root is needed to bind and to chown.
        ExecStartPre = [
          "+${pkgs.coreutils}/bin/mkdir -p ${cfg.cacheDir}"
          "+${pkgs.coreutils}/bin/chown nginx:nginx ${cfg.cacheDir}"
        ];
        ExecStart = "${pkgs.nginx}/bin/nginx -c ${backendConf} -g 'daemon off;'";
        Restart = "on-failure";
        RestartSec = 5;
      };
    };

    # The front never depends on the stick: with the backend down its 502 is
    # re-fetched from Valve, so a pulled USB drive costs the cache, not the LAN.
    services.nginx.virtualHosts.${cfg.vhostName} = {
      inherit (cfg) serverName;
      listen = [
        {
          addr = "0.0.0.0";
          port = 80;
        }
        {
          addr = "[::]";
          port = 80;
        }
      ];
      extraConfig = ''
        error_page 502 504 = @valve;
      '';
      # No explicit Host header in either location: recommendedProxySettings
      # already sets it, and a second one makes nginx reject the upstream
      # request with 400 (measured: `400 Bad Request` from the cache itself).
      locations."/" = {
        proxyPass = "http://127.0.0.1:${toString cfg.port}";
        extraConfig = ''
          proxy_http_version 1.1;
          proxy_read_timeout 300s;
        '';
      };
      locations."@valve" = {
        proxyPass = "http://$host$request_uri";
        extraConfig = ''
          resolver ${cfg.resolver} valid=60s ipv6=off;
          proxy_http_version 1.1;
          proxy_read_timeout 300s;
        '';
      };
    };
  };
}
