#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  ai-host-status.sh --mode fleet --manifest PATH [--evidence-root PATH] [--drift-root PATH] [--promotions-root PATH] [--waivers PATH]
  ai-host-status.sh --mode host --host HOST --manifest PATH [--evidence-root PATH] [--drift-root PATH] [--promotions-root PATH] [--waivers PATH]
  ai-host-status.sh --mode readiness --manifest PATH [--evidence-root PATH] [--drift-root PATH] [--promotions-root PATH] [--waivers PATH]
  ai-host-status.sh --mode delta --host HOST --manifest PATH [--evidence-root PATH] [--drift-root PATH] [--promotions-root PATH] [--waivers PATH]
USAGE
}

mode=""
host=""
manifest=""
evidence_root="./evidence/ai-hosts"
drift_root="./evidence/drift"
promotions_root="./evidence/promotions"
waivers_file="./taskfiles/ai-host-waivers.json"
waivers_query_file=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --mode)
      mode="$2"
      shift 2
      ;;
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

if [[ -z "$mode" || -z "$manifest" ]]; then
  usage
  exit 2
fi

command -v jq >/dev/null
jq -e '.hosts | type == "object"' "$manifest" >/dev/null

if [[ -f "$waivers_file" ]]; then
  waivers_query_file="$waivers_file"
else
  waivers_query_file="$(mktemp)"
  echo '{"hosts":{}}' >"$waivers_query_file"
  trap 'rm -f "$waivers_query_file"' EXIT
fi

now_epoch="$(date -u +%s)"

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
  local epoch
  epoch="$(iso_to_epoch "$ts")"
  if [[ -z "$epoch" ]]; then
    echo ""
    return
  fi
  echo $((now_epoch - epoch))
}

policy_max_validation_age() {
  local target_host="$1"
  jq -r --arg host "$target_host" '.hosts[$host].policy.maxValidationAgeSeconds // .policyDefaults.maxValidationAgeSeconds // 86400' "$manifest"
}

policy_max_drift_age() {
  local target_host="$1"
  jq -r --arg host "$target_host" '.hosts[$host].policy.maxDriftAgeSeconds // .policyDefaults.maxDriftAgeSeconds // 86400' "$manifest"
}

host_availability() {
  local target_host="$1"
  jq -r --arg host "$target_host" '.hosts[$host].availability // "always-on"' "$manifest"
}

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

