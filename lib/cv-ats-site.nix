# The CV ATS audit as a published page: `lib/matt-site.nix` ships each PDF beside
# its record, `scripts/task/cv-ats-check.sh` reads them back, and a defect fails
# this derivation instead of rendering a red row (`lib/matt-site.nix`).
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
    mkdir -p $out/records
    cp ${./cv-ats-report.py} report.py
    # The record is published under its CV's name (`lib/matt-site.nix` writes it),
    # so the page links `records/cv-de.json`, not a store hash: under `$out`,
    # because a bare `records/` is the build directory the store drops.
    ${lib.concatMapStringsSep "\n" (c: ''
        cp ${c.record} $out/records/${lib.removeSuffix ".pdf" c.name}.json
        bash ${check} --record $out/records/${lib.removeSuffix ".pdf" c.name}.json ${c.src}/cv.pdf >$out/${c.name}.log 2>&1 || {
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
