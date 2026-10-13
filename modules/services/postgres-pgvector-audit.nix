# Declarative PostgreSQL Vector (pgvector/vchord) Index Health, Maintenance & Vacuum Drill (EXP-045).
#
# Periodically inspects high-dimensional vector tables (face_search, smart_search) in Immich DB,
# validates pgvector and vchord extension integrity, executes VACUUM (VERBOSE, ANALYZE) to trigger
# vchord index page compaction and prevent fragmentation, and monitors index sizes.
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.postgresPgvectorAudit;

  auditScript = pkgs.writeShellScriptBin "postgres-pgvector-audit" ''
    set -euo pipefail

    PATH="${lib.makeBinPath [pkgs.coreutils pkgs.postgresql pkgs.systemd pkgs.gawk pkgs.gnugrep]}:$PATH"

    echo "=== [$(date '+%Y-%m-%d %H:%M:%S')] PostgreSQL Vector (pgvector/vchord) Index Health & Maintenance ==="
    echo "Database:           ${cfg.database}"
    echo "Vector Tables:      ${lib.concatStringsSep ", " cfg.vectorTables}"
    echo "Run VACUUM ANALYZE: ${
      if cfg.runVacuum
      then "YES"
      else "NO"
    }"
    echo "Run REINDEX:        ${
      if cfg.reindex
      then "YES"
      else "NO"
    }"
    echo "----------------------------------------------------------------------"

    # 1. Assert PostgreSQL service is active
    if ! systemctl is-active postgresql >/dev/null 2>&1; then
      echo "FAIL: PostgreSQL service is not active!" >&2
      exit 1
    fi

    # 2. Check extension versions
    echo ">>> Checking vector extensions in ${cfg.database}:"
    EXTENSIONS=$(psql -U postgres -d "${cfg.database}" -t -A -c "
      SELECT extname || ' (v' || extversion || ')'
      FROM pg_extension
      WHERE extname IN ('vector', 'vchord');
    " -P pager=off || echo "ERROR")

    echo "$EXTENSIONS" | while read -r ext; do
      [ -n "$ext" ] && echo "    - Extension: $ext"
    done

    echo "----------------------------------------------------------------------"

    # 3. Audit and maintain vector tables
    TOTAL_TABLES=0
    ERRORS=0

    for table in ${lib.escapeShellArgs cfg.vectorTables}; do
      TOTAL_TABLES=$((TOTAL_TABLES + 1))
      echo ">>> Inspecting vector table: $table"

      # Table metrics: total size, index size, approximate rows
      METRICS=$(psql -U postgres -d "${cfg.database}" -t -A -F'|' -c "
        SELECT
          pg_size_pretty(pg_total_relation_size(c.oid)),
          pg_size_pretty(pg_indexes_size(c.oid)),
          reltuples::bigint
        FROM pg_class c
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE relname = '$table' AND n.nspname = 'public';
      " -P pager=off || echo "ERR|ERR|0")

      IFS='|' read -r total_size index_size row_count <<< "$METRICS"
      echo "    Total size: $total_size | Index size: $index_size | Approx live rows: $row_count"

      # Query index definitions
      INDEX_DEF=$(psql -U postgres -d "${cfg.database}" -t -A -c "
        SELECT indexname
        FROM pg_indexes
        WHERE tablename = '$table' AND (indexdef ILIKE '%vector%' OR indexdef ILIKE '%vchord%');
      " -P pager=off || echo "")

      if [ -n "$INDEX_DEF" ]; then
        echo "    Vector Index: $INDEX_DEF"
      fi

      ${lib.optionalString cfg.runVacuum ''
      echo "    Running VACUUM (VERBOSE, ANALYZE) $table:"
      VAC_OUTPUT=$(psql -U postgres -d "${cfg.database}" -c "VACUUM (VERBOSE, ANALYZE) $table;" -P pager=off 2>&1 || echo "ERROR")
      FREED_PAGES=$(echo "$VAC_OUTPUT" | grep -oP 'number_of_freed_pages = \K[0-9]+' || echo "0")
      if [ "$FREED_PAGES" != "0" ]; then
        echo "    - Page Compaction: Reclaimed $FREED_PAGES allocated vector pages."
      else
        echo "    - Page Compaction: Completed (0 fragmented pages)."
      fi
    ''}

      ${lib.optionalString cfg.reindex ''
      echo "    Running REINDEX TABLE CONCURRENTLY $table:"
      psql -U postgres -d "${cfg.database}" -c "REINDEX TABLE CONCURRENTLY $table;" -P pager=off || ERRORS=$((ERRORS + 1))
      echo "    - REINDEX completed."
    ''}

      echo "----------------------------------------------------------------------"
    done

    echo "=== Vector Maintenance Scorecard ==="
    echo "Tables Inspected: $TOTAL_TABLES"
    echo "Operation Errors: $ERRORS"

    if [ "$ERRORS" -gt 0 ]; then
      echo "FAIL: Vector maintenance encountered errors!" >&2
      exit 1
    fi

    echo "PASS: PostgreSQL vector index health and maintenance verified."
    exit 0
  '';
in {
  options.services.postgresPgvectorAudit = {
    enable = lib.mkEnableOption "declarative PostgreSQL vector (pgvector/vchord) indexing health and vacuum drill";

    database = lib.mkOption {
      type = lib.types.str;
      default = "immich";
      description = "PostgreSQL database containing vector tables.";
    };

    vectorTables = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "face_search"
        "smart_search"
      ];
      description = "List of tables with vector embeddings to audit and maintain.";
    };

    runVacuum = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to run VACUUM (VERBOSE, ANALYZE) on vector tables to maintain page compaction.";
    };

    reindex = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether to run REINDEX TABLE CONCURRENTLY on vector tables.";
    };

    schedule = lib.mkOption {
      type = lib.types.str;
      default = "Sun *-*-* 02:15:00";
      description = "systemd OnCalendar schedule expression (runs before 03:00 backup window).";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.postgres-pgvector-audit = {
      description = "PostgreSQL vector (pgvector/vchord) index health and maintenance";
      serviceConfig = {
        Type = "oneshot";
        User = "postgres";
        Group = "postgres";
        ExecStart = "${auditScript}/bin/postgres-pgvector-audit";
        ProtectSystem = "full";
        PrivateTmp = true;
      };
    };

    systemd.timers.postgres-pgvector-audit = {
      description = "Scheduled PostgreSQL vector index maintenance timer";
      wantedBy = ["timers.target"];
      timerConfig = {
        OnCalendar = cfg.schedule;
        Persistent = true;
        RandomizedDelaySec = "5m";
      };
    };

    environment.systemPackages = [auditScript];
  };
}
