{
  lib,
  systems,
  pkgsFor,
  self,
  hostInventory,
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
      policyFailing = builtins.filter (id: !policiesCtl.policies.${id}.holds && !(policySoft id)) policiesCtl.ids;
      policySoftFailing = builtins.filter (id: !policiesCtl.policies.${id}.holds && policySoft id) policiesCtl.ids;
      policyFailures = epistemicsCtl.overturns policyFailing;
      softReport =
        lib.concatMapStrings (
          id: ''
            ~ ${id} (soft) — ${policiesCtl.policies.${id}.detail}
          ''
        )
        policySoftFailing;
      policyOverturned = builtins.filter (id: epistemicsCtl.overrides ? ${id}) policyFailing;
      policyReport =
        lib.concatMapStrings (
          id: ''
            ✗ ${id} — ${policiesCtl.policies.${id}.rule}
               proof: ${policiesCtl.policies.${id}.proof}
               now:   ${policiesCtl.policies.${id}.detail}
               if a declared epistemic fact shows this rule protects nothing here, record it
               in `.#epistemics.overrides` with its `because` and `evidence` — a fact may
               overturn a judgment, a convenience may not.
          ''
        )
        policyFailures;
      overturnIssues = lib.concatMap (id: let
        o = epistemicsCtl.overrides.${id};
      in
        lib.optional (!(builtins.elem id policiesCtl.ids)) "epistemics.overrides.${id} names no policy — a dead override is a silenced gate"
        ++ lib.optional (o.because or "" == "") "epistemics.overrides.${id}.because is empty — say what the rule fails to protect"
        ++ lib.optional (o.evidence or "" == "") "epistemics.overrides.${id}.evidence is empty — an override without evidence is a preference"
        ++ lib.optional (!(o ? since)) "epistemics.overrides.${id}.since is missing (the date the fact was established)")
      (builtins.attrNames epistemicsCtl.overrides);
      overturnReport =
        lib.concatMapStrings (
          id: ''
            ⇢ ${id} overturned — ${epistemicsCtl.overrides.${id}.because}
               evidence: ${epistemicsCtl.overrides.${id}.evidence} (${epistemicsCtl.overrides.${id}.since})
          ''
        )
        policyOverturned;
      dangling = map (c: "${c.doc} -> ${c.id}") policiesCtl.danglingCitations;
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
        named = builtins.length (builtins.attrNames self.modules);
        problems =
          lib.optional (leaves != reg.count)
          ".#nixFiles names ${toString leaves} files, the walk found ${toString reg.count} — a name collision dropped one"
          ++ map (n: "duplicate module name: ${n}") reg.duplicates
          ++ lib.optional (named != reg.modules)
          ".#modules has ${toString named} names for ${toString reg.modules} files under modules/ — a duplicate collapsed two"
          ++ map (n: ''self.modules."${n}" names no file under modules/'') reg.unknownNames;
      in
        if problems != []
        then builtins.throw "nix file registry is inconsistent:\n  ${lib.concatStringsSep "\n  " problems}"
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
        then builtins.throw "epistemics override is not a fact (flake/epistemics.nix):\n  ${lib.concatStringsSep "\n  " overturnIssues}"
        else if policyFailures != []
        then builtins.throw "policy violated:\n${policyReport}"
        else if dangling != []
        then builtins.throw "a doc cites a policy that does not exist:\n  ${lib.concatStringsSep "\n  " dangling}"
        else if policiesCtl.uncitedPolicies != []
        then builtins.throw "a policy is enforced but no document cites it (invisible gate):\n  ${lib.concatStringsSep "\n  " policiesCtl.uncitedPolicies}"
        else if unenforced != []
        then builtins.throw "HARD RULE without a [[flake/policies.nix#id]] citation — state the rule in the registry and cite it, or delete it:\n  ${lib.concatStringsSep "\n  " unenforced}"
        # The classification table is the policy layer's error output: a class
        # the page declares but no policy holds is a class that will be patched
        # ad hoc next time.
        else if classIssues != []
        then builtins.throw "the error-classification table and docs/issue-classes.md disagree:\n  ${lib.concatStringsSep "\n  " classIssues}"
        else
          pkgs.runCommand "policies" {}
          (''
              echo "${toString (builtins.length policiesCtl.ids)} policies hold; every citation resolves; every id is cited"
              printf '%s\n' ${lib.escapeShellArg (lib.concatStringsSep "\n" policiesCtl.errorClasses.report)}
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
              ${lib.concatStringsSep "\n  " self.inventory.issues}
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
        expectedUrls = map (n: registryCache.caches.${n}.url) registryCache.evalOrder;
        expectedKeys = builtins.filter (k: k != null) (map (n: registryCache.caches.${n}.key) registryCache.evalOrder);
        drift =
          lib.subtractLists expectedUrls flakeCache.extra-substituters
          ++ lib.subtractLists flakeCache.extra-substituters expectedUrls
          ++ lib.subtractLists expectedKeys flakeCache.extra-trusted-public-keys
          ++ lib.subtractLists flakeCache.extra-trusted-public-keys expectedKeys;
      in
        assert drift == [] || throw "flake.nix nixConfig and lib/cache-registry.nix disagree: ${builtins.toString drift}";
          pkgs.runCommand "cache-registry" {} ''
            echo "flake.nix nixConfig matches lib/cache-registry.nix (${toString (builtins.length expectedUrls)} substituters, ${toString (builtins.length expectedKeys)} keys)"
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
        declaredSources = builtins.attrNames epistemicsCtl.sources;
        badSettles =
          lib.concatMap (
            n: map (k: "${n}.settles names unknown kind '${k}'") (builtins.filter (k: !(builtins.elem k knownKinds)) epistemicsCtl.sources.${n}.settles)
          )
          declaredSources;
        badStanding = builtins.filter (n: !(builtins.elem epistemicsCtl.sources.${n}.standing ["authored" "snapshot" "unvetted"])) declaredSources;
        unreadable = builtins.filter (k: epistemicsCtl.table.${k}.read == null) knownKinds;
        unlisted =
          lib.subtractLists declaredSources epistemicsCtl.sourceIds
          ++ lib.subtractLists epistemicsCtl.sourceIds declaredSources;
        # A route is a transport: it must say how to use it, what it spends, whose
        # quota that is, and whether it may be fanned out. An unlabelled route is
        # how a metered surface gets used by accident.
        routeIssues = lib.concatMap (n: let
          rts = epistemicsCtl.sources.${n}.routes;
        in
          lib.concatMap (r: let
            rt = rts.${r};
          in
            lib.optional (rt.how or "" == "") "${n}.routes.${r}.how is empty — a route nobody can invoke"
            ++ lib.optional (!(rt ? cost) || rt.cost <= 0) "${n}.routes.${r}.cost must be a positive token count"
            ++ lib.optional (!(builtins.elem (rt.metered or "") ["none" "upstream" "quota" "paid"])) "${n}.routes.${r}.metered must be none/upstream/quota/paid"
            ++ lib.optional (!(rt ? fanout) || !builtins.isBool rt.fanout) "${n}.routes.${r}.fanout must be a bool (may it be asked many times at once?)"
            ++ lib.optional (!(rt ? offline) || !builtins.isBool rt.offline) "${n}.routes.${r}.offline must be a bool")
          (builtins.attrNames rts))
        declaredSources;
        # A measured `p` without the sentence that measured it is a number with
        # no provenance, which is the thing this file exists to stop.
        spendIssues = lib.concatMap (n: let
          rows = epistemicsCtl.spend.${n};
        in
          lib.optional (!(builtins.elem n declaredSources)) "spend.${n} names an undeclared source"
          ++ lib.concatMap (k: let
            row = rows.${k};
          in
            lib.optional (!(builtins.elem k knownKinds)) "spend.${n}.${k} names an unknown claim kind"
            ++ lib.optional (row.measured or "" == "") "spend.${n}.${k}.p has no `measured` — an unmeasured probability is what this replaces"
            ++ lib.optional (row.p <= 0.0 || row.p > 1.0) "spend.${n}.${k}.p must be in (0,1]")
          (builtins.attrNames rows))
        (builtins.attrNames epistemicsCtl.spend);
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
        persistIssues = map (k: "${k}.persist is empty — an answer with nowhere to live is researched forever") epistemicsCtl.persistable;
        evIssues =
          lib.concatMap (
            t: let
              e = epistemicsCtl.evidence.${t};
            in
              lib.optional (!(e ? rank) || !(builtins.isInt e.rank) || e.rank < 0) "evidence.${t}.rank must be a non-negative integer"
              ++ lib.optional (e.what or "" == "") "evidence.${t}.what is empty"
              ++ lib.optional (e.cannot or "" == "") "evidence.${t}.cannot is empty — say what the tier does not prove"
              ++ lib.optional (e.promote or "" == "") "evidence.${t}.promote is empty — say what would raise it"
              ++ lib.optional (!(builtins.elem (e.producedBy or "") ["person" "compiler" "machine"])) "evidence.${t}.producedBy must be person/compiler/machine"
          )
          epistemicsCtl.evidenceIds
          ++ map (t: "evidence.${t} is not in evidenceIds — the ladder has no order") (
            lib.subtractLists epistemicsCtl.evidenceIds (builtins.attrNames epistemicsCtl.evidence)
          )
          ++ map (t: "evidenceIds names '${t}', which is not a declared tier") (
            lib.subtractLists (builtins.attrNames epistemicsCtl.evidence) epistemicsCtl.evidenceIds
          )
          ++ (
            let
              ranks = map (t: epistemicsCtl.evidence.${t}.rank) epistemicsCtl.evidenceIds;
            in
              lib.optional (builtins.length (lib.unique ranks) != builtins.length ranks) "two evidence tiers share a rank — a ladder with a rung missing"
          );
        floorIssues = map (k: "kinds.${k}.evidenceFloor '${toString epistemicsCtl.kinds.${k}.evidenceFloor}' is not a declared evidence tier") (
          builtins.filter (k: !(builtins.hasAttr epistemicsCtl.kinds.${k}.evidenceFloor epistemicsCtl.evidence)) knownKinds
        );
        noteClaimIssues = map (k: "noteClaims maps a note kind to '${k}', which flake/epistemics.nix does not declare") (
          lib.subtractLists knownKinds (lib.unique (builtins.attrValues epistemicsCtl.noteClaims))
        );
        carryIssues =
          lib.optional (epistemicsCtl.carries "decision" "extracted") "an extracted match must not carry a decision"
          ++ lib.optional (!(epistemicsCtl.carries "decision" "asserted")) "an authored decision must be allowed — the ladder is inverted"
          ++ lib.optional (epistemicsCtl.carries "fleet-fact" "extracted") "a token match must not carry a compiled fleet fact"
          ++ lib.optional (!(epistemicsCtl.carries "fleet-fact" "resolved")) "a resolved lookup must carry a fleet fact";
        issues =
          badSettles
          ++ map (n: "${n}.standing is not authored/snapshot/unvetted") badStanding
          ++ map (k: "no declared source may settle '${k}' — every kind needs an authority, even if it is 'ask a person'") unreadable
          ++ map (n: "${n} is missing from sourceIds (or declared twice) — ordering would be undefined") unlisted
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
        then builtins.throw "epistemics table is inconsistent (flake/epistemics.nix):\n  ${lib.concatStringsSep "\n  " issues}"
        else
          pkgs.runCommand "epistemics" {} ''
            echo "epistemics: ${toString (builtins.length declaredSources)} sources x ${toString (builtins.length knownKinds)} claim kinds, every kind settled and persistable, every route labelled, the evidence ladder ordered, Kelly sign correct"
            touch $out
          '';

      # flake/ontology.nix
      ontology = let
        g = knowledgeGraphCtl.graph;
        nodeTypes = lib.unique (map (n: n.type) g.nodes);
        edgeTypes = lib.unique (map (e: e.type) g.edges);
        declaredEntities = ontologyCtl.entityIds;
        declaredRelations = ontologyCtl.relationIds;
        nodeTypeIssues =
          map (t: "the graph emits node type '${t}' that no entity declares") (lib.subtractLists declaredEntities nodeTypes)
          ++ map (t: "entity '${t}' is declared but the graph emits no node of that type") (lib.subtractLists nodeTypes declaredEntities);
        edgeTypeIssues =
          map (t: "the graph emits edge type '${t}' that no relation declares") (lib.subtractLists declaredRelations edgeTypes)
          ++ map (t: "relation '${t}' is declared but the graph emits no edge of that type") (lib.subtractLists edgeTypes declaredRelations);
        fieldIssues = lib.concatMap (n: let
          carried = builtins.attrNames (builtins.removeAttrs n ["id" "type"]);
          extra = lib.subtractLists ontologyCtl.entities.${n.type}.fields carried;
        in
          map (f: "node ${n.id} carries field '${f}' that ${n.type}.fields does not declare") extra)
        g.nodes;
        badEdges = builtins.filter (e: !(ontologyCtl.admit e).ok) g.edges;
        edgeIssues = map (e: "edge ${e.from} -${e.type}-> ${e.to}: ${(ontologyCtl.admit e).why}") badEdges;
        noteNodes = builtins.filter (n: n.type == "note") g.nodes;
        noteClaimIssues =
          map (n: "note ${n.id} carries no claim kind — every note is a claim (flake/epistemics.nix noteClaims)") (
            builtins.filter (n: (n.claim or null) == null) noteNodes
          )
          ++ map (n: "note ${n.id} carries claim '${n.claim}', which flake/epistemics.nix does not declare") (
            builtins.filter (
              n: let
                c = n.claim or null;
              in
                c != null && !(builtins.elem c epistemicsCtl.kindIds)
            )
            noteNodes
          )
          ++ map (n: "note ${n.id} is classified '${n.claim}' and a note is an assertion — that tier cannot carry the kind") (
            builtins.filter (
              n: let
                c = n.claim or null;
              in
                c != null && builtins.elem c epistemicsCtl.kindIds && !(epistemicsCtl.carries c "asserted")
            )
            noteNodes
          );
        claimIssues = lib.concatMap (t:
          map (k: "${t}.claims names claim kind '${k}' that flake/epistemics.nix does not declare")
          (builtins.filter (k: !(builtins.elem k epistemicsCtl.kindIds)) ontologyCtl.entities.${t}.claims))
        declaredEntities;
        sinkRoute = s: ontologyCtl.sinks.${s}.route or "";
        sinkWhy = s: ontologyCtl.sinks.${s}.why or "";
        kindIssues =
          map (k: "claim kind '${k}' is stable but has no entity home and no declared sink") ontologyCtl.unhomed
          ++ map (k: "claim kind '${k}' is stable and only a sink holds it — give it an entity home, or a sink can substitute for one forever") ontologyCtl.sinkOnly
          ++ map (k: "sink '${k}' names no claim kind") ontologyCtl.straySinks
          ++ map (s: "sink '${s}' declares kind '${ontologyCtl.sinks.${s}.kind}', not one of none|external") (
            builtins.filter (s: !(builtins.elem ontologyCtl.sinks.${s}.kind ["none" "external"])) ontologyCtl.sinkIds
          )
          ++ map (s: "sink '${s}' has an empty where — a home nobody can find") (
            builtins.filter (s: ontologyCtl.sinks.${s}.where == "") ontologyCtl.sinkIds
          )
          ++ map (s: "sink '${s}' has an empty why — say why this repository cannot hold the kind") (
            builtins.filter (s: sinkWhy s == "") ontologyCtl.sinkIds
          )
          ++ map (s: "sink '${s}' names route '${sinkRoute s}', which flake/epistemics.nix does not declare") (
            builtins.filter (s: !(builtins.elem (sinkRoute s) epistemicsCtl.sourceIds)) ontologyCtl.sinkIds
          );
        bareNotes = import ../lib/agents-notes.nix {inherit lib;};
        claimParity = let
          bare = bareNotes.counts.byClaim;
          compiled = agentsNotesCtl.counts.byClaim;
          keys = lib.unique (builtins.attrNames bare ++ builtins.attrNames compiled);
          unclassified = builtins.filter (id: (bareNotes.index.${id}.claim or null) == null) (builtins.attrNames bareNotes.index);
        in
          lib.optional (!(builtins.all (k: (bare.${k} or 0) == (compiled.${k} or 0)) keys))
          "a bare lib/agents-notes.nix import reports claim counts ${builtins.toJSON bare} where the compiled projection reports ${builtins.toJSON compiled} — the site renders the bare one"
          ++ map (id: "note ${id} has no claim kind without an explicit claimOf — a surface importing the module bare would show it unclassified") unclassified;
        claimRowIssues =
          lib.optional ((builtins.foldl' (n: r: n + r.notes) 0 agentsNotesCtl.claimRows) != agentsNotesCtl.counts.total)
          "the claim rows do not sum to the note total — a renderer reading them would show a partial table"
          ++ lib.optional ((builtins.foldl' (n: r: n + r.open) 0 agentsNotesCtl.claimRows) != agentsNotesCtl.counts.open)
          "the claim rows do not sum to the open note count";
        noteIds = builtins.attrNames agentsNotesCtl.notes;
        sliceLinkIssues = lib.concatMap (
          n:
            map (t: "note ${n.id} links '${t}', which has no slice — the lineage button on its page would 404")
            (builtins.filter (t: !(builtins.elem t noteIds)) (n.from ++ n.supersedes ++ n.replacedBy ++ n.descendants))
        ) (builtins.attrValues agentsNotesCtl.notes);
        recordedCount = builtins.length (builtins.filter (e: e ? evidence) g.edges);
        recordIssues = lib.optional (recordedCount == 0) "no edge records its own evidence — the per-edge tier is declared but nothing uses it";
        citationIssues = map (c: "citation ${c} names a policy id flake/policies.nix does not declare — the graph drops the edge, so name the rule or drop the citation") knowledgeGraphCtl.unresolvedCitations;
        tierIssues = map (r: "relation '${r}' has tier '${ontologyCtl.relations.${r}.tier}' that is not declared") (
          builtins.filter (r: !(builtins.hasAttr ontologyCtl.relations.${r}.tier ontologyCtl.tiers)) declaredRelations
        );
        sparseIssues =
          lib.concatMap (t: let
            e = ontologyCtl.entities.${t};
          in
            lib.optional (e.what == "") "${t}.what is empty"
            ++ lib.optional (e.identity == "") "${t}.identity is empty — say what makes two of these the same thing"
            ++ lib.optional (e.member == "") "${t}.member is empty — name the compiled source that enumerates membership"
            ++ lib.optional (e.fields == []) "${t}.fields is empty")
          declaredEntities
          ++ lib.concatMap (r: let
            x = ontologyCtl.relations.${r};
          in
            lib.optional (x.evidence == "") "${r}.evidence is empty — a relation with no evidence is a guess"
            ++ lib.optional (x.cannot == "") "${r}.cannot is empty — say what the edge does not prove"
            ++ lib.optional (x.from == [] || x.to == []) "${r} declares no domain or range")
          declaredRelations;
        issues = nodeTypeIssues ++ edgeTypeIssues ++ fieldIssues ++ edgeIssues ++ noteClaimIssues ++ claimIssues ++ claimParity ++ claimRowIssues ++ sliceLinkIssues ++ kindIssues ++ recordIssues ++ citationIssues ++ tierIssues ++ sparseIssues;
        nodeCount = builtins.length g.nodes;
        edgeCount = builtins.length g.edges;
        entityCount = builtins.length declaredEntities;
        relationCount = builtins.length declaredRelations;
      in
        if issues != []
        then builtins.throw "the graph is not an instance of its ontology (flake/ontology.nix):\n  ${lib.concatStringsSep "\n  " issues}"
        else
          pkgs.runCommand "ontology" {} ''
            echo "ontology: ${toString entityCount} entities x ${toString relationCount} relations, ${toString nodeCount} nodes / ${toString edgeCount} edges (${toString recordedCount} record their own tier), every edge admitted, every citation resolves, every field declared, every stable claim kind homed, every sink routed, every note classified — on a bare import too"
            touch $out
          '';

      router-labels = let
        dir = ../.agents/skills/router;
        labels = builtins.attrNames (builtins.fromJSON (builtins.readFile (dir + "/assets/labels.json")));
        rows = map builtins.head (
          builtins.filter (m: m != null) (
            map (builtins.match "\\|[[:space:]]*`([a-z]+(-[a-z]+)*)`.*") (lib.splitString "\n" (builtins.readFile (dir + "/references/playbooks.md")))
          )
        );
        missing = lib.subtractLists rows labels;
        orphans = lib.subtractLists labels rows;
        repeated = lib.subtractLists (lib.unique rows) rows;
        unknownTasks = map (t: "playbook row runs 'task ${t}', which no taskfile declares") knowledgeGraphCtl.routerUnknown;
        issues =
          map (l: "label '${l}' has no row in references/playbooks.md") missing
          ++ map (s: "row '${s}' has no label in assets/labels.json") orphans
          ++ map (s: "'${s}' appears in more than one row") (lib.unique repeated)
          ++ unknownTasks;
      in
        if issues != []
        then builtins.throw "the router's labels and playbooks disagree:\n  ${lib.concatStringsSep "\n  " issues}"
        else
          pkgs.runCommand "router-labels" {} ''
            echo "router: ${toString (builtins.length labels)} labels, each with exactly one playbook row"
            touch $out
          '';

      task-descs = let
        undescribed = builtins.filter (n: taskList.${n}.desc == "" && !taskList.${n}.hasSummary) (builtins.attrNames taskList);
        issues = map (n: "task '${n}' has no desc and no summary — invisible in both `task --list` and --list-all --json") undescribed;
      in
        if issues != []
        then builtins.throw "the task surface hides tasks:\n  ${lib.concatStringsSep "\n  " issues}"
        else
          pkgs.runCommand "task-descs" {} ''
            echo "task-descs: ${toString (builtins.length (builtins.attrNames taskList))} tasks, each visible to a person or to an agent"
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
        registry = builtins.fromTOML (builtins.readFile ../modules.toml);
        entries = registry.knobs;
        ids = builtins.attrNames entries;
        pathOf = id: ../. + "/${entries.${id}.path}";
        missingPath = builtins.filter (id: !(builtins.pathExists (pathOf id))) ids;
        readable = builtins.filter (id: builtins.pathExists (pathOf id)) ids;
        noToggle = builtins.filter (id: !(lib.hasInfix "mkEnableOption" (builtins.readFile (pathOf id)))) readable;
        unknownHosts = id: builtins.filter (h: !(builtins.hasAttr h hostInventory)) entries.${id}.hosts;
        badHosts = builtins.filter (id: unknownHosts id != []) ids;
        countDrift = (registry.metadata.total_knobs or (builtins.length ids)) != builtins.length ids;
        problems =
          lib.optional (missingPath != []) "paths that do not exist: ${lib.concatStringsSep ", " missingPath}"
          # `noToggle` is reported, not fatal: a knob may be nixpkgs' own option
          # (`programs.steam.enable`) whose declaration lives outside this tree.
          ++ lib.optional (badHosts != []) "knobs naming hosts the inventory does not have: ${lib.concatStringsSep ", " badHosts}"
          ++ lib.optional countDrift "metadata.total_knobs disagrees with the ${toString (builtins.length ids)} entries";
      in
        if problems != []
        then
          builtins.throw ''
            modules.toml drifted from the tree:
              ${lib.concatStringsSep "\n  " problems}
            Fix the registry in the same commit as the module, not later.''
        else
          pkgs.runCommand "knobs-ok" {} ''
            echo "knobs: ${toString (builtins.length ids)} entries, every path exists, every host resolves; ${toString (builtins.length (lib.subtractLists noToggle readable))} of them point at a file that declares the toggle${lib.optionalString (noToggle != []) ", ${toString (builtins.length noToggle)} are wired to an option declared elsewhere: ${lib.concatStringsSep ", " noToggle}"}" > $out
          '';

      registry-schema = let
        schema = import ../lib/registry-schema.nix;
        knobs = (builtins.fromTOML (builtins.readFile ../modules.toml)).knobs;
        ids = builtins.attrNames knobs;
        checks = (builtins.fromTOML (builtins.readFile ../taskfiles/checks.toml)).check;
        checkNames = map (r: r.name) checks;
        hosts = (builtins.fromTOML (builtins.readFile ../inventory.toml)).hosts;
        hostNames = builtins.attrNames hosts;

        kebab = "[a-z0-9]+(-[a-z0-9]+)*";
        parts = option: lib.splitString "." option;
        leafOf = option: let
          ps = parts option;
        in
          if lib.last ps == "enable"
          then lib.elemAt ps (builtins.length ps - 2)
          else lib.last ps;

        pathProblems = builtins.filter (p: p != null) (map (
            id: let
              entry = knobs.${id};
            in
              if builtins.hasAttr id schema.knobPathExceptions
              then
                if entry.path == schema.knobPathExceptions.${id}
                then null
                else "${id}: recorded exception is ${schema.knobPathExceptions.${id}}, registry says ${entry.path}"
              else if lib.any (root: lib.hasPrefix root entry.path) schema.knobPathRoots
              then null
              else "${id}: ${entry.path} is outside ${lib.concatStringsSep " or " schema.knobPathRoots} and is not recorded in lib/registry-schema.nix"
          )
          ids);

        optionOf = id: knobs.${id}.option;
        casingProblems =
          builtins.filter (p: p != null) (map (
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
            ids)
          ++ builtins.filter (p: p != null) (map (
              option:
                if builtins.any (id: optionOf id == option) ids
                then null
                else "${option} is recorded as a casing exception but no knob uses it"
            )
            schema.optionCasingExceptions);

        prosePort = id: let
          m = builtins.match ".*:([0-9]{4,5}).*" (knobs.${id}.description or "");
        in
          if m == null
          then null
          else builtins.head m;
        declaredPort = id: knobs.${id}.port or null;
        prosePorts = builtins.filter (id: prosePort id != null) ids;
        allPorts = builtins.filter (p: p != null) (map declaredPort ids);
        duplicated = builtins.filter (p: builtins.length (builtins.filter (q: q == p) allPorts) > 1) allPorts;
        portProblems =
          map (id: "${id}: description names :${prosePort id} but port = ${builtins.toString (declaredPort id)}")
          (builtins.filter (id: declaredPort id != null && builtins.toString (declaredPort id) != prosePort id) prosePorts)
          ++ map (id: "${id}: description names :${prosePort id} but the entry has no port field")
          (builtins.filter (id: declaredPort id == null) prosePorts)
          ++ lib.optional (duplicated != []) "ports claimed twice: ${lib.concatStringsSep ", " (map builtins.toString (lib.unique duplicated))}";

        seg = n: lib.splitString ":" n;
        families = lib.unique (map (n: lib.elemAt (seg n) 1) (builtins.filter (n: builtins.length (seg n) > 2) checkNames));
        duplicateRows = lib.unique (builtins.filter (n: builtins.length (builtins.filter (m: m == n) checkNames) > 1) checkNames);
        familyProblems =
          map (f: "${f} is recorded as an umbrella in lib/registry-schema.nix but has no member rows")
          (builtins.filter (f: !(builtins.elem (lib.removePrefix "checks:" f) families)) schema.umbrellaFamilies)
          ++ lib.optional (duplicateRows != []) "rows listed twice: ${lib.concatStringsSep ", " duplicateRows}";

        inventoryProblems =
          map (h: "${h}: managed must be a boolean when present, got ${builtins.typeOf hosts.${h}.managed}")
          (builtins.filter (h: hosts.${h} ? managed && builtins.typeOf hosts.${h}.managed != "bool") hostNames);
        managedAbsent = builtins.length (builtins.filter (h: !(hosts.${h} ? managed)) hostNames);

        problems = pathProblems ++ casingProblems ++ portProblems ++ familyProblems ++ inventoryProblems;
      in
        if problems != []
        then
          builtins.throw ''
            a registry broke its schema (lib/registry-schema.nix):
              ${lib.concatStringsSep "\n  " problems}
            Fix the registry, or record the departure in the schema with a reason.''
        else
          pkgs.runCommand "registry-schema" {} ''
            echo "registry schema: ${toString (builtins.length ids)} knobs (${toString (builtins.length prosePorts)} ports as data), ${toString (builtins.length checkNames)} check rows, ${toString (builtins.length hostNames)} hosts (${toString managedAbsent} leave managed at its default)" > $out
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
