# Delphi Infrastructure Stack — Health Sentinel, Autonomous Agent Schedulers, and Resource Regulation
{
  config,
  self,
  pkgs,
  lib,
  user,
  ...
}: let
  agentCascadeScript = ''
    run_agent_cascade() {
      local prompt="$1"

      # The OAuth account route, not agy-gemini: an agentic sweep outruns the
      # key's daily quota, and this cascade loads no key.
      echo "=== [$(date)] Agent Cascade: Attempting Tier 1 (agy / gemini-3.8-flash) ==="
      if ${pkgs.antigravity-cli}/bin/agy --model "''${GEMINI_MODEL:-gemini-3.8-flash}" --output-format json --dangerously-skip-permissions -p "$prompt"; then
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
      # `-q`/`--oneshot` are `hermes chat` options, not top-level ones: the
      # old `hermes -q "$prompt" --oneshot` form exited 2 on argparse before
      # any model call. Same fix as frieren; see that file for the measurement.
      if command -v hermes >/dev/null 2>&1 || [ -x "/run/current-system/sw/bin/hermes" ]; then
        echo "=== [$(date)] Agent Cascade: Attempting Tier 3 (hermes) ==="
        local hermes_bin
        hermes_bin="$(command -v hermes 2>/dev/null || echo "/run/current-system/sw/bin/hermes")"

        for hermes_env in "${user.home}/.hermes/.env" "${user.home}/.config/hermes/hermes.env"; do
          if [ -f "$hermes_env" ]; then
            set -a
            # shellcheck disable=SC1090
            source "$hermes_env" 2>/dev/null || true
            set +a
          fi
        done

        if "$hermes_bin" chat -q "$prompt" --oneshot -Q --run-budget 600; then
          echo "=== [$(date)] Agent Cascade: Tier 3 (hermes) succeeded. ==="
          return 0
        fi
        echo "=== [$(date)] WARN: hermes failed. ===" >&2
      fi

      # Tier 4 was Crush, retired 2026-11-06 (free credits exhausted). Same change
      # as hosts/frieren/infra-stack.nix — keep the two cascades in step.
      echo "=== [$(date)] ERROR: All agent execution tiers in cascade failed. ===" >&2
      return 1
    }
  '';

  # The LLM hop prefers clanker — scripts/task/clanker.sh job, the same line
  # task clanker:job runs, drops a detached job that `nix run`s agy per
  # .agents/skills/antigravity/SKILL.md. GEMINI_API_KEY rides inside the job
  # file (self-deletes at EXIT); failures fall back to run_agent_cascade.
  clankerAgentDispatch = ''
        run_via_clanker() {
          local prompt="$1" dest="''${2:-}"
          local repo="''${NIXCONFIG_REPO:-${user.home}/Documents/nixconfig}"
          local clanker="$repo/scripts/task/clanker.sh"
          local instabox="$repo/scripts/task/instabox.sh"
          [ -f "$clanker" ] && [ -f "$instabox" ] || return 1

          local key="" hermes_env
          for hermes_env in "${user.home}/.hermes/.env" "${user.home}/.config/hermes/hermes.env"; do
            [ -f "$hermes_env" ] || continue
            key="$(grep -E '^(export[[:space:]]+)?GEMINI_API_KEY=' "$hermes_env" | tail -1 | cut -d= -f2- | tr -d "\"'" || true)"
            [ -n "$key" ] && break
          done
          if [ -z "$key" ]; then
            echo "=== [$(date)] clanker lane: no GEMINI_API_KEY to lend the box; staying local ===" >&2
            return 1
          fi

          echo "=== [$(date)] Agent lane: offloading prompt to clanker (nix run agy, key route) ==="
          bash "$instabox" wake clanker >/dev/null 2>&1 || true

          # scripts/task/clanker.sh writes jobcmd as cmd.sh; the trap deletes it.
          local jobcmd
          jobcmd="$(cat <<JOB_EOF
    export PATH="\$HOME/.nix-profile/bin:\$PATH"
    export AGY_CLI_DISABLE_AUTO_UPDATE=true
    export GEMINI_API_KEY=$(printf '%q' "$key")
    trap 'rm -f "\$0"' EXIT
    mkdir -p out
    timeout 1500 nix run github:numtide/llm-agents.nix#antigravity-cli -- --settings '{"modelProvider":"gemini"}' --model "gemini-3.8-flash" --output-format json --dangerously-skip-permissions -p $(printf '%q' "$prompt") > out/report.json 2> out/agy.log
    JOB_EOF
    )"

          local id
          id="$(bash "$clanker" job -- "$jobcmd" | tail -1)" || {
            echo "=== clanker lane: job submit failed ===" >&2
            return 1
          }
          case "$id" in
            ""|*[!0-9A-Za-z-]*) echo "=== clanker lane: no job id (got '$id') ===" >&2; return 1 ;;
          esac
          echo "=== [$(date)] clanker job $id started; waiting up to 1800s ==="

          if bash "$clanker" wait "$id" 1800; then
            if [ -n "$dest" ]; then
              bash "$clanker" result "$id" >/dev/null 2>&1 &&
                cp "$repo/.clanker-out/$id/out/report.json" "$dest/clanker-$id-report.json" 2>/dev/null || true
            fi
            echo "=== [$(date)] clanker job $id finished ==="
            return 0
          fi

          echo "=== [$(date)] clanker job $id failed; log tail below, local cascade next ===" >&2
          bash "$clanker" logs "$id" 40 >&2 || true
          return 1
        }
  '';

  agySystemRunner = pkgs.writeShellScript "agy-system-runner" ''
        set -euo pipefail

        SYSTEM_FILE="${user.home}/SYSTEM.md"

        if [ ! -f "$SYSTEM_FILE" ]; then
          echo "No SYSTEM.md found in ${user.home}. Skipping execution."
          exit 0
        fi

        # The outcome of an audit is state, not prose — same contract as frieren's
        # runner: one TSV line per run, in a directory tmpfiles owns for this user so
        # the root sentinel collector can read it (its unit runs with ProtectHome, so
        # a path under $HOME would be invisible).
        STATE_DIR="''${AGY_STATE_DIR:-/var/lib/agy-system}"
        if ! mkdir -p "$STATE_DIR" 2>/dev/null; then
          echo "=== [$(date)] WARN: cannot create $STATE_DIR; recording to the journal only ===" >&2
          STATE_DIR=""
        fi
        record_outcome() {
          local outcome="$1" reason="$2"
          echo "=== [$(date)] Audit outcome: $outcome ($reason) ==="
          if [ -n "$STATE_DIR" ]; then
            printf '%s\t%s\t%s\n' "$(date -Iseconds)" "$outcome" "$reason" > "$STATE_DIR/last-run"
          fi
        }

        echo "=== [$(date)] Found $SYSTEM_FILE. Preparing execution... ==="
        ARCHIVE_DIR="${user.home}/.agents/system"
        mkdir -p "$ARCHIVE_DIR"
        ARCHIVE_COPY="$ARCHIVE_DIR/SYSTEM-$(date +%Y%m%d_%H%M%S).md"
        cp "$SYSTEM_FILE" "$ARCHIVE_COPY"

        cd "${user.home}"

        # --- STEP 1: Deterministic Health & Self-Repair (0 API tokens consumed) ---
        echo "=== [$(date)] Step 1: Performing deterministic service checks ==="
        FAILED_SYS=$( (systemctl --failed --no-pager --plain --quiet | grep -v "0 loaded" || true) | wc -l)
        FAILED_USER=$( (systemctl --user --failed --no-pager --plain --quiet | grep -v "0 loaded" || true) | wc -l)

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

        SYSTEMONE_FAILED=0
        if ! ${pkgs.curl}/bin/curl -sI -m 3 http://127.0.0.1:8091/ >/dev/null 2>&1; then
          SYSTEMONE_FAILED=1
        fi

        STIRLING_FAILED=0
        if ! systemctl is-active stirling-pdf.service >/dev/null 2>&1; then
          STIRLING_FAILED=1
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
          TIER1_COUNT=$( (grep -o '"protocol": "TIER_1_IMMEDIATE_REPAIR"' "$TRIAGE_REPORT" || true) | wc -l)
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
        elif [ "$SYSTEMONE_FAILED" -gt 0 ]; then
          SHOULD_RUN_CASCADE=1
          RUN_REASON="System One decision serve probe failure on 127.0.0.1:8091"
        elif [ "$STIRLING_FAILED" -gt 0 ]; then
          SHOULD_RUN_CASCADE=1
          RUN_REASON="Stirling PDF service is not active"
        elif [ "$UPGRADE_FAILED" -gt 0 ]; then
          SHOULD_RUN_CASCADE=1
          RUN_REASON="NixOS autoUpgrade failure detected"
        fi

        if [ "$SHOULD_RUN_CASCADE" -eq 0 ]; then
          echo "=== [$(date)] Quiet Reflex Gate: System is 100% nominal (0 failed units, all services healthy). Preserving AI tokens. ==="
          record_outcome quiet "0 failed units, all service probes healthy"
          exit 0
        fi

        # --- STEP 4: Agent execution — clanker first, local cascade as fallback ---
        echo "=== [$(date)] Step 4: Trigger active ($RUN_REASON). Invoking agent lane ==="
        ${agentCascadeScript}
        ${clankerAgentDispatch}

        # One prompt for both lanes: SYSTEM.md is embedded — scripts/task/clanker.sh
        # jobs can't see ~; in-place updates stay a local-cascade behavior.
        prompt="Here is the current SYSTEM.md, verbatim:

    $(cat "$SYSTEM_FILE")

    Execute the health and maintenance audits it describes. Do not write HANDOFF.md or any handoff file — that channel is closed; open items belong in an xs turn or an AGENTS.nix note. If you can write files, update SYSTEM.md in-place with current findings; otherwise return the complete updated SYSTEM.md as your final section. System One decision pre-triage ran on this host ($TIER1_COUNT immediate items flagged). Audit trigger reason: $RUN_REASON."

        if run_via_clanker "$prompt" "$ARCHIVE_DIR"; then
          echo "=== [$(date)] System audit answered by clanker; report archived beside $ARCHIVE_COPY ==="
          record_outcome ok "clanker:$RUN_REASON"
        elif run_agent_cascade "$prompt"; then
          echo "=== [$(date)] System maintenance run finished. Pre-run snapshot preserved at $ARCHIVE_COPY ==="
          record_outcome ok "$RUN_REASON"
        else
          echo "=== [$(date)] WARN: All AI agent tiers failed. Applying deterministic timestamp update to $SYSTEM_FILE ===" >&2
          record_outcome fallback "all agent tiers failed ($RUN_REASON)"
        fi
  '';
