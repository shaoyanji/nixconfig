#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFEST="$SCRIPT_DIR/../../taskfiles/ai-host-manifest.json"

usage() {
  cat <<'USAGE'
Usage: ai-host-manifest.sh <command> [host]
Commands:
  list                   List hosts with class, promotion group, availability, and nullclaw mode
  show <host>            Print manifest metadata for <host>
  summary <host>         Compact summary of key metadata and tasks
  services <host>        List services tied to <host>
  paths <host>           List readable paths for <host>
  validation-task <host> Show the manifest validation task
  promotion-group <host> Show the manifest promotion group
  deploy-task <host>     Canonical infra:deploy task for the host
  logs-task <host>       Canonical infra:logs task for the host
  validate-task <host>   Canonical services:validate task for the host
  promote-task <host>    Canonical services:promote task for the host
  tasks <host>           Lifecycle task summary for <host>
USAGE
}

error() {
  echo "ai-host-manifest: $*" >&2
}

require_host() {
  local host="$1"
  if ! jq -e --arg host "$host" '.hosts[$host]' "$MANIFEST" >/dev/null; then
    error "Unknown host '$host'"
    exit 1
  fi
}

require_host_arg() {
  if [ $# -lt 1 ]; then
    error "Missing host argument for '$cmd'"
    usage
    exit 1
  fi
  host="$1"
  require_host "$host"
}

print_items() {
  local label="$1"
  local data="$2"
  if [ -z "$data" ]; then
    echo "  $label: (none)"
  else
    echo "  $label:"
    while IFS= read -r item; do
      echo "    - $item"
    done <<< "$data"
  fi
}

print_task_block() {
  local host="$1"
  local title="$2"
  echo "$title"
  printf "  %-8s %s\n" "deploy:" "infra:deploy:host:$host"
  printf "  %-8s %s\n" "logs:" "infra:logs:host:$host"
  printf "  %-8s %s\n" "validate:" "services:validate:host:$host"
  printf "  %-8s %s\n" "promote:" "services:promote:host:$host"
}

if [ $# -lt 1 ]; then
  usage
  exit 1
fi

cmd="$1"
shift

case "$cmd" in
  list)
    jq -r '
      .hosts
      | to_entries[]
      | [
          .key,
          (.value.hostClass // "(none)"),
          (.value.promotionGroup // "(none)"),
          (.value.availability // "always-on"),
          (.value.nullclawMode // "(none)")
        ]
      | @tsv
    ' "$MANIFEST" | sort | while IFS=$'\t' read -r host class promo availability mode; do
      printf '%-20s class=%-12s promo=%-10s avail=%-10s mode=%s\n' "$host" "$class" "$promo" "$availability" "$mode"
    done
    ;;
  show)
    require_host_arg "$@"
    class=$(jq -r --arg host "$host" '.hosts[$host].hostClass // "(none)"' "$MANIFEST")
    host_data=$(jq -r --arg host "$host" '.hosts[$host]' "$MANIFEST")
    promotion=$(jq -r '.promotionGroup // "(none)"' <<< "$host_data")
    validation=$(jq -r '.validationTask // "(none)"' <<< "$host_data")
    deployment=$(jq -r '.deploymentStyle // "(none)"' <<< "$host_data")
    exposure=$(jq -r '.exposureType // "(none)"' <<< "$host_data")
    availability=$(jq -r '.availability // "always-on"' <<< "$host_data")
    power_policy=$(jq -r '.powerPolicy // "(none)"' <<< "$host_data")
    role_note=$(jq -r '.roleNote // ""' <<< "$host_data")
    services=$(jq -r '.services[]?' <<< "$host_data")
    paths=$(jq -r '.readablePaths[]?' <<< "$host_data")
    echo "Host: $host"
    echo "  Class: $class"
    echo "  Promotion group: $promotion"
    echo "  Availability: $availability"
    echo "  Power policy: $power_policy"
    echo "  Validation task: $validation"
    echo "  Deployment style: $deployment"
    echo "  Exposure type: $exposure"
    if [ -n "$role_note" ]; then
      echo "  Role note: $role_note"
    fi
    print_items "Services" "$services"
    print_items "Paths" "$paths"
    ;;
  summary)
    require_host_arg "$@"
    host_data=$(jq -r --arg host "$host" '.hosts[$host]' "$MANIFEST")
    class=$(jq -r '.hostClass // "(none)"' <<< "$host_data")
    promotion=$(jq -r '.promotionGroup // "(none)"' <<< "$host_data")
    validation=$(jq -r '.validationTask // "(none)"' <<< "$host_data")
    deployment=$(jq -r '.deploymentStyle // "(none)"' <<< "$host_data")
    exposure=$(jq -r '.exposureType // "(none)"' <<< "$host_data")
    rollback=$(jq -r '.rollbackShape // "(none)"' <<< "$host_data")
    availability=$(jq -r '.availability // "always-on"' <<< "$host_data")
    power_policy=$(jq -r '.powerPolicy // "(none)"' <<< "$host_data")
    role_note=$(jq -r '.roleNote // ""' <<< "$host_data")
    nullclaw_mode=$(jq -r '.nullclawMode // "(none)"' <<< "$host_data")
    nullclaw_bind=$(jq -r '.nullclawBind // ""' <<< "$host_data")
    nullclaw_port=$(jq -r '.nullclawPort // ""' <<< "$host_data")
    services=$(jq -r '.services[]?' <<< "$host_data")
    paths=$(jq -r '.readablePaths[]?' <<< "$host_data")
    echo "Host summary: $host"
    echo "  Class: $class"
    echo "  Promotion group: $promotion"
    echo "  Availability: $availability"
    echo "  Power policy: $power_policy"
    echo "  Nullclaw mode: $nullclaw_mode"
    echo "  Validation task: $validation"
    echo "  Deployment style: $deployment"
    echo "  Exposure type: $exposure"
    echo "  Rollback shape: $rollback"
    if [ -n "$role_note" ]; then
      echo "  Role note: $role_note"
    fi
    if [ -n "$nullclaw_bind" ]; then
      echo "  Nullclaw bind: $nullclaw_bind"
    fi
    if [ -n "$nullclaw_port" ]; then
      echo "  Nullclaw port: $nullclaw_port"
    fi
    print_items "Services" "$services"
    print_items "Paths" "$paths"
    print_task_block "$host" "Lifecycle tasks:"
    ;;
  services)
    require_host_arg "$@"
    services=$(jq -r --arg host "$host" '.hosts[$host].services[]?' "$MANIFEST")
    if [ -z "$services" ]; then
      echo "Services: (none defined)"
    else
      while IFS= read -r service; do
        echo "$service"
      done <<< "$services"
    fi
    ;;
  paths)
    require_host_arg "$@"
    paths=$(jq -r --arg host "$host" '.hosts[$host].readablePaths[]?' "$MANIFEST")
    if [ -z "$paths" ]; then
      echo "Paths: (none listed)"
    else
      while IFS= read -r path; do
        echo "$path"
      done <<< "$paths"
    fi
    ;;
  validation-task)
    require_host_arg "$@"
    jq -r --arg host "$host" '.hosts[$host].validationTask // "(none)"' "$MANIFEST"
    ;;
  promotion-group)
    require_host_arg "$@"
    jq -r --arg host "$host" '.hosts[$host].promotionGroup // "(none)"' "$MANIFEST"
    ;;
  deploy-task)
    require_host_arg "$@"
    printf 'infra:deploy:host:%s\n' "$host"
    ;;
  logs-task)
    require_host_arg "$@"
    printf 'infra:logs:host:%s\n' "$host"
    ;;
  validate-task)
    require_host_arg "$@"
    printf 'services:validate:host:%s\n' "$host"
    ;;
  promote-task)
    require_host_arg "$@"
    printf 'services:promote:host:%s\n' "$host"
    ;;
  tasks)
    require_host_arg "$@"
    print_task_block "$host" "Tasks for $host:"
    ;;
  *)
    error "Unknown command '$cmd'"
    usage
    exit 1
    ;;
esac
