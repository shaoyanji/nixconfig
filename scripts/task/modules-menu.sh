#!/usr/bin/env bash
# ==============================================================================
# FLEET CONTROL KNOBS CONTROL PLANE (TUI)
# ==============================================================================
# Interactive Charmbracelet Gum interface for browsing and editing modules.toml
# Backed by fast, native yq for in-place TOML AST manipulations.
# ==============================================================================

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
MODULES_FILE="${REPO_ROOT}/modules.toml"
INVENTORY_FILE="${REPO_ROOT}/inventory.toml"
DOCS_FILE="${REPO_ROOT}/docs/modules-registry.md"

if ! command -v gum >/dev/null 2>&1; then
  echo "Error: 'gum' is required for the interactive modules menu." >&2
  echo "Ensure gum is installed or run within devShell." >&2
  exit 1
fi

if ! command -v yq >/dev/null 2>&1; then
  echo "Error: 'yq' (mikefarah/yq) is required for modules manipulation." >&2
  exit 1
fi

list_knobs() {
  yq -r '.knobs | to_entries | .[] |
    [
      .key,
      .value.type,
      .value.category,
      ((.value.hosts // []) | length),
      .value.name
    ] | @tsv' "$MODULES_FILE" | awk -F'\t' '{printf "%-18s [%-8s | %-14s] (%2d hosts) %s\n", $1, $2, $3, $4, $5}'
}

list_nix_hosts() {
  if [ -f "$INVENTORY_FILE" ]; then
    yq -r '.hosts | to_entries | .[] | select(.value.status == "active" and (.value.kind == "nixos" or .value.kind == "darwin" or .value.kind == "home")) | [.key, .value.kind, .value.role] | @tsv' "$INVENTORY_FILE" | awk -F'\t' '{printf "%-15s [%-7s] %s\n", $1, $2, $3}'
  else
    yq -r '.knobs[].hosts[]' "$MODULES_FILE" | sort -u
  fi
}

show_knob_card() {
  local knob="$1"
  local name type category option path desc hosts_list
  name=$(yq -r ".knobs.\"${knob}\".name // \"Unknown\"" "$MODULES_FILE")
  type=$(yq -r ".knobs.\"${knob}\".type // \"unknown\"" "$MODULES_FILE")
  category=$(yq -r ".knobs.\"${knob}\".category // \"unknown\"" "$MODULES_FILE")
  option=$(yq -r ".knobs.\"${knob}\".option // \"none\"" "$MODULES_FILE")
  path=$(yq -r ".knobs.\"${knob}\".path // \"\"" "$MODULES_FILE")
  desc=$(yq -r ".knobs.\"${knob}\".description // \"\"" "$MODULES_FILE")
  hosts_list=$(yq -r ".knobs.\"${knob}\".hosts // [] | join(\", \")" "$MODULES_FILE")
  [ -z "$hosts_list" ] && hosts_list="(None)"

  local file_status="🟢 Found"
  if [ ! -f "${REPO_ROOT}/${path}" ]; then
    file_status="🔴 Missing on disk (${path})"
  fi

  gum style --border normal --padding "0 1" --border-foreground 212 \
    "Knob: ${name} (${knob})" \
    "Type: ${type} | Category: ${category}" \
    "Target Option: ${option}" \
    "File: ${path} [${file_status}]" \
    "Description: ${desc}" \
    "Active Hosts: ${hosts_list}"
}

toggle_knob_host() {
  local knob="$1"
  local host="$2"
  
  if yq -e ".knobs.\"${knob}\".hosts[] | select(. == \"${host}\")" "$MODULES_FILE" >/dev/null 2>&1; then
    yq -p=toml -o=toml -i ".knobs.\"${knob}\".hosts -= [\"${host}\"]" "$MODULES_FILE"
    gum style --foreground 214 "✓ Disabled knob '${knob}' on host '${host}'."
  else
    yq -p=toml -o=toml -i ".knobs.\"${knob}\".hosts += [\"${host}\"]" "$MODULES_FILE"
    gum style --foreground 42 "✓ Enabled knob '${knob}' on host '${host}'."
  fi
  sleep 1
}

knob_detail_menu() {
  local knob="$1"
  while true; do
    clear 2>/dev/null || true
    show_knob_card "$knob"
    echo ""

    action=$(printf '%s\n' \
      "toggle: Toggle host for this knob" \
      "edit-module: Jump to Nix module in \$EDITOR" \
      "back: Back to knob browser" | gum choose --header "Actions for '${knob}':")

    case "$action" in
      "toggle"*)
        selected_host_line=$(list_nix_hosts | gum filter --placeholder "Select host to toggle '${knob}'...")
        if [ -n "$selected_host_line" ]; then
          host=$(echo "$selected_host_line" | awk '{print $1}')
          toggle_knob_host "$knob" "$host"
        fi
        ;;
      "edit-module"*)
        path=$(yq -r ".knobs.\"${knob}\".path // \"\"" "$MODULES_FILE")
        if [ -n "$path" ] && [ -f "${REPO_ROOT}/${path}" ]; then
          "${EDITOR:-nano}" "${REPO_ROOT}/${path}"
        else
          gum style --foreground 196 "Module file not found: ${path}"
          sleep 1
        fi
        ;;
      "back"*)
        break
        ;;
    esac
  done
}

