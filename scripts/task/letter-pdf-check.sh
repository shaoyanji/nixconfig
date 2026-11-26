#!/usr/bin/env bash
# letter-pdf-check.sh — a finished Anschreiben must still say what letter.json says.
#
# The packet build compiles `anschreiben.typ` from the letter record and then
# checked only its page count. A template that drops a paragraph, a string that
# never reaches the body, or a PDF that loses its structure tree all compile
# cleanly, pass the page budget, and get attached to the send.
#
# So this reads the finished PDF back (pdftotext, reading order) and asserts the
# record's own text: subject, salutation, every paragraph, closing. Both sides are
# compared with whitespace and hyphens removed: a justified line break is not a
# difference, and poppler drops the hyphen when a compound breaks at a line end
# (measured: the record's `SSH-Certificate-Authority` extracts as
# `SSH-CertificateAuthority`). The PDF must also be tagged, like the CVs, so a
# parser reads structure instead of glyph positions.
#
# Usage: letter-pdf-check.sh --letter LETTER.json PDF
# Exit: 0 parity holds, 1 a property is missing, 2 bad usage or no pdftotext.
set -uo pipefail

letter=""
pdf=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --letter)
      letter=${2:?--letter needs a file}
      shift 2
      ;;
    -?*)
      echo "letter-pdf-check: unknown option $1" >&2
      exit 2
      ;;
    *)
      pdf=$1
      shift
      ;;
  esac
done

[ -n "$letter" ] && [ -f "$letter" ] || {
  echo "letter-pdf-check: no letter record (usage: letter-pdf-check.sh --letter LETTER.json PDF)" >&2
  exit 2
}
[ -n "$pdf" ] && [ -f "$pdf" ] || {
  echo "letter-pdf-check: no PDF (usage: letter-pdf-check.sh --letter LETTER.json PDF)" >&2
  exit 2
}
for cmd in pdftotext pdfinfo python3; do
  command -v "$cmd" >/dev/null 2>&1 || {
    echo "letter-pdf-check: $cmd (poppler/python) missing" >&2
    exit 2
  }
done

python3 - "$letter" "$pdf" <<'PY'
import json
import re
import subprocess
import sys

letter_path, pdf_path = sys.argv[1], sys.argv[2]

with open(letter_path, encoding="utf-8") as fh:
    letter = json.load(fh)

problems = []
for key in ("subject", "salutation", "closing"):
    if not (letter.get(key) or "").strip():
        problems.append(f"the record carries no {key}")
paragraphs = [p for p in (letter.get("paragraphs") or []) if isinstance(p, str)]
if not paragraphs:
    problems.append("the record carries no paragraphs")
if any(not p.strip() for p in paragraphs):
    problems.append("a paragraph in the record is empty — a blank block in a letter is a defect")

run = subprocess.run(["pdftotext", "-q", pdf_path, "-"], capture_output=True, text=True)
if run.returncode != 0:
    print(f"letter-pdf-check: pdftotext failed on {pdf_path}", file=sys.stderr)
    sys.exit(2)

flat = run.stdout.replace("\u00a0", " ")


def squash(text):
    """Drop whitespace and hyphens: a line break, and the hyphen poppler eats
    when a compound breaks there, are typesetting, not text."""
    return re.sub(r"[\s\-\u00ad]+", "", text or "")


def present(label, value):
    want = squash(value)
    if want and want not in squash(flat):
        problems.append(f"{label} is in the record and not in the PDF: {(value or '').strip()[:60]!r}")


present("subject", letter.get("subject"))
present("salutation", letter.get("salutation"))
present("closing", letter.get("closing"))
for i, paragraph in enumerate(paragraphs, 1):
    present(f"paragraph {i}", paragraph)

info = subprocess.run(["pdfinfo", pdf_path], capture_output=True, text=True).stdout
tagged = re.search(r"^Tagged:\s+(\w+)", info, re.M)
if not tagged or tagged.group(1).lower() != "yes":
    problems.append("the PDF is not tagged (Tagged: no) — a parser has to rebuild the structure")

if problems:
    for problem in problems:
        print(f"FAIL {problem}")
    print(f"letter-pdf-check: {len(problems)} defect(s)")
    sys.exit(1)

print(f"ok   subject, salutation, closing and {len(paragraphs)} paragraph(s) are in the text")
print("ok   the PDF is tagged")
print("letter-pdf-check: the letter matches the record")
PY
