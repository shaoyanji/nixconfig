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
#   budget [TARGET]          check a host's closure against its DYNAMIC budget
#                            (baseline × (1 + headroom), or an absolute pin)
#                            in closure-budgets.toml (HC-4); --all checks every
#                            host that has an entry
#   adopt                    measure a host and rewrite the managed baseline
#                            block in closure-budgets.toml (the ratchet);
#                            local by default, `--remote` for any reachable host
#   tui                      interactive: pick host, then pick a view
#
# Flags: --host NAME  --store URI  --refresh  --all  --remote
# Env:   HEADROOM_PCT=<n>   one-off headroom for a budget check
#        BUDGETS_FILE=<p>   alternate budget file (default closure-budgets.toml)
# ==============================================================================

set -euo pipefail

CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/nixconfig-closure"
mkdir -p "$CACHE_DIR"

REFRESH=0
ALL=0
REMOTE=0
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
    --all) ALL=1; shift ;;
    --remote) REMOTE=1; shift ;;
    --help | -h) sed -n '3,31p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
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

# Resolve a LOCAL root symlink before it becomes a cache key. The default
# target is /run/current-system, which is the SAME string on every generation;
# hashing it unresolved pinned the cache to the first generation ever measured,
# so `dev:closure:*` silently described a week-old system (measured 2026-10-17:
# cached report said 3949 paths / 34.5 GiB while the live closure was 3229
# paths). A remote store URI is left untouched — its target is the remote path.
resolve_target() {
  local t="$1"
  if [ -z "$STORE_URI" ] && [ -e "$t" ]; then
    readlink -f "$t" 2>/dev/null || printf '%s' "$t"
  else
    printf '%s' "$t"
  fi
}

load_json() {
  local key cache t
  t="$(resolve_target "$1")"
  key="$(cache_key "$t")"
  cache="$CACHE_DIR/$key.json"
  if [ "$REFRESH" = 1 ] || [ ! -s "$cache" ]; then nix path-info "${NIX_ARGS[@]}" --recursive "$t" >"$cache"; fi
  printf '%s' "$cache"
}
# path<TAB>narSize<TAB>closureSize
entries() {
  local key t
  t="$(resolve_target "$1")"
  key="$(cache_key "$t")"
  load_json "$t" >/dev/null
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
    *torch* | *transformers* | *llama* | *onnx* | *triton*) echo "ai" ;;
    # Attribution buckets added 2026-10-17, after they held the largest single
    # items in the frieren closure and were all landing in `other`: tessdata
    # `all` (1.0 GiB), libreoffice (1.5 GiB), electron pairs (0.7 GiB),
    # chromium/zen browsers (1.1 GiB).
    *tesseract* | *tessdata*) echo "ocr" ;;
    *libreoffice* | *onlyoffice*) echo "office" ;;
    *electron*) echo "electron" ;;
    *chromium* | *firefox* | *zen-*) echo "browser" ;;
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

# --- HC-4: closure budgets ----------------------------------------------------
# A "budget" is the sum of nar sizes of a host's closure — exactly what `size`
# prints — read from closure-budgets.toml through yq (the repo's TOML tool). The
# point is regression: the debloat work (docs/closure-reduction.md) has no way to
# notice a closure quietly growing back.
BUDGETS_FILE="${BUDGETS_FILE:-closure-budgets.toml}"

budget_host() {
  if [ -n "$HOST" ] && [ "$HOST" != "local" ]; then printf '%s' "$HOST"; else printf '%s' "$SELF_HOST"; fi
}

# Headroom policy: HEADROOM_PCT env > [hosts.<h>.headroom_pct] > [defaults].
default_pct() { yq -r '.defaults.headroom_pct // 1.0' "$BUDGETS_FILE" 2>/dev/null || echo 1.0; }

budget_pct() { # host -> percent
  local h="$1" pct
  if [ -n "${HEADROOM_PCT:-}" ]; then
    printf '%s' "$HEADROOM_PCT"
    return
  fi
  pct="$(yq -r ".hosts.\"$h\".headroom_pct // \"\"" "$BUDGETS_FILE" 2>/dev/null)"
  if [ -z "$pct" ] || [ "$pct" = "null" ]; then pct="$(default_pct)"; fi
  printf '%s' "$pct"
}

budget_baseline() { yq -r ".hosts.\"$1\".baseline.bytes // \"\"" "$BUDGETS_FILE" 2>/dev/null; }

# budget spec for a host as "bytes<TAB>basis"; empty when the host has neither a
# pin nor an adopted baseline. The basis column is what makes the number
# auditable: a pin and a base+% ceiling are different promises.
budget_spec() { # host
  local h="$1" pin base pct
  pin="$(yq -r ".hosts.\"$h\".bytes // \"\"" "$BUDGETS_FILE" 2>/dev/null)"
  if [ -n "$pin" ] && [ "$pin" != "null" ]; then
    printf '%s\tpin\n' "$pin"
    return
  fi
  base="$(budget_baseline "$h")"
  if [ -z "$base" ] || [ "$base" = "null" ]; then return 0; fi
  pct="$(budget_pct "$h")"
  printf '%s\tbase+%s%%\n' "$(awk -v b="$base" -v p="$pct" 'BEGIN{printf "%d", b*(1+p/100)}')" "$pct"
}

