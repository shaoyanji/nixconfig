#!/usr/bin/env bash
# scripts/task/site-routing.sh — each page offers the CV its record names.
#
#   site-routing.sh DIR CASES CASES_DE BRIEFS BRIEFS_DE
#
# The record is the routing table: `cv` on a case or brief names the tailored CV
# that argues for its subject. This reads the finished artifact and judges the
# HTML against those records, so a template that keeps a stale href, a page with
# two CV anchors, a locale that disagrees with its twin, or a variant the build
# never shipped is a failure here rather than a wrong PDF a reader downloads.
#
# site-links.sh already proves a CV anchor resolves and carries `download`. This
# proves it points at the subject the record chose, which no link check can see:
# `href="../cv-energy.pdf"` on the fleet page resolves, downloads, and is wrong.
#
# It runs inside the `matt-site` derivation (lib/matt-site.nix) before the link
# gate. The two home pages are part of the check — one CV per locale, the full
# one — because a header that quietly points at a tailored CV is the same defect
# from the other end.
#
# Exit: 0 every page agrees with its record, 1 a page does not, 2 bad input.
set -uo pipefail

dir=${1:?usage: site-routing.sh DIR CASES CASES_DE BRIEFS BRIEFS_DE}
shift
[ "$#" -eq 4 ] || {
  echo "site-routing: want four record files, got $#" >&2
  exit 2
}

python3 - "$dir" "$@" <<'PY'
import json
import os
import posixpath
import re
import sys

root = sys.argv[1]
record_paths = sys.argv[2:6]
records = []
for path in record_paths:
    with open(path, encoding="utf-8") as fh:
        records.append(json.load(fh))
cases_en, cases_de, briefs_en, briefs_de = records

ANCHOR = re.compile(r'<a\b[^>]*\bclass="cv"[^>]*>', re.I)
HREF = re.compile(r'\bhref="([^"]*)"', re.I)

bad = []
ok = 0
variants = set()


def cv_name(variant, lang):
    if variant == "full":
        return "cv-de.pdf" if lang == "de" else "cv.pdf"
    return f"cv-{variant}-de.pdf" if lang == "de" else f"cv-{variant}.pdf"


def check(page, expected):
    global ok
    path = os.path.join(root, page)
    if not os.path.isfile(path):
        bad.append(f"{page}: missing from the artifact")
        return
    with open(path, encoding="utf-8") as fh:
        text = fh.read()
    anchors = ANCHOR.findall(text)
    if len(anchors) != 1:
        bad.append(f"{page}: {len(anchors)} CV anchors (want exactly one)")
        return
    href = HREF.search(anchors[0])
    if href is None:
        bad.append(f"{page}: the CV anchor carries no href")
        return
    target = href.group(1).split("#")[0].split("?")[0]
    if target == "":
        bad.append(f"{page}: the CV anchor points at the page itself")
        return
    here = "/" + posixpath.dirname(page)
    resolved = posixpath.normpath(posixpath.join(here, target)).lstrip("/")
    if resolved != expected:
        bad.append(f"{page}: record names {expected}, page links {target}")
        return
    if not os.path.isfile(os.path.join(root, expected)):
        bad.append(f"{page}: links {expected}, which the artifact does not ship")
        return
    ok += 1


for kind, en, de, page_dir in (
    ("case", cases_en, cases_de, "work"),
    ("brief", briefs_en, briefs_de, "brief"),
):
    for slug, record in sorted(en.items()):
        variant = record.get("cv")
        if not variant:
            bad.append(f'{page_dir}/{slug}: the record names no CV (add "cv")')
            continue
        variants.add(variant)
        twin = de.get(slug)
        if twin is None:
            bad.append(f"de/{page_dir}/{slug}: the German record has no entry")
        elif twin.get("cv") != variant:
            bad.append(
                f"de/{page_dir}/{slug}: German record names {twin.get('cv') or 'no CV'},"
                f" English names {variant}"
            )
        check(f"{page_dir}/{slug}.html", cv_name(variant, "en"))
        check(f"de/{page_dir}/{slug}.html", cv_name(variant, "de"))

check("index.html", "cv.pdf")
check("de/index.html", "cv-de.pdf")

if bad:
    for line in bad:
        print(f"FAIL {line}")
    print(f"site-routing: {len(bad)} defect(s)")
    sys.exit(1)

print(
    f"site-routing: {ok} pages offer the CV their record names"
    f" ({len(variants)} variants: {', '.join(sorted(variants))})"
)
PY
