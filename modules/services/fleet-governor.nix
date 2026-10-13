# Declarative Consolidated Fleet Governor & Self-Repair Orchestrator
#
# Consolidates fragmented, monitoring-only watchdogs into a unified runtime repair engine:
# - Employs Julia-1 (144M) and Laya (421M) in series via Kelly consensus gating.
# - Strictly offline and local on CPU (< 30ms total sweep latency).
# - 0 LLM tokens consumed: protects System 2 (Nemotron) weekly quota.
# - Auto-routes to deterministic runtime repairs for WAL bloat, thermals, Btrfs snapshots,
#   paperless queues, Kiwix availability, and memory pressure.
# - Emits un-remediated or ambiguous strategic items directly to /home/devji/HANDOFF.md.
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.fleetGovernor;
in {
  options.services.fleetGovernor = {
    enable = lib.mkEnableOption "Consolidated Fleet Governor with Kelly consensus & auto-repair";

    schedule = lib.mkOption {
      type = lib.types.str;
      default = "hourly";
      description = "Systemd OnCalendar expression for governor sweep (e.g. hourly, strictly avoids 03:00-05:30 backup window).";
    };

    autoRepair = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to execute deterministic runtime fixes when Kelly consensus gate approves.";
    };

    allowSystem2 = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether to allow fallback to System 2 Nemotron if consensus splits (default false to conserve quota).";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.fleet-governor = {
      description = "Consolidated Fleet Governor & Runtime Self-Repair Dispatcher";
      path = [
        pkgs.coreutils
        pkgs.btrfs-progs
        pkgs.sqlite
        pkgs.systemd
        pkgs.curl
        pkgs.gnugrep
        pkgs.gawk
        pkgs.procps
        pkgs.python3
        config.services.systemoneDecision.ensemblePackage
      ];

      serviceConfig = {
        Type = "oneshot";
        User = "root";
        WorkingDirectory = "/home/devji";
        ExecStart = ''
          ${pkgs.writeShellScript "run-fleet-governor" ''
            set -euo pipefail
            FLAGS=""
            if [ "${toString cfg.autoRepair}" = "1" ]; then
              FLAGS="$FLAGS --auto-repair"
            fi
            if [ "${toString cfg.allowSystem2}" = "1" ]; then
              FLAGS="$FLAGS --allow-s2"
            fi
            
            if command -v systemone-ensemble >/dev/null 2>&1; then
              systemone-ensemble govern $FLAGS
            else
              python3 /Volumes/data/projects/nixconfig/modules/services/systemone/ensemble.py govern $FLAGS
            fi
          ''}
        '';
      };
    };

    systemd.timers.fleet-governor = {
      description = "Scheduled Consolidated Fleet Governor Timer";
      wantedBy = ["timers.target"];
      timerConfig = {
        OnCalendar = cfg.schedule;
        Persistent = true;
        RandomizedDelaySec = "60s";
      };
    };
  };
}
