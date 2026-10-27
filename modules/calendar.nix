# Google Calendar -> vdirsyncer -> khal, plus the sync service and DMS notifications.
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
  # The OAuth client is declared, not scraped. Both halves come from the sops
  # plane (`googleDrive.clientId` / `.clientSecret` in modules/secrets.yaml,
  # declared in modules/sops.nix), so vdirsyncer reads the rendered secret and no
  # hand-made rclone.conf sits between the config and the credential. rclone keeps
  # its own conf because rclone cannot read sops — the two now merely hold the
  # same client, and the secret plane is the source.
  clientIdPath = config.sops.secrets.gdrive_client_id.path;
  clientSecretPath = config.sops.secrets.gdrive_client_secret.path;

  # The OAuth *token* is the opposite kind of fact: it exists only after an
  # interactive consent flow on that host (calendar skill § First sync), so config
  # cannot declare it. It is the honest runtime condition for sync — and unlike
  # rclone.conf it says what sync actually needs, because a client id with no
  # token still cannot fetch a calendar.
  tokenFile = "${config.xdg.configHome}/vdirsyncer/google_token";

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
      inherit tokenFile;
      clientIdCommand = ["${pkgs.coreutils}/bin/cat" clientIdPath];
      clientSecretCommand = ["${pkgs.coreutils}/bin/cat" clientSecretPath];
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

  programs.vdirsyncer = {
    enable = true;
    package = pkgs.vdirsyncer.overridePythonAttrs (old: {
      postPatch =
        (old.postPatch or "")
        + ''
          substituteInPlace vdirsyncer/storage/dav.py \
            --replace-fail 'urlparse.quote(x, "/@")' 'urlparse.quote(x, "/@+")'
        '';
    });
  };

  services.vdirsyncer = {
    enable = pkgs.stdenv.hostPlatform.isLinux;
    frequency = "*:0/15";
  };

  # Sync runs wherever this host has completed the consent flow. The credentials
  # are declared (sops); the token is state. A systemd condition is the declarative
  # form of that dependency: the timer keeps ticking, the service is skipped where
  # the token is absent (no red unit), and a host that finishes the flow starts
  # syncing with no config change.
  systemd.user.services.vdirsyncer.Unit.ConditionPathExists = tokenFile;

  # The notifier only exists on a generation that declares a session, and only
  # runs where the sync that fills khal can work.
  systemd.user.services.calendar-notify = lib.mkIf hasSession {
    Unit = {
      Description = "Google Calendar event notifier via libnotify/dms";
      After = ["graphical-session.target"];
      ConditionPathExists = tokenFile;
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
