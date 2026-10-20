# Declarative Kiwix Offline Knowledge Library Integrity & Search Health Probe (EXP-040).
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.kiwixWatchdog;

  watchdogScript = pkgs.writeShellScriptBin "kiwix-watchdog" ''
    set -euo pipefail

    PATH="${lib.makeBinPath [pkgs.coreutils pkgs.curl pkgs.systemd pkgs.gawk pkgs.gnugrep]}:$PATH"

    ENDPOINT="${cfg.endpoint}"
    LIBRARY="${cfg.libraryFile}"

    echo "=== [$(date '+%Y-%m-%d %H:%M:%S')] Kiwix Library Integrity & Search Health Probe ==="
    echo "Kiwix Endpoint:     $ENDPOINT"
    echo "Library Catalog:    $LIBRARY"
    echo "----------------------------------------------------------------------"

    FAILURES=0

    # 1. Assert kiwix-serve service status
    SERVICE_STATE=$(systemctl is-active kiwix-serve 2>/dev/null || echo "inactive")
    if [ "$SERVICE_STATE" = "active" ]; then
      echo ">>> Service Status: OK (kiwix-serve is active)"
    else
      echo ">>> Service Status: FAIL (kiwix-serve is $SERVICE_STATE)" >&2
      FAILURES=$((FAILURES + 1))
    fi

    # 2. Check HTTP root endpoint
    HTTP_ROOT=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "$ENDPOINT/" || echo "000")
    if [ "$HTTP_ROOT" = "200" ]; then
      echo ">>> Endpoint Root:  OK (HTTP 200)"
    else
      echo ">>> Endpoint Root:  FAIL (HTTP $HTTP_ROOT)" >&2
      FAILURES=$((FAILURES + 1))
    fi

    # 3. Verify library catalog and ZIM archive files
    echo ">>> Inspecting Library ZIM Archives:"
    if [ ! -f "$LIBRARY" ]; then
      echo "FAIL: Library catalog file $LIBRARY does not exist!" >&2
      FAILURES=$((FAILURES + 1))
    else
      ARCHIVE_COUNT=0
      while read -r zim_path; do
        [ -z "$zim_path" ] && continue
        ARCHIVE_COUNT=$((ARCHIVE_COUNT + 1))
        if [ -r "$zim_path" ]; then
          ZIM_SIZE=$(stat -c '%s' "$zim_path" 2>/dev/null || echo "0")
          ZIM_MB=$(awk "BEGIN {printf \"%.1f MB\", $ZIM_SIZE / 1048576}")
          if [ "$ZIM_SIZE" -gt 1073741824 ]; then
            ZIM_MB=$(awk "BEGIN {printf \"%.2f GB\", $ZIM_SIZE / 1073741824}")
          fi
          echo "    - [OK] $(basename "$zim_path") ($ZIM_MB)"
        else
          echo "    - [FAIL] $zim_path (unreadable or missing)" >&2
          FAILURES=$((FAILURES + 1))
        fi
      done < <(grep -oP 'path="[^"]+"' "$LIBRARY" | cut -d'"' -f2 || true)
      echo "    Total declared archives: $ARCHIVE_COUNT"
    fi

    # 4. Benchmark search query response
    echo ">>> Benchmarking Search Endpoints:"
    SEARCH_ERRORS=0
    for query in ${lib.escapeShellArgs cfg.testQueries}; do
      RESPONSE_TIME=$(curl -s -o /dev/null -w "%{time_total}" --max-time 10 "$ENDPOINT/search?pattern=$query" || echo "timeout")
      STATUS_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 "$ENDPOINT/search?pattern=$query" || echo "000")

      if [ "$STATUS_CODE" = "200" ]; then
        echo "    - Query \"$query\": PASS (HTTP 200 in ''${RESPONSE_TIME}s)"
      else
        echo "    - Query \"$query\": FAIL (HTTP $STATUS_CODE in ''${RESPONSE_TIME}s)" >&2
        SEARCH_ERRORS=$((SEARCH_ERRORS + 1))
      fi
    done

    echo "----------------------------------------------------------------------"
    echo "=== Kiwix Watchdog Scorecard ==="
    echo "Total Critical Failures: $FAILURES"
    echo "Search Benchmark Errors: $SEARCH_ERRORS"

    if [ "$FAILURES" -gt 0 ] || ([ "$SEARCH_ERRORS" -gt 0 ] && [ "${
      if cfg.failOnSearchError
      then "1"
      else "0"
    }" = "1" ]); then
      echo "CRITICAL: Kiwix offline knowledge library reported errors!" >&2
      exit 1
    fi

    echo "PASS: All Kiwix ZIM archives and search indices verified healthy."
    exit 0
  '';
in {
  options.services.kiwixWatchdog = {
    enable = lib.mkEnableOption "declarative Kiwix offline knowledge library integrity and search health probe";

    endpoint = lib.mkOption {
      type = lib.types.str;
      # Derived from the server's own option, so moving Kiwix's port does not
      # leave the watchdog probing a dead socket.
      default = "http://127.0.0.1:${toString config.services.kiwix-serve.port}";
      description = "HTTP endpoint URL for the Kiwix server.";
    };

    libraryFile = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/kiwix/library.xml";
      description = "Path to the Kiwix library.xml catalog.";
    };

    testQueries = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "NixOS"
        "Btrfs"
        "Linux"
      ];
      description = "List of search terms to query during the health probe.";
    };

    schedule = lib.mkOption {
      type = lib.types.str;
      default = "daily";
      description = "systemd OnCalendar schedule expression for the watchdog timer.";
    };

    failOnSearchError = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to fail the service unit if a search query fails.";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.kiwix-watchdog = {
      description = "Kiwix offline knowledge library integrity and search health probe";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${watchdogScript}/bin/kiwix-watchdog";
        ProtectSystem = "full";
        PrivateTmp = true;
      };
    };

    systemd.timers.kiwix-watchdog = {
      description = "Scheduled Kiwix library integrity watchdog timer";
      wantedBy = ["timers.target"];
      timerConfig = {
        OnCalendar = cfg.schedule;
        Persistent = true;
        RandomizedDelaySec = "15m";
      };
    };

    environment.systemPackages = [watchdogScript];
  };
}
