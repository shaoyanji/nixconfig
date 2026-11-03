---
name: mail-archive
description: "Pick me to read or change the fleet's email archive: the hot tables behind the tailnet API on 8450, how a verdict is written and closed, and how to pull more mail out of himalaya when the archive has only the envelope."
version: 0.1.0
author: Shaoyan Ji (shaoyanji), Hermes Agent
license: MIT
platforms: [linux]
metadata:
  hermes:
    tags: ['email', 'archive', 'postgres', 'api', 'triage', 'himalaya']
    related_skills: ['apps', 'jevdecide', 'task-plane', 'confirm-before-destructive']
---

# `mail-archive` — the email hot tables behind the API

Every agent reads and writes one mail store: PostgreSQL `email_archive` on
**delphi**, published as HTTP by NpgsqlRest. The API is not a client library and
not a script — it is a directory of SQL files, one route each, type-checked
against the schema at startup.

| | |
| :--- | :--- |
| Loopback (on delphi) | `http://127.0.0.1:8080` |
| Tailnet (any fleet host) | `https://delphi.cloudforest-kardashev.ts.net:8450` |
| Health (root, not under `/api`) | `curl -s localhost:8080/health` → `Healthy` |
| Machine-readable contract | `curl -s localhost:8080/openapi.json` — 23 paths, live |
| The routes themselves | `modules/services/email-archive-endpoints/*.sql` (archive) and `modules/plugins/appflow/*.sql` (pipeline) |
| Module / docs | `modules/services/email-archive.nix`, `docs/email-archive.md` |

`RequiresAuthorization = false`: the **tailnet is the boundary**. Never publish
8080 or 8450, never put a token in a URL, and never mirror this API anywhere the
tailnet does not reach.

## Two hard rules that save a wasted request

1. **Parameter names are camelCase**, in query strings and JSON bodies: `messageId`,
   `applicationId`, `bodyPlain`. `message_id` is a **404**, not an empty result.
2. **A write body must carry exactly its keys.** One missing or unknown key is a
   404 with no body, not a 400 with a message. Send all of them.

## The tables

| Table | What it is | How it changes |
| :--- | :--- | :--- |
| `emails` | the archive: every imported message, body as plain text | `POST /api/add-email` only; an upsert that keeps existing non-null columns, so a second post fills gaps instead of overwriting |
| `email_triage` | verdicts: one row per `(message_id, classifier)` | `POST /api/triage-upsert`; the only other writable column is `resolved_at` |
| `applications`, `application_mail` | the job pipeline, a plugin of the same database | `modules/plugins/appflow/README.md` and the `apps` skill |

Read semantics worth knowing before you query:

- **The newest verdict wins.** Every read joins `lateral … order by decided_at desc
  limit 1`, so a second classifier is an upgrade, never a duplicate row.
- **`resolved_at` closes the whole message**, every classifier's verdict at once.
  An upsert keeps `resolved_at`, so re-classifying mail a person already handled
  cannot put it back in the queue.
- **`owner` routes the mail.** `agent:<name>` belongs to that agent's queue,
  `human` to the person's. `/api/attention` excludes `agent:%` on purpose.

## Reads

```bash
B=http://127.0.0.1:8080/api          # or https://delphi…:8450/api from another host
curl -s "$B/list-emails?lim=5" | jq -r '.[] | "\(.sentAt // "-") \(.sender) — \(.subject)"'
curl -s "$B/attention?lim=20" | jq        # person + action + review, unresolved, human-owned
curl -s "$B/agent-queue?owner=agent:apps&lim=20" | jq
curl -s "$B/triage-pending?classifier=<name>&lim=50" | jq
curl -s "$B/triage-digest?days=7&lim=50" | jq
curl -s "$B/plugins" | jq                 # per-owner backlog: the hub dashboard
curl -s --get --data-urlencode "q=invoice OR receipt" "$B/emails-search" | jq
curl -s --get --data-urlencode "messageId=<id>" "$B/message-body" | jq -r '.[0].bodyPlain'
```

| Route | Params | Returns |
| :--- | :--- | :--- |
| `list-emails` | `lim` | newest first, with `bodyLength` and no body |
| `emails-search` | `q` (websearch syntax: quotes, `OR`, `-word`) | 50 rows with a `ts_headline` snippet |
| `message-body` | `messageId` | the body of **one** message |
| `attention` | `lim` | the person's queue, newest per message, excludes agent owners |
| `agent-queue` | `owner`, `lim` | one agent's queue; `owner=agent` returns all of them |
| `triage-pending` | `classifier`, `lim` | messages that classifier has not judged |
| `triage-digest` | `days`, `lim` | the digest tier for a summary window |
| `plugins` | — | open/resolved per owner + last decision (no double counting) |

