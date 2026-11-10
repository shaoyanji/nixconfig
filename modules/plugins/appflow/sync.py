#!/usr/bin/env python3
"""Load the job pipeline into the archive database and link it to mail.

Three verbs, all idempotent:

* `--file <json|->` reads the workflow's `data/applications.json` and upserts one
  `applications` row per record, deriving `stage` with the same rules
  `task apps:overview` applies, so the CLI and the database agree.
* `--link` matches archived mail to applications by company, and by the record's
  own `message_id` where it has one. A link is evidence, never a verdict: it is
  written with `matched_by` and a confidence, and it never removes another link.
* `--sync` reads the queue the triage hands over, writes the status the mail
  proves, and closes the message either way: an alert from a lifecycle sender is
  bulk rather than lifecycle, and an acknowledgement that arrives after the
  application was logged moves nothing — both leave the queue instead of
  reappearing on the next run.
* `--report` prints the pipeline and the applications whose mail is still open.

A draft is the safe half of sending: `--draft` writes a message into the
mailbox's Drafts folder, where a person reads, edits or discards it. Nothing here
can send mail, so an agent may draft freely and report that a draft exists with
its attachment rather than claiming anything was mailed.

The importer talks to the loopback API only. It never touches the mailbox and
never edits the workflow's JSON: docs/email-archive.md.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
import urllib.error
import urllib.parse
import urllib.request
from email.message import EmailMessage
from email.utils import formatdate, make_msgid

# A record whose `company` is really a role ("AI Generative Engineer German") would
# otherwise match every recruiter reply, because those words are in the subject of
# all of them. Measured on the live pipeline: one such record absorbed ~30 mail.
ROLE_WORDS = {
    "ai",
    "generative",
    "engineer",
    "engineering",
    "developer",
    "german",
    "english",
    "senior",
    "junior",
    "manager",
    "architect",
    "software",
    "data",
    "ml",
    "lead",
    "intern",
    "specialist",
    "consultant",
    "general",
    "track",
}

LEGAL_SUFFIXES = {
    "gmbh",
    "mbh",
    "ag",
    "kg",
    "ug",
    "se",
    "ohg",
    "gbr",
    "inc",
    "ltd",
    "llc",
    "co",
    "corp",
    "company",
    "group",
    "the",
    "and",
    "und",
    "der",
    "die",
    "das",
}


def stage_of(status: str) -> str:
    """The bucket `task apps:overview` prints, lowercased for a stable column."""
    text = (status or "").lower()
    if re.search(r"interview|trial|warteliste", text):
        return "interview"
    if text.startswith("rejected"):
        return "rejected"
    # An acknowledgement is the proof of submission, so it lands in `applied`
    # rather than falling through to "other" — every ATS states it as
    # "Application Received", never as "Applied".
    if text.startswith("applied") or text.startswith("application received"):
        return "applied"
    if text.startswith("lead") or text.startswith("rezi"):
        return "lead"
    if "screening" in text or "follow-up required" in text:
        return "screening"
    if re.search(r"draft|packet|\bjd\b", text):
        return "prep"
    return "other"


def normalize(text: str) -> str:
    return re.sub(r"[^a-z0-9 ]+", " ", (text or "").lower()).strip()


def company_key(company: str) -> str:
    """The phrase to look for in a message, or "" when the record cannot identify
    an employer (a role name, a single generic word). A wrong join is worse than
    no join: the pipeline reads as one employer's mail if it points elsewhere."""
    words = [w for w in normalize(company).split() if w not in LEGAL_SUFFIXES]
    distinctive = [w for w in words if w not in ROLE_WORDS and len(w) >= 4]
    if not distinctive:
        return ""
    return " ".join(words)


def get(url: str, timeout: float = 60.0) -> object:
    with urllib.request.urlopen(url, timeout=timeout) as response:
        return json.loads(response.read().decode() or "null")


def post(url: str, payload: dict, timeout: float = 60.0) -> object:
    request = urllib.request.Request(
        url,
        data=json.dumps(payload).encode(),
        headers={"content-type": "application/json"},
        method="POST",
    )
    with urllib.request.urlopen(request, timeout=timeout) as response:
        body = response.read().decode() or "null"
    return json.loads(body)


