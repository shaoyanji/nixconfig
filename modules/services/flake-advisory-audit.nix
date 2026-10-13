# Declarative Flake Lock Drift & Security Advisory Audit Unit (EXP-044).
#
# Periodically inspects flake.lock input pins, evaluates input freshness, audits core
# security dependencies (nixpkgs, home-manager, sops-nix) against staleness thresholds,
# and flags archival or drifting dependencies before weekly autoUpgrades.
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.flakeAdvisoryAudit;

  auditScript = pkgs.writeShellScriptBin "flake-advisory-audit" ''
        set -euo pipefail

        export PATH="${lib.makeBinPath [pkgs.coreutils pkgs.systemd pkgs.python3]}:$PATH"

        ${pkgs.python3}/bin/python3 - <<'EOF'
    import json, datetime, sys, os

    flake_path = "${toString cfg.flakePath}"
    critical_inputs = set(${builtins.toJSON cfg.criticalInputs})
    critical_max_days = ${toString cfg.criticalMaxAgeDays}
    warn_age_days = ${toString cfg.warnAgeDays}

    now = datetime.datetime.now(datetime.timezone.utc)
    now_str = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")

    print(f"=== [{now_str}] Flake Lock Drift & Security Advisory Audit ===")
    print(f"Flake Directory:      {flake_path}")
    print(f"Critical Inputs:      {list(critical_inputs)}")
    print(f"Critical Age Ceiling: {critical_max_days} days")
    print(f"General Warn Ceiling: {warn_age_days} days")
    print("-" * 70)

    lock_file = os.path.join(flake_path, "flake.lock")
    if not os.path.exists(lock_file):
        print(f"FAIL: Flake lock file {lock_file} does not exist!", file=sys.stderr)
        sys.exit(1)

    try:
        with open(lock_file) as f:
            lock = json.load(f)
    except Exception as e:
        print(f"FAIL: Failed to parse {lock_file}: {e}", file=sys.stderr)
        sys.exit(1)

    nodes = lock.get("nodes", {})
    root = nodes.get(lock.get("root", "root"), {})
    inputs = root.get("inputs", {})

    critical_healthy = 0
    stale_inputs = []
    errors = 0

    for name, target in sorted(inputs.items()):
        node = nodes.get(target, {})
        locked = node.get("locked", {})
        ts = locked.get("lastModified")
        rev = locked.get("rev", "unknown")[:10]
        owner = locked.get("owner", "")
        repo = locked.get("repo", "")

        if not ts:
            print(f">>> Input {name:20s}: (no timestamp, rev={rev})")
            continue

        dt = datetime.datetime.fromtimestamp(ts, datetime.timezone.utc)
        age_days = (now - dt).total_seconds() / 86400

        if name in critical_inputs:
            if age_days <= critical_max_days:
                critical_healthy += 1
                print(f">>> Input {name:20s}: OK (age: {age_days:.1f}d <= {critical_max_days}d | rev={rev})")
            else:
                print(f">>> Input {name:20s}: WARN (age: {age_days:.1f}d > {critical_max_days}d | rev={rev})")
                errors += 1
        elif age_days > warn_age_days:
            stale_inputs.append((name, age_days, rev))
            print(f">>> Input {name:20s}: STALE (age: {age_days:.1f}d > {warn_age_days}d | rev={rev})")
        else:
            print(f">>> Input {name:20s}: OK (age: {age_days:.1f}d | rev={rev})")

    print("-" * 70)
    print("=== Flake Advisory Audit Scorecard ===")
    print(f"Total Inputs Audited:    {len(inputs)}")
    print(f"Critical Inputs Healthy: {critical_healthy}/{len(critical_inputs)}")
    print(f"Archival/Stale Inputs:   {len(stale_inputs)}")
    print(f"Critical Drift Errors:   {errors}")

    if errors > 0:
        print("FAIL: Flake lock contains stale critical security inputs!", file=sys.stderr)
        sys.exit(1)

    print("PASS: Flake lock integrity and input freshness verified.")
    sys.exit(0)
    EOF
  '';
in {
  options.services.flakeAdvisoryAudit = {
    enable = lib.mkEnableOption "declarative flake lock drift and security advisory audit unit";

    flakePath = lib.mkOption {
      type = lib.types.path;
      default = /Volumes/data/projects/nixconfig;
      description = "Path to the Nix flake directory containing flake.lock.";
    };

    criticalInputs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "nixpkgs"
        "home-manager"
        "sops-nix"
      ];
      description = "List of critical security inputs subject to strict freshness ceilings.";
    };

    criticalMaxAgeDays = lib.mkOption {
      type = lib.types.int;
      default = 14;
      description = "Maximum age in days for critical security inputs before flagging an error.";
    };

    warnAgeDays = lib.mkOption {
      type = lib.types.int;
      default = 60;
      description = "Age threshold in days for flagging non-critical stale inputs.";
    };

    schedule = lib.mkOption {
      type = lib.types.str;
      default = "Sun *-*-* 07:00:00";
      description = "systemd OnCalendar schedule expression (strictly after backup window).";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.flake-advisory-audit = {
      description = "Flake lock drift and security advisory audit unit";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${auditScript}/bin/flake-advisory-audit";
        ProtectSystem = "full";
        PrivateTmp = true;
      };
    };

    systemd.timers.flake-advisory-audit = {
      description = "Scheduled flake advisory audit timer";
      wantedBy = ["timers.target"];
      timerConfig = {
        OnCalendar = cfg.schedule;
        Persistent = true;
        RandomizedDelaySec = "5m";
      };
    };

    environment.systemPackages = [auditScript];
  };
}
