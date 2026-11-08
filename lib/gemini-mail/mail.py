#!/usr/bin/env python3
"""The mail archive over Gemini: one program, five modes.

Run by the wrappers the capsule installs in `cgi-bin/` — `email` (search),
`latest` (newest messages), `read` (one message by id), `attention` (what needs
a person) and `attachment` (where a file lives, never the file). The wire
format is the Gemini CGI one the rest of the fleet already uses: the script
writes the status line and then the document, and the server passes both
through unchanged. A search with no query answers `10`, which is how a Gemini
client is asked for input.

Why a CGI and not a page generated at build time: mail arrives every hour, and
a capsule built at deploy time would answer yesterday's archive.
"""

import json
import os
import sys
import urllib.error
import urllib.parse
import urllib.request

API = os.environ.get("EMAIL_ARCHIVE_API", "http://127.0.0.1:8080/api")
TIMEOUT = 8
BODY_LIMIT = 48 * 1024
QUERY_LIMIT = 200
RESULT_TITLE = 70
ATTENTION_DEFAULT = 20
ATTENTION_MAX = 100
# The order the archive sorts by: a person's mail first, then a judgement call,
# then something an action would close.
TIERS = [("person", "Person"), ("review", "Review"), ("action", "Action")]
FULL = "text/gemini; charset=utf-8"

# Never through an http_proxy: the archive is loopback-only, and a proxy would
# turn a local read into a remote request.
OPENER = urllib.request.build_opener(urllib.request.ProxyHandler({}))


class Archive(Exception):
    """The archive could not answer. A 40, never a 51: the message may exist."""


def status(line):
    sys.stdout.write(line + "\r\n")
    sys.stdout.flush()


def document(body):
    sys.stdout.write("20 " + FULL + "\r\n")
    sys.stdout.write(body)
    sys.stdout.flush()


def fetch(path, params):
    url = API + path + "?" + urllib.parse.urlencode(params, quote_via=urllib.parse.quote)
    request = urllib.request.Request(url, headers={"User-Agent": "gemini-mail/1"})
    try:
        with OPENER.open(request, timeout=TIMEOUT) as response:
            return json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as error:
        raise Archive(f"the archive answered {error.code} for {path}")
    except (urllib.error.URLError, TimeoutError, ValueError) as error:
        raise Archive(f"the archive did not answer ({error})")


def flat(value, limit):
    """One line, whitespace collapsed: gemtext is line-oriented and a status
    meta is one line by definition."""
    text = " ".join((value or "").split())
    return text[: limit - 1] + "…" if len(text) > limit else text


def day(stamp):
    text = stamp or ""
    return text[:10] if len(text) >= 10 else "—"


def human_size(count):
    return f"{count / 1000:.1f}k" if count >= 1000 else str(count)


def link(url, label):
    return f"=> {url} {label}"


def read_url(message_id):
    return "/cgi-bin/read?" + urllib.parse.quote(message_id or "", safe="")


def attachment_url(message_id):
    return "/cgi-bin/attachment?" + urllib.parse.quote(message_id or "", safe="")


def fence_safe(body):
    """A preformatted block is closed by a line that starts with ``` — a mail
    body may contain one, so such a line gets a leading space."""
    text = (body or "").replace("\r\n", "\n").replace("\r", "\n")
    lines = [(" " + line) if line.startswith("```") else line for line in text.split("\n")]
    text = "\n".join(lines).rstrip("\n")
    if len(text) > BODY_LIMIT:
        text = text[:BODY_LIMIT].rstrip() + f"\n\n[truncated at {human_size(BODY_LIMIT)} characters]"
    return text


