# Declarative SSH Bastion & Inactive Session Reaper (EXP-046).
#
# Periodically sweeps active user sessions, detects abandoned scopes and lingering
# remote SSH terminal sessions idle beyond maxIdleHours, rigorously preserves
# multiplexers (tmux, screen, agy), and terminates stale sessions via loginctl.
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.fleetSessionReaper;

  reaperScript = pkgs.writeShellScriptBin "fleet-session-reaper" ''
        set -euo pipefail

        export PATH="${lib.makeBinPath [pkgs.coreutils pkgs.systemd pkgs.procps pkgs.findutils pkgs.python3]}:$PATH"

        ${pkgs.python3}/bin/python3 - <<'EOF'
    import subprocess, os, sys, datetime

    max_idle_hours = ${toString cfg.maxIdleHours}
    max_idle_sec = max_idle_hours * 3600
    ignored_users = set(${builtins.toJSON cfg.ignoredUsers})
    preserve_mux = ${
      if cfg.preserveMultiplexers
      then "True"
      else "False"
    }
    dry_run = ${
      if cfg.dryRun
      then "True"
      else "False"
    }
    preserved_patterns = ["tmux", "screen", "agy", "weechat"]

    now_str = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    print(f"=== [{now_str}] Fleet SSH Bastion & Inactive Session Reaper ===")
    print(f"Max Idle Limit:        {max_idle_hours} hours ({max_idle_sec}s)")
    print(f"Ignored Users:         {list(ignored_users)}")
    print(f"Preserve Multiplexers: {preserve_mux}")
    print(f"Dry Run Mode:          {dry_run}")
    print("-" * 70)

    def get_uptime_us():
        try:
            with open("/proc/uptime") as f:
                return int(float(f.read().split()[0]) * 1_000_000)
        except Exception:
            return 0

    try:
        sessions_out = subprocess.check_output(["loginctl", "list-sessions", "--no-legend"]).decode()
    except Exception as e:
        print(f"FAIL: Could not list sessions: {e}", file=sys.stderr)
        sys.exit(1)

    uptime_us = get_uptime_us()
    total_inspected = 0
    reaped_count = 0
    preserved_count = 0
    errors = 0

    for line in sessions_out.strip().splitlines():
        parts = line.split()
        if not parts:
            continue
        sid = parts[0]
        total_inspected += 1

        try:
            show_out = subprocess.check_output(["loginctl", "show-session", sid]).decode()
        except Exception as e:
            print(f"Warning: failed to inspect session {sid}: {e}", file=sys.stderr)
            continue

        props = {}
        for p_line in show_out.splitlines():
            if "=" in p_line:
                k, v = p_line.split("=", 1)
                props[k] = v

        user = props.get("Name", "")
        state = props.get("State", "")
        stype = props.get("Type", "")
        service = props.get("Service", "")
        remote = props.get("Remote", "no")
        seat = props.get("Seat", "")
        tty = props.get("TTY", "")
        uid = props.get("User", "1000")
        idle_hint = props.get("IdleHint", "no")
        idle_mono = int(props.get("IdleSinceHintMonotonic", 0))
        idle_sec = (uptime_us - idle_mono) / 1_000_000 if idle_mono > 0 else 0

        # 1. Skip system managers or users in ignored_users
        if service == "systemd-user" or not user:
            print(f">>> Session {sid:2s}: SKIPPED (systemd user manager)")
            continue
        if user in ignored_users:
            print(f">>> Session {sid:2s}: SKIPPED (ignored user {user})")
            continue

        # 2. Skip local seat/console sessions
        if seat == "seat0" or tty.startswith("tty"):
            print(f">>> Session {sid:2s}: SKIPPED (local console {seat or tty})")
            continue

        # 3. Check cgroup processes
        cgroup_path = f"/sys/fs/cgroup/user.slice/user-{uid}.slice/session-{sid}.scope/cgroup.procs"
        comms = []
        if os.path.exists(cgroup_path):
            try:
                with open(cgroup_path) as f:
                    pids = [p.strip() for p in f.readlines() if p.strip()]
                for p in pids:
                    comm_file = f"/proc/{p}/comm"
                    if os.path.exists(comm_file):
                        try:
                            with open(comm_file) as cf:
                                comms.append(cf.read().strip())
                        except Exception:
                            pass
            except Exception as e:
                print(f"Warning: could not read cgroup {cgroup_path}: {e}", file=sys.stderr)

        # Check for multiplexers or persistent agent daemons
        matched_mux = [c for c in comms if any(pat in c for pat in preserved_patterns)]
        if preserve_mux and matched_mux:
            preserved_count += 1
            print(f">>> Session {sid:2s} ({user}@{tty or '-'}): PRESERVED (active multiplexer: {matched_mux[0]})")
            continue

        # 4. Check for orphaned / abandoned scopes with no processes
        if state in ("closing", "abandoned") and not comms:
            reaped_count += 1
            print(f">>> Session {sid:2s} ({user}@{tty or '-'}): REAP CANDIDATE (orphaned scope in {state}, 0 procs)")
            if not dry_run:
                res = subprocess.call(["loginctl", "terminate-session", sid])
                if res == 0:
                    print(f"    - Cleanly terminated orphaned session {sid}")
                else:
                    print(f"    - ERROR: failed to terminate session {sid} (exit {res})", file=sys.stderr)
                    errors += 1
            continue

        # 5. Check remote SSH idle timeout
        if (remote == "yes" or service == "sshd") and idle_hint == "yes" and idle_sec > max_idle_sec:
            reaped_count += 1
            idle_hours = idle_sec / 3600
            print(f">>> Session {sid:2s} ({user}@{tty or '-'}): REAP CANDIDATE (idle {idle_hours:.1f}h > {max_idle_hours}h)")
            if not dry_run:
                res = subprocess.call(["loginctl", "terminate-session", sid])
                if res == 0:
                    print(f"    - Cleanly terminated idle session {sid}")
                else:
                    print(f"    - ERROR: failed to terminate session {sid} (exit {res})", file=sys.stderr)
                    errors += 1
            continue

        idle_m = idle_sec / 60
        print(f">>> Session {sid:2s} ({user}@{tty or '-'}): OK (state={state}, idle={idle_m:.1f}m)")

    print("-" * 70)
    print("=== Session Reaper Scorecard ===")
    print(f"Sessions Inspected: {total_inspected}")
    print(f"Sessions Preserved: {preserved_count}")
    print(f"Sessions Reaped:    {reaped_count}")
    print(f"Execution Errors:   {errors}")

    if errors > 0:
        print("FAIL: Session reaper encountered errors!", file=sys.stderr)
        sys.exit(1)

    print("PASS: Session sweep completed cleanly.")
    sys.exit(0)
    EOF
  '';
