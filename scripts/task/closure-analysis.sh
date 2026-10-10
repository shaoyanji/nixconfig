#!/usr/bin/env bash
# ==============================================================================
# CLOSURE ANALYSIS (store-DB, no nix eval) — generic across hosts
# ==============================================================================
# Answers "what is IN this system and what makes it big?" without evaluating any
# Nix code. Reads the store database via `nix path-info` (seconds) instead of
# `nix eval` on a NixOS configuration (imports every module — the reason
# `checks:quick` stopped being quick).
#
# Targeting:
#   default / --host local   the local /run/current-system
#   --host <name>            SSH-resolve that host's deployed /run/current-system,
#                            then read ITS store DB via `nix path-info
#                            --store ssh://<name>`. No eval; any reachable host.
#   <TARGET> (positional)    any store path, e.g. an old generation
#
# Subcommands:
#   size                     total closure size
#   top [N] [TARGET]         N biggest contributors by own (nar) size
#   subsystems [TARGET]      group into subsystems and total each
#   graph [TARGET]           subsystem breakdown as a terminal ASCII graph
#   dot [TARGET]             raw Graphviz DOT (pipe to dot/neato)
#   toml [TARGET]            nested tree (closure -> subsystem -> top packages)
#                            for handoff / agent-to-agent reports
#   diff A [B]               closure size deltas (B defaults to current-system)
#   tui                      interactive: pick host, then pick a view
#
# Flags: --host NAME  --store URI  --refresh
# ==============================================================================

set -euo pipefail

CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/nixconfig-closure"
mkdir -p "$CACHE_DIR"

REFRESH=0
HOST=""
STORE_URI=""
POS=()
while [ $# -gt 0 ]; do
  case "$1" in
    --host) HOST="${2:?--host needs a value}"; shift 2 ;;
    --host=*) HOST="${1#*=}"; shift ;;
    --store) STORE_URI="${2:?--store needs a value}"; shift 2 ;;
    --store=*) STORE_URI="${1#*=}"; shift ;;
    --refresh) REFRESH=1; shift ;;
    --help | -h) sed -n '3,27p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
    --*) echo "unknown flag: $1" >&2; exit 2 ;;
    *) POS+=("$1"); shift ;;
  esac
done
CMD="${POS[0]:-subsystems}"

SELF_HOST="$(hostname)"

# Remote resolution: SSH-resolve the deployed generation, read its store DB.
REMOTE_TARGET=""
if [ -z "$STORE_URI" ] && [ -n "$HOST" ] && [ "$HOST" != "local" ] && [ "$HOST" != "$SELF_HOST" ]; then
  REMOTE_TARGET="$(ssh -o BatchMode=yes -o ConnectTimeout=6 "$HOST" 'readlink -f /run/current-system' 2>/dev/null || true)"
  if [ -z "$REMOTE_TARGET" ]; then
    echo "Error: could not resolve /run/current-system on '${HOST}' (offline or no SSH)." >&2
    echo "For an unbooted host, target a built store path explicitly." >&2
    exit 1
  fi
  STORE_URI="ssh://${HOST}"
fi
NIX_ARGS=(--json --json-format 1)
[ -n "$STORE_URI" ] && NIX_ARGS+=(--store "$STORE_URI")

# target: remote generation if --host given, else positional (1-indexed after CMD)
target() {
  if [ -n "$REMOTE_TARGET" ]; then printf '%s' "$REMOTE_TARGET"; else printf '%s' "${POS[$1]:-/run/current-system}"; fi
}
human() { numfmt --to=iec-i --suffix=B --format="%.1f" "$1" 2>/dev/null || echo "$1"; }
host_label() { if [ -n "$REMOTE_TARGET" ]; then printf '%s' "$HOST"; else printf '%s' "$SELF_HOST"; fi; }

# Cache key carries a schema tag, so a change to the query flags/format
# invalidates old caches instead of silently serving stale-shaped data.
cache_key() { printf '%s|%s|json-v2' "$STORE_URI" "$1" | sha256sum | cut -c1-16; }

