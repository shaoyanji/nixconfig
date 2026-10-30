# lib/docs.nix — documentation generated from the COMPILED metadata
{
  lib,
  inventory,
  # Parsed modules.toml. Pass it from the flake so the file is read once.
  modules ? builtins.fromTOML (builtins.readFile ../modules.toml),
  # AGENTS.nix -> rendered note pages (lib/agents-notes.nix). Passed in so this
  # module stays a pure renderer of compiled data.
  notes ? {},
}: let
  knobs = modules.knobs or {};
  modulesMeta = modules.metadata or {};

  inherit (inventory) metadata derived nixHosts externalHosts repos;

  # --- markdown helpers ------------------------------------------------------
  # Table cells must not contain a raw `|` or newline, or the table collapses.
  esc = s:
    builtins.replaceStrings ["|" "\n"] ["\\|" " "] (
      let
        v =
          if s == null
          then ""
          else toString s;
      in
        if v == ""
        then "—"
        else v
    );

  table = headers: rows: let
    row = cells: "| " + lib.concatStringsSep " | " (map esc cells) + " |";
    rule = "| " + lib.concatStringsSep " | " (map (_: "---") headers) + " |";
  in
    # header row, alignment rule, then the body — markdown needs all three.
    lib.concatStringsSep "\n" ([(row headers) rule] ++ map row rows);

  rowList = label: values:
    lib.optionalString (values != []) (
      "- ${label}:\n" + lib.concatMapStringsSep "\n" (v: "  - ${v}") values
    );

  # `what` already carries its own formatting (e.g. "`inventory.toml`").
  banner = what: ''
    > **Generated — not a file in the repository.** Built from ${what} by
    > `lib/docs.nix` (`nix build .#artifacts.docs`); rendered by `.#sites.fleet-docs-site`.
  '';

  header = title: what: "# ${title}\n\n${banner what}\n";

  # --- per-host page ---------------------------------------------------------
  hostPage = name: h: let
    hw = h.hardware;
    net = h.network;
    sw = h.software;
    p = h.persona;
    facts =
      table
      ["field" "value"]
      ([
          ["role" h.role]
          ["status" (h.status + lib.optionalString (h.status_detail != "") " — ${h.status_detail}")]
          ["kind / arch" "${h.kind} / ${h.arch}"]
          ["flake output" (lib.boolToString h.flake)]
          ["managed" (lib.boolToString h.managed)]
          ["in CI" (lib.boolToString h.ci)]
        ]
        ++ lib.optional (hw.model != "") ["hardware" hw.model]
        ++ lib.optional (hw.cpu != "") ["cpu" hw.cpu]
        ++ lib.optional (hw.gpu != "") ["gpu" hw.gpu]
        ++ lib.optional (hw.ram != "") ["ram" hw.ram]
        ++ lib.optional (hw.storage_layout != "") ["storage" hw.storage_layout]
        ++ lib.optional (net.lan_ip != "") ["lan" net.lan_ip]
        ++ lib.optional (net.tailscale_ip != "") ["tailnet" net.tailscale_ip]
        ++ lib.optional (p.title != "") ["persona" "${p.title} (tier: ${p.compute_tier})"]
        ++ lib.optional (p.system_prompt_hint != "") ["persona hint" p.system_prompt_hint]);
  in
    header name "`inventory.toml`"
    + "\n"
    + facts
    + "\n"
    + lib.optionalString (sw.module_chain != "") "\n## Module chain\n\n`${sw.module_chain}`\n"
    + lib.optionalString (sw.traits != []) "\n## Traits\n\n${rowList "traits" sw.traits}\n"
    + lib.optionalString (sw.key_services != []) "\n## Key services\n\n${rowList "services" sw.key_services}\n"
    + lib.optionalString (p.allowed_tasks != []) "\n## Allowed tasks\n\n${rowList "tasks" p.allowed_tasks}\n"
    + lib.optionalString (p.constraints != []) "\n## Constraints\n\n${rowList "constraint" p.constraints}\n"
    + lib.optionalString (h.notes != []) "\n## Notes\n\n${lib.concatMapStringsSep "\n" (n: "- ${n}") h.notes}\n";

  # --- fleet inventory page --------------------------------------------------
  byStatus = status: lib.filterAttrs (_: h: h.status == status) nixHosts;
  hostRows = hosts:
    map
    (name: let h = hosts.${name}; in [name h.role h.arch h.kind h.network.lan_ip h.network.tailscale_ip])
    (lib.attrNames hosts);

  fleetInventory = let
    statusSection = status: title: let
      set = byStatus status;
    in
      lib.optionalString (set != {}) ''

        ## ${title}

        ${table ["host" "role" "arch" "kind" "lan" "tailnet"] (hostRows set)}
      '';
    externalRows =
      map
      (name: let h = externalHosts.${name}; in [name h.role h.kind h.status])
      (lib.attrNames externalHosts);
    personaRows =
      map
      (name: let h = nixHosts.${name}; in [name h.persona.title h.persona.compute_tier (lib.concatStringsSep ", " h.persona.allowed_tasks)])
      (lib.filter (n: nixHosts.${n}.persona.title != "") (lib.attrNames nixHosts));
    # Ours by ownership, not by vendoring. Listed here because the page is the
    # catalog a person reads; they are absent from every host table on purpose.
    repoRows =
      map
      (name: let
        r = repos.${name};
      in [
        r.url
        r.status
        (
          if r.ci == ""
          then "none"
          else r.ci
        )
        r.deploy
      ])
      (lib.attrNames repos);
  in
    header "Fleet Device & Host Inventory" "`inventory.toml`"
    + ''
      ${metadata.description}

      Source of truth: `inventory.toml`, compiled once by `lib/inventory.nix`.

      ## Fleet overview

      ${table ["metric" "count"] [
        ["total devices" (toString derived.total)]
        ["nix hosts" (toString derived.nix)]
        ["external devices" (toString derived.external)]
        ["active" (toString derived.active)]
        ["active (nix / external)" "${toString derived.activeNix} / ${toString derived.activeExternal}"]
        ["wip" (toString derived.wip)]
        ["preserved" (toString derived.preserved)]
      ]}
    ''
    + statusSection "active" "Active Nix fleet"
    + statusSection "wip" "Work in progress"
    + statusSection "preserved" "Preserved archetypes"
    + lib.optionalString (externalRows != []) ''

      ## External (non-Nix) devices

      ${table ["host" "role" "kind" "status"] externalRows}
    ''
    + lib.optionalString (personaRows != []) ''

      ## Agent personas

      ${table ["host" "persona" "compute tier" "allowed tasks"] personaRows}
    ''
    + lib.optionalString (repoRows != []) ''

      ## Repositories outside this tree

      Registered in `inventory.toml` as `[repos.*]`: their own code, their own CI,
      their own authoring method. They are not devices, so they appear in no host
      table above and in no count.

      ${table ["repo" "status" "ci" "deploy"] repoRows}
    '';

  # --- modules registry page -------------------------------------------------
  knobRows = type:
    map
    (key: let
      k = knobs.${key};
    in [
      k.name
      k.option
      "`${k.path}`"
      (
        if k.default
        then "on"
        else "off"
      )
      (lib.concatStringsSep ", " k.hosts)
    ])
    (lib.attrNames (lib.filterAttrs (_: k: (k.type or "") == type) knobs));

  moduleSections =
    lib.concatStringsSep "\n"
    (map
      (t: let
        rows = knobRows t;
      in
        lib.optionalString (rows != []) ''

          ## ${lib.toUpper (builtins.substring 0 1 t) + builtins.substring 1 (builtins.stringLength t) t} knobs

          ${table ["knob" "option" "module" "default" "hosts"] rows}
        '')
      ["profile" "service" "role"]);

  modulesRegistry =
    header "Fleet Modular Control Knob Registry" "`modules.toml`"
    + ''
      ${modulesMeta.description or ""}

      Knobs are declared in `modules.toml` and consumed by `modules.toml`-driven
      tooling; this page is generated so it cannot lag the registry.
    ''
    + moduleSections
    + "\n";

  # --- page set (paths inside the derivation) --------------------------------
  generatedPages =
    {
      "docs/generated/fleet-inventory.md" = fleetInventory;
      "docs/generated/modules-registry.md" = modulesRegistry;
    }
    // lib.mapAttrs' (name: h: lib.nameValuePair "docs/generated/hosts/${name}.md" (hostPage name h)) nixHosts
    // notes;

  # There is no `nav` value any more: the only consumer of one was the Python
  # renderer in docs-site/, which is retired. The rendered site
  # (`.#sites.fleet-docs-site`, lib/aki-site.nix) derives its own navigation from the
  # knowledge graph — so a document that exists is a document the site shows,
  # with no second list to keep in sync.
  # --- derivation ------------------------------------------------------------
  # `install -D` creates the parent directories, so nested slugs need no mkdir.
  mkDocs = pkgs: let
    storeName = path: lib.replaceStrings ["/"] ["-"] path;
    installPage = path: text: ''
      install -Dm644 ${pkgs.writeText "doc-${storeName path}" text} $out/${path}
    '';
  in
    pkgs.runCommand "nixconfig-docs" {
      meta.description = "nixconfig documentation generated from inventory.toml and modules.toml";
    } ''
      mkdir -p $out
      ${lib.concatStringsSep "\n" (lib.mapAttrsToList installPage generatedPages)}
    '';
in {
  inherit generatedPages;

  # All pages keyed by repo-relative path (static pages are not copied: the site
  # reads them from the repo tree, the build owns only what is generated).
  pages = generatedPages;

  inherit mkDocs;
}
