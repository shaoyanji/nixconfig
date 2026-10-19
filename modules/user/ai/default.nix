{
  lib,
  pkgs,
  config,
  osConfig ? {},
  inputs,
  ...
}: let
  hostName = osConfig.networking.hostName or (config.networking.hostName or "");

  # The chromium agent-browser actually drives. llm-agents pins its OWN nixpkgs,
  # so `pkgs.chromium` is a different build (154 vs 155, ~1.7 GiB): declaring
  # that would ship a SECOND browser to gain a launcher entry. This expression
  # resolves to the identical store path agent-browser wraps, so the home
  # profile gains `bin/chromium` plus `share/applications/chromium-browser.desktop`
  # (what fuzzel lists) for zero extra bytes.
  agentChromium =
    inputs.llm-agents.inputs.nixpkgs.legacyPackages.${pkgs.stdenv.hostPlatform.system}.chromium;
  # By default, only the central mainframe (frieren), AI/compute workstation (eisen),
  # and flagship workstation (poseidon) receive the heavy multi-agent suite.
  # Lightweight mobile laptops (aristotle, fern) and other clients default to "light".
  defaultTier =
    if builtins.elem hostName ["frieren" "eisen" "poseidon"]
    then "full"
    else "light";
in {
  # Fleet-wide gate and tiering for AI CLI tooling.
  # "light" keeps closures small on mobile laptops by excluding heavy Chromium-bundled
  # agents (agent-browser), local vector indexers (qmd), and batched runners.
  options.profiles.ai = {
    enable =
      lib.mkEnableOption "AI agent CLI tooling"
      // {
        default = true;
      };

    tier = lib.mkOption {
      type = lib.types.enum ["none" "light" "full"];
      default = defaultTier;
      description = ''
        AI agent tooling tier:
        - "none": disables AI tools entirely.
        - "light": lightweight client tools (antigravity-cli, geminicommit, tgpt, aichat).
                   Excludes heavy agent-browser (700MB Chromium), qmd embeddings, and batched runner daemons.
        - "full": complete fleet agent suite (crush, qmd, agent-browser, ai-memory, toon,
                  pdfvision, parallel-cli, reasonix). Default for frieren, eisen, poseidon.
      '';
    };
  };

  imports = [
    # ./codex.nix
    # ./mods.nix
    ./aichat.nix
    ./antigravity-cli.nix
    ./skills
    ./freebuff-remote.nix
    ./mainframe-remotes.nix
    ./zed-mcp.nix
    # ./opencode.nix
  ];

  config = lib.mkIf (config.profiles.ai.enable && config.profiles.ai.tier != "none") {
    programs.translate-shell = {
      enable = true;
      settings = {
        verbose = true;
        hl = "en";
        tl = [
          "zh"
          "de"
        ];
      };
    };

    # AI agent CLIs from llm-agents.nix (overlay wired in module-sets:
    # pkgs.llm-agents.<name>; numtide cache via flake nixConfig).
    home.packages = with pkgs;
    # Base light tools (installed for both "light" and "full" tiers)
      [
        geminicommit
        tgpt
      ]
      # Heavy agent suite — ONLY installed when tier == "full"
      # Keeps ~2+ GB and bundled Chromium off light mobile clients like aristotle
      ++ lib.optionals (config.profiles.ai.tier == "full") [
        pkgs.llm-agents.crush # Charmbracelet agent (MIT, source-built)
        pkgs.llm-agents.qmd # local hybrid markdown/code search
        pkgs.llm-agents.ai-memory # persistent cross-agent memory
        pkgs.llm-agents.toon # TOON format tooling
        pkgs.llm-agents.pdfvision # PDF understanding/conversion
        pkgs.llm-agents.parallel-cli # parallel task runner for batched agent work
        pkgs.llm-agents.agent-browser # headless Chrome automation CLI (bundles Chromium ~700MB)
        pkgs.llm-agents.reasonix
      ]
      # Same store path as the browser agent-browser drives — zero extra closure
      # bytes. Gives the user `chromium` on PATH (the user environment links
      # `bin`), which is the "unhide the tool from system land" half.
      ++ lib.optionals (
        config.profiles.ai.tier == "full" && pkgs.stdenv.hostPlatform.isLinux
      ) [agentChromium];

    # The searchable half. Fuzzel reads .desktop entries, and it does NOT read
    # them from a package that merely sits in the user environment: NixOS builds
    # `users.<u>.packages` with only `bin` + `share/man` linked (`~/.nix-profile`
    # literally holds `bin/` and `share/man/`), so every package's
    # `share/applications` is dropped. That is why `xdg.desktopEntries` — which
    # only injects a hiPrio package into home.packages — produces an entry you
    # cannot find. Writing through `home.file` puts the entry in
    # ~/.local/share/applications, the XDG data dir fuzzel and every other
    # launcher scan (the same place the kando entry lives).
    #
    # `mkIf`, not `optionalAttrs`: reading `config` while the config attrset is
    # being constructed recurses, and it is also what keeps this Linux-only
    # launcher off the darwin host.
    home.file =
      lib.mkIf (config.profiles.ai.tier == "full" && pkgs.stdenv.hostPlatform.isLinux)
      {
        ".local/share/applications/chromium.desktop".source = pkgs.makeDesktopItem {
          name = "chromium";
          desktopName = "Chromium";
          genericName = "Web Browser";
          comment = "Chromium — the exact build agent-browser drives";
          exec = "${agentChromium}/bin/chromium %U";
          # Name, not an absolute path: the icon is planted in the user's
          # hicolor theme below, so the XDG lookup resolves it. That is the
          # portable form — a store path in `Icon` only works in launchers
          # that special-case absolute icons.
          icon = "chromium";
          categories = ["Network" "WebBrowser"];
          keywords = ["browser" "web" "chromium"];
          # Chromium owns the browser MIME types; without this the entry is
          # also invisible as a handler in `xdg-open`/xdg-mime.
          mimeTypes = ["x-scheme-handler/http" "x-scheme-handler/https"];
        };
        # The browser's own icons, copied into the user's hicolor theme. 12 KB
        # of PNGs, and it is what makes `Icon=chromium` in the entry above
        # resolve instead of drawing a blank tile.
        ".local/share/icons/hicolor/128x128/apps/chromium.png".source = "${agentChromium}/share/icons/hicolor/128x128/apps/chromium.png";
        ".local/share/icons/hicolor/48x48/apps/chromium.png".source = "${agentChromium}/share/icons/hicolor/48x48/apps/chromium.png";
      };
  };
}
