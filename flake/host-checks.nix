{
  lib,
  systems,
  pkgsFor,
  self,
  hostInventory,
}:
# PER-HOST CHECKS — exactly ONE host per attribute, and the cheap half of "does
# this host evaluate". The gate itself lives in flake/host-check.nix.
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
# Do not "restore" toplevel forcing here; that is the bomb. The exhaustive half is
# CI's job and CI already does it, one host per 16 GiB runner.
#
# ALL THREE KINDS, because the gate is "does this host's config hold", and a
# standalone home (kali) or darwin (cassini) config has assertions too.
#
# Kept as a separate flake output (`hostChecks`, not `checks`) because
# `nix flake check` forces every attribute of `checks.<system>` in one process, so
# anything host-sized in there is a fleet-sized memory bill. Drive this with
# `task checks:host:HOST=<host>` (one), `task checks:hosts` (a named set), or
# `fleetChecks.<system>` (the whole fleet, one host per worker process).
#
# Here the check is built with the HOST's architecture's pkgs, so CI can build the
# attribute on the matching runner and the store path is shared across machines.
lib.genAttrs systems.work (
  system: let
    pkgs = pkgsFor system;
    check = import ./host-check.nix {inherit lib pkgs hostInventory;};
    # Only hosts whose DECLARED system matches this attribute set. The system comes
    # from the registry, not from the evaluated config (which would cost the very
    # host evaluation this file exists to bound). Without the filter
    # `hostChecks.x86_64-linux` would carry the aarch64 hosts and building one would
    # demand an aarch64-linux builder for a trivial echo. There is deliberately NO
    # `systems.checks` gate — that list is for `checks` (x86_64 only); the per-host
    # gate must exist for every architecture the fleet has.
    #
    # mapAttrs is lazy in the values: building ONE attribute evaluates ONE host.
    pick = kind: configs:
      lib.mapAttrs (name: cfg:
        check {
          host = name;
          inherit kind;
          cfg = cfg.config;
        }) (lib.filterAttrs (name: _: (hostInventory.${name}.system or null) == system) configs);
  in
    pick "nixos" self.nixosConfigurations
    // pick "darwin" self.darwinConfigurations
    // pick "home" self.homeConfigurations
)