def search(query):
    rows = fetch("/emails-search", {"q": query})
    if not rows:
        document(
            f"# Nothing matches “{flat(query, QUERY_LIMIT)}”\n\n"
            "Try fewer words, or a wider term — the search covers subject, sender and body.\n\n"
            "=> /cgi-bin/email search again\n"
        )
        return
    noun = "message" if len(rows) == 1 else "messages"
    lines = [f"# {len(rows)} {noun} for “{flat(query, QUERY_LIMIT)}”", ""]
    for row in rows:
        label = " · ".join(
            [
                day(row.get("sentAt")),
                flat(row.get("sender"), 42),
                flat(row.get("subject") or "(no subject)", RESULT_TITLE),
            ]
        )
        lines.append(link(read_url(row.get("messageId")), label))
        snippet = flat((row.get("snippet") or "").replace("<<", "").replace(">>", ""), 240)
        if snippet:
            lines.append(snippet)
        lines.append("")
    lines += ["=> /cgi-bin/email search again", "=> /cgi-bin/latest newest messages"]
    document("\n".join(lines) + "\n")


def latest():
    rows = fetch("/list-emails", {"lim": 30})
    if not rows:
        document("# The archive is empty\n")
        return
    lines = ["# Newest messages", ""]
    for row in rows:
        label = " · ".join(
            [
                day(row.get("sentAt")),
                flat(row.get("sender"), 42),
                flat(row.get("subject") or "(no subject)", RESULT_TITLE),
                human_size(row.get("bodyLength") or 0),
            ]
        )
        lines.append(link(read_url(row.get("messageId")), label))
    lines += ["", "=> /cgi-bin/email search the archive"]
    document("\n".join(lines) + "\n")


def read(message_id):
    rows = fetch("/message-body", {"messageId": message_id})
    if not rows:
        status("51 no message with that id")
        return
    row = rows[0]
    lines = [
        f"# {flat(row.get('subject') or '(no subject)', 200)}",
        "",
        flat(row.get("sender"), 200),
        day(row.get("sentAt")),
        "",
    ]
    attachment = (row.get("attachmentPath") or "").rstrip("/")
    if attachment:
        # The archive names one directory per message, not a file, so the label
        # is that directory. The notice says where it is; the bytes stay put.
        lines += [
            link(
                attachment_url(row.get("messageId") or message_id),
                f"attachment {os.path.basename(attachment)} — where it lives, not served here",
            ),
            "",
        ]
    body = fence_safe(row.get("bodyPlain") or "")
    if body:
        lines += ["```text", body, "```"]
    else:
        # The importer stores the envelope first and the body when it has it.
        lines += ["(the archive holds no body for this message — envelope only)"]
    lines += [
        "",
        "=> /cgi-bin/email search the archive",
        "=> /cgi-bin/latest newest messages",
        "=> /cgi-bin/attention what needs a person",
    ]
    document("\n".join(lines) + "\n")


def tier_heading(tier, rows):
    label = dict(TIERS).get(tier, tier)
    count = sum(1 for row in rows if (row.get("tier") or "") == tier)
    return f"## {label} ({count})"


def attention(limit):
    rows = fetch("/attention", {"lim": limit})
    if not rows:
        document(
            "# Nothing needs a person\n\n"
            "Every open verdict is owned by an agent, or resolved. The agent queues\n"
            "are not this page: this is the one that is about people.\n\n"
            "=> /cgi-bin/latest newest messages\n"
            "=> /mail/ the archive\n"
        )
        return
    # The classifier's own reason already ends in its confidence ("… (0.39)"),
    # so the row carries it once and this page does not restate it.
    need = "needs" if len(rows) == 1 else "need"
    noun = "message" if len(rows) == 1 else "messages"
    lines = [
        f"# {len(rows)} {noun} {need} a person",
        "",
        "Person first, then review, then action. One row per message — the newest",
        "verdict from any classifier is the one that counts — and nothing an agent",
        "already owns appears here.",
        "",
    ]
    current = None
    for row in rows:
        tier = row.get("tier") or ""
        if tier != current:
            current = tier
            lines += [tier_heading(tier, rows), ""]
        label = " · ".join(
            [
                day(row.get("sentAt")),
                flat(row.get("sender"), 42),
                flat(row.get("subject") or "(no subject)", RESULT_TITLE),
            ]
        )
        lines.append(link(read_url(row.get("messageId")), label))
        reason = flat(row.get("reason") or "", 200)
        if reason:
            lines.append(f"* {reason}")
        lines.append("")
    # Reading is this capsule's job; resolving is a write, and a GET is the wrong
    # verb for one. The task is the acting path.
    lines += [
        "Resolving is a write, so this capsule does not do it. On the host:",
        "`task agents:mail:resolve ID=<id>` closes one message, and",
        "`task agents:mail:sweep` closes a block by sender, domain or tier.",
        "",
        "=> /cgi-bin/attention?50 fifty at a time",
        "=> /cgi-bin/latest newest messages",
        "=> /mail/ the archive",
    ]
    document("\n".join(lines) + "\n")


