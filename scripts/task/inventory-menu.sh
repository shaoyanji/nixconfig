#!/usr/bin/env bash
# ==============================================================================
# INVENTORY CONTROL PLANE (TUI)
# ==============================================================================
# Interactive Charmbracelet Gum interface for browsing and editing inventory.toml
# Backed by fast, native yq for in-place TOML AST manipulations.
# ==============================================================================

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
INVENTORY_FILE="${REPO_ROOT}/inventory.toml"

if ! command -v gum >/dev/null 2>&1; then
  echo "Error: 'gum' is required for the interactive inventory menu." >&2
  echo "Ensure gum is installed or run within devShell." >&2
  exit 1
fi

if ! command -v yq >/dev/null 2>&1; then
  echo "Error: 'yq' (mikefarah/yq) is required for inventory manipulation." >&2
  exit 1
fi

list_hosts() {
  yq -r '.hosts | to_entries | .[] | 
    [
      .key,
      .value.status,
      .value.kind,
      (if .value.status != "active" or (.value.kind != "nixos" and .value.kind != "darwin" and .value.kind != "home") then "N/A" elif .value.ci == false then "off" else "on" end),
      .value.role
    ] | @tsv' "$INVENTORY_FILE" | awk -F'\t' '{printf "%-13s [%-9s | %-6s | CI: %-3s] %s\n", $1, $2, $3, $4, $5}'
}

update_metadata_counts() {
  yq -i '
    .metadata.total_devices = (.hosts | length) |
    .metadata.active_nix_devices = ([.hosts[] | select(.status == "active" and (.kind == "nixos" or .kind == "darwin" or .kind == "home"))] | length) |
    .metadata.active_external_devices = ([.hosts[] | select(.status == "active" and .kind != "nixos" and .kind != "darwin" and .kind != "home")] | length) |
    .metadata.wip_devices = ([.hosts[] | select(.status == "wip")] | length) |
    .metadata.preserved_devices = ([.hosts[] | select(.status == "preserved")] | length)
  ' "$INVENTORY_FILE"
}

show_host_card() {
  local host="$1"
  local status kind arch role model cpu
  status=$(yq -r ".hosts.${host}.status // \"unknown\"" "$INVENTORY_FILE")
  kind=$(yq -r ".hosts.${host}.kind // \"unknown\"" "$INVENTORY_FILE")
  arch=$(yq -r ".hosts.${host}.arch // \"unknown\"" "$INVENTORY_FILE")
  role=$(yq -r ".hosts.${host}.role // \"\"" "$INVENTORY_FILE")
  model=$(yq -r ".hosts.${host}.hardware.model // \"Generic\"" "$INVENTORY_FILE")
  cpu=$(yq -r ".hosts.${host}.hardware.cpu // \"\"" "$INVENTORY_FILE")

  local ci_label
  if [ "$status" != "active" ] || { [ "$kind" != "nixos" ] && [ "$kind" != "darwin" ] && [ "$kind" != "home" ]; }; then
    ci_label="N/A (not an active Nix host)"
  elif [ "$(yq ".hosts.${host}.ci == false" "$INVENTORY_FILE")" = "true" ]; then
    ci_label="🔴 EXCLUDED (ci = false in inventory.toml)"
  else
    ci_label="🟢 ENABLED (absence of ci = false; builds automatically in CI)"
  fi

  gum style --border normal --padding "0 1" --border-foreground 99 \
    "Host: ${host}" \
    "Status: ${status} | Kind: ${kind} | Arch: ${arch}" \
    "CI Status: ${ci_label}" \
    "Role: ${role}" \
    "Hardware: ${model}${cpu:+ ($cpu)}"
}

