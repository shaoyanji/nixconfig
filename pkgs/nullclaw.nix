{
  lib,
  stdenvNoCC,
  fetchurl,
}:
stdenvNoCC.mkDerivation rec {
  pname = "nullclaw";
  version = "2026.4.17";

  src = fetchurl {
    url = "https://github.com/nullclaw/nullclaw/releases/download/v${version}/nullclaw-linux-x86_64.bin";
    # sha256 = lib.fakeSha256;
    sha256 = "sha256-iUlNt4qd+w1+UxVQV1/TQz38ep2UuG12POoK6HCjZBw=";
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
