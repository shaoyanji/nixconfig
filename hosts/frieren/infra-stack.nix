# Infrastructure monitoring + backups for frieren.
#
# smartd + scrutiny: SMART health polling and web dashboard for the
#   NAS's disks. frieren is a laptop running 24/7 — temperature and
#   reallocation trends are the early-warning system. Alerts land in
#   the journal (smartd) and the scrutiny UI; wire them into HA or
#   uptime-kuma notifications later. Port 8124 because the module
#   default 8080 collides with pihole-web.
# restic: nightly backup of the stateful services to /srv/backup
#   (data pool). The repository password is generated on-device on
#   first run (root-only file) — swap for an sops-managed file and/or
#   a remote repository when off-site backups land. PostgreSQL data
#   dirs are deliberately EXCLUDED: hot-copying a live data directory
#   is not a consistent backup — add services.postgresql.backup
#   (pg_dump) alongside before trusting DB restore points.
{ pkgs, ... }:
let
  agentCascadeScript = ''
    run_agent_cascade() {
      local prompt="$1"

      # Tier 1: Antigravity CLI (Gemini)
      echo "=== [$(date)] Agent Cascade: Attempting Tier 1 (Antigravity CLI / agy) ==="
      if ${pkgs.antigravity-cli}/bin/agy --dangerously-skip-permissions -p "$prompt"; then
        echo "=== [$(date)] Agent Cascade: Tier 1 (agy) succeeded. ==="
        return 0
      fi
      echo "=== [$(date)] WARN: agy failed (credit exhaustion, quota, or execution error). Attempting fallback... ===" >&2

      # Tier 2: Freebuff Headless (autonomous multi-session broker)
      if command -v freebuff-headless >/dev/null 2>&1 || [ -x "/home/devji/.local/bin/freebuff-headless" ]; then
        echo "=== [$(date)] Agent Cascade: Attempting Tier 2 (freebuff-headless) ==="
        local fb_bin
        fb_bin="$(command -v freebuff-headless 2>/dev/null || echo "/home/devji/.local/bin/freebuff-headless")"
        if "$fb_bin" -C /home/devji -t 600 "$prompt"; then
          echo "=== [$(date)] Agent Cascade: Tier 2 (freebuff-headless) succeeded. ==="
          return 0
        fi
        echo "=== [$(date)] WARN: freebuff-headless failed. Attempting Tier 3 fallback... ===" >&2
      fi

      # Tier 3: Hermes Agent (Nous Research agent with ~/.hermes / hermes.env)
      if command -v hermes >/dev/null 2>&1 || [ -x "/run/current-system/sw/bin/hermes" ]; then
        echo "=== [$(date)] Agent Cascade: Attempting Tier 3 (hermes) ==="
        local hermes_bin
        hermes_bin="$(command -v hermes 2>/dev/null || echo "/run/current-system/sw/bin/hermes")"

        # Source hermes API keys & env
        if [ -f "/home/devji/.config/hermes/hermes.env" ]; then
          set -a
          # shellcheck disable=SC1091
          source /home/devji/.config/hermes/hermes.env 2>/dev/null || true
          set +a
        fi

        if "$hermes_bin" -q "$prompt" --oneshot; then
          echo "=== [$(date)] Agent Cascade: Tier 3 (hermes) succeeded. ==="
          return 0
        fi
        echo "=== [$(date)] WARN: hermes failed. Attempting Tier 4 fallback... ===" >&2
      fi

      # Tier 4: Crush CLI agent (Charmbracelet agent)
      if command -v crush >/dev/null 2>&1 || [ -x "/home/devji/.local/bin/crush" ]; then
        echo "=== [$(date)] Agent Cascade: Attempting Tier 4 (crush) ==="
        local crush_bin
        crush_bin="$(command -v crush 2>/dev/null || echo "/home/devji/.local/bin/crush")"
        if "$crush_bin" run --quiet "$prompt"; then
          echo "=== [$(date)] Agent Cascade: Tier 4 (crush) succeeded. ==="
          return 0
        fi
        echo "=== [$(date)] WARN: crush failed. ===" >&2
      fi

      echo "=== [$(date)] ERROR: All agent execution tiers in cascade failed. ===" >&2
      return 1
    }
  '';

  agyHandoffRunner = pkgs.writeShellScript "agy-handoff-runner" ''
    set -euo pipefail

    HANDOFF_FILE="/home/devji/HANDOFF.md"

    if [ ! -f "$HANDOFF_FILE" ]; then
      echo "No HANDOFF.md found in /home/devji. Skipping execution."
      exit 0
    fi

    echo "=== [$(date)] Found $HANDOFF_FILE. Preparing execution... ==="
    ARCHIVE_DIR="/home/devji/.agents/handoffs"
    mkdir -p "$ARCHIVE_DIR"
    ARCHIVE_COPY="$ARCHIVE_DIR/HANDOFF-$(date +%Y%m%d_%H%M%S).md"
    cp "$HANDOFF_FILE" "$ARCHIVE_COPY"

    cd /home/devji

    ${agentCascadeScript}

    prompt="Please read HANDOFF.md in the current working directory and execute the plan."

    if run_agent_cascade "$prompt"; then
      echo "=== [$(date)] Handoff execution finished successfully. Deleting $HANDOFF_FILE ==="
      rm -f "$HANDOFF_FILE"
      echo "=== [$(date)] Cleanup complete. Archived copy retained at $ARCHIVE_COPY ==="
    else
      echo "=== [$(date)] CRITICAL: Handoff execution failed across all agent tiers! ===" >&2
      BLOCKED_COPY="$HANDOFF_FILE.blocked-$(date +%Y%m%d_%H%M%S)"
      mv "$HANDOFF_FILE" "$BLOCKED_COPY"
      echo "=== [$(date)] Preserved unexecuted handoff as $BLOCKED_COPY ===" >&2
      exit 1
    fi
  '';

  agySystemRunner = pkgs.writeShellScript "agy-system-runner" ''
    set -euo pipefail

    SYSTEM_FILE="/home/devji/SYSTEM.md"

    if [ ! -f "$SYSTEM_FILE" ]; then
      echo "No SYSTEM.md found in /home/devji. Skipping execution."
      exit 0
    fi

    echo "=== [$(date)] Found $SYSTEM_FILE. Preparing execution... ==="
    ARCHIVE_DIR="/home/devji/.agents/system"
    mkdir -p "$ARCHIVE_DIR"
    ARCHIVE_COPY="$ARCHIVE_DIR/SYSTEM-$(date +%Y%m%d_%H%M%S).md"
    cp "$SYSTEM_FILE" "$ARCHIVE_COPY"

    cd /home/devji

    # --- STEP 1: Deterministic Health & Self-Repair (Runs 100% locally with 0 API tokens) ---
    echo "=== [$(date)] Step 1: Performing deterministic service checks ==="
    FAILED_SYS=$(systemctl --failed --no-pager --plain --quiet | grep -v "0 loaded" | wc -l || echo 0)
    FAILED_USER=$(systemctl --user --failed --no-pager --plain --quiet | grep -v "0 loaded" | wc -l || echo 0)

    if [ "$FAILED_SYS" -gt 0 ]; then
      echo "Detected failed system units. Attempting reset-failed..."
      systemctl reset-failed || true
    fi
    if [ "$FAILED_USER" -gt 0 ]; then
      echo "Detected failed user units. Attempting reset-failed..."
      systemctl --user reset-failed || true
    fi

    # --- STEP 2: Agent Cascade Execution ---
    ${agentCascadeScript}

    prompt="Please read SYSTEM.md in the current working directory, execute the health and maintenance audits, draft a HANDOFF.md for any missing items or recommendations, and update/refine SYSTEM.md in-place with current findings and status."

    if run_agent_cascade "$prompt"; then
      echo "=== [$(date)] System maintenance run finished. Pre-run snapshot preserved at $ARCHIVE_COPY ==="
    else
      echo "=== [$(date)] WARN: All AI agent tiers failed. Applying deterministic timestamp update to $SYSTEM_FILE ===" >&2
      CURRENT_DATE=$(date "+%Y-%m-%d %H:%M %Z")
      sed -i "s/\* \*\*Last Audit Run:\*\* .*/\* \*\*Last Audit Run:\*\* $CURRENT_DATE (Deterministic Fallback)/" "$SYSTEM_FILE" || true
      echo "=== [$(date)] Deterministic audit recorded in $SYSTEM_FILE ==="
    fi
  '';
