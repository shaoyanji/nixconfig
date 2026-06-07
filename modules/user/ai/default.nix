{
  lib,
  pkgs,
  ...
}: {
  # options.ai.opencode.enable = lib.mkEnableOption "opencode" // {default = true;};

  imports = [
    # ./codex.nix
    # ./mods.nix
    ./aichat.nix
    # ./antigravity-cli.nix
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

  home.packages = with pkgs;
    [
      geminicommit
      tgpt
      # aichat
      # mods
    ]
    ++ lib.optionals stdenv.isLinux [
      # qwen-code
    ];
}
