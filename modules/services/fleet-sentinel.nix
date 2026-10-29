# fleet-sentinel — the closed loop for "did the config actually work?".
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.fleetSentinel;

  watchedUnits = map (u: u.unit) cfg.watchUnits;

  # Space-delimited for the shell loop below; empty is harmless (`case " " in`).
  IGNORE = lib.concatStringsSep " " cfg.ignoreFailedUnits;

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
      # Assigned rather than used inline: a `case` on a literal word trips
      # SC2194, and writeShellApplication fails the build on any finding.
      IGNORE_UNITS="${IGNORE}"

      # --- failed units ------------------------------------------------------
      while IFS= read -r line; do
        [ -n "$line" ] || continue
        # Column 1, not 2: `--plain --no-legend` prints `UNIT LOAD ACTIVE SUB
        # DESCRIPTION`, so $2 is the literal word `loaded` — which meant the
        # `ignoreFailedUnits` list could never match and the ledger reported a
        # unit named "loaded" (found 2026-10-29 via the BurgerNAS mount).
        unit="$(printf '%s' "$line" | awk '{print $1}')"
        # The collector itself is allowed to be the only failed thing while it
        # is still starting; do not let a self-transition flap the loop.
        [ "$unit" = "fleet-sentinel.service" ] && continue
        # A unit that fails BY DESIGN is not a degradation. The BurgerNAS cold
        # vault is powered on demand, so its automount timing out while the NAS
        # sleeps says nothing about this host; counting it marked frieren
        # degraded and paged on a monitor that was only reporting a dependency we
        # had deliberately left off.
        case " $IGNORE_UNITS " in
          *" $unit "*) continue ;;
        esac
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

      # --- last scheduled job that measures itself ---------------------------
      # The Steam prefill writes one JSON object per run with the cache bytes it
      # grew and the bytes it pulled from Valve. It is not copied into this
      # ledger: at a 15-minute cadence the fill's numbers would be interleaved
      # with 95 identical readings of them. Newest run is projected instead.
      PREFILL_JSON="null"
      ${lib.optionalString (cfg.prefillRuns != null) ''
        if [ -r "${cfg.prefillRuns}" ]; then
          last="$(tail -n 1 "${cfg.prefillRuns}" 2>/dev/null || true)"
          # A half-written tail must not take the whole event down with it.
          if [ -n "$last" ] && printf '%s' "$last" | jq -e . >/dev/null 2>&1; then
            PREFILL_JSON="$last"
          fi
        fi
      ''}

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
        --argjson prefill "$PREFILL_JSON" \
        '{schema: 1, ts: $ts, host: $host, state: $state, reasons: $reasons,
          failed_units: $failed_units, jobs: $jobs, generation_age_h: $gen_age_h,
          disk_pct: $disk, psi: {io: $io_psi, memory: $mem_psi},
          prefill: $prefill}')"

      printf '%s\n' "$EVENT" >> "$LEDGER"
      # Bounded history: ~100 days at the 15-minute default, enough to correlate
      # with a weekly audit without letting a timer fill the root filesystem.
      tail -n ${toString cfg.ledgerMaxLines} "$LEDGER" > "$LEDGER.tmp" && mv "$LEDGER.tmp" "$LEDGER"

      printf '%s\n' "$EVENT" | jq . > "$STATUS"
      printf '%s\n' "$HEALTH_TEXT" > "$HEALTH"

      # --- dashboard (static; reads status.json client-side) -----------------
      # The markup is a file (modules/services/fleet-sentinel-dashboard.html):
      # HTML/CSS/JS is content, not configuration, and in a Nix string every JS
      # template hole had to be double-escaped — a trap for the next editor.
      install -Dm644 ${./fleet-sentinel-dashboard.html} "$WWW/index.html"
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

    ignoreFailedUnits = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      example = ["mnt-burgernas-peachcable.mount"];
      description = ''
        Units whose failed state is expected — a dependency that is off by design,
        not a fault — and must not degrade the sentinel.
      '';
    };

    degradeOnDiskPct = lib.mkOption {
      type = lib.types.ints.between 50 99;
      default = 90;
      description = "Degrade when any watched filesystem is at or above this percentage.";
    };

    prefillRuns = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = ''
        JSONL file a self-measuring job appends to, one object per run; the
        newest object is projected into `status.json` as `prefill`. Null means
        no such job on this host. Point it at
        {option}`services.steamCache.prefill.ledger` on a host that prefills.
      '';
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
