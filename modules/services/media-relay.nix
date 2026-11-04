# media-relay — fetch YouTube over a fast uplink, serve H.264/AAC MP4 with Range.
#
# Why it exists: fetch where the peering is good, serve where the client is.
# delphi pulls a 10-minute 1080p video in 12.4 s (a gigabit) and serves it back
# over WireGuard at a measured 11.4 Mbit.
#
# Its ADVANTAGE OVER PULLING DIRECTLY IS NOT PROVEN, and the numbers that
# suggested one were contaminated: every home-side measurement on 2026-11-04 ran
# while a 20 GB download held the uplink at ~19-21 Mbit, so "Google gives this
# house 1.5-2.3 Mbit" was really "the line was full". The decisive experiment is
# one curl against googlevideo and one against this relay on a quiet line; until
# that exists, treat the throughput case as open and the value as packaging (one
# URL a client bookmarks, plus the frame-rate rule below).
#
# Two rules the format string encodes, and they are not preferences:
#   * vcodec^=avc1  — H.264. An iPad Air 1 on iOS 12 decodes nothing else, and
#                     the netbook's Gen8 iGPU has no VP9/AV1 engine.
#   * acodec^=mp4a  — AAC. Opus (format 251) is the default "bestaudio" and
#                     cannot play in an old Safari <video>.
#
# A third rule comes from measurement, not taste: the frame rate is capped at
# 30. On the netbook (Celeron N3060, Gen8 iGPU) 8 s of playback dropped 273
# frames of 1080p60, 64 with `profile=fast` and 100 with bilinear scaling — the
# box renders below 60 fps no matter how cheap the shader, so 1080p60 stutters
# there and no client setting fixes it. The same 1080p at 30 fps dropped 9.
# Height and rate are ceilings, not targets: `--height/--fps` raise them per
# fetch when the client is a TV, and the fps filter falls back to the uncapped
# chain rather than failing when a video has no ≤30 fps format.
#
# `-c copy` + `+faststart` means nothing is ever re-encoded: the fetch is a
# copy, and seeking over HTTP works because the moov atom is at the front.
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.media-relay;

  ytGet = pkgs.writeShellScriptBin "yt-get" ''
    set -eu

    max_height=${toString cfg.maxHeight}
    max_fps=${toString cfg.maxFps}
    url=""
    while [ "$#" -gt 0 ]; do
      case "$1" in
        --height) max_height="$2"; shift 2 ;;
        --fps) max_fps="$2"; shift 2 ;;
        -h | --help)
          echo "usage: yt-get [--height N] [--fps N] <url>"
          exit 0
          ;;
        -*)
          echo "yt-get: unknown option: $1" >&2
          exit 2
          ;;
        *)
          url="$1"
          shift
          ;;
      esac
    done
    if [ -z "$url" ]; then
      echo "usage: yt-get [--height N] [--fps N] <url>" >&2
      exit 2
    fi

    # A cookie jar is a credential a human provisioned, so it is checked rather
    # than assumed: without it a datacenter IP is refused at the player API
    # ("Sign in to confirm you're not a bot") and the failure looks like a
    # network problem instead of a missing login.
    cookie_flag=""
    if [ -n "${cfg.cookieFile}" ] && [ -r "${cfg.cookieFile}" ]; then
      cookie_flag="--cookies ${cfg.cookieFile}"
    elif [ "${toString cfg.requireCookies}" = "1" ]; then
      echo "yt-get: no readable cookie jar at ${cfg.cookieFile}" >&2
      echo "        YouTube refuses an anonymous player request from this IP." >&2
      echo "        Provision it (0600, owner ${cfg.user}) or set requireCookies = false." >&2
      exit 1
    fi

    export PATH="${pkgs.yt-dlp}/bin:${pkgs.ffmpeg}/bin:$PATH"

    id="$(yt-dlp $cookie_flag --no-playlist --no-warnings --print "%(id)s" "$url" | head -1)"
    if [ -z "$id" ]; then
      echo "yt-get: could not resolve a video id for $url" >&2
      exit 1
    fi

    # The id is the directory, so a re-fetch reuses it and a listing groups by
    # video rather than by whichever title YouTube was A/B-testing that hour.
    out="${cfg.mediaDir}/$id"
    mkdir -p "$out"

    format="bv*[vcodec^=avc1][height<=?$max_height][fps<=?$max_fps]+ba[acodec^=mp4a]"
    format="$format/bv*[vcodec^=avc1][height<=?$max_height]+ba[acodec^=mp4a]"
    format="$format/bv*[vcodec^=avc1][height<=?$max_height]+ba"
    format="$format/b[height<=?$max_height]"

    file="$(yt-dlp $cookie_flag --no-playlist --no-warnings --no-simulate \
      -f "$format" --merge-output-format mp4 \
      -o "$out/%(title).120B [%(id)s].%(ext)s" \
      --print after_move:filepath "$url" | tail -1)"

    if [ -z "$file" ] || [ ! -f "$file" ]; then
      echo "yt-get: yt-dlp produced no file" >&2
      exit 1
    fi

    # faststart is the difference between "plays" and "plays and can seek" in
    # Safari. `-c copy` keeps this a remux: seconds, no CPU spent on pixels.
    case "$file" in
      *.mp4)
        if ! ffmpeg -nostdin -loglevel error -y -i "$file" -c copy -movflags +faststart "$file.faststart.mp4"; then
          echo "yt-get: faststart remux failed; keeping the original" >&2
          rm -f "$file.faststart.mp4"
        else
          mv -f "$file.faststart.mp4" "$file"
        fi
        ;;
    esac

    rel="''${file#${cfg.mediaDir}/}"
    echo "${cfg.publicBase}/$rel"
  '';

  nginxPort = toString cfg.port;
