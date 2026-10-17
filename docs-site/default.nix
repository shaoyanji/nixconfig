# ==============================================================================
# docs-site — HTML build of the documentation
# ==============================================================================
# The page list is NOT in this directory any more. `nav.json` is emitted by
# `lib/docs.nix` and passed in as `${docs}/nav.json`, so:
#
#   * generated pages (fleet inventory, modules registry, per-host) and the nav
#     entry that points at them are produced by the same expression — one cannot
#     list a page the build does not make;
#   * the site renders the exact bytes `nix build .#docs` produces, which
#     `task docs:sync` copies into `docs/generated/` for git readers.
#
# The generator itself stays a Python markdown renderer: converting markdown to
# HTML is a build-time formatting job, not a second source of truth. Everything
# declarative (which pages exist, their titles/links) lives in Nix.
# ==============================================================================
{
  stdenv,
  python3,
  python3Packages,
  # Generated docs tree + nav.json (flake output `docs`).
  docs,
}:
stdenv.mkDerivation {
  name = "nixconfig-docs-site";
  # Only the sources the generator reads; generated pages come from `docs`.
  src = ../.;
  nativeBuildInputs = [python3];
  buildInputs = [python3Packages.markdown];
  phases = ["buildPhase" "installPhase"];
  buildPhase = ''
    mkdir -p docsite
    python3 $src/docs-site/generate.py \
      --repo-root $src \
      --generated-root ${docs} \
      --nav ${docs}/nav.json \
      --out docsite
  '';
  installPhase = ''
    mkdir -p $out
    cp -r docsite/* $out/
  '';
  # The output is static files; fixup would only churn mtimes.
  dontFixup = true;
}
