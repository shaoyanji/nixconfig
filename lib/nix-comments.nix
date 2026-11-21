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

  topDirs =
    root
    |> builtins.readDir
    |> lib.filterAttrs (_: t: t == "directory")
    |> builtins.attrNames;
  suffixes = [".nix" ".md" ".sh" ".toml" ".yml" ".yaml" ".json" ".jsonl" ".tsv" ".py" ".js" ".toon"];
  hasKnownSuffix = t: lib.any (s: lib.hasSuffix s t) suffixes;

  # Tokens, not substrings: `hosts/<name>/configuration.nix` is a template, not a
  # path, and a URL is not a repo file. Both fall out here instead of becoming an
  # unfixable "unresolved"
  tokens = text:
    text
    |> builtins.split "[^A-Za-z0-9_./-]+"
    |> builtins.filter builtins.isString;

  pathRefs = body:
    body
    |> tokens
    |> builtins.filter (
      t:
        (lib.splitString "/" t |> builtins.length)
        > 1
        && !(lib.hasPrefix "/" t)
        && !(lib.hasPrefix "./" t)
        && !(lib.hasPrefix "../" t)
        && hasKnownSuffix t
        && (lib.splitString "/" t |> builtins.head |> (h: builtins.elem h topDirs))
    )
    |> lib.unique;

  # `flake/policies.nix#agent-prose-budget` in a comment is a citation, the same
  # relation a document writes in brackets; `flake/policies.nix` alone is a path.
  # `#<id>` and `#id` write the convention down; they are not citations of a rule.
  placeholderIds = ["id" "policy-id"];
  policyRefs = body: let
    parts =
      body
      |> builtins.split "flake/policies\\.nix#"
      |> builtins.filter builtins.isString;
  in
    if builtins.length parts <= 1
    then []
    else
      parts
      |> builtins.tail
      |> map (
        chunk: let
          m = builtins.match "([a-z0-9][a-z0-9-]*).*" chunk;
        in
          if m == null
          then null
          else builtins.head m
      )
      |> builtins.filter (id: id != null && !(builtins.elem id placeholderIds))
      |> lib.unique;

  # `task <name>` is a pointer into the recipe book; the name set lives in
  # `taskfiles/*.yml`, so resolution is a script's job (`checks:nix:comments`).
  taskRefs = body: let
    parts =
      body
      |> builtins.split "task "
      |> builtins.filter builtins.isString;
    pick = chunk:
      chunk
      |> builtins.split "[^A-Za-z0-9:_*/-]"
      |> builtins.head
      |> lib.removeSuffix ":"
      |> lib.removeSuffix ","
      |> lib.removeSuffix ".";
  in
    parts
    |> builtins.tail
    |> map pick
    |> builtins.filter (
      n: builtins.match "[a-z0-9][a-z0-9:_*/-]*:[A-Za-z0-9*][A-Za-z0-9:_*/-]*" n != null
    );

  attrRefs = body: let
    parts =
      body
      |> builtins.split "\\.#"
      |> builtins.filter builtins.isString;
  in
    if builtins.length parts <= 1
    then []
    else
      parts
      |> builtins.tail
      |> map (
        chunk: let
          m = builtins.match "([A-Za-z0-9_-]+).*" chunk;
        in
          if m == null
          then null
          else builtins.head m
      )
      |> builtins.filter (a: a != null);

  occurrences = pat: text:
    text
    |> builtins.split pat
    |> builtins.filter builtins.isString
    |> builtins.length
    |> (n: n - 1);

  # A line inside a multi-line string is content, not a comment: the toggle is the
  # delimiter count on lines that are not themselves comments. `''$` is an escape
  # for a literal `$` inside the string, so `''${VAR}` never opens one.
  # A *.shadow.nix is a retired-code store: comments are the payload, not prose
  # debt, so they classify as `shadow` — counted, pointer-resolved, but outside
  # the header/dated ceilings a live file is held to.
  scanFile = p: let
    shadow = lib.hasSuffix ".shadow.nix" p;
    lines =
      root
      + "/${p}"
      |> builtins.readFile
      |> lib.splitString "\n";
    indexed =
      lines
      |> lib.imap0 (i: l: {
        line = i + 1;
        text = l;
      });
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
        if shadow
        then "shadow"
        else if rule
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
        inherit (acc) entries;
      };
    out =
      indexed
      |> builtins.foldl' step {
        inside = false;
        entries = [];
      };
  in
    out.entries;

  entries = paths |> lib.concatMap scanFile;

  countOf = k: entries |> builtins.filter (e: e.kind == k) |> builtins.length;

  # Where the prose actually sits, so a cleanup has an address instead of a total.
  headerPerFile =
    paths
    |> map (
      p: {
        name = p;
        value = entries |> builtins.filter (e: e.file == p && e.kind == "header") |> builtins.length;
      }
    )
    |> builtins.listToAttrs;
  worst =
    headerPerFile
    |> lib.mapAttrsToList (path: lines: {inherit path lines;})
    |> lib.sort (a: b: a.lines > b.lines)
    |> lib.take 12;

  policyCites =
    entries
    |> lib.concatMap (
      e:
        e.policy
        |> map (id: {
          inherit (e) file line;
          inherit id;
        })
    );
  taskCites =
    entries
    |> lib.concatMap (
      e:
        e.task
        |> map (name: {
          inherit (e) file line;
          inherit name;
        })
    );
  pathCites =
    entries
    |> lib.concatMap (
      e:
        e.path
        |> map (p: {
          inherit (e) file line;
          path = p;
        })
    );
in {
  files = builtins.length paths;
  comments = builtins.length entries;
  rules = countOf "rule";
  dated = countOf "dated";
  shadow = countOf "shadow";
  pointers = countOf "pointer";
  header = countOf "header";
  kinds = {
    policy = builtins.length policyCites;
    task = builtins.length taskCites;
    attr = entries |> lib.concatMap (e: e.attr) |> builtins.length;
    path = builtins.length pathCites;
  };
  unresolvedPaths =
    pathCites
    |> builtins.filter (c: !(builtins.pathExists (root + "/${c.path}")))
    |> lib.unique;
  inherit policyCites taskCites worst headerPerFile;
  ruleLines =
    entries
    |> builtins.filter (e: e.kind == "rule")
    |> map (e: {
      inherit (e) file line body;
    });
  root = rootStr;
}
