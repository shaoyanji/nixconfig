#!/usr/bin/env bash
# Fixture for the queue resolver: the rules that decide without a model, the
# closed candidate vocabulary, the ternary, and the one-turn batch. No network,
# no decision engine and no hermes: `choose`, `ternary` and `batch_decide` are
# exercised with stubs, so the gate tests the contract the live models are held
# to, not their weights.
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)

python3 - "$root/modules/plugins/appflow/resolve.py" <<'PY'
import importlib.util
import json
import sys

spec = importlib.util.spec_from_file_location("appflow_resolve", sys.argv[1])
resolve = importlib.util.module_from_spec(spec)
spec.loader.exec_module(resolve)

catalogue = [
    {"id": "pyur-genai", "company": "PŸUR (Tele Columbus Netz GmbH)", "role": "Senior Generative AI Engineer", "status": "Rejected", "stage": "rejected"},
    {"id": "tieto-genai", "company": "Tietoevry Austria (Tieto Austria)", "role": "Senior Generative AI Engineer", "status": "Rejected", "stage": "rejected"},
    {"id": "solar", "company": "Solar & Clean Energy Investments", "role": "Senior Solar Asset Manager", "status": "Applied", "stage": "applied"},
]
failed = 0
total = 0


def check(name, got, want):
    global failed, total
    total += 1
    if got != want:
        print(f"FAIL  {name}: got {got!r}, want {want!r}")
        failed += 1
    else:
        print(f"ok    {name}")


# --- closes that need no attribution ----------------------------------------
check("job alert closes", resolve.bulk_reason("noreply@join.com", "Neue Jobs für dich", ""), "job alert")
check("EEO form closes", resolve.bulk_reason("hr@x.com", "EEO Self-Identification Form", ""), "compliance form")
check("Loopcv form closes", resolve.bulk_reason("Loopcv <updates@loopcv.com>", "Loopcv - A new job application form has been submitted", ""), "form submission")
check("automatic reply closes", resolve.bulk_reason("career.no@paretosec.com", "Automatic reply: Bewerbung", ""), "automatic reply")
check("acknowledgement does not close", resolve.bulk_reason("jobs@jtl-software.com", "Deine Bewerbung als Senior AI Engineer", ""), "")

# --- retention requests leave the agent queue, not the mailbox ---------------
check(
    "consent handoff",
    resolve.handoff_reason("Tibber <no-reply@tibber.teamtailor-mail.com>", "We would love to keep considering you", ""),
    "retention/consent request",
)
check("ordinary ack is not a handoff", resolve.handoff_reason("jobs@x.com", "Deine Bewerbung als Engineer", ""), "")

# --- sender-domain attribution (Tieto, PŸUR) --------------------------------
found = resolve.candidates("Hilbert.Pustilnik@pyur.com", "AW: Bewerbung als Senior Generative AI Engineer", "", catalogue, [])
check("domain attributes pyur", [row["id"] for row, _ in found], ["pyur-genai"])

found = resolve.candidates("careers.austria@tieto.com", "AW: Bewerbung als Senior Generative AI Engineer", "", catalogue, [])
check("domain attributes tieto", [row["id"] for row, _ in found], ["tieto-genai"])

found = resolve.candidates("human@example.com", "Application: Senior Solar Asset Manager", "", catalogue, [])
check("unknown sender has no candidate", [row["id"] for row, _ in found], [])

# --- the model vocabulary is closed ----------------------------------------
found = resolve.candidates("Hilbert.Pustilnik@pyur.com", "AW: Bewerbung", "", catalogue, [])
state = "pyur\nAW: Bewerbung\n"


def stub_ask(choice, margin=0.4, probability=0.7):
    def ask(url, state, criteria, timeout=20.0):
        return choice, probability, margin

    return ask


original = resolve.ask
try:
    resolve.ask = stub_ask("app:pyur-genai")
    row, why = resolve.choose(state, found, "http://a", "http://b", 0.15)
    check("model picks a listed id", row["id"] if row else None, "pyur-genai")

    resolve.ask = stub_ask("app:not-listed")
    row, why = resolve.choose(state, found, "http://a", "http://b", 0.15)
    check("id outside vocabulary is refused", row, None)

    resolve.ask = stub_ask("defer")
    row, why = resolve.choose(state, found, "http://a", "http://b", 0.15)
    check("defer is a refusal", (row, why), (None, "model deferred"))

    resolve.ask = stub_ask("app:pyur-genai", margin=0.01)
    row, why = resolve.choose(state, found, "http://a", "http://b", 0.15)
    check("thin margin is refused", row, None)

    def disagree(url, state, criteria, timeout=20.0):
        return ("app:pyur-genai" if url == "http://a" else "defer"), 0.7, 0.4

    resolve.ask = disagree
    row, why = resolve.choose(state, found, "http://a", "http://b", 0.15)
    check("engine disagreement is refused", row, None)

    def unavailable(url, state, criteria, timeout=20.0):
        return None

    resolve.ask = unavailable
    row, why = resolve.choose(state, found, "http://a", "http://b", 0.15)
    check("no engine refuses", (row, why), (None, "model unavailable"))
finally:
    resolve.ask = original

# --- the ternary: ignore is agreed, never guessed ---------------------------
original_verdict = resolve.ask_verdict


