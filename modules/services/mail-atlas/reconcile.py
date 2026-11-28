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

Four guards, because this rewrites 2000 rows when it is wrong:

  * the walk must complete. A read that stops at the page cap is a partial set,
    and a partial set reads as "everything below this page left the inbox" —
    a scan bounded by its own limit is the one failure mode that would empty
    the working set. An incomplete walk aborts before anything is written.
  * a failure to read is a failure to conclude. himalaya errors are raised, not
    swallowed into an empty inbox. A document without an `envelopes` key is a
    failed read, not an empty mailbox: `{}` is what a wrong account or a broken
    config returns, and treating it as "nothing is here" archives everything.
  * an empty walk is refused while the archive still holds inbox letters. The
    mailbox of a person with 2000 letters is not empty, so the empty answer is
    the failure, and `--allow-empty` is the deliberate override.
  * the walk must be stable. Offset paging over a mailbox that gains mail at the
    head shifts every later row forward, so a letter can move past the page
    being read and never be seen — which reads as "it left the inbox". The head
    of page one is re-read after the walk and a changed head aborts the run.

`--dry-run` prints the diff and writes nothing; it is the default in the task.
A run is safe to repeat: the plan is recomputed from the live boxes each time
and `atlas-box-set` skips a write that changes nothing, so a second pass over a
successful one plans no changes at all.
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


class WalkError(RuntimeError):
    """The mailbox could not be read as a complete, stable set of letters."""


def himalaya(argv, config, account, timeout=300):
    cmd = ["himalaya", "-c", config, "--json"]
    if account:
        cmd += ["-a", account]
    try:
        proc = subprocess.run(cmd + argv, capture_output=True, text=True, timeout=timeout)
    except subprocess.TimeoutExpired as exc:
        raise RuntimeError(
            f"himalaya {' '.join(argv[:2])} timed out after {timeout}s"
        ) from exc
    except OSError as exc:
        raise RuntimeError(f"himalaya could not run: {exc}") from exc
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


def envelopes_of(doc, page="?"):
    """The page's envelopes, or a failed read rather than an empty mailbox."""
    if not isinstance(doc, dict) or "envelopes" not in doc:
        raise WalkError(
            f"himalaya envelope list returned no `envelopes` on page {page}; "
            "an empty document is a failed read, not an empty mailbox"
        )
    return doc.get("envelopes") or []


def head_of(envelopes):
    for envelope in envelopes:
        key = normalize(envelope.get("message-id"))
        if key:
            return key
    return None


def mailbox_ids(config, account, mailbox, page_size, max_pages, verify_head=True):
    """Every Message-ID in the mailbox, and whether the walk reached the end.

    Ordered newest first, so a short page is the end rather than a hole: paging
    stops at `--max-pages` only if the mailbox is bigger than that. A multi-page
    walk re-reads the head afterwards, because new mail at the head shifts every
    later row forward and a shifted row is a letter this walk would call gone.
    """
    seen = set()
    pages = 0
    head = None
    complete = False
    for page in range(1, max_pages + 1):
        envelopes = envelopes_of(
            himalaya(
                ["envelope", "list", "-m", mailbox, "-s", str(page_size), "-p", str(page)],
                config,
                account,
            ),
            page,
        )
        pages += 1
        for envelope in envelopes:
            key = normalize(envelope.get("message-id"))
            if key:
                seen.add(key)
        if page == 1:
            head = head_of(envelopes)
        if len(envelopes) < page_size:
            complete = True
            break

    if complete and verify_head and pages > 1:
        again = envelopes_of(
            himalaya(
                ["envelope", "list", "-m", mailbox, "-s", str(page_size), "-p", "1"],
                config,
                account,
            ),
            "1",
        )
        moved = head_of(again)
        if moved != head:
            raise WalkError(
                "the mailbox head moved during the walk "
                f"({head!r} -> {moved!r}); offset paging cannot be trusted, so "
                "this pass is not a verdict"
            )
    return seen, complete, pages


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
    parser.add_argument(
        "--allow-empty",
        action="store_true",
        help="accept an empty mailbox even though the archive still holds inbox letters",
    )
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    try:
        rows = api(args.api, "/api/atlas-boxes")
        boxes = [(row.get("messageId"), row.get("box") or INBOX) for row in rows]
    except (urllib.error.URLError, OSError, ValueError, RuntimeError) as exc:
        log(run="mail-atlas-reconcile", ok=False, error=f"cannot read the archive's boxes: {exc}")
        return 2

    try:
        present, complete, pages = mailbox_ids(
            args.himalaya_config, args.account, args.mailbox, args.page_size, args.max_pages
        )
    except (WalkError, RuntimeError) as exc:
        log(
            run="mail-atlas-reconcile",
            ok=False,
            error=str(exc)[:400],
            archive_letters=len(boxes),
            dry_run=args.dry_run,
        )
        return 2
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

    inbox_rows = sum(1 for _, box in boxes if box == INBOX)
    if not present and inbox_rows and not args.allow_empty:
        log(
            run="mail-atlas-reconcile",
            ok=False,
            error=(
                f"the walk read {args.mailbox} as empty while the archive still holds "
                f"{inbox_rows} inbox letters; that is an unread mailbox, not an empty one "
                "(--allow-empty overrides)"
            ),
            mailbox_letters=0,
            archive_letters=len(boxes),
            archive_inbox=inbox_rows,
            pages_read=pages,
        )
        return 2

    planned = plan(boxes, present)
    changes = planned[: args.limit]
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
        planned=len(planned),
        truncated=len(planned) > len(changes),
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
