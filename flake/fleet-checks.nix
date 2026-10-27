{
  lib,
  systems,
  pkgsFor,
  self,
  inventory,
}:
# THE FLEET GATE AS FLAKE OUTPUTS — two shapes, because they answer different
# questions and one of them is expensive.
#
#   fleetHostChecks.<system>.<host>   one host, one attribute, one evaluation.
#                                    Membership is the compiled inventory (active,
#                                    non-`external`), NOT a host list.
#   fleetChecks.<system>              every active host as ONE derivation.
#
# WHY TWO. `fleetChecks` is the tidy expression — building it makes Nix walk the
# graph and run one host per worker process, `--max-jobs 1` keeps one alive,
# `--keep-going` reports every failure. What it does NOT bound is EVALUATION:
# resolving that graph forces every active host's config in the single evaluator
# that reads the flake. Measured 2026-10-24 on frieren: 5122.9 MiB for twelve hosts,
# against 2358.9 MiB for the same twelve dispatched one attribute at a time. The
# fleet-in-one-process shape is what got `nix flake check` SIGKILLed at 6078.5 MiB,
# so the nightly gate uses `fleetHostChecks` — one systemd unit per host, each its
# own nix process — and `fleetChecks` stays for CI, where the runner has the headroom.
#
# KEY PROPERTY OF BOTH: the check artifact is built with THIS system's pkgs, whatever
# architecture the gated host is. The gate evaluates a config and echoes a line;
# nothing of the host is built, which is exactly true for an aarch64 host judged from
# an x86_64 NAS. That is why `fleetHostChecks.x86_64-linux.delphi` builds here while
# `hostChecks.aarch64-linux.delphi` (host-arch, CI's shape) does not.
let
  perSystem = system: let
    pkgs = pkgsFor system;
    check = import ./host-check.nix {inherit lib pkgs;};
    active = lib.filterAttrs (_: host: host.status == "active" && host.kind != "external") inventory.hosts;
    configsFor = kind:
      {
        nixos = self.nixosConfigurations;
        darwin = self.darwinConfigurations;
        home = self.homeConfigurations;
      }
    .${
        kind
      };
    names = lib.sort builtins.lessThan (builtins.attrNames active);
    checks = lib.listToAttrs (map (
        name: let
          kind = active.${name}.kind;
        in {
          inherit name;
          value = check {
            host = name;
            inherit kind;
            cfg = (configsFor kind).${name}.config;
          };
        }
      )
      names);
  in {
    inherit pkgs checks names;
  };
in {
  fleetHostChecks = lib.genAttrs systems.work (system: (perSystem system).checks);

  fleetChecks = lib.genAttrs systems.work (
    system: let
      inherit (perSystem system) pkgs checks names;
    in
      pkgs.runCommand "fleet-checks-${system}" {buildInputs = lib.attrValues checks;} ''
        echo "${toString (builtins.length names)} active host(s): module system + assertions pass, compiled inventory resolves"
        touch $out
      ''
  );
}
