"""Make the atlas box agree with the mailbox about where each letter is.

The atlas knows two things about a letter and they can drift apart. `mail_box`
records what a decision did (queued, archived, trashed) — but mail is also moved
with a phone, a web client, a filter. A letter archived in Gmail stops being in
the IMAP Inbox and still counts as inbox here, so the working set inflates with
mail the person already handled, and the numbers in the header stop meaning
anything.

The mailbox is the truth. One run reads the Message-IDs of every envelope in the
source mailbox (`inbox`) and compares them with the boxes the archive holds:

  in the mailbox, box is archived/trashed/gone   -> inbox   (it came back)
  not in the mailbox, box is inbox               -> archived (it left, unasked)
  not in the mailbox, box is queued              -> gone     (left before the drain)

`archived` is the right verdict for a letter that left the inbox by any means:
Gmail has no Archive folder, so "not in Inbox" is exactly what archiving is, and
the atlas is not the place to argue about which client did it.

Two guards, because this rewrites 2000 rows when it is wrong:

  * the walk must complete. A read that stops at the page cap is a partial set,
    and a partial set reads as "everything below this page left the inbox" —
    a scan bounded by its own limit is the one failure mode that would empty
    the working set. An incomplete walk aborts before anything is written.
  * a failure to read is a failure to conclude. himalaya errors are raised, not
    swallowed into an empty inbox.

`--dry-run` prints the diff and writes nothing; it is the default in the task.
"""

import argparse
import json
import subprocess
import sys
import urllib.error
import urllib.request

INBOX = "inbox"
ARCHIVED = "archived"
GONE = "gone"
OUT = (ARCHIVED, "trashed", "gone")


def log(**fields):
    print(json.dumps(fields, ensure_ascii=False), flush=True)


def himalaya(argv, config, account, timeout=300):
    cmd = ["himalaya", "-c", config, "--json"]
    if account:
        cmd += ["-a", account]
    proc = subprocess.run(cmd + argv, capture_output=True, text=True, timeout=timeout)
    if proc.returncode != 0:
        detail = (proc.stderr.strip() or proc.stdout.strip())[:300]
        raise RuntimeError(f"himalaya {' '.join(argv[:2])} exited {proc.returncode}: {detail}")
    try:
        return json.loads(proc.stdout or "{}")
    except json.JSONDecodeError as exc:
        raise RuntimeError(f"himalaya returned non-JSON: {exc}") from exc


def api(base, path, payload=None):
    data = None if payload is None else json.dumps(payload).encode()
    request = urllib.request.Request(
        f"{base}{path}",
        data=data,
        headers={"Content-Type": "application/json"} if data else {},
    )
    with urllib.request.urlopen(request, timeout=120) as response:
        return json.load(response)


def normalize(message_id):
    return (message_id or "").strip().strip("<> ")


def mailbox_ids(config, account, mailbox, page_size, max_pages):
    """Every Message-ID in the mailbox, and whether the walk reached the end.

    Ordered newest first, so a short page is the end rather than a hole: paging
    stops at `--max-pages` only if the mailbox is bigger than that.
    """
    seen = set()
    pages = 0
    for page in range(1, max_pages + 1):
        doc = himalaya(
            ["envelope", "list", "-m", mailbox, "-s", str(page_size), "-p", str(page)],
            config,
            account,
        )
        envelopes = doc.get("envelopes") or []
        pages += 1
        for envelope in envelopes:
            key = normalize(envelope.get("message-id"))
            if key:
                seen.add(key)
        if len(envelopes) < page_size:
            return seen, True, pages
    return seen, False, pages


def plan(boxes, present):
    """What each archived letter's box should become. Ordered, so logs are stable."""
    changes = []
    for message_id, box in boxes:
        key = normalize(message_id)
        if not key:
            continue
        here = key in present
        if here and box in OUT:
            changes.append((message_id, INBOX, "back in the inbox"))
        elif not here and box == INBOX:
            changes.append((message_id, ARCHIVED, "left the inbox"))
        elif not here and box == "queued":
            changes.append((message_id, GONE, "left the inbox before the drain"))
    return changes


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--api", default="http://127.0.0.1:8080")
    parser.add_argument("--himalaya-config", required=True)
    parser.add_argument("--account", default="")
    parser.add_argument("--mailbox", default="inbox")
    parser.add_argument("--page-size", type=int, default=500)
    parser.add_argument("--max-pages", type=int, default=40)
    parser.add_argument("--limit", type=int, default=5000)
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    boxes = [(row.get("messageId"), row.get("box") or INBOX) for row in api(args.api, "/api/atlas-boxes")]
    present, complete, pages = mailbox_ids(
        args.himalaya_config, args.account, args.mailbox, args.page_size, args.max_pages
    )
    if not complete:
        log(
            run="mail-atlas-reconcile",
            ok=False,
            error=f"mailbox walk stopped at the {args.max_pages}-page cap; a partial set is not a verdict",
            mailbox_letters=len(present),
            archive_letters=len(boxes),
            pages_read=pages,
        )
        return 2

    changes = plan(boxes, present)[: args.limit]
    restored = [c for c in changes if c[1] == INBOX]
    archived = [c for c in changes if c[1] == ARCHIVED]
    gone = [c for c in changes if c[1] == GONE]

    failures = []
    if not args.dry_run:
        for message_id, box, why in changes:
            try:
                # camelCase, not the SQL parameter name: NpgsqlRest binds a JSON
                # property to `:message_id` only as `messageId`, and a name that
                # does not bind is a 404 with an empty body. `reason` is what the
                # trail shows the person, so it is a sentence, not a code.
                api(
                    args.api,
                    "/api/atlas-box-set",
                    {"messageId": message_id, "box": box, "reason": why},
                )
            except (urllib.error.URLError, RuntimeError) as exc:
                failures.append({"message_id": message_id, "error": str(exc)[:200]})

    log(
        run="mail-atlas-reconcile",
        dry_run=args.dry_run,
        mailbox=args.mailbox,
        mailbox_letters=len(present),
        archive_letters=len(boxes),
        archive_inbox=sum(1 for _, box in boxes if box == INBOX),
        restored=len(restored),
        archived=len(archived),
        gone=len(gone),
        changed=len(changes) - len(failures),
        sample=[{"box": box, "why": why, "message_id": message_id} for message_id, box, why in changes[:5]],
        failed=failures,
        pages_read=pages,
    )
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
