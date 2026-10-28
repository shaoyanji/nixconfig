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
      default = "100g";
      description = ''
        Upper bound for the cache on disk. Set it above the largest single
        install: below that, LRU eviction removes chunks of the build a client
        is still downloading, and it re-fetches what it just fetched.
      '';
    };

    inactive = lib.mkOption {
      type = lib.types.str;
      default = "30d";
      description = "Evict an object after this long without a request.";
    };

    dnsOverride = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Point `*.steamcontent.com` and the client-installer CDN at this host in
        the fleet resolver. Off by default and not the same question as `enable`:
        the cache serves anyone who asks it by name, while the override
        *intercepts* the client. An `address=/steamcontent.com/` record is the
        whole zone, so it also takes the names Steam uses for matchmaking —
        Dota 2 refused to accept a match on 2026-10-28 while this was on.
      '';
    };

    prefill = {
      enable = lib.mkEnableOption "the nightly SteamPrefill run";

      calendar = lib.mkOption {
        type = lib.types.str;
        default = "02:00";
        description = ''
          When to fill the cache from the internet. Off-peak by design: a
          prefill is the one job here that spends WAN bandwidth, so it must not
          run while the line is being used.
        '';
      };

      maxRuntime = lib.mkOption {
        type = lib.types.str;
        default = "5h";
        description = ''
          Cap on one run. Prefill resumes where it stopped, so a window that
          closes early costs time, not progress — and a stuck run cannot still
          be pulling at breakfast.
        '';
      };

      os = lib.mkOption {
        type = lib.types.str;
        default = "windows";
        description = ''
          Platform depots to prefill (`windows`, `linux`, `macos`). Windows is
          what most clients here are; add `linux` when a Steam Deck should be
          served too, at the cost of a second depot set per title.
        '';
      };

      user = lib.mkOption {
        type = lib.types.str;
        default = "devji";
        description = ''
          Account the job runs as. SteamPrefill needs a Steam login, and the
          token it saves is per-user, so this must be the account that ran the
          one-time `select-apps`.
        '';
      };

      stateDir = lib.mkOption {
        type = lib.types.str;
        default = "/var/lib/steam-prefill";
        description = ''
          Working directory. nixpkgs patches SteamPrefill to keep `Config/` in
          the current directory (upstream keeps it beside the binary, which is
          read-only in the store), so the app list and the Steam token live
          here and must be writable.
        '';
      };
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

    # --- nightly prefill -----------------------------------------------------
    # The cache only fills on demand, so a title nothing has asked for yet is
    # empty when the first client wants it. Prefill fetches the selected apps
    # through this cache at 02:00, when the line is idle, instead of on the day
    # a client happens to install.
    systemd.tmpfiles.rules = lib.optionals cfg.prefill.enable [
      "d ${cfg.prefill.stateDir} 0700 ${cfg.prefill.user} - -"
    ];

    systemd.services.steam-prefill = lib.mkIf cfg.prefill.enable {
      description = "SteamPrefill: fill the LAN Steam cache off-peak";
      after = [
        "network-online.target"
        "steam-cache.service"
      ];
      wants = [
        "network-online.target"
        "steam-cache.service"
      ];
      unitConfig = {
        # A prefill through a missing cache would download from Valve at full
        # speed and store nothing: the front falls back by design. Both the
        # mount and the backend's health answer have to be true first.
        ConditionPathIsMountPoint = cfg.requireMount;
        # Written only by a successful one-time `select-apps`, which also saves
        # the Steam token — the honest "is this configured yet" marker.
        ConditionPathExists = "${cfg.prefill.stateDir}/Config/selectedAppsToPrefill.json";
      };
      serviceConfig = {
        Type = "oneshot";
        User = cfg.prefill.user;
        WorkingDirectory = cfg.prefill.stateDir;
        # Belt and braces with the Condition above: a cache that is up but not
        # answering must not turn a prefill into a plain internet download.
        ExecCondition = "${pkgs.curl}/bin/curl -fsS -m 5 http://127.0.0.1:${toString cfg.port}/__health";
        ExecStart = "${pkgs.steam-lancache-prefill}/bin/SteamPrefill prefill --no-ansi --os ${cfg.prefill.os}";
        # A oneshot's default start timeout is 90 s, which would kill every run
        # mid-download; the wall clock is bounded by maxRuntime instead.
        TimeoutStartSec = "infinity";
        RuntimeMaxSec = cfg.prefill.maxRuntime;
        # The flash tier is a USB BOT device with no NCQ: a prefill writing into
        # it must yield to Jellyfin reads rather than queue in front of them.
        Nice = 19;
        IOSchedulingClass = "best-effort";
        IOSchedulingPriority = 7;
      };
    };

    systemd.timers.steam-prefill = lib.mkIf cfg.prefill.enable {
      description = "Nightly SteamPrefill window";
      wantedBy = ["timers.target"];
      timerConfig = {
        OnCalendar = cfg.prefill.calendar;
        Unit = "steam-prefill.service";
        RandomizedDelaySec = "5m";
        # Not persistent: a window missed because the host was down must be
        # skipped, not fired at 10:00 on the next boot where it would eat the
        # line the whole day.
        Persistent = false;
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
