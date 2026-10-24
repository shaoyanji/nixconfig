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
  };

  docs = map mkDoc files;

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
    docs;

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
      d.mentionsSkills)
    docs
    ++ lib.concatMap (n:
      map (t: {
        from = "skill:${n}";
        to = "tag:${t}";
        type = "tagged";
      })
      skills.skills.${n}.tags)
    (builtins.attrNames skills.skills);

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
        else "MENTIONS";
    in ''
      MATCH (${a}), (${b}) MERGE (${a})-[:${rel}]->(${b});
    '')
    graph.edges;
in {
  inherit graph;
  cypher = "// generated by lib/knowledge-graph.nix\n" + cypherNodes + cypherEdges;
}
