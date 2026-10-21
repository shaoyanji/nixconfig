{
  lib,
  systems,
  pkgsFor,
  self,
  hostInventory,
  skillsCtl,
  agentsNotesCtl,
  policiesCtl,
  taskfileCtl,
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

      # pkgs.txt is a file a human edits: a trailing reason, a pasted markdown
      # list, a repeated name. The parser is a lib because another flake can
      # read its own list with it (lib/pkg-list.nix).
      pkgList = import ../lib/pkg-list.nix {inherit lib;};
      pkgFixture = pkgList.parse ''
        # a heading is a comment
        helix  # editor
        - bat # pager
        * jq
        1. ripgrep
        - [x] fd
        helix
      '';
      pkgExpected = ["helix" "bat" "jq" "ripgrep" "fd"];

      # The lenient half: a list copied out of a markdown handoff contains names
      # nixpkgs has no attribute for. `split` resolves what exists and names the
      # rest, which is the only way ingesting an untrusted list is usable.
      pkgSplit = pkgList.split {
        inherit pkgs;
        text = pkgFixtureString;
      };
      pkgFixtureString = ''
        - helix  # editor
        - SomeAppImage.bin
      '';
      policyFailures = builtins.filter (id: !policiesCtl.policies.${id}.holds) policiesCtl.ids;
      policyReport =
        lib.concatMapStrings (
          id: ''
            ✗ ${id} — ${policiesCtl.policies.${id}.rule}
               proof: ${policiesCtl.policies.${id}.proof}
               now:   ${policiesCtl.policies.${id}.detail}
          ''
        )
        policyFailures;
      dangling = map (c: "${c.doc} -> ${c.id}") policiesCtl.danglingCitations;
      unenforced = policiesCtl.unenforcedHardRules;
    in {
      # --- pkgs.txt: the format a human will actually edit -------------------
      pkg-list = assert pkgFixture == pkgExpected;
      assert (pkgList.parse "") == [];
      assert (pkgList.resolve {
        inherit pkgs;
        text = "python3Packages.requests";
      })
      != [];
      # deepSeq, not tryEval alone: resolve returns a lazy list, so a bare
      # tryEval sees the spine and never forces the throw inside it. A missing
      # entry must fail loudly rather than vanish from a user's PATH.
      assert !(
        builtins.tryEval (
          builtins.deepSeq (pkgList.resolve {
            inherit pkgs;
            text = "no-such-package-xyz";
          })
          null
        )
      ).success;
      assert (builtins.length pkgSplit.packages) == 1;
      assert pkgSplit.missing == ["SomeAppImage.bin"];
        pkgs.runCommand "pkg-list" {} ''
          echo "pkgs.txt: inline + heading comments, markdown markers, dedupe, dotted paths, loud failure"
          touch $out
        '';
      # --- policies: a rule the docs state must be a predicate here ----------
      # The gate has two halves and both matter. `holds` proves the tree still
      # does what the rule says; the citation checks prove the rule is reachable
      # from the document that states it, in both directions, so neither the
      # prose nor the gate can drift into being decorative.
      policies =
        if policyFailures != []
        then builtins.throw "policy violated:\n${policyReport}"
        else if dangling != []
        then builtins.throw "a doc cites a policy that does not exist:\n  ${lib.concatStringsSep "\n  " dangling}"
        else if policiesCtl.uncitedPolicies != []
        then builtins.throw "a policy is enforced but no document cites it (invisible gate):\n  ${lib.concatStringsSep "\n  " policiesCtl.uncitedPolicies}"
        else if unenforced != []
        then builtins.throw "HARD RULE without a [[flake/policies.nix#id]] citation — state the rule in the registry and cite it, or delete it:\n  ${lib.concatStringsSep "\n  " unenforced}"
        else
          pkgs.runCommand "policies" {} ''
            echo "${toString (builtins.length policiesCtl.ids)} policies hold; every citation resolves; every id is cited"
            touch $out
          '';

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

      # --- AGENTS.nix notes are traceable or verbose, never terse leaves -----
      agents-notes-schema =
        if !agentsNotesCtl.ok
        then
          builtins.throw ''
            AGENTS.nix violates the note schema (lib/agents-notes.nix):
              ${lib.concatStringsSep "\n  " agentsNotesCtl.issues}
          ''
        else
          pkgs.runCommand "agents-notes-schema" {} ''
            echo "AGENTS.nix OK: ${toString agentsNotesCtl.counts.total} notes (${toString agentsNotesCtl.counts.open} open, ${toString agentsNotesCtl.counts.leaves} leaves)"
            touch $out
          '';

      # --- the task graph is data, and a gate mints it ----------------------
      # lib/taskfile.nix parses Taskfile.yml + the include graph. What it cannot
      # prove is that go-task agrees with the parse — that is
      # `checks:taskfile:graph` (scripts/task/taskfile-graph.sh), which compares
      # this name set against `task --list-all --json`. This check is the half
      # that needs no `task` binary, so it runs in CI and on a keyless box.
      #
      # The derivation NAME carries the graph digest, so the artifact is
      # addressable as a version: `nix build .#checks.x86_64-linux.taskfile-graph`
      # mints one, and a kept path is a graph you can diff or fail back to.
      taskfile-graph =
        if taskfileCtl.gateFailures != []
        then
          builtins.throw ''
            the task graph violates a hard rule (lib/taskfile.nix):
              ${lib.concatStringsSep "\n  " taskfileCtl.gateFailures}

            Hard buckets: ${lib.concatStringsSep ", " taskfileCtl.gateBuckets}
            Advisory buckets (reported, never fatal): ${lib.concatStringsSep ", " (
              builtins.filter (k: !(builtins.elem k taskfileCtl.gateBuckets)) (builtins.attrNames taskfileCtl.violations)
            )}.
          ''
        else let
          report = builtins.toJSON {
            inherit (taskfileCtl) version proseVersion files names includes violations descBudget summaryBudget;
            tasks = builtins.length taskfileCtl.parsed;
            # The prose surface verbatim, not just findings *about* prose: a
            # wording edit has no address in `version` (it is the execution
            # surface on purpose), so the artifact carries what the summaries
            # actually said. An old build can then be diffed against the new one.
            prose = taskfileCtl.proseSurface;
          };
        in
          # Both digests in the name: `<version>` is what executes, `p<digest>` is
          # what an agent reads. Identical execution + edited prose is two paths,
          # and the prefix says so before you open either.
          pkgs.runCommand "taskfile-graph-${taskfileCtl.version}-p${taskfileCtl.proseVersion}" {} ''
            mkdir -p $out
            cp ${pkgs.writeText "taskfile-graph.json" report} $out/graph.json
            printf '%s\n' '${taskfileCtl.version}' > $out/version
            printf '%s\n' '${taskfileCtl.proseVersion}' > $out/prose
            echo "task graph ${taskfileCtl.version} (prose ${taskfileCtl.proseVersion}): ${toString (builtins.length taskfileCtl.parsed)} tasks in ${toString (builtins.length taskfileCtl.files)} files, ${toString (builtins.length taskfileCtl.includes)} include edges"
            echo "advisory: ${toString (builtins.length taskfileCtl.violations.longSummary)} summaries over ${toString taskfileCtl.summaryBudget} chars, ${toString (builtins.length taskfileCtl.violations.proseRef)} unresolved prose mentions, ${toString (builtins.length taskfileCtl.violations.exitUnverified)} exit claims unverifiable"
          '';

      # A gate that has only ever run on a clean tree is a gate nobody knows the
      # shape of. The fixture violates every hard bucket exactly once, and names
      # its expected verdicts here, so a bucket that stops firing (or starts
      # firing on prose) fails this check instead of drifting silently.
      taskfile-graph-selftest = let
        fixture = import ../lib/taskfile.nix {
          inherit lib;
          root = ../tests/taskfile-graph;
        };
        expect = {
          duplicate = ["dup"];
          orphanShard = ["orphan.yml"];
          unflattened = ["Taskfile.yml: loose -> taskfiles/loose.yml"];
          missingInclude = ["Taskfile.yml: gone -> taskfiles/typo.yml"];
          includeCycle = ["taskfiles/cycle.yml: root -> Taskfile.yml"];
          internal = ["Taskfile.yml:hidden"];
          danglingRef = ["Taskfile.yml:broken -> ghost:run"];
          wildcardArity = ["Taskfile.yml:wild has 0 '*' but 1 MATCH refs [0]"];
          proseRef = ["Taskfile.yml:prose -> nowhere:real"];
          noDesc = ["Taskfile.yml:bare"];
          longSummary = ["Taskfile.yml:longsum (${toString (builtins.stringLength fixture.byName.longsum.summary)})"];
          longDesc = ["Taskfile.yml:longdesc (${toString (builtins.stringLength fixture.byName.longdesc.desc)})"];
          # Deliberately empty: these tasks are well-formed, the flags task
          # (`task --list-all`) is a flag, not a dangling reference, and the
          # fixture's `desc`-only / `summary`-only tasks are legal shapes.
          nameGrammar = [];
          sourcesWithoutWatch = [];
          retiredRef = [];
          # `badexit` promises 7 against a script that only exits 3; `badexit-missing`
          # promises 1 and names a script the tree does not have, which is a
          # report, not drift.
          exitDrift = ["Taskfile.yml:badexit claims exit 7; emits [3]"];
          exitUnverified = ["Taskfile.yml:badexit-missing claims exit 1 but scripts/task/not-here.sh is not in the tree"];
        };
        sorted = builtins.sort builtins.lessThan;
        keySet = builtins.sort builtins.lessThan (builtins.attrNames fixture.violations);
        expectedKeys = builtins.sort builtins.lessThan (builtins.attrNames expect);
        mismatched = builtins.filter (k: sorted fixture.violations.${k} != sorted expect.${k}) (builtins.attrNames expect);
        detail = lib.concatMapStrings (k: "\n  ${k}\n    expected: ${builtins.toJSON (sorted expect.${k})}\n    actual:   ${builtins.toJSON (sorted fixture.violations.${k})}") mismatched;
      in
        if mismatched != [] || keySet != expectedKeys
        then
          builtins.throw ''
            tests/taskfile-graph asserts the task-graph buckets and disagrees:
              ${lib.concatStringsSep "\n  " (lib.optionals (keySet != expectedKeys) ["bucket set changed: expected ${builtins.toJSON expectedKeys}, got ${builtins.toJSON keySet}"])}${detail}
            Fix the detector or update the fixture's expectations in flake/checks.nix.
          ''
        else
          pkgs.runCommand "taskfile-graph-selftest" {} ''
            echo "fixture verdicts match: ${toString (builtins.length expectedKeys)} buckets, ${toString (builtins.length fixture.parsed)} tasks, ${toString (builtins.length (builtins.concatLists (builtins.attrValues expect)))} expected findings"
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
      # One implementation: scripts/task/docs-budget.sh, the same script
      # `task ops:docs:budget` runs and the same gate the CI `docs-budget` job
      # builds on every push. The budgets used to live here *and* in the task,
      # and they disagreed by one line (`wc -l` vs a split); running the script
      # over the flake source removes the second copy, so a document exactly at
      # its budget cannot pass one surface and fail the other.
      docs-budget = pkgs.runCommand "docs-budget" {} ''
        cd ${../.}
        bash scripts/task/docs-budget.sh
        touch $out
      '';
    }
)
