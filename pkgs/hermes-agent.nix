{
  callPackage,
  lib,
  stdenv,
  python311,
  makeWrapper,
  nodejs_20,
  ripgrep,
  git,
  openssh,
  ffmpeg,
  uv2nix,
  pyproject-nix,
  pyproject-build-systems,
  src,
  version ? "main",
}:
let
  workspace = uv2nix.lib.workspace.loadWorkspace {
    workspaceRoot = src;
  };

  overlay = workspace.mkPyprojectOverlay {
    sourcePreference = "wheel";
  };

  pythonSet =
    (callPackage pyproject-nix.build.packages {
      python = python311;
    }).overrideScope
    (
      lib.composeManyExtensions [
        pyproject-build-systems.overlays.default
        overlay
      ]
    );

  hermesVenv = pythonSet.mkVirtualEnv "hermes-agent-env" {
    hermes-agent = [ "all" ];
  };
in
stdenv.mkDerivation {
  pname = "hermes-agent";
  inherit version src;

  nativeBuildInputs = [ makeWrapper ];

  dontBuild = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin $out/share/hermes-agent

    cp -r ${src}/skills $out/share/hermes-agent/

    for bin in hermes hermes-agent hermes-acp; do
      if [ -x ${hermesVenv}/bin/$bin ]; then
        makeWrapper ${hermesVenv}/bin/$bin $out/bin/$bin \
          --prefix PATH : ${
            lib.makeBinPath [
              nodejs_20
              ripgrep
              git
              openssh
              ffmpeg
            ]
          } \
          --set HERMES_BUNDLED_SKILLS $out/share/hermes-agent/skills
      fi
    done

    runHook postInstall
  '';

  passthru = {
    inherit hermesVenv;
    pythonRuntime = hermesVenv;
    pythonVersion = python311.pythonVersion;
    upstreamSrc = src;
    dependencySource = "upstream pyproject.toml via uv2nix/pyproject-nix";
  };

  meta = with lib; {
    description = "The self-improving AI agent by Nous Research";
    homepage = "https://github.com/NousResearch/hermes-agent";
    license = licenses.mit;
    mainProgram = "hermes";
    platforms = platforms.linux ++ platforms.darwin;
  };
}
