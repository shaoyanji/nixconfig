# Needle 3 tool router: 121M params (mostly engram) at ~2.1 bits, 34 MB weights.
# A CLI, not a daemon — `--serve` latched onto one tool after ~40 turns.
# Packaging follows overlays/simplex-chat.nix: autoPatchelfHook, never patchelf.
{pkgs, ...}: let
  version = "3";

  engine = pkgs.stdenv.mkDerivation {
    pname = "needle";
    inherit version;
    src = pkgs.fetchurl {
      url = "https://huggingface.co/Cactus-Compute/needle3/resolve/main/linux-arm64/needle";
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
in {
  environment.systemPackages = [
    (pkgs.writeShellScriptBin "needle-route" ''
      exec ${engine}/bin/needle --model ${weights} --tools ${./needle-tools.json} --prompt "$*"
    '')
  ];
}
