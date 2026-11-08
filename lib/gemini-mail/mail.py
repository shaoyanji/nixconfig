#!/usr/bin/env python3
"""The mail archive over Gemini: one program, three modes.

Run by the wrappers the capsule installs in `cgi-bin/` — `email` (search),
`latest` (newest messages) and `read` (one message by id). The wire format is
the Gemini CGI one the rest of the fleet already uses: the script writes the
status line and then the document, and the server passes both through
unchanged. A search with no query answers `10`, which is how a Gemini client
is asked for input.

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
    attachment = row.get("attachmentPath") or ""
    if attachment:
        lines += [f"attachment: {os.path.basename(attachment)} (named only, not in the capsule)", ""]
    body = fence_safe(row.get("bodyPlain") or "")
    if body:
        lines += ["```text", body, "```"]
    else:
        # The importer stores the envelope first and the body when it has it.
        lines += ["(the archive holds no body for this message — envelope only)"]
    lines += ["", "=> /cgi-bin/email search the archive", "=> /cgi-bin/latest newest messages"]
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
        else:
            status("40 unknown mode")
            return 0
    except Archive as error:
        status("40 " + flat(str(error), 120))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
