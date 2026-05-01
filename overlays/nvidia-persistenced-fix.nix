# Fix for nixpkgs bug where nvidia_x11.persistenced tries to access missing makeFlags
# See: https://github.com/NixOS/nixpkgs/issues/...
final: prev: {
  nvidia_x11 = prev.nvidia_x11.overrideAttrs (old: {
    makeFlags = old.makeFlags or [];
  }) // {
    persistenced = prev.nvidia_x11.persistenced.overrideAttrs (old: {
      # Override the broken makeFlags line that references nvidia_x11.makeFlags
      makeFlags = [ "DATE=true" ];
    });
  };
}