# flake/checks.nix — the eval-time check set: cheap, no host configuration forced.
# What the gate layers prove: docs/ci-pipeline.md; the eval-cost design: note eval-cost-ladder.
{
  lib,
  systems,
  pkgsFor,
  self,
  hostInventory,
  moduleSets,
  skillsCtl,
  agentsNotesCtl,
  policiesCtl,
  epistemicsCtl,
  ontologyCtl,
  knowledgeGraphCtl,
  taskList,
}:
# Cheap checks only: nothing in this set may force a host configuration. The
# split, the measurements and the gate are AGENTS.md §Gates and
# `flake/policies.nix#flake-check-memory-gated`; the per-host half is
# `flake/host-checks.nix`.
lib.genAttrs systems.work (
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
        declared = kind:
          self.inventory.flakeHosts
          |> lib.filterAttrs (_: h: h.kind == kind)
          |> builtins.attrNames;
        tagged = kind: names: map (n: "${kind}:${n}") names;
        kinds = ["nixos" "darwin" "home"];
      in {
        # inventory.toml calls it a flake host, but the flake has no output.
        missing =
          kinds
          |> lib.concatMap (
            kind:
              declared kind
              |> lib.subtractLists kindNames.${kind}
              |> tagged kind
          );
        # the flake builds it, but inventory.toml never registered it.
        unregistered =
          kinds
          |> lib.concatMap (
            kind:
              kindNames.${kind}
              |> lib.subtractLists (declared kind)
              |> tagged kind
          );
      };

      # The module that injects the compiled registry (flake/module-sets.nix) is
      # recognised by the attribute path it carries. `?` walks only the attrset
      # spine, so it does NOT force the registry itself, and `isAttrs` keeps it
      # safe over path/function module entries (`inputs.sops-nix.nixosModules.*`
      # are functions).
      hasInjection = modules: modules |> lib.any (m: builtins.isAttrs m && (m ? _module.args.inventory));
      notInjected =
        hostInventory
        |> builtins.attrNames
        |> builtins.filter (name: !(hasInjection (moduleSets.hostModules hostInventory.${name})));

      hostCount = hostInventory |> builtins.attrNames |> builtins.length;

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
      # A policy is a judgment, a fact is not, so epistemics outranks policy
      # (flake/epistemics.nix §precedence): a rule that protects nothing real is
      # overturned by the fact that says so, never by lowering the rule. What
      # fails is filtered through `overturns`, so an overturned policy stops
      # failing the gate while its text and the fact that overturned it both stay
      # in the record. A failure with no override keeps failing, which is why this
      # is precedence and not an exemption.
      # A `soft` policy is a measured budget whose overrun is reported and does
      # not fail the gate: the number still has a home and still moves in the
      # open, but a growing corpus is a cost, not a contradiction. Hard policies
      # are unchanged — only a declared epistemic fact overturns one of those.
      policySoft = id: policiesCtl.policies.${id}.soft or false;
      policyFailing = policiesCtl.ids |> builtins.filter (id: !policiesCtl.policies.${id}.holds && !(policySoft id));
      policySoftFailing = policiesCtl.ids |> builtins.filter (id: !policiesCtl.policies.${id}.holds && policySoft id);
      policyFailures = epistemicsCtl.overturns policyFailing;
      softReport =
        policySoftFailing
        |> lib.concatMapStrings (
          id: ''
            ~ ${id} (soft) — ${policiesCtl.policies.${id}.detail}
          ''
        );
      policyOverturned = policyFailing |> builtins.filter (id: epistemicsCtl.overrides ? ${id});
      policyReport =
        policyFailures
        |> lib.concatMapStrings (
          id: ''
            ✗ ${id} — ${policiesCtl.policies.${id}.rule}
               proof: ${policiesCtl.policies.${id}.proof}
               now:   ${policiesCtl.policies.${id}.detail}
               if a declared epistemic fact shows this rule protects nothing here, record it
               in `.#epistemics.overrides` with its `because` and `evidence` — a fact may
               overturn a judgment, a convenience may not.
          ''
        );
      overturnIssues =
        epistemicsCtl.overrides
        |> builtins.attrNames
        |> lib.concatMap (id: let
          o = epistemicsCtl.overrides.${id};
        in
          lib.optional (!(builtins.elem id policiesCtl.ids)) "epistemics.overrides.${id} names no policy — a dead override is a silenced gate"
          ++ lib.optional (o.because or "" == "") "epistemics.overrides.${id}.because is empty — say what the rule fails to protect"
          ++ lib.optional (o.evidence or "" == "") "epistemics.overrides.${id}.evidence is empty — an override without evidence is a preference"
          ++ lib.optional (!(o ? since)) "epistemics.overrides.${id}.since is missing (the date the fact was established)");
      overturnReport =
        policyOverturned
        |> lib.concatMapStrings (
          id: ''
            ⇢ ${id} overturned — ${epistemicsCtl.overrides.${id}.because}
               evidence: ${epistemicsCtl.overrides.${id}.evidence} (${epistemicsCtl.overrides.${id}.since})
          ''
        );
      dangling = policiesCtl.danglingCitations |> map (c: "${c.doc} -> ${c.id}");
      unenforced = policiesCtl.unenforcedHardRules;
      classIssues = policiesCtl.errorClasses.problems;
    in {
      # flake/nix-registry.nix: one name per file, and no module name claimed
      # twice — `listToAttrs` silently keeps the last of a collision (stripping
      # `.nix` from the leaf once lost 17 files to `flake.nix` vs `flake/`).
      nix-registry = let
        reg = self.nixFileRegistry;
        countLeaves = x:
          if builtins.isAttrs x
          then builtins.foldl' (a: v: a + (countLeaves v)) 0 (builtins.attrValues x)
          else if builtins.isPath x
          then 1
          else 0;
        leaves = countLeaves self.nixFiles;
        named = self.modules |> builtins.attrNames |> builtins.length;
        problems =
          lib.optional (leaves != reg.count)
          ".#nixFiles names ${toString leaves} files, the walk found ${toString reg.count} — a name collision dropped one"
          ++ (reg.duplicates |> map (n: "duplicate module name: ${n}"))
          ++ lib.optional (named != reg.modules)
          ".#modules has ${toString named} names for ${toString reg.modules} files under modules/ — a duplicate collapsed two"
          ++ (reg.unknownNames |> map (n: ''self.modules."${n}" names no file under modules/''));
      in
        if problems != []
        then builtins.throw "nix file registry is inconsistent:\n  ${problems |> lib.concatStringsSep "\n  "}"
        else
          pkgs.runCommand "nix-registry" {} ''
            echo "nix files: ${toString reg.count}; modules named: ${toString reg.modules}"
            touch $out
          '';
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
        if overturnIssues != []
        then builtins.throw "epistemics override is not a fact (flake/epistemics.nix):\n  ${overturnIssues |> lib.concatStringsSep "\n  "}"
        else if policyFailures != []
        then builtins.throw "policy violated:\n${policyReport}"
        else if dangling != []
        then builtins.throw "a doc cites a policy that does not exist:\n  ${dangling |> lib.concatStringsSep "\n  "}"
        else if policiesCtl.uncitedPolicies != []
        then builtins.throw "a policy is enforced but no document cites it (invisible gate):\n  ${policiesCtl.uncitedPolicies |> lib.concatStringsSep "\n  "}"
        else if unenforced != []
        then builtins.throw "HARD RULE without a [[flake/policies.nix#id]] citation — state the rule in the registry and cite it, or delete it:\n  ${unenforced |> lib.concatStringsSep "\n  "}"
        # The classification table is the policy layer's error output: a class
        # the page declares but no policy holds is a class that will be patched
        # ad hoc next time.
        else if classIssues != []
        then builtins.throw "the error-classification table and docs/issue-classes.md disagree:\n  ${classIssues |> lib.concatStringsSep "\n  "}"
        else
          pkgs.runCommand "policies" {}
          (''
              echo "${policiesCtl.ids |> builtins.length |> toString} policies hold; every citation resolves; every id is cited"
              printf '%s\n' ${policiesCtl.errorClasses.report |> lib.concatStringsSep "\n" |> lib.escapeShellArg}
            ''
            + lib.optionalString (policyOverturned != []) ''
              printf '%s\n' ${lib.escapeShellArg overturnReport}
            ''
            + lib.optionalString (policySoftFailing != []) ''
              printf '%s\n' ${lib.escapeShellArg softReport}
            ''
            + ''
              touch $out
            '');

      # --- the compiled registry is internally consistent --------------------
      inventory-schema =
        if !self.inventory.ok
        then
          builtins.throw ''
            inventory.toml is inconsistent (see lib/inventory.nix):
              ${self.inventory.issues |> lib.concatStringsSep "\n  "}
          ''
        else
          pkgs.runCommand "inventory-schema" {} ''
            echo "inventory.toml OK: ${toString self.inventory.derived.total} devices (${toString self.inventory.derived.nix} nix, ${toString self.inventory.derived.external} external); ${toString self.inventory.derived.active} active"
            touch $out
          '';

      # --- the eval-time cache list is a copy of the registry ---------------
      # flake.nix must write nixConfig as literals (Determinate's reader rejects
      # thunks there), so the addresses exist twice by necessity. This gate is
      # what keeps the copy honest: it compares the flake's nixConfig against
      # lib/cache-registry.nix in both directions and throws on any difference.
      # `import ../flake.nix` reads only the `.nixConfig` attribute — the
      # `outputs` function is never applied — so it does not recurse into this
      # file.
      cache-registry = let
        flakeCache = (import ../flake.nix).nixConfig;
        registryCache = import ../lib/cache-registry.nix;
        expectedUrls = registryCache.evalOrder |> map (n: registryCache.caches.${n}.url);
        expectedKeys =
          registryCache.evalOrder
          |> map (n: registryCache.caches.${n}.key)
          |> builtins.filter (k: k != null);
        drift =
          lib.subtractLists expectedUrls flakeCache.extra-substituters
          ++ lib.subtractLists flakeCache.extra-substituters expectedUrls
          ++ lib.subtractLists expectedKeys flakeCache.extra-trusted-public-keys
          ++ lib.subtractLists flakeCache.extra-trusted-public-keys expectedKeys;
      in
        assert drift == [] || throw "flake.nix nixConfig and lib/cache-registry.nix disagree: ${builtins.toString drift}";
          pkgs.runCommand "cache-registry" {} ''
            echo "flake.nix nixConfig matches lib/cache-registry.nix (${expectedUrls |> builtins.length |> toString} substituters, ${expectedKeys |> builtins.length |> toString} keys)"
            touch $out
          '';

      # --- shell scripts: read-only static analysis -------------------------
      # `-S warning` is the gate; notes are printed but do not fail, because the
      # two notes this tree produces are structural (a sourced file shellcheck
      # cannot follow, a variable used only by the sourcing shell). The tree is at
      # zero errors and zero warnings here: the 1 error (SC2068, an unquoted path
      # array) and the 14 warnings that existed were fixed, not excluded. Reads
      # the flake source, so it sees exactly the tree being gated.
      scripts-shellcheck = pkgs.runCommand "scripts-shellcheck" {nativeBuildInputs = [pkgs.shellcheck];} ''
        set -euo pipefail
        cd ${self}
        mapfile -t files < <(find scripts .githooks -type f \( -name "*.sh" -o -name "pre-commit" \))
        files+=(.git-hooks-setup.sh)
        shellcheck -f gcc -S warning "''${files[@]}" | tee "$out"
        echo "shellcheck: ''${#files[@]} files, no error or warning" >> "$out"
      '';

      # --- the epistemics table is complete, in both directions --------------
      # Two silent failures live in a hand-declared authority table, and neither
      # shows up as a bad answer: a `settles` entry with a typo drops that
      # source's authority over a kind nobody notices, and a kind no source
      # settles makes "read: nowhere" look like a search failure. Both are
      # cheap to prove here because the table is pure data.
      epistemics = let
        knownKinds = epistemicsCtl.kindIds;
        declaredSources = epistemicsCtl.sources |> builtins.attrNames;
        badSettles =
          declaredSources
          |> lib.concatMap (
            n:
              epistemicsCtl.sources.${n}.settles
              |> builtins.filter (k: !(builtins.elem k knownKinds))
              |> map (k: "${n}.settles names unknown kind '${k}'")
          );
        badStanding = declaredSources |> builtins.filter (n: !(builtins.elem epistemicsCtl.sources.${n}.standing ["authored" "snapshot" "unvetted"]));
        unreadable = knownKinds |> builtins.filter (k: epistemicsCtl.table.${k}.read == null);
        unlisted =
          (epistemicsCtl.sourceIds |> lib.subtractLists declaredSources)
          ++ (declaredSources |> lib.subtractLists epistemicsCtl.sourceIds);
        # A route is a transport: it must say how to use it, what it spends, whose
        # quota that is, and whether it may be fanned out. An unlabelled route is
        # how a metered surface gets used by accident.
        routeIssues =
          declaredSources
          |> lib.concatMap (n: let
            rts = epistemicsCtl.sources.${n}.routes;
          in
            rts
            |> builtins.attrNames
            |> lib.concatMap (r: let
              rt = rts.${r};
            in
              lib.optional (rt.how or "" == "") "${n}.routes.${r}.how is empty — a route nobody can invoke"
              ++ lib.optional (!(rt ? cost) || rt.cost <= 0) "${n}.routes.${r}.cost must be a positive token count"
              ++ lib.optional (!(builtins.elem (rt.metered or "") ["none" "upstream" "quota" "paid"])) "${n}.routes.${r}.metered must be none/upstream/quota/paid"
              ++ lib.optional (!(rt ? fanout) || !builtins.isBool rt.fanout) "${n}.routes.${r}.fanout must be a bool (may it be asked many times at once?)"
              ++ lib.optional (!(rt ? offline) || !builtins.isBool rt.offline) "${n}.routes.${r}.offline must be a bool"));
        # A measured `p` without the sentence that measured it is a number with
        # no provenance, which is the thing this file exists to stop.
        spendIssues =
          epistemicsCtl.spend
          |> builtins.attrNames
          |> lib.concatMap (n: let
            rows = epistemicsCtl.spend.${n};
          in
            lib.optional (!(builtins.elem n declaredSources)) "spend.${n} names an undeclared source"
            ++ (
              rows
              |> builtins.attrNames
              |> lib.concatMap (k: let
                row = rows.${k};
              in
                lib.optional (!(builtins.elem k knownKinds)) "spend.${n}.${k} names an unknown claim kind"
                ++ lib.optional (row.measured or "" == "") "spend.${n}.${k}.p has no `measured` — an unmeasured probability is what this replaces"
                ++ lib.optional (row.p <= 0.0 || row.p > 1.0) "spend.${n}.${k}.p must be in (0,1]")
            ));
        # The Kelly wiring, proved by sign rather than by reading: a 0.7% settle
        # rate cannot pay for 250 tokens, and a hand-picked 50% can. If the
        # formula's arguments were ever swapped, both flip.
        kelly = epistemicsCtl.judge "personal-method" "zim-shelf";
        kellyGood = epistemicsCtl.judge "software-behaviour" "zim-shelf";
        # `or` inside a string interpolation does not parse in this Nix (`unexpected
        # 'in', expecting 'inherit'`), so the value is bound before it is printed.
        kellyEv =
          if kelly.ev == null
          then 0.0
          else kelly.ev;
        kellyGoodEv =
          if kellyGood.ev == null
          then 0.0
          else kellyGood.ev;
        kellyIssues =
          lib.optional (kelly.ev == null || kellyEv >= 0.0) "the measured 0.7% shelf hit rate must produce a NEGATIVE Kelly ev; got ${lib.strings.floatToString kellyEv}"
          ++ lib.optional (kellyGood.ev == null || kellyGoodEv <= 0.0) "the 50% software-behaviour rate must produce a POSITIVE Kelly ev; got ${lib.strings.floatToString kellyGoodEv}";
        persistIssues = epistemicsCtl.persistable |> map (k: "${k}.persist is empty — an answer with nowhere to live is researched forever");
        evIssues =
          (
            epistemicsCtl.evidenceIds
            |> lib.concatMap (
              t: let
                e = epistemicsCtl.evidence.${t};
              in
                lib.optional (!(e ? rank) || !(builtins.isInt e.rank) || e.rank < 0) "evidence.${t}.rank must be a non-negative integer"
                ++ lib.optional (e.what or "" == "") "evidence.${t}.what is empty"
                ++ lib.optional (e.cannot or "" == "") "evidence.${t}.cannot is empty — say what the tier does not prove"
                ++ lib.optional (e.promote or "" == "") "evidence.${t}.promote is empty — say what would raise it"
                ++ lib.optional (!(builtins.elem (e.producedBy or "") ["person" "compiler" "machine"])) "evidence.${t}.producedBy must be person/compiler/machine"
            )
          )
          ++ (
            epistemicsCtl.evidence
            |> builtins.attrNames
            |> lib.subtractLists epistemicsCtl.evidenceIds
            |> map (t: "evidence.${t} is not in evidenceIds — the ladder has no order")
          )
          ++ (
            epistemicsCtl.evidenceIds
            |> lib.subtractLists (epistemicsCtl.evidence |> builtins.attrNames)
            |> map (t: "evidenceIds names '${t}', which is not a declared tier")
          )
          ++ (
            let
              ranks = epistemicsCtl.evidenceIds |> map (t: epistemicsCtl.evidence.${t}.rank);
            in
              lib.optional ((ranks |> lib.unique |> builtins.length) != (ranks |> builtins.length)) "two evidence tiers share a rank — a ladder with a rung missing"
          );
        floorIssues =
          knownKinds
          |> builtins.filter (k: !(epistemicsCtl.evidence |> builtins.hasAttr epistemicsCtl.kinds.${k}.evidenceFloor))
          |> map (k: "kinds.${k}.evidenceFloor '${toString epistemicsCtl.kinds.${k}.evidenceFloor}' is not a declared evidence tier");
        noteClaimIssues =
          epistemicsCtl.noteClaims
          |> builtins.attrValues
          |> lib.unique
          |> lib.subtractLists knownKinds
          |> map (k: "noteClaims maps a note kind to '${k}', which flake/epistemics.nix does not declare");
        carryIssues =
          lib.optional (epistemicsCtl.carries "decision" "extracted") "an extracted match must not carry a decision"
          ++ lib.optional (!(epistemicsCtl.carries "decision" "asserted")) "an authored decision must be allowed — the ladder is inverted"
          ++ lib.optional (epistemicsCtl.carries "fleet-fact" "extracted") "a token match must not carry a compiled fleet fact"
          ++ lib.optional (!(epistemicsCtl.carries "fleet-fact" "resolved")) "a resolved lookup must carry a fleet fact";
        issues =
          badSettles
          ++ (badStanding |> map (n: "${n}.standing is not authored/snapshot/unvetted"))
          ++ (unreadable |> map (k: "no declared source may settle '${k}' — every kind needs an authority, even if it is 'ask a person'"))
          ++ (unlisted |> map (n: "${n} is missing from sourceIds (or declared twice) — ordering would be undefined"))
          ++ routeIssues
          ++ spendIssues
          ++ kellyIssues
          ++ persistIssues
          ++ evIssues
          ++ floorIssues
          ++ noteClaimIssues
          ++ carryIssues;
      in
        if issues != []
        then builtins.throw "epistemics table is inconsistent (flake/epistemics.nix):\n  ${issues |> lib.concatStringsSep "\n  "}"
        else
          pkgs.runCommand "epistemics" {} ''
            echo "epistemics: ${declaredSources |> builtins.length |> toString} sources x ${knownKinds |> builtins.length |> toString} claim kinds, every kind settled and persistable, every route labelled, the evidence ladder ordered, Kelly sign correct"
            touch $out
          '';

      # flake/ontology.nix
      ontology = let
        g = knowledgeGraphCtl.graph;
        nodeTypes = g.nodes |> builtins.catAttrs "type" |> lib.unique;
        edgeTypes = g.edges |> builtins.catAttrs "type" |> lib.unique;
        declaredEntities = ontologyCtl.entityIds;
        declaredRelations = ontologyCtl.relationIds;
        nodeTypeIssues =
          (nodeTypes |> lib.subtractLists declaredEntities |> map (t: "the graph emits node type '${t}' that no entity declares"))
          ++ (declaredEntities |> lib.subtractLists nodeTypes |> map (t: "entity '${t}' is declared but the graph emits no node of that type"));
        edgeTypeIssues =
          (edgeTypes |> lib.subtractLists declaredRelations |> map (t: "the graph emits edge type '${t}' that no relation declares"))
          ++ (declaredRelations |> lib.subtractLists edgeTypes |> map (t: "relation '${t}' is declared but the graph emits no edge of that type"));
        fieldIssues =
          g.nodes
          |> lib.concatMap (n: let
            carried = n |> (x: builtins.removeAttrs x ["id" "type"]) |> builtins.attrNames;
            extra = carried |> lib.subtractLists ontologyCtl.entities.${n.type}.fields;
          in
            extra |> map (f: "node ${n.id} carries field '${f}' that ${n.type}.fields does not declare"));
        badEdges = g.edges |> builtins.filter (e: !(ontologyCtl.admit e).ok);
        edgeIssues = badEdges |> map (e: "edge ${e.from} -${e.type}-> ${e.to}: ${(ontologyCtl.admit e).why}");
        noteNodes = g.nodes |> builtins.filter (n: n.type == "note");
        noteClaimIssues =
          (
            noteNodes
            |> builtins.filter (n: (n.claim or null) == null)
            |> map (n: "note ${n.id} carries no claim kind — every note is a claim (flake/epistemics.nix noteClaims)")
          )
          ++ (
            noteNodes
            |> builtins.filter (
              n: let
                c = n.claim or null;
              in
                c != null && !(builtins.elem c epistemicsCtl.kindIds)
            )
            |> map (n: "note ${n.id} carries claim '${n.claim}', which flake/epistemics.nix does not declare")
          )
          ++ (
            noteNodes
            |> builtins.filter (
              n: let
                c = n.claim or null;
              in
                c != null && builtins.elem c epistemicsCtl.kindIds && !(epistemicsCtl.carries c "asserted")
            )
            |> map (n: "note ${n.id} is classified '${n.claim}' and a note is an assertion — that tier cannot carry the kind")
          );
        claimIssues =
          declaredEntities
          |> lib.concatMap (
            t:
              ontologyCtl.entities.${t}.claims
              |> builtins.filter (k: !(builtins.elem k epistemicsCtl.kindIds))
              |> map (k: "${t}.claims names claim kind '${k}' that flake/epistemics.nix does not declare")
          );
        sinkRoute = s: ontologyCtl.sinks.${s}.route or "";
        sinkWhy = s: ontologyCtl.sinks.${s}.why or "";
        kindIssues =
          (ontologyCtl.unhomed |> map (k: "claim kind '${k}' is stable but has no entity home and no declared sink"))
          ++ (ontologyCtl.sinkOnly |> map (k: "claim kind '${k}' is stable and only a sink holds it — give it an entity home, or a sink can substitute for one forever"))
          ++ (ontologyCtl.straySinks |> map (k: "sink '${k}' names no claim kind"))
          ++ (
            ontologyCtl.sinkIds
            |> builtins.filter (s: !(builtins.elem ontologyCtl.sinks.${s}.kind ["none" "external"]))
            |> map (s: "sink '${s}' declares kind '${ontologyCtl.sinks.${s}.kind}', not one of none|external")
          )
          ++ (
            ontologyCtl.sinkIds
            |> builtins.filter (s: ontologyCtl.sinks.${s}.where == "")
            |> map (s: "sink '${s}' has an empty where — a home nobody can find")
          )
          ++ (
            ontologyCtl.sinkIds
            |> builtins.filter (s: sinkWhy s == "")
            |> map (s: "sink '${s}' has an empty why — say why this repository cannot hold the kind")
          )
          ++ (
            ontologyCtl.sinkIds
            |> builtins.filter (s: !(builtins.elem (sinkRoute s) epistemicsCtl.sourceIds))
            |> map (s: "sink '${s}' names route '${sinkRoute s}', which flake/epistemics.nix does not declare")
          );
        bareNotes = import ../lib/agents-notes.nix {inherit lib;};
        claimParity = let
          bare = bareNotes.counts.byClaim;
          compiled = agentsNotesCtl.counts.byClaim;
          keys = (builtins.attrNames bare ++ builtins.attrNames compiled) |> lib.unique;
          unclassified =
            bareNotes.index
            |> builtins.attrNames
            |> builtins.filter (id: (bareNotes.index.${id}.claim or null) == null);
        in
          lib.optional (!(keys |> builtins.all (k: (bare.${k} or 0) == (compiled.${k} or 0))))
          "a bare lib/agents-notes.nix import reports claim counts ${builtins.toJSON bare} where the compiled projection reports ${builtins.toJSON compiled} — the site renders the bare one"
          ++ (unclassified |> map (id: "note ${id} has no claim kind without an explicit claimOf — a surface importing the module bare would show it unclassified"));
        claimRowIssues =
          lib.optional ((agentsNotesCtl.claimRows |> builtins.foldl' (n: r: n + r.notes) 0) != agentsNotesCtl.counts.total)
          "the claim rows do not sum to the note total — a renderer reading them would show a partial table"
          ++ lib.optional ((agentsNotesCtl.claimRows |> builtins.foldl' (n: r: n + r.open) 0) != agentsNotesCtl.counts.open)
          "the claim rows do not sum to the open note count";
        noteIds = agentsNotesCtl.notes |> builtins.attrNames;
        sliceLinkIssues =
          agentsNotesCtl.notes
          |> builtins.attrValues
          |> lib.concatMap (
            n:
              (n.from ++ n.supersedes ++ n.replacedBy ++ n.descendants)
              |> builtins.filter (t: !(builtins.elem t noteIds))
              |> map (t: "note ${n.id} links '${t}', which has no slice — the lineage button on its page would 404")
          );
        recordedCount = g.edges |> lib.count (e: e ? evidence);
        recordIssues = lib.optional (recordedCount == 0) "no edge records its own evidence — the per-edge tier is declared but nothing uses it";
        citationIssues = knowledgeGraphCtl.unresolvedCitations |> map (c: "citation ${c} names a policy id flake/policies.nix does not declare — the graph drops the edge, so name the rule or drop the citation");
        tierIssues =
          declaredRelations
          |> builtins.filter (r: !(ontologyCtl.tiers |> builtins.hasAttr ontologyCtl.relations.${r}.tier))
          |> map (r: "relation '${r}' has tier '${ontologyCtl.relations.${r}.tier}' that is not declared");
        sparseIssues =
          (
            declaredEntities
            |> lib.concatMap (t: let
              e = ontologyCtl.entities.${t};
            in
              lib.optional (e.what == "") "${t}.what is empty"
              ++ lib.optional (e.identity == "") "${t}.identity is empty — say what makes two of these the same thing"
              ++ lib.optional (e.member == "") "${t}.member is empty — name the compiled source that enumerates membership"
              ++ lib.optional (e.fields == []) "${t}.fields is empty")
          )
          ++ (
            declaredRelations
            |> lib.concatMap (r: let
              x = ontologyCtl.relations.${r};
            in
              lib.optional (x.evidence == "") "${r}.evidence is empty — a relation with no evidence is a guess"
              ++ lib.optional (x.cannot == "") "${r}.cannot is empty — say what the edge does not prove"
              ++ lib.optional (x.from == [] || x.to == []) "${r} declares no domain or range")
          );
        issues = nodeTypeIssues ++ edgeTypeIssues ++ fieldIssues ++ edgeIssues ++ noteClaimIssues ++ claimIssues ++ claimParity ++ claimRowIssues ++ sliceLinkIssues ++ kindIssues ++ recordIssues ++ citationIssues ++ tierIssues ++ sparseIssues;
        nodeCount = g.nodes |> builtins.length;
        edgeCount = g.edges |> builtins.length;
        entityCount = declaredEntities |> builtins.length;
        relationCount = declaredRelations |> builtins.length;
      in
        if issues != []
        then builtins.throw "the graph is not an instance of its ontology (flake/ontology.nix):\n  ${issues |> lib.concatStringsSep "\n  "}"
        else
          pkgs.runCommand "ontology" {} ''
            echo "ontology: ${toString entityCount} entities x ${toString relationCount} relations, ${toString nodeCount} nodes / ${toString edgeCount} edges (${toString recordedCount} record their own tier), every edge admitted, every citation resolves, every field declared, every stable claim kind homed, every sink routed, every note classified — on a bare import too"
            touch $out
          '';

      # --- the router's labels and its playbook rows are one table -------
      # assets/labels.json names the lanes and references/playbooks.md the
      # row each lane runs; the gate keeps the two equal and every row's
      # `task X` citation inside a taskfile.
      router-labels = let
        dir = ../.agents/skills/router;
        labels =
          dir
          + "/assets/labels.json"
          |> builtins.readFile
          |> builtins.fromJSON
          |> builtins.attrNames;
        rows =
          dir
          + "/references/playbooks.md"
          |> builtins.readFile
          |> lib.splitString "\n"
          |> map (builtins.match "\\|[[:space:]]*`([a-z]+(-[a-z]+)*)`.*")
          |> builtins.filter (m: m != null)
          |> map builtins.head;
        missing = labels |> lib.subtractLists rows;
        orphans = rows |> lib.subtractLists labels;
        repeated = rows |> lib.subtractLists (lib.unique rows);
        unknownTasks = knowledgeGraphCtl.routerUnknown |> map (t: "playbook row runs 'task ${t}', which no taskfile declares");
        issues =
          (missing |> map (l: "label '${l}' has no row in references/playbooks.md"))
          ++ (orphans |> map (s: "row '${s}' has no label in assets/labels.json"))
          ++ (repeated |> lib.unique |> map (s: "'${s}' appears in more than one row"))
          ++ unknownTasks;
      in
        if issues != []
        then builtins.throw "the router's labels and playbooks disagree:\n  ${issues |> lib.concatStringsSep "\n  "}"
        else
          pkgs.runCommand "router-labels" {} ''
            echo "router: ${labels |> builtins.length |> toString} labels, each with exactly one playbook row"
            touch $out
          '';

      # --- every task is visible to a person or an agent -----------------
      # `task --list` shows `desc`, `--list-all --json` shows `summary`; a
      # task with neither exists on neither surface.
      task-descs = let
        undescribed =
          taskList
          |> builtins.attrNames
          |> builtins.filter (n: taskList.${n}.desc == "" && !taskList.${n}.hasSummary);
        issues = undescribed |> map (n: "task '${n}' has no desc and no summary — invisible in both `task --list` and --list-all --json");
      in
        if issues != []
        then builtins.throw "the task surface hides tasks:\n  ${issues |> lib.concatStringsSep "\n  "}"
        else
          pkgs.runCommand "task-descs" {} ''
            echo "task-descs: ${taskList |> builtins.attrNames |> builtins.length |> toString} tasks, each visible to a person or to an agent"
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

      # --- the site's JS is code, not a Nix literal -------------------------
      # lib/aki-site.nix used to carry ~800 lines of browser JS inside `''`
      # strings, where a syntax error was either a Nix parse error or invisible.
      # The assets are files in lib/site/, so a real JS engine can parse them.
      # `--check` parses without executing: no network, no DOM, no runtime.
      site-assets =
        pkgs.runCommand "site-assets" {
          nativeBuildInputs = [pkgs.nodejs];
        } ''
          for f in ${../lib/site/aki.js} ${../lib/site/kg.js} ${../lib/delphi/juno.js}; do
            node --check "$f"
            echo "parsed $(basename "$f")"
          done
          touch $out
        '';

      # --- the knob registry describes code that exists ----------------------
      # modules.toml is hand-written, so it will drift; what it can be denied is
      # drifting silently. Every entry must name a real file, that file must
      # declare a toggle, and every host it claims must be in the inventory —
      # the three ways a stale registry misleads someone reading the docs page.
      knobs = let
        registry = ../modules.toml |> builtins.readFile |> builtins.fromTOML;
        entries = registry.knobs;
        ids = entries |> builtins.attrNames;
        pathOf = id: ../. + "/${entries.${id}.path}";
        missingPath = ids |> builtins.filter (id: !(id |> pathOf |> builtins.pathExists));
        readable = ids |> builtins.filter (id: id |> pathOf |> builtins.pathExists);
        noToggle = readable |> builtins.filter (id: !(id |> pathOf |> builtins.readFile |> lib.hasInfix "mkEnableOption"));
        unknownHosts = id: entries.${id}.hosts |> builtins.filter (h: !(hostInventory |> builtins.hasAttr h));
        badHosts = ids |> builtins.filter (id: unknownHosts id != []);
        countDrift = (registry.metadata.total_knobs or (ids |> builtins.length)) != (ids |> builtins.length);
        problems =
          lib.optional (missingPath != []) "paths that do not exist: ${missingPath |> lib.concatStringsSep ", "}"
          # `noToggle` is reported, not fatal: a knob may be nixpkgs' own option
          # (`programs.steam.enable`) whose declaration lives outside this tree.
          ++ lib.optional (badHosts != []) "knobs naming hosts the inventory does not have: ${badHosts |> lib.concatStringsSep ", "}"
          ++ lib.optional countDrift "metadata.total_knobs disagrees with the ${ids |> builtins.length |> toString} entries";
      in
        if problems != []
        then
          builtins.throw ''
            modules.toml drifted from the tree:
              ${problems |> lib.concatStringsSep "\n  "}
            Fix the registry in the same commit as the module, not later.''
        else
          pkgs.runCommand "knobs-ok" {} ''
            echo "knobs: ${ids |> builtins.length |> toString} entries, every path exists, every host resolves; ${readable |> lib.subtractLists noToggle |> builtins.length |> toString} of them point at a file that declares the toggle${lib.optionalString (noToggle != []) ", ${noToggle |> builtins.length |> toString} are wired to an option declared elsewhere: ${noToggle |> lib.concatStringsSep ", "}"}" > $out
          '';

      registry-schema = let
        schema = import ../lib/registry-schema.nix;
        inherit ((../modules.toml |> builtins.readFile |> builtins.fromTOML)) knobs;
        ids = knobs |> builtins.attrNames;
        checkNames = (import ./check-inventory.nix).byName |> builtins.attrNames;
        inherit ((../inventory.toml |> builtins.readFile |> builtins.fromTOML)) hosts;
        hostNames = hosts |> builtins.attrNames;

        kebab = "[a-z0-9]+(-[a-z0-9]+)*";
        parts = option: lib.splitString "." option;
        leafOf = option: let
          ps = parts option;
        in
          if lib.last ps == "enable"
          then lib.elemAt ps (builtins.length ps - 2)
          else lib.last ps;

        pathProblems =
          ids
          |> map (
            id: let
              entry = knobs.${id};
            in
              if schema.knobPathExceptions |> builtins.hasAttr id
              then
                if entry.path == schema.knobPathExceptions.${id}
                then null
                else "${id}: recorded exception is ${schema.knobPathExceptions.${id}}, registry says ${entry.path}"
              else if schema.knobPathRoots |> lib.any (root: lib.hasPrefix root entry.path)
              then null
              else "${id}: ${entry.path} is outside ${schema.knobPathRoots |> lib.concatStringsSep " or "} and is not recorded in lib/registry-schema.nix"
          )
          |> builtins.filter (p: p != null);

        optionOf = id: knobs.${id}.option;
        casingProblems =
          (
            ids
            |> map (
              id: let
                option = optionOf id;
                leaf = leafOf option;
              in
                if builtins.elem option schema.optionCasingExceptions
                then null
                else if builtins.match kebab leaf != null
                then null
                else "${id}: option ${option} has a non-kebab leaf '${leaf}'"
            )
            |> builtins.filter (p: p != null)
          )
          ++ (
            schema.optionCasingExceptions
            |> map (
              option:
                if ids |> builtins.any (id: optionOf id == option)
                then null
                else "${option} is recorded as a casing exception but no knob uses it"
            )
            |> builtins.filter (p: p != null)
          );

        prosePort = id: let
          m = (knobs.${id}.description or "") |> builtins.match ".*:([0-9]{4,5}).*";
        in
          if m == null
          then null
          else builtins.head m;
        declaredPort = id: knobs.${id}.port or null;
        prosePorts = ids |> builtins.filter (id: prosePort id != null);
        allPorts = ids |> map declaredPort |> builtins.filter (p: p != null);
        duplicated = allPorts |> builtins.filter (p: (allPorts |> lib.count (q: q == p)) > 1);
        portProblems =
          (
            prosePorts
            |> builtins.filter (id: declaredPort id != null && builtins.toString (declaredPort id) != prosePort id)
            |> map (id: "${id}: description names :${prosePort id} but port = ${builtins.toString (declaredPort id)}")
          )
          ++ (
            prosePorts
            |> builtins.filter (id: declaredPort id == null)
            |> map (id: "${id}: description names :${prosePort id} but the entry has no port field")
          )
          ++ lib.optional (duplicated != []) "ports claimed twice: ${duplicated |> lib.unique |> map builtins.toString |> lib.concatStringsSep ", "}";

        seg = n: lib.splitString ":" n;
        families =
          checkNames
          |> builtins.filter (n: (seg n |> builtins.length) > 2)
          |> map (n: lib.elemAt (seg n) 1)
          |> lib.unique;
        duplicateRows =
          checkNames
          |> builtins.filter (n: (checkNames |> lib.count (m: m == n)) > 1)
          |> lib.unique;
        familyProblems =
          (
            schema.umbrellaFamilies
            |> builtins.filter (f: !(builtins.elem (lib.removePrefix "checks:" f) families))
            |> map (f: "${f} is recorded as an umbrella in lib/registry-schema.nix but has no member rows")
          )
          ++ lib.optional (duplicateRows != []) "rows listed twice: ${duplicateRows |> lib.concatStringsSep ", "}";

        inventoryProblems =
          hostNames
          |> builtins.filter (h: hosts.${h} ? managed && builtins.typeOf hosts.${h}.managed != "bool")
          |> map (h: "${h}: managed must be a boolean when present, got ${builtins.typeOf hosts.${h}.managed}");
        managedAbsent = hostNames |> lib.count (h: !(hosts.${h} ? managed));

        # .sops.yaml — the fourth registry; exceptions: lib/registry-schema.nix
        sopsYaml = ../.sops.yaml |> builtins.readFile;
        tokens = pattern:
          sopsYaml
          |> builtins.split pattern
          |> builtins.filter builtins.isList
          |> map builtins.head;
        anchorNames = tokens "&([A-Za-z0-9_-]+)" |> lib.unique;
        refNames = tokens "\\*([A-Za-z0-9_-]+)" |> lib.unique;
        sopsProblems =
          (
            anchorNames
            |> builtins.filter (a: !(builtins.elem a refNames) && !(builtins.elem a schema.sopsAnchorExceptions))
            |> map (a: ".sops.yaml anchor &${a} is referenced by no group — record it in lib/registry-schema.nix or delete the key")
          )
          ++ (
            refNames
            |> builtins.filter (r: !(builtins.elem r anchorNames))
            |> map (r: ".sops.yaml references *${r} but keys: defines no &${r} anchor")
          )
          ++ (
            schema.sopsAnchorExceptions
            |> builtins.filter (a: !(builtins.elem a anchorNames) || builtins.elem a refNames)
            |> map (a: "sopsAnchorExceptions records ${a} but the anchor is ${
              if builtins.elem a refNames
              then "referenced by a group"
              else "not defined"
            }")
          );

        problems = pathProblems ++ casingProblems ++ portProblems ++ familyProblems ++ inventoryProblems ++ sopsProblems;
      in
        if problems != []
        then
          builtins.throw ''
            a registry broke its schema (lib/registry-schema.nix):
              ${problems |> lib.concatStringsSep "\n  "}
            Fix the registry, or record the departure in the schema with a reason.''
        else
          pkgs.runCommand "registry-schema" {} ''
            echo "registry schema: ${ids |> builtins.length |> toString} knobs (${prosePorts |> builtins.length |> toString} ports as data), ${checkNames |> builtins.length |> toString} check rows, ${hostNames |> builtins.length |> toString} hosts (${toString managedAbsent} leave managed at its default), ${anchorNames |> builtins.length |> toString} sops anchors" > $out
          '';

      # --- living documents have budgets (SCHEMA.md §2) ---------------------
      # One implementation: scripts/task/docs-budget.sh, the same script
      # `task ops:docs:budget` runs and the same gate the CI `hygiene` job
      # builds on every push. The budgets used to live here *and* in the task,
      # and they disagreed by one line (`wc -l` vs a split); running the script
      # over the flake source removes the second copy, so a document exactly at
      # its budget cannot pass one surface and fail the other.
      docs-budget = pkgs.runCommand "docs-budget" {} ''
        cd ${../.}
        bash scripts/task/docs-budget.sh
        touch $out
      '';

      # The machine-checkable half of the unslop vocabulary. Same script
      # `task checks:prose` runs, and the same CI job as docs-budget: prose is
      # exactly the class of change that arrives with no host to build.
      prose-tells = pkgs.runCommand "prose-tells" {} ''
        cd ${../.}
        bash scripts/task/prose-tells.sh
        touch $out
      '';
    }
)