load_json() {
  local key cache
  key="$(cache_key "$1")"
  cache="$CACHE_DIR/$key.json"
  if [ "$REFRESH" = 1 ] || [ ! -s "$cache" ]; then nix path-info "${NIX_ARGS[@]}" --recursive "$1" >"$cache"; fi
  printf '%s' "$cache"
}
# path<TAB>narSize<TAB>closureSize
entries() {
  local key
  key="$(cache_key "$1")"
  load_json "$1" >/dev/null
  jq -r 'to_entries[] | [.key, (.value.narSize // 0), (.value.closureSize // 0)] | @tsv' "$CACHE_DIR/$key.json"
}
total_of() { entries "$1" | awk -F'\t' '{s+=$2} END{print s+0}'; }
count_of() { entries "$1" | wc -l | tr -d ' '; }

subsystem_of() {
  case "$1" in
    *linux-firmware* | *firmware*) echo "firmware" ;;
    *linux-* | *kernel* | *kmod*) echo "kernel" ;;
    *systemd* | *udev*) echo "systemd" ;;
    *glibc* | *gcc-* | *libstdc* | *binutils* | *libgcc*) echo "toolchain" ;;
    *python3* | *python-*) echo "python" ;;
    *perl*) echo "perl" ;;
    *nodejs* | *node-*) echo "node" ;;
    *rust* | *cargo* | *clippy*) echo "rust" ;;
    *go-* | *go1.* | *golang*) echo "go" ;;
    *llvm* | *clang*) echo "llvm" ;;
    *mesa* | *vulkan* | *libdrm* | *wayland* | *libGL* | *nvidia* | *rocm*) echo "graphics" ;;
    *qt* | *gtk* | *adwaita*) echo "gui-toolkit" ;;
    *font* | *noto* | *dejavu* | *freetype*) echo "fonts" ;;
    *ffmpeg* | *gstreamer* | *gst-* | *libav*) echo "media" ;;
    *jdk* | *jre* | *maven* | *gradle*) echo "java" ;;
    *torch* | *transformers* | *llama* | *onnx*) echo "ai" ;;
    nixos-system-* | *nix-2* | *nixos-*) echo "nix" ;;
    *) echo "other" ;;
  esac
}
# subsystem<TAB>size<TAB>name
annotated() {
  entries "$1" | awk -F'\t' '{n=$1; sub(/^[^-]*-/, "", n); print $2"\t"n}' |
    while IFS=$'\t' read -r size name; do printf '%s\t%s\t%s\n' "$(subsystem_of "$name")" "$size" "$name"; done
}
# subsystem<TAB>bytes<TAB>count  (sorted desc)
rollup() {
  annotated "$1" |
    awk -F'\t' '{b[$1]+=$2; c[$1]++} END{for (k in b) printf "%s\t%d\t%d\n", k, b[k], c[k]}' |
    sort -k2,2nr
}

do_size() {
  local t; t="$(target 1)"
  printf 'host:    %s\nclosure: %s\n' "$(host_label)" "$t"
  printf '  paths: %s\n  size:  %s (%s bytes)\n' "$(count_of "$t")" "$(human "$(total_of "$t")")" "$(total_of "$t")"
}

do_top() {
  local n="$1" t="$2"
  entries "$t" | sort -k2,2nr |
    awk -v n="$n" -F'\t' 'NR<=n {printf "%s\t%s\n", $2, $1}' |
    while IFS=$'\t' read -r size path; do printf '%12s  %s\n' "$(human "$size")" "${path##*/}"; done
}

do_subsystems() {
  local t="$1" total; total="$(total_of "$t")"
  rollup "$t" |
    while IFS=$'\t' read -r name size count; do
      printf '%12s  %5s%%  %4s pkgs  %s\n' "$(human "$size")" \
        "$(awk -v s="$size" -v t="$total" 'BEGIN{printf "%.1f", (t?100*s/t:0)}')" "$count" "$name"
    done
}

