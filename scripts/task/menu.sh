#!/usr/bin/env bash
# ==============================================================================
# TASK CONTROL PLANE (TUI)
# ==============================================================================
# A Charmbracelet Gum front end over the ENTIRE Taskfile, in the spirit of
# scripts/task/inventory-menu.sh and modules-menu.sh — but with a single
# control-plane source: the Taskfile itself, surfaced through `task --list-all
# --json`. Nothing here hardcodes a second menu tree, so the two front ends can
# never drift apart:
#
#   human    — themed, grouped by namespace, styled cards, descriptions
#   operator — flat and fast: exact task names for scripted/agent operation
#   --json   — the normalised control plane, for machines
#   --list   — the normalised control plane, as a flat TSV
#
# Usage:
#   scripts/task/menu.sh [human|operator]   # interactive TUI
#   scripts/task/menu.sh --json             # machine-readable control plane
#   scripts/task/menu.sh --list             # flat name<TAB>desc listing
# ==============================================================================

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TASKFILE="${REPO_ROOT}/Taskfile.yml"

MODE="human"
case "${1:-}" in
  human | "") MODE="human" ;;
  operator | machine | ops) MODE="operator" ;;
  --json) MODE="json" ;;
  --list) MODE="list" ;;
  -h | --help)
    sed -n '2,22p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
    exit 0
    ;;
  *)
    echo "Unknown mode: $1 (expected human|operator|--json|--list)" >&2
    exit 2
    ;;
esac

if [ ! -f "$TASKFILE" ]; then
  echo "Error: Taskfile not found at $TASKFILE" >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# Control-plane source: the Taskfile, via task's own JSON. Read exactly once.
# ---------------------------------------------------------------------------
CONTROL_JSON="$(task --taskfile "$TASKFILE" --list-all --json)"

# namespace  name  desc   (namespace = prefix before ':', or "root")
read_plane() {
  printf '%s' "$CONTROL_JSON" | jq -r '
    .tasks[]
    | (.name | tostring) as $n
    | (if ($n | contains(":")) then ($n | split(":")[0]) else "root" end) as $ns
    | [$ns, $n, (.desc // "")] | @tsv'
}

# Friendly titles for the namespaces that exist in the Taskfile.
theme_title() {
  case "$1" in
    root) echo "🏠 root & misc" ;;
    infra) echo "🛠️  infrastructure & hosts" ;;
    checks) echo "✅ validation & checks" ;;
    dev) echo "🧑‍💻 dev · git · flake" ;;
    agents) echo "🕹️  operator menus" ;;
    data) echo "🗄️  NAS data & storage" ;;
    services) echo "🧩 services (legacy)" ;;
    apps) echo "📄 job applications" ;;
    moto) echo "📱 moto (Termux)" ;;
    serv00) echo "🌐 serv00 (FreeBSD)" ;;
    dragoncourt) echo "🌐 dragoncourt (Alwaysdata)" ;;
    envs) echo "🌐 envs.net" ;;
    bountystash) echo "💰 bountystash" ;;
    lifecycle) echo "♻️  lifecycle" ;;
    inventory) echo "📋 inventory control plane" ;;
    modules) echo "⚙️  control knobs" ;;
    boot) echo "🚀 boot" ;;
    switch) echo "🔄 switch" ;;
    *) echo "• $1" ;;
  esac
}

# Deterministic theme order: the ones above first, then anything new.
theme_order() {
  case "$1" in
    root) echo 00 ;;
    infra) echo 01 ;;
    checks) echo 02 ;;
    dev) echo 03 ;;
    agents) echo 04 ;;
    data) echo 05 ;;
    services) echo 06 ;;
    apps) echo 07 ;;
    moto | serv00 | dragoncourt | envs | bountystash) echo 08 ;;
    lifecycle) echo 09 ;;
    inventory | modules) echo 10 ;;
    boot | switch) echo 11 ;;
    *) echo 99 ;;
  esac
}

list_themes() {
  read_plane | cut -f1 | sort | uniq -c | while read -r count ns; do
    printf '%s\t%s\t%s\n' "$(theme_order "$ns")" "$ns" "$count"
  done | sort -k1,1 -k2,2 | while IFS=$'\t' read -r _ ns count; do
    printf '%s\t%d\n' "$ns" "$count"
  done
}

