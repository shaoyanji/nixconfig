#!/usr/bin/env python3
"""Natural-language mail actions on top of himalaya, dispatched by Needle 3.

Needle is a tool caller and is used only as one: it picks a tool and fills its
arguments. Nothing here asks it to label a message, because a label is a
classification and that question belongs to a decision model — measured, three
of them answered it worse than chance, so the sweep decides by rule instead.
The design, the measurements and the rejected alternatives are in
docs/mail-agent.md. Two properties are enforced here rather than documented:
there is no delete capability in the tool schema at all, and every mutation is
dry-run until --apply.
"""

import argparse
import json
import os
import re
import subprocess
import sys
import tempfile
import time
from datetime import datetime, timedelta, timezone

HERE = os.path.dirname(os.path.abspath(__file__))
DISPATCH_TOOLS = os.path.join(HERE, "mail-agent-tools.json")

NEEDLE = os.environ.get("MAIL_AGENT_NEEDLE", "needle")
WEIGHTS = os.environ.get("MAIL_AGENT_WEIGHTS", "")
HIMALAYA = os.environ.get("MAIL_AGENT_HIMALAYA", "himalaya")

INBOX = os.environ.get("MAIL_AGENT_INBOX", "inbox")
ARCHIVE = os.environ.get("MAIL_AGENT_ARCHIVE", "[Gmail]/All Mail")
TRUSTED = [s.strip().lower() for s in os.environ.get("MAIL_AGENT_TRUSTED", "").split(",") if s.strip()]
ACCOUNT = os.environ.get("MAIL_AGENT_ACCOUNT", "")
AUDIT = os.path.expanduser(
    os.environ.get("MAIL_AGENT_AUDIT", "~/.local/state/mail-agent/audit.jsonl")
)

# Archive is for bulk mail a human never answers. Anything that could be a
# receipt, a credential, or a person's request is out of scope for the sweep,
# whatever the sender allowlist says: a model called a contract review
# "archive" at 0.23, which is why no model gets a vote here.
BULK_SENDER = re.compile(
    r"^(no-?reply|do-?not-?reply|newsletter|news|digest|marketing|offers?|deals?|"
    r"promo\w*|notifications?|updates?|hello|team|mailer-daemon)@",
    re.I,
)
BULK_SUBJECT = re.compile(
    r"(newsletter|digest|weekly|monthly roundup|unsubscribe|sale ends|% off|"
    r"last chance|limited time|deal of the day|new arrivals|webinar|product update)",
    re.I,
)
PROTECTED = re.compile(
    r"(statement|invoice|receipt|security code|security alert|sign-in|sign in|password|2fa|"
    r"verification|order|bestellung|shipping|delivery|tax|refund|interview|application|"
    r"offer letter|contract|payment|legally|authentication|public key|new app|"
    r"connected|overdue|anfrage|inquiry|invitation|confirm|login|signed in|"
    r"unrecognized|device)",
    re.I,
)

MUTATING = {"archive_mail", "mark_read"}

# The agent cannot send, and a sentence that asks it to must not be routed onto
# a tool that touches the mailbox: "send an email to matt" came out as
# archive_mail at 0.13.
UNSUPPORTED = re.compile(r"\b(send|reply|forward|compose|draft|write to)\b", re.I)

# Expectations for --self-test: the tool a correct router would pick, or NONE
# when the sentence is not a mail action at all.
BATTERY = [
    ("archive_mail", "archive all newsletters from last week"),
    ("archive_mail", "archive that github notification"),
    ("archive_mail", "file away the receipts"),
    ("search_mail", "find mail from my bank"),
    ("search_mail", "search the inbox for invoices"),
    ("search_mail", "show me email about the tax return"),
    ("search_mail", "what is in my inbox"),
    ("mark_read", "mark the newsletter as read"),
    ("mark_read", "mark that receipt as read"),
    ("NONE", "what is the weather tomorrow"),
    ("NONE", "send an email to matt saying hello"),
]


