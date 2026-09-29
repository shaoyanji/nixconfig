{ lib
, pkgs
, ...
}: {
  # options.ai.opencode.enable = lib.mkEnableOption "opencode" // {default = true;};

  imports = [
    # ./codex.nix
    # ./mods.nix
    ./aichat.nix
    ./antigravity-cli.nix
    # ./opencode.nix
  ];
  # ++ lib.optionals config.ai.opencode.enable [./opencode.nix];

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
      pkgs.llm-agents.qwen-code # Apache-2.0, actively maintained (QwenLM)
      # hermes-agent — re-enable when wanted (Fryuni fork of the 2026-09
      # teardown; upstream packaging is maintained).
      # pkgs.llm-agents.hermes-agent
      # grok — xAI CLI, closed binary; keep commented.
      # pkgs.llm-agents.grok
      # aichat
      # mods
    ]
    ++ lib.optionals stdenv.hostPlatform.isLinux [ ];
}