# ---------------------------------------------------------------------------
# Non-interactive outputs (the machine-operator surface)
# ---------------------------------------------------------------------------
if [ "$MODE" = "json" ]; then
  read_plane | jq -Rn '
    [inputs | split("\t") | {namespace: .[0], name: .[1], desc: .[2]}]
    | {source: "Taskfile.yml", task_count: length, tasks: .}'
  exit 0
fi

if [ "$MODE" = "list" ]; then
  read_plane
  exit 0
fi

# ---------------------------------------------------------------------------
# Interactive modes need gum
# ---------------------------------------------------------------------------
if ! command -v gum >/dev/null 2>&1; then
  echo "Error: 'gum' is required for the interactive menu (run within devShell)." >&2
  exit 1
fi

run_task() {
  local name="$1"
  # A wildcard task (`infra:plan:host:*`) cannot be invoked literally: Task has
  # no `.MATCH` to bind and dies with "slice index out of range". Ask for the
  # value and splice it into the name instead.
  if [[ "$name" == *":*" ]]; then
    local match
    match="$(gum input --placeholder "Value for the '*' in '${name}' (e.g. poseidon)" || true)"
    [ -z "${match// /}" ] && return 0
    name="${name%:*}:${match}"
  fi
  local args
  args="$(gum input --placeholder "Extra args for '${name}' (leave empty to just run)" || true)"
  echo ""
  if [ -n "${args// /}" ]; then
    echo "→ task ${name} ${args}"
    # shellcheck disable=SC2086  # deliberate word-splitting into task args
    (cd "$REPO_ROOT" && task "$name" $args) || gum style --foreground 196 "✗ task '${name}' exited non-zero."
  else
    echo "→ task ${name}"
    (cd "$REPO_ROOT" && task "$name") || gum style --foreground 196 "✗ task '${name}' exited non-zero."
  fi
  echo ""
  read -r -p "Press Enter to return to the menu..." || true
}

# --- human: themed browse -------------------------------------------------
human_theme_menu() {
  local ns="$1"
  while true; do
    clear 2>/dev/null || true
    gum style --border rounded --padding "0 1" --border-foreground 212 \
      "$(theme_title "$ns")" \
      "$(read_plane | awk -F'\t' -v ns="$ns" '$1==ns {c++} END{print (c+0)" tasks"}')"
    echo ""
    local selected
    selected="$(read_plane | awk -F'\t' -v ns="$ns" '$1==ns {printf "%s\t%s\n", $2, $3}' \
      | gum filter --placeholder "Filter ${ns} tasks..." --width 110 || true)"
    [ -z "$selected" ] && break
    local name="${selected%%$'\t'*}"
    [ -n "$name" ] && run_task "$name"
  done
}

human_main_menu() {
  while true; do
    clear 2>/dev/null || true
    local total
    total="$(read_plane | wc -l | tr -d ' ')"
    gum style --border rounded --padding "0 1" --border-foreground 99 \
      "🎛️  TASK CONTROL PLANE (Taskfile.yml)" \
      "${total} tasks · source: task --list-all --json"
    echo ""
    local choice
    choice="$(list_themes | while IFS=$'\t' read -r ns count; do
      printf '%s (%s)\n' "$(theme_title "$ns")" "$count"
    done | gum choose --header "Select a theme:" || true)"
    [ -z "$choice" ] && exit 0
    # map the labelled choice back to the namespace
    local ns
    ns="$(list_themes | while IFS=$'\t' read -r n count; do
      printf '%s\t%s (%s)\n' "$n" "$(theme_title "$n")" "$count"
    done | awk -F'\t' -v want="$choice" '$2==want {print $1}')"
    [ -n "$ns" ] && human_theme_menu "$ns"
  done
}

# --- operator: flat, fast -------------------------------------------------
operator_menu() {
  while true; do
    clear 2>/dev/null || true
    gum style --border rounded --padding "0 1" --border-foreground 42 \
      "⚙️  TASK CONTROL PLANE — operator" \
      "flat view; exact task names"
    echo ""
    local selected
    selected="$(read_plane | awk -F'\t' '{printf "%-46s %s\n", $2, $3}' \
      | gum filter --placeholder "Type to filter tasks by name..." --width 120 || true)"
    [ -z "$selected" ] && break
    local name
    name="$(printf '%s' "$selected" | awk '{print $1}')"
    [ -n "$name" ] && run_task "$name"
  done
}

if [ "$MODE" = "operator" ]; then
  operator_menu
else
  human_main_menu
fi
