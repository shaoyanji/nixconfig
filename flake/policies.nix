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
    ".agents/SCHEMA.md"
    ".agents/README.md"
    "docs/agent-contract.md"
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

  # --- exposure: the general gates that retire the rotation chore -------------
  # A secret rarely leaks by being pasted. It *moves*: into the second copy of a
  # file, into a tracked source file, into a store path at eval time, or onto a
  # terminal by a comparison that prints. Each of those is a predicate over the
  # tree, so the answer to a leak is a gate rather than one more paragraph and one
  # more rotation.
  secretsMirror = "modules/secrets.yaml";
  secretsSubmodule = "modules/secrets/secrets.yaml";
  secretsDir = "modules/secrets";
  sopsFiles = [
    "modules/secrets.yaml"
    "modules/ssh-ca-key.yaml"
    "modules/secrets/apikeys.yaml"
    "modules/secrets/DE-Taskfile.yaml"
    "modules/secrets/fullsecrets.yaml"
    "modules/secrets/pii.yaml"
    "modules/secrets/secrets.yaml"
  ];
  # The registry is only real if it is complete: an encrypted file nobody lists is
  # also a file `plaintextValues` never reads.
  encryptedInSecretsDir =
    if builtins.pathExists (root + "/${secretsDir}")
    then
      map (n: "${secretsDir}/${n}") (
        builtins.attrNames (
          lib.filterAttrs
          (n: t: t == "regular" && !(lib.hasPrefix "." n) && lib.hasSuffix ".yaml" n)
          (builtins.readDir (root + "/${secretsDir}"))
        )
      )
    else [];
  unregisteredSops = builtins.filter (f: !(lib.elem f sopsFiles)) encryptedInSecretsDir;
  # A clone without the submodule checked out must still evaluate: the files that
  # are here are scanned, the ones that are not are reported by the registry gate
  # the moment they appear.
  presentSopsFiles = builtins.filter (f: builtins.pathExists (root + "/${f}")) sopsFiles;
  # A bare tree (CI, nixbuild, a clone without `--recurse-submodules`) has no
  # secrets submodule at all, so a library read of it works on the machine that
  # has the checkout and nowhere else. Match the directory with its slash: the
  # tracked mirror `modules/secrets.yaml` is a different file.
  secretsReads = builtins.filter (p: lib.hasInfix "modules/secrets/" (read p)) (nixUnder "lib");

  # --- one spelling for where a secrets file lives ---------------------------
  # 27 scripts each carried their own copy of the path, and with it their own
  # answer to "canonical or mirror?" — so a writer and a reader in the same repo
  # could disagree about which file was authoritative, which is how an edit lands
  # in a copy that builds never read.
  secretsPathHelper = "scripts/task/lib/paths.sh";
  # Naming the path IS these files' job: the drift gate compares the two copies,
  # and the openwrt wrapper resolves one in a store context where the submodule
  # may not be checked out at all.
  secretsPathExempt = [
    secretsPathHelper
    "scripts/task/sops-drift-check.sh"
    "scripts/openwrt/openwrt.sh"
  ];
  scriptFiles = let
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
        else lib.optional (lib.hasSuffix ".sh" n || lib.hasSuffix ".py" n) rel)
      (builtins.attrNames entries);
  in
    if builtins.pathExists (root + "/scripts")
    then walk "scripts"
    else [];
  # A comment naming the path is documentation, so only the code before `#`
  # counts — the same reading the eval-decrypt gate uses. Python has no such
  # convention for a docstring or a `help=` string, so there only a real spelling
  # counts: a path literal (the quote sits immediately before it, so prose that
  # merely mentions the file does not match) or an `os.path.join` that names it.
  spellsSecretsPath = p:
    if lib.hasSuffix ".py" p
    then
      anyLine p (l:
        (lib.hasInfix "os.path.join" l && lib.hasInfix "modules/secrets" l)
        || builtins.match ".*[\"']modules/secrets[/.].*" l != null)
    else
      anyLine p (l: let
        code = codePart l;
      in
        lib.hasInfix "modules/secrets.yaml" code
        || builtins.match ".*modules/secrets/[A-Za-z0-9_.-]+\\.yaml.*" code != null);
  secretsPathOffenders =
    builtins.filter (p: !(lib.elem p secretsPathExempt) && spellsSecretsPath p) scriptFiles;
  plaintextSecrets = lib.concatMap (f: map (l: "${f}: ${l}") (plaintextValues f)) presentSopsFiles;
  # The mirror is a `cp` of the submodule (`task infra:secrets:sync`), so identity
  # is the invariant. A value written to one copy only decrypts on the machine that
  # wrote it and is absent everywhere after the next sync.
  mirrorDrift =
    builtins.pathExists (root + "/${secretsMirror}")
    && builtins.pathExists (root + "/${secretsSubmodule}")
    && read secretsMirror != read secretsSubmodule;

  # Positions of matching lines. Report the FILE AND LINE, never the line: a gate
  # failure is printed into a terminal, a CI log or a transcript, so quoting what
  # it found would re-publish the thing it is protecting.
  hitsWhere = p: pred: let
    lines = lib.splitString "\n" (read p);
    idx = builtins.filter (i: pred (builtins.elemAt lines i)) (lib.range 0 (builtins.length lines - 1));
  in
    map (i: "${p}:${toString (i + 1)}") idx;

  # Shapes the issuers reserve. A value cannot be matched, so match the prefix:
  # the same test a scanner runs, over every tracked text file.
  textSuffixes = [".md" ".nix" ".sh" ".yml" ".yaml" ".toml" ".json"];
  credentialShapes = [
    "ghp_[A-Za-z0-9]{30,}"
    "github_pat_[A-Za-z0-9_]{20,}"
    "AKIA[0-9A-Z]{16}"
    "-----BEGIN [A-Z ]*PRIVATE KEY-----"
    "sk-[A-Za-z0-9_-]{20,}"
    "xox[baprs]-[A-Za-z0-9-]{10,}"
    "AIza[0-9A-Za-z_-]{35}"
    "nvapi-[A-Za-z0-9_-]{20,}"
    "gsk_[A-Za-z0-9]{30,}"
  ];
  # Every tracked text file. `.git` is not in a flake source and `node_modules` is
  # ignored, but both are skipped explicitly so a dirty tree cannot make the walk
  # read a vendored tree.
  textFiles = let
    walk = d: let
      entries = builtins.readDir (root + "/${d}");
      rel = n:
        if d == "."
        then n
        else "${d}/${n}";
      step = n: let
        r = rel n;
      in
        if entries.${n} == "directory"
        then
          if n == ".git" || n == "node_modules"
          then []
          else walk r
        else lib.optional (lib.any (s: lib.hasSuffix s n) textSuffixes) r;
    in
      lib.concatMap step (builtins.attrNames entries);
  in
    walk ".";
  credentialHits =
    lib.concatMap (
      p: hitsWhere p (l: lib.any (s: builtins.match ".*${s}.*" l != null) credentialShapes)
    )
    textFiles;

  # Decryption during evaluation writes the plaintext into /nix/store: world
  # readable, and it survives every rotation of the credential itself.
  # The registry itself is excepted: stating this rule means naming the idiom.
  nixSources =
    builtins.filter (
      p: p != "flake/policies.nix"
    )
    (nixUnder "modules" ++ nixUnder "hosts" ++ nixUnder "flake" ++ nixUnder "lib");
  # A trailing comment that mentions the idiom is not the idiom; netbook's `sops #
  # \`sops -d\` …` line is prose about a root-only path, not an eval-time decrypt.
  codePart = l: builtins.head (lib.splitString "#" l);
  decryptAtEval =
    lib.concatMap (
      p: hitsWhere p (l: lib.hasInfix "sops -d" (codePart l))
    )
    nixSources;

  # `diff` over two decrypted documents prints both copies the moment they
  # disagree — which is exactly when someone is reading. `cmp -s` answers the same
  # question and prints nothing.
  printedDiff =
    lib.concatMap (
      p:
        hitsWhere p (
          l:
            lib.hasInfix "sops -d" l
            && (lib.hasInfix "| diff" l || lib.hasInfix "diff -" l || lib.hasInfix "diff <(" l)
        )
    )
    (shellScripts ++ taskfiles);

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

  # The agent-facing prose surfaces: the manual and every skill are read into
  # context on each turn, so their size is a cost, not an aesthetic. Shrink-only:
  # a cleanup lowers the number here in the same commit, and nothing may raise it.
  lineCount = p: builtins.length (lib.splitString "\n" (builtins.readFile p)) - 1;
  agentsLines = lineCount (root + "/AGENTS.md");
  skillFiles = builtins.filter (p: lib.hasSuffix "/SKILL.md" (toString p)) treeFiles;
  # Frontmatter is compiled metadata, not prose: `lib/skills.nix` turns it into the
  # one-line index an agent carries (`name` + `description`), so 647 of the 5927
  # raw SKILL.md lines were budgeted as context they never occupy. What a skill
  # costs is the body loaded when it is opened, and that is what is counted.
  frontmatterLines = p: let
    lines = lib.splitString "\n" (builtins.readFile p);
  in
    if lines == [] || lib.trim (builtins.head lines) != "---"
    then 0
    else builtins.length (takeWhile (l: lib.trim l != "---") (builtins.tail lines)) + 2;
  skillLines = builtins.foldl' (acc: p: acc + lineCount p - frontmatterLines p) 0 skillFiles;

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

  # Every tracked .nix / .md file, walked once: a header budget that only saw the
  # top level would miss the module tree, which is where the 30-line essays were.
  treeFiles = lib.filesystem.listFilesRecursive root;
  nixFiles = builtins.filter (p: lib.hasSuffix ".nix" (toString p)) treeFiles;
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
      rule = "AGENTS.md (482 lines) and the body of every tracked SKILL.md (5270 lines today) are shrink-only — they are the prose an agent carries or loads, so a cleanup lowers the number here in the same commit. A skill's frontmatter is NOT counted: `lib/skills.nix` compiles it into the one-line index, so it is metadata, not context. The only extension is an audited one: the audit lives in this rule text, the added prose must be a `Truth:` pointer counted by `skills-cite-truth`, and that policy must already hold. A budget that grows without either is how a corpus becomes a liability. SOFT gate: the overrun is reported with its number on every `checks.policies` run and never fails one — a cost to bring down, not a contradiction to refuse.";
      proof = "line counts of AGENTS.md and of every tracked SKILL.md minus its frontmatter block";
      # Audited 2026-10-21: 215 lines removed by collapsing the shadowed
      # `.agents/skills/simplex-admin` copy (the module is canonical and the
      # installer prefers it), 60 lines added as one `Truth:` pointer per skill
      # that had none. Net −155, cap lowered 5546 → 5526 in the same change.
      # Audited 2026-11-04: the skills figure counted YAML frontmatter (647 of
      # 5927 lines across 63 files), which the index compiles away, so the cap was
      # measuring the wrong thing — bodies are 5280, and the cap is that number.
      # AGENTS.md 941 → 927 by deleting the namespace table, a third copy of
      # docs/task-control-plane.md, .agents/README.md and `task --list-all`.
      # Audited 2026-11-06: the corpus had drifted to 5371 — `mail-alias` and
      # `envs` landed whole after the 2026-11-04 freeze and nobody paid for the
      # lines. Paid now, out of prose that duplicated a compiled surface: the
      # retired `crush` page shrank to its tombstone, knowledge-base dropped the
      # jq cookbook entries `ops:kg:host`/`:doc` already answer, and wikisearch,
      # envs, mail-alias and agents-notes lost their repeated measurements and
      # restated rules. 5371 → 5270, cap lowered with it.
      # Audited 2026-11-05: AGENTS.md 927 → 482. The manual had grown a second copy
      # of every surface that now compiles one: the xs endpoint (docs/agent-turns.md),
      # the verification protocol (docs/nix-patterns.md, the checks skill), the module
      # tree and the documentation map (.#knowledgeGraph, .#artifacts.docs), the
      # formatter table (scripts/task/nix-fmt.sh) and a packages section that claimed
      # the output was {}. What remains routes. The map is gone, so `no-orphan-docs`
      # went with it: reachability is the site index compiled from the graph.
      holds = agentsLines <= 482 && skillLines <= 5270;
      # Soft: a budget, not a contradiction — the overrun is reported with its number and never reds the gate.
      soft = true;
      detail = "AGENTS.md ${toString agentsLines}/482 lines, skill bodies ${toString skillLines}/5270 — over budget means delete or an audited `Truth:` extension, not a renumber";
    };

    rebuild-flags-are-finite = {
      rule = "Every rebuild answers exactly three questions and nothing else: who compiles (local | none | remote), whether Nix may substitute (on | off), and the flake posture (accept | impure). The host, the flake ref and the action are ARGUMENTS. The set is closed — a typo must be a usage error, not a silent local build — and defaults (local, on, accept) render nothing, because a flag is only worth printing when a decision was made. Before this, the same three decisions were spelled five ways inside `infra:switch:*` alone: `REMOTE_BUILD=1` meaning \"never compile here\", `--option max-jobs 0 --option builders \"\"` typed inline, `--impure` in one task, `--use-substitutes` in another, and nothing in the third.";
      proof = "scripts/task/rebuild-flags.sh · taskfiles/infra.yml (infra:switch:*, infra:rebuild:wsl, infra:rebuild:orb) · taskfiles/checks.yml (checks:rebuild)";
      holds =
        has "scripts/task/rebuild-flags.sh" "--self-test"
        && has "scripts/task/rebuild-flags.sh" "max-jobs 0 --option builders"
        && has "scripts/task/rebuild-flags.sh" "REBUILD_BUILDERS"
        && has "scripts/task/rebuild-flags.sh" "REBUILD_SUBSTITUTES"
        && has "scripts/task/rebuild-flags.sh" "REBUILD_FLAKES"
        # Adopted, not merely available: every switch path must render its flags.
        && builtins.length (lib.splitString "rebuild-flags.sh" (read "taskfiles/infra.yml")) > 3
        && has "taskfiles/checks.yml" "checks:rebuild";
      detail = "a rebuild path went back to spelling its own flags: the envelope lost its axes, its self-test, or one of the switch tasks stopped rendering from it";
    };

    daemon-clears-kelly = let
      d = import ./daemons.nix {inherit lib;};
      report = lib.concatStringsSep "\n  " (lib.mapAttrsToList (
          n: v: "${n}: p=${toString v.p} save=${toString v.save}s cost=${toString v.cost}s ev=${toString v.ev}s clears=${lib.boolToString v.clears} wanted=${lib.boolToString v.wanted}"
        )
        d.daemons);
    in {
      rule = "Anything that runs RESIDENT must be strictly worth more than zero, measured against what the counterfactual costs an agent rather than against a cold start. The counterfactual is generation at ~50 tokens/s, where any sub-second local round trip is free: a daemon that answers correctly saves only the tokens of naming the argument, so the bar is `ev = p * save - (1 - p) * cost > 0` with `save > 0` as well. `save` may be negative — correct and still slower is the normal failure — and a daemon with `ev == 0` is off, because it pays rent in memory, surface and maintenance for a coin flip. Enabling is a measured claim, so every entry carries the command that measured it; a daemon whose best case is a loss cannot be rescued by accuracy.";
      proof = "flake/daemons.nix · docs/nix-patterns.md · modules/roles/home.nix (selectorDaemon) · hosts/delphi/configuration.nix (edgeCaller) · checks:edge:resident and checks:selector:sidecar for the p they use";
      holds =
        d.failing
        == {}
        && d.unmeasured == {}
        # The formula is the stated one, not a constant someone computed by hand.
        # It is one exported function since 2026-11-04 (flake/epistemics.nix is the
        # second consumer), so the judgement follows the fact: the expression must
        # exist, and every daemon must be gated by applying it to its own numbers.
        && has "flake/daemons.nix" "p * save - (1.0 - p) * cost"
        && has "flake/daemons.nix" "ev d.p d.save d.cost"
        && has "flake/daemons.nix" "d.save > 0.0 && evd > 0.0"
        # Adoption, in both directions: the daemon the arithmetic refuses must not
        # be enabled by a host, and the one it justifies must not be silently off.
        && !(has "hosts/delphi/configuration.nix" "programs.edgeCaller.enable = true")
        && !(has "modules/roles/home.nix" "edgeCaller.enable = true")
        && has "modules/roles/home.nix" "selectorDaemon.enable"
        && has "docs/nix-patterns.md" "A daemon must clear the Kelly gate";
      detail = "a resident helper is enabled without a strictly positive Kelly score, or its measurement is missing:\n  ${report}";
    };

    edge-caller-before-reasoning = {
      rule = "Dispatch goes cheapest-first, on a Pareto frontier rather than a wish: needle3 (8-29 MB, on-device, calibrated confidence) takes the quadrant that is SMALL and NON-REDUCIBLE — one deterministic lookup whose answer is a value or a set it need not decompose, the class of call a reasoning model makes most often — and executes it all day. REDUCIBLE requests (two independent asks) are refused for the reasoning agent to split; LARGE requests (a judgement, an operation, or anything whose body can BUILD) are refused for it to do, and a task with a build verb is removed from the tool surface structurally rather than by a reviewer's memory. Only a low-confidence or empty answer escalates to a reasoning model. The class comes before the score — a READ-ONLY tool prefetches on any validated call, because a graph lookup cannot change anything and its answer is the question's neighbourhood; anything off that allowlist needs one call at or above ACT, may be shown for approval above CONFIRM, and declines below it. A single threshold either makes the caller decorative or dangerous. An invented tool is refused before confidence is consulted, the argument's TYPE is repaired from the graph rather than trusted, a decline from the graph router is a decline whatever its exit code, and telemetry is off in the shipped binary by default so the dispatcher sets it explicitly.";
      proof = "scripts/task/toolcall.sh · scripts/task/edge-sidecar.sh · scripts/task/edge-check.sh · scripts/task/toolcall-battery.jsonl · taskfiles/agents.yml (agents:call, agents:edge) · taskfiles/checks.yml (checks:toolcall, checks:edge)";
      holds =
        has "scripts/task/toolcall.sh" "taskfile_graph.py"
        && has "scripts/task/toolcall.sh" "confidence"
        && has "scripts/task/toolcall.sh" ''decision: "confirm"''
        && has "scripts/task/toolcall.sh" "NEEDLE_TELEMETRY=0"
        # the prefetch class is an allowlist, so a mutating task added to the
        # surface later is gated by construction instead of by someone's memory
        && has "scripts/task/toolcall.sh" "TOOLCALL_READ_ONLY:-^(ops:kg:|ops:ask$)"
        && has "scripts/task/toolcall.sh" "node_exists"
        && has "scripts/task/toolcall.sh" "intent[[:space:]]*: UNKNOWN"
        && has "scripts/task/toolcall-battery.sh" "unsafe"
        # The Pareto split is executable: a build verb removes a task from the
        # surface, a compound request is refused before the engine, and every
        # verdict is emitted so the caller knows which quadrant it is in.
        && has "scripts/task/toolcall.sh" "HEAVY_RE"
        && has "scripts/task/toolcall.sh" "JUDGEMENT_RE"
        && has "scripts/task/toolcall.sh" "pareto: \"decompose\""
        && has "scripts/task/toolcall-battery.sh" "pareto_bad"
        # Bounded, timed, one line per call: the piping contract that replaces a
        # blanket `timeout` around a long pipeline.
        && has "scripts/task/toolcall.sh" "TOOLCALL_STEP_S"
        && has "scripts/task/edge-check.sh" "gate\":\"timeout"
        && has "taskfiles/agents.yml" "agents:call:batch"
        # The resident caller is optional by construction: the dispatcher must keep
        # the one-shot fallback and its own switch, or a dead daemon becomes an
        # outage rather than 600 ms of extra latency.
        && has "scripts/task/toolcall.sh" "TOOLCALL_ONE_SHOT"
        && has "scripts/task/edge-sidecar.sh" "--serve"
        && has "scripts/task/edge-sidecar.sh" "/reset"
        # Parity is a gate, not a hope: same call both ways, timed.
        && has "scripts/task/edge-check.sh" "function_calls"
        && has "taskfiles/agents.yml" "agents:call"
        && has "taskfiles/agents.yml" "agents:edge"
        && has "taskfiles/checks.yml" "checks:toolcall"
        && has "taskfiles/checks.yml" "checks:edge"
        && builtins.pathExists (root + "/scripts/task/toolcall-battery.jsonl");
      detail = "the edge-caller path lost its derived tool set, its read-only prefetch allowlist, its confidence bands, its graph-side type repair, its telemetry opt-out, its battery gate, or the task that exposes it";
    };

    taskfiles-aggregators-declare-nothing = {
      rule = "An include-only shard is `version:` plus `includes:` and nothing else: `taskfiles/services.yml` flattens `services-core.yml` and `services-legacy.yml` so `services:*` resolves through one file. A task declared in the aggregator is invisible to the ownership map and vanishes the moment the file is read as a flatten of its children, which is why the rule is a predicate instead of a sentence stated twice.";
      proof = "taskfiles/services.yml · taskfiles/README.md";
      holds = !(lib.hasInfix "tasks:" (read "taskfiles/services.yml"));
      detail = "taskfiles/services.yml grew a `tasks:` section — declare it in services-core.yml or services-legacy.yml";
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
        lib.all (f: builtins.pathExists (root + "/${f}")) [secretsMirror "modules/ssh-ca-key.yaml"]
        && lib.all (f: anyLine f (l: lib.hasPrefix "sops:" l)) presentSopsFiles
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

    secrets-mirror-is-a-copy = {
      rule = "`modules/secrets.yaml` is a byte copy of the `modules/secrets/secrets.yaml` submodule, produced only by `task infra:secrets:sync`. A value written to one copy decrypts on the machine that wrote it and is missing on every host after the next sync, where it surfaces days later as a host that cannot decrypt, with nothing in the diff to explain it. Identity is also the cheapest possible proof: the two files are compared as ciphertext, so the gate never decrypts anything.";
      proof = "modules/secrets.yaml · modules/secrets/secrets.yaml · taskfiles/infra.yml (infra:secrets:sync)";
      holds = !mirrorDrift;
      detail = "the mirror and the submodule are no longer the same bytes — run `task infra:secrets:sync`, and never edit the mirror";
    };

    secrets-path-is-resolved-in-one-place = {
      rule = "A script never spells where a secrets file lives. It sources `scripts/task/lib/paths.sh`, which owns one resolution order: `$NIXCONFIG_SECRETS`, then the canonical submodule copy, then the committed mirror. 27 scripts each carried the path and, with it, their own answer to canonical-versus-mirror — so a writer and a reader in the same repository could disagree about which file was authoritative, and an edit could land in the copy builds never read. The two files that still name a path are the ones whose job that is: the drift gate compares the copies, and the openwrt wrapper resolves one where the submodule may be absent.";
      proof = "scripts/task/lib/paths.sh · scripts/**/*.sh · scripts/**/*.py";
      holds = secretsPathOffenders == [];
      detail = "script(s) spelling a secrets path instead of sourcing the helper: ${lib.concatStringsSep ", " secretsPathOffenders}";
    };

    secrets-files-are-registered = {
      rule = "Every encrypted file is named in the sops registry, because that registry is what the plaintext scan reads: an encrypted file outside it is a file whose plaintext nobody checks. New secret material therefore costs one line in `sopsFiles`, not a new scan.";
      proof = "flake/policies.nix (sopsFiles) · modules/secrets/*.yaml";
      holds = unregisteredSops == [];
      detail = "encrypted file(s) the plaintext gate never reads: ${lib.concatStringsSep ", " unregisteredSops}";
    };

    private-data-is-not-a-build-input = {
      rule = "A static page publishes everything its build reads, so private data never enters eval: `lib/` reads no file from the secrets submodule, which keeps `.#sites.*` buildable from a bare tree (CI, nixbuild, a clone without `--recurse-submodules`). Private facts live sops-encrypted (`modules/secrets/pii.yaml`) and a script decrypts them when it builds an outbound document. A `pathExists` guard on a build input buys nothing either: the artifact then differs between a machine with the file and one without, and the difference never appears in the diff. That is what makes `lib/matt/*.json` published data rather than a leak — the deployed page carries every value in it.";
      proof = "lib/matt/*.json · lib/bountystash/*.json · modules/sops.nix · modules/secrets/pii.yaml";
      holds = secretsReads == [];
      detail = "a library file reads the secrets submodule, so a bare-tree build fails there and only there: ${lib.concatStringsSep ", " secretsReads}";
    };

    credentials-never-land-in-a-tracked-file = {
      rule = "No tracked text file carries a credential shape — a provider prefix or a private-key header. A secret that is committed is the one that has to be rotated everywhere it is used, and rotation is the chore this gate exists to stop repeating. Values cannot be matched, so the gate matches what the issuers reserve, over every tracked markdown, Nix, shell, YAML, TOML and JSON file; it reports the file and line and never quotes the match, because a gate failure is printed into a terminal or a transcript.";
      proof = "every tracked *.md, *.nix, *.sh, *.yml, *.yaml, *.toml, *.json (encrypted blobs contain no such shape)";
      holds = credentialHits == [];
      detail = "credential-shaped text at: ${lib.concatStringsSep ", " credentialHits}";
    };

    secrets-are-not-decrypted-at-eval = {
      rule = "Nothing decrypts during evaluation: `sops -d` in a `.nix` file writes the plaintext into `/nix/store`, where it is world-readable and survives every rotation of the credential. Decryption belongs to activation (sops-nix) or to a runtime `passwordCommand`, both of which keep the value outside the store.";
      proof = "modules/**/*.nix · hosts/**/*.nix · flake/**/*.nix · lib/**/*.nix, non-comment lines";
      holds = decryptAtEval == [];
      detail = "eval-time decryption at: ${lib.concatStringsSep ", " decryptAtEval}";
    };

    decrypted-documents-are-compared-not-printed = {
      rule = "A decrypted document is compared with `cmp -s`, never `diff`, because `diff` prints both copies the moment they disagree — precisely when someone is reading the output. The question is identical and the output is empty, so a drifting mirror cannot become a transcript of both secrets.";
      proof = "scripts/task/*.sh · taskfiles/*.yml";
      holds = printedDiff == [];
      detail = "decrypt-then-diff at: ${lib.concatStringsSep ", " printedDiff}";
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
      rule = "CI builds each affected host's closure from the tree that host will evaluate (the bare git tree, which is the same source path as its `github:` tarball) and the module-system gate from `?submodules=1`.";
      proof = ".github/workflows/nixcachix.yml";
      # Build from `.#`, not `.?submodules=1#`: submodule contents make a second
      # tree, and a host's `github:` ref cannot even take the parameter
      # ("contains unknown parameter 'submodules'"). Measured 2026-11-02: frieren
      # rebuilt 34 derivations on a commit CI had already built.
      holds =
        has ".github/workflows/nixcachix.yml" "nix build -L \".#\${attr}\""
        && has ".github/workflows/nixcachix.yml" "?submodules=1#hostChecks."
        && has ".github/workflows/nixcachix.yml" "pipe-operators";
      detail = "the workflow stopped building host closures from the host's tree (.#attr), lost the submodule hostChecks gate, or dropped pipe-operators";
    };

    host-path-pinned-to-submodules = {
      rule = "Every task-surface reference to a host closure carries `?submodules=1` for a LOCAL tree, so the path a local switch evaluates is the path a warm built. A remote host's ref is a `github:` tarball, which takes no such parameter: warming for it means building the same bare tree (see `docs/nix-patterns.md`).";
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

    ci-task-graph = {
      rule = "The task graph is gated on every push, doc-only included: duplicate keys, dangling references, include cycles, orphan shards, MATCH arity and an exit code a summary promises but its script never emits are hard violations, the name set must equal `task --list-all --json`, and the fixture must violate every bucket where it says it does. A shard rewrite that no test covers then cannot ship silent.";
      proof = ".github/workflows/nixcachix.yml (the `docs-budget` job runs scripts/task/taskfile-graph.sh)";
      holds = has ".github/workflows/nixcachix.yml" "taskfile-graph.sh";
      detail = "the workflow lost the task-graph step; shard drift now reaches a deploy unflagged";
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

    agent-boundary-is-toon = {
      rule = "An agent's boundary is TOON in both directions: it reads a TOON document and it writes a TOON document, and the converter owns every quote, delimiter and `[n]` row count. JSON stays the linking layer a PROGRAM consumes (jq, a flake output, an API body) and TOML, YAML and Nix stay source of truth crossing in their own tool. Hand-writing JSON or YAML at the agent boundary is where tabs, quotes and counts get mangled, repeatedly; so the surface is compiled rather than typed — every agent-facing answer is encoded by `toon -e`, every agent-authored table is a `.toon` document that strict-decodes. There is no third path: a surface that concatenates its own output, or parses its own input with a hand-rolled reader, is the bug this rule names.";
      proof = "scripts/task/q.sh · scripts/task/selector-battery.toon · scripts/task/selector-check.sh · taskfiles/ops.yml (ops:q) · taskfiles/checks.yml (checks:selector, checks:toon, checks:toon:surfaces) · .agents/SCHEMA.md §Formats";
      holds =
        has "scripts/task/q.sh" "| toon -e"
        && has "scripts/task/q.sh" "toon -d"
        && has "scripts/task/selector-check.sh" "toon -d"
        && has "taskfiles/ops.yml" "ops:q"
        && has "taskfiles/checks.yml" "checks:selector"
        && has "taskfiles/checks.yml" "checks:toon"
        && has ".agents/SCHEMA.md" "never becomes the record of machine state";
      detail = "an agent-facing surface formats its own output or parses its own input instead of letting the converter cross the boundary; the `[n]`, the quoting and the delimiter drift one edit later.";
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

    library-content-is-not-scheduled = {
      rule = "A library on a network mount is pulled by a LAUNCH and by nothing else: no timer, no login job, no path unit watching for a fresh drop, and no unit may open an image to read a `.desktop` file, a version or an icon out of it. A stale cache is flushed and re-fetched on the next launch — never warmed because the library changed, because that turns one upgrade into a LAN-wide congestion event.";
      proof = "scripts/task/appimage-integrate.sh (deleted 2026-10-28) · the `appimage-launchers` user unit (login + hourly)";
      holds =
        scheduledLibraryExtractions
        == []
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

    desktop-cache-declared-once = {
      rule = "A desktop's binary cache has ONE declaration: the desktop's own module. The host profile states the enable flag explicitly, because a default is upstream's to flip, and never repeats the URL in `nix.settings` — a second declaration lists the cache twice in `nix.conf` and hides which module actually owns it.";
      proof = "modules/profiles/ryoku-desktop.nix (programs.ryoku.binaryCache.enable) · Ryoku's own `cfg.binaryCache.enable`, which adds `ryotunes.cachix.org`";
      # The ASSIGNMENT, not the mention: naming the cache while explaining why the
      # module owns it is the point, assigning `substituters` here is the fault.
      holds =
        has "modules/profiles/ryoku-desktop.nix" "binaryCache.enable = true"
        && !(has "modules/profiles/ryoku-desktop.nix" "substituters =")
        && !(has "modules/profiles/ryoku-desktop.nix" "nix.settings");
      detail = "the Ryoku profile stopped stating its cache flag, or re-declared the cache address beside the module that already owns it";
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
