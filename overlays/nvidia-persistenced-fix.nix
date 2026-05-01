# Fix for nixpkgs bug where nvidia_x11.persistenced tries to access missing makeFlags
# See: https://github.com/NixOS/nixpkgs/issues/...
final: prev: {
  nvidia_x11 = prev.nvidia_x11 // {
    persistenced = prev.nvidia_x11.persistenced.overrideAttrs (old: {
      makeFlags = old.makeFlags or [];
    });
  };
}