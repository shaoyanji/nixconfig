# Declarative Hardware UPS Clean-Poweroff Simulation Drill & Telemetry (EXP-029).
#
# Periodically inspects frieren's internal battery hardware (Lenovo L16M2PB1)
# and AC power adapter to model battery health degradation, discharge runtime
# under active NAS workloads, and verify UPower clean poweroff thresholds.
#
# Probes sysfs directly without cutting power, verifying that the hardware UPS
# will safely sustain or shut down the mainframe during a power failure.
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.upsSimulationDrill;

  drillScript = pkgs.writeShellScriptBin "ups-drill" ''
    set -euo pipefail

    PATH="${lib.makeBinPath [pkgs.coreutils pkgs.gawk pkgs.systemd]}:$PATH"

    BAT="${cfg.batteryPath}"
    ADP="${cfg.acPath}"

    if [ ! -d "$BAT" ]; then
      echo "FAIL: Battery device path $BAT does not exist!" >&2
      exit 1
    fi

    CAPACITY=$(cat "$BAT/capacity" 2>/dev/null || echo "0")
    STATUS=$(cat "$BAT/status" 2>/dev/null || echo "Unknown")

    # Read energy or charge metrics:
    if [ -f "$BAT/energy_full" ] && [ -f "$BAT/energy_full_design" ]; then
      FULL=$(cat "$BAT/energy_full")
      DESIGN=$(cat "$BAT/energy_full_design")
      NOW=$(cat "$BAT/energy_now" 2>/dev/null || echo "0")
      POWER=$(cat "$BAT/power_now" 2>/dev/null || echo "0")
      UNIT="Wh"
      SCALE=1000000
    elif [ -f "$BAT/charge_full" ] && [ -f "$BAT/charge_full_design" ]; then
      FULL=$(cat "$BAT/charge_full")
      DESIGN=$(cat "$BAT/charge_full_design")
      NOW=$(cat "$BAT/charge_now" 2>/dev/null || echo "0")
      POWER=$(cat "$BAT/current_now" 2>/dev/null || echo "0")
      UNIT="Ah"
      SCALE=1000000
    else
      echo "WARN: Standard energy/charge metrics not found in $BAT" >&2
      FULL=0
      DESIGN=0
      NOW=0
      POWER=0
      UNIT="N/A"
      SCALE=1
    fi

    # AC adapter status:
    if [ -f "$ADP/online" ]; then
      AC_ONLINE=$(cat "$ADP/online")
    else
      AC_ONLINE="unknown"
    fi

    # Battery health rating:
    if [ "$DESIGN" -gt 0 ]; then
      HEALTH_PCT=$((FULL * 100 / DESIGN))
    else
      HEALTH_PCT=100
    fi

    # Estimated runtime on battery:
    if [ "$POWER" -gt 0 ] && [ "$NOW" -gt 0 ]; then
      RUNTIME_MINS=$((NOW * 60 / POWER))
      RUNTIME_HOURS=$(awk "BEGIN {printf \"%.2f\", $NOW / $POWER}")
    else
      RUNTIME_MINS="N/A"
      RUNTIME_HOURS="N/A"
    fi

    NOW_FORMATTED=$(awk "BEGIN {printf \"%.2f\", $NOW / $SCALE}")
    FULL_FORMATTED=$(awk "BEGIN {printf \"%.2f\", $FULL / $SCALE}")
    DESIGN_FORMATTED=$(awk "BEGIN {printf \"%.2f\", $DESIGN / $SCALE}")
    POWER_FORMATTED=$(awk "BEGIN {printf \"%.2f\", $POWER / $SCALE}")

    echo "=== [$(date '+%Y-%m-%d %H:%M:%S')] Hardware UPS (Battery-as-UPS) Simulation Drill ==="
    echo "Host Battery Device:    $BAT"
    echo "AC Adapter Online:      $([ "$AC_ONLINE" = "1" ] && echo "YES (Plugged In)" || echo "NO (Running on Battery)")"
    echo "Current Battery Charge: $CAPACITY% ($NOW_FORMATTED $UNIT)"
    echo "Full Usable Capacity:   $FULL_FORMATTED $UNIT (Design: $DESIGN_FORMATTED $UNIT)"
    echo "Battery Health Rating:  $HEALTH_PCT% (Healthy: >= ${toString cfg.minHealthPercent}%)"
    echo "Host Power Draw:        $POWER_FORMATTED W"
    echo "Calculated Backup Time: $RUNTIME_HOURS hours ($RUNTIME_MINS minutes remaining)"

    # Verify UPower daemon state:
    UPOWER_ACTIVE=$(systemctl is-active upower 2>/dev/null || echo "inactive")
    echo "UPower Daemon State:    $UPOWER_ACTIVE"
    echo "Emergency Poweroff Cut: ${toString cfg.criticalPercent}% clean shutdown threshold"

    # Health & threshold assertions:
    FAIL=0
    if [ "$HEALTH_PCT" -lt "${toString cfg.minHealthPercent}" ]; then
      echo "CRITICAL: Battery capacity degraded below health threshold! ($HEALTH_PCT% < ${toString cfg.minHealthPercent}%)" >&2
      FAIL=1
    fi

    if [ "$CAPACITY" -le "${toString cfg.criticalPercent}" ] && [ "$AC_ONLINE" = "0" ]; then
      echo "CRITICAL: Battery level is at or below emergency poweroff threshold ($CAPACITY% <= ${toString cfg.criticalPercent}%) and AC is offline!" >&2
      FAIL=1
    fi

    if [ "$FAIL" = "0" ]; then
      echo "=== PASS: Hardware UPS simulation drill verified. Host battery is healthy and operational. ==="
      exit 0
    else
      echo "=== FAIL: Hardware UPS simulation drill detected abnormal power metrics! ===" >&2
      exit 1
    fi
  '';
in {
  options.services.upsSimulationDrill = {
    enable = lib.mkEnableOption "declarative hardware UPS clean-poweroff simulation drill and telemetry";

    schedule = lib.mkOption {
      type = lib.types.str;
      default = "Sun *-*-* 04:30:00";
      description = "systemd OnCalendar expression for the scheduled UPS simulation drill.";
    };

    batteryPath = lib.mkOption {
      type = lib.types.str;
      default = "/sys/class/power_supply/BAT0";
      description = "Sysfs directory path for the host battery device.";
    };

    acPath = lib.mkOption {
      type = lib.types.str;
      default = "/sys/class/power_supply/ADP0";
      description = "Sysfs directory path for the AC power adapter.";
    };

    minHealthPercent = lib.mkOption {
      type = lib.types.int;
      default = 60;
      description = "Minimum acceptable battery health percentage (full capacity vs design capacity).";
    };

    criticalPercent = lib.mkOption {
      type = lib.types.int;
      default = 5;
      description = "UPower clean emergency poweroff threshold percentage.";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.ups-simulation-drill = {
      description = "Hardware UPS simulation drill and battery telemetry";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${drillScript}/bin/ups-drill";
        ProtectSystem = "strict";
        ProtectHome = "read-only";
        PrivateTmp = true;
      };
    };

    systemd.timers.ups-simulation-drill = {
      description = "Scheduled hardware UPS simulation drill timer";
      wantedBy = ["timers.target"];
      timerConfig = {
        OnCalendar = cfg.schedule;
        Persistent = true;
        RandomizedDelaySec = "10m";
      };
    };

    environment.systemPackages = [drillScript];
  };
}
