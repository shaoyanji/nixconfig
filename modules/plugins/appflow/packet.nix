# `mkPacket`: one packet, typst in the sandbox, the artifact is $out.
#
# `jd` projects the resume corpus onto that description first; without it the file
# compiles as it always did. docs: modules/plugins/appflow/README.md
{pkgs}: let
  lib = pkgs.lib;
in {
  mkPacket = {
    application,
    resume,
    letter ? null,
    name ? "application",
    jd ? null,
    # The page budget, not the corpus: four highlights per role and four projects
    # is about one A4 page of material.
    select ? {},
  }:
    pkgs.runCommand "appflow-packet-${name}" {
      nativeBuildInputs = [pkgs.typst] ++ lib.optional (jd != null) pkgs.python3;
    } ''
      mkdir -p work "$out"
      cp ${./templates}/*.typ ${./templates}/strings.json work/
      cp ${resume} work/source.json
      cp ${application} work/application.json

      ${
        if jd == null
        then ''
          cp work/source.json work/resume.json
        ''
        else ''
          cp ${jd} work/jd.txt
          cp ${./select.py} work/select.py
          cp ${./glossary.json} work/glossary.json
          ${pkgs.python3}/bin/python3 work/select.py \
            --resume work/source.json \
            --jd work/jd.txt \
            --out work/resume.json \
            --audit "$out/selection.json" \
            --max-highlights ${toString (select.maxHighlights or 4)} \
            --min-highlights ${toString (select.minHighlights or 1)} \
            --max-projects ${toString (select.maxProjects or 4)} \
            --min-projects ${toString (select.minProjects or 1)} \
            --max-keywords ${toString (select.maxKeywords or 6)}
        ''
      }

      typst compile --root work work/lebenslauf.typ "$out/lebenslauf.pdf"
      ${
        if letter == null
        then "printf 'no letter.json supplied; rendered the CV only\\n' > \"$out/README\""
        else ''
          cp ${letter} work/letter.json
          typst compile --root work work/anschreiben.typ "$out/anschreiben.pdf"
        ''
      }
    '';
}