def die(msg, code=1):
    print(f"mail-agent: {msg}", file=sys.stderr)
    return code


def run(cmd, timeout=180):
    p = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)
    return p.returncode, p.stdout, p.stderr


def himalaya(args, timeout=180):
    cmd = [HIMALAYA] + (["-a", ACCOUNT] if ACCOUNT else []) + args
    rc, out, err = run(cmd, timeout)
    if rc != 0:
        raise RuntimeError(f"himalaya {' '.join(args)} failed: {err.strip()}")
    return out


def envelopes(query, mailbox=INBOX, limit=25):
    args = ["envelope", "search", "-m", mailbox, "--json", "-s", str(limit)]
    if query:
        args.append(query)
    else:
        args = ["envelope", "list", "-m", mailbox, "--json", "-s", str(limit)]
    doc = json.loads(himalaya(args))
    return doc.get("envelopes") or []


def ask_needle(prompt, tools, forced=False, timeout=180):
    system = tempfile.NamedTemporaryFile("w", suffix=".txt", delete=False)
    today = datetime.now(timezone.utc).date()
    system.write(
        f"Today is {today.isoformat()}. The user reads mail on an ARM server.\n"
    )
    system.close()
    try:
        cmd = [NEEDLE, "--tools", tools, "--system", system.name, "--prompt", prompt]
        if WEIGHTS:
            cmd[1:1] = ["--model", WEIGHTS]
        if forced:
            cmd.append("--forced")
        rc, out, err = run(cmd, timeout)
        if rc != 0:
            raise RuntimeError(f"needle failed ({rc}): {err.strip()[:200]}")
        return json.loads(out)
    finally:
        os.unlink(system.name)


def call_of(reply):
    calls = reply.get("function_calls") or []
    return calls[0] if calls else None


def suppressed_of(reply):
    calls = reply.get("suppressed_calls") or []
    return calls[0] if calls else None


def quote(pattern):
    return '"' + pattern.replace('"', '') + '"'


def himalaya_query(args):
    clauses = []
    if args.get("query"):
        clauses.append(f"subject {quote(args['query'])}")
    if args.get("sender"):
        clauses.append(f"from {quote(args['sender'])}")
    period = args.get("period")
    days = {"today": 0, "yesterday": 1, "last_week": 7, "last_month": 30}.get(period)
    if days is not None:
        since = datetime.now(timezone.utc).date() - timedelta(days=days)
        clauses.append(f"after {since.isoformat()}")
    if args.get("unread"):
        clauses.append("not flag seen")
    return " and ".join(clauses)


DATED = ("today", "yesterday", "last_week", "last_month")

# The model fills `sender` with a time phrase when it hears "from last week",
# which builds `from "last week"` and matches nothing.
TIME_PHRASES = {
    "today", "yesterday", "last week", "last month", "this week", "this month",
    "last_week", "last_month",
}


def clean_args(args):
    """Drop selectors a time phrase leaked into."""
    kept = dict(args)
    for key in ("query", "sender"):
        value = (kept.get(key) or "").strip()
        if value.lower() in TIME_PHRASES:
            kept.pop(key, None)
        elif value:
            kept[key] = value
    return kept


def selectors_missing(args):
    """A mutation needs a real filter: `period: any` selects the whole inbox."""
    if args.get("query") or args.get("sender"):
        return False
    return args.get("period") not in DATED


def human_date(iso):
    try:
        return datetime.fromisoformat(iso.replace("Z", "+00:00")).astimezone().strftime("%Y-%m-%d")
    except (ValueError, AttributeError):
        return (iso or "")[:10]


def sender_of(env):
    people = env.get("from") or []
    if not people:
        return ""
    return people[0].get("name") or people[0].get("email") or ""


def sender_addr(env):
    people = env.get("from") or []
    return (people[0].get("email") or "") if people else ""


def show(envs, stream=sys.stdout):
    for e in envs:
        print(f"  {e.get('id', ''):>8}  {human_date(e.get('date'))}  "
              f"{sender_of(e)[:28]:<28}  {(e.get('subject') or '')[:64]}", file=stream)


