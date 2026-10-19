{
  lib,
  systems,
  pkgsFor,
  self,
  hostInventory,
  skillsCtl,
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

      # --- the skill tree is a schema, not a folder of prose -----------------
      # Hard errors only: name/dir mismatch, missing or oversized description,
      # missing body heading, >400 lines. Optional frontmatter is normalised by
      # lib/skills.nix and reported as a warning (the warning list is printed
      # here too, so the gate output is the audit, not a separate task).
      skills-schema =
        if !skillsCtl.ok
        then
          builtins.throw ''
            .agents/skills violates the skill schema (lib/skills.nix):
              ${lib.concatStringsSep "\n  " skillsCtl.issues}
          ''
        else
          pkgs.runCommand "skills-schema" {} ''
            echo "agent skills OK: ${toString skillsCtl.index.count} skills"
            ${lib.concatMapStrings (w: ''                echo "WARN ${w}"
              '')
              skillsCtl.warnings}
            touch $out
          '';

      # --- the site's JS is code, not a Nix literal -------------------------
      # lib/aki-site.nix used to carry ~800 lines of browser JS inside `''`
      # strings, where a syntax error was either a Nix parse error or invisible.
      # The assets are files in lib/site/, so a real JS engine can parse them.
      # `--check` parses without executing: no network, no DOM, no runtime.
      site-assets =
        pkgs.runCommand "site-assets" {
          nativeBuildInputs = [pkgs.nodejs];
        } ''
          for f in ${../lib/site/aki.js} ${../lib/site/kg.js}; do
            node --check "$f"
            echo "parsed $(basename "$f")"
          done
          touch $out
        '';

      # --- living documents have budgets (SCHEMA.md §2) ---------------------
      # Pure eval: counts lines of tracked files, builds nothing, needs no
      # host. This is the flake-hook half of `task ops:docs:budget`; the task
      # is the human view, this is the gate CI can run on a doc-only change.
      docs-budget = let
        root = ./..;
        # `wc -l` semantics: the trailing newline does not start a line. Counting
        # the split as-is made this gate disagree with `task ops:docs:budget` by
        # exactly one line, so a document exactly at its budget failed the flake
        # check while passing the task.
        lines = f: lib.splitString "\n" (lib.removeSuffix "\n" (builtins.readFile (root + "/${f}")));
        count = f: builtins.length (lines f);
        # A queue is judged by what is still OPEN, not by how much it has already
        # done — the checked items are the record that the work happened, and
        # deleting them to make room would erase exactly that record. So TODO.md
        # carries two counters: 150 open items, 300 lines in total.
        queue = f: let
          ls = lines f;
        in {
          open = builtins.length (builtins.filter (l: lib.hasPrefix "- [ ]" l) ls);
          total = builtins.length ls;
        };
        limits = {
          "AGENTS.md" = 1200;
          "MANUAL.md" = 1200;
          "ARCHITECTURE.md" = 600;
          "AUDIT.md" = 150;
          "HANDOFF.md" = 150;
        };
        queueLimits = {
          "TODO.md" = {
            open = 150;
            total = 300;
          };
        };
        over =
          lib.filter (name: count name > limits.${name})
          (builtins.attrNames limits);
        overQueues = lib.filter (
          name: let
            q = queue name;
          in
            q.open > queueLimits.${name}.open || q.total > queueLimits.${name}.total
        ) (builtins.attrNames queueLimits);
        queueReport = name: let
          q = queue name;
        in "${name}: ${toString q.open}/${toString queueLimits.${name}.open} open, ${toString q.total}/${toString queueLimits.${name}.total} total";
      in
        if over != [] || overQueues != []
        then
          builtins.throw ''
            living documents exceed their SCHEMA.md budget:
              ${lib.concatStringsSep "\n  " (map (n: "${n}: ${toString (count n)} > ${toString limits.${n}}") over)}
              ${lib.concatStringsSep "\n  " (map queueReport overQueues)}
            Move detail to docs/ and leave a pointer; do not raise the budget
            (for TODO.md, close or move open items — do not delete the record).
          ''
        else
          pkgs.runCommand "docs-budget" {} ''
            echo "living documents within budget: ${toString (builtins.length (builtins.attrNames limits))} + ${toString (builtins.length (builtins.attrNames queueLimits))} queue"
            echo "${lib.concatStringsSep "; " (map queueReport (builtins.attrNames queueLimits))}"
            touch $out
          '';
    }
)
