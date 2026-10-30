#!/usr/bin/env bash
# Verify the deployment against the OCI API and the public endpoints.
# Needs: terraform (with state access), oci CLI (API-key auth), curl.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tf() { terraform -chdir="$ROOT" output -raw "$1" 2>/dev/null; }

PASS=0
FAIL=0

ok() { printf '  PASS  %s\n' "$1"; PASS=$((PASS + 1)); }
bad() { printf '  FAIL  %s (%s)\n' "$1" "${2:-}"; FAIL=$((FAIL + 1)); }
head_() { printf '\n%s\n' "$1"; }

head_ "Autonomous Database"
ADB_ID="$(tf autonomous_database_id)"
ADB_STATE="$(oci db autonomous-database get --autonomous-database-id "$ADB_ID" \
  --query data.lifecycleState --raw-output 2>/dev/null)"
[[ "$ADB_STATE" == "AVAILABLE" ]] && ok "ADB AVAILABLE" || bad "ADB state" "${ADB_STATE:-unreachable}"

FREE="$(oci db autonomous-database get --autonomous-database-id "$ADB_ID" \
  --query 'data."isFreeTier"' --raw-output 2>/dev/null)"
[[ "$FREE" == "true" ]] && ok "ADB reports Always Free" || bad "ADB is_free_tier" "${FREE:-unset}"

SHAPE="$(oci db autonomous-database get --autonomous-database-id "$ADB_ID" \
  --query 'data.{model:computeModel,count:computeCount}' --output json 2>/dev/null | tr -d ' \n')"
if grep -q '"count":2' <<<"$SHAPE" && grep -q 'ECPU' <<<"$SHAPE"; then
  ok "ADB compute is 2 ECPU (1 OCPU)"
else
  bad "ADB compute shape" "${SHAPE:-unknown}"
fi

PRIVATE_IP="$(oci db autonomous-database get --autonomous-database-id "$ADB_ID" \
  --query data.privateEndpointIp --raw-output 2>/dev/null)"
if [[ -n "$PRIVATE_IP" && "$PRIVATE_IP" != "null" ]]; then
  ok "ADB private endpoint is $PRIVATE_IP (app subnet only)"
else
  bad "ADB private endpoint" "no privateEndpointIp — the database may still be public"
fi

head_ "Secrets"
for name in adb_admin_password_secret_ocid app_password_secret_ocid; do
  LEN="$(oci secrets secret-bundle get --secret-id "$(tf "$name")" \
    --query 'length(data."secret-bundle-content".content)' --raw-output 2>/dev/null)"
  if [[ "${LEN:-0}" -gt 0 ]]; then ok "$name populated"; else bad "$name" "empty or unreadable"; fi
done

head_ "Load balancer"
LB_ID="$(tf load_balancer_id)"
[[ "$(oci lb load-balancer get --load-balancer-id "$LB_ID" --query data.lifecycleState --raw-output 2>/dev/null)" == "ACTIVE" ]] \
  && ok "load balancer ACTIVE" || bad "load balancer state" "not ACTIVE"
OK_BACKENDS="$(oci lb backend-set-health get --load-balancer-id "$LB_ID" --backend-set-name todo-backend \
  --query 'length(data.okStateBackendNames)' --raw-output 2>/dev/null)"
[[ "${OK_BACKENDS:-0}" -ge 1 ]] && ok "backend healthy" || bad "backend health" "0 healthy backends"
curl -fsS --max-time 20 "http://$(tf load_balancer_public_ip)/healthz" >/dev/null 2>&1 \
  && ok "GET /healthz over HTTP" || bad "/healthz over HTTP" "no 200 through the LB"
curl -fksS --max-time 20 "https://$(tf load_balancer_public_ip)/healthz" >/dev/null 2>&1 \
  && ok "GET /healthz over HTTPS" || bad "/healthz over HTTPS" "no 200 through the 443 listener"

head_ "DNS"
DNS_NAME="$(tf app_dns_name 2>/dev/null || true)"
if [[ -n "$DNS_NAME" && "$DNS_NAME" != "null" ]]; then
  resolved="$(getent ahostsv4 "$DNS_NAME" 2>/dev/null | awk '{print $1; exit}' || true)"
  [[ -z "$resolved" ]] && resolved="$(dig +short A "$DNS_NAME" 2>/dev/null | head -1 || true)"
  expected="$(tf load_balancer_public_ip)"
  if [[ "$resolved" == "$expected" ]]; then
    ok "$DNS_NAME resolves to the load balancer"
  else
    bad "$DNS_NAME" "resolves to ${resolved:-nothing}, expected $expected"
  fi
  curl -fsS --max-time 20 "https://$DNS_NAME/healthz" >/dev/null 2>&1 \
    && ok "GET /healthz on https://$DNS_NAME" \
    || bad "https://$DNS_NAME" "no 200 (DNS still propagating, or the certificate does not match)"
else
  printf '  SKIP  no managed A record; set acme_domain (and manage_dns) to track the load balancer IP\n'
fi

head_ "Observability"
for name in adb_cpu_alarm_id lb_unhealthy_alarm_id; do
  STATUS="$(oci monitoring alarm-status get --alarm-id "$(tf "$name")" --query data.status --raw-output 2>/dev/null)"
  [[ "$STATUS" == "OK" ]] && ok "$name OK" || bad "$name" "${STATUS:-unknown}"
done

head_ "APEX export"
if [[ -n "${ADB_LOCAL_PORT:-}" ]]; then
  if APEX_OUT="$("$ROOT/scripts/adb-sql.sh" --apex-check 2>&1)"; then
    ok "sql/apex export matches the database"
  else
    bad "sql/apex export is stale" "$(sed -n '1,3p' <<<"$APEX_OUT" | tr '\n' ' ')"
  fi
else
  printf '  SKIP  no tunnel; run ADB_LOCAL_PORT=<port> scripts/adb-sql.sh --apex-check to compare the export\n'
fi

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
printf 'APEX is on the private endpoint (%s) and needs a bastion tunnel: %s\n' \
  "$(tf adb_private_ip)" "$(tf apex_url)"
[[ "$FAIL" -eq 0 ]]
