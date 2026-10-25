# Delphi Infrastructure Stack — Health Sentinel, Autonomous Agent Schedulers, and Resource Regulation
{
  config,
  pkgs,
  lib,
  ...
}: let
  user = import ../../modules/global/user.nix;

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
        if "$fb_bin" -C "${user.home}" -t 600 "$prompt"; then
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

        if [ -f "${user.home}/.hermes/.env" ]; then
          set -a
          # shellcheck disable=SC1091
          source "${user.home}/.hermes/.env" 2>/dev/null || true
          set +a
        fi

        if "$hermes_bin" -q "$prompt" --oneshot; then
          echo "=== [$(date)] Agent Cascade: Tier 3 (hermes) succeeded. ==="
          return 0
        fi
        echo "=== [$(date)] WARN: hermes failed. Attempting Tier 4 fallback... ===" >&2
      fi

      # Tier 4: Crush CLI agent (Charm's AI coding agent)
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

    cd "${user.home}"

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
      echo "=== [$(date)] Handoff Gate: No actionable autonomous promotion candidates ($OPEN_ITEMS items remain blocked or documented). Skipping LLM agent cascade. ==="
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

    cd "${user.home}"

    # --- STEP 1: Deterministic Health & Self-Repair (0 API tokens consumed) ---
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

    # Check sentinel closed loop
    SENTINEL_HEALTH="/var/lib/fleet-sentinel/www/health.txt"
    SENTINEL_DEGRADED=0
    if [ -f "$SENTINEL_HEALTH" ]; then
      if [ "$(cat "$SENTINEL_HEALTH")" != "ok" ]; then
        SENTINEL_DEGRADED=1
      fi
    fi

    # Core delphi service probes
    DNS_FAILED=0
    if ! ${pkgs.dnsutils}/bin/dig @10.99.0.53 +short +time=2 example.com >/dev/null 2>&1; then
      DNS_FAILED=1
    fi

    NGINX_FAILED=0
    if ! ${pkgs.curl}/bin/curl -s -m 3 http://127.0.0.1/healthz >/dev/null 2>&1; then
      NGINX_FAILED=1
    fi

    DSH_FAILED=0
    if ! ${pkgs.curl}/bin/curl -sI -m 3 http://127.0.0.1:3080/ >/dev/null 2>&1; then
      DSH_FAILED=1
    fi

    SYSTEMONE_FAILED=0
    if ! ${pkgs.curl}/bin/curl -sI -m 3 http://127.0.0.1:8091/ >/dev/null 2>&1; then
      SYSTEMONE_FAILED=1
    fi

    MICROVM_FAILED=0
    if ! systemctl is-active microvm@sandbox.service >/dev/null 2>&1; then
      MICROVM_FAILED=1
    fi

    UPGRADE_FAILED=0
    if systemctl is-failed nixos-upgrade.service >/dev/null 2>&1; then
      UPGRADE_FAILED=1
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
    elif [ "$SENTINEL_DEGRADED" -gt 0 ]; then
      SHOULD_RUN_CASCADE=1
      RUN_REASON="Fleet sentinel observation state is degraded"
    elif [ "$DNS_FAILED" -gt 0 ]; then
      SHOULD_RUN_CASCADE=1
      RUN_REASON="Crab-hole DNS resolver probe failure on 10.99.0.53:53"
    elif [ "$NGINX_FAILED" -gt 0 ]; then
      SHOULD_RUN_CASCADE=1
      RUN_REASON="Nginx local healthz probe failure on port 80"
    elif [ "$DSH_FAILED" -gt 0 ]; then
      SHOULD_RUN_CASCADE=1
      RUN_REASON="DeepSeek Harness probe failure on 127.0.0.1:3080"
    elif [ "$SYSTEMONE_FAILED" -gt 0 ]; then
      SHOULD_RUN_CASCADE=1
      RUN_REASON="System One decision serve probe failure on 127.0.0.1:8091"
    elif [ "$MICROVM_FAILED" -gt 0 ]; then
      SHOULD_RUN_CASCADE=1
      RUN_REASON="MicroVM sandbox service is not active"
    elif [ "$UPGRADE_FAILED" -gt 0 ]; then
      SHOULD_RUN_CASCADE=1
      RUN_REASON="NixOS autoUpgrade failure detected"
    fi

    if [ "$SHOULD_RUN_CASCADE" -eq 0 ]; then
      echo "=== [$(date)] Quiet Reflex Gate: System is 100% nominal (0 failed units, all services healthy). Preserving AI tokens. ==="
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
    ../../modules/services/fleet-sentinel.nix
    ../../modules/services/agent-scheduler.nix
  ];

  # --- Closed-loop observation ledger & health endpoint ----------------------
  # Collects system health, unit states, disk and PSI pressure every 15 minutes.
  # Powers `task ops:health` and serves /var/lib/fleet-sentinel/www/status.json.
  services.fleetSentinel = {
    enable = true;
    watchUnits = [
      {unit = "nixos-upgrade.service";}
      {unit = "microvm@sandbox.service";}
      {unit = "dsh-web.service";}
      {unit = "crab-hole.service";}
      {unit = "systemone-decision-serve.service";}
      {unit = "nginx.service";}
      {unit = "tailscaled.service";}
    ];
  };

  # --- Declarative Autonomous Agent Scheduler (EXP-016) -----------------------
  # Coordinates system maintenance and strategic handoffs with CPU/IO regulation.
  # Runs after autoUpgrade (04:30) and staggered from frieren's 03:00/05:00 runs.
  services.agentScheduler = {
    enable = true;
    jobs = {
      agy-nightly-handoff = {
        name = "agy-nightly-handoff";
        description = "Action-gated handoff runner (runs only on autonomous promotion candidates or manual trigger)";
        schedule = "*-*-* 03:30:00";
        command = agyHandoffRunner;
        workingDirectory = "${user.home}";
        nice = 5;
        cpuWeight = 300;
        ioWeight = 300;
      };
      agy-nightly-system = {
        name = "agy-nightly-system";
        description = "Trigger-gated system health audit (Mon-Sat quiet reflex, Sunday comprehensive scorecard)";
        schedule = "*-*-* 05:30:00";
        command = agySystemRunner;
        workingDirectory = "${user.home}";
        nice = 5;
        cpuWeight = 300;
        ioWeight = 300;
      };
    };
  };

  # --- Refined CGroup & Resource Controls (2 OCPU / 11 GiB RAM Cloud Bastion) -
  # Protects interactive sshd, Nginx and crab-hole DNS from being starved by
  # guest workloads or batch harness compilations.
  systemd.services."microvm@sandbox".serviceConfig = {
    CPUWeight = 100;
    IOWeight = 100;
    MemoryHigh = "3500M";
    MemoryMax = "4000M";
  };

  systemd.services.dsh-web.serviceConfig = {
    CPUWeight = 200;
    IOWeight = 200;
    MemoryHigh = "1200M";
    MemoryMax = "1500M";
  };

  systemd.services.crab-hole.serviceConfig = {
    Restart = lib.mkForce "always";
    RestartSec = lib.mkForce 2;
    CPUWeight = 1000; # Maximum scheduling priority for zero-jitter DNS lookups
  };
}
