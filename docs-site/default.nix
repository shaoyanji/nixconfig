{ stdenv, python3, python3Packages }:

stdenv.mkDerivation {
  name = "nixconfig-docs-site";
  src = ../.;
  nativeBuildInputs = [ python3 ];
  buildInputs = [ python3Packages.markdown ];
  phases = [ "buildPhase" "installPhase" ];
  buildPhase = ''
    mkdir -p docsite
    python3 $src/docs-site/generate.py --repo-root $src --out docsite
  '';
  installPhase = ''
    mkdir -p $out
    cp -r docsite/* $out/
  '';
  dontFixup = true;
}
