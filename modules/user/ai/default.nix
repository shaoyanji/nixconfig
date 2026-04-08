{
  lib,
  pkgs,
  config,
  ...
}: {
  options.ai.opencode.enable = lib.mkEnableOption "opencode" // {default = true;};

  imports =
    [
      ./codex.nix
      ./gemini-cli.nix
      ./mods.nix
      ./aichat.nix
    ]
    ++ lib.optionals config.ai.opencode.enable [./opencode.nix];

  programs.nix-your-shell.enable = true;
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
      pi-coding-agent
      geminicommit
      tgpt
      aichat
      mods
    ]
    ++ lib.optionals stdenv.isLinux [
      qwen-code
    ];
}
