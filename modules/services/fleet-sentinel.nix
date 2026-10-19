# fleet-sentinel — the closed loop for "did the config actually work?".
#
# The fleet has plenty of *probes* (gatus endpoints, checks:*, port audits) but
# no **record** and no **transition detector**. A failed 03:30 restic run, a
# 04:00 autoUpgrade that produced no new generation, or a unit that has been
# failed since Tuesday all look the same from the outside: the UI is green
# because nothing watches the job, only the socket.
#
# This module is deliberately small and boring:
#
#   timer (15 min) -> collect -> status.json + health.txt + ledger.jsonl
#                                -> nginx serves /sentinel/
#                                -> gatus watches health.txt body == "ok"
#                                -> the SimpleX bridge alerts on 3 failures
#
# `ledger.jsonl` is append-only, one uniform JSON object per run, which is
# exactly the shape `master-toon` compresses for agents (`task ops:ledger:toon`).
# It is the *episodic* store: AUDIT.md says what changed, the ledger says what
# was observed, journald says why.
#
# It performs no builds, opens no port, and runs as a oneshot: a failed
# collector must never take the NAS down with it.
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.fleetSentinel;

  watchedUnits = map (u: u.unit) cfg.watchUnits;

  collect = pkgs.writeShellApplication {
    name = "fleet-sentinel-collect";
    runtimeInputs = with pkgs; [coreutils gnugrep gawk jq systemd findutils];
    text = ''
      set -uo pipefail

      ROOT="${cfg.stateDir}"
      WWW="$ROOT/www"
      LEDGER="$ROOT/ledger.jsonl"
      # Both live in www/ so nginx's single `/sentinel/` alias serves the
      # dashboard, the JSON body gatus asserts on, and the machine gate.
      STATUS="$WWW/status.json"
      HEALTH="$WWW/health.txt"

      mkdir -p "$WWW"
      chmod 0755 "$ROOT" "$WWW"

      # `hostname` is not in coreutils (it is inetutils/net-tools); /etc/hostname
      # is always present on NixOS and needs no extra runtime input.
      HOST="$(cat /etc/hostname)"
      HOST="''${HOST%%.*}"
      NOW="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
      REASONS=()
      FAILED_UNITS=()

      # --- failed units ------------------------------------------------------
      while IFS= read -r line; do
        [ -n "$line" ] || continue
        unit="$(printf '%s' "$line" | awk '{print $2}')"
        # The collector itself is allowed to be the only failed thing while it
        # is still starting; do not let a self-transition flap the loop.
        [ "$unit" = "fleet-sentinel.service" ] && continue
        FAILED_UNITS+=("$unit")
      done < <(systemctl list-units --state=failed --no-legend --plain --no-pager 2>/dev/null || true)

      if [ "''${#FAILED_UNITS[@]}" -gt 0 ]; then
        REASONS+=("failed-units:''${#FAILED_UNITS[@]}")
      fi

      # --- oneshot job results ----------------------------------------------
      unit_result() {
        local u="$1"
        if ! systemctl cat "$u" >/dev/null 2>&1; then
          printf 'absent'
          return
        fi
        systemctl show -p Result --value "$u" 2>/dev/null || printf 'unknown'
      }

      # A unit that has never run reports "success" with no timestamp; treat
      # absent/unknown as neutral rather than degraded (fresh installs exist).
      WATCH_JSON="{}"
      # `-` is a no-op sentinel so an empty watchUnits list cannot emit the
      # invalid shell `for u in ; do`.
      for u in ${lib.escapeShellArgs (watchedUnits ++ ["-"])}; do
        [ "$u" = "-" ] && continue
        r="$(unit_result "$u")"
        case "$r" in
          success|absent|unknown) ;;
          *) REASONS+=("unit-failed:$u:$r") ;;
        esac
        WATCH_JSON="$(printf '%s' "$WATCH_JSON" | jq -c --arg k "$u" --arg v "$r" '. + {($k): $v}')"
      done

      # --- generation age ----------------------------------------------------
      GEN_EPOCH=0
      if [ -L /nix/var/nix/profiles/system ]; then
        # The SYMLINK's mtime is the switch time. `stat -L` follows into the
        # store closure, whose mtime is the build time (years old on a reused
        # path) — that reported a 497 879 h "stale" generation on 2026-10-19.
        GEN_EPOCH="$(stat -c %Y /nix/var/nix/profiles/system 2>/dev/null || echo 0)"
      fi
      GEN_AGE_H=0
      if [ "$GEN_EPOCH" -gt 0 ]; then
        GEN_AGE_H="$(awk -v now="$(date +%s)" -v then="$GEN_EPOCH" 'BEGIN { printf "%.1f", (now - then) / 3600 }')"
      fi
      if awk -v age="$GEN_AGE_H" -v max="${toString cfg.generationMaxAgeHours}" 'BEGIN { exit !(age > max) }'; then
        REASONS+=("generation-stale:''${GEN_AGE_H}h")
      fi

      # --- disk + inodes -----------------------------------------------------
      disk_pct() {
        local p="$1"
        if [ -e "$p" ]; then
          df -P "$p" 2>/dev/null | awk 'NR==2 { gsub("%", "", $5); print $5 }'
        else
          printf 'null'
        fi
      }
      DISK_JSON="$(jq -n \
        --argjson root "$(disk_pct /)" \
        --argjson nix "$(disk_pct /nix/store)" \
        --argjson data "$(disk_pct /srv/data)" \
        '{root: $root, nix: $nix, data: $data}')"

      for p in / /nix/store /srv/data; do
        v="$(disk_pct "$p")"
        [ "$v" = "null" ] && continue
        if [ "$v" -ge "${toString cfg.degradeOnDiskPct}" ]; then
          REASONS+=("disk-high:$p:$v%")
        fi
      done

      # --- pressure (the metric that actually predicts a wedged NAS) ---------
      psi() {
        local f="/proc/pressure/$1"
        if [ -r "$f" ]; then
          awk '{ for (i=1; i<=NF; i++) if ($i ~ /^avg10=/) { sub("avg10=", "", $i); print $i } }' "$f" | head -1
        else
          printf '0.00'
        fi
      }
      IO_PSI="$(psi io)"
      MEM_PSI="$(psi memory)"
      # Kernels without CONFIG_PSI have no /proc/pressure entry; a missing
      # metric must be 0.00, not an empty --argjson that kills the event.
      [ -n "$IO_PSI" ] || IO_PSI="0.00"
      [ -n "$MEM_PSI" ] || MEM_PSI="0.00"

      # --- assemble ----------------------------------------------------------
      if [ "''${#REASONS[@]}" -eq 0 ]; then
        STATE="ok"
        HEALTH_TEXT="ok"
      else
        STATE="degraded"
        HEALTH_TEXT="degraded"
      fi

      REASONS_JSON="$(printf '%s\n' "''${REASONS[@]:-}" | jq -R . | jq -s 'map(select(length > 0))')"
      FAILED_JSON="$(printf '%s\n' "''${FAILED_UNITS[@]:-}" | jq -R . | jq -s 'map(select(length > 0))')"

      EVENT="$(jq -cn \
        --arg ts "$NOW" \
        --arg host "$HOST" \
        --arg state "$STATE" \
        --argjson reasons "$REASONS_JSON" \
        --argjson failed_units "$FAILED_JSON" \
        --argjson jobs "$WATCH_JSON" \
        --argjson gen_age_h "$GEN_AGE_H" \
        --argjson disk "$DISK_JSON" \
        --argjson io_psi "$IO_PSI" \
        --argjson mem_psi "$MEM_PSI" \
        '{schema: 1, ts: $ts, host: $host, state: $state, reasons: $reasons,
          failed_units: $failed_units, jobs: $jobs, generation_age_h: $gen_age_h,
          disk_pct: $disk, psi: {io: $io_psi, memory: $mem_psi}}')"

      printf '%s\n' "$EVENT" >> "$LEDGER"
      # Bounded history: ~100 days at the 15-minute default, enough to correlate
      # with a weekly audit without letting a timer fill the root filesystem.
      tail -n ${toString cfg.ledgerMaxLines} "$LEDGER" > "$LEDGER.tmp" && mv "$LEDGER.tmp" "$LEDGER"

      printf '%s\n' "$EVENT" | jq . > "$STATUS"
      printf '%s\n' "$HEALTH_TEXT" > "$HEALTH"

      # --- dashboard (static; reads status.json client-side) -----------------
      cat > "$WWW/index.html" <<'HTML'
      <!doctype html>
      <html lang="en">
      <head>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width,initial-scale=1">
      <title>fleet sentinel</title>
      <style>
        :root { color-scheme: dark; --bg:#11111b; --panel:#1e1e2e; --text:#cdd6f4; --muted:#6c7086;
                --ok:#a6e3a1; --bad:#f38ba8; --accent:#89b4fa; }
        * { box-sizing: border-box; }
        body { margin:0; padding:2rem; background:var(--bg); color:var(--text);
               font:15px/1.5 ui-sans-serif,system-ui,-apple-system,"Segoe UI",sans-serif; }
        h1 { font-size:1.1rem; letter-spacing:.08em; text-transform:uppercase; color:var(--muted); }
        .grid { display:grid; gap:1rem; grid-template-columns:repeat(auto-fit,minmax(14rem,1fr)); max-width:72rem; }
        .card { background:var(--panel); border-radius:1rem; padding:1rem 1.25rem;
                box-shadow:0 0.5rem 1.5rem rgba(0,0,0,.35); }
        .state { font-size:2rem; font-weight:600; }
        .ok { color:var(--ok); } .bad { color:var(--bad); }
        .k { color:var(--muted); font-size:.75rem; letter-spacing:.06em; text-transform:uppercase; }
        .v { font-size:1.25rem; margin-top:.2rem; }
        code { color:var(--accent); }
        ul { margin:.4rem 0 0; padding-left:1.1rem; } li { color:var(--bad); }
        a { color:var(--accent); }
        footer { margin-top:1.5rem; color:var(--muted); font-size:.8rem; }
      </style>
      </head>
      <body>
      <h1>fleet sentinel · frieren</h1>
      <div class="grid" id="grid"><div class="card"><div class="k">state</div><div class="state">loading…</div></div></div>
      <footer>ledger: <code>task ops:ledger</code> · toon: <code>task ops:ledger:toon</code> ·
        raw: <a href="status.json">status.json</a></footer>
      <script>
      fetch('status.json', {cache:'no-store'}).then(r => r.json()).then(s => {
        const cls = s.state === 'ok' ? 'ok' : 'bad';
        const disk = Object.entries(s.disk_pct || {})
          .filter(([,v]) => v !== null).map(([k,v]) => `<div class="v">''${k}: ''${v}%</div>`).join("");
        const jobs = Object.entries(s.jobs || {})
          .map(([k,v]) => `<div class="v">''${v}</div><div class="k">''${k}</div>`).join("");
        const reasons = (s.reasons || []).map(r => `<li>''${r}</li>`).join("") || '<li class="ok">none</li>';
        document.getElementById('grid').innerHTML = `
          <div class="card"><div class="k">state</div><div class="state ''${cls}">''${s.state}</div>
            <div class="k">''${s.ts}</div></div>
          <div class="card"><div class="k">reasons</div><ul>''${reasons}</ul></div>
          <div class="card"><div class="k">generation age</div><div class="v">''${s.generation_age_h} h</div>
            <div class="k">io psi ''${s.psi.io} · mem psi ''${s.psi.memory}</div></div>
          <div class="card"><div class="k">disk</div>''${disk}</div>
          <div class="card"><div class="k">job results</div>''${jobs}</div>`;
      }).catch(e => {
        document.getElementById('grid').innerHTML =
          `<div class="card"><div class="k">state</div><div class="state bad">unreachable</div></div>`;
      });
      </script>
      </body>
      </html>
      HTML
    '';
  };
