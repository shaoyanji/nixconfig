# lib/taskfile.nix — the Taskfile graph as data: names, fields, refs, includes.
# Nix owns the graph; go-task owns the moment (`{{.HOST}}` stays opaque data).
# Grammar, buckets, parity oracle and versioning: docs/task-control-plane.md.
{
  lib,
  # Overridable so the fixture in tests/taskfile-graph/ can prove each bucket
  # still bites. A gate that has only ever been run against a clean tree is a
  # gate nobody knows the shape of.
  root ? ../.,
}: let
  shardDir = root + "/taskfiles";
  shardFiles =
    if builtins.pathExists shardDir
    then builtins.filter (n: lib.hasSuffix ".yml" n) (builtins.attrNames (builtins.readDir shardDir))
    else [];

  # --- line model -------------------------------------------------------
  isBlank = l: builtins.match "[[:space:]]*" l != null;
  isComment = l: builtins.match "[[:space:]]*#.*" l != null;
  unquote = s: let
    m = builtins.match "\"(.*)\"" s;
  in
    if m == null
    then s
    else builtins.head m;

  mkLine = l: {
    i = builtins.stringLength (builtins.head (builtins.match "([ ]*).*" l));
    t = lib.trim l;
  };

  # Blank lines are dropped: YAML folds a `>` scalar's blank lines into a
  # hard newline, which this reader renders as a space. No `desc`/`summary` in
  # this repo uses `>` with a blank line, and the parity gate would catch it if
  # one appeared — it compares the folded text to what go-task reports.
  significant = text:
    map mkLine (builtins.filter (l: !(isBlank l) && !(isComment l)) (lib.splitString "\n" text));

  takeWhile = pred: xs:
    if xs == [] || !(pred (builtins.head xs))
    then []
    else [(builtins.head xs)] ++ takeWhile pred (builtins.tail xs);

  indexWhere = pred: xs: let
    go = k: rest:
      if rest == []
      then builtins.length xs
      else if pred (builtins.head rest)
      then k
      else go (k + 1) (builtins.tail rest);
  in
    go 0 xs;

  # --- sections ---------------------------------------------------------
  # Two sections a gate reads: `tasks:` and `includes:`. Children sit at the
  # indent the file chose, so that indent is measured, not assumed. Blocks are
  # returned in file order, which is also the order go-task loads them.
  blocks = key: lines: let
    idx = indexWhere (l: l.i == 0 && l.t == "${key}:") lines;
    after =
      if idx >= builtins.length lines
      then []
      else lib.drop (idx + 1) lines;
    childIndent =
      if after == [] || (builtins.head after).i == 0
      then null
      else (builtins.head after).i;
    body =
      if childIndent == null
      then []
      else takeWhile (l: l.i >= childIndent) after;
    step = acc: l:
      if l.i == childIndent
      then let
        n = unquote (lib.removeSuffix ":" l.t);
      in {
        current = n;
        order = acc.order ++ [n];
        chunks = acc.chunks // {${n} = [];};
      }
      else if acc.current == null
      then acc
      else
        acc
        // {
          chunks = acc.chunks // {${acc.current} = acc.chunks.${acc.current} ++ [l];};
        };
    final =
      lib.foldl' step {
        current = null;
        order = [];
        chunks = {};
      }
      body;
  in
    if body == []
    then []
    else
      map (n: {
        name = n;
        body = final.chunks.${n};
      })
      final.order;

  section = blocks;

  # --- fields -----------------------------------------------------------
  fieldIndent = body:
    if body == []
    then 0
    else (builtins.head body).i;

  # `aliases:` is the one field a gate needs structurally (a reference may
  # resolve to an alias), and it is a YAML list, so it is read as one.
  listField = name: body: let
    idx = fieldIndex name body;
  in
    if idx >= builtins.length body
    then []
    else let
      line = builtins.elemAt body idx;
      items = takeWhile (l: l.i > line.i || lib.hasPrefix "- " l.t) (lib.drop (idx + 1) body);
    in
      map (l: unquote (lib.removePrefix "- " l.t)) (builtins.filter (l: lib.hasPrefix "- " l.t) items);

  fieldIndex = name: body: let
    ind = fieldIndent body;
  in
    indexWhere (l: l.i == ind && builtins.match "${name}:.*" l.t != null) body;

  # Inline value, block value (`>` folds to spaces, `|` keeps newlines), or null.
  field = name: body: let
    idx = fieldIndex name body;
    kw = builtins.stringLength name + 1;
  in
    if idx >= builtins.length body
    then null
    else let
      line = builtins.elemAt body idx;
      raw = lib.trim (builtins.substring kw 99999 line.t);
      style =
        if builtins.match "[>|][-+0-9]*" raw == null
        then null
        else builtins.substring 0 1 raw;
      cont = takeWhile (l: l.i > line.i) (lib.drop (idx + 1) body);
    in
      if style == null
      then unquote raw
      else
        lib.concatStringsSep (
          if style == "|"
          then "\n"
          else " "
        ) (map (l: l.t) cont);

  bodyText = body: lib.concatStringsSep "\n" (map (l: l.t) body);

  # A list-valued field (`cmds:`, `deps:`, `sources:`) is `field`'s blind spot:
  # the key line has an empty value, so `field` returns "". The list body is the
  # child lines, which is what a reference scan needs.
  blockField = name: body: let
    idx = fieldIndex name body;
  in
    if idx >= builtins.length body
    then []
    else map (l: l.t) (takeWhile (l: l.i > (builtins.elemAt body idx).i) (lib.drop (idx + 1) body));

  # A reference is only real in a COMMAND position: line start (after the YAML
  # list dash), or after `$(`, `&&`, `||`, `;`, `|`. Matching `task <word>`
  # anywhere else counts prose — the first version of this file did that and
  # reported 34 "dangling" refs, ~30 of which were English ("task name",
  # "task keys", `task keys.`). An advisory bucket full of prose is slop, so the
  # two are separated: `danglingRef` can fail a gate, `proseRef` cannot.
  refPattern = "(.*[;&|(][[:space:]]*)?task ([A-Za-z0-9:._*-]+).*";
  # `task --list-all` / `task -t other.yml` / `task -d dir` are flags, not names.
  refsInLine = raw: let
    line = lib.removePrefix "- " (lib.trim raw);
    m =
      if lib.hasPrefix "#" line
      then null
      else builtins.match refPattern line;
    name =
      if m == null
      then null
      else builtins.elemAt m 1;
  in
    if name == null || builtins.match "-.*" name != null
    then []
    else [name];

  # Prose is noisier than code, so it is matched narrowly: a backticked
  # `` `task foo` `` or a namespaced `task ns:verb`. A bare `task name` in a
  # sentence is English ("a task that does not exist"), not a reference —
  # matching those made the advisory list unreadable.
  proseBackticked = "`task ([A-Za-z0-9:._*-]+)`";
  # At least one character AFTER the namespace separator, and no `.` in the tail:
  # without that, the sentence "confirmed against go-task itself." yielded the
  # "reference" `itself.` (`itself` + `.` + nothing), which is a regex artifact
  # masquerading as a stale doc reference.
  proseNamespaced = "task ([a-z0-9-]+[:.][A-Za-z0-9:_*-]+)";
  proseHits = pattern: text: map (m: builtins.head m) (builtins.filter builtins.isList (builtins.split pattern text));
  proseRefsIn = text:
    if text == null
    then []
    else
      builtins.filter (n: builtins.match "-.*" n == null) (
        proseHits proseBackticked text ++ proseHits proseNamespaced text
      );

  parseTask = shard: entry: let
    body = entry.body;
    text = bodyText body;
    desc = field "desc" body;
  in {
    inherit shard desc;
    name = entry.name;
    body = text;
    summary = field "summary" body;
    wildcards = builtins.length (builtins.filter (c: c == "*") (lib.stringToCharacters entry.name));
    # POSIX ERE: a literal `[` is `[[]`.
    matchIndices = map (m: lib.toInt (builtins.head m)) (
      builtins.filter builtins.isList (builtins.split "[{]\\{index .MATCH ([0-9]+)[}][}]" text)
    );
    refs = lib.concatMap refsInLine (blockField "cmds" body);
    proseRefs = lib.unique (proseRefsIn desc ++ proseRefsIn (field "summary" body));
    cmds = blockField "cmds" body;
    aliases = listField "aliases" body;
    retired = builtins.match ".*[[](removed|deprecated)[]].*" text != null;
    internal = field "internal" body == "true";
    declaresSources = field "sources" body != null || field "generates" body != null;
    declaresWatch = field "watch" body == "true";
  };

  # --- include graph ----------------------------------------------------
  # Parsed structurally, not by searching the concatenated text for each
  # shard name: `lib.hasInfix` is `builtins.match ".*pat.*"`, and running that
  # over ~300 KiB of YAML overflowed the C stack ("possible infinite recursion").
  #
  # Includes nest (`taskfiles/services.yml` includes `./services-core.yml`), so
  # the graph is walked, not listed: a one-level read missed 18 tasks and
  # reported two live shards as orphans. Paths resolve relative to the file
  # that declares them, and `ancestors` is the cycle detector — go-task itself
  # refuses a cycle with exit 110, so a gate should say which edge closes it.
  dirOf = p: let
    parts = lib.splitString "/" p;
  in
    if builtins.length parts <= 1
    then ""
    else lib.concatStringsSep "/" (lib.init parts);

  normalize = dir: p: let
    segments = lib.splitString "/" (
      if dir == ""
      then p
      else "${dir}/${p}"
    );
    step = acc: s:
      if s == "" || s == "."
      then acc
      else if s == ".."
      then
        (
          if acc == []
          then []
          else lib.init acc
        )
      else acc ++ [s];
  in
    lib.concatStringsSep "/" (lib.foldl' step [] segments);

  edgesOf = rel:
    map (e: {
      alias = e.name;
      from = rel;
      taskfile = field "taskfile" e.body;
      path =
        if field "taskfile" e.body == null
        then null
        else normalize (dirOf rel) (field "taskfile" e.body);
      flatten = field "flatten" e.body == "true";
      dir = field "dir" e.body;
    }) (blocks "includes" (significant (builtins.readFile (root + "/${rel}"))));

  walk = rel: ancestors: let
    out = edgesOf rel;
    exists = e: e.path != null && builtins.pathExists (root + "/${e.path}");
    cycles = builtins.filter (e: e.path != null && builtins.elem e.path ancestors) out;
    missing = builtins.filter (e: !(exists e)) out;
    descend = builtins.filter (e: exists e && !(builtins.elem e.path ancestors)) out;
    sub = map (e: walk e.path (ancestors ++ [e.path])) descend;
  in {
    order = [rel] ++ lib.concatMap (s: s.order) sub;
    edges = out ++ lib.concatMap (s: s.edges) sub;
    # `inherit cycles missing` dropped a nested edge's own defects: a cycle or a
    # dangling include declared one level down (in services.yml, say) never
    # reached the gate. The fixture caught it.
    cycles = cycles ++ lib.concatMap (s: s.cycles) sub;
    missing = missing ++ lib.concatMap (s: s.missing) sub;
  };

  graph = walk "Taskfile.yml" ["Taskfile.yml"];
  includes = graph.edges;
  files = lib.unique graph.order;

  # Reachability, not membership: a shard is an orphan only when no include
  # edge anywhere in the graph points at it.
  reachable = builtins.filter (p: p != null) (map (e: e.path) includes);

  parsed =
    lib.concatMap (
      f: map (parseTask f) (section "tasks" (significant (builtins.readFile (root + "/${f}"))))
    )
    files;

  names = map (t: t.name) parsed;
  byName = lib.foldl' (a: t: a // {${t.name} = t;}) {} parsed;

  # Wildcard tasks match a concrete invocation segment-for-segment
  # (`infra:deploy:host:*` ↔ `infra:deploy:host:fern`). A prefix test was the
  # first version and it accepted `dev:nixbuild:pl` as a call to
  # `dev:nixbuild:plan`; the star is a whole segment, so compare segments.
  segments = lib.splitString ":";
  wildNames = builtins.filter (n: lib.hasInfix "*" n) names;
  wildMatch = pat: ref: let
    p = segments pat;
    r = segments ref;
    n = builtins.length p;
  in
    n
    == builtins.length r
    && lib.all (i: builtins.elemAt p i == "*" || builtins.elemAt p i == builtins.elemAt r i) (lib.range 0 (n - 1));

  aliases = lib.concatMap (t: t.aliases) parsed;
  resolves = ref: builtins.elem ref names || builtins.elem ref aliases || lib.any (w: wildMatch w ref) wildNames;

  # `task checks:host:HOST=minyx` and `task infra:deploy:host:<host>` are both
  # valid go-task calls with fixed arguments: strip the assignment, then peel
  # argument segments (`HOST`, `<host>`) until a known name remains. Anything
  # left over is a genuinely dangling reference.
  argLike = s: builtins.match "([A-Z][A-Z0-9_]*|[<][^>]*>)" s != null;
  refName = ref: let
    m = builtins.match "([^=]*)=.*" ref;
    cleaned =
      if m == null
      then ref
      else builtins.head m;
    try = parts:
      if parts == []
      then null
      else if resolves (lib.concatStringsSep ":" parts)
      then lib.concatStringsSep ":" parts
      else if argLike (lib.last parts)
      then try (lib.init parts)
      else null;
  in
    try (segments cleaned);

  # `checks:*` in prose names a namespace family, not a task, and is legitimate
  # writing ("run the checks:* gates"). Family references resolve only for the
  # advisory prose bucket; a `cmds` line still has to name something runnable.
  familyLike = r: lib.hasSuffix ":*" r && lib.any (n: lib.hasPrefix (lib.removeSuffix "*" r) n) names;

  counts = name: builtins.length (builtins.filter (n: n == name) names);
  duplicates = builtins.filter (n: counts n > 1) (lib.unique names);

  orphanShards = builtins.filter (f: !(builtins.elem "taskfiles/${f}" reachable)) shardFiles;
  missingIncludes = graph.missing;
  # A cycle is the incident that made `task` exit 110 for every root invocation
  # (2026-10-08, see Taskfile.yml), so the gate names the closing edge.
  cycles = graph.cycles;
  unflattened = builtins.filter (e: !e.flatten) includes;

  descBudget = 240;
  # `summary` is the MCP/agent surface (AGENTS.md "Taskfile as the Agent
  # Contract"): the variable/exit-code contract plus what the gate does NOT
  # prove, in one screen. It had drifted to a 3400-char essay on `checks:host`,
  # which is a page an agent pays for on every `--list-all --json` read, so the
  # budget is a gate now rather than a suggestion.
  summaryBudget = 600;

  # `<ns>:<verb>[:<arg>…]`, `*` only ever trailing. Every segment lowercase.
  nameOk = n: builtins.match "[a-z0-9][a-z0-9-]*([:.][a-z0-9*][a-z0-9.*-]*)*" n != null;

  # --- exit codes: the promise vs the shell that keeps it ----------------
  # A summary that promises an exit code is a contract, and nothing compared it
  # to the script that implements it: when the over-budget summaries were shrunk
  # to the 600-char contract, `checks:ports` lost "1 = STRICT drift" and the task
  # kept exiting 1. Prose and code drifted with no gate in between, so there is
  # one now. Five rules keep it quiet enough to be fatal:
  #   * a claim is `exit N` / `exits N` / `Exit N (…)`, plus `N = …` pairs in a
  #     summary that names an exit at all ("Exit 0 = clean, 1 = drift, 2 = …");
  #   * a claim may name a band (`exit 130-137`): the band holds when the task
  #     emits any code inside it, so the parser reads both endpoints instead of
  #     silently truncating the promise to its left edge;
  #   * 0 is never a claim — every script can exit 0;
  #   * a script emits every literal `exit N`, plus the repo's `fail=1 … exit
  #     "$fail"` idiom, which a literal-only scan called two correct summaries
  #     wrong (`checks:build:route`, `infra:warm:host:*`);
  #   * only the scripts and inline commands the task itself runs count — a
  #     summary describing another task's codes is not this task's contract.
  scriptRef = "(scripts/task/[A-Za-z0-9._/-]+[.]sh)";
  scriptRefs = t: lib.unique (lib.concatMap (c: capturesFirst scriptRef c) t.cmds);
  # The number is the second capture group in every pattern below, so one
  # accessor serves them all: `exit[[:space:]]+(1)` and `(fail)=1` both put it
  # at index 1 of the match's group list.
  captures = pattern: text: map (m: builtins.elemAt m 1) (builtins.filter builtins.isList (builtins.split pattern text));
  # Same, for a pattern whose first group is the number (`1 =`).
  capturesFirst = pattern: text: map (m: builtins.elemAt m 0) (builtins.filter builtins.isList (builtins.split pattern text));
  codesIn = text:
    lib.unique (
      map lib.toInt (captures "(exit)[[:space:]]+([0-9]+)" text)
      ++ lib.optionals (lib.hasInfix "exit \"$" text) (map lib.toInt (captures "(fail|rc|status|code)=([0-9]+)" text))
    );
  # Claims carry a band, not a number: `exit 7` is 7-7. The first parser read
  # only the left endpoint of `exit 130-137`, so a summary could promise the band
  # while the script emitted a code outside it and the gate still passed.
  claim = lo: hi: {inherit lo hi;};
  claimText = c:
    if c.lo == c.hi
    then toString c.lo
    else "${toString c.lo}-${toString c.hi}";
  claimHolds = c: n: n >= c.lo && n <= c.hi;
  claimWithin = outer: inner: inner.lo >= outer.lo && inner.hi <= outer.hi;
  claimMatches = pattern: summary: builtins.filter builtins.isList (builtins.split pattern summary);
  claimsIn = summary:
    if summary == null
    then []
    else let
      bands = map (m: claim (lib.toInt (builtins.elemAt m 1)) (lib.toInt (builtins.elemAt m 2))) (claimMatches "([Ee]xits?)[[:space:]]*[(]?([0-9]+)[[:space:]]*[-–][[:space:]]*([0-9]+)" summary);
      singles = map (m: let n = lib.toInt (builtins.elemAt m 1); in claim n n) (claimMatches "([Ee]xits?)[[:space:]]*[(]?([0-9]+)" summary);
      # The `N = …` list only means anything when the summary named an exit at
      # all; otherwise a version number in prose ("v2 = …") becomes a claim.
      named = bands != [] || singles != [];
      listedBands =
        if named
        then map (m: claim (lib.toInt (builtins.elemAt m 0)) (lib.toInt (builtins.elemAt m 1))) (claimMatches "([0-9]+)[[:space:]]*[-–][[:space:]]*([0-9]+)([[:space:]]*=)" summary)
        else [];
      listedSingles =
        if named
        then map (m: let n = lib.toInt (builtins.elemAt m 0); in claim n n) (claimMatches "([0-9]+)([[:space:]]*=)" summary)
        else [];
      allBands = bands ++ listedBands;
      # `130-137 = …` also matches the single-number pattern on its right edge;
      # a single already covered by a band is the same promise twice.
      allSingles = builtins.filter (s: !(builtins.any (b: claimWithin b s) allBands)) (singles ++ listedSingles);
    in
      builtins.filter (c: !(c.lo == 0 && c.hi == 0)) (lib.unique (allBands ++ allSingles));
  # `builtins.pathExists` cannot answer "is this script in the tree?": on a lazy
  # flake source it reports false for a path that is merely not yet realized, and
  # the first version of this rule called 20 existing scripts "not in the tree".
  # `readDir` does realize the source, so the directory listing is the membership
  # test. tryEval keeps a root without `scripts/` (the fixture) working.
  scriptListing = builtins.tryEval (builtins.readDir (root + "/scripts/task"));
  scriptFiles =
    if scriptListing.success
    then map (n: "scripts/task/" + n) (builtins.attrNames scriptListing.value)
    else [];
  exitFacts =
    map (
      t: let
        claims = claimsIn t.summary;
        refs = scriptRefs t;
        known = builtins.filter (r: builtins.elem r scriptFiles) refs;
        inline = lib.concatMap codesIn t.cmds;
        emitted = lib.unique (inline ++ lib.concatMap (r: codesIn (builtins.readFile (root + ("/" + r)))) known);
        # A band holds when any emitted code falls inside it: `130-137` is one
        # failure mode (killed by a signal), not seven separate contracts.
        drifting = builtins.filter (c: !(builtins.any (e: claimHolds c e) emitted)) claims;
        # A claim can only be judged against something that states a code. A task
        # that just runs `nix build` inherits that tool's status, so there is
        # nothing to compare — failing those would fail correct summaries
        # (`checks:toml:lint` claims 1 from the parser's own exit).
        status =
          if claims == []
          then "none"
          else if known != refs
          then "unverified"
          else if inline == [] && known == []
          then "opaque"
          else if drifting == []
          then "ok"
          else "drift";
      in {
        inherit t claims refs known emitted drifting status;
      }
    )
    parsed;

  # Buckets, not one flat list: a gate reports per class (counts are the review),
  # and a bucket can be adopted or rejected independently — e.g. name grammar is
  # advisory until every name conforms.
  violations = {
    orphanShard = orphanShards;
    missingInclude = map (e: "${e.from}: ${e.alias} -> ${toString e.path}") missingIncludes;
    includeCycle = map (e: "${e.from}: ${e.alias} -> ${toString e.path}") cycles;
    unflattened = map (e: "${e.from}: ${e.alias} -> ${toString e.path}") unflattened;
    duplicate = duplicates;
    nameGrammar = map (t: "${t.shard}:${t.name}") (builtins.filter (t: !(nameOk t.name)) parsed);
    # Both directions: a star with no MATCH is dead syntax, and a MATCH with no
    # star reads `.MATCH 0` from a match that never happened. The first version
    # only checked the first direction, so the fixture's zero-star `wild` task
    # passed while being unrunnable.
    wildcardArity =
      map (t: "${t.shard}:${t.name} has ${toString t.wildcards} '*' but ${toString (builtins.length t.matchIndices)} MATCH refs [${lib.concatMapStringsSep "," toString t.matchIndices}]")
      (builtins.filter (t: builtins.length t.matchIndices != t.wildcards) parsed);
    internal = map (t: "${t.shard}:${t.name}") (builtins.filter (t: t.internal) parsed);
    # `desc` is the human `task --list` line; omitting it is the documented way
    # to keep a task (e.g. `exit`) off that list. A task with neither `desc` nor
    # `summary` is invisible to BOTH surfaces, and that is the defect.
    noDesc = map (t: "${t.shard}:${t.name}") (builtins.filter (t: t.desc == null && t.summary == null) parsed);
    longDesc =
      map (t: "${t.shard}:${t.name} (${toString (builtins.stringLength t.desc)})")
      (builtins.filter (t: t.desc != null && builtins.stringLength t.desc > descBudget) parsed);
    longSummary =
      map (t: "${t.shard}:${t.name} (${toString (builtins.stringLength t.summary)})")
      (builtins.filter (t: t.summary != null && builtins.stringLength t.summary > summaryBudget) parsed);
    sourcesWithoutWatch = map (t: "${t.shard}:${t.name}") (builtins.filter (t: t.declaresSources && !t.declaresWatch) parsed);
    danglingRef =
      lib.concatMap (
        t: map (r: "${t.shard}:${t.name} -> ${r}") (builtins.filter (r: refName r == null) t.refs)
      )
      parsed;
    # Advisory: a `task X` mentioned in a desc/summary that no longer exists.
    # Not a gate failure — prose is allowed to name a task family or a
    # hypothetical call — but it is the same drift signal one step early.
    proseRef =
      lib.concatMap (
        t: map (r: "${t.shard}:${t.name} -> ${r}") (builtins.filter (r: refName r == null && !(familyLike r)) t.proseRefs)
      )
      parsed;
    # A claim naming a code nothing in the task emits. A referenced script that
    # is not in the tree is not drift — it may be generated — but a claim resting
    # on one is unverified, and saying so beats a silent pass.
    exitDrift =
      map (
        f: "${f.t.shard}:${f.t.name} claims exit ${lib.concatMapStringsSep ", " claimText f.drifting}; emits [${lib.concatMapStringsSep " " toString f.emitted}]"
      )
      (builtins.filter (f: f.status == "drift") exitFacts);
    exitUnverified =
      map (
        f: "${f.t.shard}:${f.t.name} claims exit ${lib.concatMapStringsSep ", " claimText f.claims} but ${lib.concatMapStringsSep ", " toString (builtins.filter (r: !(builtins.elem r f.known)) f.refs)} is not in the tree"
      )
      (builtins.filter (f: f.status == "unverified") exitFacts);
    retiredRef =
      lib.concatMap (
        t:
          map (r: "${t.shard}:${t.name} -> ${r}") (
            builtins.filter (r: let
              n = refName r;
              d =
                if n == null
                then null
                else byName.${n} or null;
            in
              d != null && d.retired && n != t.name)
            t.refs
          )
      )
      parsed;
  };

  issues = builtins.concatLists (map (k: map (v: "${k}: ${v}") violations.${k}) (builtins.attrNames violations));

  # What a gate may fail on. Everything else is a report: a budget that is
  # already exceeded (15 long summaries today) cannot fail a gate without a
  # ratchet, and a ratchet belongs in the gate's own state, not in this lib.
  gateBuckets = [
    "duplicate"
    "orphanShard"
    "missingInclude"
    "includeCycle"
    "unflattened"
    "internal"
    "wildcardArity"
    "danglingRef"
    "retiredRef"
    "sourcesWithoutWatch"
    # Promoted once the tree fit: 28 summaries were over 600 chars, all rewritten
    # to the contract. A budget that is only reported is a budget that drifts.
    "longSummary"
    "longDesc"
    "noDesc"
    # The same argument one step further: a promised exit code is the contract's
    # sharpest clause, and it is the clause prose can silently lose while the
    # script keeps the behaviour (see exitFacts above).
    "exitDrift"
  ];
  gateFailures = builtins.concatLists (map (k: violations.${k}) gateBuckets);

  # The execution surface and its digest. Two trees with the same `version`
  # would run the same commands, which is the handle an experiment or a failover
  # needs to pin ("mint this graph, keep the old one addressable, swap back").
  # `desc`/`summary` are excluded on purpose: editing prose must not look like a
  # change in what executes.
  surface =
    map (t: {
      inherit (t) name shard cmds;
    })
    parsed;
  version = builtins.substring 0 12 (builtins.hashString "sha256" (builtins.toJSON surface));

  # Prose is excluded from `version` on purpose — editing a summary must not look
  # like a change in behaviour — which leaves a prose edit with no address at all.
  # So prose gets its own digest over the same task order, and the artifact name
  # carries both: `<version>` is what executes, `<proseVersion>` is what an agent
  # reads. A prose-only edit then still mints a distinct, buildable path.
  proseSurface =
    map (t: {
      inherit (t) name shard desc summary;
    })
    parsed;
  proseVersion = builtins.substring 0 12 (builtins.hashString "sha256" (builtins.toJSON proseSurface));
in {
  inherit
    parsed
    names
    byName
    files
    issues
    violations
    shardFiles
    includes
    descBudget
    summaryBudget
    gateBuckets
    gateFailures
    surface
    version
    proseSurface
    proseVersion
    ;
  count = builtins.length parsed;
  wildcards = builtins.filter (t: t.wildcards > 0) parsed;
  # Cheap projections for gates and menus; never a second definition of a task.
  stats = {
    withDesc = builtins.length (builtins.filter (t: t.desc != null) parsed);
    withSummary = builtins.length (builtins.filter (t: t.summary != null) parsed);
    longestDesc =
      builtins.foldl' (
        a: t:
          if t.desc != null && builtins.stringLength t.desc > a.len
          then {
            len = builtins.stringLength t.desc;
            task = t.name;
          }
          else a
      ) {
        len = 0;
        task = "";
      }
      parsed;
  };
}
