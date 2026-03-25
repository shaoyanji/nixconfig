#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: ai-host-drift-audit.sh --host HOST --manifest PATH --output-root PATH [--rehearsal-fingerprint NAME]
EOF
}

host=""
manifest=""
output_root=""
rehearsal_fingerprint=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --host)
      host="$2"
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
    --rehearsal-fingerprint)
      rehearsal_fingerprint="$2"
      shift 2
      ;;
    *)
      usage
      exit 2
      ;;
  esac
done

if [[ -z "$host" || -z "$manifest" || -z "$output_root" ]]; then
  usage
  exit 2
fi

command -v jq >/dev/null
command -v ssh >/dev/null

jq -e --arg host "$host" '.hosts[$host] != null' "$manifest" >/dev/null

timestamp="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
stamp_compact="$(date -u +%Y%m%dT%H%M%SZ)"
bundle_dir="${output_root}/${host}/${stamp_compact}-drift"
mkdir -p "$bundle_dir"

git_rev="$(git rev-parse --verify HEAD 2>/dev/null || echo unknown)"
flake_ref=".?submodules=1#${host}"

host_class="$(jq -r --arg host "$host" '.hosts[$host].hostClass' "$manifest")"
promotion_group="$(jq -r --arg host "$host" '.hosts[$host].promotionGroup // ""' "$manifest")"
nullclaw_mode="$(jq -r --arg host "$host" '.hosts[$host].nullclawMode' "$manifest")"
deployment_style="$(jq -r --arg host "$host" '.hosts[$host].deploymentStyle' "$manifest")"
bind="$(jq -r --arg host "$host" '.hosts[$host].nullclawBind' "$manifest")"
port="$(jq -r --arg host "$host" '.hosts[$host].nullclawPort|tostring' "$manifest")"
workspace_root="$(jq -r --arg host "$host" '.hosts[$host].workspaceRoot' "$manifest")"
nginx_expected="$(jq -r --arg host "$host" '.hosts[$host].nginxExpectedProxyPass // ""' "$manifest")"
services_json="$(jq -c --arg host "$host" '.hosts[$host].services // []' "$manifest")"
paths_json="$(jq -c --arg host "$host" '.hosts[$host].readablePaths // []' "$manifest")"

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

socket_target="${bind}:${port}"
if [[ -n "$rehearsal_fingerprint" && "$rehearsal_fingerprint" == "missing-listener" ]]; then
  socket_target="${bind}:65535"
fi

if ssh "$host" "ss -ltnH | awk '{print \$4}' | grep -Fx '${socket_target}' >/dev/null"; then
  record "blocking" "socket" "nullclaw_listener" "pass" "${socket_target}" "present" "nullclaw listener matched expected socket"
else
  record "blocking" "socket" "nullclaw_listener" "fail" "${socket_target}" "missing" "expected nullclaw listener socket is not present"
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

paths_eval_json="$paths_json"
if [[ -n "$rehearsal_fingerprint" && "$rehearsal_fingerprint" == "missing-readable-path" ]]; then
  paths_eval_json="$(jq -c '. + ["/definitely-missing-rehearsal-path"]' <<<"$paths_json")"
fi

while IFS= read -r path; do
  [[ -z "$path" ]] && continue
  if ssh "$host" "sudo test -r '${path}'"; then
    record "blocking" "path" "readable_path" "pass" "${path}" "readable" "required readable path is present"
  else
    record "blocking" "path" "readable_path" "fail" "${path}" "missing-or-unreadable" "required readable path is missing or unreadable"
  fi
done < <(jq -r '.[]' <<<"$paths_eval_json")

services_eval_json="$services_json"
if [[ -n "$rehearsal_fingerprint" && "$rehearsal_fingerprint" == "nullclaw-inactive" ]]; then
  services_eval_json='["nullclaw-rehearsal-inactive"]'
fi

while IFS= read -r svc; do
  [[ -z "$svc" ]] && continue
  state="$(ssh "$host" "sudo systemctl is-active '${svc}' 2>/dev/null || true")"
  if [[ "$state" == "active" ]]; then
    record "blocking" "service" "service_active" "pass" "${svc}=active" "${svc}=${state}" "service is active"
  else
    record "blocking" "service" "service_active" "fail" "${svc}=active" "${svc}=${state:-unknown}" "service is not active"
  fi
done < <(jq -r '.[]' <<<"$services_eval_json")

nginx_eval="$nginx_expected"
if [[ -n "$rehearsal_fingerprint" && "$rehearsal_fingerprint" == "nginx-upstream-mismatch" ]]; then
  nginx_eval="http://127.0.0.1:3999/"
fi

if [[ -n "$nginx_eval" ]]; then
  if ssh "$host" "sudo nginx -T 2>/dev/null | grep -F '${nginx_eval}' >/dev/null"; then
    record "blocking" "nginx" "nginx_proxy_upstream" "pass" "${nginx_eval}" "matched" "nginx upstream expectation matched"
  else
    record "blocking" "nginx" "nginx_proxy_upstream" "fail" "${nginx_eval}" "mismatch" "nginx upstream expectation did not match"
  fi
fi