Pipeline routes (`application-search`, `application-get`, `applications`,
`application-attention`, `application-pipeline`, `application-mail`,
`message-applications`, `applications-discovered`, `applications-export`) are the
`apps` skill's; writes there are `application-upsert`, `application-update`,
`application-link`.

## Writes

```bash
# one verdict — all six keys, camelCase
curl -s -X POST -H 'content-type: application/json' "$B/triage-upsert" -d '{
  "messageId":"<id>","classifier":"<name>","tier":"digest",
  "owner":"human","reason":"newsletter, no deadline","confidence":0.9}'

# close one message (returns the rows it changed; [] means nothing was open)
curl -s -X POST -H 'content-type: application/json' "$B/triage-resolve" \
  -d '{"messageId":"<id>"}'

# insert or fill in one message
curl -s -X POST -H 'content-type: application/json' "$B/add-email" -d '{
  "messageId":"<id>","threadId":"","sender":"Name <a@b.c>","recipients":"me@x.y",
  "subject":"…","sentAt":"2026-11-03T10:00:00Z","labels":"Inbox",
  "bodyPlain":"…","attachmentPath":""}'
```

`recipients` and `labels` are **comma-separated strings**, not arrays: a JSON array
cannot bind to `text[]` in NpgsqlRest (measured), so the SQL splits them.

The tier vocabulary is closed: `person`, `action`, `review`, `digest`, `robot`. The
rule *signals* (`record`, `one-shot`, `deadline`, `pointer`) are reasons that map
onto those five; a sixth tier is a queue nothing reads.

## Prefer the task, then the route

| Question | Use |
| :--- | :--- |
| what needs a person | `task agents:mail:attention` |
| done with one message | `task agents:mail:resolve ID=<messageId>` |
| clear a block by sender/tier/age | `task agents:mail:sweep SENDER=… DRY=1` then `DRY=0` |
| who owns what backlog | `task agents:hub` |
| anything else | the route above |

A new route is a new `.sql` file plus a switch — never a new script, and never a
`psql` one-liner against the live tables. Add an endpoint when an agent needs a
question no existing route answers, then name it here.

## Scraping more out of himalaya

The importer (`email-archive-import`) walks **the inbox only**, 200 new messages
per hourly run, and stores plain text plus an attachment path. Sent, Archive, a
second account, or mail older than the importer's window is not in the archive
until something posts it — that is the extension path:

```bash
H="himalaya -c ~/.config/himalaya/config.toml"
$H envelope search -m "[Gmail]/All Mail" -s 20 -- to someone@example.com   # find it
$H message read <id> -m "[Gmail]/All Mail" --raw > /tmp/m.eml               # fetch it
# extract text/plain (html2markdown for HTML-only), then POST /api/add-email
```

Rules that keep this honest:

- **`add-email` is idempotent.** Posting a message that is already archived updates
  it and keeps the non-null columns, so a re-run is safe. Post metadata first,
  body later — empty strings mean "no value", not "erase".
- **Search before you scrape.** `emails-search` costs one request; a mailbox walk
  costs a session.
- **Attachments** land under the state directory's tree and are referenced by
  `attachmentPath`; the body is what an agent reads, and it must be plain text.
- `himalaya` is also the way to read a body the archive stored empty: the archive
  keeps what the importer saw at import time.

## Safety

- **There is no delete.** `resolved_at` is the close, and `emails` is append-only.
  If a row is wrong, upsert it — never reach for `psql` to remove it.
- **Bodies are large.** Read `bodyLength` from a list, then fetch one body. Never
  dump a body into context to answer a question about an envelope, and never paste
  mail content or addresses into a commit, a note or the turn log.
- **Bulk writes need a dry run.** `agents:mail:sweep` prints what matched by tier
  and sender before it writes; a bulk `triage-upsert` loop is the last resort, and
  the classifier name is what makes it reversible (a new name re-judges).
- **Sending mail is a different act.** The archive records mail; it does not send
  it. Delivery is `himalaya message send` (see the `apps` skill for drafts and
  packets), and it needs a `From:` header — a draft without one cannot be sent.

## Verify

```bash
curl -s localhost:8080/health                       # Healthy
curl -s localhost:8080/openapi.json | jq '.paths|length'   # 23 (grows with a route)
curl -s "$B/plugins" | jq '.[] | select(.open > 0)'  # nobody starved of work
```

An HTTP 200 with `[]` is a fact ("nothing matched"), not a failure; a 404 is a
wrong parameter name or key, so fix the name before doubting the data.
