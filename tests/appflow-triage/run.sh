#!/usr/bin/env bash
# Fixture for the mail -> status rules: the sync's event vocabulary and its
# ordering. The case that motivated it is a real rejection — WattFox, 2026-10-23
# — which said "den Prozess mit anderen Kandidatinnen fortzusetzen" and matched
# none of the English words, so the application stayed at interview.
#
# A generic acknowledgement footer ("wir können nicht jede Bewerbung
# berücksichtigen") must stay No event: that sentence is in half the Personio
# acknowledgements and would otherwise reject every application it touches.
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)

python3 - "$root/modules/plugins/appflow/sync.py" "$root/modules/services/email-triage.py" <<'PY'
import importlib.util
import sys

spec = importlib.util.spec_from_file_location("appflow_sync", sys.argv[1])
sync = importlib.util.module_from_spec(spec)
spec.loader.exec_module(sync)

triage_spec = importlib.util.spec_from_file_location("email_triage", sys.argv[2])
triage = importlib.util.module_from_spec(triage_spec)
triage_spec.loader.exec_module(triage)

cases = [
    (
        "rejection: German team decision",
        "Nach intensiver Rücksprache im Team haben wir uns allerdings entschieden, "
        "den Prozess mit anderen Kandidatinnen fortzusetzen.",
        "rejected",
    ),
    (
        "rejection: no leider, no Absage",
        "Auch wenn es dieses Mal nicht geklappt hat, wünschen wir dir alles Gute.",
        "rejected",
    ),
    (
        "rejection: English",
        "We have decided not to proceed with your application.",
        "rejected",
    ),
    (
        "rejection: role filled",
        "Die Stelle ist inzwischen anderweitig besetzt.",
        "rejected",
    ),
    (
        # Canonical, 2026-11-22: the subject reads like good news ("An update on
        # your application") and the body owns none of the words above, so two
        # applications sat in `applied` until a person read them.
        "rejection: Canonical regret to inform",
        "We regret to inform you that we shall not be progressing your application "
        "further for this particular role.",
        "rejected",
    ),
    (
        "rejection: not moving forward",
        "After careful review we will not be moving forward with your candidacy.",
        "rejected",
    ),
    (
        "interview: German invite",
        "Wir laden dich herzlich zum Vorstellungsgespräch ein.",
        "interview",
    ),
    (
        "interview: English invite",
        "We would like to invite you to an interview on 3 December.",
        "interview",
    ),
    (
        # Canonical, 2026-11-21: the acknowledgement describes the people the
        # candidate might meet, and that sentence alone raised an interview on
        # the day the application was sent.
        "interview boilerplate is not an interview",
        "Thank you for your application. You will meet interviewers you meet along "
        "the way, and the hiring lead for this role will be in touch.",
        "received",
    ),
    (
        "interview tips are not an interview",
        "Interview tips: this calendar invitation was generated automatically.",
        None,
    ),
    (
        # Celonis: the acknowledgement conditions the next step on a decision
        # nobody has made yet.
        "interview journey is not an interview",
        "Thank you for applying to Celonis. We are reviewing all applications and "
        "will reach out if you are moved forward in the interview journey.",
        "received",
    ),
    (
        # Wolt: a link to interview advice inside the receipt.
        "interview preparation tips are not an interview",
        "Thanks for applying to Wolt. Tips for preparing for interviews with Wolt "
        "are on our careers site.",
        "received",
    ),
    (
        # GitLab: the handbook page about how the company interviews people.
        "how a company interviews is not an interview",
        "Thank you for applying to GitLab. For better understanding of how GitLab "
        "conducts interviews on a global scale, take a look at this handbook page.",
        "received",
    ),
    (
        # Sezzle: the assessment is described, not scheduled.
        "initial screening paragraph is not a screening",
        "Thank you for applying! As part of our initial screening, we utilize "
        "various assessments and tests.",
        "received",
    ),
    (
        # A real invitation from a person, in the same vocabulary: it must survive
        # the boilerplate filter.
        "a personal invitation still is an interview",
        "vielen Dank für dein Interesse und deine Bewerbung bei uns. Ich würde dich "
        "gerne zu einem persönlichen Vorstellungsgespräch einladen. Passt es dir am "
        "Montag um 13:30 Uhr?",
        "interview",
    ),
    (
        "received: acknowledgement",
        "Vielen Dank für deine Bewerbung. Wir haben deine Unterlagen erhalten.",
        "received",
    ),
    (
        # The footer carries "erhalten" and "berücksichtigen", so it may read as
        # an acknowledgement; what it must never do is read as a rejection.
        "footer is not a rejection",
        "Da wir viele Bewerbungen erhalten, können wir nicht jede einzeln berücksichtigen.",
        "!rejected",
    ),
    (
        "no event: privacy boilerplate",
        "Bitte beachte unsere Datenschutzerklärung.",
        None,
    ),
    (
        "no event: job alert",
        "Neue Jobs für dich: Software Engineer",
        None,
    ),
]

