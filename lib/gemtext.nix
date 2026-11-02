# lib/gemtext.nix — markdown to gemtext for the capsule, a projection of the same
# pages the docs artifact renders. Converter: ./gemtext/md2gemtext.py. CGI installs
# under $out/cgi-bin — molly-brown runs only what a CGIPaths entry resolves to.
{
  lib,
  pkgs,
  pages,
  cgi ? {},
  title ? "fleet.frieren.lan",
  description ? "The fleet's documentation over the Gemini protocol: host inventory, module registry, runbooks and project notes.",
}: let
  slug = path: lib.replaceStrings ["/"] ["-"] path;

  installPage = path: text: ''
    install -Dm644 ${pkgs.writeText "gemtext-src-${slug path}" text} $src/${path}
  '';

  installCgi = name: text: ''
    install -Dm755 ${pkgs.writeShellScript "gemini-cgi-${name}" text} $out/cgi-bin/${name}
  '';
in
  pkgs.runCommand "fleet-gemini-capsule" {
    nativeBuildInputs = [pkgs.python3];
    meta.description = "fleet.frieren.lan as gemtext, with CGI under /cgi-bin";
  } ''
    src=$TMPDIR/src
    mkdir -p $src $out $out/cgi-bin
    ${lib.concatStringsSep "\n" (lib.mapAttrsToList installPage pages)}
    python3 ${./gemtext/md2gemtext.py} $src $out ${lib.escapeShellArg title} ${lib.escapeShellArg description}
    ${lib.concatStringsSep "\n" (lib.mapAttrsToList installCgi cgi)}
    cat >> $out/index.gmi <<'EOF'

    ## Dynamic content

    => /cgi-bin/hello hello — proves CGIPaths is wired to this capsule
    EOF
  ''
