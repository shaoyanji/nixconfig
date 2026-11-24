# A structural view of the repo's knowledge, compiled from the files themselves.
{
  lib,
  inventory,
  skills,
  notes ? {},
  # The rules, as data: `flake/policies.nix` is the one home and this projects it
  # into the graph, so a policy is a node whose `rule` is readable without prose.
  policies ? {},
  tasks ? {},
}: let
  root = ../.;

  hostNames = inventory.hosts |> builtins.attrNames;

  # ARCHITECTURE.md, TODO.md, HANDOFF.md and EXPERIMENTS.md moved into
  # AGENTS.nix (2026-10-19) and are now <=10-line pointers; indexing a pointer
  # would add a doc node with no content. The notes are a separate projection
  # (`lib/agents-notes.nix`, `.#agentsNotes`, `task ops:notes`) so this graph
  # keeps its host/skill/doc semantics and its native-builder parity.
  rootDocs =
    [
      "AGENTS.md"
      "MANUAL.md"
      "README.md"
    ]
    |> map (f: root + "/${f}");

  # Markdown files directly inside a directory (empty when it does not exist).
  mdIn = dir:
    if builtins.pathExists dir
    then
      dir
      |> builtins.readDir
      |> lib.filterAttrs (n: t: t == "regular" && lib.hasSuffix ".md" n)
      |> builtins.attrNames
      |> map (n: dir + "/${n}")
    else [];

  # Markdown one level deeper — `.agents/deploy/hosts/*.md`.
  mdInSubdirs = dir:
    if builtins.pathExists dir
    then
      dir
      |> builtins.readDir
      |> lib.filterAttrs (_: t: t == "directory")
      |> builtins.attrNames
      |> lib.concatMap (sub: mdIn (dir + "/${sub}"))
    else [];

  # The doc set is every markdown file that is a document: the living documents,
  # `docs/*.md`, the agent contract (`.agents/{README,SCHEMA}.md`, `.agents/deploy/**`)
  # and the taskfile ownership map. The last three were rendered ONLY by the
  # retired Python site (`docs-site/`) — the split that made the page list a
  # second source of truth. One projection now: if a file is a document, it is a
  # node here, and the site renders it.
  skillRefDocs =
    if builtins.pathExists (root + "/.agents/skills")
    then
      (root + "/.agents/skills")
      |> builtins.readDir
      |> lib.filterAttrs (_: t: t == "directory")
      |> builtins.attrNames
      |> lib.concatMap (
        n: let
          refs = root + "/.agents/skills/${n}/references";
        in
          if builtins.pathExists refs
          then mdIn refs
          else []
      )
    else [];

  docFiles =
    mdIn (root + "/docs")
    ++ skillRefDocs
    ++ mdIn (root + "/.agents")
    ++ mdIn (root + "/.agents/deploy")
    ++ mdInSubdirs (root + "/.agents/deploy")
    ++ mdIn (root + "/taskfiles")
    # Host-local documents: `hosts/microvms/README.md` describes the guest layer two
    # hosts depend on, and `hosts/sledgehammer/USB.md` a provisioning procedure —
    # both were rendered nowhere, so the layer that `/microvm/*` serves had no node
    # and no skill could be reached from it.
    ++ mdInSubdirs (root + "/hosts");

  # `docs/generated/` is a build artifact and not committed (see
  # docs/history/pipeline-audit-2026-10.md §4); it is not a knowledge source and would only
  # add duplicate edges. The filter below is what keeps it out even if a local
  # build output is checked out by hand.
  files = (rootDocs ++ docFiles) |> builtins.filter builtins.pathExists;

  # Drafts are NOT documents and are deliberately not in `docFiles`: a draft is
  # not a page anyone routes by, so it must not answer for a finished one, and
  # the site renders every doc. They are their own node type with their own
  # edges (`about`), which is what lets `ops:kg:blast TARGET=host:frieren` list
  # the unfinished pieces about that host instead of a second doc namespace.
  ideaFiles =
    if builtins.pathExists (root + "/ideas")
    then
      (root + "/ideas")
      |> builtins.readDir
      |> lib.filterAttrs (n: t: t == "regular" && lib.hasSuffix ".md" n)
      |> builtins.attrNames
      |> map (n: root + "/ideas/${n}")
    else [];

  rel = p: let
    s = toString p;
    r = toString root;
  in
    lib.removePrefix "${r}/" s;

  # Mentions are TOKEN matches, not substrings. `hasInfix "dev" content` counted
  # every occurrence of "devji" as a mention of the `dev` skill and put it at the
  # top of `ops:kg` — a false positive that made the graph's headline output
  # untrustworthy. Splitting on non-name characters keeps `master-toon` and
  # `nix-eval` intact while stopping `dev` from matching `devji`.
  tokensOf = text:
    text
    |> builtins.split "[^A-Za-z0-9_-]+"
    |> builtins.filter (t: builtins.isString t && t != "");

  firstHeading = text: let
    lines = lib.splitString "\n" text;
    hits = lines |> builtins.filter (l: lib.hasPrefix "# " l);
  in
    if hits == []
    then "(untitled)"
    else lib.removePrefix "# " (builtins.head hits);

  skillNames = skills.skills |> builtins.attrNames;

  # Markdown inline links: the relation a token scan cannot see, and the source
  # of `references`. Only a target that IS a doc becomes an edge, so a stale path
  # cannot invent a node — `checks:docs:links` gates those. Extraction is a split
  # on `](` (glibc ERE rejects `\]`); traps in `.agents/skills/knowledge-base` §3.
  linkTargets = text: let
    parts = lib.splitString "](" text;
  in
    if builtins.length parts <= 1
    then []
    else parts |> builtins.tail |> map (chunk: chunk |> lib.splitString ")" |> builtins.head);

  cleanTarget = t: let
    noFrag = t |> lib.splitString "#" |> builtins.head;
  in
    lib.removeSuffix ">" (lib.removePrefix "<" noFrag);

  dirOf = path: let
    parts = lib.splitString "/" path;
  in
    if builtins.length parts <= 1
    then ""
    else parts |> lib.init |> lib.concatStringsSep "/";

  # `..` and `.` resolved segment-wise. Not a regex or a builtin: the target is a
  # repo-relative path, and the doc set is the only thing consulted after this.
  normalisePath = path: let
    segs = lib.splitString "/" path;
    step = acc: seg:
      if seg == "" || seg == "."
      then acc
      else if seg == ".."
      then
        (
          if acc == []
          then []
          else lib.init acc
        )
      else acc ++ [seg];
  in
    segs |> builtins.foldl' step [] |> lib.concatStringsSep "/";

  isDocLink = t:
    t
    != ""
    && lib.hasSuffix ".md" t
    && !(lib.hasPrefix "/" t)
    && !(lib.hasPrefix "http" t)
    && !(lib.hasPrefix "mailto:" t);

  # Which rules a page CITES (`[[flake/policies.nix#id]]`) rather than restates.
  # A property, not a fifth node type: the canvas, its slice set and its gate key
  # on the four types, and a type nobody renders is a node nobody can click. The
  # id is safe to trust because `checks.policies` already proves every citation
  # resolves and every id is cited.
  citedIds = text: let
    parts = lib.splitString "[[flake/policies.nix#" text;
  in
    parts |> builtins.tail |> map (chunk: chunk |> lib.splitString "]]" |> builtins.head) |> lib.unique;

  citedPolicies = text:
  # Only a DECLARED policy becomes a node: a template like `#<id>` in a doc is
  # prose about the convention, and a citation to an unknown id is a
  # `checks.ontology` failure, not a node the graph should invent.
    text |> citedIds |> builtins.filter (id: (policies |> builtins.hasAttr id) && (id |> builtins.match "[a-z0-9][a-z0-9-]*") != null);

  # Every path that will become a doc node, so a link resolves before nodes exist.
  docPaths = files |> map rel;

  referencesIn = id: content: let
    dir = dirOf id;
    targets =
      content
      |> linkTargets
      |> map cleanTarget
      |> builtins.filter isDocLink
      |> map (t:
        normalisePath (
          if dir == ""
          then t
          else "${dir}/${t}"
        ));
  in
    targets |> builtins.filter (t: t != id && (docPaths |> builtins.elem t)) |> lib.unique;

  mkDoc = p: let
    content = builtins.readFile p;
    id = rel p;
    toks = tokensOf content;
  in {
    id = "doc:${id}";
    type = "doc";
    label = firstHeading content;
    path = id;
    mentionsHosts = hostNames |> builtins.filter (h: toks |> builtins.elem h);
    mentionsSkills = skillNames |> builtins.filter (s: toks |> builtins.elem s);
    references = referencesIn id content;
    cites = citedPolicies content;
    citations = citedIds content;
  };

  docs = files |> map mkDoc;

  # Draft frontmatter, parsed line-wise: the contract, and why it is not YAML,
  # live in docs/blog-drafting.md.
  takeUntil = pred: list: let
    step = acc: x:
      if acc.done || pred x
      then acc // {done = true;}
      else acc // {items = acc.items ++ [x];};
  in
    (list
      |> builtins.foldl' step {
        done = false;
        items = [];
      })
    .items;

  frontmatter = content: let
    lines = lib.splitString "\n" content;
  in
    if lines == [] || !(lib.hasPrefix "---" (builtins.head lines))
    then []
    else
      takeUntil (l: l == "---") (
        if builtins.length lines > 1
        then builtins.tail lines
        else []
      );

  fmValue = content: key: let
    lines = frontmatter content;
    hits = lines |> builtins.filter (l: lib.hasPrefix "${key}:" l);
  in
    if hits == []
    then ""
    else hits |> builtins.head |> lib.removePrefix "${key}:" |> lib.trim;

  fmList = content: key: let
    lines = frontmatter content;
    idx =
      lines
      |> lib.imap0 (i: l:
        if l == "${key}:"
        then i
        else null)
      |> builtins.filter (i: i != null);
  in
    if idx == []
    then []
    else
      lines
      |> lib.drop ((builtins.head idx) + 1)
      |> takeUntil (l: !(lib.hasPrefix "  - " l || lib.hasPrefix "- " l))
      |> map (l: l |> lib.removePrefix "  - " |> lib.removePrefix "- " |> lib.trim);

  mkIdea = p: let
    content = builtins.readFile p;
    path = rel p;
    slug = lib.removeSuffix ".md" (baseNameOf path);
    title = fmValue content "title";
  in {
    id = "idea:${slug}";
    type = "idea";
    label =
      if title == ""
      then slug
      else title;
    inherit path;
    about = fmList content "about" |> builtins.filter (a: a != "");
  };

  ideas = ideaFiles |> map mkIdea;

  # --- Nix module graph ------------------------------------------------------
  # "Who imports this module" was a grep; the walk and the extraction are
  # `lib/nix-files.nix` (which `flake/nix-registry.nix` also names from), and
  # `ops:kg:module` / `ops:kg:blast` read them. The walk is the whole tree, so
  # `flake.nix` and the overlays are nodes.
  nixFilesCtl = import ./nix-files.nix {inherit lib root;};
  nixPaths = nixFilesCtl.paths;
  modules =
    nixPaths
    |> map (p: {
      id = "module:${p}";
      type = "module";
      label = p;
      path = p;
      imports = nixFilesCtl.importsOfPath p;
    });

  # Every node id that exists, so an `about` entry naming a typo is an edge that
  # does not resolve — which kg-check fails on — rather than an invented node.
  knowableIds =
    (hostNames |> map (h: "host:${h}"))
    ++ (skillNames |> map (s: "skill:${s}"))
    ++ (docPaths |> map (d: "doc:${d}"));

  hostNodes =
    hostNames
    |> map (h: {
      id = "host:${h}";
      type = "host";
      label = h;
      status = inventory.hosts.${h}.status or "unknown";
      kind = inventory.hosts.${h}.kind or "unknown";
    });

  serviceNodes =
    hostNames
    |> lib.concatMap (
      h:
        inventory.hosts.${h}.software.services
        |> map (s: {
          id = "service:${h}:${s.name}";
          type = "service";
          label = s.name;
          host = h;
          inherit (s) port;
          inherit (s) note;
        })
    );

  serviceEdges =
    hostNames
    |> lib.concatMap (
      h:
        inventory.hosts.${h}.software.services
        |> map (s: {
          from = "service:${h}:${s.name}";
          to = "host:${h}";
          type = "runs-on";
        })
    );

  skillNodes =
    (skills.skills |> builtins.attrNames)
    |> map (n: {
      id = "skill:${n}";
      type = "skill";
      label = n;
      description = skills.skills.${n}.description;
      path = skills.skills.${n}.path;
      tags = skills.skills.${n}.tags;
      # The body is already parsed in `lib/skills.nix`, so this costs no read.
      cites = skills.skills.${n}.body |> lib.concatStringsSep "\n" |> citedPolicies;
    });

  # A policy node exists because prose cites it: `checks.policies` proves every
  # citation resolves and every id is cited, so the set cannot be invented here.
  policyIds =
    ((docs |> lib.concatMap (d: d.cites))
      ++ ((skills.skills |> builtins.attrNames)
        |> lib.concatMap (n: skills.skills.${n}.body |> lib.concatStringsSep "\n" |> citedPolicies)))
    |> lib.unique;
  unresolvedCitations = let
    missed = id: !(builtins.hasAttr id policies) && builtins.match "[a-z0-9][a-z0-9-]*" id != null;
  in
    (docs |> lib.concatMap (d: d.citations |> builtins.filter missed |> map (id: "${d.id} -> policy:${id}")))
    ++ ((skills.skills |> builtins.attrNames)
      |> lib.concatMap (
        n:
          skills.skills.${n}.body
          |> lib.concatStringsSep "\n"
          |> citedIds
          |> builtins.filter missed
          |> map (id: "skill:${n} -> policy:${id}")
      ));
  policyNodes =
    policyIds
    |> map (id: {
      id = "policy:${id}";
      type = "policy";
      label = id;
      path = "flake/policies.nix";
      rule = policies.${id}.rule or "";
      proof = policies.${id}.proof or "";
    });

  noteEntries = notes.notes or {};
  noteIdsForEdges = noteEntries |> builtins.attrNames;
  noteNodes =
    noteIdsForEdges
    |> map (id: let
      n = noteEntries.${id};
    in {
      id = "note:${id}";
      type = "note";
      label = n.title or id;
      path = "AGENTS.nix";
      kind = n.kind or "reference";
      status = n.status or "PROPOSED";
      claim = ((notes.claims or {}).${id} or {}).claim or null;
    });
  noteEdges =
    noteIdsForEdges
    |> lib.concatMap (id: let
      n = noteEntries.${id};
      targets = k: (n.${k} or []) |> builtins.filter (p: noteIdsForEdges |> builtins.elem p);
      lineage = type: p: {
        from = "note:${id}";
        to = "note:${p}";
        inherit type;
        evidence = "asserted";
        because = "a person wrote the list; the schema only proves the id resolves";
      };
    in
      ("from" |> targets |> map (lineage "derives"))
      ++ ("supersedes" |> targets |> map (lineage "supersedes")));

  taskIds = tasks |> builtins.attrNames;
  taskNodes =
    taskIds
    |> map (n: let
      parts = n |> lib.splitString ":";
    in {
      id = "task:${n}";
      type = "task";
      label = n;
      inherit (tasks.${n}) desc;
      shard =
        if builtins.length parts > 1
        then builtins.head parts
        else "root";
      aliasOf = tasks.${n}.aliasOf or "";
    });

  playbookDoc = let
    p = root + "/.agents/skills/router/references/playbooks.md";
  in
    if builtins.pathExists p
    then builtins.readFile p
    else "";
  playbookLines = playbookDoc |> lib.splitString "\n";
  lineSpans = line: let
    parts = lib.splitString "`" line;
  in
    parts
    |> builtins.length
    |> lib.range 0
    |> builtins.filter (i: i * 2 + 1 < builtins.length parts)
    |> map (i: builtins.elemAt parts (i * 2 + 1));
  rowWords = line: line |> lineSpans |> map (s: s |> lib.removePrefix "task " |> lib.splitString " " |> builtins.head);
  rowLabel = line: let
    m = builtins.match "\\|[[:space:]]*`([a-z]+(-[a-z]+)*)`.*" line;
  in
    if m == null
    then null
    else builtins.head m;
  taskShaped = t: builtins.match "[a-z][a-z0-9-]*(:[a-z0-9*<][a-z0-9*_<>-]*)+" t != null;
  wildcardFor = t:
    taskIds
    |> builtins.filter (n: (n |> lib.hasInfix "*") && (t |> lib.hasPrefix (n |> lib.splitString "*" |> builtins.head)))
    |> lib.sort (
      a: b:
        (a |> lib.splitString "*" |> builtins.head |> builtins.stringLength)
        > (b |> lib.splitString "*" |> builtins.head |> builtins.stringLength)
    );
  resolves = t: builtins.hasAttr t tasks || wildcardFor t != [];
  resolvedTask = t:
    if builtins.hasAttr t tasks
    then t
    else t |> wildcardFor |> builtins.head;
  rowTasks = line: let
    l = rowLabel line;
  in
    if l == null
    then []
    else
      line
      |> rowWords
      |> builtins.filter (t: (t |> taskShaped) && (t |> resolves))
      |> map resolvedTask
      |> lib.unique
      |> map (n: {
        from = "doc:.agents/skills/router/references/playbooks.md";
        to = "task:${n}";
        type = "routes";
        label = l;
      });
  routeEdges = playbookLines |> lib.concatMap rowTasks;
  routerUnknown =
    playbookLines
    |> lib.concatMap (line: line |> rowWords |> builtins.filter (t: (t |> taskShaped) && !(t |> resolves)))
    |> lib.unique;

  nodes =
    hostNodes
    ++ skillNodes
    ++ serviceNodes
    ++ policyNodes
    ++ noteNodes
    ++ (docs
      |> map (d: {
        inherit (d) id type label path cites;
      }))
    ++ (ideas
      |> map (i: {
        inherit (i) id type label path;
      }))
    ++ (modules
      |> map (m: {
        inherit (m) id type label path;
      }))
    ++ taskNodes;

  edges =
    (docs
      |> lib.concatMap (d:
        (d.mentionsHosts
          |> map (h: {
            from = d.id;
            to = "host:${h}";
            type = "mentions";
          }))
        ++ (d.mentionsSkills
          |> map (s: {
            from = d.id;
            to = "skill:${s}";
            type = "mentions";
          }))
        ++ (d.references
          |> map (r: {
            from = d.id;
            to = "doc:${r}";
            type = "references";
          }))))
    ++ ((skills.skills |> builtins.attrNames)
      |> lib.concatMap (n:
        skills.skills.${n}.tags
        |> map (t: {
          from = "skill:${n}";
          to = "tag:${t}";
          type = "tagged";
        })))
    # A draft names the entities it is about; the edge is only emitted for an id
    # that exists, so a typo in frontmatter surfaces as "edge endpoints resolve
    # to nodes" in kg-check instead of quietly shrinking the graph.
    ++ (ideas
      |> lib.concatMap (i:
        i.about
        |> builtins.filter (a: knowableIds |> builtins.elem a)
        |> lib.unique
        |> map (a: {
          from = i.id;
          to = a;
          type = "about";
        })))
    # Only a path that IS a module node becomes an edge, so the importer list is
    # always answerable; the filter is what makes the extraction safe to be rough.
    ++ (modules
      |> lib.concatMap (m:
        m.imports
        |> builtins.filter (r: nixPaths |> builtins.elem r)
        |> map (r: {
          from = m.id;
          to = "module:${r}";
          type = "imports";
        })))
    # A citation: prose names the rule, so the rule can name its prose. This is
    # the edge that answers "which pages restate this" without a grep.
    ++ (docs
      |> lib.concatMap (d:
        d.cites
        |> map (id: {
          from = d.id;
          to = "policy:${id}";
          type = "cites";
        })))
    ++ ((skills.skills |> builtins.attrNames)
      |> lib.concatMap (n:
        (skills.skills.${n}.body |> lib.concatStringsSep "\n" |> citedPolicies)
        |> map (id: {
          from = "skill:${n}";
          to = "policy:${id}";
          type = "cites";
        })))
    ++ routeEdges
    ++ serviceEdges
    ++ noteEdges;

  tagNodes = (skills.skills |> builtins.attrNames) |> lib.concatMap (n: skills.skills.${n}.tags) |> lib.unique;

  graph = {
    schemaVersion = 1;
    generatedBy = "lib/knowledge-graph.nix";
    nodes =
      nodes
      ++ (tagNodes
        |> map (t: {
          id = "tag:${t}";
          type = "tag";
          label = t;
        }));
    inherit edges;
    stats = {
      hosts = hostNames |> builtins.length;
      skills = skills.skills |> builtins.attrNames |> builtins.length;
      docs = docs |> builtins.length;
      ideas = ideas |> builtins.length;
      notes = noteIdsForEdges |> builtins.length;
      modules = modules |> builtins.length;
      services = serviceNodes |> builtins.length;
      policies = policyIds |> builtins.length;
      tasks = taskIds |> builtins.length;
      edges = edges |> builtins.length;
      recordedEdges = edges |> builtins.filter (e: e ? evidence) |> builtins.length;
    };
  };

  q = s: builtins.toJSON s;
  cypherNodes =
    graph.nodes
    |> lib.concatMapStrings (n: let
      label =
        if n.type == "host"
        then "Host"
        else if n.type == "skill"
        then "Skill"
        else if n.type == "doc"
        then "Doc"
        else if n.type == "idea"
        then "Idea"
        else if n.type == "module"
        then "Module"
        else if n.type == "policy"
        then "Policy"
        else if n.type == "note"
        then "Note"
        else if n.type == "task"
        then "Task"
        else if n.type == "service"
        then "Service"
        else "Tag";
    in ''
      MERGE (${"n_${builtins.hashString "md5" n.id}"}:${label} {id: ${q n.id}})
      SET ${"n_${builtins.hashString "md5" n.id}"}.label = ${q n.label};
    '');
  cypherEdges =
    graph.edges
    |> lib.concatMapStrings (e: let
      a = "n_${builtins.hashString "md5" e.from}";
      b = "n_${builtins.hashString "md5" e.to}";
      rel =
        if e.type == "tagged"
        then "TAGGED"
        else if e.type == "about"
        then "ABOUT"
        else if e.type == "imports"
        then "IMPORTS"
        else if e.type == "derives"
        then "DERIVES"
        else if e.type == "supersedes"
        then "SUPERSEDES"
        else if e.type == "routes"
        then "ROUTES"
        else if e.type == "runs-on"
        then "RUNS_ON"
        else "MENTIONS";
    in ''
      MATCH (${a}), (${b}) MERGE (${a})-[r:${rel}]->(${b})${lib.optionalString (e ? evidence) " SET r.evidence = ${q e.evidence}"};
    '');
in {
  inherit graph routerUnknown unresolvedCitations;
  cypher = "// generated by lib/knowledge-graph.nix\n" + cypherNodes + cypherEdges;
}
