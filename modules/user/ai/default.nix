# `profiles.ai`: which AI tooling a host gets, declared once.
{
  lib,
  pkgs,
  config,
  osConfig ? {},
  ...
}: let
  hostName = osConfig.networking.hostName or (config.networking.hostName or "");

  # Which hosts get the heavy multi-agent suite is a trait a host DECLARES in
  # inventory.toml (`ai-full`), not a list of names kept here: two workstations and
  # the mainframe had to be remembered in three different modules. A host promoted
  # to full tooling now states it once, next to the hardware that justifies it.
  invHost =
    if hostName != ""
    then (osConfig.fleet.inventory.hosts.${hostName} or (config.fleet.inventory.hosts.${hostName} or null))
    else null;
  traits =
    if invHost == null
    then []
    else (invHost.software.traits or []);
  defaultTier =
    if builtins.elem "ai-full" traits
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
    ./dsh-launcher.nix
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
      ];
  };
}
