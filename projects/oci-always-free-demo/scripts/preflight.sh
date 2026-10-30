#!/usr/bin/env bash
# Check the operator's machine before running terraform or adb-sql.sh.
#
#   scripts/preflight.sh
#   ADB_LOCAL_PORT=1522 scripts/preflight.sh
#
# Exits 1 when a required check fails. SKIP means "not needed for the step you
# are on", not a pass.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PASS=0
FAIL=0

ok() { printf '  PASS  %s\n' "$1"; PASS=$((PASS + 1)); }
bad() { printf '  FAIL  %s%s\n' "$1" "${2:+ ($2)}"; FAIL=$((FAIL + 1)); }
skip() { printf '  SKIP  %s%s\n' "$1" "${2:+ ($2)}"; }
head_() { printf '\n%s\n' "$1"; }

head_ "Tools"
if command -v terraform >/dev/null 2>&1; then
  TF=terraform
elif command -v tofu >/dev/null 2>&1; then
  TF=tofu
else
  TF=""
fi
[[ -n "$TF" ]] && ok "$($TF version | head -1)" || bad "terraform/opentofu missing" "install one to plan or apply"

for bin in oci jq unzip curl ssh; do
  command -v "$bin" >/dev/null 2>&1 && ok "$bin present" || bad "$bin missing"
done

if command -v sql >/dev/null 2>&1; then
  ok "SQLcl present"
else
  skip "SQLcl (sql) missing" "needed for --bootstrap and the APEX modes"
fi

head_ "OCI authentication"
if [[ -r "${OCI_CLI_CONFIG_FILE:-$HOME/.oci/config}" ]]; then
  ok "OCI config readable"
else
  bad "no ~/.oci/config" "run: oci setup config"
fi

if command -v oci >/dev/null 2>&1; then
  if oci iam region list --query 'length(data)' --raw-output >/dev/null 2>&1; then
    ok "oci CLI authenticates"
  else
    bad "oci CLI cannot authenticate" "check the API key and profile"
  fi
fi

head_ "Terraform state"
if [[ -z "$TF" ]]; then
  skip "no terraform binary" "cannot read state"
elif "${TF}" -chdir="$ROOT" output -raw adb_private_ip >/dev/null 2>&1; then
  ok "state readable (adb_private_ip output present)"
else
  bad "cannot read state" "terraform init -backend-config=backend.hcl, or the stack is not applied yet"
fi

head_ "Keys"
if compgen -G "$HOME/.ssh/*.pub" >/dev/null; then
  ok "an SSH public key exists for bastion sessions"
else
  skip "no ~/.ssh/*.pub" "bastion sessions need a key whose public half you pass to the CLI"
fi

head_ "Database tunnel"
if [[ -n "${ADB_LOCAL_PORT:-}" ]]; then
  if [[ "$ADB_LOCAL_PORT" =~ ^[0-9]+$ ]] && (echo >"/dev/tcp/127.0.0.1/$ADB_LOCAL_PORT") 2>/dev/null; then
    ok "tunnel answers on 127.0.0.1:$ADB_LOCAL_PORT"
  else
    bad "nothing listening on 127.0.0.1:$ADB_LOCAL_PORT" "run the ssh command from adb_sql_tunnel_command"
  fi
else
  skip "ADB_LOCAL_PORT unset" "SQL and APEX need the bastion port-forward; see adb_sql_tunnel_command"
fi

head_ "Checked-in APEX export"
if [[ -f "$ROOT/sql/apex/f100.sql" ]]; then
  ok "sql/apex/f100.sql present"
else
  skip "sql/apex/f100.sql absent" "build the app once, then --as WORKSPACE --apex export"
fi

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[[ "$FAIL" -eq 0 ]]
