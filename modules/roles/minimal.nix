# `role:minimal`: base user stack + shell + AI, for containers and WSL.
{self, ...}: {
  # Base role contract: base user stack + shell base contract + AI.
  # Retired code lives in modules/roles/minimal.shadow.nix — importing it is a no-op.
  imports = [
    self.modules."user.base"
    self.modules."user.ai"
  ];
}
