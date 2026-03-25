#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: ai-host-promote.sh --host HOST --manifest PATH [--evidence-root PATH] [--drift-root PATH] [--promotions-root PATH] [--waivers PATH]
EOF
}

host=""
manifest=""
evidence_root="./evidence/ai-hosts"
drift_root="./evidence/drift"
promotions_root="./evidence/promotions"
waivers_file="./taskfiles/ai-host-waivers.json"
waivers_query_file=""

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
    --evidence-root)
      evidence_root="$2"
      shift 2
      ;;
    --drift-root)
      drift_root="$2"
      shift 2
      ;;
    --promotions-root)
      promotions_root="$2"
      shift 2
      ;;
    --waivers)
      waivers_file="$2"
      shift 2
      ;;
    *)
      usage
      exit 2
      ;;
  esac
done

if [[ -z "$host" || -z "$manifest" ]]; then
  usage
  exit 2
fi

command -v jq >/dev/null
jq -e --arg host "$host" '.hosts[$host] != null' "$manifest" >/dev/null

if [[ -f "$waivers_file" ]]; then
  waivers_query_file="$waivers_file"
else
  waivers_query_file="$(mktemp)"
  echo '{"hosts":{}}' >"$waivers_query_file"
  trap 'rm -f "$waivers_query_file"' EXIT
fi
waivers_recorded_path=""
if [[ -f "$waivers_file" ]]; then
  waivers_recorded_path="$waivers_file"
fi

