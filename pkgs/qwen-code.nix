{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
  makeWrapper,
  nodejs_20,
}:
buildNpmPackage rec {
  pname = "qwen-code";
  version = "0.14.3";

  src = fetchFromGitHub {
    owner = "QwenLM";
    repo = "qwen-code";
    rev = "v${version}";
    hash = "sha256-05hiad8aid4aw16py0rjz2mqzz0s54j71zn9r3vkpwxgjz0nbmj6=";
  };
  npmDepsHash = "sha256-eGqLW0KStAXAEJRv5Ob/nJJRjIZVLNUBjIdokUrgwFw=";
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

    makeWrapper ${nodejs_20}/bin/node $out/bin/qwen \
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
