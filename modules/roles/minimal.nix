{...}: {
  # Base role contract: base user stack + shell base contract + AI.
  imports = [
    ../user/base/default.nix
    ../user/ai/default.nix
  ];
}