def upsert(api: str, records: list[dict]) -> int:
    """One POST per record. Every parameter is sent on every call: NpgsqlRest
    answers a missing key with a 404, so a sparse record is padded with nulls."""
    written = 0
    for record in records:
        # JSON keys are camelCased (the same convention the responses use), so the
        # record's snake_case fields are translated here rather than at each use.
        # A key NpgsqlRest does not know is a 404 with no body.
        payload = {
            "id": record.get("id"),
            "company": record.get("company") or "unknown",
            "role": record.get("role") or "unknown",
            "category": record.get("category") or "other",
            "language": record.get("language") or "en",
            "fit": record.get("fit"),
            "status": record.get("status") or "",
            "stage": stage_of(record.get("status") or ""),
            "nextAction": record.get("next_action"),
            "applyUrl": record.get("apply_url"),
            "coverLetterUrl": record.get("cover_letter_url"),
            "resumeUrl": record.get("resume_url"),
            "gmail": record.get("gmail"),
            "reviewFlag": record.get("review_flag"),
            "notes": record.get("notes"),
            "folderPath": record.get("folder_path"),
            "messageId": record.get("message_id"),
            "recruiterEmail": record.get("recruiter_email"),
            "createdAt": record.get("created_at"),
            "updatedAt": record.get("updated_at"),
            "origin": record.get("origin") or "import",
        }
        if not payload["id"]:
            print(f"skip record with no id: {payload['company']}", file=sys.stderr)
            continue
        post(f"{api}/api/application-upsert", payload)
        written += 1
    return written


def link(api: str, limit: int) -> tuple[int, int]:
    applications = get(f"{api}/api/applications?lim=5000") or []
    messages = get(f"{api}/api/list-emails?lim={limit}") or []
    if not applications or not messages:
        return 0, 0

    # One rule: the employer's name appears in the sender or the subject. Token
    # matching was removed after it filed one application's mail under unrelated
    # companies, and a diluted guess is the one thing this join must not do.
    keys = [
        (application["id"], company_key(application.get("company") or ""))
        for application in applications
    ]
    keys = [(application_id, phrase) for application_id, phrase in keys if phrase]

    exact = 0
    guessed = 0
    for message in messages:
        haystack = normalize(f"{message.get('sender') or ''} {message.get('subject') or ''}")
        if not haystack:
            continue
        for application_id, phrase in keys:
            if len(phrase) < 4 or phrase not in haystack:
                continue
            confidence, matched_by = 0.9, "company"
            post(
                f"{api}/api/application-link",
                {
                    "messageId": message["messageId"],
                    "applicationId": application_id,
                    "matchedBy": matched_by,
                    "confidence": confidence,
                },
            )
            guessed += 1
            if confidence >= 0.9:
                exact += 1

    # A record's own message_id is not a guess: it is the message the workflow
    # filed the application from.
    known = {message["messageId"] for message in messages}
    for application in applications:
        message_id = application.get("message_id")
        if message_id and message_id in known:
            post(
                f"{api}/api/application-link",
                {
                    "messageId": message_id,
                    "applicationId": application["id"],
                    "matchedBy": "message_id",
                    "confidence": 1.0,
                },
            )
            exact += 1
    return exact, guessed


# Which mail changes the pipeline, and to what. A status is only written when the
# message says one of these things plainly; anything else leaves the mail
# unresolved for a person, which is why `review` exists as a tier.
EVENTS: list[tuple[str, str, str]] = [
    (
        "rejected",
        # English ATS rejections state a decision; German ones often do not say
        # `leider` or `Absage` at all. A real rejection read "Nach intensiver
        # Rücksprache im Team haben wir uns allerdings entschieden, den Prozess
        # mit anderen Kandidatinnen fortzusetzen" and fell through to no event,
        # so the application stayed at interview. These phrases are the German
        # shape of the same decision; a generic "wir können nicht jede Bewerbung
        # berücksichtigen" footer is deliberately absent, because acknowledgements
        # carry it and would turn into rejections.
        r"leider|absage|abgelehnt|unfortunately|unsuccessful|not to proceed|rejected|other candidates"
        r"|ander(?:e|en|er) kandidat|ander(?:e|en|er) bewerber|ander(?:e|en) person entschieden"
        r"|nicht weiterverfolg|nicht fortzusetzen|nicht fortführen|nicht fortfuehren"
        r"|nicht geklappt|anderweitig besetzt|keine zusage|bedauerlicherweise",
        "Rejected",
    ),
    ("interview", r"interview|vorstellungsgespr|kennenzulernen|einladung|invite|trial|warteliste|probearbeit", "Interview"),
    (
        "action",
        # "Unterlagen" alone is not a request: an acknowledgement says "wir haben
        # deine Unterlagen erhalten", and matching the noun filed it as a missing
        # document. The request is the verb around the noun.
        r"nachreichen|unterlagen (?:nach|ein)reichen|fehlende unterlagen|vollständige unterlagen"
        r"|unterlagen senden|senden sie uns|rückfrage|questionnaire|aufgabe"
        r"|please provide|please send|missing document",
        "Follow-up Required",
    ),
    (
        "received",
        # The German ATS wording is the subject line itself: "Deine Bewerbung als
        # Software Engineer" with no verb at all, which is why an acknowledgement
        # used to reach no event and stay in the queue. Order matters — this row
        # sits last, so `leider` (rejected) and `Einladung` (interview) win first.
        r"erhalten|received|eingang|thank you for your application|bewerbung ist bei uns"
        r"|deine bewerbung|bewerbung (?:als|bei)|thanks for applying|thank you for applying"
        r"|application (?:was )?(?:sent|submitted)",
        "Application Received",
    ),
]

