# lib/agents-notes.nix — compile AGENTS.nix into a validated note index.
#
# AGENTS.nix is the ONE home for the repo's narrative knowledge that used to be
# split across ARCHITECTURE.md, TODO.md, HANDOFF.md and EXPERIMENTS.md. It is a
# data file, not code: an attrset of notes, each with a status from the
# `.agents/SCHEMA.md` vocabulary, typed refs into the actual Nix tree, and a
# body. This module is the only projection: it validates the data, builds the
# indexes the query task and the docs site read, and renders the markdown pages.
#
# The traceability rule is enforced, not documented: a note must either point at
# at least one real node (host, module/file, task, doc) or carry a verbose body
# explaining the intent of an idea that has no code yet ("leaf"). A terse leaf
# is exactly how an idea becomes unactionable.
#
# Authoring contract (templates, promotion ladder, anti-slop rules):
# `.agents/skills/agents-notes/SKILL.md`; lifecycle rules: `.agents/SCHEMA.md` §5.
{
  lib,
  inventory ? null,
  notes ? import ../AGENTS.nix,
}: let
  root = ../.;
  raw = notes.notes or {};

  kinds = ["decision" "proposal" "open" "experiment" "handoff" "reference"];
  statuses = [
    "PROPOSED"
    "ACCEPTED"
    "IN FLIGHT"
    "DELIVERED"
    "SUPERSEDED"
    "REJECTED"
    "BLOCKED"
    "OPEN"
  ];
  priorities = ["P0" "P1" "P2" "P3" "P4" "P5" "P6"];
  openStatuses = ["PROPOSED" "ACCEPTED" "IN FLIGHT" "BLOCKED" "OPEN"];

  rel = p: root + "/${p}";
  exists = p: builtins.pathExists (rel p);
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

  hostNames =
    if inventory == null
    then []
    else builtins.attrNames inventory.hosts;
  unknownHosts = n: builtins.filter (h: !(builtins.elem h hostNames)) (hostsOf n);
  missing = xs: builtins.filter (p: !(exists p)) xs;

  bodyOf = n: n.body or "";
  bodyLines = n: let
    b = bodyOf n;
  in
    if b == ""
    then 0
    else builtins.length (lib.splitString "\n" (lib.removeSuffix "\n" b));
  summaryOf = n: n.summary or "";

  noteIds = builtins.attrNames raw;

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
    ++ lib.optional (builtins.stringLength (summaryOf n) > 400)
    "${id}: summary is longer than 400 chars (move detail to body)"
    ++ map (h: "${id}: refs.hosts names unknown host '${h}'") (unknownHosts n)
    ++ map (p: "${id}: refs.modules path does not exist: ${p}") (missing (modulesOf n))
    ++ map (p: "${id}: refs.docs path does not exist: ${p}") (missing (docsOf n))
    ++ map (_: "${id}: refs.tasks entry is empty") (builtins.filter (t: t == "") (tasksOf n))
    ++ map (l: "${id}: links names unknown note '${l}'") (
      builtins.filter (l: !(builtins.elem l noteIds)) (n.links or [])
    )
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

  entry = id: n: {
    inherit id;
    title = n.title or id;
    kind = n.kind or "reference";
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
    leaf = !(hasRefs n);
    lines = bodyLines n;
    body = bodyOf n;
  };

  entries = lib.genAttrs noteIds (id: entry id raw.${id});
  entryList = map (id: entries.${id}) noteIds;
  ordered = lib.sort (a: b: a.id < b.id) entryList;

  issues = lib.concatMap (id: issuesFor id raw.${id}) noteIds;

  byStatus = status: builtins.filter (e: e.status == status) entryList;
  byKind = kind: builtins.filter (e: e.kind == kind) entryList;

  indexOf = key:
    lib.foldl' (
      acc: e:
        lib.foldl' (a: v: a // {"${v}" = (a.${v} or []) ++ [e.id];}) acc e.refs.${key}
    ) {}
    entryList;

  counts = {
    total = builtins.length entryList;
    byStatus = lib.genAttrs statuses (s: builtins.length (byStatus s));
    byKind = lib.genAttrs kinds (k: builtins.length (byKind k));
    open = builtins.length (builtins.filter (e: builtins.elem e.status openStatuses) entryList);
    leaves = builtins.length (builtins.filter (e: e.leaf) entryList);
  };
  byStatusIds = lib.genAttrs statuses (s: map (e: e.id) (byStatus s));

  # --- markdown rendering ----------------------------------------------------
  capitalize = s: lib.toUpper (builtins.substring 0 1 s) + builtins.substring 1 (builtins.stringLength s) s;
  statusBadge = e: "`${e.status}`" + lib.optionalString (e.priority != null) " · `${e.priority}`"; # `linkify` is how a ref is rendered: a repository-relative link in the docs
  # tree, or plain code in the site (where the file lives at a different depth).
  refLine = linkify: label: xs:
    lib.optionalString (xs != []) (
      "- **${label}:** "
      + lib.concatStringsSep ", " (
        map (x:
          if label == "hosts" || label == "tasks"
          then "`${x}`"
          else linkify x)
        xs
      )
    );

  notePageWith = linkify: relatedLink: e:
    "# ${e.title}\n\n"
    + "**Status:** ${statusBadge e} · **Kind:** `${e.kind}`"
    + lib.optionalString (e.date != null) " · **Updated:** ${e.date}"
    + "\n\n${e.summary}\n\n"
    + lib.concatStringsSep "\n" (
      builtins.filter (s: s != "") [
        (refLine linkify "hosts" e.refs.hosts)
        (refLine linkify "modules" e.refs.modules)
        (refLine linkify "tasks" e.refs.tasks)
        (refLine linkify "docs" e.refs.docs)
        (lib.optionalString (e.links != [])
          ("- **Related notes:** " + lib.concatStringsSep ", " (map (l: relatedLink l) e.links)))
      ]
    )
    + "\n"
    + lib.optionalString (e.body != "") "\n${e.body}\n";

  notePage = base: e:
    notePageWith (x: "[\`${x}\`](${base}${x})") (l: "[\`${l}\`](./${l}.md)") e;

  indexPage = base:
    "# Agent notes\n\n"
    + "> **Generated — do not edit.** `AGENTS.nix` is the source; `lib/agents-notes.nix`\n"
    + "> compiles it (`nix build .#docs`). Query it with `task ops:notes` or\n"
    + "> `nix eval .#agentsNotes.index`.\n\n"
    + "${toString counts.total} notes (${toString counts.open} open, ${toString counts.leaves} leaves) — "
    + "each note links the hosts, modules, tasks and documents it affects; a note\n"
    + "with no such link is a leaf and carries the original intent in prose.\n\n"
    + lib.concatStringsSep "\n" (
      map (
        k:
          lib.optionalString (byKind k != []) (
            "## ${capitalize k}\n\n"
            + "| id | title | status | refs |\n| :--- | :--- | :--- | :--- |\n"
            + lib.concatMapStringsSep "\n" (
              e:
                "| [\`${e.id}\`](${base}agents-notes/${e.id}.md) | ${e.title} | ${statusBadge e} | "
                + toString (builtins.length (e.refs.hosts ++ e.refs.modules ++ e.refs.tasks ++ e.refs.docs))
                + " |"
            )
            (lib.filter (e: e.kind == k) ordered)
            + "\n"
          )
      )
      kinds
    );

  # Paths inside the `.#docs` derivation. `base` is the relative prefix back to
  # the repository root, so a ref renders as a working link in the markdown tree.
  pages =
    {"docs/generated/agents-notes.md" = indexPage "";}
    // lib.mapAttrs' (id: _: lib.nameValuePair "docs/generated/agents-notes/${id}.md" (notePage "../../../" entries.${id})) raw;

  # Same pages, but refs render as code instead of repo-relative links: the site
  # serves notes from a different depth and has no repository route.
  sitePages = lib.mapAttrs (_: e: notePageWith (x: "`${x}`") (l: "`${l}`") e) entries;

  api = {
    schemaVersion = 1;
    inherit counts issues;
    ok = issues == [];
    index = lib.mapAttrs (_: e: removeAttrs e ["body"]) entries;
    notes = entries;
    byHost = indexOf "hosts";
    byModule = indexOf "modules";
    byTask = indexOf "tasks";
    byStatus = byStatusIds;
    open = map (e: e.id) (builtins.filter (e: builtins.elem e.status openStatuses) ordered);
  };
in {
  inherit (api) schemaVersion counts issues ok index notes byHost byModule byTask byStatus open;
  inherit pages sitePages;
  json = builtins.toJSON api;
}
