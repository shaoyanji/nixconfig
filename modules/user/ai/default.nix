{
  lib,
  pkgs,
  config,
  ...
}:
{
  # Fleet-wide gate for AI CLI tooling. On by default (desktops, standalone
  # homes); container/no-DE hosts set this to false to keep the closures
  # small on headless boxes. The leaf modules (aichat.nix, antigravity-cli.nix)
  # gate themselves on this option too, so they stay inert where it is off —
  # `or true` keeps them active in chains (roles/home.nix) that never import
  # this option declaration.
  options.profiles.ai.enable = lib.mkEnableOption "AI agent CLI tooling" // {
    default = true;
  };

  imports = [
    # ./codex.nix
    # ./mods.nix
    ./aichat.nix
    ./antigravity-cli.nix
    ./freebuff-remote.nix
    ./zed-mcp.nix
    ./hermes-user.nix
    # ./opencode.nix
  ];

  config = lib.mkIf config.profiles.ai.enable {
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
    home.packages =
      with pkgs;
      [
        geminicommit
        tgpt
        pkgs.llm-agents.crush # Charmbracelet agent (MIT, source-built)
        # freebuff — frieren-only since 2026-10: the mainframe runs the TUI,
        # clients connect with freebuff-remote / freebuff-terminal (SSH).
        # qmd — local hybrid markdown/code search (tobi). CUDA gated off:
        # ares forces config.cudaSupport = true and the override arg would
        # otherwise drag cudaPackages into every host closure.
        (pkgs.llm-agents.qmd.override { cudaSupport = false; })
      # dsh — DeepSeek harness CLI (llm-agents overlay). Fleet-wide client
      # agent now that freebuff is mainframe-only.
      pkgs.llm-agents.dsh
      # Fleet agent utility stack (2026-10):
      #   ai-memory — persistent cross-agent memory (MCP + CLI; shared store)
      #   toon — TOON format tooling (the old OpenClaw memory encoding)
      #   pdfvision — PDF understanding/conversion for agent pipelines
      #   parallel-cli — parallel task runner for batched agent work
      pkgs.llm-agents.ai-memory
      pkgs.llm-agents.toon
      pkgs.llm-agents.pdfvision
      pkgs.llm-agents.parallel-cli
      # agent-browser — headless Chrome automation CLI for agents (Vercel):
      # snapshot-based element refs, compact text output. Needs chromium.
      pkgs.llm-agents.agent-browser
      pkgs.chromium
        # qwen-code — removed 2026-10: redundant with agy/crush on the 8 GB
        # laptops (Node-based CLI with a ~1 GB closure); re-enable if needed.
        # pkgs.llm-agents.qwen-code
        # hermes-agent — re-enable when wanted (Fryuni fork of the 2026-09
        # teardown; upstream packaging is maintained).
        # pkgs.llm-agents.hermes-agent
        # grok — xAI CLI, closed binary; keep commented.
        # pkgs.llm-agents.grok
        # aichat
        # mods
      ]
      ++ lib.optionals stdenv.hostPlatform.isLinux [ ];
  };
}
