# The media library over HTTP, for a terminal: docs/terminal-clients.md
{pkgs, ...}: let
  media =
    pkgs.writers.writeBashBin "media" {
      makeWrapperArgs = [
        "--prefix"
        "PATH"
        ":"
        (pkgs.lib.makeBinPath [
          pkgs.curl
          pkgs.jq
          pkgs.fzf
          pkgs.coreutils
          pkgs.gnugrep
        ])
      ];
    } ''
      set -euo pipefail

      API="''${MEDIA_API:-https://delphi.cloudforest-kardashev.ts.net:8461}"
      UA="''${MEDIA_UA:-media-cli/1}"
      TAB="$(printf '\t')"

      say() { printf '%s\n' "$*"; }
      die() { printf 'media: %s\n' "$*" >&2; exit 1; }

      usage() {
        cat <<'USAGE'
      media — delphi's media library over HTTP

      Usage:
        media health                     the API, the cookie jar, the bucket
        media ls [--local|--cloud] [--kind K] [--json]
        media find WORDS...              fuzzy over names, folders and paths
        media search QUERY               YouTube search (no download)
        media get URL [--no-wait]        fetch onto delphi
        media store URL [--no-wait]      fetch into the R2 bucket
        media play NAME|PATH [--open]    the URL to play, or play it
        media rm PATH [-y]               delete a local file
        media rm KEY --cloud [-y]        delete a stored object
        media gc [--days N] [--scope all|local|r2] [--apply]
        media jobs [--json]

      Env:
        MEDIA_API      base URL (default: the delphi tailnet front on 8461)
        MEDIA_UA       User-Agent, so a client is recognisable in the log
        GC_DAYS        default window for `media gc`
      USAGE
      }

      api() {
        curl -fsS --max-time "''${MEDIA_TIMEOUT:-1860}" -A "$UA" \
          -H 'Accept: application/json' "$@"
      }

      human() {
        awk -v b="''${1:-0}" 'BEGIN { split("B K M G T", u, " "); i = 1; while (b >= 1024 && i < 5) { b /= 1024; i++ } printf "%.0f%s", b, u[i] }'
      }

      clock() {
        awk -v s="''${1:-}" 'BEGIN { if (s == "") exit; h = int(s/3600); m = int((s%3600)/60); c = int(s%60); if (h) printf "%d:%02d:%02d", h, m, c; else printf "%d:%02d", m, c }'
      }

      encpath() { jq -nr --arg p "$1" '$p | split("/") | map(@uri) | join("/")'; }

      # One list, two sources, and an empty bucket is an empty half: docs/media-relay.md
      listing() {
        local scope="''${1:-all}" here='{"items":[]}' cloud='{"items":[]}'
        if [ "$scope" != cloud ]; then here="$(api "$API/api/library" || printf '%s' '{"items":[]}')"; fi
        if [ "$scope" != local ]; then cloud="$(api "$API/api/r2" || printf '%s' '{"items":[]}')"; fi
        printf '%s\n%s\n' "$here" "$cloud" | jq -s '
          { items: ((.[0].items // []) | map(. + {where: "here"}))
                 + ((.[1].items // []) | map({path: .key, name, dir, ext, kind, size, mtime, poster, url, where: "R2"})) }'
      }

      cmd_ls() {
        local scope=all kind="" json=0
        while [ "$#" -gt 0 ]; do
          case "$1" in
            --cloud) scope=cloud; shift ;;
            --local) scope=local; shift ;;
            --kind) kind="$2"; shift 2 ;;
            --json) json=1; shift ;;
            *) die "ls: unknown option: $1" ;;
          esac
        done
        local data
        data="$(listing "$scope")"
        if [ -n "$kind" ]; then
          data="$(printf '%s' "$data" | jq --arg k "$kind" '{items: [.items[] | select(.kind == $k)]}')"
        fi
        if [ "$json" = 1 ]; then
          printf '%s\n' "$data"
          return 0
        fi
        printf '%s' "$data" | jq -r '.items | sort_by(.mtime) | reverse | .[] | [.where, .kind, (.size | tostring), .name, .path] | @tsv' |
          while IFS="$TAB" read -r where kind size name _path; do
            printf '%-4s %-5s %7s  %s\n' "$where" "$kind" "$(human "$size")" "$name"
          done
      }

      cmd_find() {
        [ "$#" -gt 0 ] || die "find: need words"
        local q="$*"
        listing all | jq -r '.items[] | [.path, .name, .where] | @tsv' |
          if command -v fzf >/dev/null 2>&1; then
            fzf --filter "$q" --delimiter="$TAB" --with-nth=3,2 |
              while IFS="$TAB" read -r path name where; do printf '%s\n' "$path"; done
          else
            grep -i -- "$q" | cut -f1
          fi
      }

      cmd_search() {
        [ "$#" -gt 0 ] || die "search: need a query"
        api -G --data-urlencode "q=$*" --data-urlencode "limit=''${LIMIT:-15}" "$API/api/search" |
          jq -r '.items[] | [.id, (.duration // 0 | tostring), .title, (.channel // "")] | @tsv' |
          while IFS="$TAB" read -r id dur title channel; do
            printf '%s  %6s  %s  (%s)\n' "$id" "$(clock "$dur")" "$title" "$channel"
          done
      }      # Both write routes are the same fetch, and the route names the destination: docs/media-relay.md
      cmd_fetch() {
        local mode="$1" wait=1
        shift
        if [ "''${1:-}" = "--no-wait" ]; then
          wait=0
          shift
        fi
        [ "$#" -gt 0 ] || die "$mode: need a URL"
        local route=/api/fetch
        [ "$mode" = store ] && route=/api/store
        local job id state out err ticks=0
        job="$(api -X POST -H 'Content-Type: application/json' \
          -d "$(jq -nc --arg u "$1" '{url: $u, title: ""}')" "$API$route")" ||
          die "$mode: could not queue (429 means four are already running)"
        id="$(printf '%s' "$job" | jq -r '.id')"
        say "$mode queued: $id"
        [ "$wait" = 1 ] || return 0
        while :; do
          sleep 2
          ticks=$((ticks + 1))
          [ "$ticks" -lt 1800 ] || die "gave up waiting for $id; media jobs shows it"
          job="$(api "$API/api/jobs")" || continue
          state="$(printf '%s' "$job" | jq -r --arg i "$id" '.jobs[] | select(.id == $i) | .state' | head -1)"
          case "$state" in
            done)
              out="$(printf '%s' "$job" | jq -r --arg i "$id" '.jobs[] | select(.id == $i) | .out' | head -1)"
              say "$out"
              return 0
              ;;
            failed)
              err="$(printf '%s' "$job" | jq -r --arg i "$id" '.jobs[] | select(.id == $i) | .error' | head -1)"
              die "$mode failed: $err"
              ;;
            queued | running) ;;
            "") die "the queue has forgotten $id" ;;
          esac
        done
      }

      cmd_play() {
        local open=0
        if [ "''${1:-}" = "--open" ]; then
          open=1
          shift
        fi
        [ "$#" -gt 0 ] || die "play: need a name, a folder or a path"
        local row target
        row="$(listing all | jq -r --arg q "$(printf '%s' "$*" | tr '[:upper:]' '[:lower:]')" '
          [.items[] | select((.path | ascii_downcase) | contains($q))] | .[0] // empty | [.where, (.url // ""), .path] | @tsv')"
        [ -n "$row" ] || die "nothing matches: $*"
        local where url path
        IFS="$TAB" read -r where url path <<<"$row"
        if [ "$where" = R2 ]; then
          target="$url"
        else
          target="$API/$(encpath "$path")"
        fi
        say "$target"
        [ "$open" = 1 ] || return 0
        if command -v mpv >/dev/null 2>&1; then
          mpv --no-terminal "$target" &
        elif command -v xdg-open >/dev/null 2>&1; then
          xdg-open "$target" >/dev/null 2>&1 || die "xdg-open refused $target"
        else
          say "no player here; the URL above is the answer" >&2
        fi
      }

      cmd_rm() {
        local cloud=0 yes=0 arg=""
        while [ "$#" -gt 0 ]; do
          case "$1" in
            --cloud) cloud=1; shift ;;
            -y | --yes) yes=1; shift ;;
            *) arg="$1"; shift ;;
          esac
        done
        [ -n "$arg" ] || die "rm: need a path (or a key with --cloud)"
        if [ "$yes" != 1 ]; then
          printf 'delete %s? [y/N] ' "$arg" >&2
          reply=""
          read -r reply || reply=""
          case "$reply" in y | Y | yes) ;; *) die "kept" ;; esac
        fi
        if [ "$cloud" = 1 ]; then
          api -X DELETE -G --data-urlencode "key=$arg" "$API/api/r2"
        else
          api -X DELETE -G --data-urlencode "path=$arg" "$API/api/library"
        fi | jq .
      }

      # Dry unless --apply, and `rm` asks first: flake/policies.nix
      cmd_gc() {
        local days="''${GC_DAYS:-}" scope=all apply=0
        while [ "$#" -gt 0 ]; do
          case "$1" in
            --days) days="$2"; shift 2 ;;
            --scope) scope="$2"; shift 2 ;;
            --apply) apply=1; shift ;;
            --dry) apply=0; shift ;;
            *) die "gc: unknown option: $1" ;;
          esac
        done
        api -X POST -H 'Content-Type: application/json' \
          -d "$(jq -nc --arg d "$days" --arg s "$scope" --argjson a "$apply" \
            '{days: ((($d | tonumber?) // 14)), scope: $s, dry: ($a != 1)}')" \
          "$API/api/gc" | jq .
      }

      cmd_jobs() {
        local data
        data="$(api "$API/api/jobs")"
        if [ "''${1:-}" = "--json" ]; then
          printf '%s\n' "$data"
          return 0
        fi
        printf '%s' "$data" | jq -r '.jobs[] | [.state, (.mode // "local"), (.title // .url), (.out // .error // "")] | @tsv' |
          while IFS="$TAB" read -r state mode what out; do
            printf '%-8s %-5s %s\n' "$state" "$mode" "$what"
            [ -n "$out" ] && printf '         %s\n' "$out"
          done
        true
      }

      cmd_health() {
        api "$API/api/health" | jq -r '
          "api      \(.ok | tostring)\ncookies  \(.cookies | tostring)\(if .require_cookies then " (required)" else "" end)\nr2       \(.r2 | tostring)\nlibrary  \((.library // false) | tostring)\ngc       \((.gc // false) | tostring)\nretention \(.retention_days // 0) days\nactive   \(.active | tostring)"'
      }

      cmd="''${1:-}"
      [ "$#" -gt 0 ] && shift
      case "$cmd" in
        health) cmd_health ;;
        ls | list) cmd_ls "$@" ;;
        find) cmd_find "$@" ;;
        search) cmd_search "$@" ;;
        get | fetch) cmd_fetch local "$@" ;;
        store) cmd_fetch store "$@" ;;
        play | url) cmd_play "$@" ;;
        rm | delete) cmd_rm "$@" ;;
        gc) cmd_gc "$@" ;;
        jobs) cmd_jobs "$@" ;;
        -h | --help | help | "") usage ;;
        *) die "unknown command: $cmd (try: media --help)" ;;
      esac
    '';
in {
  home.packages = [media];
}
