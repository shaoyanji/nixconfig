{
  lib,
  stdenvNoCC,
  fetchurl,
}:
stdenvNoCC.mkDerivation rec {
  pname = "nullclaw";
  version = "2026.4.9";

  src = fetchurl {
    url = "https://github.com/nullclaw/nullclaw/releases/download/v${version}/nullclaw-linux-x86_64.bin";
    # sha256 = lib.fakeSha256;
    sha256 = "sha256-4O3mt+mixwqOd1/RSDhV/cik5WG4zod5G/657n5mOlM=";
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
