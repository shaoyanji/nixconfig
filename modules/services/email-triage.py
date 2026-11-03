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

TRANSACTIONAL_SIGNALS = (
    "invoice",
    "receipt",
    "your order",
    "order confirmation",
    "shipped",
    "shipping",
    "delivery",
    "tracking",
    "payment",
    "paid",
    "refund",
    "subscription",
    "renewal",
    "expires",
    "expiring",
    "verify",
    "verification",
    "security alert",
    "new sign-in",
    "password",
    "two-factor",
    "2fa",
    "sign-in",
    "confirmation",
    "application received",
    "your application",
    "interview",
    "booking",
    "reservation",
    "appointment",
    "ticket",
    "statement",
    "tax",
    "insufficient",
    "error",
)


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
            if not senders:
                continue
            plugins.append(
                {
                    "name": name,
                    "owner": rule.get("owner") or f"agent:{name}",
                    "tier": rule.get("tier") or "action",
                    "senders": senders,
                }
            )
    return plugins


def classify_rules(
    message: dict, vip: set[str], plugins: list[dict] | None = None
) -> tuple[str, str, str, float] | None:
    """(tier, owner, reason, confidence), or None when no rule fires."""
    addr = address(message.get("sender"))
    subject = (message.get("subject") or "").strip()
    low_subject = subject.lower()
    labels = message.get("labels") or []
    label_text = " ".join(labels).lower()

    if addr and addr in vip:
        return "person", "human", "VIP address", 0.99

    if addr and (addr in CI_SENDERS or addr.endswith("@github.com")):
        if CI_SUBJECT.search(subject):
            return "robot", "agent:ci", f"CI notice: {subject[:80]}", 0.95
        if "inbox" in label_text or addr == "notifications@github.com":
            return "robot", "none", "GitHub notification", 0.9

    if any(marker in addr for marker in ("jenkins", "buildkite", "circleci", "travis")):
        return "robot", "agent:ci", "CI sender", 0.9

    # Host-declared plugins, after the built-ins so a plugin cannot silently
    # outrank CI or the pipeline: adding one is config, not a patch.
    for plugin in plugins or []:
        if any(marker in addr for marker in plugin["senders"]):
            return plugin["tier"], plugin["owner"], f"plugin {plugin['name']}", 0.9

    hit = next((signal for signal in BULK_SIGNALS if signal in low_subject), None)
    if hit:
        return "digest", "none", f"bulk signal: {hit}", 0.85

    hit = next((signal for signal in TRANSACTIONAL_SIGNALS if signal in low_subject), None)
    if hit:
        return "action", "human", f"transactional signal: {hit}", 0.85

    local = addr.split("@")[0] if "@" in addr else addr
    if any(local == machine or local.startswith(machine + "-") for machine in MACHINE_LOCALS):
        return "action", "human", f"machine sender: {local}", 0.7

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


# What the second architecture may do to a message a person is already holding:
# call it bulk and close it, or leave it alone. Nothing it says can put mail in
# front of a person, so a second opinion can only take work away.
DEMOTABLE = ("digest", "robot")

# …except about these. A receipt demoted to a digest is a record nobody reads,
# and an application acknowledgement is the pipeline's whole input: measured on
# the first run, 16 of 500 demotions were one of the two. The markers are the
# first pass's own evidence, so the second model cannot overrule them.
PROTECTED = TRANSACTIONAL_SIGNALS + ("bewerbung", "einladung", "vertrag", "kündigung")


def second_pass(
    api: str,
    engine_url: str,
    classifier: str,
    margin: float,
    dry_run: bool,
) -> tuple[int, int, int]:
    """Ask the second model about unresolved human mail. (demoted, kept, skipped)."""
    try:
        get(f"{engine_url.rstrip('/')}/health", timeout=5.0)
    except (urllib.error.URLError, TimeoutError, ValueError) as error:
        print(
            f"triage: second engine unreachable at {engine_url} ({error}); pass skipped",
            file=sys.stderr,
        )
        return 0, 0, 0

    attention = [normalize(row) for row in (get(f"{api}/api/attention?lim=100000") or [])]
    if not attention:
        return 0, 0, 0

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

    demoted = kept = skipped = 0
    for message in targets:
        verdict = classify_engine(message, engine_url, margin)
        if verdict is None:
            skipped += 1
            continue
        tier, _owner, reason, confidence = verdict

        subject = (message.get("subject") or "").lower()
        protected = any(marker in subject for marker in PROTECTED)
        if tier in DEMOTABLE and not protected:
            new_tier, new_owner = "digest", "none"
            demoted += 1
        else:
            # Keep the tier a person was already given: the second model can say
            # "agreed", it cannot re-label review as action behind their back.
            new_tier, new_owner = message.get("tier") or "review", "human"
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
        if new_tier == "digest":
            post(f"{api}/api/triage-resolve", {"messageId": message["message_id"]})

    return demoted, kept, skipped


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--api", default=os.environ.get("EMAIL_ARCHIVE_API", "http://127.0.0.1:8080"))
    parser.add_argument("--classifier", default="rules+engine")
    parser.add_argument("--limit", type=int, default=500, help="messages to classify in this run")
    parser.add_argument("--vip-file", default="", help="file of always-person addresses, one per line")
    parser.add_argument("--plugins", default="", help="JSON of host-declared sender rules")
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
        verdict = classify_rules(message, vip, plugins)
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
        demoted, kept, skipped = second_pass(
            api,
            args.second_engine_url,
            args.second_classifier,
            args.margin,
            args.dry_run,
        )
        print(
            f"second pass: {demoted} closed as bulk, {kept} left for a person, "
            f"{skipped} without an answer"
        )
    return 0


if __name__ == "__main__":
    sys.exit(main())
