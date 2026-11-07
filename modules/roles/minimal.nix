# `role:minimal`: base user stack + shell + AI, for containers and WSL.
{
  self,
  lib,
  ...
}: {
  # Base role contract: base user stack + shell base contract + AI.
  imports = [
    self.modules."user.base"
    self.modules."user.ai"
  ];

  # One-time migration, deletable once every host has switched since 2026-11-07.
  # The retired Elixir sidecar resolved its interpreter into a GC-rooted
  # out-link (`~/.cache/nixconfig-kg/elixir`), which pins ~15 MB of BEAM in the
  # store forever; the scripts that wrote it are gone (96f41ea8), and a host that
  # is offline cannot be cleaned over ssh. Activation is the one path that
  # reaches those hosts, and it costs one `rm` when the path does not exist.
  home.activation.kgElixirRootCleanup = lib.hm.dag.entryAfter ["writeBoundary"] ''
    if [ -e "$HOME/.cache/nixconfig-kg" ]; then
      run rm -rf "$HOME/.cache/nixconfig-kg"
    fi
  '';
}
