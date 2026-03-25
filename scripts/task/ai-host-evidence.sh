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
host_class="$(jq -r --arg host "$host" '.hosts[$host].hostClass // ""' "$manifest")"
promotion_group="$(jq -r --arg host "$host" '.hosts[$host].promotionGroup // ""' "$manifest")"
nullclaw_mode="$(jq -r --arg host "$host" '.hosts[$host].nullclawMode // ""' "$manifest")"
deployment_style="$(jq -r --arg host "$host" '.hosts[$host].deploymentStyle // ""' "$manifest")"
bind="$(jq -r --arg host "$host" '.hosts[$host].nullclawBind' "$manifest")"
port="$(jq -r --arg host "$host" '.hosts[$host].nullclawPort|tostring' "$manifest")"
workspace_root="$(jq -r --arg host "$host" '.hosts[$host].workspaceRoot' "$manifest")"
nginx_expected="$(jq -r --arg host "$host" '.hosts[$host].nginxExpectedProxyPass // ""' "$manifest")"

summary_json="${bundle_dir}/summary.json"
findings_json="${bundle_dir}/findings.json"
details_txt="${bundle_dir}/details.txt"
findings_tmp="${bundle_dir}/findings.tmp"
: >"$findings_tmp"

record() {
  local severity="$1"
  local category="$2"
  local check_name="$3"
  local status="$4"
  local expected="$5"
  local actual="$6"
  local message="$7"
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
    "$severity" "$category" "$check_name" "$status" "$expected" "$actual" "$message" >>"$findings_tmp"
}

if ssh "$host" "ss -ltnH | awk '{print \$4}' | grep -Fx '${bind}:${port}' >/dev/null"; then
  record "blocking" "socket" "nullclaw_listener" "pass" "${bind}:${port}" "present" "nullclaw listener matched expected socket"
else
  record "blocking" "socket" "nullclaw_listener" "fail" "${bind}:${port}" "missing" "expected nullclaw listener socket is not present"
fi

if ssh "$host" "sudo test -d '${workspace_root}'"; then
  record "blocking" "workspace" "workspace_root" "pass" "${workspace_root}" "present" "workspace root exists"
else
  record "blocking" "workspace" "workspace_root" "fail" "${workspace_root}" "missing" "workspace root is missing"
fi

if ssh "$host" "sudo test -d '${workspace_root}/.nullclaw'"; then
  record "blocking" "workspace" "workspace_dot_nullclaw" "pass" "${workspace_root}/.nullclaw" "present" ".nullclaw directory exists"
else
  record "blocking" "workspace" "workspace_dot_nullclaw" "fail" "${workspace_root}/.nullclaw" "missing" ".nullclaw directory is missing"
fi

if ssh "$host" "sudo test -d '${workspace_root}/workspace'"; then
  record "blocking" "workspace" "workspace_dir" "pass" "${workspace_root}/workspace" "present" "workspace directory exists"
else
  record "blocking" "workspace" "workspace_dir" "fail" "${workspace_root}/workspace" "missing" "workspace directory is missing"
fi

while IFS= read -r path; do
  [[ -z "$path" ]] && continue
  if ssh "$host" "sudo test -r '${path}'"; then
    record "blocking" "path" "readable_path" "pass" "${path}" "readable" "required readable path is present"
  else
    record "blocking" "path" "readable_path" "fail" "${path}" "missing-or-unreadable" "required readable path is missing or unreadable"
  fi
done < <(jq -r '.[]' <<<"$paths_json")

while IFS= read -r svc; do
  [[ -z "$svc" ]] && continue
  state="$(ssh "$host" "sudo systemctl is-active '${svc}' 2>/dev/null || true")"
  if [[ "$state" == "active" ]]; then
    record "blocking" "service" "service_active" "pass" "${svc}=active" "${svc}=${state}" "service is active"
  else
    record "blocking" "service" "service_active" "fail" "${svc}=active" "${svc}=${state:-unknown}" "service is not active"
  fi
done < <(jq -r '.[]' <<<"$services_json")

if [[ -n "$nginx_expected" ]]; then
  if ssh "$host" "sudo nginx -T 2>/dev/null | grep -F '${nginx_expected}' >/dev/null"; then
    record "blocking" "nginx" "nginx_proxy_upstream" "pass" "${nginx_expected}" "matched" "nginx upstream expectation matched"
  else
    record "blocking" "nginx" "nginx_proxy_upstream" "fail" "${nginx_expected}" "mismatch" "nginx upstream expectation did not match"
  fi
fi

jq -Rn '
  [
    inputs
    | split("\t")
    | {
      severity: .[0],
      category: .[1],
      check: .[2],
      status: .[3],
      expected: .[4],
      actual: .[5],
      message: .[6]
    }
  ]
' <"$findings_tmp" >"${bundle_dir}/findings-array.json"

jq -n \
  --arg host "$host" \
  --arg event "$event" \
  --arg timestamp "$timestamp" \
  --arg git_rev "$git_rev" \
  --arg flake_ref "$flake_ref" \
  --arg result "$validation_result" \
  --arg manifest_path "$manifest" \
  --arg host_class "$host_class" \
  --arg promotion_group "$promotion_group" \
  --arg nullclaw_mode "$nullclaw_mode" \
  --arg deployment_style "$deployment_style" \
  --argjson findings "$(cat "${bundle_dir}/findings-array.json")" \
  '{
    schema_version: 2,
    host: $host,
    event: $event,
    result: $result,
    timestamp: $timestamp,
    git_rev: $git_rev,
    flake_ref: $flake_ref,
    manifest_path: $manifest_path,
    host_class: $host_class,
    promotion_group: $promotion_group,
    nullclaw_mode: $nullclaw_mode,
    deployment_style: $deployment_style,
    counts: {
      total: ($findings | length),
      blocking_failures: ($findings | map(select(.severity == "blocking" and .status == "fail")) | length),
      warning_failures: ($findings | map(select(.severity == "warning" and .status == "fail")) | length),
      info_failures: ($findings | map(select(.severity == "info" and .status == "fail")) | length),
      critical_failures: ($findings | map(select(.severity == "blocking" and .status == "fail")) | length)
    },
    findings: $findings
  }' >"$findings_json"

jq -n \
  --arg host "$host" \
  --arg event "$event" \
  --arg result "$validation_result" \
  --arg timestamp "$timestamp" \
  --arg git_rev "$git_rev" \
  --arg flake_ref "$flake_ref" \
  --arg manifest_path "$manifest" \
  --arg host_class "$host_class" \
  --arg promotion_group "$promotion_group" \
  --arg nullclaw_mode "$nullclaw_mode" \
  --arg deployment_style "$deployment_style" \
  --argjson counts "$(jq '.counts' "$findings_json")" \
  --argjson key_findings "$(jq '[.findings[] | select(.status == "fail")] | .[0:10]' "$findings_json")" \
  '{
    schema_version: 2,
    host: $host,
    event: $event,
    result: $result,
    timestamp: $timestamp,
    git_rev: $git_rev,
    flake_ref: $flake_ref,
    manifest_path: $manifest_path,
    host_class: $host_class,
    promotion_group: $promotion_group,
    nullclaw_mode: $nullclaw_mode,
    deployment_style: $deployment_style,
    counts: $counts,
    key_findings: $key_findings
  }' >"$summary_json"

{
  echo "host=${host}"
  echo "event=${event}"
  echo "timestamp=${timestamp}"
  echo "git_rev=${git_rev}"
  echo "flake_ref=${flake_ref}"
  echo "result=${validation_result}"
  echo "host_class=${host_class}"
  echo "promotion_group=${promotion_group}"
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
