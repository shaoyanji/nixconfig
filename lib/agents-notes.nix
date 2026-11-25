# lib/agents-notes.nix — compile AGENTS.nix into a validated note index.
{
  lib,
  inventory ? null,
  notes ? import ../AGENTS.nix,
  claimOf ? (import ../flake/epistemics.nix {inherit lib;}).noteClaims,
  turns ? {},
}: let
  root = ../.;
  raw = notes.notes or {};

  kinds = ["decision" "proposal" "open" "experiment" "handoff" "reference"];
  forNames = f: names: lib.genAttrs names f;
  statuses = [
    "PROPOSED"
    "ACCEPTED"
    "IN FLIGHT"
    "DELIVERED"
    "CLOSED"
    "SUPERSEDED"
    "REJECTED"
    "BLOCKED"
    "OPEN"
  ];
  priorities = ["P0" "P1" "P2" "P3" "P4" "P5" "P6"];
  openStatuses = ["PROPOSED" "ACCEPTED" "IN FLIGHT" "BLOCKED" "OPEN"];

  rel = p: root + "/${p}";
  exists = p: p |> rel |> builtins.pathExists;
  idOk = id: builtins.match "[a-z0-9][a-z0-9-]*" id != null;

  refsOf = n: let
    r = n.refs or {};
  in
    if builtins.isAttrs r
    then r
    else {};
  hostsOf = n: (refsOf n).hosts or [];
  modulesOf = n: (refsOf n).modules or [];
  tasksOf = n: (refsOf n).tasks or [];
  docsOf = n: (refsOf n).docs or [];
  hasRefs = n: (hostsOf n ++ modulesOf n ++ tasksOf n ++ docsOf n) != [];

  # Lineage. `links` is an undirected peer edge ("same thread") and says nothing
  # about which came first. `from` and `supersedes` are the directed ones: they
  # are what make a delivered note usable as provenance instead of a dead file.
  # Everything below (ancestors, descendants, replacedBy) is DERIVED from those
  # two fields, so a note never stores the same edge twice.
  fromOf = n: n.from or [];
  supersedesOf = n: n.supersedes or [];
  parentsOf = n: fromOf n ++ supersedesOf n;

  hostNames =
    if inventory == null
    then []
    else inventory.hosts |> builtins.attrNames;
  unknownHosts = n: n |> hostsOf |> builtins.filter (h: !(hostNames |> builtins.elem h));
  missing = xs: xs |> builtins.filter (p: !(p |> exists));

  bodyOf = n: n.body or "";
  bodyLines = n: let
    b = bodyOf n;
  in
    if b == ""
    then 0
    else b |> lib.removeSuffix "\n" |> lib.splitString "\n" |> builtins.length;
  summaryOf = n: n.summary or "";

  noteIds = raw |> builtins.attrNames;
  claimKindOf = n: claimOf.${n.kind or ""} or null;

  # --- validation ------------------------------------------------------------
  # Each note contributes zero or more issues. The gate
  # (`checks.<system>.agents-notes-schema`) throws on a non-empty list, so a bad
  # note cannot land.
  issuesFor = id: n:
    lib.optional (!(idOk id)) "${id}: id must match [a-z0-9][a-z0-9-]*"
    ++ lib.optional ((n.title or "") == "") "${id}: missing title"
    ++ lib.optional (!(builtins.elem (n.kind or "") kinds))
    "${id}: kind must be one of ${lib.concatStringsSep ", " kinds}"
    ++ lib.optional (!(builtins.elem (n.status or "") statuses))
    "${id}: status must be one of ${lib.concatStringsSep ", " statuses}"
    ++ lib.optional (
      let
        p = n.priority or null;
      in
        p != null && !(builtins.elem p priorities)
    ) "${id}: priority must be one of ${lib.concatStringsSep ", " priorities} or null"
    ++ lib.optional (summaryOf n == "") "${id}: missing summary"
    ++ lib.optional (claimOf != {} && claimKindOf n == null)
    "${id}: kind '${n.kind or ""}' has no claim kind in flake/epistemics.nix noteClaims"
    ++ lib.optional (builtins.stringLength (summaryOf n) > 400)
    "${id}: summary is longer than 400 chars (move detail to body)"
    ++ (n |> unknownHosts |> map (h: "${id}: refs.hosts names unknown host '${h}'"))
    ++ (n |> modulesOf |> missing |> map (p: "${id}: refs.modules path does not exist: ${p}"))
    ++ (n |> docsOf |> missing |> map (p: "${id}: refs.docs path does not exist: ${p}"))
    ++ (n |> tasksOf |> builtins.filter (t: t == "") |> map (_: "${id}: refs.tasks entry is empty"))
    ++ ((n.links or []) |> builtins.filter (l: !(noteIds |> builtins.elem l)) |> map (l: "${id}: links names unknown note '${l}'"))
    ++ (n |> fromOf |> builtins.filter (l: !(noteIds |> builtins.elem l)) |> map (l: "${id}: from names unknown note '${l}'"))
    ++ (n |> supersedesOf |> builtins.filter (l: !(noteIds |> builtins.elem l)) |> map (l: "${id}: supersedes names unknown note '${l}'"))
    # Superseding is a two-sided edit, or it is an unrecorded deletion: the new
    # note claims the edge, the old one keeps its body and changes status.
    ++ map (
      l: "${id}: supersedes '${l}', but '${l}' is ${raw.${l}.status or "unknown"} — mark it SUPERSEDED (the record stays) or use `from` if it is not being replaced"
    ) (
      n
      |> supersedesOf
      |> builtins.filter (
        l: (noteIds |> builtins.elem l) && (raw.${l}.status or "") != "SUPERSEDED"
      )
    )
    ++ (
      ((n.links or []) ++ fromOf n ++ supersedesOf n)
      |> lib.unique
      |> builtins.filter (
        l:
          lib.count (x: x == l) (n.links or [])
          > 1
          || lib.count (x: x == l) (fromOf n) > 1
          || lib.count (x: x == l) (supersedesOf n) > 1
      )
      |> map (l: "${id}: '${l}' appears twice in one relation list")
    )
    ++ lib.optional (builtins.elem id (parentsOf n))
    "${id}: a note cannot derive from or supersede itself"
    # Traceable notes are distilled; an untraceable one is a leaf and must carry
    # the verbose intent instead of losing it.
    ++ (
      if hasRefs n
      then
        lib.optional (bodyLines n > 30)
        "${id}: body is ${toString (bodyLines n)} lines; a traceable note is distilled (<=30) — link the code and summarise, or keep it as a leaf"
      else
        lib.optional (bodyLines n < 6)
        "${id}: leaf note (no refs) needs a verbose body (>=6 lines) explaining the intent"
    );

  # Transitive ancestry, seeded with the DIRECT parents so a cycle is observable
  # (the closure comes back to the note itself). The depth bound is the note
  # count: a cycle terminates the eval instead of hanging it, and the gate above
  # reports it as an issue rather than pretending the graph is a DAG.
  reach = id: let
    go = depth: acc:
      if depth == 0
      then acc
      else let
        next = (acc ++ (acc |> lib.concatMap stepOf)) |> lib.unique;
      in
        if builtins.length next == builtins.length acc
        then acc
        else go (depth - 1) next;
  in
    go (builtins.length noteIds + 1) (stepOf id);

  stepOf = id:
    parentsOf raw.${id}
    |> lib.unique
    |> builtins.filter (x: builtins.elem x noteIds);

  # Computed once per note, not once per query: 157 notes is already more than
  # the graph will ever hold, and a closure per call would make `near` quadratic.
  ancestors = lib.genAttrs noteIds (id: id |> reach |> lib.unique);
  cyclic = id: ancestors.${id} |> builtins.elem id;
  descendantsOf = id: noteIds |> builtins.filter (x: ancestors.${x} |> builtins.elem id);
  replacedByOf = id: noteIds |> builtins.filter (x: raw.${x} |> supersedesOf |> builtins.elem id);

  entry = id: n: {
    inherit id;
    title = n.title or id;
    kind = n.kind or "reference";
    claim = claimKindOf n;
    evidence = "asserted";
    status = n.status or "PROPOSED";
    priority = n.priority or null;
    date = n.date or null;
    summary = summaryOf n;
    refs = {
      hosts = hostsOf n;
      modules = modulesOf n;
      tasks = tasksOf n;
      docs = docsOf n;
    };
    links = n.links or [];
    from = fromOf n;
    supersedes = supersedesOf n;
    ancestors = ancestors.${id};
    descendants = descendantsOf id;
    replacedBy = replacedByOf id;
    leaf = !(hasRefs n);
    lines = bodyLines n;
    body = bodyOf n;
  };

  entries = lib.genAttrs noteIds (id: entry id raw.${id});
  entryList = noteIds |> map (id: entries.${id});
  ordered = entryList |> lib.sort (a: b: a.id < b.id);

  # Two whole-corpus rules, not per-note ones: a cycle in `from` has no single
  # guilty note, and SCHEMA §3's "SUPERSEDED links the replacement" is only
  # true if the replacement actually claims it.
  graphIssues =
    noteIds
    |> lib.concatMap (
      id:
        lib.optional (cyclic id) "${id}: lineage cycle (from/supersedes returns to this note)"
        ++ lib.optional (
          (raw.${id}.status or "") == "SUPERSEDED" && replacedByOf id == []
        ) "${id}: SUPERSEDED but no note supersedes it — add `supersedes = [\"${id}\"]` to the replacement so the record is not a dead end"
    );

  issues = (noteIds |> lib.concatMap (id: issuesFor id raw.${id})) ++ graphIssues;

  byStatus = status: entryList |> builtins.filter (e: e.status == status);
  byKind = kind: entryList |> builtins.filter (e: e.kind == kind);
  claimStats =
    claimOf
    |> builtins.attrValues
    |> lib.unique
    |> (names:
      lib.genAttrs names (c: let
        xs = entryList |> builtins.filter (e: e.claim == c);
      in {
        notes = builtins.length xs;
        open = xs |> lib.count (e: openStatuses |> builtins.elem e.status);
        evidence = xs |> builtins.catAttrs "evidence" |> lib.unique;
      }));
  claimRows =
    (claimStats |> builtins.attrNames)
    |> map (
      c: {
        claim = c;
        inherit (claimStats.${c}) notes open evidence;
      }
    );

  indexOf = key:
    entryList
    |> lib.foldl' (
      acc: e:
        e.refs.${key}
        |> lib.foldl' (a: v: a // {"${v}" = (a.${v} or []) ++ [e.id];}) acc
    ) {};

  counts = {
    total = entryList |> builtins.length;
    byClaim = claimOf |> builtins.attrValues |> lib.unique |> forNames (k: entryList |> lib.count (e: e.claim == k));
    byStatus = statuses |> forNames (s: s |> byStatus |> builtins.length);
    byKind = kinds |> forNames (k: k |> byKind |> builtins.length);
    open = entryList |> lib.count (e: openStatuses |> builtins.elem e.status);
    leaves = entryList |> lib.count (e: e.leaf);
    lineageEdges = noteIds |> lib.concatMap (id: parentsOf raw.${id}) |> builtins.length;
    withLineage = entryList |> lib.count (e: e.ancestors != []);
  };
  byStatusIds = statuses |> forNames (s: s |> byStatus |> builtins.catAttrs "id");

  # --- markdown rendering ----------------------------------------------------
  capitalize = s: (s |> builtins.substring 0 1 |> lib.toUpper) + (s |> builtins.stringLength |> (n: builtins.substring 1 n s));
  statusBadge = e: "`${e.status}`" + lib.optionalString (e.priority != null) " · `${e.priority}`"; # `linkify` is how a ref is rendered: a repository-relative link in the docs
  # tree, or plain code in the site (where the file lives at a different depth).
  refLine = linkify: label: xs:
    lib.optionalString (xs != []) (
      "- **${label}:** "
      + (xs
        |> lib.concatMapStringsSep ", " (x:
          if label == "hosts" || label == "tasks"
          then "`${x}`"
          else linkify x))
    );

  # Lineage renders like a ref line but every entry is a note, so it goes through
  # the same link function the notes index uses (repo-relative in `.#artifacts.docs`, code
  # in the site).
  lineageLine = relatedLink: label: xs:
    lib.optionalString (xs != []) (
      "- **${label}:** " + (xs |> lib.concatMapStringsSep ", " relatedLink)
    );

  lineageRows = e:
    [
      {
        label = "from";
        ids = e.from;
      }
      {
        label = "supersedes";
        ids = e.supersedes;
      }
      {
        label = "replaced by";
        ids = e.replacedBy;
      }
      {
        label = "led to";
        ids = lib.subtractLists e.replacedBy e.descendants;
      }
    ]
    |> builtins.filter (r: r.ids != []);

  notePageWith = linkify: relatedLink: e:
    "# ${e.title}\n\n"
    + "**Status:** ${statusBadge e} · **Kind:** `${e.kind}`"
    + lib.optionalString (e.claim != null) " · **Claim:** `${e.claim}` (${e.evidence})"
    + lib.optionalString (e.date != null) " · **Updated:** ${e.date}"
    + "\n\n${e.summary}\n\n"
    + (
      ([
          (refLine linkify "hosts" e.refs.hosts)
          (refLine linkify "modules" e.refs.modules)
          (refLine linkify "tasks" e.refs.tasks)
          (refLine linkify "docs" e.refs.docs)
          (lib.optionalString (e.links != [])
            ("- **Related notes:** " + (e.links |> lib.concatMapStringsSep ", " relatedLink)))
        ]
        ++ (e |> lineageRows |> map (r: lineageLine relatedLink (capitalize r.label) r.ids)))
      |> builtins.filter (s: s != "")
      |> lib.concatStringsSep "\n"
    )
    + "\n"
    + lib.optionalString (e.body != "") "\n${e.body}\n";

  notePage = base: e:
    notePageWith (x: "[\`${x}\`](${base}${x})") (l: "[\`${l}\`](./${l}.md)") e;

  indexPage = base:
    "# Agent notes\n\n"
    + "> **Generated — do not edit.** `AGENTS.nix` is the source; `lib/agents-notes.nix`\n"
    + "> compiles it (`nix build .#artifacts.docs`). Query it with `task ops:notes` or\n"
    + "> `nix eval .#agentsNotes.index`.\n\n"
    + "${toString counts.total} notes (${toString counts.open} open, ${toString counts.leaves} leaves) — "
    + "each note links the hosts, modules, tasks and documents it affects; a note\n"
    + "with no such link is a leaf and carries the original intent in prose.\n\n"
    + "| claim | notes | open | evidence |\n| :--- | :--- | :--- | :--- |\n"
    + (claimRows
      |> lib.concatMapStrings (
        r: "| `${r.claim}` | ${toString r.notes} | ${toString r.open} | ${r.evidence |> lib.concatMapStringsSep "," (x: "`${x}`")} |\n"
      ))
    + "\n"
    + (kinds
      |> lib.concatMapStringsSep "\n" (
        k:
          lib.optionalString (byKind k != []) (
            "## ${capitalize k}\n\n"
            + "| id | title | status | claim | refs |\n| :--- | :--- | :--- | :--- | :--- |\n"
            + (ordered
              |> builtins.filter (e: e.kind == k)
              |> lib.concatMapStringsSep "\n" (
                e:
                  "| [\`${e.id}\`](${base}agents-notes/${e.id}.md) | ${e.title} | ${statusBadge e} | "
                  + lib.optionalString (e.claim != null) "\`${e.claim}\`"
                  + " | "
                  + toString (builtins.length (e.refs.hosts ++ e.refs.modules ++ e.refs.tasks ++ e.refs.docs))
                  + " |"
              ))
            + "\n"
          )
      ));

  # Paths inside the `.#artifacts.docs` derivation. `base` is the relative prefix back to
  # the repository root, so a ref renders as a working link in the markdown tree.
  pages =
    {"docs/generated/agents-notes.md" = indexPage "";}
    // (raw |> lib.mapAttrs' (id: _: lib.nameValuePair "docs/generated/agents-notes/${id}.md" (notePage "../../../" entries.${id})));

  # Same pages, but refs render as code instead of repo-relative links: the site
  # serves notes from a different depth and has no repository route.
  sitePages = entries |> lib.mapAttrs (_: e: notePageWith (x: "`${x}`") (l: "`${l}`") e);

  api = {
    schemaVersion = 2;
    inherit counts issues;
    ok = issues == [];
    index = entries |> lib.mapAttrs (_: e: removeAttrs e ["body"]);
    notes = entries;
    appended = entries // turns;
    turnEntries = turns |> builtins.attrNames |> builtins.length;
    byHost = indexOf "hosts";
    byModule = indexOf "modules";
    byTask = indexOf "tasks";
    byDoc = indexOf "docs";
    byStatus = byStatusIds;
    claims = entries |> lib.mapAttrs (_: e: {inherit (e) claim evidence;});
    # One record per note, both directions, all derived. This is what
    # `task ops:notes:lineage` reads — no traversal at query time.
    lineage =
      entries
      |> lib.mapAttrs (_: e: {
        inherit (e) from;
        inherit (e) supersedes;
        inherit (e) ancestors;
        inherit (e) descendants;
        inherit (e) replacedBy;
      });
    origins = noteIds |> builtins.filter (id: entries.${id}.ancestors == []);
    frontier = noteIds |> builtins.filter (id: entries.${id}.descendants == []);
    open = ordered |> builtins.filter (e: openStatuses |> builtins.elem e.status) |> builtins.catAttrs "id";
  };
in {
  inherit api;
  inherit (api) schemaVersion counts issues ok index notes byHost byModule byTask byDoc byStatus claims lineage origins frontier open;
  inherit pages sitePages claimStats claimRows lineageRows;
  # `api` is the typed document; `artifacts.agents-notes` serializes it.
}
