#!/usr/bin/env python3
"""Classify archived mail into a tier and an owner.

The rules run first and cover the bulk of a real mailbox: the VIP address, CI
notices from GitHub, machine senders, marketing. Only the residue reaches the
decision engine (services.systemoneDecision, julia-1 on loopback), and a verdict
the engine is not sure about lands in `review` — surfaced, never hidden.

Nothing here writes to a mailbox: the output is one row per message in
`email_triage`, which /api/attention and /api/agent-queue read. docs/email-archive.md.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
import urllib.error
import urllib.parse
import urllib.request
from collections import Counter
from datetime import datetime, timedelta, timezone
from email.utils import parseaddr

# A margin over the runner-up, not an absolute probability: julia-1 is a 144M
# model whose probabilities sit low even when its choice is right (measured:
# 0.38 top vs 0.21 second on an obvious CI notice). An absolute bar of 0.5 would
# send nearly every message to review and make the model pointless.
DEFAULT_MARGIN = 0.10

TIERS = ("person", "action", "digest", "robot", "review")

CRITERIA = [
    "person: a real human wrote to me",
    "action: a transactional notice I may need to act on",
    "digest: newsletter or marketing",
    "robot: automated CI or system notice with no human content",
    "review: cannot tell",
]

# CI first: a GitHub run failure is the one robot mail with a job behind it, and
# it is the only one that gets an owner instead of `none`.
CI_SUBJECT = re.compile(
    r"^(\[.*?\]\s*)?(run failed|workflow run failed|run cancelled|action required|"
    r"build failed|build #|job failed|[a-z0-9-]+\s-\s.*\(failure\))",
    re.IGNORECASE,
)
# No application-specific rules live here on purpose: a plugin declares its own
# senders (services.emailArchive.plugins), so removing a plugin removes its
# routing. CI is the only built-in, because its rule is a subject pattern.
CI_SENDERS = ("notifications@github.com", "actions@github.com", "ci@", "jenkins@", "buildkite@")
CI_BODY = re.compile(r"(github\.com/[^/\s]+/[^/\s]+/actions/runs/\d+|run #?\d+)", re.IGNORECASE)

MACHINE_LOCALS = (
    "noreply",
    "no-reply",
    "donotreply",
    "do-not-reply",
    "mailer-daemon",
    "postmaster",
    "notifications",
    "notification",
    "notify",
    "alerts",
    "newsletter",
    "marketing",
    "mailings",
    "info",
    "hello",
    "support",
    "news",
    "billing",
    "invoices",
    "service",
)

# Rule sets are host-agnostic. A host list names what this mailbox actually
# receives; the engine handles anything new.
BULK_SIGNALS = (
    "newsletter",
    "weekly digest",
    "daily digest",
    "this week",
    "new posts",
    "recommended for you",
    "you may have missed",
    "unsubscribe",
    "% off",
    "sale ends",
    "deal of",
    "limited time",
    "webinar",
    "podcast",
    "issue #",
    "deals",
    "shop ",
    "shop our",
    "events",
    "voting",
    "award",
    "exclusive",
    "last chance",
    "save up to",
    "giveaway",
    "invite",
    "review us",
    "bewerten",
)

# A deadline that survives the mail. This is the only robot-written class that
# stays in front of a person: a domain about to expire is not stale in a week.
ACTIONABLE_SIGNALS = (
    "expiring",
    "expires",
    "läuft ab",
    "action required",
    "deadline",
    "frist",
    "kündigung",
    "insufficient",
    "suspended",
    "failed payment",
)

# A record you keep and search, never a queue item: money and shipping. It stays
# archived and full-text searchable, it just does not sit in front of a person.
DURABLE_SIGNALS = (
    "statement",
    "invoice",
    "rechnung",
    "receipt",
    "quittung",
    "your order",
    "order confirmation",
    "bestellung",
    "shipped",
    "shipping",
    "versand",
    "delivery",
    "tracking",
    "payment",
    "zahlung",
    "paid",
    "refund",
    "subscription",
    "abo",
    "renewal",
    "tax",
    "steuer",
)

# Mail whose value ends when it is read: a code, a sign-in alert, a password
# reset. Measured on the 2026-11-03 queue, 67 rows a person was holding were one
# of these — a verification code is useless the minute it is read.
EPHEMERAL_SIGNALS = (
    "verification",
    "verify",
    "passcode",
    "bestätigungscode",
    "verification code",
    "password",
    "passwort",
    "security alert",
    "sicherheitshinweis",
    "new sign-in",
    "sign-in",
    "anmeldung",
    "two-factor",
    "2fa",
    "confirmation",
)

# The signals a second model may not close: an application is the pipeline's
# whole input, and a deadline is the one thing whose expiry has consequences.
# Everything else is fair game, in either direction.
PROTECTED_SIGNALS = ("bewerbung", "einladung", "vertrag") + ACTIONABLE_SIGNALS


# NpgsqlRest publishes column names as camelCase in JSON responses, while the
# POST parameters are the snake_case names in the SQL file. One normalisation at
# the boundary keeps the rules reading named fields instead of guessing.
ALIASES = {"messageId": "message_id", "sentAt": "sent_at", "bodyLength": "body_length"}


def normalize(row: dict) -> dict:
    return {ALIASES.get(key, key): value for key, value in row.items()}


def address(sender: str | None) -> str:
    if not sender:
        return ""
    return parseaddr(sender)[1].strip().lower()


def display_name(sender: str | None) -> str:
    if not sender:
        return ""
    return parseaddr(sender)[0].strip()


def load_vip(path: str) -> set[str]:
    """Addresses that are always a person. Private by construction: the file is
    operator state, not repository content, so a family address never lands in a
    public tree."""
    if not path or not os.path.exists(path):
        return set()
    out = set()
    with open(path, encoding="utf-8") as handle:
        for line in handle:
            # The sops value is one line; a hand-written file may be one per line.
            for entry in line.replace(",", "\n").splitlines():
                entry = entry.strip()
                if not entry or entry.startswith("#"):
                    continue
                out.add(address(entry) or entry.lower())
    return out


def post(url: str, payload: dict, timeout: float = 30.0) -> dict:
    data = json.dumps(payload).encode()
    request = urllib.request.Request(
        url, data=data, headers={"content-type": "application/json"}, method="POST"
    )
    with urllib.request.urlopen(request, timeout=timeout) as response:
        body = response.read().decode() or "null"
    return json.loads(body) if body.strip() else {}


def get(url: str, timeout: float = 30.0) -> object:
    with urllib.request.urlopen(url, timeout=timeout) as response:
        return json.loads(response.read().decode() or "null")


def load_plugins(path: str) -> list[dict]:
    """Sender rules a host declares, so a new plugin needs no code change.

    Each entry is `{name, owner, tier, senders}`; a message whose sender matches
    is routed to that owner. The shape matches `services.emailArchive.plugins`,
    which generates the file at build time.
    """
    if not path or not os.path.exists(path):
        return []
    with open(path, encoding="utf-8") as handle:
        raw = json.load(handle)
    plugins = []
    for name, plugin in (raw or {}).items():
        for rule in plugin.get("rules") or []:
            senders = [str(sender).lower() for sender in rule.get("senders") or [] if sender]
            subjects = [str(subject).lower() for subject in rule.get("subjects") or [] if subject]
            if not senders and not subjects:
                continue
            plugins.append(
                {
                    "name": name,
                    "owner": rule.get("owner") or f"agent:{name}",
                    "tier": rule.get("tier") or "action",
                    "senders": senders,
                    "subjects": subjects,
                }
            )
    return plugins


def load_pointers(path: str) -> set[str]:
    """Addresses of agents that send a regular pointer, one per day at most.

    A pointer is a person-facing action item that a machine writes: exempt from
    the feed rules, and never closed by the second model.
    """
    if not path or not os.path.exists(path):
        return set()
    with open(path, encoding="utf-8") as handle:
        return {address(line) or line.strip().lower() for line in handle if line.strip()}


def classify_rules(
    message: dict,
    vip: set[str],
    plugins: list[dict] | None = None,
    pointers: set[str] | None = None,
) -> tuple[str, str, str, float] | None:
    """(tier, owner, reason, confidence), or None when no rule fires."""
    addr = address(message.get("sender"))
    subject = (message.get("subject") or "").strip()
    low_subject = subject.lower()
    labels = message.get("labels") or []
    label_text = " ".join(labels).lower()
    pointers = pointers or set()

    if addr and addr in vip:
        return "person", "human", "VIP address", 0.99

    # A declared pointer is an agent's daily "look here": regular by design, so
    # the feed rules below never touch it, and the second model cannot close it.
    if addr in pointers:
        return "action", "human", f"pointer: {addr}", 0.95

    if addr and (addr in CI_SENDERS or addr.endswith("@github.com")):
        if CI_SUBJECT.search(subject):
            return "robot", "agent:ci", f"CI notice: {subject[:80]}", 0.95
        if "inbox" in label_text or addr == "notifications@github.com":
            return "robot", "none", "GitHub notification", 0.9

    if any(marker in addr for marker in ("jenkins", "buildkite", "circleci", "travis")):
        return "robot", "agent:ci", "CI sender", 0.9

    # Host-declared plugins, after the built-ins so a plugin cannot silently
    # outrank CI or the pipeline: adding one is config, not a patch. A plugin may
    # claim by sender or by subject, which is how application mail from a
    # company's own mailbox reaches the pipeline instead of a person.
    for plugin in plugins or []:
        if any(marker in addr for marker in plugin["senders"]) or any(
            marker in low_subject for marker in plugin["subjects"]
        ):
            return plugin["tier"], plugin["owner"], f"plugin {plugin['name']}", 0.9

    hit = next((signal for signal in BULK_SIGNALS if signal in low_subject), None)
    if hit:
        return "digest", "none", f"bulk signal: {hit}", 0.85

    # A deadline survives the read; a record does not need a person; a code is
    # over. Checked in that order because "order confirmation" contains
    # "confirmation", and a booking is a record, not a one-shot.
    hit = next((signal for signal in ACTIONABLE_SIGNALS if signal in low_subject), None)
    if hit:
        return "action", "human", f"deadline signal: {hit}", 0.8

    hit = next((signal for signal in DURABLE_SIGNALS if signal in low_subject), None)
    if hit:
        return "digest", "none", f"record signal: {hit}", 0.8

    hit = next((signal for signal in EPHEMERAL_SIGNALS if signal in low_subject), None)
    if hit:
        return "robot", "none", f"one-shot signal: {hit}", 0.8

    local = addr.split("@")[0] if "@" in addr else addr
    if any(local == machine or local.startswith(machine + "-") for machine in MACHINE_LOCALS):
        # A robot wrote it, so a robot's inbox: the reason said "machine sender"
        # while the tier said "a person's action item", which is where 203 of the
        # 511 rows in the queue came from.
        return "digest", "none", f"machine sender: {local}", 0.7

    return None


def classify_engine(message: dict, engine_url: str, margin: float) -> tuple[str, str, str, float] | None:
    state = "\n".join(
        [
            f"Sender: {message.get('sender') or ''}",
            f"Subject: {message.get('subject') or ''}",
            f"Labels: {', '.join(message.get('labels') or [])}",
        ]
    )
    payload = {
        "state": state,
        "questions": {
            "tier": {
                "type": "classify",
                "instructions": "Which tier does this mail belong to?",
                "criteria": CRITERIA,
            }
        },
    }
    try:
        answer = post(f"{engine_url.rstrip('/')}/v1/systemone", payload, timeout=20.0)
    except (urllib.error.URLError, TimeoutError, ValueError) as error:
        print(f"triage: engine unreachable ({error}); leaving for review", file=sys.stderr)
        return None

    verdict = (answer.get("answers") or {}).get("tier") or {}
    choice = (verdict.get("choice") or "").strip()
    probabilities = verdict.get("probabilities") or {}
    if not choice:
        return None

    tier = choice.split(":", 1)[0].strip().lower()
    if tier not in TIERS:
        return None

    # A robot verdict needs evidence. With no CI match and no machine sender the
    # engine has called marketing `robot` (measured: a university's admissions
    # newsletter at 0.34), and burying it would hide mail the digest tier is for.
    if tier == "robot":
        addr = address(message.get("sender"))
        if not any(marker in addr for marker in ("github", "jenkins", "buildkite", "circleci")):
            tier = "digest"

    ranked = sorted(probabilities.values(), reverse=True)
    top = ranked[0] if ranked else 0.0
    runner_up = ranked[1] if len(ranked) > 1 else 0.0
    if top - runner_up < margin:
        return "review", "human", f"engine unsure: {choice} ({top:.2f} vs {runner_up:.2f})", top

    owner = "human" if tier in ("person", "action") else "none"
    return tier, owner, f"engine: {choice} ({top:.2f})", top


# What a second model's verdict may replace: anything. The two architectures
# override each other in both directions, because a disagreement is information
# and the queue is what pays for a tie. The only bar is a declared pointer.
CLOSING = ("digest", "robot")

# How long a declared pointer stays in front of a person. It is a daily thing.
POINTER_DAYS = 7


def second_pass(
    api: str,
    engine_url: str,
    classifier: str,
    margin: float,
    dry_run: bool,
    pointers: set[str] | None = None,
) -> tuple[int, int, int, int]:
    """Ask the second model about unresolved human mail.

    (closed, reopened, kept, skipped). The two architectures override each other:
    a definite verdict replaces the other one in either direction, and a tie falls
    back to the tier `julia` already assigned. The bias is towards deciding —
    `review` is for a message neither model can place, not a parking spot.
    """
    pointers = pointers or set()
    try:
        get(f"{engine_url.rstrip('/')}/health", timeout=5.0)
    except (urllib.error.URLError, TimeoutError, ValueError) as error:
        print(
            f"triage: second engine unreachable at {engine_url} ({error}); pass skipped",
            file=sys.stderr,
        )
        return 0, 0, 0, 0

    attention = [normalize(row) for row in (get(f"{api}/api/attention?lim=100000") or [])]
    if not attention:
        return 0, 0, 0, 0

    # A sender that keeps writing with no deadline in sight is a feed: recurring
    # mail is the shape of a newsletter, and the addressing rules cannot see the
    # difference between one pointer and a thousand "Daily Chew"s.
    per_sender = Counter(address(row.get("sender")) for row in attention)

    # `triage-pending` answers the complement: every message this classifier has
    # not judged. Intersecting it with attention is what keeps the pass to the
    # human queue, and to mail that a run has not already asked about.
    unjudged = {
        normalize(row).get("message_id")
        for row in (
            get(
                f"{api}/api/triage-pending?classifier={urllib.parse.quote(classifier)}&lim=100000"
            )
            or []
        )
    }
    targets = [row for row in attention if row.get("message_id") in unjudged]

    closed = reopened = kept = skipped = 0
    for message in targets:
        verdict = classify_engine(message, engine_url, margin)
        if verdict is None:
            skipped += 1
            continue
        tier, owner, reason, confidence = verdict

        subject = (message.get("subject") or "").lower()
        addr = address(message.get("sender"))
        current_tier = message.get("tier") or "review"
        protected = addr in pointers or any(marker in subject for marker in PROTECTED_SIGNALS)
        feed = per_sender.get(addr, 0) > 1 and not any(
            marker in subject for marker in ACTIONABLE_SIGNALS
        )

        if protected:
            new_tier, new_owner = "action", "human"
        elif tier != "review":
            # Either direction: a definite verdict wins over the other model's.
            new_tier, new_owner = tier, owner
        elif feed:
            new_tier, new_owner = "digest", "none"
        else:
            new_tier, new_owner = current_tier, "human"

        if new_tier in CLOSING:
            closed += 1
        elif current_tier == "review" and new_tier in ("person", "action"):
            reopened += 1
        else:
            kept += 1

        if dry_run:
            print(
                f"second {new_tier:<7} {new_owner:<6} {confidence:.2f}  "
                f"{message.get('subject', '')[:70]}"
            )
            continue

        post(
            f"{api}/api/triage-upsert",
            {
                "messageId": message["message_id"],
                "classifier": classifier,
                "tier": new_tier,
                "owner": new_owner,
                "reason": f"second model: {reason}",
                "confidence": confidence,
            },
        )
        # Bulk mail that is closed is mail nobody has to look at twice; leaving it
        # open would move the queue rather than shorten it.
        if new_tier in CLOSING:
            post(f"{api}/api/triage-resolve", {"messageId": message["message_id"]})

    return closed, reopened, kept, skipped


def expire(
    api: str, days: int, pointers: set[str] | None = None, dry_run: bool = False
) -> int:
    """Resolve `review` rows older than `days`.

    A message neither model can place, that nobody has touched for a month, is a
    rolling window's job: it stays archived and searchable, it just stops being
    parked in front of a person. `person`, `action` and a declared pointer are
    never expired, and `resolved_at` is one update away from being undone.
    """
    if days <= 0:
        return 0
    pointers = pointers or set()
    now = datetime.now(timezone.utc)
    attention = [normalize(row) for row in (get(f"{api}/api/attention?lim=100000") or [])]
    expired = 0
    for row in attention:
        tier = row.get("tier") or ""
        addr = address(row.get("sender"))
        # A pointer is consumed, not kept: today's supersedes yesterday's, and a
        # week-old "look here" is a link to a moment that has passed.
        if addr in pointers:
            cutoff = now - timedelta(days=min(days, POINTER_DAYS))
        elif tier == "review":
            cutoff = now - timedelta(days=days)
        else:
            continue
        if any(marker in (row.get("subject") or "").lower() for marker in ACTIONABLE_SIGNALS):
            continue
        sent = row.get("sent_at") or ""
        try:
            when = datetime.fromisoformat(sent[:19]).replace(tzinfo=timezone.utc)
        except ValueError:
            continue
        if when >= cutoff:
            continue
        if not dry_run:
            post(f"{api}/api/triage-resolve", {"messageId": row["message_id"]})
        expired += 1
    return expired


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--api", default=os.environ.get("EMAIL_ARCHIVE_API", "http://127.0.0.1:8080"))
    parser.add_argument("--classifier", default="rules+engine")
    parser.add_argument("--limit", type=int, default=500, help="messages to classify in this run")
    parser.add_argument("--vip-file", default="", help="file of always-person addresses, one per line")
    parser.add_argument("--plugins", default="", help="JSON of host-declared sender rules")
    parser.add_argument("--pointers", default="", help="file of agent addresses whose mail is a pointer")
    parser.add_argument(
        "--expire-days",
        type=int,
        default=0,
        help="resolve `review` rows older than this; 0 keeps them forever",
    )
    parser.add_argument("--engine-url", default=os.environ.get("SYSTEMONE_URL", "http://127.0.0.1:8091"))
    parser.add_argument("--margin", type=float, default=DEFAULT_MARGIN)
    parser.add_argument("--no-engine", action="store_true", help="rules only; residue goes to review")
    parser.add_argument(
        "--second-engine-url",
        default=os.environ.get("SYSTEMONE_SECOND_URL", "http://127.0.0.1:8092"),
        help="second architecture; the pass is skipped when it does not answer",
    )
    parser.add_argument(
        "--second-classifier",
        default="second-pass",
        help="classifier name the second model's verdicts are stored under",
    )
    parser.add_argument(
        "--no-second",
        action="store_true",
        help="skip the second pass over human mail (default: run it)",
    )
    parser.add_argument("--dry-run", action="store_true", help="print verdicts, write nothing")
    parser.add_argument("--report", action="store_true", help="print tier counts from the API and exit")
    args = parser.parse_args()

    api = args.api.rstrip("/")

    if args.report:
        attention = get(f"{api}/api/attention?lim=100000") or []
        queue = [normalize(row) for row in (get(f"{api}/api/agent-queue?owner=agent&lim=100000") or [])]
        print(f"attention  {len(attention)} unresolved (person/action/review)")
        print(f"agent      {len(queue)} unresolved owned by an agent")
        for row in queue[:20]:
            print(f"  {row['sent_at'][:10]}  {row['owner']:<12} {row['subject'][:70]}")
        return 0

    vip = load_vip(args.vip_file)
    plugins = load_plugins(args.plugins)
    pointers = load_pointers(args.pointers)
    pending = [
        normalize(row)
        for row in get(
            f"{api}/api/triage-pending?classifier={urllib.parse.quote(args.classifier)}&lim={args.limit}"
        )
        or []
    ]
    # Nothing unjudged is not the same as nothing to do: the second pass runs
    # over mail the first one already filed, so it must run on an idle hour too.
    if not pending:
        print("triage: nothing pending")

    counts: dict[str, int] = {tier: 0 for tier in TIERS}
    owners: dict[str, int] = {}
    written = 0
    for message in pending:
        verdict = classify_rules(message, vip, plugins, pointers)
        if verdict is None and not args.no_engine:
            verdict = classify_engine(message, args.engine_url, args.margin)
        if verdict is None:
            verdict = ("review", "human", "no rule matched", 0.0)

        tier, owner, reason, confidence = verdict
        counts[tier] = counts.get(tier, 0) + 1
        owners[owner] = owners.get(owner, 0) + 1

        if args.dry_run:
            print(f"{tier:<7} {owner:<9} {confidence:.2f}  {message.get('subject', '')[:70]}")
            continue

        # Request bodies are camelCased like the responses: NpgsqlRest's
        # parameter `:message_id` is the JSON key `messageId`, and a key that
        # does not match is a 404 with no body, not a 400.
        post(
            f"{api}/api/triage-upsert",
            {
                "messageId": message["message_id"],
                "classifier": args.classifier,
                "tier": tier,
                "owner": owner,
                "reason": reason,
                "confidence": confidence,
            },
        )
        written += 1

    summary = " ".join(f"{tier}={count}" for tier, count in counts.items() if count)
    print(f"triage: {len(pending)} pending, {written} written, {summary}")
    print("owners: " + " ".join(f"{owner}={count}" for owner, count in sorted(owners.items())))

    if not args.no_second:
        closed, reopened, kept, skipped = second_pass(
            api,
            args.second_engine_url,
            args.second_classifier,
            args.margin,
            args.dry_run,
            pointers,
        )
        print(
            f"second pass: {closed} closed, {reopened} moved to a person, "
            f"{kept} kept, {skipped} without an answer"
        )

    expired = expire(api, args.expire_days, pointers, args.dry_run)
    if args.expire_days > 0:
        state = "would expire" if args.dry_run else "expired"
        print(f"expiry: {state} {expired} review rows older than {args.expire_days}d")
    return 0


if __name__ == "__main__":
    sys.exit(main())
