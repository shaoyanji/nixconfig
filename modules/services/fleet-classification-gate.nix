# fleet-classification-gate — the nightly systemd classification drift sweep.
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.fleetClassificationGate;

  # The driver resolves its own root as `dirname/../..` and calls oom-guard.sh
  # relative to it, so both files must sit in the same tree. Staging them into the
  # store makes the gate independent of a checkout: the unit runs the driver that
  # was built into THIS generation and judges `flakeRef` — so a dirty or half-pulled
  # checkout cannot change either the rules or the revision under judgement.
  driver = pkgs.runCommand "fleet-classification-gate-driver" {} ''
    install -Dm755 ${../../scripts/task/host-check-sweep.sh} $out/scripts/task/host-check-sweep.sh
    install -Dm755 ${../../scripts/task/oom-guard.sh} $out/scripts/task/oom-guard.sh
  '';

  gate = pkgs.writeShellApplication {
    name = "fleet-classification-gate";
    runtimeInputs = [
      config.nix.package
      pkgs.bash
      pkgs.coreutils
      pkgs.gawk
      pkgs.gnugrep
      pkgs.procps
    ];
    text = ''
      set -uo pipefail
      REF="${cfg.flakeRef}"
      export NIX_CONFIG="experimental-features = nix-command flakes"

      # One fetch before the loop: on 2026-10-24 a fetch racing the first per-host
      # eval failed delphi for a network hiccup, which is not drift. After this line
      # every eval reads the local git cache.
      nix flake metadata "$REF" >/dev/null

      # The set and the filter are Nix, not jq: one leaf read of the compiled
      # registry (0.15 s), so no second parser sits between the truth and the loop.
      # A host added to inventory.toml is gated the next night; `external` kinds
      # have no flake configuration to evaluate.
      # getAttr, not attribute-access-by-name: inside shell single quotes that
      # syntax is read as an unexpanded shell variable (SC2016) and shellcheck
      # fails the build.
      HOSTS="$(nix eval --raw "$REF#inventory.hosts" --apply '
        h: let keep = n: let v = builtins.getAttr n h; in v.status == "active" && v.kind != "external";
        in builtins.concatStringsSep " " (builtins.filter keep (builtins.attrNames h))')"
      if [ -z "''${HOSTS// /}" ]; then
        echo "fleet-classification-gate: the inventory read returned no active host — refusing to report green" >&2
        exit 1
      fi

      echo "fleet-classification-gate: gating $REF"
      echo "  hosts: $HOSTS"
      # eval mode is arch-independent, so no builder is involved and aarch64/darwin
      # hosts are covered from this machine. One host per process under the OOM
      # watchdog: peak memory is one host, and pressure stops the run instead of
      # the NAS (AGENTS.md: never a fleet eval in one process).
      bash ${driver}/scripts/task/host-check-sweep.sh \
        --hosts "$HOSTS" --mode eval --flake "$REF" --timeout ${toString cfg.timeout}
    '';
  };
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
      default = 180;
      description = "Per-host timeout, seconds, enforced by oom-guard.sh.";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.fleet-classification-gate = {
      description = "Nightly systemd classification drift gate (per-host assertions)";
      after = ["network-online.target"];
      wants = ["network-online.target"];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${gate}/bin/fleet-classification-gate";
        TimeoutStartSec = "45min";
        Nice = 10;
        IOSchedulingClass = "idle";
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
