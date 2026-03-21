{
  lib,
  stdenvNoCC,
  fetchurl,
}:
stdenvNoCC.mkDerivation rec {
  pname = "nullclaw";
  version = "2026.3.18";

  src = fetchurl {
    url = "https://github.com/nullclaw/nullclaw/releases/download/v${version}/nullclaw-linux-x86_64.bin";
    sha256 = "9a67f2cdfea90a86f5e3a5c20b263096b419adb5092e42ff9f3e7fddd03eecb2";
  };

  dontUnpack = true;

  installPhase = ''
    install -Dm755 "$src" "$out/bin/nullclaw"
  '';

  meta = with lib; {
    description = "Fast, small AI assistant infrastructure written in Zig";
    homepage = "https://github.com/nullclaw/nullclaw";
    license = licenses.mit;
    mainProgram = "nullclaw";
    platforms = ["x86_64-linux"];
  };
}
