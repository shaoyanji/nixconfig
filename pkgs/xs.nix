{
  lib,
  stdenvNoCC,
  fetchurl,
}:
stdenvNoCC.mkDerivation rec {
  pname = "xs";
  version = "0.11.0";

  src = fetchurl {
    url = "https://github.com/cablehead/xs/releases/download/v${version}/cross-stream-v${version}-linux-amd64.tar.gz";
    sha256 = "sha256-TiK/ZT64eNKvjYTKprQqwDpavnfsLEg+82qOzI1UmFA=";
  };

  dontUnpack = true;

  installPhase = ''
    runHook preInstall

    tar -xzf "$src"
    install -Dm755 "cross-stream-v${version}/xs" "$out/bin/xs"

    runHook postInstall
  '';

  meta = with lib; {
    description = "Event store runtime binary";
    homepage = "https://github.com/cablehead/xs";
    license = licenses.mit;
    mainProgram = "xs";
    platforms = ["x86_64-linux"];
    sourceProvenance = [sourceTypes.binaryNativeCode];
  };
}
