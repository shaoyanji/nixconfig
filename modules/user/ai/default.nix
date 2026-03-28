{pkgs, ...}: {
  imports = [
    ./codex.nix
    ./gemini-cli.nix
    ./mods.nix
    ./opencode.nix
    ./aichat.nix
  ];

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

  home.packages = with pkgs; [
    tgpt
    aichat
    mods
  ];
}