in {
  options.services.media-relay = {
    enable = lib.mkEnableOption "YouTube fetch and range-serving relay (delphi)";

    port = lib.mkOption {
      type = lib.types.port;
      # 8093 is taken on delphi (a loopback python service), 8091 is the
      # decision engine; 8094 measured free 2026-11-04.
      default = 8094;
      description = "HTTP port for the library. Nothing opens it in the firewall: it is reachable over the tailnet only, which is what keeps the fleet's one internet-facing host from also being a media server.";
    };

    mediaDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/media-relay/library";
      description = "Where fetched videos live.";
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = "devji";
      description = "Owner of the library and the cookie jar.";
    };

    cookieFile = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/media-relay/cookies.txt";
      description = ''
        Netscape-format cookie jar for an authenticated YouTube session. A
        credential, so it is provisioned by hand at 0600 and never enters the
        store. Blank it out (`""`) to run without cookies.
      '';
    };

    requireCookies = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Fail instead of fetching anonymously. An anonymous request from a datacenter address is refused at the player API, so the fallback is a confusing error rather than a working download.";
    };

    maxHeight = lib.mkOption {
      type = lib.types.int;
      default = 1080;
      description = "Ceiling for the fetched stream. 1080p at ~5-8 Mbit fits the measured 11.4 Mbit delphi->home path; 4K does not.";
    };

    maxFps = lib.mkOption {
      type = lib.types.int;
      default = 30;
      description = ''
        Frame-rate ceiling, in frames per second. The weakest client decides the
        default: the netbook renders 1080p at ~40 fps and dropped 273 frames of
        1080p60 in 8 s but 9 of 1080p30. Raise per fetch with `yt-get --fps 60`
        when the file is destined for a TV.
      '';
    };

    retentionDays = lib.mkOption {
      type = lib.types.int;
      default = 14;
      description = "Delete files untouched for this many days. 200 GB of boot volume is shared with five services.";
    };

    publicBase = lib.mkOption {
      type = lib.types.str;
      default = "http://delphi:${nginxPort}";
      description = "URL prefix printed by `yt-get`, i.e. what a client bookmarks.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.cookieFile == "" || lib.hasPrefix "/" cfg.cookieFile;
        message = "services.media-relay.cookieFile must be an absolute path (or empty)";
      }
    ];

    environment.systemPackages = [ytGet pkgs.yt-dlp pkgs.ffmpeg];

    # Group left as `-` on purpose: delphi's devji has no group of its own
    # (primary gid 100 = users), and naming it made the rule fail with
    # "invalid group", which then left the nginx root missing.
    systemd.tmpfiles.rules = [
      "d ${cfg.mediaDir} 0755 ${cfg.user} - -"
      # Traversable, not 0750: nginx workers are not devji and cannot enter a
      # group-restricted parent, which turns every request into 403 while the
      # jar itself stays 0600.
      "d ${builtins.dirOf cfg.cookieFile} 0755 ${cfg.user} - -"
    ];

    # Range support is native to nginx; what is added is the listing a client
    # can actually browse on an iPad (plain HTML, no JS) and a cache header that
    # keeps a re-watch off the wire.
    services.nginx = {
      enable = true;
      virtualHosts."media-relay" = {
        listen = [
          {
            addr = "0.0.0.0";
            port = cfg.port;
          }
        ];
        root = cfg.mediaDir;
        locations."/" = {
          extraConfig = ''
            autoindex on;
            autoindex_exact_size off;
            autoindex_localtime on;
            add_header Cache-Control "public, max-age=86400";
            # nginx already emits `Accept-Ranges: bytes` for static files; an
            # explicit header here is a second copy of the same line.
          '';
        };
      };
    };

    systemd.services.media-relay-prune = {
      description = "Delete fetched videos untouched for ${toString cfg.retentionDays} days";
      path = [pkgs.findutils];
      serviceConfig.Type = "oneshot";
      script = ''
        find ${cfg.mediaDir} -type f -mtime +${toString cfg.retentionDays} -print -delete || true
        find ${cfg.mediaDir} -type d -empty -delete || true
      '';
    };

    systemd.timers.media-relay-prune = {
      wantedBy = ["timers.target"];
      timerConfig = {
        OnCalendar = "daily";
        Persistent = true;
      };
    };
  };
}