latest_summary_for_suffix() {
  local root="$1"
  local target_host="$2"
  local suffix="$3"
  local latest=""
  local latest_ts=""
  shopt -s nullglob
  for file in "${root}/${target_host}"/*-"${suffix}"/summary.json; do
    [[ -f "$file" ]] || continue
    local ts
    ts="$(jq -r '.timestamp // ""' "$file" 2>/dev/null || true)"
    if [[ -z "$latest" || "$ts" > "$latest_ts" ]]; then
      latest="$file"
      latest_ts="$ts"
    fi
  done
  shopt -u nullglob
  echo "$latest"
}

read_result() {
  local file="$1"
  if [[ -z "$file" || ! -f "$file" ]]; then
    echo "missing"
  else
    jq -r '.result // .validation_result // .overall // "missing"' "$file" 2>/dev/null || echo "missing"
  fi
}

read_ts() {
  local file="$1"
  if [[ -z "$file" || ! -f "$file" ]]; then
    echo ""
  else
    jq -r '.timestamp // ""' "$file" 2>/dev/null || echo ""
  fi
}

iso_to_epoch() {
  local ts="$1"
  if [[ -z "$ts" ]]; then
    echo ""
  else
    date -u -d "$ts" +%s 2>/dev/null || echo ""
  fi
}

age_seconds() {
  local ts="$1"
  local now_epoch="$2"
  local epoch
  epoch="$(iso_to_epoch "$ts")"
  if [[ -z "$epoch" ]]; then
    echo ""
    return
  fi
  echo $((now_epoch - epoch))
}

count_blocking_failures() {
  local summary="$1"
  local findings="$2"
  if [[ -n "$findings" && -f "$findings" ]]; then
    jq -r '
      def normsev: if . == "critical" then "blocking" else . end;
      [.findings[]? | select(.status == "fail" and ((.severity|normsev) == "blocking"))] | length
    ' "$findings" 2>/dev/null || echo 0
  elif [[ -n "$summary" && -f "$summary" ]]; then
    jq -r '.counts.blocking_failures // .counts.critical_failures // 0' "$summary" 2>/dev/null || echo 0
  else
    echo 0
  fi
}

count_warning_failures() {
  local summary="$1"
  local findings="$2"
  if [[ -n "$findings" && -f "$findings" ]]; then
    jq -r '
      def normsev: if . == "critical" then "blocking" else . end;
      [.findings[]? | select(.status == "fail" and ((.severity|normsev) == "warning"))] | length
    ' "$findings" 2>/dev/null || echo 0
  elif [[ -n "$summary" && -f "$summary" ]]; then
    jq -r '.counts.warning_failures // 0' "$summary" 2>/dev/null || echo 0
  else
    echo 0
  fi
}

count_waived_warning_failures() {
  local findings="$1"
  if [[ -z "$findings" || ! -f "$findings" ]]; then
    echo 0
    return
  fi
  jq -r \
    --arg host "$host" \
    --argjson now "$(date -u +%s)" \
    --slurpfile wf "$waivers_query_file" '
      def normsev: if . == "critical" then "blocking" else . end;
      def active($w): (($w.expiresAt // "") == "") or (($w.expiresAt | fromdateiso8601?) // 0 >= $now);
      def match($f; $w):
        (($w.category // $f.category) == $f.category)
        and (($w.check // $f.check) == $f.check)
        and (($w.expected // $f.expected // "") == ($f.expected // ""));
      ($wf[0].hosts[$host] // []) as $waivers
      | [ .findings[]?
          | . as $f
          | select($f.status == "fail" and (($f.severity|normsev) == "warning"))
          | select(any($waivers[]?; active(.) and match($f; .)))
        ]
      | length
    ' "$findings" 2>/dev/null || echo 0
}

timestamp="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
stamp_compact="$(date -u +%Y%m%dT%H%M%SZ)"
receipt_dir="${promotions_root}/${host}/${stamp_compact}-promotion"
mkdir -p "$receipt_dir"
receipt_json="${receipt_dir}/receipt.json"
receipt_txt="${receipt_dir}/details.txt"
baseline_file="${promotions_root}/${host}/baseline.json"

git_rev="$(git rev-parse --verify HEAD 2>/dev/null || echo unknown)"
flake_ref=".?submodules=1#${host}"
host_class="$(jq -r --arg host "$host" '.hosts[$host].hostClass // ""' "$manifest")"
promotion_group="$(jq -r --arg host "$host" '.hosts[$host].promotionGroup // ""' "$manifest")"

validation_summary="$(latest_summary_for_suffix "$evidence_root" "$host" "validate")"
drift_summary="$(latest_summary_for_suffix "$drift_root" "$host" "drift")"
validation_findings=""
drift_findings=""
[[ -n "$validation_summary" ]] && validation_findings="$(dirname "$validation_summary")/findings.json"
[[ -n "$drift_summary" ]] && drift_findings="$(dirname "$drift_summary")/findings.json"

readiness="ready"
readiness_reason="all-gates-passed"
validation_result="$(read_result "$validation_summary")"
drift_result="$(read_result "$drift_summary")"
validation_ts="$(read_ts "$validation_summary")"
drift_ts="$(read_ts "$drift_summary")"
now_epoch="$(date -u +%s)"
max_validation_age="$(jq -r --arg host "$host" '.hosts[$host].policy.maxValidationAgeSeconds // .policyDefaults.maxValidationAgeSeconds // 86400' "$manifest")"
max_drift_age="$(jq -r --arg host "$host" '.hosts[$host].policy.maxDriftAgeSeconds // .policyDefaults.maxDriftAgeSeconds // 86400' "$manifest")"
validation_age="$(age_seconds "$validation_ts" "$now_epoch")"
drift_age="$(age_seconds "$drift_ts" "$now_epoch")"
validation_blocking="$(count_blocking_failures "$validation_summary" "$validation_findings")"
drift_blocking="$(count_blocking_failures "$drift_summary" "$drift_findings")"
validation_warning="$(count_warning_failures "$validation_summary" "$validation_findings")"
drift_warning="$(count_warning_failures "$drift_summary" "$drift_findings")"
validation_waived_warning="$(count_waived_warning_failures "$validation_findings")"
drift_waived_warning="$(count_waived_warning_failures "$drift_findings")"
effective_warning_count=$((validation_warning - validation_waived_warning + drift_warning - drift_waived_warning))
if [[ "$effective_warning_count" -lt 0 ]]; then
  effective_warning_count=0
fi

if [[ -z "$validation_summary" ]]; then
  readiness="not-ready"
  readiness_reason="no-validation-evidence"
elif [[ "$validation_result" != "pass" ]]; then
  readiness="not-ready"
  readiness_reason="validation-failed"
elif [[ -z "$validation_age" || "$validation_age" -gt "$max_validation_age" ]]; then
  readiness="not-ready"
  readiness_reason="validation-stale"
elif [[ "$validation_blocking" -gt 0 ]]; then
  readiness="not-ready"
  readiness_reason="validation-blocking-findings"
elif [[ -z "$drift_summary" ]]; then
  readiness="not-ready"
  readiness_reason="no-drift-evidence"
elif [[ "$drift_result" != "pass" ]]; then
  readiness="not-ready"
  readiness_reason="drift-failed"
elif [[ -z "$drift_age" || "$drift_age" -gt "$max_drift_age" ]]; then
  readiness="not-ready"
  readiness_reason="drift-stale"
elif [[ -n "$validation_ts" && -n "$drift_ts" && "$drift_ts" < "$validation_ts" ]]; then
  readiness="not-ready"
  readiness_reason="drift-older-than-validation"
elif [[ "$drift_blocking" -gt 0 ]]; then
  readiness="not-ready"
  readiness_reason="drift-blocking-findings"
fi

result="fail"
baseline_designation="none"

if [[ "$readiness" == "ready" ]]; then
  tmp_baseline="$(mktemp)"
  jq -n \
    --arg host "$host" \
    --arg updated_at "$timestamp" \
    --arg promotion_group "$promotion_group" \
    --arg host_class "$host_class" \
    --arg source_receipt "$receipt_json" \
    --arg baseline_validation_summary "$validation_summary" \
    --arg baseline_drift_summary "$drift_summary" \
    --arg baseline_validation_findings "$validation_findings" \
    --arg baseline_drift_findings "$drift_findings" \
    '{
      schema_version: 1,
      host: $host,
      updated_at: $updated_at,
      promotion_group: $promotion_group,
      host_class: $host_class,
      source_receipt: $source_receipt,
      baseline_validation_summary: $baseline_validation_summary,
      baseline_drift_summary: $baseline_drift_summary,
      baseline_validation_findings: $baseline_validation_findings,
      baseline_drift_findings: $baseline_drift_findings
    }' >"$tmp_baseline"

  if mkdir -p "$(dirname "$baseline_file")" && mv "$tmp_baseline" "$baseline_file"; then
    result="pass"
    baseline_designation="updated"
  else
    readiness="not-ready"
    readiness_reason="baseline-update-failed"
    result="fail"
    baseline_designation="update-failed"
    rm -f "$tmp_baseline" || true
  fi
fi

jq -n \
  --arg schema_version "1" \
  --arg host "$host" \
  --arg timestamp "$timestamp" \
  --arg git_rev "$git_rev" \
  --arg flake_ref "$flake_ref" \
  --arg promotion_group "$promotion_group" \
  --arg host_class "$host_class" \
  --arg readiness "$readiness" \
  --arg readiness_reason "$readiness_reason" \
  --arg result "$result" \
  --arg baseline_designation "$baseline_designation" \
  --arg baseline_file "$baseline_file" \
  --arg validation_summary "$validation_summary" \
  --arg drift_summary "$drift_summary" \
  --arg validation_findings "$validation_findings" \
  --arg drift_findings "$drift_findings" \
  --arg manifest_path "$manifest" \
  --arg waivers_path "${waivers_recorded_path}" \
  --argjson max_validation_age_seconds "$max_validation_age" \
  --argjson max_drift_age_seconds "$max_drift_age" \
  --argjson validation_age_seconds "${validation_age:-0}" \
  --argjson drift_age_seconds "${drift_age:-0}" \
  --argjson validation_blocking_failures "$validation_blocking" \
  --argjson drift_blocking_failures "$drift_blocking" \
  --argjson validation_warning_failures "$validation_warning" \
  --argjson drift_warning_failures "$drift_warning" \
  --argjson validation_waived_warning_failures "$validation_waived_warning" \
  --argjson drift_waived_warning_failures "$drift_waived_warning" \
  --argjson effective_warning_count "$effective_warning_count" \
  '{
    schema_version: ($schema_version|tonumber),
    host: $host,
    timestamp: $timestamp,
    event: "promotion",
    result: $result,
    readiness: $readiness,
    readiness_reason: $readiness_reason,
    git_rev: $git_rev,
    flake_ref: $flake_ref,
    promotion_group: $promotion_group,
    host_class: $host_class,
    manifest_path: $manifest_path,
    waivers_path: $waivers_path,
    freshness_policy: {
      max_validation_age_seconds: $max_validation_age_seconds,
      max_drift_age_seconds: $max_drift_age_seconds
    },
    evidence_ages_seconds: {
      validation: $validation_age_seconds,
      drift: $drift_age_seconds
    },
    finding_summary: {
      validation_blocking_failures: $validation_blocking_failures,
      drift_blocking_failures: $drift_blocking_failures,
      validation_warning_failures: $validation_warning_failures,
      drift_warning_failures: $drift_warning_failures,
      validation_waived_warning_failures: $validation_waived_warning_failures,
      drift_waived_warning_failures: $drift_waived_warning_failures,
      effective_warning_count: $effective_warning_count
    },
    evidence_paths: {
      validation_summary: $validation_summary,
      drift_summary: $drift_summary,
      validation_findings: $validation_findings,
      drift_findings: $drift_findings
    },
    baseline_designation: $baseline_designation,
    baseline_file: $baseline_file
  }' >"$receipt_json"

{
  echo "host=${host}"
  echo "timestamp=${timestamp}"
  echo "event=promotion"
  echo "result=${result}"
  echo "readiness=${readiness}"
  echo "readiness_reason=${readiness_reason}"
  echo "max_validation_age_seconds=${max_validation_age}"
  echo "max_drift_age_seconds=${max_drift_age}"
  echo "validation_age_seconds=${validation_age:-unknown}"
  echo "drift_age_seconds=${drift_age:-unknown}"
  echo "validation_blocking_failures=${validation_blocking}"
  echo "drift_blocking_failures=${drift_blocking}"
  echo "effective_warning_count=${effective_warning_count}"
  echo "promotion_group=${promotion_group}"
  echo "host_class=${host_class}"
  echo "git_rev=${git_rev}"
  echo "flake_ref=${flake_ref}"
  echo "validation_summary=${validation_summary:-none}"
  echo "drift_summary=${drift_summary:-none}"
  echo "baseline_designation=${baseline_designation}"
  echo "baseline_file=${baseline_file}"
} >"$receipt_txt"

echo "$receipt_dir"

if [[ "$result" != "pass" ]]; then
  echo "promotion failed: ${readiness_reason}" >&2
  exit 1
fi
