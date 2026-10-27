# lib/delphi-site.nix — delphi's two surfaces (public dossier, tailnet console)
# from ONE evaluated structure: registry + knowledge graph + service-portal cards.
# Reasons and runbook: .agents/deploy/hosts/delphi.md § The two surfaces.
{
  pkgs,
  lib ? pkgs.lib,
  # Compiled registry (flake output `inventory`). The host passes
  # `config.fleet.inventory`, so the page cannot disagree with the host config
  # about a status, a role or an address. The TOML fallback exists only for a
  # standalone `nix-build lib/delphi-site.nix` — which needs `cards` too, and
  # says so at eval instead of rendering an empty console.
  inventory ? null,
  host ? "delphi",
  # `config.services.servicePortal.cards` — the compiled card projection. This
  # is the same list the host's own mount units are generated from, so a mount
  # cannot exist that the console does not list, and a card cannot point at a
  # port nothing serves. Required: an omitted or empty registry throws below,
  # because the one artifact that serves IS this host instantiation
  # (`system.build.delphiSite`), so a host-free preview would be a different
  # page wearing the same name.
  cards ? throw "lib/delphi-site.nix: `cards` is required — pass `config.services.servicePortal.cards`; the served site is the host instantiation, not a host-free build",
  publicDomain ? null,
  tailnetHost ? null,
  # The tailnet resolver address this host binds on `lo` (the host config's one
  # constant). Null means the page does not claim one.
  resolver ? null,
  # `config.system.nixos.release` from the host, so the dossier prints the
  # version the host actually runs instead of a number someone remembered.
  nixosVersion ? "",
}: let
  inv =
    if inventory != null
    then inventory
    else builtins.fromTOML (builtins.readFile ../inventory.toml);
  skills = import ./skills.nix {inherit lib;};
  kg = import ./knowledge-graph.nix {
    inherit lib skills;
    inventory = inv;
  };

  hosts = inv.hosts or {};
  meta = hosts.${host} or {};
  hw = meta.hardware or {};
  net = meta.network or {};
  sw = meta.software or {};
  persona = meta.persona or {};
  hostValues = lib.attrValues hosts;

  # --- the evaluated model ---------------------------------------------------
  tally = f:
    lib.foldl' (
      acc: h: let
        k = f h;
      in
        acc // {"${k}" = (acc.${k} or 0) + 1;}
    ) {}
    hostValues;

  byKind = tally (h: h.kind or "unknown");
  byArch = tally (h: h.arch or "unknown");
  countWhere = p: builtins.length (lib.filter p hostValues);

  devices = builtins.length hostValues;
  externalCount = countWhere (h: (h.kind or "") == "external");
  nixCount = devices - externalCount;
  activeCount = countWhere (h: (h.status or "") == "active");
  wipCount = countWhere (h: (h.status or "") == "wip");
  preservedCount = countWhere (h: (h.status or "") == "preserved");

  inherit (kg) graph;
  tagCount =
    builtins.length graph.nodes
    - graph.stats.hosts
    - graph.stats.skills
    - graph.stats.docs;

  # --- the surfaces ----------------------------------------------------------
  # A tag-net card is an address on the tailnet. Printing one on the public page
  # would be a map, so the public surface reports the COUNT and withholds the
  # addresses: `withheld` below is derived, not an editorial choice made twice.
  # An empty list is not a smaller site, it is a site that knows nothing: the
  # cards ARE the registry, so `[]` means the portal is disabled or the caller
  # invented its own empty list. Fail here rather than ship a page that explains
  # its own emptiness.
  cardRegistry =
    if cards == []
    then throw "lib/delphi-site.nix: `cards` is empty — enable `services.servicePortal` on the host so the site renders the registry that also generates the `tailscale serve` units"
    else cards;

  byAudience = a: lib.filter (c: c.audience == a) cardRegistry;
  tailnetCards =
    lib.sort (a: b: a.title < b.title)
    (lib.filter (c: c.audience == "tailnet") cardRegistry);
  publicCards = byAudience "public";
  lanCards = byAudience "lan";
  withheld = builtins.length tailnetCards;
  cardCount = builtins.length cardRegistry;

  keyServices = sw.key_services or [];
  traits = sw.traits or [];
  constraints = persona.constraints or [];
  allowedTasks = persona.allowed_tasks or [];
  notes = meta.notes or [];

  # The registry's own network facts. `domain` and `tailscale_ip` are compiled
  # fields, so the host config and this page cannot disagree about an address.
  tailnetIp = net.tailscale_ip or "";
  publicUrl =
    if publicDomain != null
    then "https://${publicDomain}"
    else "";
  tailnetUrl =
    if tailnetHost != null
    then "https://${tailnetHost}"
    else "";

  # Singular/plural, so no page prints "1 services".
  plural = n: one: many:
    if n == 1
    then one
    else many;
  inherit (builtins) toString;
  n = toString;

  esc = s: lib.escapeXML (toString s);

  # A field the registry does not carry is OMITTED, never filled with invented
  # prose: an empty string is the compiled schema's "unknown", so it is also the
  # row's absence.
  mkRow = label: value: let
    text =
      if builtins.isList value
      then lib.concatStringsSep ", " value
      else toString value;
  in
    lib.optionalString (text != "") ''
      <tr><th scope="row">${esc label}</th><td>${esc text}</td></tr>
    '';

  mkBullets = xs: lib.concatMapStringsSep "\n" (x: "<li>${esc x}</li>") xs;
  mkChips = xs: lib.concatMapStringsSep "\n" (x: ''<li class="chip">${esc x}</li>'') xs;

  hardwareRows =
    mkRow "Model" (hw.model or "")
    + mkRow "CPU" (hw.cpu or "")
    + mkRow "Memory" (hw.ram or "")
    + mkRow "GPU" (hw.gpu or "")
    + mkRow "Storage" (hw.storage_type or "")
    + mkRow "Layout" (hw.storage_layout or "");

  # `nixos 24 · darwin 1 · home 3 · external 6` rather than alphabetical: the
  # platform that owns most of the fleet belongs first. Anything the registry
  # invents later still prints, at the end, instead of being dropped.
  preferred = ["nixos" "darwin" "home" "external"];
  orderedRow = attrs: let
    present = builtins.attrNames attrs;
    known = lib.filter (k: builtins.elem k present) preferred;
    rest = lib.filter (k: !(builtins.elem k preferred)) present;
  in
    lib.concatMapStringsSep " · " (k: "${k} ${n attrs.${k}}") (known ++ rest);

  # The withheld note only exists when something is withheld: a host whose cards
  # are all public has nothing to explain.
  withheldNote = lib.optionalString (withheld > 0) ''
    <div class="panel">
      <h3>${n withheld} ${plural withheld "service" "services"}, addresses withheld</h3>
      <p>
        Their names and descriptions are compiled from the registry that renders
        this page; the ports are not. A URL is half of a credential, and this
        document is on the internet.
      </p>
    </div>
  '';

  # Where the card list came from, counted rather than described, because "the
  # services page" with no numbers was the failure mode this site replaced.
  serviceLine = "${n cardCount} compiled cards, ${n withheld} of them tailnet-only";

  # A card is a link with its address on the console, and a bare row on the
  # public surface — the same evaluated values, one difference that is the whole
  # point. `console` prints the port and the unit it waits on; `dossier` prints
  # neither, because an address on an internet-facing page is a map.
  card = mode: c: let
    console = mode == "console";
    tag =
      if console
      then "a"
      else "div";
    waits =
      lib.optionalString (c.requires != [])
      ''<span class="svc-waits">waits on ${esc (lib.concatStringsSep ", " c.requires)}</span>'';
    # A plain double-quoted string, not `''`: an indented string's shared leading
    # whitespace is stripped, which silently glued `data-title="…"href="…"`
    # together (measured in the built console).
    hrefAttr = lib.optionalString console " href=\"${esc c.href}\"";
  in ''
    <${tag} class="svc" data-title="${esc (lib.toLower c.title)}"${hrefAttr}>
      <span class="svc-title">${esc c.title}</span>
      <span class="svc-desc">${esc c.description}</span>
      ${lib.optionalString console ''<span class="svc-meta">${esc c.badge}${waits}</span>''}
    </${tag}>
  '';

  cardGrid = mode: cs:
    lib.concatMapStringsSep "\n" (g: ''
      <h3 class="svc-group">${esc g}</h3>
      <div class="svc-grid">
      ${lib.concatMapStringsSep "\n" (card mode) (lib.filter (c: c.group == g) cs)}
      </div>
    '') (lib.unique (map (c: c.group) cs));

  # A canonical link only when there is a name to be canonical about; an empty
  # href is worse than no tag at all.
  canonical = url: lib.optionalString (url != "") ''<link rel="canonical" href="${url}">'';

  # --- the compiled structure ------------------------------------------------
  # This is the artifact: both surfaces are projections of it, and
  # `data/delphi.json` ships it verbatim (a TUI, a probe or an agent reads that
  # instead of scraping the HTML).
  site = {
    schemaVersion = 1;
    generatedBy = "lib/delphi-site.nix";
    inherit host;
    identity = {
      role = meta.role or "";
      status = meta.status or "unknown";
      statusDetail = meta.status_detail or "";
      kind = meta.kind or "";
      arch = meta.arch or "";
      category = meta.category or "";
      inherit nixosVersion publicUrl tailnetUrl tailnetIp;
      resolver =
        if resolver != null
        then resolver
        else "";
    };
    machine = {
      inherit (hw) model cpu gpu ram storage_type storage_layout;
      personaTitle = persona.title or "";
      computeTier = persona.compute_tier or "";
    };
    registry = {
      inherit devices activeCount wipCount preservedCount externalCount nixCount byKind byArch;
    };
    graph = {
      inherit (graph.stats) hosts skills docs edges;
      nodes = builtins.length graph.nodes;
      tags = tagCount;
    };
    services = {
      total = cardCount;
      inherit withheld;
      public = builtins.length publicCards;
      lan = builtins.length lanCards;
      tailnet = builtins.length tailnetCards;
      declared = keyServices;
      cards = cardRegistry;
    };
    declared = {
      inherit traits constraints allowedTasks notes;
      moduleChain = sw.module_chain or "";
      impermanence = sw.impermanence or false;
    };
  };

  dataJson = builtins.toJSON site;

  # --- templates -------------------------------------------------------------
  render = file: values: let
    text = builtins.readFile file;
    names = builtins.attrNames values;
    out = lib.replaceStrings (map (x: "{{${x}}}") names) (map (x: toString values.${x}) names) text;
    unbound = lib.head (lib.splitString "}}" (lib.last (lib.splitString "{{" out)));
  in
    if lib.hasInfix "{{" out
    then throw "template ${toString file}: unbound placeholder {{${unbound}}}"
    else out;

  styleCss = builtins.readFile ./delphi/juno.css;
  scriptJs = builtins.readFile ./delphi/juno.js;
  cssHash = builtins.substring 0 8 (builtins.hashString "sha256" styleCss);
  jsHash = builtins.substring 0 8 (builtins.hashString "sha256" scriptJs);
  cssFileName = "juno.${cssHash}.css";
  jsFileName = "juno.${jsHash}.js";
  cssFile = pkgs.writeText cssFileName styleCss;
  jsFile = pkgs.writeText jsFileName scriptJs;

  # Both surfaces share the document scaffolding; only the surface-specific
  # values differ. `surface` is the body's own rendering, already substituted.
  shell = surfaceValues:
    render ./delphi/shell.html (surfaceValues
      // {
        cssFile = cssFileName;
        jsFile = jsFileName;
      });

  specs = rows: "<ul class=\"specs\">" + rows + "</ul>";
  spec = k: v:
    lib.optionalString (v != "") ''
      <li><span class="spec-k">${esc k}</span><span class="spec-v">${esc v}</span></li>
    '';

  statusClass =
    if (meta.status or "") == "active"
    then "ok"
    else if (meta.status or "") == "wip"
    then "wip"
    else "dormant";

  # ---- surface 1: the public dossier ----------------------------------------
  publicBody = render ./delphi/public.html {
    statusDetail = esc (meta.status_detail or "");
    personaTitle = esc (persona.title or "");
    computeTier = esc (persona.compute_tier or "");
    moduleChain = esc (sw.module_chain or "");
    devices = n devices;
    active = n activeCount;
    preserved = n preservedCount;
    wip = n wipCount;
    nixCount = n nixCount;
    archs = n (builtins.length (builtins.attrNames byArch));
    kindRow = orderedRow byKind;
    archRow = lib.concatMapStringsSep " · " (a: "${a} ${n byArch.${a}}") (builtins.attrNames byArch);
    graphNodes = n site.graph.nodes;
    graphEdges = n site.graph.edges;
    graphHosts = n site.graph.hosts;
    graphSkills = n site.graph.skills;
    graphDocs = n site.graph.docs;
    graphTags = n site.graph.tags;
    inherit hardwareRows;
    inherit withheldNote;
    inherit serviceLine;
    # The card rows, WITHOUT href or badge: what a service is, never where it
    # answers. The same rows on the console carry both.
    serviceList = cardGrid "dossier" tailnetCards;
    constraintList = mkBullets constraints;
    allowedTaskList = mkBullets allowedTasks;
    noteList = mkBullets notes;
    traitList = mkChips traits;
    impermanence =
      if sw.impermanence or false
      then "ephemeral root, declared persistence"
      else "mutable root";
  };

  publicSpecs =
    specs
    (spec "Host" (hw.model or "")
      + spec "Arch" (meta.arch or "")
      + spec "NixOS" nixosVersion
      + spec "Memory" (hw.ram or "")
      + spec "Tier" (persona.compute_tier or ""));

  publicDoc = shell {
    surface = "public";
    robots = "index, follow";
    title = esc "${host} — ${meta.role or "fleet host"}";
    description = esc (lib.substring 0 150 (meta.status_detail or (meta.role or "")));
    canonicalTag = canonical publicUrl;
    eyebrow = "Portfolio · Fleet Engineering";
    heading = host;
    deck =
      if nixCount > 0
      then "An always-free ARM64 outpost, provisioned by one Nix flake: the outside vantage point for a fleet of ${n devices} registered devices, ${n nixCount} of them Nix machines that build themselves."
      else "An always-free ARM64 outpost, provisioned by one Nix flake.";
    inherit statusClass;
    statusText = meta.status or "unknown";
    stamp = "registry · ${n devices} devices";
    specs = publicSpecs;
    body = publicBody;
    colophon = "Every figure on this page is evaluated from <code>inventory.toml</code>, the knowledge graph and this host's compiled service registry at build time. Nothing is typed.";
    provenance = "lib/delphi-site.nix · inventory.toml · lib/knowledge-graph.nix · services.servicePortal";
  };

  # ---- surface 2: the tailnet console --------------------------------------
  tailnetCardsOrThrow =
    if tailnetCards != [] && tailnetHost == null
    then throw "lib/delphi-site.nix: mounts exist but `tailnetHost` is null — their cards would have nowhere to point"
    else tailnetCards;

  tailnetBody = render ./delphi/tailnet.html {
    tailnetIp =
      if tailnetIp != ""
      then n tailnetIp
      else "—";
    resolver =
      if resolver != null
      then n resolver
      else "—";
    mountCount = n withheld;
    mountWord = plural withheld "service" "services";
    serviceList = cardGrid "console" tailnetCardsOrThrow;
    publicUrl =
      if publicUrl != ""
      then esc publicUrl
      else "the public dossier";
  };
  tailnetSpecs =
    specs
    (spec "Tailnet" (
        if tailnetIp != ""
        then tailnetIp
        else ""
      )
      + spec "Resolver" (
        if resolver != null
        then resolver
        else ""
      )
      + spec "Services" (n withheld)
      + spec "Public" (
        if publicDomain != null
        then publicDomain
        else ""
      ));

  tailnetDoc = shell {
    surface = "tailnet";
    robots = "noindex, nofollow";
    title = esc "${host} — tailnet services";
    description = "Tailnet-only service console for ${host}.";
    canonicalTag = canonical tailnetUrl;
    eyebrow = "Tailnet · Service Console";
    heading = host;
    deck = "Each service gets its own port inside the mesh, reachable by name or address. Nothing on this page answers from the internet — that is the whole design, not a setting.";
    inherit statusClass;
    statusText = meta.status or "unknown";
    stamp = "${n withheld} ${plural withheld "service" "services"}";
    specs = tailnetSpecs;
    body = tailnetBody;
    colophon = "The cards are the compiled <code>services.servicePortal</code> registry &mdash; the same declaration generates the <code>tailscale serve</code> units.";
    provenance = "lib/delphi-site.nix · services.servicePortal.cards · inventory.toml";
  };
