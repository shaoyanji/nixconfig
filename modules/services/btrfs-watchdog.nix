# Declarative Btrfs Silent Corruption & Device Error Watchdog (EXP-022).
#
# Periodically probes Btrfs hardware error counters (write_io_errs, read_io_errs,
# flush_io_errs, corruption_errs, generation_errs) across declared mount points.
#
# Detects silent bit rot, cable glitches, and deteriorating media without waiting
# for unrecoverable read failures or manual `btrfs device stats` checks.
#
# Emits structured journal alerts and fails the systemd unit so that daily audits
# (SYSTEM.md) or systemd OnFailure triggers can alert immediately.
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.btrfsWatchdog;

  watchdogScript = pkgs.writeShellScriptBin "btrfs-watchdog" ''
    set -euo pipefail

    PATH="${lib.makeBinPath [pkgs.btrfs-progs pkgs.coreutils pkgs.gnugrep pkgs.gawk pkgs.systemd]}:$PATH"

    TOTAL_ERRORS=0
    CHECKED_COUNT=0

    echo "=== [$(date '+%Y-%m-%d %H:%M:%S')] Starting Btrfs device error watchdog audit ==="

    ${lib.concatMapStringsSep "\n" (mount: ''
        if [ -d "${mount}" ]; then
          if btrfs filesystem df "${mount}" >/dev/null 2>&1; then
            echo "Inspecting Btrfs mount: ${mount}..."
            CHECKED_COUNT=$((CHECKED_COUNT + 1))

            STATS=$(btrfs device stats "${mount}" 2>&1 || true)
            echo "$STATS"

            # Parse any non-zero errors (format: [/dev/sda2].corruption_errs  0)
            ERR_LINES=$(echo "$STATS" | awk '$2 > 0 {print $0}')
            if [ -n "$ERR_LINES" ]; then
              echo "ERROR: Hardware or corruption errors detected on ${mount}!" >&2
              echo "$ERR_LINES" >&2
              ERR_SUM=$(echo "$STATS" | awk '{sum += $2} END {print sum}')
              TOTAL_ERRORS=$((TOTAL_ERRORS + ERR_SUM))
            fi
          else
            echo "Skipping ${mount}: not recognized as an active Btrfs filesystem."
          fi
        else
          echo "Skipping ${mount}: directory does not exist."
        fi
      '')
      cfg.mounts}

    if [ "$CHECKED_COUNT" -eq 0 ]; then
      echo "WARNING: No valid Btrfs mount points were checked!" >&2
      exit 2
    fi

    if [ "$TOTAL_ERRORS" -gt 0 ]; then
      echo "=== CRITICAL: Btrfs watchdog detected $TOTAL_ERRORS total hardware/corruption errors! ===" >&2
      ${lib.optionalString cfg.failOnErrors "exit 1"}
    else
      echo "=== PASS: All $CHECKED_COUNT Btrfs mount(s) report 0 hardware and corruption errors. ==="
      exit 0
    fi
  '';
in {
  options.services.btrfsWatchdog = {
    enable = lib.mkEnableOption "declarative Btrfs silent corruption and device error watchdog";

    mounts = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = ["/" "/Volumes/data"];
      description = "List of filesystem mount points to inspect for Btrfs device statistics.";
    };

    interval = lib.mkOption {
      type = lib.types.str;
      default = "hourly";
      description = "systemd OnCalendar timer interval (e.g. 'hourly', '*-*-* 00/4:00:00').";
    };

    failOnErrors = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether the systemd service should exit with code 1 if errors are found, flagging the unit as failed.";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.btrfs-watchdog = {
      description = "Btrfs silent corruption & device error watchdog";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${watchdogScript}/bin/btrfs-watchdog";
        ProtectSystem = "strict";
        ProtectHome = "read-only";
        ReadOnlyPaths = cfg.mounts;
        PrivateTmp = true;
      };
    };

    systemd.timers.btrfs-watchdog = {
      description = "Hourly Btrfs device stats inspection timer";
      wantedBy = ["timers.target"];
      timerConfig = {
        OnCalendar = cfg.interval;
        Persistent = true;
        RandomizedDelaySec = "5m";
      };
    };

    environment.systemPackages = [watchdogScript];
  };
}
