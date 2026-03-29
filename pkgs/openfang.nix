{
  lib,
  stdenvNoCC,
  fetchurl,
}:
stdenvNoCC.mkDerivation rec {
  pname = "openfang";
  version = "0.5.5";

  src = fetchurl {
    url = "https://github.com/RightNow-AI/openfang/releases/download/v${version}/openfang-x86_64-unknown-linux-gnu.tar.gz";
    sha256 = "sha256-V9fhoZI+xXSzekzNr4PZ5WuecIbzVK5WaEiPeFcxqb0=";
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
