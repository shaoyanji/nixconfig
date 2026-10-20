_: {
  # Base role contract: base user stack + shell base contract + AI.
  imports = [
    ../user/base.nix
    ../user/ai/default.nix
  ];
}
