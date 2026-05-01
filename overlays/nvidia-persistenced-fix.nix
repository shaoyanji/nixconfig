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

  # Also fix legacy versions that have the same issue
  nvidia_x11_470 = prev.nvidia_x11_470.overrideAttrs (old: {
    makeFlags = old.makeFlags or [];
  }) // {
    persistenced = prev.nvidia_x11_470.persistenced.overrideAttrs (old: {
      makeFlags = [ "DATE=true" ];
    });
  };

  nvidia_x11_535 = prev.nvidia_x11_535.overrideAttrs (old: {
    makeFlags = old.makeFlags or [];
  }) // {
    persistenced = prev.nvidia_x11_535.persistenced.overrideAttrs (old: {
      makeFlags = [ "DATE=true" ];
    });
  };

  nvidia_x11_545 = prev.nvidia_x11_545.overrideAttrs (old: {
    makeFlags = old.makeFlags or [];
  }) // {
    persistenced = prev.nvidia_x11_545.persistenced.overrideAttrs (old: {
      makeFlags = [ "DATE=true" ];
    });
  };
}