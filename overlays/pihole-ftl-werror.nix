# Workaround: nixpkgs rev 4b10e4d (2026-10-06) cannot build pihole-ftl from
_final: prev: {
  pihole-ftl = prev.pihole-ftl.overrideAttrs (old: {
    NIX_CFLAGS_COMPILE = (old.NIX_CFLAGS_COMPILE or "") + " -Wno-unused-but-set-variable";
  });
}
