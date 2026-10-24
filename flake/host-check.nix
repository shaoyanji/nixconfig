{
  lib,
  pkgs,
}:
# ONE host's evaluation gate, as a derivation.
#
# The gate is the assertion half of "does this host hold": forcing
# `config.assertions` runs the same conditions nixpkgs' toplevel asserts, so it
# catches conflicting options, bad values, port collisions and repo policy
# violations WITHOUT instantiating the system's derivation graph (that is the
# >120 s / unbounded-memory bomb; `nixos-rebuild switch` and CI do it instead).
#
# The artifact is a three-line echo, so its `pkgs` decides only which SYSTEM the
# derivation claims — never what it proves. That split is what lets one machine
# gate an aarch64 or darwin host: the configuration is EVALUATED here, and nothing
# of it is built. Callers choose:
#   flake/host-checks.nix — pkgs of the host's own arch, so CI builds it per runner
#   flake/fleet-checks.nix — pkgs of the evaluator, so one host can gate the fleet
{
  host,
  kind,
  cfg,
}: let
  # Forces every assertion condition — the eval gate proper.
  failed = lib.filter (a: !a.assertion) cfg.assertions;
  inventoryForHost = cfg.fleet.inventory.hosts.${host};
  inventoryCount = builtins.length (builtins.attrNames cfg.fleet.inventory.hosts);
  # Home-manager has systemd.user only; nix-darwin has no systemd at all.
  hasGoBackend = (cfg.systemd.services or {}) ? go-backend;
in
  if failed != []
  then
    throw ''
      ${host} (${kind}): ${toString (builtins.length failed)} assertion(s) failed:
        ${lib.concatMapStringsSep "\n  " (a: a.message) failed}
    ''
  else if hasGoBackend
  then
    throw ''
      host-architecture: services.go-backend is enabled on ${host}, which is not a
      go-backend host (the legacy go backend lives in modules/services/go-backend.nix
      and is expected to be enabled by no host). Remove it from
      hosts/${host}/configuration.nix or from its chain in flake/host-inventory.nix.
    ''
  else
    pkgs.runCommand "host-check-${host}" {} ''
      echo "${host} (${kind}): module system evaluated, ${toString (builtins.length cfg.assertions)} assertion(s) passed"
      echo "  compiled inventory.toml: hostname=${inventoryForHost.hostname} kind=${inventoryForHost.kind} arch=${inventoryForHost.arch} role=${inventoryForHost.role}"
      echo "  registry visible to this host: ${toString inventoryCount} host(s) at config.fleet.inventory.hosts"
      touch $out
    ''