write_dot() {
  local out="$1" t="$2" total; total="$(total_of "$t")"
  {
    echo "digraph closure {"
    echo "  rankdir=LR;"
    echo "  node [shape=box, fontname=\"monospace\"];"
    printf '  root [label="%s:%s\\n%s"];\n' "$(host_label)" "$(basename "$t")" "$(human "$total")"
    rollup "$t" | awk 'NR<=16' |
      while IFS=$'\t' read -r name size count; do
        printf '  "%s" [label="%s\\n%s (%s)"];\n' "$name" "$name" "$(human "$size")" "$count"
        printf '  root -> "%s" [label="%s"];\n' "$name" "$(human "$size")"
      done
    echo "}"
  } >"$out"
}

do_toml() {
  local t="$1" tmp total
  tmp="$(mktemp)"; total="$(total_of "$t")"
  annotated "$t" >"$tmp"
  echo "# Closure static-analysis tree — generated by scripts/task/closure-analysis.sh"
  echo "# Do not edit by hand. Levels: closure -> subsystem -> top packages."
  printf '# Source: %s:%s\n\n' "$(host_label)" "$t"
  echo "[closure]"
  printf 'host = "%s"\n' "$(host_label)"
  printf 'system = "%s"\n' "$(basename "$t")"
  printf 'total_bytes = %s\n' "$total"
  printf 'path_count = %s\n\n' "$(count_of "$t")"
  awk -F'\t' '{b[$1]+=$2; c[$1]++} END{for (k in b) printf "%s\t%d\t%d\n", k, b[k], c[k]}' "$tmp" |
    sort -k2,2nr |
    while IFS=$'\t' read -r name size count; do
      printf '[closure.subsystems.%s]\nbytes = %s\npaths = %s\n' "$name" "$size" "$count"
      local rows
      rows="$(awk -F'\t' -v s="$name" '$1==s {printf "%s\t%s\n", $2, $3}' "$tmp" | sort -k1,1nr | awk -F'\t' 'NR<=8 {printf "  { name = \"%s\", bytes = %s },\n", $2, $1}')"
      [ -n "$rows" ] && printf 'top = [\n%s]\n' "$rows"
      echo
    done
  rm -f "$tmp"
}

do_tui() {
  command -v gum >/dev/null 2>&1 || { echo "gum required for tui" >&2; exit 1; }
  local hosts
  hosts="$({ echo "local"; [ -f inventory.toml ] && yq -r '.hosts | to_entries | .[] | select(.value.status == "active" and (.value.kind == "nixos" or .value.kind == "darwin")) | .key' inventory.toml; } 2>/dev/null)"
  while true; do
    clear 2>/dev/null || true
    local host view
    host="$(printf '%s\n' "$hosts" | gum filter --placeholder "Pick a host (local = this machine)..." --width 80)" || return 0
    [ -z "$host" ] && return 0
    view="$(printf '%s\n' "size" "top" "subsystems" "graph" "toml" "back" | gum choose --header "Closure view for '${host}':")" || return 0
    case "$view" in
      back) continue ;;
      top) bash "${BASH_SOURCE[0]}" --host "$host" top 20 | gum pager ;;
      size | subsystems | graph | toml) bash "${BASH_SOURCE[0]}" --host "$host" "$view" | gum pager ;;
    esac
  done
}

case "$CMD" in
  size) do_size ;;
  top)
    N="${POS[1]:-15}"; [[ "$N" =~ ^[0-9]+$ ]] || N=15
    do_top "$N" "$(target 2)"
    ;;
  subsystems) do_subsystems "$(target 1)" ;;
  graph)
    d="$CACHE_DIR/graph.$$.dot"; write_dot "$d" "$(target 1)"
    if command -v graph-easy >/dev/null 2>&1; then graph-easy --as=boxart "$d"; else cat "$d"; fi
    rm -f "$d"
    ;;
  dot) d="$CACHE_DIR/raw.$$.dot"; write_dot "$d" "$(target 1)"; cat "$d"; rm -f "$d" ;;
  toml) do_toml "$(target 1)" ;;
  tui) do_tui ;;
  diff)
    A="${POS[1]:-}"; B="${POS[2]:-/run/current-system}"
    [ -z "$A" ] && { echo "usage: closure-analysis.sh diff A [B]" >&2; exit 2; }
    nix store diff-closures "$A" "$B" | sort -t: -k2 -rn | tail -n 40
    ;;
  *) echo "unknown command: $CMD" >&2; exit 2 ;;
esac