in
{
  # --- SMART monitoring ---
  services.smartd = {
    enable = true;
    autodetect = true;
    notifications.mail.enable = false; # no MTA configured; see header
  };

  services.scrutiny = {
    enable = true;
    collector.enable = true; # weekly metric collector (default timer)
    settings.web.listen.port = 8124;
  };
  networking.firewall.allowedTCPPorts = [ 8124 ];

  # --- Vaultwarden (Bitwarden Compatible Password & TOTP Vault) ---
  services.vaultwarden = {
    enable = true;
    config = {
      ROCKET_ADDRESS = "127.0.0.1";
      ROCKET_PORT = 8222;
      DOMAIN = "http://vault.frieren.lan";
      SIGNUPS_ALLOWED = true;
    };
    backupDir = "/srv/backup/vaultwarden";
  };

  # --- PostgreSQL daily pg_dump for Immich & Paperless ---
  systemd.tmpfiles.rules = [
    # 0755 (not 0700): the vaultwarden and postgres service users must be
    # able to TRAVERSE /srv/backup to reach their own 0700 subdirectories.
    # With 0700 their backups failed with "Backup folder does not exist".
    "d /srv/backup 0755 root root -"
    "d /srv/backup/postgresql 0700 postgres postgres -"
    "d /srv/backup/vaultwarden 0700 vaultwarden vaultwarden -"
  ];

  services.postgresqlBackup = {
    enable = true;
    databases = [ "immich" ];
    location = "/srv/backup/postgresql";
    startAt = "*-*-* 03:00:00"; # 30 min before 03:30 restic snapshot
  };

  # --- restic local backups ---
  services.restic.backups.frieren-local = {
    initialize = true;
    repository = "/srv/backup/restic";
    passwordFile = "/root/.restic-password";
    paths = [
      "/srv/private/home-assistant"
      "/srv/private/plex"
      "/srv/private/zigbee2mqtt"
      "/var/lib/immich"
      "/var/lib/paperless"
      "/var/lib/uptime-kuma"
      "/var/lib/vaultwarden"
      "/srv/backup/postgresql"
      "/srv/backup/vaultwarden"
    ];
    # NOTE: /var/lib/postgresql intentionally excluded — see header.
    timerConfig = {
      OnCalendar = "*-*-* 03:30:00"; # before the 04:00 autoUpgrade
      Persistent = true;
      RandomizedDelaySec = "10min";
    };
    pruneOpts = [
      "--keep-daily 7"
      "--keep-weekly 5"
      "--keep-monthly 12"
    ];
  };

  # Guarantee the restic password file exists before restic-backups runs
  # (preStart runs after module initialization, which leads to ordering failures).
  systemd.services.restic-ensure-password = {
    description = "Ensure restic repository password file exists";
    wantedBy = [ "multi-user.target" ];
    before = [ "restic-backups-frieren-local.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = pkgs.writeShellScript "restic-ensure-password" ''
        if [ ! -s /root/.restic-password ]; then
          head -c 32 /dev/urandom | base64 > /root/.restic-password
          chmod 0600 /root/.restic-password
        fi
      '';
    };
  };

  systemd.services.restic-backups-frieren-local.unitConfig = {
    Wants = [ "restic-ensure-password.service" ];
    After = [ "restic-ensure-password.service" ];
  };

  # 24/7 Remote Operator Gateway: Antigravity remote-control daemon
  systemd.user.services.antigravity-cli-daemon = {
    description = "antigravity remote-control daemon";
    after = [ "network.target" ];
    unitConfig = {
      StartLimitIntervalSec = 0;
    };
    serviceConfig = {
      Type = "simple";
      Environment = [
        "SSH_CLIENT=127.0.0.1 1 1"
        "SSH_CONNECTION=127.0.0.1 1 127.0.0.1 22"
        "HOME=/home/devji"
        "USER=devji"
        "PATH=/home/devji/.nix-profile/bin:/etc/profiles/per-user/devji/bin:/run/current-system/sw/bin"
        "SHELL=/run/current-system/sw/bin/bash"
      ];
      ExecStart = "${pkgs.antigravity-cli}/bin/agy remote-control serve";
      Restart = "on-failure";
      RestartSec = "10s";
      RestartPreventExitStatus = 3;
      TimeoutStopSec = "30s";
      StandardOutput = "journal";
      StandardError = "journal";
    };
    wantedBy = [ "default.target" ];
  };

  # Nightly Antigravity Handoff Runner (3:00 AM)
  systemd.user.services.agy-nightly-handoff = {
    description = "Run /home/devji/HANDOFF.md with Antigravity if present, then delete";
    after = [ "network.target" ];
    serviceConfig = {
      Type = "oneshot";
      WorkingDirectory = "/home/devji";
      Environment = [
        "HOME=/home/devji"
        "USER=devji"
        "PATH=/home/devji/.nix-profile/bin:/etc/profiles/per-user/devji/bin:/run/current-system/sw/bin:/home/devji/.local/bin"
        "SHELL=/run/current-system/sw/bin/bash"
      ];
      ExecStart = "${agyHandoffRunner}";
      StandardOutput = "journal";
      StandardError = "journal";
    };
  };

  systemd.user.timers.agy-nightly-handoff = {
    description = "Check and run /home/devji/HANDOFF.md nightly at 3 AM";
    timerConfig = {
      OnCalendar = "*-*-* 03:00:00";
      Persistent = true;
    };
    wantedBy = [ "timers.target" ];
  };

  # Daily 5:00 AM Antigravity System Maintenance Runner (SYSTEM.md)
  systemd.user.services.agy-nightly-system = {
    description = "Run /home/devji/SYSTEM.md with Antigravity if present, then delete";
    after = [ "network.target" ];
    serviceConfig = {
      Type = "oneshot";
      WorkingDirectory = "/home/devji";
      Environment = [
        "HOME=/home/devji"
        "USER=devji"
        "PATH=/home/devji/.nix-profile/bin:/etc/profiles/per-user/devji/bin:/run/current-system/sw/bin:/home/devji/.local/bin"
        "SHELL=/run/current-system/sw/bin/bash"
      ];
      ExecStart = "${agySystemRunner}";
      StandardOutput = "journal";
      StandardError = "journal";
    };
  };

  systemd.user.timers.agy-nightly-system = {
    description = "Check and run /home/devji/SYSTEM.md daily at 5 AM";
    timerConfig = {
      OnCalendar = "*-*-* 05:00:00";
      Persistent = true;
    };
    wantedBy = [ "timers.target" ];
  };
}