def attachment_notice(message_id):
    rows = fetch("/message-body", {"messageId": message_id})
    if not rows:
        status("51 no message with that id")
        return
    row = rows[0]
    path = (row.get("attachmentPath") or "").rstrip("/")
    subject = flat(row.get("subject") or "(no subject)", 200)
    if not path:
        document(
            f"# No attachment\n\nThe archived copy of “{subject}” names no attachment.\n\n"
            f"=> {read_url(message_id)} back to the message\n"
            "=> /cgi-bin/attention what needs a person\n"
        )
        return
    name = os.path.basename(path) or "unnamed"
    lines = [
        f"# Attachment {name}",
        "",
        f"From “{subject}” — {flat(row.get('sender'), 120)}, {day(row.get('sentAt'))}.",
        "",
        link(read_url(message_id), "back to the message"),
        "",
        "## Where it lives",
        "",
        "```text",
        path + "/",
        "```",
        "",
        "That is a directory on the host that serves this capsule, under the",
        "archive's attachment tree: one directory per message, named from a hash of",
        "the message id, holding every file that arrived with it. The tree is 0750",
        "and owned by the archive's service user, so this capsule can see the name",
        "and not the contents — no list, no bytes.",
        "",
        "A file is fetched on the host, as that user:",
        "",
        "```text",
        f"sudo -u npgsqlrest ls {path}/",
        f"sudo -u npgsqlrest cp -r {path}/ ~/attachments-{name}/",
        "```",
        "",
        "## Why it is not served here",
        "",
        "A capsule copy would be a second home for a file that already has one: the",
        "bytes would enter a store path, and reading mail would grow the capsule.",
        "The archive can mirror this tree to Google Drive on an hourly timer; that",
        "runs once the operator has written the rclone remote, and it is a mirror of",
        "the tree, not a route through this page.",
        "",
        "=> /cgi-bin/attention what needs a person",
        "=> /mail/ the archive",
    ]
    document("\n".join(lines) + "\n")


def main(argv):
    mode = argv[1] if len(argv) > 1 else "search"
    # The CGI contract hands the query over still percent-encoded. `+` is left
    # alone on purpose: a search for C++ is not a search for C.
    query = urllib.parse.unquote(os.environ.get("QUERY_STRING", "")).strip()[:QUERY_LIMIT]
    try:
        if mode == "search":
            if not query:
                status('10 Search the archive — words, "a phrase", OR, -excluded')
                return 0
            search(query)
        elif mode == "latest":
            latest()
        elif mode == "read":
            if not query:
                status("10 message id")
                return 0
            read(query)
        elif mode == "attachment":
            if not query:
                status("10 message id")
                return 0
            attachment_notice(query)
        elif mode == "attention":
            # The query is a count, not a word: `?50` asks for fifty.
            limit = int(query) if query.isdigit() else ATTENTION_DEFAULT
            attention(max(1, min(ATTENTION_MAX, limit)))
        else:
            status("40 unknown mode")
            return 0
    except Archive as error:
        status("40 " + flat(str(error), 120))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
