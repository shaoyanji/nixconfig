# flake/policies.nix — the rules the docs state, as predicates over the tree.
# Cite one as [[flake/policies.nix#id]] instead of restating it; `checks.policies`
# proves every `holds` and that every citation and id exists, in both directions.
{lib}: let
  root = ../.;
  read = p: builtins.readFile (root + "/${p}");
  has = p: needle: lib.hasInfix needle (read p);
  anyLine = p: pred: lib.any pred (lib.splitString "\n" (read p));

  # Top-level files of one directory with a suffix. No tree walk: walking the
  # root would copy the repository into the store just to list markdown.
  filesWithSuffix = dir: suffix:
    map (n:
      if dir == "."
      then n
      else "${dir}/${n}") (
      builtins.attrNames (
        lib.filterAttrs (n: t: t == "regular" && lib.hasSuffix suffix n) (builtins.readDir (root + "/${dir}"))
      )
    );

  taskfiles = filesWithSuffix "taskfiles" ".yml";
  shellScripts = filesWithSuffix "scripts/task" ".sh";

  # Every .nix under a directory, repo-relative. The systemd policies read the
  # modules that DECLARE units, which is a directory walk, not a top-level list.
  nixUnder = dir: let
    walk = d: let
      entries = builtins.readDir (root + "/${d}");
    in
      lib.concatMap (n: let
        rel =
          if d == "."
          then n
          else "${d}/${n}";
      in
        if entries.${n} == "directory"
        then walk rel
        else lib.optional (lib.hasSuffix ".nix" n) rel)
      (builtins.attrNames entries);
  in
    walk dir;

  # `systemd.services.<name> = …` blocks: from a declaration line to the next one,
  # so a `Restart` cannot borrow a neighbouring unit's classification.
  # A unit's attrset extent: from its declaration through the first following
  # non-comment line indented no deeper than the declaration itself. Indentation,
  # not "next declaration", because a partial override
  # (`systemd.services.<n>.serviceConfig = …`) and a block with no sibling after it
  # both otherwise swallow unrelated lines and report a `Restart` that belongs to
  # another unit — a false positive, which is worse than no gate.
  # --- library reads: the gate behind #library-content-is-not-scheduled ------
  # A library on a network mount is metadata to anything automatic. Deleting the
  # offender is not the gate; this predicate is.
  netMounts = ["/Volumes/data" "/mnt/burgernas"];
  contentExtractors = ["unsquashfs" "readelf"];
  unitHosts = nixUnder "modules" ++ nixUnder "hosts";
  libraryExtractors =
    builtins.filter
    (p: let
      t = read p;
    in
      lib.any (m: lib.hasInfix m t) netMounts
      && lib.any (r: lib.hasInfix r t) contentExtractors)
    (shellScripts ++ unitHosts);
  extractorNames = map (p: lib.removeSuffix ".sh" (builtins.baseNameOf p)) libraryExtractors;
  # The unit's own file never contains the extractor — it names the script — so
  # this is a name match against the scripts that do.
  scheduledLibraryExtractions =
    builtins.filter
    (p: let
      t = read p;
    in
      lib.hasInfix "systemd." t
      && lib.any (n: lib.hasInfix n t) extractorNames)
    unitHosts;
  # A library's bytes are pulled by a LAUNCH and by nothing else: no timer, no
  # login, no path unit watching for a fresh drop. A stale cache is flushed on
  # the next launch — that is cheap and user-initiated; warming ahead of it is a
  # LAN-wide congestion event nobody asked for.
  libraryPathWatchers =
    builtins.filter
    (p: let
      t = read p;
    in
      lib.any (m: lib.hasInfix m t) netMounts
      && (lib.hasInfix "systemd.paths" t || lib.hasInfix "systemd.user.paths" t))
    unitHosts;
  # Named explicitly so a revert cannot pass by having no unit at all.
  deletedLibraryIntegrators = builtins.filter (p: builtins.pathExists (root + "/${p}")) [
    "scripts/task/appimage-integrate.sh"
    "modules/scripts/appimage-integrate.nix"
    "modules/user/desktop/appimage-launchers.nix"
  ];

  indentOf = l: builtins.stringLength (builtins.head (builtins.match "([[:space:]]*).*" l));
  serviceBlocks = p: let
    lines = lib.splitString "\n" (read p);
    isStart = l: builtins.match "[[:space:]]*systemd\\.services\\.[A-Za-z0-9_.-]+ *=.*" l != null;
    isComment = l: builtins.match "[[:space:]]*#.*" l != null;
    isBlank = l: builtins.match "[[:space:]]*" l != null;
    indices = lib.range 0 (builtins.length lines - 1);
    starts = builtins.filter (i: isStart (builtins.elemAt lines i)) indices;
    endOf = i: let
      at = builtins.elemAt lines i;
      sibling =
        builtins.filter (
          j: j > i && !(isBlank (builtins.elemAt lines j)) && !(isComment (builtins.elemAt lines j)) && indentOf (builtins.elemAt lines j) <= indentOf at
        )
        indices;
    in
      if sibling == []
      then builtins.length lines
      else builtins.head sibling + 1;
  in
    if lines == []
    then []
    else map (i: lib.concatStringsSep "\n" (lib.sublist i (endOf i - i) lines)) starts;

  # Modules that declare systemd units are exactly the ones a hostname list may
  # not gate: a host file naming itself is that host's config, a shared module
  # naming hosts is a capability nobody declared.
  unitModules = builtins.filter (
    p:
      lib.hasInfix "systemd.services" (read p)
      || lib.hasInfix "systemd.user.services" (read p)
  ) (nixUnder "modules");
  # Every module, not only the ones that declare units: a package list or a tier
  # chosen by name is the same undeclared capability as a unit gated by name, and
  # it rots the moment a host is renamed, added or repurposed. Host files under
  # hosts/ are that host's own config and may say its name; a shared module may not.
  hostnameGatedModules =
    builtins.filter (
      p:
        anyLine p (l: builtins.match ".*builtins\\.elem hostName.*" l != null)
        || anyLine p (l: builtins.match ".*lib\\.elem hostName.*" l != null)
        || anyLine p (l: builtins.match ".*hostName ==.*" l != null)
        # `hostName != "frieren"` is the same list in the negative: a capability
        # nobody declared. The empty-string guard (`hostName != ""`, used to pick an
        # inventory entry) is not a hostname comparison and stays legal.
        || anyLine p (l: builtins.match ".*hostName *[!=]= *\"[^\"]+\".*" l != null)
    )
    (nixUnder "modules");
  hostnameGatedUnitModules = builtins.filter (p: builtins.elem p unitModules) hostnameGatedModules;
  unclassifiedDaemons =
    lib.concatMap (
      p:
        map (b: "${p}: ${lib.removeSuffix "\n" (builtins.head (lib.splitString "\n" b))}")
        (builtins.filter (b: lib.hasInfix "Restart" b && !(lib.hasInfix "X-Fleet-Role" b)) (serviceBlocks p))
    )
    (builtins.filter (p: builtins.pathExists (root + "/${p}")) (nixUnder "modules" ++ nixUnder "hosts"));

  # The normative documents: the ones allowed to state a rule. Skills are
  # procedure, deliberately out of scope (`.agents/SCHEMA.md` §4).
  normativeDocs = builtins.filter (d: builtins.pathExists (root + "/${d}")) [
    "AGENTS.md"
    "README.md"
    "MANUAL.md"
    "AUDIT.md"
    ".agents/SCHEMA.md"
    ".agents/README.md"
    "docs/ci-pipeline.md"
    "docs/nix-patterns.md"
    "docs/sops-rekey.md"
    "docs/storage-taxonomy.md"
    "taskfiles/README.md"
  ];

  # POSIX ERE, not PCRE: a literal `[` is `[[]`, so `[[` is `[[][[]`. An
  # anchored group is the only capture, which `builtins.split` requires.
  citationRe = "[[][[]flake.policies.nix#([A-Za-z0-9_-]+)]]";

  citations = lib.concatMap (doc: let
    text = read doc;
    groups = builtins.filter builtins.isList (builtins.split citationRe text);
  in
    map (g: {
      inherit doc;
      id = builtins.head g;
    })
    groups)
  normativeDocs;

  # A root markdown file is either one of the living documents or a pointer
  # stub. Anything else is a new document that belongs in `docs/`.
  knownRootMd = [
    "AGENTS.md"
    "ARCHITECTURE.md"
    "AUDIT.md"
    "EXPERIMENTS.md"
    "HANDOFF.md"
    "MANUAL.md"
    "README.md"
    "TODO.md"
  ];
  rootMd = filesWithSuffix "." ".md";
  strayRootMd = builtins.filter (f: !(builtins.elem f knownRootMd)) rootMd;

  rel = p: lib.removePrefix "${toString root}/" (toString p);

  # Position, not presence: a guard that runs after the expensive step is
  # decoration. An absent needle resolves to the whole file, so `before` is false
  # for a guard somebody deleted.
  offsetOf = p: needle: builtins.stringLength (builtins.head (lib.splitString needle (read p)));
  before = p: a: b:
    offsetOf p a
    < offsetOf p b
    && offsetOf p a < builtins.stringLength (read p);
  anyMatchingLine = p: re: lib.any (l: builtins.match re l != null) (lib.splitString "\n" (builtins.readFile p));

  # --- secrets: encrypted per VALUE, not per file ---------------------------
  # Counting one `ENC[` per file passes a file whose other keys were pasted in
  # plaintext. Position matters: everything before the `sops:` block is data,
  # everything after it is the metadata sops itself must read.
  indexOf = pred: xs: let
    go = i: rest:
      if rest == []
      then builtins.length xs
      else if pred (builtins.head rest)
      then i
      else go (i + 1) (builtins.tail rest);
  in
    go 0 xs;

  plaintextValues = file: let
    lines = lib.splitString "\n" (read file);
    cut = indexOf (l: lib.hasPrefix "sops:" l) lines;
    body = lib.take cut lines;
    meta = lib.drop cut lines;
    suffixHits = builtins.filter (l: lib.hasPrefix "unencrypted_suffix:" (lib.trim l)) meta;
    suffix =
      if suffixHits == []
      then null
      else lib.trim (lib.removePrefix "unencrypted_suffix:" (lib.trim (builtins.head suffixHits))); # Return the KEY, never the value: a gate error must not echo a secret.
    plainKey = l: let
      t = lib.trim l;
      m = builtins.match "([A-Za-z0-9_.-]+):[[:space:]]+(.+)" t;
    in
      if t == "" || lib.hasPrefix "#" t || m == null
      then null
      else
        (
          let
            key = builtins.elemAt m 0;
            value = lib.trim (builtins.elemAt m 1);
          in
            if !(lib.hasPrefix "ENC[" value) && !(suffix != null && lib.hasSuffix suffix key)
            then key
            else null
        );
  in
    builtins.filter (k: k != null) (map plainKey body);

  # The library's release table, read as data: a row that lands in an arch dir
  # without a pin downloads whichever asset eget feels like.
  library = import (root + "/tools/library.nix");
  unpinnedRows =
    lib.concatMap (
      name: let
        t = library.tools.${name};
        archDirs = builtins.filter (d: d != "appimages") t.dirs;
        missing = builtins.filter (d: !(t ? pick) || !(builtins.hasAttr d t.pick)) archDirs;
      in
        map (d: "${name}/${d}") missing
    )
    (builtins.attrNames library.tools);

  sopsFiles = [
    "modules/secrets.yaml"
    "modules/ssh-ca-key.yaml"
  ];
  plaintextSecrets = lib.concatMap (f: map (l: "${f}: ${l}") (plaintextValues f)) sopsFiles;

  # --- user access: one source of keys, no host-local key literals ----------
  # Not "no keys at all" — `config.ssh.authorizedKeys.keys` is the fleet's
  # break-glass list and every flake-managed host renders it. The rule is that
  # nobody *else* pastes a key: CA-signed certs are the access path, and a
  # second literal is how `authorized_keys` management creeps back.
  keySourceFiles = [
    "modules/config/authorized-keys.nix"
    "modules/ssh-ca.nix"
    "modules/profiles/nixbuild-client.nix"
  ];
  outOfScopeHosts = [
    "hosts/netbook/"
    "hosts/microvms/"
  ];
  ownKeyLiterals =
    builtins.filter (
      p: let
        r = rel p;
      in
        !(builtins.elem r keySourceFiles)
        && !(lib.any (h: lib.hasPrefix h r) outOfScopeHosts)
        && anyMatchingLine p ".*(ssh-ed25519|ssh-rsa|ecdsa-sha2-nistp256) AAAA.*"
    )
    nixFiles;

  # `docs/` is the site's navigation source, so an unreferenced page has no
  # parent and no reader. A page earns its place by being linked from a living
  # document — the same rule that keeps prose out of a `.nix` header.
  docsFiles = filesWithSuffix "docs" ".md"; # The agent-facing prose surfaces: the manual and every skill are read into
  # context on each turn, so their size is a cost, not an aesthetic. Shrink-only:
  # a cleanup lowers the number here in the same commit, and nothing may raise it.
  lineCount = p: builtins.length (lib.splitString "\n" (builtins.readFile p)) - 1;
  agentsLines = lineCount (root + "/AGENTS.md");
  skillFiles = builtins.filter (p: lib.hasSuffix "/SKILL.md" (toString p)) treeFiles;
  skillLines = builtins.foldl' (acc: p: acc + lineCount p) 0 skillFiles;

  # Truth, as a skill may cite it: a backticked repo path that RESOLVES, or a
  # policy citation. Prose that describes a mechanism without naming the file
  # that implements it is a second source of truth nobody can diff.
  repoRefPrefixes = ["modules/" "hosts/" "flake/" "lib/" "taskfiles/" "scripts/"];
  citedPaths = p:
    lib.filter (s: builtins.isString s && lib.any (pre: lib.hasPrefix pre s) repoRefPrefixes) (
      builtins.split "`" (builtins.readFile p)
    );
  citesTruth = p:
    lib.hasInfix "[[flake/policies.nix#" (builtins.readFile p)
    || lib.any (q: builtins.pathExists (root + "/${q}")) (citedPaths p);
  skillName = p: baseNameOf (dirOf (toString p));
  skillsWithoutTruth = map skillName (builtins.filter (p: !(citesTruth p)) skillFiles);

  # A skill may name an option; it may not define one. A pasted `*.enable =`
  # block is the module's value typed a second time, with no type check and no
  # assertion behind it.
  definesService = p:
    lib.any (l: builtins.match "[[:space:]]+[A-Za-z][A-Za-z0-9.-]*\\.enable = (true|false);" l != null)
    (lib.splitString "\n" (builtins.readFile p));
  skillsDefiningServices = map skillName (builtins.filter definesService skillFiles);
  # Supervision is a record, not a feeling: one JSON line per judged candidate,
  # and the automation label is gated on its verdicts (see `automation-is-earned`).
  ledger = ".agents/supervision.jsonl";
  ledgerLines =
    if builtins.pathExists (root + "/${ledger}")
    then lib.splitString "\n" (read ledger)
    else [];
  agreeCount = builtins.length (builtins.filter (l: lib.hasInfix "\"agree\":true" (lib.replaceStrings [" "] [""] l)) ledgerLines);
  totalJudged = builtins.length (builtins.filter (l: lib.hasInfix "\"target\"" l) ledgerLines);
  disagreeCount = totalJudged - agreeCount;

  # One blob of every .md/.nix in the tree, so "linked from somewhere" is one scan.
  # A *link* counts (`](docs/x.md)` from the manual, `](./x.md)` from a sibling
  # page); plain prose naming a file routes nobody to it.
  treeText = lib.concatStringsSep "\n" (map builtins.readFile textSources);
  links = base:
    builtins.length (lib.splitString "](docs/${base})" treeText)
    + builtins.length (lib.splitString "](./${base})" treeText)
    - 2;
  orphanDocs = builtins.filter (doc: links (baseNameOf doc) < 1) docsFiles;

  # Every tracked .nix / .md file, walked once: a header budget that only saw the
  # top level would miss the module tree, which is where the 30-line essays were.
  treeFiles = lib.filesystem.listFilesRecursive root;
  nixFiles = builtins.filter (p: lib.hasSuffix ".nix" (toString p)) treeFiles;
  textSources = builtins.filter (p: let s = toString p; in lib.hasSuffix ".md" s || lib.hasSuffix ".nix" s) treeFiles;
  takeWhile = pred: xs:
    if xs == [] || !(pred (builtins.head xs))
    then []
    else [(builtins.head xs)] ++ takeWhile pred (builtins.tail xs);
  headerLines = p: let
    isBanner = s: lib.match "[=#*~_-]+" s != null;
    lines = lib.splitString "\n" (builtins.readFile p);
    block = takeWhile (l: let s = lib.trim l; in s == "" || lib.hasPrefix "#" s) lines;
    bodies = map (l: lib.trim (lib.removePrefix "#" (lib.trim l))) block;
  in
    builtins.length (builtins.filter (s: s != "" && !(isBanner s)) bodies);
  longHeaders = map (p: lib.removePrefix "${toString root}/" (toString p)) (builtins.filter (p: headerLines p > 3) nixFiles);

  # A compositor swap inside `base-desktop-environment` is two configs fighting:
  # niri/DMS are force-disabled while the profile that installed them, and their
  # whole userland (zen, nautilus, portals, gnome-keyring), stays in the closure.
  # 2026-10-22: scratch ran exactly that shape for days — dwl on screen, fleet
  # desktop underneath. A host that disables a compositor has to fork the profile.
  hostConfigs = builtins.filter (p: builtins.pathExists (root + "/${p}")) (
    map (h: "hosts/${h}/configuration.nix") (
      builtins.attrNames (
        lib.filterAttrs (_: t: t == "directory") (builtins.readDir (root + "/hosts"))
      )
    )
  );
  halfForked =
    builtins.filter (
      p:
        lib.hasInfix "base-desktop-environment" (read p)
        && lib.hasInfix "programs.niri.enable = lib.mkForce false" (read p)
    )
    hostConfigs;

  policies = {
    desktop-fork-not-disable = {
      rule = "Swapping the compositor means forking the userland: a host may not import `base-desktop-environment` and force `programs.niri.enable = false` in the same module. That combination keeps niri, DMS, zen, nautilus and the portal/keyring stack installed behind a different WM, so the session changes and everything it opens does not. Drop the profile and declare the modules instead.";
      proof = "hosts/*/configuration.nix that both import base-desktop-environment and force niri off";
      holds = halfForked == [];
      detail = "half-forked hosts: ${lib.concatStringsSep ", " halfForked}";
    };

    capabilities-are-traits-not-names = {
      rule = "A shared module asks a host what it declares, never what it is called. Capability belongs in `inventory.toml` (`category`, `persona.compute_tier`, `software.traits`), and the module reads it: `traits` for a package list or toolchain tier, `category` for what kind of machine it is. A hostname list compiles in a second registry whose only maintenance event is a breakage — frieren, eisen and poseidon were remembered in three separate modules, the GPU tier list had drifted from `hardware.gpu` (ares matched only by name, netbook's card matched by neither), and the NAS profiles excluded the server by comparing its name.";
      proof = "modules/**/*.nix scanned for `builtins.elem hostName`, `hostName ==` and a comparison against a quoted hostname; the traits they now read (including `nas-server`) live in inventory.toml";
      holds = hostnameGatedModules == [];
      detail = "hostname-gated modules (the trait they need belongs in inventory.toml): ${lib.concatStringsSep ", " hostnameGatedModules}";
    };

    systemd-units-are-capability-gated = {
      rule = "A systemd unit, timer or enable is gated by a declared capability, a systemd `Condition*`, or not at all — never by a hostname list and never by a runtime environment probe inside the unit's script. A hostname list is a capability nobody declared, so the config cannot say where a unit runs and the unit exists on hosts where it can only fail; a runtime probe makes the unit look healthy while doing nothing.";
      proof = "modules/*.nix that declare systemd units, scanned for hostname gates; modules/user/desktop/niri.nix (the session capability's activation half); modules/calendar.nix (no WAYLAND_DISPLAY probe)";
      holds =
        hostnameGatedUnitModules
        == []
        && has "modules/user/desktop/niri.nix" "graphical-session.target"
        && has "modules/user/desktop/niri.nix" "import-environment"
        && has "modules/calendar.nix" "ConditionPathExists"
        && !(has "modules/calendar.nix" "WAYLAND_DISPLAY")
        && has "modules/systemd-policy.nix" "userUnitViolations";
      detail = "hostname-gated unit modules: ${lib.concatStringsSep ", " hostnameGatedUnitModules}; session wiring or the calendar gate is missing";
    };

    systemd-daemons-declare-their-class = {
      rule = "A system systemd service this tree declares states its crash-loop class where it is declared: `unitConfig.X-Fleet-Role = \"daemon\"` (must come back: Restart set and never retirable by systemd's start limit) or `\"bounded\"` (retiring is the point, so it carries an explicit StartLimitBurst). nixpkgs' own units are upstream's policy and carry no marker; a `Restart=` block without a role is a unit whose behaviour nobody decided, and the gate in modules/systemd-policy.nix enforces the class it names.";
      proof = "systemd.services blocks in modules/ and hosts/ that set Restart; lib/systemd-policy.nix markedSystemViolations";
      holds = unclassifiedDaemons == [];
      detail = "system services with Restart and no X-Fleet-Role:\n    ${lib.concatStringsSep "\n    " unclassifiedDaemons}";
    };

    root-markdown-closed = {
      rule = "No new root-level markdown: a document lives in docs/, in a skill, or as a note in AGENTS.nix.";
      proof = "root *.md listing";
      holds = strayRootMd == [];
      detail = "stray root markdown: ${lib.concatStringsSep ", " strayRootMd}";
    };

    nix-header-budget = {
      rule = "A `.nix` file opens with at most three comment lines naming its contract, and no comment block — header or inline — explains a fact that has a home: rationale belongs in a docs page, an AGENTS.nix note, a skill, or a policy, which the graph and qmd compile into an answer. Nothing compiles a comment, so an explanation written in a module is answerable only by reading that module; restating what Nix already declares (a mount's protocol version, a unit's ordering) is worse, a second home that drifts. The corpus is gated by the header budget; new work is gated on the **diff** by `scripts/task/nix-prose-lint.sh` in the pre-commit hook — a run of 8+ added comment lines citing no home fails — so an essay cannot land even where the old backlog remains.";
      proof = "leading comment block of every tracked .nix file · scripts/task/nix-prose-lint.sh (added lines) · .githooks/pre-commit";
      holds =
        longHeaders
        == []
        && has ".githooks/pre-commit" "nix-prose-lint.sh"
        && has "taskfiles/checks.yml" "checks:nix:prose";
      detail = "headers over budget: ${lib.concatStringsSep ", " longHeaders} (or the diff gate was unwired from the hook or its task); report the comment backlog with `task checks:nix:prose MODE=all`";
    };

    agent-prose-budget = {
      rule = "AGENTS.md (928 lines) and every tracked SKILL.md (5526 lines today) are shrink-only — they are read into context on every turn, so a cleanup lowers the number here in the same commit. The only extension is an audited one: the audit lives in this rule text, the added prose must be a `Truth:` pointer counted by `skills-cite-truth`, and that policy must already hold. A budget that grows without either is how a corpus becomes a liability.";
      proof = "line counts of AGENTS.md and every tracked SKILL.md";
      # Audited 2026-10-21: 215 lines removed by collapsing the shadowed
      # `.agents/skills/simplex-admin` copy (the module is canonical and the
      # installer prefers it), 60 lines added as one `Truth:` pointer per skill
      # that had none. Net −155, cap lowered 5546 → 5526 in the same change.
      holds = agentsLines <= 928 && skillLines <= 5526;
      detail = "AGENTS.md ${toString agentsLines}/928 lines, skills ${toString skillLines}/5526 — over budget means delete or an audited `Truth:` extension, not a renumber";
    };

    channels-have-a-task = {
      rule = "Every discovery channel keeps an entry point: a fleet fact is read with `task dev:inventory:feed`, a note with `ops:notes:show`, a durable doc with `docs:build`, and a rule with the policy check. A category with no entry point is a fact nobody can reach, which is how prose becomes the only home.";
      proof = "taskfiles/dev.yml (inventory:feed, docs:build), taskfiles/ops.yml (ops:notes:show), flake/checks.nix (policyFailures)";
      holds =
        has "taskfiles/dev.yml" "inventory:feed"
        && has "taskfiles/dev.yml" "docs:build"
        && has "taskfiles/ops.yml" "ops:notes:show"
        && has "flake/checks.nix" "policyFailures";
      detail = "a channel lost its task, so the category it owns has no route";
    };

    categorize-sends-features-only = {
      rule = "The categorizer sends a file's FEATURES to the provider, never its contents: comment/line counts, duplicate-fact hits, age and pattern counts. A categorizer that pipes the document itself to a remote model is a data-egress path wearing a lint's clothes, so the state format is a predicate and `cat \"$f\"` is not allowed in it.";
      proof = "scripts/task/categorize.sh (features() builds the state; ask/jev_classify send only that string)";
      holds =
        has "scripts/task/categorize.sh" "printf 'comments="
        && !(has "scripts/task/categorize.sh" "cat \"$f\"")
        && !(has "scripts/task/categorize.sh" "jq -Rs");
      detail = "the categorizer started sending file contents (or stopped proving it sends features)";
    };

    automation-is-earned = {
      rule = "An automation stamp is earned by the supervision ledger, never by an agent's optimism: `.agents/supervision.jsonl` records one judged candidate per line (target, engine label, human label, agree), the categorizer never moves or rewrites prose (`git mv`, `sed -i`, an in-place write to the candidate file all fail it), and it may not grow an `--auto`/`--apply` path unless at least 5 agreements are recorded AND they are at least half the judged set. A paywall, a 402 or a provider error is not a disagreement to average over — it is a refusal.";
      proof = ".agents/supervision.jsonl and scripts/task/categorize.sh";
      holds =
        # It classifies and never moves: a mutating categorizer is an automation
        # path whatever it calls itself, so the flag-name gate alone is not enough.
        !(lib.any (t: has "scripts/task/categorize.sh" t) ["git mv" "sed -i" "mv \"$f\"" ">\"$f\""])
        && (
          (!(has "scripts/task/categorize.sh" "--auto")
            && !(has "scripts/task/categorize.sh" "--apply"))
          || (agreeCount >= 5 && agreeCount * 2 >= totalJudged)
        );
      detail = "supervision: ${toString agreeCount} agree / ${toString disagreeCount} disagree of ${toString totalJudged} judged — automation is ${
        if agreeCount >= 5 && agreeCount * 2 >= totalJudged
        then "earned"
        else "not earned"
      }; ${
        if agreeCount >= 5 && agreeCount * 2 >= totalJudged
        then "an --auto path is permitted while this majority holds"
        else "adding --auto now fails this policy"
      }";
    };

    decision-engine-routing = {
      rule = "Categorization runs on jev (TypeSafe) and says so: julia-1's `choice` is label-biased — a real command sequence reads as 'a fact about a machine' in both orders (0/10 on the steps anchor, 4/10 on the rule anchor) — and OpenRouter answers HTTP 402 without credit, so a skill may not offer it as the default. The pipeline order is qmd (find the prose) → jev (fan out candidates) → classification (validate the action) → supervision before automation, and it fails CLOSED: a paywall, a 402 or a provider error refuses the table and never acts on a partial result.";
      proof = "scripts/task/categorize.sh (default engine, error gate) and .agents/skills/jevdecide/SKILL.md (named provider)";
      holds =
        has "scripts/task/categorize.sh" "CATEGORIZE_ENGINE:-jev"
        && has "scripts/task/categorize.sh" "jev-error"
        && has ".agents/skills/jevdecide/SKILL.md" "--provider typesafe"
        && !(has ".agents/skills/jevdecide/SKILL.md" "--provider openrouter");
      detail = "the categorizer fell back to julia-1, lost its engine-error gate, or a skill advertises the provider without credit";
    };

    services-live-in-modules = {
      rule = "A skill names a service option, it never defines one: no `*.enable = true|false;` assignment inside a SKILL.md. Service behaviour is an option in a module with its own assertions, so a skill that carries the value is a second home.";
      proof = "line scan of every tracked SKILL.md";
      holds = skillsDefiningServices == [];
      detail = "skills defining a service: ${lib.concatStringsSep ", " skillsDefiningServices}";
    };

    skills-cite-truth = {
      rule = "A SKILL.md may describe procedure but must point at machine truth: a backticked repo path (`modules/`, `hosts/`, `flake/`, `lib/`, `taskfiles/`, `scripts/`) that exists on disk, or a [[flake/policies.nix#id]] citation. A skill that is the only home of a fact is the fact nobody can check.";
      proof = "inline code spans and policy citations in every tracked SKILL.md, resolved against the tree";
      holds = skillsWithoutTruth == [];
      detail = "skills citing no resolvable repo path: ${lib.concatStringsSep ", " skillsWithoutTruth}";
    };

    paperless-closure-traps = {
      rule = "frieren's paperless keeps stock `pkgs.tika` in an inline unit and a stubbed gotenberg chromium; an override re-derives both uncached (Maven, ~300 MiB chromium).";
      proof = "hosts/frieren/paperless.nix";
      holds =
        has "hosts/frieren/paperless.nix" "systemd.services.tika"
        && has "hosts/frieren/paperless.nix" ''runCommand "chromium"''
        && !(anyLine "hosts/frieren/paperless.nix" (l: builtins.match "[[:space:]]*services.tika.enable = true;" l != null));
      detail = "paperless went back to the module-level tika override or a real chromium";
    };

    secrets-are-encrypted = {
      rule = "Every sops file in the tree is encrypted (`ENC[AES256_GCM` values plus `sops:` metadata); a plaintext commit fails rather than being reviewed.";
      proof = "modules/secrets.yaml, modules/ssh-ca-key.yaml";
      holds =
        lib.all (
          f: builtins.pathExists (root + "/${f}") && anyLine f (l: lib.hasPrefix "sops:" l)
        )
        sopsFiles
        && plaintextSecrets == [];
      detail = "plaintext value(s) in a sops file: ${lib.concatStringsSep "; " plaintextSecrets}";
    };

    secrets-submodule-declared = {
      rule = "The real secret files are the `modules/secrets` submodule; `modules/secrets.yaml` is its mirror, and both copies carry the recipients.";
      proof = ".gitmodules, docs/sops-rekey.md";
      holds =
        has ".gitmodules" ''[submodule "modules/secrets"]''
        && has "docs/sops-rekey.md" "modules/secrets.yaml";
      detail = ".gitmodules lost the secrets submodule, or the rekey page stopped naming the mirror";
    };

    ssh-ca-declarative = {
      rule = "User access is CA-signed certificates: one CA key, `rotate-ssh-cert` for 1-week certs, no `authorized_keys` management.";
      proof = "modules/ssh-ca.nix, modules/profiles/base-node.nix";
      holds =
        has "modules/ssh-ca.nix" "rotate-ssh-cert"
        && has "modules/profiles/base-node.nix" "ssh.ca.enable = true";
      detail = "the CA module lost rotate-ssh-cert, or base-node stopped enabling ssh.ca";
    };

    ca-only-user-access = {
      rule = "User access is CA-signed certificates plus the one key list in `modules/config/authorized-keys.nix`; no host ships its own key literal.";
      proof = "every .nix file outside the key sources and the out-of-flake hosts";
      holds =
        ownKeyLiterals
        == []
        && has "modules/config/authorized-keys.nix" "config.ssh.authorizedKeys.keys";
      detail = "key literals outside the single source: ${lib.concatStringsSep ", " (map rel ownKeyLiterals)}";
    };

    ci-matrix-is-inventory = {
      rule = "CI eligibility is `inventory.toml`; a task that edits a build matrix, or a workflow matrix list, is editing something the pipeline does not read.";
      proof = ".github/workflows/nixcachix.yml (calls the detector, has no `machine:` list), taskfiles/*.yml";
      holds =
        has ".github/workflows/nixcachix.yml" "detect-affected-hosts.py"
        && !(anyLine ".github/workflows/nixcachix.yml" (l: builtins.match "[[:space:]]*machine:.*" l != null))
        && lib.all (f: !(has f "lifecycle:ci:enable-host")) taskfiles;
      detail = "the workflow stopped being inventory-driven, or a task went back to editing a matrix";
    };

    ci-dormant-hosts-excluded = {
      rule = "Dormant and `ci = false` hosts are excluded by the detector, not by a comment in the workflow.";
      proof = "scripts/ci/detect-affected-hosts.py";
      holds =
        has "scripts/ci/detect-affected-hosts.py" ''status") == "active"''
        && has "scripts/ci/detect-affected-hosts.py" "ci_excluded";
      detail = "the detector stopped selecting active hosts only, or stopped honouring the per-host ci flag";
    };

    ci-builds-config-and-gate = {
      rule = "CI builds the closure and the module-system gate for each affected host, both with `?submodules=1`.";
      proof = ".github/workflows/nixcachix.yml";
      holds =
        has ".github/workflows/nixcachix.yml" "nix build -L .?submodules=1#"
        && has ".github/workflows/nixcachix.yml" "hostChecks."
        && has ".github/workflows/nixcachix.yml" "pipe-operators";
      detail = "the workflow stopped building hostChecks, lost ?submodules=1, or dropped pipe-operators";
    };

    host-path-pinned-to-submodules = {
      rule = "Every task-surface reference to a host closure carries `?submodules=1`, so the path a switch evaluates is the path a warm built.";
      proof = "scripts/task/warm-host.sh, scripts/task/activate-host.sh, scripts/task/host-check-sweep.sh, scripts/task/boot-check.sh, taskfiles/infra.yml";
      # A warm built `.#frieren` (v3xykfhr…); the switch evaluated
      # `.?submodules=1#frieren` (fpmxv4fn…), 34 derivations apart, so the cache
      # could not serve it. It is also faster (0.12 s vs 0.24 s for a leaf read).
      holds =
        has "scripts/task/warm-host.sh" ".?submodules=1#nixosConfigurations."
        && has "scripts/task/activate-host.sh" ".?submodules=1#nixosConfigurations."
        && has "scripts/task/host-check-sweep.sh" "?submodules=1#hostChecks."
        && has "scripts/task/boot-check.sh" "?submodules=1#hostBootChecks."
        && has "taskfiles/infra.yml" "?submodules=1#nixosConfigurations."
        && lib.all
        (f:
          !(anyLine f (l:
            builtins.match ".*\\.#(nixosConfigurations|hostChecks|hostBootChecks)\\..*" l
            != null
            && builtins.match ".*submodules=1.*" l == null
            && builtins.match ".*flakeref.*" l == null)))
        (taskfiles ++ shellScripts);
      detail = "a task or script grew a bare `.#host...` reference; use `.?submodules=1#` (or the `flakeref` helper in nixbuild-warm.sh for remote refs)";
    };

    ci-doc-budget = {
      rule = "A doc-only change still runs the living-document budget, so a runaway manual cannot land green on a push that allocated no build runner.";
      proof = ".github/workflows/nixcachix.yml (the `docs-budget` job builds `checks.<system>.docs-budget`)";
      holds =
        has ".github/workflows/nixcachix.yml" "docs-budget:"
        && has ".github/workflows/nixcachix.yml" "checks.x86_64-linux.docs-budget";
      detail = "the workflow lost the docs-budget job; doc-only pushes now allocate nothing and gate nothing";
    };

    ci-task-graph-pin = {
      rule = "The task graph's exec and prose digests are pinned, and the pin is built on every push (doc-only included), so a silent shard rewrite cannot ship.";
      proof = ".github/workflows/nixcachix.yml builds `checks.<system>.taskfile-digest-pin`";
      holds = has ".github/workflows/nixcachix.yml" "checks.x86_64-linux.taskfile-digest-pin";
      detail = "the workflow lost the task-graph pin step; digest drift now reaches a deploy unflagged";
    };

    taxonomy-one-home = {
      rule = "The `/srv/data` layout has one home (`docs/storage-taxonomy.md`); the manual links to it instead of carrying a second table.";
      proof = "docs/storage-taxonomy.md exists, and AGENTS.md has no `/srv/data` layout table";
      holds =
        builtins.pathExists (root + "/docs/storage-taxonomy.md")
        && !(lib.hasInfix "| Path (`/srv/data/` /" (read "AGENTS.md"));
      detail = "the storage table is back in AGENTS.md, or the taxonomy page is gone";
    };

    media-tree-isolation = {
      rule = "A media library holds only video, and every unindexed tree carries both `.nomedia` and `.plexignore`.";
      proof = "scripts/task/data-ops.sh (arr/ hygiene + sentinel checks), taskfiles/data.yml";
      holds =
        has "taskfiles/data.yml" "data:audit"
        && has "scripts/task/data-ops.sh" "Media Server Hygiene"
        && has "scripts/task/data-ops.sh" "plexignore";
      detail = "the data audit stopped checking media hygiene or the plexignore sentinel";
    };

    private-trees-restricted = {
      rule = "`p/*` and `security/` stay `0700`, key material `0600`, and the private trees stay shielded from scanners.";
      proof = "scripts/task/data-ops.sh (protect-private)";
      holds =
        has "scripts/task/data-ops.sh" "chmod 700"
        && has "scripts/task/data-ops.sh" "chmod 600"
        && has "scripts/task/data-ops.sh" ".nomedia";
      detail = "protect-private stopped widening-restoring to 0700/0600 or stopped planting sentinels";
    };

    no-orphan-docs = {
      rule = "A `docs/*.md` page is reachable by a markdown link from the manual or a sibling page; an unlinked page is a page nothing routes to.";
      proof = "docs/*.md against inbound `](…x.md)` links in AGENTS.md, README.md and sibling pages";
      holds = orphanDocs == [];
      detail = "docs nothing links to: ${lib.concatStringsSep ", " orphanDocs}";
    };

    surfaces-are-compiled = {
      rule = "A human-facing surface — landing page, service list, tailnet mount — is compiled from one registry with assertions, never written twice by hand.";
      proof = "modules/services/service-portal.nix (registry + asserts) · lib/delphi-site.nix (the dossier and the console) · hosts/frieren/reverse-proxy.nix · hosts/delphi/configuration.nix";
      holds =
        has "modules/services/service-portal.nix" "assertions = ["
        # frieren renders the registry's own LAN page; delphi renders the CARD
        # PROJECTION through its own compiler, because its two surfaces (a
        # portfolio dossier and a tailnet console) are not the same page twice.
        && has "hosts/frieren/reverse-proxy.nix" "config.services.servicePortal.pages.lan"
        && has "hosts/delphi/configuration.nix" "config.services.servicePortal.cards"
        && has "hosts/delphi/configuration.nix" "lib/delphi-site.nix"
        # A hand-written card list and a hand-rolled mount are the two shapes
        # this replaced; either coming back means a second source of truth.
        && !(has "hosts/frieren/reverse-proxy.nix" "class=\"card\"")
        && !(has "hosts/frieren/reverse-proxy.nix" "card-desc")
        && !(has "hosts/delphi/configuration.nix" "tailscale serve --bg")
        # The card rows are generated in the compiler, never typed into a page.
        && !(has "lib/delphi/public.html" "class=\"svc\"")
        && !(has "lib/delphi/tailnet.html" "class=\"svc\"");
      detail = "a portal page, a card row or a `tailscale serve` mount was hand-written again instead of declared in `services.servicePortal`";
    };

    no-fleet-default = {
      rule = "No task defaults to the whole fleet: `checks:hosts` takes the set at the call site (a default of one local host is fine, a default of 23 is not).";
      proof = "taskfiles/checks.yml";
      holds =
        has "taskfiles/checks.yml" "HOSTS IS REQUIRED"
        # the sweep passes HOSTS through verbatim — a `| default` here is the footgun
        && has "taskfiles/checks.yml" ''--hosts "{{.HOSTS}}"''
        && lib.all (f: !(has f "checks:hosts:all")) taskfiles;
      detail = "checks:hosts lost its required HOSTS, or a `checks:hosts:all` sweep came back";
    };

    task-surface-visible = {
      rule = "No task is hidden with `internal: true`: it disappears from `task --list-all --json` too.";
      proof = "taskfiles/*.yml";
      # A YAML KEY, not the phrase: `task checks:tasks`' own summary names the
      # rule (`internal: true` is banned), and a substring match made the gate
      # fail on its own documentation. Matched at field indent so a `desc:` or a
      # `#` comment may talk about it freely.
      holds = lib.all (f: !(anyLine f (l: builtins.match " +internal:[[:space:]]*true[[:space:]]*(#.*)?" l != null))) taskfiles;
      detail = "a taskfile marks a task internal";
    };

    sweeps-under-watchdog = {
      rule = "A host sweep runs under the OOM watchdog, one host per process.";
      proof = "scripts/task/host-check-sweep.sh";
      holds = has "scripts/task/host-check-sweep.sh" "oom-guard";
      detail = "host-check-sweep.sh stopped calling oom-guard.sh";
    };

    boot-gate-needs-kvm = {
      rule = "A boot of some OTHER host is an instrument, not a check: `scripts/task/boot-check.sh` refuses before its first eval or build unless /dev/kvm is usable, and names CI when it does. Under TCG a real host costs a core for ~8 minutes, and the machines that reach for it by hand are also serving (delphi: public TLS and ssh on 2 OCPU), so the cost is degraded traffic rather than a slow test. The one exception is the host you are about to switch — `--self` resolves to `$(hostname)` or refuses — because a bad stage-1 there cannot be diagnosed from outside. ALLOW_TCG=1 is the remaining deliberate override.";
      proof = "the /dev/kvm probe's position in scripts/task/boot-check.sh, ahead of its first `nix eval` and `nix build`";
      holds =
        has "scripts/task/boot-check.sh" "ALLOW_TCG"
        && has "scripts/task/boot-check.sh" ''[ ! -r /dev/kvm ]''
        && has "scripts/task/boot-check.sh" "no usable /dev/kvm"
        && has "scripts/task/boot-check.sh" "--self is for"
        && before "scripts/task/boot-check.sh" "/dev/kvm" ''status="$(nix eval''
        && before "scripts/task/boot-check.sh" "/dev/kvm" "nix build --no-link";
      detail = "boot-check.sh builds a VM without probing /dev/kvm first, or lost the ALLOW_TCG/--self overrides";
    };

    flake-check-memory-gated = {
      rule = "`nix flake check` is refused below 16 GiB: it evaluates every flake output in one process.";
      proof = "taskfiles/checks.yml (checks:flake)";
      holds =
        has "taskfiles/checks.yml" "MemTotal"
        && has "taskfiles/checks.yml" ''default "16384"'';
      detail = "checks:flake lost its MemTotal guard";
    };

    toml-through-a-tool = {
      rule = "TOML is edited through a format-aware tool, never by text substitution.";
      proof = "scripts/task/*.sh";
      holds =
        lib.all (
          f: !(anyLine f (l: lib.hasInfix "sed -i" l && lib.hasInfix ".toml" l))
        )
        shellScripts;
      detail = "a script edits a .toml with sed -i";
    };

    generated-not-tracked = {
      rule = "A generated artifact is a store path (`.#artifacts.docs`), never a tracked directory.";
      # Presence is not the failure mode — a local `nix build .#artifacts.docs` writes
      # docs/generated legitimately. Being *trackable* is: once the artifact is
      # not gitignored, a `git add -A` commits a copy that drifts.
      proof = ".gitignore + docs-site absence";
      holds =
        has ".gitignore" "docs/generated/"
        && !(builtins.pathExists (root + "/docs-site"));
      detail = "docs/generated is not gitignored, or the retired docs-site/ renderer is back";
    };

    statix-advisory = {
      rule = "The default fix set is deadnix + alejandra; statix is reported, never auto-applied.";
      proof = "scripts/task/nix-fmt.sh";
      holds = has "scripts/task/nix-fmt.sh" ''TOOLS="deadnix,alejandra"'';
      detail = "nix-fmt.sh's default tool set changed";
    };

    negative-cache-disabled = {
      rule = "A cache check disables the 1 h negative narinfo cache, or a freshly warmed path reads as missing.";
      proof = "scripts/task/activate-host.sh";
      holds = has "scripts/task/activate-host.sh" "narinfo-cache-negative-ttl 0";
      detail = "activate-host.sh queries the cache without disabling the negative cache";
    };

    library-fetch-is-static = {
      rule = "The portable tool library (/Volumes/data/bin-*, appimages) is executed by NON-Nix machines — pentest targets, research boxes — which cannot relink a binary or install a matching libc, so a fetch only accepts a statically linked build and a dynamic asset is moved to `.rejected/` and fails the run. The judgment is `library-audit.sh --probe`, the one implementation of \"is this static\" shared by the audit and the fetcher, and every accepted fetch records provenance (sha256, repo, resolved tag, asset, date) in `.library.tsv` — the one fact a file cannot carry about itself.";
      proof = "scripts/task/library-fetch.sh · scripts/task/library-audit.sh (--probe)";
      holds =
        has "scripts/task/library-fetch.sh" "library-audit.sh\" --probe"
        && has "scripts/task/library-fetch.sh" ''"$linkage" != static''
        && !(has "scripts/task/library-fetch.sh" "allow-dynamic")
        && has "scripts/task/library-fetch.sh" ".library.tsv"
        && has "scripts/task/library-audit.sh" "--probe)";
      detail = "the fetcher stopped proving its download is static, grew an override, or stopped recording provenance";
    };

    library-crosses-the-wire = {
      rule = "The library is mirrored whole to BurgerNAS inside its scheduled uptime window, so a non-Nix machine pulls tools from the NAS without frieren being up: every bin-*/appimages directory is mirrored (`--delete`, the mirror is not an append-only attic) and `.rejected` is excluded because a dynamic binary is not library material. The destination is the **NFS export** (`/volume1/peachcable`, the only share DSM exports), not merely a directory on the NAS: a mirror written anywhere else is unreachable by the DietPi/Raspberry Pi clients that are its whole reason to exist, and one lane holds the real bytes while the legacy `/volume1/Shared Library/{bin-*,appimages}` paths are server-local symlinks to it.";
      proof = "hosts/frieren/infra-stack.nix (burgernas-library-sync)";
      holds =
        has "hosts/frieren/infra-stack.nix" "burgernas-library-sync"
        && has "hosts/frieren/infra-stack.nix" ''dirs="bin-x86 bin-aarch64 bin-script appimages"''
        && has "hosts/frieren/infra-stack.nix" ''DEST_PATH="/volume1/peachcable"''
        && has "hosts/frieren/infra-stack.nix" "--exclude '.rejected'";
      detail = "the NAS mirror lost a directory, kept rejected downloads, stopped deleting removed files, or drifted off the exported share into a path no NFS client can reach";
    };

    library-table-generated = {
      rule = "The release-built library is one table in `tools/library.nix`, rendered by `task data:library:update` into `library-fetch.sh` calls. No TOML, eget config or hand-written download line is tracked, and no second fetcher pushes the library on its own schedule — the NAS copy is the scheduled mirror.";
      proof = "tools/library.nix · taskfiles/data.yml";
      holds =
        filesWithSuffix "tools" ".toml"
        == []
        && has "taskfiles/data.yml" "tools/library.nix"
        && has "tools/library.nix" "library-fetch.sh";
      detail = "a TOML or a second fetcher is back under tools/, or the library task stopped rendering the table";
    };

    library-row-pins-its-arch = {
      rule = "Every library row names the substring that pins its asset per dir (`pick`), because eget does not filter by architecture: an aarch64 host fetched `starship-x86_64` once the arm token was missing, which is a binary the NAS can only fail to exec.";
      proof = "tools/library.nix rows that land in bin-aarch64/bin-x86";
      holds = unpinnedRows == [];
      detail = "rows with no pin for an arch dir: ${lib.concatStringsSep ", " unpinnedRows}";
    };

    library-content-is-not-scheduled = {      rule = "A library on a network mount is pulled by a LAUNCH and by nothing else: no timer, no login job, no path unit watching for a fresh drop, and no unit may open an image to read a `.desktop` file, a version or an icon out of it. A stale cache is flushed and re-fetched on the next launch — never warmed because the library changed, because that turns one upgrade into a LAN-wide congestion event.";
      proof = "scripts/task/appimage-integrate.sh (deleted 2026-10-28) · the `appimage-launchers` user unit (login + hourly)";
      holds =
        scheduledLibraryExtractions == []
        && libraryPathWatchers == []
        && deletedLibraryIntegrators == [];
      detail =
        if deletedLibraryIntegrators != []
        then "the AppImage integrator is back: ${lib.concatStringsSep ", " deletedLibraryIntegrators} — it opened every image in /Volumes/data/appimages with unsquashfs/readelf on a timer. Measured 2026-10-28: 61 images, 50 CPU-seconds and a 673 MiB peak per hourly run on frieren; ~300 MB of NFS reads on the netbook inside four minutes of boot, on a Celeron over wifi."
        else "a scheduled unit names a script that extracts library content across a network mount: ${lib.concatStringsSep ", " scheduledLibraryExtractions}";
    };

    history-sync-is-one-server = {
      rule = "Shell history syncs to the one atuin server this tree declares, and that server stops accepting sign-ups once the account exists — an open registration on a history database is an account anyone who reaches the vhost can create.";
      proof = "modules/shell/atuin.nix · modules/services/atuin-server.nix · hosts/frieren/configuration.nix";
      holds =
        !(has "hosts/frieren/configuration.nix" "openRegistration = true")
        && has "modules/services/atuin-server.nix" "openRegistration"
        && !(has "modules/shell/atuin.nix" "api.atuin.sh");
      detail = "registration is open again, the server lost the option, or a client points at the public service";
    };

    one-history-widget = {
      rule = "Ctrl-R has one owner: with atuin enabled, fzf's history widget is disabled, so the key that searches history searches the synced history instead of whichever host's local file fzf found.";
      proof = "modules/shell/default.nix";
      holds = has "modules/shell/default.nix" ''fzf.historyWidget.command = ""'';
      detail = "fzf took Ctrl-R back from atuin";
    };

    pipe-operators-declared = {
      rule = "`|>` needs `pipe-operators` in experimental-features; the tree does not parse without it.";
      proof = "modules/global/global.nix";
      holds = has "modules/global/global.nix" "\"pipe-operators\"";
      detail = "modules/global/global.nix dropped pipe-operators";
    };
  };

  ids = builtins.attrNames policies;
  citedIds = lib.unique (map (c: c.id) citations);
in {
  inherit
    policies
    citations
    normativeDocs
    ids
    citedIds
    ;

  # Both directions. A citation to an id that does not exist is a broken link
  # (Obsidian shows it greyed out); an id nobody cites is an invisible gate.
  danglingCitations =
    builtins.filter (c: !(builtins.elem c.id ids)) citations;
  uncitedPolicies =
    builtins.filter (id: !(builtins.elem id citedIds)) ids;

  # `HARD RULE` is this repo's own token for "this one is enforced, not
  # advised", so the convention is checkable without guessing at English: a
  # hard rule that carries no citation is exactly the bloat we are deleting.
  unenforcedHardRules = let
    scan = doc:
      builtins.filter
      (l: lib.hasInfix "HARD RULE" l && !(lib.hasInfix "[[flake/policies.nix#" l))
      (lib.splitString "\n" (read doc));
  in
    lib.concatMap (d: map (l: "${d}: ${lib.removePrefix "#" (lib.trim l)}") (scan d)) normativeDocs;
}
