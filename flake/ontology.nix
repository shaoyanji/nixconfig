{
  lib,
  epistemics ? import ./epistemics.nix {inherit lib;},
}: let
  tiers = lib.mapAttrs (_: e: e.rank) epistemics.evidence;
  tierNotes = lib.mapAttrs (_: e: e.what) epistemics.evidence;

  entities = {
    doc = {
      what = "a markdown page a person routes by: AGENTS.md, docs/, .agents/, taskfiles/, hosts/*/README.md";
      identity = "the repo-relative path; two pages are the same page only at the same path";
      member = "lib/knowledge-graph.nix docFiles";
      fields = ["label" "path" "cites"];
      claims = ["config-syntax" "decision" "definition" "fleet-fact" "historical-fact" "procedure" "software-behaviour"];
    };
    idea = {
      what = "an unfinished draft in ideas/, carrying frontmatter and nothing a reader routes by";
      identity = "the basename of the file, without .md";
      member = "lib/knowledge-graph.nix ideaFiles";
      fields = ["label" "path"];
      claims = [];
    };
    host = {
      what = "a machine the fleet builds, registered in inventory.toml";
      identity = "the inventory key, which is also the flake attribute name";
      member = "inventory.toml through lib/inventory.nix";
      fields = ["label" "status" "kind"];
      claims = ["fleet-fact"];
    };
    module = {
      what = "a tracked .nix file, addressed by its path rather than by a registry name";
      identity = "the repo-relative path";
      member = "lib/nix-files.nix";
      fields = ["label" "path"];
      claims = ["fleet-fact"];
    };
    note = {
      what = "a decision, proposal, experiment, open item, handoff or reference in AGENTS.nix";
      identity = "the attrset key under notes, which the id grammar already constrains";
      member = "AGENTS.nix through lib/agents-notes.nix";
      fields = ["label" "path" "kind" "status" "claim"];
      claims = lib.unique (builtins.attrValues epistemics.noteClaims);
    };
    policy = {
      what = "a rule a machine can check, declared in flake/policies.nix";
      identity = "the bare id, without the citing path and the #";
      member = "flake/policies.nix";
      fields = ["label" "path" "rule" "proof"];
      claims = ["decision"];
    };
    skill = {
      what = "an agent procedure in .agents/skills/<name>/SKILL.md";
      identity = "the directory name, which the frontmatter name must equal";
      member = "lib/skills.nix";
      fields = ["label" "description" "path" "tags" "cites"];
      claims = ["definition" "procedure" "software-behaviour"];
    };
    task = {
      what = "a thing a person runs: a name in taskfiles/*.yml that go-task exposes, with the description it prints";
      identity = "the full name you type after `task`, namespace included — `help`, `checks:host`";
      member = "flake/outputs.nix taskList: yq projects taskfiles/*.yml to JSON at eval, Nix reads the JSON";
      fields = ["label" "desc" "shard" "aliasOf"];
      claims = ["procedure"];
    };
    tag = {
      what = "a free label a skill declares";
      identity = "the label text itself";
      member = "lib/skills.nix byTag";
      fields = ["label"];
      claims = [];
    };
  };

  relations = {
    about = {
      what = "a draft names the entity it is about";
      from = ["idea"];
      to = ["doc" "host" "skill"];
      evidence = "the `about` list of the draft frontmatter, filtered to ids that exist";
      tier = "asserted";
      cannot = "that the draft is agreed or delivered: status is the note's, not the edge's";
    };
    cites = {
      what = "a page or a skill cites a policy id instead of restating the rule";
      from = ["doc" "skill"];
      to = ["policy"];
      evidence = "`[[flake/policies.nix#<id>]]`, resolved against the ids flake/policies.nix declares";
      tier = "resolved";
      cannot = "that the citing page obeys the rule; the gate proves the citation, not the conduct";
    };
    derives = {
      what = "a note exists because of an earlier note: it grew out of it, closes it, or was inspired by it";
      from = ["note"];
      to = ["note"];
      evidence = "the `from` list of the note, filtered to note ids that exist";
      tier = "resolved";
      cannot = "causation or agreement: the author asserted the link, and the arrow only says which note came first";
    };
    imports = {
      what = "one Nix file imports another";
      from = ["module"];
      to = ["module"];
      evidence = "an import path in the source, resolved against the file walk in lib/nix-files.nix";
      tier = "extracted";
      cannot = "that the import is on an enabled host's path: the chain decides that, one host at a time";
    };
    mentions = {
      what = "an entity name appears in a page body";
      from = ["doc"];
      to = ["host" "skill"];
      evidence = "a token match on the entity name, split on non-name characters so devji is not dev";
      tier = "extracted";
      cannot = "an intent, a version, or that the page is about the entity; it is a place to look";
    };
    routes = {
      what = "a playbook row names the task that carries it out";
      from = ["doc" "skill"];
      to = ["task"];
      evidence = "a backticked command in a labelled references/playbooks.md row, whose first word names a declared task; the edge carries the row's label";
      tier = "resolved";
      cannot = "that the task still does what the row claims, or that the row's gate is the one that runs";
    };
    references = {
      what = "one page links to another";
      from = ["doc"];
      to = ["doc"];
      evidence = "an inline markdown link whose target resolves to a page in the doc set";
      tier = "resolved";
      cannot = "that the target was read, or that the sentence around the link is still true";
    };
    supersedes = {
      what = "a note replaces an earlier one, which stays in the record as SUPERSEDED";
      from = ["note"];
      to = ["note"];
      evidence = "the `supersedes` list of the replacement, gated to name a note marked SUPERSEDED";
      tier = "resolved";
      cannot = "that every other page already cites the replacement; retired prose may still link the old note";
    };
    tagged = {
      what = "a skill declares a tag";
      from = ["skill"];
      to = ["tag"];
      evidence = "the tags list of SKILL.md, parsed by lib/skills.nix";
      tier = "asserted";
      cannot = "that a skill sharing the tag is related, or that the tag names a topic anyone maintains";
    };
  };

  sinks = {
    "current-release" = {
      kind = "none";
      where = "nothing durable: a moving answer carries its date, not a corpus entry";
    };
    "personal-method" = {
      kind = "external";
      where = "every `## Claim` in ~/vaults/personal";
    };
    "project-fact" = {
      kind = "external";
      where = "every `## Claim` in ~/vaults/personal";
    };
    "model-label" = {
      kind = "external";
      where = "the turn log (xs), with the label and its margin — never a fact";
    };
  };

  entityIds = builtins.attrNames entities;
  relationIds = builtins.attrNames relations;

  idType = id: let
    parts = lib.splitString ":" id;
    head = builtins.head parts;
  in
    if builtins.length parts < 2
    then null
    else if builtins.hasAttr head entities
    then head
    else null;

  admit = edge: let
    rel = relations.${edge.type} or null;
    src = idType (edge.from or "");
    dst = idType (edge.to or "");
    verdict = ok: why: {
      inherit (edge) from to type;
      tier =
        if rel == null
        then null
        else rel.tier;
      producedBy =
        if rel == null
        then null
        else epistemics.evidence.${rel.tier}.producedBy;
      canSettle =
        if rel == null
        then []
        else epistemics.canCarry rel.tier;
      promote =
        if rel == null
        then null
        else epistemics.evidence.${rel.tier}.promote;
      inherit ok why;
    };
  in
    if rel == null
    then verdict false "no relation '${toString (edge.type or "")}' is declared"
    else if src == null || !(builtins.elem src rel.from)
    then verdict false "${toString src} is not a declared source of ${edge.type}"
    else if dst == null || !(builtins.elem dst rel.to)
    then verdict false "${toString dst} is not a declared target of ${edge.type}"
    else verdict true "${src} --${rel.tier}--> ${dst}";

  homes =
    lib.foldl' (
      acc: t:
        lib.foldl' (a: k: a // {"${k}" = (a.${k} or []) ++ [t];}) acc entities.${t}.claims
    ) {}
    entityIds;

  stableKinds = builtins.filter (k: epistemics.kinds.${k}.volatility == "stable") epistemics.kindIds;
  unhomed = builtins.filter (k: !(builtins.hasAttr k homes) && !(builtins.hasAttr k sinks)) stableKinds;
  sinkIds = builtins.attrNames sinks;
  straySinks = builtins.filter (k: !(builtins.elem k epistemics.kindIds)) sinkIds;

  touches = t:
    builtins.filter (r: builtins.elem t relations.${r}.from || builtins.elem t relations.${r}.to) relationIds;

  weak = builtins.filter (r: relations.${r}.tier == "extracted") relationIds;

  samples = [
    {
      type = "cites";
      from = "doc:AGENTS.md";
      to = "policy:agent-prose-budget";
    }
    {
      type = "mentions";
      from = "doc:MANUAL.md";
      to = "host:frieren";
    }
    {
      type = "references";
      from = "doc:AGENTS.md";
      to = "module:flake/nix-registry.nix";
    }
  ];
in {
  inherit entities relations tiers tierNotes sinks sinkIds entityIds relationIds homes stableKinds unhomed straySinks samples idType admit touches weak;
  inherit (epistemics) evidence;
  all = map admit samples;
  count = {
    entities = builtins.length entityIds;
    relations = builtins.length relationIds;
  };
}