budget_header() {
  echo "=== closure budget — ${BUDGETS_FILE} (dynamic: baseline × (1 + headroom)) ==="
  printf '%-14s %12s %12s  %-12s  %s\n' "host" "budget" "actual" "basis" "status"
}

# One table row. Returns 1 when the host is over budget — the failure this whole
# subcommand exists to surface.
budget_line() { # host actual-bytes
  local h="$1" actual="$2" spec budget basis delta pct
  spec="$(budget_spec "$h")"
  if [ -z "$spec" ]; then
    printf '%-14s %12s %12s  %-12s  %s\n' \
      "$h" "-" "$(human "$actual")" "-" "NOT BUDGETED (task dev:closure:budget:adopt HOST=$h)"
    return 0
  fi
  IFS=$'\t' read -r budget basis <<<"$spec"
  delta=$((actual - budget))
  if [ "$delta" -le 0 ]; then
    printf '%-14s %12s %12s  %-12s  %s\n' \
      "$h" "$(human "$budget")" "$(human "$actual")" "$basis" "OK ($(human "$((-delta))") under)"
    return 0
  fi
  pct="$(awk -v d="$delta" -v b="$budget" 'BEGIN{printf "%.1f", (b?100*d/b:0)}')"
  printf '%-14s %12s %12s  %-12s  %s\n' \
    "$h" "$(human "$budget")" "$(human "$actual")" "$basis" "OVER by $(human "$delta") (${pct}%)"
  return 1
}

# Adopt the local host's measured closure as its new baseline. The measurement is
# written into the managed block, so this file's policy/comments survive.
do_budget_adopt() {
  local h actual on block merged remote_t=""
  h="$(budget_host)"
  if [ "$h" = "local" ] || [ "$h" = "$SELF_HOST" ]; then
    h="$SELF_HOST"
    actual="$(total_of "$(target 1)")"
  else
    # A remote baseline must be MEASURED there, never inferred from this machine.
    # Without --remote the old refusal stands: recording frieren's closure under
    # `eisen` would be a plausible-looking number that describes the wrong host.
    [ "$REMOTE" = 1 ] || {
      echo "adopt measures the LOCAL closure only (got '$h')." >&2
      echo "  Meant the remote host? re-run with --remote (reads ITS store DB over ssh)." >&2
      exit 2
    }
    remote_t="$(ssh -o BatchMode=yes -o ControlMaster=no -o ConnectTimeout=6 "$h" 'readlink -f /run/current-system' 2>/dev/null || true)"
    [ -n "$remote_t" ] || {
      echo "Error: cannot resolve /run/current-system on '$h' (offline, no SSH, or no store access); nothing adopted." >&2
      exit 1
    }
    actual="$(total_of_store "ssh://$h" "$remote_t")"
    [ "${actual:-0}" -gt 0 ] || {
      echo "Error: measured 0 bytes on '$h' ($remote_t); refusing to adopt an empty closure." >&2
      exit 1
    }
    echo "measured $h → $remote_t over ssh"
  fi
  [ -f "$BUDGETS_FILE" ] || { echo "missing $BUDGETS_FILE" >&2; exit 2; }
  on="$(date +%F)"
  block="$(mktemp)"
  merged="$(mktemp)"
  {
    # The adopted host is EXCLUDED here, not deduped afterwards. `!seen[$1]++`
    # kept the first row, and this read is printed before the new measurement —
    # so re-adopting an existing host used to leave its old baseline in place
    # while reporting success (found 2026-10-19 by adopting frieren: file still
    # said 32,104,328,080 after a 30,689,043,280 run).
    ADOPT_HOST="$h" yq -r '.hosts | to_entries[] | select(.value.baseline.bytes and .key != strenv(ADOPT_HOST)) | [.key, .value.baseline.bytes, (.value.baseline.measured_on // "")] | @tsv' "$BUDGETS_FILE"
    printf '%s\t%s\t%s\n' "$h" "$actual" "$on"
  } | awk -F'\t' '!seen[$1]++' | sort -k1,1 |
    while IFS=$'\t' read -r host bytes date; do
      # `yq` prints ONE EMPTY LINE when its expression matches nothing, and an
      # empty line splits into three empty fields — which emitted a literal
      # `[hosts..baseline]` table and made the file unparseable. Skipping blank
      # rows is what keeps a first-ever adoption (zero existing baselines from
      # other hosts) from corrupting the file.
      [ -n "$host" ] || continue
      printf '[hosts.%s.baseline]\nbytes = %s\nmeasured_on = "%s"\n\n' "$host" "$bytes" "$date"
    done > "$block"
  # Splice the managed block; append it when the markers are not there yet.
  BLOCK="$block" awk '
    /^# >>> baseline/ {
      print
      while ((getline line < ENVIRON["BLOCK"]) > 0) print line
      print "# <<< baseline"
      skipping = 1
      drop = 0
      next
    }
    /^# <<< baseline/ { skipping = 0; next }
    skipping { next }
    # A stray [hosts.<h>.baseline] table outside the managed block would be a
    # duplicate definition once the block carries that host; the block owns
    # baselines, so drop the stray table (its values were merged above).
    /^\[hosts\.[A-Za-z0-9:_-]+\.baseline\]/ { drop = 1; next }
    drop && /^\[/ { drop = 0 }
    drop { next }
    { print }
  ' "$BUDGETS_FILE" > "$merged"
  if ! grep -q '^# >>> baseline' "$merged"; then
    { echo; echo '# >>> baseline (managed by `task dev:closure:budget:adopt` — do not edit)'; cat "$block"; echo '# <<< baseline'; } >> "$merged"
  fi
  mv "$merged" "$BUDGETS_FILE"
  rm -f "$block"
  # Prove the number landed. A splice that keeps an older value is exactly the
  # failure the ratchet exists to prevent, and it used to report success doing it.
  if [ "$(budget_baseline "$h")" != "$actual" ]; then
    echo "Error: the adopted value did not land in $BUDGETS_FILE (found '$(budget_baseline "$h")', expected '$actual')." >&2
    exit 1
  fi
  echo "adopted $h baseline: $(human "$actual") ($actual bytes) on $on"
  # `do_budget` would re-measure the LOCAL target; the row must describe the host
  # this run just measured, so the number is passed through instead.
  do_budget "$actual"
}

