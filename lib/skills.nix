# Skills as compiled data.
{lib}: let
  root = ../.agents/skills;

  isDir = t: t == "directory";
  dirs =
    root
    |> builtins.readDir
    |> lib.filterAttrs (_: isDir)
    |> builtins.attrNames;

  # --- small, total text helpers -------------------------------------------
  trimL = s:
    s
    |> builtins.match "[[:space:]]*(.*)"
    |> (m:
      if m == null
      then ""
      else m |> builtins.head);

  trim = s:
    s
    |> trimL
    |> builtins.match "(.*[^[:space:]])[[:space:]]*"
    |> (m:
      if m == null
      then ""
      else m |> builtins.head);

  unquote = s: let
    dq = s |> builtins.match "\"(.*)\"";
    sq = s |> builtins.match "'(.*)'";
  in
    if dq != null
    then dq |> builtins.head
    else if sq != null
    then sq |> builtins.head
    else s;

  # `[linux, macos]` -> ["linux" "macos"]; a bare scalar -> [scalar].
  parseList = v: let
    s = v |> trim;
    m = s |> builtins.match "[[](.*)[]]";
  in
    if s == ""
    then []
    else if m == null
    then [(s |> unquote)]
    else
      m
      |> builtins.head
      |> lib.splitString ","
      |> map (x: x |> trim |> unquote)
      |> lib.filter (x: x != "");

  takeUntil = pred: xs: let
    go = acc: rest:
      if rest == []
      then acc
      else if rest |> builtins.head |> pred
      then acc
      else go (acc ++ [(rest |> builtins.head)]) (rest |> builtins.tail);
  in
    go [] xs;

  dropN = n: xs:
    if n <= 0 || xs == []
    then xs
    else xs |> builtins.tail |> dropN (n - 1);

  # --- frontmatter ----------------------------------------------------------
  # The schema is deliberately a *subset* of YAML: `key: value` lines between
  # the first two `---` fences, optional indentation, no nested mappings.
  parse = text: let
    lines = text |> lib.splitString "\n";
    fm = lines |> dropN 1 |> takeUntil (l: (l |> trim) == "---");
    fields =
      fm
      |> lib.foldl' (
        acc: line: let
          t = line |> trim;
          m = t |> builtins.match "([A-Za-z0-9_-]+):[[:space:]]*(.*)";
        in
          if m == null
          then acc
          else acc // {"${m |> builtins.head}" = m |> (xs: builtins.elemAt xs 1);}
      ) {};
    body = lines |> dropN (fm |> builtins.length |> (n: n + 2));
    bodyFirst =
      (
        (body |> takeUntil (l: l |> trim |> lib.hasPrefix "# ") |> lib.filter (l: (l |> trim) != ""))
        ++ (body |> lib.filter (l: (l |> trim) != ""))
        ++ [""]
      )
      |> builtins.head;
  in {inherit fields body bodyFirst lines;};

  readSkill = name: let
    text = root + "/${name}/SKILL.md" |> builtins.readFile;
    p = text |> parse;
    declared = (p.fields.name or "") |> trim |> unquote;
    description = (p.fields.description or "") |> trim |> unquote;
    version = (p.fields.version or "0.0.0") |> trim |> unquote;
    tags = (p.fields.tags or "") |> parseList;
    platforms = (p.fields.platforms or "") |> parseList;
    lineCount = p.lines |> builtins.length;
  in {
    inherit name description version tags platforms lineCount;
    # The parsed body lines (`p.body`), for a gate that has to read the markdown
    # itself — currently the task-mirror check. `index` does not project it.
    inherit (p) body;
    declaredName = declared;
    path = ".agents/skills/${name}";
    bodyHeading = p.bodyFirst |> trim;
    # Soft: the schema says these are optional with defaults.
    missing =
      lib.optional (version == "0.0.0") "version"
      ++ lib.optional (platforms == []) "platforms"
      ++ lib.optional (tags == []) "tags";
  };

  skills =
    dirs
    |> map (n: {
      name = n;
      value = n |> readSkill;
    })
    |> builtins.listToAttrs;

  issueFor = s:
    lib.optional (s.declaredName != s.name)
    "name: '${s.declaredName}' does not match directory '${s.name}' (agent discovery uses the directory)"
    ++ lib.optional (s.declaredName == "")
    "name: missing"
    ++ lib.optional (s.description == "")
    "description: missing"
    ++ lib.optional ((s.description |> builtins.stringLength) > 240)
    "description: ${s.description |> builtins.stringLength |> toString} chars > 240 (it is a routing hint, not a summary)"
    ++ lib.optional ((s.description |> builtins.stringLength) < 10 && s.description != "")
    "description: too short to route on"
    ++ lib.optional (s.lineCount > 400)
    "body: ${s.lineCount |> toString} lines > 400 (move detail to docs/ and keep the skill a router)"
    ++ lib.optional (!(s.bodyHeading |> lib.hasPrefix "# "))
    "body: does not start with a level-1 heading";

  issues = dirs |> lib.concatMap (n: skills.${n} |> issueFor |> map (m: "${n}: ${m}"));
  warnings = dirs |> lib.concatMap (n: skills.${n}.missing |> map (f: "${n}: missing optional frontmatter '${f}' (defaults applied)"));

  byTag =
    dirs
    |> lib.foldl' (
      acc: n:
        skills.${n}.tags
        |> lib.foldl' (a: t: a // {"${t}" = (a."${t}" or []) ++ [n];}) acc
    ) {};

  index = {
    schemaVersion = 1;
    generatedBy = "lib/skills.nix";
    count = dirs |> builtins.length;
    skills =
      skills
      |> lib.mapAttrs (_: s: {
        inherit (s) description version tags platforms lineCount path;
      });
    inherit byTag;
  };
in {
  inherit skills index byTag issues warnings;
  ok = issues == [];
  strictOk = issues == [] && warnings == [];
}