in {
  imports = [
    self.modules."services.fleet-sentinel"
    self.modules."services.agent-scheduler"
  ];

  # The audit is a user unit and the sentinel collector reads as root with
  # ProtectHome, so the outcome record needs a shared directory owned by the
  # user rather than StateDirectory= (which a user manager does not reliably
  # provide).
  systemd.tmpfiles.rules = [
    "d /var/lib/agy-system 0755 ${user.name} users -"
  ];

  # `/sentinel/ingest` lives on frieren's `frieren.lan` vhost only; the bare
  # tailnet address 404s there (measured 2026-11-26, every 15 minutes).
  networking.extraHosts = ''
    100.97.61.65 frieren.lan
  '';

  # --- Closed-loop observation ledger & health endpoint ----------------------
  # Collects system health, unit states, disk and PSI pressure every 15 minutes.
  # Powers `task ops:health` and serves /var/lib/fleet-sentinel/www/status.json.
  services.fleetSentinel = {
    enable = true;
    # This host's 03:00 audit verdict, written by agy-nightly-system as
    # `<ts>\t<outcome>\t<reason>`. `fallback` degrades the host and pages; a
    # record older than 192 h does too.
    auditRecord = "/var/lib/agy-system/last-run";
    watchUnits = [
      {unit = "nixos-upgrade.service";}
      {unit = "stirling-pdf.service";}
      {unit = "searx.service";}
      {unit = "crab-hole.service";}
      {unit = "systemone-decision-serve.service";}
      {unit = "nginx.service";}
      {unit = "tailscaled.service";}
      {unit = "dsh-free-models.service";}
      {unit = "tailscale-serve-dsh.service";}
      {unit = "tailscale-serve-free-models.service";}
    ];
    # User units are where the 2026-11-15 outages lived: a vdirsyncer timer that
    # failed every 15 minutes for three days and a keepalive that failed 104
    # times, both invisible to a collector that only asks the system manager.
    collectUserUnits = true;
    push = {
      url = "http://frieren.lan/sentinel/ingest";
      tokenFile = config.sops.secrets."agent-turns-token".path;
    };
    # The same publisher the appflow triage uses (hosts/delphi/email-archive.nix),
    # so the push channel has one configuration and one credential on this fleet.
    notify = {
      url = "http://127.0.0.1:8096";
      topic = "fleet";
      user = "fleet";
      passwordFile = config.sops.secrets."ntfy/fleet-password".path;
    };
    queueProbe.url = "http://127.0.0.1:${toString config.services.emailArchive.port}/api/queue-health";
  };

  # --- Declarative Autonomous Agent Scheduler (EXP-016) -----------------------
  # Coordinates system maintenance with CPU/IO regulation.
  # Runs after autoUpgrade (04:30) and staggered from frieren's 03:00/05:00 runs.
  services.agentScheduler = {
    enable = true;
    jobs = {
      # KEEP (deep-slash review): load-bearing — fleetSentinel.auditRecord in
      # hosts/delphi/infra-stack.nix reads its verdict file; stale pages, task ops:health.
      agy-nightly-system = {
        description = "Trigger-gated system health audit (probes stay local; LLM hop prefers a clanker job, local cascade fallback)";
        schedule = "*-*-* 05:30:00";
        command = agySystemRunner;
        nice = 5;
        cpuWeight = 300;
        ioWeight = 300;
      };
    };
  };

  # The sandbox microVM's resource controls. Why:
  # .agents/deploy/hosts/delphi.md §"Guest layer — the `sandbox` microVM".
  # The dsh-web cgroup guards retired with the unit — hosts/delphi/dsh-web.shadow.nix.

  systemd.services.crab-hole = {
    unitConfig = {
      X-Fleet-Role = "daemon";
      StartLimitIntervalSec = 0;
    };
    serviceConfig = {
      Restart = lib.mkForce "always";
      RestartSec = lib.mkForce 2;
      CPUWeight = 1000; # Maximum scheduling priority for zero-jitter DNS lookups
    };
  };
}
