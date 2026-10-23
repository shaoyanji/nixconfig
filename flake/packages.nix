# `packages.<system>` as a tree, not a bag: one namespace per kind of artifact.
#
#   sites.*      rendered HTML trees a vhost serves
#   artifacts.*  compiled data (inventory, agent feed)
#   servers.*    long-running services a host may install
#   cli.*        borrowed commands, `nix run .#cli.<family>.<tool>` (flake/cli.nix)
#
# The CLI tree is imported rather than repeated here: `flake/cli.nix` is the one
# table, and both `packages.cli` and `apps.cli` are projections of it, so a tool
# cannot exist in one namespace and be missing from the other.
{
  lib,
  systems,
  pkgsFor,
  cliFor,
  inventory,
  docsGen,
  skillsCtl,
  agentsNotesCtl,
  knowledgeGraphCtl,
  self,
}: let
  feedHost = name: h: let
    bullets = label: values: lib.optionalString (values != []) "\n- ${label}: ${lib.concatStringsSep ", " values}";
    # Prose fields are whole sentences, not labels. Comma-joining them produced
    # "...plus the sops/nix-index HM modules., Steam runs under ..." — a broken
    # sentence where the reader cannot tell where one note ends. One sub-bullet per
    # entry instead. Short label fields (traits, key services) stay `bullets`.
    prose = label: values:
      lib.optionalString (values != []) (
        "\n- ${label}:\n" + lib.concatMapStringsSep "\n" (v: "  - ${v}") values
      );
    lines =
      [
        "## ${name}"
        "- role: ${h.role}"
        "- status: ${h.status}${lib.optionalString (h.status_detail != "") " — ${h.status_detail}"}"
        "- kind/arch: ${h.kind} / ${h.arch}"
        "- flake: ${lib.boolToString (h.kind != "external" && h.flake)} (managed: ${lib.boolToString h.managed}, ci: ${lib.boolToString h.ci})"
      ]
      ++ lib.optional (h.hardware.model != "") "- hardware: ${h.hardware.cpu} / ${h.hardware.ram}"
      ++ lib.optional (h.hardware.storage_layout != "") "- storage: ${h.hardware.storage_layout}"
      ++ lib.optional (h.network.lan_ip != "") "- lan: ${h.network.lan_ip}"
      ++ lib.optional (h.network.tailscale_ip != "") "- tailnet: ${h.network.tailscale_ip}"
      ++ lib.optional (h.persona.title != "") "- persona: ${h.persona.title} (tier: ${h.persona.compute_tier})"
      ++ lib.optional (h.persona.system_prompt_hint != "") "- hint: ${h.persona.system_prompt_hint}"
      ++ lib.optional (h.software.module_chain != "") "- module chain: ${h.software.module_chain}";
    lists =
      bullets "traits" h.software.traits
      + bullets "key services" h.software.key_services
      + bullets "allowed tasks" h.persona.allowed_tasks
      + bullets "constraints" h.persona.constraints
      + prose "notes" h.notes;
  in
    lib.concatStringsSep "\n" lines + lists + "\n";
in
  lib.genAttrs systems.work (system: let
    pkgs = pkgsFor system;
    cli = cliFor system;
    # The one serializer. `pkgs.formats.json` validates the value against the
    # JSON type at eval time, so an attribute that cannot be represented fails
    # here instead of producing a broken artifact nobody parses until runtime.
    json = pkgs.formats.json {};
  in {
    sites =
      {
        # Aki explorer site: fed the COMPILED registry, so its host matrix cannot
        # disagree with the hosts or with the markdown docs built from the same value.
        fleet-docs-site = import ../lib/aki-site.nix {inherit pkgs lib inventory;};

        # bountystash.com — the portfolio, rendered from evaluated data by the same
        # Nix-native approach as the fleet site (lib/bountystash-site.nix): one CSS
        # file, two locales, no JavaScript.
        bountystash-site = import ../lib/bountystash-site.nix {inherit pkgs lib;};
      }
      // lib.optionalAttrs (system == "aarch64-linux") {
        # delphi's two surfaces: the public dossier and the tailnet console, from one
        # evaluated structure (`lib/delphi-site.nix`).
        #
        # This IS the artifact nginx serves — `system.build.delphiSite` from the host's
        # own evaluation, including `services.servicePortal.cards` — because a second,
        # card-less build under the same name was a preview that showed an empty console
        # while the live page listed four mounts. It costs a host evaluation to read, so
        # it lives outside the per-system set below only for delphi's architecture: a
        # package set for another system would hold a foreign derivation that a local
        # `nix build` can only satisfy by spending a builder's budget.
        delphi-site = self.nixosConfigurations.delphi.config.system.build.delphiSite;
      };

    artifacts =
      {
        # Machine-readable registry, pretty-printed for diffing. Consume this instead
        # of re-parsing inventory.toml with `yq` in scripts: it is already validated,
        # defaults-normalised and carries the derived counts.
        inventory-json = pkgs.runCommand "inventory.json" {nativeBuildInputs = [pkgs.jq];} ''
          jq . ${json.generate "inventory.compiled.json" inventory.compiled} > $out
        '';

        # The agent feed: every Nix host's role, persona hint, hardware, traits and
        # operational notes as one compiled document. This is where the commentary
        # that used to live as Nix comments is meant to land.
        fleet-feed = pkgs.writeText "FLEET-FEED.md" (
          let
            m = inventory.metadata;
            d = inventory.derived;
          in
            ''
              # ${m.title}

              ${m.description}

              Compiled from `inventory.toml` (schema v${m.version}) by `lib/inventory.nix`.

              - devices: ${toString d.total} (nix: ${toString d.nix}, external: ${toString d.external})
              - active: ${toString d.active} (nix: ${toString d.activeNix}, external: ${toString d.activeExternal})
              - wip: ${toString d.wip}, preserved: ${toString d.preserved}

            ''
            + lib.concatStringsSep "\n" (lib.mapAttrsToList feedHost inventory.nixHosts)
            + ''
              ## Non-Nix devices

              ${lib.concatStringsSep "\n" (lib.mapAttrsToList (name: h: "- ${name}: ${h.role} (${h.status})") inventory.externalHosts)}
            ''
        );
      }
      // lib.optionalAttrs (system == "x86_64-linux") {
        # Documentation is compiled once, on the x86 host that serves it. Keeping
        # it out of aarch64's set is the point: delphi is a two-core OCI instance
        # that runs services, and asking it for `.#artifacts.docs` should be a
        # missing attribute, not a failed build of a foreign system.
        docs = docsGen.mkDocs pkgs;

        # Every skill tree plus the compiled index, for consumers that want one
        # path instead of a directory walk. Same reasoning as above.
        agent-skills-bundle = pkgs.runCommand "agent-skills-bundle" {} ''
          mkdir -p $out
          cp -a ${../.agents/skills} $out/skills
          cp ${json.generate "agent-skills-index.json" skillsCtl.index} $out/index.json
          chmod -R u+w $out
        '';

        # The two agent-context documents, serialized from the typed values the
        # roots (`.#agentsNotes.api`, `.#knowledgeGraph.graph`) already expose.
        agents-notes = json.generate "agents-notes.json" agentsNotesCtl.api;
        knowledge-graph = json.generate "knowledge-graph.json" knowledgeGraphCtl.graph;
      };

    servers = {
      inherit (pkgs) simplex-chat smp-server;
    };

    cli = cli.packages;
  })