# An ATS relay sends job alerts from the same address as application mail
# (`noreply@join.com`), so sender routing cannot separate them: the alert reaches
# the pipeline's queue and, with no linked application, used to create a
# `discovered` record for an employer that never received an application. The
# subject is where an alert says what it is.
ALERT_MARKERS = (
    "vollzeitstelle",
    "teilzeitstelle",
    "aushilfe",
    "stellenangebot",
    "stellenanzeige",
    "stellenvorschlag",
    "stellenmarkt",
    "jobangebot",
    "jobempfehlung",
    "job alert",
    "passende jobs",
    "jobs für dich",
    "diese jobs",
    "neue jobs",
    "new jobs",
    "recommended jobs",
    "job recommendation",
)


def job_alert(subject: str) -> str:
    """The marker that says a message is an alert, or "" when it is not one."""
    lowered = (subject or "").lower()
    return next((marker for marker in ALERT_MARKERS if marker in lowered), "")


# An acknowledgement often mentions the interview it might lead to: "Wenn wir
# weitere Fragen haben oder dich zu einem Vorstellungsgespräch einladen möchten".
# Counting that as an invite put a candidate at interview on the day they applied.
CONDITIONAL_INVITE = re.compile(
    r"(?:wenn|falls|sollten|möchten|ggf\.?|gegebenenfalls|eventuell)[^.]{0,140}"
    r"(?:vorstellungsgespr|kennenzulernen|einlad)"
)


def detect_event(text: str) -> tuple[str, str] | None:
    lowered = text.lower()
    received = next((pattern for kind, pattern, _ in EVENTS if kind == "received"), "")
    conditional = bool(CONDITIONAL_INVITE.search(lowered) and re.search(received, lowered))
    for kind, pattern, label in EVENTS:
        if kind == "interview" and conditional:
            continue
        if re.search(pattern, lowered):
            return kind, label
    return None


# How far along a message puts an application. The sync walks a mailbox's worth
# of mail per applicant in order, so without this an acknowledgement from
# September overwrote an interview from October: the queue is newest-first and
# the last write won. A status only moves forward, and `rejected` is terminal
# until a human says otherwise.
EVENT_RANK = {"received": 1, "action": 2, "interview": 3, "rejected": 4}
STAGE_RANK = {"lead": 0, "prep": 0, "other": 1, "applied": 1, "screening": 2, "interview": 3, "rejected": 4}


