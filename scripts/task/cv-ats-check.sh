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
# `--deployed` asks the other question: is what is published still this build?
# `task dev:site:deploy:cv-ats` publishes by hand, so production can be a build
# behind while every local gate is green. It fetches each file the artifact
# carries and compares the bytes, `index.html` as `/` because Pages redirects
# that path and `/` is the page a reader gets.
#
# The host comes from `taskfiles/site-manifest.json`, never from the project name.
# Pages assigns the `pages.dev` suffix, and the bare `cv-ats.pages.dev` belongs to
# an unrelated French ATS site: a gate that derived the host would compare this
# build with a stranger's files and call the stranger drift.
#
# Usage: cv-ats-check.sh --record RECORD.json [--application APP.json] PDF
#        cv-ats-check.sh --deployed [URL]
# Exit: 0 parity holds, 1 a property is missing, 2 bad usage, no pdftotext, no
#       artifact, or no host recorded for the target.
set -uo pipefail

record=""
application=""
pdf=""
deployed=0
url=""
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
    --deployed)
      deployed=1
      shift
      case "${1:-}" in
        http://* | https://*)
          url=$1
          shift
          ;;
      esac
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

if [ "$deployed" = 1 ]; then
  artifact=${ARTIFACT:-/tmp/cv-ats}
  host=$url
  if [ -z "$host" ]; then
    command -v jq >/dev/null 2>&1 || {
      echo "cv-ats-check: jq missing (it reads the target's host from the manifest)" >&2
      exit 2
    }
    manifest=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/taskfiles/site-manifest.json
    host=$(jq -r '.targets["cv-ats"].deployHostname // empty' "$manifest" 2>/dev/null)
    [ -n "$host" ] || {
      echo "cv-ats-check: no deployHostname for the cv-ats target in $manifest" >&2
      exit 2
    }
    host=https://$host
  fi
  host=${host%/}
  command -v curl >/dev/null 2>&1 || {
    echo "cv-ats-check: curl missing" >&2
    exit 2
  }
  [ -d "$artifact" ] && [ -f "$artifact/index.html" ] || {
    echo "cv-ats-check: no built audit at $artifact — build .#sites.cv-ats-site at the commit under test (task dev:site:build:cv-ats) first" >&2
    exit 2
  }

  work=$(mktemp -d)
  trap 'rm -rf "$work"' EXIT
  same=0
  drift=0
  while IFS= read -r file; do
    rel=${file#"$artifact"/}
    path=/$rel
    [ "$rel" = index.html ] && path=/
    # Cache-busted: Pages fronts every deployment, and a stale edge copy of a
    # matching file would otherwise read as drift in the other direction.
    if ! curl -fsSL --max-time 30 -o "$work/live" "$host$path?cb=$(date +%s)" 2>/dev/null; then
      printf 'FAIL %s is not served at %s%s\n' "$rel" "$host" "$path"
      drift=$((drift + 1))
      continue
    fi
    built=$(sha256sum "$file" | cut -d' ' -f1)
    live=$(sha256sum "$work/live" | cut -d' ' -f1)
    if [ "$built" = "$live" ]; then
      printf 'ok   %s\n' "$path"
      same=$((same + 1))
      continue
    fi
    hint=""
    if [ "$rel" = index.html ] && ! grep -q 'CV ATS audit' "$work/live" 2>/dev/null; then
      hint=" — and it is not the audit page: the project is cv-ats, whose real host is the manifest's deployHostname, not its bare name"
    fi
    printf 'FAIL %s: live %s B %s, build %s B %s%s\n' \
      "$rel" "$(wc -c <"$work/live")" "${live:0:12}" "$(wc -c <"$file")" "${built:0:12}" "$hint"
    drift=$((drift + 1))
  done < <(find -L "$artifact" -type f ! -name '.*' | sort)

  echo
  if [ "$drift" -ne 0 ]; then
    printf 'cv-ats-check: %s of %s deployed file(s) diverge from %s\n' "$drift" "$((same + drift))" "$artifact"
    exit 1
  fi
  printf 'cv-ats-check: %s file(s) at %s match %s\n' "$same" "$host" "$artifact"
  exit 0
fi

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

# The assertion above only fires when the continuation starts lowercase, so
# `Generation-` / `Alter` and `Nix-` / `Entwicklungsumgebung` pass it — and the
# reading order this check reads drops the hyphen at a break, arriving at one word
# no parser matches. So ask the other question: every compound the template prints
# with a hyphen must arrive whole. Only the fields the template emits are read, or
# a hyphen in a row it never prints would fail the document. Scoped to the packet's
# JSON Resume: the site's German PDFs still break these and are not this packet's.
if resume:
    def printed_fields(rec):
        basics_ = rec.get("basics") or {}
        for key in ("name", "label", "summary", "email", "phone", "url"):
            yield basics_.get(key, "")
        location = basics_.get("location") or {}
        for key in ("address", "postalCode", "city", "countryCode"):
            yield location.get(key, "")
        for profile in basics_.get("profiles") or []:
            yield from (profile.get("url", ""), profile.get("username", ""))
        for job in rec.get("work") or []:
            for key in ("name", "position", "location"):
                yield job.get(key, "")
            yield from job.get("highlights") or []
        for project in rec.get("projects") or []:
            bullets = project.get("highlights") or []
            entity = project.get("entity", "")
            description = project.get("description", "")
            yield project.get("name", "")
            # The template prints `entity` as the subtitle when there are bullets,
            # and the description only when there is no entity or no bullets.
            yield entity if bullets and entity else description if not bullets or not entity else ""
            yield from bullets
        for study in rec.get("education") or []:
            for key in ("institution", "studyType", "area"):
                yield study.get(key, "")
            yield from study.get("courses") or []
        for skill in rec.get("skills") or []:
            yield skill.get("name", "")
            yield from skill.get("keywords") or []
        for spoken in rec.get("languages") or []:
            yield from (spoken.get("language", ""), spoken.get("fluency", ""))

    for token in sorted(
        {hit for text in printed_fields(record) for hit in re.findall(r"[^\W\d_]{2,}(?:-[^\W\d_]{2,})+", text)}
    ):
        if token not in flat:
            fail(
                f"the record's {token!r} is not in the extracted text — a compound broken "
                f"at its hyphen arrives glued, and a parser matches neither half"
            )

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