def audit(record):
    os.makedirs(os.path.dirname(AUDIT), exist_ok=True)
    record["ts"] = datetime.now(timezone.utc).isoformat(timespec="seconds")
    with open(AUDIT, "a", encoding="utf-8") as fh:
        fh.write(json.dumps(record, ensure_ascii=False) + "\n")


def dispatch(request, apply, limit, force):
    if UNSUPPORTED.search(request):
        return die("I can search, archive and mark read — this agent has no send tool", 2)
    reply = ask_needle(request, DISPATCH_TOOLS)
    call = call_of(reply)
    forced = False
    if call is None:
        call = suppressed_of(reply)
        forced = True
    if call is None:
        reply = ask_needle(request, DISPATCH_TOOLS, forced=True)
        call = call_of(reply)
        forced = True
    if call is None:
        return die("that is not a mail action I can perform", 2)

    tool, args = call.get("name"), clean_args(call.get("arguments") or {})
    conf = reply.get("confidence", 0.0)
    if tool not in ("search_mail", "archive_mail", "mark_read"):
        return die(f"tool {tool!r} is not in the allowlist", 2)
    if tool in MUTATING and selectors_missing(args):
        return die(f"{tool} arrived without a selector; refusing to guess", 2)
    suppressed_route = forced and tool in MUTATING

    query = himalaya_query(args)
    envs = envelopes(query, limit=limit)
    how = "proposed" if forced else "router call"
    print(f"{tool}  conf {conf:.2f}  ({how})")
    print(f"  query: {query or '<inbox, no filter>'}")
    print(f"  matches: {len(envs)}")
    show(envs)

    if tool == "search_mail":
        if not envs and conf < 0.25:
            print("\nno mail matched, and the router was unsure this is a mail request")
        audit({"mode": "search", "request": request, "tool": tool, "args": args,
               "query": query, "matched": len(envs), "confidence": conf, "applied": True})
        return 0

    if not apply:
        print(f"\ndry run — nothing changed. Re-run with --apply to act on these {len(envs)}.")
        if suppressed_route:
            print("the router suppressed this call rather than emitting it, so --apply "
                  "will also need --force")
        return 0
    if suppressed_route and not force:
        return die("the router suppressed that call rather than emitting it; "
                   "re-run with --force if this plan is what you meant", 3)
    if not envs:
        return 0

    ids = [e["id"] for e in envs]
    if tool == "archive_mail":
        himalaya(["message", "move", "-f", INBOX, "-t", ARCHIVE] + ids)
        verb = f"archived {len(ids)} into {ARCHIVE}"
    else:
        himalaya(["flag", "add", "-m", INBOX, "-f", "seen"] + ids)
        verb = f"marked {len(ids)} read"
    print(f"\n{verb}")
    audit({"mode": "dispatch", "request": request, "tool": tool, "args": args,
           "query": query, "matched": len(envs),
           "moved": [e.get("message-id") for e in envs],
           "confidence": conf, "applied": True})
    return 0


def trusted(addr):
    return any(t in addr.lower() for t in TRUSTED)


