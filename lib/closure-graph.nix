# closure-graph.nix — Nix-native closure analysis (prototype)
{lib}: let
  inherit
    (builtins)
    baseNameOf
    div
    elemAt
    floor
    fromJSON
    head
    isString
    length
    match
    readFile
    storePath
    tail
    toString
    ;

  # "…/<hash>-<name>" -> "<name>"
  # Mirrors the shell's `sub(/^[^-]*-/, "", n)`: the "/nix/store/" + hash prefix
  # never contains a "-", so stripping up to the first "-" is the same thing.
  stripHash = p: let
    parts = lib.splitString "-" p;
  in
    if length parts > 1
    then lib.concatStringsSep "-" (tail parts)
    else p;

  # registration -> [ { path, base, name, narSize } ]
  # `base` is the hashed basename (`top` view), `name` the hash-stripped one
  # (subsystem matching + TOML rows) — the shell draws the same distinction.
  #
  # NOTE: `builtins.readFile` of a store path returns a string *carrying that
  # store path in its context*, and every substring of it inherits the context.
  # Left alone, that context leaks into the rendered text and Nix refuses to
  # coerce it ("the string '1' is not allowed to refer to a store path").
  # Callers therefore pass context-free text; see `readInfo` below.
  # Home: docs/task-control-plane.md §"Nix-native counterpart".
  parseRegistration = text: let
    lines = text |> lib.removeSuffix "\n" |> lib.splitString "\n";
    n = length lines;
    go = i: acc:
      if i >= n
      then lib.reverseList acc
      else let
        path = lines |> (xs: elemAt xs i);
        narSize = lines |> (xs: elemAt xs (i + 2)) |> fromJSON;
        refCount = lines |> (xs: elemAt xs (i + 4)) |> fromJSON;
      in
        go (i + 5 + refCount) (
          [
            {
              inherit path narSize;
              base = baseNameOf path;
              name = stripHash path;
            }
          ]
          ++ acc
        );
  in
    if text == ""
    then []
    else go 0 [];

  # Read a file out of the closure-info derivation without dragging the
  # derivation's store-path context into the values derived from it.
  readInfo = path: path |> readFile |> builtins.unsafeDiscardStringContext;

  # Subsystem buckets. Order matters — first match wins, exactly as in the
  # shell's `case`, so the two rollups stay comparable.
  subsystemOf = name: let
    m = re: match re name != null;
  in
    if m ".*linux-firmware.*|.*firmware.*"
    then "firmware"
    else if m ".*linux-.*|.*kernel.*|.*kmod.*"
    then "kernel"
    else if m ".*systemd.*|.*udev.*"
    then "systemd"
    else if m ".*glibc.*|.*gcc-.*|.*libstdc.*|.*binutils.*|.*libgcc.*"
    then "toolchain"
    else if m ".*python3.*|.*python-.*"
    then "python"
    else if m ".*perl.*"
    then "perl"
    else if m ".*nodejs.*|.*node-.*"
    then "node"
    else if m ".*rust.*|.*cargo.*|.*clippy.*"
    then "rust"
    else if m ".*go-.*|.*go1..*|.*golang.*"
    then "go"
    else if m ".*llvm.*|.*clang.*"
    then "llvm"
    else if m ".*mesa.*|.*vulkan.*|.*libdrm.*|.*wayland.*|.*libGL.*|.*nvidia.*|.*rocm.*"
    then "graphics"
    else if m ".*qt.*|.*gtk.*|.*adwaita.*"
    then "gui-toolkit"
    else if m ".*font.*|.*noto.*|.*dejavu.*|.*freetype.*"
    then "fonts"
    else if m ".*ffmpeg.*|.*gstreamer.*|.*gst-.*|.*libav.*"
    then "media"
    else if m ".*jdk.*|.*jre.*|.*maven.*|.*gradle.*"
    then "java"
    else if m ".*torch.*|.*transformers.*|.*llama.*|.*onnx.*"
    then "ai"
    else if m "nixos-system-.*|.*nix-2.*|.*nixos-.*"
    then "nix"
    else "other";

  # Tie-breaks are not cosmetic: they decide which of two equal-sized paths
  # makes the top-N cut. The shell reaches them through GNU sort's last-resort
  # whole-line comparison, and the two views sort different lines:
  #   • `do_top`  sorts the `path<TAB>narSize<TAB>closureSize` rows  -> path asc
  #   • `do_toml` sorts `size<TAB>name` lines                        -> name asc
  # so both comparators are needed to stay byte-identical.
  bySizeDesc = a: b:
    if a.narSize != b.narSize
    then a.narSize > b.narSize
    else a.path < b.path;
  bySizeDescName = a: b:
    if a.narSize != b.narSize
    then a.narSize > b.narSize
    else a.name < b.name;

  # `printf '%12s'` pads on the LEFT; lib.strings.fixedWidthString pads right.
  padLeft = width: s: let
    len = lib.stringLength s;
  in
    if width > len
    then (width - len) |> lib.genList (_: " ") |> lib.concatStrings |> (pad: pad + s)
    else s;

  # --- human-readable sizes ---------------------------------------------------
  # `%.1f`-style fixed one-decimal rendering.
  fmt1 = x: let
    scaled = floor (x * 10.0 + 0.5);
    whole = div scaled 10;
    frac = scaled - whole * 10;
  in "${toString whole}.${toString frac}";

  # Replicates `numfmt --to=iec-i --suffix=B --format="%.1f"`. 1024-based, byte
  # counts keep the ".0" (192 -> "192.0B"), and — the non-obvious part —
  # numfmt's default rounding is `--round=up`, i.e. away from zero, NOT
  # round-to-nearest: 4617089844 B is 4.3000000007 GiB and prints "4.4GiB".
  # Integer arithmetic keeps this exact on the 0.1 boundaries.
  human = bytes: let
    units = [
      "B"
      "KiB"
      "MiB"
      "GiB"
      "TiB"
      "PiB"
    ];
    divisors = [
      1
      1024
      1048576
      1073741824
      1099511627776
      1125899906842624
    ];
    pick = i:
      if i + 1 < length divisors && bytes >= (divisors |> (xs: elemAt xs (i + 1)))
      then pick (i + 1)
      else i;
    idx = pick 0;
    d = divisors |> (xs: elemAt xs idx);
    scaled = div (bytes * 10 + d - 1) d; # ceil(bytes*10/d)
    whole = div scaled 10;
    frac = scaled - whole * 10;
  in "${toString whole}.${toString frac}${units |> (xs: elemAt xs idx)}";

  rollupOf = entries: let
    annotated = entries |> map (e: e // {sub = e.name |> subsystemOf;});
    subs = annotated |> map (e: e.sub) |> lib.unique;
    oneSub = sub: let
      sel = annotated |> builtins.filter (e: e.sub == sub);
    in {
      name = sub;
      bytes = sel |> lib.foldl' (a: e: a + e.narSize) 0;
      paths = length sel;
      top = sel |> lib.sort bySizeDescName;
    };
  in
    subs
    |> map oneSub
    |> lib.sort (a: b:
      if a.bytes != b.bytes
      then a.bytes > b.bytes
      else a.name < b.name);
in rec {
  inherit
    parseRegistration
    subsystemOf
    human
    fmt1
    stripHash
    padLeft
    ;

  # mkClosureGraph { pkgs, host, roots, rootLabel, topN, topPerSubsystem }
  #   pkgs      — an evaluated nixpkgs set (for `pkgs.closureInfo`)
  #   roots     — derivations, or "/nix/store/…" strings (declared with storePath)
  #   rootLabel — what the `size` view echoes as "closure:"; defaults to the
  #               resolved store path (pass "/run/current-system" to match the
  #               shell tool when no explicit target was given)
  #   topN      — how many biggest paths the `top` view lists
  mkClosureGraph = {
    pkgs,
    host ? "local",
    roots,
    rootLabel ? null,
    topN ? 15,
    topPerSubsystem ? 8,
  }: let
    declared =
      roots
      |> map (r:
        if isString r
        then storePath r
        else r);
    info = pkgs.closureInfo {rootPaths = declared;};
    entries = "${info}/registration" |> readInfo |> parseRegistration;
    totalBytes = "${info}/total-nar-size" |> readInfo |> fromJSON;
    rollup = entries |> rollupOf |> map (s: s // {top = s.top |> lib.take topPerSubsystem;});
  in {
    inherit host entries totalBytes rollup;
    rootPath = toString (head declared);
    rootName = baseNameOf (toString (head declared));
    label =
      if rootLabel != null
      then rootLabel
      else toString (head declared);
    pathCount = length entries;
    top = entries |> lib.sort bySizeDesc |> lib.take topN;
    infoPath = toString info;
    # sum of the parsed narSizes — a self-check against total-nar-size
    sumNarSize = entries |> lib.foldl' (a: e: a + e.narSize) 0;
  };

  # --- renderers --------------------------------------------------------------

  renderSize = g:
    "host:    ${g.host}\n"
    + "closure: ${g.label}\n"
    + "  paths: ${toString g.pathCount}\n"
    + "  size:  ${human g.totalBytes} (${toString g.totalBytes} bytes)\n";

  renderSubsystems = g:
    g.rollup
    |> lib.concatMapStrings (
      s: let
        pct =
          if g.totalBytes != 0
          then fmt1 (100.0 * s.bytes / g.totalBytes)
          else "0.0";
      in "${padLeft 12 (human s.bytes)}  ${padLeft 5 pct}%  ${padLeft 4 (toString s.paths)} pkgs  ${s.name}\n"
    );

  renderTop = g: g.top |> lib.concatMapStrings (e: "${padLeft 12 (human e.narSize)}  ${e.base}\n");

  toTOML = g: let
    block = s: let
      # The shell builds these rows in `$(...)`, which strips trailing
      # newlines — so its last row ends up glued to the closing bracket
      # (`...,]`). Reproduced verbatim so the two TOMLs are byte-identical;
      # it is a quirk of the baseline, not a design choice.
      rows =
        s.top
        |> map (e: "  { name = \"${e.name}\", bytes = ${toString e.narSize} },")
        |> lib.concatStringsSep "\n";
    in
      "[closure.subsystems.${s.name}]\n"
      + "bytes = ${toString s.bytes}\n"
      + "paths = ${toString s.paths}\n"
      + (
        if s.top == []
        then ""
        else "top = [\n${rows}]\n"
      )
      + "\n";
  in
    "# Closure static-analysis tree — generated by scripts/task/closure-analysis.sh\n"
    + "# Do not edit by hand. Levels: closure -> subsystem -> top packages.\n"
    + "# Source: ${g.host}:${g.label}\n\n"
    + "[closure]\n"
    + "host = \"${g.host}\"\n"
    + "system = \"${g.rootName}\"\n"
    + "total_bytes = ${toString g.totalBytes}\n"
    + "path_count = ${toString g.pathCount}\n\n"
    + (g.rollup |> map block |> lib.concatStrings);

  toDOT = g: let
    node = s:
      "  \"${s.name}\" [label=\"${s.name}\\n${human s.bytes} (${toString s.paths})\"];\n"
      + "  root -> \"${s.name}\" [label=\"${human s.bytes}\"];";
  in
    "digraph closure {\n"
    + "  rankdir=LR;\n"
    + "  node [shape=box, fontname=\"monospace\"];\n"
    + "  root [label=\"${g.host}:${g.rootName}\\n${human g.totalBytes}\"];\n"
    + (g.rollup |> lib.take 16 |> map node |> lib.concatStringsSep "\n")
    + "\n}\n";
}
