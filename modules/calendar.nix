{
  config,
  pkgs,
  lib,
  ...
}: let
  getGoogleClientId = pkgs.writeShellScript "google-client-id" ''
    ${pkgs.python3}/bin/python3 -c "import configparser; cfg=configparser.ConfigParser(); cfg.read('${config.home.homeDirectory}/.config/rclone/rclone.conf'); print(cfg.get('gdrive','client_id'))"
  '';

  getGoogleClientSecret = pkgs.writeShellScript "google-client-secret" ''
    ${pkgs.python3}/bin/python3 -c "import configparser; cfg=configparser.ConfigParser(); cfg.read('${config.home.homeDirectory}/.config/rclone/rclone.conf'); print(cfg.get('gdrive','client_secret'))"
  '';

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
    primaryCollection = "Primary";
    khal = {
      enable = true;
      type = "discover";
    };
    vdirsyncer = {
      enable = true;
      collections = ["from a" "from b"];
      metadata = ["color" "displayname"];
      tokenFile = "${config.xdg.configHome}/vdirsyncer/google_token";
      clientIdCommand = ["${getGoogleClientId}"];
      clientSecretCommand = ["${getGoogleClientSecret}"];
    };
    remote = {
      type = "google_calendar";
    };
    local = {
      type = "filesystem";
      fileExt = ".ics";
    };
  };

  programs.khal = {
    enable = true;
    settings = {
      default = {
        default_calendar = "Primary";
      };
    };
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
