# lib/gemtext.nix — the fleet documentation as a Gemini capsule.
#
# A projection, not a second tree: callers hand in the same markdown the docs
# pipeline and site already render (lib/docs.nix `generatedPages` plus the repo's
# own `.md`), and this turns each page into the `.gmi` page it becomes. The
# converter lives in ./gemtext/md2gemtext.py rather than in a '' string here, so
# it is linted and diffed like any other code.
#
# `cgi` scripts are installed under $out/cgi-bin as executable store files:
# molly-brown only executes a CGI when the resolved path is under a CGIPaths
# entry (and relative entries are joined to DocBase), so the capsule must own
# the directory it serves from.
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
