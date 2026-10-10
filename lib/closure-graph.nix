# ==============================================================================
# closure-graph.nix — Nix-native closure analysis (prototype)
# ==============================================================================
#
# Milestone 4 of `docs/control-plane-vision.md` ("Nix-native closure graph"):
# the same data as `scripts/task/closure-analysis.sh`, expressed as a function
# over Nix's own store graph instead of a shell loop over `nix path-info`.
#
# Why `pkgs.closureInfo` and not `nix path-info`:
#   `closureInfo { rootPaths = [ root ]; }` runs `exportReferencesGraph` in its
#   builder, so the traversal is done BY NIX over the derivation graph. It emits
#   a store path — reproducible and cached — containing:
#
#     store-paths      every path in the closure, one per line
#     registration     `nix-store --load-db` format, i.e. per path:
#                        <path> / <narHash> / <narSize> / <deriver> /
#                        <refCount> / <ref>…
#     total-nar-size   sum of the *own* (nar) sizes — the closure's footprint
#
#   Verified on frieren: `store-paths` and `nix path-info --recursive` return
#   the *identical* 3949-path set, and `total-nar-size` equals the shell tool's
#   summed narSize exactly. So this is not an approximation.
#
# Declaring roots (the sharp edge):
#   `exportReferencesGraph` refuses paths that are not in the derivation's input
#   closure:
#     error: cannot export references of path '…' because it is not in the input
#            closure of the derivation
#   Passing the "/run/current-system" symlink therefore fails. Two things work:
#     • `builtins.storePath "/nix/store/…"`  — a live, already-resolved store path
#     • a derivation attribute (`config.system.build.toplevel`) — inside a flake
#   `mkClosureGraph` accepts either and declares strings with `storePath`.
#
# Scope: local store only. Unlike `closure-analysis.sh` this cannot read a
# remote store (`closureInfo` builds locally); a remote host's closure must be
# copied or analysed by the shell tool.
# ==============================================================================
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
  parseRegistration = text: let
    lines = lib.splitString "\n" (lib.removeSuffix "\n" text);
    n = length lines;
    go = i: acc:
      if i >= n
      then lib.reverseList acc
      else let
        path = elemAt lines i;
        narSize = fromJSON (elemAt lines (i + 2));
        refCount = fromJSON (elemAt lines (i + 4));
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
  readInfo = path: builtins.unsafeDiscardStringContext (readFile path);

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
    then lib.concatStrings (lib.genList (_: " ") (width - len)) + s
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
      if i + 1 < length divisors && bytes >= elemAt divisors (i + 1)
      then pick (i + 1)
      else i;
    idx = pick 0;
    d = elemAt divisors idx;
    scaled = div (bytes * 10 + d - 1) d; # ceil(bytes*10/d)
    whole = div scaled 10;
    frac = scaled - whole * 10;
  in "${toString whole}.${toString frac}${elemAt units idx}";

  rollupOf = entries: let
    annotated = map (e: e // {sub = subsystemOf e.name;}) entries;
    subs = lib.unique (map (e: e.sub) annotated);
    oneSub = sub: let
      sel = builtins.filter (e: e.sub == sub) annotated;
    in {
      name = sub;
      bytes = lib.foldl' (a: e: a + e.narSize) 0 sel;
      paths = length sel;
      top = lib.sort bySizeDescName sel;
    };
  in
    lib.sort (a: b:
      if a.bytes != b.bytes
      then a.bytes > b.bytes
      else a.name < b.name) (map oneSub subs);
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
    declared = map (r:
      if isString r
      then storePath r
      else r)
    roots;
    info = pkgs.closureInfo {rootPaths = declared;};
    entries = parseRegistration (readInfo "${info}/registration");
    totalBytes = fromJSON (readInfo "${info}/total-nar-size");
    rollup = map (s: s // {top = lib.take topPerSubsystem s.top;}) (rollupOf entries);
  in {
    inherit host entries totalBytes rollup;
    rootPath = toString (head declared);
    rootName = baseNameOf (toString (head declared));
    label =
      if rootLabel != null
      then rootLabel
      else toString (head declared);
    pathCount = length entries;
    top = lib.take topN (lib.sort bySizeDesc entries);
    infoPath = toString info;
    # sum of the parsed narSizes — a self-check against total-nar-size
    sumNarSize = lib.foldl' (a: e: a + e.narSize) 0 entries;
  };

  # --- renderers --------------------------------------------------------------

  renderSize = g:
    "host:    ${g.host}\n"
    + "closure: ${g.label}\n"
    + "  paths: ${toString g.pathCount}\n"
    + "  size:  ${human g.totalBytes} (${toString g.totalBytes} bytes)\n";

  renderSubsystems = g:
    lib.concatMapStrings (
      s: let
        pct =
          if g.totalBytes != 0
          then fmt1 (100.0 * s.bytes / g.totalBytes)
          else "0.0";
      in "${padLeft 12 (human s.bytes)}  ${padLeft 5 pct}%  ${padLeft 4 (toString s.paths)} pkgs  ${s.name}\n"
    )
    g.rollup;

  renderTop = g: lib.concatMapStrings (e: "${padLeft 12 (human e.narSize)}  ${e.base}\n") g.top;

  toTOML = g: let
    block = s: let
      # The shell builds these rows in `$(...)`, which strips trailing
      # newlines — so its last row ends up glued to the closing bracket
      # (`...,]`). Reproduced verbatim so the two TOMLs are byte-identical;
      # it is a quirk of the baseline, not a design choice.
      rows = lib.concatStringsSep "\n" (
        map (e: "  { name = \"${e.name}\", bytes = ${toString e.narSize} },") s.top
      );
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
    + lib.concatStrings (map block g.rollup);

  toDOT = g: let
    node = s:
      "  \"${s.name}\" [label=\"${s.name}\\n${human s.bytes} (${toString s.paths})\"];\n"
      + "  root -> \"${s.name}\" [label=\"${human s.bytes}\"];";
  in
    "digraph closure {\n"
    + "  rankdir=LR;\n"
    + "  node [shape=box, fontname=\"monospace\"];\n"
    + "  root [label=\"${g.host}:${g.rootName}\\n${human g.totalBytes}\"];\n"
    + lib.concatStringsSep "\n" (map node (lib.take 16 g.rollup))
    + "\n}\n";
}
