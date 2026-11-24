# `profiles.ai`: which AI tooling a host gets, declared once.
{
  self,
  lib,
  pkgs,
  config,
  osConfig ? {},
  # Per-host leaf list (`hmAi` in flake/host-inventory.nix). Same rule as
  # user.base: the default reads the constants file, never the `user` module
  # arg — `imports` may not force `config`.
  hmAiFeatures ? (import self.modules."global.user").hmAiFeatures,
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

  # Memory layer — the accepted note: task ops:notes:show ID=memory-architecture.
  memoryTools = [
    pkgs.llm-agents.qmd # local hybrid markdown/code search — the wiki layer
    pkgs.llm-agents.ai-memory # persistent cross-agent memory — scratch, never authority
    pkgs.llm-agents.toon # TOON format tooling
  ];

  agentTools = [
    pkgs.llm-agents.agent-browser # headless Chrome automation CLI (bundles Chromium ~700MB)
  ];

  # Leaf-name → module set; `dsh-launcher` and `reasonix` stay out of the
  # canonical list on purpose (retired, see their files).
  aiFeatures = {
    aichat = [self.modules."user.ai.aichat"];
    antigravity-cli = [self.modules."user.ai.antigravity-cli"];
    skills = [self.modules."user.ai.skills"];
    freebuff-remote = [self.modules."user.ai.freebuff-remote"];
    mainframe-remotes = [self.modules."user.ai.mainframe-remotes"];
    zed-mcp = [self.modules."user.ai.zed-mcp"];
  };
in {
  # Tiering for AI CLI tooling. There is no `profiles.ai.enable` flag: under
  # the leaf-list model a host's AI surface is its `hmAi`/`hmModules` data —
  # off means the module is not named (containers do exactly that), so the
  # flag only ever held its default true (chain-polish 2026-11-24).
  # "light" keeps closures small on mobile laptops by excluding heavy Chromium-bundled
  # agents (agent-browser), local vector indexers (qmd), and batched runners.
  options.profiles.ai = {
    tier = lib.mkOption {
      type = lib.types.enum ["none" "light" "full"];
      default = defaultTier;
      description = ''
        AI agent tooling tier:
        - "none": disables AI tools entirely.
        - "light": lightweight client tools (antigravity-cli, geminicommit, tgpt, aichat).
                   Excludes heavy agent-browser (700MB Chromium), qmd embeddings, and batched runner daemons.
        - "full": complete fleet agent suite (qmd, agent-browser, ai-memory, toon,
                  reasonix). Default for frieren, eisen, poseidon.
                  `crush` is retired (free credits exhausted, 2026-11-06) and
                  pdfvision/parallel-cli are slashed (zero callers, pkgs.txt) —
                  none are part of any tier.
      '';
    };
  };

  imports = lib.concatMap (f: aiFeatures.${f} or []) hmAiFeatures;

  config = lib.mkIf (config.profiles.ai.tier != "none") {
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
      ++ lib.optionals (config.profiles.ai.tier == "full") (
        # pkgs.llm-agents.crush — retired 2026-11-06 (free credits exhausted); do
        # not re-add without a paid quota. See `.agents/skills/crush`.
        memoryTools ++ agentTools
      );
  };
}