def sync(api: str, apply: bool, limit: int, ledger_path: str, only: str = "") -> int:
    """Read the agent's ATS queue, write what the mail proves, close the mail.

    Writes are conservative by construction: one message, one unambiguous
    application, one plain statement. A message that matches two applications of
    the same employer is left open and recorded as ambiguous rather than
    guessing, because a wrong status is worse than a stale one.

    `only` narrows the run to one message id. A replay after a rule fix must not
    re-walk the queue and rewrite records the fix was not about, so the timer
    runs all of it and a correction runs one.
    """
    queue = get(f"{api}/api/agent-queue?owner=agent:apps&lim={limit}") or []
    if only:
        queue = [row for row in queue if row.get("messageId") == only]
        if not queue:
            print(f"pipeline sync: {only} is not in the queue (resolve is a one-way close)")
            return 1
    if not queue:
        print("pipeline sync: nothing in the queue")
        return 0

    # Oldest first: the newest message is the one that decides the current status.
    queue.sort(key=lambda row: row.get("sentAt") or "")

    # Query parameters are camelCased by NpgsqlRest too, which cost a 404 to
    # learn: `?messageId=`, not `?message_id=`.
    catalogue = get(f"{api}/api/applications?lim=5000") or []
    phrases = [
        (row, company_key(row.get("company") or "")) for row in catalogue
    ]
    phrases = [(row, phrase) for row, phrase in phrases if phrase]

    written = ambiguous = unprovable = discovered = alerts = closed = 0
    ledger = open(ledger_path, "a", encoding="utf-8")
    for item in queue:
        message_id = item.get("messageId")
        subject = item.get("subject") or ""
        applications = get(
            f"{api}/api/message-applications?messageId={urllib.parse.quote(message_id)}"
        ) or []

        # Bulk mail from a lifecycle sender: an alert proves nothing about an
        # application even when the body happens to mention an interview or a
        # phrase link already attached it to one. The subject is the message's
        # own account of what it is, and a subject that states an event is not an
        # alert whatever marker it carries ("… auf unser Stellenangebot … wurde
        # abgelehnt"). Closed here so the queue stops offering it, and before the
        # discovery rule can turn an employer that never saw an application into
        # a record.
        marker = job_alert(subject)
        if marker and detect_event(subject) is None:
            alerts += 1
            ledger.write(
                json.dumps(
                    {
                        "action": "job-alert" if apply else "job-alert (dry)",
                        "message_id": message_id,
                        "subject": subject,
                        "marker": marker,
                        "linked": [row["id"] for row in applications],
                    }
                )
                + "\n"
            )
            if apply:
                post(f"{api}/api/triage-resolve", {"messageId": message_id})
            continue

        # A link is only one way a message gets attributed: an ATS relay
        # (`noreply@join.com`) names the employer in the body, not the sender.
        # Read the message, and when exactly one application's name appears,
        # record the link that missed.
        if not applications:
            body = get(f"{api}/api/message-body?messageId={urllib.parse.quote(message_id)}") or [{}]
            body = body[0] or {}
            haystack = normalize(
                f"{body.get('sender') or ''} {subject} {body.get('bodyPlain') or ''}"
            )
            hits = [row for row, phrase in phrases if phrase in haystack]
            if len(hits) == 1:
                post(
                    f"{api}/api/application-link",
                    {
                        "messageId": message_id,
                        "applicationId": hits[0]["id"],
                        "matchedBy": "body",
                        "confidence": 0.8,
                    },
                )
                applications = hits

        # Still nothing: the mail names an employer the pipeline does not have.
        # That is the hub hydrating the tracker — a record with provenance, so the
        # interface shows the application instead of an empty queue.
        if not applications:
            employer = extract_employer(subject)
            if employer:
                applications = [discover(api, employer, item, "discovered")]
                discovered += 1
                ledger.write(
                    json.dumps(
                        {
                            "action": "discovered",
                            "message_id": message_id,
                            "company": employer,
                            "application": applications[0]["id"],
                            "subject": subject,
                        }
                    )
                    + "\n"
                )

        # Their pipeline keeps several records per employer (a role variant, a
        # re-application). Refusing every such message left 21 of 40 untouched,
        # so when the employer is the same record set the sync picks the role the
        # subject names, then the most recently touched one, and the ledger
        # carries the alternatives so a wrong choice is visible and correctable.
        alternatives: list[str] = []
        if len(applications) > 1:
            subject_words = normalize(subject)
            scored = []
            for candidate in applications:
                tokens = [
                    word
                    for word in normalize(candidate.get("role") or "").split()
                    if len(word) >= 4 and word not in ROLE_WORDS
                ]
                hits = sum(1 for token in tokens if token in subject_words)
                scored.append((hits, candidate.get("updated_at") or "", candidate))
            scored.sort(key=lambda row: (row[0], row[1]), reverse=True)
            applications = [scored[0][2]]
            alternatives = [row[2]["id"] for row in scored[1:]]

        if len(applications) != 1:
            ambiguous += 1
            ledger.write(
                json.dumps(
                    {
                        "action": "ambiguous" if applications else "unlinked",
                        "message_id": message_id,
                        "subject": subject,
                        "applications": [row["id"] for row in applications],
                    }
                )
                + "\n"
            )
            continue

        target = applications[0]

        # A discovered record is one row per employer and its role is literally
        # "undiscovered": a later message about a different role at the same
        # employer would attach its status to this application. avenit's
        # "Senior Generative AI Engineer" rejection landed on the IT
        # Systemadministrator record this way. Only the resolver, which knows
        # which message discovered the record, may move it.
        if (target.get("role") or "") == "undiscovered":
            ambiguous += 1
            ledger.write(
                json.dumps(
                    {
                        "action": "ambiguous-undiscovered",
                        "message_id": message_id,
                        "application": target["id"],
                        "subject": subject,
                    }
                )
                + "\n"
            )
            continue

        body = get(f"{api}/api/message-body?messageId={urllib.parse.quote(message_id)}") or [{}]
        text = f"{subject}\n{(body[0] or {}).get('bodyPlain') or ''}"
        event = detect_event(text)
        if event is None:
            # ATS boilerplate ("please accept the privacy policy", "continue your
            # application") carries no status, and leaving it open fills the
            # plugin's queue with messages nobody can act on. The agent has done
            # the work by reading it; the ledger keeps what it read.
            unprovable += 1
            ledger.write(
                json.dumps({"action": "resolved-noise" if apply else "no-event", "message_id": message_id, "application": target["id"], "subject": subject})
                + "\n"
            )
            if apply:
                post(f"{api}/api/triage-resolve", {"messageId": message_id})
            continue

        kind, label = event
        if EVENT_RANK[kind] <= STAGE_RANK.get(target.get("stage") or "other", 1):
            # Read and understood, but the stage already covers it: an
            # acknowledgement that arrives after the application was logged moves
            # nothing. Leaving it open made the same mail reappear on every run
            # and re-enter the queue forever, so it is closed with the reason
            # written down instead.
            closed += 1
            ledger.write(
                json.dumps(
                    {
                        "action": "resolved-backwards" if apply else "skip-backwards",
                        "message_id": message_id,
                        "application": target["id"],
                        "stage": target.get("stage"),
                        "event": kind,
                        "subject": subject,
                    }
                )
                + "\n"
            )
            if apply:
                post(f"{api}/api/triage-resolve", {"messageId": message_id})
            continue

        sent = (item.get("sentAt") or "")[:10]
        status = f"{label} (email {sent or 'undated'})"
        next_action = {
            "rejected": "none",
            "interview": "reply and book the interview",
            "action": "send the documents they asked for",
            "received": "wait for their decision",
        }[kind]
        record = {
            "action": "apply" if apply else "would-apply",
            "message_id": message_id,
            "application": target["id"],
            "company": target["company"],
            "from": target["status"],
            "to": status,
            "stage": stage_of(status),
            "next_action": next_action,
            "subject": subject,
        }
        if alternatives:
            record["alternatives"] = alternatives
        if apply:
            post(
                f"{api}/api/application-update",
                {
                    "id": target["id"],
                    "status": status,
                    "stage": stage_of(status),
                    "nextAction": next_action,
                },
            )
            post(f"{api}/api/triage-resolve", {"messageId": message_id})
        ledger.write(json.dumps(record) + "\n")
        written += 1
        print(f"{'wrote' if apply else 'would write'}  {target['company'][:30]:<30} {target['status'][:28]:<28} -> {status}")

    ledger.close()

    print(
            f"pipeline sync: {written} {'updated' if apply else 'to update'}, {discovered} discovered,"
            f" {alerts} job alert(s) closed, {closed} already reflected in the stage,"
            f" {ambiguous} ambiguous or unnamed, {unprovable} with no provable event (ledger: {ledger_path})"
        )
    return 0


