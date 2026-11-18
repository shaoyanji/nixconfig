# Terminal clients — one API, three readers

Every webapp on delphi is a loopback process behind a `tailscale serve` mount.
A browser is one reader of that; `curl`, a shell CLI and a TUI are the others.
The rule this page sets is that **the terminal is a first-class reader of the
same routes**, not a second backend: nothing here adds a service, and nothing a
terminal does reaches a table a page cannot.

| Service | Loopback | Tailnet | The terminal client |
| :--- | :--- | :--- | :--- |
| media library (`docs/media-relay.md`) | `127.0.0.1:8094` | `:8461` | `media` (`modules/scripts/media-cli.nix`) |
| email archive (`docs/email-archive.md`) | `127.0.0.1:8080` | `:8450` | `mail` (`modules/scripts/mail-cli.nix`) |

Both CLIs are thin: `curl` + `jq` + `fzf`, no state, no cache, no credentials.
The tailnet is the boundary on both ports — there is no token anywhere — so a
client only needs to be on the tailnet to be the same principal the webapp is.

## What a surface needs before a terminal can use it

These are the properties the two APIs were held to, and the checklist for the
next one:

1. **One request per view.** `GET /api/library` and `GET /api/r2` each answer a
   whole listing. A client that has to walk a tree makes N round trips over
   WireGuard and a person waits.
2. **Envelope in the list, body on demand.** `list-emails` returns
   `body_length`; `message-body` returns one body. A terminal prints forty rows,
   not forty megabytes.
3. **Stable ids.** `messageId` for mail, `key`/`path` for media. A row a person
   picks in `fzf` must still name the same thing a second later.
4. **Destructive verbs are explicit.** Delete and prune are `DELETE` and a `gc`
   that is dry unless told; closing a verdict is a POST through a route. No
   route deletes as a side effect of reading, so a CLI never needs `psql`.
5. **The same shape in JSON.** `jq -r '.[] | [...] | @tsv'` is the whole
   rendering layer. A route that returns prose, or a number as a string, is a
   route a terminal cannot tabulate.
6. **Nothing depends on JavaScript.** The page is one static file; the same data
   is one JSON route. A TUI must never need to scrape HTML.

## The routes, as a terminal sees them

### media (`:8461`)

| Route | Verb | Params | Answers |
| :--- | :--- | :--- | :--- |
| `/api/health` | GET | — | liveness, cookie jar, whether R2 and gc are configured, retention |
| `/api/library` | GET | — | the local manifest: `{count, bytes, items[]}` |
| `/api/r2` | GET | `refresh` | the bucket's rows, `{count, bytes, items[]}` |
| `/api/search` | GET | `q`, `limit` | one `yt-dlp -J ytsearch`, cached 10 min |
| `/api/jobs` | GET | — | the queue's last 40 records |
| `/api/fetch` | POST | `{url,title}` | queue a local fetch; `out` is a path |
| `/api/store` | POST | `{url,title}` | queue a store; `out` is the edge URL |
| `/api/library` | DELETE | `path` | one local file, its poster, its empty folder |
| `/api/r2` | DELETE | `key` | one object and the poster beside it |
| `/api/gc` | POST | `{days,dry,scope}` | prune both halves; dry unless `dry:false` |

`media ls`, `find`, `search`, `get`, `store`, `play`, `rm`, `gc`, `jobs` and
`health` are those routes and nothing else. `find` is local fuzzy ranking over
one listing (`fzf --filter`), not a server-side search, because the listing is
already on the wire.

### mail (`:8450`)

| Route | Verb | Params | Answers |
| :--- | :--- | :--- | :--- |
| `/api/list-emails` | GET | `lim` | newest first, `body_length`, no body |
| `/api/emails-search` | GET | `q` | full text, `websearch_to_tsquery`, a `ts_headline` snippet |
| `/api/emails-fuzzy` | GET | `q` | one literal substring across sender, subject and body |
| `/api/message-body` | GET | `messageId` | one body |
| `/api/attention` | GET | `lim` | the person's queue, newest verdict per message |
| `/api/agent-queue` | GET | `owner`, `lim` | one agent's queue |
| `/api/triage-*` | GET/POST | see the skill | verdicts, digest, resolve |
| `/api/plugins` | GET | — | open/resolved per owner |

`emails-search` and `emails-fuzzy` are two engines because they fail
differently: the first needs words the stemmer knows, the second answers a
fragment an address or a part number. `mail q` tries the index, falls back to
the substring, and ranks whatever comes back with `fzf` — the fuzzy part is the
client's, which is why the route stays a simple `select`.

## Content negotiation, when it lands

The next step is the one the browser and a terminal disagree about: `GET /` on
the media vhost returns HTML, and `curl https://delphi…:8461/` should return the
same listing as text. The design that does not fork the service:

- nginx `map`s `$http_accept` and `$http_user_agent` to a `$reader` variable:
  `text/plain` or a user agent of `curl`, `wget`, `nushell`, `hx`, `w3m`,
  `lynx`, `links`, `elinks`, `httpie` → `plain`; everything else → `html`.
- `/` selects `index.html` or a TOON document rendered from the same
  `/index.json` + `/api/r2` pair, so there is one source and two renderings.
- `?format=text|json|html` overrides the guess, because a UA is a hint and not
  a contract, and a person testing with `curl` should be able to ask for HTML.

TOON, not CSV: the fleet's boundary format is TOON (`docs/agent-contract.md`),
so a terminal rendering and an agent's read are the same bytes.

## Where a TUI starts, and where Go belongs

A shell CLI is the right size for CRUD: the work is one `curl`, one `jq`, and a
person's eyes. A **TUI** is a different programme — focus, a viewport, polling,
a composer, mail bodies rendered with wrapping and links, and eventually a
graph. That is where the shell stops being honest, and it is a separate private
repo rather than a third module here:

- **The seam is the HTTP contract on this page.** A TUI is a client of `:8461`
  and `:8450`, the same routes a browser and `media`/`mail` use. It needs no
  privileged access, no database driver and no SSH.
- **Go is the right language for that binary**, not for this repo: `bubbletea`
  gives the focus and viewport model, one static binary installs on every
  tailnet host, and the fleet's Nix side then packages a release rather than
  compiling a Go tree inside the flake. `modules/` stays Nix and shell.
- **Nothing moves out of this repo.** The routes, the schema, the endpoints and
  the two CLIs stay; the TUI depends on them and can be rewritten without
  touching a host.
- **Stirling is a separate project again.** A PDF workstation TUI shares the
  terminal-client shape and none of the data model, so it earns its own repo and
  its own decision.

Open work, in the order it pays:

1. The `Accept`/UA map on `:8461` and `:8450` (`?format=` first: it is testable).
2. A `mail thread MESSAGE_ID` route: the archive stores `thread_id` but no read
   returns a thread, and a terminal reader wants the conversation.
3. A `media rm --all-matching` for a folder, so a bad fetch is one command
   rather than two files and a poster.
4. The TUI repo, once the text rendering above is good enough that a person
   would use it without the browser.