in
  pkgs.runCommand "delphi-site" {
    meta.description = "delphi's compiled dossier (public) and service console (tailnet)";
  } ''
    mkdir -p $out/public $out/tailnet $out/data

    cat > $out/public/index.html <<'PUBLIC'
    ${publicDoc}
    PUBLIC

    cat > $out/tailnet/index.html <<'TAILNET'
    ${tailnetDoc}
    TAILNET

    cp ${cssFile} $out/public/${cssFileName}
    cp ${cssFile} $out/tailnet/${cssFileName}
    cp ${jsFile} $out/public/${jsFileName}
    cp ${jsFile} $out/tailnet/${jsFileName}
    cp $out/public/${cssFileName} $out/public/juno.css
    cp $out/tailnet/${cssFileName} $out/tailnet/juno.css

    cp ${pkgs.writeText "delphi.json" dataJson} $out/data/delphi.json

    # Pre-compressed for nginx `gzip_static` (modules/config/nginx-static-cache.nix):
    # the bytes are a store path, so this is paid once at build, never per request.
    gzip -9k $out/public/index.html $out/public/*.css $out/public/*.js
    gzip -9k $out/tailnet/index.html $out/tailnet/*.css $out/tailnet/*.js
    gzip -9k $out/data/delphi.json
  ''