# An ATS relay names the employer in the subject, not in the sender: the mail
# comes from `noreply@join.com` and says "Willkommen bei AmRest". These patterns
# are the whole of the discovery rule — a message that matches none of them is
# left for a person rather than turned into a record.
EMPLOYER_PATTERNS = [
    r"bewerbung (?:als [^\-–|,]{1,40}?\s)?bei ([A-ZÄÖÜ][\w&.\- ]{2,40})",
    r"deine bewerbung bei ([A-ZÄÖÜ][\w&.\- ]{2,40})",
    r"bewerbung bei ([A-ZÄÖÜ][\w&.\- ]{2,40})",
    r"willkommen bei ([A-ZÄÖÜ][\w&.\- ]{2,40})",
    r"gesetzt ihre bewerbung fort bei ([A-ZÄÖÜ][\w&.\- ]{2,40})",
    r"application (?:for [^\-–|,]{1,40}?\s)?(?:at|with) ([A-Z][\w&.\- ]{2,40})",
    r"your application (?:to|at) ([A-Z][\w&.\- ]{2,40})",
    r"welcome to ([A-Z][\w&.\- ]{2,40})",
    # The acknowledgement templates that name the employer after the verb.
    # "Thank you for applying at Vitruvi" had no pattern and stayed unattributed
    # even though the employer is right there in the subject.
    r"thank(?:s| you) for applying (?:at|to) ([A-Z][\w&.\- ]{2,40})",
    # Personio's own template is "<FirstName> x <Employer> // <Role>": the
    # employer sits before the separator, so every "Bewerbung … bei …" pattern
    # above misses it and the acknowledgement stays unattributed.
    r"^[^/]{1,40}? x ([^/]{2,40}?) //",
]


