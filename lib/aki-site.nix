# ==============================================================================
# lib/aki-site.nix — the fleet site, as a project of evaluated data
# ==============================================================================
# An ultra-minimal hypermedia site (~270 B aki JS primitive) generated natively
# by Nix at build time: index.html, aki.min.js, style.css, and static JSON slices
# for zero-daemon exploration of hosts, notes, closures, and the knowledge graph.
#
# WHAT IS CODE AND WHAT IS NIX: browser JS, CSS, the page shell and the page
# bodies live in lib/site/ — `aki.js`, `kg.js`, `style.css`, `sidebar.html`,
# `shell.html`, `overview.html`. They are read at eval time, so they are
# lintable/parseable as what they are (`checks.site-assets` runs `node --check`
# on the JS) and a typo in them is not a Nix parse error. The HTML files carry
# `{{name}}` holes filled by `render` below; what stays in this file is data +
# interpolation: every figure is a `${...}` over an evaluated source, never a
# typed literal.
#
# HARD RULE — no typed facts. Every figure, path, service, size and status this
# site prints is an INTERPOLATION of an evaluated value:
#
#   inventory.toml          (compiled by lib/inventory.nix)  hosts, counts, roles
#   closure-budgets.toml    (measured by the adopt task)     closure baselines
#   .agents/skills/**       (compiled by lib/skills.nix)     skill notes
#   living docs + docs/*.md (compiled by lib/knowledge-graph.nix)
#   the note files themselves (rendered into their own slices)
#
# The 2026-10-19 revision still claimed "Generation 82", "33.8 GiB", "3,946
# store paths" and a port table months after each value had changed: literals
# outlive the config they describe. So the rule is structural — if a value has
# no source of truth, it is not rendered at all, and anything that does have one
# is written as ${toString ...} over that source.
# ==============================================================================
{
  pkgs,
  lib ? pkgs.lib,
  # Compiled registry from lib/inventory.nix (flake output `inventory`). The
  # flake AND every host pass it, so this site cannot disagree with the hosts
  # about a host's kind/status/role; the TOML fallback exists only for a
  # standalone `nix-build lib/aki-site.nix` and is NOT defaults-normalised.
  inventory ? null,
  # Host that serves the site, for the status badge. `null` makes no claim.
  host ? null,
}: let
  root = ../.;
  inventoryFile = ../inventory.toml;
  rawInventory =
    if builtins.pathExists inventoryFile
    then builtins.fromTOML (builtins.readFile inventoryFile)
    else {hosts = {};};
  inv =
    if inventory != null
    then inventory
    else rawInventory;

  skills = import ./skills.nix {inherit lib;};
  kg = import ./knowledge-graph.nix {
    inherit lib skills;
    inventory = inv;
  };

  # --- the evaluated model ---------------------------------------------------
  hosts = inv.hosts or {};
  hostNames = builtins.attrNames hosts;
  hostValues = lib.attrValues hosts;

  # Counts are filtered out of the registry here, not read from a `derived`
  # block and not typed: the registry's own derived block is computed upstream
  # by lib/inventory.nix, but recomputing keeps the site correct even in the
  # standalone TOML fallback.
  totalHosts = builtins.length hostNames;
  countWhere = p: builtins.length (lib.filter p hostValues);
  externalCount = countWhere (h: (h.kind or "") == "external");
  nixHostCount = totalHosts - externalCount;
  activeNix = countWhere (h: (h.status or "") == "active" && (h.kind or "") != "external");
  activeExternal = countWhere (h: (h.status or "") == "active" && (h.kind or "") == "external");
  activeTotal = activeNix + activeExternal;
  wipCount = countWhere (h: (h.status or "") == "wip");
  preservedCount = countWhere (h: (h.status or "") == "preserved");

  byStatus =
    lib.foldl'
    (acc: h:
      acc
      // {
        "${h.status or "unknown"}" = (acc.${h.status or "unknown"} or 0) + 1;
      })
    {}
    (lib.attrValues hosts);

  byKind =
    lib.foldl'
    (acc: h:
      acc
      // {
        "${h.kind or "unknown"}" = (acc.${h.kind or "unknown"} or 0) + 1;
      })
    {}
    (lib.attrValues hosts);

  archCount =
    lib.foldl'
    (acc: h: let
      a = h.arch or "unknown";
    in
      acc // {"${a}" = (acc.${a} or 0) + 1;})
    {}
    (lib.attrValues hosts);

  # Services are the ones the registry declares per host; nothing is invented.
  serviceNames = lib.unique (lib.concatMap (h: h.software.key_services or []) (lib.attrValues hosts));
  serviceCount = builtins.length serviceNames;

  # --- closure budgets: measured, never typed --------------------------------
  # `[hosts.<h>.baseline] bytes/measured_on` is rewritten by
  # `task dev:closure:budget:adopt`; `headroom_pct` and an optional absolute
  # `bytes` pin are policy. The site shows baseline and the derived budget.
  budgets = builtins.fromTOML (builtins.readFile ../closure-budgets.toml);
  budgetHosts = budgets.hosts or {};
  # `or` only rescues a missing attribute, not a missing parent, so each level is
  # defaulted on its own — a file with no [defaults] must still render.
  defaultHeadroom = (budgets.defaults or {}).headroom_pct or 0;

  budgetRow = name: let
    b = budgetHosts.${name};
    baseline = (b.baseline or {}).bytes or null;
    headroom = b.headroom_pct or defaultHeadroom;
    pinned = b.bytes or null;
    bytes =
      if pinned != null
      then pinned
      else if baseline != null
      then baseline * (1.0 + headroom / 100.0)
      else null;
  in {
    inherit name baseline headroom pinned bytes;
    measuredOn = (b.baseline or {}).measured_on or "—";
  };

  budgetRows = lib.filter (r: r.bytes != null) (map budgetRow (builtins.attrNames budgetHosts));
  budgetNames = map (r: r.name) budgetRows;

  # Coverage is judged against the hosts that HAVE a closure to measure. An
  # external device (Windows, FreeBSD, Android, a NAS) has no Nix store, so
  # listing it as "without a baseline" forever would be noise that hides the
  # real gap: an active Nix host nobody adopted.
  namesWhere = p: builtins.attrNames (lib.filterAttrs (_: p) hosts);
  externalNames = namesWhere (h: (h.kind or "") == "external");
  activeNixNames = namesWhere (h: (h.status or "") == "active" && (h.kind or "") != "external");
  preservedNixNames =
    namesWhere (h: (h.status or "") != "active" && (h.kind or "") != "external");
  isCovered = n: builtins.elem n budgetNames;
  coveredActive = lib.filter isCovered activeNixNames;
  uncoveredActive = lib.filter (n: !(isCovered n)) activeNixNames;
  uncoveredPreserved = lib.filter (n: !(isCovered n)) preservedNixNames;

  maxBudget =
    lib.foldl' (a: r:
      if r.bytes > a
      then r.bytes
      else a)
    0
    budgetRows;
  totalBudget = lib.foldl' (a: r: a + r.bytes) 0 budgetRows;

  # One decimal formatter for every figure the site prints. Nix has no printf,
  # and `toString` on a float keeps six decimals ("30.100000 GiB"), so the integer
  # and its tenth are split arithmetically instead of formatted.
  fmtTenths = v: let
    tenths = builtins.floor (v * 10.0 + 0.5);
    whole = tenths / 10;
    frac = tenths - whole * 10;
  in "${toString whole}.${toString frac}";

  fmtGiB = bytes: "${fmtTenths (bytes / 1073741824.0)} GiB";
  fmtPct = v: "${fmtTenths v}%";

  graphStats = kg.graph.stats;
  nodeCount = builtins.length kg.graph.nodes;
  edgeCount = builtins.length kg.graph.edges;

  # The host that serves this site, resolved from the registry rather than
  # named in the markup.
  hostStatus =
    if host != null && hosts ? ${host}
    then hosts.${host}.status or "unknown"
    else "";
  hostBadge =
    if hostStatus != ""
    then "${host}: ${hostStatus}"
    else "registry: ${toString totalHosts} devices";
  badgeClass =
    if hostStatus == "active"
    then "badge-green"
    else "badge-blue";

  # Aki hypermedia driver with delegated click listener for dynamic DOM mutations.
  # Assets are FILES (lib/site/), not literals: Nix cannot lint, format or
  # syntax-check CSS/JS, and a missing quote inside `''` is a Nix parse error at
  # eval time. What stays in this file is data + interpolation only.
  akiJs = builtins.readFile ./site/aki.js;

  # Interactive knowledge-graph canvas (Gap D, canvas half).
  #
  # Aki transitions replace #detail-pane.innerHTML, so this file owns its own
  # lifecycle: it initialises whenever a slice introduces #kg-canvas and leaves
  # everything else to the runtime. It is a plain .js file (lib/site/kg.js) so it
  # can be syntax-checked and reviewed as JavaScript; nothing in it is typed by
  # Nix — every fact it displays comes from data/kg-graph.json at runtime.
  #
  # Interaction contract, matching the TODO exit criterion: a click on ANY node
  # performs an Aki transition to that node's static slice (data/kg/<type>-<hash>.json).
  # Hover inspects without navigating; pan/zoom never navigate.
  kgJs = builtins.readFile ./site/kg.js;

  styleCss = builtins.readFile ./site/style.css;

  # Asset fingerprinting hashes for immutable caching (Gap B)
  cssHash = builtins.substring 0 8 (builtins.hashString "sha256" styleCss);
  jsHash = builtins.substring 0 8 (builtins.hashString "sha256" akiJs);
  kgHash = builtins.substring 0 8 (builtins.hashString "sha256" kgJs);
  cssFileName = "style.${cssHash}.css";
  jsFileName = "aki.${jsHash}.min.js";
  kgFileName = "kg.${kgHash}.min.js";

  # The asset bytes as store paths. `readFile` above is for the hash and for the
  # page that interpolates them, but the build copies these, so the JS/CSS never
  # travel through a build-script heredoc.
  cssFile = pkgs.writeText cssFileName styleCss;
  jsFile = pkgs.writeText jsFileName akiJs;
  kgFile = pkgs.writeText kgFileName kgJs;

  # One navigation list, rendered by the shell and restored by every transition
  # that replaced the sidebar (a slice only swaps the selectors it names).
  # Static navigation buttons; every URL is a slice this build writes.
  sidebarButtons = builtins.readFile ./site/sidebar.html;

  # The overview body is a single expression because it is rendered twice: as
  # the no-JS initial document and as the `data/overview.json` transition. Two
  # copies is how the old page drifted from the data it claimed to describe.
  # Templates are real .html files (lib/site/{shell,overview}.html) with
  # `{{name}}` holes: a page is reviewable as HTML, and editing copy is not an
  # edit to a Nix module that also imports the knowledge graph. `render`
  # substitutes every hole in ONE pass — replaceStrings never rescans a
  # replacement, so a value that happens to contain `{{` cannot cascade — and it
  # refuses to return a page that still has a hole. A renamed value would
  # otherwise ship as literal braces on the page instead of failing the build.
  render = file: values: let
    text = builtins.readFile file;
    names = builtins.attrNames values;
    out = lib.replaceStrings (map (n: "{{${n}}}") names) (map (n: toString values.${n}) names) text;
    unbound = lib.head (lib.splitString "}}" (lib.last (lib.splitString "{{" out)));
  in
    if lib.hasInfix "{{" out
    then throw "template ${toString file}: unbound placeholder {{${unbound}}}"
    else out;

  # Values for the two templates. Deliberately NOT named after the bindings they
  # read (`devices`, not `totalHosts`): an attribute named `totalHosts` here
  # would shadow the compiled value and recurse forever. `t` is shared with the
  # shell, which adds only the document-scaffolding holes.
  t = {
    devices = toString totalHosts;
    active = toString activeTotal;
    preserved = toString preservedCount;
    wip = toString wipCount;
    nixHosts = toString nixHostCount;
    external = toString externalCount;
    nodes = toString nodeCount;
    edges = toString edgeCount;
    graphHosts = toString graphStats.hosts;
    graphSkills = toString graphStats.skills;
    graphDocs = toString graphStats.docs;
    notes = toString (builtins.length noteEntries);
    budgets = toString (builtins.length budgetRows);
    budgetWord =
      if builtins.length budgetRows == 1
      then "baseline"
      else "baselines";
    budgetTotal = fmtGiB totalBudget;
    budgetMax = fmtGiB maxBudget;
    services = toString serviceCount;
    uncovered = toString (builtins.length uncoveredActive);
    activeNixHosts = toString (builtins.length activeNixNames);
    kindRow = lib.concatMapStringsSep ", " (k: "${k} (${toString byKind.${k}})") (lib.attrNames byKind);
    statusRow = lib.concatMapStringsSep ", " (s: "${s} (${toString byStatus.${s}})") (lib.attrNames byStatus);
    archRow = lib.concatMapStringsSep ", " (a: "${a} (${toString archCount.${a}})") (lib.attrNames archCount);
  };

  overviewBody = render ./site/overview.html t;

  # Top-level shell
  # The shell: document scaffolding plus the two composited fragments. Every
  # other hole is a scalar the body already exported.
  indexHtml = render ./site/shell.html (t
    // {
      cssFile = cssFileName;
      akiJsFile = jsFileName;
      kgJsFile = kgFileName;
      statusClass = badgeClass;
      statusText = hostBadge;
      sidebar = sidebarButtons;
      overview = overviewBody;
    });

  # JSON Slices
  overviewJson = builtins.toJSON {
    "#breadcrumbs" = {textContent = "fleet / overview";};
    "#detail-pane" = {innerHTML = overviewBody;};
    "#sidebar-pane" = {innerHTML = sidebarButtons;};
  };

  # Host list for sidebar
  hostKeys = hostNames;

  # Every registered host, ordered as the registry orders them. The old list was
  # `status == active` only, which silently hid preserved and WIP machines that
  # the registry still describes.
  hostSidebarButtons = lib.concatStringsSep "\n" (
    map (
      h: ''<button class="side-btn" url="data/host-${h}.json">${h} (${hosts.${h}.kind or "unknown"})</button>''
    )
    hostKeys
  );

  inventoryJson = builtins.toJSON {
    "#breadcrumbs" = {textContent = "fleet / inventory";};
    "#sidebar-pane" = {innerHTML = hostSidebarButtons;};
    "#detail-pane" = {
      innerHTML = ''
        <h2>Fleet Device & Host Inventory</h2>
        <p style="margin: 0.75rem 0; color: var(--text-muted);">
          ${toString totalHosts} registered devices: ${toString activeTotal} active,
          ${toString wipCount} WIP, ${toString preservedCount} preserved &middot;
          ${toString nixHostCount} Nix, ${toString externalCount} external.
        </p>
        <table>
          <thead>
            <tr>
              <th>Host</th>
              <th>Status</th>
              <th>Kind</th>
              <th>Arch</th>
              <th>Role</th>
            </tr>
          </thead>
          <tbody>
            ${lib.concatStringsSep "\n" (
          map (h: let
            info = hosts.${h};
          in ''
            <tr>
              <td><strong><button class="side-btn" style="padding:0; border:none; color:var(--heading); cursor:pointer;" url="data/host-${h}.json">${h}</button></strong></td>
              <td><span class="badge ${
              if info.status == "active"
              then "badge-green"
              else "badge-yellow"
            }">${info.status}</span></td>
              <td>${info.kind or "unknown"}</td>
              <td><code>${info.arch or "unknown"}</code></td>
              <td>${info.role or "—"}</td>
            </tr>
          '')
          hostKeys
        )}
          </tbody>
        </table>
      '';
    };
  };

  # Individual host pages
  # A field the registry does not carry is OMITTED, not filled with a invented
  # default ("Generic", "DHCP", "Integrated" were all typed prose). Empty string
  # is the compiled schema's "unknown", so it is also the row's absence.
  mkHostRow = label: value:
    lib.optionalString (value != "") ''<tr><th>${label}</th><td>${value}</td></tr>'';

  mkHostJson = h: let
    info = hosts.${h};
    hw = info.hardware or {};
    net = info.network or {};
    sw = info.software or {};
    persona = info.persona or {};
    budget = lib.findFirst (r: r.name == h) null budgetRows;
    graphNode = lib.findFirst (n: n.id == "host:${h}") null kg.graph.nodes;

    hardRows =
      mkHostRow "Model" (escH (hw.model or ""))
      + mkHostRow "CPU" (escH (hw.cpu or ""))
      + mkHostRow "GPU" (escH (hw.gpu or ""))
      + mkHostRow "RAM" (escH (hw.ram or ""))
      + mkHostRow "Storage" (escH (hw.storage_type or ""))
      + mkHostRow "Layout" (escH (hw.storage_layout or ""))
      + mkHostRow "Display" (escH (hw.display or ""))
      + mkHostRow "Battery" (escH (hw.battery or ""));

    netRows =
      mkHostRow "LAN IP" (escH (net.lan_ip or ""))
      + mkHostRow "Tailscale" (escH (net.tailscale_ip or ""))
      + mkHostRow "Domain" (escH (net.domain or ""))
      + mkHostRow "SSH alias" (escH (net.ssh_alias or ""))
      + mkHostRow "Tailscale" (
        if net.tailscale or false
        then "enabled"
        else ""
      )
      + mkHostRow "Gemini" (escH (net.gemini_url or ""))
      + mkHostRow "Gopher" (escH (net.gopher_url or ""));

    swRows =
      mkHostRow "Boot" (escH (sw.module_chain or ""))
      + mkHostRow "Impermanence" (
        if sw.impermanence or false
        then "enabled"
        else ""
      )
      + mkHostRow "Services" (escH (lib.concatStringsSep ", " (sw.key_services or [])))
      + mkHostRow "Traits" (escH (lib.concatStringsSep ", " (sw.traits or [])))
      + mkHostRow "Compute tier" (escH (persona.compute_tier or ""))
      + mkHostRow "Constraints" (escH (lib.concatStringsSep "; " (persona.constraints or [])));

    budgetBlock = lib.optionalString (budget != null) ''
      <h3 style="margin-top: 1.25rem; margin-bottom: 0.5rem; color: var(--heading);">Closure Budget</h3>
      <table>
        <tbody>
          <tr><th>Baseline</th><td>${
        if budget.baseline == null
        then "not recorded"
        else "${fmtGiB budget.baseline} (${toString budget.baseline} B)"
      }</td></tr>
          <tr><th>Headroom</th><td>${fmtPct budget.headroom}</td></tr>
          <tr><th>Budget</th><td><strong>${fmtGiB budget.bytes}</strong></td></tr>
          <tr><th>Measured</th><td>${escH budget.measuredOn}</td></tr>
        </tbody>
      </table>
    '';

    statusBadge =
      if (info.status or "") == "active"
      then "badge-green"
      else if (info.status or "") == "wip"
      then "badge-blue"
      else "badge-yellow";
  in
    builtins.toJSON {
      "#breadcrumbs" = {textContent = "fleet / inventory / ${h}";};
      "#detail-pane" = {
        innerHTML = ''
          <h2>${h} — ${escH (info.role or "registered device")}</h2>
          <p style="margin: 0.5rem 0 1rem 0;"><span class="badge ${statusBadge}">${info.status or "unknown"}</span> &bull; <code>${info.kind or "unknown"}</code> &bull; <code>${info.arch or "unknown"}</code>${
            lib.optionalString (info.flake or false) " &bull; built by this flake"
          }</p>

          <div class="card-grid">
            <div class="card">
              <h4>Hardware</h4>
              ${
            if hardRows == ""
            then "<p><small>not recorded</small></p>"
            else "<table><tbody>" + hardRows + "</tbody></table>"
          }
            </div>
            <div class="card">
              <h4>Network &amp; software</h4>
              ${
            if netRows + swRows == ""
            then "<p><small>not recorded</small></p>"
            else "<table><tbody>" + netRows + swRows + "</tbody></table>"
          }
            </div>
          </div>

          ${
            lib.optionalString ((info.status_detail or "") != "")
            ''<h3 style="margin-top: 1.25rem; margin-bottom: 0.5rem; color: var(--heading);">Status detail</h3><p>${escH info.status_detail}</p>''
          }

          ${
            lib.optionalString ((info.notes or []) != [])
            ''<h3 style="margin-top: 1.25rem; margin-bottom: 0.5rem; color: var(--heading);">Operator notes</h3><ul>${lib.concatMapStringsSep "" (n: "<li>${escH n}</li>") info.notes}</ul>''
          }

          ${budgetBlock}

          <p style="margin-top: 1.5rem; display: flex; gap: 0.5rem; flex-wrap: wrap;">
            ${lib.optionalString (graphNode != null) ''<button class="tab-btn" url="${sliceForId "host:${h}"}">Knowledge-graph slice</button>''}
            <button class="tab-btn" url="data/closures.json">All budgets</button>
            <button class="tab-btn" url="data/inventory.json">&larr; Inventory</button>
          </p>
        '';
      };
    };

  # Closure budgets — the only closure figures this site may print.
  #
  # The attribution rollup and the debloat playbook that used to live here were
  # hand-written byte splits ("15.4 GiB exclusive (46%)", "~703 MiB") about one
  # generation of one host. They could not be reproduced from the repository and
  # were wrong within a week. `closure-budgets.toml` is the closure document that
  # a MEASUREMENT rewrites (`task dev:closure:budget:adopt`), so it is the one
  # rendered: baseline, headroom, derived budget, and the date taken.
  closureRows = lib.sort (a: b: a.bytes > b.bytes) budgetRows;

  closuresJson = builtins.toJSON {
    "#breadcrumbs" = {textContent = "fleet / closure-budgets";};
    "#sidebar-pane" = {innerHTML = sidebarButtons;};
    "#detail-pane" = {
      innerHTML = ''
        <h2>Closure Budgets</h2>
        <p style="margin: 0.75rem 0; color: var(--text-muted);">
          Baseline bytes are measured on the host and written into
          <code>closure-budgets.toml</code> by
          <code>task dev:closure:budget:adopt</code> (add <code>REMOTE=1</code>
          for a host that is not this machine). The budget is
          <code>baseline &times; (1 + headroom)</code>, computed here — never
          entered. A host with no row has never been measured, and the site says
          so instead of guessing.
        </p>

        <div class="card-grid">
          <div class="card">
            <h4>Active Nix hosts measured</h4>
            <p><strong>${toString (builtins.length coveredActive)} of ${toString (builtins.length activeNixNames)}</strong></p>
            <p><small style="color: var(--text-muted);">${toString (builtins.length uncoveredActive)} active host(s) not adopted yet</small></p>
            <p><small style="color: var(--text-muted);">${toString (builtins.length uncoveredPreserved)} dormant Nix host(s) unmeasured &middot; ${toString (builtins.length externalNames)} external devices have no Nix closure</small></p>
          </div>
          <div class="card">
            <h4>Total allowed</h4>
            <p><strong>${fmtGiB totalBudget}</strong></p>
            <p><small style="color: var(--text-muted);">sum of every derived budget</small></p>
          </div>
          <div class="card">
            <h4>Largest budget</h4>
            <p><strong>${fmtGiB maxBudget}</strong></p>
            <p><small style="color: var(--text-muted);">${
          if closureRows == []
          then "no measured host"
          else (builtins.head closureRows).name
        }</small></p>
          </div>
        </div>

        ${
          if closureRows == []
          then ''
            <p style="margin-top: 1.5rem;">No host has a measured baseline yet.</p>
          ''
          else ''
            <table style="margin-top: 1.5rem;">
              <thead>
                <tr><th>Host</th><th>Baseline</th><th>Headroom</th><th>Budget</th><th>Measured</th></tr>
              </thead>
              <tbody>
                ${lib.concatMapStringsSep "\n" (r: ''
                <tr>
                  <td><button class="side-btn" style="padding:0;border:none;color:var(--heading);cursor:pointer;" url="data/host-${r.name}.json">${r.name}</button></td>
                  <td>${
                  if r.baseline == null
                  then "—"
                  else fmtGiB r.baseline
                }</td>
                  <td>${fmtPct r.headroom}${lib.optionalString (r.pinned != null) " (pinned)"}</td>
                  <td><strong>${fmtGiB r.bytes}</strong></td>
                  <td>${escH r.measuredOn}</td>
                </tr>
              '')
              closureRows}
              </tbody>
            </table>
          ''
        }        ${
          if uncoveredActive == []
          then ''
            <p style="margin-top: 1.5rem; color: var(--green);">Every active Nix host has a measured baseline.</p>
          ''
          else ''
            <h3 style="margin-top: 1.5rem; margin-bottom: 0.5rem; color: var(--heading);">Active Nix hosts without a baseline</h3>
            <p>${lib.concatStringsSep ", " (map (n: ''<code>${n}</code>'') uncoveredActive)}</p>
            <p><small style="color: var(--text-muted);">Adopt them in one deliberate run from a machine that can reach the host's store:</small></p>
            <pre>task dev:closure:budget:adopt:hosts HOSTS="${lib.concatStringsSep " " uncoveredActive}"</pre>
          ''
        }

        ${
          if uncoveredPreserved == []
          then ""
          else ''
            <h3 style="margin-top: 1.5rem; margin-bottom: 0.5rem; color: var(--heading);">Dormant Nix hosts without a baseline</h3>
            <p>${lib.concatStringsSep ", " (map (n: ''<code>${n}</code>'') uncoveredPreserved)}</p>
          ''
        }
      '';
    };
  };

  # Notes index — every doc and skill the graph knows, by how often it is cited.
  # Opening a row is an ordinary transition to that note's slice, which carries
  # the rendered note itself (see noteEntries / the build step below).
  noteIndex = lib.sort (
    a: b: a.degree > b.degree || (a.degree == b.degree && a.label < b.label)
  ) (map (n: n // {degree = degree.${n.id} or 0;}) noteNodes);

  uncitedNotes = lib.filter (n: n.degree == 0) noteIndex;

  notesJson = builtins.toJSON {
    "#breadcrumbs" = {textContent = "fleet / notes";};
    "#sidebar-pane" = {innerHTML = sidebarButtons;};
    "#detail-pane" = {
      innerHTML = ''
        <h2>Notes &amp; Skills</h2>
        <p style="margin: 0.75rem 0; color: var(--text-muted);">
          ${toString (builtins.length noteIndex)} notes compiled by
          <code>lib/knowledge-graph.nix</code> from living documents and
          <code>.agents/skills/*/SKILL.md</code>, plus the narrative notes in
          <code>AGENTS.nix</code> (decisions, queue, design studies). Each opens
          as a static slice that contains the note's own text — the site renders
          it at build time, so there is no repository link to rot and no second
          copy to drift.
        </p>
        <p style="margin-bottom: 0.75rem;">
          <button class="tab-btn" url="data/agents-notes.json">Agent notes (AGENTS.nix)</button>
        </p>

        <div class="card-grid">
          <div class="card">
            <h4>Documents</h4>
            <p><strong>${toString (builtins.length docNodes)}</strong></p>
          </div>
          <div class="card">
            <h4>Skills</h4>
            <p><strong>${toString (builtins.length skillNodes)}</strong></p>
          </div>
          <div class="card">
            <h4>Uncited</h4>
            <p><strong>${toString (builtins.length uncitedNotes)}</strong></p>
            <p><small style="color: var(--text-muted);">mentioned by no other node</small></p>
          </div>
        </div>

        <table style="margin-top: 1.5rem;">
          <thead>
            <tr><th>Note</th><th>Type</th><th>Path</th><th>Mentions</th></tr>
          </thead>
          <tbody>
            ${lib.concatMapStringsSep "\n" (n: ''
            <tr>
              <td><button class="side-btn" style="padding:0;border:none;color:var(--heading);cursor:pointer;text-align:left;" url="${sliceRel n}">${escH n.label}</button></td>
              <td>${escH n.type}</td>
              <td><code>${escH (n.path or "")}</code></td>
              <td>${toString n.degree}</td>
            </tr>
          '')
          noteIndex}
          </tbody>
        </table>
      '';
    };
  };

  # AGENTS.nix notes index + one static slice per note. These are not graph
  # nodes: the note is the unit, so the page lists it directly and the slice
  # carries its own rendered text (filled by injectNotes at build time).
  agentsNotesJson = builtins.toJSON {
    "#breadcrumbs" = {textContent = "fleet / notes / agents";};
    "#sidebar-pane" = {innerHTML = sidebarButtons;};
    "#detail-pane" = {
      innerHTML = ''
        <h2>Agent notes — <code>AGENTS.nix</code></h2>
        <p style="margin: 0.75rem 0; color: var(--text-muted);">
          ${toString agentsNotes.counts.total} notes
          (${toString agentsNotes.counts.open} open, ${toString agentsNotes.counts.leaves} leaves)
          compiled by <code>lib/agents-notes.nix</code>. A note with refs is
          distilled onto the code it affects; a leaf keeps the original intent in
          prose. Query them with <code>task ops:notes</code> or one of the
          <code>ops:notes:*</code> tasks; this page is the rendered view.
        </p>
        <table style="margin-top: 1.5rem;">
          <thead>
            <tr><th>Note</th><th>Status</th><th>Kind</th><th>Refs</th></tr>
          </thead>
          <tbody>
            ${lib.concatMapStringsSep "\n" (e: ''
            <tr>
              <td><button class="side-btn" style="padding:0;border:none;color:var(--heading);cursor:pointer;text-align:left;" url="data/agents-notes/${e.id}.json">${escH e.title}</button></td>
              <td>${escH e.status}</td>
              <td>${escH e.kind}</td>
              <td>${toString (builtins.length (e.refs.hosts ++ e.refs.modules ++ e.refs.tasks ++ e.refs.docs))}</td>
            </tr>
          '')
          (lib.sort (a: b: a.id < b.id) (lib.attrValues agentsNotes.notes))}
          </tbody>
        </table>
      '';
    };
  };

  agentNoteSlices =
    lib.mapAttrsToList (id: e: let
      metaRows =
        [["status" e.status] ["kind" e.kind]]
        ++ lib.optional (e.priority != null) ["priority" e.priority]
        ++ lib.optional (e.date != null) ["updated" e.date]
        ++ lib.optional (e.leaf) ["trace" "leaf (no code refs; verbose intent)"];
      refRows =
        lib.optional (e.refs.hosts != []) ["hosts" (lib.concatStringsSep ", " e.refs.hosts)]
        ++ lib.optional (e.refs.modules != []) ["modules" (lib.concatStringsSep ", " e.refs.modules)]
        ++ lib.optional (e.refs.tasks != []) ["tasks" (lib.concatStringsSep ", " e.refs.tasks)]
        ++ lib.optional (e.refs.docs != []) ["docs" (lib.concatStringsSep ", " e.refs.docs)]
        ++ lib.optional (e.links != []) ["related" (lib.concatStringsSep ", " e.links)];
      row = r: ''<tr><th>${escH (builtins.head r)}</th><td><code>${escH (builtins.elemAt r 1)}</code></td></tr>'';
    in {
      name = "data/agents-notes/${id}.json";
      file = pkgs.writeText "agent-note-${nodeSlug id}.json" (builtins.toJSON {
        "#breadcrumbs" = {textContent = "fleet / notes / ${id}";};
        "#sidebar-pane" = {innerHTML = sidebarButtons;};
        "#detail-pane" = {
          innerHTML = ''
            <h2>${escH e.title}</h2>
            <p style="margin: 0.75rem 0; color: var(--text-muted);">${escH e.summary}</p>
            <table><tbody>
              ${lib.concatMapStringsSep "\n" row (metaRows ++ refRows)}
            </tbody></table>
            <div class="note"><!--KG_NOTE--></div>
            <p style="margin-top: 1.5rem;">
              <button class="tab-btn" url="data/agents-notes.json">&larr; All agent notes</button>
              <button class="tab-btn" url="data/notes.json">Docs &amp; skills</button>
            </p>
          '';
        };
      });
    })
    agentsNotes.notes;

  # Knowledge Graph slice (Gap D)
  kgJson = builtins.toJSON {
    "#breadcrumbs" = {textContent = "fleet / knowledge-graph";};
    "#sidebar-pane" = {
      innerHTML = ''
        <button class="side-btn nav-active" url="data/kg.json">Graph Overview</button>
        <button class="side-btn" url="data/inventory.json">Host Matrix</button>
        <button class="side-btn" url="data/notes.json">Notes</button>
        <button class="side-btn" url="data/closures.json">Closure Budgets</button>
      '';
    };
    "#detail-pane" = {
      innerHTML = ''
        <h2>Fleet Knowledge Graph & Architectural Projection</h2>
        <p style="margin: 0.75rem 0; color: var(--text-muted);">
          Deterministic structural view compiled directly from repository AST: hosts, skill manuals, and living docs.
        </p>

        <div class="card-grid">
          <div class="card">
            <h4>Entities (Nodes)</h4>
            <p><strong>${toString (builtins.length kg.graph.nodes)}</strong> total nodes</p>
            <p><small style="color: var(--text-muted);">${toString kg.graph.stats.hosts} hosts &bull; ${toString kg.graph.stats.skills} skills &bull; ${toString kg.graph.stats.docs} docs</small></p>
          </div>
          <div class="card">
            <h4>Mentions (Edges)</h4>
            <p><strong>${toString kg.graph.stats.edges}</strong> explicit connections</p>
            <p><small style="color: var(--green);">Zero embeddings &bull; Token-exact AST</small></p>
          </div>
          <div class="card">
            <h4>Query Interface</h4>
            <p><code>task ops:kg</code></p>
            <p><small style="color: var(--heading);">Instant sub-second projection</small></p>
          </div>
        </div>

        <h3 style="margin-top: 1.5rem; margin-bottom: 0.5rem; color: var(--heading);">Interactive projection</h3>
        <p style="margin-bottom: 0.75rem; color: var(--text-muted);">
          Drag to pan &middot; wheel to zoom &middot; type to search labels &middot;
          toggle a type to filter &middot; hover (or search) to highlight a node and its
          neighbours &middot; <strong>click any node to open its slice</strong>.
          The filter lives in the URL, so a filtered view is a shareable link.
        </p>
        <div style="position: relative;">
          <canvas id="kg-canvas" style="width: 100%; height: 560px; display: block; background: var(--bg); border: 1px solid var(--border); border-radius: 6px; cursor: grab; touch-action: none;"></canvas>
          <div id="kg-tip" style="display: none; position: absolute; pointer-events: none; background: var(--card-bg); border: 1px solid var(--accent); border-radius: 4px; padding: 0.3rem 0.5rem; font-size: 0.75rem; color: var(--text); white-space: nowrap;"></div>
        </div>
        <p style="margin-top: 0.75rem; display: flex; align-items: center; gap: 0.5rem; flex-wrap: wrap;">
          <button class="tab-btn" id="kg-zoom-in">+</button>
          <button class="tab-btn" id="kg-zoom-out">&minus;</button>
          <button class="tab-btn" id="kg-reset">Fit</button>
          <input id="kg-search" type="search" placeholder="filter by label or id" style="flex: 1 1 200px; min-width: 170px; background: var(--bg); color: var(--text); border: 1px solid var(--border); border-radius: 6px; padding: 0.45rem 0.6rem; font-family: inherit; font-size: 0.85rem;" />
          <span id="kg-count" class="badge badge-blue">${toString (builtins.length kg.graph.nodes)} nodes</span>
        </p>
        <p style="margin-bottom: 0.75rem; display: flex; align-items: center; gap: 0.5rem; flex-wrap: wrap;">
          <button class="tab-btn nav-active" data-kg-type="host">host <span class="badge badge-blue">${toString kg.graph.stats.hosts}</span></button>
          <button class="tab-btn nav-active" data-kg-type="skill">skill <span class="badge badge-green">${toString kg.graph.stats.skills}</span></button>
          <button class="tab-btn nav-active" data-kg-type="doc">doc <span class="badge badge-yellow">${toString kg.graph.stats.docs}</span></button>
          <button class="tab-btn nav-active" data-kg-type="tag">tag <span class="badge" style="background: rgba(187, 154, 247, 0.2); color: var(--accent); border: 1px solid var(--accent);">${toString tagCount}</span></button>
        </p>

        <h3 style="margin-top: 1.5rem; margin-bottom: 0.75rem; color: var(--heading);">Graph Projection Layers</h3>
        <table>
          <thead>
            <tr>
              <th>Layer</th>
              <th>Count</th>
              <th>Canonical Source</th>
              <th>Role in Fleet</th>
            </tr>
          </thead>
          <tbody>
            <tr>
              <td><strong>Hosts</strong></td>
              <td>${toString kg.graph.stats.hosts}</td>
              <td><code>inventory.toml</code></td>
              <td>Physical servers, workstations, VPS, and preserved states</td>
            </tr>
            <tr>
              <td><strong>Skills</strong></td>
              <td>${toString kg.graph.stats.skills}</td>
              <td><code>.agents/skills/*/SKILL.md</code></td>
              <td>Autonomous agent runbooks and operational skills</td>
            </tr>
            <tr>
              <td><strong>Living Documents</strong></td>
              <td>${toString kg.graph.stats.docs}</td>
              <td>Root markdown & <code>docs/*.md</code></td>
              <td>Fleet architecture, invariants, and system handoffs</td>
            </tr>
            <tr>
              <td><strong>Edges (Mentions)</strong></td>
              <td>${toString kg.graph.stats.edges}</td>
              <td>AST Token Parser</td>
              <td>Explicit cross-subsystem knowledge references</td>
            </tr>
          </tbody>
        </table>
      '';
    };
  };

  # --- interactive canvas data ----------------------------------------------
  # The graph itself is the canonical projection (`lib/knowledge-graph.nix`).
  # The site adds ONLY presentation fields — a static slice URL per node and a
  # degree — so a canvas click is an ordinary Aki transition to a JSON file.
  # No daemon, no router, no client-side graph query language.
  # nixpkgs exposes `escapeXML` (a superset of what HTML text needs: & < > " ').
  escH = s: lib.escapeXML (toString s);
  nodeSlug = id: builtins.substring 0 16 (builtins.hashString "sha256" id);
  sliceRel = n: "data/kg/${n.type}-${nodeSlug n.id}.json";
  sliceForId = id: let
    sep = builtins.split ":" id;
    ty = builtins.head sep;
  in "data/kg/${ty}-${nodeSlug id}.json";

  # AGENTS.nix notes are a separate projection from the graph (they have no
  # repository file to index): decisions, queue items and design studies,
  # compiled and validated by lib/agents-notes.nix. They use the same
  # build-time markdown renderer and the same static-slice navigation as a doc.
  agentsNotes = import ./agents-notes.nix {inherit lib;};

  # Doc and skill nodes carry their own text into their slice. The note is read
  # from the repository at evaluation time, shipped as data next to the slice,
  # and rendered by the build step below — so "open the note" is a transition
  # inside the site, not a link to a forge that may have moved the file (the old
  # page hardcoded one such URL, and it was the only way to reach any note).
  docNodes = builtins.filter (n: n.type == "doc") kg.graph.nodes;
  skillNodes = builtins.filter (n: n.type == "skill") kg.graph.nodes;
  noteNodes = docNodes ++ skillNodes;
  # A skill node's `path` is its directory (`.agents/skills/<name>`); its note is
  # the SKILL.md inside it. `lib/knowledge-graph.nix` deliberately projects the
  # directory because that is how agents discover a skill.
  noteFile = n:
    if n.type == "skill"
    then "${n.path}/SKILL.md"
    else n.path;

  # Skills (and some docs) open with a YAML frontmatter fence. It is metadata for
  # agent discovery, already compiled by lib/skills.nix; rendering it would print
  # the frontmatter as body text. Drop everything through the closing `---`.
  stripFrontmatter = text: let
    lines = lib.splitString "\n" text;
    rest = builtins.tail lines;
    close =
      lib.findFirst (
        i: builtins.elemAt rest i == "---"
      )
      null (lib.range 0 (builtins.length rest - 1));
  in
    if builtins.length lines > 1 && builtins.head lines == "---" && close != null
    then lib.concatStringsSep "\n" (lib.drop (close + 1) rest)
    else text;

  noteEntries =
    map
    (n: {
      slice = sliceRel n;
      path = noteFile n;
      text = stripFrontmatter (builtins.readFile (root + "/${noteFile n}"));
    })
    (builtins.filter (n: n ? path) noteNodes)
    ++ lib.mapAttrsToList (id: _: {
      slice = "data/agents-notes/${id}.json";
      path = "AGENTS.nix#${id}";
      text = agentsNotes.sitePages.${id};
    })
    agentsNotes.notes;

  # Degree and incident edges computed once here rather than in the browser:
  # the slice a click lands on must already contain its neighbours, because the
  # page it navigates to is fetched, not computed.
  degree =
    lib.foldl'
    (acc: e:
      acc
      // {
        "${e.from}" = (acc.${e.from} or 0) + 1;
        "${e.to}" = (acc.${e.to} or 0) + 1;
      })
    {}
    kg.graph.edges;

  incident =
    lib.foldl'
    (acc: e:
      acc
      // {
        "${e.from}" =
          (acc.${e.from} or [])
          ++ [
            {
              dir = "out";
              id = e.to;
            }
          ];
        "${e.to}" =
          (acc.${e.to} or [])
          ++ [
            {
              dir = "in";
              id = e.from;
            }
          ];
      })
    {}
    kg.graph.edges; # Tag nodes have no stat of their own; derive the count so the chip can
  # never disagree with the data it filters.
  tagCount =
    builtins.length kg.graph.nodes
    - kg.graph.stats.hosts
    - kg.graph.stats.skills
    - kg.graph.stats.docs;

  siteNodes =
    map
    (n:
      n
      // {
        slice = sliceRel n;
        degree = degree.${n.id} or 0;
      })
    kg.graph.nodes;

  kgGraphJson = builtins.toJSON {
    schemaVersion = kg.graph.schemaVersion;
    generatedBy = kg.graph.generatedBy;
    stats = kg.graph.stats;
    nodes = siteNodes;
    edges = kg.graph.edges;
  };

  kgSlice = n: let
    inc = incident.${n.id} or [];
    outward = lib.filter (x: x.dir == "out") inc;
    inward = lib.filter (x: x.dir == "in") inc;
    links = xs:
      if xs == []
      then "<p><small>none</small></p>"
      else
        "<p>"
        + lib.concatMapStringsSep "\n" (x: ''
          <button class="side-btn" url="${sliceForId x.id}">${escH x.id}</button>
        '') (lib.take 40 xs)
        + (lib.optionalString (builtins.length xs > 40) ''<small>… ${toString (builtins.length xs - 40)} more</small>'')
        + "</p>";

    # Real navigation targets, so a slice is not a dead end: the host inventory
    # page for a registered host, the notes index for a note. No external URL is
    # hardcoded — the site's own state is the whole destination set.
    onward = let
      hostPage =
        lib.optionalString (n.type == "host" && builtins.elem n.label hostNames)
        ''<button class="tab-btn" url="data/host-${n.label}.json">Inventory page</button>'';
      notesPage =
        lib.optionalString (n.type == "doc" || n.type == "skill")
        ''<button class="tab-btn" url="data/notes.json">All notes</button>'';
    in
      hostPage + notesPage;

    # The placeholder is filled by the build step (scripts/task inject-notes.py)
    # with the note rendered from markdown; leaving it unreplaced is caught by
    # `task checks:kg:canvas`, so a note can never silently render empty.
    noteBody = lib.optionalString ((n.type == "doc" || n.type == "skill") && (n ? path)) ''
      <div class="note"><!--KG_NOTE--></div>
    '';

    # Values are HTML fragments already (escaped here, once), so the row
    # renderer above never re-escapes or double-escapes a path.
    meta =
      [
        ["id" "<code>${escH n.id}</code>"]
        ["type" (escH n.type)]
        ["links" (toString (degree.${n.id} or 0))]
      ]
      ++ lib.optional (n ? path) ["path" "<code>${escH n.path}</code>"]
      ++ lib.optional (n ? status) ["status" (escH n.status)]
      ++ lib.optional (n ? kind) ["kind" (escH n.kind)]
      ++ lib.optional (n ? description) ["description" (escH n.description)]
      ++ lib.optional (n ? tags) ["tags" (escH (lib.concatStringsSep ", " n.tags))];
  in
    builtins.toJSON {
      "#breadcrumbs" = {textContent = "fleet / knowledge-graph / ${n.id}";};
      "#detail-pane" = {
        innerHTML = ''
          <h2>${escH n.label}</h2>
          <p style="margin: 0.75rem 0; color: var(--text-muted);">${escH (n.description or "Structural node of the fleet knowledge projection.")}</p>
          <table>
            <tbody>
              ${lib.concatMapStringsSep "\n" (r: ''<tr><th>${escH (builtins.head r)}</th><td>${builtins.elemAt r 1}</td></tr>'') meta}
            </tbody>
          </table>

          ${noteBody}

          <h3 style="margin-top: 1.25rem; color: var(--heading);">This node mentions (${toString (builtins.length outward)})</h3>
          ${links outward}

          <h3 style="margin-top: 1.25rem; color: var(--heading);">Mentioned by (${toString (builtins.length inward)})</h3>
          ${links inward}

          <p style="margin-top: 1.5rem; display: flex; gap: 0.5rem; flex-wrap: wrap;">
            <button class="tab-btn" url="data/kg.json">&larr; Back to the graph</button>
            ${onward}
          </p>
        '';
      };
    };

  kgSliceFiles =
    map (n: {
      name = sliceRel n;
      file = pkgs.writeText "kg-slice-${nodeSlug n.id}.json" (kgSlice n);
    })
    kg.graph.nodes;

  # Live telemetry is OPTIONAL and is written by the host at runtime. The static
  # fallback therefore carries only facts this build knows: which host serves
  # the site and that these values are unknown. `null` is the honest value — the
  # old file invented "generation: booted", "uptime: nominal", "load: 0.0",
  # which the page then displayed as if measured.
  fallbackLiveJson = builtins.toJSON {
    hostname =
      if host != null
      then host
      else "";
    generation = null;
    uptime = null;
    load = null;
    memory = null;
    timestamp = null;
  };

  # One slice per registered host, not only the active ones: a preserved or WIP
  # host is still described by the registry and still reachable from the graph.
  hostJsonFiles =
    map (h: {
      name = "data/host-${h}.json";
      file = pkgs.writeText "host-${h}.json" (mkHostJson h);
    })
    hostKeys;

  # Notes are markdown; rendering is a build-time job, so the build needs a
  # markdown renderer and the manifest of (slice, path, text) that Nix already
  # assembled. Both are inputs here, never a second parser written in JS.
  noteRenderer = pkgs.python3.withPackages (ps: [ps.markdown]);
  noteManifest = pkgs.writeText "note-manifest.json" (builtins.toJSON noteEntries);
  injectNotes = pkgs.writeText "inject-notes.py" ''
    import json, os, sys

    import markdown

    out, manifest = sys.argv[1], sys.argv[2]
    entries = json.load(open(manifest))
    for e in entries:
        target = os.path.join(out, e["slice"])
        with open(target) as fh:
            slice_ = json.load(fh)
        pane = slice_["#detail-pane"]["innerHTML"]
        html = markdown.markdown(
            e["text"],
            extensions=["tables", "fenced_code", "sane_lists"],
            output_format="html5",
        )
        if "<!--KG_NOTE-->" not in pane:
            # A note whose slice does not offer the placeholder is a schema
            # mismatch; failing the build is better than shipping a dead page.
            sys.exit("no note placeholder in " + e["slice"])
        slice_["#detail-pane"]["innerHTML"] = pane.replace("<!--KG_NOTE-->", html, 1)
        with open(target, "w") as fh:
            json.dump(slice_, fh)
    print("rendered %d notes" % len(entries))
  '';
  # `import markdown` lives in this interpreter's environment, so the renderer
  # is invoked through it rather than through the build's own python3.
  injectNotesCmd = ''
    ${noteRenderer}/bin/python3 ${injectNotes} $out ${noteManifest}
  '';
in
  pkgs.runCommand "fleet-docs-site" {
    meta = {
      description = "Aki-powered static fleet documentation and closure explorer";
    };
  } ''
    mkdir -p $out/data/kg
    cat <<'EOF' > $out/index.html
    ${indexHtml}
    EOF

    # Assets are store paths already, so copy them verbatim instead of
    # re-emitting their bytes through a heredoc in the build script.
    cp ${jsFile} $out/${jsFileName}
    cp ${cssFile} $out/${cssFileName}

    # Backward-compatible unhashed copies
    cp $out/${jsFileName} $out/aki.min.js
    cp $out/${cssFileName} $out/style.css

    cp ${kgFile} $out/${kgFileName}
    cp $out/${kgFileName} $out/kg.min.js

    cp ${pkgs.writeText "overview.json" overviewJson} $out/data/overview.json
    cp ${pkgs.writeText "inventory.json" inventoryJson} $out/data/inventory.json
    cp ${pkgs.writeText "kg.json" kgJson} $out/data/kg.json
    cp ${pkgs.writeText "notes.json" notesJson} $out/data/notes.json
    cp ${pkgs.writeText "agents-notes.json" agentsNotesJson} $out/data/agents-notes.json
    mkdir -p $out/data/agents-notes

    ${lib.concatStringsSep "\n" (
      map (s: "cp ${s.file} $out/${s.name}") agentNoteSlices
    )}
    cp ${pkgs.writeText "closures.json" closuresJson} $out/data/closures.json
    cp ${pkgs.writeText "live.json" fallbackLiveJson} $out/data/live.json
    cp ${pkgs.writeText "kg-graph.json" kgGraphJson} $out/data/kg-graph.json

    ${lib.concatStringsSep "\n" (
      map (hj: "cp ${hj.file} $out/${hj.name}") hostJsonFiles
    )}

    ${lib.concatStringsSep "\n" (
      map (s: "cp ${s.file} $out/${s.name}") kgSliceFiles
    )}

    # `cp` from the store yields read-only files; the slice needs to be rewritten
    # in place to carry its note.
    chmod -R u+w $out/data

    # Bake each note's own text into its slice (markdown -> HTML at build time).
    ${injectNotesCmd}

    # Pre-compress static assets for Nginx gzip_static (zero runtime CPU)
    gzip -9k $out/index.html $out/*.js $out/*.css $out/data/*.json $out/data/kg/*.json $out/data/agents-notes/*.json
  ''
