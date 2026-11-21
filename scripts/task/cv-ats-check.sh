#!/usr/bin/env bash
# cv-ats-check.sh — a shipped CV's text must still be its record's text.
#
# The build compiles the PDF from a record, but nothing proved the PDF still said
# what the record says. A heading that becomes a house word, a role the template
# loop drops, a URL that exists only as a link target, or a word hyphenated at a
# line end all compile cleanly: each is invisible to `typst compile` and to the
# page-count report in lib/typeset.nix, and each is a defect an applicant tracking
# system sees instead of the document.
#
# So this reads the finished PDF back rather than the source: `pdftotext` in
# reading order (not `-layout`, which reintroduces the columns the template
# removed), the lines for headings, and the whitespace-flattened text for the
# record's own strings. Link annotations are allowed over their own visible
# address; a link label with no address in the text is not.
#
# The record is the payload the build generated for this document, so the
# comparison is PDF against the data it was built from. A site build is a pure
# derivation and cannot read the applications table; `task career:export` is what
# carries a row change into the JSON.
#
# Two dialects reach it, because two builders emit a CV:
#   * the site's payload (`profile`, `labels`, `work[].title`) — lib/matt-site.nix,
#     four PDFs through one `cvPdf` builder;
#   * the packet's JSON Resume (`basics`, `work[].position`) — packet.nix, whose
#     language lives in `application.json`, hence `--application`.
#
# Usage: cv-ats-check.sh --record RECORD.json [--application APP.json] PDF
# Exit: 0 parity holds, 1 a property is missing, 2 bad usage or no pdftotext.
set -uo pipefail

record=""
application=""
pdf=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --record)
      record=${2:?--record needs a file}
      shift 2
      ;;
    --application)
      application=${2:?--application needs a file}
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
  echo "cv-ats-check: no record (usage: cv-ats-check.sh --record RECORD.json [--application APP.json] PDF)" >&2
  exit 2
}
[ -z "$application" ] || [ -f "$application" ] || {
  echo "cv-ats-check: --application $application does not exist" >&2
  exit 2
}
[ -n "$pdf" ] && [ -f "$pdf" ] || {
  echo "cv-ats-check: no PDF (usage: cv-ats-check.sh --record RECORD.json [--application APP.json] PDF)" >&2
  exit 2
}
command -v pdftotext >/dev/null 2>&1 || {
  echo "cv-ats-check: pdftotext (poppler) missing" >&2
  exit 2
}

python3 - "$record" "$pdf" "$application" <<'PY'
import json
import os
import re
import subprocess
import sys

record_path, pdf_path, application_path = sys.argv[1], sys.argv[2], sys.argv[3]

with open(record_path, encoding="utf-8") as fh:
    record = json.load(fh)
application = {}
if application_path:
    with open(application_path, encoding="utf-8") as fh:
        application = json.load(fh)

# The dialect decides only where the same facts are spelled; the properties asked
# of the finished PDF are the same for both.
resume = "basics" in record
if resume:
    lang = application.get("language") or record.get("lang")
    if not lang:
        print("cv-ats-check: a JSON Resume carries no language; pass --application with `language`", file=sys.stderr)
        sys.exit(2)
else:
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

basics = record.get("basics") or {}
profile = record.get("profile") or {}

problems = []


def fail(message):
    problems.append(message)


# The headings this document must carry. A JSON Resume prints only the sections it
# has data for, so requiring the other words would fail a truthful document; the
# site payload always carries all five, and its `labels` must already be the
# standard words rather than a house variant of them.
sections = []
if resume:
    # A JSON Resume spells the experience section `work`; without this map the one
    # heading every CV has would be the one the check never asked for.
    for key, word in STANDARD[lang]:
        if record.get({"experience": "work"}.get(key, key)):
            sections.append((key, word))
else:
    labels = record.get("labels") or {}
    for key, word in STANDARD[lang]:
        got = labels.get(key)
        if got != word:
            fail(f"the record's {key!r} heading is {got!r}; the ATS word is {word!r}")
        sections.append((key, word))


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


name = basics.get("name", "") if resume else profile.get("name", "")
if not name:
    fail("the record carries no name")
