# The email archive from a terminal, on the routes and camelCase rule in .agents/skills/mail-archive/SKILL.md
{pkgs, ...}: let
  mail =
    pkgs.writers.writeBashBin "mail" {
      makeWrapperArgs = [
        "--prefix"
        "PATH"
        ":"
        (pkgs.lib.makeBinPath [
          pkgs.curl
          pkgs.jq
          pkgs.fzf
          pkgs.coreutils
          pkgs.less
        ])
      ];
    } ''
      set -euo pipefail

      ARCHIVE="''${EMAIL_ARCHIVE_API:-https://delphi.cloudforest-kardashev.ts.net:8450}"
      UA="''${MAIL_UA:-mail-cli/1}"
      TAB="$(printf '\t')"

      say() { printf '%s\n' "$*"; }
      die() { printf 'mail: %s\n' "$*" >&2; exit 1; }

      usage() {
        cat <<'USAGE'
      mail — the email archive from a terminal

      Usage:
        mail ls [--lim N]             newest first, envelope only
        mail q WORDS...               fuzzy: full text, then substring, ranked with fzf
        mail body MESSAGE_ID          one body, through $PAGER
        mail open                     pick a message with fzf, then read it
        mail attention [--lim N]      what needs a person
        mail hub                      backlog per owner
        mail resolve MESSAGE_ID [-y]  close a message (every classifier at once)
        mail health

      Env:
        EMAIL_ARCHIVE_API   base URL (default: the delphi tailnet front on 8450)
        PAGER               defaults to less
      USAGE
      }

      api() {
        curl -fsS --max-time 60 -A "$UA" -H 'Accept: application/json' "$@"
      }

      table() {
        jq -r '.[] | [(.sentAt // .sent_at // "-"), (.sender // ""), (.subject // ""), (.messageId // .message_id // "")] | @tsv' |
          while IFS="$TAB" read -r sent sender subject id; do
            printf '%s  %-28.28s  %-60.60s  %s\n' "''${sent%%.*}" "$sender" "$subject" "$id"
          done
      }

      cmd_ls() {
        local lim=20
        while [ "$#" -gt 0 ]; do
          case "$1" in
            --lim) lim="$2"; shift 2 ;;
            *) die "ls: unknown option: $1" ;;
          esac
        done
        api "$ARCHIVE/api/list-emails?lim=$lim" | table
      }

      # Two engines: full text first, then substring, then fzf ranks — docs/email-archive.md
      cmd_q() {
        [ "$#" -gt 0 ] || die "q: need words"
        local q="$*" rows
        rows="$(api -G --data-urlencode "q=$q" "$ARCHIVE/api/emails-search" || printf '[]')"
        if [ "$rows" = "[]" ] || [ -z "$rows" ]; then
          rows="$(api -G --data-urlencode "q=$q" "$ARCHIVE/api/emails-fuzzy" || printf '[]')"
        fi
        if [ "$rows" = "[]" ]; then
          say "nothing matches: $q"
          return 0
        fi
        if [ ! -t 1 ] || ! command -v fzf >/dev/null 2>&1; then
          printf '%s' "$rows" | jq -r '.[] | [(.sentAt // "-"), (.sender // ""), (.subject // ""), (.messageId // "")] | @tsv' |
            while IFS="$TAB" read -r sent sender subject id; do
              printf '%s  %-28.28s  %-60.60s  %s\n' "''${sent%%.*}" "$sender" "$subject" "$id"
            done
          return 0
        fi
        local pick
        pick="$(printf '%s' "$rows" |
          jq -r '.[] | [(.messageId // ""), (.sentAt // "-"), (.sender // ""), (.subject // ""), ((.snippet // "") | gsub("<<|>>"; ""))] | @tsv' |
          fzf --delimiter="$TAB" --with-nth=2,3,4,5 --nth=3,4,5 --header="$q" || true)"
        [ -n "$pick" ] || return 0
        cmd_body "''${pick%%"$TAB"*}"
      }

      cmd_body() {
        [ "$#" -gt 0 ] || die "body: need a message id"
        local body
        body="$(api -G --data-urlencode "messageId=$1" "$ARCHIVE/api/message-body" |
          jq -r '.[0] | if . == null then empty else "From: \(.sender // "")\nSubject: \(.subject // "")\nDate: \(.sentAt // "")\n\n\(.bodyPlain // "")" end')"
        [ -n "$body" ] || die "no message with that id"
        if [ -t 1 ]; then
          printf '%s\n' "$body" | "''${PAGER:-less}"
        else
          printf '%s\n' "$body"
        fi
      }

      cmd_open() {
        local pick
        pick="$(api "$ARCHIVE/api/list-emails?lim=50" |
          jq -r '.[] | [(.messageId // ""), (.sentAt // "-"), (.sender // ""), (.subject // "")] | @tsv' |
          fzf --delimiter="$TAB" --with-nth=2,3,4 --nth=3,4 --header="newest 50" || true)"
        [ -n "$pick" ] || return 0
        cmd_body "''${pick%%"$TAB"*}"
      }

      cmd_attention() {
        local lim=20
        while [ "$#" -gt 0 ]; do
          case "$1" in
            --lim) lim="$2"; shift 2 ;;
            *) die "attention: unknown option: $1" ;;
          esac
        done
        api "$ARCHIVE/api/attention?lim=$lim" | table
      }

      cmd_hub() {
        api "$ARCHIVE/api/plugins" |
          jq -r '.[] | [.owner, (.open | tostring), (.resolved // 0 | tostring)] | @tsv' |
          while IFS="$TAB" read -r owner open resolved; do
            printf '%-24s open %-4s resolved %s\n' "$owner" "$open" "$resolved"
          done
      }

      # Closing closes every classifier's verdict, so it asks first: flake/policies.nix
      cmd_resolve() {
        local yes=0 id=""
        while [ "$#" -gt 0 ]; do
          case "$1" in
            -y | --yes) yes=1; shift ;;
            *) id="$1"; shift ;;
          esac
        done
        [ -n "$id" ] || die "resolve: need a message id"
        if [ "$yes" != 1 ]; then
          printf 'close %s? [y/N] ' "$id" >&2
          reply=""
          read -r reply || reply=""
          case "$reply" in y | Y | yes) ;; *) die "kept open" ;; esac
        fi
        api -X POST -H 'Content-Type: application/json' -d "$(jq -nc --arg m "$id" '{messageId: $m}')" \
          "$ARCHIVE/api/triage-resolve" | jq .
      }

      cmd_health() {
        api "$ARCHIVE/health" 2>/dev/null || die "the archive API is not answering at $ARCHIVE"
        say ""
        api "$ARCHIVE/openapi.json" | jq -r '"routes \(.paths | length)"'
      }

      cmd="''${1:-}"
      [ "$#" -gt 0 ] && shift
      case "$cmd" in
        ls | list) cmd_ls "$@" ;;
        q | search) cmd_q "$@" ;;
        body | show) cmd_body "$@" ;;
        open) cmd_open ;;
        attention) cmd_attention "$@" ;;
        hub | plugins) cmd_hub ;;
        resolve | close) cmd_resolve "$@" ;;
        health) cmd_health ;;
        -h | --help | help | "") usage ;;
        *) die "unknown command: $cmd (try: mail --help)" ;;
      esac
    '';
in {
  home.packages = [mail];
}