unit_cat="$(ssh "$host" "sudo systemctl cat nullclaw 2>/dev/null || true")"
case "${deployment_style}:${nullclaw_mode}" in
  "nullclaw-deployment-wrapper:config-json")
    if grep -Fq ".nullclaw/config.json" <<<"$unit_cat" && ! grep -Fq "EnvironmentFile=" <<<"$unit_cat"; then
      record "warning" "deployment-style" "deployment_style_inference" "pass" "${deployment_style}:${nullclaw_mode}" "unit-shape-matched" "unit file shape is consistent with wrapper config-json mode"
    else
      record "warning" "deployment-style" "deployment_style_inference" "fail" "${deployment_style}:${nullclaw_mode}" "unit-shape-mismatch" "unit file shape is not consistent with wrapper config-json mode"
    fi
    ;;
  "nullclaw-deployment-wrapper:env-file"|"direct-aiServices-nullclaw:env-file")
    if grep -Fq "EnvironmentFile=" <<<"$unit_cat"; then
      record "warning" "deployment-style" "deployment_style_inference" "pass" "${deployment_style}:${nullclaw_mode}" "unit-shape-matched" "unit file shape is consistent with env-file mode"
    else
      record "warning" "deployment-style" "deployment_style_inference" "fail" "${deployment_style}:${nullclaw_mode}" "unit-shape-mismatch" "unit file shape is not consistent with env-file mode"
    fi
    ;;
  *)
    record "warning" "deployment-style" "deployment_style_inference" "pass" "${deployment_style}:${nullclaw_mode}" "not-checked" "no deployment-style inference rule configured"
    ;;
esac

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

blocking_failures="$(jq '[.[] | select(.severity == "blocking" and .status == "fail")] | length' "${bundle_dir}/findings-array.json")"
warning_failures="$(jq '[.[] | select(.severity == "warning" and .status == "fail")] | length' "${bundle_dir}/findings-array.json")"

overall="pass"
if [[ "$blocking_failures" != "0" ]]; then
  overall="fail"
fi

jq -n \
  --arg host "$host" \
  --arg host_class "$host_class" \
  --arg promotion_group "$promotion_group" \
  --arg nullclaw_mode "$nullclaw_mode" \
  --arg deployment_style "$deployment_style" \
  --arg event "drift" \
  --arg result "$overall" \
  --arg timestamp "$timestamp" \
  --arg git_rev "$git_rev" \
  --arg flake_ref "$flake_ref" \
  --arg manifest_path "$manifest" \
  --arg overall "$overall" \
  --arg rehearsal_fingerprint "$rehearsal_fingerprint" \
  --argjson findings "$(cat "${bundle_dir}/findings-array.json")" \
  '{
    schema_version: 2,
    host: $host,
    event: $event,
    result: $result,
    host_class: $host_class,
    promotion_group: $promotion_group,
    nullclaw_mode: $nullclaw_mode,
    deployment_style: $deployment_style,
    timestamp: $timestamp,
    git_rev: $git_rev,
    flake_ref: $flake_ref,
    manifest_path: $manifest_path,
    audit_type: "drift",
    rehearsal_fingerprint: (if $rehearsal_fingerprint == "" then null else $rehearsal_fingerprint end),
    overall: $overall,
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
  --arg host_class "$host_class" \
  --arg promotion_group "$promotion_group" \
  --arg nullclaw_mode "$nullclaw_mode" \
  --arg deployment_style "$deployment_style" \
  --arg event "drift" \
  --arg result "$overall" \
  --arg timestamp "$timestamp" \
  --arg overall "$overall" \
  --arg bundle_dir "$bundle_dir" \
  --arg rehearsal_fingerprint "$rehearsal_fingerprint" \
  --arg manifest_path "$manifest" \
  --arg git_rev "$git_rev" \
  --arg flake_ref "$flake_ref" \
  --argjson counts "$(jq '.counts' "$findings_json")" \
  --argjson key_findings "$(jq '[.findings[] | select(.status == "fail")] | .[0:10]' "$findings_json")" \
  '{
    schema_version: 2,
    host: $host,
    host_class: $host_class,
    promotion_group: $promotion_group,
    nullclaw_mode: $nullclaw_mode,
    deployment_style: $deployment_style,
    event: $event,
    result: $result,
    timestamp: $timestamp,
    audit_type: "drift",
    rehearsal_fingerprint: (if $rehearsal_fingerprint == "" then null else $rehearsal_fingerprint end),
    overall: $overall,
    counts: $counts,
    key_findings: $key_findings,
    bundle_dir: $bundle_dir,
    manifest_path: $manifest_path,
    git_rev: $git_rev,
    flake_ref: $flake_ref
  }' >"$summary_json"

{
  echo "host=${host}"
  echo "timestamp=${timestamp}"
  echo "overall=${overall}"
  if [[ -n "$rehearsal_fingerprint" ]]; then
    echo "rehearsal_fingerprint=${rehearsal_fingerprint}"
  fi
  echo
  echo "== categorized findings =="
  jq -r '.findings[] | "\(.status)\t\(.severity)\t\(.category)\t\(.check)\t\(.message)"' "$findings_json"
  echo
  echo "== nullclaw systemd excerpt =="
  ssh "$host" "sudo systemctl status --no-pager -l nullclaw | sed -n '1,40p' || true"
  echo
  echo "== nullclaw journal excerpt (last 80 lines) =="
  ssh "$host" "sudo journalctl -u nullclaw -n 80 --no-pager || true"
} >"$details_txt"

echo "$bundle_dir"

if [[ "$overall" != "pass" ]]; then
  exit 1
fi
