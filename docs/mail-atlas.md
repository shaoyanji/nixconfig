# mail-atlas — the archive as a field

The reading surface over `email_archive`: fuzzy finding, a curated tag taxonomy,
and a relation graph that redraws itself on every query. Same database as the API
in [`docs/email-archive.md`](email-archive.md), no second copy of the mail.

| | |
| :--- | :--- |
| Tailnet | `https://delphi.cloudforest-kardashev.ts.net:8452` (tailnet only, `tailscale serve`) |
| Loopback | nginx vhost `127.0.0.1:8085`; `/api/` proxies to `npgsqlrest` on `127.0.0.1:8080` |
| Module | `modules/services/mail-atlas.nix` |
| Schema | `modules/services/mail-atlas/schema.sql` |
| Endpoints | `modules/services/mail-atlas/endpoints/*.sql` |
| Page | `modules/services/mail-atlas/site/` (HTML, CSS, JS, one `.wat`) |
| Queue | `task agents:mail:atlas` — the decisions waiting on an agent |

The frontend and the API share an origin on purpose: the browser needs no CORS
grant, and `/api` is not reachable from anywhere except this vhost. Publishing is
one `services.servicePortal.mounts.mail-atlas` entry, so the tailnet port, the
served upstream and the portal card are the same declaration.

## The schema

Four tables, all owned by the archive role and applied by `email-archive-db-init`
through the hub's plugin contract (`services.emailArchive.plugins.mail-atlas`).

| Table | What it is |
| :--- | :--- |
| `mail_category` | ten fixed domains, each with a glyph, a label and a one-line stance |
| `mail_tag` | a findable subject inside exactly one category |
| `mail_tag_rule` | how a tag is recognised: a `LIKE` pattern on sender, subject, body or all three |
| `email_tag` | the association, keyed `(message_id, tag, source)` so two taggers can disagree |
| `mail_action` | a decision a person made in the reader: archive, queue deletion, or an instruction for Hermes |
| `mail_box` | where a letter sits in the working inbox: `inbox`, `queued`, `archived`, `trashed`, `gone` |
| `mail_command` | a command about the mailbox rather than a letter, in the person's own words |

`tags are stored, not computed at query time` — a taxonomy that is recomputed per
request cannot be corrected by hand, and the graph needs the counts cheaply.

`mail_atlas_autotag()` is the rules pass. It judges messages that carry no rule
verdict yet, newest first, bounded by `services.mailAtlas.tagLimit` (4000), and
adds `attachment` from the column rather than from text — an attachment is a fact
about the row. `mail-atlas-tag.service` runs it at `:50` every hour: the importer
runs on the hour with a delay and triage at `:45`, so this is the first slot after
both. It is idempotent and reports the number of rows it added (`0` is the normal
steady state).

Coverage is honest, not total: 1536 of 2050 messages carry at least one tag. The
remainder are mail no rule claims — still fully searchable by body, just not
placed on the map.

`pg_trgm` is created by the db-init unit as `postgres` before any plugin schema
runs as the archive role, because `CREATE EXTENSION` is superuser-only. Two GIN
trigram indexes on `lower(subject)` and `lower(sender)` are what make a
misspelling resolve instead of returning nothing.

## The endpoints

All are proxied under `/api/`, and every parameter is required — NpgsqlRest never
registers a defaulted one, and an unregistered parameter is a 404 rather than a
400.

| Route | Method | Parameters | What |
| :--- | :--- | :--- | :--- |
| `/api/atlas-search` | GET | `q`, `cat`, `box`, `off`, `lim` | fuzzy finding; empty `q` is "newest", empty `cat` is every category, `box` is the working set |
| `/api/atlas-taxonomy` | GET | — | categories with glyphs, tags and distinct-message counts |
| `/api/atlas-tags` | GET | `q`, `lim` | fuzzy tag completion for the chip row |
| `/api/atlas-message` | GET | `id` | one message in full, with its tags and the decisions already taken |
| `/api/atlas-stats` | GET | — | letters / tags / tagged / associations / newest |
| `/api/atlas-act` | POST | `messageId`, `kind`, `instruction` | record a decision; also closes the open verdicts for that message |
| `/api/atlas-actions` | GET | `status`, `lim` | the queue a drainer executes, oldest first |
| `/api/atlas-close` | POST | `id`, `status`, `result` | close a queued decision as `done` or `dismissed` |
| `/api/atlas-command` | POST | `instruction` | a command about the mailbox, not one letter |
| `/api/atlas-commands` | GET | `status`, `lim` | the general commands waiting on an agent |
| `/api/atlas-command-close` | POST | `id`, `status`, `result` | close a general command with one line of result |
| `/api/atlas-boxes` | GET | — | every letter and its box, flat — the reconcile's index, not a ranked page |
| `/api/atlas-box-set` | POST | `messageId`, `box` | set one letter's box from outside a decision |

