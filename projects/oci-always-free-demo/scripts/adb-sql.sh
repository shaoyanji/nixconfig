#!/usr/bin/env bash
# SQL and APEX plumbing for the demo database, which has a private endpoint.
#
#   scripts/adb-sql.sh --bootstrap
#       schema (ADMIN) -> table (TODO_APP) -> workspace (ADMIN) -> APEX import
#       (TODO_ADMIN) when sql/apex/f<id>.sql exists.
#   scripts/adb-sql.sh --as ADMIN sql/01_schema.sql
#   scripts/adb-sql.sh --as APP sql/02_table.sql
#   scripts/adb-sql.sh --as WORKSPACE --apex export
#   scripts/adb-sql.sh --as WORKSPACE --apex import
#   scripts/adb-sql.sh --apex-check
#       re-exports the application and diffs it against the checked-in file;
#       exits 1 when the repository is behind the database.
#
# SQL scripts receive two positional arguments: &1 is the TODO_APP password and
# &2 is the notification email.
#
# The database is only reachable from the app subnet. Get in with a bastion
# port-forward (terraform output -raw adb_sql_tunnel_command), run the ssh
# command it returns in another terminal, then set ADB_LOCAL_PORT to the local
# port that command mapped.
#
# Needs: terraform (with state access), oci CLI (API-key auth), unzip, and SQLcl
# (`sql`) or Oracle Instant Client (`sqlplus`).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APEX_DIR="$ROOT/sql/apex"
APP_ID="${APEX_APP_ID:-100}"

usage() { sed -n '2,/^set -euo pipefail$/p' "${BASH_SOURCE[0]}" | sed '$d' | sed 's/^# \{0,1\}//'; }

AS=ADMIN
MODE=script
SCRIPT=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --as) AS="${2:?--as needs ADMIN, APP or WORKSPACE}"; shift 2 ;;
    --apex) MODE="apex-${2:?--apex needs export or import}"; shift 2 ;;
    --apex-check) MODE=apex-check; shift ;;
    --bootstrap) MODE=bootstrap; shift ;;
    -h | --help) usage; exit 0 ;;
    --*) echo "unknown flag: $1" >&2; usage; exit 2 ;;
    *) SCRIPT="$1"; shift ;;
  esac
done

for bin in terraform oci base64 unzip; do
  command -v "$bin" >/dev/null 2>&1 || { echo "missing required tool: $bin" >&2; exit 1; }
done

tf() { terraform -chdir="$ROOT" output -raw "$1"; }

secret_content() {
  oci secrets secret-bundle get \
    --secret-id "$1" \
    --query 'data."secret-bundle-content".content' \
    --raw-output | base64 -d
}

DB_USER_FOR() {
  case "$1" in
    ADMIN) echo ADMIN ;;
    APP) echo TODO_APP ;;
    WORKSPACE) echo TODO_ADMIN ;;
    *) echo "unknown user: $1 (use ADMIN, APP or WORKSPACE)" >&2; exit 2 ;;
  esac
}

PASSWORD_FOR() {
  case "$1" in
    ADMIN) echo "$ADMIN_PW" ;;
    *) echo "$APP_PW" ;;
  esac
}

CONNECT_STRING="$(tf adb_connection_string_low || true)"
[[ -n "$CONNECT_STRING" ]] || { echo "no connection string output; is the database provisioned?" >&2; exit 1; }

if [[ -n "${ADB_LOCAL_PORT:-}" ]]; then
  # Through the tunnel the endpoint's own hostname is not resolvable, so the
  # descriptor is pointed at the local port. The certificate DN from the
  # descriptor is kept, so TLS server identity is still verified.
  CONNECT_STRING="$(sed -E \
    -e "s/\(host=[^)]+\)/(host=127.0.0.1)/g" \
    -e "s/\(port=[0-9]+\)/(port=${ADB_LOCAL_PORT})/g" <<<"$CONNECT_STRING")"
fi

TMP="$(mktemp -d)"
chmod 700 "$TMP"
trap 'rm -rf "$TMP"' EXIT

NAMESPACE="$(tf artifacts_bucket_namespace)"
BUCKET="$(tf artifacts_bucket_name)"
OBJECT="$(tf wallet_object)"

oci os object get \
  --namespace "$NAMESPACE" \
  --bucket-name "$BUCKET" \
  --name "$OBJECT" \
  --file "$TMP/wallet.b64" >/dev/null
base64 -d "$TMP/wallet.b64" > "$TMP/wallet.zip"
unzip -q "$TMP/wallet.zip" -d "$TMP/wallet"

