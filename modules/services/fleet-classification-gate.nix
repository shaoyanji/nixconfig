# fleet-classification-gate — nightly drift sweep: one generated unit per host.
# --max-jobs 1 serialises builds, not evaluation, so one unit per host bounds memory.
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.fleetClassificationGate;

  system = pkgs.stdenv.hostPlatform.system;

  # Membership is the compiled inventory, not a list: a host added to inventory.toml
  # is gated the next night, and a host that leaves stops being gated.
  active =
    lib.filterAttrs
    (_: host: host.status == "active" && host.kind != "external")
    config.fleet.inventory.hosts;

  # Sorted so the `After=` chain is deterministic: a generation must not reorder
  # the schedule (or the store paths) because attrNames happened to differ.
  hosts = lib.sort builtins.lessThan (builtins.attrNames active);

  unitOf = host: "fleet-classification-check-${host}.service";

  # Each check is `After=` the previous host's check, so the timer cannot start
  # twelve evaluators at once. Deliberately NOT `Requires=`: one broken host must
  # not hide the rest — the old shell sweep's `--keep-going` behaviour, expressed as
  # ordering instead of as a flag.
  previous = host: let
    i = lib.lists.findFirstIndex (h: h == host) 0 hosts;
  in
    lib.optional (i > 0) (unitOf (lib.lists.elemAt hosts (i - 1)));
in {
  options.services.fleetClassificationGate = {
    enable = lib.mkEnableOption "the nightly systemd classification drift sweep";

    flakeRef = lib.mkOption {
      type = lib.types.str;
      default = "github:shaoyanji/nixconfig";
      description = ''
        Revision to gate. Defaults to the ref system.autoUpgrade deploys, so drift
        is reported before that revision is installed — not after.
      '';
    };

    schedule = lib.mkOption {
      type = lib.types.str;
      default = "*-*-* 01:00:00";
      description = ''
        OnCalendar expression. Before the 03:00-05:30 nightly window and before the
        04:00 autoUpgrade, so a failure is in the sentinel ledger hours before the
        deploy it warns about.
      '';
    };

    timeout = lib.mkOption {
      type = lib.types.int;
      default = 600;
      description = "Per-host TimeoutStartSec, seconds.";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services =
      lib.mapAttrs' (host: hostCfg:
        lib.nameValuePair "fleet-classification-check-${host}" {
          description = "Classification gate: ${host} (${hostCfg.kind})";
          after = ["network-online.target"];
          wants = ["network-online.target"];
          # Ordered after the previous host, so one evaluator is alive at a time.
          unitConfig.After = previous host;
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
            ExecStart = "${pkgs.writeShellScript "fleet-classification-check-${host}" ''
              set -uo pipefail
              export NIX_CONFIG="experimental-features = nix-command flakes"
              # One fetch before the first deref: a network hiccup during the first
              # evaluation is not drift, and it failed a host on 2026-10-24.
              nix flake metadata ${cfg.flakeRef} >/dev/null
              # `--builders ""` because the check is a local echo and a gate must be
              # unable to spend remote build seconds (AGENTS.md).
              exec ${config.nix.package}/bin/nix build \
                --builders "" -L --no-link \
                "${cfg.flakeRef}#fleetHostChecks.${system}.${host}"
            ''}";
            TimeoutStartSec = toString cfg.timeout;
            Nice = 10;
            IOSchedulingClass = "idle";
          };
        })
      active
      // {
        # The result everyone reads: one command, no loop. `systemctl is-failed`
        # exits 0 when AT LEAST ONE of the named units failed (verified on 2026-10-24:
        # two active units -> 1, one failed -> 0), so the verdict is its inverse. The
        # exit status is what the sentinel ledger records.
        fleet-classification-gate = {
          description = "Nightly systemd classification drift gate (verdict)";
          wants = map unitOf hosts;
          after = map unitOf hosts;
          serviceConfig = {
            Type = "oneshot";
            ExecStart = "${pkgs.writeShellScript "fleet-classification-verdict" ''
              set -uo pipefail
              if out=$(${pkgs.systemd}/bin/systemctl is-failed ${lib.concatMapStringsSep " " unitOf hosts}); then
                echo "classification gate: at least one host failed — journalctl -u fleet-classification-check-*" >&2
                printf '%s\n' "$out" >&2
                exit 1
              fi
              echo "${toString (builtins.length hosts)} active host(s): module system + assertions pass"
            ''}";
          };
        };
      };

    systemd.timers.fleet-classification-gate = {
      wantedBy = ["timers.target"];
      timerConfig = {
        OnCalendar = cfg.schedule;
        Persistent = true;
        RandomizedDelaySec = "10min";
      };
    };
  };
}