**A POST body is camelCase.** NpgsqlRest binds a JSON property to a SQL parameter
by name, and the response aliases arrive camelCased too: `{"messageId": "<RFC
Message-ID>", "kind": "archive", "instruction": ""}`. Sending `message_id` is
not a 400 — it is a 404 with an empty body, because the parameter never binds and
the insert fails the foreign key (measured 2026-11-05). The Message-ID string is
the identity; a row `id` from the search response is a different number and will
fail the same way.

**Score is three signals, not one.** `ts_rank` ranks the body,
`similarity(lower(subject), q)` and `similarity(lower(sender), q)` measure the
typed string against the two fields a person remembers, and a third term comes
from tag similarity, so a query can route through the taxonomy before it reaches
a body. `invoce` finds the invoice; `kleinanzeig` finds the marketplace.

**An empty query-string value is `NULL`, not `''`.** `coalesce(:q, '')` and
`coalesce(:cat, '')` are what make `?cat=` mean "every category" instead of
"match nothing" — without them every unfiltered search returned `[]` while
answering `200` (measured 2026-11-05).

## Decisions

A letter opened in the reader carries three buttons, and the popup is the only
place they live: the message is what the decision is about. `a` archives it, `x`
queues deletion, `h` hands it to Hermes with an instruction in the person's own
words (`archive after the refund lands`). Deletion asks twice — the first press
arms, the second queues, four seconds to change your mind — because a mail
removed by accident is not recoverable from this archive.

**These are requests, not effects.** `mail_action` rows are what the browser is
allowed to write: the archive never deletes mail (it is the searchable record)
and no browser runs `himalaya`. One row per `(message, kind)`, so asking twice
updates the instruction instead of queueing the same work twice, and a repeat
after closure reopens it.

## The working set

The list is an inbox, not a browse of the archive. `mail_box` says where each
letter stands — `inbox` (nothing decided), `queued` (asked for, not yet
executed), `archived`, `trashed`, `gone` (it left the Gmail inbox by other
means) — and the search filters on it (`box=inbox|queued|done|all`, default
`inbox`).

A decision moves the letter out of the working set **when it is asked for**, not
when the drain gets to it: `POST /api/atlas-act` writes `box='queued'` in the
same statement, and the page drops the row locally so the list never shows what
you just told it to handle. `/api/atlas-close` then records the outcome —
`archived`, `trashed` for a deletion, `gone` for a dismissal. That is why a batch
of forty leaves the list at once instead of waiting for the next import, which
would never notice: the archive keeps mail on purpose.

The tabs above the list are that filter (`inbox` / `queued` / `handled` / `all`),
the header counts are the working set and what is in flight, and `more letters`
continues the same query with `off` — forty-eight is a page, not the whole inbox.

## The queue is executed

`mail-atlas-drain` is the other end. A oneshot unit on
`mail-atlas-drain.timer` — `OnCalendar=*:0/5`, `Persistent=true`, 20 s
`RandomizedDelaySec` — reads the pending rows, resolves each Message-ID in the
source mailbox through `himalaya`, and does the one reversible thing the
decision means:

| Kind | What the drain does | Result recorded |
| :--- | :--- | :--- |
| `archive` | `message move` Inbox → `[Gmail]/All Mail` | `moved uid … to [Gmail]/All Mail` |
| `delete` | `message delete` — trash first; nothing here expunges | `trashed uid …` |
| `hermes` | **nothing** — an instruction is a sentence for an agent | row stays `pending` |

