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

  # Where the cache front answers on the LAN. A prefill that pins the detection
  # name to loopback would pass detection and still not store what a client
  # fetches, so the default is the address clients use: this host's lan_ip from
  # the compiled registry.
  lanIp =
    lib.attrByPath ["hosts" config.networking.hostName "network" "lan_ip"] "127.0.0.1"
    config.fleet.inventory;
  pinAddress =
    if cfg.prefill.pinAddress != null
    then cfg.prefill.pinAddress
    else lanIp;
  pinResolver =
    if cfg.prefill.pinResolver != null
    then cfg.prefill.pinResolver
    else pinAddress;

  # The prefill's DNS pin as store paths: nsswitch, host.conf, hosts, resolv.conf
  # and an empty nscd directory. Being closure paths is the point — the unit
  # cannot pick up a stale copy from /tmp, and the pin is reviewed with the rest
  # of the config instead of in a shell script in a state directory.
  pinFiles = {
    nsswitch = pkgs.writeText "steam-prefill-nsswitch.conf" ''
      hosts: files dns
    '';
    hostConf = pkgs.writeText "steam-prefill-host.conf" ''
      multi off
    '';
    hosts = pkgs.writeText "steam-prefill-hosts" ''
      127.0.0.1 localhost
      ::1 localhost
      ${pinAddress} lancache.steamcontent.com
    '';
    resolv = pkgs.writeText "steam-prefill-resolv.conf" ''
      nameserver ${pinResolver}
      options timeout:2 attempts:2 rotate
    '';
    nscd = pkgs.runCommandLocal "steam-prefill-empty-nscd" {} "mkdir -p $out";
  };

  # Per-run measurement. The prefill's own progress line counts chunks across the
  # whole selection and serves the new chunks first, so it sat at 18 % for 46
  # minutes while doing every byte of real work and finished the rest in 8:29 off
  # the cache (2026-10-29). Two numbers are the honest instrument instead:
  #
  #   growth — apparent bytes in the cache tree, before vs after the run;
  #   wan    — the cache backend's IPIngressBytes delta, i.e. Valve's reply
  #            bodies. The front is local, so LAN hits land on the backend's
  #            egress, not its ingress: this cannot mistake a cache hit for
  #            bandwidth spent. (The prefill unit's own counter cannot do this —
  #            it reported 34 GB incoming on a run that stored nothing, all of
  #            it from this host.)
  #
  # Both live in a root unit because the cache tree is `0700 nginx` and the
  # prefill runs as its own user. The baseline is a separate unit rather than an
  # ExecStartPre for the same reason: systemd has no per-command user.
  recorder = pkgs.writeShellApplication {
    name = "steam-prefill-record";
    runtimeInputs = with pkgs; [coreutils jq systemd];
    text = ''
      set -uo pipefail

      phase="$1"
      baseline="${cfg.prefill.stateDir}/run-baseline.json"
      ledger="${cfg.prefill.ledger}"
      cache="${cfg.cacheDir}"
      # A baseline older than this is not this run's; see the record branch.
      baseline_max_age=3600

      now() { date -u +%Y-%m-%dT%H:%M:%SZ; }

      # Null rather than 0 when the tree is unreadable: an absent mount is "not
      # measured", and 0 would read as "the cache did not grow".
      cache_bytes() {
        if [ -d "$1" ]; then
          du -sb --apparent-size "$1" 2>/dev/null | cut -f1 || printf 'null'
        else
          printf 'null'
        fi
      }

      wan_bytes() {
        local v
        v="$(systemctl show steam-cache.service -p IPIngressBytes --value 2>/dev/null || true)"
        # An empty match is written as two double quotes, not the usual pair of
        # single ones: in a Nix indented string that pair starts an escape and
        # the file stops parsing.
        case "$v" in
          "" | *[!0-9]*) printf 'null' ;;
          *) printf '%s' "$v" ;;
        esac
      }

      if [ "$phase" = baseline ]; then
        mkdir -p "$(dirname "$baseline")"
        jq -n \
          --arg ts "$(now)" \
          --argjson cache "$(cache_bytes "$cache")" \
          --argjson wan "$(wan_bytes)" \
          '{ts: $ts, cache_bytes: $cache, wan_bytes: $wan}' > "$baseline"
        exit 0
      fi

      recorded=true
      reason=""
      before=null
      before_wan=null
      age=null
      if [ -r "$baseline" ]; then
        b_ts="$(jq -r '.ts // empty' "$baseline" 2>/dev/null || true)"
        before="$(jq -c '.cache_bytes // null' "$baseline" 2>/dev/null || printf 'null')"
        before_wan="$(jq -c '.wan_bytes // null' "$baseline" 2>/dev/null || printf 'null')"
        if [ -n "$b_ts" ] && b_epoch="$(date -d "$b_ts" +%s 2>/dev/null)"; then
          age=$(( $(date +%s) - b_epoch ))
        fi
      else
        recorded=false
        reason="no-baseline"
      fi
      # The fill is skipped (mount gone, cache not answering) after a baseline was
      # written; attributing the gap to this run would charge a night of client
      # downloads to it.
      if [ "$recorded" = true ] && { [ "$age" = null ] || [ "$age" -gt "$baseline_max_age" ]; }; then
        recorded=false
        reason="stale-baseline"
      fi

      after=null
      after_wan=null
      if [ "$recorded" = true ]; then
        after="$(cache_bytes "$cache")"
        after_wan="$(wan_bytes)"
      fi

      result="$(systemctl show steam-prefill.service -p Result --value 2>/dev/null || true)"
      status="$(systemctl show steam-prefill.service -p ExecMainStatus --value 2>/dev/null || true)"
      host="$(cut -d. -f1 /etc/hostname)"

      mkdir -p "$(dirname "$ledger")"
      jq -cn \
        --arg ts "$(now)" \
        --arg host "$host" \
        --arg result "''${result:-unknown}" \
        --arg status "$status" \
        --arg reason "$reason" \
        --argjson recorded "$recorded" \
        --argjson age "$age" \
        --argjson before "$before" \
        --argjson after "$after" \
        --argjson before_wan "$before_wan" \
        --argjson after_wan "$after_wan" \
        --argjson oses '${builtins.toJSON cfg.prefill.oses}' \
        '{schema: 1, ts: $ts, host: $host, recorded: $recorded, reason: $reason,
          result: $result, exit_status: ($status | if test("^[0-9]+$") then tonumber else null end),
          oses: $oses, baseline_age_s: $age,
          cache_bytes_before: $before, cache_bytes_after: $after,
          cache_growth_bytes:
            (if $before == null or $after == null then null else $after - $before end),
          wan_bytes:
            (if $before_wan == null or $after_wan == null or $after_wan < $before_wan then null
             else $after_wan - $before_wan end),
          wan_counter_reset: ($before_wan != null and $after_wan != null and $after_wan < $before_wan)}' \
        >> "$ledger"
      tail -n ${toString cfg.prefill.ledgerMaxLines} "$ledger" > "$ledger.tmp"
      mv "$ledger.tmp" "$ledger"
    '';
  };

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

      oses = lib.mkOption {
        type = lib.types.listOf (
          lib.types.enum [
            "windows"
            "linux"
            "macos"
          ]
        );
        default = ["windows"];
        description = ''
          Platform depots to prefill, cheapest first in the order listed.

          `--os` takes several values in one invocation (verified on 3.6.1). The
          total it prints is the manifest size of the selection, not what the
          run will transfer: Dota 2 reports 33.42 GiB for `linux` and 33.72 GiB
          for `linux windows`, while adding the second platform to an already
          filled cache moved 7.7 GB (measured 2026-10-29: cache 45 -> 53 GB) —
          shared content chunks, distinct platform depots. Leave `macos` out
          unless a Mac plays here: there is no client for it, so its depots are
          pure cache pressure.
        '';
      };

      ledger = lib.mkOption {
        type = lib.types.str;
        default = "/var/lib/steam-prefill/runs.jsonl";
        description = ''
          Append-only record of prefill runs, one JSON object per line: cache
          bytes before/after, growth, and the bytes the cache backend pulled
          from Valve. The nightly progress percentage is not evidence of
          anything (it serves new chunks first), so this is what a fill is
          judged by. Point a host's {option}`services.fleetSentinel.prefillRuns`
          at the same path to surface the last run in `status.json`.
        '';
      };

      ledgerMaxLines = lib.mkOption {
        type = lib.types.ints.positive;
        default = 1000;
        description = ''
          Rotate the run ledger to this many lines. A nightly job reaches 1000
          entries in under three years; the file stays small enough to read
          whole.
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

      pin = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = ''
          Point `lancache.steamcontent.com` at this host for the prefill process
          only, through a private mount namespace.

          SteamPrefill refuses to start unless that name resolves to a private
          address (`LancacheNotFoundException`), and the fleet resolver answers
          it publicly. The record that would fix it globally —
          `address=/steamcontent.com/` — takes the whole zone, so it also points
          Steam's matchmaking at this host; with it on, a Dota 2 match could not
          be accepted (2026-10-28). The pin therefore must never outlive the
          process, which is exactly what a unit-scoped namespace gives: nothing
          on the host changes, and LAN DNS keeps resolving publicly.
        '';
      };

      pinAddress = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = ''
          Address the pinned name resolves to. Null means this host's
          {option}`network.lan_ip` from the compiled inventory: a LAN client
          asking for the name must land on the same front the prefill does.
        '';
      };

      pinResolver = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = ''
          Resolver the prefill uses for every other lookup. Null means
          {option}`pinAddress` — the fleet resolver, deliberately: detection
          reverse-resolves the cache address, and a public resolver NXDOMAINs a
          LAN PTR. Never a public resolver, never empty.
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

    # The unit exists whenever the cache does, and `prefill.enable` only arms
    # the timer. A fill is then one `systemctl start steam-prefill` that uses
    # this recipe — the alternative was a hand-kept script in the state dir,
    # which is the one copy nobody reviews and every host would restate.
    systemd.services.steam-prefill = lib.mkIf cfg.enable {
      description = "SteamPrefill: fill the LAN Steam cache";
      after = [
        "network-online.target"
        "steam-cache.service"
        "steam-prefill-baseline.service"
      ];
      wants = [
        "network-online.target"
        "steam-cache.service"
        "steam-prefill-baseline.service"
        "steam-prefill-record.service"
      ];
      # The record unit runs after this one, so it measures the run that just
      # ended instead of racing it. Both are pulled in by the same transaction
      # (a timer or a hand-started `systemctl start steam-prefill`), so an ad-hoc
      # fill is measured exactly like the nightly one.
      before = ["steam-prefill-record.service"];
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
        # The DNS pin, as mounts rather than a script: systemd puts the unit in
        # its own mount namespace, so a prefill that crashes or is killed cannot
        # leave the host resolving this name `address=`-style. Four files, each
        # one a trap verified by removing it and watching the fill fail:
        #   nsswitch — the host lists `resolve` before `files dns`, so a hosts
        #              entry is otherwise never read;
        #   host.conf — `multi off`, or glibc merges the public AAAA/A that DNS
        #              returns with the pinned IPv4 and the client connects to
        #              the public address (a 33 GiB download that stores nothing);
        #   hosts     — the pin itself;
        #   nscd      — an empty dir over /var/run/nscd, because nsncd answers
        #              from its own cache and /etc/hosts would never be consulted.
        PrivateMounts = true;
        BindReadOnlyPaths = lib.optionals cfg.prefill.pin [
          "${pinFiles.nsswitch}:/etc/nsswitch.conf"
          "${pinFiles.hostConf}:/etc/host.conf"
          "${pinFiles.hosts}:/etc/hosts"
          "${pinFiles.resolv}:/etc/resolv.conf"
          "${pinFiles.nscd}:/var/run/nscd"
        ];
        # Belt and braces with the Condition above: a cache that is up but not
        # answering must not turn a prefill into a plain internet download.
        ExecCondition = "${pkgs.curl}/bin/curl -fsS -m 5 http://127.0.0.1:${toString cfg.port}/__health";
        ExecStart = "${pkgs.steam-lancache-prefill}/bin/SteamPrefill prefill --no-ansi --os ${lib.concatStringsSep " " cfg.prefill.oses}";
        # A oneshot's default start timeout is 90 s, which would kill every run
        # mid-download, and `RuntimeMaxSec` is ignored for oneshot (measured:
        # "RuntimeMaxSec= has no effect in combination with Type=oneshot"), so
        # the window itself is the start timeout.
        TimeoutStartSec = cfg.prefill.maxRuntime;
        # The flash tier is a USB BOT device with no NCQ: a prefill writing into
        # it must yield to Jellyfin reads rather than queue in front of them.
        Nice = 19;
        IOSchedulingClass = "best-effort";
        IOSchedulingPriority = 7;
      };
    };

    # --- the two halves of a measurement -------------------------------------
    # Root, unlike the fill itself: the cache tree is `0700 nginx`, so the
    # account SteamPrefill runs as cannot size it. Same mount condition as the
    # fill — with the stick out there is nothing to measure.
    systemd.services.steam-prefill-baseline = lib.mkIf cfg.enable {
      description = "Steam cache: size the cache before a prefill";
      unitConfig.ConditionPathIsMountPoint = cfg.requireMount;
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${recorder}/bin/steam-prefill-record baseline";
        ProtectSystem = "strict";
        ReadWritePaths = [cfg.prefill.stateDir];
        ProtectHome = true;
        PrivateTmp = true;
        NoNewPrivileges = true;
      };
    };

    systemd.services.steam-prefill-record = lib.mkIf cfg.enable {
      description = "Steam cache: record what the prefill moved";
      # `After` only: the record must run whether the fill succeeded, failed or
      # was skipped by its Conditions. A silent skip is a fact worth recording.
      after = ["steam-prefill.service"];
      unitConfig.ConditionPathIsMountPoint = cfg.requireMount;
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${recorder}/bin/steam-prefill-record record";
        ProtectSystem = "strict";
        ReadWritePaths = [
          cfg.prefill.stateDir
          (builtins.dirOf cfg.prefill.ledger)
        ];
        ProtectHome = true;
        PrivateTmp = true;
        NoNewPrivileges = true;
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
      # SteamPrefill (and every lancache client) proves a cache is here by this
      # path, so it must answer on the front itself rather than through the
      # backend — the backend would forward it to Valve, which 403s (measured).
      # `X-LanCache-Processed-By` is the acceptance criterion, not the status:
      # a 200 without it is rejected (measured, SteamPrefill 3.6.1).
      locations."= /lancache-heartbeat" = {
        return = "200 \"OK\"";
        extraConfig = ''
          add_header X-LanCache-Processed-By "frieren" always;
        '';
      };
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
