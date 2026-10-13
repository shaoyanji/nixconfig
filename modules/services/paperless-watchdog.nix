# Declarative Paperless-ngx Document Ingestion Watchdog & Health Probe (EXP-038).
#
# Periodically inspects the Paperless consume directory (/var/lib/paperless/consume)
# for stalled, corrupted, or 0-byte files that fail to be ingested by the consumer daemon,
# and verifies active operational status across all Paperless systemd service units.
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.paperlessWatchdog;

  watchdogScript = pkgs.writeShellScriptBin "paperless-watchdog" ''
    set -euo pipefail

    PATH="${lib.makeBinPath [pkgs.coreutils pkgs.findutils pkgs.systemd pkgs.gawk]}:$PATH"

    echo "=== [$(date '+%Y-%m-%d %H:%M:%S')] Paperless Ingestion Watchdog & Pipeline Health Probe ==="
    echo "Consume Directory:   ${cfg.consumeDir}"
    echo "Stall Age Threshold: ${toString cfg.maxStallMinutes} minutes"
    echo "----------------------------------------------------------------------"

    # 1. Check Paperless service units
    SVC_FAILURES=0
    echo ">>> Checking Paperless systemd services:"
    for unit in ${lib.escapeShellArgs cfg.checkServices}; do
      STATE=$(systemctl is-active "$unit" 2>/dev/null || echo "inactive")
      if [ "$STATE" = "active" ]; then
        echo "    - $unit: OK (active)"
      else
        echo "    - $unit: FAIL ($STATE)" >&2
        SVC_FAILURES=$((SVC_FAILURES + 1))
      fi
    done

    echo "----------------------------------------------------------------------"

    # 2. Check consume directory
    if [ ! -d "${cfg.consumeDir}" ]; then
      echo "WARN: Consume directory ${cfg.consumeDir} does not exist!" >&2
      exit 0
    fi

    echo ">>> Inspecting consume queue for stalled files:"
    STALL_COUNT=0
    ZERO_BYTE_COUNT=0

    # Find files older than threshold
    while IFS= read -r file; do
      [ -z "$file" ] && continue
      STALL_COUNT=$((STALL_COUNT + 1))
      SIZE=$(stat -c '%s' "$file" 2>/dev/null || echo "0")
      MTIME=$(stat -c '%y' "$file" 2>/dev/null || echo "unknown")

      if [ "$SIZE" -eq 0 ]; then
        ZERO_BYTE_COUNT=$((ZERO_BYTE_COUNT + 1))
        echo "    [STALLED EMPTY] $file (0 bytes, mtime: $MTIME)"
        echo "      -> Note: 0-byte ghost file will never be processed by OCR worker."
      else
        echo "    [STALLED FILE]  $file ($SIZE bytes, mtime: $MTIME)"
      fi
    done < <(find "${cfg.consumeDir}" -type f -mmin +${toString cfg.maxStallMinutes} 2>/dev/null || true)

    echo "----------------------------------------------------------------------"
    echo "=== Paperless Watchdog Scorecard ==="
    echo "Active Services Checked: ${toString (builtins.length cfg.checkServices)}"
    echo "Service Unit Failures:   $SVC_FAILURES"
    echo "Stalled Ingestion Files: $STALL_COUNT (Empty 0-byte: $ZERO_BYTE_COUNT)"

    if [ "$SVC_FAILURES" -gt 0 ]; then
      echo "CRITICAL: One or more Paperless service units are down!" >&2
      exit 1
    fi

    if [ "$STALL_COUNT" -gt 0 ]; then
      echo "WARNING: Detected $STALL_COUNT stalled file(s) in Paperless consume queue."
      if [ "${
      if cfg.failOnStall
      then "1"
      else "0"
    }" = "1" ]; then
        exit 1
      fi
    fi

    echo "PASS: Paperless ingestion pipeline verified."
    exit 0
  '';
in {
  options.services.paperlessWatchdog = {
    enable = lib.mkEnableOption "declarative Paperless-ngx document ingestion watchdog & pipeline health probe";

    consumeDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/paperless/consume";
      description = "Path to the Paperless consume directory to monitor.";
    };

    maxStallMinutes = lib.mkOption {
      type = lib.types.int;
      default = 20;
      description = "Maximum age in minutes for files in consume directory before flagging as stalled.";
    };

    schedule = lib.mkOption {
      type = lib.types.str;
      default = "hourly";
      description = "systemd timer OnCalendar schedule for watchdog execution.";
    };

    checkServices = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "paperless-consumer"
        "paperless-web"
        "paperless-task-queue"
      ];
      description = "Paperless systemd services to assert active status for.";
    };

    failOnStall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether to exit non-zero when stalled files are found.";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.paperless-watchdog = {
      description = "Paperless document ingestion watchdog and pipeline health probe";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${watchdogScript}/bin/paperless-watchdog";
        ProtectSystem = "full";
        PrivateTmp = true;
      };
    };

    systemd.timers.paperless-watchdog = {
      description = "Scheduled Paperless ingestion watchdog timer";
      wantedBy = ["timers.target"];
      timerConfig = {
        OnCalendar = cfg.schedule;
        Persistent = true;
        RandomizedDelaySec = "10m";
      };
    };

    environment.systemPackages = [watchdogScript];
  };
}
