final: _prev: {
  simplex-chat = final.stdenv.mkDerivation rec {
    pname = "simplex-chat";
    version = "7.0.3";

    src = final.fetchurl {
      url = "https://github.com/simplex-chat/simplex-chat/releases/download/v${version}/simplex-chat-ubuntu-22_04-x86_64";
      hash = "sha256-WvsdJe/lzPVkoasSS8f0EKenMXHJdKTYt/TY8uPWLnc=";
    };

    dontUnpack = true;

    nativeBuildInputs = [ final.autoPatchelfHook ];
    buildInputs = [ final.zlib final.openssl final.gmp final.stdenv.cc.cc.lib ];

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
}
