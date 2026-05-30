{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
  makeWrapper,
  nodejs_22,
}:
buildNpmPackage rec {
  pname = "qwen-code";
  version = "0.14.3";

  src = fetchFromGitHub {
    owner = "QwenLM";
    repo = "qwen-code";
    rev = "v${version}";
    hash = "sha256-RtZlwZev8zv3yMn+cCQpGvyPq/gyA39N4Iq0qFBTERY=";
  };
  npmDepsHash = "sha256-13YseUyf7l3XwdsE4cGlXRbpK0zeADC6sGniKoEgGzk=";
  npmDepsFetcherVersion = 2;
  nativeBuildInputs = [makeWrapper];

  # Qwen's repo separates workspace build from final CLI bundle packaging.
  buildPhase = ''
    runHook preBuild

    npm run build
    npm run bundle
    npm run prepare:package

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib/qwen-code $out/bin
    cp -r dist/* $out/lib/qwen-code/

    makeWrapper ${nodejs_22}/bin/node $out/bin/qwen \
      --add-flags "$out/lib/qwen-code/cli.js"

    runHook postInstall
  '';

  meta = with lib; {
    description = "Qwen Code terminal coding agent";
    homepage = "https://github.com/QwenLM/qwen-code";
    license = licenses.asl20;
    mainProgram = "qwen";
    platforms = platforms.linux ++ platforms.darwin;
  };
}
