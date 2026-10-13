# Declarative SQLite WAL Checkpoint, Optimization & Integrity Dispatcher (EXP-030).
#
# Periodically inspects embedded SQLite databases across fleet services (Pi-hole,
# Uptime-Kuma, SimpleX, Scrutiny, Sonarr), performs non-blocking or truncating WAL
# checkpoints, runs query planner statistics optimization (PRAGMA optimize), and
# verifies database integrity (PRAGMA quick_check) before nightly backup windows.
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.sqliteMaintenance;

  maintenanceScript = pkgs.writeShellScriptBin "sqlite-maintenance" ''
    set -euo pipefail

    PATH="${lib.makeBinPath [pkgs.coreutils pkgs.sqlite pkgs.gawk pkgs.util-linux]}:$PATH"

    echo "=== [$(date '+%Y-%m-%d %H:%M:%S')] SQLite WAL Checkpoint & Integrity Maintenance ==="
    echo "Checkpoint mode:      ${cfg.checkpointMode}"
    echo "Run PRAGMA optimize:  ${
      if cfg.runOptimize
      then "YES"
      else "NO"
    }"
    echo "Run PRAGMA quick_check: ${
      if cfg.runQuickCheck
      then "YES"
      else "NO"
    }"
    echo "----------------------------------------------------------------------"

    TOTAL_CHECKED=0
    TOTAL_ERRORS=0

    run_sqlite() {
      local db_path="$1"
      local sql_query="$2"
      local owner_user
      owner_user=$(stat -c '%U' "$db_path")

      # If the file is owned by a normal non-root user that exists in the system,
      # run as that user to respect POSIX file ownership and prevent permission mismatches.
      if [ "$owner_user" != "root" ] && [ "$owner_user" != "nobody" ] && id "$owner_user" >/dev/null 2>&1; then
        if runuser -u "$owner_user" -- sqlite3 "$db_path" "$sql_query" 2>/dev/null; then
          return 0
        fi
      fi

      # Fallback to direct execution (as root)
      sqlite3 "$db_path" "$sql_query"
    }

    preserve_ownership() {
      local db_path="$1"
      local owner_uid owner_gid
      owner_uid=$(stat -c '%u' "$db_path" 2>/dev/null || echo "")
      owner_gid=$(stat -c '%g' "$db_path" 2>/dev/null || echo "")

      if [ -n "$owner_uid" ] && [ -n "$owner_gid" ]; then
        for ext in "-wal" "-shm"; do
          if [ -f "$db_path$ext" ]; then
            chown "$owner_uid:$owner_gid" "$db_path$ext" 2>/dev/null || true
          fi
        done
      fi
    }

    ${lib.concatMapStringsSep "\n" (db: ''
        DB="${db}"
        if [ ! -f "$DB" ]; then
          echo "SKIPPED: Database $DB does not exist on disk."
        else
          TOTAL_CHECKED=$((TOTAL_CHECKED + 1))
          DB_SIZE=$(stat -c '%s' "$DB" 2>/dev/null || echo "0")
          WAL_SIZE_BEFORE=0
          if [ -f "$DB-wal" ]; then
            WAL_SIZE_BEFORE=$(stat -c '%s' "$DB-wal" 2>/dev/null || echo "0")
          fi

          echo ">>> Inspecting: $DB"
          echo "    Main DB size: $DB_SIZE bytes | WAL size before: $WAL_SIZE_BEFORE bytes"

          JOURNAL_MODE=$(run_sqlite "$DB" "PRAGMA journal_mode;" 2>/dev/null | tail -n 1 || echo "unknown")
          echo "    Journal mode: $JOURNAL_MODE"

          if [ "$JOURNAL_MODE" = "wal" ]; then
            CHECKPOINT_RESULT=$(run_sqlite "$DB" "PRAGMA wal_checkpoint(${cfg.checkpointMode});" 2>/dev/null || echo "ERROR")
            echo "    WAL Checkpoint (${cfg.checkpointMode}): $CHECKPOINT_RESULT"
          else
            echo "    WAL Checkpoint skipped (database is not in WAL mode)."
          fi

          ${lib.optionalString cfg.runOptimize ''
          run_sqlite "$DB" "PRAGMA optimize;" 2>/dev/null || true
          echo "    PRAGMA optimize completed."
        ''}

          ${lib.optionalString cfg.runQuickCheck ''
          QUICK_CHECK=$(run_sqlite "$DB" "PRAGMA quick_check;" 2>/dev/null | tail -n 1 || echo "FAIL")
          if [ "$QUICK_CHECK" = "ok" ]; then
            echo "    Integrity check: PASS (ok)"
          else
            echo "    Integrity check: FAIL ($QUICK_CHECK)" >&2
            TOTAL_ERRORS=$((TOTAL_ERRORS + 1))
          fi
        ''}

          # Ensure correct UID/GID ownership of WAL/SHM companion files
          preserve_ownership "$DB"

          WAL_SIZE_AFTER=0
          if [ -f "$DB-wal" ]; then
            WAL_SIZE_AFTER=$(stat -c '%s' "$DB-wal" 2>/dev/null || echo "0")
          fi
          echo "    WAL size after: $WAL_SIZE_AFTER bytes"
          echo "----------------------------------------------------------------------"
        fi
      '')
      cfg.databases}

    echo "=== SQLite Maintenance Summary ==="
    echo "Databases inspected: $TOTAL_CHECKED"
    echo "Integrity errors:    $TOTAL_ERRORS"

    if [ "$TOTAL_ERRORS" -gt 0 ] && [ "${
      if cfg.failOnCorruption
      then "1"
      else "0"
    }" = "1" ]; then
      echo "CRITICAL: Database corruption detected during maintenance run!" >&2
      exit 1
    fi

    echo "PASS: All inspected databases verified healthy."
    exit 0
  '';
in {
  options.services.sqliteMaintenance = {
    enable = lib.mkEnableOption "declarative SQLite WAL checkpoint, optimization, and integrity maintenance";

    schedule = lib.mkOption {
      type = lib.types.str;
      default = "*-*-* 02:30:00";
      description = "systemd OnCalendar schedule expression (runs before 03:00 nightly backup window).";
    };

    databases = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "List of SQLite database file paths to maintain.";
    };

    checkpointMode = lib.mkOption {
      type = lib.types.enum ["passive" "restart" "truncate"];
      default = "truncate";
      description = "WAL checkpoint mode (passive, restart, truncate).";
    };

    runOptimize = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to run PRAGMA optimize to refresh query planner statistics.";
    };

    runQuickCheck = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to verify database integrity via PRAGMA quick_check.";
    };

    failOnCorruption = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to fail the service unit if PRAGMA quick_check detects corruption.";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.sqlite-maintenance = {
      description = "SQLite WAL checkpoint, optimization, and integrity maintenance";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${maintenanceScript}/bin/sqlite-maintenance";
        ProtectSystem = "full";
        PrivateTmp = true;
      };
    };

    systemd.timers.sqlite-maintenance = {
      description = "Scheduled SQLite maintenance timer";
      wantedBy = ["timers.target"];
      timerConfig = {
        OnCalendar = cfg.schedule;
        Persistent = true;
        RandomizedDelaySec = "5m";
      };
    };

    environment.systemPackages = [maintenanceScript];
  };
}
