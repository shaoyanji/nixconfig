# Every comment in the tree, classified. A Nix file is written, evaluated and
# never read line by line, so a comment earns its place only as a pointer: a path
# that resolves, a `task` name the graph has, a policy id, a flake attribute.
# Anything else is prose, and prose has a ceiling that only falls. Gate:
# `flake/policies.nix#nix-comments-are-pointers`; census read:
# `nix eval --json .#nixComments | toon -e`.
{
  lib,
  root ? ../.,
  paths,
}: let
  rootStr = toString root;

  topDirs = builtins.attrNames (lib.filterAttrs (_: t: t == "directory") (builtins.readDir root));
  suffixes = [".nix" ".md" ".sh" ".toml" ".yml" ".yaml" ".json" ".jsonl" ".tsv" ".py" ".js" ".toon"];
  hasKnownSuffix = t: lib.any (s: lib.hasSuffix s t) suffixes;

  # Tokens, not substrings: `hosts/<name>/configuration.nix` is a template, not a
  # path, and a URL is not a repo file. Both fall out here instead of becoming an
  # unfixable "unresolved"
  tokens = text: builtins.filter builtins.isString (builtins.split "[^A-Za-z0-9_./-]+" text);

  pathRefs = body:
    lib.unique (builtins.filter (
        t:
          builtins.length (lib.splitString "/" t)
          > 1
          && !(lib.hasPrefix "/" t)
          && !(lib.hasPrefix "./" t)
          && !(lib.hasPrefix "../" t)
          && hasKnownSuffix t
          && builtins.elem (builtins.head (lib.splitString "/" t)) topDirs
      )
      (tokens body));

  # `flake/policies.nix#agent-prose-budget` in a comment is a citation, the same
  # relation a document writes in brackets; `flake/policies.nix` alone is a path.
  # `#<id>` and `#id` write the convention down; they are not citations of a rule.
  placeholderIds = ["id" "policy-id"];
  policyRefs = body: let
    parts = builtins.filter builtins.isString (builtins.split "flake/policies\\.nix#" body);
  in
    if builtins.length parts <= 1
    then []
    else
      lib.unique (
        builtins.filter (id: id != null && !(builtins.elem id placeholderIds)) (
          map (chunk: let
            m = builtins.match "([a-z0-9][a-z0-9-]*).*" chunk;
          in
            if m == null
            then null
            else builtins.head m)
          (builtins.tail parts)
        )
      );

  # `task <name>` is a pointer into the recipe book; the name set lives in
  # `taskfiles/*.yml`, so resolution is a script's job (`checks:nix:comments`).
  taskRefs = body: let
    parts = builtins.filter builtins.isString (builtins.split "task " body);
    pick = chunk: let
      raw = builtins.head (builtins.split "[^A-Za-z0-9:_*/-]" chunk);
    in
      lib.removeSuffix "." (lib.removeSuffix "," (lib.removeSuffix ":" raw));
  in
    builtins.filter (
      n: builtins.match "[a-z0-9][a-z0-9:_*/-]*:[A-Za-z0-9*][A-Za-z0-9:_*/-]*" n != null
    )
    (map pick (builtins.tail parts));

  attrRefs = body: let
    parts = builtins.filter builtins.isString (builtins.split "\\.#" body);
  in
    if builtins.length parts <= 1
    then []
    else
      builtins.filter (a: a != null) (
        map (chunk: let
          m = builtins.match "([A-Za-z0-9_-]+).*" chunk;
        in
          if m == null
          then null
          else builtins.head m)
        (builtins.tail parts)
      );

  occurrences = pat: text: builtins.length (builtins.filter builtins.isString (builtins.split pat text)) - 1;

  # A line inside a multi-line string is content, not a comment: the toggle is the
  # delimiter count on lines that are not themselves comments. `''$` is an escape
  # for a literal `$` inside the string, so `''${VAR}` never opens one.
  scanFile = p: let
    lines = lib.splitString "\n" (builtins.readFile (root + "/${p}"));
    indexed =
      lib.imap0 (i: l: {
        line = i + 1;
        text = l;
      })
      lines;
    step = acc: cur: let
      trimmed = lib.trim cur.text;
      quotes = occurrences "''" cur.text - occurrences "''\\$" cur.text;
      isComment = !acc.inside && lib.hasPrefix "#" trimmed;
      quotesHere =
        if isComment
        then 0
        else quotes;
      inside =
        if acc.inside
        then lib.mod quotesHere 2 == 0
        else lib.mod quotesHere 2 == 1;
      body = lib.trim (lib.removePrefix "#" trimmed);
      rule = builtins.stringLength body >= 4 && builtins.match "[=#-]+" body != null;
      dated = builtins.match ".*20[0-9][0-9]-[0-9][0-9]-[0-9][0-9].*" body != null;
      policy = policyRefs body;
      task = taskRefs body;
      attr = attrRefs body;
      path = pathRefs body;
      kind =
        if rule
        then "rule"
        else if dated
        then "dated"
        else if policy != [] || task != [] || attr != [] || path != []
        then "pointer"
        else "header";
      entry = {
        file = p;
        inherit (cur) line;
        inherit kind body policy task attr path;
      };
    in
      if isComment
      then {
        inherit inside;
        entries = acc.entries ++ [entry];
      }
      else {
        inherit inside;
        entries = acc.entries;
      };
    out =
      builtins.foldl' step {
        inside = false;
        entries = [];
      }
      indexed;
  in
    out.entries;

  entries = lib.concatMap scanFile paths;

  countOf = k: builtins.length (builtins.filter (e: e.kind == k) entries);

  # Where the prose actually sits, so a cleanup has an address instead of a total.
  headerPerFile = builtins.listToAttrs (map (p: let
      n = builtins.length (builtins.filter (e: e.file == p && e.kind == "header") entries);
    in {
      name = p;
      value = n;
    })
    paths);
  worst = lib.take 12 (
    lib.sort (a: b: a.lines > b.lines) (lib.mapAttrsToList (path: lines: {inherit path lines;}) headerPerFile)
  );

  policyCites = lib.concatMap (e:
    map (id: {
      inherit (e) file line;
      inherit id;
    })
    e.policy)
  entries;
  taskCites = lib.concatMap (e:
    map (name: {
      inherit (e) file line;
      inherit name;
    })
    e.task)
  entries;
  pathCites = lib.concatMap (e:
    map (p: {
      inherit (e) file line;
      path = p;
    })
    e.path)
  entries;
in {
  files = builtins.length paths;
  comments = builtins.length entries;
  rules = countOf "rule";
  dated = countOf "dated";
  pointers = countOf "pointer";
  header = countOf "header";
  kinds = {
    policy = builtins.length policyCites;
    task = builtins.length taskCites;
    attr = builtins.length (lib.concatMap (e: e.attr) entries);
    path = builtins.length pathCites;
  };
  unresolvedPaths = lib.unique (builtins.filter (c: !(builtins.pathExists (root + "/${c.path}"))) pathCites);
  inherit policyCites taskCites worst;
  ruleLines = map (e: {
    inherit (e) file line body;
  }) (builtins.filter (e: e.kind == "rule") entries);
  root = rootStr;
}
