{
  lib,
  stdenvNoCC,
  fetchurl,
}:
stdenvNoCC.mkDerivation rec {
  pname = "openfang";
  version = "0.3.30";

  src = fetchurl {
    url = "https://github.com/RightNow-AI/openfang/releases/download/v${version}/openfang-x86_64-unknown-linux-gnu.tar.gz";
    sha256 = "1gd965bpi3s8d1bawm7khrq9wsz5v61szkacgarp9i9yjahy3msp";
  };

  dontUnpack = true;

  installPhase = ''
    runHook preInstall

    tar -xzf "$src"
    install -Dm755 openfang "$out/bin/openfang"

    runHook postInstall
  '';

  meta = with lib; {
    description = "Rust-based agent operating system binary";
    homepage = "https://github.com/RightNow-AI/openfang";
    license = with licenses; [mit asl20];
    mainProgram = "openfang";
    platforms = ["x86_64-linux"];
    sourceProvenance = [sourceTypes.binaryNativeCode];
  };
}
