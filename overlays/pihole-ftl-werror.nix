# Workaround: nixpkgs rev 4b10e4d (2026-10-06) cannot build pihole-ftl from
# source on x86_64-linux:
#
#   src/config/validator.c:824:13: error: variable 'i' set but not used
#   [-Werror=unused-but-set-variable=]
#   cc1: all warnings being treated as errors
#
# The package compiles with -Werror, and the compiler at this rev promotes
# that warning to an error, so no binary cache has a substitute for it —
# hydra/nixbuild.net both fail the same way. Disabling the warning entirely
# (rather than -Wno-error=…) is order-independent: -Werror can only promote
# warnings that are still enabled.
#
# Applied only to frieren (the sole host running pihole-ftl). Promote this to
# flake/pkgs-for.nix if another host ever enables pihole. Drop the override
# once upstream fixes the unused variable or the cache catches up.
_final: prev: {
  pihole-ftl = prev.pihole-ftl.overrideAttrs (old: {
    NIX_CFLAGS_COMPILE = (old.NIX_CFLAGS_COMPILE or "") + " -Wno-unused-but-set-variable";
  });
}