latest_rehearsal_drift_summary() {
  local target_host="$1"
  local latest=""
  local latest_ts=""
  shopt -s nullglob
  for file in "${drift_root}/${target_host}"/*-drift/summary.json; do
    [[ -f "$file" ]] || continue
    local has_rehearsal
    has_rehearsal="$(jq -r '(.rehearsal_fingerprint // "")' "$file" 2>/dev/null || true)"
    [[ -n "$has_rehearsal" ]] || continue
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

latest_good_validation_summary() {
  local target_host="$1"
  local latest=""
  local latest_ts=""
  shopt -s nullglob
  for file in "${evidence_root}/${target_host}"/*-validate/summary.json; do
    [[ -f "$file" ]] || continue
    local result
    result="$(jq -r '.result // .validation_result // .overall // "unknown"' "$file" 2>/dev/null || true)"
    [[ "$result" == "pass" ]] || continue
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

baseline_file_for_host() {
  local target_host="$1"
  local file="${promotions_root}/${target_host}/baseline.json"
  if [[ -f "$file" ]]; then
    echo "$file"
  else
    echo ""
  fi
}

baseline_summary_for_host() {
  local target_host="$1"
  local baseline_file
  baseline_file="$(baseline_file_for_host "$target_host")"
  if [[ -z "$baseline_file" ]]; then
    echo ""
    return
  fi

  local preferred
  preferred="$(jq -r '.baseline_drift_summary // .baseline_validation_summary // ""' "$baseline_file" 2>/dev/null || true)"
  if [[ -n "$preferred" && -f "$preferred" ]]; then
    echo "$preferred"
  else
    echo ""
  fi
}

summary_field() {
  local file="$1"
  local expr="$2"
  if [[ -z "$file" || ! -f "$file" ]]; then
    echo ""
  else
    jq -r "$expr" "$file" 2>/dev/null || true
  fi
}

findings_file_for_summary() {
  local summary="$1"
  if [[ -z "$summary" ]]; then
    echo ""
  else
    local f
    f="$(dirname "$summary")/findings.json"
    if [[ -f "$f" ]]; then
      echo "$f"
    else
      echo ""
    fi
  fi
}

count_blocking_failures() {
  local summary="$1"
  local findings="$2"
  if [[ -n "$findings" ]]; then
    jq -r '
      def normsev: if . == "critical" then "blocking" else . end;
      [.findings[]? | select(.status == "fail" and ((.severity|normsev) == "blocking"))] | length
    ' "$findings" 2>/dev/null || echo 0
  elif [[ -n "$summary" ]]; then
    jq -r '.counts.blocking_failures // .counts.critical_failures // 0' "$summary" 2>/dev/null || echo 0
  else
    echo 0
  fi
}

count_warning_failures() {
  local summary="$1"
  local findings="$2"
  if [[ -n "$findings" ]]; then
    jq -r '
      def normsev: if . == "critical" then "blocking" else . end;
      [.findings[]? | select(.status == "fail" and ((.severity|normsev) == "warning"))] | length
    ' "$findings" 2>/dev/null || echo 0
  elif [[ -n "$summary" ]]; then
    jq -r '.counts.warning_failures // 0' "$summary" 2>/dev/null || echo 0
  else
    echo 0
  fi
}

count_waived_warning_failures() {
  local target_host="$1"
  local findings="$2"

  if [[ -z "$findings" ]]; then
    echo 0
    return
  fi

  jq -r \
    --arg host "$target_host" \
    --argjson now "$now_epoch" \
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

non_negative_subtract() {
  local left="$1"
  local right="$2"
  local value=$((left - right))
  if [[ "$value" -lt 0 ]]; then
    echo 0
  else
    echo "$value"
  fi
}

host_readiness() {
  local target_host="$1"
  local validate_summary="$2"
  local drift_summary="$3"

  local max_validation_age max_drift_age
  max_validation_age="$(policy_max_validation_age "$target_host")"
  max_drift_age="$(policy_max_drift_age "$target_host")"

  local availability
  availability="$(host_availability "$target_host")"

  if [[ -z "$validate_summary" ]]; then
    if [[ "$availability" == "on-demand" ]]; then
      echo "standby:on-demand-no-validation|0|0"
    else
      echo "not-ready:no-validation-evidence|0|0"
    fi
    return
  fi

  local validate_result validate_ts validate_age
  validate_result="$(summary_field "$validate_summary" '.result // .validation_result // .overall // "unknown"')"
  validate_ts="$(summary_field "$validate_summary" '.timestamp // ""')"
  validate_age="$(age_seconds "$validate_ts")"

  if [[ "$validate_result" != "pass" ]]; then
    echo "not-ready:validation-failed|0|0"
    return
  fi

  if [[ -z "$validate_age" || "$validate_age" -gt "$max_validation_age" ]]; then
    if [[ "$availability" == "on-demand" ]]; then
      echo "standby:on-demand-validation-stale|0|0"
    else
      echo "not-ready:validation-stale|0|0"
    fi
    return
  fi

  local validate_findings validate_blocking validate_warning validate_waived
  validate_findings="$(findings_file_for_summary "$validate_summary")"
  validate_blocking="$(count_blocking_failures "$validate_summary" "$validate_findings")"
  validate_warning="$(count_warning_failures "$validate_summary" "$validate_findings")"
  validate_waived="$(count_waived_warning_failures "$target_host" "$validate_findings")"

  if [[ "$validate_blocking" -gt 0 ]]; then
    echo "not-ready:validation-blocking-findings|$validate_blocking|$(non_negative_subtract "$validate_warning" "$validate_waived")"
    return
  fi

  if [[ -z "$drift_summary" ]]; then
    if [[ "$availability" == "on-demand" ]]; then
      echo "standby:on-demand-no-drift|0|$(non_negative_subtract "$validate_warning" "$validate_waived")"
    else
      echo "not-ready:no-drift-evidence|0|$(non_negative_subtract "$validate_warning" "$validate_waived")"
    fi
    return
  fi

  local drift_result drift_ts drift_age
  drift_result="$(summary_field "$drift_summary" '.result // .overall // "unknown"')"
  drift_ts="$(summary_field "$drift_summary" '.timestamp // ""')"
  drift_age="$(age_seconds "$drift_ts")"

  if [[ "$drift_result" != "pass" ]]; then
    echo "not-ready:drift-failed|0|$(non_negative_subtract "$validate_warning" "$validate_waived")"
    return
  fi

  if [[ -z "$drift_age" || "$drift_age" -gt "$max_drift_age" ]]; then
    if [[ "$availability" == "on-demand" ]]; then
      echo "standby:on-demand-drift-stale|0|$(non_negative_subtract "$validate_warning" "$validate_waived")"
    else
      echo "not-ready:drift-stale|0|$(non_negative_subtract "$validate_warning" "$validate_waived")"
    fi
    return
  fi

  if [[ -n "$validate_ts" && -n "$drift_ts" && "$drift_ts" < "$validate_ts" ]]; then
    if [[ "$availability" == "on-demand" ]]; then
      echo "standby:on-demand-drift-older-than-validation|0|$(non_negative_subtract "$validate_warning" "$validate_waived")"
    else
      echo "not-ready:drift-older-than-validation|0|$(non_negative_subtract "$validate_warning" "$validate_waived")"
    fi
    return
  fi

  local drift_findings drift_blocking drift_warning drift_waived
  drift_findings="$(findings_file_for_summary "$drift_summary")"
  drift_blocking="$(count_blocking_failures "$drift_summary" "$drift_findings")"
  drift_warning="$(count_warning_failures "$drift_summary" "$drift_findings")"
  drift_waived="$(count_waived_warning_failures "$target_host" "$drift_findings")"

  if [[ "$drift_blocking" -gt 0 ]]; then
    echo "not-ready:drift-blocking-findings|$drift_blocking|$(non_negative_subtract "$drift_warning" "$drift_waived")"
    return
  fi

  local effective_warning
  effective_warning=$(( $(non_negative_subtract "$validate_warning" "$validate_waived") + $(non_negative_subtract "$drift_warning" "$drift_waived") ))
  if [[ "$effective_warning" -gt 0 ]]; then
    echo "ready:with-warnings|0|$effective_warning"
  else
    echo "ready|0|0"
  fi
}

print_host_status_line() {
  local target_host="$1"
  local cls grp
  cls="$(jq -r --arg host "$target_host" '.hosts[$host].hostClass' "$manifest")"
  grp="$(jq -r --arg host "$target_host" '.hosts[$host].promotionGroup' "$manifest")"

  local validate_summary drift_summary rehearsal_summary baseline_file
  validate_summary="$(latest_summary_for_suffix "$evidence_root" "$target_host" "validate")"
  drift_summary="$(latest_summary_for_suffix "$drift_root" "$target_host" "drift")"
  rehearsal_summary="$(latest_rehearsal_drift_summary "$target_host")"
  baseline_file="$(baseline_file_for_host "$target_host")"

  local v_ts v_rs d_ts d_rs r_ts r_rs baseline_ts baseline_state baseline_age ready_info ready_state warn_count
  v_ts="$(summary_field "$validate_summary" '.timestamp // ""')"
  v_rs="$(summary_field "$validate_summary" '.result // .validation_result // .overall // "missing"')"
  d_ts="$(summary_field "$drift_summary" '.timestamp // ""')"
  d_rs="$(summary_field "$drift_summary" '.result // .overall // "missing"')"
  r_ts="$(summary_field "$rehearsal_summary" '.timestamp // ""')"
  r_rs="$(summary_field "$rehearsal_summary" '.result // .overall // "missing"')"
  baseline_ts="$(summary_field "$baseline_file" '.updated_at // ""')"
  baseline_age="$(age_seconds "$baseline_ts")"
  baseline_state="none"
  if [[ -n "$baseline_file" ]]; then
    baseline_state="set"
  fi

  v_rs="${v_rs:-missing}"
  d_rs="${d_rs:-missing}"
  r_rs="${r_rs:-missing}"
  v_ts="${v_ts:-none}"
  d_ts="${d_ts:-none}"
  r_ts="${r_ts:-none}"
  baseline_ts="${baseline_ts:-none}"
  baseline_age="${baseline_age:-none}"

  ready_info="$(host_readiness "$target_host" "$validate_summary" "$drift_summary")"
  ready_state="${ready_info%%|*}"
  warn_count="$(echo "$ready_info" | awk -F'|' '{print $3}')"

  printf "%-14s %-8s %-8s %-8s %-20s %-8s %-20s %-8s %-20s %-8s %-20s %-10s %-28s\n" \
    "$target_host" "$cls" "$grp" "$v_rs" "$v_ts" "$d_rs" "$d_ts" "$r_rs" "$r_ts" "$baseline_state" "$baseline_ts" "$baseline_age" "${ready_state}(w=${warn_count:-0})"
}

print_delta_report() {
  local target_host="$1"
  local baseline_summary drift_summary baseline_source
  baseline_summary="$(baseline_summary_for_host "$target_host")"
  baseline_source="promoted-baseline"
  if [[ -z "$baseline_summary" ]]; then
    baseline_summary="$(latest_good_validation_summary "$target_host")"
    baseline_source="latest-good-validation"
  fi
  drift_summary="$(latest_summary_for_suffix "$drift_root" "$target_host" "drift")"

  echo "host=${target_host}"
  echo "baseline_source=${baseline_source}"
  echo "baseline_summary=${baseline_summary:-none}"
  echo "latest_drift_summary=${drift_summary:-none}"

  if [[ -z "$drift_summary" ]]; then
    echo "delta_status=unknown:no-drift-evidence"
    return
  fi

  local baseline_findings drift_findings
  baseline_findings="$(findings_file_for_summary "$baseline_summary")"
  drift_findings="$(findings_file_for_summary "$drift_summary")"

  if [[ -z "$drift_findings" ]]; then
    echo "delta_status=unknown:drift-findings-missing"
    return
  fi

  local tmp_base
  tmp_base="$(mktemp)"
  if [[ -n "$baseline_findings" && -f "$baseline_findings" ]]; then
    cat "$baseline_findings" >"$tmp_base"
  else
    echo '{"findings":[]}' >"$tmp_base"
  fi

  local tmp_delta
  tmp_delta="$(mktemp)"
  jq -n \
    --arg host "$target_host" \
    --argjson now "$now_epoch" \
    --slurpfile base "$tmp_base" \
    --slurpfile cur "$drift_findings" \
    --slurpfile wf "$waivers_query_file" '
      def normsev: if . == "critical" then "blocking" else . end;
      def active($w): (($w.expiresAt // "") == "") or (($w.expiresAt | fromdateiso8601?) // 0 >= $now);
      def match($f; $w):
        (($w.category // $f.category) == $f.category)
        and (($w.check // $f.check) == $f.check)
        and (($w.expected // $f.expected // "") == ($f.expected // ""));
      def waived($f): any(($wf[0].hosts[$host] // [])[]?; active(.) and match($f; .));
      def effective_failed($x):
        [($x[0].findings // [])[]
          | select(.status == "fail")
          | .severity = (.severity|normsev)
          | select((.severity == "blocking") or (.severity == "warning" and (waived(.) | not)))
        ];
      def key($f): ($f.severity + "|" + $f.category + "|" + $f.check + "|" + ($f.expected // ""));
      (effective_failed($base)) as $b
      | (effective_failed($cur)) as $c
      | ($b | map(key(.))) as $bkeys
      | ($c | map(select((key(.)) as $k | ($bkeys | index($k)) == null))) as $new
      | {
        host: $host,
        baseline_failures: ($b | length),
        current_failures: ($c | length),
        new_failures_count: ($new | length),
        new_failures: $new
      }
    ' >"$tmp_delta"

  local new_count
  new_count="$(jq -r '.new_failures_count' "$tmp_delta")"
  if [[ "$new_count" == "0" ]]; then
    echo "delta_status=ok:no-new-failures"
  else
    echo "delta_status=drift:new-failures"
    echo "new_failures:"
    jq -r '.new_failures[] | "- [\(.severity)] \(.category)/\(.check): \(.message) (expected=\(.expected), actual=\(.actual))"' "$tmp_delta"
  fi

  rm -f "$tmp_base" "$tmp_delta"
}

case "$mode" in
  fleet)
    printf "%-14s %-8s %-8s %-8s %-20s %-8s %-20s %-8s %-20s %-8s %-20s %-10s %-28s\n" \
      "HOST" "CLASS" "GROUP" "VAL" "VAL_TS" "DRIFT" "DRIFT_TS" "REHRSL" "REHRSL_TS" "BASELN" "BASELN_TS" "B_AGE" "PROMOTION_READINESS"
    while IFS= read -r h; do
      print_host_status_line "$h"
    done < <(jq -r '.hosts | keys[]' "$manifest")
    ;;
  host)
    if [[ -z "$host" ]]; then
      usage
      exit 2
    fi
    jq -e --arg host "$host" '.hosts[$host] != null' "$manifest" >/dev/null
    printf "%-14s %-8s %-8s %-8s %-20s %-8s %-20s %-8s %-20s %-8s %-20s %-10s %-28s\n" \
      "HOST" "CLASS" "GROUP" "VAL" "VAL_TS" "DRIFT" "DRIFT_TS" "REHRSL" "REHRSL_TS" "BASELN" "BASELN_TS" "B_AGE" "PROMOTION_READINESS"
    print_host_status_line "$host"
    ;;
  readiness)
    printf "%-14s %-8s %-8s %-28s\n" "HOST" "CLASS" "GROUP" "PROMOTION_READINESS"
    while IFS= read -r h; do
      cls="$(jq -r --arg host "$h" '.hosts[$host].hostClass' "$manifest")"
      grp="$(jq -r --arg host "$h" '.hosts[$host].promotionGroup' "$manifest")"
      validate_summary="$(latest_summary_for_suffix "$evidence_root" "$h" "validate")"
      drift_summary="$(latest_summary_for_suffix "$drift_root" "$h" "drift")"
      ready_info="$(host_readiness "$h" "$validate_summary" "$drift_summary")"
      ready_state="${ready_info%%|*}"
      warn_count="$(echo "$ready_info" | awk -F'|' '{print $3}')"
      printf "%-14s %-8s %-8s %-28s\n" "$h" "$cls" "$grp" "${ready_state}(w=${warn_count:-0})"
    done < <(jq -r '.hosts | keys[]' "$manifest")
    ;;
  delta)
    if [[ -z "$host" ]]; then
      usage
      exit 2
    fi
    jq -e --arg host "$host" '.hosts[$host] != null' "$manifest" >/dev/null
    print_delta_report "$host"
    ;;
  *)
    usage
    exit 2
    ;;
esac
