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

python3 - "$root/modules/plugins/appflow/sync.py" <<'PY'
import importlib.util
import sys

spec = importlib.util.spec_from_file_location("appflow_sync", sys.argv[1])
sync = importlib.util.module_from_spec(spec)
spec.loader.exec_module(sync)

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
        "interview: German invite",
        "Wir laden dich herzlich zum Vorstellungsgespräch ein.",
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

total = len(cases) + 3
print(f"{total - failed}/{total} passed")
sys.exit(1 if failed else 0)
PY
