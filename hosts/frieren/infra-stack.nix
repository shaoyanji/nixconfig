# Infrastructure monitoring + backups for frieren.
{
  pkgs,
  config,
  lib,
  ...
}: let
  # Primary user constants (modules/global/user.nix is the single source).
  user = import ../../modules/global/user.nix;

  qmdEisenEmbedSync = import ../../modules/scripts/qmd-eisen-embed-sync.nix {inherit pkgs;};

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

  burgernasSftp = pkgs.writeShellScript "burgernas-sftp" ''
    exec ${pkgs.openssh}/bin/ssh -i /root/.ssh/id_ed25519 -o StrictHostKeyChecking=accept-new devji@192.168.3.92 /usr/local/bin/sftp-server "$@"
  '';

  fleetGatusReport =
    pkgs.writers.writePython3Bin "fleet-gatus-report" {
      libraries = [pkgs.python3Packages.websockets];
      flakeIgnore = ["E501" "E302" "E305" "E203" "W503"];
    } ''
      import asyncio
      import json
      import sys
      import urllib.request
      import uuid
      import websockets

      endpoint = "http://127.0.0.1:8181/api/v1/endpoints/statuses"
      try:
          req = urllib.request.Request(endpoint, headers={"User-Agent": "FleetGatusReporter/1.0"})
          with urllib.request.urlopen(req, timeout=5) as resp:
              data = json.loads(resp.read().decode())
      except Exception as e:
          msg = "⚠️ [Fleet Monitoring Alert - 05:00 AM] Gatus API unreachable at %s: %s\nHost: frieren (192.168.3.25)" % (endpoint, str(e))
          print("FAILED: 1")
          print(msg)
          sys.exit(1)

      total = len(data)
      failed = [d for d in data if not d.get("results", [{}])[-1].get("success", False)]
      if failed:
          header = "🚨 [Fleet Monitoring ALERT - 05:00 AM] %d of %d services DEGRADED." % (len(failed), total)
      else:
          header = "📊 [Fleet Monitoring Scorecard - 05:00 AM] All %d services NOMINAL." % total

      lines = [header, "Host: frieren (192.168.3.25)"]
      for d in data:
          name = d.get("name")
          group = d.get("group", "fleet")
          res = d.get("results", [{}])[-1]
          status = "UP" if res.get("success") else "DOWN"
          dur_ms = round(res.get("duration", 0) / 1000000.0, 1)
          lines.append("• %s (%s): %s (%.1f ms)" % (name, group, status, dur_ms))

      report = "\n".join(lines)
      print("FAILED: %d" % len(failed))
      print(report)

      async def send_to_simplex():
          corr_id = str(uuid.uuid4())[:8]
          rpc_req = {"corrId": corr_id, "cmd": "#Fleet " + report}
          async with websockets.connect("ws://127.0.0.1:5225") as ws:
              await ws.send(json.dumps(rpc_req))
              await asyncio.wait_for(ws.recv(), timeout=5.0)

      try:
          asyncio.run(send_to_simplex())
          print("Report dispatched to SimpleX #Fleet.")
      except Exception as e:
          sys.stderr.write("WARN: Failed to deliver 5AM report to SimpleX #Fleet: %s\n" % str(e))

      if failed:
          sys.exit(1)
    '';

  makeAudibleBatchLiberation = {
    name,
    timeoutSecs,
    limitBooks ? null,
    limitGb ? null,
    windowDesc,
    nice ? 10,
    ionice ? null,
  }: let
    limitArg =
      if limitGb != null
      then "--limit-gb ${toString limitGb}"
      else if limitBooks != null
      then "--limit-books ${toString limitBooks}"
      else "--limit-books 50";
    priorityPrefix =
      if nice != null && ionice != null
      then "${pkgs.coreutils}/bin/nice -n ${toString nice} ${pkgs.util-linux}/bin/ionice -c ${toString ionice}"
      else if nice != null
      then "${pkgs.coreutils}/bin/nice -n ${toString nice}"
      else "";
    pythonWithWebsockets = pkgs.python3.withPackages (ps: [ps.websockets]);
  in
    pkgs.writeShellScript name ''
            set -euo pipefail

            echo "=== [$(date)] Starting Scheduled Phased Audible Liberation (${windowDesc}) ==="

            # 1. Storage safety guard (require at least 250 GB available on /srv/data)
            AVAIL_GB=$(${pkgs.coreutils}/bin/df -BG /srv/data | ${pkgs.gawk}/bin/awk "NR==2 {gsub(/G/,\"\"); print \$4}")
            echo "Available storage on /srv/data: ''${AVAIL_GB} GB"

            MIN_HEADROOM_GB=250
            if [ "$AVAIL_GB" -lt "$MIN_HEADROOM_GB" ]; then
              MSG="⚠️ [Audible Liberation Skipped] Storage headroom too low (''${AVAIL_GB} GB free < ''${MIN_HEADROOM_GB} GB threshold). Pausing liberation."
              echo "$MSG" >&2
              SIMPLEX_RPC="${../../modules/user/ai/skills/simplex-admin/scripts/simplex-rpc.py}"
              if [ ! -f "$SIMPLEX_RPC" ]; then
                SIMPLEX_RPC="${user.home}/.gemini/config/skills/simplex-admin/scripts/simplex-rpc.py"
              fi
              if [ -f "$SIMPLEX_RPC" ]; then
                ${pythonWithWebsockets}/bin/python3 "$SIMPLEX_RPC" --send-group "#Fleet" "$MSG" || true
              fi
              exit 0
            fi

            # 2. Hard timeout enforcement:
            TIMEOUT_SECS=${toString timeoutSecs}
            LIBATION_BIN="${pkgs.libation}/bin/libationcli"

            echo "Executing: $LIBATION_BIN liberate ${limitArg}"
            BATCH_START_TIME=$(${pkgs.coreutils}/bin/date +%s)
            PRE_COUNT=$(${pkgs.findutils}/bin/find /srv/data/audiobooks/Books -type f -name "*.m4b" | ${pkgs.coreutils}/bin/wc -l || echo 0)

            ${priorityPrefix} \
              ${pkgs.coreutils}/bin/timeout --preserve-status -s TERM "$TIMEOUT_SECS" \
              "$LIBATION_BIN" liberate ${limitArg} || {
              EXIT_CODE=$?
              if [ "$EXIT_CODE" -eq 124 ] || [ "$EXIT_CODE" -eq 143 ]; then
                echo "=== [$(date)] Hit window cutoff timer (${windowDesc}); stopped gracefully ==="
              else
                echo "=== [$(date)] libationcli exited with code $EXIT_CODE ==="
              fi
            }

            BATCH_END_TIME=$(${pkgs.coreutils}/bin/date +%s)
            DURATION_MINS=$(( (BATCH_END_TIME - BATCH_START_TIME) / 60 ))
            POST_COUNT=$(${pkgs.findutils}/bin/find /srv/data/audiobooks/Books -type f -name "*.m4b" | ${pkgs.coreutils}/bin/wc -l || echo 0)
            NEW_BOOKS=$(( POST_COUNT - PRE_COUNT ))
            NEW_AVAIL_GB=$(${pkgs.coreutils}/bin/df -BG /srv/data | ${pkgs.gawk}/bin/awk "NR==2 {gsub(/G/,\"\"); print \$4}")

            REPORT="📚 [Audible Batch Liberation - ${windowDesc}]
      Batch Duration: ''${DURATION_MINS}m
      New Books Converted: ''${NEW_BOOKS}
      Total Library Size: ''${POST_COUNT} books
      Remaining Free Space: ''${NEW_AVAIL_GB} GB"

            echo "$REPORT"

            # 3. Post-batch Audiobookshelf notification / library check
            if ${pkgs.curl}/bin/curl -s -f http://127.0.0.1:13378/healthcheck >/dev/null 2>&1; then
              echo "Audiobookshelf is healthy on port 13378."
            fi

            # 4. Dispatch status report to SimpleX #Fleet
            SIMPLEX_RPC="${../../modules/user/ai/skills/simplex-admin/scripts/simplex-rpc.py}"
            if [ ! -f "$SIMPLEX_RPC" ]; then
              SIMPLEX_RPC="${user.home}/.gemini/config/skills/simplex-admin/scripts/simplex-rpc.py"
            fi
            if [ -f "$SIMPLEX_RPC" ]; then
              ${pythonWithWebsockets}/bin/python3 "$SIMPLEX_RPC" --send-group "#Fleet" "$REPORT" || true
            fi

            echo "=== [$(date)] Phased Audible Liberation Batch Finished Successfully ==="
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
      if command -v freebuff-headless >/dev/null 2>&1 || [ -x "${user.home}/.local/bin/freebuff-headless" ]; then
        echo "=== [$(date)] Agent Cascade: Attempting Tier 2 (freebuff-headless) ==="
        local fb_bin
        fb_bin="$(command -v freebuff-headless 2>/dev/null || echo "${user.home}/.local/bin/freebuff-headless")"
        if "$fb_bin" -C ${user.home} -t 600 "$prompt"; then
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
        if [ -f "${user.home}/.hermes/.env" ]; then
          set -a
          # shellcheck disable=SC1091
          source ${user.home}/.hermes/.env 2>/dev/null || true
          set +a
        elif [ -f "${user.home}/.config/hermes/hermes.env" ]; then
          set -a
          # shellcheck disable=SC1091
          source ${user.home}/.config/hermes/hermes.env 2>/dev/null || true
          set +a
        fi

        if "$hermes_bin" -q "$prompt" --oneshot; then
          echo "=== [$(date)] Agent Cascade: Tier 3 (hermes) succeeded. ==="
          return 0
        fi
        echo "=== [$(date)] WARN: hermes failed. Attempting Tier 4 fallback... ===" >&2
      fi

      # Tier 4: Crush CLI agent (Charmbracelet agent)
      if command -v crush >/dev/null 2>&1 || [ -x "${user.home}/.local/bin/crush" ]; then
        echo "=== [$(date)] Agent Cascade: Attempting Tier 4 (crush) ==="
        local crush_bin
        crush_bin="$(command -v crush 2>/dev/null || echo "${user.home}/.local/bin/crush")"
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

    HANDOFF_FILE="${user.home}/HANDOFF.md"

    if [ ! -f "$HANDOFF_FILE" ]; then
      echo "No HANDOFF.md found in ${user.home}. Skipping execution."
      exit 0
    fi

    echo "=== [$(date)] Found $HANDOFF_FILE. Preparing execution... ==="
    ARCHIVE_DIR="${user.home}/.agents/handoffs"
    mkdir -p "$ARCHIVE_DIR"
    ARCHIVE_COPY="$ARCHIVE_DIR/HANDOFF-$(date +%Y%m%d_%H%M%S).md"
    cp "$HANDOFF_FILE" "$ARCHIVE_COPY"

    cd ${user.home}

    # --- System One Decision Triage Preflight (Julia-1 & Laya) ---
    TRIAGE_REPORT="/tmp/systemone-handoff-triage.json"
    OPEN_ITEMS=0
    ACTIONABLE_COUNT=0
    if command -v systemone-decision >/dev/null 2>&1; then
      echo "=== [$(date)] Preflight: Running System One decision triage on $HANDOFF_FILE ==="
      systemone-decision --model julia-1 triage-handoff "$HANDOFF_FILE" > "$TRIAGE_REPORT" || true
      OPEN_ITEMS=$(grep -o '"status": "OPEN"' "$TRIAGE_REPORT" | wc -l || echo 0)
      ACTIONABLE_COUNT=$(grep -o '"category": "AUTONOMOUS_PROMOTION_CANDIDATE"' "$TRIAGE_REPORT" | wc -l || echo 0)
      echo "System One Handoff Triage: Evaluated $HANDOFF_FILE ($OPEN_ITEMS open items found, $ACTIONABLE_COUNT actionable autonomous candidates)."
    fi

    # --- Trigger Gate: Only invoke heavy LLM cascade if on-demand or actionable tasks exist ---
    if [ "''${FORCE_RUN:-0}" != "1" ] && [ "''${1:-}" != "--force" ] && [ "$ACTIONABLE_COUNT" -eq 0 ]; then
      echo "=== [$(date)] Handoff Gate: No actionable autonomous promotion candidates ($OPEN_ITEMS items remain blocked on hardware or documented gaps). Skipping LLM agent cascade. ==="
      exit 0
    fi

    ${agentCascadeScript}

    prompt="Please read HANDOFF.md in the current working directory and execute the plan. System One decision triage pre-analysis is available at /tmp/systemone-handoff-triage.json ($OPEN_ITEMS open items, $ACTIONABLE_COUNT actionable). The intent is to provide live execution guidance without replacing or deleting the markdown files."

    if run_agent_cascade "$prompt"; then
      echo "=== [$(date)] Handoff execution finished successfully. Preserved $HANDOFF_FILE in-place. ==="
    else
      echo "=== [$(date)] CRITICAL: Handoff execution encountered errors across agent tiers. Preserved $HANDOFF_FILE for inspection. ===" >&2
      exit 1
    fi
  '';

  agySystemRunner = pkgs.writeShellScript "agy-system-runner" ''
    set -euo pipefail

    SYSTEM_FILE="${user.home}/SYSTEM.md"

    if [ ! -f "$SYSTEM_FILE" ]; then
      echo "No SYSTEM.md found in ${user.home}. Skipping execution."
      exit 0
    fi

    echo "=== [$(date)] Found $SYSTEM_FILE. Preparing execution... ==="
    ARCHIVE_DIR="${user.home}/.agents/system"
    mkdir -p "$ARCHIVE_DIR"
    ARCHIVE_COPY="$ARCHIVE_DIR/SYSTEM-$(date +%Y%m%d_%H%M%S).md"
    cp "$SYSTEM_FILE" "$ARCHIVE_COPY"

    cd ${user.home}

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

    BTRFS_ERRS=$(btrfs device stats / 2>/dev/null | awk '{s+=$2} END {print s}' || echo 0)
    BACKUP_FAILS=$(systemctl is-failed postgresqlBackup-immich.service restic-backups-frieren-local.service restic-backups-frieren-burgernas.service backup-vaultwarden.service 2>/dev/null | grep failed | wc -l || echo 0)
    UPGRADE_FAILED=0
    if systemctl is-failed nixos-upgrade.service >/dev/null 2>&1; then
      UPGRADE_FAILED=1
    fi

    # --- STEP 1b: Gatus Fleet Monitoring & 5:00 AM SimpleX Dispatch ---
    echo "=== [$(date)] Step 1b: Running Gatus 5:00 AM fleet scorecard & SimpleX dispatch ==="
    GATUS_DOWN=0
    if ! ${fleetGatusReport}/bin/fleet-gatus-report; then
      echo "=== [$(date)] Gatus fleet monitor reported service failure(s) ==="
      GATUS_DOWN=1
    fi

    # --- STEP 2: System One Decision Triage (Julia-1 & Laya) ---
    echo "=== [$(date)] Step 2: Running System One Decision Triage (Julia-1) ==="
    TRIAGE_REPORT="/tmp/systemone-system-triage.json"
    TIER1_COUNT=0
    if command -v systemone-decision >/dev/null 2>&1; then
      systemone-decision --model julia-1 triage-system "$SYSTEM_FILE" > "$TRIAGE_REPORT" || true
      TIER1_COUNT=$(grep -o '"protocol": "TIER_1_IMMEDIATE_REPAIR"' "$TRIAGE_REPORT" | wc -l || echo 0)
      echo "System One System Triage: Evaluated scorecard with $TIER1_COUNT potential TIER 1 immediate repair item(s)."
    fi

    # --- STEP 3: Trigger Decision Gate ---
    # Trigger conditions for running full AI agent cascade:
    # 1. Scheduled weekly comprehensive audit (Sunday, date +%u == 7)
    # 2. Or manual on-demand trigger (FORCE_RUN=1 or argument --force)
    # 3. Or an active failure / regression detected:
    #    - FAILED_SYS > 0 or FAILED_USER > 0
    #    - BTRFS_ERRS > 0
    #    - BACKUP_FAILS > 0
    #    - UPGRADE_FAILED > 0
    #    - GATUS_DOWN > 0
    DAY_OF_WEEK=$(date +%u) # 1=Mon, ..., 7=Sun
    SHOULD_RUN_CASCADE=0
    RUN_REASON=""

    if [ "''${FORCE_RUN:-0}" = "1" ] || [ "''${1:-}" = "--force" ]; then
      SHOULD_RUN_CASCADE=1
      RUN_REASON="Manual on-demand trigger (--force / FORCE_RUN=1)"
    elif [ "$DAY_OF_WEEK" -eq 7 ]; then
      SHOULD_RUN_CASCADE=1
      RUN_REASON="Scheduled weekly comprehensive audit (Sunday)"
    elif [ "$FAILED_SYS" -gt 0 ] || [ "$FAILED_USER" -gt 0 ]; then
      SHOULD_RUN_CASCADE=1
      RUN_REASON="Active failed systemd units detected (sys: $FAILED_SYS, user: $FAILED_USER)"
    elif [ "$BTRFS_ERRS" -gt 0 ]; then
      SHOULD_RUN_CASCADE=1
      RUN_REASON="Btrfs device I/O or corruption errors detected ($BTRFS_ERRS errors)"
    elif [ "$BACKUP_FAILS" -gt 0 ]; then
      SHOULD_RUN_CASCADE=1
      RUN_REASON="Nightly backup service failure detected ($BACKUP_FAILS units failed)"
    elif [ "$UPGRADE_FAILED" -gt 0 ]; then
      SHOULD_RUN_CASCADE=1
      RUN_REASON="NixOS autoUpgrade failure detected"
    elif [ "$GATUS_DOWN" -gt 0 ]; then
      SHOULD_RUN_CASCADE=1
      RUN_REASON="Gatus fleet monitor alert: service failure detected during 05:00 AM audit"
    fi

    if [ "$SHOULD_RUN_CASCADE" -eq 0 ]; then
      echo "=== [$(date)] Quiet Reflex Gate: System is 100% nominal (0 failed units, 0 Btrfs errors, all backups clean). Preserving AI tokens. ==="
      CURRENT_DATE=$(date "+%Y-%m-%d %H:%M %Z")
      sed -i "s/\* \*\*Last Audit Run:\*\* .*/\* \*\*Last Audit Run:\*\* $CURRENT_DATE (Quiet Nominal Gate - 0 errors, AI tokens preserved)/" "$SYSTEM_FILE" || true
      echo "Recorded quiet nominal audit in $SYSTEM_FILE."
      exit 0
    fi

    # --- STEP 4: Agent Cascade Execution ---
    echo "=== [$(date)] Step 4: Trigger active ($RUN_REASON). Invoking Agent Cascade ==="
    ${agentCascadeScript}

    prompt="Please read SYSTEM.md in the current working directory, execute the health and maintenance audits, draft a HANDOFF.md for any missing items or recommendations, and update/refine SYSTEM.md in-place with current findings and status. System One decision pre-triage is available at /tmp/systemone-system-triage.json ($TIER1_COUNT immediate items flagged). Audit trigger reason: $RUN_REASON."

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
    (import ../../modules/profiles/microvm-host.nix {
      inherit pkgs;
      natExternalInterface = "enp1s0";
      bridgeAddress = "192.168.83.1/24";
    })
    ../../modules/services/fleet-monitors.nix
    ../../modules/services/downloads-sort.nix
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
    ../../modules/services/fleet-governor.nix
  ];

  # --- monitors as code (HC-6) ---
  # Nothing was watched before this: Uptime-Kuma had 0 monitors and Kuma's own
  # monitors cannot be declared (its HTTP API is read-only), so the list lives in
  # the repo instead and gatus consumes it. Every endpoint probes loopback, so no
  # firewall entry is needed and the UI is reached at monitors.frieren.lan through
  # nginx (reverse-proxy.nix).
  # Staging is a waiting room, not a home: everything downloaded lands in
  # /srv/data/downloads and is sorted into the taxonomy by scripts/task/
  # sort-downloads.sh (also `task data:sort`). The timer keeps it from becoming
  # a second, undeclared media tree; an item it cannot classify leaves the unit
  # failed rather than being guessed into arr/ or isos/.
  services.downloadsSort = {
    enable = true;
    interval = "hourly";
    # Extension and kind rules place the common case; a model is asked only when
    # they cannot, and only from a fixed list of destinations. It needs the
    # TypeSafe key, which lives in the rendered secrets tree for this host.
    classify = true;
    classifyPath = "/home/devji/.local/bin";
    classifyEnvironment = "/run/secrets/rendered/hermes.env";
  };

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
      # endpoint (see the `resolver-independence` note in AGENTS.nix).
      {
        name = "dns (pihole-ftl)";
        url = "tcp://127.0.0.1:53";
        group = "dns";
        conditions = ["[CONNECTED] == true"];
      }
      {
        name = "audiobookshelf";
        url = "http://127.0.0.1:13378";
        group = "frieren";
        conditions = ["[STATUS] < 400"];
      }
      # The closed loop: not "is nginx up" (the endpoint above) but "did the
      # nightly jobs succeed, is the generation fresh, is the NAS under
      # pressure". Body is JSON, so the condition asserts the sentinel's own
      # verdict rather than a 200 from a static file.
      {
        name = "fleet sentinel";
        url = "http://127.0.0.1:80/sentinel/status.json";
        group = "frieren";
        conditions = ["[BODY].state == ok"];
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
      # Declared rather than defaulted: the reverse proxy interpolates this value
      # (vault.frieren.lan /notifications/hub), and before this line :3012 existed
      # exactly once in the tree — inside the nginx config, as a literal.
      WEBSOCKET_PORT = 3012;
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

  # --- restic secrets (SOPS managed, rendered to /run/secrets/restic-password) ---
  sops.secrets.restic-password = {
    mode = "0400";
  };

  # --- restic local backups ---
  services.restic.backups.frieren-local = {
    initialize = true;
    repository = "/srv/backup/restic";
    passwordFile = config.sops.secrets.restic-password.path;
    paths = [
      "/srv/private/home-assistant"
      "/srv/private/plex"
      "/srv/private/zigbee2mqtt"
      "/var/lib/immich"
      "/var/lib/paperless"
      "/var/lib/uptime-kuma"
      "/var/lib/vaultwarden"
      "/var/lib/audiobookshelf"
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

  # --- restic cold vault backup to BurgerNAS ---
  # Pushes encrypted & deduplicated snapshots of Sandy, user documents, and stateful databases
  # to BurgerNAS during its daily scheduled uptime window (DSM hardware RTC powers on at 03:25, shuts off at 04:00).
  # Frieren acts as the push client so BurgerNAS (512MB RAM) only runs sftp-server and avoids OOM.
  services.restic.backups.frieren-burgernas = {
    initialize = true;
    repository = "sftp:devji@192.168.3.92:/volume1/backup/frieren/restic";
    passwordFile = config.sops.secrets.restic-password.path;
    extraOptions = [
      "sftp.command=${burgernasSftp}"
    ];
    paths = [
      "/srv/private/Sandy"
      "/srv/data/documents"
      "/srv/data/projects"
      "/srv/data/security"
      "/srv/backup/postgresql"
      "/srv/backup/vaultwarden"
      "/var/lib/immich"
      "/var/lib/paperless"
      "/srv/private/home-assistant"
      "/srv/private/zigbee2mqtt"
    ];
    timerConfig = {
      OnCalendar = "*-*-* 03:28:00";
      Persistent = true;
    };
    pruneOpts = [
      "--keep-daily 7"
      "--keep-weekly 4"
      "--keep-monthly 6"
      "--keep-yearly 2"
    ];
    backupPrepareCommand = ''
      # Verify BurgerNAS is reachable within its daily 03:25-04:00 DSM power window
      echo "Waiting for BurgerNAS SSH (192.168.3.92:22) to become reachable..."
      # NOTE: this runs inside the restic unit, whose PATH carries openssh and
      # coreutils but NOT `bash`. Invoke bash by absolute path.
      ONLINE=0
      for i in $(seq 1 60); do
        if timeout 3 ${pkgs.bash}/bin/bash -c 'cat < /dev/null > /dev/tcp/192.168.3.92/22' 2>/dev/null; then
          echo "BurgerNAS SSH port 22 open after $((i * 2))s."
          ONLINE=1
          break
        fi
        sleep 2
      done

      if [ "$ONLINE" -ne 1 ]; then
        echo "ERROR: BurgerNAS SSH unreachable within 120s (DSM scheduled power-on at 03:25 missed?)" >&2
        exit 1
      fi

      sleep 2
    '';
    backupCleanupCommand = ''
      echo "=== [$(date)] BurgerNAS backup finished. NAS will shut down at DSM scheduled 04:00. ==="
    '';
  };

  # --- BurgerNAS daily power-off safety net (22:45) ---
  # BurgerNAS shuts down at 04:00 daily via DSM's internal power schedule.
  # This timer serves as an auxiliary safety net at 22:45 to power off the NAS
  # if a manual session was forgotten during the day.
  systemd.services.burgernas-poweroff = {
    description = "Power off BurgerNAS if online (daily safety net)";
    after = ["network-online.target"];
    wants = ["network-online.target"];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = pkgs.writeShellScript "burgernas-poweroff" ''
        set -u
        NAS=devji@192.168.3.92
        KEY=/root/.ssh/id_ed25519
        SSH="${pkgs.openssh}/bin/ssh -i $KEY -o StrictHostKeyChecking=accept-new -o BatchMode=yes -o ConnectTimeout=5"
        # Only act when the NAS is up — a nightly error when it is already off
        # would be pure noise. NB: this unit's PATH has coreutils but NOT
        # `bash`, so use the absolute bash (a bare `bash -c` fails silently and
        # the check would always report the NAS offline).
        if ! timeout 5 ${pkgs.bash}/bin/bash -c 'cat < /dev/null > /dev/tcp/192.168.3.92/22' 2>/dev/null; then
          echo "BurgerNAS offline; nothing to power off."
          exit 0
        fi
        echo "BurgerNAS online at $(date -Is); powering off cleanly."
        $SSH "$NAS" "sudo /usr/syno/sbin/synopoweroff || sudo /sbin/poweroff" || true
      '';
    };
  };

  systemd.timers.burgernas-poweroff = {
    description = "Daily BurgerNAS power-off safety net (22:45)";
    wantedBy = ["timers.target"];
    timerConfig = {
      OnCalendar = "*-*-* 22:45:00";
      Persistent = true;
    };
  };

  # --- BurgerNAS portable-library mirror (weekly Sunday 03:32) ---
  # The whole tool library crosses the wire while the NAS is powered for its
  # scheduled window, so a non-Nix machine can pull tools from the NAS without
  # frieren being up. Rejected (dynamic) downloads are excluded: they are not
  # library material.
  systemd.services.burgernas-library-sync = {
    description = "Weekly mirror of the portable tool library to BurgerNAS";
    after = ["network-online.target" "restic-backups-frieren-burgernas.service"];
    wants = ["network-online.target"];
    serviceConfig = {
      Type = "oneshot";
      User = "devji";
      Group = "users";
      ExecStart = pkgs.writeShellScript "burgernas-library-sync" ''
        set -eu
        SRC="/Volumes/data"
        # The host and the path stay separate values. Concatenated into one
        # string they were both pasted into the `mkdir` that runs on the NAS,
        # which created a literal `./devji@192.168.3.92:/volume1/...` tree in its
        # home while rsync then failed on the path that was never made.
        DEST_HOST="devji@192.168.3.92"
        # The one lane is the export, so the bytes must live here.
        # Why: [[flake/policies.nix#library-crosses-the-wire]]
        DEST_PATH="/volume1/peachcable"
        KEY="${user.home}/.ssh/id_ed25519"
        SSH="${pkgs.openssh}/bin/ssh -i $KEY -o StrictHostKeyChecking=accept-new -o BatchMode=yes -o ConnectTimeout=5"

        if ! timeout 5 ${pkgs.bash}/bin/bash -c 'cat < /dev/null > /dev/tcp/192.168.3.92/22' 2>/dev/null; then
          echo "BurgerNAS offline; skipping library sync."
          exit 0
        fi

        dirs="bin-x86 bin-aarch64 bin-script appimages"
        # rsync creates only the final component, so the tree root goes first.
        # The share already exists; this is a no-op there and a creation on a
        # fresh NAS.
        $SSH "$DEST_HOST" "mkdir -p '$DEST_PATH' '$DEST_PATH/bin-x86' '$DEST_PATH/bin-aarch64' '$DEST_PATH/bin-script' '$DEST_PATH/appimages'"
        for dir in $dirs; do
          [ -d "$SRC/$dir" ] || continue
          echo "=== [$(date -Is)] mirroring $dir ==="
          # -s (--protect-args) is required, not cosmetic: the remote path
          # contains a space, and without it the *remote* shell splits it.
          # --no-perms because DSM's shared folders are ACL-managed and chmod
          # on the directory itself fails with EPERM, turning a successful
          # transfer into rsync exit 23.
          ${pkgs.rsync}/bin/rsync -azs --delete --partial --no-perms \
            --exclude '.rejected' \
            --exclude '@eaDir' \
            --exclude '.DS_Store' \
            --rsync-path=/usr/bin/rsync \
            -e "$SSH" \
            "$SRC/$dir/" "$DEST_HOST:$DEST_PATH/$dir/"
        done
        ${pkgs.rsync}/bin/rsync -qs --no-perms -e "$SSH" "$SRC/.library.tsv" "$DEST_HOST:$DEST_PATH/.library.tsv" || true
        echo "=== [$(date -Is)] Library mirror finished. ==="
      '';
    };
  };

  systemd.timers.burgernas-library-sync = {
    description = "Weekly mirror of the portable tool library to BurgerNAS";
    wantedBy = ["timers.target"];
    timerConfig = {
      OnCalendar = "Sun *-*-* 03:32:00";
      Persistent = true;
    };
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

  # --- QMD Remote Embedding Offload (Monthly, 1st of month at 02:00) ---
  # Offloads batch vector embeddings from Frieren (15W quad-core NAS) to Eisen
  # (12-core Xeon workstation) via Wake-on-LAN without LLM assistance.
  # Runs at 02:00 on the 1st of the month, well clear of the 03:00-05:30 backup window.
  # A timer-driven oneshot, not a daemon: it has no crash-loop class to declare.
  systemd.services.qmd-eisen-embed-sync = {
    description = "Monthly QMD vector embedding synchronization to Eisen via WoL";
    after = ["network-online.target"];
    wants = ["network-online.target"];
    serviceConfig = {
      Type = "oneshot";
      User = user.name;
      Group = "users";
      ExecStart = "${qmdEisenEmbedSync}/bin/qmd-eisen-embed-sync";
    };
  };

  systemd.timers.qmd-eisen-embed-sync = {
    description = "Monthly QMD vector embedding sync to Eisen";
    wantedBy = ["timers.target"];
    timerConfig = {
      OnCalendar = "*-*-01 02:00:00";
      Persistent = true;
      RandomizedDelaySec = "10min";
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
        ''"SSH_CLIENT=127.0.0.1 1 1"''
        ''"SSH_CONNECTION=127.0.0.1 1 127.0.0.1 22"''
        "HOME=${user.home}"
        "USER=devji"
        "PATH=${user.home}/.nix-profile/bin:/etc/profiles/per-user/${user.name}/bin:/run/current-system/sw/bin"
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
        description = "Action-gated handoff runner (runs only on autonomous promotion candidates or manual trigger)";
        schedule = "*-*-* 03:00:00";
        command = agyHandoffRunner;
        workingDirectory = "${user.home}";
      };
      agy-nightly-system = {
        name = "agy-nightly-system";
        description = "Trigger-gated system health audit (Mon-Sat quiet reflex, Sunday comprehensive scorecard)";
        schedule = "*-*-* 05:00:00";
        command = agySystemRunner;
        workingDirectory = "${user.home}";
      };
      audible-phased-liberation = {
        name = "audible-phased-liberation";
        description = "Scheduled nightly batch Audible liberation (00:00-02:50 CEST, 50 GB limit, 170m timeout)";
        schedule = "*-*-* 00:00:00";
        command = makeAudibleBatchLiberation {
          name = "audible-nightly-liberation";
          timeoutSecs = 10200; # 170 min, hard cutoff at 02:50 before 03:00 backup window
          limitGb = 50;
          windowDesc = "Nightly 00:00-02:50 CEST";
          nice = null;
        };
        workingDirectory = "${user.home}";
        lockFile = "/tmp/audible-liberation.lock";
        nice = 10;
        ioSchedulingClass = "best-effort";
      };
    };
  };

  # ===========================================================================
  # CONSOLIDATED FLEET GOVERNOR & RUNTIME SELF-REPAIR ORCHESTRATOR
  # Consolidates fragmented, monitoring-only watchdogs into a unified runtime repair engine:
  # - Kelly-gated dual-model reflex tier: Julia-1 (144M) + Laya (421M) in series (< 30ms sweep).
  # - 0 System 2 tokens consumed: completely protects weekly Nemotron quota.
  # - Deterministic runtime fixes: WAL compaction, thermals, Btrfs snapshots, paperless ghost quarantine.
  # - Automatic strategic handover: writes un-remediated anomalies directly to ${user.home}/HANDOFF.md.
  # ===========================================================================
  services.fleetGovernor = {
    enable = true;
    schedule = "hourly";
    autoRepair = true;
    allowSystem2 = false; # Strictly preserves weekly System 2 quota
  };

  # Declarative Btrfs silent corruption & device error watchdog (Consolidated into fleetGovernor)
  services.btrfsWatchdog.enable = false;

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

  # Declarative SQLite WAL checkpoint & integrity dispatcher (Consolidated into fleetGovernor)
  services.sqliteMaintenance.enable = false;

  # Declarative Paperless-ngx document ingestion watchdog (Consolidated into fleetGovernor)
  services.paperlessWatchdog.enable = false;

  # Declarative Kiwix offline library integrity & search probe (Consolidated into fleetGovernor)
  services.kiwixWatchdog.enable = false;

  # Declarative PostgreSQL vector indexing health & vacuum drill (Consolidated into fleetGovernor)
  services.postgresPgvectorAudit.enable = false;

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

  # Declarative flake lock drift & security advisory audit unit (Consolidated into fleetGovernor)
  services.flakeAdvisoryAudit.enable = false;

  # Autonomous Nginx SSL/TLS Certificate Expiry Watchdog (Consolidated into fleetGovernor)
  services.tlsCertWatchdog.enable = false;

  # System One Decision Engine CLI & Service (Julia-1 & Laya)
  services.systemoneDecision = {
    enable = true;
    defaultModel = "julia-1";
    installCli = true;
  };

  # Ollama Local AI & Cloud Model Proxy Service (revived on frieren)
  # Connects to state & model repository on HDD data pool (/Volumes/data/ollama)
  services.ollama = {
    enable = true;
    home = "/Volumes/data/ollama";
    modelsDir = "/Volumes/data/ollama/models";
    host = "127.0.0.1";
    openFirewall = false;
  };

  # Ephemeral MicroVM Sandbox SSH Client Configuration (EXP-102)
  # Eliminates known_hosts collisions and prompts for ephemeral test VMs
  # `~/.ssh/known_hosts_canary`, not /var/lib/microvms/.known_hosts: that directory
  # belongs to the microvm runner user (0755), so a non-root login could not write
  # its host key there and ssh failed on the pin while reporting only a key error.
  # The separate file still keeps ephemeral guests out of the real known_hosts.
  programs.ssh.extraConfig = ''
    Host frieren-canary
      HostName ${config.fleet.inventory.hosts.frieren-canary.network.lan_ip}
      User ${user.name}
      StrictHostKeyChecking accept-new
      UserKnownHostsFile ~/.ssh/known_hosts_canary
      IdentityFile ~/.ssh/id_ed25519
      ConnectTimeout 3

    Host 192.168.83.* testvm
      User devji
      StrictHostKeyChecking accept-new
      UserKnownHostsFile ~/.ssh/known_hosts_canary
      IdentityFile ~/.ssh/id_ed25519
      ConnectTimeout 3
  '';

  # User and permissions for MicroVM tap interfaces & KVM access
  users.users.microvm = {
    isSystemUser = true;
    group = "kvm";
    description = "MicroVM runner daemon user";
  };
  users.users.devji.extraGroups = ["kvm"];
}