ADMIN_PW="$(secret_content "$(tf adb_admin_password_secret_ocid)")"
APP_PW="$(secret_content "$(tf app_password_secret_ocid)")"
EMAIL="$(tf notification_email)"

run_sql() {
  local user="$1"
  shift
  local connect
  connect="$user/$(PASSWORD_FOR "$user")@$CONNECT_STRING"

  if command -v sql >/dev/null 2>&1; then
    sql -S -cloudconfig "$TMP/wallet.zip" "$connect" "$@"
  else
    TNS_ADMIN="$TMP/wallet" sqlplus -S "$connect" "$@"
  fi
}

run_as() {
  local role="$1"
  shift
  run_sql "$(DB_USER_FOR "$role")" "$@"
}

need_sqlcl() {
  command -v sql >/dev/null 2>&1 || {
    echo "the APEX modes need SQLcl (sql) — sqlplus cannot run the apex command" >&2
    exit 1
  }
}

# SQLcl's apex command is what makes the export reproducible; -skipExportDate
# keeps two exports of an unchanged app byte-identical.
export_app_to() {
  local dir="$1"
  mkdir -p "$dir"
  cat > "$TMP/apex-export.sql" <<SQL
apex export -applicationid $APP_ID -dir "$dir" -skipExportDate
exit
SQL
  run_as WORKSPACE "@$TMP/apex-export.sql"
}

case "$MODE" in
  script)
    [[ -n "$SCRIPT" ]] || { usage; exit 2; }
    [[ -f "$SCRIPT" ]] || { echo "no such SQL file: $SCRIPT" >&2; exit 1; }
    run_as "$AS" "@$SCRIPT" "$APP_PW" "$EMAIL"
    ;;
  bootstrap)
    echo "==> schema (ADMIN)"
    run_as ADMIN "@$ROOT/sql/01_schema.sql" "$APP_PW" "$EMAIL"
    echo "==> table (TODO_APP)"
    run_as APP "@$ROOT/sql/02_table.sql" "$APP_PW" "$EMAIL"
    echo "==> APEX workspace (ADMIN)"
    run_as ADMIN "@$ROOT/sql/03_apex_workspace.sql" "$APP_PW" "$EMAIL"

    if [[ -f "$APEX_DIR/f$APP_ID.sql" ]]; then
      echo "==> APEX import of application $APP_ID (TODO_ADMIN)"
      run_as WORKSPACE "@$APEX_DIR/f$APP_ID.sql"
    else
      echo "==> APEX: no export at sql/apex/f$APP_ID.sql"
      echo "    Build the app once in Page Designer, then:"
      echo "      scripts/adb-sql.sh --as WORKSPACE --apex export"
      echo "    and commit the file. Every later --bootstrap recreates it."
    fi
    ;;
  apex-export)
    need_sqlcl
    export_app_to "$APEX_DIR"
    [[ -f "$APEX_DIR/f$APP_ID.sql" ]] || { echo "export produced no sql/apex/f$APP_ID.sql" >&2; exit 1; }
    echo "exported application $APP_ID to sql/apex/f$APP_ID.sql — commit it"
    ;;
  apex-check)
    need_sqlcl
    CHECKED_IN="$APEX_DIR/f$APP_ID.sql"
    [[ -f "$CHECKED_IN" ]] || {
      echo "FAIL: nothing is checked in at sql/apex/f$APP_ID.sql" >&2
      exit 1
    }

    # Content, not clocks: importing an app bumps its last-updated timestamp, so
    # a timestamp comparison would pass or fail for reasons unrelated to pages.
    export_app_to "$TMP/apex"
    if diff -u "$CHECKED_IN" "$TMP/apex/f$APP_ID.sql" > "$TMP/apex.diff"; then
      echo "OK: sql/apex/f$APP_ID.sql matches application $APP_ID in the database"
    else
      echo "FAIL: sql/apex/f$APP_ID.sql is behind the database — the checked-in export is stale" >&2
      sed -n '1,40p' "$TMP/apex.diff" >&2
      echo "  re-export with: scripts/adb-sql.sh --as WORKSPACE --apex export, then commit" >&2
      exit 1
    fi
    ;;
  apex-import)
    [[ -f "$APEX_DIR/f$APP_ID.sql" ]] || {
      echo "no export at sql/apex/f$APP_ID.sql; run --as WORKSPACE --apex export first" >&2
      exit 1
    }
    run_as WORKSPACE "@$APEX_DIR/f$APP_ID.sql"
    echo "imported application $APP_ID from sql/apex/f$APP_ID.sql"
    ;;
  *)
    echo "unknown mode: $MODE" >&2
    exit 2
    ;;
esac