def stub_verdict(choice, margin=0.4, probability=0.7):
    def ask(url, state, timeout=20.0):
        return choice, probability, margin

    return ask


try:
    resolve.ask_verdict = stub_verdict("ignore")
    verdict, why = resolve.ternary(state, "http://a", "http://b", 0.25, False)
    check("ternary ignores on agreement", verdict, "ignore")

    def verdict_disagree(url, state, timeout=20.0):
        return ("ignore" if url == "http://a" else "unsure"), 0.7, 0.4

    resolve.ask_verdict = verdict_disagree
    verdict, why = resolve.ternary(state, "http://a", "http://b", 0.25, False)
    check("ternary disagreement defers", verdict, None)

    resolve.ask_verdict = stub_verdict("ignore", margin=0.01)
    verdict, why = resolve.ternary(state, "http://a", "http://b", 0.25, False)
    check("ternary thin margin defers", verdict, None)

    resolve.ask_verdict = stub_verdict("attribute")
    verdict, why = resolve.ternary(state, "http://a", "http://b", 0.25, False)
    check("ternary attribute without a candidate is refused", (verdict, why), (None, "attribute without a candidate"))

    resolve.ask_verdict = stub_verdict("ignore")
    verdict, why = resolve.ternary(state, "http://a", "http://b", 0.25, True)
    check("a linked message is not ignorable", verdict, None)
finally:
    resolve.ask_verdict = original_verdict

# --- the batch: one call, closed ids, per-row refusal -----------------------


def ctx(message_id, candidates=(), linked=False, event=("received", "Application Received"), reason="no candidate"):
    return {
        "message_id": message_id,
        "sender": "Jobs <jobs@example.com>",
        "subject": "Deine Bewerbung als Senior AI Engineer",
        "sent": "2026-11-01",
        "body": "Wir haben deine Bewerbung erhalten.",
        "linked": linked,
        "event": event,
        "found": list(candidates),
        "reason": reason,
    }


def runner(payload, calls=None):
    def run(prompt, timeout=240.0, run_budget=180):
        if calls is not None:
            calls.append(prompt)
        return (payload if isinstance(payload, str) else json.dumps(payload)), ""

    return run


pyur = (catalogue[0], "company")
items = [ctx("m1", [pyur]), ctx("m2"), ctx("m3")]

calls = []
decisions, error, _ = resolve.batch_decide(
    items,
    runner(
        {
            "decisions": [
                {"message_id": "m1", "action": "attribute", "application_id": "pyur-genai", "reason": "names PŸUR"},
                {"message_id": "m2", "action": "ignore", "reason": "newsletter"},
                {"message_id": "m3", "action": "unsure", "reason": "no employer"},
            ]
        },
        calls,
    ),
)
check("batch attributes a supplied id", (decisions["m1"]["action"], decisions["m1"]["application_id"]), ("attribute", "pyur-genai"))
check("batch ignores", decisions["m2"]["action"], "ignore")
check("batch leaves unsure alone", decisions["m3"]["action"], "unsure")
check("batch makes exactly one call", len(calls), 1)
check("batch prompt marks bodies untrusted", "untrusted" in calls[0], True)
check("batch prompt carries the message ids", all(mid in calls[0] for mid in ("m1", "m2", "m3")), True)

decisions, error, _ = resolve.batch_decide(
    [ctx("m1", [pyur])],
    runner({"decisions": [{"message_id": "m1", "action": "attribute", "application_id": "not-offered", "reason": "guess"}]}),
)
check("batch refuses an id outside the candidates", (decisions["m1"]["action"], error), ("unsure", ""))

decisions, error, _ = resolve.batch_decide(
    [ctx("m1", [pyur]), ctx("m2", [pyur])],
    runner({"decisions": [{"message_id": "m1", "action": "ignore", "reason": "none"}]}),
)
check("batch fills a missing row with unsure", decisions["m2"]["action"], "unsure")

decisions, error, _ = resolve.batch_decide(
    [ctx("m1", [pyur], linked=True)],
    runner({"decisions": [{"message_id": "m1", "action": "ignore", "reason": "none"}]}),
)
check("batch refuses ignore on a linked message", (decisions["m1"]["action"], error), ("unsure", ""))

decisions, error, _ = resolve.batch_decide([ctx("m1", [pyur])], runner("this is not json"))
check("malformed batch defers everything", (decisions["m1"]["action"], bool(error)), ("unsure", True))

# --- ignore is a tier, not a resolution ------------------------------------
original_post = resolve.sync.post
posted = []


def capture(url, payload, timeout=60.0):
    posted.append((url, payload))
    return {}


try:
    resolve.sync.post = capture
    resolve.ignore_message("http://api", "m1", "batch: newsletter", 0.7)
    check("ignore writes the tier", posted[-1][1]["tier"], "ignore")
    check("ignore keeps the owner", posted[-1][1]["owner"], "agent:apps")
    check("ignore never resolves the message", any("triage-resolve" in url for url, _ in posted), False)
    check("ignore writes a triage row", posted[-1][0].endswith("/api/triage-upsert"), True)
    resolve.restore_message("http://api", "m1")
    check("restore returns it to action", posted[-1][1]["tier"], "action")
    check("restore never resolves the message", any("triage-resolve" in url for url, _ in posted), False)
finally:
    resolve.sync.post = original_post

print(f"{total - failed}/{total} passed")
sys.exit(1 if failed else 0)
PY