Resolution never guesses. himalaya cannot query a Message-ID, and real subjects
are not valid queries (`[shaoyanji/nixconfig] Run failed: …` — brackets, colons,
parentheses all break the parser), so the header decides and each query only
narrows the page it sits on: the message's own `date`, then the neighbouring two
days (the `Date:` header carries the sender's offset), then one alphanumeric
token of the subject. A message none of those find is closed `dismissed` with

`not in inbox` — the archive stored the same header the query reads, so a miss
means something already moved it, and the person's decision is satisfied.

Measured on a 6000-envelope inbox: a resolved decision costs ~7 s end to end
(including `himalaya` auth), where the `--deep-scan` walk of the whole mailbox
that used to be the fallback cost **74 s per run**.

A himalaya failure leaves that row `pending` and fails the unit, so the next tick
retries it; one bad row never stops the others. `--dry-run` (or
`services.mailAtlas.drain.dryRun`) resolves and logs the uid each row would act
on while closing nothing. The journal line is one JSON object per run:
`pending`, `done`, `dismissed`, `left_for_agent`, `failed`.

**The same rows, two readers.** The timer executes `archive` and `delete`;
`hermes` rows are read by an agent with `task agents:mail:atlas` (TOON by
default, `FORMAT=text` for a table), executed under its own `--apply` gate, and
closed through `/api/atlas-close` with one line of result.

Posting any decision also resolves the message's open `email_triage` verdicts:
the person has just dealt with it, so it should leave `/api/attention` in the
same act rather than needing a second click.

## The mailbox is the truth

`mail_box` only ever knew what this page asked for. Mail is also archived from a
phone, a web client or a filter, and none of that reaches the atlas — so a letter
archived in Gmail kept counting as inbox, and the working set filled with mail
the person had already handled. That is a wrong number at the top of the page,
which is worse than a slow one.

`mail-atlas-reconcile` closes it. One run reads the Message-IDs of every
envelope in the Inbox through `himalaya` (500 per page, until a short page says
the walk reached the end) and compares them with `/api/atlas-boxes`:

| In the Inbox | Box here | Becomes | Because |
| :--- | :--- | :--- | :--- |
| yes | `archived` / `trashed` / `gone` | `inbox` | it came back; undo and re-filing both look like this |
| no | `inbox` | `archived` | it left, unasked. Gmail has no Archive folder, so "not in Inbox" is what archiving is |
| no | `queued` | `gone` | it left before the drain could act, so the request closed itself |

Two guards, because a wrong run rewrites two thousand rows: **the walk must
complete** — a scan stopped at its own page cap is a partial set, and a partial
set reads as "everything below this page left the Inbox", which would empty the
working set in one pass; and **a failed read is not an empty Inbox** — a himalaya
error is raised and the run writes nothing. `--dry-run` (the default in the task)
prints the diff and touches no row.

The timer is `mail-atlas-reconcile.timer` (`OnCalendar=*-*-* 04:20:00`, nightly):
it lands before the 06:30 bulk sweep, so the sweep decides against a working set
that already knows what left the Inbox by other means. A full walk of the Inbox
is a night job — 13 envelope pages on 6394 letters — and a run with nothing to
write is that walk and one read. Its journal line is one JSON object —
`mailbox_letters`, `archive_inbox`, `restored`, `archived`, `gone`, `sample`,
`failed`.

## Box history

`mail_box` says where a letter is; `mail_box_event` says how it got there. Every
move appends a row — a decision (`decision archive`), the drain closing it
(`drain done`), or the reconcile finding the mailbox had moved it first (`left
the inbox`) — with the box it came from and the time.

The handled list shows the last line of that trail, `trashed · 2 h ago`, with the
reason as its tooltip; the reader shows the last four moves under the sender
(`queued 3 h ago → trashed 1 h ago`). A write that changes nothing appends
nothing, so the trail stays a list of changes rather than of looks. Boxes that
predate the table were backfilled once as `recorded` from `changed_at`, so an old
handled row has an age without inventing a move it cannot prove.

## The page

One static document. `信海圖` — the character for a letter over the character for
a sea, over the character for a chart.

- **The field.** `site/particles.wat` is a real particle simulation — position and
  velocity arrays, a flow field over them, a ripple impulse — compiled to
  `particles.wasm` by `wabt` at build time. Core WASM has no `sin`/`cos`, so the
  flow field carries a polynomial approximation with range reduction. The canvas
  only reads the shared buffer and paints; if the module fails to load, the field
  is hidden and the archive still works. Clicking anywhere sends a ripple.
- **The field answers the search.** `mood(amp, swirl)` is the one channel from the
  page into the simulation: a query raises the current (measured **43 → 79 px/s**
  mean speed at 3.4 amplitude, over 641 particles), turns it gold and slow when nothing answers, and
  relaxes over about a second. The page also schedules impulses — an inhale at the
  search box on submit, a light ripple per keystroke, a heartbeat at the graph's
  centre when results land. The simulation never learns the query; it only feels
  how much the sea is moving.
- **The graph is the answer, not a decoration.** Nodes are the query, all ten
  gates, its hottest tags and the first 30 letters; edges are letter→tag and
  tag→category, bowed and carrying a travelling spark whose rate is the link's
  heat. Every node has a heat derived from the result set: gate gauges are the
  share of the answer a gate claims, tag diamonds and letter dots scale with it,
  and gates outside the answer stay faint so the whole archive remains legible.
  A slow sweep runs the outer ring. Positions persist across keystrokes, so the
  field responds rather than rebuilding. Labels carry the same fuzzy highlight as
  the list. Clicking a tag re-runs the search; clicking a gate filters to it.
- **Fuzzy is one classifier, two renderers.** `classify()` marks exact substrings
  and subsequence matches; the list renders them as `mark` (solid for exact,
  dotted for fuzzy) and the canvas labels as gold runs, so a hit looks the same
  wherever it is drawn.
- **The type ships with the page.** The Han glyphs are cut from Noto CJK TC into
  an 11.9 kB WOFF subset at build time (`han.woff`) and served same-origin — a
  machine without CJK fonts used to render the title as tofu boxes.
- **Keys.** `/` focuses the search, `↑`/`↓` (or `j`/`k`) walk the results, `↵`
  opens the reader — including with the caret still in the search box, as long as
  that box holds the query the list was built from, so `↵` after typing a new
  word searches instead of opening a stale result. Inside the reader `a` / `x` /
  `h` are the decisions, `⌘↵` in the instruction box queues it, `Esc` closes.
  State lives in the URL (`?q=&cat=`), so a search is a link.
- **The list is a workspace.** `space` (or a click on the row's box) marks a
  letter, `a` archives the marked set, `x` queues it for deletion — twice, the
  same arm-then-confirm as the reader — and `Esc` clears the marks and disarms.
  With nothing marked both letters apply to the focused row (or the first one),
  so a single decision never needs a second gesture. The bar under the title
  carries the same three verbs as buttons, so the list does not require the
  keyboard it rewards.
- **One command for the whole mailbox.** `H`, or the `command Hermes` button in
  the header, opens a box for a sentence with no letter behind it — "every
  newsletter older than a month can go". It writes a `mail_command` row: nothing
  executes it, `task agents:mail:atlas` reads it beside the per-letter
  decisions, and an agent closes it with `/api/atlas-command-close`.
- **The field folds.** The graph is an instrument beside the list, not the point
  of the page: `fold` collapses its column, which also stops the particle
  simulation, and the choice survives a reload (`localStorage`). On a small
  machine that is the difference between a decoration and a usable inbox.
- **The page presents; it does not rewrite the record.** Bodies are markdown by
  design (`html2markdown` at ingest), and older rows carry drawn-out escapes and
  HTML entities from before that filter existed. One cleaner runs at render:
  entities and `\uXXXX` sequences are unpacked, tags, autolinks, link and image
  syntax are reduced to their text, heading and rule lines go, stray emphasis
  markers go. Measured over all 2051 archived bodies, no markdown delimiter,
  entity or escape survives except inside tokens (`WPC__Kg`, a masked phone
  number). The stored body is never touched — it is the record.
- **No third-party origins.** No CDN, no analytics. The one webfont is the
  subset built above, served from this vhost; everything else is the system's
  serif and mono.

## Verify

```bash
systemctl status mail-atlas-tag.timer mail-atlas-drain.timer --no-pager
systemctl list-timers mail-atlas-drain.timer --no-pager      # next tick
task agents:mail:atlas                                        # what the timer will do
sudo journalctl -u mail-atlas-drain -n 3 --no-pager           # last run, one JSON line
curl -s http://127.0.0.1:8085/ | grep -c 信海圖          # the page
curl -s -o /dev/null -w '%{content_type}\n' http://127.0.0.1:8085/particles.wasm  # application/wasm
curl -s -o /dev/null -w '%{content_type} %{size_download}\n' http://127.0.0.1:8085/han.woff  # font/woff ~11.9 kB
curl -s 'http://127.0.0.1:8085/api/atlas-stats' | jq
curl -s 'http://127.0.0.1:8085/api/atlas-search?q=invoce&cat=&lim=3' | jq '.[].subject'
sudo journalctl -u mail-atlas-tag -n 5 --no-pager
```

The last line should end in a number: rows added. `0` means the archive is fully
tagged against the current rules.

## Not done here

- **No auth beyond tailnet membership**, same as the archive API itself.
- **No bulk selection by rule.** Marking is manual (space or click); "everything
  from this sender" is a command for Hermes, not a checkbox.
- **Rules only.** Nothing semantic reads a body to invent a tag; a new tag is a
  row in `mail_tag_rule`, not code.
- **No UI for the taxonomy.** A tag applied by hand is a SQL statement, which is
  why `email_tag` carries `source`.
- **Hermes rows are not executed.** The drain carries out `archive` and
  `delete`; an `h` instruction waits for an agent to read it, and the atlas can
  only report that the row is still `pending`.
