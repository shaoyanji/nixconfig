# A structural view of the repo's knowledge, compiled from the files themselves.
{
  lib,
  inventory,
  skills,
}: let
  root = ../.;

  hostNames = builtins.attrNames inventory.hosts;

  # ARCHITECTURE.md, TODO.md, HANDOFF.md and EXPERIMENTS.md moved into
  # AGENTS.nix (2026-10-19) and are now <=10-line pointers; indexing a pointer
  # would add a doc node with no content. The notes are a separate projection
  # (`lib/agents-notes.nix`, `.#agentsNotes`, `task ops:notes`) so this graph
  # keeps its host/skill/doc semantics and its native-builder parity.
  rootDocs = map (f: root + "/${f}") [
    "AGENTS.md"
    "MANUAL.md"
    "AUDIT.md"
    "README.md"
  ];

  # Markdown files directly inside a directory (empty when it does not exist).
  mdIn = dir:
    if builtins.pathExists dir
    then
      map (n: dir + "/${n}") (
        builtins.attrNames (
          lib.filterAttrs (n: t: t == "regular" && lib.hasSuffix ".md" n) (builtins.readDir dir)
        )
      )
    else [];

  # Markdown one level deeper — `.agents/deploy/hosts/*.md`.
  mdInSubdirs = dir:
    if builtins.pathExists dir
    then
      lib.concatMap (sub: mdIn (dir + "/${sub}")) (
        builtins.attrNames (lib.filterAttrs (_: t: t == "directory") (builtins.readDir dir))
      )
    else [];

  # The doc set is every markdown file that is a document: the living documents,
  # `docs/*.md`, the agent contract (`.agents/{README,SCHEMA}.md`, `.agents/deploy/**`)
  # and the taskfile ownership map. The last three were rendered ONLY by the
  # retired Python site (`docs-site/`) — the split that made the page list a
  # second source of truth. One projection now: if a file is a document, it is a
  # node here, and the site renders it.
  docFiles =
    mdIn (root + "/docs")
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
  # docs/docs-pipeline-audit.md §4); it is not a knowledge source and would only
  # add duplicate edges. The filter below is what keeps it out even if a local
  # build output is checked out by hand.
  files = builtins.filter builtins.pathExists (rootDocs ++ docFiles);

  # Drafts are NOT documents and are deliberately not in `docFiles`: a draft is
  # not a page anyone routes by, so it must not answer for a finished one, and
  # the site renders every doc. They are their own node type with their own
  # edges (`about`), which is what lets `ops:kg:blast TARGET=host:frieren` list
  # the unfinished pieces about that host instead of a second doc namespace.
  ideaFiles =
    if builtins.pathExists (root + "/ideas")
    then
      map (n: root + "/ideas/${n}") (
        builtins.attrNames (
          lib.filterAttrs (n: t: t == "regular" && lib.hasSuffix ".md" n) (builtins.readDir (root + "/ideas"))
        )
      )
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
    builtins.filter (t: builtins.isString t && t != "")
    (builtins.split "[^A-Za-z0-9_-]+" text);

  firstHeading = text: let
    lines = lib.splitString "\n" text;
    hits = builtins.filter (l: lib.hasPrefix "# " l) lines;
  in
    if hits == []
    then "(untitled)"
    else lib.removePrefix "# " (builtins.head hits);

  skillNames = builtins.attrNames skills.skills;

  # Markdown inline links: the relation a token scan cannot see, and the source
  # of `references`. Only a target that IS a doc becomes an edge, so a stale path
  # cannot invent a node — `checks:docs:links` gates those. Extraction is a split
  # on `](` (glibc ERE rejects `\]`); traps in `.agents/skills/knowledge-base` §3.
  linkTargets = text: let
    parts = lib.splitString "](" text;
  in
    if builtins.length parts <= 1
    then []
    else map (chunk: builtins.head (lib.splitString ")" chunk)) (builtins.tail parts);

  cleanTarget = t: let
    noFrag = builtins.head (lib.splitString "#" t);
  in
    lib.removeSuffix ">" (lib.removePrefix "<" noFrag);

  dirOf = path: let
    parts = lib.splitString "/" path;
  in
    if builtins.length parts <= 1
    then ""
    else lib.concatStringsSep "/" (lib.init parts);

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
    lib.concatStringsSep "/" (builtins.foldl' step [] segs);

  isDocLink = t:
    t
    != ""
    && lib.hasSuffix ".md" t
    && !(lib.hasPrefix "/" t)
    && !(lib.hasPrefix "http" t)
    && !(lib.hasPrefix "mailto:" t);

  # Every path that will become a doc node, so a link resolves before nodes exist.
  docPaths = map rel files;

  referencesIn = id: content: let
    dir = dirOf id;
    targets = map (t:
      normalisePath (
        if dir == ""
        then t
        else "${dir}/${t}"
      )) (
      builtins.filter isDocLink (map cleanTarget (linkTargets content))
    );
  in
    lib.unique (builtins.filter (t: t != id && builtins.elem t docPaths) targets);

  mkDoc = p: let
    content = builtins.readFile p;
    id = rel p;
    toks = tokensOf content;
  in {
    id = "doc:${id}";
    type = "doc";
    label = firstHeading content;
    path = id;
    mentionsHosts = builtins.filter (h: builtins.elem h toks) hostNames;
    mentionsSkills = builtins.filter (s: builtins.elem s toks) skillNames;
    references = referencesIn id content;
  };

  docs = map mkDoc files;

  # Draft frontmatter, parsed line-wise and mirrored in tools/kg-engine: the
  # contract, and why it is not YAML, live in docs/blog-drafting.md.
  takeUntil = pred: list: let
    step = acc: x:
      if acc.done || pred x
      then acc // {done = true;}
      else acc // {items = acc.items ++ [x];};
  in
    (builtins.foldl' step {
        done = false;
        items = [];
      }
      list)
    .items;

  frontmatter = content: let
    lines = lib.splitString "\n" content;
  in
    if lines == [] || !(lib.hasPrefix "---" (builtins.head lines))
    then []
    else
      takeUntil (l: l == "---") (
        if builtins.length lines > 1
        then lib.tail lines
        else []
      );

  fmValue = content: key: let
    lines = frontmatter content;
    hits = builtins.filter (l: lib.hasPrefix "${key}:" l) lines;
  in
    if hits == []
    then ""
    else lib.trim (lib.removePrefix "${key}:" (builtins.head hits));

  fmList = content: key: let
    lines = frontmatter content;
    idx = builtins.filter (i: i != null) (
      lib.imap0 (i: l:
        if l == "${key}:"
        then i
        else null)
      lines
    );
  in
    if idx == []
    then []
    else
      map (l: lib.trim (lib.removePrefix "- " (lib.removePrefix "  - " l))) (
        takeUntil (l: !(lib.hasPrefix "  - " l || lib.hasPrefix "- " l)) (
          lib.drop ((builtins.head idx) + 1) lines
        )
      );

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
    about = builtins.filter (a: a != "") (fmList content "about");
  };

  ideas = map mkIdea ideaFiles;

  # Every node id that exists, so an `about` entry naming a typo is an edge that
  # does not resolve — which kg-check fails on — rather than an invented node.
  knowableIds =
    map (h: "host:${h}") hostNames
    ++ map (s: "skill:${s}") skillNames
    ++ map (d: "doc:${d}") docPaths;

  hostNodes =
    map (h: {
      id = "host:${h}";
      type = "host";
      label = h;
      status = inventory.hosts.${h}.status or "unknown";
      kind = inventory.hosts.${h}.kind or "unknown";
    })
    hostNames;

  skillNodes =
    map (n: {
      id = "skill:${n}";
      type = "skill";
      label = n;
      description = skills.skills.${n}.description;
      path = skills.skills.${n}.path;
      tags = skills.skills.${n}.tags;
    })
    (builtins.attrNames skills.skills);

  nodes =
    hostNodes
    ++ skillNodes
    ++ map (d: {
      inherit (d) id type label path;
    })
    docs
    ++ map (i: {
      inherit (i) id type label path;
    })
    ideas;

  edges =
    lib.concatMap (d:
      map (h: {
        from = d.id;
        to = "host:${h}";
        type = "mentions";
      })
      d.mentionsHosts
      ++ map (s: {
        from = d.id;
        to = "skill:${s}";
        type = "mentions";
      })
      d.mentionsSkills
      ++ map (r: {
        from = d.id;
        to = "doc:${r}";
        type = "references";
      })
      d.references)
    docs
    ++ lib.concatMap (n:
      map (t: {
        from = "skill:${n}";
        to = "tag:${t}";
        type = "tagged";
      })
      skills.skills.${n}.tags)
    (builtins.attrNames skills.skills)
    # A draft names the entities it is about; the edge is only emitted for an id
    # that exists, so a typo in frontmatter surfaces as "edge endpoints resolve
    # to nodes" in kg-check instead of quietly shrinking the graph.
    ++ lib.concatMap (i:
      map (a: {
        from = i.id;
        to = a;
        type = "about";
      })
      (lib.unique (builtins.filter (a: builtins.elem a knowableIds) i.about)))
    ideas;

  tagNodes = lib.unique (lib.concatMap (n: skills.skills.${n}.tags) (builtins.attrNames skills.skills));

  graph = {
    schemaVersion = 1;
    generatedBy = "lib/knowledge-graph.nix";
    nodes =
      nodes
      ++ map (t: {
        id = "tag:${t}";
        type = "tag";
        label = t;
      })
      tagNodes;
    inherit edges;
    stats = {
      hosts = builtins.length hostNames;
      skills = builtins.length (builtins.attrNames skills.skills);
      docs = builtins.length docs;
      ideas = builtins.length ideas;
      edges = builtins.length edges;
    };
  };

  q = s: builtins.toJSON s;
  cypherNodes =
    lib.concatMapStrings (n: let
      label =
        if n.type == "host"
        then "Host"
        else if n.type == "skill"
        then "Skill"
        else if n.type == "doc"
        then "Doc"
        else if n.type == "idea"
        then "Idea"
        else "Tag";
    in ''
      MERGE (${"n_${builtins.hashString "md5" n.id}"}:${label} {id: ${q n.id}})
      SET ${"n_${builtins.hashString "md5" n.id}"}.label = ${q n.label};
    '')
    graph.nodes;
  cypherEdges =
    lib.concatMapStrings (e: let
      a = "n_${builtins.hashString "md5" e.from}";
      b = "n_${builtins.hashString "md5" e.to}";
      rel =
        if e.type == "tagged"
        then "TAGGED"
        else if e.type == "about"
        then "ABOUT"
        else "MENTIONS";
    in ''
      MATCH (${a}), (${b}) MERGE (${a})-[:${rel}]->(${b});
    '')
    graph.edges;
in {
  inherit graph;
  cypher = "// generated by lib/knowledge-graph.nix\n" + cypherNodes + cypherEdges;
}
