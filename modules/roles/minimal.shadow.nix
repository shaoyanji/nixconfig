# modules/roles/minimal.shadow.nix — code removed from modules/roles/minimal.nix.
# A *.shadow.nix is a valid empty module: importing it is a no-op, reviving is
# uncommenting. Addressable as roles.minimal.shadow under .#modules; removed
# packages belong in pkgs.txt — task checks:nix:comments gates this file too.
{...}: {
  # Expired migration dropped from modules/roles/minimal.nix at 887f4364 —
  # home.activation.kgElixirRootCleanup = lib.hm.dag.entryAfter ["writeBoundary"] ''
  #   cacheDir="$HOME/.cache/kg-elixir"
  #   if [ -d "$cacheDir" ]; then rm -rf "$cacheDir"; fi
  # '';
}