show_host_summary() {
  local host="$1"
  local active_profiles active_services active_roles
  
  active_profiles=$(yq -r ".knobs | to_entries | .[] | select(.value.type == \"profile\" and ((.value.hosts // [])[] == \"${host}\")) | .key" "$MODULES_FILE" | tr '\n' ' ')
  active_services=$(yq -r ".knobs | to_entries | .[] | select(.value.type == \"service\" and ((.value.hosts // [])[] == \"${host}\")) | .key" "$MODULES_FILE" | tr '\n' ' ')
  active_roles=$(yq -r ".knobs | to_entries | .[] | select(.value.type == \"role\" and ((.value.hosts // [])[] == \"${host}\")) | .key" "$MODULES_FILE" | tr '\n' ' ')

  [ -z "$active_profiles" ] && active_profiles="none"
  [ -z "$active_services" ] && active_services="none"
  [ -z "$active_roles" ] && active_roles="none"

  gum style --border normal --padding "0 1" --border-foreground 99 \
    "Host Control Knobs: ${host}" \
    "Active Profiles: ${active_profiles}" \
    "Active Services: ${active_services}" \
    "Active Roles:    ${active_roles}"
}

list_host_knob_statuses() {
  local host="$1"
  yq -r '.knobs | to_entries | .[] |
    [
      .key,
      (if ((.value.hosts // [])[] == "'"${host}"'") then "ON " else "OFF" end),
      .value.type,
      .value.name,
      .value.option
    ] | @tsv' "$MODULES_FILE" 2>/dev/null | awk -F'\t' '{
      status = ($2 ~ /ON/) ? "[\033[32mON \033[0m]" : "[\033[90mOFF\033[0m]";
      printf "%-18s %s %-8s %-28s (%s)\n", $1, status, $3, $4, $5
    }'
}

host_knobs_menu() {
  local host="$1"
  while true; do
    clear 2>/dev/null || true
    show_host_summary "$host"
    echo ""

    action=$(printf '%s\n' \
      "toggle: Toggle a control knob ON/OFF" \
      "edit-config: Jump to host configuration in \$EDITOR" \
      "back: Back to host browser" | gum choose --header "Actions for '${host}':")

    case "$action" in
      "toggle"*)
        raw_selection=$(list_host_knob_statuses "$host" | gum filter --placeholder "Select knob to toggle ON/OFF on '${host}'..." --width 120)
        if [ -n "$raw_selection" ]; then
          knob=$(echo "$raw_selection" | awk '{print $1}')
          toggle_knob_host "$knob" "$host"
        fi
        ;;
      "edit-config"*)
        host_nix=""
        if [ -f "${REPO_ROOT}/hosts/${host}/configuration.nix" ]; then
          host_nix="${REPO_ROOT}/hosts/${host}/configuration.nix"
        elif [ -f "${REPO_ROOT}/hosts/${host}/default.nix" ]; then
          host_nix="${REPO_ROOT}/hosts/${host}/default.nix"
        elif [ -f "${REPO_ROOT}/hosts/${host}.nix" ]; then
          host_nix="${REPO_ROOT}/hosts/${host}.nix"
        fi

        if [ -n "$host_nix" ]; then
          "${EDITOR:-nano}" "$host_nix"
        else
          gum style --foreground 196 "Could not find configuration file for host '${host}'"
          sleep 1
        fi
        ;;
      "back"*)
        break
        ;;
    esac
  done
}

