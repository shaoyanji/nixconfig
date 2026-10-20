# Declarative PostgreSQL Logical Backup Verification Drill (EXP-042).
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.postgresBackupDrill;

  pgPackage = config.services.postgresql.finalPackage;

  drillScript = pkgs.writeShellScriptBin "postgres-backup-drill" ''
    set -euo pipefail

    export PATH="${lib.makeBinPath [pkgs.coreutils pkgs.gzip pkgs.gawk pkgs.gnugrep pkgs.systemd]}:${pgPackage}/bin:$PATH"

    echo "=== [$(date '+%Y-%m-%d %H:%M:%S')] PostgreSQL Logical Backup Verification Drill ==="
    echo "Backup Directory:      ${cfg.backupDir}"
    echo "Target Databases:      ${lib.concatStringsSep ", " cfg.databases}"
    echo "Minimum Tables Target: ${toString cfg.assertMinimumTables}"
    echo "PostgreSQL Package:    ${pgPackage.name}"
    echo "----------------------------------------------------------------------"

    TOTAL_DBS=0
    ERRORS=0

    for db in ${lib.escapeShellArgs cfg.databases}; do
      TOTAL_DBS=$((TOTAL_DBS + 1))
      DUMP_FILE="${cfg.backupDir}/$db.sql.gz"

      echo ">>> Auditing backup dump for: $db"
      if [ ! -f "$DUMP_FILE" ]; then
        echo "FAIL: Backup dump file $DUMP_FILE does not exist!" >&2
        ERRORS=$((ERRORS + 1))
        continue
      fi

      DUMP_SIZE=$(stat -c '%s' "$DUMP_FILE" 2>/dev/null || echo "0")
      DUMP_MB=$(awk "BEGIN {printf \"%.2f MB\", $DUMP_SIZE / 1048576}")
      DUMP_MTIME=$(stat -c '%y' "$DUMP_FILE" 2>/dev/null || echo "unknown")
      echo "    Dump size: $DUMP_MB | Last modified: $DUMP_MTIME"

      # Create ephemeral cluster workspace
      TMPDIR=$(mktemp -d /tmp/pg-backup-drill-$db.XXXXXX)
      SOCKET_DIR="$TMPDIR/socket"
      DATA_DIR="$TMPDIR/data"
      mkdir -p "$SOCKET_DIR" "$DATA_DIR"

      CLEANUP() {
        if [ -n "''${PXPID:-}" ]; then
          pg_ctl -D "$DATA_DIR" -m immediate stop >/dev/null 2>&1 || kill -9 "$PXPID" >/dev/null 2>&1 || true
        fi
        rm -rf "$TMPDIR" || true
      }
      trap CLEANUP EXIT

      echo "    Initializing ephemeral PostgreSQL cluster in tmpfs..."
      initdb -D "$DATA_DIR" -U postgres --no-locale -E UTF8 --auth=trust >/dev/null 2>&1

      # Start isolated ephemeral PostgreSQL daemon on private UNIX socket (no TCP listener)
      postgres -D "$DATA_DIR" -k "$SOCKET_DIR" -h "" -p 54329 >"$TMPDIR/postgres.log" 2>&1 &
      PXPID=$!

      for i in $(seq 1 30); do
        if pg_isready -h "$SOCKET_DIR" -p 54329 >/dev/null 2>&1; then
          break
        fi
        sleep 0.2
      done

      if ! pg_isready -h "$SOCKET_DIR" -p 54329 >/dev/null 2>&1; then
        echo "FAIL: Ephemeral PostgreSQL cluster failed to start!" >&2
        cat "$TMPDIR/postgres.log" >&2
        ERRORS=$((ERRORS + 1))
        CLEANUP
        trap - EXIT
        continue
      fi

      echo "    Restoring $DUMP_FILE into ephemeral cluster..."
      RESTORE_START=$(date +%s%N)
      gzip -dc "$DUMP_FILE" | psql -h "$SOCKET_DIR" -p 54329 -U postgres -d postgres >"$TMPDIR/restore.log" 2>&1 || true
      RESTORE_END=$(date +%s%N)
      RESTORE_SEC=$(awk "BEGIN {printf \"%.2f\", ($RESTORE_END - $RESTORE_START) / 1000000000}")
      echo "    - Restore completed in $RESTORE_SEC seconds."

      # Inspect restored database tables
      TABLE_COUNT=$(psql -h "$SOCKET_DIR" -p 54329 -U postgres -d "$db" -t -A -c "
        SELECT count(*) FROM pg_tables WHERE schemaname = 'public';
      " 2>/dev/null || echo "0")
      echo "    - Tables Restored: $TABLE_COUNT (minimum required: ${toString cfg.assertMinimumTables})"

      if [ "$TABLE_COUNT" -lt "${toString cfg.assertMinimumTables}" ]; then
        echo "FAIL: Restored database $db has only $TABLE_COUNT tables (expected >= ${toString cfg.assertMinimumTables})!" >&2
        ERRORS=$((ERRORS + 1))
      else
        echo "    - Schema Table Verification: PASS"
      fi

      # For immich, verify core entity row counts
      if [ "$db" = "immich" ]; then
        echo "    Verifying Immich core table entities:"
        ENTITY_COUNTS=$(psql -h "$SOCKET_DIR" -p 54329 -U postgres -d "$db" -t -A -c "
          SELECT 'assets: ' || count(*) FROM asset
          UNION ALL
          SELECT 'users: ' || count(*) FROM \"user\"
          UNION ALL
          SELECT 'face_search: ' || count(*) FROM face_search
          UNION ALL
          SELECT 'smart_search: ' || count(*) FROM smart_search;
        " 2>/dev/null || echo "ERROR")

        if [ "$ENTITY_COUNTS" = "ERROR" ]; then
          echo "FAIL: Could not query Immich core entity row counts!" >&2
          ERRORS=$((ERRORS + 1))
        else
          echo "$ENTITY_COUNTS" | while read -r line; do
            [ -n "$line" ] && echo "      * $line"
          done
        fi
      fi

      # Stop ephemeral cluster and clean up
      pg_ctl -D "$DATA_DIR" -m immediate stop >/dev/null 2>&1 || kill -9 "$PXPID" >/dev/null 2>&1 || true
      unset PXPID
      rm -rf "$TMPDIR" || true
      trap - EXIT

      echo "----------------------------------------------------------------------"
    done

    echo "=== PostgreSQL Backup Drill Scorecard ==="
    echo "Databases Audited: $TOTAL_DBS"
    echo "Drill Errors:      $ERRORS"

    if [ "$ERRORS" -gt 0 ]; then
      echo "FAIL: PostgreSQL backup verification drill encountered errors!" >&2
      exit 1
    fi

    echo "PASS: All PostgreSQL backups successfully verified and restored in ephemeral cluster."
    exit 0
  '';
in {
  options.services.postgresBackupDrill = {
    enable = lib.mkEnableOption "declarative PostgreSQL logical backup verification drill";

    backupDir = lib.mkOption {
      type = lib.types.path;
      default = "/srv/backup/postgresql";
      description = "Directory containing PostgreSQL compressed dumps.";
    };

    databases = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = ["immich"];
      description = "List of database names to restore and verify.";
    };

    assertMinimumTables = lib.mkOption {
      type = lib.types.int;
      default = 20;
      description = "Minimum expected public table count for a successful restore.";
    };

    schedule = lib.mkOption {
      type = lib.types.str;
      default = "Sun *-*-* 06:00:00";
      description = "systemd OnCalendar schedule expression (strictly after 03:00-05:30 backup window).";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.postgres-backup-drill = {
      description = "PostgreSQL logical backup verification drill";
      serviceConfig = {
        Type = "oneshot";
        User = "postgres";
        Group = "postgres";
        ExecStart = "${drillScript}/bin/postgres-backup-drill";
        ProtectSystem = "full";
        PrivateTmp = true;
      };
    };

    systemd.timers.postgres-backup-drill = {
      description = "Scheduled PostgreSQL backup verification drill timer";
      wantedBy = ["timers.target"];
      timerConfig = {
        OnCalendar = cfg.schedule;
        Persistent = true;
        RandomizedDelaySec = "5m";
      };
    };

    environment.systemPackages = [drillScript];
  };
}
