{
  lib,
  systems,
  pkgsFor,
  self,
  hostInventory,
}:
# PER-HOST CHECKS — exactly ONE host per attribute, and the cheap half of "does
# this host evaluate".
#
# WHAT IS AND IS NOT COVERED, measured on frieren 2026-10-15:
#
#   this file forces      the module system + EVERY assertion condition
#                         -> 6.56 s, 687 MiB peak, per host
#   it does NOT force     config.system.build.toplevel, i.e. the instantiation of
#                         the whole system derivation graph -> >120 s, unbounded
#                         wall clock, and the thing the old `host-eval-<host>`
#                         checks did for all 23 hosts in ONE process: 6078.5 MiB
#                         peak, SIGKILL (exit 137), 62 % sustained IO-stall.
#
# Forcing `config.assertions` runs the same conditions nixpkgs' toplevel asserts,
# so this catches the failure class the eval gate exists for — conflicting
# options, bad values, port collisions, repo policy violations — without paying
# for closure instantiation. The exhaustive half is CI's job and CI already does
# it: `nix build .#nixosConfigurations.<host>` builds the real closure, one host
# per 16 GiB runner. Do not "restore" toplevel forcing here; that is the bomb.
#
# Kept as a separate flake output (`hostChecks`, not `checks`) because
# `nix flake check` forces every attribute of `checks.<system>` in one process, so
# anything host-sized in there is a fleet-sized memory bill. Drive this with
# `task checks:host:HOST=<host>` (one) or `task checks:hosts` (sequential sweep).
lib.genAttrs systems.work (
  system: let
    pkgs = pkgsFor system;
    # Only hosts whose DECLARED system matches this attribute set. The system comes
    # from the registry, not from the evaluated config (which would cost the very
    # host evaluation this file exists to bound). Without the filter
    # `hostChecks.x86_64-linux` would carry the aarch64 hosts and building one would
    # demand an aarch64-linux builder for a trivial echo. There is deliberately NO
    # `systems.checks` gate — that list is for `checks` (x86_64 only); the per-host
    # gate must exist for every architecture the fleet has.
    configs = lib.filterAttrs (name: _: hostInventory.${name}.system == system) self.nixosConfigurations;
  in
    # mapAttrs is lazy in the values: building ONE attribute evaluates ONE host.
    lib.mapAttrs (
      host: _: let
        cfg = self.nixosConfigurations.${host}.config;
        # Forces every assertion condition — the eval gate proper.
        failed = lib.filter (a: !a.assertion) cfg.assertions;
        inventoryForHost = cfg.fleet.inventory.hosts.${host};
        inventoryCount = builtins.length (builtins.attrNames cfg.fleet.inventory.hosts);
      in
        if failed != []
        then
          throw ''
            ${host}: ${toString (builtins.length failed)} assertion(s) failed:
              ${lib.concatMapStringsSep "\n  " (a: a.message) failed}
          ''
        else if cfg.systemd.services ? go-backend
        then
          throw ''
            host-architecture: services.go-backend is enabled on ${host}, which is not a
            go-backend host (the legacy go backend lives in modules/services/go-backend.nix
            and is expected to be enabled by no host). Remove it from
            hosts/${host}/configuration.nix or from its chain in flake/host-inventory.nix.
          ''
        else
          pkgs.runCommand "host-check-${host}" {} ''
            echo "${host}: module system evaluated, ${toString (builtins.length cfg.assertions)} assertion(s) passed"
            echo "  compiled inventory.toml: hostname=${inventoryForHost.hostname} kind=${inventoryForHost.kind} arch=${inventoryForHost.arch} role=${inventoryForHost.role}"
            echo "  registry visible to this host: ${toString inventoryCount} host(s) at config.fleet.inventory.hosts"
            touch $out
          ''
    )
    configs
)