sync_docs() {
  echo "Generating ${DOCS_FILE}..."
  mkdir -p "$(dirname "$DOCS_FILE")"
  
  cat << 'EOF' > "$DOCS_FILE"
# Fleet Modular Control Knob Registry

> **Source of Truth**: [`modules.toml`](../modules.toml)  
> **Interactive Manager**: `task modules` / `task dev:modules:menu`  
> **Last Synchronized**: Automatically generated by fleet control plane

## Overview
This registry catalogs declarative configuration knobs (optional profiles, system services, and operational roles) across all fleet hosts. Operators can inspect and toggle these knobs directly using `task modules` without manually searching through nested Nix module trees.

---

## 1. Optional Profiles

| Knob ID | Name | Target Option | Source Module | Active Hosts | Description |
| :--- | :--- | :--- | :--- | :--- | :--- |
EOF

  yq -r '.knobs | to_entries | .[] | select(.value.type == "profile") |
    [
      .key,
      .value.name,
      ("`" + .value.option + "`"),
      ("[" + .value.path + "](../" + .value.path + ")"),
      ((.value.hosts // []) | join(", ")),
      .value.description
    ] | @tsv' "$MODULES_FILE" | awk -F'\t' '{
      hosts = ($5 == "") ? "_none_" : $5;
      printf "| `%s` | **%s** | %s | %s | %s | %s |\n", $1, $2, $3, $4, hosts, $6
    }' >> "$DOCS_FILE"

  cat << 'EOF' >> "$DOCS_FILE"

---

## 2. System Services

| Knob ID | Name | Target Option | Source Module | Active Hosts | Description |
| :--- | :--- | :--- | :--- | :--- | :--- |
EOF

  yq -r '.knobs | to_entries | .[] | select(.value.type == "service") |
    [
      .key,
      .value.name,
      ("`" + .value.option + "`"),
      ("[" + .value.path + "](../" + .value.path + ")"),
      ((.value.hosts // []) | join(", ")),
      .value.description
    ] | @tsv' "$MODULES_FILE" | awk -F'\t' '{
      hosts = ($5 == "") ? "_none_" : $5;
      printf "| `%s` | **%s** | %s | %s | %s | %s |\n", $1, $2, $3, $4, hosts, $6
    }' >> "$DOCS_FILE"

  cat << 'EOF' >> "$DOCS_FILE"

---

## 3. System Roles

| Knob ID | Name | Target Option | Source Module | Active Hosts | Description |
| :--- | :--- | :--- | :--- | :--- | :--- |
EOF

  yq -r '.knobs | to_entries | .[] | select(.value.type == "role") |
    [
      .key,
      .value.name,
      ("`" + .value.option + "`"),
      ("[" + .value.path + "](../" + .value.path + ")"),
      ((.value.hosts // []) | join(", ")),
      .value.description
    ] | @tsv' "$MODULES_FILE" | awk -F'\t' '{
      hosts = ($5 == "") ? "_none_" : $5;
      printf "| `%s` | **%s** | %s | %s | %s | %s |\n", $1, $2, $3, $4, hosts, $6
    }' >> "$DOCS_FILE"

  echo "✓ Successfully synchronized ${DOCS_FILE}."
}

validate_registry() {
  echo "Validating modules.toml syntax and file paths..."
  local errors=0

  if ! yq '.' "$MODULES_FILE" >/dev/null 2>&1; then
    echo "🔴 ERROR: modules.toml contains invalid TOML syntax."
    errors=$((errors + 1))
  else
    echo "🟢 Syntax check passed."
  fi

  while IFS=$'\t' read -r knob path; do
    if [ ! -f "${REPO_ROOT}/${path}" ]; then
      echo "🔴 ERROR: Knob '${knob}' points to missing file: ${path}"
      errors=$((errors + 1))
    else
      echo "  ✓ [${knob}] -> ${path}"
    fi
  done < <(yq -r '.knobs | to_entries | .[] | [.key, .value.path] | @tsv' "$MODULES_FILE")

  if [ "$errors" -eq 0 ]; then
    gum style --foreground 42 "✓ All $(yq '.knobs | length' "$MODULES_FILE") knobs validated successfully with existing module paths!"
  else
    gum style --foreground 196 "✗ Found ${errors} validation errors in modules.toml."
  fi
}

main_menu() {
  while true; do
    clear 2>/dev/null || true

    local total profiles services roles
    total=$(yq '.knobs | length' "$MODULES_FILE")
    profiles=$(yq '[.knobs[] | select(.type == "profile")] | length' "$MODULES_FILE")
    services=$(yq '[.knobs[] | select(.type == "service")] | length' "$MODULES_FILE")
    roles=$(yq '[.knobs[] | select(.type == "role")] | length' "$MODULES_FILE")

    gum style --border rounded --padding "0 1" --border-foreground 212 \
      "⚙️ FLEET CONTROL KNOBS CONTROL PLANE (modules.toml)" \
      "Total Knobs: ${total} | Profiles: ${profiles} | Services: ${services} | Roles: ${roles}"
    echo ""

    action=$(printf '%s\n' \
      "knobs: Browse & inspect all modular knobs (${total})" \
      "hosts: Manage control knobs by host" \
      "sync: Synchronize markdown documentation" \
      "validate: Check registry paths & TOML integrity" \
      "edit: Edit full modules.toml in \$EDITOR" \
      "exit: Quit" | gum choose --header "Select operational mode:")

    case "$action" in
      "knobs"*)
        while true; do
          selected=$(list_knobs | gum filter --placeholder "Filter knobs (name, type, category)..." --width 110)
          if [ -z "$selected" ]; then
            break
          fi
          knob=$(echo "$selected" | awk '{print $1}')
          if [ -n "$knob" ]; then
            knob_detail_menu "$knob"
          fi
        done
        ;;
      "hosts"*)
        while true; do
          selected_host=$(list_nix_hosts | gum filter --placeholder "Select host to configure knobs..." --width 110)
          if [ -z "$selected_host" ]; then
            break
          fi
          host=$(echo "$selected_host" | awk '{print $1}')
          if [ -n "$host" ]; then
            host_knobs_menu "$host"
          fi
        done
        ;;
      "sync"*)
        sync_docs
        echo ""
        read -r -p "Press Enter to continue..." || true
        ;;
      "validate"*)
        validate_registry
        echo ""
        read -r -p "Press Enter to continue..." || true
        ;;
      "edit"*)
        "${EDITOR:-nano}" "$MODULES_FILE"
        sync_docs
        ;;
      "exit"*)
        exit 0
        ;;
    esac
  done
}

if [ "${1:-}" = "sync" ]; then
  sync_docs
elif [ "${1:-}" = "validate" ]; then
  validate_registry
else
  main_menu
fi
