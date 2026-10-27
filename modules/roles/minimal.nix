# `role:minimal`: base user stack + shell + AI, for containers and WSL.
_: {
  # Base role contract: base user stack + shell base contract + AI.
  imports = [
    ../user/base.nix
    ../user/ai/default.nix
  ];
}