host_menu() {
  local host="$1"
  while true; do
    clear 2>/dev/null || true
    show_host_card "$host"
    echo ""

    local ci_action_label
    if [ "$(yq ".hosts.${host}.ci == false" "$INVENTORY_FILE")" = "true" ]; then
      ci_action_label="toggle-ci: Re-enable CI (remove ci = false)"
    else
      ci_action_label="toggle-ci: Exclude from CI (set ci = false)"
    fi

    action=$(printf '%s\n' \
      "$ci_action_label" \
      "status: Change lifecycle status (active, preserved, wip)" \
      "edit: Jump to host in \$EDITOR" \
      "card: View full LLM context card" \
      "back: Back to host browser" | gum choose --header "Actions for '${host}':")

    case "$action" in
      "toggle-ci"*)
        if [ "$(yq ".hosts.${host}.ci == false" "$INVENTORY_FILE")" = "true" ]; then
          yq -i "del(.hosts.${host}.ci)" "$INVENTORY_FILE"
          gum style --foreground 42 "✓ Host '${host}' is now ENABLED for CI (ci field removed)."
        else
          yq -i ".hosts.${host}.ci = false" "$INVENTORY_FILE"
          gum style --foreground 214 "✓ Host '${host}' is now EXCLUDED from CI (ci = false set)."
        fi
        sleep 1
        echo "Synchronizing inventory docs..."
        (cd "$REPO_ROOT" && task dev:inventory:sync)
        sleep 1
        ;;
      "status"*)
        new_status=$(printf '%s\n' active preserved wip cancel | gum choose --header "Select new lifecycle status:")
        if [ "$new_status" != "cancel" ] && [ -n "$new_status" ]; then
          yq -i ".hosts.${host}.status = \"${new_status}\"" "$INVENTORY_FILE"
          update_metadata_counts
          gum style --foreground 42 "✓ Host '${host}' status updated to '${new_status}'."
          echo "Synchronizing inventory docs..."
          (cd "$REPO_ROOT" && task dev:inventory:sync)
          sleep 1
        fi
        ;;
      "edit"*)
        line=$(grep -n "^\[hosts\.${host}\]" "$INVENTORY_FILE" | head -n 1 | cut -d: -f1)
        "${EDITOR:-nano}" "+${line:-1}" "$INVENTORY_FILE"
        echo "Synchronizing inventory docs after edit..."
        (cd "$REPO_ROOT" && task dev:inventory:sync)
        ;;
      "card"*)
        (cd "$REPO_ROOT" && task dev:inventory:llm HOST="${host}") | gum pager
        ;;
      "back"*)
        break
        ;;
    esac
  done
}

main_menu() {
  while true; do
    clear 2>/dev/null || true
    
    gum style --border rounded --padding "0 1" --border-foreground 212 \
      "📋 FLEET INVENTORY CONTROL PLANE (inventory.toml)" \
      "Total: $(yq '.metadata.total_devices' "$INVENTORY_FILE") | Active Nix: $(yq '.metadata.active_nix_devices' "$INVENTORY_FILE") | Active Ext: $(yq '.metadata.active_external_devices' "$INVENTORY_FILE") | WIP: $(yq '.metadata.wip_devices' "$INVENTORY_FILE") | Preserved: $(yq '.metadata.preserved_devices' "$INVENTORY_FILE")"
    echo ""

    action=$(printf '%s\n' \
      "hosts: Browse & manage fleet hosts (31)" \
      "ci: Inspect CI affected hosts plan" \
      "edit: Edit full inventory.toml in \$EDITOR" \
      "sync: Synchronize docs & fleet matrix" \
      "validate: Check inventory schema & drift" \
      "exit: Quit" | gum choose --header "Select operational mode:")

    case "$action" in
      "hosts"*)
        while true; do
          selected=$(list_hosts | gum filter --placeholder "Type to filter hosts (name, status, role, arch)..." --width 110)
          if [ -z "$selected" ]; then
            break
          fi
          host=$(echo "$selected" | awk '{print $1}')
          if [ -n "$host" ]; then
            host_menu "$host"
          fi
        done
        ;;
      "ci"*)
        ci_choice=$(printf '%s\n' \
          "worktree: Inspect uncommitted local changes (--working-tree)" \
          "committed: Inspect changes since origin/main" \
          "back: Back to main menu" | gum choose --header "CI affected hosts preview:")
        case "$ci_choice" in
          "worktree"*)
            (cd "$REPO_ROOT" && task dev:ci:plan:worktree) | gum pager
            ;;
          "committed"*)
            (cd "$REPO_ROOT" && task dev:ci:plan) | gum pager
            ;;
        esac
        ;;
      "edit"*)
        "${EDITOR:-nano}" "$INVENTORY_FILE"
        echo "Synchronizing inventory docs after edit..."
        (cd "$REPO_ROOT" && task dev:inventory:sync)
        ;;
      "sync"*)
        (cd "$REPO_ROOT" && task dev:inventory:sync)
        echo ""
        read -r -p "Press Enter to continue..." || true
        ;;
      "validate"*)
        (cd "$REPO_ROOT" && nix-shell -p python3 --run "python3 scripts/task/compile-llm-specs.py --check")
        echo ""
        read -r -p "Press Enter to continue..." || true
        ;;
      "exit"*)
        exit 0
        ;;
    esac
  done
}

main_menu
