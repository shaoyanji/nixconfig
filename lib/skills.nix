# Skills as compiled data.
{lib}: let
  root = ../.agents/skills;

  isDir = t: t == "directory";
  dirs = builtins.attrNames (lib.filterAttrs (_: isDir) (builtins.readDir root));

  # --- small, total text helpers -------------------------------------------
  trimL = s: let
    m = builtins.match "[[:space:]]*(.*)" s;
  in
    if m == null
    then ""
    else builtins.head m;

  trim = s: let
    m = builtins.match "(.*[^[:space:]])[[:space:]]*" (trimL s);
  in
    if m == null
    then ""
    else builtins.head m;

  unquote = s: let
    dq = builtins.match "\"(.*)\"" s;
    sq = builtins.match "'(.*)'" s;
  in
    if dq != null
    then builtins.head dq
    else if sq != null
    then builtins.head sq
    else s;

  # `[linux, macos]` -> ["linux" "macos"]; a bare scalar -> [scalar].
  parseList = v: let
    s = trim v;
    m = builtins.match "[[](.*)[]]" s;
  in
    if s == ""
    then []
    else if m == null
    then [(unquote s)]
    else
      builtins.head m
      |> lib.splitString ","
      |> map (x: x |> trim |> unquote)
      |> lib.filter (x: x != "");

  takeUntil = pred: xs: let
    go = acc: rest:
      if rest == []
      then acc
      else if pred (builtins.head rest)
      then acc
      else go (acc ++ [(builtins.head rest)]) (builtins.tail rest);
  in
    go [] xs;

  dropN = n: xs:
    if n <= 0 || xs == []
    then xs
    else dropN (n - 1) (builtins.tail xs);

  # --- frontmatter ----------------------------------------------------------
  # The schema is deliberately a *subset* of YAML: `key: value` lines between
  # the first two `---` fences, optional indentation, no nested mappings.
  parse = text: let
    lines = lib.splitString "\n" text;
    fm = takeUntil (l: trim l == "---") (dropN 1 lines);
    fields =
      lib.foldl' (
        acc: line: let
          t = trim line;
          m = builtins.match "([A-Za-z0-9_-]+):[[:space:]]*(.*)" t;
        in
          if m == null
          then acc
          else acc // {"${builtins.head m}" = builtins.elemAt m 1;}
      ) {}
      fm;
    body = dropN (builtins.length fm + 2) lines;
    bodyFirst = builtins.head (
      lib.filter (l: trim l != "") (takeUntil (l: lib.hasPrefix "# " (trim l)) body)
      ++ (lib.filter (l: trim l != "") body)
      ++ [""]
    );
  in {inherit fields body bodyFirst lines;};

  readSkill = name: let
    text = builtins.readFile (root + "/${name}/SKILL.md");
    p = parse text;
    declared = unquote (trim (p.fields.name or ""));
    description = unquote (trim (p.fields.description or ""));
    version = unquote (trim (p.fields.version or "0.0.0"));
    tags = parseList (p.fields.tags or "");
    platforms = parseList (p.fields.platforms or "");
    lineCount = builtins.length p.lines;
  in {
    inherit name description version tags platforms lineCount;
    # The parsed body lines (`p.body`), for a gate that has to read the markdown
    # itself — currently the task-mirror check. `index` does not project it.
    body = p.body;
    declaredName = declared;
    path = ".agents/skills/${name}";
    bodyHeading = trim p.bodyFirst;
    # Soft: the schema says these are optional with defaults.
    missing =
      lib.optional (version == "0.0.0") "version"
      ++ lib.optional (platforms == []) "platforms"
      ++ lib.optional (tags == []) "tags";
  };

  skills = builtins.listToAttrs (map (n: {
      name = n;
      value = readSkill n;
    })
    dirs);

  issueFor = s:
    lib.optional (s.declaredName != s.name)
    "name: '${s.declaredName}' does not match directory '${s.name}' (agent discovery uses the directory)"
    ++ lib.optional (s.declaredName == "")
    "name: missing"
    ++ lib.optional (s.description == "")
    "description: missing"
    ++ lib.optional (builtins.stringLength s.description > 240)
    "description: ${toString (builtins.stringLength s.description)} chars > 240 (it is a routing hint, not a summary)"
    ++ lib.optional (builtins.stringLength s.description < 10 && s.description != "")
    "description: too short to route on"
    ++ lib.optional (s.lineCount > 400)
    "body: ${toString s.lineCount} lines > 400 (move detail to docs/ and keep the skill a router)"
    ++ lib.optional (!(lib.hasPrefix "# " s.bodyHeading))
    "body: does not start with a level-1 heading";

  issues = lib.concatMap (n: map (m: "${n}: ${m}") (issueFor skills.${n})) dirs;
  warnings = lib.concatMap (n: map (f: "${n}: missing optional frontmatter '${f}' (defaults applied)") skills.${n}.missing) dirs;

  byTag =
    lib.foldl' (
      acc: n:
        lib.foldl' (a: t: a // {"${t}" = (a."${t}" or []) ++ [n];})
        acc
        skills.${n}.tags
    ) {}
    dirs;

  index = {
    schemaVersion = 1;
    generatedBy = "lib/skills.nix";
    count = builtins.length dirs;
    skills =
      lib.mapAttrs (_: s: {
        inherit (s) description version tags platforms lineCount path;
      })
      skills;
    inherit byTag;
  };
in {
  inherit skills index byTag issues warnings;
  ok = issues == [];
  strictOk = issues == [] && warnings == [];
}
