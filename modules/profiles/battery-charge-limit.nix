# Battery charge ceiling for a plugged-in laptop: a pack parked at 100 % state of
# charge is where calendar ageing is fastest, and the ceiling is the only battery
# knob firmware exposes.
#
# The interface is a sysfs attribute, not an option, and drivers differ: some
# (thinkpad, asus-wmi, ideapad, acer-wmi, ...) expose
# charge_control_end_threshold, some expose only charge_behaviour, and some
# expose nothing -- the ceiling then lives in a vendor BIOS setting. The unit
# reports which case it found rather than failing on hardware it cannot drive:
# `journalctl -u battery-charge-limit` is the probe.
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.profiles.batteryChargeLimit;

  apply = pkgs.writeShellScript "battery-charge-limit" ''
    set -eu
    ceiling=${toString cfg.endThreshold}
    floor=${toString cfg.startThreshold}

    # /run is tmpfs, so a marker there lasts exactly one boot -- the right
    # cadence for "this hardware has no interface", which the 20-minute timer
    # below would otherwise repeat 72 times a day.
    state=/run/battery-charge-limit

    seen=0
    for bat in /sys/class/power_supply/BAT*; do
      [ -e "$bat" ] || continue
      seen=1
      name=''${bat##*/}
      end_file="$bat/charge_control_end_threshold"
      start_file="$bat/charge_control_start_threshold"

      if [ ! -w "$end_file" ]; then
        if [ ! -e "$state-$name-unsupported" ]; then
          : > "$state-$name-unsupported"
          echo "$name: no charge_control_end_threshold; the firmware owns the ceiling" >&2
        fi
        continue
      fi

      # Floor first: an EC that receives end < start rejects the pair.
      if [ -w "$start_file" ]; then
        echo "$floor" > "$start_file" || echo "$name: floor=$floor refused" >&2
      fi
      if echo "$ceiling" > "$end_file"; then
        echo "$name: ceiling=$ceiling floor=$floor"
      else
        echo "$name: ceiling=$ceiling refused" >&2
      fi
    done

    if [ "$seen" = 0 ] && [ ! -e "$state-no-battery" ]; then
      : > "$state-no-battery"
      echo "no /sys/class/power_supply/BAT*; nothing to limit" >&2
    fi
  '';
in {
  options.profiles.batteryChargeLimit = {
    enable = lib.mkEnableOption "a battery charge ceiling, so a docked laptop is not held at full charge";

    endThreshold = lib.mkOption {
      type = lib.types.ints.between 40 100;
      default = 80;
      description = "Highest charge level the pack may reach, in percent.";
    };

    startThreshold = lib.mkOption {
      type = lib.types.ints.between 0 100;
      default = 75;
      description = "Level at which charging resumes, where a start threshold exists.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.startThreshold < cfg.endThreshold;
        message = "profiles.batteryChargeLimit.startThreshold must be below endThreshold.";
      }
    ];

    systemd.services.battery-charge-limit = {
      description = "Hold the battery at or below ${toString cfg.endThreshold} % charge";
      wantedBy = ["multi-user.target"];
      # oneshot and not RemainAfterExit: the timer below has to be able to run it
      # again after a resume, and a start job on an active unit is a no-op.
      serviceConfig = {
        Type = "oneshot";
        ExecStart = apply;
      };
    };

    # Re-assert periodically. An EC reset or a resume can forget the ceiling, and
    # re-writing it is four bytes.
    systemd.timers.battery-charge-limit = {
      wantedBy = ["timers.target"];
      timerConfig = {
        Unit = "battery-charge-limit.service";
        OnBootSec = "2min";
        OnUnitInactiveSec = "20min";
      };
    };

    services.udev.extraRules = ''
      SUBSYSTEM=="power_supply", ATTR{type}=="Battery", ACTION=="add", TAG+="systemd", ENV{SYSTEMD_WANTS}+="battery-charge-limit.service"
    '';
  };
}