# total narSize of a target read from a named store URI — used by --all, which
# must read several hosts' store DBs in one run (the single-host path reuses the
# globals set from --host and so goes through total_of).
total_of_store() { # store-uri target
  local uri="$1" t="$2" key cache
  key="$(printf '%s|%s|json-v2' "$uri" "$t" | sha256sum | cut -c1-16)"
  cache="$CACHE_DIR/$key.json"
  if [ "$REFRESH" = 1 ] || [ ! -s "$cache" ]; then
    if [ -n "$uri" ]; then
      nix path-info --json --json-format 1 --store "$uri" --recursive "$t" >"$cache"
    else
      nix path-info --json --json-format 1 --recursive "$t" >"$cache"
    fi
  fi
  jq -r 'to_entries[] | (.value.narSize // 0)' "$cache" | awk '{s+=$1} END{print s+0}'
}

do_budget() {
  local actual="${1:-}"
  [ -n "$actual" ] || actual="$(total_of "$(target 1)")"
  budget_header
  budget_line "$(budget_host)" "$actual"
}

do_budget_all() {
  local h t actual rc=0
  budget_header
  while IFS= read -r h; do
    [ -n "$h" ] || continue
    if [ "$h" = "$SELF_HOST" ]; then
      actual="$(total_of "/run/current-system")"
    else
      t="$(ssh -o BatchMode=yes -o ConnectTimeout=6 "$h" 'readlink -f /run/current-system' 2>/dev/null || true)"
      if [ -z "$t" ]; then
        printf '%-14s %14s %14s  skipped (unreachable)\n' "$h" "-" "-"
        continue
      fi
      actual="$(total_of_store "ssh://${h}" "$t")"
    fi
    budget_line "$h" "$actual" || rc=1
  done < <(yq -r '.hosts | keys[]' "$BUDGETS_FILE")
  return "$rc"
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
  adopt)
    [ -f "$BUDGETS_FILE" ] || { echo "Error: '$BUDGETS_FILE' not found (run from the repo root, or set BUDGETS_FILE)." >&2; exit 2; }
    command -v yq >/dev/null 2>&1 || { echo "Error: yq is required for budget updates." >&2; exit 2; }
    do_budget_adopt
    ;;
  budget)
    [ -f "$BUDGETS_FILE" ] || { echo "Error: '$BUDGETS_FILE' not found (run from the repo root, or set BUDGETS_FILE)." >&2; exit 2; }
    command -v yq >/dev/null 2>&1 || { echo "Error: yq is required for budget lookups." >&2; exit 2; }
    if [ "$ALL" = 1 ]; then do_budget_all || exit 1; else do_budget || exit 1; fi
    ;;
  tui) do_tui ;;
  diff)
    A="${POS[1]:-}"; B="${POS[2]:-/run/current-system}"
    [ -z "$A" ] && { echo "usage: closure-analysis.sh diff A [B]" >&2; exit 2; }
    nix store diff-closures "$A" "$B" | sort -t: -k2 -rn | tail -n 40
    ;;
  *) echo "unknown command: $CMD" >&2; exit 2 ;;
esac
