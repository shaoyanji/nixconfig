# `role:minimal`: base user stack + shell + AI, for containers and WSL.
{self, ...}: {
  # Base role contract: base user stack + shell base contract + AI.
  imports = [
    self.modules."user.base"
    self.modules."user.ai"
  ];
}