def sweep(apply, limit):
    scanned = envelopes("", limit=limit)
    candidates, protected = [], 0
    for e in scanned:
        subject = e.get("subject") or ""
        if PROTECTED.search(subject):
            protected += 1
            continue
        if BULK_SENDER.search(sender_addr(e)) or BULK_SUBJECT.search(subject):
            candidates.append(e)

    # The trust list is the whole gate, by measurement: needle3, julia-1 and laya
    # each scored 3/10 on a labelled keep/archive battery, so the sender allowlist
    # and the PROTECTED guard decide, and everything else is held.
    approved, held = [], []
    for e in candidates:
        if trusted(sender_addr(e)):
            approved.append(e)
        else:
            held.append((e, "sender not in sweep.trustedSenders"))

    print(f"sweep: scanned {len(scanned)}, bulk candidates {len(candidates)}, "
          f"protected {protected}, approved {len(approved)}, held {len(held)} "
          f"(trusted senders {len(TRUSTED)})")
    for e in approved:
        print(f"  ARCHIVE  {human_date(e.get('date'))}  {sender_of(e)[:26]:<26}  "
              f"{(e.get('subject') or '')[:58]}")
    for e, why in held:
        print(f"  held           {human_date(e.get('date'))}  {sender_of(e)[:26]:<26}  "
              f"{(e.get('subject') or '')[:44]:<44}  {why}")

    if not apply:
        print("\ndry run — nothing changed. Re-run with --apply to archive the approved set.")
        return 0
    if not approved:
        audit({"mode": "sweep", "scanned": len(scanned), "approved": 0,
               "held": len(held), "moved": [], "gate": "trustedSenders",
               "applied": True})
        return 0

    ids = [e["id"] for e in approved]
    himalaya(["message", "move", "-f", INBOX, "-t", ARCHIVE] + ids)
    print(f"\narchived {len(ids)} into {ARCHIVE}")
    audit({"mode": "sweep", "scanned": len(scanned), "approved": len(approved),
           "held": len(held), "moved": [e.get("message-id") for e in approved],
           "gate": "trustedSenders", "applied": True})
    return 0


def self_test():
    emitted_ok = emitted_total = 0
    forced_ok = forced_total = 0
    print(f"{'':<6} {'expected':<13} {'chosen':<13} {'conf':<7} {'route':<10} sentence")
    for want, phrase in BATTERY:
        if UNSUPPORTED.search(phrase):
            # The dispatch path refuses these before the model is consulted.
            print(f"{'PASS' if want == 'NONE' else 'FAIL':<6} {want:<13} {'REFUSED':<13} "
                  f"{'-':<7} {'guard':<10} {phrase}")
            emitted_total += 1
            emitted_ok += want == "NONE"
            forced_total += 1
            forced_ok += want == "NONE"
            continue
        reply = ask_needle(phrase, DISPATCH_TOOLS)
        call = call_of(reply)
        route = "emitted"
        if call is None:
            emitted_total += 1
            call = suppressed_of(reply) or call_of(ask_needle(phrase, DISPATCH_TOOLS, forced=True))
            route = "forced"
        got = (call or {}).get("name", "NONE")
        conf = reply.get("confidence", 0.0)
        if route == "emitted":
            emitted_ok += got == want
            emitted_total += 1
        forced_ok += got == want
        forced_total += 1
        print(f"{'PASS' if got == want else 'FAIL':<6} {want:<13} {got:<13} "
              f"{conf:<7.3f} {route:<10} {phrase}")
    print(f"\nemitted-only precision {emitted_ok}/{emitted_total}; "
          f"with forced fallback {forced_ok}/{forced_total}")
    return 0 if forced_ok == forced_total else 1


def main():
    ap = argparse.ArgumentParser(
        prog="mail-agent",
        description="Natural-language mail actions (search, archive, mark read) "
                    "through himalaya, routed by Needle 3. Dry run unless --apply.")
    ap.add_argument("request", nargs="*", help="what to do, in plain English")
    ap.add_argument("--sweep", action="store_true",
                    help="nightly policy: archive bulk mail from sweep.trustedSenders")
    ap.add_argument("--self-test", action="store_true",
                    help="run the routing battery and report accuracy")
    ap.add_argument("--apply", action="store_true", help="actually change the mailbox")
    ap.add_argument("--force", action="store_true",
                    help="accept a mutation the router suppressed rather than emitted")
    ap.add_argument("--limit", type=int, default=25, help="envelopes to consider (default 25)")
    opts = ap.parse_args()

    try:
        if opts.self_test:
            return self_test()
        if opts.sweep:
            return sweep(opts.apply, opts.limit)
        if not opts.request:
            ap.print_help()
            return 2
        return dispatch(" ".join(opts.request), opts.apply, opts.limit, opts.force)
    except RuntimeError as exc:
        return die(str(exc))


if __name__ == "__main__":
    sys.exit(main())
