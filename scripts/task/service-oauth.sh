#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# service-oauth.sh — Ergonomic OAuth/session management for AI service users
#
# Usage:
#   service-oauth.sh list
#   service-oauth.sh paths SERVICE
#   service-oauth.sh status SERVICE TOOL
#   service-oauth.sh login SERVICE TOOL
#   service-oauth.sh exec SERVICE TOOL -- <command...>

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Service → user/home mapping (from modules/services/*.nix)
declare -A SERVICE_USER=(
  [nullclaw]="nullclaw"
  [openclaw]="openclaw"
  [xs]="xs"
  [openfang]="openfang"
  [hermes]="hermes"
)

declare -A SERVICE_HOME=(
  [nullclaw]="/var/lib/nullclaw"
  [openclaw]="/var/lib/openclaw"
  [xs]="/var/lib/xs"
  [openfang]="/var/lib/openfang"
  [hermes]="/var/lib/hermes"
)

# Tool → auth file paths (relative to service home)
declare -A TOOL_PATHS=(
  [codex]=".codex/config.toml .codex/auth.json"
  [qwen]=".qwen/settings.json"
  [gemini]=".gemini/oauth_creds.json .gemini/settings.json"
)

# Tool → login command
declare -A TOOL_LOGIN=(
  [codex]="codex login"
  [qwen]="qwen auth"
  [gemini]="gemini auth login"
)

usage() {
  cat <<'EOF'
Usage: service-oauth.sh <command> [args]

Commands:
  list                      List known services and tools
  paths SERVICE             Show auth file paths for a service
  status SERVICE TOOL       Check authentication status
  login SERVICE TOOL        Run interactive login for a tool
  exec SERVICE TOOL -- cmd  Run tool command as service user with correct env

Examples:
  service-oauth.sh list
  service-oauth.sh paths nullclaw
  service-oauth.sh status nullclaw codex
  service-oauth.sh login nullclaw codex
  service-oauth.sh exec nullclaw codex -- whoami
EOF
}

# Resolve service user
get_user() {
  local service="$1"
  local user="${SERVICE_USER[$service]:-}"
  if [ -z "$user" ]; then
    echo "ERROR: Unknown service '$service'" >&2
    echo "Known services: ${!SERVICE_USER[*]}" >&2
    exit 1
  fi
  echo "$user"
}

# Resolve service home
get_home() {
  local service="$1"
  local home="${SERVICE_HOME[$service]:-}"
  if [ -z "$home" ]; then
    echo "ERROR: Unknown service '$service'" >&2
    echo "Known services: ${!SERVICE_HOME[*]}" >&2
    exit 1
  fi
  echo "$home"
}

# Build environment for service user
build_env() {
  local service="$1"
  local home
  home="$(get_home "$service")"
  
  cat <<EOF
HOME=$home
XDG_CONFIG_HOME=$home/.config
XDG_DATA_HOME=$home/.local/share
XDG_STATE_HOME=$home/.local/state
EOF
}

# Run command as service user with correct env
run_as_service() {
  local service="$1"
  local user
  user="$(get_user "$service")"
  local home
  home="$(get_home "$service")"
  
  # Build environment and run command
  local env_vars
  env_vars="$(build_env "$service")"
  
  # Use sudo to run as service user with explicit HOME
  sudo -u "$user" HOME="$home" XDG_CONFIG_HOME="$home/.config" XDG_DATA_HOME="$home/.local/share" XDG_STATE_HOME="$home/.local/state" "$@"
}

# List known services and tools
cmd_list() {
  echo "Known services: ${!SERVICE_USER[*]}"
  echo "Known tools:    ${!TOOL_PATHS[*]}"
  echo ""
  echo "Service → Tool support:"
  for service in "${!SERVICE_USER[@]}"; do
    if [ "$service" = "hermes" ]; then
      echo "  $service:    (host-level, use systemd override)"
    else
      echo "  $service:  ${!TOOL_PATHS[*]}"
    fi
  done
}

# Show auth file paths for a service
cmd_paths() {
  local service="${1:-}"
  if [ -z "$service" ]; then
    echo "ERROR: SERVICE required" >&2
    usage
    exit 1
  fi
  
  local home
  home="$(get_home "$service")"
  local user
  user="$(get_user "$service")"
  
  echo "Service: $service (user: $user, home: $home)"
  echo ""
  echo "Tool auth paths:"
  
  for tool in "${!TOOL_PATHS[@]}"; do
    echo "  $tool:"
    # Split paths by space (temporarily reset IFS)
    local paths_str="${TOOL_PATHS[$tool]}"
    local old_ifs="$IFS"
    IFS=' '
    for path in $paths_str; do
      echo "    $home/$path"
    done
    IFS="$old_ifs"
  done
}

# Check authentication status
cmd_status() {
  local service="${1:-}"
  local tool="${2:-}"
  
  if [ -z "$service" ] || [ -z "$tool" ]; then
    echo "ERROR: SERVICE and TOOL required" >&2
    usage
    exit 1
  fi
  
  local home
  home="$(get_home "$service")"
  local user
  user="$(get_user "$service")"
  
  echo "Service: $service"
  echo "Tool:    $tool"
  
  # Check if auth files exist
  local auth_files="${TOOL_PATHS[$tool]:-}"
  if [ -z "$auth_files" ]; then
    echo "Status:  UNKNOWN (tool '$tool' not recognized)"
    exit 1
  fi
  
  local all_exist=true
  local has_any=false
  
  # Split paths by space (temporarily reset IFS)
  local paths_str="$auth_files"
  local old_ifs="$IFS"
  IFS=' '
  for path in $paths_str; do
    local full_path="$home/$path"
    if [ -f "$full_path" ]; then
      has_any=true
      local mtime
      mtime="$(stat -c '%y' "$full_path" 2>/dev/null | cut -d'.' -f1)"
      echo "  ✓ $full_path ($mtime)"
    else
      all_exist=false
      echo "  ✗ $full_path (not found)"
    fi
  done
  IFS="$old_ifs"
  
  if [ "$has_any" = true ]; then
    if [ "$all_exist" = true ]; then
      echo "Status:  AUTHENTICATED"
    else
      echo "Status:  PARTIAL (some auth files missing)"
    fi
  else
    echo "Status:  NOT_AUTHENTICATED"
  fi
}

# Run interactive login
cmd_login() {
  local service="${1:-}"
  local tool="${2:-}"
  
  if [ -z "$service" ] || [ -z "$tool" ]; then
    echo "ERROR: SERVICE and TOOL required" >&2
    usage
    exit 1
  fi
  
  local login_cmd="${TOOL_LOGIN[$tool]:-}"
  if [ -z "$login_cmd" ]; then
    echo "ERROR: Unknown tool '$tool'" >&2
    echo "Known tools: ${!TOOL_LOGIN[*]}" >&2
    exit 1
  fi
  
  local user
  user="$(get_user "$service")"
  local home
  home="$(get_home "$service")"
  
  echo "Running: sudo -u $user HOME=$home ... $login_cmd"
  echo ""
  
  # Run login command interactively
  run_as_service bash -c "$login_cmd"
  
  echo ""
  echo "✓ Login complete"
}

# Execute arbitrary command as service user
cmd_exec() {
  local service="${1:-}"
  local tool="${2:-}"
  shift 2 || true
  
  # Parse -- separator
  local cmd_args=()
  local found_sep=false
  for arg in "$@"; do
    if [ "$arg" = "--" ]; then
      found_sep=true
      continue
    fi
    if [ "$found_sep" = true ]; then
      cmd_args+=("$arg")
    fi
  done
  
  if [ -z "$service" ] || [ -z "$tool" ] || [ ${#cmd_args[@]} -eq 0 ]; then
    echo "ERROR: SERVICE, TOOL, and command required" >&2
    echo "Usage: service-oauth.sh exec SERVICE TOOL -- <command-args...>" >&2
    echo "Example: service-oauth.sh exec nullclaw codex -- whoami" >&2
    exit 1
  fi
  
  # Get the base login command for this tool and extract the tool name
  local base_cmd="${TOOL_LOGIN[$tool]:-}"
  if [ -z "$base_cmd" ]; then
    echo "ERROR: Unknown tool '$tool'" >&2
    echo "Known tools: ${!TOOL_LOGIN[*]}" >&2
    exit 1
  fi
  
  # Extract tool command (first word of base_cmd)
  local tool_cmd
  tool_cmd="$(echo "$base_cmd" | awk '{print $1}')"
  
  # Run: <tool-cmd> <args...> as service user
  # Need to pass service first to run_as_service, then the command
  local user
  user="$(get_user "$service")"
  local home
  home="$(get_home "$service")"
  
  sudo -u "$user" HOME="$home" XDG_CONFIG_HOME="$home/.config" XDG_DATA_HOME="$home/.local/share" XDG_STATE_HOME="$home/.local/state" "$tool_cmd" "${cmd_args[@]}"
}

# Main
if [ $# -lt 1 ]; then
  usage
  exit 1
fi

command="$1"
shift

case "$command" in
  list)
    cmd_list
    ;;
  paths)
    cmd_paths "$@"
    ;;
  status)
    cmd_status "$@"
    ;;
  login)
    cmd_login "$@"
    ;;
  exec)
    cmd_exec "$@"
    ;;
  --help|-h|help)
    usage
    ;;
  *)
    echo "ERROR: Unknown command '$command'" >&2
    usage
    exit 1
    ;;
esac
