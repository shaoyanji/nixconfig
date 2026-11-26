# media-relay — fetch YouTube on delphi's uplink, serve H.264/AAC MP4 with Range.
# Why it exists, what is still unproven, and the three format rules it encodes:
# `docs/media-relay.md`.
{
  config,
  lib,
  pkgs,
  self,
  systemdJobs,
  ...
}: let
  cfg = config.services.media-relay;

  # `.#cacheRegistry` is the one home for the edge URL.
  edgeUrl = self.cacheRegistry.caches.edge.url;

  # scripts/media-relay/r2-env.sh — the credential, read at run time.
  r2Env = pkgs.writeTextFile {
    name = "media-relay-r2-env.sh";
    text = builtins.readFile ../../scripts/media-relay/r2-env.sh;
    executable = true;
  };

  # The cookie jar is a credential a human provisioned, and both scripts read it
  # through this one fragment: a search that forgot it meets the consent page
  # while a fetch from the same session works, which reads as a YouTube bug.
  cookieFlag = ''
    cookie_flag=""
    if [ -n "${cfg.cookieFile}" ] && [ -r "${cfg.cookieFile}" ]; then
      cookie_flag="--cookies ${cfg.cookieFile}"
    fi
  '';

  ytGet = pkgs.writeShellScriptBin "yt-get" ''
    set -eu

    usage='usage: yt-get [--height N] [--fps N] [--allow-live] [--dest DIR] <url>'
    max_height=${toString cfg.maxHeight}
    max_fps=${toString cfg.maxFps}
    allow_live=0
    dest=${lib.escapeShellArg cfg.mediaDir}
    print_path=0
    url=""
    while [ "$#" -gt 0 ]; do
      case "$1" in
        --height) max_height="$2"; shift 2 ;;
        --fps) max_fps="$2"; shift 2 ;;
        --allow-live) allow_live=1; shift ;;
        # `yt-store` spools here; docs/media-relay.md has the destinations.
        --dest)
          dest="$2"
          print_path=1
          shift 2
          ;;
        -h | --help)
          echo "$usage"
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
      echo "$usage" >&2
      exit 2
    fi

    # A cookie jar is a credential a human provisioned, so it is checked rather
    # than assumed: without it a datacenter IP is refused at the player API
    # ("Sign in to confirm you're not a bot") and the failure looks like a
    # network problem instead of a missing login.
    ${cookieFlag}
    if [ -z "$cookie_flag" ] && [ "${toString cfg.requireCookies}" = "1" ]; then
      echo "yt-get: no readable cookie jar at ${cfg.cookieFile}" >&2
      echo "        YouTube refuses an anonymous player request from this IP." >&2
      echo "        Provision it (0600, owner ${cfg.user}) or set requireCookies = false." >&2
      exit 1
    fi

    export PATH="${pkgs.yt-dlp}/bin:${pkgs.ffmpeg}/bin:$PATH"

    # One metadata call answers both questions: which folder this is, and
    # whether it is live. A live capture has no size for --max-filesize to
    # check and runs until the broadcast ends, which is how one click fills a
    # boot volume shared with five services. `was_live` is a finished stream and
    # downloads like any video; an unknown status (a non-YouTube extractor) is
    # not blocked on the strength of a missing field.
    meta="$(yt-dlp $cookie_flag --no-playlist --no-warnings --print "%(id)s|%(live_status)s" "$url" | head -1)"
    id="''${meta%%|*}"
    live="''${meta#*|}"
    if [ -z "$id" ]; then
      echo "yt-get: could not resolve a video id for $url" >&2
      exit 1
    fi
    case "$live" in
      is_live | is_upcoming | post_live)
        if [ "$allow_live" != 1 ]; then
          echo "yt-get: refusing a live stream ($live): it has no size to check and records until the broadcast ends." >&2
          echo "        Record it deliberately with --allow-live, and watch the disk." >&2
          exit 1
        fi
        ;;
    esac

    # The id is the directory, so a re-fetch reuses it and a listing groups by
    # video rather than by whichever title YouTube was A/B-testing that hour.
    out="$dest/$id"
    mkdir -p "$out"

    # H.264/AAC or nothing. A `best` fallback here would store VP9 or AV1 in an
    # mp4 and hand the iPad a file it cannot open — the failure would be silent,
    # at the client, days later. A fetch with no avc1 stream fails and says why.
    format="bv*[vcodec^=avc1][height<=?$max_height][fps<=?$max_fps]+ba[acodec^=mp4a]"
    format="$format/bv*[vcodec^=avc1][height<=?$max_height]+ba[acodec^=mp4a]"

    file="$(yt-dlp $cookie_flag --no-playlist --no-warnings --no-simulate \
      --max-filesize ${toString cfg.maxDownloadGiB}G \
      -f "$format" --merge-output-format mp4 \
      -o "$out/%(title).120B [%(id)s].%(ext)s" \
      --print after_move:filepath "$url" | tail -1)"

    if [ -z "$file" ] || [ ! -f "$file" ]; then
      echo "yt-get: yt-dlp produced no file — no H.264/AAC stream at or below height $max_height, fps $max_fps, or the fetch failed" >&2
      echo "        Raise --height/--fps, or transcode by hand: the relay stores only H.264 so old Apple clients can play it." >&2
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

    # The poster is YouTube's own still when this account can reach it — one
    # metadata call, full 16:9 frame, no decode — and a frame from the file only
    # as the fallback. Failure is cosmetic (the page shows the filename), so
    # neither path may fail the fetch. A video shorter than the first seek yields
    # no frame at all (exit 0, empty output), hence the second attempt at 0.
    poster="$out/poster.jpg"
    if [ ! -s "$poster" ]; then
      if yt-dlp $cookie_flag --no-playlist --no-warnings --skip-download \
        --write-thumbnail --convert-thumbnails jpg \
        -o "$out/thumb.%(ext)s" "$url" >/dev/null 2>&1 && [ -s "$out/thumb.jpg" ]; then
        mv -f "$out/thumb.jpg" "$poster"
      fi
      # A converted thumbnail can leave the original behind, and a stray image is
      # a second entry in the index.
      rm -f "$out"/thumb.*
    fi
    if [ ! -s "$poster" ]; then
      for at in 3 0; do
        if ffmpeg -nostdin -loglevel error -y -ss "$at" -i "$file" \
          -frames:v 1 -vf "scale=480:-2" -q:v 4 "$poster" 2>/dev/null && [ -s "$poster" ]; then
          break
        fi
        rm -f "$poster"
      done
      [ -s "$poster" ] || echo "yt-get: no poster frame; the page shows the filename only" >&2
    fi

    if [ "$print_path" = "1" ]; then
      echo "$file"
      exit 0
    fi

    rel="''${file#$dest/}"

    # The library page reads this manifest, so a file that appeared only after
    # the next timer tick would look like a failed download.
    if ! ${indexScript}; then
      echo "yt-get: index refresh failed; the timer retries within five minutes" >&2
    fi

    echo "${cfg.publicBase}/$rel"
  '';

  # The upload half of the same fetch; docs/media-relay.md has the destinations.
  # Its credential is scripts/media-relay/r2-env.sh, never this file.
  ytStore = pkgs.writeShellScriptBin "yt-store" ''
    set -eu

    usage='usage: yt-store [--height N] [--fps N] <url>'
    max_height=${toString cfg.maxHeight}
    max_fps=${toString cfg.maxFps}
    url=""
    while [ "$#" -gt 0 ]; do
      case "$1" in
        --height) max_height="$2"; shift 2 ;;
        --fps) max_fps="$2"; shift 2 ;;
        -h | --help)
          echo "$usage"
          exit 0
          ;;
        -*)
          echo "yt-store: unknown option: $1" >&2
          exit 2
          ;;
        *)
          url="$1"
          shift
          ;;
      esac
    done
    if [ -z "$url" ]; then
      echo "$usage" >&2
      exit 2
    fi

    export PATH="${ytGet}/bin:${pkgs.yt-dlp}/bin:${pkgs.ffmpeg}/bin:${pkgs.rclone}/bin:${pkgs.sops}/bin:${pkgs.jq}/bin:${pkgs.curl}/bin:${pkgs.python3}/bin:$PATH"

    MEDIA_SOPS_FILE=${lib.escapeShellArg cfg.r2.sopsFile}
    . ${r2Env}

    bucket=${lib.escapeShellArg cfg.r2.bucket}
    prefix=${lib.escapeShellArg cfg.r2.prefix}
    budget_bytes=${toString (cfg.r2.budgetGiB * 1024 * 1024 * 1024)}

    ${pkgs.coreutils}/bin/mkdir -p ${lib.escapeShellArg cfg.spoolDir}
    spool="$(${pkgs.coreutils}/bin/mktemp -d ${lib.escapeShellArg cfg.spoolDir}/store.XXXXXX)"
    trap '${pkgs.coreutils}/bin/rm -rf "$spool"' EXIT

    held="$(rclone size "r2:$bucket/$prefix" --json 2>/dev/null | ${pkgs.jq}/bin/jq -r '.bytes // 0' || true)"
    held="''${held:-0}"
    if [ "$held" -ge "$budget_bytes" ]; then
      echo "yt-store: $prefix holds $(( held / 1024 / 1024 )) MiB, at the ${toString cfg.r2.budgetGiB} GiB media budget" >&2
      echo "          the rest of the bucket is the nix cache's; prune a video or raise" >&2
      echo "          services.media-relay.r2.budgetGiB" >&2
      exit 1
    fi

    file="$(yt-get --dest "$spool" --height "$max_height" --fps "$max_fps" "$url")"
    if [ -z "$file" ] || [ ! -f "$file" ]; then
      echo "yt-store: yt-get produced no file; the library was not touched" >&2
      exit 1
    fi
    dir="$(${pkgs.coreutils}/bin/dirname "$file")"
    name="$(${pkgs.coreutils}/bin/basename "$file")"
    id="$(${pkgs.coreutils}/bin/basename "$dir")"
    key="$prefix/$id/$name"

    rclone copyto "$file" "r2:$bucket/$key" --transfers 1 --checkers 1
    if [ -s "$dir/poster.jpg" ]; then
      rclone copyto "$dir/poster.jpg" "r2:$bucket/$prefix/$id/poster.jpg" || true
    fi

    rclone lsf "r2:$bucket/$prefix/$id" --files-only 2>/dev/null |
      while IFS= read -r stale; do
        case "$stale" in
          "$name" | poster.jpg) ;;
          *) rclone deletefile "r2:$bucket/$prefix/$id/$stale" || true ;;
        esac
      done || true

    rel="''${key#"$prefix/"}"
    public_url="${cfg.r2.publicBase}/$(python3 -c 'import sys, urllib.parse; print(urllib.parse.quote(sys.argv[1]))' "$rel")"
    if ! curl -sfI --max-time 15 "$public_url" >/dev/null; then
      echo "yt-store: uploaded, but $public_url is not served yet" >&2
      echo "          deploy the Worker that owns /media/: task dev:nixcache:deploy" >&2
    fi

    echo "$public_url"
  '';

  # The cloud listing, read by scripts/media-relay/r2-env.sh for the page.
  r2List = pkgs.writeShellScript "media-relay-r2-list" ''
    set -eu
    export PATH="${pkgs.rclone}/bin:${pkgs.sops}/bin:${pkgs.jq}/bin:$PATH"
    MEDIA_SOPS_FILE=${lib.escapeShellArg cfg.r2.sopsFile}
    . ${r2Env}
    exec rclone lsjson "r2:${cfg.r2.bucket}/${cfg.r2.prefix}" --files-only --recursive
  '';

  # The one pruner, called by the timer and by `/api/gc` — docs/media-relay.md
  mediaGc = pkgs.writeShellScript "media-gc" ''
    set -eu

    media=${lib.escapeShellArg cfg.mediaDir}
    bucket=${lib.escapeShellArg cfg.r2.bucket}
    prefix=${lib.escapeShellArg cfg.r2.prefix}
    days=${toString cfg.retentionDays}
    scope=all
    apply=0
    while [ "$#" -gt 0 ]; do
      case "$1" in
        --days) days="$2"; shift 2 ;;
        --scope) scope="$2"; shift 2 ;;
        --apply) apply=1; shift ;;
        --dry) apply=0; shift ;;
        *) echo "media-gc: unknown option: $1" >&2; exit 2 ;;
      esac
    done
    case "$days" in "" | *[!0-9]*) echo "media-gc: --days must be a number" >&2; exit 2 ;; esac
    case "$scope" in all | local | r2) ;; *) echo "media-gc: --scope must be all, local or r2" >&2; exit 2 ;; esac

    export PATH="${lib.makeBinPath [pkgs.findutils pkgs.coreutils pkgs.jq pkgs.rclone pkgs.sops]}"

    local_removed='[]'
    if [ "$scope" != "r2" ] && [ -d "$media" ]; then
      list="$(find "$media" -type f ! -name '.index.json' -mtime +"$days" -printf '%P\n' || true)"
      local_removed="$(printf '%s\n' "$list" | jq -R -s 'split("\n") | map(select(length > 0))')"
      if [ "$apply" = 1 ] && [ -n "$list" ]; then
        printf '%s\n' "$list" | while IFS= read -r rel; do
          rm -f -- "$media/$rel"
        done
        find "$media" -type d -empty -delete 2>/dev/null || true
        ${indexScript} || true
      fi
    fi

    r2_removed='[]'
    ${lib.optionalString cfg.r2.enable ''
      if [ "$scope" != "local" ]; then
        MEDIA_SOPS_FILE=${lib.escapeShellArg cfg.r2.sopsFile}
        . ${r2Env}
        objects="$(rclone lsjson "r2:$bucket/$prefix" --files-only --recursive 2>/dev/null || echo '[]')"
        cutoff="$(( $(date +%s) - days * 86400 ))"
        # An unreadable ModTime keeps the object; a guessed date deletes a library: docs/media-relay.md
        stale="$(printf '%s' "$objects" | jq -r --argjson cut "$cutoff" --argjson now "$(date +%s)" '
          .[] | ((.ModTime // "") | sub("\\.[0-9]+$"; "")) as $t
          | (($t | fromdateiso8601?) // $now) as $epoch
          | select($epoch < $cut) | .Path')"
        r2_removed="$(printf '%s\n' "$stale" | jq -R -s 'split("\n") | map(select(length > 0))')"
        if [ "$apply" = 1 ] && [ -n "$stale" ]; then
          printf '%s\n' "$stale" | while IFS= read -r key; do
            rclone deletefile "r2:$bucket/$prefix/$key" || true
            case "$key" in
              poster.jpg | */poster.jpg) ;;
              */*) rclone deletefile "r2:$bucket/$prefix/''${key%/*}/poster.jpg" 2>/dev/null || true ;;
            esac
          done
        fi
      fi
    ''}

    jq -n --argjson local "$local_removed" --argjson r2 "$r2_removed" \
      --argjson days "$days" --arg scope "$scope" --argjson applied "$apply" \
      '{days: $days, scope: $scope, applied: ($applied == 1),
        local: $local, r2: $r2,
        local_count: ($local | length), r2_count: ($r2 | length)}'
  '';

  # One object, gone; `/api/r2`'s delete route — docs/media-relay.md
  r2Delete = pkgs.writeShellScript "media-relay-r2-delete" ''
    set -eu
    export PATH="${lib.makeBinPath [pkgs.rclone pkgs.sops pkgs.jq]}"
    MEDIA_SOPS_FILE=${lib.escapeShellArg cfg.r2.sopsFile}
    . ${r2Env}
    exec rclone deletefile "r2:${cfg.r2.bucket}/${cfg.r2.prefix}/$1"
  '';

  # Search, for the page's search field. `--flat-playlist` is the whole trick:
  # one search request, no per-video extraction, and the entry already carries
  # the title, channel, duration and thumbnail the page draws — the same shape
  # ytfzf reads. The cookie jar is optional here (a search page is less guarded
  # than the player API) but shared with `yt-get` so the two agree about who is
  # asking.
  ytSearch = pkgs.writeShellScriptBin "yt-search" ''
    set -euo pipefail

    limit=15
    query=""
    while [ "$#" -gt 0 ]; do
      case "$1" in
        --limit)
          limit="$2"
          shift 2
          ;;
        -h | --help)
          echo "usage: yt-search [--limit N] <query>"
          exit 0
          ;;
        -*)
          echo "yt-search: unknown option: $1" >&2
          exit 2
          ;;
        *)
          query="$1"
          shift
          ;;
      esac
    done

    case "$limit" in
      *[!0-9]*)
        echo "yt-search: --limit must be a number" >&2
        exit 2
        ;;
    esac
    if [ -z "$limit" ]; then
      echo "yt-search: --limit must be a number" >&2
      exit 2
    fi

    if [ -z "$query" ]; then
      echo "usage: yt-search [--limit N] <query>" >&2
      exit 2
    fi

    ${cookieFlag}

    export PATH="${pkgs.yt-dlp}/bin:$PATH"

    yt-dlp $cookie_flag --flat-playlist --no-warnings -J "ytsearch''${limit}:$query" \
      | ${pkgs.jq}/bin/jq '
          [.entries[]? | select(. != null and .id != null)
           | {id, title, channel, duration,
              live: (.live_status // "not_live"),
              url: ("https://www.youtube.com/watch?v=" + .id),
              thumb: (([.thumbnails[]? | .url] | last)
                      // ("https://i.ytimg.com/vi/" + .id + "/mqdefault.jpg"))}]
        '
  '';

  # What the library page lists. `find` is the authority — a manifest a fetch has
  # to remember to update is a manifest that goes stale — and the page never
  # walks the directory tree itself, which is one request per folder.
  indexScript = pkgs.writeShellScript "media-relay-index" ''
    set -euo pipefail
    media=${lib.escapeShellArg cfg.mediaDir}
    out="$media/.index.json"
    tmp="$out.tmp"
    trap '${pkgs.coreutils}/bin/rm -f "$tmp"' EXIT
    # shellcheck disable=SC2016 # $now and $e are jq variables, not shell ones
    ${pkgs.findutils}/bin/find "$media" -type f ! -name '.index.json' -printf '%P\t%s\t%T@\n' \
      | ${pkgs.jq}/bin/jq -R -n --arg now "$(${pkgs.coreutils}/bin/date -u +%FT%TZ)" '
        def kinds: {
          video: ["mp4","m4v","webm","mkv","mov","avi","mpg","mpeg","ts"],
          audio: ["mp3","m4a","aac","ogg","opus","flac","wav"],
          image: ["jpg","jpeg","png","webp","gif","avif"],
          subtitle: ["srt","vtt"]
        };
        def kindof($e): (kinds | to_entries | map(select(.value | index($e))) | .[0].key) // null;
        [inputs | select(length > 0) | split("\t")]
        | map({path: .[0], size: (.[1] | tonumber), mtime: (.[2] | tonumber | floor)})
        | map(.name = (.path | split("/") | last))
        | map(.ext = (.name | split(".") | if length > 1 then .[-1] else "" end | ascii_downcase))
        | map(.dir = (.path | split("/") | if length > 1 then .[:-1] | join("/") else "" end))
        # `poster.jpg` is metadata about the video beside it, not an image in its
        # own right: it is never listed and never counted, or a fetch would add a
        # second entry (and a duplicate thumbnail) to the library.
        | ([.[] | select(.name == "poster.jpg") | .dir] | unique) as $posters
        | map(select(.name != "poster.jpg"))
        | map(.kind = kindof(.ext))
        | map(select(.kind != null))
        | map(if .kind == "video" and (.dir as $d | $posters | index($d) != null)
               then .poster = ((if .dir == "" then "" else .dir + "/" end) + "poster.jpg")
               else . end)
        | sort_by(.path)
        | {generated: $now, count: length, bytes: (map(.size) | add // 0), files: .}
      ' >"$tmp"
    ${pkgs.coreutils}/bin/mv -f "$tmp" "$out"
  '';

  # Posters for everything already in the library: a fetch writes its own, but a
  # file copied in by hand, or fetched before posters existed, has none. One
  # frame per video, skipped when the poster is already there, so a second run is
  # a `find` and nothing else.
  postersScript = pkgs.writeShellScript "media-relay-posters" ''
    set -eu
    media=${lib.escapeShellArg cfg.mediaDir}
    export PATH="${pkgs.ffmpeg}/bin:$PATH"
    ${pkgs.findutils}/bin/find "$media" -type f \
      \( -name '*.mp4' -o -name '*.m4v' -o -name '*.webm' -o -name '*.mkv' \
      -o -name '*.mov' -o -name '*.avi' -o -name '*.mpg' -o -name '*.mpeg' -o -name '*.ts' \) -print0 \
      | while IFS= read -r -d $'\0' f; do
        poster="$(dirname "$f")/poster.jpg"
        if [ -s "$poster" ]; then continue; fi
        for at in 3 0; do
          if ffmpeg -nostdin -loglevel error -y -ss "$at" -i "$f" \
            -frames:v 1 -vf "scale=480:-2" -q:v 4 "$poster" 2>/dev/null && [ -s "$poster" ]; then
            break
          fi
          rm -f "$poster"
        done
      done
  '';

  # One immutable page: the listing is data, and the page is fed the manifest at
  # `= /index.json`, so nothing is generated into the store per request.
  staticUi = import ../config/nginx-static-ui.nix;
  mediaUi = staticUi.package pkgs "media-relay" ../../lib/media-relay/index.html;

  # The page's write half. Loopback only: the vhost's `/api/` proxy is the whole
  # surface, because a fetch is an outbound request this host makes on someone
  # else's behalf.
  api = pkgs.writeShellScript "media-relay-api" ''
    set -eu
    export YT_GET=${ytGet}/bin/yt-get
    export YT_SEARCH=${ytSearch}/bin/yt-search
    export COOKIE_FILE=${cfg.cookieFile}
    ${lib.optionalString cfg.r2.enable ''
      export YT_STORE=${ytStore}/bin/yt-store
      export R2_LIST=${r2List}
      export R2_DEL=${r2Delete}
      export R2_PUBLIC=${cfg.r2.publicBase}
      export MEDIA_GC=${mediaGc}
    ''}
    export MEDIA_DIR=${lib.escapeShellArg cfg.mediaDir}
    export INDEX=${indexScript}
    export RETENTION_DAYS=${toString cfg.retentionDays}
    export REQUIRE_COOKIES=${
      if cfg.requireCookies
      then "1"
      else "0"
    }
    export BIND_ADDR=127.0.0.1
    export PORT=${toString cfg.apiPort}
    exec ${pkgs.python3}/bin/python3 ${../../lib/media-relay/api.py}
  '';

  nginxPort = toString cfg.port;
  mediaRelayPruneJob = systemdJobs.mkTimerJob {} {
    description = "Delete fetched videos untouched for ${toString cfg.retentionDays} days";
    path = [pkgs.findutils];
    serviceConfig = {
      Type = "oneshot";
      # The bucket half reads sops as the library owner: docs/sops-rekey.md
      User = cfg.user;
    };
    script = "${mediaGc} --days ${toString cfg.retentionDays} --scope all --apply";
    onCalendar = "daily";
  };
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

    apiPort = lib.mkOption {
      type = lib.types.port;
      # 8099 is the turn dashboard, 8098 miniflux, 8097 vikunja, 8096 ntfy and
      # 8094 the library itself, so 8100 is the next free loopback port here.
      default = 8100;
      description = "Loopback port for the search/fetch API the vhost proxies at /api/.";
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

    maxDownloadGiB = lib.mkOption {
      type = lib.types.int;
      default = 4;
      description = ''
        Ceiling for one download, in GiB (`yt-dlp --max-filesize`). It bounds a
        VOD that turns out to be enormous; a live stream is refused separately,
        because it has no size to check and would record until it ends.
      '';
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

    spoolDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/media-relay/spool";
      description = ''
        Scratch space for `yt-store`: `yt-get --dest` writes here, the upload
        reads it, and the directory is deleted on exit whatever happened. It is on
        the same volume as the library, so a spool is counted by `df` while it
        lasts — one file at a time, because the API queues stores.
      '';
    };

    # The bucket docs/nix-cache-edge.md owns, double-dipped per docs/media-relay.md.
    r2.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Offer `→ R2` on the page and `yt-store` on the host: fetch into the
        bucket instead of the boot volume, and play it back from the edge. Off by
        default, because it depends on a credential and a deployed Worker.
      '';
    };

    r2.bucket = lib.mkOption {
      type = lib.types.str;
      default = "nix-cache";
      description = "R2 bucket. The cache's name, not a second bucket: one free-tier budget, one lifecycle rule, one Worker.";
    };

    r2.prefix = lib.mkOption {
      type = lib.types.str;
      default = "media";
      description = ''
        Object prefix, and the Worker's URL prefix (`/media/…`). It must stay a
        first path segment that no narinfo or nar grammar claims, or a stored
        video would shadow a store path.
      '';
    };

    r2.publicBase = lib.mkOption {
      type = lib.types.str;
      default = "${edgeUrl}/${cfg.r2.prefix}";
      description = ''
        Where a stored object is played from: the edge Worker, not this host. The
        default is `lib/cache-registry.nix`'s edge URL, so the cache and the
        library cannot disagree about which Worker serves the bucket.
      '';
    };

    r2.budgetGiB = lib.mkOption {
      type = lib.types.int;
      default = 6;
      description = ''
        Ceiling for the prefix, in GiB, measured by `rclone size` before every
        store. A refusal, not a warning: the bucket's 10 GiB free tier is shared
        with the nix cache, and overflow is billed. 6 leaves the cache its
        documented 4.
      '';
    };

    r2.sopsFile = lib.mkOption {
      type = lib.types.str;
      default = "${config.users.users.${cfg.user}.home}/Documents/nixconfig/modules/secrets/apikeys.yaml";
      description = ''
        The sops apikeys plane `yt-store` and the lister read at run time with the
        library owner's age key (`CLOUDFLARE.{ACCESS.KEY.ID,
        SECRET.ACCESS.KEY,S3.API.ENDPOINT}`). A path rather than a store copy: the
        directory is a git submodule and the keys are not declared in Nix, the
        same rule scripts/task/nixcache.sh follows.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.cookieFile == "" || lib.hasPrefix "/" cfg.cookieFile;
        message = "services.media-relay.cookieFile must be an absolute path (or empty)";
      }
    ];

    environment.systemPackages =
      [ytGet ytSearch pkgs.yt-dlp pkgs.ffmpeg]
      ++ lib.optional cfg.r2.enable ytStore;

    # Group left as `-` on purpose: delphi's devji has no group of its own
    # (primary gid 100 = users), and naming it made the rule fail with
    # "invalid group", which then left the nginx root missing.
    systemd.tmpfiles.rules =
      [
        "d ${cfg.mediaDir} 0755 ${cfg.user} - -"
        # Traversable, not 0750: nginx workers are not devji and cannot enter a
        # group-restricted parent, which turns every request into 403 while the
        # jar itself stays 0600.
        "d ${builtins.dirOf cfg.cookieFile} 0755 ${cfg.user} - -"
      ]
      ++ lib.optional cfg.r2.enable "d ${cfg.spoolDir} 0700 ${cfg.user} - -";

    # Range support is native to nginx; what is added is the listing a client
    # can actually browse on an iPad (plain HTML, no JS) and a cache header that
    # keeps a re-watch off the wire.
    services.nginx = {
      enable = true;
      virtualHosts."media-relay" = {
        listen = [
          {
            # Loopback: reaching this is a decision about a mount or a firewall
            # row, not something the bind address should pre-empt on a host whose
            # public interface is the fleet's only one.
            addr = "127.0.0.1";
            inherit (cfg) port;
          }
        ];
        root = cfg.mediaDir;
        locations =
          {
            "/" = {
              extraConfig = ''
                autoindex on;
                autoindex_exact_size off;
                autoindex_localtime on;
                add_header Cache-Control "public, max-age=86400";
                # nginx already emits `Accept-Ranges: bytes` for static files; an
                # explicit header here is a second copy of the same line.
              '';
            };
          }
          # The browse page owns the root via the shared static-UI pair; a
          # directory URL still gets the plain listing, so a bookmark taken
          # before the page existed keeps working.
          // staticUi.locations mediaUi
          // {
            "= /index.json" = {
              alias = "${cfg.mediaDir}/.index.json";
              extraConfig = ''
                # Regenerated on a timer and after every fetch: a cached manifest is
                # a library missing the file you just downloaded.
                add_header Cache-Control "no-store";
              '';
            };
            # The page's write half: search YouTube, queue a fetch. Proxied with its
            # path intact (`/api/` on both sides), and `no-store` because it
            # describes a queue that moves.
            "/api/" = {
              proxyPass = "http://127.0.0.1:${toString cfg.apiPort}/api/";
              extraConfig = ''
                proxy_http_version 1.1;
                proxy_set_header Host 127.0.0.1;
                # A search runs yt-dlp for a few seconds; a POST answers at once.
                proxy_read_timeout 90s;
                client_max_body_size 8k;
                add_header Cache-Control "no-store" always;
              '';
            };
          };
      };
    };

    systemd.services.media-relay-prune = mediaRelayPruneJob.service;

    systemd.timers.media-relay-prune = mediaRelayPruneJob.timer;

    # Written as the library's owner so the manifest is never a file nginx can
    # read but a fetch cannot replace.
    # Boot is when a hand-copied file is noticed; a fetch never waits on this
    # unit, because `yt-get` writes its own poster before it refreshes the index.
    systemd.services.media-relay-posters = {
      description = "Write the poster frame each video in the library is missing";
      wantedBy = ["multi-user.target"];
      serviceConfig = {
        Type = "oneshot";
        User = cfg.user;
        UMask = "0022";
      };
      script = "${postersScript}";
    };

    systemd.services.media-relay-index = {
      description = "Write the media library's index.json";
      serviceConfig = {
        Type = "oneshot";
        User = cfg.user;
        UMask = "0022";
      };
      script = "${indexScript}";
    };

    systemd.timers.media-relay-index = {
      wantedBy = ["timers.target"];
      timerConfig = {
        OnBootSec = "30s";
        OnUnitActiveSec = "5min";
        AccuracySec = "30s";
      };
    };

    # Search and fetch. It runs as the library's owner so `yt-get` can write
    # under mediaDir without a second ownership rule, and it is the only process
    # here that takes input — hence loopback-only and the URL allow-list in
    # api.py rather than a bare `yt-get $anything`.
    systemd.services.media-relay-api = {
      description = "media-relay search and fetch API on 127.0.0.1:${toString cfg.apiPort}";
      unitConfig.X-Fleet-Role = "daemon";
      wantedBy = ["multi-user.target"];
      after = ["network-online.target"];
      wants = ["network-online.target"];
      serviceConfig = {
        Type = "simple";
        User = cfg.user;
        ExecStart = "${api}";
        Restart = "always";
        RestartSec = 3;
        # A fetch can outlive a stop (a long video), and killing yt-dlp mid-merge
        # leaves a partial file in the library.
        TimeoutStopSec = "45s";
        KillMode = "mixed";
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectSystem = "strict";
        # The jar's DIRECTORY, not just mediaDir: `--cookies` opens the file
        # read-write so yt-dlp can save the refreshed session back, and
        # ProtectSystem=strict alone made it read-only — every search died with
        # `OSError: [Errno 30]` inside yt_dlp/cookies.py and the page saw a 502
        # (measured 2026-11-10, first deploy of this API).
        ReadWritePaths =
          [cfg.mediaDir]
          ++ lib.optional (cfg.cookieFile != "") (builtins.dirOf cfg.cookieFile)
          ++ lib.optional cfg.r2.enable cfg.spoolDir;
        RestrictAddressFamilies = ["AF_INET" "AF_INET6"];
        # The interpreter plus one yt-dlp child; the cap is the runaway guard,
        # not the expectation.
        MemoryMax = "512M";
      };
    };
  };
}
