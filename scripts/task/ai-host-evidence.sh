#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: ai-host-evidence.sh --host HOST --event EVENT --manifest PATH --output-root PATH --validation-result RESULT
EOF
}

host=""
event=""
manifest=""
output_root=""
validation_result=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --host)
      host="$2"
      shift 2
      ;;
    --event)
      event="$2"
      shift 2
      ;;
    --manifest)
      manifest="$2"
      shift 2
      ;;
    --output-root)
      output_root="$2"
      shift 2
      ;;
    --validation-result)
      validation_result="$2"
      shift 2
      ;;
    *)
      usage
      exit 2
      ;;
  esac
done

if [[ -z "$host" || -z "$event" || -z "$manifest" || -z "$output_root" || -z "$validation_result" ]]; then
  usage
  exit 2
fi

command -v jq >/dev/null
command -v ssh >/dev/null

jq -e --arg host "$host" '.hosts[$host] != null' "$manifest" >/dev/null

timestamp="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
stamp_compact="$(date -u +%Y%m%dT%H%M%SZ)"
host_dir="${output_root}/${host}"
bundle_dir="${host_dir}/${stamp_compact}-${event}"
mkdir -p "$bundle_dir"

git_rev="$(git rev-parse --verify HEAD 2>/dev/null || echo unknown)"
flake_ref=".?submodules=1#${host}"

services_json="$(jq -c --arg host "$host" '.hosts[$host].services // []' "$manifest")"
paths_json="$(jq -c --arg host "$host" '.hosts[$host].readablePaths // []' "$manifest")"
bind="$(jq -r --arg host "$host" '.hosts[$host].nullclawBind' "$manifest")"
port="$(jq -r --arg host "$host" '.hosts[$host].nullclawPort|tostring' "$manifest")"
workspace_root="$(jq -r --arg host "$host" '.hosts[$host].workspaceRoot' "$manifest")"
nginx_expected="$(jq -r --arg host "$host" '.hosts[$host].nginxExpectedProxyPass // ""' "$manifest")"

summary_json="${bundle_dir}/summary.json"
details_txt="${bundle_dir}/details.txt"

jq -n \
  --arg host "$host" \
  --arg event "$event" \
  --arg timestamp "$timestamp" \
  --arg git_rev "$git_rev" \
  --arg flake_ref "$flake_ref" \
  --arg validation_result "$validation_result" \
  --arg manifest_path "$manifest" \
  '{
    host: $host,
    event: $event,
    timestamp: $timestamp,
    git_rev: $git_rev,
    flake_ref: $flake_ref,
    validation_result: $validation_result,
    manifest_path: $manifest_path
  }' >"$summary_json"

{
  echo "host=${host}"
  echo "event=${event}"
  echo "timestamp=${timestamp}"
  echo "git_rev=${git_rev}"
  echo "flake_ref=${flake_ref}"
  echo "validation_result=${validation_result}"
  echo
  echo "== nullclaw socket check =="
  ssh "$host" "ss -ltnH | awk '{print \$4}' | grep -Fx '${bind}:${port}' >/dev/null && echo 'socket:ok ${bind}:${port}' || echo 'socket:missing ${bind}:${port}'"
  echo
  echo "== workspace check =="
  ssh "$host" "sudo test -d '${workspace_root}' && echo 'workspace:ok ${workspace_root}' || echo 'workspace:missing ${workspace_root}'"
  ssh "$host" "sudo test -d '${workspace_root}/.nullclaw' && echo 'dot-nullclaw:ok ${workspace_root}/.nullclaw' || echo 'dot-nullclaw:missing ${workspace_root}/.nullclaw'"
  ssh "$host" "sudo test -d '${workspace_root}/workspace' && echo 'workspace-dir:ok ${workspace_root}/workspace' || echo 'workspace-dir:missing ${workspace_root}/workspace'"
  echo
  echo "== readable path checks =="
  while IFS= read -r path; do
    [[ -z "$path" ]] && continue
    ssh "$host" "sudo test -r '${path}' && echo 'readable:ok ${path}' || echo 'readable:missing ${path}'"
  done < <(jq -r '.[]' <<<"$paths_json")
  echo
  echo "== service status =="
  while IFS= read -r svc; do
    [[ -z "$svc" ]] && continue
    echo "-- ${svc} is-active --"
    ssh "$host" "sudo systemctl is-active '${svc}' || true"
    echo "-- ${svc} status (first 25 lines) --"
    ssh "$host" "sudo systemctl status --no-pager -l '${svc}' | sed -n '1,25p' || true"
  done < <(jq -r '.[]' <<<"$services_json")
  echo
  echo "== nullclaw journal excerpt (last 80 lines) =="
  ssh "$host" "sudo journalctl -u nullclaw -n 80 --no-pager || true"
  if [[ -n "$nginx_expected" ]]; then
    echo
    echo "== nginx proxy expectation =="
    ssh "$host" "sudo nginx -T 2>/dev/null | grep -F '${nginx_expected}' >/dev/null && echo 'nginx-proxy:ok ${nginx_expected}' || echo 'nginx-proxy:mismatch ${nginx_expected}'"
  fi
} >"$details_txt"

echo "$bundle_dir"
