# Needle 3 engine and weights, pinned once for every consumer; the engine URL is
# a revision, not `main`, since upstream deleted linux-arm64/. Packaging follows
# overlays/simplex-chat.nix: autoPatchelfHook, never patchelf by hand. docs/mail-agent.md.
{pkgs}: let
  version = "3";
in rec {
  engine = pkgs.stdenv.mkDerivation {
    pname = "needle";
    inherit version;
    src = pkgs.fetchurl {
      url = "https://huggingface.co/Cactus-Compute/needle3/resolve/d6c7d6a2e9655505e0f8e23339356dd1705900eb/linux-arm64/needle";
      hash = "sha256-p90H90B2NQftvKdg3H5wZbbaa2vWw6BSiMqXTxTOD8s=";
    };
    dontUnpack = true;
    nativeBuildInputs = [pkgs.autoPatchelfHook];
    buildInputs = [pkgs.stdenv.cc.cc.lib];
    installPhase = ''
      install -Dm755 $src $out/bin/needle
    '';
    meta = {
      description = "Needle 3 tool-calling engine (Simple Attention Network, byte-level grammar)";
      homepage = "https://huggingface.co/Cactus-Compute/needle3";
      license = pkgs.lib.licenses.asl20;
      mainProgram = "needle";
    };
  };

  # Weights are a separate file from the engine; the engine maps it in place.
  weights = pkgs.fetchurl {
    url = "https://huggingface.co/Cactus-Compute/needle3/resolve/main/needle3.cact";
    hash = "sha256-ydkV7KKC7ULRoJsUO1kq20zGdE/+LSlK31z8VUgXDDg=";
  };
}