elif not any(name in line for line in lines[:3]):
    fail(f"the name {name!r} is not in the first three extracted lines — a footer or a second column moved it")

# Contact details as body text: the packet's header row joins them with a bullet,
# so the address and the town are checked rather than the separator.
if resume:
    present("email", basics.get("email", ""))
    present("city", (basics.get("location") or {}).get("city", ""))
else:
    present("contact", profile.get("handle", ""))
    # The CV header prints the place, not the "· remote (...)" work-mode note
    # the site header carries; check the part the document is meant to show.
    present("location", profile.get("location", "").split(" · ")[0])

positions = []
for key, word in sections:
    hit = next((i for i, line in enumerate(lines) if line == word), None)
    if hit is None:
        fail(f"heading {word!r} is not a line of the extracted text — an ATS matches the word, not an uppercased or house-style variant")
    else:
        positions.append((key, hit))
for (k1, p1), (k2, p2) in zip(positions, positions[1:]):
    if p2 <= p1:
        fail(f"heading {k2!r} is read before {k1!r} — the sections are out of reading order")

if resume:
    for job in record.get("work") or []:
        present("work employer", job.get("name", ""))
        present("work role", job.get("position", ""))
    # The Lebenslauf prints every project it is given, so every one is checked; the
    # site's template renders the first six and the rest are the page's material.
    for project in record.get("projects") or []:
        present("project", project.get("name", ""))
    for study in record.get("education") or []:
        present("school", study.get("institution", ""))
        present("degree", study.get("studyType", ""))
        present("field", study.get("area", ""))
    for skill in record.get("skills") or []:
        present("skill group", skill.get("name", ""))
    for spoken in record.get("languages") or []:
        present("language", spoken.get("language", ""))
        present("fluency", spoken.get("fluency", ""))
else:
    for w in record.get("work") or []:
        present("work title", w.get("title", ""))
        present("work role", w.get("role", ""))
    for e in record.get("education") or []:
        present("degree", e.get("degree", ""))
        present("school", e.get("school", ""))
    for e in (record.get("projects") or [])[:6]:
        present("project", e.get("name", ""))
    for s in record.get("stack") or []:
        present("skill group", s.get("category", ""))

# A structure tree is what lets a parser read `/H2 Experience` instead of guessing
# a heading from a larger bold run. It is a compile flag (`--pdf-standard ua-1`),
# so it is the kind of property that disappears in a refactor without any text
# changing — hence the assertion rather than a comment.
info = subprocess.run(["pdfinfo", pdf_path], capture_output=True, text=True).stdout
tagged = re.search(r"^Tagged:\s+(\w+)", info, re.M)
if not tagged or tagged.group(1).lower() != "yes":
    fail("the PDF is not tagged (Tagged: no) — a parser has to rebuild the headings from glyph positions")

for i, line in enumerate(raw[:-1]):
    if re.search(r"[A-Za-z]-$", line) and raw[i + 1][:1].islower():
        fail(f"a line ends in a hyphen and continues lowercase ({line.strip()[-30:]!r} / {raw[i + 1].strip()[:20]!r}) — a hyphenated word is the one a parser stops matching")

doc = os.path.basename(pdf_path)
dialect = ", jsonresume" if resume else ""
print(f"cv-ats-check: {doc} <- {os.path.basename(record_path)} ({lang}{dialect})")
if problems:
    for problem in problems:
        print(f"FAIL {problem}")
    print(f"cv-ats-check: {len(problems)} defect(s)")
    sys.exit(1)

print("ok   headings in reading order: " + ", ".join(word for _, word in sections))
if resume:
    print(
        f"ok   {len(record.get('work') or [])} work entries, {len(record.get('projects') or [])} projects, "
        f"{len(record.get('education') or [])} degrees, {len(record.get('skills') or [])} skill groups, "
        f"{len(record.get('languages') or [])} languages from the record are in the text"
    )
else:
    print(
        f"ok   {len(record.get('work') or [])} work entries, {len((record.get('projects') or [])[:6])} projects, "
        f"{len(record.get('education') or [])} degrees, {len(record.get('stack') or [])} skill groups from the record are in the text"
    )
print("ok   name first, contact in the body, visible URLs, no hyphenated line end")
print(f"cv-ats-check: {doc} matches the record")
PY
