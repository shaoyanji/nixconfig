# `mkPacket`: one packet, typst in the sandbox, the artifact is $out.
#
# `jd` projects the resume corpus onto that description first; without it the file
# compiles as it always did. docs: modules/plugins/appflow/README.md
{pkgs}: let
  # The rules the site's CVs answer to as well: page budget, no barely-filled last
  # page (lib/typeset.nix).
  typeset = import ../../../lib/typeset.nix {inherit pkgs;};
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
    # Pages each document may make, exactly. The build measures the compiled
    # document and fails on a spillover, so a budget that stops fitting is a build
    # error instead of a second page carrying one line.
    pages ? 1,
    letterPages ? 1,
  }:
    pkgs.runCommand "appflow-packet-${name}" {
      nativeBuildInputs = [pkgs.typst pkgs.jq pkgs.poppler-utils pkgs.python3];
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
          cp ${./jdselect.py} work/jdselect.py
          cp ${./glossary.json} work/glossary.json
          ${pkgs.python3}/bin/python3 work/jdselect.py \
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

      # Tagged, like the site's CVs: the section headings reach the structure tree
      # instead of existing only as bold glyph runs an ATS has to guess at.
      typst compile --pdf-standard ua-1 --root work work/lebenslauf.typ "$out/lebenslauf.pdf"
      ${typeset.check {
        source = "work/lebenslauf.typ";
        budget = pages;
        doc = "lebenslauf.pdf";
      }}
      # The same read-back the site's four CVs get (lib/matt-site.nix `cvPdf`): the
      # finished PDF against the record it was compiled from. After a job-ad
      # selection `work/resume.json` is what the template was given, so a row the
      # selector dropped is not a defect while a row the template dropped is. The
      # language is the packet's own, which lives in application.json.
      bash ${../../../scripts/task/cv-ats-check.sh} --record work/resume.json \
        --application work/application.json "$out/lebenslauf.pdf"
      ${
        if letter == null
        then "printf 'no letter.json supplied; rendered the CV only\\n' > \"$out/README\""
        else ''
          cp ${letter} work/letter.json
          typst compile --root work work/anschreiben.typ "$out/anschreiben.pdf"
          ${typeset.check {
            source = "work/anschreiben.typ";
            budget = letterPages;
            doc = "anschreiben.pdf";
          }}
        ''
      }
    '';
}
