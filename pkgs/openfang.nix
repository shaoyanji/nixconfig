{
  lib,
  stdenvNoCC,
  fetchurl,
}:
stdenvNoCC.mkDerivation rec {
  pname = "openfang";
  version = "0.5.9";

  src = fetchurl {
    url = "https://github.com/RightNow-AI/openfang/releases/download/v${version}/openfang-x86_64-unknown-linux-gnu.tar.gz";
    sha256 = "sha256-ZDaGfTb3o9opWpitRTew0wbNwrusALxB+gK8wtqQZxI=";
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