def extract_employer(subject: str) -> str:
    """The employer a message names, or "" when it does not name one."""
    for pattern in EMPLOYER_PATTERNS:
        match = re.search(pattern, subject or "", re.IGNORECASE)
        if not match:
            continue
        candidate = re.split(r"[\-–|!,(]", match.group(1))[0].strip(" .")
        words = normalize(candidate).split()
        if len(candidate) < 3 or not words:
            continue
        if all(word in ROLE_WORDS or word in LEGAL_SUFFIXES for word in words):
            continue
        return candidate
    return ""


def discover(api: str, company: str, message: dict, origin: str) -> dict:
    """Create (or refresh) the pipeline record the mail just revealed."""
    slug = re.sub(r"[^a-z0-9]+", "-", normalize(company)).strip("-")[:48] or "unknown"
    record = {
        "id": f"discovered-{slug}",
        "company": company,
        "role": "",
        "category": "other",
        "language": "en",
        "fit": None,
        "status": f"Discovered from mail ({((message.get('sentAt') or '')[:10])})",
        "stage": "applied",
        "next_action": "confirm and record the application",
        "messageId": message.get("messageId"),
        "createdAt": message.get("sentAt"),
        "updatedAt": message.get("sentAt"),
        "origin": "discovered",
    }
    post(
        f"{api}/api/application-upsert",
        {
            "id": record["id"],
            "company": record["company"],
            # The workflow's schema requires role and category; "undiscovered"
            # says plainly that the mail did not tell us which role it was.
            "role": "undiscovered",
            "category": "other",
            "language": "en",
            "fit": None,
            "status": record["status"],
            "stage": record["stage"],
            "nextAction": record["next_action"],
            "applyUrl": None,
            "coverLetterUrl": None,
            "resumeUrl": None,
            "gmail": None,
            "reviewFlag": "discovered",
            "notes": f"Found by the mail hub from: {message.get('subject') or ''}",
            "folderPath": None,
            "messageId": record["messageId"],
            "recruiterEmail": None,
            "createdAt": record["createdAt"],
            "updatedAt": record["updatedAt"],
            "origin": "discovered",
        },
    )
    post(
        f"{api}/api/application-link",
        {
            "messageId": record["messageId"],
            "applicationId": record["id"],
            "matchedBy": "discovered",
            "confidence": 0.6,
        },
    )
    return record


def export_json(api: str, destination: str) -> int:
    """Write `applications.json` from the database: the export half of the sunset.

    The workflow repo keeps a committed copy for its Typst build and its history,
    so the shape has to stay exactly what it reads today, snake_case and all.
    """
    rows = get(f"{api}/api/applications-export") or []
    records = []
    for row in rows:
        records.append(
            {
                "id": row.get("id"),
                "company": row.get("company"),
                "role": row.get("role"),
                "category": row.get("category"),
                "language": row.get("language"),
                "fit": row.get("fit"),
                "status": row.get("status"),
                "next_action": row.get("nextAction") or "",
                "apply_url": row.get("applyUrl") or "",
                "cover_letter_url": row.get("coverLetterUrl") or "",
                "resume_url": row.get("resumeUrl") or "",
                "gmail": row.get("gmail") or "",
                "review_flag": row.get("reviewFlag") or "",
                "notes": row.get("notes") or "",
                "folder_path": row.get("folderPath") or "",
                "message_id": row.get("messageId") or "",
                "recruiter_email": row.get("recruiterEmail") or "",
                "created_at": row.get("createdAt"),
                "updated_at": row.get("updatedAt"),
            }
        )

    text = json.dumps(records, indent=2, ensure_ascii=False) + "\n"
    if destination == "-":
        sys.stdout.write(text)
    else:
        with open(destination, "w", encoding="utf-8") as handle:
            handle.write(text)
        print(f"exported {len(records)} applications to {destination}")
    return 0


def report(api: str, as_json: bool = False) -> None:
    pipeline = get(f"{api}/api/application-pipeline") or []
    total = sum(row.get("applications") or 0 for row in pipeline)
    attention = get(f"{api}/api/application-attention?lim=10") or []
    if as_json:
        print(
            json.dumps(
                {
                    "applications": total,
                    "stages": [
                        {
                            "stage": row.get("stage"),
                            "count": row.get("applications"),
                            "withNextAction": row.get("withNextAction", 0),
                        }
                        for row in pipeline
                    ],
                    "open_mail": len(attention),
                },
                ensure_ascii=False,
            )
        )
        return
    print(f"applications: {total}")
    for row in pipeline:
        print(f"  {row['stage']:<10} {row['applications']:>4}  (next action: {row.get('withNextAction', 0)})")
    print(f"open mail on an application: {len(attention)} (showing 10)")
    for row in attention[:10]:
        print(f"  {row['stage']:<10} {row['company'][:34]:<34} {row['subject'][:48]}")


