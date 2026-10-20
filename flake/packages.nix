{
  lib,
  systems,
  pkgsFor,
  inventory,
  ...
}:
lib.genAttrs systems.default (system: let
  pkgs = pkgsFor system;

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
in {
  inherit (pkgs) simplex-chat;
  inherit (pkgs) smp-server;
  # Aki explorer site: fed the COMPILED registry, so its host matrix cannot
  # disagree with the hosts or with the markdown docs built from the same value.
  fleet-docs-site = import ../lib/aki-site.nix {inherit pkgs lib inventory;};

  # --- compiled inventory artifacts ---------------------------------------
  # Both are generated from the ONE parse in lib/inventory.nix, so they cannot
  # disagree with each other or with inventory.toml.

  # Machine-readable registry, pretty-printed for diffing. Consume this instead
  # of re-parsing inventory.toml with `yq` in scripts: it is already validated,
  # defaults-normalised and carries the derived counts.
  inventory-json = pkgs.runCommand "inventory.json" {nativeBuildInputs = [pkgs.jq];} ''
    jq . ${pkgs.writeText "inventory.compiled.json" inventory.json} > $out
  '';

  # bountystash.com — the portfolio, rendered from evaluated data by the same
  # Nix-native approach as the fleet site (lib/bountystash-site.nix): one CSS
  # file, two locales, no JavaScript.
  bountystash-site = import ../lib/bountystash-site.nix {inherit pkgs lib;};

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
})