in {
  options.services.fleetSessionReaper = {
    enable = lib.mkEnableOption "declarative SSH bastion and inactive session reaper";

    maxIdleHours = lib.mkOption {
      type = lib.types.int;
      default = 4;
      description = "Maximum idle duration in hours for remote SSH sessions before reaping.";
    };

    ignoredUsers = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "List of usernames whose sessions are never terminated.";
    };

    preserveMultiplexers = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to preserve sessions running tmux, screen, agy, or weechat.";
    };

    dryRun = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether to operate in dry-run mode (audit only, do not terminate).";
    };

    schedule = lib.mkOption {
      type = lib.types.str;
      default = "hourly";
      description = "systemd OnCalendar schedule expression for periodic reaper execution.";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.fleet-session-reaper = {
      description = "Fleet SSH bastion and inactive session reaper";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${reaperScript}/bin/fleet-session-reaper";
        ProtectSystem = "full";
        PrivateTmp = true;
      };
    };

    systemd.timers.fleet-session-reaper = {
      description = "Scheduled fleet inactive session reaper timer";
      wantedBy = ["timers.target"];
      timerConfig = {
        OnCalendar = cfg.schedule;
        Persistent = true;
        RandomizedDelaySec = "5m";
      };
    };

    environment.systemPackages = [reaperScript];
  };
}
