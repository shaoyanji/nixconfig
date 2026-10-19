{
  config,
  pkgs,
  lib,
  ...
}: let
  user = import ./global/user.nix;

  calendarNotify = pkgs.writeShellApplication {
    name = "calendar-notify";
    runtimeInputs = with pkgs; [
      khal
      libnotify
      coreutils
      gnugrep
    ];
    text = ''
      # Only probe and notify if an active graphical display session exists
      if [ -z "''${WAYLAND_DISPLAY:-}" ] && [ -z "''${DISPLAY:-}" ]; then
        exit 0
      fi

      RUNTIME_DIR="''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
      STATE_FILE="$RUNTIME_DIR/calendar-notified.cache"
      touch "$STATE_FILE"

      # Look ahead 15 minutes for upcoming events
      # Format: {start-time}|{title}|{location}
      khal list now 15m --format "{start-time}|{title}|{location}" 2>/dev/null | while IFS="|" read -r time title loc; do
        [ -z "$title" ] && continue

        EVENT_KEY="$(date +%Y-%m-%d)-$time-$title"
        if ! grep -qFx "$EVENT_KEY" "$STATE_FILE"; then
          BODY="Starts at $time"
          if [ -n "$loc" ]; then
            BODY="$BODY ($loc)"
          fi

          notify-send \
            --app-name="Calendar" \
            --urgency=normal \
            --icon="calendar-symbolic" \
            --category="appointment" \
            "$title" \
            "$BODY" || true

          echo "$EVENT_KEY" >> "$STATE_FILE"
        fi
      done
    '';
  };
in {
  accounts.calendar.basePath = "${config.xdg.dataHome}/calendars";

  accounts.calendar.accounts."google" = {
    primary = true;
    khal = {
      enable = true;
      type = "discover";
    };
    vdirsyncer = {
      enable = true;
      collections = ["from a" "from b"];
      metadata = ["color" "displayname"];
    };
    remote = {
      type = "caldav";
      url = "https://apidata.googleusercontent.com/caldav/v2/${user.email}/user";
      userName = user.email;
      passwordCommand = ["cat" config.sops.secrets.gmail.path];
    };
    local = {
      type = "filesystem";
      fileExt = ".ics";
    };
  };

  programs.khal = {
    enable = true;
    locale = {
      timeformat = "%H:%M";
      dateformat = "%Y-%m-%d";
      longdateformat = "%Y-%m-%d";
      datetimeformat = "%Y-%m-%d %H:%M";
      longdatetimeformat = "%Y-%m-%d %H:%M";
      firstweekday = 0; # Monday
    };
  };

  programs.vdirsyncer.enable = true;

  services.vdirsyncer = {
    enable = pkgs.stdenv.hostPlatform.isLinux;
    frequency = "*:0/15";
  };

  systemd.user.services.calendar-notify = lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
    Unit = {
      Description = "Google Calendar event notifier via libnotify/dms";
      After = ["graphical-session.target"];
    };
    Service = {
      Type = "oneshot";
      ExecStart = "${calendarNotify}/bin/calendar-notify";
    };
  };

  systemd.user.timers.calendar-notify = lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
    Unit = {
      Description = "Check for upcoming calendar events every 5 minutes";
    };
    Timer = {
      OnCalendar = "*:0/5";
      Persistent = true;
    };
    Install = {
      WantedBy = ["timers.target"];
    };
  };
}