failed = 0
for name, text, want in cases:
    found = sync.detect_event(text)
    got = found[0] if found else None
    good = (got != "rejected") if want == "!rejected" else (got == want)
    if not good:
        print(f"FAIL  {name}: got {got!r}, want {want!r}")
        failed += 1
    else:
        print(f"ok    {name}")

# The stage a rejection lands in is the other half: a status the sync writes is
# only useful if `applications.stage` agrees with it.
if sync.stage_of("Rejected (email 2026-10-23)") != "rejected":
    print("FAIL  stage_of(Rejected …) is not rejected")
    failed += 1
else:
    print("ok    stage_of(Rejected …)")

# Discovery: Personio puts the employer before " //", which none of the
# "Bewerbung … bei …" patterns can see. The acknowledgement of a real
# application then stays unattributed instead of hydrating a record.
employer = sync.extract_employer(
    "Matt x avenit group // Wir freuen uns über deine Bewerbung als IT Systemadministrator"
)
if employer.lower() != "avenit group":
    print(f"FAIL  Personio employer: got {employer!r}")
    failed += 1
else:
    print("ok    Personio employer")

# A question is not a status and must not be closed as noise: the Eat Happy mail
# asked "Wäre es für Sie möglich, in Vollzeit zu arbeiten?" and the sync resolved
# it, so nobody was ever asked to answer. The ATS footer asks nothing.
questions = [
    (
        "question: full-time possible",
        "Wäre es für Sie möglich, in Vollzeit zu arbeiten?",
        True,
    ),
    (
        "question: availability in English",
        "Are you available to start on 1 December?",
        True,
    ),
    (
        "footer asks nothing",
        "Haben Sie Fragen? Kontaktieren Sie uns jederzeit gerne.",
        False,
    ),
]
for name, text, want in questions:
    got = sync.asks_question(text)
    if got != want:
        print(f"FAIL  {name}: asks_question={got!r}, want {want!r}")
        failed += 1
    else:
        print(f"ok    {name}")

# A conditional invite is an acknowledgement, not an interview.
conditional = sync.detect_event(
    "Wir haben deine Unterlagen erhalten. Wenn wir dich zu einem "
    "Vorstellungsgespräch einladen möchten, melden wir uns."
)
if not conditional or conditional[0] != "received":
    print(f"FAIL  conditional invite: got {conditional!r}")
    failed += 1
else:
    print("ok    conditional invite is not an interview")

# A bracketed display name defeats parseaddr: "Malt [no reply]" made address()
# return "", so the Malt digest rule could never fire.
malt_sender = "Malt [no reply] <noreply@malt.com>"
if triage.address(malt_sender) != "noreply@malt.com":
    print(f"FAIL  bracketed display name: got {triage.address(malt_sender)!r}")
    failed += 1
else:
    print("ok    bracketed display name")

verdict = triage.classify_rules(
    {"sender": malt_sender, "subject": "New opportunity with YANUS UG", "labels": []}, set()
)
if not verdict or verdict[:2] != ("digest", "none"):
    print(f"FAIL  Malt opportunity match: got {verdict!r}")
    failed += 1
else:
    print("ok    Malt opportunity match is digest")

total = len(cases) + 3 + len(questions) + 2
print(f"{total - failed}/{total} passed")
sys.exit(1 if failed else 0)
PY
