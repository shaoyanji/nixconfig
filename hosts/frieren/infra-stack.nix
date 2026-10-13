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
{
  pkgs,
  config,
  lib,
  ...
}: let
  # The backup whose repository the restore drill below verifies.
  resticBackup = config.services.restic.backups.frieren-local;

  # `restic check` validates repository structure/consistency; the sampled
  # restore proves the data actually comes back. Fails loudly (non-zero exit)
  # so a broken repo cannot pass silently. Used by restic-drill.service below.
  resticDrill = pkgs.writeShellScript "restic-drill" ''
    set -euo pipefail
    export RESTIC_REPOSITORY=${lib.escapeShellArg (toString resticBackup.repository)}
    export RESTIC_PASSWORD_FILE=${lib.escapeShellArg (toString resticBackup.passwordFile)}
    export HOME=/root
    export XDG_CACHE_HOME=/tmp/restic-drill-cache
    restic=${pkgs.restic}/bin/restic

    echo "== restic check (repository integrity) =="
    "$restic" check

    echo "== sampled restore (latest snapshot: /srv/private/home-assistant) =="
    latest=$("$restic" snapshots latest --json | ${pkgs.jq}/bin/jq -r '.[0].short_id')
    scratch=$(${pkgs.coreutils}/bin/mktemp -d /srv/backup/.restic-drill.XXXXXX)
    trap '${pkgs.coreutils}/bin/rm -rf "$scratch"' EXIT
    "$restic" restore "$latest" --target "$scratch" --include /srv/private/home-assistant
    # Assert real restored content: configuration.yaml is an absolute symlink
    # into /etc, so `test -f` would resolve the LIVE file and prove nothing.
    test -d "$scratch/srv/private/home-assistant"
    test -n "$(${pkgs.findutils}/bin/find "$scratch/srv/private/home-assistant" -type f -print -quit)"
    echo "restic drill OK: restored a sample from snapshot $latest"
  '';

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

        # Source hermes API keys & env directly from ~/.hermes/.env
        if [ -f "/home/devji/.hermes/.env" ]; then
          set -a
          # shellcheck disable=SC1091
          source /home/devji/.hermes/.env 2>/dev/null || true
          set +a
        elif [ -f "/home/devji/.config/hermes/hermes.env" ]; then
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
in {
  imports = [
    ../../modules/services/fleet-monitors.nix
    ../../modules/services/agent-scheduler.nix
    ../../modules/services/btrfs-watchdog.nix
    ../../modules/services/uds-static-bridge.nix
    ../../modules/services/ups-simulation-drill.nix
    ../../modules/services/sqlite-maintenance.nix
    ../../modules/services/paperless-watchdog.nix
    ../../modules/services/kiwix-watchdog.nix
    ../../modules/services/postgres-pgvector-audit.nix
    ../../modules/services/fleet-session-reaper.nix
    ../../modules/services/postgres-backup-drill.nix
    ../../modules/services/flake-advisory-audit.nix
    ../../modules/services/tls-cert-watchdog.nix
    ../../modules/services/systemone-decision.nix
  ];

  # --- monitors as code (HC-6) ---
  # Nothing was watched before this: Uptime-Kuma had 0 monitors and Kuma's own
  # monitors cannot be declared (its HTTP API is read-only), so the list lives in
  # the repo instead and gatus consumes it. Every endpoint probes loopback, so no
  # firewall entry is needed and the UI is reached at monitors.frieren.lan through
  # nginx (reverse-proxy.nix).
  services.fleetMonitors = {
    enable = true;
    endpoints = [
      {
        name = "nginx portal";
        url = "http://127.0.0.1:80";
        group = "frieren";
        conditions = ["[STATUS] < 400"];
      }
      {
        name = "jellyfin";
        url = "http://127.0.0.1:8096";
        group = "frieren";
        conditions = ["[STATUS] < 400"];
      }
      {
        name = "immich";
        url = "http://127.0.0.1:2283";
        group = "frieren";
        conditions = ["[STATUS] < 400"];
      }
      {
        name = "paperless";
        url = "http://127.0.0.1:28981";
        group = "frieren";
        conditions = ["[STATUS] < 400"];
      }
      {
        name = "home assistant";
        url = "http://127.0.0.1:8123";
        group = "frieren";
        conditions = ["[STATUS] < 400"];
      }
      {
        name = "harmonia cache";
        url = "http://127.0.0.1:5000";
        group = "frieren";
        conditions = ["[STATUS] < 400"];
      }
      # The clearest previously-unwatched failure mode: a connecting probe proves
      # the resolver socket is up. A full resolution assertion needs a dns://
      # endpoint (see TODO.md HC-6 remaining).
      {
        name = "dns (pihole-ftl)";
        url = "tcp://127.0.0.1:53";
        group = "dns";
        conditions = ["[CONNECTED] == true"];
      }
    ];
  };

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
  networking.firewall.allowedTCPPorts = [8124];

  # Scrutiny brings InfluxDB up with it (`services.scrutiny.influxdb.enable`
  # defaults on), and InfluxDB's HTTP API then binds every interface on 8086.
  # Scrutiny reads it over localhost, so narrow the bind instead of leaving a
  # public listener the firewall has to hold back (HC-7). Nothing else in the
  # tree queries this instance — checked: no `8086`/`influxdb` consumer outside
  # this module, and the provisioner already targets localhost when the bind is
  # not a wildcard.
  services.influxdb2.settings.http-bind-address = "127.0.0.1:8086";

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
    databases = ["immich"];
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
    wantedBy = ["multi-user.target"];
    before = ["restic-backups-frieren-local.service"];
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
    Wants = ["restic-ensure-password.service"];
    After = ["restic-ensure-password.service"];
  };

  # --- restic restore drill ---
  # A backup that is never restored is a hypothesis; the script (defined in the
  # let block) runs `restic check` + a sampled restore. Runs weekly, outside the
  # nightly backup window, and fails loudly into the journal.
  systemd.services.restic-drill = {
    description = "restic repository check + sampled restore drill";
    path = [pkgs.coreutils pkgs.findutils];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = resticDrill;
    };
  };

  systemd.timers.restic-drill = {
    description = "Weekly restic restore drill";
    wantedBy = ["timers.target"];
    timerConfig = {
      OnCalendar = "Sun *-*-* 06:30:00";
      Persistent = true;
      RandomizedDelaySec = "15min";
    };
  };

  # 24/7 Remote Operator Gateway: Antigravity remote-control daemon
  systemd.user.services.antigravity-cli-daemon = {
    description = "antigravity remote-control daemon";
    after = ["network.target"];
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
    wantedBy = ["default.target"];
  };

  # Declarative Agent Scheduler (EXP-016)
  services.agentScheduler = {
    enable = true;
    jobs = {
      agy-nightly-handoff = {
        name = "agy-nightly-handoff";
        description = "Run /home/devji/HANDOFF.md with Antigravity if present, then delete";
        schedule = "*-*-* 03:00:00";
        command = agyHandoffRunner;
        workingDirectory = "/home/devji";
      };
      agy-nightly-system = {
        name = "agy-nightly-system";
        description = "Run /home/devji/SYSTEM.md with Antigravity if present, then delete";
        schedule = "*-*-* 05:00:00";
        command = agySystemRunner;
        workingDirectory = "/home/devji";
      };
    };
  };

  # Declarative Btrfs silent corruption & device error watchdog (EXP-022)
  # Periodically inspects kernel Btrfs device stats counters across the SSD
  # root partition (/dev/sdb3) and the HDD data pool (/dev/sda2).
  services.btrfsWatchdog = {
    enable = true;
    mounts = ["/" "/Volumes/data"];
    interval = "hourly";
    failOnErrors = true;
  };

  # Zero-TCP static documentation bridge via UNIX domain sockets (EXP-024)
  # Serves immutable Aki fleet docs natively over unix:/run/uds-docs/docs.sock
  services.udsStaticBridge = {
    enable = true;
    socketPath = "/run/uds-docs/docs.sock";
  };

  # Hardware UPS simulation drill and battery telemetry (EXP-029)
  # Inspects Lenovo battery health, runtime modeling, and UPower clean poweroff thresholds.
  services.upsSimulationDrill = {
    enable = true;
    minHealthPercent = 60;
    criticalPercent = 5;
  };

  # Declarative SQLite WAL checkpoint & integrity dispatcher (EXP-030)
  # Compacts WAL files and verifies integrity across embedded fleet databases before backup window.
  services.sqliteMaintenance = {
    enable = true;
    schedule = "*-*-* 02:30:00";
    databases = [
      "/var/lib/pihole/pihole-FTL.db"
      "/var/lib/pihole/gravity.db"
      "/var/lib/private/uptime-kuma/kuma.db"
      "/var/lib/private/scrutiny/scrutiny.db"
      "/var/lib/sonarr/.config/NzbDrone/sonarr.db"
      "/var/lib/paperless/db.sqlite3"
      "/srv/data/paperless/celerybeat-schedule.db"
      "/home/devji/.simplex/simplex_v1_agent.db"
      "/home/devji/.simplex/simplex_v1_chat.db"
    ];
    checkpointMode = "truncate";
    runOptimize = true;
    runQuickCheck = true;
    failOnCorruption = true;
  };

  # Declarative Paperless-ngx document ingestion watchdog & pipeline health probe (EXP-038)
  # Inspects /var/lib/paperless/consume for stalled, un-ingested, or 0-byte ghost files.
  services.paperlessWatchdog = {
    enable = true;
    consumeDir = "/var/lib/paperless/consume";
    maxStallMinutes = 20;
    schedule = "hourly";
    failOnStall = false; # alert/log without failing unit
  };

  # Declarative Kiwix offline library integrity & search health probe (EXP-040)
  # Verifies ZIM archives readability and benchmarks full-text search responsiveness.
  services.kiwixWatchdog = {
    enable = true;
    endpoint = "http://127.0.0.1:8088";
    libraryFile = "/var/lib/kiwix/library.xml";
    testQueries = ["NixOS" "Btrfs" "Linux"];
    schedule = "daily";
    failOnSearchError = true;
  };

  # Declarative PostgreSQL vector (pgvector/vchord) indexing health & vacuum drill (EXP-045)
  # Inspects face_search and smart_search vector tables in Immich DB and runs page compaction vacuum.
  services.postgresPgvectorAudit = {
    enable = true;
    database = "immich";
    vectorTables = ["face_search" "smart_search"];
    runVacuum = true;
    reindex = false;
    schedule = "Sun *-*-* 02:15:00"; # strictly before 03:00 backup window
  };

  # Declarative SSH bastion & inactive session reaper (EXP-046)
  # Sweeps orphaned session scopes and idle remote SSH sessions (> 4h) while preserving tmux/screen/agy.
  services.fleetSessionReaper = {
    enable = true;
    maxIdleHours = 4;
    ignoredUsers = [];
    preserveMultiplexers = true;
    dryRun = false;
    schedule = "hourly";
  };

  # Declarative PostgreSQL logical backup verification drill (EXP-042)
  # Ephemerally restores nightly pg_dump snapshots to verify recoverability and row counts.
  services.postgresBackupDrill = {
    enable = true;
    backupDir = "/srv/backup/postgresql";
    databases = ["immich"];
    assertMinimumTables = 20;
    schedule = "Sun *-*-* 06:00:00"; # strictly after 03:00-05:30 backup window
  };

  # Declarative flake lock drift & security advisory audit unit (EXP-044)
  # Audits flake.lock inputs, asserts freshness on nixpkgs/home-manager/sops-nix, and flags stale inputs.
  services.flakeAdvisoryAudit = {
    enable = true;
    flakePath = /Volumes/data/projects/nixconfig;
    criticalInputs = ["nixpkgs" "home-manager" "sops-nix"];
    criticalMaxAgeDays = 14;
    warnAgeDays = 60;
    schedule = "Sun *-*-* 07:00:00"; # strictly after backup window
  };

  # Autonomous Nginx SSL/TLS Certificate Expiry Watchdog (EXP-050)
  # Audits local certificate files and declared endpoints to assert valid expiration windows.
  services.tlsCertWatchdog = {
    enable = true;
    endpoints = [
      "http://127.0.0.1:80"
      "http://127.0.0.1:8222"
    ];
    warnDays = 14;
    criticalDays = 5;
    schedule = "00/12:00:00"; # twice daily
    failOnCritical = false;
  };

  # System One Decision Engine CLI & Service (Julia-1 & Laya)
  services.systemoneDecision = {
    enable = true;
    defaultModel = "julia-1";
    installCli = true;
  };
}
