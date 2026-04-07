{
  lib,
  bash,
  writeShellApplication,
  coreutils,
  file,
  gawk,
  gnugrep,
  gnused,
  jq,
  python3,
  util-linux,
  xs,
  xs-materializer,
}:
writeShellApplication {
  name = "xs-helper";

  runtimeInputs = [
    coreutils
    file
    gawk
    gnugrep
    gnused
    jq
    python3
    util-linux
    xs
    xs-materializer
  ];

  text = ''
    export XS_BIN="${xs}/bin/xs"
    export XS_MATERIALIZER_BIN="${xs-materializer}/bin/xs-materializer"
    exec ${bash}/bin/bash ${../scripts/task/xs-helper.sh} "$@"
  '';

  meta = with lib; {
    description = "Shell-first helper CLI for local xs dogfooding";
    mainProgram = "xs-helper";
    license = licenses.mit;
    platforms = platforms.linux;
  };
}
