# lib/cv-ats-site.nix — the CV ATS audit as a published page.
#
# The audit already ran inside every `matt-cv-*` derivation, and nothing
# published what it found. This reads the same six PDFs back against the same
# records and emits one page plus `report.json`, from `matt-site`'s own CV
# outputs: the surface and the CVs it describes are one build, so a page cannot
# outlive the PDF it audited.
#
# A defect fails this derivation rather than rendering a red row: the shipped
# CVs fail first, and a published audit that lists failures would reach the web
# from a build that already refused to ship those CVs.
{
  pkgs,
  lib ? pkgs.lib,
  mattSite,
}: let
  check = ../scripts/task/cv-ats-check.sh;
in
  pkgs.runCommand "cv-ats-site" {
    nativeBuildInputs = [pkgs.python3 pkgs.poppler-utils];
  } ''
    mkdir -p $out records
    cp ${./cv-ats-report.py} report.py
    # The record is copied in under its CV's name so the audit line the page
    # publishes reads `records/cv-de.json`, not a store hash: the surface is for
    # a reader, and the path it names is one the reader can reason about.
    ${lib.concatMapStringsSep "\n" (c: ''
        cp ${c.record} records/${lib.removeSuffix ".pdf" c.name}.json
        bash ${check} --record records/${lib.removeSuffix ".pdf" c.name}.json ${c.src}/cv.pdf >$out/${c.name}.log 2>&1 || {
          cat $out/${c.name}.log >&2
          echo "cv-ats-site: ${c.name} does not match the record that built it" >&2
          exit 1
        }
      '')
      mattSite.cvFiles}
    python3 report.py $out
    cat >$out/robots.txt <<'EOF'
    User-agent: *
    Allow: /
    EOF
  ''
