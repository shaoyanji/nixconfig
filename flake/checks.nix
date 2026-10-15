{
  lib,
  systems,
  pkgsFor,
  self,
  hostInventory,
}:
# CHEAP CHECKS ONLY — `checks.<system>` MUST NOT force a host configuration.
#
# This is a hard budget rule, not a style preference. Every check in this set is
# evaluated in ONE nix process, and a NixOS host config costs ~200 MiB of
# evaluator heap (measured: 1.98 s / 197.6 MiB for `nixosConfigurations.frieren`).
# The previous revision forced every host here — `host-eval-<host>`,
# `inventory-host-<host>` and a `host-architecture` check that read
# `config.systemd.services` for all 23 — so `nix flake check` (and
# `task checks:quick`, which built `host-architecture`) evaluated 23 full
# toplevels in a single process: ~4.5 GiB, which on this 11 GiB host with 5 GiB
# already swapped was SIGKILLed (exit 137) leaving the box in a 62 %-IO-stall
# state for minutes.
#
# The split:
#   * checks.<system>          — this file. Reads the compiled registry and flake
#                                attr NAMES. ~50 MiB, no host evaluation. Runs in
#                                `nix flake check` and CI unconditionally.
#   * hostChecks.<system>.<h>  — flake/host-checks.nix. Exactly ONE host per
#                                attribute, so one bounded evaluation (~200 MiB).
#                                CI runs it for affected hosts; `task
#                                checks:host:HOST=` runs one; `task checks:hosts`
#                                sweeps sequentially, never in one process.
lib.genAttrs systems.default (
  system: let
    pkgs = pkgsFor system;
  in
    if !(builtins.elem system systems.checks)
    then {}
    else let
      # Cross-check the compiled inventory against the flake's own outputs.
      # `builtins.attrNames` forces the output projection (a mapAttrs over the
      # registry) but NOT the configurations behind it, so this is cheap.
      coverage = let
        kindNames = {
          nixos = builtins.attrNames self.nixosConfigurations;
          darwin = builtins.attrNames self.darwinConfigurations;
          home = builtins.attrNames self.homeConfigurations;
        };
        declared = kind: builtins.attrNames (lib.filterAttrs (_: h: h.kind == kind) self.inventory.flakeHosts);
        tagged = kind: names: map (n: "${kind}:${n}") names;
        kinds = ["nixos" "darwin" "home"];
      in {
        # inventory.toml calls it a flake host, but the flake has no output.
        missing = lib.concatMap (kind: tagged kind (lib.subtractLists kindNames.${kind} (declared kind))) kinds;
        # the flake builds it, but inventory.toml never registered it.
        unregistered = lib.concatMap (kind: tagged kind (lib.subtractLists (declared kind) kindNames.${kind})) kinds;
      };

      # The module that injects the compiled registry (flake/module-sets.nix) is
      # recognised by the attribute path it carries. `?` walks only the attrset
      # spine, so it does NOT force the registry itself, and `isAttrs` keeps it
      # safe over path/function module entries (`inputs.sops-nix.nixosModules.*`
      # are functions).
      hasInjection = modules: lib.any (m: builtins.isAttrs m && (m ? _module.args.inventory)) modules;
      notInjected =
        builtins.filter (name: !(hasInjection hostInventory.${name}.modules))
        (builtins.attrNames hostInventory);

      hostCount = builtins.length (builtins.attrNames hostInventory);
    in {
      # --- the compiled registry is internally consistent --------------------
      inventory-schema =
        if !self.inventory.ok
        then
          builtins.throw ''
            inventory.toml is inconsistent (see lib/inventory.nix):
              ${lib.concatStringsSep "\n  " self.inventory.issues}
          ''
        else
          pkgs.runCommand "inventory-schema" {} ''
            echo "inventory.toml OK: ${toString self.inventory.derived.total} devices (${toString self.inventory.derived.nix} nix, ${toString self.inventory.derived.external} external); ${toString self.inventory.derived.active} active"
            touch $out
          '';

      # --- registry and flake outputs agree, both directions ----------------
      inventory-hosts = assert (coverage.missing == []) || throw "inventory.toml declares flake hosts the flake does not build: ${builtins.toString coverage.missing}";
      assert (coverage.unregistered == []) || throw "the flake builds hosts missing from inventory.toml: ${builtins.toString coverage.unregistered}";
        pkgs.runCommand "inventory-hosts" {} ''
          echo "inventory/flake host sets agree across nixos, darwin and home"
          touch $out
        '';

      # --- every host COMPILES inventory.toml, proven without evaluating one -
      # This replaces the old per-host `inventory-host-<host>` evaluations, which
      # were pure waste: the registry is compiled ONCE at flake level
      # (flake/outputs.nix → lib/inventory.nix), so a host cannot re-parse or
      # re-derive it. The only per-host failure mode is that the injection module
      # is absent from the host's module list, which is a structural property of
      # flake/host-inventory.nix — checkable by inspecting the lists, at zero
      # evaluation cost. Behavioural proof (the host's module system really
      # resolved `config.fleet.inventory`) lives in hostChecks.<system>.<host>.
      inventory-modules =
        if notInjected == []
        then
          pkgs.runCommand "inventory-modules" {} ''
            echo "all ${toString hostCount} registered hosts carry the compiled-inventory module (nixos chains, containers, standalone home, darwin, microvms)"
            touch $out
          ''
        else
          builtins.throw ''
            these hosts have NO compiled-inventory module injected, so they have no
            config.fleet.inventory (add moduleSets.inventoryModules to their list in
            flake/host-inventory.nix): ${builtins.toString notInjected}
          '';

      docs-site = pkgs.runCommand "docs-site" {} ''
        mkdir -p "$out"
        ls "${self.docsSite}/index.html" > "$out/index.html"
      '';
    }
)