# A draft needs a From: himalaya takes the SMTP envelope sender from that header
# and refuses to send without it, so a draft saved without one can never be sent
# as-is. Which address is a property of the mailbox, not of the letter.
SENDER = os.environ.get("APPFLOW_SENDER", "Matt Ji <matt@bountystash.com>")

# A subject is the only part of a letter that can be defaulted safely: the body
# is prose a person signed, so it is always an input, never a template.
DRAFT_SUBJECTS = {
    "de": "Bewerbung – {role} bei {company}",
    "en": "Application – {role} at {company}",
}


def draft_message(
    application: dict, body: str, to: str, attachments: list[str], subject: str = ""
) -> EmailMessage:
    language = (application.get("language") or "en").strip().lower()
    template = DRAFT_SUBJECTS["de"] if language.startswith(("de", "ger")) else DRAFT_SUBJECTS["en"]
    message = EmailMessage()
    message["From"] = SENDER
    # A reply keeps the thread's subject; only a fresh application gets the
    # generated one, because a reply that starts a new thread reads as bulk.
    message["Subject"] = subject or template.format(
        role=application.get("role") or "—", company=application.get("company") or "—"
    )
    if to:
        message["To"] = to
    message["Date"] = formatdate(localtime=True)
    message["Message-ID"] = make_msgid()
    message.set_content(body)
    for path in attachments:
        with open(path, "rb") as handle:
            data = handle.read()
        name = os.path.basename(path)
        maintype, subtype = ("application", "pdf") if name.lower().endswith(".pdf") else (
            "application",
            "octet-stream",
        )
        message.add_attachment(data, maintype=maintype, subtype=subtype, filename=name)
    return message


def save_draft(
    api: str,
    himalaya_config: str,
    mailbox: str,
    application_id: str,
    body_path: str,
    to: str,
    attachments: list[str],
    dry_run: bool,
    subject: str = "",
) -> dict:
    rows = get(f"{api}/api/application-get?id={urllib.parse.quote(application_id)}") or []
    if not rows:
        raise RuntimeError(f"no application {application_id}")
    application = rows[0]
    body = sys.stdin.read() if body_path == "-" else open(body_path, encoding="utf-8").read()
    recipient = to or application.get("recruiterEmail") or application.get("gmail") or ""
    message = draft_message(application, body, recipient, attachments, subject)
    raw = message.as_string()
    result = {
        "application": application_id,
        "mailbox": mailbox,
        "subject": message["Subject"],
        "to": message.get("To", ""),
        "attachments": [os.path.basename(path) for path in attachments],
        "bytes": len(raw.encode()),
        "saved": False,
    }
    if dry_run:
        return result
    cmd = ["himalaya", "-c", himalaya_config, "message", "add", "-m", mailbox, "-f", "draft"]
    proc = subprocess.run(cmd, input=raw, capture_output=True, text=True, timeout=120)
    if proc.returncode != 0:
        raise RuntimeError(f"himalaya message add failed: {(proc.stderr or proc.stdout).strip()[:300]}")
    result["saved"] = True
    return result


