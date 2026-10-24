{
  config,
  pkgs,
  lib,
  osConfig ? null,
  ...
}: let
  # A graphical session is a declared capability, not a hostname: the profile
  # that installs the compositor (modules/profiles/base-desktop-environment.nix)
  # sets `programs.niri.enable`. A generation that never imports that profile
  # has no session, so the notifier does not exist there at all — frieren's boot
  # default is headless and gets nothing, while its `desktop` specialisation
  # declares the compositor and gets the unit. Standalone HM hosts have no
  # osConfig, hence no session.
  hasSession =
    pkgs.stdenv.hostPlatform.isLinux
    && osConfig != null
    && (osConfig.programs.niri.enable or false);
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

          # Record the event only when the toast was actually delivered: a
          # failed send (no session bus, no notification daemon) must be retried
          # on the next tick, not silently swallowed for the rest of the day.
          if notify-send \
            --app-name="Calendar" \
            --urgency=normal \
            --icon="calendar-symbolic" \
            --category="appointment" \
            "$title" \
            "$BODY"; then
            echo "$EVENT_KEY" >> "$STATE_FILE"
          fi
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

  # vdirsyncer's credentials are the Google OAuth client id/secret read out of the
  # hand-made ~/.config/rclone/rclone.conf (see getGoogleClientId/Secret) — a file
  # no Nix module declares, which is why this used to be a hostname list. A
  # systemd condition is the declarative form of that dependency: the timer keeps
  # ticking, the service is skipped where the file is absent (no red unit), and a
  # host that later gains the file starts syncing with no config change.
  systemd.user.services.vdirsyncer.Unit.ConditionPathExists = "%h/.config/rclone/rclone.conf";

  # The notifier only exists on a generation that declares a session, and only
  # runs where the sync that fills khal can work.
  systemd.user.services.calendar-notify = lib.mkIf hasSession {
    Unit = {
      Description = "Google Calendar event notifier via libnotify/dms";
      After = ["graphical-session.target"];
      ConditionPathExists = "%h/.config/rclone/rclone.conf";
    };
    Service = {
      Type = "oneshot";
      ExecStart = "${calendarNotify}/bin/calendar-notify";
    };
  };

  systemd.user.timers.calendar-notify = lib.mkIf hasSession {
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
