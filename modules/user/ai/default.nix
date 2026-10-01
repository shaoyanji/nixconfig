{ lib
, pkgs
, config
, ...
}:
{
  # Fleet-wide gate for AI CLI tooling. On by default (desktops, standalone
  # homes); container/no-DE hosts set this to false to keep the closures
  # small on headless boxes. The leaf modules (aichat.nix, antigravity-cli.nix)
  # gate themselves on this option too, so they stay inert where it is off —
  # `or true` keeps them active in chains (roles/home.nix) that never import
  # this option declaration.
  options.profiles.ai.enable = lib.mkEnableOption "AI agent CLI tooling" // { default = true; };

  imports = [
    # ./codex.nix
    # ./mods.nix
    ./aichat.nix
    ./antigravity-cli.nix
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
    home.packages = with pkgs;
      [
        geminicommit
        tgpt
        pkgs.llm-agents.crush # Charmbracelet agent (MIT, source-built)
        pkgs.llm-agents.freebuff # Codebuff community CLI
        # qmd — local hybrid markdown/code search (tobi). CUDA gated off:
        # ares forces config.cudaSupport = true and the override arg would
        # otherwise drag cudaPackages into every host closure.
        (pkgs.llm-agents.qmd.override { cudaSupport = false; })
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

