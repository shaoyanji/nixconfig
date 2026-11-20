#!/usr/bin/env bash
# cv-ats-check.sh — the shipped CV's text must still be the record's text.
#
# The build compiles cv.pdf from cv.json, but nothing proved the PDF still said
# what the record says. A heading that becomes a house word, a role the template
# loop drops, a link annotation that comes back, or a word hyphenated at a line
# end all compile cleanly: each is invisible to `typst compile` and to the
# page-count report in lib/typeset.nix, and each is a defect an applicant tracking
# system sees instead of the document.
#
# So this reads the finished PDF back rather than the source: `pdftotext` in
# reading order (not `-layout`, which reintroduces the columns the template
# removed), the lines for headings, the whitespace-flattened text for the record's
# own strings, and the raw bytes for annotations.
#
# The record is the payload the build generated for this document, so the
# comparison is PDF against the data it was built from. A site build is a pure
# derivation and cannot read the applications table; `task career:export` is what
# carries a row change into the JSON.
#
# Usage: cv-ats-check.sh --record RECORD.json PDF
# Exit: 0 parity holds, 1 a property is missing, 2 bad usage or no pdftotext.
set -uo pipefail

record=""
pdf=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --record)
      record=${2:?--record needs a file}
      shift 2
      ;;
    -?*)
      echo "cv-ats-check: unknown option $1" >&2
      exit 2
      ;;
    *)
      pdf=$1
      shift
      ;;
  esac
done

[ -n "$record" ] && [ -f "$record" ] || {
  echo "cv-ats-check: no record (usage: cv-ats-check.sh --record RECORD.json PDF)" >&2
  exit 2
}
[ -n "$pdf" ] && [ -f "$pdf" ] || {
  echo "cv-ats-check: no PDF (usage: cv-ats-check.sh --record RECORD.json PDF)" >&2
  exit 2
}
command -v pdftotext >/dev/null 2>&1 || {
  echo "cv-ats-check: pdftotext (poppler) missing" >&2
  exit 2
}

python3 - "$record" "$pdf" <<'PY'
import json
import os
import re
import subprocess
import sys

record_path, pdf_path = sys.argv[1], sys.argv[2]

with open(record_path, encoding="utf-8") as fh:
    record = json.load(fh)

lang = record.get("lang", "en")
# The fixed vocabulary an applicant tracking system classifies sections by. It is
# written here rather than read from the build's `labels` because agreeing with
# itself is not the property: the record has to use the words a parser knows.
STANDARD = {
    "en": [
        ("experience", "Experience"),
        ("projects", "Projects"),
        ("education", "Education"),
        ("skills", "Skills"),
        ("languages", "Languages"),
    ],
    "de": [
        ("experience", "Berufserfahrung"),
        ("projects", "Projekte"),
        ("education", "Ausbildung"),
        ("skills", "Kenntnisse"),
        ("languages", "Sprachen"),
    ],
}
if lang not in STANDARD:
    print(f"cv-ats-check: the record's language is {lang!r}; no ATS vocabulary for it", file=sys.stderr)
    sys.exit(2)

labels = record.get("labels") or {}
profile = record.get("profile") or {}
work = record.get("work") or []
education = record.get("education") or []
# The template renders the first six projects; the rest are the page's material.
projects = (record.get("projects") or [])[:6]
stack = record.get("stack") or []

problems = []


def fail(message):
    problems.append(message)


run = subprocess.run(["pdftotext", "-q", pdf_path, "-"], capture_output=True, text=True)
if run.returncode != 0:
    print(f"cv-ats-check: pdftotext failed on {pdf_path}", file=sys.stderr)
    sys.exit(2)

raw = run.stdout.replace("\f", "\n").splitlines()
lines = [line.strip() for line in raw if line.strip()]
flat = " ".join(run.stdout.split())


def present(label, value):
    if value and value not in flat:
        fail(f"{label} {value!r} is in the record and not in the PDF — a row the template dropped")


for key, word in STANDARD[lang]:
    got = labels.get(key)
    if got != word:
        fail(f"the record's {key!r} heading is {got!r}; the ATS word is {word!r}")

name = profile.get("name", "")
if not name:
    fail("the record carries no profile.name")
elif not any(name in line for line in lines[:3]):
    fail(f"the name {name!r} is not in the first three extracted lines — a footer or a second column moved it")
present("contact", profile.get("handle", ""))
present("location", profile.get("location", ""))

positions = []
for key, word in STANDARD[lang]:
    want = labels.get(key, word)
    hit = next((i for i, line in enumerate(lines) if line == want), None)
    if hit is None:
        fail(f"heading {want!r} is not a line of the extracted text — an ATS matches the word, not an uppercased or house-style variant")
    else:
        positions.append((key, hit))
for (k1, p1), (k2, p2) in zip(positions, positions[1:]):
    if p2 <= p1:
        fail(f"heading {k2!r} is read before {k1!r} — the sections are out of reading order")

for w in work:
    present("work title", w.get("title", ""))
    present("work role", w.get("role", ""))
for e in education:
    present("degree", e.get("degree", ""))
    present("school", e.get("school", ""))
for e in projects:
    present("project", e.get("name", ""))
for s in stack:
    present("skill group", s.get("category", ""))

with open(pdf_path, "rb") as fh:
    blob = fh.read()
if b"/URI" in blob:
    fail("the PDF carries a /URI annotation — a parser that strips link annotations can drop the address or its text")

for i, line in enumerate(raw[:-1]):
    if re.search(r"[A-Za-z]-$", line) and raw[i + 1][:1].islower():
        fail(f"a line ends in a hyphen and continues lowercase ({line.strip()[-30:]!r} / {raw[i + 1].strip()[:20]!r}) — a hyphenated word is the one a parser stops matching")

doc = os.path.basename(pdf_path)
print(f"cv-ats-check: {doc} <- {os.path.basename(record_path)} ({lang})")
if problems:
    for problem in problems:
        print(f"FAIL {problem}")
    print(f"cv-ats-check: {len(problems)} defect(s)")
    sys.exit(1)

print("ok   headings in reading order: " + ", ".join(word for _, word in STANDARD[lang]))
print(f"ok   {len(work)} work entries, {len(projects)} projects, {len(education)} degrees, {len(stack)} skill groups from the record are in the text")
print("ok   name first, contact in the body, no /URI annotation, no hyphenated line end")
print(f"cv-ats-check: {doc} matches the record")
PY
