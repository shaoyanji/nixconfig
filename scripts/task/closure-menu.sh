#!/usr/bin/env bash
# ==============================================================================
# CLOSURE MENU — traversable closure explorer (gum TUI over the Nix-native graph)
# ==============================================================================
# The traversal front end for `closure-graph.sh data`. Every question the menu
# can answer is also a NON-INTERACTIVE subcommand that prints plain text to
# stdout, so it is testable, scriptable, and usable by agents — and so the gum
# layer can degrade cleanly when there is no TTY (gum needs /dev/tty, which is
# absent in a pipe, a CI job, or an agent's tool call).
#
# Numbers are never re-derived here. This script renders what
# `closure-graph.sh data` computed, and that payload is byte-parity-checked
# against the shell baseline by `dev:closure:native:diff`. So the menu, the
# gate, and `closure-analysis.sh` cannot disagree about a single byte.
#
# Usage:
#   closure-menu.sh [--host LABEL] [--root PATH] [--refresh] <command> [ARGS]
#
# Commands:
#   summary                 one screen: totals, subsystem table, worst dupes
#   subsystems              subsystem table only
#   list <SUBSYSTEM>        every package in a subsystem (size, name, path)
#   dups [N]                duplicate package groups ranked by wasted bytes
#   members <GROUP>         the concrete paths inside one duplicate group
#   reduce [N]              reduction report: top N duplicate groups WITH every
#                           concrete copy (so a pin/override can be chosen), plus
#                           the biggest subsystem buckets
#   why <QUERY>             why-depends chain root -> package (QUERY=name|path)
#   menu (default)          interactive gum explorer; degrades to `summary`
#                           when there is no TTY or no gum
#
# Flags: --host LABEL (label only)  --root PATH (default: /run/current-system)
#        --refresh (ignore the cached payload)
# ==============================================================================

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
GRAPH="${REPO_ROOT}/scripts/task/closure-graph.sh"
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/nixconfig-closure"
mkdir -p "$CACHE_DIR"