def list_drafts(himalaya_config: str, mailbox: str, limit: int) -> list[dict]:
    cmd = [
        "himalaya", "-c", himalaya_config, "--json", "envelope", "list",
        "-m", mailbox, "-s", str(limit),
    ]
    proc = subprocess.run(cmd, capture_output=True, text=True, timeout=120)
    if proc.returncode != 0:
        raise RuntimeError(f"himalaya envelope list failed: {(proc.stderr or proc.stdout).strip()[:300]}")
    # himalaya answers `{"queued": n, "envelopes": […]}` when --json is set, not
    # a bare array: reading it as one is an AttributeError, not an empty folder.
    payload = json.loads(proc.stdout or "{}")
    rows = payload.get("envelopes") if isinstance(payload, dict) else payload
    drafts = []
    for row in rows or []:
        drafts.append(
            {
                "id": row.get("id"),
                "subject": row.get("subject") or "",
                "date": row.get("date") or "",
                "flags": row.get("flags") or [],
                "has_attachment": row.get("has-attachment"),
            }
        )
    return drafts


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--api", default=os.environ.get("EMAIL_ARCHIVE_API", "http://127.0.0.1:8080"))
    parser.add_argument("--file", default="", help="applications.json, or - for stdin")
    parser.add_argument("--link", action="store_true", help="match archived mail to applications")
    parser.add_argument("--link-limit", type=int, default=3000, help="messages considered when linking")
    parser.add_argument("--export", default="", help="write applications.json from the database (- for stdout)")
    parser.add_argument("--report", action="store_true")
    parser.add_argument("--sync", action="store_true", help="write status from the ATS mail queue")
    parser.add_argument("--only", default="", help="with --sync: one message id, for a replay after a rule fix")
    parser.add_argument("--apply", action="store_true", help="with --sync: write the changes (default is a dry run)")
    parser.add_argument("--sync-limit", type=int, default=50)
    parser.add_argument(
        "--ledger",
        default=os.path.expanduser("~/.local/state/email-archive/apps-sync.jsonl"),
    )
    parser.add_argument("--update", default="", help="application id whose status changes")
    parser.add_argument("--status", default="", help="with --update: the new status text")
    parser.add_argument("--next", default="", help="with --update: the next action")
    parser.add_argument("--draft", default="", help="application id to draft a reply for")
    parser.add_argument("--body", default="-", help="draft body file, or - for stdin")
    parser.add_argument("--to", default="", help="recipient; defaults to the record's recruiter or gmail")
    parser.add_argument("--attach", action="append", default=[], help="file to attach (repeatable)")
    parser.add_argument("--drafts", action="store_true", help="list the mailbox's drafts")
    parser.add_argument(
        "--subject",
        default="",
        help="with --draft: the thread's subject; empty generates one from the record",
    )
    parser.add_argument(
        "--himalaya-config",
        default=os.path.expanduser("~/.config/himalaya/config.toml"),
        help="himalaya config; the account password lives there as a command",
    )
    parser.add_argument("--draft-mailbox", default="Drafts")
    parser.add_argument(
        "--json",
        action="store_true",
        help="structured output; pipe through `toon -e` for an agent",
    )
    args = parser.parse_args()

    api = args.api.rstrip("/")

    if args.file:
        raw = sys.stdin.read() if args.file == "-" else open(args.file, encoding="utf-8").read()
        records = json.loads(raw)
        if not isinstance(records, list):
            print("applications: the source is not a JSON array", file=sys.stderr)
            return 2
        print(f"imported {upsert(api, records)} of {len(records)} records")

    if args.link:
        exact, guessed = link(api, args.link_limit)
        print(f"links: {exact} from an explicit message id or a company phrase, {guessed} matched in total")

    if args.export:
        export_json(api, args.export)

    if args.sync:
        os.makedirs(os.path.dirname(args.ledger), exist_ok=True)
        sync(api, args.apply, args.sync_limit, args.ledger, args.only)

    if args.report:
        report(api, args.json)

    if args.update:
        if not args.status:
            print("appflow-sync: --update needs --status", file=sys.stderr)
            return 2
        stage = stage_of(args.status)
        post(
            f"{api}/api/application-update",
            {
                "id": args.update,
                "status": args.status,
                "stage": stage,
                "nextAction": args.next,
            },
        )
        if args.json:
            print(json.dumps({"id": args.update, "status": args.status, "stage": stage}))
        else:
            print(f"{args.update}  stage={stage}  status={args.status}")

    if args.draft:
        result = save_draft(
            api,
            args.himalaya_config,
            args.draft_mailbox,
            args.draft,
            args.body,
            args.to,
            args.attach,
            dry_run=not args.apply,
            subject=args.subject,
        )
        if args.json:
            print(json.dumps(result, ensure_ascii=False))
        else:
            state = "saved" if result["saved"] else "would save"
            attachments = ", ".join(result["attachments"]) or "no attachment"
            print(
                f"{state} draft  {result['application']}\n"
                f"  mailbox  {result['mailbox']}\n"
                f"  to       {result['to'] or '(no recipient)'}\n"
                f"  subject  {result['subject']}\n"
                f"  attached {attachments}"
            )

    if args.drafts:
        drafts = list_drafts(args.himalaya_config, args.draft_mailbox, 20)
        if args.json:
            print(json.dumps(drafts, ensure_ascii=False))
        else:
            print(f"{len(drafts)} draft(s) in {args.draft_mailbox}")
            for row in drafts:
                print(f"  {(row['date'] or '')[:10]:<10} {row['subject'][:70]}")

    return 0


if __name__ == "__main__":
    sys.exit(main())
