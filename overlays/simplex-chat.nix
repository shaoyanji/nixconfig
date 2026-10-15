final: _prev: {
  simplex-chat = final.stdenv.mkDerivation rec {
    pname = "simplex-chat";
    version = "7.0.3";

    src = final.fetchurl {
      url = "https://github.com/simplex-chat/simplex-chat/releases/download/v${version}/simplex-chat-ubuntu-22_04-x86_64";
      hash = "sha256-WvsdJe/lzPVkoasSS8f0EKenMXHJdKTYt/TY8uPWLnc=";
    };

    dontUnpack = true;

    nativeBuildInputs = [final.autoPatchelfHook];
    buildInputs = [final.zlib final.openssl final.gmp final.stdenv.cc.cc.lib];

    installPhase = ''
      install -Dm755 $src $out/bin/simplex-chat
    '';

    meta = with final.lib; {
      description = "SimpleX Chat CLI and WebSocket daemon";
      homepage = "https://simplex.chat";
      license = licenses.agpl3Only;
      platforms = ["x86_64-linux"];
      mainProgram = "simplex-chat";
    };
  };

  smp-server = final.stdenv.mkDerivation rec {
    pname = "smp-server";
    version = "6.5.0";

    src = final.fetchurl {
      url = "https://github.com/simplex-chat/simplexmq/releases/download/v${version}/smp-server-ubuntu-22_04-x86-64";
      hash = "sha256-8eVT2Kt6aHxE/62Sf9Z3QyLsAYby9gtPV+UniMksJGs=";
    };

    dontUnpack = true;

    nativeBuildInputs = [final.autoPatchelfHook];
    buildInputs = [final.zlib final.openssl final.gmp final.stdenv.cc.cc.lib];

    installPhase = ''
      install -Dm755 $src $out/bin/smp-server
    '';

    meta = with final.lib; {
      description = "SimpleX Messaging Protocol (SMP) server broker";
      homepage = "https://simplex.chat";
      license = licenses.agpl3Only;
      platforms = ["x86_64-linux"];
      mainProgram = "smp-server";
    };
  };
}