HOST="$(hostname)"
ROOT=""
REFRESH=0
POS=()
while [ $# -gt 0 ]; do
  case "$1" in
    --host) HOST="${2:?--host needs a value}"; shift 2 ;;
    --host=*) HOST="${1#*=}"; shift ;;
    --root) ROOT="${2:?--root needs a value}"; shift 2 ;;
    --root=*) ROOT="${1#*=}"; shift ;;
    --refresh) REFRESH=1; shift ;;
    --help | -h)
      # Print the comment header (title + body) and stop at the first
      # non-comment line, dropping trailing rule lines — so help tracks the
      # comment block above no matter how it is reworded.
      awk 'NR <= 2 { next }
           /^[^#]/ { exit }
           { rows[++n] = $0 }
           END {
             while (n > 0 && (rows[n] ~ /^# =+$/ || rows[n] ~ /^#?[ \t]*$/)) n--
             for (i = 1; i <= n; i++) { sub(/^# ?/, "", rows[i]); print rows[i] }
           }' "${BASH_SOURCE[0]}"
      exit 0
      ;;
    --*) echo "unknown flag: $1" >&2; exit 2 ;;
    *) POS+=("$1"); shift ;;
  esac
done
CMD="${POS[0]:-menu}"
ARG="${POS[1]:-}"

[ -f "$GRAPH" ] || { echo "error: missing ${GRAPH}" >&2; exit 1; }

ROOT_LABEL="${ROOT:-/run/current-system}"
GRAPH_ARGS=(--host "$HOST")
if [ -n "$ROOT" ]; then GRAPH_ARGS+=(--root "$ROOT"); fi

# ---------------------------------------------------------------------------
# Payload
# ---------------------------------------------------------------------------
# `sha256sum | cut -d' ' -f1` on stdin, with fallbacks for hosts that ship only
# `shasum` (macOS) or `openssl`.
sha256_sum() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum | cut -d' ' -f1
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 | cut -d' ' -f1
  else
    openssl dgst -sha256 | awk '{print $NF}'
  fi
}

# The cache key carries the generator's own hash, so editing closure-graph.sh
# invalidates a stale payload instead of silently serving last week's numbers.
payload() {
  local key cache tmp resolved
  # The key must follow the SYMLINK, not the label we were handed. After a
  # `nixos-rebuild switch` the label "/run/current-system" is unchanged while the
  # store path behind it is not, so a label-keyed cache keeps serving the
  # previous system's numbers — it reported the pre-switch 3949 paths / 34.5 GiB
  # straight after the 2026-10-10 deployment. Resolving first makes a switch
  # invalidate the cache for free.
  resolved="$(readlink -f "$ROOT_LABEL" 2>/dev/null || printf '%s' "$ROOT_LABEL")"
  key="$(printf '%s|%s|%s' "$resolved" "$HOST" "$(sha256_sum <"$GRAPH")" | sha256_sum)"
  cache="${CACHE_DIR}/menu-${key:0:16}.json"
  if [ "$REFRESH" = 1 ] || [ ! -s "$cache" ]; then
    tmp="$(mktemp)"
    bash "$GRAPH" "${GRAPH_ARGS[@]}" data >"$tmp"
    mv "$tmp" "$cache"
  fi
  printf '%s' "$cache"
}

# ---------------------------------------------------------------------------
# Renderers — text only, no gum, so every one of these is testable in a pipe
# ---------------------------------------------------------------------------
render_subsystems() {
  jq -r '.subsystems[] | [.bytesHuman, .percent, (.paths | tostring), .name] | @tsv' "$1" |
    awk -F'\t' '{ printf "%-10s %6s%% %7s  %s\n", $1, $2, $3, $4 }'
}

render_dups() {
  jq -r --argjson n "$2" '.duplicates[:$n][] | [.wastedHuman, (.count | tostring), .totalHuman, .name] | @tsv' "$1" |
    awk -F'\t' 'BEGIN { printf "%-9s %-7s %-9s  %s\n", "WASTED", "COPIES", "TOTAL", "GROUP" }
                { printf "%-9s x%-6s %-9s  %s\n", $1, $2, $3, $4 }'
}

render_members() {
  jq -r --arg n "$1" '.duplicates[] | select(.name == $n) | .members[]
    | [.narSizeHuman, .subsystem, .path] | @tsv' "$2" |
    awk -F'\t' 'BEGIN { printf "%-10s %-12s %s\n", "OWN SIZE", "SUBSYSTEM", "STORE PATH" }
                { printf "%-10s %-12s %s\n", $1, $2, $3 }'
}

render_list() {
  jq -r --arg s "$1" '.subsystems[] | select(.name == $s) | .pkgs[]
    | [.narSizeHuman, .name, .path] | @tsv' "$2" |
    awk -F'\t' 'BEGIN { printf "%-10s %-38s %s\n", "OWN SIZE", "PACKAGE", "STORE PATH" }
                { printf "%-10s %-38s %s\n", $1, $2, $3 }'
}

# Note on `jq ... | head`: forbidden here. Under `set -o pipefail` an early-closed
# pipe turns jq's SIGPIPE into a non-zero pipeline status and errexit kills the
# script. Every "first match" is therefore expressed as `[ ... ][0] // ""`
# inside jq, and every bounded listing as `awk 'NR <= n'`.

# ---------------------------------------------------------------------------
# why-depends / referrers
# ---------------------------------------------------------------------------
why_text() {
  local path="$1" out
  out="$(nix why-depends "$ROOT_PATH" "$path" 2>&1)" && {
    printf '%s\n' "$out"
    return 0
  }
  printf '%s\n' "$out"
  printf '\n(no chain traced: the path may not be reachable from %s)\n' "$ROOT_PATH"
}

referrers() {
  local path="$1"
  command -v nix-store >/dev/null 2>&1 || { echo "(nix-store unavailable)"; return 0; }
  local refs
  refs="$(nix-store -q --referrers "$path" 2>/dev/null || true)"
  if [ -z "$refs" ]; then
    echo "(no other path references it directly)"
  else
    printf '%s\n' "$refs" | awk 'NR <= 15 { print } END { if (NR > 15) printf "... and %d more\n", NR - 15 }'
  fi
}

package_detail() { # cache sub name path
  local cache="$1" sub="$2" name="$3" path="$4" size
  size="$(jq -r --arg p "$path" '([.subsystems[].pkgs[] | select(.path == $p)][0].narSizeHuman) // ""' "$cache")"
  {
    echo "subsystem : ${sub}"
    echo "package   : ${name}"
    echo "own size  : ${size}"
    echo "store path: ${path}"
    echo
    echo "--- why the system depends on it ---"
    why_text "$path"
    echo
    echo "--- direct referrers (what pulls it in) ---"
    referrers "$path"
  }
}

# ---------------------------------------------------------------------------
# Non-interactive commands
# ---------------------------------------------------------------------------
cmd_summary() {
  local cache
  cache="$(payload)"
  ROOT_PATH="$(jq -r '.rootPath' "$cache")"
  jq -r '"host:             \(.host)
closure:          \(.label)
paths:            \(.pathCount)
size:             \(.totalHuman) (\(.totalBytes) bytes)
subsystems:       \(.subsystems | length)
duplicate groups: \(.duplicates | length)
reclaimable:      \(.dupWastedHuman) (optimistic: collapse each group to one copy)"' "$cache"
  echo
  echo "subsystem breakdown:"
  render_subsystems "$cache" | sed 's/^/  /'
  echo
  echo "worst duplicate groups:"
  render_dups "$cache" 8 | sed 's/^/  /'
}

cmd_subsystems() {
  local cache
  cache="$(payload)"
  render_subsystems "$cache"
}

cmd_list() {
  local cache
  cache="$(payload)"
  if [ -z "$ARG" ]; then
    echo "pick a subsystem (exact name):" >&2
    render_subsystems "$cache" >&2
    exit 2
  fi
  if [ "$(jq -r --arg s "$ARG" '([.subsystems[] | select(.name == $s)][0].name) // ""' "$cache")" = "" ]; then
    echo "unknown subsystem: ${ARG}" >&2
    render_subsystems "$cache" >&2
    exit 2
  fi
  render_list "$ARG" "$cache"
}

cmd_dups() {
  local cache n
  cache="$(payload)"
  n="${ARG:-15}"
  [[ "$n" =~ ^[0-9]+$ ]] || n=15
  render_dups "$cache" "$n"
}

cmd_members() {
  local cache
  cache="$(payload)"
  if [ -z "$ARG" ]; then
    echo "usage: closure-menu.sh members <GROUP>   (GROUP from 'dups')" >&2
    exit 2
  fi
  if [ "$(jq -r --arg n "$ARG" '([.duplicates[] | select(.name == $n)][0].name) // ""' "$cache")" = "" ]; then
    echo "no duplicate group named: ${ARG}" >&2
    render_dups "$cache" 15 >&2
    exit 2
  fi
  render_members "$ARG" "$cache"
}

cmd_why() {
  local cache path hits
  cache="$(payload)"
  ROOT_PATH="$(jq -r '.rootPath' "$cache")"
  if [ -z "$ARG" ]; then
    echo "usage: closure-menu.sh why <QUERY>   (package name, or a store path)" >&2
    exit 2
  fi
  if [[ "$ARG" == /nix/store/* ]]; then
    path="$ARG"
  else
    path="$(jq -r --arg q "$ARG" \
      '([.subsystems[].pkgs[] | select(.name == $q or .base == $q or (.name | contains($q)))][0].path) // ""' "$cache")"
    hits="$(jq -r --arg q "$ARG" \
      '[.subsystems[].pkgs[] | select(.name == $q or .base == $q or (.name | contains($q)))] | length' "$cache")"
  fi
  if [ -z "$path" ]; then
    echo "no closure path matches '${ARG}'" >&2
    exit 1
  fi
  [ "${hits:-1}" -le 1 ] || echo "# '${ARG}' matched ${hits} paths; showing the first"
  echo "target: ${path}"
  echo
  why_text "$path"
}

cmd_reduce() {
  local cache n
  cache="$(payload)"
  n="${ARG:-10}"
  [[ "$n" =~ ^[0-9]+$ ]] || n=10
  # Every member is printed, not just the group total: a group is only a
  # *candidate* until a human confirms which copy is the redundant one, and the
  # choice is made by looking at the concrete store paths.
  jq -r --argjson n "$n" '
    "reclaimable (optimistic): \(.dupWastedHuman) of \(.totalHuman) - \(.duplicates | length) duplicate groups",
    "\(.totalHuman) across \(.pathCount) paths in \(.subsystems | length) subsystems",
    "",
    "top \($n) duplicate groups - every concrete copy, so a pin can be chosen:",
    "",
    (.duplicates[:$n][] |
      "-- \(.name)   \(.wastedHuman) reclaimable of \(.totalHuman) across \(.count) copies",
      (.members[] | "     \(.narSizeHuman)  \(.subsystem)  \(.path)")
    ),
    "",
    "largest subsystem buckets (the coarse other bucket is the standing invitation for a finer split):",
    (.subsystems[:3][] | "  \(.bytesHuman)  \(.percent)%  \(.paths) pkgs  \(.name)")
  ' "$cache"
}

# ---------------------------------------------------------------------------
# Interactive traversal (gum)
# ---------------------------------------------------------------------------
drill_subsystems() { # cache
  local cache="$1" sub pkg path name
  sub="$(jq -r '.subsystems[].name' "$cache" | gum filter --placeholder "Pick a subsystem..." --width 60)" || return 0
  [ -n "$sub" ] || return 0
  pkg="$(render_list "$sub" "$cache" | gum filter --placeholder "Pick a package in '${sub}'..." --width 100)" || return 0
  [ -n "$pkg" ] || return 0
  path="$(printf '%s\n' "$pkg" | awk '{ print $NF }')"
  name="$(jq -r --arg p "$path" '([.subsystems[].pkgs[] | select(.path == $p)][0].name) // ""' "$cache")"
  package_detail "$cache" "$sub" "$name" "$path" | gum pager
}

drill_duplicates() { # cache
  local cache="$1" grp
  grp="$(render_dups "$cache" 60 | gum filter --placeholder "Pick a duplicate group..." --width 90)" || return 0
  [ -n "$grp" ] || return 0
  case "$grp" in
    WASTED* | "") return 0 ;;
  esac
  {
    echo "duplicate group: $(printf '%s\n' "$grp" | awk '{ print $NF }')"
    echo
    render_members "$(printf '%s\n' "$grp" | awk '{ print $NF }')" "$cache"
  } | gum pager
}

drill_why() { # cache
  local cache="$1" q path hits
  q="$(gum input --placeholder "package name (e.g. libreoffice, immich, torch)")" || return 0
  [ -n "$q" ] || return 0
  path="$(jq -r --arg q "$q" \
    '([.subsystems[].pkgs[] | select(.name == $q or .base == $q or (.name | contains($q)))][0].path) // ""' "$cache")"
  if [ -z "$path" ]; then
    printf 'no closure path matches %s\n' "$q" | gum pager
    return 0
  fi
  hits="$(jq -r --arg q "$q" \
    '[.subsystems[].pkgs[] | select(.name == $q or .base == $q or (.name | contains($q)))] | length' "$cache")"
  {
    [ "$hits" -le 1 ] || echo "# matched ${hits} paths; showing the first"
    echo "target: ${path}"
    echo
    why_text "$path"
  } | gum pager
}

cmd_menu() {
  if [ ! -t 0 ] || [ ! -t 1 ] || ! command -v gum >/dev/null 2>&1; then
    {
      echo "! no TTY or no gum available - falling back to the non-interactive summary."
      echo "! drive it directly instead:"
      echo "!   closure-menu.sh list <SUBSYSTEM>"
      echo "!   closure-menu.sh dups [N]"
      echo "!   closure-menu.sh members <GROUP>"
      echo "!   closure-menu.sh why <QUERY>"
      echo
    } >&2
    cmd_summary
    return 0
  fi

  local cache
  cache="$(payload)"
  ROOT_PATH="$(jq -r '.rootPath' "$cache")"

  while true; do
    clear 2>/dev/null || true
    gum style --border normal --padding "0 1" --border-foreground 99 \
      "Closure explorer" \
      "$(jq -r '"\(.host): \(.label)"' "$cache")" \
      "$(jq -r '"\(.totalHuman) across \(.pathCount) paths - \(.subsystems | length) subsystems"' "$cache")" \
      "$(jq -r '"duplicate waste (optimistic): \(.dupWastedHuman) in \(.duplicates | length) groups"' "$cache")"

    local view
    view="$(gum choose --header "What do you want to see?" \
      "Subsystems - drill subsystem -> package -> why" \
      "Duplicates - reclaimable size groups" \
      "Why does this exist? - dependency chain for a package" \
      "Graph - subsystem ASCII graph" \
      "Quit")" || return 0

    case "$view" in
      Subsystems*) drill_subsystems "$cache" ;;
      Duplicates*) drill_duplicates "$cache" ;;
      Why*) drill_why "$cache" ;;
      Graph*)
        bash "$GRAPH" "${GRAPH_ARGS[@]}" graph | gum pager
        ;;
      *) return 0 ;;
    esac
  done
}

# ---------------------------------------------------------------------------
# Dispatch
# ---------------------------------------------------------------------------
ROOT_PATH=""
case "$CMD" in
  summary) cmd_summary ;;
  subsystems) cmd_subsystems ;;
  list) cmd_list ;;
  dups) cmd_dups ;;
  members) cmd_members ;;
  reduce) cmd_reduce ;;
  why) cmd_why ;;
  menu | tui) cmd_menu ;;
  *) echo "unknown command: $CMD" >&2; exit 2 ;;
esac
