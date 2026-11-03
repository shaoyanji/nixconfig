# `mkPacket` builds one application packet: typst in the sandbox, the artifact is
# the output path. Inputs are JSON Resume plus an application record.
# docs: modules/plugins/appflow/README.md
{pkgs}: {
  mkPacket = {
    application,
    resume,
    letter ? null,
    name ? "application",
  }:
    pkgs.runCommand "appflow-packet-${name}" {
      nativeBuildInputs = [pkgs.typst];
    } ''
      mkdir -p work "$out"
      cp ${./templates}/*.typ ${./templates}/strings.json work/
      cp ${resume} work/resume.json
      cp ${application} work/application.json

      typst compile --root work work/lebenslauf.typ "$out/lebenslauf.pdf"
      ${
        if letter == null
        then ''
          printf 'no letter.json supplied; rendered the CV only\n' > "$out/README"
        ''
        else ''
          cp ${letter} work/letter.json
          typst compile --root work work/anschreiben.typ "$out/anschreiben.pdf"
        ''
      }
    '';
}