in {
  options.services.fleetSentinel = {
    enable = lib.mkEnableOption "append-only fleet observation ledger and health endpoint";

    stateDir = lib.mkOption {
      type = lib.types.path;
      default = "/var/lib/fleet-sentinel";
      description = "Ledger, status and static dashboard directory.";
    };

    interval = lib.mkOption {
      type = lib.types.str;
      default = "15min";
      description = "Collection interval (systemd time span).";
    };

    ledgerMaxLines = lib.mkOption {
      type = lib.types.ints.positive;
      default = 10000;
      description = "Rotate the JSONL ledger to this many lines.";
    };

    generationMaxAgeHours = lib.mkOption {
      type = lib.types.float;
      default = 72.0;
      description = ''
        Degrade when the running system generation is older than this. 72 h is
        three missed 04:00 autoUpgrade windows on frieren — late enough not to
        fire on a quiet weekend, early enough to catch a broken update path.
      '';
    };

    degradeOnDiskPct = lib.mkOption {
      type = lib.types.ints.between 50 99;
      default = 90;
      description = "Degrade when any watched filesystem is at or above this percentage.";
    };

    watchUnits = lib.mkOption {
      type = lib.types.listOf (lib.types.submodule {
        options = {
          unit = lib.mkOption {
            type = lib.types.str;
            description = "Oneshot/timer service whose `Result` property is recorded.";
          };
          reason = lib.mkOption {
            type = lib.types.str;
            default = "";
            description = "Why this unit is watched (documentation only).";
          };
        };
      });
      default = [];
      description = ''
        Jobs whose last result should degrade the sentinel when not `success`.
        The default set on frieren is the backup/upgrade chain; a host without
        those units records `absent` and stays neutral.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.tmpfiles.rules = [
      "d ${cfg.stateDir} 0755 root root -"
      "d ${cfg.stateDir}/www 0755 root root -"
    ];

    systemd.services.fleet-sentinel = {
      description = "Fleet sentinel: collect observation ledger + health";
      wants = ["network-online.target"];
      after = ["network-online.target"];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${collect}/bin/fleet-sentinel-collect";
        TimeoutStartSec = 120;
        Nice = 10;
        IOSchedulingClass = "idle";
        # Read-only view of the system; the only write is its own state dir.
        ProtectSystem = "strict";
        ProtectHome = true;
        ReadWritePaths = [cfg.stateDir];
        PrivateTmp = true;
        NoNewPrivileges = true;
      };
    };

    systemd.timers.fleet-sentinel = {
      description = "Collect fleet sentinel observations";
      wantedBy = ["timers.target"];
      timerConfig = {
        OnBootSec = "3min";
        OnUnitActiveSec = cfg.interval;
        Persistent = true;
        RandomizedDelaySec = "45s";
      };
    };
  };
}
